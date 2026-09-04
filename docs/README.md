# ドキュメント案内

Shift Alarm（Calender_Aralrm）の設計・運用ドキュメントの一覧と正典マップ。各ドキュメントが「何の正典か」をここで把握できる。

> 状態・進捗・優先度・担当の正典は Linear（Shift Alarm / Calender_Aralrm）である。repo docs は定義の正典であり、状態を持たない。エージェント規約の正典は [`AGENTS.md`](../AGENTS.md)、タスク定義と DoD は [`ROADMAP.md`](../ROADMAP.md)、ビルドと手動確認の手順は [`README.md`](../README.md) が正典。

## エージェント規約

| ドキュメント | 適用範囲 |
|---|---|
| [`docs/AGENTS.md`](AGENTS.md) | `docs/` で作業するときの規約 |
| [`docs/CLAUDE.md`](CLAUDE.md) | 上を Claude Code へ届ける import 専用ファイル |

## 設計

| ドキュメント | 役割 |
|---|---|
| [`p2-algorithms.md`](p2-algorithms.md) | P2-α / P2-β / P2-γ のアルゴリズム詳細 |
| [`p2-bulk-preset-apply.md`](p2-bulk-preset-apply.md) | P2-ε 日付一括選択とプリセット一括適用の仕様・DoD |
| [`p2-holiday-alarm-control.md`](p2-holiday-alarm-control.md) | P2-ζ 祝日のアラーム制御とカレンダー可視化の仕様・DoD |

## 運用

| ドキュメント | 役割 |
|---|---|
| [`agent-tooling-setup.md`](agent-tooling-setup.md) | エージェント用 MCP、補助ツール、Skill ミラーの非対称、cloud-setup の runbook |
| [`linear-conventions.md`](linear-conventions.md) | Linear 運用の共有コアと Project Delta |
| [`archive/`](archive/) | 更新しない前提の記録。鮮度チェックの対象外 |
