<!--
  SHARED CORE — Agent / Linear 運用規約（管制塔モデル）
  この「共有コア」は全リポジトリで同一内容をミラーする。
  個別 repo で直接編集しない。編集は origin（後述）で行い、各 repo へ伝播する。
  version: 0.7-draft   updated: 2026-09-01
  status: 規約確定・origin = dolquis/agent-ops に確定。repo 新設/配置・ラベル移行(Phase 4)は未実施。§2.1 Codex Execution Policy を追加(2026-06-07)。§7.1 Design / Gate Split と PR マージ→In Review 設定を追加(2026-06-19)。§11 に Design / Implementation spec-first checks・tracking の Codex 実行候補混入検出・設計未完のまま impl 実行許可の検出を追加(2026-07-05)。同 spec-first checks を移行期の旧カテゴリラベル(Feature / enhancement)と In Progress の課題にも適用(2026-07-05)。§3/§7.1.3/§10/§11 に In Review の意味分割(Merged 状態の新設・PR マージ遷移先の変更・人間ゲートの Todo 待機・tracking の In Progress 維持・検証メモのフロー化)を追加(2026-08-31・DEV-923)。§7.2 記録の鮮度(導出可能な現在を description に書かない・状態依存の例外を Next AI Tasks に限定・遷移時記録原則)を新設し、§5/§7/§7.1.3/§11/§12 をこれに合わせて改訂(2026-09-01・DEV-927)。
  origin(編集の起点・単一正典): dolquis/agent-ops/linear-conventions.md（このファイル）
  各 repo の docs/linear-conventions.md は本ファイルのベンダリングコピー + §13 Delta。
  プロジェクト固有の差分は各 repo の「Project Delta」節（本ファイル末尾）に置く。
-->

# Linear 管制塔モデル 運用規約（Shared Core）

Dev チーム配下の全プロジェクトで共通の、Linear 運用ルール。
**詳細仕様・ロードマップ・本規約の正典は GitHub repo docs。Linear ドキュメントはそのミラー。**

このファイルは、全 repo で同一内容をミラーする「共有コア」（§1–§12）と、各 repo だけが書き換える「Project Delta」（§13）で構成される。共有コアは origin で 1 回編集し、各 repo へ同一内容を伝播する（個別 repo で直接編集しない）。

---

## 1. 役割分担（control tower）

- **Linear = 管制塔**: 状態・優先度・進捗・親子関係・依存・担当エージェント・「次に AI へ渡す Issue」のルーティング。
- **GitHub = 正典(source of truth)**: 実装規約・ビルド/テスト手順・詳細仕様・ロードマップ、そして本運用規約。
- **Repository docs**: `AGENTS.md` / `README.md` / `docs/*` / `ROADMAP`（または `WORKFLOW.md`）。

原則: Linear に仕様を複製しない。詳細は GitHub 正典を参照する。

---

## 2. エージェント分業

| ラベル | 役割 |
| -- | -- |
| `agent:claude-design` | 仕様整理・設計・タスク分割・レビュー観点作成 |
| `agent:claude-review` | 実装後レビュー・整合性確認・リスク洗い出し |
| `agent:codex-impl` | 実装担当 |
| `agent:codex-pr-review` | PR 差分レビュー担当 |

Issue には「次の AI 役割」を示す `agent:*` を 1 つ付ける。ただし `gate:human-required` または旧 `type:human-gate` の人間専任タスクは `agent:*` を省略してよい。

---

## 2.1 Codex Execution Policy（Codex 実行ポリシー）

対象: Codex Cloud（"Codex for Linear"）。Linear で Issue を Codex に assign / delegate する、コメントで mention トークン（`@`+`Codex`）を付ける、または triage rule で自動 delegate すると起動する。ローカルの Codex App は Codex チャット（Linear 管轄外）から起動し、Linear のラベルでは起動しない。

- `agent:codex-impl` / `agent:codex-pr-review` は **ルーティング（候補）ラベル**であり、Codex Cloud の実行を許可しない（滑走路前の待機列）。
- Claude は Codex 候補 Issue の作成・分割・ラベル付け・関連付け・整理と、実行指示文の下書きまで行ってよい。ただし Codex への assign / delegate / mention は **行わない**。
- Codex Cloud の実行には人間 lead の明示許可（Issue コメント）が必要。Claude / エージェントはいかなる Linear コメント / Issue 本文 / テンプレートにもリテラルな mention トークン（`@`+`Codex`）を再生産しない（無害化する）。承認後に実際の mention で起動するのは人間 lead のみ。
- triage rule による Codex 自動 delegate は使わない。
- 実行したら Codex Run Record（§6）に approval / Codex task link / branch / commit / PR / validation / remaining risk を記録する。
- 無許可で Codex Cloud が動いた場合はインシデントとして扱う: delegate を解除して Issue を候補へ戻し、GitHub に branch / PR が到達していないか確認し、Issue に記録する。

### 実行許可フォーマット（人間 → Issue コメント）

- Issue / Repo / Scope（Acceptance Criteria のみ）
- Allowed output: summary only | branch only | draft PR | PR（repo の PR 規約に従う。Draft PR 必須の repo では draft PR までとする）
- Human gate: none | required before Done
- Prohibited: 無関係な refactor / スコープ変更 / main への直接 push / human-gate 判断の変更

このコメントがある場合に限り、人間が Codex への delegate / mention を行う。

---

## 3. ワークフロー状態

標準フロー（Linear のステータス名が完全一致しなくても、この順序で解釈する）:

1. **Backlog / Todo** — 未整理または未着手
2. **Design** — Claude Code で仕様整理・実装方針作成
3. **Implement** — Codex で実装
4. **Review** — Claude Code または Codex で差分レビュー（Linear の In Review。open な PR がある）
5. **Merged** — PR マージ済み・検証メモ待ち（Done 判定前の滞留を可視化する）
6. **Done** — repo 固有の完了条件を満たし、作業結果・検証・PR・ドキュメント影響確認が記録済み

### 3.1 状態に意味を重ねない

In Review が「PR レビュー待ち」「マージ済み検証メモ待ち」「人間ゲート待ち」を兼ねると、キューの内訳が Linear 単体では分からず、監査のたびに GitHub の open PR 実態と突合することになる（2026-08-31 監査では In Review 18 件のうち open PR を持つ課題は 1 件だった。DEV-923）。次のように使い分ける。

- **In Review** は open な PR（Draft 含む）を持つ課題だけに使う。open PR が無い課題を In Review に置かない。
- **Merged** は PR がマージ済みで、検証メモの記載と Done への明示遷移（§7.1.3）が済んでいない課題に使う。
- **人間ゲート課題**（`gate:human-required` の人間専任 Issue）は PR を持たないため In Review / Merged に置かず、Todo のまま人間の着手を待つ。キューは §10 の Needs Human Verification ビューが担う（started 系の状態に置くと、着手できないまま cycle 集計に乗り続ける）。
- **`type:tracking`** は子 Issue の進行中は In Progress を維持する。子 PR のマージは束ねの完了ではないため、In Review / Merged に置かない。

---

## 4. ラベル分類体系（コロン式に統一）

ラベル prefix はコロン式に統一する。技術領域 `area:` も複数付与するが、Linear 上では label group 化せずフラットなラベルとして運用するため、コロン式でも複数選択できる（Linear のラベルグループ排他制約は明示的なグループにのみ働き、`area:foo` のような prefix 付きフラットラベルには働かない。2026-06-03 決定、後日コロン式へ統一）。Phase 4 完了までは各 repo の Delta / `AGENTS.md` が定める active label を優先する。

| プレフィックス | 用途 | 値 |
| -- | -- | -- |
| `repo:` | 対象 GitHub リポジトリ（実 repo 名をそのまま反映） | 各 1 つ必須（Phase 4 完了までは旧 repo ラベルも有効） |
| `area:` | 技術領域 | 1 つ以上（複数付与可。Linear ではフラットなラベルとして運用。旧 `area_*` は Phase 4 で付け替え） |
| `agent:` | 次の AI 役割（§2） | 原則 1 つ（人間専任タスクを除く） |
| `type:` | Issue の役割 | `tracking` / `implementation` / `review` |
| `gate:` | 人間ゲート（横断フラグ） | `human-required` |
| `kind:` | 変更カテゴリ | `feature` / `improvement` / `bug` / `docs` |
| `Migrated` | 由来フラグ（他サービス起票） | 任意 |

ルール:
- `area:` は複数選択可能にするため Linear label group にせずフラットなラベルとして運用する（例 `area:converter-core`）。`repo:` は実 GitHub repo 名をそのまま使い区切りを正規化しない。
- **`area:docs` は repo 横断の共有 area**（ドキュメント・ガバナンス・規約の整合）。特定 repo の技術領域に属さない文書系 Issue に付与する。repo 固有の技術領域 area（例: azooKey `area:settings`（設定アプリ / schema）/ `area:build`（CMake・CTest・CI・コード署名・MSIX パッケージング））は各 repo の Delta / `AGENTS.md` で定義する。
- **人間ゲートは `type:` ではなく `gate:human-required`（横断フラグ）で表す。** 例: 人間確認が必要なレビュー Issue は `type:review` + `gate:human-required`。旧 `type:human-gate` は本規約で廃止。移行期は旧ラベルが残る Issue があるため Phase 4 で `gate:human-required` へ付け替える（読むときは両対応）。
- **変更カテゴリは `kind:*` を正典とする**（`feature` / `improvement` / `bug` / `docs`）。旧 `Feature` / `Improvement` / `Bug` / `enhancement` / `documentation` は Phase 4 まで移行互換として扱い、Phase 4 で物理退役（ラベル削除は設定画面で手動）する。`Migrated` は由来フラグとして存続。
- **Phase 4 完了までの移行互換**: 旧 `repo_*` / 旧 `area_*` / 旧カテゴリラベルのみが付いた Issue も、Ready / Missing Metadata / 週次監査では欠落扱いしない。新規作成・更新時は repo の Delta または既存 `AGENTS.md` の現行ラベルを優先し、Phase 4 後に `repo:` / `area:` / `kind:*` へ収束する。

---

## 5. Agent Task Format（Issue 記述）

Fields: Background / Goal / Repository / Area label / Files / Expected behavior / Plan / Done criteria / Owner / Handoff notes

Claude が Issue を作成・更新・分割するときは、本文冒頭に **Agent Handoff** ブロックを置く:

```md
## Agent Handoff

- Type:
- Agent:
- Repo:
- Goal:
- First files to inspect:
- Protected areas:
- Required validation:
- Expected PR size:
- Blocks:
- Blocked by:
- Codex safety: `agent:codex-*` はルーティングのみ。Claude は Codex へ delegate / assign / mention しない（実行は人間 lead のみ。mention トークンは候補段階で書かない）。
```

Issue タイプ（`type:`）:
- `tracking` — 進捗管理・子 Issue 集約・順序整理。直接実装しない。
- `implementation` — 1 PR で完了可能な実装・修正・テスト追加。
- `review` — 設計レビュー・PR レビュー・整合性確認。

Tracking Issue または Project description 上部には、`## Next AI Tasks` 見出しで最大 3 件を書く（Project description ではこの見出しを含む §12 の 5 H2 形式に従う）。Next AI Tasks は description に書いてよい唯一の状態依存記述であり、遷移時の更新義務が伴う（§7.2）。

---

## 6. Agent Run Report Format（作業後コメント）

作業後に Linear Issue へ残すログ形式（仕様ではなく作業ログ）:

- **Agent**: Claude Code / Codex / ChatGPT / other
- **Read**: 確認した正典（AGENTS / roadmap / README / 連携 GitHub Issue / 関連 docs）
- **Changed**: 変更ファイル、または Linear のみの変更
- **Validation**: test / lint / build / 手動確認、スキップ時は理由
- **Findings**: リスク・ブロッカー・follow-up
- **Next**: 次アクションと次オーナー

Codex Cloud を実行した場合は、追加で **Codex Run Record** を残す:

- Execution approved by / approval comment
- Codex task link / branch / commit / PR
- Validation / known limitations
- Human gate required / next reviewer

短く保ち、仕様はコピーせず GitHub へリンクする。

---

## 7. Definition of Ready / Done

### Ready
- Project が正しく設定されている。
- `repo:*` ラベルがある（Phase 4 完了までは repo 固有の旧 repo ラベルも有効）。
- 関連する `area:*` が 1 つ以上ある（Phase 4 完了までは repo 固有の旧 `area_*` ラベルも有効）。
- 次の AI 役割を示す `agent:*` がある。ただし `gate:human-required` または旧 `type:human-gate` の人間専任タスクは `agent:*` を省略してよい。
- 可能なら GitHub Issue / PR リンクが添付されている。
- Goal と done criteria が明確。
- 実行順序が重要な場合、ブロッカーが relation で表現されている。

### Done
- 作業結果が記録されている。
- 検証結果が記録されている（スキップ時は理由）。
- 親 tracking Issue と所属 Project の `## Next AI Tasks` から本 Issue を外し、次に渡す Issue へ差し替えてある（§7.2 遷移時記録原則）。
- GitHub 正典に対するドキュメント影響を確認済み。
- 可能なら関連 PR / GitHub Issue がリンクされている。
- 必要な follow-up Issue が作成/リンクされている。
- `gate:human-required` または旧 `type:human-gate` の Issue は人間確認が取れている。
- repo 固有 Delta / `AGENTS.md` / `WORKFLOW.md` が追加ゲート（PR マージ、検証メモなど）を要求する場合、それを満たしている。

Done は「Linear 上で運用的に完了」を意味し、GitHub docs のリリース基準を置き換えない。

---

## 7.1 Design / Gate Split（設計層と人間ゲートの分離）

`agent:claude-design` / `agent:claude-review` の AI 設計作業と `gate:human-required` の人間判断が両方絡む Issue は、原則として **設計 Issue** と **人間ゲート Issue** の 2 件に分離する。1 件に同居させると、設計 PR のマージで Issue 全体が誤って Done 化し、未達の人間ゲートを飛び越える（管制塔の状態が実態と乖離する）。

### 7.1.1 分離テスト（分割するか否か）

人間が必要とする作業が、**AI セッションでは生み出せず、かつ同一レビュー内で人間が即座に記録もできない**もの（実機・実データ計測 / 購入・契約 / 外部アカウント開設 / 法務・ライセンス確定 / 署名値設定 / 本番デプロイ 等）を含むなら **分割必須**。

人間の入力が「AI が用意した決定ブリーフの『決定』欄を埋める」程度で、**同一サイクル内に完了**するなら、分割せず単一 Issue のままその場でゲートをクリアしてよい（決定内容・合意日を検証メモに記録）。

### 7.1.2 分割後の規格

| 項目 | 設計 Issue | 人間ゲート Issue |
| -- | -- | -- |
| タイトル | 元のまま | `Human Gate: <決定内容>` で開始（roadmap コード併記可: 例 `D-04-A`） |
| `agent:*` | `agent:claude-design` / `claude-review` | 付けない（人間専任。§2 / §7 Ready で免除） |
| `gate:human-required` | **付けない** | 付ける |
| `type:` | `review` 等 | `review` |
| `repo:` / `area:` / `kind:` | 通常どおり | 通常どおり |
| 関連付け | — | 設計 Issue へ `related`、所属 tracking / epic を parent、リリース律速なら下流へ `blocks` |
| Done 条件 | 調査 / spec / 雛形 / ハーネスが PR マージ + 検証メモで確定 | 人間判断・実機検証 + 決定 / 計測値の記録（検証メモ） |

設計 Issue は純 AI スコープになるため、Done 化時に `gate:human-required` を残さない（クリア済みなら除去、未クリアなら Done にしない）。

### 7.1.3 自動 Done の防止（設定・運用）

事故の根本原因は、Linear–GitHub 連携が PR マージ / ブランチ名連動で Issue を Done 化し、人間ゲートを飛び越える点にある。次の多層で防ぐ:

1. **連携設定（採用）**: チームの GitHub 連携で「PR マージ時の遷移先」を **Done ではなく Merged** にする（Merged 状態が未整備の間は In Review で代用し、週次監査で再分類する）。最終 Done は必ず人間 / Claude の明示操作とする。これにより設計 PR のマージは Merged で止まり、人間ゲートの取りこぼしが構造的に起きない。マージ済みの課題がレビュー待ちの課題と混ざらないため、In Review は「open PR あり」を保ち続ける（§3.1。この設定変更は人間 lead が Linear 側で行う）。
2. **closing キーワードの使い分け**: 設計 PR は設計 Issue のみを `Fixes DEV-<design>` で閉じる。人間ゲート Issue は closing キーワードで参照せず `Ref DEV-<gate>` / `Part of DEV-<gate>` のみとし、PR リンクは attachment で手動付与する。 GitHub ミラー Issue も同様に、人間ゲート / 検証メモ待ちの Issue では `Fixes #<N>`（マージで GitHub Issue をクローズ → Linear 同期で Done 化し Merged を迂回する）を避け、`Refs #<N>` 等の非クローズ参照にする。
3. **分割の徹底**: §7.1.1 に該当する Issue は分割し、auto-close が人間ゲート Issue に当たらないようにする。
4. **検証メモのフロー化**（§7.2 遷移時記録原則の適用例）: PR のマージを検知したセッション（マージを実行した人間から引き継いだエージェント・PR 監視エージェント・直後に該当 repo で作業するセッション）は、その場で検証メモ（確認したテスト名・CI ジョブ名を含む）を Issue にコメントし、`gate:human-required` が無ければ Done へ明示遷移する。遷移時にやることは §7 Done チェックリストに集約してある。検証メモを週次監査でまとめて書く運用は Merged の滞留を生む（DEV-662 で 18 件、DEV-925 で 11 件が一括処理になった）ため、監査での記入は取りこぼしの回収に限る。

本節の遷移規約（PR マージ→Merged、Done は明示遷移）は、各 repo の `AGENTS.md` / `docs/GITHUB_LINEAR_MAPPING.md` / `docs/WORKFLOW.md` 等のライフサイクル要約より**優先**する。要約側が「PR マージ→Done」と記す場合は本節に読み替え、可能なら要約側も更新する。

---

## 7.2 記録の鮮度

tracking Issue の進捗欄と Project description は、子 Issue の状態を人手で写した**手書きキャッシュ**である。無効化の仕組みがないため、元データが動くたびに黙って実態とずれる（DEV-775: 進捗欄が 27 日放置され、description は全面更新の 2 時間後に子 3 件の Done 遷移で再び陳腐化し、検出から修正まで 15 日かかった）。全面更新の 2 時間後に腐る以上、更新頻度を上げても解決しない。書ける内容を絞り、腐る面そのものを減らす。

**原則**: Linear の状態から**導出できる記述を description に書かない**。現在は生データ（sub-issue リスト・blocked-by リレーション・mention チップ）に語らせる。導出できない意図・構造・過去の事実は書いてよい。

| 区分 | 例 | 判定 |
| -- | -- | -- |
| 構造と意図 | 分解の意図、spec アンカー、正典の所在、依存の理由 | 書いてよい（腐らない） |
| 日付つき完了記録 | 「Done（PR #89、2026-08-31）」 | 書いてよい（過去の事実） |
| Next AI Tasks | 次に AI へ渡す Issue の並び（最大 3 件） | 書いてよい。**唯一の状態依存例外**で、下記の更新義務が伴う |
| 導出可能な現在 | 状態名（`In Review` / `Merged` 等）、「着手可」「〜待ち」「残 N 件」 | 書かない |
| 状態スナップショット | 「進捗（YYYY-MM-DD 時点）」節 | description に置かず、`Status snapshot YYYY-MM-DD` 見出しのコメントへ積む |

「導出可能な現在」は上の語彙の列挙ではなく、**Linear を引けば分かる記述すべて**を指す（列挙は例示）。コメントは日付を持つ過去ログとして読まれるため腐らない。description が腐るのは「現在」を名乗るからである。

**遷移時記録原則**: 記録を更新するのは「気づいた人」ではなく**状態を変えた者**とし、同じセッション内で行う。

- Done / Canceled へ遷移させたときは、親 tracking と Project の Next AI Tasks を更新する（**義務**。§7 Done チェックリスト）。Done の Issue が残ると次のエージェントを誤ルーティングするため。
- 新規起票で上位 3 件の並びが変わると判断したときも更新する（ベストエフォート。載せ漏れは候補が 1 つ見えないだけで害が小さい）。
- 義務は完璧である必要はない。取りこぼしは週次監査（§11）が拾う二層構成とする。

**到達性**: 現在を description から外すぶん、状態は Linear を引いて得る。作業開始時に対象 Issue の子・blocked-by と §10 のキューを取得してから動く。

---

## 8. Navigation Rules

- Linear リンクはナビゲーションと計画にのみ使う。
- Tracking item は小さな作業項目を束ねる。
- Order/blocking マーカーは実際の順序にのみ使う。
- Reference マーカーは緩い関連に使う。
- Same/duplicate マーカーは真に同一の作業にのみ使う。

GitHub docs remain canonical.

---

## 9. Do Not Do

- GitHub roadmap の詳細を Linear docs にコピーしない。
- Linear docs を仕様(spec)として扱わない。
- 人間ゲート Issue を手動確認なしでクローズしない。
- 実機・署名など人間判断が必要な作業を AI 判断だけで Done にしない。
- Migrated 作業で GitHub Issue リンクを省略しない。
- Linear 作業から README に進捗表/TODO を増やさない。
- Claude から Codex へ assign / delegate / mention しない。実行は人間 lead が明示許可コメント後に自ら行う（Claude は実行指示文の下書きまで）。
- Claude / エージェントはいかなる Linear コメント / Issue にもリテラルな Codex mention トークン（`@` + `Codex`）を再生産しない（無害化する）。承認後に実際の mention で起動するのは人間 lead のみ。
- triage rule で Codex を自動 delegate しない。
- `agent:claude-*`（design / review）と `gate:human-required` を同居させたまま PR で auto-close される構成にしない。分離テスト（§7.1.1）に該当するなら 2 件に分割する。
- Done 化時に `gate:human-required` を残さない（人間判断がクリア済みなら除去、未クリアなら Done にしない）。

---

## 10. Control Tower Views（推奨ビュー）

各プロジェクトで以下のフィルタビューを用意する（Project でスコープ）:

- **Ready for Claude Design**: `agent:claude-design` + Backlog/Todo
- **Ready for Claude Review**: `agent:claude-review` + Todo/In Review
- **Codex Candidate Queue**: `agent:codex-impl` + Todo + delegate なし + 非ブロック（候補。実行はしない）
- **Codex Review Candidate Queue**: `agent:codex-pr-review` + Todo/In Review + delegate なし（候補。実行はしない）
- **Delegated to Codex**: delegate = Codex（暴発・実行中・実行済みの監査用。Candidate と必ず分離する）
- **Needs Human Verification**: `gate:human-required`（+ not Done。旧 `type:human-gate` も読む）
- **In Review**: status In Review（open PR のレビュー・マージ待ち。open PR の無い課題が現れたら §11 で再分類する）
- **Merged / Needs Verification Memo**: status Merged（マージ済み・検証メモ待ち。滞留は検証メモ債務として §11 で点検する）
- **Missing Metadata**: repo / area / agent ラベル欠落、または Migrated Issue の GitHub リンク欠落（移行期の旧 repo/area ラベルと `gate:human-required` / 旧 `type:human-gate` 人間専任タスクの `agent:*` 免除を考慮）

Codex Candidate（`agent:codex-*` 候補）と Delegated to Codex（delegate 済み・実行）は絶対に混ぜない。`delegate = Codex` が見えたら必ずレビュー対象にする。

ビューはレーダー画面であって仕様ではない。曖昧なら GitHub docs と連携 GitHub Issue を見てから動く。

---

## 11. Recurring Control Tower Audit（週次・統一チェックリスト）

各プロジェクトに `[Recurring] Linear control tower audit — <PROJECT>` を 1 件持つ
（`type:review` + `agent:claude-review` + `repo:*`。この recurring audit Issue 自体は `area:*` 免除）。チェック項目:

- [ ] Project 未設定の Issue
- [ ] `repo:` ラベル欠落（Phase 4 完了までは repo 固有の旧 repo ラベルも有効）
- [ ] `area:*` ラベル欠落（Phase 4 完了までは repo 固有の旧 `area_*` ラベルも有効。recurring audit Issue 自体を除く）
- [ ] `agent:` ラベル欠落（`gate:human-required` または旧 `type:human-gate` の人間専任タスクを除く）
- [ ] Migrated なのに GitHub リンク欠落
- [ ] 人間確認が要るのに `gate:human-required` 欠落
- [ ] Tracking Issue で子が未リンク
- [ ] 実行順序を表さなくなったブロッカー
- [ ] Done なのに検証ノート欠落
- [ ] `agent:claude-*` と `gate:human-required` が同居した Issue（Design / Gate 分割漏れ。§7.1）
- [ ] Done の設計 Issue（`agent:claude-*` 付き）に `gate:human-required` が残っている（分割後に除去すべき stale ラベル。人間ゲート Issue 自体が検証メモ付きで Done なのは正常）
- [ ] 人間ゲート Issue が PR の auto-close 対象になっている（closing キーワードで参照されている）
- [ ] `type:tracking` Issue が Codex 実行候補（`agent:codex-*` + Todo・delegate なし・非ブロック）として Candidate Queue（§10）に現れている（tracking は束ね専用で直接実装しない。§5 / §8。実行は子 implementation Issue へ降ろす）

Codex safety checks:

- [ ] 人間 lead の明示許可なく Codex へ delegate された Issue がない
- [ ] 明示許可なく Codex mention トークン（`@`+`Codex`）を含むコメント / Issue 本文 / テンプレートがない
- [ ] `agent:codex-*` をルーティング（候補）ラベルとしてのみ扱っている
- [ ] Codex 実行開始後に Todo へ放置された delegate 済み Issue がない
- [ ] Codex 完了タスクに task / PR / commit リンク・検証・残リスクが記録されている
- [ ] 人間ゲート Issue が人間確認なしで Done になっていない
- [ ] ブロック中の Codex 候補が Ready として表示されていない
- [ ] 依存する設計 Issue（`agent:claude-design` / `agent:claude-review`）が未完了（not Done）のまま、その下流 implementation Issue に Codex 実行許可（§2.1 の許可コメント / delegate）が出ていない（設計固定前の実装着手＝仕様の雰囲気決定を防ぐ。§2.1 / §3 / §7.1）

機械判定項目（状態と記録の整合。スクリプト化対象）:

監査セッションはまずこの群を一括で判定し、人力は判断が要る他の項目に充てる。**スクリプト（`scripts/`）を実装したら本群は §11 から降ろし、スクリプトを正典とする**（インシデントごとに項目を足し続けると、規約自身が無効化機構のない手書きキャッシュになるため。DEV-928）。判定の起点は Merged 状態の整備完了後とする（DEV-924）。

- [ ] In Review なのに open PR が無い Issue（マージ済みなら Merged、未着手なら Todo へ再分類。§3.1）
- [ ] Merged のまま 2 週間以上滞留している Issue（検証メモ債務。§7.1.3-4 のフロー化が機能していない兆候）
- [ ] `gate:human-required` の人間専任 Issue が In Review / Merged に置かれている（Todo で待機させる。§3.1）
- [ ] `type:tracking` Issue が In Review / Merged に置かれている（子完了まで In Progress を維持する。§3.1）
- [ ] Next AI Tasks に Done / Canceled の Issue が混入している（tracking Issue・Project description の両方。§7.2 の遷移時記録原則が守られていない兆候）
- [ ] description の記述と mention 先 Issue の実状態が矛盾している（「In Review」と書いてあるが実際は Done、など。ヒューリスティックなので過検出前提で、ヒットは人が判定する）
- [ ] description に残る「進捗（YYYY-MM-DD 時点）」見出しの日付が 14 日を超えている（§7.2 でコメントへ移すまでの移行期に限る。日付つき完了記録は対象外）
- [ ] `Next checkpoint` の期日が過ぎている（§12）

Design / Implementation spec-first checks（設計 §2 / §7.1 の spec-first 分業の担保）:

- [ ] `agent:codex-impl` のフィーチャー（`kind:feature`。Phase 4 完了までは旧 `Feature` / `enhancement` も対象）が、対応する `docs/*-spec.md` 節（または roadmap の該当マイルストーン節）で当該サブ課題の難所（IPC payload / JSON schema・境界値・アルゴリズム・責務境界）を確定する前に In Progress 以降へ入っていないか（未着手の課題だけでなく、既に In Progress の課題も対象）。spec が未確定のまま実装着手していないか。
- [ ] 専用 `agent:claude-design` 課題を持たないフィーチャーでも、tracking / 比較レポート / roadmap 節 / `docs/*-spec.md` のいずれかで難所が上流確定され、実装課題からアンカー参照されているか。
- [ ] 波（wave）分割されたフィーチャーで、先行波の spec だけが書かれ後続波が未確定のまま実装着手していないか（just-in-time spec が波ごとに守られているか）。

Rule: Linear のルーティングのみを点検する。GitHub docs が正典。

---

## 12. Project description テンプレート

各プロジェクト description は次の 5 つの独立した H2 セクションで構成する（順序もこの通り）:

```md
## Current control policy

Lead: <name>
Current focus: <いま何を優先するかの意図を一文で。状態名・残件数・「〜待ち」は書かない（§7.2）>
Codex safety: `agent:codex-*` は候補ラベルのみ。Claude は Codex へ delegate / assign / mention しない（実行は人間 lead のみ）。
Next checkpoint: <YYYY-MM-DD>。<その日に判定する内容>

## Next AI Tasks

1. <DEV-xx> <内容>
2. <DEV-xx> <内容>
3. <DEV-xx> <内容>   （最大3件）

## Human Gate

* <DEV-xx> <判断の内容> は人間確認必須。（状態は書かない。キューは §10 の Needs Human Verification ビュー）

## Canonical docs

正典: <REPO>/docs/linear-conventions.md, <REPO>/docs/<WORKFLOW or ROADMAP>.md

## Stage map

<ステージ名と定義だけを置く。達成状態・残件・進行中の Issue は書かない（正典は repo の roadmap。§1 / §7.2）>
```

見出しは上記 5 つ（`## Current control policy` / `## Next AI Tasks` / `## Human Gate` / `## Canonical docs` / `## Stage map`）に統一する。単一ブロック化したり `Next AI Task` 等へ表記を揺らさない。

description に書ける内容は §7.2 が定める。状態依存の記述は `Next AI Tasks` だけに許し、鮮度は `Next checkpoint` の期日で担保する。

### マイルストーン命名
- 1 プロジェクト内では 1 つのトークン体系に統一する（`Stage N` / `P N` / `MVP-N` のいずれか）。
- 数字を綴り字にしない（`Stage Three` ではなく `Stage 3`）。
- 各マイルストーンは Stage map のステージに対応させる。

---

## 13. Project Delta（各 repo 固有・ここだけ repo ごとに書き換える）

```md
- PROJECT_NAME: <例: azooKey Desktop / Windows IME MVP>
- REPO: <例: dolquis/azooKey-Desktop>
- REPO_LABEL: <例: repo:azooKey-Desktop>
- CANONICAL_DOCS: <例: AGENTS.md, plans/windows-port-roadmap.md, docs/*-spec.md>
- AREA_LABELS: <例: area:tsf-tip, area:inference-host, area:ipc, area:learning, area:converter-core>
- STAGE_MAP: <例: MVP-0 基盤 / MVP-1 TIP / MVP-2 Host・IPC / ...>
```

Delta として各 repo 個別に保持する文書（共有コアには入れない）:
- GitHub ↔ Linear Mapping（対応表データ）
- Decision Log（決定記録）
- Agent Prompt Cards（プロジェクト色のあるプロンプト雛形）

## 13. Project Delta — Shift Alarm

- PROJECT_NAME: Shift Alarm / Calender_Aralrm
- REPO: dolquis/Calender_Aralrm
- REPO_LABEL: repo:Calender_Aralrm
- CANONICAL_DOCS: AGENTS.md, ROADMAP.md, README.md, docs/*
- AREA_TOPICS_CURRENT_FOCUS: current focus examples only, not exhaustive: alarmkit, signing, import-export. Other active areas include SwiftData/domain, Widget/Live Activity, HealthKit/App Intents, localization, and onboarding; use existing repo area labels before Phase 4 and converge on `area:<topic>` labels.
- LABEL_MIGRATION_COMPATIBILITY: Phase 4 までは `AGENTS.md` の `Bug` / `Improvement` / `Feature` も有効。`kind:*` は移行後の収束先。
- STAGE_MAP:
  - P0 実機ビルド・署名・権限確認
  - P1 Alarm reliability diagnostics
  - P2 .shiftalarm input validation
- DELTA_DOCS: GitHub↔Linear Mapping, Decision Log, Agent Prompt Cards
