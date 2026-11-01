import SwiftUI
import Charts

struct BodyMetricsSection: View {
    @EnvironmentObject var library: PaceLibrary
    @State private var editing = false
    private var lastWeight: PaceBodyLog? { library.bodyLogs.last(where: { $0.weightKg != nil }) }
    private var lastWaist: PaceBodyLog? { library.bodyLogs.last(where: { $0.waistCm != nil }) }
    private var weightHistory: [PaceBodyLog] { library.bodyLogs.filter { $0.weightKg != nil } }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                PaceSectionTitle(title: "Composition corporelle")
                Spacer()
                Button { editing = true } label: {
                    Label("Ajouter", systemImage: "plus").font(.subheadline.weight(.semibold))
                }
                .tint(PaceColors.teal)
            }
            HStack(spacing: 10) {
                PaceMetric(caption: "Dernier poids", value: lastWeight?.weightKg.map { PaceFormat.distance($0, places: 1) } ?? "—", suffix: "kg", symbol: "scalemass")
                PaceMetric(caption: "Tour de taille", value: lastWaist?.waistCm.map { PaceFormat.distance($0, places: 1) } ?? "—", suffix: "cm", symbol: "ruler")
            }
            if weightHistory.count >= 2 {
                PaceCard {
                    VStack(alignment: .leading, spacing: 11) {
                        Text("Évolution du poids").font(.subheadline.weight(.semibold))
                        Chart(weightHistory) { record in
                            if let weight = record.weightKg {
                                LineMark(x: .value("Date", record.date), y: .value("kg", weight))
                                    .foregroundStyle(PaceColors.teal)
                                    .lineStyle(StrokeStyle(lineWidth: 2.3))
                                PointMark(x: .value("Date", record.date), y: .value("kg", weight))
                                    .foregroundStyle(PaceColors.teal)
                            }
                        }
                        .frame(height: 160)
                    }
                }
            }
            Text("Mesures renseignées manuellement, conservées uniquement sur l’iPhone.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .sheet(isPresented: $editing) {
            NavigationStack { AddBodyMetricsScreen() }
        }
    }
}

struct AddBodyMetricsScreen: View {
    @EnvironmentObject var library: PaceLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var day = Date.now
    @State private var weight = ""
    @State private var waist = ""
    private func parse(_ raw: String) -> Double? {
        Double(raw.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }
    private var weightValue: Double? { parse(weight) }
    private var waistValue: Double? { parse(waist) }
    private var valid: Bool {
        let w = weightValue, c = waistValue
        return (w != nil || c != nil)
            && (w == nil || (w! >= 25 && w! <= 350))
            && (c == nil || (c! >= 35 && c! <= 260))
    }
    var body: some View {
        Form {
            Section("Mesure") {
                DatePicker("Date", selection: $day, in: ...Date.now, displayedComponents: .date)
                HStack {
                    Text("Poids")
                    Spacer()
                    TextField("kg", text: $weight).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    Text("kg").foregroundStyle(.secondary)
                }
                HStack {
                    Text("Tour de taille")
                    Spacer()
                    TextField("cm", text: $waist).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    Text("cm").foregroundStyle(.secondary)
                }
            }
            Section {
                Text("Renseignez une ou deux mesures. Utilisez idéalement les mêmes conditions de pesée pour comparer les tendances.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Nouvelle mesure")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Annuler") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Enregistrer") {
                    guard valid else { return }
                    library.saveBody(date: day, weight: weightValue, waist: waistValue)
                    dismiss()
                }
                .fontWeight(.semibold)
                .disabled(!valid)
            }
        }
    }
}
