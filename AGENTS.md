# AGENTS.md — エージェント向けエントリポイント

このファイルは **OpenAI Codex / Claude Code / その他コーディングエージェント** が
このリポジトリで作業を始める際に最初に読むべき要約です。

詳細な開発計画は **`ROADMAP.md`** を参照してください。

---

## 1. 何のプロジェクトか

- iOS 26+ / Swift 6 / SwiftUI + SwiftData / AlarmKit ベースの
  **シフト勤務者向け目覚ましカレンダーアプリ**。
- AlarmKit を使うことで silent / focus mode を貫通してアラームを鳴らす。
- 月カレンダー / プリセット / ローテーション / 祝日オーバーライド /
  共有 (`.shiftalarm` JSON & URL scheme) / Widget / Live Activity / ja-en ローカライズ。

詳細: `README.md` (英語) / `README.ja.md` (日本語)

---

## 2. 開発状況

開発フェーズ・完了済み PR・既知の不安要素の**最新状況は `ROADMAP.md` §0
「現状サマリ」が唯一の正**。作業前に必ず参照すること（重複を避けるため本ファイルに
PR 一覧は再掲しない）。

概況（2026-05-21 時点）: P1 群（P1-1〜P1-4）と P2-2（Sleep / Bedtime / HealthKit /
App Intents）完了。P2-α（シフトパターン自動検出）と P2-η（`.ics` エクスポート）も
実装済み。次の焦点は `Config/LocalSigning.xcconfig` に実 Developer Portal 値を入れて
`scripts/p0-readiness.sh` を緑にし、P0-3 の実機ゴールデンパス検証を行うこと。
残る新機能ロードマップは P2-β（長期連休越境）/ P2-γ（シフト表画像 AI 解析） —
`ROADMAP.md` §4 を参照。iCloud 同期と Apple Watch は **スコープ外（不採用）**。

---

## 3. 作業を始める前に必ず読むファイル

| 優先度 | パス | 目的 |
|---|---|---|
| 必読 | `ROADMAP.md` | フェーズ・タスク・DoD・運用ルール |
| 必読 | `README.md` または `README.ja.md` | 機能、ビルド手順、手動テスト手順 |
| 任意 | `ROADMAP.md` §6 ファイル別索引 | 触ろうとしているファイルの注意点 |

---

## 4. ビルド / テスト

```sh
# 初回のみ
bash scripts/bootstrap.sh

# XcodeGen で .xcodeproj 再生成
bash scripts/regen.sh

# ビルド + テスト（CI と同じ。iOS 26 simulator 自動選択）
bash scripts/verify.sh

# 固定 destination で実行したい場合
DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' bash scripts/verify.sh

# Swift コードスタイル検査 / 自動整形（CI の lint ジョブと同じ）
bash scripts/lint.sh check   # 違反があれば非ゼロ終了
bash scripts/lint.sh fix     # その場で整形
```

CI は `.github/workflows/ios.yml` が `macos-26` / Xcode 26+ で実行する。
`build-test` ジョブが `scripts/verify.sh`、`lint` ジョブが `scripts/lint.sh check`
（`swift-format`、設定は `.swift-format`）を並列に走らせる。
**CI 緑 = ローカルで `verify.sh` と `lint.sh check` がともに緑** が前提。
現状は 85 件の XCTest（16 テストクラス、うち DayCell snapshot 5 件は通常 verify で
skip）を確認する。
実機向け P0 確認は `bash scripts/p0-readiness.sh`、実機 build 入口は
`bash scripts/p0-device-build.sh`。

---

## 5. 触ってよい / 触ってはいけないもの

### 触ってよい
- `Sources/**`, `App/**`, `Widget/**`, `Tests/**`, `Resources/**`
  （オンボーディングは `Sources/Features/Onboarding/`、Sleep schedule は
  `Sources/Features/SleepSchedule/`、HealthKit / App Intents は
  `Sources/Services/HealthKit/` および `Sources/Services/AppIntents/`）
- `project.yml`（変更後は `bash scripts/regen.sh`）
- `Config/SigningDefaults.xcconfig`, `Config/LocalSigning.xcconfig.example`
  （実値は git ignore 済みの `Config/LocalSigning.xcconfig` に置く）
- `.github/workflows/*.yml`
- `scripts/*.sh`

### 触る前に必ず影響を確認
- `Sources/Domain/Persistence/SchemaV1.swift` — SwiftData スキーマ。
  non-optional 追加はマイグレーションが必要。
- `App/ShiftAlarm.entitlements`, `Widget/ShiftAlarmWidget.entitlements` —
  App Group / AlarmKit / HealthKit。
- `Sources/Services/Sharing/ShiftBundleCodec.swift` —
  `.shiftalarm` 公開フォーマット。互換性を壊さないこと
  （PR #5 の legacy `exportedAt` 受け入れと `CalendarDay` を踏襲）。

### 触らない
- `ShiftAlarm.xcodeproj/` の中身を **手で編集しない**。
  すべて `project.yml` 経由 → `scripts/regen.sh`。
- `main` への直接 push 禁止。

---

## 6. ブランチ / PR 運用

1. `feature/<topic>` または `fix/<topic>` を `main` から切る。
2. PR は **draft で作成**。`scripts/verify.sh` が緑になってから ready for review。
3. ローカライズ追加時は `Resources/Localizable.xcstrings` の **ja / en 両方** を埋める。
4. AlarmKit / ActivityKit の API 差分対応は
   `Sources/Services/AlarmKit/AlarmConfigurationBuilder.swift` と
   `Sources/Services/LiveActivity/LiveActivityController.swift` に局所化する。
5. 実機検証前は `Config/LocalSigning.xcconfig.example` を
   `Config/LocalSigning.xcconfig` にコピーし、Team ID / bundle id / App Group を実値にする。
   その後 `bash scripts/regen.sh` と `bash scripts/p0-readiness.sh` を実行する。
6. PR 説明には **何を直したか / なぜ / どうテストしたか** を書く。
7. **プッシュ・PR 作成前にセルフレビューを必ず実施する**（下記 §6.1）。

### 6.1 プッシュ / PR 作成前のセルフレビュー

変更をプッシュして PR を作成する**前**に、必ず以下を実施すること。

1. `git diff`（新規ファイルは `git status`）で差分全体を読み返し、
   意図しない変更・デバッグコード・コメントアウトの残骸が混入していないか確認する。
2. `bash scripts/lint.sh check` と `bash scripts/verify.sh` がともに緑であることを
   確認する。実機向け変更を含む場合は `bash scripts/p0-readiness.sh` も確認する。
3. 上記 §5「触ってよい / 触ってはいけないもの」に違反していないか確認する。
4. ローカライズ追加時は `Resources/Localizable.xcstrings` の ja / en 両方を確認する。
5. コミットメッセージと PR 説明に **何を直したか / なぜ / どうテストしたか** が
   書かれているか確認する。
6. 変更箇所およびその周辺に**バグや P1 / P2 レベルの問題**（クラッシュ、
   データ不整合、回帰、アクセシビリティ欠落、`ROADMAP.md` で P1 / P2 と
   位置づけられる品質課題など）がないかを能動的に確認する。

セルフレビューで問題が見つかった場合は、プッシュ前に修正すること。
発見したバグや P1 / P2 レベルの問題は、当該変更のスコープ内であれば
本 PR で修正する。スコープ外で大きい場合は修正せず、`ROADMAP.md` への
反映や Issue 化を提案したうえでユーザーに確認する。

---

## 7. 困ったときの参照順

1. `ROADMAP.md` の該当タスクの「対象ファイル」「DoD」
2. `ROADMAP.md` §6「ファイル別の触るときの注意」
3. 過去 PR の説明文（特に #1 / #2 / #5 / #6 / #7 / #10 / #11 / #14）
4. `README.md` の Architecture notes セクション

---

## 8. スキル（`.agents/skills/` / `.claude/skills/`）

Codex CLI は `.agents/skills/`、Claude Code は `.claude/skills/` を参照する。本文は
両者で同一の物理コピー（将来 symlink 統合の余地は残す。詳細は §10）。

| name | 自動発動条件（概略） |
|---|---|
| `xcodegen-regen` | `project.yml` 編集、`.swift` ファイル追加・削除、`xcodebuild` でファイル不一致エラー時 |
| `alarmkit-scheduling` | `AlarmScheduler` / `DayResolver` / `RotationExpander` / BG lookahead を編集・デバッグするとき |
| `swiftdata-migration` | `Sources/Domain/` の `@Model` を追加・変更・削除、App Group ストアや `.shiftalarm` JSON 連動が絡むとき |

各スキルの本文は `SKILL.md`、補足は `references/` 配下（`day-resolver.md` /
`app-group-store.md`）にある。precedence や App Group の運用ルールはこの references が
唯一の正。

## 9. MCP サーバー（`.codex/config.toml` / `.mcp.json`）

| name | 用途 | 起動方式 |
|---|---|---|
| `context7` | AlarmKit / WidgetKit / ActivityKit / SwiftData / HealthKit の Apple ドキュメント参照 | HTTP (`https://mcp.context7.com/mcp`) |
| `xcodebuild` | Xcode ビルド・iOS 26 シミュレータ制御を構造化 JSON で扱う | stdio (`npx -y xcodebuildmcp`、Node 18+ 必須) |

macOS + Xcode 26 前提。Linux / Windows では `xcodebuild` MCP が起動失敗するが
想定動作（`context7` は全 OS で動く）。シークレットは設定ファイルに直書きせず、
必要なら `${ENV_VAR}` 経由で渡す。

## 10. 二重管理ルール（Claude Code 用と Codex 用）

`.claude/` と `.codex/` / `.agents/` は独立に維持する方針。両方を有意に保つために
以下を守ること：

1. スキル本文（`xcodegen-regen` / `alarmkit-scheduling` / `swiftdata-migration` の
   `SKILL.md` および `references/`）を変更したら、`.claude/skills/` と
   `.agents/skills/` の **両方** を同時に更新する。
2. MCP サーバー定義を増減した場合、`.mcp.json` と `.codex/config.toml` の両方を
   更新する（用途と起動方式が一致するように）。
3. ビルド / swift-format / Widget の運用ルールはこの `AGENTS.md`（§4 / §5 / §6）が
   唯一の正。`CLAUDE.md` はポインタのみで重複させない。
4. Claude Code 起動プロンプトと bootstrap ドキュメントは `docs/handoff/` に保管
   （`claude-code-bootstrap.md` / `codex-bootstrap.md`）。setup 完了後は
   `docs/archive/` への移動または削除を検討してよい。
