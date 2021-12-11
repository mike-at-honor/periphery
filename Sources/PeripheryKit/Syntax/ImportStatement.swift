public struct ImportStatement: Hashable {
    let parts: [String]
    let isTestable: Bool
    let location: SourceLocation

    public var path: String {
        parts.joined(separator: ".")
    }
}
