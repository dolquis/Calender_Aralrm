# P2-α / P2-β / P2-γ アルゴリズム詳細

ROADMAP.md §4 の P2-α / P2-β / P2-γ について、**実装に必要なアルゴリズム本体・
パラメータ・テスト設計**を詰めたドキュメント。ROADMAP は「何を作るか」、本書は
「どう作るか」を担当する。各テスト ID は ROADMAP §9 と 1:1 対応している。

最終更新: 2026-05-18

---

## 1. P2-α — シフトパターン自動検出

### 1.1 入力

- `manualAssignments: [Date: DayAssignmentSnapshot]`
  （[`DayResolverInputBuilder`](../Sources/Domain/Logic/DayResolverInputBuilder.swift)
  から）
- `presets: [UUID: ShiftPresetSnapshot]`
- `today: Date`
- `calendar: Calendar`
- `config: ShiftPatternDetector.Configuration`

```swift
public struct Configuration {
    public var windowDays: Int = 90        // α-U11
    public var minCycleLength: Int = 2     // α-U4 が日単位の交互を許す
    public var maxCycleLength: Int = 35    // 5 週
    public var minCycles: Int = 2          // α-U2
    public var minMatchRate: Double = 0.85 // α-U6 / α-U7
    public var minDensityPerSlot: Double = 0.5
}
```

### 1.2 シンボル表現

各 `Date d ∈ [today - windowDays, today - 1]` について:

| 手動割当の状態 | Symbol |
|---|---|
| `manualAssignments` に存在しない | `nil` (ワイルドカード) |
| `skipAlarm == true` または `presetID == nil` | `.off` |
| `presetID == someUUID` かつ `presets` に存在 | `.preset(UUID)` |
| `presetID == someUUID` だが `presets` に存在しない | `nil` (ワイルドカード) |

結果: `series: [Symbol?]` 長さ `windowDays`。

ローテーション由来のプリセットは `DayAssignment` 行として永続化されないため、
フィルタは入力選択時点で暗黙に成立する (α-U10)。

### 1.3 周期探索

候補 `P ∈ [minCycleLength, maxCycleLength]` について:

1. 各スロットの `expectedCount[s] ≥ minCycles` を満たさなければ `P` を棄却。
2. インデックスを `i mod P` でグループ化。各スロット `s ∈ 0..<P` について:
   - 非 nil シンボルを `{s, s+P, s+2P, ...}` から集める。
   - `expectedCount[s]`: window 内で `i mod P == s` になる日数
     （90 日窓の末尾にある部分サイクルを含む）。
   - `density[s] = observedCount / expectedCount[s]`。
   - `mode[s] = 非 nil シンボルの最頻値`（タイブレーク: 窓内の最初の出現が早い側）。
   - `slotMatchRate[s] = count(symbols == mode[s]) / observedCount`
     （分母にワイルドカードを含めない — 確定済み設計）。
3. いずれかの `density[s] < minDensityPerSlot` ならば `P` を棄却。
4. `overallMatchRate(P) = Σ matches / Σ observed`。
5. `overallMatchRate(P) < minMatchRate` ならば `P` を棄却。

### 1.4 最良周期の選択

棄却されなかった `P` のうち:

- `overallMatchRate(P)` 最大の `P*` を選ぶ。
- タイブレークは小さい `P` を優先（よりシンプルな周期）。
  α-U3 vs α-U4 の弁別: 「DDDDDDD NNNNNNN」は `P=2` で score 0.5 → `P=14` が勝つ。
  「DNDNDN...」は `P=2` で score 1.0 → `P=2` が勝つ。

### 1.5 正規化（月曜アンカー — α-U12）

最良 `P*` と `mode[0..<P*]` から:

- `today - windowDays` 以降で最も早い月曜日を `anchorDate` とする。
- `phaseShift = (firstWindowDate - anchorDate) mod P*` を計算し、スロット配列を
  回転して `anchorDate` がスロット 0 に揃うようにする。

### 1.6 出力

```swift
public struct SuggestedRotation: Equatable, Sendable {
    public let anchorDate: Date
    public let cycleLength: Int
    public let slots: [UUID?]          // .off → nil
    public let confidence: Double      // = overallMatchRate
    public let observedDays: Int
    public let fingerprint: String     // sha256("\(P)|\(slots)") — snooze 識別用
}
```

どの `P` も全ゲートを通過しない場合は `nil`。

### 1.7 スヌーズ

`AppSettings` に追加:

- `patternSuggestionSnoozedUntil: Date?`
- `patternSuggestionSnoozedFingerprint: String?`

表示側ロジック（`RotationListView` / Onboarding 分岐）:

- 検出器が `SuggestedRotation s` を返す場合:
  - `snoozedFingerprint == s.fingerprint && now < snoozedUntil` → 非表示 (α-I5)
  - それ以外 → カード表示
- **Accept**: `RotationPattern(anchorDate:, cycleLength:, slots:, priority: 0,
  isActive: true)` を insert → `AlarmScheduler.refreshScheduledAlarms()` 呼出。
- **Reject**: `snoozedUntil = now + 30 days`,
  `snoozedFingerprint = s.fingerprint` (α-I4 / α-I5)。

異なる fingerprint の新提案はスヌーズを迂回する。

### 1.8 テスト対応

| ROADMAP test | アルゴリズム上の保証 |
|---|---|
| α-U1 | 空 series → どの `P` も `minCycles` を満たさず `nil` |
| α-U2 | 各スロットの `expectedCount < 2` → `P` 棄却 |
| α-U3 | 14 日交互: `P=14` score 1.0; `P=2` score 0.5 → `P=14` 勝 |
| α-U4 | "DNDNDN..." `P=2` score 1.0 → タイブレークで `P=2` |
| α-U5 | 22 日混合: `P=22` のみ閾値超え |
| α-U6 | ノイズ多: どの `P` も 0.85 未満 → `nil` |
| α-U7 | Configuration で閾値を上下できる |
| α-U8 | `mode` は preset 同一性を保つ |
| α-U9 | `.off` シンボルへのマッピング |
| α-U10 | 入力構築時に手動のみ抽出 |
| α-U11 | `windowDays` 境界 |
| α-U12 | 月曜正規化（1.5 節） |

### 1.9 受入後ドリフト検出

派生機能 **A1**（ROADMAP §4 P2-α A1）の本体ロジック。

**入力:**

- `pattern: RotationPatternSnapshot`（既に受諾済み、`isActive == true`）
- `recentManualAssignments: [Date: DayAssignmentSnapshot]`（直近 30 日）
- `presets: [UUID: ShiftPresetSnapshot]`
- `today: Date`、`calendar: Calendar`
- `threshold: Double = AppSettings.patternDriftThreshold`（既定 0.15）

**手順:**

1. `window = [today - 30 days, today - 1]` を `calendar.startOfDay` で正規化。
2. 各日 `d ∈ window` について:
   - `expected = pattern.slots[baseSlotIndex(d, pattern)]`（連休越境拡張があれば
     `VacationAwareRotation` を使う）
   - `manual = recentManualAssignments[d]`
   - `manual == nil`（手動上書き無し）の日は分母に含めない（ローテ展開を信頼）。
   - `manual != nil` 日のうち `manual.presetID ≠ expected` の件数を分子に。
3. `mismatchRate = mismatches / observed`。`observed == 0` なら `nil` を返す。
4. `mismatchRate < threshold` → `nil`。
5. しきい値超 → `ShiftPatternDetector.detect(...)` を **同じ `recentManualAssignments`
   入力で再走** → 新 `SuggestedRotation` を返す。
6. 呼び出し側（`RotationListView` / 同 ViewModel）は新 `fingerprint` を既存 pattern
   から導出した fingerprint と比較し、**異なる場合のみ** カードを表示する。
7. スヌーズ判定は α-I4/I5 と同じ `patternSuggestionSnoozedFingerprint` / `Until` を
   共用する。

**受諾フロー:**

- 新 `RotationPattern` を **新規 priority** で insert（既存 pattern の priority より
  高く、または同等）。
- 既存 pattern の `isActive = false` をセット（履歴保持目的）。
- `AlarmScheduler.refreshScheduledAlarms()` を呼出。

**API シグネチャ案:**

```swift
extension ShiftPatternDetector {
    public func detectDrift(
        pattern: RotationPatternSnapshot,
        recentManualAssignments: [Date: DayAssignmentSnapshot],
        presets: [UUID: ShiftPresetSnapshot],
        today: Date,
        calendar: Calendar,
        threshold: Double
    ) -> SuggestedRotation?
}
```

### 1.10 DOW 検出

派生機能 **A2**（ROADMAP §4 P2-α A2）の本体ロジック。α 周期検出器と
**並走** する別アルゴリズム。

**Configuration 追加:**

```swift
extension ShiftPatternDetector.Configuration {
    public var minDOWDensity: Double = 0.6
    public var minDOWMatchRate: Double = 0.85
}
```

**手順:**

1. 各日 `d ∈ window`（α と同 90 日窓）について `(weekday, weekOfMonth)` を計算:
   - `weekday = calendar.component(.weekday, from: d)`（1..7）
   - `weekOfMonth = calendar.component(.weekOfMonth, from: d)`（1..6）
2. 観測を `Dictionary<DOWKey, [Symbol]>` に集約（Symbol は α と同じ
   `.preset(UUID)` / `.off` / nil）。
3. 各キーについて:
   - `observedCount` = 非 nil シンボル数
   - `expectedCount` = 窓内でその `(weekday, weekOfMonth)` が出現した回数
   - `density = observedCount / expectedCount`
   - `mode` = 最頻値（α と同じタイブレーク規則）
   - `matchRate = count(symbols == mode) / observedCount`
4. `density ≥ minDOWDensity` かつ `matchRate ≥ minDOWMatchRate` のキーを採用。
5. 採用キーごとに `SuggestedDOWRule { dayOfWeek, weekOfMonth, presetID, observedMatches,
   confidence: matchRate }` を生成。

**出力:**

```swift
public struct SuggestedDOWRule: Identifiable, Equatable, Sendable {
    /// 検出器が `(dayOfWeek, weekOfMonth, presetID)` から **決定論的に** 生成する
    /// 安定 ID。同じ規則が同じ入力から再検出されれば同じ UUID になる
    /// （例: `UUID(uuidString:)` を `SHA256("\(dayOfWeek)|\(weekOfMonth)|\(presetID?.uuidString ?? "off")")`
    /// の先頭 16 byte で生成）。`HolidayOverride.expandedFromRuleID` がこれを
    /// 参照し、後日 §P3-15 で `RuleExpandedOverride` に migration するときに
    /// 「元の規則」を再特定できるようにする。受諾時に毎回新 UUID を振ると
    /// provenance チェーンが切れて migration が壊れるため避ける。
    public let id: UUID
    public let dayOfWeek: Int            // 1..7（calendar 由来）
    public let weekOfMonth: Int          // 1..6
    public let presetID: UUID?           // .off → nil
    public let observedMatches: Int
    public let confidence: Double
}
```

**受諾フロー:**

v1 では `HolidayOverride` 経由で展開する（新 `@Model` を作らない）:

- 採用された各 `SuggestedDOWRule` について、次の 6 ヶ月の該当日を計算。
- 各該当日に `HolidayOverride(date: d, presetID: rule.presetID,
  skipAlarm: rule.presetID == nil, isVacationGroup: false,
  expandedFromRuleID: rule.id, expandedAt: now)` を upsert。
- 6 ヶ月の境界は **ユーザが UI で再生成を承認するまで** 自動更新しない（過剰書込み
  を避ける）。

**provenance 列の追加（v1 必須、ROADMAP §P3-15 への前提条件）**: A2 v1 出荷時に
`HolidayOverride` へ次の 2 列を追加する:

- `expandedFromRuleID: UUID?` — A2 由来なら DOW ルール ID、ユーザ手動 override
  なら `nil`
- `expandedAt: Date?` — 再展開バッチの判定用、手動なら `nil`

この 2 列が無いまま A2 を出すと、ユーザ手動の祝日 override と A2 自動展開行が
テーブル上区別できなくなり、後日 §P3-15 で `RuleExpandedOverride` に分離する
migration で「どの行を移すか」を確定できない。lightweight migration の範囲で
完結する（nullable 2 列追加 / 既存 row は両方 `nil`）。Widget 側 SwiftData
container でも schema 解決できることを `/swiftdata-migration` skill 起動時に
確認する。

**実装精緻化（2026-05-27 追加）:**

- 検出器設定を `ShiftPatternDetector.Configuration` の入れ子としてではなく、
  **独立 struct** として持つことを推奨（A2 を α と別ファイルに分離した場合に再利用
  しやすい）:
  ```swift
  public struct DayOfWeekPatternDetectorConfiguration: Sendable {
      public var windowDays: Int = 90
      public var minDensity: Double = 0.6
      public var minMatchRate: Double = 0.85
      public var minObservedMatches: Int = 2
  }
  ```
- 初期実装範囲は `weekday + weekOfMonth` のみ。`lastWeekOfMonth`（毎月最終週ルール）
  は Phase 2 として後送する。
- **受諾フローは §7 の `ChangePreview` を経由**。`HolidayOverride` 展開前に
  該当日リストをユーザがレビューできる。
- **展開件数増の懸念**: A2 が `HolidayOverride` に最大 6 ヶ月分一括 insert すると
  行数が膨らむため、運用数値を見て **専用テーブル `RuleExpandedOverride`** への
  分離を検討（ROADMAP §P3-15 バックログ）。
- テスト ID DOW-U1〜DOW-I3（ROADMAP §9-α 末尾）と一対一でアルゴリズム上の保証点を
  対応させる。

### 1.11 テスト対応（A1 / A2）

| ROADMAP test | アルゴリズム上の保証 |
|---|---|
| α-U13 | §1.9 step 4 のしきい値ゲート |
| α-U14 | §1.9 step 5-6（再検出 + fingerprint 比較） |
| α-U15 | §1.10 step 4 で第 1・第 3 金曜の 2 キーが採用される |
| α-U16 | §1.10 step 3-4 の density ゲート |
| α-U17 | α 周期検出と §1.10 DOW 検出が独立に走り、両者の出力が UI で並列表示される |
| α-I7 | §1.9 受諾フローで旧 pattern が `isActive=false` 化 |

---

## 2. P2-β — 連休越境ローテーション

### 2.1 データモデル追加（Schema V2）

**新規 @Model `VacationPeriod`**（`Sources/Domain/Models/VacationPeriod.swift`）:

```swift
@Model public final class VacationPeriod {
    @Attribute(.unique) public var id: UUID
    public var startDate: Date           // inclusive、startOfDay 正規化
    public var endDate: Date             // inclusive、startOfDay 正規化
    public var label: String
    public init(id: UUID = UUID(), startDate: Date, endDate: Date, label: String)
}
```

最短 3 日は書き込み時に validate（`endDate - startDate ≥ 2 days`）。(β-U7)

**Enum**（同ファイル or `VacationPolicy.swift`）:

```swift
public enum CrossVacationPolicy: Int, Codable, Sendable, CaseIterable {
    case invert = 0     // 既定
    case `continue` = 1
    case resetToDay = 2
}
```

**フィールド追加**:

- `RotationPattern.crossVacationPolicyRaw: Int = 0` (default `.invert`)
- `RotationPattern.dayStartSlotIndex: Int?` —
  「昼勤始まり」スロット。nil なら自動導出。UI で明示可。
- `ShiftPreset.crossVacationPolicyRaw: Int?` —
  **optional** override（nil ならパターン側に従う）
- `HolidayOverride.isVacationGroup: Bool = false` —
  UI 表示用フラグのみ。resolver では使わない

`DayResolver.swift` のスナップショット構造体にも対応フィールドを追加。
`VacationPeriodSnapshot { startDate, endDate, label }` を新設。
`DayResolverInput` に `vacations: [VacationPeriodSnapshot]` を追加。

### 2.2 スキーママイグレーション（V1 → V2）

SwiftData の lightweight migration:

- 新規 @Model `VacationPeriod` — 追加のみ。既存行に影響なし
- `RotationPattern.crossVacationPolicyRaw`: 既定 0 で既存行を埋める (β-S1)
- `RotationPattern.dayStartSlotIndex`: optional、既存行は nil
- `ShiftPreset.crossVacationPolicyRaw`: optional、既存行は nil
- `HolidayOverride.isVacationGroup`: 既定 false (β-S2)
- **既存 `HolidayOverride` の連続範囲を自動的に `VacationPeriod` 化しない** (β-S3)

`Sources/Domain/Persistence/SchemaV2.swift` + `MigrationPlan.swift` を新設し、
`SchemaV2.versionIdentifier = Schema.Version(2, 0, 0)`、
`SchemaMigrationPlan` の `stages = [.lightweight(fromVersion: SchemaV1.self,
toVersion: SchemaV2.self)]` を用意。

**実装精緻化（2026-05-27 追加）:**

- **Widget の SwiftData container も V2 を読むこと** を確認する。App と Widget は
  App Group 配下の同一 SwiftData store を共有しているため、`Widget/` 側の
  `ModelContainer` 初期化コードでも `SchemaV2` を渡す必要がある。`/swiftdata-migration`
  skill を起動して確認漏れを防ぐ。
- `CrossVacationPolicy.invert/continue/resetToDay` の **Int rawValue (0/1/2) は確定**。
  将来追加する policy は rawValue 3 以降に積み、既存数値を変更しない。
- `VacationPeriod` は **独立 @Model** で `HolidayOverride` とは別エンティティ。
  `HolidayOverride.isVacationGroup` は「`VacationPeriod` 由来か否かのマーカー」専用
  であり、単日 override の責務に侵食しない。

### 2.3 アルゴリズム: `VacationAwareRotation.presetID`

`DayResolver.resolve` のローテ分岐を置き換える。

```
入力:
  date d
  pattern p (RotationPatternSnapshot)
  vacations V (startDate 昇順)
  presets (UUID -> ShiftPresetSnapshot)

出力:
  UUID?  (preset id、連休セルは nil)
```

**Step 1 — 連休所属。**
`v.startDate ≤ d ≤ v.endDate` を満たす `v ∈ V` があれば `nil` を返す (β-U6)。

**Step 2 — 直前連休の累積シフト。**

```
shift = 0
phaseAdjust = 0
prevWorkingPresetIdx = baseSlotIndex(p.anchorDate, p)
for v in V where v.endDate < d:
    duration = daysBetween(v.startDate, v.endDate) + 1
    // ".continue" 意味論: 連休日数をサイクルカウンタから除外
    shift -= duration
    // この連休のポリシーを決定
    policy = policyFor(v, p, presets, prevWorkingPresetIdx)
    switch policy {
    case .continue:
        break  // shift -= duration で吸収済み
    case .invert:
        phaseAdjust += p.cycleLength / 2  // 整数除算
    case .resetToDay:
        // 連休明け初日を「昼勤始まりスロット」にスナップ
        let dayAfter = v.endDate + 1 day
        let baseIdx = (baseSlotIndex(dayAfter, p) + shift + phaseAdjust) mod L
        let target = effectiveDayStartSlot(p, presets)
        phaseAdjust += (target - baseIdx) mod L
    }
    // prevWorkingPresetIdx を v.startDate - 1 日時点に更新
    let preVacDate = v.startDate - 1 day
    let preVacIdx = (baseSlotIndex(preVacDate, p) + shiftSnapshot + phaseAdjustSnapshot) mod L
    prevWorkingPresetIdx = preVacIdx

return slot at (baseSlotIndex(d, p) + shift + phaseAdjust) mod L
```

ここで:

- `baseSlotIndex(date, p) = ((daysBetween(p.anchorDate, date)) mod p.cycleLength + p.cycleLength) mod p.cycleLength`
- `L = p.cycleLength`
- `daysBetween` は両日を `calendar.startOfDay` 正規化した上で
  `calendar.dateComponents([.day], from: a, to: b).day!`。

**Step 3 — `policyFor(v, p, presets, prevWorkingPresetIdx)`**
（pattern + preset 階層）:

```
let prevPresetID = p.slots[prevWorkingPresetIdx]
if let prevPreset = prevPresetID.flatMap({ presets[$0] }),
   let override = prevPreset.crossVacationPolicy {
    return override
}
return p.crossVacationPolicy   // 既定 = .invert
```

スナップショット構造体は preset 側に `crossVacationPolicy: CrossVacationPolicy?`、
pattern 側に non-optional の同名フィールドを持つ。

**Step 4 — `effectiveDayStartSlot(p, presets)`**（`.resetToDay` 用）:

```
if let explicit = p.dayStartSlotIndex { return explicit }
// 自動導出: defaultAlarmHour が [4,12] に入る最早スロット、
// 同点はインデックス昇順。
return p.slots
  .enumerated()
  .compactMap { (idx, pid) in
      guard let pid, let pre = presets[pid] else { return nil }
      guard let h = pre.alarmTime?.hour, (4...12).contains(h) else { return nil }
      return (idx, h)
  }
  .min(by: { ($0.1, $0.0) < ($1.1, $1.0) })?.0 ?? 0
```

### 2.4 DayResolver への組込

[`Sources/Domain/Logic/DayResolver.swift`](../Sources/Domain/Logic/DayResolver.swift)
内の `RotationExpander.presetID(...)` 呼出し箇所を
`VacationAwareRotation.presetID(...)` に置き換え、`input.vacations` を渡す。

手動 `DayAssignment` と `HolidayOverride` の優先順位は不変。
連休内の手動割当は手動が勝つ（β-U10）。

### 2.5 AlarmScheduler への影響

`AlarmScheduler` のコード変更は不要。`DayResolverInput` と `ResolvedDay` を消費
するだけなので、`VacationAwareRotation` が連休日に `nil` を返せば期待アラーム
集合から自動除外される (β-I1)。連休明け日も flipped preset として解決される
ため、`AlarmKit` 登録時刻が自動的に正しくなる (β-I2 / β-I3)。

### 2.6 UI 変更（仕様のみ）

- **`Sources/Features/Holidays/HolidayManagerView.swift`**: 範囲選択 →
  「選択範囲を連休にする」アクション:
  - 連続性と `count ≥ 3` を検証
  - ラベル入力シートを開く
  - 範囲分の `VacationPeriod` を作成
  - 範囲内の `HolidayOverride` 行に `isVacationGroup = true` を立てる
    （無ければ off-override を新規作成）
- **`Sources/Features/Rotation/RotationEditorView.swift`**:
  `crossVacationPolicy` ピッカー（3 オプション + ヘルプテキスト）。
  `dayStartSlotIndex` 設定用の任意ステッパー。
- **`Sources/Features/Presets/PresetEditorView.swift`**: ピッカー 4 択
  （「パターンに従う (default)」「継続」「反転」「昼勤リセット」）を
  `crossVacationPolicy` にバインド。

### 2.7 テスト対応

| ROADMAP test | アルゴリズム上の根拠 |
|---|---|
| β-U1 | 直前連休なし → `shift = phaseAdjust = 0` → 基底 expander と一致 |
| β-U2/β-U3 | `.invert` → `phaseAdjust += L/2`、半周期反転 |
| β-U4 | `.continue` → `shift -= duration` のみ |
| β-U5 | `.resetToDay` → `effectiveDayStartSlot` にスナップ |
| β-U6 | Step 1 |
| β-U7 / β-U8 | 書き込み時 validate（`≥ 3` 日 + 明示操作） |
| β-U9 | 連休ループでシフト累積 |
| β-U10 | `DayResolver` の優先度連鎖は不変 |
| β-U11 | `rotations` は `priority` 順、最高優先 pattern を選択 |
| β-U12 / β-U13 | `daysBetween` が `calendar` 由来 → 月/年境界も自然 |
| β-S1/2/3 | 2.2 節 |
| β-I1/2/3 | 2.5 節 |
| β-U14/U15/U16 | 4.3.3 節（preset override） |

### 2.8 自動グルーピング提案フロー

派生機能 **A4**（ROADMAP §4 P2-β A4）の本体ロジック。β-S3 の不変条件
「マイグレーションで自動グルーピングしない」を踏襲しつつ、**初回 β 画面オープン
時に 1 回だけ**ユーザ同意を取って既存 `HolidayOverride` を `VacationPeriod` に
昇格させる。

**検出:**

1. SwiftData query: `HolidayOverride` を `date` 昇順で取得。
2. ランレングス: 隣接日 `date_i+1 == date_i + 1 day` を連続とみなし、ラン化。
3. ラン長 `≥ 3` のものを候補化（β-U7 と同じ最短日数）。
4. 各候補に「範囲 + 含まれる祝日ラベル」を付与して候補リストにまとめる。

**提示:**

- 初回 β 画面（`HolidayManagerView` / `RotationListView` どちらでもよい — 設計時に
  選択）オープン時、`AppSettings.vacationAutoGroupingOffered == false` なら sheet を
  開く。
- sheet には候補リストを表示、チェックボックスで個別に含める / 含めない選択可。
- 「全てまとめる」「選択分のみまとめる」「あとで」の 3 ボタン。

**適用:**

- 選択された各 ran について:
  - `VacationPeriod(startDate: run.start, endDate: run.end,
    label: "自動グルーピング: \(label_set.joined(", "))")` を insert。
  - 範囲内 `HolidayOverride.isVacationGroup = true` を更新。
- 適用後 `AppSettings.vacationAutoGroupingOffered = true`。

**閉じる:**

- 「あとで」または sheet 閉じるだけでも `vacationAutoGroupingOffered = true` に
  する（再表示しない）。ユーザは後から個別に手動で `VacationPeriod` を作成できる
  ので、機会を逃しても困らない。

**API シグネチャ案:**

```swift
public enum VacationAutoGrouping {
    public static func detectCandidates(
        holidays: [HolidayOverride],
        calendar: Calendar,
        minRunLength: Int = 3
    ) -> [VacationCandidate]

    public static func apply(
        candidates: [VacationCandidate],
        context: ModelContext
    ) throws
}

public struct VacationCandidate: Equatable, Sendable {
    public let startDate: Date
    public let endDate: Date
    public let holidayLabels: [String]
}
```

**テスト対応:**

| ROADMAP test | アルゴリズム上の根拠 |
|---|---|
| β-U17 | §2.8 検出 step 3（≥ 3 日のみ） |
| β-U18 | apply で選択された候補のみ insert |
| β-I4 | sheet 表示時に `vacationAutoGroupingOffered = true` を立てる |

---

## 3. P2-γ — シフト表画像インポート

### 3.0 Phase 構成（2026-05-27 仕様提案書取り込みで更新）

評価時の指摘「Vision OCR は日本語縦書き・手書き勤務表で精度が出にくい / グリッド
推定は本番品質まで持っていくのに大工数」を反映し、**OCR 抜きでも動く土台を先行**
させる Phase 構成へ再整理した。各 Phase は単独で価値を提供できる。

| Phase | スコープ | 完成時に提供される価値 |
|---|---|---|
| **Phase 1 — 手動グリッド + 記号マッピング** | 表範囲・日付行・データセルをユーザがタップで指定。`ShiftSymbolMapping` を保存し次回以降は自動適用。差分プレビューは §7 `ChangePreview` を経由 | **OCR 完全失敗時でも画像取込が完結する**フォールバック UX が常時利用可能 |
| **Phase 2 — Vision OCR 自動抽出** | `OCRTextRecognizer` / `ShiftTableGridDetector` で §3.1〜§3.4 を自動化。信頼度 `high/medium/low` のうち low セルは未選択で Phase 1 の手動フローへ落ちる | 自動抽出が成功するケースでは入力負荷が大幅に下がる |
| **Phase 3 — FoundationModels 補助** | iOS 26 `FoundationModels` でラベル意味マッピング補助 + 勤務表形式推定。利用不可機種ではルールベースに fallback | 曖昧記号・複雑な表構造の解釈精度が向上 |

§3.1〜§3.12 は Phase 2 / Phase 3 のパイプラインを詳述する。Phase 1 は記号
マッピング (§3.6 Stage 5) と差分プレビュー (§3.7 Stage 6) を **ユーザ操作で直接
駆動する** 形態と読み替える。

### 3.1 パイプライン全景（Phase 2 自動抽出時）

```
[画像入力]
    ↓ (PhotosPicker | DataScannerViewController)
[CGImage(s)]
    ↓ ShiftImageOCR.recognize
[OCRObservation[]]
    ↓ ShiftImageParser.detectGrid
[RosterGrid]
    ↓ ShiftImageParser.mergePages (複数画像時)
[RosterGrid]
    ↓ 従業員行フィルタ (ユーザピッカー、AppSettings.userNameOnRoster にキャッシュ)
[CellsForSelectedRow]
    ↓ FoundationModelsShiftMapper.map (ルールベース fallback あり)
[Date → MapResult]
    ↓ buildShiftBundle
[ShiftBundle]
    ↓ ShareImporter.preview / .apply  (既存、無改変)
[SwiftData persisted + AlarmScheduler.refreshScheduledAlarms()]
```

### 3.2 Stage 1 — OCR (`ShiftImageOCR`)

```swift
public protocol VisionOCRService: Sendable {
    func recognize(image: CGImage) async throws -> [OCRObservation]
}

public struct OCRObservation: Sendable, Equatable {
    public let text: String
    public let boundingBox: CGRect      // Vision 正規化座標 (0..1)
    public let confidence: Float
    public let angle: CGFloat           // ラジアン
}
```

実装は `VNRecognizeTextRequest` をラップ:

- `recognitionLevel = .accurate`
- `recognitionLanguages = ["ja-JP", "en-US"]`
- `usesLanguageCorrection = false`
- `customWords` = プリセット名 ∪ シフトラベル語彙
  (`["昼", "夜", "休", "明", "D", "N", "OFF", "AM", "PM", "Day", "Night"]`)

**回転トレランス**（γ-U3）: 観測角の中央値が 5° を超え、かつ初回試行なら
`CGImage` を `-medianAngle` だけ回転して 1 回だけ再試行する。

**空画像**（γ-U4）: Vision が `[]` → そのまま empty を返す。

### 3.3 Stage 2 — グリッド構造検出 (`ShiftImageParser`)

主経路（iOS 18+）: `VNRecognizeDocumentsRequest` の表構造を `RosterGrid` に
変換。

Fallback（旧 OS or 主経路が空 — γ-U6）:

1. **行クラスタリング**: `boundingBox.midY` で 1-D DBSCAN
   （ε = 0.5 × 観測高さの中央値）。`rows: [[OCRObservation]]` を得る。
2. **列クラスタリング**: 全観測の `midX` に対して同様。
3. **セルスナップ**: 各観測を最近傍重心の `(rowIdx, colIdx)` に割当。
4. **軸判定**:
   - 上端行で `1..31` の整数が 80% 以上を占める → 日付軸 = 列
   - 違うなら左端列を同様に判定 → 日付軸 = 行
   - どちらでもなければ `.gridStructureNotDetected` で失敗
5. **ヘッダ解析**:
   - 任意観測から `\d{4}\s*[年/-]\s*\d{1,2}` (ja) または
     `\b(Jan|Feb|...|Dec)\s+\d{4}\b` (en) で `(year, month)` を抽出。
   - 取れない場合は nil → UI で月入力をプロンプト。
6. **従業員軸ラベル**: 日付軸でない側の先頭観測。

```swift
public struct RosterGrid: Sendable, Equatable {
    public enum DateAxis { case rows, columns }
    public let dateAxis: DateAxis
    public let dates: [(index: Int, day: Int)]
    public let employees: [(index: Int, name: String)]
    public let cells: [GridKey: CellContent]  // 疎マップ
    public let detectedYear: Int?
    public let detectedMonth: Int?
}
```

### 3.4 Stage 3 — マルチページマージ (γ-U9)

複数画像を 1 セッションで取込む場合:

1. 各画像を独立にパース。
2. `(detectedYear, detectedMonth)` で昇順ソート。未検出はユーザ提示順を保つ。
3. 従業員名 union（NFKC + lowercase 正規化、Levenshtein ≤ 2 または substring
   で同一視）。
4. セルを結合。`(year, month, day)` 重複時は confidence が高い方を採用。

### 3.5 Stage 4 — 従業員行選択 (γ-U10)

```
if grid.employees.count == 1:
    その行を使用
else if AppSettings.userNameOnRoster がいずれかと fuzzy 一致:
    自動選択
else:
    ピッカー表示 → 確定で AppSettings.userNameOnRoster に保存
```

Fuzzy 一致: NFKC 正規化 + lowercase 後、`Levenshtein ≤ 2` または
「一方が他方を含む」で一致と判定。γ-D3 の 95% は curated fixture で測る。

### 3.6 Stage 5 — ラベル → preset (`FoundationModelsShiftMapper`)

```swift
public protocol ShiftLabelMapper: Sendable {
    func map(
        labels: [String],
        existingPresets: [ShiftPresetSnapshot]
    ) async -> [String: MapResult]
}

public enum MapResult: Sendable, Equatable {
    case existingPreset(UUID, confidence: Double)
    case newPreset(suggestedName: String, suggestedColorHex: String, confidence: Double)
    case off(confidence: Double)
    case unresolved(reason: String)
}
```

**2-pass 戦略。**

**Pass A — ルールベース**（常に最初に走る。LLM 不要、決定論的）:

| トークン (NFKC + lowercase) | 結果 |
|---|---|
| `休`, `休み`, `off`, `公休`, `有休` | `.off(1.0)` |
| `昼`, `日勤`, `d`, `day`, `am`, `早` | `.existingPreset(matchByName, 0.95)` または `.newPreset("昼勤", "#FFB300", 0.8)` |
| `夜`, `夜勤`, `n`, `night`, `pm`, `遅` | `.existingPreset(matchByName, 0.95)` または `.newPreset("夜勤", "#3949AB", 0.8)` |
| `明`, `明け` | `.off(0.9)`（夜勤明け休み） |
| 上記以外 | Pass B へフォールスルー |

既存プリセット一致: `ShiftPresetSnapshot.name` の NFKC 正規化済み完全一致または
case-insensitive substring。同点は `createdAt` が新しい方を優先（γ-U16）。

**Pass B — LLM**（`FoundationModels`、iOS 26+; γ-U13 / γ-U14 / γ-U15）:

- Pass A で未解決のラベルのみ呼ぶ。
- 可用性プローブ: `LanguageModel.isAvailable`（実装時に `.swiftinterface` で再確認）。
- プロンプト雛形:
  ```
  Existing shift presets: {JSON of [{name, colorHex, alarmTime}]}.
  Map these cell labels to the most likely preset.
  Output JSON: {label: {kind: "existing"|"new"|"off"|"unknown",
                       presetID?: UUID,
                       name?: string,
                       colorHex?: string,
                       confidence: 0..1}}.
  ```
- 信頼度閾値: **0.7**。下回ったら `.unresolved(reason: "low_confidence")` (γ-U15)。
- モデル不可なら Pass B は `.unresolved(reason: "model_unavailable")` を返す。
  パイプライン自体は完走し、差分プレビューでユーザに見せる。

### 3.7 Stage 6 — `ShiftBundle` 構築 → `ShareImporter` を再利用

既存型 [`ShiftBundle`](../Sources/Services/Sharing/ShiftBundleCodec.swift) を組立:

- `presets`: 参照済み既存プリセット + `.newPreset` で出てきた新規プリセット
  （新規 UUID を発番、色は循環選択）。
- `assignments`: 選択行のセルから `.existingPreset` / `.newPreset` / `.off`
  だったものを `AssignmentDTO` 化:
  - `.off` → `presetID: nil, skipAlarm: true`
  - `.existingPreset(id)` → `presetID: id, skipAlarm: false`
  - `.newPreset` → `presetID: <new UUID>, skipAlarm: false`
  - `.unresolved` は bundle に含めず、`unresolvedCells: [(date, text)]` として
    UI 側で「未確定セル — 手動で割り当ててください」表示する。
- 画像インポートでは `patterns: []`, `overrides: []` (γ-I1)。

その後:

```swift
let preview = ShareImporter.preview(bundle: bundle, container: container)
// 差分 UI 表示
ShareImporter.apply(bundle: bundle, container: container)
// AlarmScheduler.refreshScheduledAlarms()
```

`ShareImporter` は無改変。既存の add/update 差分 + id/date マージで γ-I3 の
「既存の手動上書きは破壊しない」を満たす。

冪等性 (γ-I4): `ShareImporter.apply` は `AssignmentDTO.date` キーで upsert する
ため、再試行で重複行は出ない。

### 3.8 ネットワークガード (γ-U12)

- `ShiftImageOCR`、`ShiftImageParser`、`FoundationModelsShiftMapper` は
  **`URLSession` を生成しない**。コードレビューで担保（コンパイル時には強制しない）。
- テストでは `URLSessionConfiguration.default.protocolClasses` に登録した
  `URLProtocol` サブクラスで全リクエストを失敗させ、パース実行中の観測リクエスト
  数が 0 であることを assert する。

### 3.9 日付組立

セル `(employeeRow, dateColumn)` ごとに:

- `day = grid.dates[dateColumn].day`
- `year = grid.detectedYear ?? userPicker.year`
- `month = grid.detectedMonth ?? userPicker.month`
- `CalendarDay(year:month:day:)` → `CalendarDay.date(in: calendar)`。

### 3.10 Info.plist 追加

- `NSCameraUsageDescription`（ja + en）
- `NSPhotoLibraryUsageDescription`（ja + en）

ROADMAP §7 規則 6 に従い `Resources/Localizable.xcstrings` に両言語を入れる。

### 3.11 テスト対応

| ROADMAP test | アルゴリズム上の根拠 |
|---|---|
| γ-U1 / γ-U2 | §3.2 + 実画像サンプル |
| γ-U3 | §3.2 回転リトライ |
| γ-U4 | §3.2 空入力 |
| γ-U5 / γ-U6 | §3.3 主経路 + fallback |
| γ-U7 | §3.6 Pass A 表 |
| γ-U8 | §3.6 `.unresolved` |
| γ-U9 | §3.4 |
| γ-U10 | §3.5 |
| γ-U11 | §3.3 疎マップ |
| γ-U12 | §3.8 |
| γ-U13–U16 | §3.6 |
| γ-I1–I4 | §3.7 (`ShareImporter` 再利用) |
| γ-D1–D3 | `Tests/Fixtures/ShiftImages/` で精度測定（ROADMAP §9-x の 1 ファイル 500 KB 上限） |

### 3.12 ラベル学習キャッシュ

派生機能 **A3**（ROADMAP §4 P2-γ A3）の本体ロジック。差分プレビュー UI で
ユーザが手動修正したラベル → preset 対応を保存し、次回の Pass A より前に参照
することで OCR/LLM 推論の精度を経験的に上げる。

**保存先:**

- `AppSettings.learnedLabelMappingsJSON: String`（既定: `"{}"`）。
- SwiftData の Dictionary 制約を避けるため JSON 文字列で保持。
- ロード時に `Data` → `JSONDecoder` で `[String: LearnedMapping]` にデコード。
- 保存時に `JSONEncoder` で再シリアライズ。

**型:**

```swift
public struct LearnedMapping: Codable, Equatable, Sendable {
    public let presetID: UUID?      // nil → .off を意味する
    public let isOff: Bool
    public let learnedAt: Date
}

public typealias LabelKey = String  // "<NFKC + lowercase>(label)|<userNameOnRoster?>"
```

`LabelKey` の構築:

```swift
let normalized = label.precomposedStringWithCompatibilityMapping.lowercased()
let key = "\(normalized)|\(AppSettings.userNameOnRoster ?? "")"
```

**マッパへの組込:**

`FoundationModelsShiftMapper.map(...)` の冒頭で参照:

```
for label in labels:
    let key = makeKey(label)
    if let cached = learned[key]:
        result[label] = cached.isOff
            ? .off(confidence: 1.0)
            : (cached.presetID.flatMap { id in
                existingPresets.first { $0.id == id }
                    .map { _ in MapResult.existingPreset(id, confidence: 1.0) }
              } ?? .unresolved(reason: "cached_preset_deleted"))
    else:
        // Pass A → Pass B に進む（既存ロジック）
```

**ユーザ補正フローでの書込:**

`ImageImportView` の差分プレビューでユーザがマッピングを変更したら：

1. 補正された `(label, presetID?)` を抽出。
2. `LabelKey` を計算。
3. `LearnedMapping(presetID:, isOff: presetID == nil, learnedAt: Date.now)` を
   `learnedLabelMappings[key] = ...` で upsert。
4. JSON 再シリアライズ → `AppSettings.learnedLabelMappingsJSON` に保存。

**LRU 退避:**

- 上限 200 エントリ。
- 書込み時に `learned.count > 200` なら `learnedAt` 古い順に 1 件削除。
- 等タイムスタンプは `LabelKey` 辞書順タイブレーク（決定論性）。

**削除セマンティクス:**

- 設定画面に「学習データをリセット」ボタンを追加。
- リセット = `learnedLabelMappingsJSON = "{}"`。
- 個別エントリ削除は UI からは提供しない（v1 は全消去のみ）。

**プライバシー:**

- すべて `AppSettings`（ローカル SwiftData）に保存。
- export (`.shiftalarm`) には含めない（`ShiftBundleCodec` から除外）。
- iCloud / CloudKit は使わない（前提）。

**テスト対応:**

| ROADMAP test | アルゴリズム上の根拠 |
|---|---|
| γ-U17 | キャッシュヒット時 Pass A をスキップし confidence 1.0 を返す |
| γ-U18 | `isOff = true` を保存 → 読み戻し |
| γ-U19 | 200 件入った状態で 201 件目を書込 → 最古退避 |
| γ-I5 | プレビュー補正ハンドラが JSON 再シリアライズ → 永続化 |

---

## 横断ノート

- **Calendar 正規化**: すべての `Date` 比較は `calendar.startOfDay(for:)` で
  正規化する（PR #5 の `CalendarDay` 方針と一致、DST/TZ ドリフト回避）。
- **決定性**: アルゴリズムは固定 `Calendar` のもとで入力の純粋関数。
  `Date.now` は α の `today:` パラメータ・snooze 読出経路以外では読まない。
- **DI seam**: `VisionOCRService` / `ShiftLabelMapper` などプロトコル境界化し、
  ユニットテストで fake を注入する（ROADMAP §9-x の「FoundationModels は実モ
  デル呼び出しを CI でしない」を満たす）。
- **PR 分割案**:
  1. `feature/p2-alpha-pattern-detector`（リスク最小）
  2. `feature/p2-beta-vacation-rotation`（スキーマ migration あり）
  3. `feature/p2-gamma-image-import`（最大だが他から疎結合）

---

## 4. テスト設計詳細

ROADMAP §9 punch list は「何をテストするか」を列挙している。本節は
**fixture・入力・期待値・DI seam** までを固定し、実装者（人間 or エージェント）
が機械的にテストを書けるようにする。各小節は punch list ID と 1:1 対応。

### 4.1 共通スキャフォールディング (α / β / γ)

- **決定論的 Calendar**: 全テストで
  `Calendar(identifier: .gregorian)` + `timeZone = TimeZone(identifier:
  "Asia/Tokyo")!` + `firstWeekday = 2` (Monday)。
  日付ヘルパ: `func date(_ y: Int, _ m: Int, _ d: Int) -> Date`。
- **凍結 today**: "today" を読むアルゴリズムは全てパラメータ化。テストは
  `today = date(2026, 5, 18)` で固定。
- **UUID ヘルパ**: 固定 UUID を `static let` で。例:
  `let dayPresetID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!`
- **Snapshot builder**: `Tests/Support/SnapshotFactory.swift` に
  `presetSnapshot(id:, name:, alarmHour:)` / `rotationSnapshot(...)` /
  `vacationSnapshot(...)` / `dayAssignmentSnapshot(...)` を置く。テストター
  ゲット限定、プロダクション側へは出さない。
- **In-memory ModelContainer**: 統合テストは
  `ModelConfiguration(isStoredInMemoryOnly: true)` の `ModelContainer` を使う。

### 4.2 P2-α — `ShiftPatternDetectorTests`

#### 4.2.1 Fixture ヘルパ

| ヘルパ | 定義 |
|---|---|
| `historyAlternateWeeks(start: Date, weeks: Int)` | `weeks * 7` 日分。1 週目は全 `dayPresetID`、2 週目は全 `nightPresetID`、以降交互。 |
| `historyDailyAlternate(start: Date, days: Int)` | 日単位 D/N/D/N... |
| `history22DayPattern(start: Date, cycles: Int)` | ROADMAP §4.P2-α 引用の 22 日列 `[D,D,off,off,N,N,off,off,D,D,D,D,off,off,off,off,D,D,D,D,off,off]` × `cycles`。 |
| `historyWithNoise(base:, errorEvery:)` | ベース列の N 日ごとに別 preset へ差し替え。 |
| `historyWithGaps(base:, keepRatio:)` | ランダム（seed 固定）に間引いてワイルドカード混入。 |

#### 4.2.2 テスト入力と期待値

| # | Setup | `today` | 期待値 |
|---|---|---|---|
| α-U1 | `manualAssignments = [:]` | `2026-05-18` | `detect() == nil` |
| α-U2 | `historyAlternateWeeks(start: 2026-05-11, weeks: 1)` (7 日) | `2026-05-18` | `nil` (`minCycles=2` 未満) |
| α-U3 | `historyAlternateWeeks(start: 2026-05-04, weeks: 2)` | `2026-05-18` | `cycleLength == 14`, `confidence == 1.0`, slots は `[D×7, N×7]` を月曜アンカーに回転 |
| α-U4 | `historyDailyAlternate(start: 2026-05-04, days: 14)` | `2026-05-18` | `cycleLength == 2`, `slots == [dayID, nightID]` |
| α-U5 | `history22DayPattern(start: 2026-04-06, cycles: 2)` (44 日) | `2026-05-18` | `cycleLength == 22`, slots は基準 22 日列と一致 |
| α-U6 | `historyWithNoise(base: alternateWeeks×2, errorEvery: 3)` | `2026-05-18` | `nil` (match rate < 0.85) |
| α-U7 | α-U6 と同入力 + `Configuration(minMatchRate: 0.5)` | `2026-05-18` | 非 nil（閾値ゲートを実証） |
| α-U8 | `dayPresetID`, `nightPresetID`, `eveningPresetID` の 3 UUID パターン | `2026-05-18` | スロット UUID 順序が保たれる（reラベル無し） |
| α-U9 | `DayAssignmentSnapshot(presetID: nil, skipAlarm: true)` を off 日に持つ履歴 | `2026-05-18` | slots に `nil` (`.off`) が正しい位置で含まれる |
| α-U10 | `manualAssignments` は空。`rotations` 配列にはパターンあり。 | `2026-05-18` | `nil` — 検出器は `manualAssignments` しか読まない（関数シグネチャに `rotations` を渡さない事も assert） |
| α-U11 | 履歴が 89/90/91 日前まで存在、パターンは 88–90 日目にのみ可視 | `2026-05-18` | `windowDays=90`: 89 → detect、90 → detect、91 → nil。3 ケースをパラメータ化。 |
| α-U12 | 28 日週次交互、開始が水曜 (`2026-05-06`) | `2026-05-18` | `anchorDate` は窓開始以前の最寄月曜、slots は index 0 が月曜に揃う。`Calendar.component(.weekday, from: anchorDate) == 2`。 |

#### 4.2.3 統合スイート (`PatternSuggestionFlowTests`)

- α-I1 / α-I2: in-memory `ModelContainer` を組み、28 日交互の `DayAssignment`
  をシード。`RotationListView` を `ViewInspector` か `@testable` ViewModel
  で立ち上げ、`viewModel.suggestion != nil` を assert。Accept で
  `RotationPattern` の件数が 1 増えることを assert。
- α-I3: Accept 後に `await AlarmScheduler.refreshScheduledAlarms()`。
  以後 30 日分の `ShiftAlarm` 行が登録されていることを assert。
- α-I4 / α-I5: Reject で
  `AppSettings.patternSuggestionSnoozedUntil == now + 30 days ± 1 minute`、
  `patternSuggestionSnoozedFingerprint == suggestion.fingerprint`。
  同一履歴での再検出は同じ fingerprint を返すが、ViewModel 側の
  `displayedSuggestion` は `nil`。1 件編集して fingerprint を変えるとスヌーズ
  を迂回することも検証。
- α-I6: `AppSettings.hasOnboarded = false` + サンプル履歴シード → Onboarding
  の「サンプル履歴から提案」分岐を歩き、メインタブ着地前に提案が出ることを
  assert。

### 4.3 P2-β — `VacationAwareRotationTests`

#### 4.3.1 ベースラインパターン (β-U1…β-U13)

```
anchor:  2026-05-04 (Monday)
cycle:   14
slots:   [day, day, day, day, day, day, day,
          night, night, night, night, night, night, night]
```

Day preset の `defaultAlarmHour = 6`、Night preset の `defaultAlarmHour = 17`。
`dayStartSlotIndex` は nil（自動導出で 0）。

#### 4.3.2 テストケース

| # | Vacation set | 問合せ日付 | Policy | 期待スロット |
|---|---|---|---|---|
| β-U1 | `[]` | `2026-05-25` (anchor + 21) | n/a | `night` (基底 expander と同一) |
| β-U2 | `[VP(8-13 → 8-16, 4 日)]`; 8-12 は `night` | `2026-08-17` | `.invert` | `day` |
| β-U3 | 同連休だが anchor を調整して 8-12 が `day` になる構成 | `2026-08-17` | `.invert` | `night` |
| β-U4 | β-U2 構成 | `2026-08-17` | `.continue` | `night`（位相継続） |
| β-U5 | β-U2 構成 + `dayStartSlotIndex = 0` | `2026-08-17` | `.resetToDay` | `day`（slot 0） |
| β-U6 | `[VP(8-13 → 8-16)]` | `2026-08-14`（連休内） | any | `nil` |
| β-U7 | `[VP(8-13 → 8-14, 2 日)]` — 短すぎる | n/a | n/a | `VacationPeriod.init` または validator が `VacationError.tooShort` を投げる |
| β-U8 | 3 日連続の `HolidayOverride` 行のみ。`isVacationGroup=false` で `VacationPeriod` 行は無し | `2026-08-17` | n/a | 基底 expander と同一（フラグは resolver に効かない） |
| β-U9 | `[VP(GW 5-3 → 5-6), VP(Obon 8-13 → 8-16)]` | `2026-08-17` | `.invert` × 2 | 累積 `L/2 + L/2 = L → 0`、結果は `.continue` と一致 |
| β-U10 | β-U2 構成 + 連休内に `DayAssignment(date: 8-15, preset: day)` | `2026-08-15` | n/a | `ResolvedDay.manual(presetID: day, …)`（手動が連休より優先）— `DayResolver` レベルで検証 |
| β-U11 | 低優先 14-day pattern + 高優先 7-day all-`day` pattern | `2026-08-17` | 低優先側 `.invert` | 高優先 pattern の `day`（優先度連鎖は不変） |
| β-U12 | `VP(2026-04-29 → 2026-05-08)`（10 日、月またぎ） | `2026-05-09` | `.invert` | 連続 1 つの連休として扱われ二重シフトしない |
| β-U13 | `VP(2026-12-30 → 2027-01-03)` | `2027-01-04` | `.invert` | 年境界も `Calendar.dateComponents([.day], from: a, to: b)` で正しく扱われる |

#### 4.3.3 Pattern + Preset override（β-U14/U15/U16）

ROADMAP §9 にはまだ無い拡張テスト。`VacationAwareRotationTests` に追加。

| # | Pattern policy | 連休前 preset の policy | 期待 |
|---|---|---|---|
| β-U14 | `.invert` | nil | pattern 優先 → `.invert` |
| β-U15 | `.invert` | `.continue` | preset 優先 → `.continue` |
| β-U16 | `.continue` | `.resetToDay` | preset 優先 → `.resetToDay` |

#### 4.3.4 スキーマ migration (`SchemaV1MigrationTests`)

- β-S1: コードで SchemaV1 の `ModelContainer` を組み、`RotationPattern` /
  `ShiftPreset` 各 1 行を入れて close。SchemaV2 + `MigrationPlan` で再 open。
  読み戻して `crossVacationPolicy == .invert`（pattern）、`nil`（preset）を
  assert。
- β-S2: 同様に `HolidayOverride` 3 行をシード → migration 後にも 3 行残り、
  全行 `isVacationGroup == false`。
- β-S3: migration 後の `VacationPeriod` 件数 = 0（自動グルーピング無し）。

実装メモ: `SchemaMigrationPlan` は in-memory store では発火しない。
`URL(fileURLWithPath: NSTemporaryDirectory()).appending(component: UUID
().uuidString + ".store")` で一時ファイルを使い、`tearDown` で削除する。

#### 4.3.5 統合（`AlarmSchedulerTests` 拡張）

- β-I1: in-memory container にベースライン pattern + 日 30–34 連休をシード。
  `refreshScheduledAlarms()`。`ShiftAlarm` 行を読み、日 30–34 に `.main` が
  存在しないこと。
- β-I2: 日 35 のアラーム時刻が day preset の `defaultAlarmTime` と一致
  （`.invert` で night → day になっていること）。
- β-I3: `DayResolver.resolve(date: day35, input:)` →
  `ResolvedDay.rotation(presetID: dayID, …)`。

### 4.4 P2-γ — 画像インポートテスト

Vision と FoundationModels は CI のユニットフェーズで動かさない。下記は
`VisionOCRService` / `ShiftLabelMapper` プロトコルでモックする。**1 ターゲット
のみ**、`Tests/Fixtures/ShiftImages/*Smoke*` が
`XCTSkipIf(ProcessInfo.processInfo.environment["VISION_E2E"] == nil)` で
gate された実 Vision を走らせる。

#### 4.4.1 モック実装（テストターゲット内）

```swift
struct StubOCR: VisionOCRService {
    var observations: [OCRObservation]
    func recognize(image: CGImage) async throws -> [OCRObservation] { observations }
}

struct StubMapper: ShiftLabelMapper {
    var responses: [String: MapResult]
    func map(labels: [String], existingPresets: [ShiftPresetSnapshot]) async -> [String: MapResult] {
        Dictionary(uniqueKeysWithValues: labels.map { ($0, responses[$0] ?? .unresolved(reason: "stub")) })
    }
}
```

加えて、`setUp` で `URLSessionConfiguration.default.protocolClasses` に
`NetworkBlockingURLProtocol` を入れ、`tearDown` で観測リクエスト数 = 0 を
assert（γ-U12）。

#### 4.4.2 OCR テスト (`ShiftImageOCRTests`)

| # | 戦略 |
|---|---|
| γ-U1 / γ-U2 | 実 Vision 起動。サンプル画像 1 枚で観測数 ≥ N を assert。`VISION_E2E` gate（CI では skip）。 |
| γ-U3 | 回転リトライ制御のユニットテスト: 1 回目は傾いた観測、2 回目は正常を返すスタブを注入し、呼出回数が正確に 2 になることを assert。回転処理自体は `func rotate(_ image: CGImage, by: CGFloat) -> CGImage` シームで diff 可能化。 |
| γ-U4 | StubOCR `[]` → パーサが空 `RosterGrid` を返し throw しないこと。 |

#### 4.4.3 Parser テスト (`ShiftImageParserTests`)

`[OCRObservation]` を直接組んで使う。画像は不要。

| # | 観測レイアウト | 期待 |
|---|---|---|
| γ-U5 | 列ヘッダ 7 個 (1..7) を y=0.05 行に、従業員名 1 個を x=0.05 列に、本体 7 セル | `RosterGrid.dateAxis == .columns`、日付 7、従業員 1 |
| γ-U6 | テストシーム `useDocumentRequest = false` で γ-U5 と同入力 | 同出力（fallback 経路） |
| γ-U7 | セル文字列 `["昼", "夜", "休", "D", "N"]`。StubMapper が想定 preset を返す | `bundle.assignments[i].presetID` がラベル表どおり |
| γ-U8 | セル `"???"` + StubMapper が `.unresolved` | bundle に含めず、`unresolvedCells: [(date, text)]` で返す |
| γ-U9 | 2 ページ（page1 `(2026, 7)`, page2 `(2026, 8)`）を逆順入力 | マージ後は日付昇順、重複なし |
| γ-U10 | 3 従業員グリッド + `AppSettings.userNameOnRoster = "山田"` | `bundle.assignments.count == datesInGrid.count`（"山田" 行のみ） |
| γ-U11 | 30 セル中 4 セル欠損 | `bundle.assignments.count == 26`、crash 無し |
| γ-U12 | パイプラインを `NetworkBlockingURLProtocol` 付きで走らせ、`requestCount == 0` |

#### 4.4.4 Mapper テスト (`FoundationModelsShiftMapperTests`)

| # | Setup |
|---|---|
| γ-U13 | `LanguageModelAvailability.isAvailable = false`（DI シーム）。`map(["昼","??"], …)`。期待: `"昼"` はルールベース、`"??"` は `.unresolved(reason: "model_unavailable")` |
| γ-U14 | モック LLM `{"夜勤": {kind:"existing", presetID: nightID, confidence: 0.9}}`。期待: `.existingPreset(nightID, 0.9)` |
| γ-U15 | モック LLM `confidence: 0.5`。期待: `.unresolved(reason: "low_confidence")` |
| γ-U16 | 既存 preset `[{name:"早番"}, {name:"日勤"}]`。セル `"早"`。Pass A の substring 一致が "早番" にヒット。期待: `.existingPreset(早番.id, ≥0.9)`（汎用「昼」ルールより既存名一致を優先） |

#### 4.4.5 統合 (`ImageImportIntegrationTests`)

- γ-I1: StubOCR + StubMapper で全パイプラインを走らせ、生成 `ShiftBundle` を
  `ShareImporter.preview(bundle: container:)` に渡す（無改変）。
  `ImportPreview` の `addedAssignments` が期待数。
- γ-I2: `ShareImporter.apply(bundle: container:)`。`ModelContext` から
  `DayAssignment` 行を読んで日付ごとの存在 + `preset` リンクを assert。
- γ-I3: 事前に `DayAssignment(date: D, preset: nightID, skipAlarm: false,
  note: "manual")` をシード。同 `D` を `dayID` に書き換える bundle を import。
  再 query: `preset == dayID` だが `note == "manual"` は保たれる（field-merge
  挙動を確認。whole-row 置換ならば follow-up issue 化）。ROADMAP の
  「既存の手動上書きは破壊されない」を最低限担保: `add` ではなく `update`。
- γ-I4: 同 bundle を 2 回 apply。行数不変、2 回目の preview で
  `updatedAssignments == 0`。

#### 4.4.6 精度 DoD (`Tests/Fixtures/ShiftImages/`)

- PNG fixture 2 枚（ROADMAP §9-x の 1 ファイル 500 KB 以内）:
  `ja_monthly_30.png`、`en_monthly_30.png`。各 JSON サイドカー
  `ja_monthly_30.expected.json` = `{"cells":[{"day":1,"label":"昼"}…]}`。
- Smoke ゲート `AccuracyDoDTests`（`VISION_E2E=1` 以外で skip）:
  - 実 Vision パイプラインを実行。
  - 抽出ラベルと expected を日付でジョイン。
  - `matchedCells / expectedCells ≥ 0.80`（γ-D1, γ-D2）。
  - γ-D3 用に `ja_multirow.png` + `expected.json`（`target: "山田"`）。20 回
    実行で 95% 以上、ピッカー選択が target に一致（実運用では 1 発で決定論的、
    95% は CI 上の OCR 揺らぎ吸収用）。

### 4.5 何をテストしないか

- **CI 上での実 `FoundationModels` / `Vision` 呼出**: ROADMAP §9-x のルール。
  精度 DoD は `VISION_E2E=1` でローカル/ナイトリーのみ。
- **CloudKit 経由の SwiftData migration**: 対象外（ROADMAP §4 スコープ外）。
- **新提案カード / 画像 importer の UI スナップショット**: P3-2 の領域。

### 4.6 テスト実行マップ

| トリガ | 走るもの |
|---|---|
| `bash scripts/verify.sh`（CI 既定） | α / β / γ の unit + integration（モック使用）。現状 56 件に対し ~40 件追加見込み。**2026-05-27 取り込みでさらに AS / SBV / DIAG / DRIFT / DOW / VAC / IMG 系（~50 件）追加見込み。** |
| `SNAPSHOT_TESTING_ENABLED=1 bash scripts/verify.sh` | + 既存スナップショット 5 件 + `ChangePreviewSnapshotTests` 系（§P1-6）。 |
| `VISION_E2E=1 bash scripts/verify.sh` | + γ-U1/U2 smoke + 精度 DoD (γ-D1/D2/D3)。ローカル運用。 |

**2026-05-27 取り込みで追加されるテスト ID 群**（ROADMAP §9-α / §9-β / §9-γ /
§P0-4 / §P0-5 / §P1-5 末尾参照）:

- **AS-U1〜U9 / AS-I1**: AlarmScheduler fake 注入（§P0-4）。U9 は §7.1 step 4
  の save-failure rollback（save throw 時に新 ID を cancel して orphan を防ぐ）。
- **SBV-U1〜U11 / SBV-I1〜I2**: `.shiftalarm` バリデーション（§P0-5）。U7 は
  `skipAlarm` 真偽別 / U9・U10 は assignment override hour・minute 範囲 /
  U11 は duplicate date error 昇格 / 加えて patterns[].slots[] の missing
  preset 参照 と patterns / overrides 件数上限を `tooManyItems` の path 形式
  で網羅すること。
- **DIAG-U1〜U6 / DIAG-I1〜I2**: アラーム診断（§P1-5）。U6 は saved
  `current_alarm_kit_id` non-nil だが `alarmClient.scheduledIDs()` に含まれない
  ケースを critical 判定。
- **DRIFT-U1〜U5 / DRIFT-I1〜I3**: A1 ドリフト UI 統合
- **DOW-U1〜U5 / DOW-I1〜I3**: A2 DOW ルール検出
- **VAC-U1〜U10 / VAC-I1〜I2**: P2-β 連休越境ローテーション。U9 は UI 入力検証 /
  U10 は domain factory 側で 3 日未満 reject（`VacationPeriodError.tooShort`）。
- **IMG-U1〜U5 / IMG-I1〜I3 / IMG-S1〜S2**: P2-γ Phase 1 画像インポート

3 段階の gating で CI は速度と決定論を保ちつつ、DoD の精度測定はオンデマンドで
可能にする。

---

## 5. P2-δ — シフトスワップ

ROADMAP §4 P2-δ に対応。同僚との勤務交換を 1 操作で記録し、**スワップした日でも
正しいシフトのアラームが鳴る** ことを保証する。

### 5.1 データモデル追加（Schema V3）

**新規 @Model `SwapRecord`**（`Sources/Domain/Models/SwapRecord.swift`）:

```swift
@Model public final class SwapRecord {
    @Attribute(.unique) public var id: UUID
    public var date: Date              // startOfDay 正規化
    public var kindRaw: Int            // 0=.covered, 1=.covering, 2=.exchange
    public var counterpartyLabel: String
    public var note: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        date: Date,
        kind: SwapKind,
        counterpartyLabel: String,
        note: String = "",
        createdAt: Date = Date()
    )
}

public enum SwapKind: Int, Codable, Sendable, CaseIterable {
    case covered = 0      // 自分が休む（同僚が代わってくれた）
    case covering = 1     // 自分が出る（同僚の代わりに出勤）
    case exchange = 2     // 双方向（v2 検討）
}
```

`date` は `calendar.startOfDay(for:)` 正規化。`@Relationship` は持たず、
`DayAssignment` とは独立に存在する（書き戻し負荷最小化のため）。

### 5.2 スキーマ migration（V2 → V3）

- `SwapRecord` 追加のみ。SwiftData lightweight migration で吸収。
- 新規 `Sources/Domain/Persistence/SchemaV3.swift` + 既存 `MigrationPlan` 拡張:
  - `SchemaV3.versionIdentifier = Schema.Version(3, 0, 0)`
  - `SchemaMigrationPlan.stages += [.lightweight(from: V2, to: V3)]`
- 既存 `DayAssignment` / `RotationPattern` / `VacationPeriod` / `ShiftPreset` /
  `HolidayOverride` / `AppSettings` は **非破壊** (δ-S1)。
- migration 直後 `SwapRecord.count == 0` (δ-S2)。

### 5.3 操作フロー

`DayDetailEditorView` に「シフト交代」ボタンを追加し、以下のハンドラを実装:

```
入力: (date, kind, counterpartyLabel, optionalPresetID)
処理:
  1. DayAssignment を upsert:
     - .covered: presetID = nil, skipAlarm = true
     - .covering: presetID = optionalPresetID (必須), skipAlarm = false
     - .exchange: 2 つの date を順次処理（v2）
  2. SwapRecord を insert (date, kind, counterpartyLabel, note)
  3. await AlarmScheduler.refreshScheduledAlarms()
```

**重要:** `DayResolver` / `AlarmScheduler` は **完全に無改変**。
手動 `DayAssignment` がローテーション / 連休 / 祝日に勝つ既存の優先順位
（PR #5 で確立、`docs/p2-algorithms.md` §2.4 で再確認済み）が
そのまま機能するため、スワップ専用の resolver 拡張は不要。

### 5.4 過去日 / 削除セマンティクス

- 過去日でも `SwapRecord` は作成可（履歴目的）。`AlarmScheduler` の
  `lookaheadDays` 範囲外は登録対象外、これは既存ロジックそのまま (δ-U4)。
- `SwapRecord` 削除では `DayAssignment` の値は元に戻さない (δ-U5)。
  「スワップを取り消す」UI は v2 検討。

### 5.5 UI バッジ

- `DayResolverInputBuilder` に `swapRecords: [SwapRecordSnapshot]` を追加
  （ただし `DayResolver` 内部では使わず、UI レイヤから参照する）。
- `DayCellView` で `swapRecords[date] != nil` なら「↔」アイコンを描画。
- VoiceOver: `"\(presetName), シフト交代済み"`。

### 5.6 テスト対応

| ROADMAP test | アルゴリズム上の根拠 |
|---|---|
| δ-U1 | §5.3 step 1 `.covered` 分岐 |
| δ-U2 | §5.3 step 1 `.covering` 分岐 |
| δ-U3 | §5.1 全フィールドの read/write 往復 |
| δ-U4 | §5.4（過去日は記録のみ、AlarmKit 登録は既存 lookahead でカット） |
| δ-U5 | §5.4 削除セマンティクス |
| δ-S1 | §5.2 lightweight migration の非破壊性 |
| δ-S2 | §5.2 自動 insert 無し |
| δ-I1 | §5.3 step 3 → AlarmScheduler diff-sync で `.covering` 日に登録 |
| δ-I2 | §5.3 step 1 `.covered` → `skipAlarm = true` → diff-sync で削除 |
| δ-I3 | DayResolver 無改変なので他日には影響しない |

### 5.7 PR 分割案

1. `feature/p2-delta-schema-v3` — `SwapRecord` 追加 + V3 migration + migration テスト。
2. `feature/p2-delta-day-editor` — DayDetailEditorView 操作 + AlarmScheduler 統合テスト。
3. `feature/p2-delta-badge` — `DayCellView` バッジ + a11y。

---

## 6. P2-η — .ics エクスポート

ROADMAP §4 P2-η に対応。月単位の確定シフトを iCalendar 形式で書き出し、家族が
標準 Calendar アプリで読める形で共有する。

### 6.1 入力

- `range: ClosedRange<Date>`（`startOfDay` ベース、最大 12 ヶ月）
- `resolvedDays: [ResolvedDay]`（`DayResolver` を range 全日に走らせた結果）
- `presets: [UUID: ShiftPresetSnapshot]`
- `calendar: Calendar`
- `timeZone: TimeZone = calendar.timeZone`

`AlarmScheduler` の diff-sync 経路と独立に動く、純粋関数。

### 6.2 出力フォーマット

RFC 5545 準拠の iCalendar。v1 では **UTC（Z 形式）** で時刻を出力し、
`VTIMEZONE` ブロックを省略する。これは TZID 参照（`DTSTART;TZID=...`）に対する
VTIMEZONE 同梱が RFC 5545 §3.6.5 で要求される一方、IANA 名のみで動かす Apple Calendar
以外（特に Outlook）でずれが出るのを避けるため。`Asia/Tokyo` 6:00 のシフトは
`20260519T210000Z` として出力され、受信側のローカル TZ で正しくレンダされる。

```
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//ShiftAlarm//ja//EN
CALSCALE:GREGORIAN
X-WR-CALNAME:ShiftAlarm Export
X-WR-TIMEZONE:Asia/Tokyo
BEGIN:VEVENT
UID:<deterministic>@shiftalarm.local
DTSTAMP:20260518T120000Z
DTSTART:20260519T210000Z
DTEND:20260519T213000Z
SUMMARY:昼勤
END:VEVENT
...
END:VCALENDAR
```

**規則:**

- 改行は **CRLF** 固定（`\r\n`）。
- content line は UTF-8 octet 数で 75 octets 以下に fold する。継続行は 1 文字目を
  whitespace prefix にする（RFC 5545 §3.1）。
- `SUMMARY` のエスケープ（RFC 5545 §3.3.11）:
  - `\` → `\\`
  - `,` → `\,`
  - `;` → `\;`
  - 改行 → `\n`
- `UID` は決定論的: `sha256("\(yyyy-MM-dd)|\(presetID.uuidString)")@shiftalarm.local`。
  同入力で再エクスポートしても同 UID → 受け取り側で購読更新が安定 (η-U6)。
- `DTEND = DTSTART + 30 分` の固定長ダミー区間。
- `DTSTAMP`、`DTSTART`、`DTEND` はすべて **UTC**（末尾 `Z`）。テストでは DI で固定。
- `X-WR-TIMEZONE` は **情報ヘッダのみ**（受信側がプロパティ非対応でも害は無い）。
  iCal セマンティクスとしては UTC 時刻が正。

### 6.3 イベント化対象

| 条件 | イベント化 |
|---|---|
| `resolved.preset != nil && skipAlarm == false && !inVacationPeriod` | する |
| `skipAlarm == true` | しない (η-U4) |
| 連休範囲内 (`VacationPeriod` でカバー) | しない (η-U5) |
| preset 削除済み | しない（preset 名が解決できないため） |
| 過去日 (`< today`) | する（履歴としても残せる） |

### 6.4 タイムゾーン

- ローカル時刻 → UTC 変換に `calendar.timeZone`（既定: `Calendar.current.timeZone`）を
  使う。例えば `Asia/Tokyo` の `2026-05-20 06:00` は `20260519T210000Z` に変換される。
- `X-WR-TIMEZONE` は **エクスポート時のユーザ TZ 識別子**（情報ヘッダ）。受信側で
  非対応でも `DTSTART` の UTC が正なので時刻ズレなし。
- `VTIMEZONE` ブロックは v1 では出力しない。代わりに UTC で出すため、Apple Calendar /
  Google Calendar / Outlook 全てで同じ瞬間時刻が表示される（DoD と整合）。
- v2 で「ローカル時刻 + VTIMEZONE」方式へ切り替える場合は、IANA TZ → RFC 5545
  `VTIMEZONE`（`STANDARD` / `DAYLIGHT` + `RRULE`）の自動生成が必要。バックログ。

### 6.5 ネットワークガード

- `ICSExporter` は **`URLSession` を生成しない**（γ と同じ規約）。
- テストでは `URLSessionConfiguration.default.protocolClasses` に
  `NetworkBlockingURLProtocol` を入れ、エクスポート中の `requestCount == 0`
  を assert (η-U8)。

### 6.6 API シグネチャ案

```swift
public protocol ICalendarExporting: Sendable {
    func export(
        range: ClosedRange<Date>,
        resolvedDays: [ResolvedDay],
        presets: [UUID: ShiftPresetSnapshot],
        calendar: Calendar,
        timeZone: TimeZone,
        now: Date
    ) -> String
}

public struct ICSExporter: ICalendarExporting { ... }
```

ファイル書込みは別レイヤ:

```swift
extension ICSExporter {
    public func write(
        text: String,
        toTemporaryFileNamed filename: String
    ) throws -> URL
}
```

`ICSExportView` で `URL` を取得し、`ShareLink` に渡す。

### 6.7 個人情報フィルタ

- `SwapRecord.counterpartyLabel`、`DayAssignment.note` は **出力に含めない**。
- preset 名（`昼勤` / `夜勤` 等）と時刻のみ。
- export ファイル名は `ShiftAlarm-YYYY-MM.ics`。

### 6.8 テスト対応

| ROADMAP test | アルゴリズム上の根拠 |
|---|---|
| η-U1 | range 内出勤 0 件 → `VCALENDAR` のみ、`VEVENT` 0 |
| η-U2 | 固定入力で行ごとに固定アサート（CRLF + 必須プロパティ） |
| η-U3 | §6.2 エスケープ規則 |
| η-U4 / η-U5 | §6.3 フィルタ |
| η-U6 | §6.2 UID 決定論性（sha256 が同入力で同値） |
| η-U7 | §6.4 UTC 変換: `Asia/Tokyo 06:00` → `20260519T210000Z` を行アサート。`X-WR-TIMEZONE` が `calendar.timeZone.identifier` と一致 |
| η-U8 | §6.5 ネットワークガード |
| η-U9 | range の `startOfDay` 昇順で resolvedDays を辿るため自然に昇順 |
| η-I1 | in-memory `ModelContainer` シード → `DayResolver` → `ICSExporter.export` |
| η-I2 | 出力文字列をテスト内パーサで再パース（後述 §6.8.1）し、`VEVENT` 件数 / `SUMMARY` / UTC `DTSTART` を assert。EventKit には ICS ファイル取込 API が無いため、ファイルレベルのアサートで代替 |

#### 6.8.1 テスト用 ICS パーサ（η-I2 用）

EventKit には ICS ファイルを直接取り込む公開 API が存在しない
（`EKEventStore` は `EKEvent` を生成 / 永続化はできても外部 `.ics` を読まない）。
そのため η-I2 はテストターゲット内に **最小 iCalendar パーサ** を置いて検証する:

```swift
struct ParsedICSEvent: Equatable {
    let uid: String
    let summary: String
    let dtstart: Date  // UTC
    let dtend: Date    // UTC
}

enum ICSTestParser {
    static func parse(_ text: String) throws -> [ParsedICSEvent]
}
```

- 行は `\r\n` 区切り。
- `BEGIN:VEVENT` / `END:VEVENT` で区切る。
- 各イベント内で `UID:`、`SUMMARY:`、`DTSTART:`、`DTEND:` をプリフィックス比較で
  抽出（`TZID=` 付きは v1 では出ない前提）。
- `DTSTART:20260519T210000Z` を ISO8601 で `Date` にパース。
- `SUMMARY` のエスケープ復号（`\\` / `\,` / `\;` / `\n`）も実装。
- 想定 30 行以下の小実装。テストターゲット限定で `Tests/Support/ICSTestParser.swift`
  に置く（プロダクション側へは出さない）。

別案: 既存の **`EventKit.EKCalendar` を経由した実機経路**（カレンダー App に
共有シートで読ませる）は CI で動かせないため、p0-3 ゴールデンパス（手動 / 実機）
として残す。η-I2 はあくまでパース整合性の単体性検証に絞る。

### 6.9 PR 分割案

1. `feature/p2-eta-ics-exporter` — 純ロジック + ユニットテスト。
2. `feature/p2-eta-ics-share-ui` — `ICSExportView` + 共有シート + 統合テスト。

---

## 7. 横断: ChangePreview 抽象 / アラーム診断 / `.shiftalarm` validator

2026-05-27 仕様提案書取り込みで追加された **横断的なデータモデル / プロトコル**
を本章にまとめる。これらは P0-4 / P0-5 / P1-5 / P1-6（および P1 追補 A1）の
複数タスクで参照されるため、各タスク説明から重複を避けて当章を参照する。

### 7.1 `AlarmSchedulingClient` protocol（P0-4）

`AlarmScheduler` の diff-sync を fake で検証可能にするための protocol 境界。
具体 actor `AlarmService` は `AlarmManager.shared` を直叩きするため fake 化でき
ないので、間に protocol を挟む。

```swift
public enum ScheduledAlarmKind: Sendable {
    case main
    case bedtime
}

public protocol AlarmSchedulingClient: Sendable {
    func schedule(
        id: UUID,
        fireDate: Date,
        label: String,
        soundID: String,
        kind: ScheduledAlarmKind
    ) async throws -> UUID

    func cancel(id: UUID) async throws

    /// AlarmKit に現在登録済みのアラーム ID 集合を返す。診断 (§P1-5) と
    /// orphan 検出に使う。テスト用 fake では in-memory 集合を返す。
    func scheduledIDs() async throws -> Set<UUID>

    /// AlarmKit 認可状態。`AlarmService` は `AlarmManager.shared.authorizationState`
    /// を直接呼ぶが、fake は任意の状態（`.authorized` / `.denied` /
    /// `.notDetermined`）を返せること。§P1-5 DIAG-U1（未許可時 critical）が
    /// `AlarmManager.shared` に触れずに決定論的にテストできる。
    func authorizationState() async -> AlarmAuthorizationState
}

extension AlarmService: AlarmSchedulingClient {}
```

**同期順序の保証**（schedule 失敗時に旧アラーム消失 / cancel 失敗時に
orphan 化を防ぐ）:

1. 新しいアラームを `schedule`（失敗時はここで例外、DB 旧 row は無傷）
2. DB の `current_alarm_kit_id` を新 ID に書き換える **前に**、置換対象の旧 ID を
   `pending_cancel_alarm_kit_ids: [UUID]` に append する
3. `current_alarm_kit_id` を新 ID に更新
4. **`modelContext.save()` を必ずここで実行**（旧 ID が pending に退避された
   状態をディスク永続化。プロセスが落ちても新旧 ID 両方が DB に残るよう保証する）。
   **save が throw した場合のロールバック**: 新 ID は AlarmKit 上に登録済みだが
   DB のどこにも記録されていない orphan 状態になる。`save()` 失敗を catch して
   **直前に schedule した新 ID を `alarmClient.cancel(newID)` で取り消してから**
   上位に例外を rethrow する。cancel 自体が失敗した場合は構造化ログに `newID`
   と両方の例外を残し、次回 `refreshScheduledAlarms` 起動時に
   `alarmClient.scheduledIDs()` と DB の `current_alarm_kit_id`（古い値のまま）
   を突き合わせて orphan を検出・cancel する。pending-cancel loop には絶対に
   入らない（旧 ID は cancel されていない＝安全、新 ID は cancel 済み or
   orphan）。AS-U4 は schedule 失敗、加えて **AS-U9 save-failure rollback** を
   テスト ID として追加する。
5. `pending_cancel_alarm_kit_ids` の各 ID を順次 `cancel` 試行
6. **cancel が成功した ID のみ** `pending_cancel_alarm_kit_ids` から除去
   （除去結果もその場で `save()` で永続化）
7. 残った ID は次回 `refreshScheduledAlarms` 実行時に再試行する

**ポイント**: 旧 ID を「pending」リストに退避してから新 ID で上書きするため、
cancel が失敗しても旧 AlarmKit エントリの参照が DB 側に残り続ける。これにより
「新規 schedule 成功 → cancel 失敗で旧アラームが孤児化して鳴り続ける」事故を
防げる。`refreshScheduledAlarms` の冪等性も保たれる。step 4 の save を省略すると
「schedule 成功 → cancel 成功 → プロセス kill で save 未到達 → 起動後に旧 ID 
を再 cancel しようとして旧アラームが存在しないというエッジケース」が現れる
ため、cancel ループに入る前の save は仕様上必須。

**`ShiftAlarm` モデルへの追加**: bedtime リマインダは独立した `@Model` ではなく
`ShiftAlarm` の `isBedtimeReminder` フラグ付き行として保存されているため、追加
する列は **`ShiftAlarm` 一箇所のみ**:

- `current_alarm_kit_id: UUID?` — 既存 `alarmKitID` プロパティを rename。SwiftData
  には **`@Attribute(originalName: "alarmKitID")` を必ず付与**して、既存ストア
  内の値を新カラムに引き継ぐ。これを忘れると lightweight migration は新カラム
  を空で作り直し、アップグレード時に登録済み AlarmKit ID への参照を全行で失う
  （cancel 不可・診断画面の saved-ID 判定が常に「未登録」になる回帰）。
- `pendingCancelData: Data` — 新規列。SwiftData の `[UUID]` 直接サポートは
  バージョン依存で App / Widget 共有ストアでの安全性が不確実なため、**既存
  `RotationPattern.slotsData` と同じ JSON 化方針** で永続化する。具体的には
  `JSONEncoder().encode([UUID])` の結果を `Data` として持ち、API 側は computed
  `pendingCancelIDs: [UUID]` を経由して読み書きする（getter は decode、setter
  は encode → `pendingCancelData` 代入）。既存 row はマイグレーション時に空
  array を JSON 化した `Data` で初期化。本文中の "`pending_cancel_alarm_kit_ids`"
  という呼称は概念名であり、実際の永続列名は `pendingCancelData`、API
  identifier は `pendingCancelIDs` の二段構成になる。

`BedtimeReminder` という独立 @Model は存在しないため、別モデルの追加 / migration
は不要。Widget の SwiftData container も同 schema を読むため、Widget 側ビルドで
新列が解決できることをビルド確認する。

**Swift 6 strict concurrency 上の注意**: `AlarmScheduler` が `@MainActor` の場合、
fake client は `Sendable` actor として実装する。`FakeAlarmSchedulingClient` は
`Tests/Support/` 配下に置き、`operations: [Operation]` と
`scheduledIDs: Set<UUID>` を内部状態として保持する。

### 7.2 `ShiftBundleValidator` モデル（P0-5）

`.shiftalarm` の意味検査層。Codable 後 / preview 前に必ず通す。

```swift
public struct ShiftBundleValidationResult: Equatable, Sendable {
    public var errors: [ShiftBundleValidationIssue]
    public var warnings: [ShiftBundleValidationIssue]
    public var isValid: Bool { errors.isEmpty }
}

public struct ShiftBundleValidationIssue: Identifiable, Equatable, Sendable {
    /// **決定論的 ID**。`"\(code.rawValue)|\(path)"` を `id` の生成入力にして、
    /// 同じ違反が同じ bundle から 2 度抽出されても同一 UUID を返すこと。
    /// P0-5 は preview 直前と apply 直前で validator を 2 回呼ぶ設計のため、
    /// `UUID()` を毎回振ると `Equatable` 比較が false になって SwiftUI の
    /// `ForEach` がプレビュー行を毎回 churn し直し、ユーザの選択が解除される
    /// 回帰が出る。実装案: `UUID(uuidString:)` を `SHA256("\(code)|\(path)")`
    /// の先頭 16 byte で生成、または `Hashable` のみで保持して `id` を
    /// computed property にする。
    public var id: UUID
    public var code: ShiftBundleValidationCode
    public var path: String      // 例: "presets[3].defaultAlarmHour" /
                                 //     "assignments[42].overrideAlarmHour" /
                                 //     "patterns[1].slots[3]"
    public var message: String   // ja / en ローカライズ済み
}

public enum ShiftBundleValidationCode: String, Sendable {
    case unsupportedVersion
    case futureVersion
    case tooManyItems
    case invalidAlarmHour       // preset.defaultAlarmHour と
                                // assignment.overrideAlarmHour の両方で使用
    case invalidAlarmMinute     // preset.defaultAlarmMinute と
                                // assignment.overrideAlarmMinute の両方で使用
    case invalidCycleLength
    case slotCountMismatch
    case duplicateID
    case duplicateDate
    case missingPresetReference
    case textTooLong
    case invalidColorHex
}
```

**`hour` / `minute` 範囲検査は preset と assignment override の両方で必須**。
`ShareImporter` は `AssignmentDTO.overrideAlarmHour` / `overrideAlarmMinute` を
そのまま `DayAssignment` に永続化し、`AlarmScheduler` が fire date 構築に直接
利用するため、これらが `24` や `60` を含むと wrong-day alarm や missing alarm の
原因になる。validator は次の path をすべてカバーする:

- `presets[N].defaultAlarmHour` / `defaultAlarmMinute`（既存）
- `assignments[N].overrideAlarmHour` / `overrideAlarmMinute`（**今回明示的に追加**）
- `assignments[N].bedtimeOverrideMinutes` のような将来追加フィールドも、
  `AlarmScheduler` が時刻として使う限り同じ range 検査を通すこと。

**判定マトリクス**:

| 検査 | 区分 | 動作 |
|---|---|---|
| `version` 対応範囲外 | error | 全体 reject |
| 将来 version | error（初期実装） | 全体 reject |
| `hour ∉ 0..23` / `minute ∉ 0..59` | error | 全体 reject |
| `cycleLength ∉ 1..365` / `slots.count != cycleLength` | error | 全体 reject |
| duplicate UUID | error | 全体 reject |
| 件数上限（preset 100 / assignment 2000） | error | 全体 reject |
| preset 名 ≥ 64 文字 | error | 全体 reject |
| note ≥ 512 文字 | warning | preview に表示、truncate 選択可 |
| missing presetID（`skipAlarm == false`） | error | 全体 reject（manual 行が rotation を黙らせる事故を防ぐ） |
| missing presetID（`skipAlarm == true`） | warning | 該当 assignment を skip 候補に |
| duplicate date | error（P1-6 完了まで） | 全体 reject。P1-6 で conflict resolution UI が用意できたら warning に降格し preview で後勝ち / 先勝ち / スキップを選ばせる |
| 不正 color hex | warning | デフォルト色 |
| unknown fields | ignore | forward compatibility |

**`missingPresetReference` を error に昇格した理由**: `skipAlarm == false` のまま
preset 参照だけが nil になった状態で apply すると、`ShareImporter.applyAssignments`
は `preset = nil` の manual `DayAssignment` を作成する。`DayResolver.resolve` は
manual を holiday / rotation より優先するため fire time を返さず、本来鳴るはず
だったローテーション由来のアラームを **暗黙に黙らせる**。`skipAlarm == true` なら
ユーザの「鳴らさない」意図と一致するため warning に留める。

**`duplicateDate` を error に昇格した理由**: 同一 `assignments[*].date` が複数回
現れる bundle を現行 `ShareImporter` がそのまま apply すると、新規 assignment では
先勝ち / 既存 assignment では繰り返し上書きという **deterministic でない部分適用**
が発生する。conflict resolution UI が P1-6 で揃うまで一律 reject にする。

### 7.3 `AlarmDiagnosticsReport` モデル（P1-5）

`AlarmDiagnosticsService.generate()` の出力。永続化はしない。

```swift
public struct AlarmDiagnosticsReport: Equatable, Sendable {
    public var generatedAt: Date
    public var overallStatus: AlarmDiagnosticsStatus
    public var checks: [AlarmDiagnosticsCheck]
    public var nextAlarmSummary: NextAlarmSummary?
    public var scheduledAlarmCount: Int
    public var lastSchedulerRunAt: Date?
}

public enum AlarmDiagnosticsStatus: String, Sendable {
    case normal, warning, attention, critical
}

public struct AlarmDiagnosticsCheck: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var status: AlarmDiagnosticsStatus
    public var message: String
    public var recoveryAction: AlarmDiagnosticsRecoveryAction?
}

public enum AlarmDiagnosticsRecoveryAction: Equatable, Sendable {
    case requestAlarmAuthorization
    case refreshScheduledAlarms
    case openSettings
    case openHealthAuthorization
    case none
}
```

**`overallStatus` 集約規則**:

- どれか 1 つでも `critical` → `critical`
- どれか 1 つでも `attention` → `attention`
- どれか 1 つでも `warning` → `warning`
- 全部 `normal` → `normal`

**「次回アラーム登録」チェックの判定ロジック**（DB の `current_alarm_kit_id` が
non-nil なだけでは不十分。AlarmKit 側で **実際に scheduled** であることを確認する）:

```swift
let savedID: UUID? = next ShiftAlarm row's current_alarm_kit_id
let liveIDs: Set<UUID> = try await alarmClient.scheduledIDs()  // §7.1 protocol

switch (savedID, liveIDs.contains(savedID ?? UUID())) {
case (nil, _):
    return .critical(.refreshScheduledAlarms)   // 未登録
case (let id?, false):
    return .critical(.refreshScheduledAlarms)   // 保存 ID が AlarmKit に存在しない
                                                // → 権限喪失 / 外部 purge / 同期失敗
case (_, true):
    return .normal                              // OK
}
```

`AlarmService` は既に `scheduledAlarms` を内部で参照しているので、
`AlarmSchedulingClient.scheduledIDs()`（§7.1 で追加）を経由して取得する。これに
より「DB 上は登録済みに見えるが実際は鳴らない」状態を診断画面で `critical` として
表面化できる。

**`AppSettings` 追加**: `lastAlarmSchedulerRunAt: Date?` /
`lastAlarmSchedulerResultRaw: String?`。後者は構造化ログ化（§P3-8）と合わせて
将来 enum rawValue に寄せる。

### 7.4 `ChangePreview` 共通モデル（P1-6）

`.shiftalarm` import / 画像 import / ドリフト受諾 / DOW ルール展開 / 長期連休
グルーピング / 将来の CSV import で共有する差分プレビュー基盤。

```swift
public struct ChangePreview: Equatable, Sendable {
    public var summary: ChangeSummary
    public var sections: [ChangePreviewSection]
}

public struct ChangeSummary: Equatable, Sendable {
    public var addedCount: Int
    public var updatedCount: Int
    public var deletedCount: Int
    public var unchangedCount: Int
    public var conflictCount: Int
    public var warningCount: Int
}

public struct ChangePreviewSection: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var items: [ChangePreviewItem]
}

public struct ChangePreviewItem: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var date: Date?
    public var entityKind: ChangeEntityKind
    public var changeKind: ChangeKind
    public var beforeText: LocalizedStringResource?   // String 直書きを避ける
    public var afterText: LocalizedStringResource?
    public var warnings: [LocalizedStringResource]
    public var isSelected: Bool
}

public enum ChangeKind: String, Sendable {
    case add, update, delete, unchanged, conflict
}

public enum ChangeEntityKind: String, Sendable {
    case preset
    case dayAssignment
    case rotationPattern
    case holidayOverride
    case vacationPeriod
    case dowRule
}
```

**移行順序（漸進）**:

1. **Step 1**: 既存 `ShareImporter` 内のプレビューロジックを
   `Sources/Features/Sharing/ImportPreviewView.swift` として独立抽出
   （振る舞い不変リファクタ）。
2. **Step 2**: `ChangePreview` 抽象モデル導入、`.shiftalarm` import 経路を
   新モデルへ移行。
3. **Step 3**: 画像 import / ドリフト UI / DOW ルール展開も同 UI を共有。

Step 1 は §P0-5 と独立に並走可能（validator は ShareImporter 内呼び出し、
抽出は別 PR）。

### 7.5 これらが集まって守るもの

| 機能 | 守る性質 |
|---|---|
| `AlarmSchedulingClient`（P0-4） | 「鳴らないアラーム」を fake テストで再現できる |
| `ShiftBundleValidator`（P0-5） | 壊れた外部入力からデータを守る |
| `AlarmDiagnosticsReport`（P1-5） | ユーザが「本当に鳴るか」を可視化できる |
| `ChangePreview`（P1-6） | すべての破壊的変更を Apply 前に確認させる |

「Alarm first / Preview before mutation / Explainable automation / Reversible」
という 2026-05-27 取り込みの基本原則を技術側で実装するための核となる 4 つ。

---

## 8. P2 拡張 ロードマップ的優先順位（参考）

P2 本体 (α / β / γ) と派生 (A1-A4) と新規 (δ / η) の **推奨着手順** は、独立性 ×
リスクで決める:

| 順 | タスク | 理由 |
|---|---|---|
| 1 | A1 (P2-α ドリフト検出) | α 本体実装の有無に関係なく `AppSettings` 拡張 1 件で動かせる。リスク最小 |
| 2 | A3 (P2-γ ラベル学習) | γ 本体実装の中に組込む形が綺麗。γ-本体と同 PR でも別 PR でも可 |
| 3 | P2-η (.ics エクスポート) | 既存 `DayResolver` / `ShareImporter` 経路だけ使うので独立、UI も小規模 |
| 4 | A4 (β 自動グルーピング) | β 本体 (Schema V2) が landing した直後に同型 sheet で追加 |
| 5 | A2 (DOW 検出) | `HolidayOverride` 大量 insert があるため、α 本体と並列稼動の検証が必要 |
| 6 | P2-δ (シフトスワップ) | Schema V3 を要するため β の V2 が landing した後。最大規模 |

α / β / γ 本体と派生機能の **依存関係は強くない** ため、人員リソースに応じて
派生機能を先行させることも可能。
