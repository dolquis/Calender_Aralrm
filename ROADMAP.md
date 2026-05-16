# Calender_Aralrm 開発ロードマップ

このファイルは Claude Code / OpenAI Codex / その他エージェントが参照するための
**開発仕様兼ロードマップ**です。タスクは優先度（P0 → P3）順、各項目に
**目的 / 対象ファイル / 完了条件 (DoD)** を明記しています。

最終更新: 2026-05-15
対象ブランチ運用: タスクごとに `feature/<topic>` を切り、main へ PR。

---

## 0. 現状サマリ（2026-05-15 時点）

- iOS 26+ / Swift 6 / SwiftUI + SwiftData / AlarmKit ベースのシフト勤務向けアラームアプリ。
- 主要レイヤー（Domain / Services / Features / Widget / Live Activity / Sharing / Deep link / ja-en ローカライズ）は実装済み。
- **P1 群（オンボーディング / a11y / 空状態 UX / Widget タイムライン）と P2-2（Bedtime reminder, Sleep schedule, HealthKit, App Intents）まで完了**。
- P0-1 は Xcode 26.5 / iOS 26.5 SDK でコードレベル検証に着手済み。
  `AlarmPresentation.Alert.stopButton` の iOS 26.1 deprecation を回避し、
  `AlarmManager.AlarmConfiguration.alarm(...)` に寄せた。実機確認は未完了。
- テスト 56 件 (13 ファイル + snapshot support) 緑。通常の `scripts/verify.sh` では
  5 件の snapshot test は `SNAPSHOT_TESTING_ENABLED=1` 未指定のため skip。
  CI は `macos-26` / Xcode 26+ で `scripts/verify.sh` を実行。
- オープン Issue / オープン PR は 0。
- マージ済み主要 PR:
  - #1 初期スキャフォールド（救出は #5）/ #2 EventKit 祝日 / #3 DayEditor 状態漏れ修正
  - #5 PR #1 残差救出 / #6 Swift 6・CI 安定化
  - **#7 P1-1 オンボーディング + P1-3 空状態 UX + P3-1 テスト追加**
  - **#8 / #9 P1-2 アクセシビリティ監査**
  - **#10 P1-4 Widget マルチエントリ・タイムライン + Sleep schedule 初版（P2-2）**
  - **#11 Sleep / HealthKit / App Intents の P1/P2 レビュー反映**
  - **#12 ROADMAP / README の P1/P2-2 進捗反映**
  - **#13 DayResolverInputBuilder 抽出、DI seam、CI / テスト拡充**

未確定 / 既知の不安要素:

- AlarmKit / ActivityKit は Xcode 26.5 SDK では build / test 緑。今後の Xcode 26.x
  更新時は `Sources/Services/AlarmKit/AlarmConfigurationBuilder.swift` と
  `Sources/Services/LiveActivity/LiveActivityController.swift` を再確認する。
- AlarmKit エンタイトルメントは Apple Developer 申請が必要。ローカルには entitlement
  key、`NSAlarmKitUsageDescription`、`Config/LocalSigning.xcconfig` による実機向け
  signing override 導線は入っている。実 Team ID / bundle id / App Group の値は未設定。
- 実機 / 実 iOS 26 シミュレータでのゴールデンパス通し検証は未実施。

---

## 1. フェーズ全体像

| フェーズ | テーマ | ゲート（次フェーズへの条件） |
|---|---|---|
| **P0** | リリース前検証 | 実機/実シミュレータでゴールデンパス完走 |
| **P1** | UX 完成度 | アクセシビリティ監査 / 空・エラー UX 揃え / オンボーディング |
| **P2** | README ロードマップ実装 | iCloud / Bedtime / Watch のいずれか 1 つを TestFlight 配布 |
| **P3** | 品質・運用 | TestFlight 自動配布 + UI/統合テスト緑 |

---

## 2. P0 — リリース前検証（コードを増やす前にやる）

> ステータス: **P0-1 はコードレベル着手済み、P0-2 は設定導線実装済み / 実 Developer Portal 値待ち、P0-3 は実機待ち**。

### P0-1. AlarmKit / ActivityKit シグネチャ再確認（着手中: SDK 26.5 コード対応済み / 実機確認待ち）

- **目的**: iOS 26 SDK 最終版の AlarmKit / ActivityKit API と現コードの差分を解消する。
- **対象ファイル**:
  - `Sources/Services/AlarmKit/AlarmConfigurationBuilder.swift` (63 行)
  - `Sources/Services/AlarmKit/AlarmService.swift` (90 行)
  - `Sources/Services/AlarmKit/AlarmScheduler.swift` (213 行)
  - `Sources/Services/AlarmKit/AlarmAuthorization.swift` (31 行)
  - `Sources/Services/LiveActivity/LiveActivityController.swift` (100 行)
  - `Sources/Services/LiveActivity/ShiftAlarmAttributes.swift` (42 行)
- **2026-05-15 実施済み**:
  - Xcode 26.5 (17F42) / iOS 26.5 Simulator SDK で `bash scripts/verify.sh` 緑。
  - `AlarmManager.schedule(id:configuration:)`, `cancel(id:)`,
    `requestAuthorization()` は現行実装と一致。
  - `AlarmPresentation.Alert.stopButton` は iOS 26.1 以降 deprecated / 未使用のため、
    iOS 26.1+ では stopButton なし initializer、iOS 26.0 では legacy initializer を使う
    availability 分岐に更新。
  - `AlarmManager.AlarmConfiguration.alarm(schedule:attributes:stopIntent:secondaryIntent:sound:)`
    が存在するため、通常アラーム用途として builder から明示的に使用。
  - ActivityKit は `Activity.request(attributes:content:pushType:)`,
    `activity.update(_:)`, `activity.end(_:dismissalPolicy:)` が現行実装と一致。
- **手順**:
  1. Xcode 26.x 更新ごとに `bash scripts/verify.sh` を実行し、AlarmKit / ActivityKit 関連の
     ビルドエラー・Deprecation を列挙。
  2. Apple Developer Documentation と SDK の `.swiftinterface` を突き合わせ、
     - `AlarmManager` API（schedule / cancel / authorization）
     - `AlarmConfiguration` / `AlarmPresentation` / `AlarmAttributes`
     - `Activity` 起動・更新・終了
     の差分を洗い出す。
  3. `#if canImport(AlarmKit)` のフォールバックは維持し、最小差分で修正。
- **DoD**:
  - `scripts/verify.sh` がローカル / CI ともに緑。
  - AlarmKit 認可ダイアログが実機で表示される。
  - Live Activity が Dynamic Island に表示される。

### P0-2. AlarmKit エンタイトルメント取得 & プロビジョニング（着手中: ローカル設定導線追加済み）

- **対象**: `Config/SigningDefaults.xcconfig`, `Config/LocalSigning.xcconfig.example`,
  `project.yml`, `App/ShiftAlarm.entitlements`, `Widget/ShiftAlarmWidget.entitlements`,
  App Group.
- **ローカル確認済み**:
  - `App/ShiftAlarm.entitlements` に App Group / AlarmKit / HealthKit key あり。
  - `Widget/ShiftAlarmWidget.entitlements` に App Group key あり。
  - `App/Info.plist` に `NSAlarmKitUsageDescription` あり。
  - App / Widget の App Group、BGTask identifier、URL type、UTI、bundle id は
    `Config/SigningDefaults.xcconfig` 経由の build setting に集約済み。
  - `Config/LocalSigning.xcconfig.example` をコピーして実値を入れる運用に変更済み。
    `Config/LocalSigning.xcconfig` は git ignore。
  - runtime の App Group / BGTask identifier は Info.plist から取得するため、
    local override と実行時値がずれない。
  - `bash scripts/p0-readiness.sh` で実 Team ID / bundle id / App Group / entitlement
    の readiness を検査できる。
  - `bash scripts/p0-device-build.sh` で readiness 検査後に `generic/platform=iOS`
    向け build へ進める。
- **実機前に必要**:
  - `Config/LocalSigning.xcconfig.example` を `Config/LocalSigning.xcconfig` にコピー。
  - `DEVELOPMENT_TEAM`, `SHIFTALARM_APP_BUNDLE_ID`, `SHIFTALARM_WIDGET_BUNDLE_ID`,
    `SHIFTALARM_TESTS_BUNDLE_ID`, `SHIFTALARM_APP_GROUP_ID`,
    `SHIFTALARM_BG_REFRESH_TASK_ID`, `SHIFTALARM_URL_TYPE_NAME`,
    `SHIFTALARM_BUNDLE_UTI` を実 Apple Developer Portal 上の値に差し替える。
  - `bash scripts/regen.sh` 後、`bash scripts/p0-readiness.sh` が緑になることを確認。
  - `bash scripts/p0-device-build.sh` で実機向け build が通ることを確認。
- **DoD**:
  - 実 Apple ID / Developer Team で署名済みビルドが実機にインストールできる。
  - 実 App Group が App と Widget の両方で共有されている。

### P0-3. ゴールデンパス手動検証（未着手: ローカル build/test のみ緑）

- **シナリオ**: README §"Testing manually" の 1〜8 を実機で完走。
- **追加で確認**:
  - シミュレータ時計を進めたとき、AlarmKit が **silent / focus を貫通**するか。
  - 祝日インポート（JSON / EventKit 両方）で日付が 1 日もズレないか
    （PR #5 で対応した `CalendarDay` 安定化の回帰テスト）。
  - Deep link `shiftalarm://import?payload=...` で ImportView が開き、差分プレビューが出るか。
- **DoD**: 上記すべて OK のチェックリストを Issue に貼り closed。

---

## 3. P1 — UX 完成度

> ステータス: **すべて完了**（PR #7 / #8 / #9 / #10）。以下は履歴として残す。

### P1-1. オンボーディング ✅ 完了 (PR #7)

- **目的**: 初回起動で AlarmKit 認可 → サンプルプリセット作成 → ローテ作成までの導線。
- **対象**:
  - 新規: `Sources/Features/Onboarding/OnboardingView.swift`
  - 改修: `App/ShiftAlarmApp.swift`, `Sources/Features/RootTabView.swift`,
    `App/AppDependencies.swift`（初回フラグを `AppSettings` に追加）
- **DoD**:
  - 新規インストールから 3 タップ以内に最初のアラームを鳴らせる。
  - 2 回目以降は表示されない。

### P1-2. アクセシビリティ監査 ✅ 完了 (PR #8 / #9)

- **目的**: VoiceOver / Dynamic Type / コントラスト対応。
- **対象**: 全 `Sources/Features/**/*.swift`、特に
  - `Sources/Features/Calendar/DayCellView.swift`
  - `Sources/Features/Presets/PresetEditorView.swift`（色プリセット）
  - `Widget/NextAlarmWidgetView.swift`, `Widget/DynamicIslandViews.swift`
- **DoD**:
  - すべての主要画面で VoiceOver の読み上げが意味のある順序で取れる。
  - Dynamic Type の XXL でレイアウトが崩れない。
  - プリセット色は WCAG AA 相当のコントラストガードを実装（`Color+Hex` に拡張）。

### P1-3. 空状態 / 認可拒否 UX を全画面で揃える ✅ 完了 (PR #7)

- **現状**: 祝日（EventKit）は拒否時に Settings 誘導済み（PR #2）。
- **未対応**: AlarmKit 認可拒否時 / カレンダー初期空状態 / ローテゼロ件 / プリセットゼロ件。
- **対象**:
  - `Sources/Features/Settings/PermissionStatusView.swift`
  - `Sources/Features/Calendar/CalendarMonthView.swift`
  - `Sources/Features/Rotation/RotationListView.swift`
  - `Sources/Features/Presets/PresetListView.swift`
- **DoD**:
  - 拒否状態でも crash せず、「設定を開く」CTA がある。
  - 空状態は意味のあるイラスト or 説明 + 最初のアクションへの導線がある。

### P1-4. Live Activity / Widget タイムライン微調整 ✅ 完了 (PR #10)

実装ノート:
- `Widget/NextAlarmTimelineProvider.swift` は最大 8 件の今後のアラームを多段
  エントリ化し、T-2h チェックポイントと発火後 60 秒で次アラームに切り替える。
- `Sources/Services/LiveActivity/LiveActivityController.swift` は
  `AppSettings.liveActivityLeadHours`（既定 8h）で表示開始タイミングを設定可能。
- Bedtime リマインダは Widget の next-wake 選定から除外（PR #11 で修正）。

- **対象**:
  - `Sources/Services/LiveActivity/LiveActivityController.swift`（表示開始 T-N の設定 UI）
  - `Widget/NextAlarmTimelineProvider.swift`
  - `Sources/Domain/Models/AppSettings.swift`（既存 lookahead と合わせて Live Activity プレ時間を保持）
- **DoD**:
  - Settings から Live Activity 表示開始時間を変更でき、即時反映。
  - Widget のタイムラインが次のアラームに近づくにつれて自然に更新される。

---

## 4. P2 — README ロードマップ実装

### P2-1. iCloud 同期（CloudKit）（未着手）

- **目的**: `ModelConfiguration(cloudKitDatabase:)` で SwiftData を CloudKit と同期。
- **対象**:
  - `Sources/Domain/Persistence/ModelContainer+Shared.swift`
  - `Sources/Domain/Persistence/SchemaV1.swift`
  - `App/ShiftAlarm.entitlements`（iCloud, CloudKit, App Group）
  - `project.yml`
- **設計メモ**:
  - Widget は App Group の local store を読むので、CloudKit ↔ local の同期境界は
    App ターゲットに閉じる。Widget は **読み取り専用** を維持する。
  - 競合解決は SwiftData の組込みポリシーをまず採用、不足があれば最終更新優先で上書き。
- **DoD**:
  - 2 端末で 1 つの iCloud アカウントにサインインし、プリセット / ローテ / 割当が双方向同期される。
  - Widget が壊れない。

### P2-2. Bedtime reminder（T-N 分前のプレアラーム）✅ 完了 (PR #10 / #11)

**当初想定スコープを超え、Sleep schedule / HealthKit / App Intents まで実装済み**。

- 目的（達成）: 起床時刻から逆算して bedtime と T-N 分前のリマインダを生成。
- 主要実装:
  - `Sources/Domain/Models/ShiftPreset.swift` — `targetSleepDuration`（既定 8h）、
    `bedtimeLeadMinutes`（既定 30 分）。
  - `Sources/Domain/Logic/SleepWindowResolver.swift` — bedtime / リマインダ時刻計算。
  - `Sources/Services/AlarmKit/AlarmScheduler.swift` — `(date, kind)` を鍵に
    `.main | .bedtime` を diff-sync 登録。
  - `Sources/Features/SleepSchedule/SleepScheduleView.swift` — 今後の睡眠ウィンドウ
    一覧 + HealthKit 認可 + Shortcuts ガイド。
  - `Sources/Services/HealthKit/SleepSampleWriter.swift` — HealthKit 睡眠サンプル書込み。
  - `Sources/Services/AppIntents/` — `GetSleepWindowIntent` ほか Shortcuts 公開。
- テスト: `Tests/DomainTests/SleepWindowResolverTests.swift`。

### P2-3. Apple Watch コンパニオン（未着手）

- **目的**: 時計アプリ風の独立ウォッチアプリで「今日 / 明日のアラーム」を表示。
- **前提作業**:
  - `Sources/Domain` を独立した Swift package / static framework に切り出し、
    Watch ターゲットからも参照可能にする（現状は App ターゲット内）。
- **対象**:
  - `project.yml` に WatchApp ターゲット追加
  - 新規: `Watch/` ディレクトリ
- **DoD**:
  - Watch 単独で次のアラームが見える。
  - iPhone と Watch で SwiftData / CloudKit を共有（P2-1 完了後が望ましい）。

---

## 5. P3 — 品質・運用

### P3-1. テスト拡充 ✅ 完了 (PR #7 / #10 / #11)

- 追加済み:
  - `Tests/DomainTests/DayResolverInputBuilderTests.swift` — SwiftData から resolver input への変換。
  - `Tests/ServicesTests/ShareImporterTests.swift` — 差分プレビューと apply。
  - `Tests/ServicesTests/DeepLinkRouterTests.swift` — URL → import flow。
  - `Tests/ServicesTests/BGRefreshControllerTests.swift` — refresh task request / submit seam。
  - `Tests/ServicesTests/SleepIntentHelperTests.swift` — App Intents 用 sleep window 取得。
  - `Tests/ServicesTests/SleepSampleWriterTests.swift` — HealthKit 書込み対象 window 抽出。
  - `Tests/DomainTests/SleepWindowResolverTests.swift` — bedtime 計算 / 端境ケース。
- 現状: 13 ファイル / 56 テスト緑（うち 5 件 snapshot は通常 verify では skip）。

### P3-2. UI / スナップショットテスト（一部着手）

- 対象: `Tests/UITests/`（新規ターゲット）
- 主要画面の light/dark / Dynamic Type 3 サイズ × ja/en のスナップショット。
- 進捗: `Tests/SnapshotTests/DayCellViewSnapshotTests.swift` で DayCell の light / dark /
  祝日 / out-of-month / Dynamic Type XL を追加済み。通常 verify では skip し、
  `SNAPSHOT_TESTING_ENABLED=1` で記録 / 検証する。
- **DoD**: スナップショット差分が CI で検出される。

### P3-3. TestFlight 自動配布（未着手）

- 対象: `.github/workflows/release.yml`（新規）
- タグ `v*` プッシュで Archive → App Store Connect API → TestFlight。
- **DoD**: タグ 1 個で TestFlight に届く。

### P3-4. クラッシュ / ログ収集（未着手）

- 軽量に: `os.Logger` のサブシステム整理 + MetricKit 取り込み。
- 外部 SDK は避ける（プライバシー / AlarmKit のバックグラウンド要件のため）。

---

## 6. ファイル別「触るときの注意」（エージェント向け索引）

| パス | 何が入っているか | 触る際の注意 |
|---|---|---|
| `Sources/Services/AlarmKit/AlarmScheduler.swift` | expected set との diff-sync 本体 | キャンセル漏れに注意。テストは `AlarmSchedulerTests.swift` |
| `Sources/Domain/Logic/DayResolver.swift` | 優先度: 手動 > 祝日 > ローテ > なし | PR #5 で削除済み preset のフォールバックを復元済み |
| `Sources/Domain/Logic/RotationExpander.swift` | アンカー基準の周期展開（負オフセット可） | 不正な cycle/slot 数はスキップ |
| `Sources/Services/Sharing/ShiftBundleCodec.swift` | `.shiftalarm` JSON | 日付は `CalendarDay`（PR #5）。legacy `exportedAt` 文字列受け入れ済み |
| `Sources/Services/Holidays/EventKitHolidayProvider.swift` | actor、終日イベント取得 | `NSCalendarsFullAccessUsageDescription` 必須 |
| `App/AppDependencies.swift` | DI ハブ / pendingImport / settings singleton | PR #5 で `ensureSettingsSingleton()` 復元 |
| `Sources/Shared/URLScheme/DeepLinkRouter.swift` | `shiftalarm://import?payload=…` | `AppDependencies.pendingImport` 経由で ImportView を表示 |
| `Widget/NextAlarmTimelineProvider.swift` | Widget タイムライン（マルチエントリ） | App Group SwiftData を **読み取りのみ**。bedtime リマインダは next-wake 選定から除外 |
| `Sources/Domain/Logic/SleepWindowResolver.swift` | 起床時刻から bedtime / リマインダ時刻を逆算 | `(date, kind)` 鍵分離を維持。テストは `SleepWindowResolverTests.swift` |
| `Sources/Services/HealthKit/SleepSampleWriter.swift` | HealthKit 睡眠サンプル書込み | エンタイトルメントは `App/ShiftAlarm.entitlements`。実機/シミュレータ認可必須 |
| `Sources/Services/AppIntents/` | `GetSleepWindowIntent` ほか Shortcuts 公開エントリ | Intent パラメータ追加時は `SleepWindowEntity` の互換も確認 |
| `Sources/Features/Onboarding/OnboardingView.swift` | 初回起動オンボーディング (AlarmKit 認可 + サンプル投入) | `AppSettings` のフラグで 2 回目以降抑止 |
| `project.yml` | XcodeGen 唯一の真実 | 変更後は `bash scripts/regen.sh` |
| `scripts/verify.sh` | regen → simulator 選択 → build/test | CI と同じ。デバッグは `DESTINATION=…` で固定可 |

---

## 7. ブランチ / PR 運用ルール（エージェント共通）

1. `main` に直接 push しない。`feature/<topic>` または `fix/<topic>` を切る。
2. PR は **draft で作成**。CI（`scripts/verify.sh`）が緑になってから ready for review。
3. `.xcodeproj` は commit 対象（XcodeGen で再生成されても）。
4. AlarmKit / ActivityKit の API 変更を伴う PR は、変更箇所を
   `AlarmConfigurationBuilder.swift` と `LiveActivityController.swift` に局所化する。
5. Domain model に **non-optional プロパティ追加** をする場合は
   `SchemaV1.swift` のマイグレーション影響を必ず記載する。
6. ローカライズ文字列を追加したら `Resources/Localizable.xcstrings` の **ja / en 両方** を埋める。

---

## 8. 「次の 1 手」

**次は `Config/LocalSigning.xcconfig` に実 Developer Team / bundle id / App Group を入れ、
`bash scripts/p0-readiness.sh` を緑にしてから P0-3 golden path を実機で完走する。**
P0-1 のコードレベル確認と P0-2 のローカル設定導線はできたため、残りのリリース前ゲートは
実機での AlarmKit 認可ダイアログ、AlarmKit alert、Live Activity / Dynamic Island、
Widget、共有 import/export の通し確認。
