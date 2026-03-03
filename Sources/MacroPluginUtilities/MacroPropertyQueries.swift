import SwiftSyntax

/// Captures an uninitialized stored property discovered in source.
public struct UninitializedStoredProperty {
    /// Property identifier text.
    public let name: String
    /// Syntax node for diagnostic anchoring.
    public let syntax: Syntax

    /// Creates a property record for validation diagnostics.
    public init(name: String, syntax: Syntax) {
        self.name = name
        self.syntax = syntax
    }
}

/// Returns `true` when `classDecl` contains a stored instance `let` with matching name and type.
public func hasStoredLetProperty(
    named propertyName: String,
    typeNamed typeName: String,
    in classDecl: ClassDeclSyntax
) -> Bool {
    classDecl.memberBlock.members.contains { member in
        guard let variableDecl = member.decl.as(VariableDeclSyntax.self),
              variableDecl.bindingSpecifier.tokenKind == .keyword(.let),
              DeclarationSyntaxQuery.isInstanceVariable(variableDecl)
        else {
            return false
        }

        return variableDecl.bindings.contains { binding in
            guard binding.accessorBlock == nil,
                  let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self),
                  identifierPattern.identifier.text == propertyName,
                  let typeAnnotation = binding.typeAnnotation
            else {
                return false
            }

            let type = typeAnnotation.type.trimmedDescription
            return type == typeName || type.hasSuffix(".\(typeName)")
        }
    }
}

/// Returns stored properties that remain uninitialized in source.
///
/// - Note: Validation runs before macro member synthesis, so macro-generated members are
///   intentionally excluded from this check.
public func uninitializedStoredProperties(
    in classDecl: ClassDeclSyntax,
    excludingManagedNames managedPropertyNames: Set<String>
) -> [UninitializedStoredProperty] {
    classDecl.memberBlock.members.flatMap { member -> [UninitializedStoredProperty] in
        guard let variableDecl = member.decl.as(VariableDeclSyntax.self),
              DeclarationSyntaxQuery.isInstanceVariable(variableDecl)
        else {
            return []
        }

        return variableDecl.bindings.compactMap { binding in
            guard binding.accessorBlock == nil,
                  binding.initializer == nil,
                  let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self),
                  !bindingHasImplicitDefaultInitialization(
                      variableDecl: variableDecl,
                      binding: binding
                  )
            else {
                return nil
            }

            let propertyName = identifierPattern.identifier.text
            guard !managedPropertyNames.contains(propertyName) else {
                return nil
            }

            return UninitializedStoredProperty(
                name: propertyName,
                syntax: Syntax(identifierPattern.identifier)
            )
        }
    }
}

/// Returns `true` when `classDecl` declares `init(parameterLabel: parameterType:)`.
///
/// - Note: This helper intentionally matches only a single-parameter initializer shape.
public func hasConflictingInitializer(
    parameterLabel: String,
    parameterType: String,
    in classDecl: ClassDeclSyntax
) -> Bool {
    classDecl.memberBlock.members.contains { member in
        guard let initializerDecl = member.decl.as(InitializerDeclSyntax.self) else {
            return false
        }

        let parameters = initializerDecl.signature.parameterClause.parameters
        guard parameters.count == 1, let parameter = parameters.first else {
            return false
        }

        let hasExpectedLabel = parameter.firstName.text == parameterLabel
        let hasExpectedType = DeclarationSyntaxQuery.typeMatches(parameter.type, name: parameterType)
        return hasExpectedLabel && hasExpectedType
    }
}

/// Returns `true` when `classDecl` already declares a deinitializer.
public func hasDeinitializer(in classDecl: ClassDeclSyntax) -> Bool {
    classDecl.memberBlock.members.contains { member in
        member.decl.is(DeinitializerDeclSyntax.self)
    }
}

private func bindingHasImplicitDefaultInitialization(
    variableDecl: VariableDeclSyntax,
    binding: PatternBindingSyntax
) -> Bool {
    guard variableDecl.bindingSpecifier.tokenKind == .keyword(.var),
          let typeAnnotation = binding.typeAnnotation
    else {
        return false
    }

    return isOptionalType(typeAnnotation.type)
}

private func isOptionalType(_ type: TypeSyntax) -> Bool {
    if type.is(OptionalTypeSyntax.self) || type.is(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
        return true
    }

    if let attributedType = type.as(AttributedTypeSyntax.self) {
        return isOptionalType(attributedType.baseType)
    }

    return false
}
