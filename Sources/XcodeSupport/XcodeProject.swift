import Foundation
import XcodeProj
import SystemPackage
import PeripheryKit
import Shared

final class XcodeProject: XcodeProjectlike {
    private static var cache: [FilePath: XcodeProject] = [:]

    static func tryMake(path: FilePath, referencedBy refPath: FilePath) throws -> XcodeProject? {
        if !path.exists {
            let logger: Logger = inject()
            logger.warn("No such project exists at '\(path.lexicallyNormalized())', referenced by '\(refPath)'.")
            return nil
        }

        return try make(path: path)
    }

    static func make(path: FilePath) throws -> XcodeProject {
        if let cached = cache[path] {
            return cached
        }

        return try self.init(path: path, xcodebuild: inject(), logger: inject())
    }

    let type: String = "project"
    let path: FilePath
    let sourceRoot: FilePath
    let xcodeProject: XcodeProj
    let name: String

    private let xcodebuild: Xcodebuild

    private(set) var targets: Set<XcodeTarget> = []
    private(set) var packages: Set<SPM.Package> = []

    required init(path: FilePath, xcodebuild: Xcodebuild, logger: Logger) throws {
        logger.contextualized(with: "xcode:project").debug("Loading \(path)")

        self.path = path
        self.xcodebuild = xcodebuild
        self.name = self.path.lastComponent?.stem ?? ""
        self.sourceRoot = self.path.removingLastComponent()

        do {
            self.xcodeProject = try XcodeProj(pathString: self.path.lexicallyNormalized().string)
        } catch let error {
            throw PeripheryError.underlyingError(error)
        }

        // Cache before loading sub-projects to avoid infinite loop from cyclic project references.
        XcodeProject.cache[path] = self

        var subProjects: [XcodeProject] = []

        // Don't search for sub projects within CocoaPods.
        if !path.components.contains("Pods.xcodeproj") {
            subProjects = try xcodeProject.pbxproj.fileReferences
                .filter { $0.path?.hasSuffix(".xcodeproj") ?? false }
                .compactMap { try $0.fullPath(sourceRoot: sourceRoot.string) }
                .compactMap { try XcodeProject.tryMake(path: FilePath($0), referencedBy: path) }
        }

        targets = Set(xcodeProject.pbxproj.nativeTargets
            .map { XcodeTarget(project: self, target: $0) }
            + subProjects.flatMap { $0.targets })

        let shouldLoadPackages = targets.contains { $0.hasPackageProductDependencies }

        if shouldLoadPackages {
            // The project file does not provide a clear way to identify file references for local SPM packages.
            // We need to iterate over all references and check for folders containing a Package.swift file.
            for fileRef in xcodeProject.pbxproj.fileReferences {
                // To avoid checking every single file reference, narrow our search down to the known file types Xcode uses
                // for package references.
                let lastKnownFileType = fileRef.lastKnownFileType

                guard (lastKnownFileType == "text" || lastKnownFileType == "wrapper"),
                      let fullPath = try fileRef.fullPath(sourceRoot: sourceRoot.string)
                else { continue }

                let packagePath = FilePath(fullPath)

                if packagePath.appending("Package.swift").exists {
                    try packagePath.chdir {
                        // TODO log dir?
                        let package = try SPM.Package.load()
                        packages.insert(package)
                    }
                }
            }
        }
    }

    func schemes() throws -> Set<XcodeScheme> {
        let schemes = try xcodebuild.schemes(project: self).map {
            try XcodeScheme.make(project: self, name: $0)
        }
        return Set(schemes)
    }
}

extension XcodeProject: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(path.lexicallyNormalized().string)
    }
}

extension XcodeProject: Equatable {
    static func == (lhs: XcodeProject, rhs: XcodeProject) -> Bool {
        return lhs.path == rhs.path
    }
}
