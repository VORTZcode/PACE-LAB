import Foundation

/// Synchronizes Apple Health running metrics by actual timestamp, without guessing missing values.
/// This is an intentionally bounded *summary* of locally stored records, never a GPS route.
/// Data is only sent remotely if the user explicitly enables the corresponding Coach permission.
enum PaceDynamicsTimeline {
    struct Sample: Codable {
        let timestamp: String
        let value: Double
    }
    struct Metric: Codable {
        let label: String
        let unit: String
        let samples: [Sample]
    }
    private struct Bucket {
        var sum: Double = 0
        var count: Int = 0
        mutating func add(_ value:Double) {
            sum += value; count += 1
        }
        var mean: Double? { count > 0 ? sum / Double(count) : nil }
    }
    static func summarize(startedAt:String,duration:TimeInterval,metrics:[Metric],
                          maxBuckets:Int = 120) -> String {
        let iso = ISO8601DateFormatter()
        guard let start = iso.date(from:startedAt),duration >= 30,
              duration.isFinite, maxBuckets > 0 else {
            return "Profil synchronisé indisponible : durée ou date d'activité invalide."
        }
        let bucketWidth = max(60,ceil(duration / Double(maxBuckets) / 60) * 60)
        let buckets = min(maxBuckets,Int(ceil(duration/bucketWidth)))
        guard buckets > 0 else { return "Profil synchronisé indisponible." }
        var matrix = [[Bucket]](repeating:[Bucket](repeating:Bucket(),count:buckets),count:metrics.count)
        var validSamples = [Int](repeating:0,count:metrics.count)
        for (metricIndex,metric) in metrics.enumerated() {
            for sample in metric.samples {
                guard sample.value.isFinite,sample.value > 0,
                      let date = iso.date(from:sample.timestamp) else { continue }
                let seconds = date.timeIntervalSince(start)
                guard seconds >= 0,seconds <= duration else { continue }
                let index = min(buckets-1,Int(seconds/bucketWidth))
                // Filter impossible samples, not missing measurements.
                let valid: Bool
                switch metric.label {
                case "FC":valid = (25...245).contains(sample.value)
                case "Vitesse":valid = (0.5...12).contains(sample.value)
                case "Puissance":valid = (1...1800).contains(sample.value)
                case "Foulée":valid = (0.2...3.5).contains(sample.value)
                case "Contact":valid = (70...1000).contains(sample.value)
                case "Oscillation":valid = (1...40).contains(sample.value)
                default:valid = false
                }
                guard valid else { continue }
                matrix[metricIndex][index].add(sample.value)
                validSamples[metricIndex] += 1
            }
        }
        let present = metrics.indices.filter { validSamples[$0] > 0 }
        guard !present.isEmpty else {
            return "Aucune série temporelle avancée utilisable pour cette sortie. Valeurs absentes, non estimées."
        }
        var lines = [
            "PROFILS SYNCHRONISÉS APPLE SANTÉ (mesures moyennes par fenêtre ; aucune interpolation, GPS absent).",
            "Durée \(Int(duration/60)) min ; fenêtres \(Int(bucketWidth/60)) min ; \(buckets) fenêtres, maximum \(maxBuckets).",
            "Couverture (nombre d'échantillons de source, la fréquence de mesure peut varier) : " +
              metrics.indices.map { "\(metrics[$0].label)=\(validSamples[$0])" }.joined(separator:" ; "),
            "Horodatages alignés sur le départ de la séance, pas sur la distance parcourue."
        ]
        for bucket in 0..<buckets {
            let from = Int(Double(bucket)*bucketWidth/60)
            let to = Int(min(duration,Double(bucket+1)*bucketWidth)/60)
            var values:[String] = []
            for metricIndex in present {
                guard let mean = matrix[metricIndex][bucket].mean else { continue }
                let metric = metrics[metricIndex]
                let display:String
                if metric.label == "Vitesse" {
                    let totalSeconds = Int((1000 / mean).rounded())
                    display = "allure \(totalSeconds/60):\(String(format:"%02d",totalSeconds%60))/km"
                } else {
                    let precision = ["Foulée","Oscillation"].contains(metric.label) ? 2 : 0
                    display = "\(metric.label) \(mean.formatted(.number.precision(.fractionLength(precision)))) \(metric.unit)"
                }
                values.append(display)
            }
            if !values.isEmpty { lines.append("\(from)-\(max(from+1,to)) min: " + values.joined(separator:" | ")) }
        }
        lines.append("IMPORTANT : certaines fenêtres peuvent ne contenir qu'une seule mesure et plusieurs capteurs peuvent être manquants. Comparer FC/puissance/allure en tenant compte du terrain, de la météo et des interruptions ; aucune causalité ou diagnostic inférés des seules courbes.")
        return lines.joined(separator:"\n")
    }
}
