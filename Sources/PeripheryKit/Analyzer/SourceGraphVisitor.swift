
protocol SourceGraphVisitor: AnyObject {
    static func make(graph: SourceGraph) -> Self
    func visit() throws
}
