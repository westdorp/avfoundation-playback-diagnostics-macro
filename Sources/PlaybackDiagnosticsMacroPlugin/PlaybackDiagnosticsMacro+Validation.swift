import MacroPluginUtilities
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

extension PlaybackDiagnosticsMacro {
    private struct UsageValidation {
        let missingFinalModifier: Bool
        let missingMainActorAttribute: Bool
        let missingItemProperty: Bool
        let hasConflictingInitializer: Bool
        let hasConflictingDeinitializer: Bool
        let uninitializedProperties: [UninitializedStoredProperty]

        var isValidForGeneration: Bool {
            !missingFinalModifier
                && !missingMainActorAttribute
                && !missingItemProperty
                && !hasConflictingInitializer
                && !hasConflictingDeinitializer
                && uninitializedProperties.isEmpty
        }
    }

    static let macroManagedPropertyNames: Set<String> = ["item"]

    static func validateUsage(of declaration: some DeclGroupSyntax, in context: some MacroExpansionContext) -> Bool {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            context.diagnose(
                Diagnostic(
                    node: Syntax(declaration),
                    message: MacroDiagnosticMessage(
                        MacroDiagnosticText.compose(
                            what: "@PlaybackDiagnostics can only be applied to a final class.",
                            why: "The macro owns mutable notification lifecycle state that requires stable reference identity.",
                            how: "Apply @PlaybackDiagnostics to a declaration like '@MainActor final class PlayerDiagnostics { let item: AVPlayerItem }'."
                        ),
                        domain: diagnosticDomain,
                        id: "class-only"
                    )
                )
            )
            return false
        }

        let validation = usageValidation(for: classDecl)

        if validation.missingFinalModifier {
            let fixIts = [
                makeAddFinalFixIt(
                    for: classDecl,
                    fixItMessage: MacroFixItMessage(
                        "Add 'final' modifier",
                        domain: diagnosticDomain,
                        id: "add-final-modifier"
                    )
                ),
            ]

            context.diagnose(
                Diagnostic(
                    node: Syntax(classDecl.name),
                    message: MacroDiagnosticMessage(
                        MacroDiagnosticText.compose(
                            what: "@PlaybackDiagnostics can only be applied to a final class.",
                            why: "The macro owns mutable notification lifecycle state that requires stable reference identity.",
                            how: "Add the 'final' modifier to this class declaration."
                        ),
                        domain: diagnosticDomain,
                        id: "class-only"
                    ),
                    fixIts: fixIts
                )
            )
        }

        if validation.missingMainActorAttribute {
            let fixIts = [
                makeAddMainActorFixIt(
                    for: classDecl,
                    fixItMessage: MacroFixItMessage(
                        "Add '@MainActor' attribute",
                        domain: diagnosticDomain,
                        id: "add-mainactor-attribute"
                    )
                ),
            ]

            context.diagnose(
                Diagnostic(
                    node: Syntax(classDecl.name),
                    message: MacroDiagnosticMessage(
                        MacroDiagnosticText.compose(
                            what: "@PlaybackDiagnostics requires @MainActor isolation.",
                            why: "Notification callbacks mutate diagnostics state and must serialize on the main actor.",
                            how: "Annotate the type with '@MainActor'."
                        ),
                        domain: diagnosticDomain,
                        id: "mainactor-required"
                    ),
                    fixIts: fixIts
                )
            )
        }

        if validation.missingItemProperty {

            context.diagnose(
                Diagnostic(
                    node: Syntax(classDecl.name),
                    message: MacroDiagnosticMessage(
                        MacroDiagnosticText.compose(
                            what: "@PlaybackDiagnostics requires a stored instance property 'let item: AVPlayerItem'.",
                            why: "Diagnostics aggregation reads AVPlayerItem failure and log surfaces from this property.",
                            how: "Add 'let item: AVPlayerItem'."
                        ),
                        domain: diagnosticDomain,
                        id: "item-required"
                    )
                )
            )
        }

        if validation.hasConflictingInitializer {
            context.diagnose(
                Diagnostic(
                    node: Syntax(classDecl.name),
                    message: MacroDiagnosticMessage(
                        MacroDiagnosticText.compose(
                            what: "@PlaybackDiagnostics cannot synthesize 'init(item:)' because it is already declared.",
                            why: "The macro owns this initializer to wire diagnostics streams and notifications.",
                            how: "Remove the custom 'init(item:)' or remove @PlaybackDiagnostics and manage wiring manually."
                        ),
                        domain: diagnosticDomain,
                        id: "init-conflict"
                    )
                )
            )
        }

        if validation.hasConflictingDeinitializer {
            context.diagnose(
                Diagnostic(
                    node: Syntax(classDecl.name),
                    message: MacroDiagnosticMessage(
                        MacroDiagnosticText.compose(
                            what: "@PlaybackDiagnostics cannot synthesize 'deinit' because one is already declared.",
                            why: "The macro owns notification observer cleanup and stream completion in deinitialization.",
                            how: "Remove the custom 'deinit' or remove @PlaybackDiagnostics and manage diagnostics lifecycle manually."
                        ),
                        domain: diagnosticDomain,
                        id: "deinit-conflict"
                    )
                )
            )
        }

        for property in validation.uninitializedProperties {
            context.diagnose(
                Diagnostic(
                    node: property.syntax,
                    message: MacroDiagnosticMessage(
                        MacroDiagnosticText.compose(
                            what: "@PlaybackDiagnostics cannot synthesize 'init(item:)' because stored property '\(property.name)' is not initialized.",
                            why: "The synthesized initializer can only assign managed macro properties and 'item'.",
                            how: "Initialize this property inline or provide a custom initializer."
                        ),
                        domain: diagnosticDomain,
                        id: "unsupported-stored-property"
                    )
                )
            )
        }

        return validation.isValidForGeneration
    }

    static func canGenerateMembers(for classDecl: ClassDeclSyntax) -> Bool {
        usageValidation(for: classDecl).isValidForGeneration
    }

    private static func usageValidation(for classDecl: ClassDeclSyntax) -> UsageValidation {
        UsageValidation(
            missingFinalModifier: !DeclarationSyntaxQuery.hasModifier(
                named: "final",
                in: classDecl.modifiers
            ),
            missingMainActorAttribute: !DeclarationSyntaxQuery.hasAttribute(
                named: "MainActor",
                in: classDecl.attributes
            ),
            missingItemProperty: !hasStoredLetProperty(named: "item", typeNamed: "AVPlayerItem", in: classDecl),
            hasConflictingInitializer: hasConflictingInitializer(
                parameterLabel: "item",
                parameterType: "AVPlayerItem",
                in: classDecl
            ),
            hasConflictingDeinitializer: hasDeinitializer(in: classDecl),
            uninitializedProperties: uninitializedStoredProperties(
                in: classDecl,
                excludingManagedNames: macroManagedPropertyNames
            )
        )
    }
}
