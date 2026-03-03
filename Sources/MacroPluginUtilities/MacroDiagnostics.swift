import SwiftDiagnostics

/// Wraps a SwiftDiagnostics message with a stable domain/id pair.
public struct MacroDiagnosticMessage: DiagnosticMessage {
    /// Human-readable text shown in diagnostics output.
    public let message: String
    /// Stable identifier used by compiler diagnostics tooling.
    public let diagnosticID: MessageID
    /// Diagnostic severity. Defaults to `.error`.
    public let severity: DiagnosticSeverity

    /// Creates a diagnostic message with stable identity.
    public init(
        _ message: String,
        domain: String,
        id: String,
        severity: DiagnosticSeverity = .error
    ) {
        self.message = message
        self.diagnosticID = MessageID(domain: domain, id: id)
        self.severity = severity
    }
}

/// Wraps a SwiftDiagnostics fix-it message with a stable identifier.
public struct MacroFixItMessage: FixItMessage {
    /// Human-readable text shown in fix-it output.
    public let message: String
    /// Stable identifier used by compiler fix-it tooling.
    public let fixItID: MessageID

    /// Creates a fix-it message with stable identity.
    public init(_ message: String, domain: String, id: String) {
        self.message = message
        self.fixItID = MessageID(domain: domain, id: id)
    }
}

/// Builds a concise diagnostic sentence from `what`, optional `why`, and optional `how`.
///
/// This keeps messaging format consistent across macro plugins while allowing each plugin
/// to provide domain-specific content.
public enum MacroDiagnosticText {
    /// Composes a diagnostic message in `what + why + how` order for consistent macro UX.
    ///
    /// - Note: Empty fragments are ignored and internal whitespace is normalized.
    public static func compose(
        what: String,
        why: String? = nil,
        how: String? = nil
    ) -> String {
        [what, why, how]
            .compactMap { fragment in
                guard let fragment else {
                    return nil
                }

                let normalized = fragment
                    .split(whereSeparator: \.isWhitespace)
                    .joined(separator: " ")
                return normalized.isEmpty ? nil : normalized
            }
            .joined(separator: " ")
    }
}
