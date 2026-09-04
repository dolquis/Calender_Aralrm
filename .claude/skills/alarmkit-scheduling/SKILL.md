---
name: alarmkit-scheduling
description: AlarmScheduler、DayResolver、AlarmKit 経由のアラーム登録／キャンセル／diff-sync、ローテーションパターン展開、休暇オーバーライドを編集・デバッグするときに使用する。
allowed-tools: Read, Edit, Grep, Glob, WebFetch
---

# AlarmKit スケジューリング

## このスキルが扱う範囲

- `Sources/Services/AlarmKit/AlarmScheduler.swift` — AlarmKit との diff-sync の中核
- `Sources/Domain/Logic/DayResolver.swift` / `DayResolverInputBuilder.swift` / `RotationExpander.swift` — 日付→プリセット解決
- `BGAppRefreshTask` での lookahead（既定 30 日）
- AlarmKit のオーソリ取得（Onboarding 経由）

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
   フル再登録に書き換えない（バッテリ・性能影響が大きい）。
4. AlarmKit のオーソリは Onboarding で取得。コードパスのどこかで再要求が必要な場合は
   ユーザー操作を経由させ、サイレントに失敗しない。

## 補助ツール（マーケット品を活用）

- API 仕様確認：Context7 MCP 経由で <https://developer.apple.com/documentation/alarmkit> を fetch
- コード補完・型エラー：エディタの Swift LSP（Claude Code では `swift-lsp` プラグイン）
- テスト実行：`bash scripts/verify.sh test`（XcodeBuild MCP を入れていればそちらでもよい）

## 変更後に必ず確認すること

- `bash scripts/verify.sh test` で AlarmScheduler 系のユニットテストがパスする。
- precedence や境界条件を変える場合は、必ず新しいテストケースを追加する。

## やってはいけない

- AlarmKit に直接アクセスするコードを `Sources/Features/`（SwiftUI 層）に書く。
  必ず `Sources/Services/AlarmKit/` のスケジューラ越し。
- precedence ルールを断りなく変える。
- BGAppRefresh のスケジュール頻度を上げる（OS から絞られて逆効果になりやすい）。

## 参照
- `references/day-resolver.md` — precedence の具体例と落とし穴
