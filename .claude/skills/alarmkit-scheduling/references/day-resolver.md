# DayResolver の precedence 早見表

実装：`Sources/Domain/Logic/DayResolver.swift`（`DayResolver.resolve(date:input:)`）。
入力は `Sources/Domain/Logic/DayResolverInputBuilder.swift` が SwiftData モデルから組み立てる。

## 評価順序

`resolve(date:input:)` は以下の順に最初にヒットしたものを返す。
**`manual > holiday > rotation > none`**。

1. `manualAssignments[startOfDay(date)]` がある → `.manual(...)` を返す。
   - `presetID` から `presets[id]` を引いて `alarmTime` を補完するが、
     `overrideTime` が指定されていれば常にそれを優先する。
   - `skipAlarm == true` の場合、`fireTime == nil`（鳴らさない）になる。
2. `holidays[startOfDay(date)]` がある →
   - `skipAlarm == true` なら `.holiday(skip: true, replacement: nil)` を返す（鳴らさない）。
   - `replacementPresetID` がある → 該当 preset の `alarmTime` で `.holiday(skip: false, ...)`。
   - `skipAlarm == false` で replacement が無い → **rotation 評価へフォールスルー**
     （祝日扱いでも通常のローテーションを鳴らす）。
3. `rotations.filter { isActive }` のうち `applies(_:to:calendar:)` が true のものを
   `priority` 降順で総当たり。
   - `cycleLength <= 0` または `slots.count != cycleLength` の壊れた pattern は
     スキップして次の候補へ。
   - `RotationExpander.presetID(for:pattern:calendar:)` が `nil` を返した日（明示休み slot）は
     `.none` を返してその場で確定。
   - presetID が返るが `presets[id]` に存在しない（削除された preset）場合は次候補へ。
4. 全て該当しなければ `.none`。

## 具体例 3 ケース

### ケース 1：祝日 vs ローテーション（holiday が勝つ）

- 同じ日に「祝日 (`skipAlarm == true`)」と「ローテーションで早番 06:00」が当たる。
- → `.holiday(skip: true)` が返る。**ローテーションは無視され、アラームは鳴らない。**

### ケース 2：手動割当 vs 祝日（manual が勝つ）

- 同じ日に「手動で 09:00、`skipAlarm == false`」と「祝日（休み扱い）」が当たる。
- → `.manual(alarmTime: 09:00, skip: false)` が返る。**祝日設定は無視される。**

### ケース 3：祝日かつ `skipAlarm == false` で replacement 無し → rotation を継続使用

- 「祝日（label='平常運転'、`skipAlarm == false`、`replacementPresetID == nil`）」が
  当たり、なおかつローテーションで遅番 14:00 が当たる。
- → ホリデー判定をフォールスルーして `.rotation(presetID: 遅番, alarmTime: 14:00)`。
  **祝日として記録しつつ、通常のシフトアラームは鳴る。**

### ケース 4（補足）：ローテーション slot が nil → none

- ローテーションの slot 配列に `nil`（明示的な休み）があり、その日に当たる。
- → 同 priority 以下を見ずに `.none` を確定する（明示休みは下位 pattern にフォールスルーしない）。

## 仕様変更時の注意

- precedence のいずれかを動かす変更は **仕様変更**。`docs/` の該当章を必ず更新し、
  `Tests/DayResolverTests.swift` のケースも追加・更新する。
- `RotationExpander.presetID(for:pattern:calendar:)` の挙動を変える場合、
  cycle anchor（`anchorDate` からの差分）と無効 pattern スキップ（DayResolver 側）の
  契約を必ず再確認する。
