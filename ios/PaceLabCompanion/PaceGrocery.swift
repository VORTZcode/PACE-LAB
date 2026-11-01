import SwiftUI

struct PaceGroceryLine: Identifiable {
    let id: String
    let title: String
}
struct GroceryScreen: View {
    @EnvironmentObject private var library: PaceLibrary

    private func lines(for recipe: PaceRecipe) -> [PaceGroceryLine] {
        recipe.ingredients.components(separatedBy: .newlines).enumerated().compactMap { index, raw in
            let title = raw.replacingOccurrences(of: "•", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            return PaceGroceryLine(id: recipe.id + "|\(index)", title: title)
        }
    }
    private var total: Int {
        library.programme.recipes.reduce(0) { $0 + lines(for: $1).count }
    }
    private var checked: Int {
        library.programme.recipes.reduce(0) { count, recipe in
            count + lines(for: recipe).filter { library.shoppingChecked.contains($0.id) }.count
        }
    }
    private var sharedText: String {
        library.programme.recipes.map { recipe in
            let items = lines(for: recipe).map { "• " + $0.title }.joined(separator: "\n")
            return recipe.day + " · " + recipe.meal + " — " + recipe.name + "\n" + items
        }.joined(separator: "\n\n")
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(checked) / \(total)")
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Spacer()
                        Image(systemName: "basket").foregroundStyle(PaceColors.teal)
                    }
                    Text("Ingrédients cochés").font(.subheadline).foregroundStyle(.secondary)
                    ProgressView(value: Double(checked), total: Double(max(total, 1)))
                        .tint(PaceColors.teal)
                }.padding(.vertical, 4)
            } footer: {
                Text("Liste organisée par recette, sans fusion automatique des quantités. Les mêmes ingrédients peuvent apparaître plusieurs fois.")
            }
            ForEach(library.programme.recipes) { recipe in
                Section {
                    ForEach(lines(for: recipe)) { item in
                        Button {
                            library.toggleGrocery(item.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: library.shoppingChecked.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(library.shoppingChecked.contains(item.id) ? PaceColors.teal : Color.secondary)
                                Text(item.title)
                                    .foregroundStyle(library.shoppingChecked.contains(item.id) ? Color.secondary : Color.primary)
                                    .strikethrough(library.shoppingChecked.contains(item.id))
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.title + (library.shoppingChecked.contains(item.id) ? ", coché" : ", non coché"))
                    }
                } header: {
                    Text("\(recipe.day) · \(recipe.meal) — \(recipe.name)")
                        .textCase(nil)
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
