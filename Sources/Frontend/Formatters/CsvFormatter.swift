import Shared
import PeripheryKit

final class CsvFormatter: OutputFormatter {
    static func make() -> Self {
        return self.init(logger: inject())
    }

    private let logger: Logger

    required init(logger: Logger) {
        self.logger = logger
    }

    func perform(_ results: [ScanResult]) {
        logger.info("Kind,Name,Modifiers,Attributes,Accessibility,IDs,Location,Hints", canQuiet: false)

        for result in results {
            switch result {
            case let .import(statement):
                // TODO
                break
            case let .declaration(declaration, annotation):
                let line = format(
                    kind: declaration.kind.rawValue,
                    name: declaration.name,
                    modifiers: declaration.modifiers,
                    attributes: declaration.attributes,
                    accessibility: declaration.accessibility.value.rawValue,
                    usrs: declaration.usrs,
                    location: declaration.location,
                    hint: describe(annotation)
                )
                logger.info(line, canQuiet: false)

                switch annotation {
                case let .redundantProtocol(references: references):
                    for ref in references {
                        let line = format(
                            kind: ref.kind.rawValue,
                            name: ref.name,
                            modifiers: [],
                            attributes: [],
                            accessibility: nil,
                            usrs: [ref.usr],
                            location: ref.location,
                            hint: redundantConformanceHint)
                        logger.info(line, canQuiet: false)
                    }
                default:
                    break
                }
            }
        }
    }

    // MARK: - Private

    private func format(
        kind: String,
        name: String?,
        modifiers: Set<String>,
        attributes: Set<String>,
        accessibility: String?,
        usrs: Set<String>,
        location: SourceLocation,
        hint: String?
    ) -> String {
        let joinedModifiers = attributes.joined(separator: "|")
        let joinedAttributes = modifiers.joined(separator: "|")
        let joinedUsrs = usrs.joined(separator: "|")
        return "\(kind),\(name ?? ""),\(joinedModifiers),\(joinedAttributes),\(accessibility ?? ""),\(joinedUsrs),\(location),\(hint ?? "")"
    }
}
