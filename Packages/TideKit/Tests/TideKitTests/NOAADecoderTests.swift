import Foundation
import Testing
@testable import TideKit

@Suite("NOAA decoding (real captured responses)")
struct NOAADecoderTests {
    @Test func decodesReferenceHighLowEvents() throws {
        let events = try NOAADecoder.events(from: Fixture.data("santamonica_9410840_hilo"))
        #expect(events.count == 13) // verified against the raw fixture
        #expect(events.first == TideEvent(date: utc("2026-11-15 03:12"), heightMeters: 0.158, kind: .low))
        #expect(events == events.sorted { $0.date < $1.date })
    }

    @Test func decodesFifteenMinuteSamples() throws {
        let samples = try NOAADecoder.samples(from: Fixture.data("santamonica_9410840_15min"))
        #expect(samples.first?.date == utc("2026-11-15 00:00"))
        #expect(samples.first?.heightMeters == 0.61)
        let steps = Set(zip(samples, samples.dropFirst()).map { $1.date.timeIntervalSince($0.date) })
        #expect(steps == [900])
    }

    @Test func decodesSubordinateHighLow() throws {
        let events = try NOAADecoder.events(from: Fixture.data("kingharbor_9410738_hilo"))
        #expect(!events.isEmpty)
        #expect(events.allSatisfy { $0.kind == .high || $0.kind == .low })
    }

    @Test func subordinateIntervalRequestIsRejected() throws {
        #expect(throws: NOAAError.rejected(message: "No Predictions data was found. Please make sure the Datum input is valid.")) {
            try NOAADecoder.samples(from: Fixture.data("kingharbor_9410738_15min_error"))
        }
    }

    @Test func invalidStationIsRejected() throws {
        #expect(throws: NOAAError.rejected(message: "The station is not a valid station or there is system error.")) {
            try NOAADecoder.events(from: Fixture.data("error_bad_station"))
        }
    }

    @Test func badDateIsRejected() throws {
        do {
            _ = try NOAADecoder.events(from: Fixture.data("error_bad_date"))
            Issue.record("expected rejection")
        } catch let error as NOAAError {
            guard case let .rejected(message) = error else { Issue.record("wrong error \(error)"); return }
            #expect(message.hasPrefix("Wrong Date"))
        }
    }

    @Test func throttleBodyIsRecognised() throws {
        #expect(throws: NOAAError.throttled) { try NOAADecoder.events(from: Fixture.data("error_throttled_403")) }
    }

    @Test func malformedValueFailsWholeResponse() throws {
        #expect(throws: NOAAError.malformedResponse) { try NOAADecoder.events(from: Fixture.data("malformed_value")) }
        #expect(throws: NOAAError.malformedResponse) { try NOAADecoder.events(from: Data("not json".utf8)) }
    }

    @Test func emptyPredictionsAreReported() throws {
        #expect(throws: NOAAError.noPredictions) { try NOAADecoder.events(from: Fixture.data("empty_predictions")) }
    }

    @Test func highLowRowWithoutTypeIsMalformed() throws {
        let data = Data(#"{"predictions":[{"t":"2026-11-15 00:00","v":"0.61"}]}"#.utf8)
        #expect(throws: NOAAError.malformedResponse) { try NOAADecoder.events(from: data) }
    }

    @Test func timestampsAreStrict() {
        #expect(NOAATimestamp.parse("2026-11-15 24:00") == nil)
        #expect(NOAATimestamp.parse("2026-13-01 00:00") == nil)
        #expect(NOAATimestamp.parse("2026-11-15") == nil)
        #expect(NOAATimestamp.parse("2026-12-31 23:59") != nil)
    }

    @Test func requestUsesDocumentedParameters() throws {
        let request = NOAARequest(stationID: "9410840", begin: utc("2026-11-15 12:00"), rangeHours: 48, interval: .highLow)
        let items = try #require(URLComponents(url: request.url, resolvingAgainstBaseURL: false)?.queryItems)
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        #expect(query["product"] == "predictions")
        #expect(query["time_zone"] == "gmt")
        #expect(query["units"] == "metric")
        #expect(query["datum"] == "MLLW")
        #expect(query["interval"] == "hilo")
        #expect(query["begin_date"] == "20261115 12:00")
        #expect(query["range"] == "48")
        #expect(query["application"] == "LittleTide_iOS")
        #expect(request.url.scheme == "https")
    }
}
