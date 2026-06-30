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
                        .onTapGesture {
                            editingDate = viewModel.calendar.startOfDay(for: date)
                        }
                }
            }
            Spacer()
        }
        .padding()
        .navigationTitle("tab.calendar")
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
            }
            .accessibilityLabel(Text("a11y.calendar.next_month"))
        }
    }

    @ViewBuilder
    private var weekdayHeader: some View {
        let symbols = viewModel.calendar.shortStandaloneWeekdaySymbols
        let firstWeekday = viewModel.calendar.firstWeekday
        let ordered = (0..<7).map { symbols[(firstWeekday - 1 + $0) % 7] }
        HStack {
            ForEach(ordered, id: \.self) { s in
                Text(s)
                    .frame(maxWidth: .infinity)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func cell(for date: Date) -> some View {
        let normalized = viewModel.calendar.startOfDay(for: date)
        let resolved = DayResolver.resolve(date: normalized, input: resolverInput)
        let presetID = resolved.presetID
        let preset = presetID.flatMap { resolverInput.presets[$0] }
        let holiday = resolverInput.holidays[normalized]
        DayCellView(
            date: normalized,
            inCurrentMonth: viewModel.isInCurrentMonth(normalized),
            presetName: preset?.name,
            presetColorHex: preset?.colorHex,
            alarmTime: resolved.fireTime,
            holidayLabel: holiday?.label,
            hasSwapRecord: !(resolverInput.swapRecords[normalized]?.isEmpty ?? true)
        )
    }
}

private struct IdentifiableDate: Identifiable {
    var date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}
