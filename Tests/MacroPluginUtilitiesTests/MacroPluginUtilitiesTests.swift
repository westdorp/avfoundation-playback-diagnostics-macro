import MacroPluginUtilities
import SwiftParser
import SwiftSyntax
import Testing

@Suite("Macro Plugin Utilities")
struct MacroPluginUtilitiesTests {
    @Test("Compose uses WHAT when WHY and HOW are missing")
    func composeUsesWhatOnlyWhenOptionalSegmentsAreMissing() {
        let message = MacroDiagnosticText.compose(
            what: "State enum is required."
        )

        #expect(message == "State enum is required.")
    }

    @Test(
        "Compose joins non-empty segments in WHAT-WHY-HOW order",
        arguments: [
            (
                what: "State enum is required.",
                why: "The state machine needs a finite state domain.",
                how: "Add nested enum State { ... }.",
                expected: "State enum is required. The state machine needs a finite state domain. Add nested enum State { ... }."
            ),
            (
                what: "Event marker is missing.",
                why: "   ",
                how: "\nAdd @PlaybackInput.\n",
                expected: "Event marker is missing. Add @PlaybackInput."
            ),
        ]
    )
    func composeNormalizesAndJoinsSegments(
        what: String,
        why: String?,
        how: String?,
        expected: String
    ) {
        let message = MacroDiagnosticText.compose(
            what: what,
            why: why,
            how: how
        )

        #expect(message == expected)
    }

    @Test("Detects Sendable conformance from inheritance clause")
    func hasSendableConformanceDetectsDirectInheritance() throws {
        let classDecl = try #require(
            parseClassDecl(
                from: """
                final class PlayerDiagnostics: Sendable {
                }
                """
            )
        )

        #expect(hasSendableConformance(in: classDecl))
    }

    @Test("Detects Sendable conformance from extension in same file")
    func hasSendableConformanceDetectsSameFileExtension() throws {
        let classDecl = try #require(
            parseClassDecl(
                from: """
                final class PlayerDiagnostics {
                }

                extension PlayerDiagnostics: Sendable {
                }
                """
            )
        )

        #expect(hasSendableConformance(in: classDecl))
    }

    @Test("Finds uninitialized stored properties excluding managed names")
    func uninitializedStoredPropertiesReturnsOnlyUnsupportedMembers() throws {
        let classDecl = try #require(
            parseClassDecl(
                from: """
                final class PlayerDiagnostics {
                    let item: AVPlayerItem
                    let requestID: String
                    var optionalRequestID: String?
                    var count: Int
                }
                """
            )
        )

        let properties = uninitializedStoredProperties(
            in: classDecl,
            excludingManagedNames: ["item"]
        )

        #expect(properties.map(\.name) == ["requestID", "count"])
    }
}

private func parseClassDecl(from source: String) -> ClassDeclSyntax? {
    let sourceFile = Parser.parse(source: source)

    return sourceFile.statements
        .compactMap { statement in
            statement.item.as(ClassDeclSyntax.self)
        }
        .first
}
