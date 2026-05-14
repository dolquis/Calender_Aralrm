# Calender_Aralrm — シフトアラーム

シフト勤務（昼勤・夜勤、3直2交代、4勤2休 など）向けの目覚ましカレンダーアプリです。
**AlarmKit** (iOS 26+) を用いるため、純正「時計」アプリと同等の信頼性
（サイレント/集中モード貫通、ロック画面提示、Live Activity 表示）で動作します。

iOS 26.0+ をデプロイメントターゲットに、Swift 6 / SwiftUI / SwiftData で実装しています。
Widget Extension によりホーム画面ウィジェットと Dynamic Island にも対応しています。

## 機能

- **月カレンダー** — 日付ごとにプリセットを割当て、時刻上書きやスキップも可能。
- **シフトプリセット** — 名前、色、既定アラーム時刻、サウンドを設定。
- **ローテーションパターン** — 4勤2休、3直2交代 などの周期パターンをアンカー日基準で展開。
  優先度・適用範囲・有効/無効を制御。
- **祝日・有休オーバーライド** — 祝日や有休はアラームをスキップ、または別プリセットに切替。
  日本の祝日テーブルを同梱。
- **共有 / インポート** — プリセット・パターン・割当・祝日設定を `.shiftalarm` (JSON) で
  エクスポート/インポート。URLスキーム `shiftalarm://import?payload=...` にも対応。
- **ウィジェット** — ホーム画面とロック画面で次のアラームを表示。
  マルチエントリ・タイムラインで次々と来るアラームへ自然に切り替わる。
- **Live Activity** — Dynamic Island に次のアラームまでのカウントダウンを表示
  （発火 N 時間前から自動的に開始、`AppSettings.liveActivityLeadHours` で調整可能）。
- **就寝スケジュール / Bedtime リマインダ** — 起床時刻と `targetSleepDuration` から
  bedtime を逆算し、`bedtimeLeadMinutes` 分前にプレアラームを発火。
- **HealthKit / ショートカット連携** — 睡眠サンプルを HealthKit に書込み、
  `GetSleepWindowIntent` で Siri / ショートカットから次の睡眠ウィンドウを参照可能。
- **オンボーディング** — 初回起動で AlarmKit 認可とサンプルプリセット導入まで
  3 タップ程度で完了する導線を提供。

## ビルド

macOS + Xcode 26.0+ + Homebrew が必要です。

```sh
# 1. XcodeGen のインストール（初回のみ）
bash scripts/bootstrap.sh

# 2. project.yml から ShiftAlarm.xcodeproj を再生成
bash scripts/regen.sh

# 3. 利用可能な iOS 26 シミュレータでビルドとテストを検証
bash scripts/verify.sh

# 4. Xcode で開く
open ShiftAlarm.xcodeproj
```

Xcodeで `ShiftAlarm` スキームを選び、iOS 26 シミュレータ（または AlarmKit エンタイトルメントを
持つ Apple Developer アカウントの実機）を選択して `⌘R` でビルド・実行します。

`scripts/verify.sh` は Xcode project を再生成し、利用可能な iOS 26 の iPhone シミュレータを
自動選択してビルドとテストを実行します。特定の destination を使う場合は次のように指定できます。

```sh
DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' bash scripts/verify.sh
```

## 手動テスト（golden path）

1. 設定タブ → 「許可をリクエスト」で AlarmKit を許可。
2. プリセットタブ → 「夜勤 20:00」「昼勤 06:30」を作成。
3. カレンダー → 翌日をタップ → 「夜勤」を割当。
4. シミュレータの時計を進め、AlarmKit のアラート画面が出ることを確認。
5. ローテーション → 「4勤2休」をアンカー = 今日 で作成し、カレンダーに展開されることを確認。
6. 設定 → 祝日/有休 → 「日本の祝日をまとめて読み込む」→ 祝日セルからアラームが消えることを確認。
7. 設定 → エクスポート で `.shiftalarm` を保存。別シミュレータで設定 → インポート → 差分プレビュー
   を確認し、適用。
8. ホーム画面長押し → 「次のアラーム」ウィジェットを追加して表示確認。

## ユニットテスト

```sh
bash scripts/verify.sh test
```

ローテーション展開、優先順位解決、共有バンドルの相互変換をカバーしています。

## アーキテクチャ概要

- `AlarmScheduler`（`Sources/Services/AlarmKit/AlarmScheduler.swift`）が中核。
  `DayResolver` で算出した「あるべきアラーム集合」と AlarmKit の登録状況を突き合わせ、
  差分のみ schedule / cancel します。
- `DayResolver` の優先順位: **手動割当 > 祝日 > ローテーション > なし**。
- `BGAppRefreshTask` がバックグラウンドで先読み窓（既定 30 日）を更新し続けます。
- Widget は App Group (`group.com.example.shiftalarm`) 経由で SwiftData ストアを共有。
- AlarmKit は `#if canImport(AlarmKit)` で囲ってあり、未対応ツールチェインでもコードがパースできます。

## 将来拡張（実装余地として設計）

- iCloud 同期（`ModelConfiguration(cloudKitDatabase:)` で後付け可能）
- Apple Watch コンパニオン（`Sources/Domain` を共有する）

詳細なフェーズ計画は `ROADMAP.md` を参照。

## ライセンス

MIT
