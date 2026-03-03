import SwiftSyntax

/// Query helpers for declaration-level syntax checks used by macro validation.
public enum DeclarationSyntaxQuery {
    /// Returns `true` when `modifiers` contains a modifier with an exact text match.
    public static func hasModifier(named name: String, in modifiers: DeclModifierListSyntax) -> Bool {
        modifiers.contains { modifier in
            modifier.name.text == name
        }
    }

    /// Returns `true` when `attributes` contains an attribute whose name matches `name`.
    public static func hasAttribute(named name: String, in attributes: AttributeListSyntax) -> Bool {
        attributes.contains { element in
            guard let attribute = element.as(AttributeSyntax.self) else {
                return false
            }

            return attributeNameMatches(attribute, name: name)
        }
    }

    /// Returns `true` when `attribute` has the expected base name, qualified or unqualified.
    public static func attributeNameMatches(_ attribute: AttributeSyntax, name: String) -> Bool {
        let attributeName = attribute.attributeName.trimmedDescription
        return attributeName == name || attributeName.hasSuffix(".\(name)")
    }

    /// Returns `true` when `type` matches the expected type name, ignoring whitespace.
    ///
    /// This supports both unqualified (`Foo`) and qualified (`Module.Foo`) spellings.
    public static func typeMatches(_ type: TypeSyntax, name: String) -> Bool {
        let normalized = type.trimmedDescription.filter { character in
            !character.isWhitespace
        }
        return normalized == name || normalized.hasSuffix(".\(name)")
    }

    /// Returns `true` when `variableDecl` is an instance property declaration.
    public static func isInstanceVariable(_ variableDecl: VariableDeclSyntax) -> Bool {
        !variableDecl.modifiers.contains { modifier in
            let name = modifier.name.text
            return name == "static" || name == "class"
        }
    }
}
