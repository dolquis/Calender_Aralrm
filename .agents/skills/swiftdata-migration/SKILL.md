---
name: swiftdata-migration
description: Sources/Domain/ の SwiftData @Model を追加・変更・削除するとき、App Group ストアとの整合性、既存ユーザーデータのマイグレーション、Widget との SwiftData 共有を扱うときに使用する。
---

# SwiftData マイグレーション運用

## このスキルが扱う範囲

- `Sources/Domain/Models/` 配下の `@Model` 定義群
- `Sources/Domain/Persistence/SchemaV1.swift`（`VersionedSchema`）
- `Sources/Domain/Persistence/ModelContainer+Shared.swift`（`SharedPersistence.makeContainer`）
- App Group 共有ストア（`SHIFTALARM_APP_GROUP_ID`、既定値 `group.com.example.shiftalarm`）
- `Sources/Services/Sharing/ShiftBundleCodec.swift` — `.shiftalarm` JSON のスキーマ整合
- `Tests/` でのスキーマ破壊検出

## 変更時の判定マトリクス

| 変更の種類 | マイグレーション要否 | 注意点 |
|---|---|---|
| 新規 `@Model` 追加 | 不要（既存データに影響なし） | `SchemaV1.models` に追加し忘れない |
| 新規プロパティ追加（optional / 既定値あり） | 軽量で可 | デフォルト値が `DayResolver` の precedence と矛盾しないか |
| プロパティの型変更／削除 | **重量マイグレーション必須** | 新 `VersionedSchema` + `SchemaMigrationPlan` で明示 |
| `@Relationship` の変更 | **重量マイグレーション必須** | 既存リンクの保全方針を決める |
| `.shiftalarm` JSON スキーマと連動する変更 | エクスポート／インポートの両方を更新 | バージョンフィールドを bump、`ShiftBundleCodec` の legacy 受け入れを壊さない |

## 守るべき手順

1. 変更前のスキーマを `SchemaV1` として残し、新スキーマは `SchemaV2`（`VersionedSchema`）を新設。
2. `SchemaMigrationPlan.stages` で変換を明示し、`SharedPersistence.makeContainer` の
   schema/configuration を新版に切り替える。
3. **App Group ストア URL を変えない**（Widget が読めなくなる）。
   `SharedPersistence.storeURL()` が返すパス（`containerURL(forSecurityApplicationGroupIdentifier:)
   .appendingPathComponent("ShiftAlarm.store")`）に依存していることを忘れない。
4. `.shiftalarm` JSON の import 側（`ShiftBundleCodec`）にも対応コードを追加。PR #5 の
   legacy `exportedAt` / `CalendarDay` 互換を踏襲。
5. テストを追加（既存データを読み込めるか、変換が冪等か、Widget 側 fetch が壊れないか）。

## 補助ツール（マーケット品を活用）

- API 仕様確認：Context7 MCP 経由で <https://developer.apple.com/documentation/swiftdata/schemamigrationplan> を fetch
- コード補完：エディタの Swift LSP（Claude Code では `swift-lsp` プラグイン）

## やってはいけない

- マイグレーションを書かずに `@Model` の型を破壊的に変える（既存ユーザーのデータが消える）。
- App Group ID（`SHIFTALARM_APP_GROUP_ID`）を変更する（既存インストールで Widget と本体が見えなくなる）。
- `.shiftalarm` JSON のスキーマを変えずに `@Model` だけ変える（インポートが壊れる）。
- `SchemaV1.models` 配列に新 model を追加し忘れる（`makeContainer` が新 model を知らない）。

## 参照
- `references/app-group-store.md` — App Group SwiftData ストアの設定とパス
