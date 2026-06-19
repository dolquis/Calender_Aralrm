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

**状態・進捗・優先度の正典は Linear**（team `Dev` / project **Shift Alarm /
Calender_Aralrm**。管制塔モデルの全体像は §6.1.2）。開発フェーズ・完了済み PR・
仕様サマリ・既知の不安要素は `ROADMAP.md` §0「現状サマリ」を参照する（重複を避けるため
本ファイルに PR 一覧は再掲しない）。状態と仕様の正典分担は §6.1.2 の正典マトリクスが唯一の正。

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
テストは Apple の Swift Testing（`@Test` / `#expect`）で記述。現状は 140 件のテスト
（20 テストスイート / 23 ファイル、うち snapshot 6 件は通常 verify で skip）を確認する。
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

1. Linear issue から生成されるブランチ名 `dolquis/dev-xx-*` を `main` から切る
   （Linear issue が無い緊急時のみ `feature/<topic>` / `fix/<topic>`）。
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
7. コード変更（機能実装・バグ修正・設計変更）を伴う場合は、`ROADMAP.md` /
   `README*.md` / `docs/` の記述と Issue 参照が実態と一致するよう更新したか確認する
   （詳細は §6.2）。

セルフレビューで問題が見つかった場合は、プッシュ前に修正すること。
発見したバグや P1 / P2 レベルの問題は、当該変更のスコープ内であれば
本 PR で修正する。**スコープ外で当該セッション内に修正しないものは、§6.1.1 に従い
Linear に起票**してハンドオフする（必要なら GitHub Issue にミラーする。大きな設計変更を
伴う場合は起票前に `AskUserQuestion` 等でユーザーに確認する）。

### 6.1.1 発見したバグ・Pending 問題の Linear 起票

**タスク・既知のバグ・修正待ちの問題は、まず Linear に起票して追跡する**のが本
リポジトリの方針（状態・進捗・優先度の正典は Linear。管制塔モデルの全体像は §6.1.2）。
セッション中に発見したが当該セッション内では修正しない問題は、以下に従って Linear に
起票すること。

1. **起票先**: Linear team **Dev** / project **Shift Alarm / Calender_Aralrm**
   に起票する（利用可能な Linear アクセス手段で。Linear はリポジトリ同梱の MCP 設定には
   含めず、実行環境 / アカウント側のコネクタまたは Linear Web UI で扱う — §9 参照）。
2. **登録内容**: issue を作成し、本文に以下を含める。
   - 問題の要約（タイトル）と再現手順（可能な場合）
   - 影響範囲（クラッシュ / データ不整合 / アラーム沈黙 など。P0〜P3 のどれ相当か）
   - 発見経緯と、当該セッションで直さない理由（スコープ外 / 別タスク化 等）
   - 関連コード・ドキュメント箇所（`file:line` 形式）
   - **詳細仕様・DoD は `ROADMAP.md` §P0-x / `docs/` に残し**、issue 本文は要約＋リンクに留める。
3. **ラベル（必須）**: `repo:Calender_Aralrm` ＋ 技術領域 `area:*`（ドキュメント・ガバナンス整合の Issue は repo 横断の共有 `area:docs` を使用）＋ 想定担当 `agent:*`
   （人手検証が要るものは `gate:human-required`）＋ 種別 `Bug` / `Improvement` / `Feature`（`kind:*` への統一は Phase 4。移行ルールは `docs/linear-conventions.md` §4）。
   - **Codex 実行ポリシー**: `agent:codex-*` は候補（ルーティング）ラベルで Codex 実行許可ではない。Codex Cloud の起動（assign / delegate / mention）は人間の明示許可があるときのみで、Claude は行わない。正典は `docs/linear-conventions.md` §2.1。
4. **優先度**: 重要度を Linear priority にマップする — **P0→Urgent / P1→High /
   P2→Medium / P3→Low**。
5. **GitHub ミラー（任意）**: 外部可視性が必要なら GitHub Issue にもミラーし、Linear 側に
   `Migrated` ラベルと GitHub への link 添付、GitHub Issue 側に Linear へのコメントを付けて
   **双方向リンク**にする。
6. **ドキュメントとの整合**: 既存の `ROADMAP.md` 等の本文は**残したまま**、該当節の
   `追跡:` 行を Linear issue（必要なら GitHub ミラー）に更新する（本文の詳細仕様を
   issue に移して削除しない）。§0「現状サマリ」の issue 一覧も必要に応じて更新する。

**理由**: known bug / pending をドキュメントだけに書くとセッション間で追跡が途切れ、
重複実装や見落としを招く。状態・進捗・優先度・エージェント・ルーティングを Linear に
一元化することで、複数セッション・複数エージェント間のハンドオフが確実になる。

### 6.1.2 Linear 運用（管制塔）

タスク管理は Linear を管制塔（control tower）とするハイブリッドモデルで運用する。

**正典マトリクス**

| 対象 | 正典 |
|---|---|
| 状態 / 進捗 / 優先度 / エージェント・ルーティング / 計画 | **Linear**（project Shift Alarm / Calender_Aralrm） |
| 仕様 / DoD / アルゴリズム詳細 | **repo docs**（`ROADMAP.md` §P0-x / `docs/`） |
| ビルド / テスト / 運用ルール | 本 `AGENTS.md` |
| 外部可視の課題ミラー | **GitHub Issue**（`Migrated` ラベル＋双方向リンク） |

**ラベル規約**: `repo:Calender_Aralrm`（リポジトリ識別）/ `area:*`（技術領域）/
`agent:*`（AI 担当）/ `gate:human-required`（人手検証要）/ `Migrated`（GitHub 由来）/
種別 `Bug` / `Improvement` / `Feature`。

**状態ライフサイクル**: Backlog → Todo → In Progress → In Review → Done
（中止は Canceled、重複は Duplicate）。ブランチ作成・PR で In Progress / In Review へ、
PR マージで Done へ遷移させる。

**ブランチ命名**: Linear issue が自動生成する `dolquis/dev-xx-*` を基本とする。

**週次監査**: Linear の recurring issue **DEV-23**「Linear control tower audit」で、
project / repo / area / agent ラベル欠落、`Migrated` issue の GitHub link 欠落、
`gate:human-required` 欠落、tracking issue の子リンク欠落、Done issue の検証メモ欠落、
および Codex safety checks（無許可の Codex delegate / mention、放置された delegate 済み
課題など。`docs/linear-conventions.md` §11）を点検する。監査は Linear の routing / handoff
のみを対象とし、GitHub docs の仕様本文は書き換えない。

**新規タスク群のレビュー観点（2026-05-27 仕様提案書取り込みで追加）**

`ROADMAP.md` §P0-4 / §P0-5 / §P1-5 / §P1-6 / §P2-α A2 / §P2-β / §P2-γ Phase 1
配下の作業時は、上記 1〜6 に加えて次を確認する:

- **`Sources/Services/AlarmKit/AlarmService.swift` / `AlarmScheduler.swift` を
  触ったか?**: `bash scripts/verify.sh` で `Sendable` 警告が増えていないことを
  確認する。Swift 6 strict concurrency 下で actor → protocol 化する箇所は
  `Sendable` / `@MainActor` の境界が崩れやすい。
- **`Sources/Domain/Models/` を触ったか?**: `.claude/skills/swiftdata-migration`
  または `.agents/skills/swiftdata-migration` の SKILL.md を読み、App と Widget
  の双方で同 schema を扱えていることを確認する。`Widget/` 配下の
  `ModelContainer` 初期化も含めて目視する。
- **`Resources/Localizable.xcstrings` を触ったか?**: ja / en 両方に key を追加
  したか確認する。`ShiftBundleValidationCode` のメッセージなど、片言語のみだと
  バリデーション結果が空表示になる可能性がある。P3-12 整合チェック自動化は
  未着手のため、当面は目視で担保する。
- **`ChangePreview` を経由する破壊的変更を追加したか?**: 画像インポート / DOW
  ルール展開 / 連休グルーピングは、Apply 前に必ず `ChangePreview` 経由で
  ユーザに確認させる導線になっているかを確認する（spec proposal の
  "Preview before mutation" 原則）。

### 6.2 コード変更時の進捗反映

機能実装・バグ修正・設計変更を行った場合は、コード差分だけで完了扱いにしない。
PR 前に以下を確認する。

- `ROADMAP.md` の該当タスクのステータス・DoD・対象ファイル・進捗メモが実態と
  一致しているか。
- `README.md` / `README.ja.md` の機能一覧・ビルド手順・手動テスト手順が
  古くなっていないか。
- `docs/` 配下の仕様・architecture note が実装と矛盾していないか
  （`docs/archive/` の歴史的記録は対象外）。
- 完了したタスクは Linear issue を **Done** に遷移させる（ブランチ / PR で自動遷移する
  場合も状態を確認する）。GitHub ミラーがある場合のみ PR 本文に `Closes #N`、参照のみは
  `References #N` を併記する（§6.1.1 / §6.1.2）。
- セッション内で修正しない新規バグ / pending は §6.1.1 に従って Linear に起票する。

特に `ROADMAP.md` 上で「未着手」「設計済み」「実装予定」と書かれている項目を
実装した場合は、同じ PR で `ROADMAP.md` を更新すること。

---

## 7. 困ったときの参照順

1. `ROADMAP.md` の該当タスクの「対象ファイル」「DoD」
2. `ROADMAP.md` §6「ファイル別の触るときの注意」
3. 過去 PR の説明文（特に #1 / #2 / #5 / #6 / #7 / #10 / #11 / #14）
4. `README.md` の Architecture notes セクション

---

## 8. スキル（`.agents/skills/` / `.claude/skills/`）

Codex CLI は `.agents/skills/`、Claude Code は `.claude/skills/` を参照する。本文は
**「意図的非対称を除いて」同一**（同期・例外規定は §8.2 参照、将来 symlink 統合の
余地は残す）。

| name | 自動発動条件（概略） |
|---|---|
| `xcodegen-regen` | `project.yml` 編集、`.swift` ファイル追加・削除、`xcodebuild` でファイル不一致エラー時 |
| `alarmkit-scheduling` | `AlarmScheduler` / `DayResolver` / `RotationExpander` / BG lookahead を編集・デバッグするとき |
| `swiftdata-migration` | `Sources/Domain/` の `@Model` を追加・変更・削除、App Group ストアや `.shiftalarm` JSON 連動が絡むとき |

各スキルの本文は `SKILL.md`、補足は `references/` 配下（`day-resolver.md` /
`app-group-store.md`）にある。precedence や App Group の運用ルールはこの references が
唯一の正。

### 8.1 意図的非対称（Claude / Codex 間で異なる部分）

| 箇所 | Claude 版（`.claude/skills/`） | Codex 版（`.agents/skills/`） | 理由 |
|---|---|---|---|
| frontmatter `allowed-tools` | あり（`Bash, Read, Edit` 等） | なし | Codex SKILL.md 仕様は frontmatter に `name` / `description` のみ |
| 補助ツール節の `swift-lsp` 言及 | あり | なし | swift-lsp は Claude Code 公式マーケットのプラグインで Codex には存在しない |
| 補助ツール節の `Context7` / `XcodeBuildMCP` 表記 | プラグイン名に揃え（PascalCase） | MCP サーバー名に揃え（小文字 `context7` / `xcodebuild MCP`） | 各ツール側の表記慣習に合わせる |
| `references/` 配下 | 同一内容 | 同一内容 | 例外なし。`diff -q` で常に一致すべき |

同期時はこの表の左右を**フィールド単位で個別に維持**する。「単純な丸ごとコピー」で
上書きすると Claude 固有の `allowed-tools` 等が消えてプラグイン挙動が壊れるので注意。

### 8.2 skills 同期ルール

`.claude/skills/` と `.agents/skills/` は、プロジェクト固有の仕様・禁止事項・
確認手順が**意味的に一致**した状態を保つ。ただし §8.1 の意図的非対称
（`allowed-tools` frontmatter、`swift-lsp` 言及、`Context7` / `xcodebuild` の表記差）は
維持する。

- 同期時に片方をもう片方へ**丸ごとコピーして上書きしない**。
- `SKILL.md` 本文は「完全一致」ではなく**内容同等**を目標とする。
- `references/` 配下は原則として**完全一致**を確認する。

同期後は次で差分を確認する。

```sh
diff -qr .claude/skills .agents/skills || true
```

`SKILL.md` が差分として出るのは frontmatter 等の意図的非対称によるもので想定内。
差分が出た場合は、それが §8.1 の意図的非対称なのか単なる更新漏れなのかを判断し、
更新漏れなら同じ PR で修正する。

### 8.3 ドキュメント・スキル鮮度チェック

`README*.md` / `ROADMAP.md` / `AGENTS.md` / `docs/`（`docs/archive/` を除く）を更新した
場合は、`.claude/skills/**/SKILL.md` と `.agents/skills/**/SKILL.md` も stale 化していな
いか確認する。特にテスト件数・ビルド手順・Xcode / iOS バージョン・MCP / plugin 設定は
skill 側に古い値が残りやすいため、PR 前に grep すること。

```sh
rg '85|103|121|XCTest|Swift Testing|Xcode 26|iOS 26|verify\.sh|lint\.sh|xcodebuildmcp|Context7' \
  -g '!docs/archive/**' README*.md AGENTS.md ROADMAP.md docs .claude .agents
```

古いテスト件数（現状は Swift Testing 140 件 / 20 スイート / 23 ファイル）、古いビルド
手順、古い Xcode / iOS バージョン、古い MCP / plugin 設定が見つかった場合は、該当
文書を同じ PR で更新する（`0.85` などのしきい値は対象外）。

## 9. MCP サーバー（`.codex/config.toml` / `.mcp.json`）

| name | 用途 | 起動方式 |
|---|---|---|
| `context7` | AlarmKit / WidgetKit / ActivityKit / SwiftData / HealthKit の Apple ドキュメント参照 | HTTP (`https://mcp.context7.com/mcp`) |
| `xcodebuild` | Xcode ビルド・iOS 26 シミュレータ制御を構造化 JSON で扱う | stdio (`npx -y xcodebuildmcp@latest mcp`、Node 18+ 必須。`mcp` サブコマンドが無いと CLI モードで起動して MCP サーバーが立たない) |

macOS + Xcode 26 前提。Linux / Windows では `xcodebuild` MCP が起動失敗するが
想定動作（`context7` は全 OS で動く）。シークレットは設定ファイルに直書きせず、
必要なら `${ENV_VAR}` 経由で渡す。

> **Linear（管制塔）はこのリポジトリ同梱の MCP 設定には含めない**。repo bootstrap で
> 提供されるのは上表の `context7` / `xcodebuild` のみ。Linear へのアクセスは実行環境 /
> アカウント側のコネクタ（Claude Code / Codex の Linear 連携）または Linear Web UI で
> 行う想定で、特定の MCP ツール名（`save_issue` 等）に依存しない。§6.1.1 の起票は
> その時点で利用可能な Linear アクセス手段を使う。

## 10. 二重管理ルール（Claude Code 用と Codex 用）

`.claude/` と `.codex/` / `.agents/` は独立に維持する方針。両方を有意に保つために
以下を守ること：

1. スキル本文（`xcodegen-regen` / `alarmkit-scheduling` / `swiftdata-migration` の
   `SKILL.md` および `references/`）を変更したら、`.claude/skills/` と
   `.agents/skills/` の **両方** を同時に更新する。同期の具体的手順・意図的非対称の
   扱い・`diff -qr` 確認は **§8.2 が正**（重複定義を避けるためここでは再掲しない）。
2. MCP サーバー定義を増減した場合、`.mcp.json` と `.codex/config.toml` の両方を
   更新する（用途と起動方式が一致するように）。
3. ビルド / swift-format / Widget の運用ルールはこの `AGENTS.md`（§4 / §5 / §6）が
   唯一の正。`CLAUDE.md` はポインタのみで重複させない。
4. Claude Code / Codex の bootstrap ドキュメントは setup 完了済みのため
   `docs/archive/`（`claude-code-bootstrap.md` / `codex-bootstrap.md`）へアーカイブ済み。
   歴史的記録であり、運用ルールの正は本 `AGENTS.md`、スキル本文の正は各 `SKILL.md`。
   アーカイブは凍結扱いで鮮度チェック（§8.3）の対象外。
