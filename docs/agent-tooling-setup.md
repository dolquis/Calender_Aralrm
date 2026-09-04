# エージェント用ツールのセットアップと診断

本書は、Claude Code と Codex が Calender_Aralrm の調査、ビルド、検証で使うホスト側ツールの恒常 runbook である。標準のビルド、テスト、lint、補助ツールの手順は `README.md` に置き、本書ではエージェント固有の接続条件だけを扱う。本書は `AGENTS.md` の「プロジェクトと正典」「条件付きで読む資料」「Human Gate と編集禁止対象」から参照される。

## 設定の正典

- Claude Code の repo MCP は `.mcp.json`、プラグイン（`swift-lsp` など）と SessionStart hook は `.claude/settings.json` が定義する。
- Codex の repo 固有 sandbox と MCP は `.codex/config.toml` が定義する。MCP 定義を増減したら両方を同時に更新し、用途と起動方式を一致させる。
- secret は設定ファイルへ直書きせず、必要なら `${ENV_VAR}` 経由で渡す。

設定ファイル自体がサーバー名、URL、引数の正典である。本書へ一覧を転記せず、接続失敗時は設定ファイルとユーザー連携の両方を確認する。

## repo 同梱の MCP と同梱しないもの

- Context7 は AlarmKit / WidgetKit / ActivityKit / SwiftData / HealthKit の Apple ドキュメント参照に使う。HTTP 接続で全 OS で動く。
- xcodebuild MCP は Xcode ビルドと iOS 26 シミュレータ制御を構造化 JSON で扱う。macOS + Xcode 26 と Node 18+ が前提で、`mcp` サブコマンドが無いと CLI モードで起動して MCP サーバーが立たない。Linux / Windows では起動失敗が想定動作である。
- Linear は repo 同梱の MCP 設定に含めない。Linear へのアクセスは実行環境またはアカウント側のコネクタか Linear Web UI で行い、特定の MCP ツール名に依存しない。

## ホスト側の補助ツール

- CodeGraph（`.codegraph/`）は構造、呼び出し関係、変更影響範囲の候補出しに使う。データはローカル生成物で、`.codegraph/.gitignore` が本体を除外する。
- Serena（`.serena/`）は symbol の宣言、実装、参照、診断、意味的リファクタリングに使う。`.serena/project.yml` は共有設定としてコミットし、cache と `project.local.yml` は `.serena/.gitignore` が除外する。
- Context-Mode（`.context-mode/`、`.ctx/`）は長い文書、検索結果、diff、build / test / CI log の整理に使う。

いずれも開発者のローカル環境に導入する任意ツールで、Claude Code on the web や Codex Cloud には無い。接続できない場合は、対象を狭めた `rg`、ファイル読み取り、build / test log の直接確認へ切り替える。要約結果は候補抽出に使い、修正完了の判断は実ファイル、最新 diff、関連テストで行う。

## Skill ミラーの意図的非対称

repo 所有 Skill の `.claude/skills/` 版と `.agents/skills/` 版は、次の差異だけを許す。同期時は片方を丸ごとコピーして上書きせず、フィールド単位で維持する。差分は `python3 scripts/docs-lint.py --category mirror` と `diff -qr .claude/skills .agents/skills` で確認する。

| 箇所 | Claude 版 | Codex 版 | 理由 |
|---|---|---|---|
| frontmatter `allowed-tools` | あり | なし | Codex の SKILL.md は `name` / `description` のみ |
| 補助ツール節の `swift-lsp` 言及 | あり | なし | Claude Code 公式プラグインで Codex には無い |
| `Context7` / `XcodeBuildMCP` の表記 | プラグイン名（PascalCase） | MCP サーバー名（小文字） | 各ツール側の表記慣習 |
| `references/` | 同一 | 同一 | 例外なし |

`doc-coauthoring` は Claude 専用で `.claude/skills/` のみに置く。

## Claude Code on the web

`.claude/settings.json` の SessionStart hook が `scripts/cloud-setup.sh` を呼び、remote セッションでのみ gitleaks、typos などのクロスプラットフォームツールを導入する。ローカルでは何もしない。Xcode 依存の periphery、xcresultparser、`buildServer.json` はローカル mac と macOS CI 専用である。

## 過去の bootstrap 記録

Claude Code / Codex の初期セットアップ手順は `docs/archive/` の `claude-code-bootstrap.md` と `codex-bootstrap.md` に凍結してある。運用ルールの正典は `AGENTS.md`、Skill 本文の正典は各 `SKILL.md` である。
