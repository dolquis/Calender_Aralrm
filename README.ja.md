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

現在は 85 件の XCTest（16 テストクラス）で、Domain / Services / App Intents /
HealthKit 補助ロジック / Background refresh / Deep link / Sharing / Snapshot を
カバーしています。DayCell の snapshot test 5 件は通常 `verify.sh` では skip され、
`SNAPSHOT_TESTING_ENABLED=1` 指定時に記録 / 検証されます。

## コードスタイル

Swift ソースは Xcode 26 ツールチェーン同梱の
[`swift-format`](https://github.com/swiftlang/swift-format) で整形します。設定は
リポジトリ直下の `.swift-format` です。CI の `lint` ジョブは違反があると失敗します。

```sh
bash scripts/lint.sh check   # 検査。違反があれば非ゼロ終了
bash scripts/lint.sh fix     # その場で整形
```

## アーキテクチャ概要

- `AlarmScheduler`（`Sources/Services/AlarmKit/AlarmScheduler.swift`）が中核。
  `DayResolver` で算出した「あるべきアラーム集合」と AlarmKit の登録状況を突き合わせ、
  差分のみ schedule / cancel します。
- `DayResolver` の優先順位: **手動割当 > 祝日 > ローテーション > なし**。
- `BGAppRefreshTask` がバックグラウンドで先読み窓（既定 30 日）を更新し続けます。
- Widget は設定済み App Group（既定: `group.com.example.shiftalarm`）経由で SwiftData ストアを共有。
- AlarmKit は `#if canImport(AlarmKit)` で囲ってあり、未対応ツールチェインでもコードがパースできます。
  AlarmKit / ActivityKit API は Xcode 26.5 で確認済みで、`AlarmConfigurationBuilder` は
  現行の `AlarmManager.AlarmConfiguration.alarm(...)` factory を使い、iOS 26.1 以降では
  deprecated な `AlarmPresentation.Alert.stopButton` を避けます。

## Bundle ID / App Group の実機向け変更

シミュレータビルドは `Config/SigningDefaults.xcconfig` の既定値で動きます。実機で
AlarmKit を検証する場合は、`Config/LocalSigning.xcconfig.example` を
`Config/LocalSigning.xcconfig` にコピーし、Apple Developer Team ID、登録済み bundle id、
App Group を実値へ置き換えてください。

```sh
bash scripts/regen.sh
bash scripts/p0-readiness.sh
bash scripts/p0-device-build.sh
```

`Config/LocalSigning.xcconfig` は git ignore 済みです。既定の `com.example.*` のままでは
readiness script が意図的に失敗します。device build script は同じ readiness check を通してから
`generic/platform=iOS` 向けにビルドします。

## ロードマップ

最近実装済み:

- **シフトパターン自動検出** — 既存の割当履歴から周期性を検出し、「これローテとして
  登録しませんか？」と提案する。単純な昼夜交互週から多週の複雑パターンまでカバー。
- **家族向けカレンダー（`.ics`）エクスポート** — 割当を標準の `.ics` ファイルとして
  書き出し、家族が自分のカレンダーアプリから購読できる。

設計済み（未実装）:

- **長期連休を挟んだ昼夜シフト切替** — お盆 / ゴールデンウィークなどを 1 つの "連休" として
  マークし、連休前後で昼夜を入れ替えるポリシー（invert / continue / reset-to-day）を
  ローテに適用する。
- **シフト表画像の AI 取込** — 紙やポータル画面のシフト表を写真でアップロードすると、
  端末内 OCR (`Vision`) と iOS 26 の `FoundationModels` がグリッドを解析し、既存の
  JSON インポートと同じ差分プレビューで適用できる。クラウド送信なし。

iCloud 同期と Apple Watch コンパニオンは検討の結果 **スコープ外**。詳細なフェーズ計画は
`ROADMAP.md` を参照。

## ライセンス

MIT
