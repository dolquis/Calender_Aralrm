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
    @State private var viewModel = CalendarMonthViewModel()
    @State private var editingDate: Date?

    public init() {}

    private var resolverInput: DayResolverInput {
        DayResolverInputBuilder.make(
            presets: presets,
            assignments: assignments,
            holidays: holidays,
            rotations: rotations,
            vacations: vacations,
            swapRecords: swapRecords,
            calendar: viewModel.calendar
        )
    }

    public var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        VStack(spacing: 12) {
            header
            if presets.isEmpty && rotations.isEmpty {
                emptySetupBanner
            }
            weekdayHeader
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(viewModel.gridDates(), id: \.self) { date in
                    cell(for: date)
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
    private func cell(for date: Date) -> some View {
        let normalized = viewModel.calendar.startOfDay(for: date)
        let resolved = DayResolver.resolve(date: normalized, input: resolverInput)
        let presetID = resolved.presetID
        let preset = presetID.flatMap { resolverInput.presets[$0] }
        let holiday = resolverInput.holidays[normalized]
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
                holidayLabel: holiday?.label,
                hasSwapRecord: !(resolverInput.swapRecords[normalized]?.isEmpty ?? true),
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
