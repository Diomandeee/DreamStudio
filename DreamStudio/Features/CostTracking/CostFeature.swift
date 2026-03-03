import ComposableArchitecture
import SwiftUI

// MARK: - Cost Feature

@Reducer
struct CostFeature: Sendable {
    @ObservableState
    struct State: Equatable {
        var cost: DreamGenerationCost
        var sessionCosts: [SessionCostEntry] = []

        var totalTokens: Int { cost.totalTokens }

        var formattedCost: String {
            guard let usd = cost.estimatedCostUSD else {
                return estimateFromTokens()
            }
            return String(format: "$%.4f", usd)
        }

        private func estimateFromTokens() -> String {
            // Rough estimates: $0.15/1M input, $0.60/1M output (Gemini Flash pricing)
            let inputCost = Double(cost.inputTokens) * 0.00000015
            let outputCost = Double(cost.outputTokens) * 0.0000006
            let total = inputCost + outputCost
            return String(format: "$%.4f", total)
        }
    }

    struct SessionCostEntry: Equatable, Identifiable, Sendable {
        let id: String
        let dreamTitle: String
        let cost: DreamGenerationCost
        let date: Date
    }

    enum Action: Sendable, Equatable {
        case onAppear
        case dismiss
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none
            case .dismiss:
                return .none
            }
        }
    }
}

// MARK: - Cost Tracking View

struct CostTrackingView: View {
    @Bindable var store: StoreOf<CostFeature>

    var body: some View {
        NavigationStack {
            List {
                Section("Current Session") {
                    costRow(label: "Input Tokens", value: formatNumber(store.cost.inputTokens))
                    costRow(label: "Output Tokens", value: formatNumber(store.cost.outputTokens))
                    if let thinking = store.cost.thinkingTokens, thinking > 0 {
                        costRow(label: "Thinking Tokens", value: formatNumber(thinking))
                    }
                    costRow(label: "Total Tokens", value: formatNumber(store.totalTokens))
                    if let imageCount = store.cost.imageCount, imageCount > 0 {
                        costRow(label: "Images Generated", value: "\(imageCount)")
                    }

                    HStack {
                        Text("Estimated Cost")
                            .font(.headline)
                        Spacer()
                        Text(store.formattedCost)
                            .font(.headline)
                            .foregroundStyle(.green)
                    }
                }

                Section("Cost Breakdown") {
                    VStack(alignment: .leading, spacing: 8) {
                        costBar(label: "Spec Generation", fraction: 0.1, color: .blue)
                        costBar(label: "Layout Generation", fraction: 0.5, color: .purple)
                        costBar(label: "Image Generation", fraction: 0.3, color: .orange)
                        costBar(label: "Script Generation", fraction: 0.1, color: .green)
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pricing Notes")
                            .font(.subheadline.bold())
                        Text("Costs are estimated based on provider pricing. Actual costs may vary. Gemini Flash pricing: $0.15/1M input tokens, $0.60/1M output tokens.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Usage & Cost")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        store.send(.dismiss)
                    }
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
        }
    }

    private func costRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
    }

    private func costBar(label: String, fraction: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption)
                Spacer()
                Text("\(Int(fraction * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.3))
                    .frame(width: geo.size.width)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color)
                            .frame(width: geo.size.width * fraction)
                    }
            }
            .frame(height: 6)
        }
    }

    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
