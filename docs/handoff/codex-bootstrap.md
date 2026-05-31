# Codex CLI 引き継ぎ：`.codex/` `.agents/` セットアップ

> このファイルは、`dolquis/Calender_Aralrm`(iOS 26+ シフトワーカー向けアラームアプリ、
> Swift 6 / SwiftUI / SwiftData / AlarmKit)に **OpenAI Codex CLI** 用の共有設定を
> 導入するための、Codex CLI への作業指示書です。
>
> **方針：マーケット配布の MCP を最大限活用し、自作スキルはプロジェクト固有で
> 代替が無い領域のみに限定する。Claude Code 版とは独立に維持する。**

---

## 0. 大前提(厳守)

- PR は必ず **`dolquis/Calender_Aralrm` 宛・Draft** で作成する。
- `main` ブランチに直接 push しない。新規ブランチを切って作業する。
- `gh pr create` を使うときは `--repo dolquis/Calender_Aralrm --base main --draft` を必ず明示。
- `Config/LocalSigning.xcconfig` は git 管理外。**作成・編集・コミットしない**。
- `ShiftAlarm.xcodeproj` は **XcodeGen 生成物**。直接編集せず、`project.yml` を編集して
  `bash scripts/regen.sh` で再生成する。
- セッション内で修正しないバグ・pending 問題は **GitHub Issue として登録**して
  ハンドオフする（doc に埋め込まない。手順は `AGENTS.md` §6.1.1）。
- 既存の Claude Code 用設定(`.claude/` `.mcp.json` `CLAUDE.md`)は **触らない**。Codex 用は独立で構築する。

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
  - `Tests/` — Swift Testing 91 ケース / 16 スイート、`SNAPSHOT_TESTING_ENABLED=1` で snapshot 5 件追加
- 既存メタファイル：`CLAUDE.md`(Claude Code 用)、`AGENTS.md`(Codex CLI および人間用)

## 2. Codex CLI と Claude Code の設定差(復習)

| 項目 | Claude Code | Codex CLI |
|---|---|---|
| プロジェクト命令 | `CLAUDE.md` | **`AGENTS.md`** |
| プロジェクト設定 | `.claude/settings.json`(JSON) | **`.codex/config.toml`**(TOML) |
| MCP 定義 | `.mcp.json`(独立、JSON) | **`.codex/config.toml` 内 `[mcp_servers.*]`**(統合) |
| スキル配置 | `.claude/skills/<name>/SKILL.md` | **`.agents/skills/<name>/SKILL.md`** |
| SKILL.md フォーマット | YAML frontmatter + 本文 | **完全に同じ**(クロス互換) |

## 3. ゴール

リポジトリ直下に以下を配置する。

```
AGENTS.md                              ← 新規(または既存追記)。Codex CLI が必ず読む
.codex/
  config.toml                          ← Codex プロジェクト設定 + MCP 定義(共有)
.agents/
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

**自作スキルを3個に絞り込んだ理由**

| 項目 | どうするか | 理由 |
|---|---|---|
| `xcodegen-regen` | **残す**(自作)| `project.yml` 一極集中、`Config/LocalSigning.xcconfig` 不可侵などプロジェクト固有制約 |
| `swift-format-check` | AGENTS.md に2行追記で代替 | `scripts/lint.sh check`/`fix` の運用だけ |
| `alarmkit-scheduling` | **残す**(自作)| precedence ルールと diff-sync 設計はプロジェクト固有 |
| `widget-liveactivity` | AGENTS.md に注意事項を追記、Context7 で代替 | App Group ID 等は AGENTS.md に書けば十分、汎用知識は MCP で足りる |
| `swiftdata-migration` | **残す**(自作)| App Group + `.shiftalarm` JSON との整合性はプロジェクト固有 |

## 4. `.codex/config.toml` の作成

リポジトリ直下に `.codex/config.toml` を新規作成し、コミットする。

> **重要**: Codex CLI は `.codex/config.toml` を **trust された project でのみ** 読み込む。
> 各開発者が初回起動時に Codex の trust プロンプトに同意する必要がある。

```toml
#:schema https://developers.openai.com/codex/config-schema.json

# ─────────────────────────────────────────────
# トップレベル設定（サンドボックス / 承認ポリシー）
# ─────────────────────────────────────────────
#
# 重要：TOML はテーブルヘッダ（`[...]`）以降のキーがそのテーブルに属するため、
# トップレベルのスカラ設定（sandbox_mode / approval_policy 等）は
# 全ての [table] ヘッダより前にまとめて書く必要がある。
# 後ろに書くと意図せず直前テーブルにネストされ、設定が効かなくなる。

# workspace-write: リポジトリ内の書き込みは許可
sandbox_mode = "workspace-write"

# 既定 = on-request (重要操作はユーザー承認を仰ぐ)
approval_policy = "on-request"

# ─────────────────────────────────────────────
# サンドボックス詳細
# ─────────────────────────────────────────────

[sandbox_workspace_write]
network_access = true   # MCP HTTP(context7)と Swift Package Manager / CocoaPods のため

# ─────────────────────────────────────────────
# MCP サーバー定義(共有)
# ─────────────────────────────────────────────

# Context7: AlarmKit / WidgetKit / ActivityKit / SwiftData / HealthKit の Apple ドキュメント参照
[mcp_servers.context7]
url = "https://mcp.context7.com/mcp"
startup_timeout_sec = 15

# XcodeBuildMCP: Xcode ビルド・iOS 26 シミュレータ制御を構造化 JSON で扱える
# Node.js 18+ が必要(npx 経由でインストール)
# `mcp` サブコマンドが必須。これが無いと npx は即終了し MCP サーバーが起動しない。
# 上流: https://github.com/cameroncooke/XcodeBuildMCP
[mcp_servers.xcodebuild]
command = "npx"
args = ["-y", "xcodebuildmcp@latest", "mcp"]
startup_timeout_sec = 30

# ─────────────────────────────────────────────
# プロジェクトルート判定
# ─────────────────────────────────────────────

# Git ベースなので default(`.git`)で十分。明示しなくてもOK。
# project_root_markers = [".git"]

# ─────────────────────────────────────────────
# Web 検索 / モデル(任意。各開発者の好みに任せる場合は省く)
# ─────────────────────────────────────────────

# web_search = "cached"
# model = "gpt-5-codex"
```

**Codex CLI が実装時に確認すべきこと:**

1. `xcodebuild` MCP の正確なパッケージ名・引数を最新ドキュメントで照合：
   - XcodeBuildMCP: <https://github.com/cameroncooke/XcodeBuildMCP>(または同等の現行 fork)
2. シークレットを TOML に直接書かない。必要な環境変数があれば `env` テーブルで参照：
   ```toml
   [mcp_servers.<name>.env]
   SOME_API_KEY = "${SOME_API_KEY}"
   ```
3. macOS / Xcode 26 が前提。Linux/Windows では `xcodebuild` MCP は起動失敗するが想定動作。
   失敗を許容するため `required = false`(既定)のままにする。
4. **`sandbox_mode = "workspace-write"`** と **`network_access = true`** の組み合わせは、
   Swift Package Manager 依存解決、CocoaPods、MCP HTTP のために必要。
5. **Swift Agent Skills(Paul Hudson 他)** は公式マーケットではないが、各開発者が
   `~/.codex/skills/` 配下に個人インストールできる。`README.md` の「推奨開発環境」セクションで
   案内するが、リポジトリには含めない(各自のローカル利用に留める)。

## 5. `AGENTS.md` の作成(または既存への統合)

リポジトリ直下に `AGENTS.md` を新規作成、または既存に追記する。Codex CLI は起動時に
これを最初に読み、毎ターン参照する。Claude Code の `CLAUDE.md` とは**独立に維持**する
方針なので、内容が重複してもよいが、片方の更新を忘れない運用ルールを `README.md` に書く。

````markdown
# AGENTS.md — Calender_Aralrm(ShiftAlarm, iOS 26+)

このファイルは OpenAI Codex CLI、および本リポジトリで作業する人間のエージェント全員が
最初に読むべき規約です。

## 厳守事項

- PR は必ず **`dolquis/Calender_Aralrm` 宛・Draft** で作成。
- `main` への直接 push 禁止。新規ブランチを切る。
- `gh pr create` は `--repo dolquis/Calender_Aralrm --base main --draft` を明示。
- `Config/LocalSigning.xcconfig` は **作成・編集・コミットしない**(git 管理外)。
- `ShiftAlarm.xcodeproj` は XcodeGen 生成物。**直接編集禁止**。`project.yml` を編集して
  `bash scripts/regen.sh`。

## プロジェクト概要

iOS 26+ シフトワーカー向けアラームアプリ。Swift 6、SwiftUI、SwiftData、AlarmKit、
WidgetKit、ActivityKit、HealthKit、App Intents を使用。

precedence: `manual > holiday > rotation > none`。`AlarmScheduler` は `DayResolver` の
出力と AlarmKit を **diff-sync**(フル再登録禁止)。

## ビルド / テスト

```bash
bash scripts/bootstrap.sh         # 初回のみ
bash scripts/regen.sh             # project.yml 編集後
bash scripts/verify.sh            # ビルド + テスト 91 件(snapshot 5 件は既定スキップ)
bash scripts/verify.sh test       # テストのみ

# Snapshot テストも回す場合
SNAPSHOT_TESTING_ENABLED=1 bash scripts/verify.sh test
```

XcodeBuildMCP を使ってシミュレータ操作・スクショ取得もできるが、**CI と乖離しないよう
`scripts/verify.sh` を一次手段**とする。

## swift-format

```bash
bash scripts/lint.sh check        # CI と同じチェック
bash scripts/lint.sh fix          # in-place 自動修正
```

`.swift-format`(リポジトリ root)が唯一の設定源。使う `swift-format` は Xcode 26
toolchain 同梱版(Homebrew 版とバージョン乖離注意)。自動生成コード
(`ShiftAlarm.xcodeproj/` 配下)に lint を流さない。

## Widget / Live Activity

- Widget は別プロセス。アプリ本体と直接メモリを共有しない。
  共有は App Group(既定：`group.com.example.shiftalarm`)の SwiftData ストアか
  `UserDefaults(suiteName:)` のみ。
- TimelineProvider は複数エントリを返す(`policy: .never` 禁止)。
- 依存ロジックは `Sources/Domain/` を再利用、Widget 側でビジネスロジックを再実装しない。
- Live Activity の表示時間は `liveActivityLeadHours` 設定値に従う。
- Widget 側から AlarmKit / HealthKit を直接呼ばない。アプリ本体側で書き込んだ値を読むだけ。

## スキル(`.agents/skills/`)

- `xcodegen-regen` — `project.yml` 編集 → 再生成 → ビルド検証
- `alarmkit-scheduling` — `AlarmScheduler` / `DayResolver` / diff-sync
- `swiftdata-migration` — `@Model` スキーマ変更と App Group / JSON との整合性

該当作業時は Codex が自動的に当該 SKILL.md を読み込む。

## MCP サーバー(`.codex/config.toml`)

- `context7` — AlarmKit / WidgetKit / ActivityKit / SwiftData の Apple ドキュメント参照
- `xcodebuild` — Xcode ビルド・iOS 26 シミュレータ制御
````

Codex CLI が `AGENTS.md` に追記する場合、既存内容と矛盾しない場所に配置すること。
すでに `AGENTS.md` がある場合は、上記の各セクションを「Codex 用」とマークして
末尾に追加する形にする。

## 6. 自作スキル個別仕様

SKILL.md フォーマットは Claude Code 版と完全に同じ。**前回 Claude Code 用に作成したものと
本文は同一**で、配置先だけ `.claude/skills/` → `.agents/skills/` に変わる。

### 6.1 `.agents/skills/xcodegen-regen/SKILL.md`

````markdown
---
name: xcodegen-regen
description: project.yml を編集したとき、ShiftAlarm.xcodeproj に不整合があるとき、ファイル追加・削除でビルドが通らなくなったときに使用する。XcodeGen 再生成とビルド検証を統一的に行う。
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
- `project.yml` を編集したら必ず `verify.sh` を回す(ビルド成功・テスト 91 件パスを確認)。
- Snapshot テスト 5 件は既定でスキップ。動かしたい場合は `SNAPSHOT_TESTING_ENABLED=1`。
- XcodeBuildMCP を入れている場合でも、CI と乖離しないよう `scripts/verify.sh` を一次手段とする。

## やってはいけない

- `ShiftAlarm.xcodeproj/project.pbxproj` を手書きで編集する。
- `Config/LocalSigning.xcconfig` を作成・編集・コミットする(ローカル専用、`.gitignore` 対象)。
- 既定のバンドル ID(`com.example.*`)のまま実機ビルドする(`p0-readiness.sh` が落ちる)。
````

### 6.2 `.agents/skills/alarmkit-scheduling/SKILL.md`

````markdown
---
name: alarmkit-scheduling
description: AlarmScheduler、DayResolver、AlarmKit 経由のアラーム登録／キャンセル／diff-sync、ローテーションパターン展開、休暇オーバーライドを編集・デバッグするときに使用する。
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

- API 仕様確認：context7 MCP 経由で <https://developer.apple.com/documentation/alarmkit> を fetch
- テスト実行：`bash scripts/verify.sh test`(or xcodebuild MCP)

## 変更後に必ず確認すること

- `bash scripts/verify.sh test` で AlarmScheduler 系のユニットテストがパスする。
- precedence や境界条件を変える場合は、必ず新しいテストケースを追加する。

## やってはいけない

- AlarmKit に直接アクセスするコードを `Sources/Features/`(SwiftUI 層)に書く。
  必ず `Sources/Services/AlarmKit/` のスケジューラ越し。
- precedence ルールを断りなく変える。
- BGAppRefresh のスケジュール頻度を上げる(OS から絞られて逆効果になりやすい)。
````

**Codex CLI による `references/day-resolver.md` 埋め込みタスク:**

- `Sources/Domain/DayResolver*` を読んで、precedence の具体例を 2〜3 個記述：
  - 祝日とローテーションが衝突したときに holiday が勝つ例
  - 手動割当が祝日より優先される例
  - ローテーションが none の日に何も登録されない例

### 6.3 `.agents/skills/swiftdata-migration/SKILL.md`

````markdown
---
name: swiftdata-migration
description: Sources/Domain/ の SwiftData @Model を追加・変更・削除するとき、App Group ストアとの整合性、既存ユーザーデータのマイグレーション、Widget との SwiftData 共有を扱うときに使用する。
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

- API 仕様確認：context7 経由で <https://developer.apple.com/documentation/swiftdata/schemamigrationplan> を fetch

## やってはいけない

- マイグレーションを書かずに `@Model` の型を破壊的に変える(既存ユーザーのデータが消える)。
- App Group ID を変更する(既存インストールで Widget と本体が見えなくなる)。
- `.shiftalarm` JSON のスキーマを変えずに `@Model` だけ変える(インポートが壊れる)。

## 参照
- `references/app-group-store.md` — App Group SwiftData ストアの設定とパス
````

**Codex CLI による `references/app-group-store.md` 埋め込みタスク:**

- `App/` の entitlements を読んで App Group ID の設定箇所を特定
- `Sources/Services/` の SchemaContainer 初期化箇所を特定
- `Widget/` 側で同じ App Group を参照している箇所を特定
- ストア URL の決まり方を整理(`FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)`)

## 7. 作業フロー

1. ブランチを切る：`git switch -c chore/codex-bootstrap`
2. `.codex/config.toml` を作成(§4)
3. `AGENTS.md` を作成または追記(§5)
4. `.agents/skills/` 配下に3スキルを作成(§6)
   - `references/` 配下は実コードを `grep` / `view` で読んで埋める
5. `.gitignore` に **追加不要**。`.codex/config.toml` `.agents/skills/` `AGENTS.md` は
   全て共有が目的なのでコミット対象。**ただし**、開発者個別の `~/.codex/config.toml` は
   元から git 管理外なので追加不要。
6. 動作確認：
   - `codex mcp list` で `context7` / `xcodebuild` の2つが見える
   - Codex CLI を起動し、`/skills`(or `$` メンション)で3スキルが見える
   - `project.yml` を軽く触って `xcodegen-regen` が自動発動するか確認
   - `bash scripts/verify.sh` で 91 テストが既存通りパスする
7. PR 作成：
   ```bash
   gh pr create \
     --repo dolquis/Calender_Aralrm \
     --base main \
     --head chore/codex-bootstrap \
     --draft \
     --title "chore(codex): bootstrap .codex/, AGENTS.md, .agents/skills/ for ShiftAlarm" \
     --body "Codex CLI setup: MCP servers (context7, xcodebuild) + custom skills (xcodegen-regen, alarmkit-scheduling, swiftdata-migration)."
   ```

## 8. Claude Code 版との関係 / 二重管理について

- **初回 bootstrap 時のスコープ分離（この doc に従う一度きりの作業の範囲）**：
  本 doc に従って Codex 用ファイル (`.codex/`, `.agents/`, AGENTS.md 追記) を新規に
  追加する作業中は、既に存在する Claude Code 用設定 (`.claude/`, `.mcp.json`,
  `CLAUDE.md`) を **同じ PR では触らない**（PR を Codex 専用に保ち、レビュー範囲を
  小さく保つため）。
- **bootstrap 後の継続運用ルール（AGENTS.md §10 が正）**：
  bootstrap 完了後、MCP 定義やスキル本文を変更する際は、`.mcp.json` と
  `.codex/config.toml`、`.claude/skills/` と `.agents/skills/` の **両方を必ず
  同時に更新する**。これが AGENTS.md §10 で定めた二重管理の正規ルール。上の
  「触らず独立に維持」は **新規 bootstrap PR のスコープ制限** であって、将来の
  更新作業に拡張してはならない。
- 将来的に統合したくなったら、ハイブリッド戦略(B)に移行可能。
  実体を `.agents/skills/` 側に置き、`.claude/skills/` から symlink。macOS 開発なので
  シンボリックリンクは自然に動く(`git config core.symlinks true` も基本不要)。

## 9. 完了基準(DoD)

- [ ] `.codex/config.toml` がリポジトリ直下にあり、2 MCP サーバーが定義されている。
- [ ] `.codex/config.toml` にシークレットが直書きされていない。
- [ ] `AGENTS.md` がリポジトリ直下にあり、PR 規約・ビルド・swift-format・Widget が記載されている。
- [ ] `.agents/skills/` 配下に 3 スキル(`xcodegen-regen`, `alarmkit-scheduling`, `swiftdata-migration`)が
      作成され、実コードに即した `references/` も整備されている。
- [ ] `codex mcp list` で 2 MCP サーバーが認識されている。
- [ ] Codex CLI 起動時に `AGENTS.md` が読み込まれる(`/init` で出力が確認できる)。
- [ ] スキルの自動発動が確認できる(`project.yml` 編集で `xcodegen-regen` が発動)。
- [ ] `bash scripts/verify.sh` で 91 テストが既存通りパスする。
- [ ] Draft PR が `dolquis/Calender_Aralrm` 宛で作成されている。
- [ ] Claude Code 用ファイル(`.claude/` `.mcp.json` `CLAUDE.md`)が変更されていない。

## 10. 参考リソース

- Codex 公式 — AGENTS.md: <https://developers.openai.com/codex/guides/agents-md>
- Codex 公式 — Config Reference: <https://developers.openai.com/codex/config-reference>
- Codex 公式 — Skills: <https://developers.openai.com/codex/skills>
- Codex 公式 — MCP: <https://developers.openai.com/codex/mcp>
- Codex 公式 — Plugins: <https://developers.openai.com/codex/plugins>
- XcodeBuildMCP: <https://github.com/cameroncooke/XcodeBuildMCP>
- Swift Agent Skills(Paul Hudson、個人インストール推奨): <https://github.com/twostraws/swift-agent-skills>
- AlarmKit: <https://developer.apple.com/documentation/alarmkit>
- WidgetKit: <https://developer.apple.com/documentation/widgetkit>
- ActivityKit: <https://developer.apple.com/documentation/activitykit>
- SwiftData: <https://developer.apple.com/documentation/swiftdata>
