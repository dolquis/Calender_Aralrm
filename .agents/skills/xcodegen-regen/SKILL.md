---
name: xcodegen-regen
description: project.yml を編集したとき、ShiftAlarm.xcodeproj に不整合があるとき、ファイル追加・削除でビルドが通らなくなったときに使用する。XcodeGen 再生成とビルド検証を統一的に行う。
---

# XcodeGen 再生成フロー

## 標準コマンド

初回セットアップ（マシンごとに1回）：
```bash
bash scripts/bootstrap.sh
```

再生成：
```bash
bash scripts/regen.sh
```

ビルド＋テスト検証（既定の iOS 26 シミュレータ）：
```bash
bash scripts/verify.sh
```

シミュレータを明示する場合：
```bash
DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' bash scripts/verify.sh
```

テストのみ：
```bash
bash scripts/verify.sh test
```

## いつこのスキルを使うか

- `project.yml` を編集した直後
- 新しい `.swift` ファイルを `Sources/`, `App/`, `Widget/`, `Tests/` に追加した直後
- `ShiftAlarm.xcodeproj` の中身を直接編集しようとしている自分／他人を見たとき
- `xcodebuild` が「ファイルがプロジェクトに含まれていない」系のエラーを出したとき

## 守るべきこと

- `ShiftAlarm.xcodeproj` を **直接編集しない**。`project.yml` を編集して `regen.sh`。
- `project.yml` を編集したら必ず `verify.sh` を回す（ビルド成功と通常実行のテストパスを確認）。
- Snapshot テストは既定でスキップ。動かしたい場合は `SNAPSHOT_TESTING_ENABLED=1`。
- XcodeBuildMCP を入れている場合でも、CI と乖離しないよう `scripts/verify.sh` を一次手段とする。

## やってはいけない

- `ShiftAlarm.xcodeproj/project.pbxproj` を手書きで編集する。
- `Config/LocalSigning.xcconfig` を作成・編集・コミットする（ローカル専用、`.gitignore` 対象）。
- 既定のバンドル ID（`com.example.*`）のまま実機ビルドする（`p0-readiness.sh` が落ちる）。
