
public enum ScanResult {
    public enum DeclarationAnnotation {
        case unused
        case assignOnlyProperty
        case redundantProtocol(references: Set<Reference>)
        case redundantPublicAccessibility(modules: Set<String>)
    }

    case `import`(ImportStatement)
    case declaration(Declaration, DeclarationAnnotation)

    public var location: SourceLocation {
        switch self {
        case let .import(statement):
            return statement.location
        case let .declaration(declaration, _):
            return declaration.location
        }
    }
}
