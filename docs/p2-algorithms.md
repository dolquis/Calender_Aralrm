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
| `presetID == someUUID` | `.preset(UUID)` |

結果: `series: [Symbol?]` 長さ `windowDays`。

ローテーション由来のプリセットは `DayAssignment` 行として永続化されないため、
フィルタは入力選択時点で暗黙に成立する (α-U10)。

### 1.3 周期探索

候補 `P ∈ [minCycleLength, maxCycleLength]` について:

1. `floor(series.count / P) ≥ minCycles` を満たさなければ `P` を棄却。
2. インデックスを `i mod P` でグループ化。各スロット `s ∈ 0..<P` について:
   - 非 nil シンボルを `{s, s+P, s+2P, ...}` から集める。
   - `density[s] = observedCount / cyclesCount`。
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
| α-U2 | `cyclesCount < 2` → `P` 棄却 |
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

---

## 3. P2-γ — シフト表画像インポート

### 3.1 パイプライン全景

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
| `bash scripts/verify.sh`（CI 既定） | α / β / γ の unit + integration（モック使用）。現状 56 件に対し ~40 件追加見込み。 |
| `SNAPSHOT_TESTING_ENABLED=1 bash scripts/verify.sh` | + 既存スナップショット 5 件。本タスクではスナップショット追加なし。 |
| `VISION_E2E=1 bash scripts/verify.sh` | + γ-U1/U2 smoke + 精度 DoD (γ-D1/D2/D3)。ローカル運用。 |

3 段階の gating で CI は速度と決定論を保ちつつ、DoD の精度測定はオンデマンドで
可能にする。
