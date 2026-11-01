import Foundation
import SwiftUI

/// Private, on-device notes keyed by HealthKit UUID. No server, no Git data.
struct PaceSessionNote: Codable, Equatable {
    var effort: Int? = nil       // User-rated RPE 1–10, never inferred from HR.
    var comment: String = ""
    var updatedAt: Date = .now
}

@MainActor final class PaceSessionJournal: ObservableObject {
    @Published private(set) var notes: [String: PaceSessionNote] = [:]
    private let file: URL
    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        file = dir.appendingPathComponent("pace-session-notes.json")
        if let bytes = try? Data(contentsOf: file),
           let saved = try? JSONDecoder().decode([String: PaceSessionNote].self, from: bytes) {
            notes = saved
        }
    }
    func note(for uuid: String) -> PaceSessionNote { notes[uuid] ?? .init() }
    func save(for uuid: String, effort: Int?, comment: String) {
        guard !uuid.isEmpty else { return }
        let clean = String(comment.prefix(1200)).trimmingCharacters(in: .whitespacesAndNewlines)
        let score = effort.flatMap { (1...10).contains($0) ? $0 : nil }
        if score == nil && clean.isEmpty { notes.removeValue(forKey: uuid) }
        else { notes[uuid] = PaceSessionNote(effort: score, comment: clean, updatedAt: .now) }
        guard let bytes = try? JSONEncoder().encode(notes) else { return }
        do {
            try bytes.write(to: file, options: .atomic)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: file.path
            )
        } catch { print("Local note save failed:", error.localizedDescription) }
    }
}

struct PaceEffortEditor: View {
    @EnvironmentObject private var journal: PaceSessionJournal
    @Environment(\.dismiss) private var dismiss
    let uuid: String
    @State private var effort = 0
    @State private var comment = ""

    private var effortText: String {
        switch effort {
        case 1...2: "Très facile"
        case 3...4: "Facile"
        case 5...6: "Modéré"
        case 7...8: "Difficile"
        case 9...10: "Très difficile"
        default: "Non renseigné"
        }
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .firstTextBaseline) {
                        Text(effort == 0 ? "—" : "\(effort)").font(.system(size: 44, weight: .semibold, design: .rounded)).monospacedDigit()
                        Text("/ 10").foregroundStyle(.secondary)
                        Spacer()
                        Text(effortText).foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(get: { Double(effort) }, set: { effort = Int($0) }), in: 0...10, step: 1)
                        .tint(PaceColors.teal)
                        .accessibilityLabel("Difficulté ressentie de zéro à dix")
                } header: { Text("Effort ressenti (RPE)") }
                  footer: { Text("0 signifie non renseigné. Ce ressenti est saisi par vous : il ne provient pas de l’Apple Watch.") }
                Section("Notes personnelles") {
                    TextEditor(text: $comment)
                        .frame(minHeight: 130)
                        .accessibilityLabel("Notes sur la séance")
                }
                Section {
                    Text("Enregistrement local uniquement. Vous pouvez modifier ou effacer ces notes à tout moment.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Mon ressenti")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Enregistrer") {
                        journal.save(for: uuid, effort: effort == 0 ? nil : effort, comment: comment)
                        dismiss()
                    }.fontWeight(.semibold)
                }
            }
            .onAppear {
                let value = journal.note(for: uuid)
                effort = value.effort ?? 0
                comment = value.comment
            }
        }
    }
}
