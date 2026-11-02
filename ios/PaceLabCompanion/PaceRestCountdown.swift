import SwiftUI

/// No background timer or notifications; elapsed rest derives from the wall clock.
/// The athlete may always ignore, skip, or stop this optional reminder.
struct PaceRestCountdown: View {
    let end: Date
    let seconds: Int
    let afterSet: Int
    let onSkip: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let remaining = max(0, Int(ceil(end.timeIntervalSince(timeline.date))))
            VStack(alignment:.leading,spacing:11) {
                HStack(alignment:.firstTextBaseline) {
                    Label(remaining > 0 ? "Récupération après la série \(afterSet)" :
                            "Récupération terminée",
                          systemImage: remaining > 0 ? "timer" : "checkmark.circle")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength:8)
                    Text("\(remaining / 60):\(String(format: "%02d", remaining % 60))")
                        .font(.system(.title2,design:.rounded,weight:.semibold))
                        .monospacedDigit()
                        .foregroundStyle(PaceColors.teal)
                }
                ProgressView(value: Double(max(0, seconds - remaining)),
                             total: Double(max(seconds, 1)))
                    .tint(PaceColors.teal)
                HStack(alignment:.center,spacing:10) {
                    Text(remaining > 0 ? "Repars quand tu es prêt ; le repos peut être prolongé."
                         : "Tu peux lancer la prochaine série à ton rythme.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength:5)
                    Button(remaining > 0 ? "Ignorer" : "Fermer", action: onSkip)
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                        .tint(PaceColors.teal)
                }
            }
            .padding(15)
            .background(PaceColors.teal.opacity(0.085),
                        in:RoundedRectangle(cornerRadius:17))
            .accessibilityElement(children:.contain)
            .accessibilityLabel("Repos entre deux séries")
        }
    }
}
