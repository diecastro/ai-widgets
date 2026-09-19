import Foundation
import Testing
@testable import UsageCore

/// Guards the app/widget contract: whatever the app writes, the widget must be
/// able to decode. A silent decode failure here is indistinguishable from "no
/// data yet" on screen, which is exactly how it went wrong once.
@Suite("Store round trip against a real file")
struct RealSnapshotTests {

    @Test func `decodes a snapshot written by the running app`() throws {
        let url = URL(fileURLWithPath: "/tmp/readcheck-snapshot.json")
        let data = try #require(try? Data(contentsOf: url),
                                "no captured snapshot; run the app first")
        let store = SnapshotStore(fileURL: url)
        let snapshot = store.read()
        #expect(!snapshot.providers.isEmpty, "decode produced no providers")
        #expect(snapshot.providers.contains { $0.provider == .claudeCode })
        _ = data
    }
}
