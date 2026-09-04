@AGENTS.md

# CLAUDE.md — Claude Code 固有事項

`AGENTS.md` を共通契約として一度だけ import する。ここでは再読せず、Claude Code 固有事項だけを定める。

repo 固有のセルフレビュー項目と検証コマンドは `AGENTS.md` の「検証とセルフレビュー」を正典とし、共通手順は `pre-pr-self-review` に置く。`dolquis/agent-ops` からベンダリングした共有 Skill の本文・`references/` は、この repo で直接編集しない。

## 日本語文書

日本語の README、設計書、仕様書、解説の本格的な作成・推敲では `japanese-doc-workflow` を入口にする。短いコメント、コミットメッセージ、コードだけの変更には使わない。

## Advisor（Fable）

複数段階の作業の計画レビュー、AlarmKit スケジューリングや SwiftData マイグレーションなど既存ユーザーデータに影響する設計の着手前、ローテーション展開・休暇オーバーライドなど仕様分岐が複雑なロジックの方針決定、繰り返す失敗、重要変更の完了前レビューでは、利用可能なら Fable Advisor に相談する。助言は批判的に検討し、最終判断は自分で行う。

typo や軽微で可逆な変更では使わず、Linear 運用や人間のレビューゲートの代替にしない。未設定の環境では本節を無視してよい。
