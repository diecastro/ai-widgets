import Foundation
import Testing

enum Fixture {
    static func url(_ name: String) throws -> URL {
        try #require(Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: nil),
                     "missing fixture \(name)")
    }
    static func data(_ name: String) throws -> Data {
        try Data(contentsOf: url(name))
    }
}
