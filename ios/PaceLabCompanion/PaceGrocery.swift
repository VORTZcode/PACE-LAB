import SwiftUI

struct PaceGroceryGroup: Identifiable {
    let id: String
    let name: String
    var grams: Int
    var sources: [String]
    var labels: [String]
}

struct GroceryScreen: View {
    @EnvironmentObject private var library: PaceLibrary

    private var grouped: [PaceGroceryGroup] {
        var groups: [String: PaceGroceryGroup] = [:]
        var ordered: [String] = []
        for recipe in library.programme.recipes {
            for (index, raw) in recipe.ingredients.components(separatedBy: .newlines).enumerated() {
                let cleaned = raw.replacingOccurrences(of: "•", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else { continue }
                let pair = cleaned.components(separatedBy: " : ")
                let name = pair.first?.trimmingCharacters(in: .whitespaces) ?? cleaned
                let quantity = pair.count == 2
                    ? Int(pair[1].replacingOccurrences(of: " g", with: "")
                        .trimmingCharacters(in: .whitespaces)) : nil
                let key = quantity == nil ? cleaned.lowercased() : name.lowercased()
                let source = recipe.id + "|" + String(index)
                let label = recipe.day + " · " + recipe.meal
                if groups[key] == nil {
                    groups[key] = PaceGroceryGroup(id: key, name: name,
                                                     grams: 0, sources: [], labels: [])
                    ordered.append(key)
                }
                groups[key]?.grams += quantity ?? 0
                groups[key]?.sources.append(source)
                groups[key]?.labels.append(label)
            }
        }
        return ordered.compactMap { groups[$0] }.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
    private var completedCount: Int {
        grouped.filter { group in
            group.sources.allSatisfy { library.shoppingChecked.contains($0) }
        }.count
    }
    private var sharedText: String {
        grouped.map { group in
            let quantity = group.grams > 0 ? " : \(group.grams) g" : ""
            return "• \(group.name)\(quantity)"
        }.joined(separator: "\n")
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "basket")
                        .font(.title2).foregroundStyle(PaceColors.teal)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(completedCount) / \(grouped.count) produits")
                            .font(.title3.weight(.semibold)).monospacedDigit()
                        Text("Liste regroupée pour toute la semaine")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                ProgressView(value: Double(completedCount), total: Double(max(grouped.count, 1)))
                    .tint(PaceColors.teal)
                    .padding(.vertical, 5)
            } footer: {
                Text("Quantités additionnées uniquement pour les ingrédients aux noms identiques et exprimés en grammes.")
            }
            Section("À acheter") {
                ForEach(grouped) { group in
                    let done = group.sources.allSatisfy { library.shoppingChecked.contains($0) }
                    Button {
                        library.setGroceries(group.sources, checked: !done)
                    } label: {
                        HStack(alignment: .center, spacing: 14) {
                            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(done ? PaceColors.teal : .secondary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(group.name)
                                    .foregroundStyle(done ? .secondary : .primary)
                                    .strikethrough(done)
                                if group.sources.count > 1 {
                                    Text("Pour \(group.sources.count) repas")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 6)
                            if group.grams > 0 {
                                Text("\(group.grams) g")
                                    .font(.subheadline.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(done ? .secondary : .primary)
                            }
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(group.name), \(group.grams) grammes, \(done ? "coché" : "à acheter")")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(PaceColors.base)
        .navigationTitle("Liste de courses")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ShareLink(item: sharedText) {
                        Label("Partager la liste", systemImage: "square.and.arrow.up")
                    }
                    Button("Tout décocher", systemImage: "arrow.counterclockwise", role: .destructive) {
                        library.clearGrocery()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Options de la liste de courses")
            }
        }
    }
}
