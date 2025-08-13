import SwiftUI

struct SearchView: View {
    @ObservedObject var viewModel: ContentViewModel
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search all content...", text: $viewModel.searchTerm)
                        .textFieldStyle(.plain)
                        .onSubmit(viewModel.runSearch)
                        .focused($isSearchFocused)
                    if !viewModel.searchTerm.isEmpty {
                        Button(action: { viewModel.searchTerm = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
                .padding(.horizontal)

                HubSelectionRow(
                    label: "Filter by Hub",
                    selectedHubId: viewModel.searchHubFilter,
                    allHubs: viewModel.hubStore.descriptors,
                    allowAll: true
                ) {
                    viewModel.presentHubPicker(for: .search)
                }
                .padding(.horizontal)

                if viewModel.isSearching {
                    ProgressView()
                    Spacer()
                } else if viewModel.hits.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text(viewModel.searchTerm.isEmpty ? "Search for content across your hubs." : "No Results Found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List(viewModel.hits, id: \.id) { hit in
                        VStack(alignment: .leading, spacing: 8) {
                            highlightedText(hit.text, term: viewModel.searchTerm)
                                .lineLimit(5)
                            HStack {
                                Text(hit.hubId)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.2))
                                    .clipShape(Capsule())
                                Spacer()
                                Text(hit.documentId)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
            // Tap anywhere blank to dismiss keyboard
            .contentShape(Rectangle())
            .onTapGesture { if isSearchFocused { isSearchFocused = false; hideKeyboard() } }
            // Drag gesture to dismiss if pulling content
            .gesture(DragGesture().onChanged { _ in if isSearchFocused { isSearchFocused = false; hideKeyboard() } })
            // Interactive scroll dismissal for results list (iOS 16+)
            .modifier(ScrollDismissIfAvailable())
        }
    }
}

// MARK: - Highlight Helper
extension SearchView {
    // Returns a Text view with matched term segments bolded & colored.
    fileprivate func highlightedText(_ text: String, term: String) -> Text {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Text(text) }
        let lowerText = text.lowercased()
        let lowerTerm = trimmed.lowercased()
        var segments: [(String, Bool)] = []  // (segment, isMatch)
        var searchIndex = lowerText.startIndex
        var lastIndex = lowerText.startIndex
        while searchIndex < lowerText.endIndex,
              let r = lowerText.range(of: lowerTerm, range: searchIndex..<lowerText.endIndex) {
            if r.lowerBound > lastIndex {
                segments.append((String(text[lastIndex..<r.lowerBound]), false))
            }
            segments.append((String(text[r]), true))
            lastIndex = r.upperBound
            searchIndex = r.upperBound
        }
        if lastIndex < lowerText.endIndex {
            segments.append((String(text[lastIndex..<lowerText.endIndex]), false))
        }
        // Assemble Text
        var result = Text("")
        for (seg, highlight) in segments {
            if highlight { result = result + Text(seg).bold().foregroundColor(.accentColor) }
            else { result = result + Text(seg) }
        }
        return result
    }
}

// MARK: - Scroll Dismiss Helper
private struct ScrollDismissIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollDismissesKeyboard(.interactively)
        } else {
            content
        }
    }
}
