
public struct ScanResultBuilder {
    let graph: SourceGraph

    public init(graph: SourceGraph) {
        self.graph = graph
    }

    public func build() -> [ScanResult] {
        let assignOnlyProperties = graph.assignOnlyProperties
        let removableDeclarations = graph.unreachableDeclarations.subtracting(assignOnlyProperties)
        let redundantProtocols = graph.redundantProtocols.filter { !removableDeclarations.contains($0.0) }
        let redundantPublicAccessibility = graph.redundantPublicAccessibility.filter { !removableDeclarations.contains($0.0) }
        var results: [ScanResult] = []

        removableDeclarations.forEach {
            if shouldMakeResult(for: $0) {
                results.append(.declaration($0, .unused))
            }
        }
        assignOnlyProperties.forEach {
            if shouldMakeResult(for: $0) {
                results.append(.declaration($0, .assignOnlyProperty))
            }
        }
        redundantProtocols.forEach {
            if shouldMakeResult(for: $0.0) {
                results.append(.declaration($0.0, .redundantProtocol(references: $0.1)))
            }
        }
        redundantPublicAccessibility.forEach {
            if shouldMakeResult(for: $0.0) {
                results.append(.declaration($0.0, .redundantPublicAccessibility(modules: $0.1)))
            }
        }

        graph.unusedImports.forEach { results.append(.import($0)) }

        return results
    }

    // MARK: - Private

    private func shouldMakeResult(for declaration: Declaration) -> Bool {
        !declaration.isImplicit &&
        !declaration.kind.isAccessorKind &&
        !graph.ignoredDeclarations.contains(declaration)
    }
}
