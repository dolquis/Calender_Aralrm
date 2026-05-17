# Calender_Aralrm 開発ロードマップ

このファイルは Claude Code / OpenAI Codex / その他エージェントが参照するための
**開発仕様兼ロードマップ**です。タスクは優先度（P0 → P3）順、各項目に
**目的 / 対象ファイル / 完了条件 (DoD)** を明記しています。

最終更新: 2026-05-17
対象ブランチ運用: タスクごとに `feature/<topic>` を切り、main へ PR。

---

## 0. 現状サマリ（2026-05-17 時点）

- iOS 26+ / Swift 6 / SwiftUI + SwiftData / AlarmKit ベースのシフト勤務向けアラームアプリ。
- 主要レイヤー（Domain / Services / Features / Widget / Live Activity / Sharing / Deep link / ja-en ローカライズ）は実装済み。
- **P1 群（オンボーディング / a11y / 空状態 UX / Widget タイムライン）と P2-2（Bedtime reminder, Sleep schedule, HealthKit, App Intents）まで完了**。
- P0-1 は Xcode 26.5 / iOS 26.5 SDK でコードレベル検証に着手済み。
  `AlarmPresentation.Alert.stopButton` の iOS 26.1 deprecation を回避し、
  `AlarmManager.AlarmConfiguration.alarm(...)` に寄せた。実機確認は未完了。
- テスト 56 件 (14 ファイル) 緑。通常の `scripts/verify.sh` では
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
  - **#14 P0-2 signing readiness ワークフロー (`scripts/p0-readiness.sh` / `scripts/p0-device-build.sh`)**

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

### P2-α. シフトパターン自動検出 → プリセット / ローテ提案（未着手）

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
- 現状: 14 ファイル / 56 テスト緑（うち 5 件 snapshot は通常 verify では skip）。

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
P0-1 のコードレベル確認は済み、P0-2 の readiness / device-build スクリプトも PR #14 で
マージ済みのため、残りのリリース前ゲートは実機での AlarmKit 認可ダイアログ、AlarmKit
alert、Live Activity / Dynamic Island、Widget、共有 import/export の通し確認。

P0-3 完了後の **新機能着手順** は P2-α (パターン検出) → P2-β (連休越境) → P2-γ (画像
解析) を想定。最も既存ロジック (`RotationExpander` / `DayAssignment`) に近い P2-α を
最初の差分にすると review コストが低い。

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

**統合 / UI — `Tests/ServicesTests/PatternSuggestionFlowTests.swift`（新規）**

| # | テスト名 | 検証する性質 |
|---|---|---|
| α-I1 | `testSuggestionAppearsAfterDetectionFires` | RotationListView で提案カードが表示される |
| α-I2 | `testAcceptCreatesRotationPattern` | 受諾で `RotationPattern` が SwiftData に永続化 |
| α-I3 | `testAcceptSchedulesAlarmsForFutureDates` | 受諾後 `AlarmScheduler` の diff-sync で未来日のアラーム登録が増える |
| α-I4 | `testRejectSetsSnoozeUntilDate` | 却下で `AppSettings.patternSuggestionSnoozedUntil` に 30 日後の値 |
| α-I5 | `testSnoozedSuggestionNotShownAgain` | スヌーズ期間中は提案が再表示されない |
| α-I6 | `testOnboardingPathTriggersSuggestion` | Onboarding 完了直後にサンプル履歴があれば提案分岐に入る |

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

**統合 — `Tests/ServicesTests/ImageImportIntegrationTests.swift`（新規）**

| # | テスト名 | 検証する性質 |
|---|---|---|
| γ-I1 | `testImportProducesShareImporterCompatibleDiff` | 抽出結果が `ShareImporter` と同型の diff (`add` / `update` / `delete`) を返す |
| γ-I2 | `testApplyDiffPersistsAssignments` | 適用で SwiftData に書き込まれ Calendar 表示が更新 |
| γ-I3 | `testRetainsExistingManualOverrides` | 取込前の手動上書きは破壊されない（衝突時は `add` ではなく `update` 候補） |
| γ-I4 | `testRetryOnPartialFailureKeepsAlreadyAppliedDays` | 途中失敗時に既適用日はロールバックされない（idempotent） |

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

### 9-x. テスト実行・運用ルール

- 単体テストはすべて `scripts/verify.sh` 既定実行で緑にする。
- 画像 fixtures はリポジトリに含めるが大きさ上限は **1 ファイル 500 KB**。超えるなら
  画像を縮小するか圧縮 PDF にする。
- `FoundationModels` は **実モデル呼び出しを CI でしない**。プロトコル境界でモック。
- 手動 (golden path) は P0-3 のチェックリストに追記し、リリース前にユーザが実機で走らせる。
- スナップショットテスト (P3-2 拡張) は `SNAPSHOT_TESTING_ENABLED=1` 環境変数で
  `verify.sh` から enable／skip を制御する既存運用を踏襲する。
