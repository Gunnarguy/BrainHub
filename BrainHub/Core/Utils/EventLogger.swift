import Foundation
import Combine

/// Lightweight in-memory ring buffer logger for structured app events.
final class EventLogger: ObservableObject {
    static let shared = EventLogger(maxEvents: 200)
    private let maxEvents: Int
    @Published private(set) var events: [AppEvent] = []
    private let queue = DispatchQueue(label: "brainhub.eventlogger", qos: .utility)

    init(maxEvents: Int) { self.maxEvents = maxEvents }

    func record(_ event: AppEvent) {
        queue.async { [weak self] in
            guard let self else { return }
            var copy = self.events
            copy.append(event)
            if copy.count > self.maxEvents { copy.removeFirst(copy.count - self.maxEvents) }
            DispatchQueue.main.async { self.events = copy }
        }
    }

    func clear() {
        DispatchQueue.main.async { self.events.removeAll() }
    }
}

struct AppEvent: Identifiable {
    enum Kind: String, CaseIterable { case ingestSuccess, ingestDuplicate, ingestError, searchRun, searchError, system }
    let id = UUID()
    let kind: Kind
    let message: String
    let data: [String: String]
    let timestamp: Date = Date()
}
