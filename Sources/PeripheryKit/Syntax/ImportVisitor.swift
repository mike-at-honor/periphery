import SwiftSyntax

final class ImportVisitor: PeripherySyntaxVisitor {
    static func make(sourceLocationBuilder: SourceLocationBuilder) -> Self {
        self.init(sourceLocationBuilder: sourceLocationBuilder)
    }

    private let sourceLocationBuilder: SourceLocationBuilder

    var importStatements: [ImportStatement] = []

    init(sourceLocationBuilder: SourceLocationBuilder) {
        self.sourceLocationBuilder = sourceLocationBuilder
    }

    func visit(_ node: ImportDeclSyntax) {
        let parts = node.path.map { $0.name.text }
        let attributes = node.attributes?.compactMap { $0.as(AttributeSyntax.self)?.attributeName.text } ?? []
        let location = sourceLocationBuilder.location(at: node.positionAfterSkippingLeadingTrivia)
        let statement = ImportStatement(
            parts: parts,
            isTestable: attributes.contains("testable"),
            location: location)
        importStatements.append(statement)
    }
}
