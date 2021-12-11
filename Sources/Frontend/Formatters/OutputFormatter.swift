import Shared
import PeripheryKit

protocol OutputFormatter: AnyObject {
    static func make() -> Self
    func perform(_ results: [ScanResult]) throws
}

extension OutputFormatter {
    var redundantConformanceHint: String { "redundantConformance" }

    func describe(_ annotation: ScanResult.DeclarationAnnotation) -> String {
        switch annotation {
        case .unused:
            return "unused"
        case .assignOnlyProperty:
            return "assignOnlyProperty"
        case .redundantProtocol(_):
            return "redundantProtocol"
        case .redundantPublicAccessibility:
            return "redundantPublicAccessibility"
        }
    }

    func describe(_ result: ScanResult, colored: Bool) -> [(SourceLocation, String)] {
        var description: String = ""
        var secondaryResults: [(SourceLocation, String)] = []

        switch result {
        case let .import(statement):
            let path = colored ? colorize(statement.path, .lightBlue) : statement.path
            description = "Module '\(path)' is unused"
        case let .declaration(declaration, annotation):
            if var name = declaration.name {
                if let kind = declaration.kind.displayName, let first_ = kind.first {
                    let first = String(first_)
                    description += "\(first.uppercased())\(kind.dropFirst()) "
                }

                name = colored ? colorize(name, .lightBlue) : name
                description += "'\(name)'"

                switch annotation {
                case .unused:
                    description += " is unused"
                case .assignOnlyProperty:
                    description += " is assigned, but never used"
                case let .redundantProtocol(references):
                    description += " is redundant as it's never used as an existential type"
                    secondaryResults = references.map {
                        ($0.location, "Protocol '\(name)' conformance is redundant")
                    }
                case let .redundantPublicAccessibility(modules):
                    let modulesJoined = modules.joined(separator: ", ")
                    description += " is declared public, but not used outside of \(modulesJoined)"
                }
            } else {
                description += "unused"
            }
        }

        return [(result.location, description)] + secondaryResults
    }
}

extension OutputFormat {
    var formatter: OutputFormatter.Type {
        switch self {
        case .xcode:
            return XcodeFormatter.self
        case .csv:
            return CsvFormatter.self
        case .json:
            return JsonFormatter.self
        case .checkstyle:
            return CheckstyleFormatter.self
        }
    }
}
