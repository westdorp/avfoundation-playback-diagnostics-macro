import MacroTesting
import SwiftSyntaxMacros
import Testing

#if canImport(PlaybackDiagnosticsMacroPlugin)
import PlaybackDiagnosticsMacroPlugin
#endif

private let testMacros: [String: Macro.Type] = {
    #if canImport(PlaybackDiagnosticsMacroPlugin)
    ["PlaybackDiagnostics": PlaybackDiagnosticsMacro.self]
    #else
    [:]
    #endif
}()

private func withPlaybackDiagnosticsMacroPlugin(_ body: () throws -> Void) throws {
    #if canImport(PlaybackDiagnosticsMacroPlugin)
    try body()
    #else
    Issue.record("macros are only supported when running tests for the host platform")
    #endif
}

@Suite("PlaybackDiagnostics Macro", .macros(testMacros))
struct PlaybackDiagnosticsTests {
    @Test("Generates notification lifecycle scaffolding")
    func playbackDiagnosticsGeneratesNotificationLifecycleScaffolding() throws {
        try withPlaybackDiagnosticsMacroPlugin {
            assertMacro {
                """
                @PlaybackDiagnostics
                @MainActor
                final class PlayerDiagnostics {
                    let item: AVPlayerItem
                }
                """
            } expansion: {
                expectedMacroExpansion(
                    classDeclaration: "@MainActor\nfinal class PlayerDiagnostics",
                    includeSendableExtension: true
                )
            }
        }
    }

    @Test("Rejects non-final declaration")
    func playbackDiagnosticsRequiresFinalClass() throws {
        try withPlaybackDiagnosticsMacroPlugin {
            assertMacro {
                """
                @PlaybackDiagnostics
                struct PlayerDiagnostics {}
                """
            } diagnostics: {
                """
                @PlaybackDiagnostics
                ╰─ 🛑 @PlaybackDiagnostics can only be applied to a final class. The macro owns mutable notification lifecycle state that requires stable reference identity. Apply @PlaybackDiagnostics to a declaration like '@MainActor final class PlayerDiagnostics { let item: AVPlayerItem }'.
                struct PlayerDiagnostics {}
                """
            }
        }
    }

    @Test("Adds final fix-it for class declarations")
    func playbackDiagnosticsAddsFinalFixItForClass() throws {
        try withPlaybackDiagnosticsMacroPlugin {
            assertMacro {
                """
                @PlaybackDiagnostics
                @MainActor
                class PlayerDiagnostics {
                    let item: AVPlayerItem
                }
                """
            } diagnostics: {
                """
                @PlaybackDiagnostics
                @MainActor
                class PlayerDiagnostics {
                      ┬────────────────
                      ╰─ 🛑 @PlaybackDiagnostics can only be applied to a final class. The macro owns mutable notification lifecycle state that requires stable reference identity. Add the 'final' modifier to this class declaration.
                         ✏️ Add 'final' modifier
                    let item: AVPlayerItem
                }
                """
            } fixes: {
                """
                @PlaybackDiagnostics
                @MainActor
                final class PlayerDiagnostics {
                    let item: AVPlayerItem
                }
                """
            } expansion: {
                expectedMacroExpansion(
                    classDeclaration: "@MainActor\nfinal class PlayerDiagnostics",
                    includeSendableExtension: true
                )
            }
        }
    }

    @Test("Rewrites open class to public final in fix-it")
    func playbackDiagnosticsRewritesOpenClassForFinalFixIt() throws {
        try withPlaybackDiagnosticsMacroPlugin {
            assertMacro {
                """
                @PlaybackDiagnostics
                @MainActor
                open class PlayerDiagnostics {
                    let item: AVPlayerItem
                }
                """
            } diagnostics: {
                """
                @PlaybackDiagnostics
                @MainActor
                open class PlayerDiagnostics {
                           ┬────────────────
                           ╰─ 🛑 @PlaybackDiagnostics can only be applied to a final class. The macro owns mutable notification lifecycle state that requires stable reference identity. Add the 'final' modifier to this class declaration.
                              ✏️ Add 'final' modifier
                    let item: AVPlayerItem
                }
                """
            } fixes: {
                """
                @PlaybackDiagnostics
                @MainActor
                public final class PlayerDiagnostics {
                    let item: AVPlayerItem
                }
                """
            } expansion: {
                expectedMacroExpansion(
                    classDeclaration: "@MainActor\npublic final class PlayerDiagnostics",
                    includeSendableExtension: true
                )
            }
        }
    }

    @Test("Requires item property")
    func playbackDiagnosticsRequiresItemProperty() throws {
        try withPlaybackDiagnosticsMacroPlugin {
            assertMacro {
                """
                @PlaybackDiagnostics
                @MainActor
                final class PlayerDiagnostics {}
                """
            } diagnostics: {
                """
                @PlaybackDiagnostics
                @MainActor
                final class PlayerDiagnostics {}
                            ┬────────────────
                            ╰─ 🛑 @PlaybackDiagnostics requires a stored instance property 'let item: AVPlayerItem'. Diagnostics aggregation reads AVPlayerItem failure and log surfaces from this property. Add 'let item: AVPlayerItem'.
                """
            }
        }
    }

    @Test("Rejects static item property")
    func playbackDiagnosticsRejectsStaticItemProperty() throws {
        try withPlaybackDiagnosticsMacroPlugin {
            assertMacro {
                """
                @PlaybackDiagnostics
                @MainActor
                final class PlayerDiagnostics {
                    static let item: AVPlayerItem
                }
                """
            } diagnostics: {
                """
                @PlaybackDiagnostics
                @MainActor
                final class PlayerDiagnostics {
                            ┬────────────────
                            ╰─ 🛑 @PlaybackDiagnostics requires a stored instance property 'let item: AVPlayerItem'. Diagnostics aggregation reads AVPlayerItem failure and log surfaces from this property. Add 'let item: AVPlayerItem'.
                    static let item: AVPlayerItem
                }
                """
            }
        }
    }

    @Test("Rejects preexisting synthesized initializer")
    func playbackDiagnosticsRejectsPreexistingSynthesizedInitializerSignature() throws {
        try withPlaybackDiagnosticsMacroPlugin {
            assertMacro {
                """
                @PlaybackDiagnostics
                @MainActor
                final class PlayerDiagnostics {
                    let item: AVPlayerItem

                    init(item: AVPlayerItem) {
                        self.item = item
                    }
                }
                """
            } diagnostics: {
                """
                @PlaybackDiagnostics
                @MainActor
                final class PlayerDiagnostics {
                            ┬────────────────
                            ╰─ 🛑 @PlaybackDiagnostics cannot synthesize 'init(item:)' because it is already declared. The macro owns this initializer to wire diagnostics streams and notifications. Remove the custom 'init(item:)' or remove @PlaybackDiagnostics and manage wiring manually.
                    let item: AVPlayerItem

                    init(item: AVPlayerItem) {
                        self.item = item
                    }
                }
                """
            }
        }
    }

    @Test("Rejects preexisting deinitializer")
    func playbackDiagnosticsRejectsPreexistingDeinitializer() throws {
        try withPlaybackDiagnosticsMacroPlugin {
            assertMacro {
                """
                @PlaybackDiagnostics
                @MainActor
                final class PlayerDiagnostics {
                    let item: AVPlayerItem

                    deinit {
                    }
                }
                """
            } diagnostics: {
                """
                @PlaybackDiagnostics
                @MainActor
                final class PlayerDiagnostics {
                            ┬────────────────
                            ╰─ 🛑 @PlaybackDiagnostics cannot synthesize 'deinit' because one is already declared. The macro owns notification observer cleanup and stream completion in deinitialization. Remove the custom 'deinit' or remove @PlaybackDiagnostics and manage diagnostics lifecycle manually.
                    let item: AVPlayerItem

                    deinit {
                    }
                }
                """
            }
        }
    }

    @Test("Skips generated Sendable extension when class already conforms")
    func playbackDiagnosticsSkipsSendableExtensionWhenClassAlreadyConforms() throws {
        try withPlaybackDiagnosticsMacroPlugin {
            assertMacro {
                """
                @PlaybackDiagnostics
                @MainActor
                final class PlayerDiagnostics: Sendable {
                    let item: AVPlayerItem
                }
                """
            } expansion: {
                expectedMacroExpansion(
                    classDeclaration: "@MainActor\nfinal class PlayerDiagnostics: Sendable",
                    includeSendableExtension: false
                )
            }
        }
    }

    @Test("Rejects unsupported uninitialized stored properties")
    func playbackDiagnosticsRejectsUninitializedUnsupportedStoredProperties() throws {
        try withPlaybackDiagnosticsMacroPlugin {
            assertMacro {
                """
                @PlaybackDiagnostics
                @MainActor
                final class PlayerDiagnostics {
                    let item: AVPlayerItem
                    let requestID: String
                }
                """
            } diagnostics: {
                """
                @PlaybackDiagnostics
                @MainActor
                final class PlayerDiagnostics {
                    let item: AVPlayerItem
                    let requestID: String
                        ┬────────
                        ╰─ 🛑 @PlaybackDiagnostics cannot synthesize 'init(item:)' because stored property 'requestID' is not initialized. The synthesized initializer can only assign managed macro properties and 'item'. Initialize this property inline or provide a custom initializer.
                }
                """
            }
        }
    }

    @Test("Allows optional var with implicit nil initialization")
    func playbackDiagnosticsAllowsImplicitlyInitializedOptionalVar() throws {
        try withPlaybackDiagnosticsMacroPlugin {
            assertMacro {
                """
                @PlaybackDiagnostics
                @MainActor
                final class PlayerDiagnostics {
                    let item: AVPlayerItem
                    var requestID: String?
                }
                """
            } expansion: {
                expectedMacroExpansion(
                    classDeclaration: "@MainActor\nfinal class PlayerDiagnostics",
                    additionalTypeMembers: ["var requestID: String?"],
                    includeSendableExtension: true
                )
            }
        }
    }

    @Test("Requires MainActor isolation")
    func playbackDiagnosticsRequiresMainActorIsolation() throws {
        try withPlaybackDiagnosticsMacroPlugin {
            assertMacro {
                """
                @PlaybackDiagnostics
                final class PlayerDiagnostics {
                    let item: AVPlayerItem
                }
                """
            } diagnostics: {
                """
                @PlaybackDiagnostics
                final class PlayerDiagnostics {
                            ┬────────────────
                            ╰─ 🛑 @PlaybackDiagnostics requires @MainActor isolation. Notification callbacks mutate diagnostics state and must serialize on the main actor. Annotate the type with '@MainActor'.
                               ✏️ Add '@MainActor' attribute
                    let item: AVPlayerItem
                }
                """
            } fixes: {
                """
                @MainActor
                @PlaybackDiagnostics
                final class PlayerDiagnostics {
                    let item: AVPlayerItem
                }
                """
            } expansion: {
                expectedMacroExpansion(
                    classDeclaration: "@MainActor\nfinal class PlayerDiagnostics",
                    includeSendableExtension: true
                )
            }
        }
    }
}
