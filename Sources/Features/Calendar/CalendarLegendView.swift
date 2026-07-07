import SwiftUI

/// Compact legend explaining the day-cell markers on the month calendar.
struct CalendarLegendView: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                items
            }
            VStack(alignment: .leading, spacing: 6) {
                items
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var items: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(.tint, lineWidth: 1.5)
                .frame(width: 12, height: 12)
            Text("calendar.today_button")
        }
        HStack(spacing: 4) {
            Circle()
                .fill(.secondary)
                .frame(width: 8, height: 8)
            Text("calendar.legend.shift")
        }
        HStack(spacing: 4) {
            StatusPill("calendar.holiday_short", tint: .red)
            Text("calendar.legend.holiday")
        }
        HStack(spacing: 4) {
            Image(systemName: "arrow.left.arrow.right")
            Text("calendar.legend.swap")
        }
    }
}
