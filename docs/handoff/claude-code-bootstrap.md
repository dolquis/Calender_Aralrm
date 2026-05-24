# Claude Code 引き継ぎ：`.claude/` セットアップ(ハイブリッド版)

> このファイルは、`dolquis/Calender_Aralrm`(iOS 26+ シフトワーカー向けアラームアプリ、
> Swift 6 / SwiftUI / SwiftData / AlarmKit)に Claude Code 用の共有設定を導入するための、
> Claude Code への作業指示書です。
>
> **方針：マーケット配布の MCP・プラグインを最大限活用し、自作スキルは
> プロジェクト固有でマーケットに代替が無い領域のみに限定する。**

---

## 0. 大前提(厳守)

- PR は必ず **`dolquis/Calender_Aralrm` 宛・Draft** で作成する。
- `main` ブランチに直接 push しない。新規ブランチを切って作業する。
- `gh pr create` を使うときは `--repo dolquis/Calender_Aralrm --base main --draft` を必ず明示。
- `Config/LocalSigning.xcconfig` は git 管理外。**作成・編集・コミットしない**。
- `ShiftAlarm.xcodeproj` は **XcodeGen 生成物**。直接編集せず、`project.yml` を編集して
  `bash scripts/regen.sh` で再生成する。

## 1. プロジェクト現状サマリー

- 対象：iOS 26.0+、Swift 6、SwiftUI / SwiftData、Widget Extension あり。
- 主要機能：シフトプリセット、ローテーション、祝日／休暇オーバーライド、
  `.shiftalarm` JSON エクスポート／インポート、URL scheme、Widget、Live Activity、
  HealthKit 連携、App Intents、就寝予定・就寝リマインダー。
- アーキテクチャ要点：
  - `AlarmScheduler` が `DayResolver` の出力と AlarmKit を **diff-sync**
  - precedence：**manual > holiday > rotation > none**
  - `BGAppRefreshTask` で 30 日先まで lookahead
  - Widget は App Group(既定：`group.com.example.shiftalarm`)で SwiftData ストアを共有
- ディレクトリ要点：
  - `project.yml` — XcodeGen の唯一の真実源
  - `scripts/` — `bootstrap.sh`, `regen.sh`, `verify.sh`, `lint.sh`, `p0-readiness.sh`
  - `Sources/Domain/` — SwiftData `@Model` + 純粋ロジック
  - `Sources/Services/` — AlarmKit, Background, LiveActivity, Sharing, Holidays
  - `Tests/` — XCTest 85 ケース / 16 クラス、`SNAPSHOT_TESTING_ENABLED=1` で snapshot 5 件追加
- 既存メタファイル：`CLAUDE.md`, `AGENTS.md` あり(役割を被らせない)

## 2. ゴール

リポジトリ直下に以下の3つを配置する。

```
.mcp.json                              ← マーケット/公開 MCP サーバー定義(共有)
.claude/
  settings.json                        ← 公式マーケット自動登録＋有効化プラグイン
  skills/                              ← 自作スキル(最小限のみ)
    xcodegen-regen/
      └── SKILL.md
    alarmkit-scheduling/
      ├── SKILL.md
      └── references/
          └── day-resolver.md
    swiftdata-migration/
      ├── SKILL.md
      └── references/
          └── app-group-store.md
```

**自作スキルを3個に絞り込んだ理由(前回案からの差分)**

| 前回案 | 今回どうするか | 理由 |
|---|---|---|
| `xcodegen-regen` | **残す**(自作)| `project.yml` 一極集中、`Config/LocalSigning.xcconfig` 不可侵などプロジェクト固有制約 |
| `swift-format-check` | **削除**。CLAUDE.md に2行追記で代替 | `scripts/lint.sh check`/`fix` の運用だけなので |
| `alarmkit-scheduling` | **残す**(自作)| precedence ルールと diff-sync 設計はプロジェクト固有 |
| `widget-liveactivity` | **削除**。`swift-lsp` + Context7 で代替 | App Group ID 等は CLAUDE.md に書けば十分、汎用知識は LSP+ドキュメント MCP で足りる |
| `swiftdata-migration` | **残す**(自作)| App Group + `.shiftalarm` JSON との整合性はプロジェクト固有 |

## 3. `.mcp.json` の作成

リポジトリ直下に作成し、コミットする。`${...}` で参照する環境変数は各開発者の
シェルで設定する運用とし、ファイル自体にシークレットは書かない。

```json
{
  "mcpServers": {
    "context7": {
      "type": "http",
      "url": "https://mcp.context7.com/mcp"
    },
    "xcodebuild": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "xcodebuildmcp"]
    }
  }
}
```

**Claude Code が実装時に確認すべきこと：**

1. `xcodebuild` の起動コマンド(パッケージ名・引数)は最新ドキュメントを `WebFetch` で照合：
   - XcodeBuildMCP: <https://github.com/cameroncooke/XcodeBuildMCP>(or 同等の現行 fork)
2. macOS / Xcode 26 が前提。Linux/Windows では `xcodebuild` MCP は起動失敗するが想定動作。
   `context7` だけは全 OS で動く。
3. シークレットを直接書かない。必要があれば `${ENV_VAR}` で参照。
4. `node` / `npx` がホスト側にインストールされている前提。`README.md` の「推奨開発環境」に
   Node 18+ 必須の旨を追記する。

## 4. `.claude/settings.json` の作成

公式マーケット(`claude-plugins-official`)を明示的に登録し、本プロジェクトで
使うプラグインを有効化リストとして列挙する。

```json
{
  "extraKnownMarketplaces": {
    "claude-plugins-official": {
      "source": {
        "source": "github",
        "repo": "anthropics/claude-plugins-official"
      }
    }
  },
  "enabledPlugins": [
    "swift-lsp@claude-plugins-official",
    "github@claude-plugins-official",
    "commit-commands@claude-plugins-official",
    "pr-review-toolkit@claude-plugins-official"
  ]
}
```

**Claude Code が実装時に確認すべきこと：**

1. `enabledPlugins` の正確なスキーマ(キー名・配列要素の書式)を Claude Code 公式ドキュメント
   <https://code.claude.com/docs/en/plugin-marketplaces> で確認。本ドキュメントの記載は概念例なので、
   実フィールド名が `enabledPlugins` で正しいか・別名(`autoInstall` 等)が現行か必ず照合する。
2. 公式マーケットがデフォルトで利用可能な場合、`extraKnownMarketplaces` のエントリは
   省略可能なことがある。冗長になるなら省く。
3. 各プラグインが本リポジトリで有効に動くか、`/plugin install` 後に手動確認すること：
   - `swift-lsp` … `Sources/` 配下で SourceKit-LSP 経由の補完・診断が出る
   - `github` … `gh` 経由の PR 作業がエージェントから可能
   - `commit-commands` … 規約に沿ったコミットメッセージ生成
   - `pr-review-toolkit` … PR レビュー補助
4. SourceKit-LSP は Xcode 26 同梱の toolchain を使う。複数 toolchain を入れている場合、
   `xcrun --find sourcekit-lsp` が期待のものを返すか確認(`README.md` に追記)。
5. **Swift Agent Skills(Paul Hudson 他)** は公式マーケットではないが、各開発者が
   `~/.claude/skills/` 配下に個人インストールできる。`README.md` の「推奨開発環境」セクションで
   案内するが、リポジトリには含めない(各自のローカルでの利用に留める)。

## 5. 自作スキル個別仕様

### 5.1 `xcodegen-regen`

**目的**：`project.yml` 編集 → `ShiftAlarm.xcodeproj` 再生成 → ビルド検証の流れを統一。
XcodeGen 中心の運用と固有スクリプト名はプロジェクト固有のためマーケット代替不可。

````markdown
---
name: xcodegen-regen
description: project.yml を編集したとき、ShiftAlarm.xcodeproj に不整合があるとき、ファイル追加・削除でビルドが通らなくなったときに使用する。XcodeGen 再生成とビルド検証を統一的に行う。
allowed-tools: Bash, Read, Edit
---

# XcodeGen 再生成フロー

## 標準コマンド

初回セットアップ(マシンごとに1回)：
```bash
bash scripts/bootstrap.sh
```

再生成：
```bash
bash scripts/regen.sh
```

ビルド＋テスト検証(既定の iOS 26 シミュレータ)：
```bash
bash scripts/verify.sh
```

シミュレータを明示する場合：
```bash
DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' bash scripts/verify.sh
```

テストのみ：
```bash
bash scripts/verify.sh test
```

## いつこのスキルを使うか

- `project.yml` を編集した直後
- 新しい `.swift` ファイルを `Sources/`, `App/`, `Widget/`, `Tests/` に追加した直後
- `ShiftAlarm.xcodeproj` の中身を直接編集しようとしている自分／他人を見たとき
- `xcodebuild` が「ファイルがプロジェクトに含まれていない」系のエラーを出したとき

## 守るべきこと

- `ShiftAlarm.xcodeproj` を **直接編集しない**。`project.yml` を編集して `regen.sh`。
- `project.yml` を編集したら必ず `verify.sh` を回す(ビルド成功・テスト 85 件パスを確認)。
- Snapshot テスト 5 件は既定でスキップ。動かしたい場合は `SNAPSHOT_TESTING_ENABLED=1`。
- XcodeBuildMCP を入れている場合でも、CI と乖離しないよう `scripts/verify.sh` を一次手段とする。

## やってはいけない

- `ShiftAlarm.xcodeproj/project.pbxproj` を手書きで編集する。
- `Config/LocalSigning.xcconfig` を作成・編集・コミットする(ローカル専用、`.gitignore` 対象)。
- 既定のバンドル ID(`com.example.*`)のまま実機ビルドする(`p0-readiness.sh` が落ちる)。
````

### 5.2 `alarmkit-scheduling`

**目的**：AlarmKit ＋ `AlarmScheduler` ＋ `DayResolver` を触るときの落とし穴を集約。
precedence ルールと diff-sync 設計はプロジェクト固有のためマーケット代替不可。

````markdown
---
name: alarmkit-scheduling
description: AlarmScheduler、DayResolver、AlarmKit 経由のアラーム登録／キャンセル／diff-sync、ローテーションパターン展開、休暇オーバーライドを編集・デバッグするときに使用する。
allowed-tools: Read, Edit, Grep, Glob, WebFetch
---

# AlarmKit スケジューリング

## このスキルが扱う範囲

- `Sources/Services/AlarmKit/AlarmScheduler.swift` — AlarmKit との diff-sync の中核
- `Sources/Domain/` の `DayResolver` / `RotationExpander` 等 — 日付→プリセット解決
- `BGAppRefreshTask` での lookahead(既定 30 日)
- AlarmKit のオーソリ取得(Onboarding 経由)

## DayResolver の precedence

**manual > holiday > rotation > none**

このルールを破る変更は仕様変更扱い。`docs/` の関連仕様を更新せずに変えないこと。
詳細は `references/day-resolver.md`。

## AlarmKit 連携の守るべきこと

1. `#if canImport(AlarmKit)` ガードを外さない。AlarmKit が無い toolchain でも
   コードが parse できる前提を維持する。
2. `AlarmConfigurationBuilder` は現行の `AlarmManager.AlarmConfiguration.alarm(...)` を使う。
   iOS 26.1 の `AlarmPresentation.Alert.stopButton` deprecation を避けた書き方を維持。
3. `AlarmScheduler` は **diff-sync**：期待集合と登録済み集合の差分だけを操作する。
   フル再登録に書き換えない(バッテリ・性能影響が大きい)。
4. AlarmKit のオーソリは Onboarding で取得。コードパスのどこかで再要求が必要な場合は
   ユーザー操作を経由させ、サイレントに失敗しない。

## 補助ツール(マーケット品を活用)

- API 仕様確認：Context7 MCP 経由で <https://developer.apple.com/documentation/alarmkit> を fetch
- コード補完・型エラー：`swift-lsp` プラグイン
- テスト実行：`bash scripts/verify.sh test`(or XcodeBuildMCP)

## 変更後に必ず確認すること

- `bash scripts/verify.sh test` で AlarmScheduler 系のユニットテストがパスする。
- precedence や境界条件を変える場合は、必ず新しいテストケースを追加する。

## やってはいけない

- AlarmKit に直接アクセスするコードを `Sources/Features/`(SwiftUI 層)に書く。
  必ず `Sources/Services/AlarmKit/` のスケジューラ越し。
- precedence ルールを断りなく変える。
- BGAppRefresh のスケジュール頻度を上げる(OS から絞られて逆効果になりやすい)。
````

**`references/day-resolver.md` の埋め方(Claude Code 側で実施)：**

- `Sources/Domain/DayResolver*` を読んで、precedence の具体例を 2〜3 個記述：
  - 祝日とローテーションが衝突したときに holiday が勝つ例
  - 手動割当が祝日より優先される例
  - ローテーションが none の日に何も登録されない例

### 5.3 `swiftdata-migration`

**目的**：SwiftData `@Model` のスキーマ変更を、App Group ストアと Widget の整合を保ちつつ
安全に行う。App Group ID と `.shiftalarm` JSON との二重整合性はプロジェクト固有のため
マーケット代替不可。

````markdown
---
name: swiftdata-migration
description: Sources/Domain/ の SwiftData @Model を追加・変更・削除するとき、App Group ストアとの整合性、既存ユーザーデータのマイグレーション、Widget との SwiftData 共有を扱うときに使用する。
allowed-tools: Read, Edit, Grep, Glob
---

# SwiftData マイグレーション運用

## このスキルが扱う範囲

- `Sources/Domain/` 配下の `@Model` 定義
- App Group(既定：`group.com.example.shiftalarm`)共有ストア
- `.shiftalarm` JSON エクスポート/インポートのスキーマとの整合
- `Tests/` でのスキーマ破壊検出

## 変更時の判定マトリクス

| 変更の種類 | マイグレーション要否 | 注意点 |
|---|---|---|
| 新規 `@Model` 追加 | 不要(既存データに影響なし) | App Group の SchemaContainer に追加し忘れない |
| 新規プロパティ追加(optional / 既定値あり) | 軽量で可 | デフォルト値が `DayResolver` の precedence と矛盾しないか |
| プロパティの型変更／削除 | **重量マイグレーション必須** | `VersionedSchema` + `SchemaMigrationPlan` で明示 |
| `@Relationship` の変更 | **重量マイグレーション必須** | 既存リンクの保全方針を決める |
| `.shiftalarm` JSON スキーマと連動する変更 | エクスポート／インポートの両方を更新 | バージョンフィールドを bump |

## 守るべき手順

1. 変更前のスキーマを `VersionedSchema` として残す。
2. 新スキーマを定義し、`SchemaMigrationPlan.stages` で変換を記述。
3. App Group ストア URL を変えない(Widget が読めなくなる)。
4. `.shiftalarm` JSON の import 側にも対応コードを追加。
5. テストを追加(既存データを読み込めるか、変換が冪等か)。

## 補助ツール(マーケット品を活用)

- API 仕様確認：Context7 経由で <https://developer.apple.com/documentation/swiftdata/schemamigrationplan> を fetch
- コード補完：`swift-lsp` プラグイン

## やってはいけない

- マイグレーションを書かずに `@Model` の型を破壊的に変える(既存ユーザーのデータが消える)。
- App Group ID を変更する(既存インストールで Widget と本体が見えなくなる)。
- `.shiftalarm` JSON のスキーマを変えずに `@Model` だけ変える(インポートが壊れる)。

## 参照
- `references/app-group-store.md` — App Group SwiftData ストアの設定とパス
````

**`references/app-group-store.md` の埋め方(Claude Code 側で実施)：**

- `App/` の entitlements を読んで App Group ID の設定箇所を特定
- `Sources/Services/` の SchemaContainer 初期化箇所を特定
- `Widget/` 側で同じ App Group を参照している箇所を特定
- ストア URL の決まり方を整理(`FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)`)

## 6. CLAUDE.md への追記(マーケット品で代替する内容)

前回案で自作スキルにしていた 2 項目は、CLAUDE.md に短く追記するだけで足りる。
**既存の CLAUDE.md を読み、矛盾しない場所に以下を追記する**：

````markdown
## swift-format

```bash
bash scripts/lint.sh check    # CI と同じチェック
bash scripts/lint.sh fix      # in-place 自動修正
```

`.swift-format`(リポジトリ root)が唯一の設定源。
使う `swift-format` は Xcode 26 toolchain 同梱版(Homebrew 版とバージョン乖離注意)。
自動生成コード(`ShiftAlarm.xcodeproj/` 配下)に lint を流さない。

## Widget / Live Activity

- Widget は別プロセス。アプリ本体と直接メモリを共有しない。
  共有は App Group(既定：`group.com.example.shiftalarm`)の SwiftData ストアか
  `UserDefaults(suiteName:)` のみ。
- TimelineProvider は複数エントリを返す(`policy: .never` 禁止)。
- 依存ロジックは `Sources/Domain/` を再利用、Widget 側でビジネスロジックを再実装しない。
- Live Activity の表示時間は `liveActivityLeadHours` 設定値に従う。
- Widget 側から AlarmKit / HealthKit を直接呼ばない。アプリ本体側で書き込んだ値を読むだけ。
````

## 7. 作業フロー

1. ブランチを切る：`git switch -c chore/claude-bootstrap`
2. `.mcp.json` を作成(§3)
3. `.claude/settings.json` を作成(§4、スキーマを公式ドキュメントで再確認)
4. `.claude/skills/` 配下に3スキルを作成(§5)
   - `references/` 配下は実コードを `grep` / `view` で読んで埋める
5. `CLAUDE.md` に §6 の2セクションを追記(既存と矛盾しないこと)
6. `.gitignore` に **追加不要**。`.mcp.json` `.claude/settings.json` `.claude/skills/` は
   全て共有が目的なのでコミット対象。
7. 動作確認：
   - `claude mcp list` で `context7`、`xcodebuild` の2つが見える
   - `/plugin marketplace list` で `claude-plugins-official` が見える
   - `/plugin list` で4プラグインが enabled になっている
   - `bash scripts/verify.sh` が通る(既存挙動を壊していないこと)
8. PR 作成：
   ```bash
   gh pr create \
     --repo dolquis/Calender_Aralrm \
     --base main \
     --head chore/claude-bootstrap \
     --draft \
     --title "chore(claude): bootstrap MCP, plugins, and skills for ShiftAlarm" \
     --body "Hybrid setup: marketplace MCP/plugins + minimal custom skills (xcodegen-regen, alarmkit-scheduling, swiftdata-migration)."
   ```

## 8. 完了基準(DoD)

- [ ] `.mcp.json` がリポジトリ直下にあり、2 MCP サーバーが定義されている。
- [ ] `.mcp.json` にシークレットが含まれていない(`${ENV_VAR}` 参照のみ)。
- [ ] `.claude/settings.json` が公式マーケットを登録し、4プラグインを有効化している。
- [ ] `.claude/skills/` 配下に 3 スキル(`xcodegen-regen`, `alarmkit-scheduling`, `swiftdata-migration`)が
      作成され、実コードに即した `references/` も整備されている。
- [ ] `CLAUDE.md` に swift-format・Widget の2セクションが追記されている。
- [ ] `claude mcp list` / `/plugin list` で全てが認識されている。
- [ ] `bash scripts/verify.sh` で 85 テストが既存通りパスする。
- [ ] Draft PR が `dolquis/Calender_Aralrm` 宛で作成されている。

## 9. 参考リソース

- Claude Code MCP: <https://code.claude.com/docs/en/mcp>
- Claude Code Plugin Marketplaces: <https://code.claude.com/docs/en/plugin-marketplaces>
- 公式マーケット: <https://github.com/anthropics/claude-plugins-official>
- コミュニティマーケット一覧: <https://claudemarketplaces.com/>
- XcodeBuildMCP: <https://github.com/cameroncooke/XcodeBuildMCP>
- Swift Agent Skills(Paul Hudson、個人インストール推奨): <https://github.com/twostraws/swift-agent-skills>
- AlarmKit: <https://developer.apple.com/documentation/alarmkit>
- WidgetKit: <https://developer.apple.com/documentation/widgetkit>
- ActivityKit: <https://developer.apple.com/documentation/activitykit>
- SwiftData: <https://developer.apple.com/documentation/swiftdata>
