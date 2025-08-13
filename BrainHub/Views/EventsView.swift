import SwiftUI

struct EventsView: View {
    @ObservedObject var logger: EventLogger = .shared
    @Environment(\.dismiss) private var dismiss
    @State private var filterKind: AppEvent.Kind? = nil
    @State private var search = ""

    private var filtered: [AppEvent] {
        logger.events.reversed().filter { e in
            if let fk = filterKind, e.kind != fk { return false }
            if !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let q = search.lowercased()
                if !e.message.lowercased().contains(q) && !e.data.values.contains(where: { $0.lowercased().contains(q) }) {
                    return false
                }
            }
            return true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                if filtered.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No Events")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding()
                } else {
                    List(filtered) { e in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                kindBadge(e.kind)
                                Text(e.timestamp, style: .time).font(.caption).foregroundColor(.secondary)
                            }
                            Text(e.message).font(.subheadline)
                            if !e.data.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(e.data.sorted(by: { $0.key < $1.key }), id: \.key) { kv in
                                            Text("\(kv.key)=\(kv.value)")
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(Color(.secondarySystemBackground))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Events")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Close") { dismiss() } }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        Button("All") { filterKind = nil }
                        Divider()
                        ForEach(AppEvent.Kind.allCases, id: \.self) { k in
                            Button(k.rawValue) { filterKind = k }
                        }
                    } label: { Image(systemName: "line.3.horizontal.decrease.circle") }
                    Button(role: .destructive) { logger.clear() } label: { Image(systemName: "trash") }
                }
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField("Search events", text: $search)
                .textFieldStyle(.plain)
            if !search.isEmpty {
                Button(action: { search = "" }) { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
    }

    @ViewBuilder private func kindBadge(_ kind: AppEvent.Kind) -> some View {
        Text(kind.rawValue)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color(for: kind).opacity(0.15))
            .foregroundColor(color(for: kind).opacity(0.9))
            .clipShape(Capsule())
    }

    private func color(for k: AppEvent.Kind) -> Color {
        switch k {
        case .ingestSuccess: return .green
        case .ingestDuplicate: return .orange
        case .ingestError: return .red
        case .searchRun: return .blue
        case .searchError: return .red
        case .system: return .gray
        }
    }
}

#Preview { EventsView() }
