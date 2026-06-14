# P2-ε. 日付一括選択 → プリセット一括適用 → パターン検出

> 状態: **未着手 / 設計確定（2026-06-14）**。本ファイルが仕様・DoD の正典（AGENTS.md §6.1.2）。
> 状態・進捗・優先度の正典は Linear（追跡: [DEV-200](https://linear.app/dolquis/issue/DEV-200)）。ROADMAP.md §P2-ε はサマリで、本ファイルへリンクする。
> 関連: [P1-6 ChangePreview 共通化](../ROADMAP.md)（前提）/ [P2-α シフトパターン自動検出](p2-algorithms.md#1-p2-α--シフトパターン自動検出)（再利用）。

## 1. 目的

カレンダーで「日付を選ぶ → 1 日ずつプリセットを適用」する現行フロー
（[DayDetailEditorView.swift](../Sources/Features/Calendar/DayDetailEditorView.swift) は単日専用）を逆転し、

1. **プリセットを選んで複数日をまとめて塗り、一括適用**できるようにする。
2. 塗った日列が **周期パターンとして検出**できる場合、「ローテーションとして他の日付にも
   適用しますか？」をポップアップで提案し、既存の `RotationPattern` 機構へ載せる。

手作業の反復を減らし、シフトの月次入力コストを下げる。

## 2. 用語

| 用語 | 意味 |
|---|---|
| 一括編集モード | カレンダーで複数日を選択・塗布できる編集状態。 |
| アクティブプリセット | パレットで選択中のプリセット（塗布対象）。「休み(なし)」「消音」も選べる。 |
| 選択集合 | 一括編集モードで塗った日付の集合。プリセットが混在しうる。 |
| 適用 | 選択集合を `DayAssignment` として永続化する操作。`ChangePreview` 確定を経る。 |

## 3. 確定方針（ユーザー合意済み 2026-06-14）

- インタラクションは **「塗る → 一括適用（プレビュー確定型）」**。即時反映のペイント型は採らない。
- 検出パターンは **ローテ登録を主**とし、**選択範囲のみの一回展開も選べる**。

## 4. スコープ / 非スコープ

**スコープ**
- 一括編集モードのトグル、プリセットパレット、複数日選択 UI。
- 選択集合の一括 `DayAssignment` upsert（`ChangePreview` 確定経由）。
- 選択集合からの周期検出（`ShiftPatternDetector` 再利用）とローテ提案ポップアップ。
- ローテ受諾時の `RotationPattern` 生成（適用範囲＝無期限／指定範囲の選択つき）。

**非スコープ（本タスクでは扱わない）**
- DOW（曜日×週序）ルール検出（[P2-α A2](p2-algorithms.md#110-dow-検出) 側）。
- 画像インポートからの一括適用（P2-γ）。
- 新しい検出アルゴリズムの追加（既存 `ShiftPatternDetector` を再利用し、設定のみ調整）。

## 5. UX フロー（メイン導線）

1. [CalendarMonthView.swift](../Sources/Features/Calendar/CalendarMonthView.swift) のツールバーに
   **「一括編集」トグル**を追加。ON で一括編集モードに入る。
2. 上部に **プリセットパレット**（横スクロールのチップ：各 `ShiftPreset` ＋「休み(なし)」＋「消音」）。
   1 つをアクティブにする。
3. カレンダー上で日をタップ＝アクティブプリセットで「塗る」。アクティブを切り替えれば別プリセットで
   塗れる（選択集合にプリセットが混在＝パターンの素になる）。塗った日はプリセット色＋選択リングで表示。
4. 下部バーに「N 日を選択中」＋ **「適用」**。
5. 「適用」で **`ChangePreview`** を表示（追加 / 変更 / 競合 / 警告）。確定で `DayAssignment` を
   一括 upsert → `AlarmScheduler.refreshScheduledAlarms()` を **1 回だけ**呼ぶ。
6. 確定時（またはプレビュー内）に選択集合へ `ShiftPatternDetector` を実行。周期が見つかれば
   **パターン検出ポップアップ**を出す。
   - **ローテーションとして登録**: `RotationPattern` を生成（[P2-α](p2-algorithms.md) 受諾ロジック流用）。
     適用範囲を選択（無期限／今年いっぱい／開始・終了指定）。将来日へ自動反映。
   - **選択した N 日だけに適用**: ローテ化せず手動割り当てのみで終了。

## 6. インタラクション詳細

- **タップでトグル**を基本（最も確実）。補助として:
  - **範囲選択**: 開始日タップ → 終了日タップで連続選択。
  - **クイック選択**: 「今月の平日 / 土日 / 毎週○曜」。
- 選択中の日はアクティブプリセット色で即時プレビュー、2px 選択リング。
- 表示中の前後月のはみ出し日は **当面は当月＋表示週内に限定**（誤操作防止）。
- アクセシビリティ: 色のみに依存しない（VoiceOver で「N 日目、日勤、選択中」等を読む）。
  Dynamic Type XL でパレット・下部バーが崩れないこと（P1-2 a11y 基準）。

## 7. パターン検出 → ローテ展開

- 検出は [ShiftPatternDetector.swift](../Sources/Domain/Logic/ShiftPatternDetector.swift) を再利用。
  履歴向けの既定設定（windowDays=90 / minDensity=0.5）とは別に **選択専用の検出設定**を渡す:
  - 走査窓 = 選択範囲（連続部分）に限定。
  - 最低 2 周期分の観測を要求（既存 DoD と整合）。
  - 選択集合は密で意図的なため、`minMatchRate` はやや緩め（例 0.80）を初期値として要チューニング。
- **素直な代替（フォールバック）**: 選択範囲がちょうど 1 周期分（連続塗布）なら、その並びを
  そのままサイクルとして繰り返す簡易提案を併設（検出に頼らず確実）。
- 受諾時の `RotationPattern` 生成は [RotationListView.swift](../Sources/Features/Rotation/RotationListView.swift)
  の受諾ロジックと共通化（`anchorDate` 正規化・`priority` 採番・fingerprint スヌーズ）。
- **適用範囲指定**: ローテ登録時に `startDate` / `endDate` を選択（無期限／今年いっぱい／指定範囲）。
  無期限ローテの暴走を避ける。「選択した日だけ」を選んだ場合は `RotationPattern` を作らない。

## 8. データフロー / 解決ロジックへの影響

- 既存の解決優先順位 **手動 > 祝日 > ローテ**（[DayResolver.swift](../Sources/Domain/Logic/DayResolver.swift)）と整合。
  一括適用した日は **手動 `DayAssignment`** として残り、ローテは「他の日」を埋める層になる
  （P2-α が手動割り当てを検出の証跡として残す方針と一致）。
- 書き込みは単日エディタと同じ upsert を **バッチ化**するだけ。新規モデルは不要。
  - 「休み(なし)」= `preset = nil`。空レコードがローテを誤って抑止しないよう、既存の
    「全フィールド空なら行を作らない」ロジック（[DayDetailEditorView.swift](../Sources/Features/Calendar/DayDetailEditorView.swift) 保存部）に倣う。
  - 「消音」= `DayAssignment.skipAlarm = true`。
- `refreshScheduledAlarms()` は選択全体に対し **1 回**呼ぶ（N 回呼ばない）。

## 9. ChangePreview 連携（前提依存）

- AGENTS.md §6.1.2「Preview before mutation」原則により、**一括適用は必ず `ChangePreview` を経由**する。
- これは **P1-6 ChangePreview 共通化が前提**。`ChangeEntityKind` に `dayAssignment` / `rotationPattern`
  が想定済みで合致する。
- 段階対応: P1-6 未完なら **Phase 1 は暫定の確認シート**で代替し、P1-6 完了後に共通基盤へ載せ替える。

## 10. 対象ファイル

**新規**
- `Sources/Features/Calendar/BulkApplyToolbar.swift` — パレット＋下部アクションバー。
- `Sources/Features/Calendar/BulkApplyViewModel.swift` — 選択集合・アクティブプリセット状態、検出呼び出し。
- `Sources/Features/Calendar/BulkPatternSuggestionSheet.swift`（命名要調整）— 検出ポップアップ。
- `Tests/DomainTests/BulkApplyTests.swift` — バッチ upsert / 競合解決 / 検出連携。

**変更**
- `Sources/Features/Calendar/CalendarMonthView.swift` — モードトグル、複数選択状態、塗布表示。
- `Sources/Features/Calendar/CalendarMonthViewModel.swift` — `selectedDates: Set<Date>` 等の選択状態。
- `Sources/Features/Calendar/DayCellView.swift` — 選択リング表示の追加（プロパティ追加）。
- `Sources/Domain/Logic/ShiftPatternDetector.swift` — 選択専用 Configuration の追加（設定のみ、アルゴリズム不変）。
- `Sources/Features/Rotation/RotationListView.swift` — 受諾ロジックを共通関数として切り出し再利用。
- `Resources/Localizable.xcstrings` — ja / en の文言追加。

## 11. 段階的実装

- **Phase 1**: 一括編集モード＋パレット＋複数選択＋一括 upsert（検出なし）。`ChangePreview` は
  P1-6 or 暫定確認シートで対応。
- **Phase 2**: 選択集合からのパターン検出＋ローテ提案ポップアップ（P2-α 再利用、適用範囲指定込み）。
- **Phase 3**: 範囲選択・クイック選択などの選択補助。

## 12. テスト ID（実装時に Tests へ反映）

- BULK-U1 複数日に同一プリセットを一括 upsert できる。
- BULK-U2 複数プリセット混在の塗布を一括 upsert できる。
- BULK-U3 既存割り当てがある日は「変更／競合」として `ChangePreview` に出る。
- BULK-U4 「休み(なし)」塗布で空レコードを作らない（ローテ抑止が起きない）。
- BULK-U5 `refreshScheduledAlarms()` が選択全体で 1 回だけ呼ばれる。
- BULK-D1 選択集合（2 周期分）から正しい周期が検出される。
- BULK-D2 1 周期ぶんの連続塗布で「そのまま繰り返す」簡易提案が出る。
- BULK-D3 「ローテとして登録」で `RotationPattern` が生成され、将来日に反映される。
- BULK-D4 「選択した日だけ」で `RotationPattern` を作らない。
- BULK-D5 適用範囲（startDate/endDate）指定がローテに反映される。

## 13. DoD

- プリセットを選び、カレンダーで複数日を塗って一括適用できる。
- 既存割り当てとの競合が `ChangePreview` で確認でき、確定後に正しく反映される。
- 選択集合が周期を成すとき提案ポップアップが出る。
- 「ローテとして登録」で将来日に自動反映、「選択した日だけ」で手動割り当てのみ。
- Dynamic Type XL で崩れず、VoiceOver で選択状態・プリセット名が読める。
- `scripts/verify.sh` / `scripts/lint.sh check` が緑。

## 14. 既知の不確実性 / レビュー観点

- 選択専用検出の `minMatchRate` 初期値（0.80 案）は実データで要チューニング。
- 一括適用＋ローテ受諾を両方行うと、選択日は手動割り当てとローテの二重表現になる（手動が優先で
  動作は正しいが冗長）。受諾時に種日を残すか整理するかは要レビュー（既定: P2-α に倣い手動を残す）。
- 巨大選択（数百日）時の `ChangePreview` 表示・確定性能。
- `AlarmScheduler` / `ShiftPatternDetector` 改修時は Swift 6 strict concurrency の
  `Sendable` 警告が増えないこと（AGENTS.md §6.1.2）。
