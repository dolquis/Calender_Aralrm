# AGENTS.md — Calender_Aralrm（Shift Alarm）エージェント規約

原則として日本語で回答する。本ファイルは、このリポジトリで常時適用する最小の共通契約である。詳細は作業に必要な正典の該当 ID・節だけを読む。

## 1. プロジェクトと正典

Shift Alarm は、iOS 26+ / Swift 6 / SwiftUI + SwiftData / AlarmKit で作るシフト勤務者向け目覚ましカレンダーアプリである。AlarmKit で silent / focus mode を貫通して鳴らし、月カレンダー、プリセット、ローテーション、祝日オーバーライド、`.shiftalarm` 共有、Widget / Live Activity、ja-en ローカライズを持つ。iCloud 同期と Apple Watch はスコープ外である。

| 対象 | 正典 |
|---|---|
| フェーズ・タスク定義、DoD、依存関係、対象ファイル | `ROADMAP.md`（§P0-x 〜 §P3-x） |
| ファイル別の触るときの注意 | `ROADMAP.md` §6 |
| アルゴリズム詳細、P2 設計仕様 | `docs/p2-*.md` |
| 状態・進捗・優先度・担当・計画 | Linear の Shift Alarm / Calender_Aralrm |
| Linear 運用（共有コアと §13 Project Delta） | `docs/linear-conventions.md` |
| 機能一覧、ビルド・テスト・手動確認手順、補助ツール | `README.md`（英語）/ `README.ja.md`（日本語） |
| CI の構成 | `.github/workflows/ios.yml` |
| MCP・プラグイン・ホスト前提 | `.mcp.json`、`.codex/config.toml`、`docs/agent-tooling-setup.md` |

進捗・完了状態は本ファイルにも `ROADMAP.md` にも書かず Linear に置く。

## 2. 作業開始と変更方針

- 進捗や PR の確認前は必要に応じて `git fetch origin` で更新し、作業ブランチを切り替えずに `origin/main` との差を確認する。
- 対象タスクの DoD・対象ファイルが `ROADMAP.md` に無ければ確認を取り、推測で schema、既定値、アルゴリズムを確定しない。
- 最小差分を基本とし、無関係なリファクタリング、整形、rename を混ぜない。大きな設計変更は着手前にユーザーへ確認する。

## 3. 条件付きで読む資料

全資料を一律に全文読込しない。`ROADMAP.md` は大きいので、Issue が示す §P0-x 等の見出しを `rg` で特定し、必要な節を前後の文脈とともに読む。

| 作業 | 読むもの |
|---|---|
| 通常の実装・修正 | Issue が示す `ROADMAP.md` の節（対象ファイル・DoD）、同 §6 の該当ファイル行、関連実装・テスト |
| AlarmKit スケジューリング、DayResolver、ローテーション展開、休暇オーバーライド | `alarmkit-scheduling` と同 Skill の `references/` |
| SwiftData `@Model` の追加・変更、App Group ストア、Widget との共有 | `swiftdata-migration` と同 Skill の `references/` |
| `project.yml` 編集、ファイル追加・削除、`.xcodeproj` 不整合 | `xcodegen-regen` |
| P2 の新機能（一括プリセット適用、休日アラーム制御など） | `docs/p2-*.md` の該当仕様と `ROADMAP.md` §9 のテスト項目 |
| 実機検証、署名、P0 確認 | `README.md` の Build 節、`scripts/p0-readiness.sh`、`scripts/p0-device-build.sh` |
| Linear / PR 状態変更、起票、ラベル | `docs/linear-conventions.md` の該当節と §13 Project Delta、既存 Issue / PR の最新状態 |
| 日本語の本格的な文書作業 | `japanese-doc-workflow`。短いコメントやコミット文には使わない |
| docs の軽微な修正 | 対象文書、docs lint（手順は `doc-governance`）。無関係な正典は読まない |
| MCP・ツール・ホスト前提 | `.mcp.json`、`.codex/config.toml`、`docs/agent-tooling-setup.md` |

## 4. 調査・実装ツール

- 単一ファイルや単純検索は Read / Edit / `rg` を使う。
- `.codegraph/` があり CodeGraph が利用可能で、構造や影響範囲が不明なら先に使う。結果は実ファイルとテストで確認する。
- Serena が利用可能なら symbol の宣言、実装、参照、診断、意味的リファクタリングに使う。開始前に project / languages を確認する。
- Context-Mode が利用可能なら大量の文書、検索結果、diff、ログ、CI 出力の整理に使う。要約だけで完了判断しない。
- Context7 が利用可能なら AlarmKit / WidgetKit / ActivityKit / SwiftData / HealthKit の Apple ドキュメント参照に使う。xcodebuild MCP は macOS + Xcode 26 でのみ動く。
- SwiftData schema、entitlements、`.shiftalarm` 公開フォーマットなどの影響確認では、利用可能な構造解析を使い、使えない環境では `rg`、実ファイル、関連テスト、文書で確認する。
- GitHub connector が利用可能なら優先し、使えない場合は `gh` を使う。

## 5. 実装上の不変条件

- `ShiftAlarm.xcodeproj/` の中身を手で編集しない。すべて `project.yml` 経由で `bash scripts/regen.sh` する。
- `Sources/Domain/Persistence/SchemaV1.swift` の non-optional 追加はマイグレーションが必要である。`Sources/Domain/Models/` を触ったら `swiftdata-migration` に従い、App と Widget の双方（`Widget/` の `ModelContainer` 初期化を含む）で同 schema を扱えることを確認する。
- `App/ShiftAlarm.entitlements` と `Widget/ShiftAlarmWidget.entitlements`（App Group / AlarmKit / HealthKit）の変更は影響を確認してから行う。
- `Sources/Services/Sharing/ShiftBundleCodec.swift` の `.shiftalarm` 公開フォーマットは互換性を壊さない（legacy `exportedAt` の受け入れと `CalendarDay` を踏襲）。
- AlarmKit / ActivityKit の API 差分対応は `AlarmConfigurationBuilder.swift` と `LiveActivityController.swift` に局所化する。`AlarmService.swift` / `AlarmScheduler.swift` を触ったら `bash scripts/verify.sh` で `Sendable` 警告が増えないことを確認する。
- ローカライズ追加時は `Resources/Localizable.xcstrings` の ja / en 両方を埋める。片言語のみだとバリデーション結果が空表示になりうる。
- 画像インポート、DOW ルール展開、連休グルーピングなど破壊的変更は、Apply 前に必ず `ChangePreview` 経由でユーザーに確認させる（Preview before mutation）。
- 署名の実値は git ignore 済みの `Config/LocalSigning.xcconfig` に置き、`Config/SigningDefaults.xcconfig` と `.example` に書かない。
- repo docs は定義だけを持ち、状態を持たない。見出しで進捗・完了を主張せず、状態語（語彙は `python3 scripts/docs-lint.py --print-words`）を地の文へ書かず、行番号や実測件数（テスト件数など）をコード参照に書かない。状態の正典は Linear である。
- 実装で `ROADMAP.md`、`README*.md`、`docs/` の既存記述が偽になる場合は、同じ PR で DoD・対象ファイル・手順を定義文へ書き換える。`ROADMAP.md` が唯一のトラッカーだった期間の記録は削除せず `docs/archive/` へ移す。
- MCP の secret は設定ファイルへ直書きせず、`${ENV_VAR}` 経由で渡す。MCP 定義の増減は `.mcp.json` と `.codex/config.toml` の両方に反映する。

## 6. 検証とセルフレビュー

- 最小ゲートは `bash scripts/lint.sh check` と `bash scripts/verify.sh`（CI と同じ。macOS + Xcode 26 が必要）。CI 緑はこの 2 つがローカルで緑であることを前提とする。実機向け変更を含む場合は `bash scripts/p0-readiness.sh` も確認する。個別コマンドと補助ツールは `README.md` にある。
- `README*.md`、`ROADMAP.md`、`AGENTS.md`、`CLAUDE.md`、`docs/`、Skill を変更したら `python3 scripts/docs-lint.py --baseline .docs-lint-baseline.json` と `python3 scripts/check_agent_instruction_size.py` を実行し、ベースラインからの増加と予算超過がないことを確認する。
- repo 内ファイルを変更したら、最終報告前と stage、commit、push、PR 更新前に `pre-pr-self-review` を使う。利用できない環境では、`origin/main` との全差分と未追跡ファイル、secret や生成物の混入、編集境界、P1 / P2、文書同期、検証結果を確認する。
- 変更起因の問題は修正して関連検証を再実行する。無関係な既存問題は勝手に直さず報告する。未実施・失敗・既存失敗は理由と影響を明記する。
- Linux / Claude Code on the web では Xcode 依存の build / test は実行できない。gitleaks、typos、docs-lint、予算検査だけを回し、実機・シミュレータ確認は人間へ引き渡す。

## 7. Linear・ブランチ・PR

- 実装は Linear Issue 起点とし、原則 `dolquis/dev-<番号>-<slug>`、1 Issue = 1 branch = 1 Draft PR とする。
- `main` へ直接 push / force push しない。PR は `dolquis/Calender_Aralrm` の `main` 向けとし、base / head / compare 範囲と同一 head の既存 PR を確認する。
- 新規 PR は Draft で作成し、`create-draft-pr` が利用可能なら使う。`scripts/verify.sh` が緑になってから ready for review にする。既存 Ready PR を Draft に戻さない。通常のマージ方法はノーマルマージとする。
- PR 本文に何を直したか、なぜ、どうテストしたか、Linear Issue、Documentation impact を書く。GitHub ミラーがある場合のみ `Closes #N` / `References #N` を併記する。
- Draft PR 作成で Linear を In Review、マージで Merged とし、検証メモを残してから Done へ明示遷移する。人間ゲート課題は Todo で待機させる。状態・ラベル・週次監査の規約は必要時に `docs/linear-conventions.md` の該当節を読む。
- セッション内で直さない問題は Linear の Shift Alarm / Calender_Aralrm に起票する。ラベルは `repo:Calender_Aralrm`、`area:*`（docs は `area:docs`）、`agent:*` または `gate:human-required`、種別ラベルを付け、優先度は P0→Urgent / P1→High / P2→Medium / P3→Low にマップする。本文は要約と正典へのリンクに留め、`ROADMAP.md` の該当節の `追跡:` 行を更新する。repo 側の詳細仕様を Issue へ移して削除しない。
- `agent:codex-*` は候補ラベルであり、Codex Cloud の assign / delegate / mention には人間 lead の明示許可が要る（`docs/linear-conventions.md` §2.1）。

## 8. Human Gate と編集禁止対象

- 実機での AlarmKit 動作、署名、Apple Developer 設定、App Store 提出に関わる確認は CI やシミュレータで代替せず、人間へ引き渡す。
- `docs/linear-conventions.md` の共有コア（§1〜§12）、`scripts/docs-lint.py`、`scripts/check_agent_instruction_size.py` とそのテスト、`dolquis/agent-ops` からベンダリングした共有 Skill の本文・`references/` をこの repo で直接編集しない。変更は origin で行い配布し直す。Project Delta、`.docs-lint.toml`、repo 所有のドメイン Skill は Issue の範囲で変更できる。
- repo 所有 Skill（`xcodegen-regen`、`alarmkit-scheduling`、`swiftdata-migration`）は `.agents/skills/` と `.claude/skills/` を同じ PR で同期する。`references/` は完全一致、`SKILL.md` は frontmatter と `swift-lsp` 言及などの意図的非対称（`docs/agent-tooling-setup.md`）を除いて同一に保つ。`doc-coauthoring` が Claude 側だけにある非対称は意図的である。
- secret、credential、token、`.env`、`Config/LocalSigning.xcconfig`、生成物、ローカル設定、`.codegraph/`、`.serena/` の cache と memories、`.context-mode/`、`.ctx/`、キャッシュ、セッションログを編集・index・commit しない。
