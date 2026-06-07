# App Group SwiftData ストアの設定とパス

## App Group ID の解決経路

App Group ID は xcconfig 変数 `SHIFTALARM_APP_GROUP_ID` に集約されている。

| 層 | ファイル | 内容 |
|---|---|---|
| 既定値（公開） | `Config/SigningDefaults.xcconfig` | `SHIFTALARM_APP_GROUP_ID = group.com.example.shiftalarm` |
| ローカル上書き（git 管理外） | `Config/LocalSigning.xcconfig`（テンプレ：`...example`）| 実機向け実値。**作成・編集・コミット禁止**（`.gitignore` 対象） |
| Info.plist 注入 | `project.yml` (`infoPlist.ShiftAlarmAppGroupIdentifier = $(SHIFTALARM_APP_GROUP_ID)`) | アプリ本体・Widget 両方で同一キー名 |
| Entitlements | `App/ShiftAlarm.entitlements`, `Widget/ShiftAlarmWidget.entitlements` | 両方とも `com.apple.security.application-groups` 配列に `$(SHIFTALARM_APP_GROUP_ID)` |

ランタイム側は `AppRuntimeConfiguration.appGroupID` 経由で Info.plist の
`ShiftAlarmAppGroupIdentifier` を読み、`SharedPersistence.appGroupID` がそれを露出する。

## SwiftData ストア URL の確定ロジック

実装は `Sources/Domain/Persistence/ModelContainer+Shared.swift`。

```swift
public static func storeURL() -> URL {
    if let groupURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupID)
    {
        return groupURL.appendingPathComponent(storeFileName)   // "ShiftAlarm.store"
    }
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    return docs.appendingPathComponent(storeFileName)
}
```

- App Group が解決できる（=entitlement とプロビジョニングが揃っている）場合、
  `group container/ShiftAlarm.store` を使う。**ここが本体と Widget の共有点。**
- 解決できない場合（テストや開発用ビルドで entitlement 無し）は Documents 配下に
  ローカルストアを置く。テストでは `makeContainer(inMemory: true)` を使うのが既定。

`makeContainer(inMemory:)` は現行の versioned schema
（例: `Schema(versionedSchema: SchemaV2.self)`）を一次源として
`ModelConfiguration("ShiftAlarmStore", schema:, url:)` を組み立て、
`ModelContainer(for:, migrationPlan:, configurations:)` に migration plan を渡す。
マイグレーション時に新 schema へ切り替えるのはこの 1 箇所。

## Widget 側の共有点

- `Widget/ShiftAlarmWidget.entitlements` が本体と同一の `$(SHIFTALARM_APP_GROUP_ID)` を宣言。
- Widget の TimelineProvider は `SharedPersistence.makeContainer()` を通じて
  同じ store URL を開く（**別プロセスで同一ファイルを読み書き**）。
- アプリ本体側で `@Model` を変更したら Widget Extension のビルドターゲットでも
  同じ Domain ソースをコンパイルしているため、現行 `SchemaVN.models` と
  migration plan に追加するだけで Widget も自動追従する。逆に追加し忘れると
  Widget が起動しない。

## 変更時の checklist

- [ ] `SchemaV1.models`（または新 `SchemaVN.models`）に新 model を追加した
- [ ] `SHIFTALARM_APP_GROUP_ID` を**変えていない**
- [ ] `storeFileName` を**変えていない**（互換性のため `ShiftAlarm.store` 固定）
- [ ] `App/ShiftAlarm.entitlements` と `Widget/ShiftAlarmWidget.entitlements` の
      application-groups が一致している
- [ ] 重量マイグレーションなら `SchemaMigrationPlan.stages` を定義し、
      `ModelContainer(for:, migrationPlan:, configurations:)` に渡している
- [ ] `bash scripts/verify.sh test` で既存テストが緑のまま
