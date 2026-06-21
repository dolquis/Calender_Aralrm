# Calender_Aralrm 開発ロードマップ

このファイルは Claude Code / OpenAI Codex / その他エージェントが参照するための
**開発仕様兼ロードマップ**です。タスクは優先度（P0 → P3）順、各項目に
**目的 / 対象ファイル / 完了条件 (DoD)** を明記しています。

最終更新: 2026-06-09
対象ブランチ運用: Linear issue から生成されるブランチ名 `dolquis/dev-xx-*` を基本とし、
main へ PR（Linear issue が無い緊急時のみ `feature/<topic>`）。

---

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
- テストは Apple の Swift Testing（`@Test` / `#expect`）で記述。141 件 (20 スイート /
  23 ファイル) 緑。通常の `scripts/verify.sh` では 6 件の snapshot test は
  `SNAPSHOT_TESTING_ENABLED=1` 未指定のため skip。
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
- P2 拡張案 A2 / A3 / A4 + P2-β / P2-γ / P2-δ は未着手。
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

> 追跡: Linear DEV-18（GitHub #29 ミラー）

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

> 追跡: Linear DEV-19（GitHub #30 ミラー）

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

> 追跡: Linear DEV-20（GitHub #31 ミラー）

- **シナリオ**: README §"Testing manually" の 1〜8 を実機で完走。
- **追加で確認**:
  - シミュレータ時計を進めたとき、AlarmKit が **silent / focus を貫通**するか。
  - 祝日インポート（JSON / EventKit 両方）で日付が 1 日もズレないか
    （PR #5 で対応した `CalendarDay` 安定化の回帰テスト）。
  - Deep link `shiftalarm://import?payload=...` で ImportView が開き、差分プレビューが出るか。
- **将来検討**: 上記手順を `docs/release-golden-path.md` としてテンプレ化する案
  （レビュー#2 §3.1）。当面は本セクションを実機検証時に Issue に貼る運用を継続。
- **DoD**: 上記すべて OK のチェックリストを Issue に貼り closed。

### P0-4. AlarmScheduler を protocol / fake 注入可能にする（実装中: DEV-34）

> 2026-05-27 提案書取り込みにより **§P3-7 から昇格**。本文は当セクションを正とし、
> §P3-7 はアンカー兼履歴として最小化する。アルゴリズム / モデル詳細は
> [docs/p2-algorithms.md §7](docs/p2-algorithms.md#7-横断-changepreview-抽象--アラーム診断--shiftalarm-validator) に集約。
>
> 追跡: Linear DEV-34

- **目的**: `AlarmScheduler` の diff-sync 副作用（schedule / cancel の順序、失敗時の
  DB 整合性）をユニットテストで検証可能にし、「新規アラーム登録に失敗したのに古い
  アラームを消してしまう」「cancel に失敗したのに DB 上は消したことにしてしまう」
  などの致命的失敗系を再現テストで縛る。
- **設計方針**:
  - 新規 protocol `AlarmSchedulingClient`:
    ```swift
    public protocol AlarmSchedulingClient: Sendable {
        func schedule(
            id: UUID, fireDate: Date, label: String,
            soundID: String, kind: ScheduledAlarmKind
        ) async throws -> UUID
        func cancel(id: UUID) async throws

        /// AlarmKit に現在登録済みのアラーム ID 集合を返す。§P1-5 診断の
        /// saved-ID vs 実在 ID 突き合わせ（DIAG-U6）に必須。fake は in-memory
        /// 集合を返す。
        func scheduledIDs() async throws -> Set<UUID>

        /// AlarmKit の認可状態（authorized / denied / notDetermined）を返す。
        /// §P1-5 診断の `AlarmKit 権限` チェック（DIAG-U1）が決定論的に
        /// テスト可能になるよう protocol 経由で取得する。`AlarmService` 具体型は
        /// `AlarmManager.shared.authorizationState` を直接呼ぶが、fake は
        /// 任意の状態を返せること。
        func authorizationState() async -> AlarmAuthorizationState
    }
    ```
  - `kind: ScheduledAlarmKind` は **初期は `.main` / `.bedtime` のみ**。
  - `AlarmAuthorizationState` は既存 `Sources/Services/AlarmKit/AlarmAuthorization.swift`
    の enum を再利用（新規追加しない）。
  - `AlarmService` actor を `extension AlarmService: AlarmSchedulingClient {}` で
    準拠させ、`AlarmScheduler` は具体型ではなく protocol を保持する。
  - `App/AppDependencies.swift` での組み立てを更新。
- **安全な同期順序**（cancel 失敗時に旧アラームが孤児化しないことを保証）:
  1. 新しいアラームを `schedule`（失敗時はここで例外、DB 旧 row は無傷）
  2. 旧 ID を `pending_cancel_alarm_kit_ids` に append（**新 ID で上書きする前**）
  3. `current_alarm_kit_id` を新 ID に更新
  4. **ここで `modelContext.save()` を必ず実行**（旧 ID は pending に退避され、
     新 ID は DB に書かれた状態を**ディスク永続化**する。これより前にプロセスが
     落ちても旧 ID が失われない不変条件を守る）。
     - **save が throw した場合のロールバック**: 新 ID は AlarmKit に登録済みだが
       DB のどこにも記録されていない状態（cancel する手段が失われた orphan）に
       なる。これを防ぐため、`save()` 失敗を catch して **直前に schedule した
       新 ID を `alarmClient.cancel(newID)` で取り消してから** 上位に例外を
       rethrow する。
       - **cancel(newID) も失敗した二段失敗の orphan 検出**: 新 ID は AlarmKit
         上に live のまま、DB にはどこにも記録されていない最悪パターン。
         単純な「saved `current_alarm_kit_id` vs `scheduledIDs()`」突き合わせ
         では旧 ID が依然 live なので一致してしまい新 ID の存在を見逃す。
         具体的な対処は次のどちらかを必ず採る:
         - **(a) 集合差分による orphan 検出**: `refreshScheduledAlarms` の
           プロローグで `live = alarmClient.scheduledIDs()` を取得し、
           DB 上の全 `ShiftAlarm.current_alarm_kit_id` ∪
           `pending_cancel_alarm_kit_ids` を合算した DB 既知集合 `known` と
           比較する。`live \ known` は「DB が知らないが AlarmKit には存在
           する」ID で、これらは無条件に `cancel` 対象として除去する
           （冪等で安全）。これによりロールバック失敗で残った新 ID も
           次回 sync で必ず回収される。
         - **(b) 失敗 ID の最小限永続化**: `save()` 失敗の rollback パスでも、
           catch 内で `failedRollbackIDs: [UUID]` の専用列に append + save
           を試みる（この最小 save が失敗したら最後はクラッシュレポートに
           頼る）。次回 sync は `failedRollbackIDs` を pending-cancel と同じ
           扱いで cancel する。
         - 推奨は **(a)**（実装シンプル・追加列なし）。`refreshScheduledAlarms`
           は冪等のままで `live \ known` の余剰 ID 掃除を仕様に組み込む。
       - pending-cancel loop には絶対に入らない（旧 ID は安全、新 ID は
         cancel 済み or (a) で次回回収）。
  5. `pending_cancel_alarm_kit_ids` の各 ID を順次 cancel 試行
  6. cancel が成功した ID のみ pending リストから除去、残りは次回同期で再試行
     （除去結果も `save()` で永続化）
  - 旧 ID を pending リストに退避してから上書きするため、cancel 失敗で DB 上の
    参照を失わない。`refreshScheduledAlarms` は冪等。Step 4 の save を省略すると
    「新 schedule 成功 → cancel 成功 → プロセス kill で save 未到達 → 起動後に
    旧 ID を再 cancel」のような取り違えが起き得るため、cancel ループに入る前の
    save は必須。
  - **bedtime リマインダは独立モデルではなく `ShiftAlarm` の `isBedtimeReminder`
    フラグ付き行として保存されている**ため、追加する列は `ShiftAlarm` 一箇所のみ:
    - `pending_cancel_alarm_kit_ids` を新規列として追加。SwiftData の `[UUID]`
      直接サポートはバージョン依存で App / Widget 共有ストアでの安全性が
      不確実なため、**既存 `RotationPattern.slotsData` と同じ JSON 化方針** で
      永続化する: 列の型は `pendingCancelData: Data`（`JSONEncoder().encode([UUID])`
      の結果）、API 上は computed `pendingCancelIDs: [UUID]` を経由して読み書き
      する。既存 row はマイグレーション時に空 array を JSON 化した `Data` で
      初期化する。
    - **schema version は新規に `SchemaV2` を導入**して App / Widget 共有ストア
      の migration 境界を明示する。`SchemaV1` を後から in-place で書き換えると、
      既に V1 ストアで起動した端末がアップグレード時に「いつの V1 か」を判別
      できず、`@Attribute(originalName:)` rename のメタデータと既存値の対応が
      崩れる。具体的には:
      - `Sources/Domain/Persistence/SchemaV2.swift` を新規追加し、`SchemaV1.models`
        と同じモデル群を履歴版と分離した `SchemaV2.*` として定義したうえで、
        `ShiftAlarm` を本変更後の形に差し替える。
      - `Sources/Domain/Persistence/MigrationPlan.swift`（または等価ファイル）に
        `SchemaV1 → SchemaV2` の lightweight migration stage を登録。
        `@Attribute(originalName: "alarmKitID")` を持つ `current_alarm_kit_id`
        と、`Data` デフォルト値（`Data([0x5b, 0x5d])` = `"[]"`）の
        `pendingCancelData` で SwiftData が自動的に値を引き継ぐ。
      - P0-4 時点の `SharedPersistence.makeContainer()` は
        `Schema(versionedSchema: SchemaV2.self)` を渡し、`MigrationPlan` を
        コンテナ生成オプションに付与する（現在は後続の DEV-35 migration により
        SchemaV3 が active）。
      - 履歴版 `SchemaV1` の列構成は **変更しない**（migration baseline 維持）。
        以降のタスクが更にスキーマを足す場合は active schema の次版
        （DEV-35 完了後は SchemaV4 以降）として段階的に追加する。
      - `/swiftdata-migration` skill を必ず起動し、Widget ターゲットでも V2
        を読めることをビルドで確認する。
    - 既存 `alarmKitID` プロパティを `current_alarm_kit_id` に rename する際は
      **`@Attribute(originalName: "alarmKitID")` を付与**して SwiftData が既存
      ストアの値を引き継ぐようにする。生の rename だと既存 row の AlarmKit ID
      が失われ、アップグレード後に旧アラームの cancel 不可能・診断画面 (§P1-5)
      の saved-ID チェックが空振りする回帰が出る。
    - migration は引き続き lightweight 範囲で完結する（新列 + 既存列のメタデータ
      上の rename のみ）。`BedtimeReminder` という独立 @Model は存在しないので
      作成・migration の追加は不要。
- **追加テスト** (`Tests/ServicesTests/AlarmSchedulerTests.swift` 新規):
  - AS-U1 新規アラーム: schedule のみ呼ばれる
  - AS-U2 変更なし: schedule / cancel なし
  - AS-U3 時刻変更: new schedule → pending append → current update → old cancel の順
  - AS-U4 schedule 失敗時に旧 AlarmKit ID と DB row を維持
  - AS-U5 cancel 失敗時に旧 ID が `pending_cancel_alarm_kit_ids` に残り、次回
    `refresh` で再試行される
  - AS-U6 bedtime reminder と wake alarm が同一 calendar day でも key collision なし
  - AS-U7 skipAlarm: 登録済みなら **pending 経由で cancel**。具体的には:
    1. 旧 ID を `pending_cancel_alarm_kit_ids` に append、
    2. `current_alarm_kit_id` を `nil` にクリア、
    3. **ここで必ず `modelContext.save()`**（cancel ループに入る前に
       「pending に退避 + current=nil」を永続化。process kill しても旧 ID は
       pending に残るので冪等再試行可能）、
    4. pending 内の各 ID を順次 `cancel`、成功した ID のみ pending から
       除去して再 save。
    schedule 付き再登録時の step 1〜6 と同じ "save-before-cancel" 順序を
    cancel-only の expected-set 縮小（skipAlarm 切替 / 祝日 override 追加 /
    rotation 削除など）でも守る。
  - AS-U8 祝日 override: expected set から除外（cancel-only path も
    AS-U7 と同じ save-before-cancel 順序で行う）
  - AS-U9 save-failure rollback: `modelContext.save()` が throw した場合に
    直前の新 ID が `alarmClient.cancel()` され、pending-cancel ループに入らない
    （fake client で `save()` を意図的に throw させ、`cancel` が 1 回だけ
    新 ID 引数で呼ばれることを assert）
  - AS-U9b rollback cancel 失敗: `cancel(newID)` も失敗した場合、次回 refresh の
    `live \ known` orphan 検出で新 ID が回収される
  - AS-U10 既存 `ShiftAlarm` fetch 失敗時: store を読めない状態では orphan sweep /
    diff-sync を行わず、live AlarmKit ID を cancel しない
  - AS-I1 `refreshScheduledAlarms` の操作列を fake で検証
  - AS-M1 pre-P0-4 V1 store migration: 旧 top-level V1 モデルで作成した fixture store の
    既存 `alarmKitID` が `currentAlarmKitID` に引き継がれ、`pendingCancelIDs` は空配列として読める
- **対象ファイル**:
  - 新規 `Sources/Services/AlarmKit/AlarmSchedulingClient.swift`
  - 変更 `Sources/Services/AlarmKit/AlarmService.swift`
  - 変更 `Sources/Services/AlarmKit/AlarmScheduler.swift`
  - 変更 `Sources/Domain/Models/ShiftAlarm.swift`（`pendingCancelData: Data` 列
    追加 / `alarmKitID` → `current_alarm_kit_id` に
    `@Attribute(originalName: "alarmKitID")` 付き rename）
  - 変更 `Sources/Domain/Persistence/SchemaV1.swift`（履歴版モデルを `SchemaV1.*`
    として固定し、V2 の新列と混線しない migration baseline を維持）
  - 新規 `Sources/Domain/Persistence/SchemaV2.swift`（P0-4 時点の現行モデルを
    `SchemaV2.*` として公開。現在は DEV-35 の SchemaV3 が active）
  - 新規 / 変更 `Sources/Domain/Persistence/MigrationPlan.swift`（`SchemaV1 →
    SchemaV2` の lightweight migration stage を登録）
  - 変更 `Sources/Domain/Persistence/ModelContainer+Shared.swift`
    （P0-4 時点で `SharedPersistence.makeContainer()` が
    `Schema(versionedSchema: SchemaV2.self)` と `MigrationPlan` を使うように切り替え）
  - 変更 `App/AppDependencies.swift`
  - 新規 `Tests/Support/FakeAlarmSchedulingClient.swift`
  - **変更（既存ファイル）** `Tests/ServicesTests/AlarmSchedulerTests.swift`
    — 既に `buildResolverInput` を検証する `@Test` 1 件が存在する。新規作成ではなく、
    このファイルへ AS-U1〜AS-U10 / AS-I1 を**追記**する。
- **注意**: Swift 6 strict concurrency 下で actor → protocol 化する際の
  `Sendable` 制約、`@MainActor` な `AlarmScheduler` と fake client の相性。
- **DoD**:
  - **AS-U1 / AS-U2 / AS-U3 / AS-U4 / AS-U5 / AS-U6 / AS-U7 / AS-U8 / AS-U9 /
    AS-U10 / AS-I1 / AS-M1 の全 13 件**（AS-U9 は rollback 成功 / rollback cancel 失敗の
    2 ケース、AS-M1 は SwiftData migration）が `scripts/verify.sh` で緑。
    特に AS-I1 は `refreshScheduledAlarms` の操作列を fake で検証する
    integration テストで、unit のみ緑でも DoD は満たさない（unit と
    integration を両方明記して落とし穴を塞ぐ）。
  - 既存 `AlarmService` 公開 API 非破壊。
  - Swift 6 strict concurrency 下で `Sendable` 警告が増えない。

### P0-5. `.shiftalarm` バリデーション層 ✅ 実装済み (DEV-17)

> 追跡: Linear DEV-17（GitHub #28 ミラー）。参照切れ preset によるアラーム沈黙バグを含む。
> 2026-06-09 実装: `ShiftBundleValidator` を追加し、`ShareImporter.preview` / `apply` 前段で
> 再検証する。

> 2026-05-27 提案書取り込みにより **§P3-9 から昇格**。本文は当セクションを正とし、
> §P3-9 はアンカー兼履歴として最小化する。データモデル詳細は
> [docs/p2-algorithms.md §7](docs/p2-algorithms.md#7-横断-changepreview-抽象--アラーム診断--shiftalarm-validator) に集約。

- **目的**: 外部から渡ってくる `.shiftalarm` JSON について、Codable で構造が読める
  だけでは検出できない **意味的に壊れた値** を弾く層を追加する。共有・バックアップ・
  URL import の **入口での検査** を一本化する。
- **基本方針**:
  - decode 後 / preview 前に必ず validator を通す
  - **重大エラーは全体 reject**、軽微な警告は preview に表示
  - apply 時にも再検証する
  - 将来 version は原則 read-only preview または reject
- **モデル**:
  ```swift
  public struct ShiftBundleValidationResult: Equatable, Sendable {
      public var errors: [ShiftBundleValidationIssue]
      public var warnings: [ShiftBundleValidationIssue]
      public var isValid: Bool { errors.isEmpty }
  }
  public enum ShiftBundleValidationCode: String, Sendable {
      case unsupportedVersion, futureVersion, tooManyItems
      case invalidAlarmHour, invalidAlarmMinute, invalidCycleLength
      case slotCountMismatch, duplicateID, duplicateDate
      case missingPresetReference, textTooLong, invalidColorHex
  }
  ```
- **検査項目（error 区分）**: `version` 対応範囲外 / 将来 version / preset 名 64 文字超 /
  `hour ∉ 0...23` / `minute ∉ 0...59` / `cycleLength ∉ 1...365` /
  `slots.count != cycleLength` / 件数上限超過 / duplicate UUID。
  - **件数上限（`tooManyItems`）はすべての top-level コレクションを対象**:
    暫定値として `presets ≤ 100` / `assignments ≤ 2000` / **`patterns ≤ 50`** /
    **`overrides ≤ 3000`**（祝日 + 有給 + 将来の DOW 展開を見越して大きめ）。
    `ShareImporter.applyPatterns` / `applyOverrides` は配列をそのまま iterate
    して persist するため、上限を設けないと preset / assignment が小さい
    bundle でも `patterns` / `overrides` 側で SwiftData ストアを膨張・停滞
    させ得る。path は `patterns` / `overrides` / `presets` / `assignments`
    の 4 種を返せること。
  - **`hour` / `minute` range 検査は preset の default 値だけでなく、
    `AssignmentDTO.overrideAlarmHour` / `overrideAlarmMinute` も対象**。
    `ShareImporter` は assignment override をそのまま永続化し、`AlarmScheduler`
    が fire date 構築に直接利用するため、ここで `24` / `60` が通ると wrong-day
    alarm / missing alarm の原因になる。path は `presets[N].defaultAlarmHour` /
    `assignments[N].overrideAlarmHour` の両形式を生成する。
- **検査項目（warning 区分）**: note 512 文字超 / 不正 color hex。
- **`missingPresetReference` を error に昇格**: `AssignmentDTO.presetID` が存在し
  ない（参照切れ）かつ `skipAlarm == false` で、完全な
  `overrideAlarmHour` / `overrideAlarmMinute` も無いアサインは error。`ShareImporter`
  が `preset = nil` かつ override 時刻なしの manual `DayAssignment` を素通しすると、
  `DayResolver` はその manual 行を holiday / rotation より優先するため fire date を返さず、
  本来鳴るはずだったローテーション由来のアラームを **暗黙に黙らせる**。`skipAlarm
  == true` のときは意図的に音を出さない指示なので warning に留め、`presetID == nil`
  でも完全な override 時刻があれば custom-time-only alarm として valid にする。
  参照切れ `presetID` でも完全な override 時刻で fire できる場合は warning に留める。
- **`missingPresetReference` は `patterns[N].slots[M]` も対象**: ローテ slot
  内の preset UUID が bundle 内の `presets[]` に存在しない場合も warning として
  preview に出す。`ShareImporter.applyPatterns` は slot を直接 persist するが、
  `DayResolver` は stale slot を低優先度 rotation への fall-through として扱うため、
  アプリ自身が書き出した「preset 削除後の rotation」backup は round-trip 可能にする。
  path は `patterns[N].slots[M]` を生成する。
- **`missingPresetReference` は `overrides[N].replacementPresetID` も対象**:
  holiday / PTO 用 override の代替 preset 参照切れ + `skipAlarm == false` は
  error。`ShareImporter.applyOverrides` は `replacementPresetID` が nil の
  override 行を作り、`DayResolver` はその行を precedence 順で採用するが fire
  date が生成できず、本来の祝日 / 有給代替アラームが沈黙する。`skipAlarm
  == true` のときは「鳴らさない」意図と一致するため warning に降格、
  apply 時に `replacement = nil` の skip 経路として扱う。path は
  `overrides[N].replacementPresetID`。テスト ID **SBV-U12**（override の
  preset 参照切れ + skipAlarm=false で error）と **SBV-U13**（skipAlarm=true
  で warning）を新設。
- **`duplicateDate` を error に昇格**: 同一 `assignments[*].date` または
  `overrides[*].date` が複数回現れる bundle は §P1-6 の conflict resolution UI が出るまで
  一律 error として reject する。現行 `ShareImporter` は new assignment では先勝ち /
  既存 assignment / override は上書きの連発で **deterministic でない部分適用** が起きる。
  P1-6 完了後に warning へ降格し preview で「後勝ち / 先勝ち / スキップ」を選ばせる予定
  （その時点で warning 区分に戻し、判定マトリクスを再更新する）。
- **検査項目（ignore）**: unknown fields（forward compatibility）。
- **UI**: 既存 `ShareImporter` の preview / apply 前段で呼び出し、error がある場合は
  Apply ボタンを disabled にする。`ImportPreviewView` への抽出は §P1-6 で実施。
- **追加テスト** (`Tests/ServicesTests/ShiftBundleValidatorTests.swift`):
  - SBV-U1 正常 bundle は valid
  - SBV-U2 unsupported version は error
  - SBV-U3 preset.defaultAlarmHour 24 は error
  - SBV-U4 preset.defaultAlarmMinute 60 は error
  - SBV-U5 slots.count 不一致は error
  - SBV-U6 duplicate UUID は error
  - SBV-U7 missing presetID は fire 不能なら error / `skipAlarm == true`
    または完全な override 時刻で fire 可能なら warning または valid（境界を検証）
  - SBV-U8 件数上限超過は error
  - SBV-U9 assignment.overrideAlarmHour 24 は error（path に
    `assignments[N].overrideAlarmHour` を含む）
  - SBV-U10 assignment.overrideAlarmMinute 60 は error（同上 path）
  - SBV-U11 duplicate assignment / override date は error（P1-6 完了までは一律 reject）
  - SBV-U12 overrides[N].replacementPresetID 参照切れ + `skipAlarm == false`
    は error
  - SBV-U13 overrides[N].replacementPresetID 参照切れ + `skipAlarm == true`
    は warning
  - SBV-U14 patterns[N].slots[M] の missing preset 参照は warning
  - SBV-I1 Import preview 前に validator が呼ばれる
  - SBV-I2 error ありで Apply ボタン disabled
- **対象ファイル**:
  - `Sources/Services/Sharing/ShiftBundleValidator.swift`
  - 変更 `Sources/Services/Sharing/ShareImporter.swift`
  - `Tests/ServicesTests/ShiftBundleValidatorTests.swift`
  - 変更 `Resources/Localizable.xcstrings`（ja / en の error / warning メッセージ）
- **DoD**:
  - 壊れた bundle を apply できない。
  - 警告は preview で読める。
  - `bash scripts/verify.sh test` で SBV-U1〜U14 / SBV-I1〜I2 を含む 141 tests が緑。
  - 既存正常系 `ShareImporterTests` が壊れない。
  - 参照切れ presetID でクラッシュしない。
  - ja / en ローカライズ済み。

---

## 3. P1 — UX 完成度

> ステータス: **P1-1〜P1-4 は完了**（PR #7 / #8 / #9 / #10、以下は履歴）。
> **P1-5 アラーム診断画面は DEV-35 で実装済み**。P1-6 ChangePreview 共通化は
> 未着手。P1（追補）A1 ドリフト UI 統合は `RotationListView` へ実装済み。

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

### P1-5. アラーム診断画面（実装済み / DEV-35）

> 詳細モデル / アルゴリズムは
> [docs/p2-algorithms.md §7](docs/p2-algorithms.md#7-横断-changepreview-抽象--アラーム診断--shiftalarm-validator) に集約。

- **目的**: ユーザが「次のアラームは本当に鳴るのか」を一目で確認できる画面を追加し、
  ユーザ向けの安心表示と開発者向けのトラブルシュート材料を兼ねる。
- **画面名**: `アラーム診断` / `Alarm Diagnostics`
- **導線**: `SettingsView` の「安全性 / 診断」セクションに追加。可能なら次回
  アラームカードにも `登録済み` / `要確認` / `権限未許可` の小バッジを表示。
- **診断項目（8 種）**:
  - AlarmKit 権限（OK: authorized / NG: critical → 許可リクエスト CTA）。
    取得は `alarmClient.authorizationState()`（§P0-4 protocol 経由）で行い、
    `AlarmManager.shared` への直接依存を避ける。fake client は `.denied` /
    `.notDetermined` / `.authorized` を任意に返せるので DIAG-U1 がテスト時に
    決定論的になる。
  - 次回アラーム登録（**保存 ID が non-nil かつ AlarmKit の scheduled IDs に
    実在する**こと。`alarmClient.scheduledIDs()`（§P0-4 protocol 経由）と
    `current_alarm_kit_id` を突き合わせる。権限喪失・外部 purge・同期失敗で
    AlarmKit 側から消えていても DB 上は残るケースを検出するため、saved ID 単独で
    OK 判定しない。 NG: 今すぐ同期 CTA）
  - 最終同期時刻（24 時間以内 / NG: 今すぐ同期 CTA）
  - App Group（App/Widget 間で読み取り可能 / NG: 詳細を見る）
  - BG Refresh 登録（NG: 再登録）
  - Live Activity 設定値（NG: 設定を開く）
  - HealthKit（任意 / 未許可は warning）
  - 近日の未登録日（next N days に未同期がない / NG: 再同期）
- **状態 4 段階**: `normal` / `warning`（任意機能のみ問題） / `attention`（AlarmKit 登録・
  BG refresh に問題） / `critical`（権限なし、次回アラームなし等）。
- **モデル**: `AlarmDiagnosticsReport` / `AlarmDiagnosticsStatus` / `AlarmDiagnosticsCheck` /
  `AlarmDiagnosticsRecoveryAction`。**永続化なし**（一時値）。
- **AppSettings 追加**:
  - `lastAlarmSchedulerRunAt: Date?`
  - `lastAlarmSchedulerResultRaw: String?` ← 構造化ログ化は §P3-8 と一緒に実施する
    前提で、初期は raw String を許容。
- **依存**: P0-4（AlarmScheduler protocol 化）完了後に着手。
  `lastAlarmSchedulerRunAt` の更新は AlarmScheduler から行う。
- **追加テスト**:
  - DIAG-U1 AlarmKit 権限なしなら critical
  - DIAG-U2 次回アラームなしなら attention 以上
  - DIAG-U3 HealthKit 未許可のみなら warning
  - DIAG-U4 最終同期が 24 時間超なら attention
  - DIAG-U5 すべて OK なら normal
  - DIAG-U6 **DB 上は `current_alarm_kit_id` が non-nil だが
    `alarmClient.scheduledIDs()` に含まれない場合は critical**（権限喪失・外部
    purge シナリオ。Fake client で saved ID と scheduledIDs を意図的にずらして検証）
  - DIAG-I1 「今すぐ同期」CTA で `AlarmScheduler.refresh` が呼ばれる
  - DIAG-I2 SettingsView から診断画面へ遷移できる
- **対象ファイル**:
  - 新規 `Sources/Services/Diagnostics/AlarmDiagnosticsService.swift`
  - 新規 `Sources/Features/Settings/AlarmDiagnosticsView.swift`
  - 変更 `Sources/Features/Settings/SettingsView.swift`
  - 変更 `Sources/Services/AlarmKit/AlarmScheduler.swift`
  - 変更 `Sources/Domain/Models/AppSettings.swift`
  - 新規 `Sources/Domain/Persistence/SchemaV3.swift` /
    `Sources/Domain/Persistence/SchemaV2Models.swift`
  - 新規 `Tests/ServicesTests/AlarmDiagnosticsServiceTests.swift`
- **DoD**:
  - Settings から診断画面を開ける。
  - 次回アラーム、登録件数、最終同期時刻が表示される。
  - AlarmKit 未許可時に明確な CTA が出る。
  - 診断結果が VoiceOver で意味のある順序で読める（既存 P1-2 a11y 監査済みリストに
    追記）。
  - 単体テストで状態判定 5 ケース + DIAG-U6 を網羅する。

### P1-6. ChangePreview 共通化（実装中 / DEV-256 / 2026-06-19 更新）

> 詳細モデルは
> [docs/p2-algorithms.md §7](docs/p2-algorithms.md#7-横断-changepreview-抽象--アラーム診断--shiftalarm-validator) に集約。

- **目的**: `.shiftalarm` import、シフト表画像インポート、ドリフト検出からの
  ローテ更新、A2 DOW ルール展開、A4 長期連休自動グルーピング、将来の CSV import
  などで使える **差分プレビュー基盤** を作る。
- **段階分け（漸進実装）**:
  - **Step 1**: `ShareImporter.swift` 内に埋め込まれているプレビューロジックを
    `Sources/Features/Sharing/ImportPreviewView.swift` として独立ファイルに抽出
    （リファクタのみ・振る舞い不変）。
  - **Step 2**: `ChangePreview` 抽象モデルを新設し `.shiftalarm` import から移行。
  - **Step 3**: 画像インポート / ドリフト UI / DOW ルール展開からも同抽象を利用。
- **モデル**: `ChangePreview` / `ChangeSummary` / `ChangePreviewSection` /
  `ChangePreviewItem` / `ChangeKind { add, update, delete, unchanged, conflict }` /
  `ChangeEntityKind { preset, dayAssignment, rotationPattern, holidayOverride,
  vacationPeriod, dowRule }`。
- **設計留意**: `beforeText` / `afterText` は `String` ではなく **localizable な
  構造化値**（`AttributedString` か `LocalizedStringResource`）を許容できる設計に
  する。
- **UI**: フィルタ（すべて / 追加 / 変更 / 競合 / 警告 / 選択中のみ）と一括操作
  （すべて選択 / 解除 / 競合を除いて選択 / 変更だけ選択）を備える。
- **対象ファイル**:
  - 新規 `Sources/Domain/Models/ChangePreview.swift`
  - 新規 `Sources/Features/Shared/ChangePreviewView.swift`
  - 新規 `Sources/Features/Shared/ChangePreviewRow.swift`
  - 新規 `Sources/Features/Sharing/ImportPreviewView.swift`
  - 変更 `Sources/Services/Sharing/ShareImporter.swift`（抽出後の参照更新）
  - 新規 `Tests/DomainTests/ChangePreviewTests.swift`
  - 新規 `Tests/SnapshotTests/ChangePreviewSnapshotTests.swift`
- **DoD**:
  - `.shiftalarm` import preview が共通 UI へ移行できる。
  - 追加 / 変更 / 競合 / 警告の表示が可能。
  - 選択状態を保持できる。
  - Dynamic Type XL で崩れない。
  - VoiceOver で before / after が読める。
- **進捗 (2026-06-19 / DEV-256)**: Step 1 / Step 2 として
  `.shiftalarm` import 経路を `ChangePreview` / `ChangePreviewView` /
  `ImportPreviewView` に移行中。item 単位の決定論的 ID、選択適用、
  validator warning / conflict 表示、通常 verify で gated される snapshot 入口を追加。
  Step 3（画像 import / ドリフト UI / DOW ルール展開への横展開）は後続 issue で扱う。

### P1（追補）. A1 ドリフト検出 UI 統合（§P2-α A1 を P1 相当に昇格）

> 詳細は §P2-α A1（[L389-407](#p2-α-シフトパターン自動検出--プリセット--ローテ提案--コア実装済み-pr-19)）を参照。
> アルゴリズムは PR #19 で実装済み (`ShiftPatternDetector.detectDrift()`)。
> **2026-05-29 監査で UI 統合も実装済みであることを確認**: `RotationListView` の
> `detectDriftOrPattern(...)` が drift を検出し `PatternSuggestionView` の提案カードとして
> 表示する（専用 View は作らず既存カードに統合）。残作業は **実機 / ビルドでの UI 最終検証
> と DRIFT-* テストの整備のみ**。

- **実装状況**:
  - 実装済み: `Sources/Features/Rotation/RotationListView.swift`（`detectDriftOrPattern`）
    + 既存 `PatternSuggestionView`（専用 `PatternDriftSuggestionView.swift` は不要と判断）
  - 要確認: DRIFT-* テストの有無と Mac でのビルド / UI 検証
- **snooze 設計の精緻化（2026-05-27 追加）**:
  - `AppSettings.patternDriftSnoozedUntil: Date?`
  - `AppSettings.patternDriftSnoozedFingerprint: String?` に **algorithm version
    プレフィックス** を含める。例: `"v1:abc123..."`。アルゴリズム更新時に古い
    fingerprint が誤って snooze 一致しないようにする。
- **追加テスト**: DRIFT-U1〜U5 / DRIFT-I1〜I3（提案書 §8.7 を採用）。
- **旧 pattern は削除せず `isActive = false`** のフラグ運用（提案書 §8.5 ＝
  既存 A1 DoD と一致）。

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
  - 結果は `SuggestedRotation` ではなく `SuggestedDOWRule { id, dayOfWeek,
    weekOfMonth, presetID, observedMatches, confidence }` のリストとして返し
    （`id` は決定論的派生、下記「実装精緻化」参照）、UI 上は通常ローテ提案と
    並列のカードで表示。
  - 受諾時は v1 では **`HolidayOverride`** に展開（週序計算で範囲展開、複数月分を
    一括 insert）。`RecurrenceRule` モデル化はバックログ扱い。
  - **対象ファイル**:
    - 新規 `Sources/Domain/Logic/DayOfWeekPatternDetector.swift`（α 検出器の兄弟）
    - 既存 `Sources/Features/Rotation/RotationListView.swift` に DOW 提案カードを追加
  - **実装精緻化（2026-05-27 追加）**:
    - `SuggestedDOWRule` を `{ id, dayOfWeek, weekOfMonth, presetID?,
      observedMatches, confidence }` 形に確定（`confidence: Double` 追加）。
      **`id: UUID` は決定論的派生**（`(dayOfWeek, weekOfMonth, presetID)` を
      入力として `SHA256` 先頭 16 byte で生成、詳細は
      [docs/p2-algorithms.md §1.10](docs/p2-algorithms.md#110-曜日週序検出) 参照）。
      同じ入力からは常に同じ ID を生成しないと、後続の `HolidayOverride
      .expandedFromRuleID = rule.id` 永続化がルール再検出のたびに別 UUID を
      持つことになり、§P3-15 で `RuleExpandedOverride` に分離する migration
      で「元の規則 → 展開行」の対応が壊れる。
    - 検出設定を構造体化:
      ```swift
      public struct DayOfWeekPatternDetectorConfiguration: Sendable {
          public var windowDays: Int = 90
          public var minDensity: Double = 0.6
          public var minMatchRate: Double = 0.85
          public var minObservedMatches: Int = 2
      }
      ```
    - 初期実装範囲は `weekday + weekOfMonth` のみ。`lastWeekOfMonth`（毎月最終週）は
      Phase 2 として後送。
    - 受諾フローは **§P1-6 `ChangePreview` を経由**してから `HolidayOverride` へ
      展開。既存手動割当は上書きしない。
    - **展開件数が増えやすい懸念**（6 ヶ月分の `HolidayOverride` 大量追加）に対し、
      専用テーブル化（`RuleExpandedOverride`）は §5 P3 バックログとして追加検討。
    - **v1 出荷時に provenance 列の追加を必須化**: `HolidayOverride` に
      `expandedFromRuleID: UUID?` と `expandedAt: Date?` の 2 列を **A2 と同じ
      PR で** 追加する。これが無いとユーザの手動 override と A2 自動展開行が
      テーブル上区別できず、後日 §P3-15 で `RuleExpandedOverride` を分離する
      migration が安全に実装できない（手動データを巻き込む / 取りこぼすリスク）。
      SwiftData lightweight migration の範囲で完結する（nullable 2 列追加 / 既存
      row は両方 `nil` で初期化）。`/swiftdata-migration` skill を必ず起動。
    - **`.shiftalarm` 共有バンドルにも provenance を載せる**: SwiftData 列を
      追加するだけでは export → import 経路で provenance が失われ、
      再 import 後は全 A2 由来行が `expandedFromRuleID = nil` 扱いになって
      手動 override と区別不能になる（§P3-15 migration の前提が壊れる）。
      A2 と同じ PR で次のいずれかを併せて実装:
      - **(a) DTO 拡張（推奨）**: `OverrideDTO` に `expandedFromRuleID:
        UUID?` と `expandedAt: Date?` をオプショナルに追加。古い `.shiftalarm`
        は両 field 欠落 = `nil` decode で後方互換、新 bundle は両 field を
        export/import で往復する。`ShiftBundleValidator` 側は ignore する
        unknown field 扱いではなく **正規 field** として認識（forward
        compat ポリシーは §P0-5 のとおり）。
      - **(b) 共有時除外**: A2 由来行（`expandedFromRuleID != nil`）は
        `ShareExporter` で export 対象から落とし、`SuggestedDOWRule`
        自体を別 DTO として export する。受け取り側は再展開で復元。
      - 初期実装は (a) を採用し、`OverrideDTO` の `expandedFromRuleID` /
        `expandedAt` を `Codable` default-`nil` で導入する。
      Widget の SwiftData container も同 schema を共有するため、Widget 側ビルド
      でも参照可能であることを確認すること。
  - **テスト ID**:
    - DOW-U1 第 1・第 3 金曜を検出
    - DOW-U2 観測 1 件では検出しない
    - DOW-U3 matchRate 不足では検出しない
    - DOW-U4 off も検出可能
    - DOW-U5 複数ルールを返せる
    - DOW-I1 受諾で 6 ヶ月分展開
    - DOW-I2 手動割当は上書きしない
    - DOW-I3 差分プレビューを経由
  - **DoD**:
    - 第 1・第 3 金曜のみ夜勤の履歴で 2 つの `SuggestedDOWRule` が返る。
    - 観測 1 件など低密度パターンは検出されない。
    - α 周期検出と DOW 検出が同入力で並走し、両ヒット時は両カードが出る。
    - 受諾前に該当日を `ChangePreview` で確認できる。
    - 既存の手動割当を壊さない。

- **A5. 提案 UX フィードバック計測（派生 / 未着手）**

  - **目的**: 提案カードの受諾率 / 却下（スヌーズ）率 / 受諾後ドリフト到達率を
    ローカル匿名集計し、しきい値（`minMatchRatio` / `minOccupancyRatio` /
    `patternDriftThreshold`）の調整サイクルを回す。レビュー#2 §4.3 が出典。
  - **対象ファイル**:
    - 既存 `Sources/Domain/Models/AppSettings.swift` に集計カウンタ
      （`patternAccepted: Int`, `patternRejected: Int`,
      `patternDriftAccepted: Int`, `lastResetAt: Date?`）を追加
    - 既存 `Sources/Features/Rotation/RotationListView.swift` の提案カード
      ハンドラから受諾 / 却下時にカウンタ更新
    - 既存 `Sources/Features/Settings/` 配下に閲覧・リセット UI を追加
  - **明示制約**: クラウド送信なし。analytics SDK は追加しない（プライバシー /
    AlarmKit バックグラウンド要件のため）。
  - **DoD**:
    - 受諾 / 却下 / ドリフト受諾の各イベントが永続化される。
    - Settings から現在値を閲覧でき、ワンタップでリセットできる。
    - リセット操作は `lastResetAt` を更新する。

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
- **実装精緻化（2026-05-27 追加）**:
  - `CrossVacationPolicy` を **Int rawValue** Codable enum で固定:
    ```swift
    public enum CrossVacationPolicy: Int, Codable, CaseIterable, Sendable {
        case invert = 0
        case `continue` = 1
        case resetToDay = 2
    }
    ```
  - `VacationPeriod` は **独立 @Model** とし、`HolidayOverride.isVacationGroup`
    フラグは「`VacationPeriod` 由来か否かのマーカー」としてのみ使う。
    `HolidayOverride` 自体の責務は単日 override に維持する。
  - **3 日未満の VacationPeriod は作成不可**。**UI バリデーションだけでなく、
    `VacationPeriod` の throwing initializer または専用 factory（例: `static func
    make(...) throws -> VacationPeriod`）の中でも同じ不変条件を強制する**。理由:
    `RotationExpander` / `DayResolver` は永続化された `VacationPeriod` を
    アラーム抑制範囲として無条件に扱うため、自動グルーピング (β-S2 / β-S3) や
    将来の `.shiftalarm` import / App Intents / テストヘルパなど他の write path
    から 1〜2 日の `VacationPeriod` が混入すると、本来鳴るはずの 1〜2 日分の
    ローテーション・アラームを **暗黙に黙らせる** 事故が起き得る。invariant
    違反は `VacationPeriodError.tooShort(days: Int)` を throw し、UI 側は
    既存の入力検証メッセージに繋ぐ。同じ不変条件をテスト ID **VAC-U10**
    （初期化時 / domain factory 側で 2 日範囲が reject される）として
    P2-β テスト群に追加すること。
  - **Widget の SwiftData container も最新スキーマを読むこと**を migration 時に
    確認（App と Widget で同じ App Group store を共有しているため）。
    `/swiftdata-migration` skill 必須。**DEV-35 完了時点で SchemaV3 が active** のため、
    P2-β は **SchemaV4 以降を新規追加** し、`MigrationPlan` に
    `SchemaV3 → SchemaV4` stage を登録する形で `VacationPeriod`
    + `RotationPattern` / `ShiftPreset` 列追加を載せる。SchemaV2 に追記する
    形にすると、既に V2 / V3 で起動した端末にスキーマ baseline
    の不整合が生じる。`Sources/Domain/Persistence/SchemaV4.swift` を新規追加し、
    `SharedPersistence.makeContainer()` の `Schema(...)` 引数も SchemaV4 に
    切り替える。
  - 連休内の日付は **手動割当を優先**（既存 DayResolver 優先順位
    `手動 > 祝日/有休/連休 > ローテ > なし` を維持）。
- **テスト ID**:
  - VAC-U1 連休なしなら既存 `RotationExpander` と同じ
  - VAC-U2 連休中は nil
  - VAC-U3 手動割当は連休より優先
  - VAC-U4 invert で半周期ずれる
  - VAC-U5 continue で連休日数が周期から除外される
  - VAC-U6 resetToDay で昼勤スロットへ揃う
  - VAC-U7 複数連休の補正が累積する
  - VAC-U8 年末年始を跨いでも日付ズレしない
  - VAC-U9 3 日未満の `VacationPeriod` は **UI 入力検証** で reject される
    （フォーム / 確認ダイアログ層）
  - VAC-U10 3 日未満の `VacationPeriod` は **domain factory / throwing init**
    でも reject される（`VacationPeriodError.tooShort` を throw）。
    自動グルーピング (β-S2 / β-S3) / `.shiftalarm` import / App Intents /
    テストヘルパなど UI を経由しない write path をすべてカバーするための
    invariant。
  - VAC-I1 HolidayManager から連休登録できる
  - VAC-I2 登録後に AlarmScheduler の expected set が変化する
- **DoD**:
  - 既定 (`.invert`) で連休前夜勤 → 連休 → 昼勤、が再現できる。
  - `.continue` policy で連休前と同じ位相が維持される。
  - `.resetToDay` で常に昼勤始まりになる。
  - SwiftData マイグレーション後、既存 `HolidayOverride` は破壊されない。
  - 3 日未満の連休登録が UI で弾かれる。
  - Widget の next-alarm timeline も連休を考慮した結果になる。

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
  - 新規 `Sources/Domain/Models/ShiftSymbolMapping.swift`（Phase 1 で必須。
    上記「永続化先」参照）
  - 変更 `Sources/Domain/Persistence/Schema*.swift`（**P2-γ Phase 1 着手時点で
    `SharedPersistence.makeContainer()` が読んでいる最新スキーマ版** の
    `models` 配列に `ShiftSymbolMapping.self` を追加。`AppDependencies.swift`
    ではなくここが App / Widget 共有 `ModelContainer` の単一エントリポイント。
    `SharedPersistence.makeContainer()` が `Schema(<最新版>.models)` を構築する。
    DEV-35 完了時点で `SchemaV3` が active。P2-γ Phase 1 が着手される頃には
    P2-β などの先行 migration により更に進んでいる可能性がある。`SchemaV1` を
    後から書き換えると migration baseline が変わって既存ユーザストアが壊れるので、
    **履歴版 (V1/V2/...) は触らず、現行 active 版の次版に追加する**。Phase 1 着手 PR
    の冒頭で `SharedPersistence` の `Schema(...)` 呼び出しを grep して active 版を
    特定すること。
  - 既存の Import/Export 画面から「画像から取り込む」導線を追加
  - `App/Info.plist`: `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` を追加
  - テスト: 新規 `Tests/ServicesTests/ShiftImageParserTests.swift`
    （`Resources/TestFixtures/` にサンプル画像を置き、構造抽出が安定するか確認）。
    FoundationModels 部分は **プロトコル境界でモック**。
- **実装精緻化（2026-05-27 追加） — Phase 順序入れ替え**:
  - 評価時に「Vision OCR は日本語縦書き・手書き勤務表で精度が出にくい / グリッド
    推定は本番品質まで持っていくのに大工数」という指摘を反映し、**OCR 抜きでも
    動く土台 (手動グリッド + 記号マッピング) を先行**させる Phase 構成へ再整理:
    - **Phase 1 — 手動グリッド + 記号マッピング**（OCR なしでも完成形）:
      - ユーザが画像から表範囲・日付行・データセルをタップで指定
      - `ShiftSymbolMapping { symbol, presetID?, skipAlarm, lastUsedAt }` を保存
        し、次回以降は自動適用
      - 差分プレビューは §P1-6 `ChangePreview` を経由
      - 「OCR が読めなかった時のフォールバック UX」がこの Phase で常時利用できる
        状態になる
      - **永続化先**: `ShiftSymbolMapping` を **SwiftData の `@Model` として
        新規追加**（`Sources/Domain/Models/ShiftSymbolMapping.swift`）。`symbol`
        は string PK 相当（`@Attribute(.unique)`）、`presetID` は `ShiftPreset` 
        への optional 参照、`skipAlarm: Bool`、`lastUsedAt: Date`、`createdAt: Date`。
        AppSettings に格納するシングルトン KV ではなく独立テーブルにすることで、
        記号ごとの最終利用時刻で並べ替えたり破棄したりするクエリが素直に書ける。
        **`Sources/Domain/Persistence/Schema*.swift` のうち、`SharedPersistence
        .makeContainer()` が現に `Schema(...)` 引数として渡している最新スキーマ
        版の次版** の `models` 配列に `ShiftSymbolMapping.self` を追加して、App /
        Widget 共有 `ModelContainer` が新モデルを認識するようにする。**履歴版
        (`SchemaV1` / `SchemaV2` 等) は migration baseline を保つため触らない**。
        DEV-35 で SchemaV3 が導入されているため、P2-γ Phase 1 着手時点では
        SchemaV3 以降が active になっている前提で着手前に grep で確認する。
        `/swiftdata-migration` skill を必ず起動。Widget 側ビルドで model 解決でき
        ることを確認する（参照しないが schema に存在することは必要）。IMG-U1
        「mapping が保存される」テストは Phase 1 PR 内で SwiftData store を経由
        した read-back で検証する。
    - **Phase 2 — Vision OCR 自動抽出**:
      - `OCRTextRecognizer` / `ShiftTableGridDetector` 追加（既存 P2-γ 本文の
        `ShiftImageOCR` / `ShiftImageParser` がここに相当）
      - 信頼度判定 `high` / `medium` / `low` を `ShiftImportConfidence` で持つ。
        low セルは未選択で Phase 1 の手動フローへ落ちる
    - **Phase 3 — FoundationModels 補助**:
      - iOS 26 `FoundationModels` でラベル意味マッピング補助 + 勤務表形式推定
      - 利用不可機種ではルールベースに fallback（既存 DoD どおり）
  - 主要勤務記号の例: 早 / 日 / 遅 / 夜 / 明（alarm なし） / 休（alarm なし） /
    有（alarm なし）。
  - プライバシー初回明示: 「画像解析は端末内で行われます。勤務表の画像は外部
    サーバーへ送信されません。」
- **テスト ID（提案書 §10.14 採用）**:
  - IMG-U1 勤務記号 mapping が保存される
  - IMG-U2 unknown symbol は未確定になる
  - IMG-U3 休 / 明は skipAlarm になる
  - IMG-U4 低信頼度セルは未選択
  - IMG-U5 同じ日付の重複は conflict
  - IMG-I1 画像解析後に差分プレビュー表示
  - IMG-I2 Apply で DayAssignment 作成
  - IMG-I3 既存手動割当との競合表示
  - IMG-S1 Mapping UI snapshot
  - IMG-S2 Preview UI snapshot
- **DoD**:
  - 月次シフト表サンプル（昼/夜/休 3 種ラベル）から 80% 以上のセルが正しく抽出される
    （ja / en サンプル各 1 セット、Phase 2 達成時点で評価）。
  - **Phase 1 単独でも、画像 + 手動グリッド指定 + 記号マッピングで完結する**
    （OCR が完全に失敗しても利用可能）。
  - 抽出結果は §P1-6 `ChangePreview` でレビューしてから適用できる。
  - FoundationModels が利用不可な OS / 機種でもルールベース fallback で動作する。
  - **クラウド通信は発生しない**（プライバシー / ネット非依存）。
  - 不確実なセルは自動適用されない。
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
>
> 追跡: Linear DEV-281（team Dev / project Shift Alarm / Backlog / P2）。

- **目的**: 同僚と勤務を交換した日でも **正しいシフトのアラームが鳴る** ことを保証する。
  「火曜の昼勤を A に代わってもらった / 水曜の夜勤を代わってあげた」を 1 操作で記録し、
  対象日の `DayAssignment` を更新、`AlarmScheduler` の diff-sync を発火する。
- **対象シナリオ**:
  1. **被代行 (off)**: 自分が出勤予定だった日を同僚に代わってもらう → 当日のアラームを
     ミュート（`skipAlarm = true`）し、`SwapRecord` に「A に代行依頼」を残す。
  2. **代行 (on)**: 自分が休み予定だった日に同僚の代わりに出勤する → 当日のプリセットを
     出勤シフトに上書きし、アラーム登録。
  3. **同時スワップ (exchange)**: 1 + 2 を同じ操作で記録。
- **データモデル（active schema → 次版）**:
  - 新規 `@Model SwapRecord { id, date, kind: .covered|.covering|.exchange,
    counterpartyLabel: String, note: String, createdAt }`。
  - `DayAssignment` には **フィールド追加なし**。出勤 / 欠勤は通常の `DayAssignment` で
    表現し、`SwapRecord` はメタデータ専用。
  - これにより `DayResolver` / `AlarmScheduler` は **完全に無改変**（既存の手動優先パス
    がそのまま機能する）。
- **対象ファイル**:
  - 新規 `Sources/Domain/Models/SwapRecord.swift`（SwiftData @Model、次版 schema）
  - 新規 `Sources/Domain/Persistence/SchemaV*.swift` + 既存 `MigrationPlan` 拡張
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

### P2-ε. 日付一括選択 → プリセット一括適用 → パターン検出（未着手 / 設計確定 2026-06-14）

> 詳細仕様・DoD・テスト ID は [docs/p2-bulk-preset-apply.md](docs/p2-bulk-preset-apply.md) が正典。
> 追跡: Linear [DEV-200](https://linear.app/dolquis/issue/DEV-200)（team Dev / project Shift Alarm / Backlog / P2）。

- **目的**: 「日付を選ぶ → 1 日ずつ適用」を逆転し、**プリセットを選んで複数日をまとめて塗り、
  一括適用**する。塗った日列が周期を成せば「ローテとして他の日付にも適用しますか？」を提案。
- **確定方針**: 塗る→一括適用（**プレビュー確定型**）/ 検出パターンは **ローテ登録を主＋範囲限定も選択可**。
- **再利用**: [ShiftPatternDetector](docs/p2-algorithms.md#1-p2-α--シフトパターン自動検出)（検出）/
  `RotationExpander` / `RotationListView` 受諾ロジック。新規アルゴリズムは増やさない。
- **前提**: §P1-6 `ChangePreview` 共通化（一括適用は Apply 前に必ず経由）。未完時は暫定確認シートで代替。
- **対象ファイル / 段階 / テスト ID / DoD**: docs を参照（Phase 1 一括適用 → Phase 2 検出提案 → Phase 3 選択補助）。

### P2-ζ. 祝日のアラーム制御（全体／個別）＋カレンダー可視化（未着手 / 設計確定 2026-06-14）

> 詳細仕様・DoD・テスト ID・マイグレーションは [docs/p2-holiday-alarm-control.md](docs/p2-holiday-alarm-control.md) が正典。
> 追跡: Linear [DEV-201](https://linear.app/dolquis/issue/DEV-201)（team Dev / project Shift Alarm / Backlog / P2）。
> **スキーマ変更を伴う。着手時は `/swiftdata-migration` skill を起動**（App / Widget 双方の ModelContainer 確認）。

- **目的**: 祝日のアラームを **全体一括／個別**に鳴らす・鳴らさない選択。祝日と鳴動可否をカレンダーで可視化。
- **確定方針**: 既存 `skipAlarm=true`→`inherit` 移行＋全体既定 `silence`（現挙動不変、全体トグルで全祝日鳴動）/
  祝日表示は常時オーバーレイ、実効は明示取り込み or 先読み窓の自動 materialize。
- **モデル**: `HolidayAlarmBehavior {inherit, ring, silence}`、`AppSettings.holidayAlarmDefaultRaw`、
  `HolidayOverride.alarmBehaviorRaw`。**次版スキーマの追加列 + 遅延 backfill**（lightweight 維持、custom 破壊的移行は非推奨。
  版番号は DEV-35 で導入済みの SchemaV3 以降と調整し、次の未使用版番号を使う）。
- **互換**: `.shiftalarm` Override DTO に `alarmBehavior` を Codable default-nil 追加（旧 bundle は `skipAlarm` 読み替え）。
- **解決**: `DayResolver` の祝日分岐で `inherit` を全体既定に解決。優先順位 手動 > 祝日 > ローテ は不変。
- **対象ファイル / 段階 / テスト ID / DoD**: docs を参照（**Phase 1 = 三値＋全体既定＋移行＋先読み窓の auto-materialize
  ＋全体既定変更の確認ダイアログ（暫定可・preview-before-mutation）**〔materialize=未取り込み祝日がローテへ落ちて鳴るのを防ぐ／
  確認=多数の祝日を無確認で反転させない、いずれも必須〕→ Phase 2 = 確認の共有 ChangePreview 統合 ＋ materialize 最適化）。

---

## 5. P3 — 品質・運用

> 開発環境ハードニング backlog（P3-6〜P3-14）の進捗追跡は Linear DEV-21（GitHub #32 ミラー）に集約。
> 各タスクの詳細仕様は以下の各節が引き続き唯一の正。

### P3-1. テスト拡充 ✅ 完了 (PR #7 / #10 / #11)

- 追加済み:
  - `Tests/DomainTests/DayResolverInputBuilderTests.swift` — SwiftData から resolver input への変換。
  - `Tests/ServicesTests/ShareImporterTests.swift` — 差分プレビューと apply。
  - `Tests/ServicesTests/DeepLinkRouterTests.swift` — URL → import flow。
  - `Tests/ServicesTests/BGRefreshControllerTests.swift` — refresh task request / submit seam。
  - `Tests/ServicesTests/SleepIntentHelperTests.swift` — App Intents 用 sleep window 取得。
  - `Tests/ServicesTests/SleepSampleWriterTests.swift` — HealthKit 書込み対象 window 抽出。
  - `Tests/DomainTests/SleepWindowResolverTests.swift` — bedtime 計算 / 端境ケース。
- 現状: Swift Testing で 20 スイート / 141 テスト緑（うち 6 件 snapshot は通常 verify では skip）。

### P3-2. UI / スナップショットテスト（一部着手）

> 追跡: Linear DEV-282（team Dev / project Shift Alarm / Backlog / P3）。

- 対象: `Tests/UITests/`（新規ターゲット）
- 主要画面の light/dark / Dynamic Type 3 サイズ × ja/en のスナップショット。
- 進捗: `Tests/SnapshotTests/DayCellViewSnapshotTests.swift` で DayCell の light / dark /
  祝日 / out-of-month / Dynamic Type XL を追加済み。通常 verify では skip し、
  `SNAPSHOT_TESTING_ENABLED=1` で記録 / 検証する。
- **DoD**: スナップショット差分が CI で検出される。

### P3-3. TestFlight 自動配布（未着手）

> 追跡: Linear DEV-283（team Dev / project Shift Alarm / Backlog / P3。`gate:human-required`、DEV-19 ブロック）。

- 対象: `.github/workflows/release.yml`（新規）
- タグ `v*` プッシュで Archive → App Store Connect API → TestFlight。
- **DoD**: タグ 1 個で TestFlight に届く。

### P3-4. クラッシュ / ログ収集（未着手）

> 追跡: Linear DEV-284（team Dev / project Shift Alarm / Backlog / P3。P3-8 構造化ログと整合）。

- 軽量に: `os.Logger` のサブシステム整理 + MetricKit 取り込み。
- 外部 SDK は避ける（プライバシー / AlarmKit のバックグラウンド要件のため）。

### P3-5. Swift Testing 移行（✅ 完了 — 既に Swift Testing 採用済み）

> 2026-05-29 監査で判明: `Tests/` 配下は **既に全件 Apple Swift Testing
> （`import Testing` / `@Test` / `#expect`）で記述済み**であり、XCTest は使用していない。
> 本タスクは実質完了。以下は移行内容の履歴注記。

- **目的（達成済み）**: XCTest 相当のテストを Apple の Swift Testing（`@Test`）で記述し、
  `#expect` / `#require` ベースの表現力と並列実行を得る。
- **現状**: `Tests/` 配下 23 ファイル / 20 テストスイート（`struct` + `@Test`） /
  141 テスト関数。`XCTestCase` サブクラスは 0。`@testable import ShiftAlarm` を維持。
  `project.yml` のテストターゲット定義は変更不要（Swift Testing はツールチェーン同梱）。
- **採用済みの対応**:
  - `XCTestCase` サブクラス → `struct` + `@Test` 関数。
  - `XCTAssertEqual` / `XCTAssertTrue` 等 → `#expect(...)`、`XCTUnwrap` → `#require(...)`。
  - snapshot ゲートは `SNAPSHOT_TESTING_ENABLED=1` 指定時のみ有効（`DayCellViewSnapshotTests`
    の 5 テスト）。`@MainActor` / `async` テストもそのまま動作。
- **残作業**: なし（新規テストも Swift Testing で書くこと）。

### P3-6. 依存バージョン固定（`Package.resolved` 追跡）（未着手）

> 根拠: 第三者レビュー#1 §4.1

- **目的**: `swift-snapshot-testing` 等 SPM 依存の解決バージョンを git に固定
  し、新規 clone / CI / 将来 Xcode 更新でも同一バージョンを保証する。snapshot
  test は微差分に敏感なため特に有効。
- **対象**:
  - `.gitignore`: `Package.resolved` の除外を解除
  - 追跡対象（実装時に `xcodebuild -resolvePackageDependencies -project
    ShiftAlarm.xcodeproj -scheme ShiftAlarm` で生成位置を確認）:
    `ShiftAlarm.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- **DoD**:
  - 新規 clone 直後の CI / ローカル `verify.sh` で同一バージョンが解決される。
  - snapshot test の差分が依存解決揺らぎで増えない。

### P3-7. AlarmScheduler を protocol / fake 注入可能にする → **§P0-4 へ昇格 (2026-05-27)**

> 2026-05-27 仕様提案書取り込みにより **§2 P0-4 に昇格**。本項は履歴アンカーとして
> 残す。実装着手は §P0-4 を正とする（テスト ID / 詳細設計が拡張されている）。
>
> 根拠: 第三者レビュー#1 §4.4

- **目的**: `AlarmScheduler` の diff-sync 副作用（schedule / cancel の順序、失敗
  時の DB 整合性）をユニットテストで検証可能にする。現状は actor `AlarmService`
  が `AlarmManager.shared` を直叩きするため fake 化できない。
- **設計方針**:
  - 新規 protocol を導入:
    ```swift
    public protocol AlarmSchedulingClient: Sendable {
        func schedule(id: UUID, fireDate: Date, label: String, soundID: String)
            async throws -> UUID
        func cancel(id: UUID) async throws
    }
    ```
  - `AlarmService` actor をこの protocol に準拠させ、`AlarmScheduler` は具体型
    ではなく protocol を受け取る形へ変更。
  - `App/AppDependencies.swift` での組み立てを更新。
- **追加テスト案** (`Tests/ServicesTests/AlarmSchedulerTests.swift`):
  - 新規アラームのみ schedule される
  - 時刻変更時に **new schedule → old cancel** の順になる
  - schedule 失敗時に旧 AlarmKit ID と DB row を維持する
  - cancel 失敗時に DB row を delete しない
  - bedtime reminder と wake alarm が同一 calendar day でも key collision しない
- **注意**: Swift 6 strict concurrency 下で actor → protocol 化する際の
  `Sendable` 制約、`@MainActor` な `AlarmScheduler` と fake client の相性。
- **DoD**: 上記 5 系統が `scripts/verify.sh test` で緑、`AlarmService` の既存
  公開 API は破壊しない。

### P3-8. AlarmScheduler 構造化ログ（未着手）

> 根拠: 第三者レビュー#2 §3.2

- **目的**: 「鳴らなかった」系の障害解析を Console.app から行えるようにする。
  P0-3 実機検証時の切り分け速度も上がる。
- **方針**:
  - `os.Logger`（サブシステム = bundle id、カテゴリ = `AlarmScheduler` /
    `AlarmService`）で次を出力:
    - スケジュール対象件数 / 追加・更新・削除件数
    - 失敗理由（権限 / API 失敗 / validation エラーの分類）
  - **個人情報を含めない**: preset 名・時刻はマスク or hash で出す。
  - Debug は詳細、Release は集約のみ。
- **対象**:
  - `Sources/Services/AlarmKit/AlarmScheduler.swift`
  - `Sources/Services/AlarmKit/AlarmService.swift`
- **DoD**: Console.app でフィルタリングして diff-sync 1 回ぶんの結果を把握
  できる。

### P3-9. `.shiftalarm` import バリデーション層 → **§P0-5 へ昇格 (2026-05-27)**

> 2026-05-27 仕様提案書取り込みにより **§2 P0-5 に昇格**。本項は履歴アンカーとして
> 残す。実装内容は §P0-5 を正とする（`ShiftBundleValidationCode` enum / error vs
> warning 区分 / テスト ID が確定している）。
>
> 根拠: 第三者レビュー#1 §4.5

- **目的**: 外部から渡ってくる `.shiftalarm` JSON について、Codable で構造が
  読めるだけでは検出できない「意味的に壊れた値」を弾く層を追加する。
- **対象ファイル**:
  - 新規 `Sources/Services/Sharing/ShiftBundleValidator.swift`
  - 既存 `Sources/Services/Sharing/ShareImporter.swift` の preview / apply の
    前段で呼ぶ
  - テスト: 新規 `Tests/ServicesTests/ShiftBundleValidatorTests.swift`
- **検査項目**:
  - `version` が対応範囲内
  - preset 名 / note の最大長
  - `defaultAlarmHour ∈ 0...23`、`defaultAlarmMinute ∈ 0...59`
  - `cycleLength > 0`、`slots.count == cycleLength`
  - import 件数上限
  - 参照 presetID の存在
  - duplicate UUID / duplicate date の扱い
- **仕様判断（実装 PR でユーザに確認）**:
  - invalid bundle を全体 reject するか、一部だけ skip + warning か
  - unknown version は reject か、future version は read-only preview を許すか
  - 参照先 preset が無い assignment は `preset = nil` で受け入れるか、reject か
- **DoD**: 上記検査がテストで網羅され、既存の正常系 `ShareImporterTests` が
  壊れない。

### P3-10. `.shiftalarm` / `.ics` ラウンドトリップ & 境界プロパティテスト（未着手）

> 根拠: 第三者レビュー#2 §3.3

- **目的**: 共有フォーマットの破壊的変更を早期検出し、locale / timezone を跨ぐ
  日付境界での 1 日ズレを防ぐ。
- **追加テスト**:
  - `ShiftBundleCodec` の encode → decode 不変条件
  - locale / timezone 差異を跨ぐ日付境界ケース（年末年始、夏時間境界）
  - 既知の legacy フィールド欠落 / 追加耐性
  - `ICSExporter` の TZ 境界網羅（既存 `η-U7` の拡張）
- **対象**:
  - 既存 `Tests/ServicesTests/ShareImporterTests.swift` を拡張
  - 既存 `Tests/ServicesTests/ICSExporterTests.swift` を拡張
  - 新規 `Tests/Support/MinimalCounterExample.swift`（失敗時に最小反例を吐く
    helper）
- **DoD**: 上記境界ケースで日付が 1 日ズレないことが確認できる。

### P3-11. SwiftData スキーマ変更ガード（CI 軽量チェック）（未着手）

> 根拠: 第三者レビュー#2 §4.1

- **目的**: `SchemaV*.swift` への non-optional 追加・rename を PR 前に検知し、
  migration 対応忘れを防ぐ。
- **対象**:
  - 新規 `scripts/check-schema.sh`（`git diff` ベースの軽量 grep）
  - 既存 `.github/workflows/ios.yml` の verify job 後段に組み込み
- **DoD**: 意図しない破壊的変更を含む PR で CI が警告 / fail する。

### P3-12. Localizable.xcstrings ja / en 整合チェック（未着手）

> 根拠: 第三者レビュー#2 §4.2

- **目的**: 片言語のみへの key 追加を CI で防ぐ。
- **対象**:
  - 新規 `scripts/check-l10n.sh`（`Resources/Localizable.xcstrings` の JSON を
    パースし ja / en の key 集合差分を出す）
  - `scripts/verify.sh` から `VERIFY_L10N=1` 指定時のみ走らせる任意フック
- **DoD**: ja 側のみ更新した PR で CI が片落ち key を列挙する。

### P3-13. Release ビルドでの設定 fallback 厳格化（未着手）

> 根拠: 第三者レビュー#1 §4.7

- **目的**: Release ビルドで `AppRuntimeConfiguration` が Info.plist の
  プレースホルダ (`$(...)`) や空値に落ちた状態をユーザが気づかずに配布する事故
  を防ぐ。`p0-readiness.sh` と二重チェックになることを許容する。
- **方針**: Debug は現状の fallback を継続。Release はプレースホルダ検出時に
  **OSLog で重大ログ + 非破壊**（即 crash の `preconditionFailure` は採用
  しない）。
- **対象**:
  - 既存 `Sources/Shared/Extensions/AppRuntimeConfiguration.swift`
  - テスト: 既存 `Tests/ServicesTests/AppRuntimeConfigurationTests.swift` に
    Release fallback の検証を追加（compile flag で経路を切替）
- **DoD**: Release ビルドでプレースホルダが残った場合に Console.app の重大
  ログから確認できる。

### P3-14. CI / 開発環境衛生（未着手 / サブ項目あり）

> 根拠: 第三者レビュー#1 §4.6 / §4.8 / §4.9 / §4.10、第三者レビュー#2 §5

- **a) `UIBackgroundModes.processing` 要否再確認**: `BGProcessingTaskRequest`
  が未使用なら `App/Info.plist` から `processing` を削除し `fetch` のみ残す。
  App Review 説明コスト削減。実装時にコードベース全体を再 grep して確認。
- **b) `workflow_dispatch` 追加**: `.github/workflows/ios.yml` の `on:` に
  `workflow_dispatch` を足し、手動 CI 再実行を可能に。
- **c) `.xcode-version` 追記**: 期待 Xcode 26.x を明文化（CI 探索順 26.5 →
  26.4 → 26.0 と AGENTS.md の既存記述に整合）。`mise.toml` は導入しない。
- **d) Debug / Release xcconfig 分割**: 当面保留。現行 `SigningDefaults.xcconfig`
  一本で運用継続。将来 Release で `SWIFT_COMPILATION_MODE = wholemodule` /
  `VALIDATE_PRODUCT = YES` / `ENABLE_TESTABILITY = NO` を切る価値が出てから
  着手する。
- **e) `docs/architecture.md` 起票**: 依存方向と責務境界を図示するドキュメント
  を別途追加。AGENTS.md からリンクする想定。
- **f) `scripts/verify.sh` 要約モード**: `--summary` フラグで失敗箇所ジャンプ
  をしやすくする。
- **g) Widget / Live Activity の snapshot 拡張**: P3-2 の追補として
  `NextAlarmWidgetView` / `DynamicIslandViews` のケースを追加。

### P3-15. DOW ルール用 `RuleExpandedOverride` 専用テーブル（未着手 / 2026-05-27 追加）

> 根拠: 仕様提案書取り込み（§9 DOW）評価時の指摘
>
> 追跡: 設計は Linear DEV-143（spike）。provenance 2 列（`expandedFromRuleID` /
> `expandedAt`）は **DEV-259（A2 v1）と同 PR** で出荷し、本節（テーブル分離）は
> A2 出荷後の後続タスク。専用 Linear issue は **DEV-309**（blockedBy DEV-259 /
> related DEV-143）。

> 追跡: Linear DEV-296（実装。blockedBy DEV-259 / related DEV-143）

- **目的**: §P2-α A2 DOW ルール検出が受諾されると最大 6 ヶ月分の
  `HolidayOverride` を一括 insert するため、行数が増えて `DayResolver` クエリ
  コストへ影響しうる懸念に対応する。
- **方針**: DOW ルール由来の展開分は **専用の `RuleExpandedOverride` @Model** に
  分離し、`HolidayOverride` は引き続き単日 override の責務に留める。
- **依存**: A2 が v1 として `HolidayOverride` 展開で出荷された後、運用数値を見て
  着手判断。**A2 出荷ブロッカーではない**。
- **A2 v1 出荷時の前提条件（migration 安全性）**: A2 が `HolidayOverride` を
  共用テーブルとして使う以上、後で `RuleExpandedOverride` に分離するには
  「どの行が DOW ルール由来か」を判定できる必要がある。**A2 v1 出荷時点で**
  `HolidayOverride` に次の 2 列を追加し、ユーザの手動 override と A2 由来の
  展開行を後方互換に区別できる状態にしておく:
  - `expandedFromRuleID: UUID?`（nil なら手動・既存ロジックそのまま）
  - `expandedAt: Date?`（再展開バッチ判定用）
  ↑この 2 列が無いまま A2 を出してしまうと、ユーザ手動の祝日 override と
  A2 由来の展開行が事実上区別不能になり、P3-15 migration で「どの行を
  `RuleExpandedOverride` へ移すか」を確定できなくなる。よって P3-15 自体を
  後送するのは可だが、**provenance 2 列の追加だけは A2 と同じ PR に含める**。
- **DoD**:
  - DOW ルール展開分が独立テーブルに保存され、`DayResolver` の優先順位（手動 >
    祝日/有休 > ルール展開 > ローテ > なし）が壊れない。
  - 既存 `HolidayOverride` データを破壊せず、A2 由来分（`expandedFromRuleID`
    non-nil）を migration で `RuleExpandedOverride` に振り分け可能。手動 override
    （`expandedFromRuleID == nil`）はそのまま `HolidayOverride` に残る。

---

## 6. ファイル別「触るときの注意」（エージェント向け索引）

| パス | 何が入っているか | 触る際の注意 |
|---|---|---|
| `Sources/Services/AlarmKit/AlarmScheduler.swift` | expected set との diff-sync 本体 | キャンセル漏れに注意。テストは `AlarmSchedulerTests.swift` |
| `Sources/Domain/Logic/DayResolver.swift` | 優先度: 手動 > 祝日 > ローテ > なし | PR #5 で削除済み preset のフォールバックを復元済み |
| `Sources/Domain/Logic/RotationExpander.swift` | アンカー基準の周期展開（負オフセット可） | 不正な cycle/slot 数はスキップ |
| `Sources/Services/Sharing/ShiftBundleCodec.swift` | `.shiftalarm` JSON | 日付は `CalendarDay`（PR #5）。legacy `exportedAt` 文字列受け入れ済み |
| `Sources/Services/Sharing/ShiftBundleValidator.swift` | `.shiftalarm` 入力の意味検査 | `ShiftBundleCodec` decode 後、`ShareImporter.preview` / `apply` の前に挟む |
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

1. `main` に直接 push しない。Linear issue から生成されるブランチ名 `dolquis/dev-xx-*`
   を基本とする（Linear issue が無い緊急時のみ `feature/<topic>` / `fix/<topic>`）。
2. PR は **draft で作成**。CI（`scripts/verify.sh`）が緑になってから ready for review。
3. `.xcodeproj` は commit 対象（XcodeGen で再生成されても）。
4. AlarmKit / ActivityKit の API 変更を伴う PR は、変更箇所を
   `AlarmConfigurationBuilder.swift` と `LiveActivityController.swift` に局所化する。
5. Domain model に **non-optional プロパティ追加** をする場合は
   `SchemaV1.swift` のマイグレーション影響を必ず記載する。
6. ローカライズ文字列を追加したら `Resources/Localizable.xcstrings` の **ja / en 両方** を埋める。

---

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
   `VacationPeriod` 独立 @Model 追加、SwiftData V2 マイグレーション。
   Widget container 整合性確認。

8. **P2-γ 画像インポート Phase 1**: 手動グリッド + 記号マッピング UI を OCR 抜きで
   先行リリース。差分プレビューは P1-6 を経由。

**直近の開発環境ハードニング（P3 配下 / 機能追加と並行で進める想定）**:
P3-6 (`Package.resolved` 固定) → P3-8 (`AlarmScheduler` 構造化ログ、P0-4 完了後) →
P3-14a (`UIBackgroundModes` 整理) → P3-14b (`workflow_dispatch`) の順で、
小さな PR を継続的に出す。

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

**新規テスト ID（2026-05-27 追加） — A1 / A2 拡充版**

| # | テスト名 | 検証する性質 |
|---|---|---|
| DRIFT-U1 | `testDetectDriftReturnsNilWhenObservedZero` | observed 0 で `nil` |
| DRIFT-U2 | `testDetectDriftReturnsNilBelowThreshold` | mismatchRate < `patternDriftThreshold` で `nil` |
| DRIFT-U3 | `testDetectDriftRedetectsAboveThreshold` | 閾値以上で再検出が走る |
| DRIFT-U4 | `testDetectDriftHidesSameFingerprint` | 既存と同 fingerprint なら非表示 |
| DRIFT-U5 | `testDetectDriftHidesDuringSnooze` | snooze 中なら非表示 |
| DRIFT-I1 | `testDriftAcceptDeactivatesOldPattern` | 受諾で旧 pattern が `isActive = false` |
| DRIFT-I2 | `testDriftAcceptActivatesNewPattern` | 受諾で新 pattern が active |
| DRIFT-I3 | `testDriftAcceptRefreshesAlarmScheduler` | 受諾後に `AlarmScheduler.refresh` が呼ばれる |
| DOW-U1 | `testFirstAndThirdFridayDetected` | 第 1・第 3 金曜の夜勤を検出 |
| DOW-U2 | `testDOWDetectorRejectsSingleObservation` | 観測 1 件では検出しない |
| DOW-U3 | `testDOWDetectorRejectsLowMatchRate` | matchRate 不足では検出しない |
| DOW-U4 | `testDOWDetectorDetectsOffPattern` | off も検出可能 |
| DOW-U5 | `testDOWDetectorReturnsMultipleRules` | 複数ルールを返せる |
| DOW-I1 | `testDOWAcceptExpandsSixMonths` | 受諾で 6 ヶ月分展開 |
| DOW-I2 | `testDOWAcceptDoesNotOverrideManual` | 手動割当は上書きしない |
| DOW-I3 | `testDOWAcceptGoesThroughChangePreview` | `ChangePreview` を経由 |

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

**新規テスト ID（2026-05-27 追加） — VAC 系**

> **VAC-U* と β-U* の関係**: 旧 β-U* / β-I* は P2-β の **当初設計時の暫定 ID**
> で、`docs/p2-algorithms.md §4` の test execution map にも残っている。2026-05-27
> 提案書取り込み以降の **canonical な ID は VAC-U* / VAC-I*** に統一する。
> 既存 β-U1〜β-I4 はそのまま消さず、対応関係（β-U1 ↔ VAC-U1 など番号順）として
> 解釈する。実装着手時は VAC-* を Swift Testing の `@Test` 関数名に採用し、β-* は当面
> ドキュメント上の旧名称として残置するに留める（将来の docs 整理 PR で
> 段階的に削除）。VAC-U10 は β 系には対応物が無い新規（domain factory invariant）。

| # | テスト名 | 検証する性質 |
|---|---|---|
| VAC-U1 | `testNoVacationProducesSameResultAsBaseExpander` | 連休なしは既存 `RotationExpander` と完全一致 |
| VAC-U2 | `testVacationDaysReturnNil` | 連休中は `nil` |
| VAC-U3 | `testManualOverrideBeatsVacation` | 手動割当は連休より優先 |
| VAC-U4 | `testInvertPolicyShiftsHalfPeriod` | invert で半周期ずれる |
| VAC-U5 | `testContinuePolicyExcludesVacationFromCycle` | continue で連休日数が周期から除外 |
| VAC-U6 | `testResetToDayPolicyAlignsToDaySlot` | resetToDay で昼勤スロットへ揃う |
| VAC-U7 | `testMultipleVacationsAccumulate` | 複数連休の補正が累積する |
| VAC-U8 | `testYearBoundaryDoesNotShiftDates` | 年末年始を跨いでも日付ズレしない |
| VAC-U9 | `testVacationPeriodLessThanThreeDaysRejectedByUI` | 3 日未満の `VacationPeriod` は UI 入力検証で reject される |
| VAC-U10 | `testVacationPeriodFactoryRejectsLessThanThreeDays` | domain factory / throwing init が 2 日範囲を `VacationPeriodError.tooShort` で reject |
| VAC-I1 | `testHolidayManagerCreatesVacation` | HolidayManager から連休登録できる |
| VAC-I2 | `testAlarmSchedulerExpectedSetChangesAfterVacation` | 登録後に AlarmScheduler の expected set が変化する |

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

**新規テスト ID（2026-05-27 追加） — Phase 1 手動グリッド + 記号マッピング系**

| # | テスト名 | 検証する性質 |
|---|---|---|
| IMG-U1 | `testSymbolMappingPersists` | 勤務記号 mapping が `ShiftSymbolMapping` として保存される |
| IMG-U2 | `testUnknownSymbolBecomesUnresolved` | unknown symbol は未確定状態（要ユーザ指定） |
| IMG-U3 | `testRestAndAfterShiftMapToSkipAlarm` | 休 / 明は `skipAlarm = true` になる |
| IMG-U4 | `testLowConfidenceCellsRemainUnselected` | 低信頼度 (`ShiftImportConfidence.low`) セルは未選択 |
| IMG-U5 | `testDuplicateDateMarkedAsConflict` | 同じ日付の重複は `ChangeKind.conflict` |
| IMG-I1 | `testImageAnalysisShowsChangePreview` | 画像解析後に `ChangePreview` 経由のプレビュー表示 |
| IMG-I2 | `testApplyCreatesDayAssignments` | Apply で `DayAssignment` 作成 |
| IMG-I3 | `testConflictWithExistingManualAssignment` | 既存手動割当との競合表示 |
| IMG-S1 | `testMappingUISnapshot` | Mapping UI snapshot |
| IMG-S2 | `testPreviewUISnapshot` | Preview UI snapshot |

**手動 (golden path)**

- 機内モードで画像を取込 → 通信エラーが出ず正しく抽出 → 差分プレビュー → 適用 → Calendar
  に反映。
- カメラ撮影 (`DataScannerViewController`) で撮影 → 同じパイプラインで適用できる。
- `FoundationModels` が利用不可な OS にフォールバックを設定 → ルールベースで動作する。
- **Phase 1 単独**: OCR を意図的に無効化し、画像 + 手動グリッド指定だけで完結すること
  を確認（OCR 完全失敗時のフォールバック動作）。

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
