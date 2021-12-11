import Foundation
import IndexStoreDB

final class UnusedImportMarker: SourceGraphVisitor {
    static func make(graph: SourceGraph) -> Self {
        return self.init(graph: graph)
    }

    private let graph: SourceGraph
    private let db: IndexStoreDB

    required init(graph: SourceGraph) {
        self.graph = graph
        let lib = try! IndexStoreLibrary(dylibPath: "/Applications/Xcode13.2b2.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/libIndexStore.dylib")
        self.db = try! IndexStoreDB(
            storePath: graph.indexStorePath,
            databasePath: NSTemporaryDirectory() + "index_\(getpid())",
            library: lib,
            waitUntilDoneInitializing: true,
            listenToUnitEvents: false)
    }

    func visit() throws {
        for (file, references) in graph.allReferencesBySourceFile {
            let referencedUSRs: Set<String> = references.reduce(into: .init()) { result, reference in
                result.insert(reference.usr)
            }

            var fileRefs: [String: SymbolLocation] = [:]

            let referencedModules: Set<String> = referencedUSRs.reduce(into: .init()) { result, usr in
                var usrResults: Set<String> = []
                db.forEachSymbolOccurrence(byUSR: usr, roles: .definition) { occurrence in
                    fileRefs[usr] = occurrence.location
                    usrResults.insert(occurrence.location.moduleName)
                    return true
                }
                db.forEachSymbolOccurrence(byUSR: usr, roles: .declaration) { occurrence in
                    fileRefs[usr] = occurrence.location
                    usrResults.insert(occurrence.location.moduleName)
                    return true
                }
                result.formUnion(usrResults)
            }

            for importStatement in file.importStatements {
                if !referencedModules.contains(importStatement.parts.first!) {
                    graph.markUnusedImport(importStatement)
//                    print(file.path)
//                    print(referencedModules.sorted())
//                    fileRefs.forEach { print($0) }
//                    print("----------")
                }
            }
        }
    }
}
