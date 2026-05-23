import EventKit
import Foundation

/// Actor-isolated wrapper around EKEventStore for importing all-day holiday events.
/// EKEventStore is not Sendable, so all access must stay within the actor.
public actor EventKitHolidayProvider {

    public static let shared = EventKitHolidayProvider()

    private let store = EKEventStore()

    private init() {}

    // MARK: - Public API

    /// Requests full calendar access. Returns true if granted.
    public func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    /// Returns (date, name) pairs for all-day events in holiday-like calendars
    /// within the given date range. Dates are normalized to start-of-day.
    public func fetchHolidayEntries(
        from start: Date, to end: Date
    ) async -> [(date: Date, name: String)] {
        let calendars = holidayCalendars()
        guard !calendars.isEmpty else { return [] }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let cal = Calendar.current
        // Extract only Sendable values (String, Date) before returning across isolation boundary.
        return store.events(matching: predicate)
            .filter { $0.isAllDay }
            .compactMap { event -> (date: Date, name: String)? in
                guard let startDate = event.startDate,
                    let title = event.title, !title.isEmpty
                else { return nil }
                return (date: cal.startOfDay(for: startDate), name: title)
            }
    }

    // MARK: - Private

    private func holidayCalendars() -> [EKCalendar] {
        let keywords = ["holiday", "Holiday", "祝日", "公休", "祝祭日"]
        return store.calendars(for: .event).filter { cal in
            // Match by keyword for all calendar types (subscription, CalDAV, etc.).
            // Checking only subscription type would import sports/school feeds too.
            keywords.contains { cal.title.localizedStandardContains($0) }
        }
    }
}
