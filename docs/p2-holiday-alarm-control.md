# P2-ζ. 祝日のアラーム制御（全体／個別）＋カレンダー可視化

> 状態: **未着手 / 設計確定（2026-06-14）**。本ファイルが仕様・DoD の正典（AGENTS.md §6.1.2）。
> 状態・進捗・優先度の正典は Linear（追跡: [DEV-201](https://linear.app/dolquis/issue/DEV-201)）。ROADMAP.md §P2-ζ はサマリで、本ファイルへリンクする。
> 関連: [P1-6 ChangePreview 共通化](../ROADMAP.md)（全体トグル波及時に利用）。
> **スキーマ変更を伴う。着手時は `/swiftdata-migration` skill を必ず起動**（App / Widget の
> ModelContainer 双方で同 schema を扱えることを確認）。

## 1. 目的

祝日に **アラームを鳴らす／鳴らさない**を、**全体一括**でも **個別の祝日ごと**でも選べるようにする。
祝日に関係なく働くワーカーがいるため。さらにカレンダー画面で **祝日と、その日に鳴るかどうか**を
一目で確認できるようにする。

## 2. 現状（出発点）

- [HolidayOverride.swift](../Sources/Domain/Models/HolidayOverride.swift)（`SchemaV2.HolidayOverride`）は
  `skipAlarm: Bool`（既定 true）＋ `replacementPreset?` を持つ。**個別の二値制御は実質存在**するが、
  「skip alarm」表現で「鳴らす？」として分かりにくい。
- **全体の既定設定が無い**（祝日も働く人は全祝日を 1 件ずつ off にする必要がある）。
- [DayCellView.swift](../Sources/Features/Calendar/DayCellView.swift) は祝日ラベルを出すが
  **鳴動可否インジケータが無い**。
- 祝日は **取り込み済みの `HolidayOverride` 行がある日**しか表示・反映されない
  （[HolidayProvider.swift](../Sources/Services/Holidays/HolidayProvider.swift) の同梱 JP 祝日 /
  [EventKitHolidayProvider.swift](../Sources/Services/Holidays/EventKitHolidayProvider.swift) は明示取り込み時のみ）。
- 解決ロジック [DayResolver.swift](../Sources/Domain/Logic/DayResolver.swift):
  優先順位 **手動 > 祝日 > ローテ**。祝日は `skipAlarm` で鳴動停止、`replacementPreset` で差し替え、
  それ以外は通常解決へフォールスルー。

## 3. 確定方針（ユーザー合意済み 2026-06-14）

- 既存 `skipAlarm=true` を **`inherit` に移行**し、**全体既定を `silence`** にする。
  → 現状の実効挙動は不変（inherit→silence）。祝日も働く人は **全体トグルを `ring` にするだけ**で全祝日が鳴る。
- 祝日の **表示は常時オーバーレイ**（取り込み不要で確認可）。**アラーム実効は「明示取り込み」または
  「先読み期間内の自動 materialize」**で担保する。

## 4. データモデル変更

### 4.1 列挙型（新規）
```swift
public enum HolidayAlarmBehavior: Int, Codable, Sendable {
    case inherit = 0   // 全体既定に従う（個別行のみ）
    case ring    = 1   // 鳴らす（replacementPreset があればその時刻、無ければ通常解決へ）
    case silence = 2   // 鳴らさない
}
```

### 4.2 `AppSettings`（[AppSettings.swift](../Sources/Domain/Models/AppSettings.swift) = `SchemaV2.AppSettings`）
- 追加: `holidayAlarmDefaultRaw: Int?`（nil = 未設定 → `silence` 扱い）。
- 算出: `effectiveHolidayAlarmDefault: HolidayAlarmBehavior`（**`ring` か `silence` の二値のみ**。`inherit` は
  個別行専用で、全体既定には第三状態を設けない — `inherit` は具体値へ解決される必要があるため。§8 の全体既定 UI も二択にする）。
- **device-local 設定**であり `.shiftalarm` バンドルには含めない
  （[ShareExporter.swift](../Sources/Services/Sharing/ShareExporter.swift) は `AppSettings` を export しない）。
  → import で他人の全体ポリシーを上書きしない。

### 4.3 `HolidayOverride`
- 追加: `alarmBehaviorRaw: Int?`（nil = 未移行 → backfill 対象）。算出 `alarmBehavior: HolidayAlarmBehavior`。
- `skipAlarm: Bool` は **当面残す**（`.shiftalarm` 後方互換・旧アプリ向け）。書き込み時に
  `alarmBehavior` から導出して同期（`silence`→true、`ring`/`inherit`→そのときの実効に応じて）。
- `replacementPreset` は据え置き（`ring` 時の差し替え時刻として継続利用）。

### 4.4 マイグレーション（**推奨 = 追加列 + 遅延 backfill**）
- **次版スキーマ（既定 SchemaV3）** を新設し、上記 2 列（`AppSettings.holidayAlarmDefaultRaw` /
  `HolidayOverride.alarmBehaviorRaw`）を **nullable 追加**（[SchemaV2.swift](../Sources/Domain/Persistence/SchemaV2.swift)
  に倣い [MigrationPlan.swift](../Sources/Domain/Persistence/MigrationPlan.swift) に `.lightweight` stage を追加）。
  - **版番号の調整（重要）**: ROADMAP §P2-β / §P2-γ も SchemaV2→**SchemaV3** の新設を予定している
    （ROADMAP.md L304 / L920 / L1008）。**先に着手したタスクが SchemaV3 を取り、後発は SchemaV4 以降**にする。
    本仕様の「V3」はプレースホルダで、実装着手時に次の未使用版番号へ解決する（複数のスキーマ追加を
    1 PR に束ねる場合は 1 版にまとめる）。
- **遅延 backfill**（初回起動 or コンテナ初期化時に 1 回）:
  - `HolidayOverride.alarmBehaviorRaw == nil` の行 → `skipAlarm ? .inherit : .ring`（方針 #3: true→inherit）。
  - `AppSettings.holidayAlarmDefaultRaw == nil` → `.silence`。
- **なぜ lightweight + backfill か**: 現行プランは V1→V2 を lightweight 1 段で運用。値変換を伴う
  破壊的 custom stage（`skipAlarm` 列の削除＋値再マップ）は SwiftData では壊れやすく、`.shiftalarm`
  の後方互換も失う。追加列＋backfill なら **既存挙動を保ったまま**段階移行でき、将来 `skipAlarm` を
  廃止するクリーンアップは別タスクに分離できる。
- 代替（非推奨）: SchemaV3 で `skipAlarm` を削除する custom migration stage。クリーンだが
  リスクが高く、`.shiftalarm` 互換のための別対応が必要。

### 4.5 共有フォーマット（`.shiftalarm`）後方互換
- [ShiftBundleCodec.swift](../Sources/Services/Sharing/ShiftBundleCodec.swift) の Override DTO（現行 `skipAlarm: Bool`）に
  `alarmBehavior: HolidayAlarmBehavior?` を **Codable default-nil で追加**（P2-α A2 の DTO 拡張方針に倣う）。
  - 旧 bundle: `alarmBehavior` 欠落 → `skipAlarm` から **`silence`/`ring`** に読み替え（`true→silence`、`false→ring`）。
    旧 `skipAlarm` は binary で三値概念を持たないため、**送信側の明示的な「鳴らさない」意図を保持**する目的で
    `true→silence`（明示）にマップする。**ローカル移行 backfill（§4.4）の `true→inherit` とは別経路・別マッピング**:
    backfill は当端末ユーザー自身の行を全体トグルに従わせるため `inherit`、import は他端末の明示選択を受信側の
    全体既定で勝手に反転させないため `silence`。これにより全体既定が `ring` の端末でも（または後で `ring` に変えても）、
    旧 bundle で明示 skip された祝日が誤って鳴ることはない。
  - 新 bundle: 両 field を往復。`ShiftBundleValidator` は `alarmBehavior` を **正規 field** として認識。
- export は両 field を書く（`skipAlarm` は実効から導出、旧アプリでも妥当に解釈される）。

## 5. 解決ロジック / スケジューラへの影響

- [DayResolverInputBuilder.swift](../Sources/Domain/Logic/DayResolverInputBuilder.swift):
  - `HolidayOverrideSnapshot` に `behavior: HolidayAlarmBehavior` を追加。
  - `DayResolverInput` に `holidayAlarmDefault: HolidayAlarmBehavior`（ring/silence）を追加。
- [DayResolver.swift](../Sources/Domain/Logic/DayResolver.swift) の祝日分岐:
  - `effective = behavior == .inherit ? input.holidayAlarmDefault : behavior`。
  - `effective == .silence` → `.holiday(skip: true)`（= 現 `skipAlarm==true` 経路）。
  - `effective == .ring` → `replacementPresetID` があればその時刻、無ければ **ローテ解決へフォールスルー**
    （= 現 `skipAlarm==false` 経路）。
- 優先順位 **手動 > 祝日 > ローテ** は不変。
- [AlarmScheduler.swift](../Sources/Services/AlarmKit/AlarmScheduler.swift) は変更最小（`DayResolver` 経由のため）。
  ただし下記 §6 の自動 materialize を入れる場合は refresh フローに materialize ステップを足す。

## 6. 祝日の表示と実効（方針 #4）

- **表示（常時オーバーレイ）**: [CalendarMonthView.swift](../Sources/Features/Calendar/CalendarMonthView.swift) で
  `HolidayProvider`（同梱 JP）＋ EventKit（認可時）の既知祝日を **表示レイヤとしてマージ**。
  `HolidayOverride` 行があればそれを優先（ラベル・behavior）。取り込み前でも祝日名を確認できる。
- **実効（鳴動可否）**: 2 経路のいずれか:
  - **(a) 明示取り込み**（Phase 1・低リスク）: 既存「祝日を取り込む」で `HolidayOverride` 行を作成して初めて
    アラームに効く。表示はオーバーレイ、効かせるには取り込み、と役割を分ける。
  - **(b) 自動 materialize**（Phase 2・推奨 UX）: 先読み期間（`AppSettings.lookaheadDays`、既定 30 ＋ buffer）内の
    既知祝日のうち **`HolidayOverride` 行が無い日**だけを `behavior=.inherit` で冪等生成。ユーザー作成行は
    上書きしない。これで全体トグルが取り込み操作なしに効く。
    - **件数懸念**: 生成は先読み窓に限定し小さく保つ（P2-α A2 の大量展開懸念と同様の配慮）。

## 7. カレンダー表示（鳴動インジケータ）

- [DayCellView.swift](../Sources/Features/Calendar/DayCellView.swift) に鳴動可否インジケータを追加。
  既に `alarmTime(=resolved.fireTime)` と `holidayLabel` を受け取っており、`holidayLabel != nil` のとき
  `fireTime` の有無で **🔔（鳴る）／🔕（鳴らない）**を出せる（プラミング最小）。
- **アクセシビリティ**: 色・アイコンのみに依存せず、VoiceOver ラベルに「海の日、アラーム鳴る／鳴らない」を含める。
- 祝日番号は日本式に赤系で表示（既存表示と整合）。

## 8. 設定 UI

- [HolidayManagerView.swift](../Sources/Features/Holidays/HolidayManagerView.swift) を拡張:
  - 先頭に **全体既定トグル（二択：通常どおり鳴らす／すべて鳴らさない）**。これは `inherit` 行が解決する具体値で、
    `holidayAlarmDefaultRaw` の `ring`/`silence` に対応（§4.2）。**全体既定に第三状態「個別」は設けない**
    （`inherit` は具体値へ解決される必要があり、設けると `inherit`＋`個別` の解決が未定義になるため）。
  - **「個別に設定」は独立した全体状態ではなく、常時表示される各祝日行の三値コントロール（既定／鳴らす／消音）で実現**する。
    `既定` は全体既定に従い、`鳴らす`/`消音` で行単位に上書きする。`既定` 行には全体既定の実効値を併記（例「既定：鳴る」）。
  - 初期モックアップの 3 択トグルは、モデル整合のため本仕様で **二択＋行単位上書き**に改める（Codex review 反映）。
- 文言は「skip alarm」中心から「この祝日にアラームを鳴らす？」へ明確化。
  `Resources/Localizable.xcstrings` に ja / en 両方を追加（片言語欠落で空表示にならないこと）。

## 9. 全体トグル変更時の ChangePreview

- 全体既定の変更は多数の祝日に波及するため、**`ChangePreview` で「N 件が 鳴る→鳴らない に変わる」を確認**させてから適用
  （AGENTS.md §6.1.2「Preview before mutation」）。P1-6 未完なら暫定確認ダイアログで代替。

## 10. 対象ファイル

**新規**
- `Sources/Domain/Models/HolidayAlarmBehavior.swift` — 列挙型。
- `Sources/Domain/Persistence/SchemaV3.swift` — V3 スキーマ。
- `Sources/Domain/Persistence/HolidayBehaviorBackfill.swift`（命名要調整）— 遅延 backfill。
- `Tests/DomainTests/HolidayAlarmResolveTests.swift` / `Tests/DomainTests/HolidayMigrationBackfillTests.swift`。

**変更**
- `Sources/Domain/Models/HolidayOverride.swift`（→ V3 へ。`alarmBehaviorRaw` 追加、`skipAlarm` 同期）。
- `Sources/Domain/Models/AppSettings.swift`（→ V3 へ。`holidayAlarmDefaultRaw` 追加）。
- `Sources/Domain/Persistence/SchemaV2.swift` 参照 / `MigrationPlan.swift`（V3 stage 追加）。
- `Sources/Domain/Logic/DayResolver.swift` / `DayResolverInputBuilder.swift`（behavior + 全体既定）。
- `Sources/Services/AlarmKit/AlarmScheduler.swift`（自動 materialize を入れる場合）。
- `Sources/Features/Calendar/CalendarMonthView.swift` / `DayCellView.swift`（オーバーレイ + 🔔/🔕）。
- `Sources/Features/Holidays/HolidayManagerView.swift`（全体トグル + 個別三値）。
- `Sources/Services/Sharing/ShiftBundleCodec.swift` / `ShareExporter.swift` / `ShareImporter.swift` /
  `ShiftBundleValidator.swift`（DTO 拡張・後方互換）。
- `Widget/`（同 schema 参照確認）。
- `Resources/Localizable.xcstrings`（ja / en）。

## 11. 段階的実装

- **Phase 1**: 個別三値化＋全体既定＋ SchemaV3 追加列 + backfill。`DayResolver`/Scheduler 反映。
  実効は **明示取り込み**経路 (6-a)。表示オーバーレイ＋🔔/🔕。
- **Phase 2**: 先読み窓の **自動 materialize** (6-b)。全体トグル変更の `ChangePreview` 連携。
- **Phase 3（別タスク化可）**: `skipAlarm` 廃止クリーンアップ／「同名祝日すべてに適用」等の利便機能。

## 12. テスト ID

- HOL-U1 `inherit` ＋ 全体 `silence` で鳴らない（＝移行後も現挙動）。
- HOL-U2 `inherit` ＋ 全体 `ring` で鳴る（祝日も働く人の 1 操作）。
- HOL-U3 個別 `silence` は全体 `ring` でも鳴らない。
- HOL-U4 個別 `ring` ＋ `replacementPreset` でその時刻に鳴る。
- HOL-U5 個別 `ring` ＋ replacement 無しはローテ解決へフォールスルー。
- HOL-U6 手動割り当ては祝日より優先（既存仕様維持）。
- HOL-M1 backfill: `skipAlarm=true`→`inherit`、`false`→`ring`。
- HOL-M2 backfill: `AppSettings` 既定が `silence` に設定される。
- HOL-S1 `.shiftalarm` 旧 bundle（`alarmBehavior` 欠落）の import が `skipAlarm` を **`true→silence` / `false→ring`** に
  読み替える（送信側の明示意図を保持。backfill の `true→inherit`〔HOL-M1〕とは別マッピングである点も検証）。
- HOL-S2 新 bundle で `alarmBehavior` が往復する。
- HOL-V1 カレンダーセルに祝日の 🔔/🔕 が `fireTime` と整合して出る（VoiceOver ラベル込み）。
- HOL-X1（Phase 2）先読み窓内の既知祝日が冪等 materialize され、ユーザー行を上書きしない。

## 13. DoD

- 全体既定（**鳴らす／鳴らさない の二択**）と、祝日ごとの三値（既定／鳴らす／消音）を設定できる（「個別運用」は行単位の上書きで実現）。
- 移行後も既存ユーザーの実効挙動が不変（祝日は既定で消音のまま）。全体を「鳴らす」にすると全祝日が鳴る。
- カレンダーで祝日と鳴動可否（🔔/🔕）が確認できる。
- `.shiftalarm` の旧／新 bundle が破綻なく往復する。
- `scripts/verify.sh` / `scripts/lint.sh check` 緑。スキーマ変更で `Sendable` 警告が増えない。

## 14. 既知の不確実性 / レビュー観点

- 過去にユーザーが **意図的に** `skipAlarm=true` にした個別祝日も backfill で `inherit` になり、後で全体を
  `ring` にすると鳴るようになる（現 schema に provenance が無いため手動 true と取り込み true を区別不可）。
  取り込みが大多数で、全体トグルが本機能の主目的のため **true→inherit を採用**（方針 #3）。要周知。
- 自動 materialize (6-b) の生成件数と冪等性（重複生成防止のキー設計）。
- `skipAlarm` を当面残すことによる二重表現。廃止時期は別タスクで管理。
