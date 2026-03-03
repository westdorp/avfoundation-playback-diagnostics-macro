import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct PlaybackDiagnosticsMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        PlaybackDiagnosticsMacro.self,
    ]
}
