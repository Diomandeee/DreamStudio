import SwiftUI
import ComposableArchitecture

// MARK: - Main Content View

struct ContentView: View {
    @Bindable var store: StoreOf<GenerationFeature>

    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("Dream Studio")
                .toolbar { toolbarContent }
                .safeAreaInset(edge: .bottom) {
                    promptInputBar
                }
                .sheet(item: $store.scope(state: \.providerConfig, action: \.providerConfig)) { providerStore in
                    ProviderSettingsView(store: providerStore)
                }
                .sheet(item: $store.scope(state: \.templatePicker, action: \.templatePicker)) { templateStore in
                    TemplatePickerView(store: templateStore)
                }
                .sheet(item: $store.scope(state: \.costTracker, action: \.costTracker)) { costStore in
                    CostTrackingView(store: costStore)
                }
                .alert("Error", isPresented: .constant(store.error != nil)) {
                    Button("OK") { }
                } message: {
                    Text(store.error ?? "")
                }
                .onAppear {
                    store.send(.onAppear)
                }
        }
    }

    // MARK: - Main Content Area

    private var mainContent: some View {
        VStack(spacing: 0) {
            if store.isGenerating {
                stageProgressBar
            }

            if let _ = store.session, store.stage == .complete {
                if let canvasStore = store.scope(state: \.canvas, action: \.canvas.presented) {
                    CanvasView(store: canvasStore)
                } else {
                    dreamListView
                }
            } else {
                dreamListView
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                store.send(.showProviderConfig)
            } label: {
                Image(systemName: "gearshape")
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 12) {
                if store.accumulatedCost.totalTokens > 0 {
                    Button {
                        store.send(.showCostTracker)
                    } label: {
                        Image(systemName: "dollarsign.circle")
                    }
                }

                Button {
                    store.send(.refreshList)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }

    // MARK: - Stage Progress Bar

    private var stageProgressBar: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: store.stage.systemImage)
                    .foregroundStyle(Color.accentColor)
                Text(store.stage.displayName)
                    .font(.subheadline.bold())
                Spacer()
                if let stageNum = store.stage.stageNumber {
                    Text("Stage \(stageNum) of 4")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Stop") {
                    store.send(.stopGeneration)
                }
                .font(.caption.bold())
                .foregroundStyle(.red)
            }

            ProgressView(value: store.stage.progress)
                .tint(Color.accentColor)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Dream List

    private var dreamListView: some View {
        Group {
            if store.isLoadingList {
                ProgressView("Loading dreams...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.dreams.isEmpty {
                emptyStateView
            } else {
                dreamListContent
            }
        }
    }

    private var dreamListContent: some View {
        List {
            if store.isGenerating, let session = store.session {
                Section("Generating") {
                    activeGenerationRow(session)
                }
            }

            if let template = store.selectedTemplate {
                Section("Template") {
                    selectedTemplateRow(template)
                }
            }

            Section("Dreams (\(store.dreams.count))") {
                ForEach(store.dreams) { dream in
                    dreamRow(dream)
                }
                .onDelete { offsets in
                    for offset in offsets {
                        store.send(.deleteDream(store.dreams[offset].id))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(Color.accentColor.opacity(0.6))

            Text("Dream Studio")
                .font(.title.bold())

            Text("Enter a prompt below to generate interactive web experiences, games, dashboards, and more.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                store.send(.useExamplePrompt)
            } label: {
                Label("Try an Example", systemImage: "lightbulb")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)

            templateCategoryButtons
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var templateCategoryButtons: some View {
        HStack(spacing: 12) {
            ForEach(TemplateCategory.allCases) { category in
                VStack(spacing: 4) {
                    Image(systemName: category.systemImage)
                        .font(.title3)
                    Text(category.displayName)
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
                .frame(width: 60, height: 60)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onTapGesture {
                    store.send(.showTemplatePicker)
                }
            }
        }
    }

    private func activeGenerationRow(_ session: DreamSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text(store.stage.displayName)
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
            Spacer()
            ProgressView()
        }
    }

    private func selectedTemplateRow(_ template: DreamTemplate) -> some View {
        HStack {
            Image(systemName: template.systemImage)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading) {
                Text(template.name)
                    .font(.subheadline.bold())
                Text(template.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button("Change") {
                store.send(.showTemplatePicker)
            }
            .font(.caption)
        }
    }

    private func dreamRow(_ dream: DreamSummary) -> some View {
        Button {
            store.send(.selectDream(dream.id))
        } label: {
            dreamRowContent(dream)
        }
        .swipeActions(edge: .leading) {
            Button {
                store.send(.toggleFavorite(dream.id))
            } label: {
                Image(systemName: dream.isFavorite ? "star.slash" : "star.fill")
            }
            .tint(.yellow)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                store.send(.deleteDream(dream.id))
            } label: {
                Image(systemName: "trash")
            }
        }
    }

    private func dreamRowContent(_ dream: DreamSummary) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if dream.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                    Text(dream.title)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                }

                Text(dream.prompt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(dream.outputType.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())

                    Text(dream.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Prompt Input Bar

    private var promptInputBar: some View {
        VStack(spacing: 8) {
            promptOptionsRow
            promptInputRow
        }
        .padding(.top, 8)
        .background(.ultraThinMaterial)
    }

    private var promptOptionsRow: some View {
        HStack(spacing: 12) {
            Button {
                store.send(.showTemplatePicker)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: store.selectedTemplate?.systemImage ?? "rectangle.3.group")
                        .font(.caption)
                    Text(store.selectedTemplate?.name ?? "Template")
                        .font(.caption)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
            }

            outputTypeMenu

            Spacer()

            onlineIndicator
        }
        .padding(.horizontal)
    }

    private var outputTypeMenu: some View {
        Menu {
            ForEach(DreamOutputType.allCases, id: \.self) { type in
                Button {
                    store.send(.outputTypeChanged(type))
                } label: {
                    if type == store.selectedOutputType {
                        Label(type.displayName, systemImage: "checkmark")
                    } else {
                        Text(type.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "doc")
                    .font(.caption)
                Text(store.selectedOutputType.displayName)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(.systemGray5))
            .clipShape(Capsule())
        }
    }

    private var onlineIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(store.isOnline ? .green : .orange)
                .frame(width: 6, height: 6)
            Text(store.isOnline ? "Online" : "Local")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var promptInputRow: some View {
        let isEmpty = store.promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return HStack(spacing: 8) {
            TextField("Describe what you want to create...", text: $store.promptText.sending(\.promptTextChanged), axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Button {
                store.send(.createAndGenerate)
            } label: {
                Image(systemName: store.isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(isEmpty && !store.isGenerating ? .secondary : Color.accentColor)
            }
            .disabled(isEmpty && !store.isGenerating)
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }
}

#Preview {
    ContentView(
        store: Store(initialState: GenerationFeature.State()) {
            GenerationFeature()
        }
    )
}
