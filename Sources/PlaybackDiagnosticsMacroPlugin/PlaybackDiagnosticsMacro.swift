import MacroPluginUtilities
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Implements `@PlaybackDiagnostics` member and extension generation.
public struct PlaybackDiagnosticsMacro: MemberMacro, ExtensionMacro {
    static let diagnosticDomain = "PlaybackDiagnosticsMacro"

    /// Generates diagnostics members for a validated `@PlaybackDiagnostics` declaration.
    public static func expansion(
        of _: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo _: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard validateUsage(of: declaration, in: context),
              declaration.as(ClassDeclSyntax.self) != nil
        else {
            return []
        }

        return [
            DeclSyntax(stringLiteral: buildPlaybackDiagnosticEventDeclaration()),
            DeclSyntax(stringLiteral: buildPlaybackFailureContextDeclaration()),
            """
            /// The most recent captured playback diagnostics snapshot.
            ///
            /// This snapshot updates for every diagnostics event, including log entries.
            /// - Important: Read this property from the main actor.
            private(set) var latestDiagnosticsContext: PlaybackFailureContext
            """,
            """
            /// The most recent captured playback failure snapshot.
            ///
            /// This value remains `nil` until a failure is observed on a failure surface.
            /// Once set, it is sticky and only changes when a newer failure snapshot is captured.
            /// - Important: Read this property from the main actor.
            private(set) var latestFailureContext: PlaybackFailureContext?
            """,
            """
            /// A stream of normalized playback diagnostics events.
            ///
            /// - Important: Consume this stream from the main actor.
            let playbackDiagnostics: AsyncStream<PlaybackDiagnosticEvent>
            """,
            """
            private let _diagnosticsContinuation: AsyncStream<PlaybackDiagnosticEvent>.Continuation
            """,
            """
            private var _notificationTokens: [NSObjectProtocol] = []
            """,
            DeclSyntax(stringLiteral: buildEmitDiagnosticsDeclaration()),
            DeclSyntax(stringLiteral: buildInitializerDeclaration()),
            """
            isolated deinit {
                for token in _notificationTokens {
                    NotificationCenter.default.removeObserver(token)
                }
                _diagnosticsContinuation.finish()
            }
            """,
        ]
    }

    /// Conditionally synthesizes `Sendable` conformance when the declaration does not
    /// already conform in source or lexical extension context.
    public static func expansion(
        of _: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo _: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self),
              canGenerateMembers(for: classDecl),
              !classHasExistingSendableConformance(classDecl, in: context)
        else {
            return []
        }

        return [try ExtensionDeclSyntax("extension \(type): Sendable {}")]
    }

    private static func classHasExistingSendableConformance(
        _ classDecl: ClassDeclSyntax,
        in context: some MacroExpansionContext
    ) -> Bool {
        hasSendableConformance(in: classDecl, lexicalContext: context.lexicalContext)
    }
}
