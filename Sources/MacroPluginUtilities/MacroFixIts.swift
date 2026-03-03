import SwiftDiagnostics
import SwiftSyntax

/// Builds a fix-it that ensures a class declaration is `final`.
///
/// If the declaration is `open`, the fix-it rewrites `open` to `public` before adding `final`
/// because `open final` is invalid Swift.
public func makeAddFinalFixIt(for classDecl: ClassDeclSyntax, fixItMessage: MacroFixItMessage) -> FixIt {
    var updatedClassDecl = classDecl

    if classDecl.modifiers.isEmpty {
        var classKeyword = classDecl.classKeyword
        let classLeadingTrivia = classKeyword.leadingTrivia
        classKeyword.leadingTrivia = []
        updatedClassDecl.classKeyword = classKeyword

        // Preserve the original declaration indentation/comments on the inserted modifier.
        let finalModifier = DeclModifierSyntax(
            leadingTrivia: classLeadingTrivia,
            name: .keyword(.final, trailingTrivia: .space)
        )
        updatedClassDecl.modifiers = DeclModifierListSyntax([finalModifier])
    } else {
        let hasPublicModifier = classDecl.modifiers.contains { modifier in
            modifier.name.tokenKind == .keyword(.public)
        }

        var rewrittenModifiers: [DeclModifierSyntax] = []
        rewrittenModifiers.reserveCapacity(classDecl.modifiers.count + 1)
        for modifier in classDecl.modifiers {
            guard modifier.name.tokenKind == .keyword(.open) else {
                rewrittenModifiers.append(modifier)
                continue
            }

            if !hasPublicModifier {
                var publicModifier = modifier
                publicModifier.name = .keyword(
                    .public,
                    leadingTrivia: modifier.name.leadingTrivia,
                    trailingTrivia: .space
                )
                rewrittenModifiers.append(publicModifier)
            }
        }

        rewrittenModifiers.append(
            DeclModifierSyntax(name: .keyword(.final, trailingTrivia: .space))
        )
        updatedClassDecl.modifiers = DeclModifierListSyntax(rewrittenModifiers)
    }

    return FixIt(
        message: fixItMessage,
        changes: [
            .replace(oldNode: Syntax(classDecl), newNode: Syntax(updatedClassDecl))
        ]
    )
}

/// Builds a fix-it that prepends `@MainActor` to a class declaration.
public func makeAddMainActorFixIt(for classDecl: ClassDeclSyntax, fixItMessage: MacroFixItMessage) -> FixIt {
    let mainActorAttribute = AttributeSyntax(
        atSign: .atSignToken(),
        attributeName: IdentifierTypeSyntax(name: .identifier("MainActor")),
        trailingTrivia: .newlines(1)
    )
    let updatedAttributes = AttributeListSyntax(
        [.attribute(mainActorAttribute)] + Array(classDecl.attributes)
    )

    return FixIt(
        message: fixItMessage,
        changes: [
            .replace(oldNode: Syntax(classDecl.attributes), newNode: Syntax(updatedAttributes))
        ]
    )
}
