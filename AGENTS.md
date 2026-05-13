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

## 2. 開発状況のステートマシン

現在地は **P0-1（AlarmKit / ActivityKit シグネチャ再確認）開始前**。
詳細フェーズは `ROADMAP.md` §1 を見ること。

完了済みの主要 PR:

- #1 初期スキャフォールド（直接マージはせず #5 で救出）
- #2 EventKit によるシステムカレンダー祝日インポート
- #3 `DayDetailEditorView` の状態漏れ修正
- #5 PR #1 残差の安全救出（`CalendarDay`、singleton、deep link 等）
- #6 Swift 6 / Xcode 26 ビルド修正、`scripts/verify.sh`、GitHub Actions CI

オープン PR / Issue は 0。

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
```

CI は `.github/workflows/ios.yml` が `macos-26` / Xcode 26+ で
`scripts/verify.sh` を実行する。**CI 緑 = ローカル `verify.sh` 緑** が前提。

---

## 5. 触ってよい / 触ってはいけないもの

### 触ってよい
- `Sources/**`, `App/**`, `Widget/**`, `Tests/**`, `Resources/**`
- `project.yml`（変更後は `bash scripts/regen.sh`）
- `.github/workflows/*.yml`
- `scripts/*.sh`

### 触る前に必ず影響を確認
- `Sources/Domain/Persistence/SchemaV1.swift` — SwiftData スキーマ。
  non-optional 追加はマイグレーションが必要。
- `App/ShiftAlarm.entitlements`, `Widget/ShiftAlarmWidget.entitlements` —
  App Group / AlarmKit / iCloud。
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
5. PR 説明には **何を直したか / なぜ / どうテストしたか** を書く。

---

## 7. 困ったときの参照順

1. `ROADMAP.md` の該当タスクの「対象ファイル」「DoD」
2. `ROADMAP.md` §6「ファイル別の触るときの注意」
3. 過去 PR の説明文（特に #1 / #2 / #5 / #6）
4. `README.md` の Architecture notes セクション
