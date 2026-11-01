import SwiftUI

struct NutritionScreen: View {
    @EnvironmentObject var library: PaceLibrary
    @State private var selected = "Lundi"
    @State private var didChooseInitialDay = false

    private var day: PaceDay? { library.programme.plan.first { $0.day == selected } }
    private var meals: [PaceRecipe] { library.programme.recipes.filter { $0.day == selected } }
    private var days: [String] { library.programme.plan.map(\.day) }
    private func selectCurrentOrUpcoming() {
        guard !didChooseInitialDay else { return }
        didChooseInitialDay = true
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: .now)
        let list = library.programme.plan
        if let same = list.first(where: { $0.date == today }) {
            selected = same.day
        } else if let upcoming = list.first(where: { $0.date > today }) {
            selected = upcoming.day
        } else if let recent = list.last {
            selected = recent.day
        }
    }


    var body: some View {
        NavigationStack {
            PaceScreen(title: "Nutrition") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("VOTRE PLAN ALIMENTAIRE")
                        .font(.caption2.weight(.bold)).tracking(1.3).foregroundStyle(PaceColors.teal)
                    Text("Repas du programme")
                        .font(.title3.weight(.semibold))
                    Text("Deux repas par jour. Quantités de féculents indiquées à cru.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    NavigationLink {
                        GroceryScreen()
                    } label: {
                        Label("Liste de courses", systemImage: "basket")
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(PaceColors.teal)
                    .padding(.top, 6)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(days, id: \.self) { name in
                            Button {
                                selected = name
                            } label: {
                                Text(String(name.prefix(3)).capitalized)
                                    .font(.subheadline.weight(selected == name ? .semibold : .regular))
                                    .foregroundStyle(selected == name ? Color.white : Color.primary)
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 11)
                                    .background(selected == name ? PaceColors.teal : PaceColors.surface, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if let day {
                    PaceCard {
                        HStack(spacing: 18) {
                            VStack(alignment: .leading, spacing: 7) {
                                Text("REPÈRES DU JOUR SÉLECTIONNÉ").font(.caption2.weight(.bold)).tracking(1.1).foregroundStyle(.secondary)
                                Text("\(Int(day.kcal)) kcal").font(.system(size: 27, weight: .semibold, design: .rounded)).monospacedDigit()
                                Text("Repère alimentaire indicatif").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 8) {
                                Image(systemName: "fork.knife.circle")
                                    .font(.title2).foregroundStyle(PaceColors.teal)
                                Text("\(Int(day.protein)) g").font(.title3.weight(.semibold)).monospacedDigit()
                                Text("protéines prévues").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                PaceSectionTitle(title: "Au menu", subtitle: selected)
                ForEach(meals) { meal in
                    NavigationLink { RecipeDetailScreen(recipe: meal) } label: {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text(meal.meal.uppercased())
                                    .font(.caption2.weight(.bold)).tracking(1.2)
                                    .foregroundStyle(PaceColors.teal)
                                Spacer()
                                if library.eaten.contains(meal.id) {
                                    Label("Fait", systemImage: "checkmark.circle.fill")
                                        .font(.caption.weight(.semibold)).foregroundStyle(PaceColors.teal)
                                }
                            }
                            Text(meal.name).font(.title3.weight(.semibold)).foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            HStack {
                                Label("\(Int(meal.kcal)) kcal", systemImage: "flame")
                                Text("·")
                                Text("\(Int(meal.protein)) g de protéines")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(19)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PaceColors.surface, in: RoundedRectangle(cornerRadius: 21))
                    }
                    .buttonStyle(.plain)
                }
                PaceCard {
                    HStack(spacing: 13) {
                        Image(systemName: "info.circle").foregroundStyle(PaceColors.teal)
                        Text("Les apports sont des estimations du programme, pas des calories effectivement consommées.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear { selectCurrentOrUpcoming() }
        }
    }
}

struct RecipeDetailScreen: View {
    @EnvironmentObject var library: PaceLibrary
    let recipe: PaceRecipe
    var body: some View {
        PaceScreen(title: recipe.meal) {
            VStack(alignment: .leading, spacing: 8) {
                Text(recipe.day.uppercased()).font(.caption2.weight(.bold)).tracking(1.3).foregroundStyle(PaceColors.teal)
                Text(recipe.name).font(.system(size: 29, weight: .semibold))
                HStack(spacing: 8) {
                    PacePill(label: "\(Int(recipe.kcal)) kcal", symbol: "flame")
                    PacePill(label: "\(Int(recipe.protein)) g protéines", symbol: "leaf")
                }
            }
            PaceSectionTitle(title: "Ingrédients")
            PaceCard {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(recipe.ingredients.components(separatedBy: "\n"), id: \.self) { item in
                        Text(item.replacingOccurrences(of: "• ", with: ""))
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            PaceSectionTitle(title: "Préparation")
            PaceCard {
                Text(recipe.method).font(.body).lineSpacing(6)
            }
            if !recipe.notes.isEmpty {
                PaceCard {
                    Label(recipe.notes, systemImage: "lightbulb")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Button {
                library.toggleMeal(recipe.id)
            } label: {
                Label(library.eaten.contains(recipe.id) ? "Repas validé" : "Marquer comme consommé",
                      systemImage: library.eaten.contains(recipe.id) ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent).tint(PaceColors.teal)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
