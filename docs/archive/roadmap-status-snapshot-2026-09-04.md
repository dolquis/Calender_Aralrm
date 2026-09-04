<!-- lint:allow-file heading-state,status,line-ref -->

# ROADMAP 状態スナップショット（2026-09-04 凍結）

2026-09-04 に `ROADMAP.md` から状態の記述を外した際、当時の記録をそのまま保全した
ものである。**更新しない。** 現在の状態は Linear（team `Dev` / project
**Shift Alarm / Calender_Aralrm**）を見ること。

保全した理由は、消した完了マーカーの一部が Linear に対応する記録を持たなかったため
である。照会した結果、`DEV-305`（P2-δ）と `DEV-257`（P2-β）は Linear に Done として
存在したが、見出しが参照していた `DEV-17` / `DEV-34` / `DEV-35` / `DEV-256` は
Linear に存在しなかった（同じ齟齬を DEV-781 が追跡している）。PR 番号で記録されて
いた完了（#7〜#22）も Linear 側には無く、下記の旧 §0 が唯一の一覧だった。

## 旧 §0（2026-06-09 時点の現状サマリ）

## 0. 現状サマリ（2026-06-09 時点）

- iOS 26+ / Swift 6 / SwiftUI + SwiftData / AlarmKit ベースのシフト勤務向けアラームアプリ。
- 主要レイヤー（Domain / Services / Features / Widget / Live Activity / Sharing / Deep link / ja-en ローカライズ）は実装済み。
- **P1 群（オンボーディング / a11y / 空状態 UX / Widget タイムライン）と P2-2（Bedtime reminder, Sleep schedule, HealthKit, App Intents）まで完了**。
- **P2-α（ShiftPatternDetector + RotationListView 提案カード）および P2-η（ICSExporter + ICSExportView）を実装済み（PR #19）**。
- **P0-5（`.shiftalarm` セマンティックバリデーション層）を実装済み**。decode 後 / preview
  前 / apply 前に `ShiftBundleValidator` を通し、重大 error は apply 不可、warning は preview
  に表示する。
- P0-1 は Xcode 26.5 / iOS 26.5 SDK でコードレベル検証に着手済み。
  `AlarmPresentation.Alert.stopButton` の iOS 26.1 deprecation を回避し、
  `AlarmManager.AlarmConfiguration.alarm(...)` に寄せた。実機確認は未完了。
- テストは Apple の Swift Testing（`@Test` / `#expect`）で記述。183 件 (27 スイート /
  27 ファイル) を定義し、通常の `scripts/verify.sh` では 8 件の snapshot test が
  `SNAPSHOT_TESTING_ENABLED=1` 未指定のため skip され、175 件が緑。
  CI は `macos-26` / Xcode 26+ で `scripts/verify.sh` を実行。
- **状態・進捗・優先度の正典は Linear**（team `Dev` / project **Shift Alarm /
  Calender_Aralrm**）。各項目の**詳細仕様・DoD は本 `ROADMAP.md` §P0-x が正典**で、
  Linear issue は要約＋本 doc へのリンクに留める。GitHub Issue はミラー（`Migrated`
  ラベル＋相互リンク）。運用ルールは `AGENTS.md` §6.1.1 / §6.1.2「Linear 運用（管制塔）」が
  唯一の正。
  現時点で登録済みの主な Linear issue（GitHub ミラー）:
  - **DEV-17**（GH #28）`.shiftalarm` セマンティックバリデーション層（P0-5 / 参照切れ
    preset によるアラーム沈黙バグ、実装済み）→ §P0-5
  - **DEV-18**（GH #29）AlarmKit/ActivityKit 実機検証 & Xcode 更新時 API 再確認（P0-1）→ §P0-1
  - **DEV-19**（GH #30）実 signing / entitlement 値の設定（P0-2）→ §P0-2
  - **DEV-20**（GH #31）ゴールデンパス手動検証（P0-3）→ §P0-3
  - **DEV-21**（GH #32）開発環境ハードニング backlog（P3-6〜P3-14 追跡）→ §5
  - **DEV-34** AlarmScheduler protocol / fake 化（P0-4）→ §P0-4
  - umbrella: **DEV-22**（P0 release readiness）/ 週次監査: **DEV-23**
- マージ済み主要 PR:
  - #1 初期スキャフォールド（救出は #5）/ #2 EventKit 祝日 / #3 DayEditor 状態漏れ修正
  - #5 PR #1 残差救出 / #6 Swift 6・CI 安定化
  - **#7 P1-1 オンボーディング + P1-3 空状態 UX + P3-1 テスト追加**
  - **#8 / #9 P1-2 アクセシビリティ監査**
  - **#10 P1-4 Widget マルチエントリ・タイムライン + Sleep schedule 初版（P2-2）**
  - **#11 Sleep / HealthKit / App Intents の P1/P2 レビュー反映**
  - **#12 ROADMAP / README の P1/P2-2 進捗反映**
  - **#13 DayResolverInputBuilder 抽出、DI seam、CI / テスト拡充**
  - **#14 P0-2 signing readiness ワークフロー (`scripts/p0-readiness.sh` / `scripts/p0-device-build.sh`)**
  - **#18 P2-α アルゴリズム仕様・テスト計画 + P2-δ / P2-η 提案書**
  - **#19 P2-α `ShiftPatternDetector` + `PatternSuggestionView` + `RotationListView`
    提案カード / P2-η `ICSExporter` + `ICSExportView` + `SettingsView` 導線**
  - **#20 プッシュ / PR 作成前のセルフレビュー方針を文書化**
  - **#21 ドキュメント整理（CLAUDE.md / AGENTS.md / ROADMAP / README の重複削除と SSoT 整理）**
  - **#22 swift-format 導入 + `scripts/lint.sh` + CI lint job**

未確定 / 既知の不安要素:

- AlarmKit / ActivityKit は Xcode 26.5 SDK では build / test 緑。今後の Xcode 26.x
  更新時は `Sources/Services/AlarmKit/AlarmConfigurationBuilder.swift` と
  `Sources/Services/LiveActivity/LiveActivityController.swift` を再確認する。
- AlarmKit エンタイトルメントは Apple Developer 申請が必要。ローカルには entitlement
  key、`NSAlarmKitUsageDescription`、`Config/LocalSigning.xcconfig` による実機向け
  signing override 導線は入っている。実 Team ID / bundle id / App Group の値は未設定。
- 実機 / 実 iOS 26 シミュレータでのゴールデンパス通し検証は未実施。
- P2 拡張案 A2 / A3 / A4 + P2-γ / P2-δ は未着手。P2-β は DEV-257 で実装中
  （SchemaV4 / `VacationAwareRotation` / `.shiftalarm` policy round-trip /
  migration・domain tests まで実装済み。HolidayManager からの連休登録 UI は未実装）。
- P2-ε（一括適用→パターン検出）/ P2-ζ（祝日アラーム制御）は **設計確定（2026-06-14）・実装未着手**
  （仕様: `docs/p2-bulk-preset-apply.md` / `docs/p2-holiday-alarm-control.md`）。
- A1 ドリフト検出アルゴリズム (`ShiftPatternDetector.detectDrift`) は実装済み。
  **UI 統合も `RotationListView` に実装済み**（`detectDriftOrPattern` で drift を検出し
  `PatternSuggestionView` の提案カードとして表示、snooze 判定 `isSuggestionVisible` 込み。
  2026-05-29 監査で確認）。専用の `PatternDriftSuggestionView.swift` は作らず既存カードに
  統合する形を採用。実機 / ビルドでの最終 UI 検証は Mac で要実施（§P1（追補）参照）。
- 第三者レビュー(2026-05-22)で挙がった開発環境ハードニング項目（依存固定 /
  AlarmScheduler テスト容易性 / `.shiftalarm` import バリデーション / 構造化
  ログ / CI ガードレール 等）は **§5 P3 配下 (P3-6 〜 P3-14) で追跡**する。

2026-05-27 仕様提案書取り込み（評価結果は本 ROADMAP / `docs/p2-algorithms.md`
に直接インライン化。元提案書は PR #27 のレビューで合意済みのものをドキュメント
側に集約しており、リポジトリ内に別ファイルとしては配置しない）:

- **P3-7 を §2 P0-4 へ昇格**: AlarmScheduler の protocol / fake 化を P0 に格上げ。
- **P3-9 を §2 P0-5 へ昇格**: `.shiftalarm` バリデーション層を P0 に格上げ。
- **§3 に P1-5 / P1-6 を新規追加**: アラーム診断画面 / ChangePreview 共通化。
- **§4 P2-α A1（ドリフト UI 統合）を P1 相当に昇格**: §3 P1 から前方参照。
- **§4 P2-α A2 / P2-β / P2-γ** に「実装精緻化（2026-05-27 追加）」サブ見出しを設け、
  データモデル形式・テスト ID・Phase 順序などの確定情報を追記。
- 取り込みアルゴリズム / 横断モデル詳細は `docs/p2-algorithms.md` に集約。
- 提案書 §6（近日アラーム）/ §11（仮眠）/ §12（統計）/ §13（家族共有 privacy）
  は 2026-05-27 時点で不採用。

## 旧 §8「次の 1 手」

## 8. 「次の 1 手」

**P2-α / P2-η は PR #19 でマージ済み。** 2026-05-27 仕様提案書取り込み後の優先順位:

1. **P0-3 実機ゴールデンパス**: `Config/LocalSigning.xcconfig` に実 Developer Team /
   bundle id / App Group を入れ、`bash scripts/p0-readiness.sh` を緑にしてから
   AlarmKit 認可ダイアログ・アラーム発火・Live Activity / Widget の通し確認。

2. **P0-4 AlarmScheduler protocol / fake 化**: `AlarmSchedulingClient` 導入、
   `AlarmService` を準拠、`AlarmScheduler` を protocol ベースに変更。
   `FakeAlarmSchedulingClient` で AS-U1〜U9 / AS-I1 を緑にする。

3. **P0-5 `.shiftalarm` バリデーション**: DEV-17 で実装済み。`ShiftBundleValidator`、
   `ShareImporter` の preview / apply 前段再検証、SBV-U1〜U14 / SBV-I1〜I2、
   ja / en メッセージ整備まで完了。

4. **A1 ドリフト検出 UI 統合（P1 相当）**: `ShiftPatternDetector.detectDrift()` は
   実装済みのため、`RotationListView` にドリフト検出カードを追加し、受入で旧
   pattern を `isActive = false` にする。`patternDriftSnoozedFingerprint` は
   `"v1:..."` プレフィックス付き。

5. **P1-5 アラーム診断画面**: DEV-35 で実装済み。`AlarmDiagnosticsService`、
   `AlarmDiagnosticsView`、`SettingsView` 導線、DIAG-U1〜U6 を追加。

6. **P1-6 ChangePreview 共通化**: Step 1（`ImportPreviewView` 抽出）→ Step 2
   （`ChangePreview` 抽象モデル導入）→ Step 3（画像 / ドリフト / DOW へ展開）。
   Step 1 は P0-5 と並走可能。

7. **P2-β 連休越境ローテーション**: `RotationExpander` の vacation-aware 拡張、
   `VacationPeriod` 独立 @Model 追加、SchemaV3→V4 lightweight マイグレーション
   （現行 active は SchemaV3）。Widget container 整合性確認。

8. **P2-γ 画像インポート Phase 1**: 手動グリッド + 記号マッピング UI を OCR 抜きで
   先行リリース。差分プレビューは P1-6 を経由。

**直近の開発環境ハードニング（P3 配下 / 機能追加と並行で進める想定）**:
P3-6 (`Package.resolved` 固定) → P3-8 (`AlarmScheduler` 構造化ログ、P0-4 完了後) →
P3-14a (`UIBackgroundModes` 整理) → P3-14b (`workflow_dispatch`) の順で、
小さな PR を継続的に出す。

## 見出しから外した状態マーカー

| 変更前 | 変更後 |
|---|---|
| `### P0-1. AlarmKit / ActivityKit シグネチャ再確認（着手中: SDK 26.5 コード対応済み / 実機確認待ち）` | `### P0-1. AlarmKit / ActivityKit シグネチャ再確認` |
| `### P0-2. AlarmKit エンタイトルメント取得 & プロビジョニング（着手中: ローカル設定導線追加済み）` | `### P0-2. AlarmKit エンタイトルメント取得 & プロビジョニング` |
| `### P0-3. ゴールデンパス手動検証（未着手: ローカル build/test のみ緑）` | `### P0-3. ゴールデンパス手動検証` |
| `### P0-4. AlarmScheduler を protocol / fake 注入可能にする（実装中: DEV-34）` | `### P0-4. AlarmScheduler を protocol / fake 注入可能にする` |
| `### P0-5. `.shiftalarm` バリデーション層 ✅ 実装済み (DEV-17)` | `### P0-5. `.shiftalarm` バリデーション層` |
| `### P1-1. オンボーディング ✅ 完了 (PR #7)` | `### P1-1. オンボーディング` |
| `### P1-2. アクセシビリティ監査 ✅ 完了 (PR #8 / #9)` | `### P1-2. アクセシビリティ監査` |
| `### P1-3. 空状態 / 認可拒否 UX を全画面で揃える ✅ 完了 (PR #7)` | `### P1-3. 空状態 / 認可拒否 UX を全画面で揃える` |
| `### P1-4. Live Activity / Widget タイムライン微調整 ✅ 完了 (PR #10)` | `### P1-4. Live Activity / Widget タイムライン微調整` |
| `### P1-5. アラーム診断画面（実装済み / DEV-35）` | `### P1-5. アラーム診断画面` |
| `### P1-6. ChangePreview 共通化（実装中 / DEV-256 / 2026-06-19 更新）` | `### P1-6. ChangePreview 共通化` |
| `### P2-α. シフトパターン自動検出 → プリセット / ローテ提案 ✅ コア実装済み (PR #19)` | `### P2-α. シフトパターン自動検出 → プリセット / ローテ提案` |
| `### P2-β. 長期連休を挟んだ昼夜シフト切替（実装中 / DEV-257）` | `### P2-β. 長期連休を挟んだ昼夜シフト切替` |
| `### P2-γ. シフト表画像の AI 解析 → カレンダー自動適用（未着手）` | `### P2-γ. シフト表画像の AI 解析 → カレンダー自動適用` |
| `### P2-δ. シフトスワップ — 代行 / 被代行のアラーム正当性 ✅ 実装済み (DEV-305)` | `### P2-δ. シフトスワップ — 代行 / 被代行のアラーム正当性` |
| `### P2-η. 家族共有用 .ics エクスポート ✅ 実装済み (PR #19)` | `### P2-η. 家族共有用 .ics エクスポート` |
| `### P2-ε. 日付一括選択 → プリセット一括適用 → パターン検出（未着手 / 設計確定 2026-06-14）` | `### P2-ε. 日付一括選択 → プリセット一括適用 → パターン検出（設計確定 2026-06-14）` |
| `### P2-ζ. 祝日のアラーム制御（全体／個別）＋カレンダー可視化（未着手 / 設計確定 2026-06-14）` | `### P2-ζ. 祝日のアラーム制御（全体／個別）＋カレンダー可視化（設計確定 2026-06-14）` |
| `### P3-1. テスト拡充 ✅ 完了 (PR #7 / #10 / #11)` | `### P3-1. テスト拡充` |
| `### P3-2. UI / スナップショットテスト（一部着手）` | `### P3-2. UI / スナップショットテスト` |
| `### P3-3. TestFlight 自動配布（未着手）` | `### P3-3. TestFlight 自動配布` |
| `### P3-4. クラッシュ / ログ収集（未着手）` | `### P3-4. クラッシュ / ログ収集` |
| `### P3-5. Swift Testing 移行（✅ 完了 — 既に Swift Testing 採用済み）` | `### P3-5. Swift Testing 移行` |
| `### P3-6. 依存バージョン固定（`Package.resolved` 追跡）（未着手）` | `### P3-6. 依存バージョン固定（`Package.resolved` 追跡）` |
| `### P3-8. AlarmScheduler 構造化ログ（未着手）` | `### P3-8. AlarmScheduler 構造化ログ` |
| `### P3-10. `.shiftalarm` / `.ics` ラウンドトリップ & 境界プロパティテスト（未着手）` | `### P3-10. `.shiftalarm` / `.ics` ラウンドトリップ & 境界プロパティテスト` |
| `### P3-11. SwiftData スキーマ変更ガード（CI 軽量チェック）（未着手）` | `### P3-11. SwiftData スキーマ変更ガード（CI 軽量チェック）` |
| `### P3-12. Localizable.xcstrings ja / en 整合チェック（未着手）` | `### P3-12. Localizable.xcstrings ja / en 整合チェック` |
| `### P3-13. Release ビルドでの設定 fallback 厳格化（未着手）` | `### P3-13. Release ビルドでの設定 fallback 厳格化` |
| `### P3-14. CI / 開発環境衛生（未着手 / サブ項目あり）` | `### P3-14. CI / 開発環境衛生（サブ項目あり）` |
| `### P3-15. DOW ルール用 `RuleExpandedOverride` 専用テーブル（未着手 / 2026-05-27 追加）` | `### P3-15. DOW ルール用 `RuleExpandedOverride` 専用テーブル（2026-05-27 追加）` |
| `### P2-2. Bedtime reminder（T-N 分前のプレアラーム）✅ 完了 (PR #10 / #11)` | `### P2-2. Bedtime reminder（T-N 分前のプレアラーム）` |
