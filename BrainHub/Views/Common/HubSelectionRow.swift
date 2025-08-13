import SwiftUI

struct HubSelectionRow: View {
    let label: String
    let selectedHubId: String
    let allHubs: [HubDescriptor]
    let allowAll: Bool
    let onSelect: () -> Void

    private var selectedHubTitle: String {
        if allowAll && selectedHubId.isEmpty {
            return "All Hubs"
        }
        return allHubs.first { $0.id == selectedHubId }?.title ?? selectedHubId
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Button(action: onSelect) {
                HStack(spacing: 6) {
                    Text(selectedHubTitle)
                        .font(.headline)
                        .foregroundColor(.accentColor)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
            }
        }
    }
}
