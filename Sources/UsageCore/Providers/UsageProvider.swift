import Foundation

public enum ProviderError: Error, Equatable, Sendable {
    /// The provider's source does not exist yet — the tool has not run, or has
    /// never reported limits. Distinct from a failure: nothing is wrong.
    case noData(String)
    /// The source existed but could not be understood.
    case unreadable(String)
    /// The provider needs a credential that has not been supplied.
    case notConfigured
}

/// A provider maps one tool's on-disk or remote state to a ``ProviderSnapshot``.
///
/// Implementations are `nonisolated` so the caller decides where the work runs,
/// and take their source location by injection so each can be tested against a
/// fixture with no app, no Xcode target and no network.
public protocol UsageProvider: Sendable {
    var id: ProviderID { get }
    func fetch() async throws -> ProviderSnapshot
}
