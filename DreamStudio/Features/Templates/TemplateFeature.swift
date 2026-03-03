import ComposableArchitecture
import SwiftUI

// MARK: - Template Feature

@Reducer
struct TemplateFeature: Sendable {
    @ObservableState
    struct State: Equatable {
        var templates: [DreamTemplate] = DreamTemplates.all
        var selectedCategory: TemplateCategory?
        var searchText: String = ""

        var filteredTemplates: [DreamTemplate] {
            var result = templates

            if let category = selectedCategory {
                result = result.filter { $0.category == category }
            }

            if !searchText.isEmpty {
                let query = searchText.lowercased()
                result = result.filter {
                    $0.name.lowercased().contains(query) ||
                    $0.description.lowercased().contains(query)
                }
            }

            return result
        }
    }

    enum Action: Sendable, Equatable {
        case categorySelected(TemplateCategory?)
        case searchTextChanged(String)
        case templateSelected(DreamTemplate)
        case dismiss
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .categorySelected(let category):
                state.selectedCategory = category
                return .none

            case .searchTextChanged(let text):
                state.searchText = text
                return .none

            case .templateSelected:
                return .none

            case .dismiss:
                return .none
            }
        }
    }
}

// MARK: - Template Picker View

struct TemplatePickerView: View {
    @Bindable var store: StoreOf<TemplateFeature>

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        categoryChip(label: "All", category: nil)
                        ForEach(TemplateCategory.allCases) { category in
                            categoryChip(label: category.displayName, category: category)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(.ultraThinMaterial)

                // Template List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(store.filteredTemplates) { template in
                            templateCard(template)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Choose Template")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $store.searchText.sending(\.searchTextChanged), prompt: "Search templates...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.send(.dismiss)
                    }
                }
            }
        }
    }

    private func categoryChip(label: String, category: TemplateCategory?) -> some View {
        let isSelected = store.selectedCategory == category

        return Button {
            store.send(.categorySelected(category))
        } label: {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }

    private func templateCard(_ template: DreamTemplate) -> some View {
        Button {
            store.send(.templateSelected(template))
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: template.systemImage)
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 40, height: 40)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(template.name)
                            .font(.headline)
                        Text(template.category.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }

                Text(template.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                // Example Prompts
                VStack(alignment: .leading, spacing: 4) {
                    Text("Example prompts:")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                    ForEach(template.examplePrompts.prefix(2), id: \.self) { prompt in
                        HStack(alignment: .top, spacing: 4) {
                            Image(systemName: "lightbulb")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                            Text(prompt)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                // Libraries
                HStack(spacing: 6) {
                    ForEach(template.suggestedLibraries, id: \.self) { lib in
                        Text(lib)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
