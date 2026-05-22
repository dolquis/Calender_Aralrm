# Calender_Aralrm 開発ロードマップ

このファイルは Claude Code / OpenAI Codex / その他エージェントが参照するための
**開発仕様兼ロードマップ**です。タスクは優先度（P0 → P3）順、各項目に
**目的 / 対象ファイル / 完了条件 (DoD)** を明記しています。

最終更新: 2026-05-21
対象ブランチ運用: タスクごとに `feature/<topic>` を切り、main へ PR。

---

## 0. 現状サマリ（2026-05-21 時点）

- iOS 26+ / Swift 6 / SwiftUI + SwiftData / AlarmKit ベースのシフト勤務向けアラームアプリ。
- 主要レイヤー（Domain / Services / Features / Widget / Live Activity / Sharing / Deep link / ja-en ローカライズ）は実装済み。
- **P1 群（オンボーディング / a11y / 空状態 UX / Widget タイムライン）と P2-2（Bedtime reminder, Sleep schedule, HealthKit, App Intents）まで完了**。
- **P2-α（ShiftPatternDetector + RotationListView 提案カード）および P2-η（ICSExporter + ICSExportView）を実装済み（PR #19）**。
- P0-1 は Xcode 26.5 / iOS 26.5 SDK でコードレベル検証に着手済み。
  `AlarmPresentation.Alert.stopButton` の iOS 26.1 deprecation を回避し、
  `AlarmManager.AlarmConfiguration.alarm(...)` に寄せた。実機確認は未完了。
- テスト 85 件 (16 テストクラス) 緑。通常の `scripts/verify.sh` では
  5 件の snapshot test は `SNAPSHOT_TESTING_ENABLED=1` 未指定のため skip。
  CI は `macos-26` / Xcode 26+ で `scripts/verify.sh` を実行。
- オープン Issue / PR は 0。
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

未確定 / 既知の不安要素:

- AlarmKit / ActivityKit は Xcode 26.5 SDK では build / test 緑。今後の Xcode 26.x
  更新時は `Sources/Services/AlarmKit/AlarmConfigurationBuilder.swift` と
  `Sources/Services/LiveActivity/LiveActivityController.swift` を再確認する。
- AlarmKit エンタイトルメントは Apple Developer 申請が必要。ローカルには entitlement
  key、`NSAlarmKitUsageDescription`、`Config/LocalSigning.xcconfig` による実機向け
  signing override 導線は入っている。実 Team ID / bundle id / App Group の値は未設定。
- 実機 / 実 iOS 26 シミュレータでのゴールデンパス通し検証は未実施。
- P2 拡張案 A2 / A3 / A4 + P2-β / P2-γ / P2-δ は未着手。
- A1 ドリフト検出アルゴリズム (`ShiftPatternDetector.detectDrift`) は実装済み、
  `RotationListView` への UI 統合は未着手。

---

## 1. フェーズ全体像

| フェーズ | テーマ | ゲート（次フェーズへの条件） |
|---|---|---|
| **P0** | リリース前検証 | 実機/実シミュレータでゴールデンパス完走 |
| **P1** | UX 完成度 | アクセシビリティ監査 / 空・エラー UX 揃え / オンボーディング |
| **P2** | 新機能拡張（シフト体験の自動化） | Bedtime + Sleep schedule を TestFlight 配布、画像解析 / パターン検出 / 連休越境のいずれかを着手 |
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

## 4. P2 — 新機能拡張（シフト体験の自動化）

> **スコープ外（不採用）**: iCloud 同期 (CloudKit) / Apple Watch コンパニオン。
> 過去 ROADMAP の旧 P2-1 / P2-3 は方針として削除した。

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

### P2-α. シフトパターン自動検出 → プリセット / ローテ提案 ✅ コア実装済み (PR #19)

> アルゴリズム詳細: [docs/p2-algorithms.md §1](docs/p2-algorithms.md#1-p2-α--シフトパターン自動検出)

- **目的**: ユーザが手動で日付ごとに割り当てているアラーム履歴から **周期性を検出** し、
  「これローテとして登録しませんか？」と提案する。手作業の反復を吸収しオンボーディング
  後のリテンションを上げる。
- **検出すべき例**:
  1. **単純周期**: 1 週間ごとに「夜勤週」「昼勤週」が交互。
  2. **複雑周期**: 月火（昼）水木（休）金土（夜）月火（休）水木金土（昼）月火水木（昼）…
     のような **多週周期**。
- **アプローチ**:
  - 直近 N 日（既定 90 日）の `DayAssignment` から `(date, presetID|.off|wildcard)` の列を抽出。
    **手動割当の無い日は wildcard** として一致率算定の分母から除外する。
  - 候補周期長 2〜35 日を総当たりし、スロットごとの最頻値マッチ率で best fit を選ぶ。
  - スロット観測密度 ≥ 0.5（既定）を別途要求し、スパース履歴での過学習を防ぐ。
  - 一致率 ≥ しきい値（既定 0.85）かつ最低 2 周期分の観測がある場合のみ提案する。
- **対象ファイル**:
  - 新規 `Sources/Domain/Logic/ShiftPatternDetector.swift`（純粋ロジック）
  - 新規 `Sources/Features/Rotation/PatternSuggestionView.swift`
  - 既存 `Sources/Features/Rotation/RotationListView.swift` に CTA 追加
  - 既存 `Sources/Features/Onboarding/OnboardingView.swift` に「履歴からの提案」分岐追加
  - 既存 `Sources/Domain/Models/AppSettings.swift` に提案スヌーズ用フラグを追加
  - テスト: 新規 `Tests/DomainTests/ShiftPatternDetectorTests.swift`
- **DoD**:
  - 単純な「昼夜交互週」プリセットが 14 日分の履歴から正しく抽出される。
  - 22 日複雑パターンが正しく 1 つの提案として抽出される。
  - 提案を受け入れると `RotationPattern` として保存され、以後のカレンダーに反映される。
  - 提案を却下したら 30 日間同じ提案を再表示しない。

- **A1. 受入後ドリフト検出（派生 / 未着手）**

  > アルゴリズム詳細: [docs/p2-algorithms.md §1.9](docs/p2-algorithms.md#19-受入後ドリフト検出)

  - 受諾済み `RotationPattern` に対し、直近 30 日の `DayAssignment`（手動上書き）が
    指定割合を超えたら「パターン更新を提案」する。
  - `AppSettings.patternDriftThreshold: Double = 0.15`（既定 15%）。
  - 再評価は `ShiftPatternDetector` を再実行し、新 `SuggestedRotation` の `fingerprint`
    が既存 pattern と異なる場合のみカード表示。同 fingerprint なら抑止。
  - 受諾で **新規 pattern を別 priority** として insert（既存 pattern は
    `isActive=false` にフラグ）。
  - 却下は通常の 30 日スヌーズ（α-I4/I5 と同じパス）を共用。
  - **対象ファイル**:
    - 既存 `Sources/Domain/Models/AppSettings.swift` に `patternDriftThreshold` 追加
    - 既存 `Sources/Domain/Logic/ShiftPatternDetector.swift` に `detectDrift(...)` 追加
    - 既存 `Sources/Features/Rotation/RotationListView.swift` に「更新提案カード」分岐追加
  - **DoD**:
    - 不一致率 < 閾値で再提案が走らない。
    - 閾値超 & 新 fingerprint で再提案カードが出る。
    - 受諾で旧 pattern が無効化、新 pattern が active 化される。

- **A2. 曜日×週序検出（派生 / 未着手）**

  > アルゴリズム詳細: [docs/p2-algorithms.md §1.10](docs/p2-algorithms.md#110-dow-検出)

  - 純粋周期に乗らない「第 1・第 3 金曜は夜勤」「毎月最終週は休」型の **DOW
    (day-of-week × week-of-month)** パターンを別アルゴリズムで検出。
  - 結果は `SuggestedRotation` ではなく `SuggestedDOWRule { dayOfWeek, weekOfMonth,
    presetID, observedMatches }` のリストとして返し、UI 上は通常ローテ提案と並列の
    カードで表示。
  - 受諾時は v1 では **`HolidayOverride`** に展開（週序計算で範囲展開、複数月分を
    一括 insert）。`RecurrenceRule` モデル化はバックログ扱い。
  - **対象ファイル**:
    - 新規 `Sources/Domain/Logic/DayOfWeekPatternDetector.swift`（α 検出器の兄弟）
    - 既存 `Sources/Features/Rotation/RotationListView.swift` に DOW 提案カードを追加
  - **DoD**:
    - 第 1・第 3 金曜のみ夜勤の履歴で 2 つの `SuggestedDOWRule` が返る。
    - 観測 1 件など低密度パターンは検出されない。
    - α 周期検出と DOW 検出が同入力で並走し、両ヒット時は両カードが出る。

### P2-β. 長期連休を挟んだ昼夜シフト切替（未着手）

> アルゴリズム詳細: [docs/p2-algorithms.md §2](docs/p2-algorithms.md#2-p2-β--連休越境ローテーション)

- **目的**: お盆・ゴールデンウィーク等の **連続休暇** をユーザが設定したとき、休暇前の最後
  のシフトと休暇後の最初のシフトを **意図通りに切り替える**。
  プリセット / ローテに **連休越境ポリシー** を持たせて自動適用する。
- **対象シナリオ**:
  - 連休前が夜勤ブロックで終わっていたら、連休明けは昼勤始まりにする（既定ポリシー
    `.invert`）。
  - ユーザがポリシーを「連休前と同じ位置から続行 (`.continue`)」「逆転 (`.invert`)」
    「リセット (`.resetToDay`)」から選べる。
- **アプローチ**:
  - `HolidayOverride` を連続範囲として束ねる `VacationPeriod` 概念を導入。
    （3 日以上連続でユーザが明示的に "連休" マークしたもの）
  - `RotationPattern.crossVacationPolicy` を **既定** (`.invert`) として持ち、
    `ShiftPreset.crossVacationPolicy?` を **optional override** とする（連休直前の
    最後のプリセットに override があれば pattern を上書き）。
  - `RotationExpander` を vacation-aware に拡張: 連休範囲を周期計算から除外しつつ、復帰
    時に policy に従ってオフセットを再計算する。
- **対象ファイル**:
  - 既存 `Sources/Domain/Models/HolidayOverride.swift` に `isVacationGroup` フラグ
  - 新規 `Sources/Domain/Models/VacationPeriod.swift`（SwiftData @Model、SchemaV1→V2
    マイグレーション必要）
  - 既存 `Sources/Domain/Models/RotationPattern.swift` に
    `crossVacationPolicy: CrossVacationPolicy = .invert` と
    `dayStartSlotIndex: Int?` を追加
  - 既存 `Sources/Domain/Models/ShiftPreset.swift` に
    `crossVacationPolicy: CrossVacationPolicy?`（nil = pattern に従う）を追加
  - 既存 `Sources/Domain/Logic/RotationExpander.swift` を vacation-aware に拡張
  - 新規 `Sources/Domain/Logic/VacationAwareRotation.swift`（policy 適用ロジック）
  - 既存の祝日/有休 UI に "連休としてまとめる" 操作を追加
  - 既存 `Sources/Features/Presets/PresetEditorView.swift` に policy ピッカー追加
  - テスト: 新規 `Tests/DomainTests/VacationAwareRotationTests.swift`
- **DoD**:
  - 既定 (`.invert`) で連休前夜勤 → 連休 → 昼勤、が再現できる。
  - `.continue` policy で連休前と同じ位相が維持される。
  - `.resetToDay` で常に昼勤始まりになる。
  - SwiftData マイグレーション後、既存 `HolidayOverride` は破壊されない。

- **A4. 連休自動グルーピング（opt-in 派生 / 未着手）**

  > アルゴリズム詳細: [docs/p2-algorithms.md §2.8](docs/p2-algorithms.md#28-自動グルーピング提案フロー)

  - β-S3「マイグレーションで自動グルーピングしない」を踏襲しつつ、**初回 β 画面
    オープン時にだけ**「連続 3 日以上の既存 `HolidayOverride` を `VacationPeriod`
    としてまとめますか？」プロンプトを 1 回出す。
  - `AppSettings.vacationAutoGroupingOffered: Bool = false`。プロンプト表示で
    `true` に更新し、二度と出さない。
  - 受諾で各連続範囲を `VacationPeriod` 化し、範囲内 `HolidayOverride.isVacationGroup`
    を `true` にする。
  - 却下は単にフラグを `true` にして閉じる（再表示なし、手動で個別作成は常時可能）。
  - **対象ファイル**:
    - 既存 `Sources/Domain/Models/AppSettings.swift` に
      `vacationAutoGroupingOffered` 追加
    - 既存 `Sources/Features/Holidays/HolidayManagerView.swift` に提案 sheet 追加
  - **DoD**:
    - 連続 3 日以上のみ候補化される（2 日以下は除外）。
    - 候補から個別に除外できる。
    - フラグ `true` 後は β 画面再オープンで再表示しない。

### P2-γ. シフト表画像の AI 解析 → カレンダー自動適用（未着手）

> アルゴリズム詳細: [docs/p2-algorithms.md §3](docs/p2-algorithms.md#3-p2-γ--シフト表画像インポート)

- **目的**: 紙のシフト表や、職場のポータルから保存したカレンダー画像をアップロードする
  だけで、AI が日付ごとのシフト（昼 / 夜 / 休 / 明 など）を読み取り、当アプリのカレンダ
  ーに自動で割り当てる。手入力・JSON インポート以外の **第 3 の入力チャネル**。
- **入力 UX**:
  - `PhotosPicker` で写真ライブラリから、または `VisionKit.DataScannerViewController` で
    その場でカメラ撮影。
  - 複数枚（月またぎや見開き）にも対応。
- **解析パイプライン**:
  1. **OCR**: `Vision.VNRecognizeTextRequest`（ja / en）で全テキストと bounding box を抽出。
  2. **構造検出**: テキスト座標から行/列のグリッドを推定し、(日付セル × 名前行) の表構造
     を再構築。`VNRecognizeDocumentsRequest`（iOS 18+）が使える場合は優先利用。
  3. **意味マッピング**: 抽出セル文字列を **iOS 26 の `FoundationModels`（on-device LLM）**
     に渡し、`{date, shiftLabel} -> existing ShiftPreset?` の対応を生成。
     既存プリセットが空ならラベルから自動命名で **新規 ShiftPreset を提案**する。
     **オフライン推論を既定**にし、クラウド送信は無し。
  4. **ユーザ名フィルタ**: 表に複数従業員行がある場合、初回にユーザ自身の名前を選択。次回
     以降は `AppSettings.userNameOnRoster` に記憶。
  5. **差分プレビュー**: 既存 `ShareImporter` の diff UI を再利用し、適用前にユーザが確認。
- **対象ファイル**:
  - 新規 `Sources/Services/Vision/ShiftImageOCR.swift`（Vision request ラッパ）
  - 新規 `Sources/Services/Vision/ShiftImageParser.swift`（OCR → 構造 → 意味マッピング）
  - 新規 `Sources/Services/Vision/FoundationModelsShiftMapper.swift`
    （iOS 26 FoundationModels 呼び出し。利用不可ならルールベースに fallback）
  - 新規 `Sources/Features/Import/ImageImportView.swift`（PhotosPicker + 進捗 + diff UI）
  - 既存 `Sources/Services/Sharing/ShareImporter.swift` の diff/apply ロジックを再利用
  - 既存 `Sources/Domain/Models/AppSettings.swift` に `userNameOnRoster` を追加
  - 既存の Import/Export 画面から「画像から取り込む」導線を追加
  - `App/Info.plist`: `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` を追加
  - テスト: 新規 `Tests/ServicesTests/ShiftImageParserTests.swift`
    （`Resources/TestFixtures/` にサンプル画像を置き、構造抽出が安定するか確認）。
    FoundationModels 部分は **プロトコル境界でモック**。
- **DoD**:
  - 月次シフト表サンプル（昼/夜/休 3 種ラベル）から 80% 以上のセルが正しく抽出される
    （ja / en サンプル各 1 セット）。
  - 抽出結果は `ShareImporter` と同じ差分プレビューでレビューしてから適用できる。
  - FoundationModels が利用不可な OS / 機種でもルールベース fallback で動作する。
  - **クラウド通信は発生しない**（プライバシー / ネット非依存）。
- **既知の不確実性**:
  - iOS 26 `FoundationModels` の API は実装着手時に `.swiftinterface` で再チェック。
  - 手書きシフト表は OCR 精度が落ちる可能性。初版では印刷 / デジタル表に限定し、手書きは
    バックログ扱い。

- **A3. ラベル学習キャッシュ（派生 / 未着手）**

  > アルゴリズム詳細: [docs/p2-algorithms.md §3.12](docs/p2-algorithms.md#312-ラベル学習キャッシュ)

  - 差分プレビュー UI でユーザがラベル → preset 対応を手動修正したら、その対応を
    `AppSettings.learnedLabelMappingsJSON` に JSON 保存。
  - `LabelKey = "<NFKC + lowercase>(label)|<userNameOnRoster?>"`。
  - 次回パイプラインで **Pass A（ルール）の前** に参照、ヒットなら
    `MapResult.existingPreset(_, confidence: 1.0)` 相当を返す。
  - `nil` を覚えるケース = `.off`（「これは休」を学習）。
  - 上限 200 エントリ。超過時は `learnedAt` 古い順に LRU 退避。
  - 設定画面に「学習データをリセット」ボタンを追加（A3 範囲内）。
  - クラウド送信なし。
  - **対象ファイル**:
    - 既存 `Sources/Domain/Models/AppSettings.swift` に `learnedLabelMappingsJSON: String`
      フィールド追加（Dictionary は SwiftData 制約により JSON 文字列で保持）
    - 既存（未実装）`Sources/Services/Vision/FoundationModelsShiftMapper.swift` で
      キャッシュ参照
    - 既存（未実装）`Sources/Features/Import/ImageImportView.swift` のプレビュー
      補正ハンドラで保存
    - 既存 `Sources/Features/Settings/` 配下にリセットボタン追加
  - **DoD**:
    - キャッシュヒットがルールベース / LLM より優先される。
    - `.off` 学習が次回呼出でヒット。
    - 上限超過で最古エントリが退避。
    - 補正がプレビュー → 適用フローを通すと `AppSettings` に永続化される。

---

### P2-δ. シフトスワップ — 代行 / 被代行のアラーム正当性（未着手）

> アルゴリズム詳細: [docs/p2-algorithms.md §5](docs/p2-algorithms.md#5-p2-δ--シフトスワップ)

- **目的**: 同僚と勤務を交換した日でも **正しいシフトのアラームが鳴る** ことを保証する。
  「火曜の昼勤を A に代わってもらった / 水曜の夜勤を代わってあげた」を 1 操作で記録し、
  対象日の `DayAssignment` を更新、`AlarmScheduler` の diff-sync を発火する。
- **対象シナリオ**:
  1. **被代行 (off)**: 自分が出勤予定だった日を同僚に代わってもらう → 当日のアラームを
     ミュート（`skipAlarm = true`）し、`SwapRecord` に「A に代行依頼」を残す。
  2. **代行 (on)**: 自分が休み予定だった日に同僚の代わりに出勤する → 当日のプリセットを
     出勤シフトに上書きし、アラーム登録。
  3. **同時スワップ (exchange)**: 1 + 2 を同じ操作で記録。
- **データモデル（V2 → V3）**:
  - 新規 `@Model SwapRecord { id, date, kind: .covered|.covering|.exchange,
    counterpartyLabel: String, note: String, createdAt }`。
  - `DayAssignment` には **フィールド追加なし**。出勤 / 欠勤は通常の `DayAssignment` で
    表現し、`SwapRecord` はメタデータ専用。
  - これにより `DayResolver` / `AlarmScheduler` は **完全に無改変**（既存の手動優先パス
    がそのまま機能する）。
- **対象ファイル**:
  - 新規 `Sources/Domain/Models/SwapRecord.swift`（SwiftData @Model、Schema V2 → V3）
  - 新規 `Sources/Domain/Persistence/SchemaV3.swift` + 既存 `MigrationPlan` 拡張
  - 既存 `Sources/Features/Calendar/DayDetailEditorView.swift` にスワップアクション追加
  - 既存 `Sources/Features/Calendar/DayCellView.swift` に「↔」バッジ追加
  - 既存 `Sources/Domain/Logic/DayResolverInputBuilder.swift` に SwapRecord スナップ
    ショット同梱（UI バッジ用、resolver 自体は使わない）
  - テスト: 新規 `Tests/DomainTests/SwapRecordTests.swift` /
    `Tests/DomainTests/SchemaV2MigrationTests.swift` /
    `Tests/ServicesTests/AlarmSchedulerTests.swift` 拡張
- **UX**:
  - 日付詳細画面に「シフト交代」ボタン → kind 選択 → 相手ラベル入力 → 該当日の
    `DayAssignment` を upsert（出勤化なら preset 選択、欠勤化なら skip）→ `SwapRecord`
    を作成。
  - 月カレンダーのバッジで「↔」アイコン表示（VoiceOver 文言: "シフト交代済み"）。
- **DoD**:
  - 「代行 (on)」記録後、当日のアラームが指定プリセットの時刻で AlarmKit に登録。
  - 「被代行 (off)」記録後、当日のアラーム登録が消える。
  - SwiftData V2 → V3 マイグレーション後、既存データ非破壊。
  - 月カレンダーで「↔」バッジが該当日に出る（VoiceOver 含む）。

---

### P2-η. 家族共有用 .ics エクスポート ✅ 実装済み (PR #19)

> アルゴリズム詳細: [docs/p2-algorithms.md §6](docs/p2-algorithms.md#6-p2-η--ics-エクスポート)

- **目的**: 月単位の確定シフトを **iCalendar (.ics) ファイル** として書き出し、AirDrop /
  Mail / メッセージで家族に渡せるようにする。受け取り側は標準 Calendar アプリで
  読み取り専用購読する。**CloudKit は使わない**。
- **対象範囲**:
  - エクスポートは **手動操作の都度**。バックグラウンド同期はしない。
  - 1 ファイル = 1 ヶ月分（既定）。範囲ピッカーで 1〜12 ヶ月選択可。
  - 1 シフト = 1 `VEVENT`。`SUMMARY = preset.name`、`DTSTART/DTEND` は
    `alarmTime` を起点に 30 分のダミーイベント。
  - 連休 (`VacationPeriod`) と `skipAlarm` 日はイベント化しない。
  - `PRODID = -//ShiftAlarm//ja//EN`、`X-WR-CALNAME` は固定文字列。
- **対象ファイル**:
  - 新規 `Sources/Services/Sharing/ICSExporter.swift`（純ロジック）
  - 新規 `Sources/Features/Sharing/ICSExportView.swift`（範囲ピッカー + 共有シート）
  - 既存 Import/Export 画面に「.ics で書き出し」導線追加
  - テスト: 新規 `Tests/ServicesTests/ICSExporterTests.swift` /
    `Tests/ServicesTests/ICSExportFlowTests.swift`
- **DoD**:
  - 1 ヶ月分の `.ics` が macOS / iOS Calendar、Google Calendar、Outlook で
    時刻・タイトル・タイムゾーン正しく読める。
  - 個人情報（`counterpartyLabel`、note）はエクスポートに含まれない（preset 名のみ）。
  - 機内モードで書き出し → 共有シートで保存可能（ネット通信なし）。
- **既知の不確実性**:
  - 終日イベント (`DTSTART;VALUE=DATE`) でなく 30 分イベントとして書く判断は要レビュー。
    家族側で「6 時から夜勤?」と誤読しない文面 / X-プロパティを実装時に詰める。

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
- 現状: 16 テストクラス / 85 テスト緑（うち 5 件 snapshot は通常 verify では skip）。

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

### P3-5. Swift Testing 移行（未着手 / Mac 作業）

- **目的**: 既存の XCTest テストを Apple の Swift Testing（`@Test`）へ移行し、
  `#expect` / `#require` ベースの表現力と並列実行を得る。
- **対象**: `Tests/` 配下 18 ファイル / 16 テストクラス / 85 テストメソッド。
  `@testable import ShiftAlarm` は維持。`project.yml` のテストターゲット定義は
  変更不要（Swift Testing はツールチェーン同梱）。
- **機械的変換**:
  - `XCTestCase` サブクラス → `struct` + `@Test` 関数。
  - `XCTAssertEqual` / `XCTAssertTrue` 等 → `#expect(...)`。
  - `XCTUnwrap` → `#require(...)`。
  - `@MainActor` / `async` テストはそのまま移行可。
- **注意が必要な箇所**:
  - `Tests/SnapshotTests/SnapshotTestSupport.swift` の `SnapshotTestGate`:
    `XCTSkipUnless` を Swift Testing の条件付きスキップ
    （`@Test(.enabled(if:))` 等）へ書き換える。影響は
    `DayCellViewSnapshotTests` の 5 テスト。
  - `Tests/ServicesTests/SleepIntentHelperTests.swift` の `tearDown`
    （`containerFactory` リセット）→ per-test フィクスチャ / `deinit` へ。
- **難易度**: 大半（約 13 ファイル）は easy。`tearDown` / snapshot 系が
  medium〜hard。
- **進め方**: 専用ブランチ・単独 PR で実施し、swift-format 一括整形 PR とは
  混在させない。検証は macOS + Xcode 26 が必須。
- **DoD**: `bash scripts/verify.sh` がビルド・テストとも緑。snapshot ゲートが
  従来どおり `SNAPSHOT_TESTING_ENABLED=1` でのみ有効になる。

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

**P2-α / P2-η は PR #19 でマージ済み。** 次の優先順位:

1. **P0-3 実機ゴールデンパス**: `Config/LocalSigning.xcconfig` に実 Developer Team /
   bundle id / App Group を入れ、`bash scripts/p0-readiness.sh` を緑にしてから
   AlarmKit 認可ダイアログ・アラーム発火・Live Activity / Widget の通し確認。

2. **A1 RotationListView 統合**: `ShiftPatternDetector.detectDrift()` は実装済みのため、
   `RotationListView.detectPattern()` にドリフト検出を追加し、受入で旧 pattern を
   `isActive = false` にするフローを実装する。

3. **P2-β 連休越境ローテーション**: `RotationExpander` の vacation-aware 拡張（最大規模の
   次タスク）。SwiftData V2 マイグレーションが必要。

---

## 9. P2 テスト項目（実装ガイド）

各 P2 タスクの **実装と検証を同時に進めるための test punch list**。各項目は
「`Tests/...` の予定ファイル + 関数名 + 検証する性質」の三点セットで書く。
TDD 的に最初に **赤いテスト** として並べてから実装すると、DoD と一対一で対応する。

ユニットテストは「純ロジック」を、UI / Integration テストは「振る舞い」を、
手動 (golden path) は「実機で確認すべき UX」を扱う。

### 9-α. P2-α シフトパターン自動検出

**ユニット — `Tests/DomainTests/ShiftPatternDetectorTests.swift`（新規）**

| # | テスト名 | 検証する性質 |
|---|---|---|
| α-U1 | `testEmptyHistoryReturnsNoSuggestion` | 履歴 0 件 → `nil` |
| α-U2 | `testFewerThanTwoCyclesReturnsNoSuggestion` | 1 周期分しか観測が無い場合 → 提案無し |
| α-U3 | `testSimpleWeeklyAlternationDetected` | 14 日 (昼週 → 夜週) で `period=14` を検出 |
| α-U4 | `testSimpleDailyAlternationDetected` | 14 日 (昼/夜 交互) で `period=2` を検出 |
| α-U5 | `testComplexMultiWeekPatternDetected` | 22 日 (例: 月火昼/水木休/金土夜/月火休/水木金土昼/月火水木昼) を 1 つの 22 日周期として検出 |
| α-U6 | `testNoisySequenceBelowThresholdRejected` | 一致率が `< 0.85` なら提案無し |
| α-U7 | `testThresholdAdjustableViaConfig` | しきい値を境にして検出/未検出が切り替わる |
| α-U8 | `testSuggestionPreservesPresetIDOrder` | 結果列が `[presetID \| .off]` の順序を保持 |
| α-U9 | `testSkipDayMappedToExplicitOff` | `skip` フラグ付きの日が `.off` として認識される |
| α-U10 | `testRotationGeneratedAssignmentsExcludedFromInput` | rotation 由来の自動値は検出入力から除外し、手動入力のみを見る |
| α-U11 | `testHistoryWindowDefaultIs90Days` | 検出窓は既定 90 日（境界テスト: 89 / 90 / 91 日） |
| α-U12 | `testCanonicalizationStartsFromMonday` | 検出結果は週初を月曜に揃えて返す（曜日ズレ吸収） |
| α-U13 | `testDriftBelowThresholdSuppressesReSuggestion` | A1: 不一致率 < 閾値で `detectDrift` が `nil` |
| α-U14 | `testDriftAboveThresholdReturnsNewSuggestion` | A1: 閾値超 → 検出再走 → 新 fingerprint なら提案返却 |
| α-U15 | `testDOWDetectorFindsFirstAndThirdFriday` | A2: 第 1・第 3 金曜のみ夜勤履歴 → 2 ルール検出 |
| α-U16 | `testDOWDetectorRejectsLowDensity` | A2: 観測 1 件のみ → `nil` |
| α-U17 | `testPeriodicAndDOWCoexistBothReturned` | A2: 7 日交互 + 第 1 金曜上書き → 両提案 |

**統合 / UI — `Tests/ServicesTests/PatternSuggestionFlowTests.swift`（新規）**

| # | テスト名 | 検証する性質 |
|---|---|---|
| α-I1 | `testSuggestionAppearsAfterDetectionFires` | RotationListView で提案カードが表示される |
| α-I2 | `testAcceptCreatesRotationPattern` | 受諾で `RotationPattern` が SwiftData に永続化 |
| α-I3 | `testAcceptSchedulesAlarmsForFutureDates` | 受諾後 `AlarmScheduler` の diff-sync で未来日のアラーム登録が増える |
| α-I4 | `testRejectSetsSnoozeUntilDate` | 却下で `AppSettings.patternSuggestionSnoozedUntil` に 30 日後の値 |
| α-I5 | `testSnoozedSuggestionNotShownAgain` | スヌーズ期間中は提案が再表示されない |
| α-I6 | `testOnboardingPathTriggersSuggestion` | Onboarding 完了直後にサンプル履歴があれば提案分岐に入る |
| α-I7 | `testAcceptDriftDeactivatesPreviousPattern` | A1: ドリフト受諾で旧 pattern が `isActive=false`、新 pattern が active |

**手動 (golden path)**

- 22 日分の混合シフトを Calendar で手動割当 → Rotation 画面に提案バナー出現を確認。
- 受諾後、適用範囲外の翌月セルがプリセット色で自動展開されるか確認。

---

### 9-β. P2-β 長期連休を挟んだ昼夜シフト切替

**ユニット — `Tests/DomainTests/VacationAwareRotationTests.swift`（新規）**

| # | テスト名 | 検証する性質 |
|---|---|---|
| β-U1 | `testNoVacationPeriodProducesIdenticalResultToBaseExpander` | 連休無し → 既存 `RotationExpander` と完全一致 |
| β-U2 | `testInvertPolicyFlipsNightToDayAfterVacation` | 連休前=夜勤 → 連休明け初日=昼勤（既定） |
| β-U3 | `testInvertPolicyFlipsDayToNightAfterVacation` | 連休前=昼勤 → 連休明け初日=夜勤 |
| β-U4 | `testContinuePolicyMaintainsPhase` | `.continue` で連休前と同じ位相が続く |
| β-U5 | `testResetToDayPolicyAlwaysStartsDay` | `.resetToDay` でどんな連休前でも昼勤始まり |
| β-U6 | `testVacationDaysHaveNoPresetAssignment` | 連休セルは `nil` (skip) で返る |
| β-U7 | `testShortHolidayBelowMinDurationNotVacation` | 連続日数 `< 3`（既定）は通常祝日として処理 |
| β-U8 | `testIsVacationGroupFlagRequired` | 連続 ≥ 3 日でも `isVacationGroup=false` なら通常処理 |
| β-U9 | `testMultipleVacationPeriodsHandledIndependently` | お盆 + GW など複数連休の独立適用 |
| β-U10 | `testManualOverrideInsideVacationWins` | 連休内に手動割当があれば手動を優先 |
| β-U11 | `testHigherPriorityRotationOverridesAfterVacation` | 連休越境後も rotation の priority が尊重される |
| β-U12 | `testVacationAtMonthBoundary` | 月境界（例: 4/29 〜 5/8）で連休が分断されず 1 つとして扱われる |
| β-U13 | `testVacationAtYearBoundary` | 年末年始（12/30 〜 1/3）でも同上 |
| β-U17 | `testAutoGroupingDetectsThreePlusConsecutiveHolidays` | A4: 連続 3 日以上で候補化、2 日以下は除外 |
| β-U18 | `testAutoGroupingRespectsUserSelection` | A4: 候補から個別除外したら除外分は作成されない |

**スキーマ — `Tests/DomainTests/SchemaV1MigrationTests.swift`（既存 or 新規）**

| # | テスト名 | 検証する性質 |
|---|---|---|
| β-S1 | `testMigrationFromV1AddsCrossVacationPolicyDefault` | 既存 `RotationPattern` / `ShiftPreset` に `.invert` が付く |
| β-S2 | `testMigrationPreservesExistingHolidayOverrides` | 既存 `HolidayOverride` が破壊されない |
| β-S3 | `testMigrationCreatesNoVacationPeriodAutomatically` | マイグレーション時に自動で連休をまとめない（明示操作必須） |

**統合 — `Tests/ServicesTests/AlarmSchedulerTests.swift`（拡張）**

| # | テスト名 | 検証する性質 |
|---|---|---|
| β-I1 | `testAlarmSchedulerSkipsAlarmsDuringVacation` | 連休範囲の AlarmKit 登録が無い |
| β-I2 | `testAlarmSchedulerRegistersFlippedAlarmAfterVacation` | 連休明け初日のアラーム時刻が `.invert` で正しい |
| β-I3 | `testDayResolverReturnsCorrectPresetAfterVacation` | `DayResolver` で連休明け初日のプリセットが解決 |
| β-I4 | `testAutoGroupingPromptShownOnlyOnce` | A4: フラグ `true` 後は β 画面再オープンで表示無し |

**手動 (golden path)**

- 夜勤を 1 週間続けた後 8/13-16 を連休としてマーク → 8/17 が昼勤化することを Calendar /
  Widget / Live Activity で確認。
- policy を `.continue` に切替 → 8/17 が夜勤継続することを確認。

---

### 9-γ. P2-γ シフト表画像の AI 解析

**ユニット — `Tests/ServicesTests/ShiftImageOCRTests.swift`（新規）**

| # | テスト名 | 検証する性質 |
|---|---|---|
| γ-U1 | `testOCRExtractsAllVisibleCellsFromJapaneseSample` | ja サンプル画像 → 全テキスト + bounding box |
| γ-U2 | `testOCRExtractsAllVisibleCellsFromEnglishSample` | en サンプル画像 → 同上 |
| γ-U3 | `testOCRHandlesRotatedImageWithinTolerance` | ±10° 回転画像でも抽出可能 |
| γ-U4 | `testOCRReturnsEmptyForBlankImage` | 真っ白画像 → 空配列、エラー無し |

**ユニット — `Tests/ServicesTests/ShiftImageParserTests.swift`（新規）**

| # | テスト名 | 検証する性質 |
|---|---|---|
| γ-U5 | `testGridStructureRecognitionForMonthlyTable` | OCR 結果 → (date × employee) のセル配列 |
| γ-U6 | `testGridStructureFallbackWhenNoTableDetected` | `VNRecognizeDocumentsRequest` が空なら座標クラスタリングへ fallback |
| γ-U7 | `testCellLabelMapsToShiftPreset` | "昼" / "夜" / "休" / "D" / "N" を既存 ShiftPreset に対応付け |
| γ-U8 | `testUnknownLabelMarkedAsAmbiguous` | 未知ラベルは `nil` ではなく `.unresolved` で返す |
| γ-U9 | `testMultiPageMergePreservesOrder` | 月またぎ 2 枚を 1 件の `DayAssignment` 集合にマージ |
| γ-U10 | `testUserNameFilterIncludesOnlySelectedRow` | 「ユーザ名」選択時、その行だけ抽出 |
| γ-U11 | `testParserHandlesPartiallyOccludedTable` | セル欠損があっても抽出済み分のみ返す |
| γ-U12 | `testNoNetworkRequestsDuringParse` | パイプライン中に URL リクエストが発生しない（`URLProtocol` で監視） |

**ユニット (Mapper モック) — `Tests/ServicesTests/FoundationModelsShiftMapperTests.swift`（新規）**

| # | テスト名 | 検証する性質 |
|---|---|---|
| γ-U13 | `testRuleBasedMapperUsedWhenModelUnavailable` | `FoundationModels` 利用不可環境で rule-based fallback が動く |
| γ-U14 | `testModelMapperReturnsHighConfidenceMapping` | モック返却で confidence ≥ 閾値なら確定マッピング |
| γ-U15 | `testLowConfidenceMappingMarkedUnresolved` | confidence < 閾値 → `.unresolved` |
| γ-U16 | `testMapperRespectsPreviousNamingHint` | 既存 ShiftPreset 名と最も近いものを優先 |
| γ-U17 | `testLearnedMappingTakesPrecedenceOverRuleBased` | A3: キャッシュに `"早"→nightID` を入れた状態でルールの `早→dayID` を上書き |
| γ-U18 | `testLearnedOffMappingPersists` | A3: `.off` 学習が次回呼出でヒット |
| γ-U19 | `testLRUEvictionAt201stEntry` | A3: 上限超過で最古エントリが破棄 |

**統合 — `Tests/ServicesTests/ImageImportIntegrationTests.swift`（新規）**

| # | テスト名 | 検証する性質 |
|---|---|---|
| γ-I1 | `testImportProducesShareImporterCompatibleDiff` | 抽出結果が `ShareImporter` と同型の diff (`add` / `update` / `delete`) を返す |
| γ-I2 | `testApplyDiffPersistsAssignments` | 適用で SwiftData に書き込まれ Calendar 表示が更新 |
| γ-I3 | `testRetainsExistingManualOverrides` | 取込前の手動上書きは破壊されない（衝突時は `add` ではなく `update` 候補） |
| γ-I4 | `testRetryOnPartialFailureKeepsAlreadyAppliedDays` | 途中失敗時に既適用日はロールバックされない（idempotent） |
| γ-I5 | `testUserCorrectionInPreviewPersistsToSettings` | A3: プレビュー UI 補正 → 適用後 `AppSettings.learnedLabelMappingsJSON` 反映 |

**精度 DoD — `Tests/Fixtures/ShiftImages/` に手動アノテーション付きで配置**

| # | 指標 | 値 |
|---|---|---|
| γ-D1 | ja 月次サンプル 30 日 × 1 行で **セル一致率** | ≥ 80% |
| γ-D2 | en 月次サンプル 30 日 × 1 行で **セル一致率** | ≥ 80% |
| γ-D3 | ユーザ名フィルタの正解率（複数行表） | ≥ 95% |

**手動 (golden path)**

- 機内モードで画像を取込 → 通信エラーが出ず正しく抽出 → 差分プレビュー → 適用 → Calendar
  に反映。
- カメラ撮影 (`DataScannerViewController`) で撮影 → 同じパイプラインで適用できる。
- `FoundationModels` が利用不可な OS にフォールバックを設定 → ルールベースで動作する。

---

### 9-δ. P2-δ シフトスワップ

**ユニット — `Tests/DomainTests/SwapRecordTests.swift`（新規）**

| # | テスト名 | 検証する性質 |
|---|---|---|
| δ-U1 | `testCoveredMarksDayAsSkipAlarm` | `.covered` 操作で `DayAssignment.skipAlarm == true` |
| δ-U2 | `testCoveringUpsertsAssignmentWithPreset` | `.covering` 操作で `DayAssignment.preset == 指定` |
| δ-U3 | `testSwapRecordMetadataPersists` | `counterpartyLabel` と `kind` が読み戻し可能 |
| δ-U4 | `testPastDateSwapAccepted` | 過去日でも記録は作成可能 |
| δ-U5 | `testDeletingSwapRecordKeepsAssignment` | レコード削除で割当は残る |

**スキーマ — `Tests/DomainTests/SchemaV2MigrationTests.swift`（新規）**

| # | テスト名 | 検証する性質 |
|---|---|---|
| δ-S1 | `testMigrationV2ToV3PreservesExistingData` | V2 で書いた行が V3 で全件読める |
| δ-S2 | `testMigrationV2ToV3AddsNoSwapRecords` | migration 直後 `SwapRecord` count == 0 |

**統合 — `Tests/ServicesTests/AlarmSchedulerTests.swift`（拡張）**

| # | テスト名 | 検証する性質 |
|---|---|---|
| δ-I1 | `testCoveringDayGetsScheduledAlarm` | `.covering` 記録後の対象日に AlarmKit 登録 |
| δ-I2 | `testCoveredDayRemovesScheduledAlarm` | `.covered` 記録後に当該日の登録が消える |
| δ-I3 | `testSwapDoesNotAffectOtherDays` | スワップ日以外の登録は変化しない |

**手動 (golden path)**

- 今週金曜の昼勤を「同僚 X に代行してもらう」→ 金曜のアラームが鳴らないことを実機で確認。
- 翌週月曜（休み予定）を「Y の代わりに昼勤」→ 月曜にプリセット色のセル + アラームが
  鳴ることを実機で確認。

---

### 9-η. P2-η .ics エクスポート

**ユニット — `Tests/ServicesTests/ICSExporterTests.swift`（新規）**

| # | テスト名 | 検証する性質 |
|---|---|---|
| η-U1 | `testEmptyRangeProducesValidEmptyCalendar` | 範囲内に出勤日 0 → `VCALENDAR` のみ、`VEVENT` 0 |
| η-U2 | `testSingleEventFormatMatchesRFC5545` | 1 件出勤の出力を行ごとに固定アサート（CRLF + 必須プロパティ全て） |
| η-U3 | `testSummaryEscapesSpecialCharacters` | preset 名に `;,\n\\` を含む → エスケープ済 |
| η-U4 | `testSkipAlarmDayExcluded` | `skipAlarm` 日は `VEVENT` に含まれない |
| η-U5 | `testVacationPeriodDayExcluded` | 連休範囲はスキップ |
| η-U6 | `testUIDIsDeterministicAcrossRuns` | 同入力で 2 回エクスポートしても同 UID |
| η-U7 | `testUTCConversionMatchesCalendarTimezone` | `X-WR-TIMEZONE` が `calendar.timeZone.identifier` と一致、`DTSTART` は UTC（末尾 `Z`） |
| η-U8 | `testNoNetworkRequestsDuringExport` | `URLProtocol` 監視で `requestCount == 0` |
| η-U9 | `testMultiMonthExportWithinLimit` | 12 ヶ月分でも順序がカレンダー昇順 |

**統合 — `Tests/ServicesTests/ICSExportFlowTests.swift`（新規）**

| # | テスト名 | 検証する性質 |
|---|---|---|
| η-I1 | `testExportFromContainerEmitsValidICS` | `ModelContainer` シード → エクスポート → ヘッダ・件数アサート |
| η-I2 | `testExportParseRoundtrip` | 出力文字列をテスト内 `ICSTestParser` で再パースし、件数・SUMMARY・UTC DTSTART が一致（EventKit には ICS 取込 API が無いためファイルレベル検証で代替、詳細 `docs/p2-algorithms.md §6.8.1`） |

**手動 (golden path)**

- iPhone で 1 ヶ月分書き出し → AirDrop で別端末に送信 → 標準 Calendar で全件読めることを確認。
- Outlook / Google Calendar に読み込ませて時刻が正しい TZ で表示されることを確認。

---

### 9-x. テスト実行・運用ルール

- 単体テストはすべて `scripts/verify.sh` 既定実行で緑にする。
- 画像 fixtures はリポジトリに含めるが大きさ上限は **1 ファイル 500 KB**。超えるなら
  画像を縮小するか圧縮 PDF にする。
- `FoundationModels` は **実モデル呼び出しを CI でしない**。プロトコル境界でモック。
- 手動 (golden path) は P0-3 のチェックリストに追記し、リリース前にユーザが実機で走らせる。
- スナップショットテスト (P3-2 拡張) は `SNAPSHOT_TESTING_ENABLED=1` 環境変数で
  `verify.sh` から enable／skip を制御する既存運用を踏襲する。
