import Foundation

/// Decodes CO-OPS `product=predictions` JSON. Strict: an unreadable row fails the
/// whole response rather than being skipped or guessed.
public enum NOAADecoder {
    private struct Envelope: Decodable {
        struct Row: Decodable {
            let t: String
            let v: String
            let type: String?
        }

        struct ErrorBody: Decodable { let message: String }

        let predictions: [Row]?
        let error: ErrorBody?
        let message: String?
    }

    public static func events(from data: Data) throws(NOAAError) -> [TideEvent] {
        let rows = try predictionRows(from: data)
        return try rows.map { row throws(NOAAError) -> TideEvent in
            guard let date = NOAATimestamp.parse(row.t),
                  let height = Double(row.v), height.isFinite,
                  let type = row.type.flatMap({ TideEvent.Kind(rawValue: $0.uppercased()) })
            else { throw .malformedResponse }
            return TideEvent(date: date, heightMeters: height, kind: type)
        }.sorted { $0.date < $1.date }
    }

    public static func samples(from data: Data) throws(NOAAError) -> [TideSample] {
        let rows = try predictionRows(from: data)
        return try rows.map { row throws(NOAAError) -> TideSample in
            guard let date = NOAATimestamp.parse(row.t), let height = Double(row.v), height.isFinite
            else { throw .malformedResponse }
            return TideSample(date: date, heightMeters: height)
        }.sorted { $0.date < $1.date }
    }

    private static func predictionRows(from data: Data) throws(NOAAError) -> [Envelope.Row] {
        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw .malformedResponse
        }
        if let error = envelope.error {
            throw .rejected(message: error.message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard let rows = envelope.predictions else {
            if envelope.message?.lowercased() == "forbidden" { throw .throttled }
            throw .malformedResponse
        }
        guard !rows.isEmpty else { throw .noPredictions }
        return rows
    }
}
