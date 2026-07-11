import SwiftData
import SwiftUI

public struct CalendarMonthView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.modelContext) private var modelContext
    @Query private var presets: [ShiftPreset]
    @Query private var assignments: [DayAssignment]
    @Query private var holidays: [HolidayOverride]
    @Query private var rotations: [RotationPattern]
    @Query(sort: [SortDescriptor(\VacationPeriod.startDate)])
    private var vacations: [VacationPeriod]
    @Query(sort: [SortDescriptor(\SwapRecord.date)])
    private var swapRecords: [SwapRecord]
    @Query private var settings: [AppSettings]
    @State private var viewModel = CalendarMonthViewModel()
    @State private var editingDate: Date?

    public init() {}

    /// App-wide holiday alarm default (`ring`/`silence`) that `.inherit` holidays resolve to.
    /// Read-only here (the toggle UI lands in a later P2-ζ PR); defaults to `.silence`.
    private var holidayAlarmDefault: HolidayAlarmBehavior {
        settings.first?.effectiveHolidayAlarmDefault ?? .silence
    }

    private var resolverInput: DayResolverInput {
        DayResolverInputBuilder.make(
            presets: presets,
            assignments: assignments,
            holidays: holidays,
            rotations: rotations,
            vacations: vacations,
            swapRecords: swapRecords,
            holidayAlarmDefault: holidayAlarmDefault,
            calendar: viewModel.calendar
        )
    }

    /// Bundled Japanese public holidays as an always-on display overlay (P2-ζ §6): the calendar
    /// shows a holiday and its 🔔/🔕 even before a `HolidayOverride` row is materialized. Built
    /// once per render; `HolidayOverride` rows take precedence for the label.
    private var bundledHolidayNames: [Date: String] {
        var map: [Date: String] = [:]
        for entry in HolidayProvider.loadJapaneseHolidays() {
            guard let day = HolidayProvider.parseLocalDay(entry.date, calendar: viewModel.calendar)
            else { continue }
            map[viewModel.calendar.startOfDay(for: day)] = entry.name
        }
        return map
    }

    public var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        // Compute the resolver input and holiday overlay once per render instead of rebuilding
        // them inside every one of the 42 cells.
        let input = resolverInput
        let holidayNames = bundledHolidayNames
        let globalDefault = holidayAlarmDefault

        VStack(spacing: 12) {
            header
            if presets.isEmpty && rotations.isEmpty {
                emptySetupBanner
            }
            weekdayHeader
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(viewModel.gridDates(), id: \.self) { date in
                    cell(
                        for: date, input: input, holidayNames: holidayNames,
                        globalDefault: globalDefault)
                }
            }
            CalendarLegendView()
            Spacer()
        }
        .padding()
        .navigationTitle("tab.calendar")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("calendar.today_button") {
                    viewModel.goToToday()
                }
            }
        }
        .sheet(
            item: Binding(
                get: { editingDate.map(IdentifiableDate.init) },
                set: { editingDate = $0?.date }
            )
        ) { wrapper in
            DayDetailEditorView(date: wrapper.date)
        }
    }

    @ViewBuilder
    private var emptySetupBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.tint)
            Text("calendar.empty_setup_hint")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            Button {
                viewModel.step(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("a11y.calendar.previous_month"))
            Spacer()
            Text(viewModel.monthTitle())
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button {
                viewModel.step(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("a11y.calendar.next_month"))
        }
    }

    @ViewBuilder
    private var weekdayHeader: some View {
        let symbols = viewModel.calendar.shortStandaloneWeekdaySymbols
        let firstWeekday = viewModel.calendar.firstWeekday
        HStack {
            ForEach(0..<7, id: \.self) { offset in
                let weekdayNumber = ((firstWeekday - 1 + offset) % 7) + 1
                Text(symbols[(firstWeekday - 1 + offset) % 7])
                    .frame(maxWidth: .infinity)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(weekdayColor(weekdayNumber))
            }
        }
    }

    private func weekdayColor(_ weekdayNumber: Int) -> Color {
        switch weekdayNumber {
        case 1: .red
        case 7: .blue
        default: .secondary
        }
    }

    @ViewBuilder
    private func cell(
        for date: Date,
        input: DayResolverInput,
        holidayNames: [Date: String],
        globalDefault: HolidayAlarmBehavior
    ) -> some View {
        let normalized = viewModel.calendar.startOfDay(for: date)
        let resolved = DayResolver.resolve(date: normalized, input: input)
        let preset = resolved.presetID.flatMap { input.presets[$0] }
        // Merge the materialized row (if any) with the always-on bundled overlay. A row wins for
        // the label; the 🔔/🔕 status comes from the effective policy (row behavior or, for a
        // display-only holiday, `.inherit` resolved against the app-wide default).
        let row = input.holidays[normalized]
        let bundledName = holidayNames[normalized]
        let holidayLabel = row?.label ?? bundledName
        let ringStatus: HolidayRingStatus? =
            (row != nil || bundledName != nil)
            ? HolidayRingStatus.resolve(rowBehavior: row?.behavior, globalDefault: globalDefault)
            : nil
        Button {
            editingDate = normalized
        } label: {
            DayCellView(
                date: normalized,
                inCurrentMonth: viewModel.isInCurrentMonth(normalized),
                isToday: viewModel.calendar.isDateInToday(normalized),
                presetName: preset?.name,
                presetColorHex: preset?.colorHex,
                alarmTime: resolved.fireTime,
                holidayLabel: holidayLabel,
                holidayRingStatus: ringStatus,
                hasSwapRecord: !(input.swapRecords[normalized]?.isEmpty ?? true),
                calendar: viewModel.calendar
            )
        }
        .buttonStyle(.plain)
    }
}

private struct IdentifiableDate: Identifiable {
    var date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}
