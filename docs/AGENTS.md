# docs/ instructions

- `README*.md`、`ROADMAP.md`、`AGENTS.md`、`CLAUDE.md`、`docs/` を変更するときは `doc-governance` を使う。日本語文書を新規作成または大きく推敲するときは `japanese-doc-workflow` を入口にする。
- `ROADMAP.md` は大きいので、Issue が示す §P0-x 等の見出しと §6 のファイル別索引を `rg` で特定し、必要な節から読む。全体監査が必要な場合を除き、一律に全文を読み込まない。
- コード変更で DoD、対象ファイル、依存関係、手動テスト手順が変わる場合は、`ROADMAP.md` と `README*.md`、該当する `docs/p2-*.md` を同じ PR で更新する。実装で既存記述が偽になる場合は同じ PR で定義文へ書き換える。
- 状態、進捗、行番号付きコード参照、変動する実測件数（テスト件数を含む）を恒常文書へ複製しない。状態の正典は Linear である。
- ドキュメントを更新したら、`.claude/skills/**/SKILL.md` と `.agents/skills/**/SKILL.md` が stale 化していないか確認する。ビルド手順、Xcode / iOS バージョン、MCP / plugin 設定は Skill 側に古い値が残りやすい。PR 前に次を実行する。

  ```sh
  rg 'XCTest|Swift Testing|Xcode 26|iOS 26|verify\.sh|lint\.sh|XcodeBuild|Context7' \
    -g '!docs/archive/**' README*.md AGENTS.md ROADMAP.md docs .claude .agents
  ```

- 新規または rename した文書は `docs/README.md` に索引する。更新しない前提の記録は `docs/archive/` へ移す。archive は鮮度チェックの対象外である。
- `docs/linear-conventions.md` の共有コアと、`dolquis/agent-ops` からベンダリングした共有 Skill の本文・`references/` はこの repo で編集しない。
- 変更後は `python3 scripts/docs-lint.py --baseline .docs-lint-baseline.json` を実行し、ベースラインからの増加がないことを確認する。
