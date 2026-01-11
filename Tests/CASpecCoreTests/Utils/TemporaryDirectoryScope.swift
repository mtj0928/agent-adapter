import Foundation
import Testing

func temporaryRootPath() throws -> URL {
    guard let rootPath = TemporaryDirectoryScope.rootPath else {
        throw TemporaryDirectoryScopeError.missingScope
    }
    return rootPath
}

// MARK: - TestScoping

struct TemporaryDirectoryScope: TestTrait, TestScoping {

    @TaskLocal fileprivate static var rootPath: URL?

    func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: () async throws -> Void
    ) async throws {
        let rootPath = try makeTemporaryRoot()
        defer {
            try? FileManager.default.removeItem(at: rootPath)
        }

        try await TemporaryDirectoryScope.$rootPath.withValue(rootPath) {
            try await function()
        }
    }

    private func makeTemporaryRoot() throws -> URL {
        let tempRoot = FileManager.default.temporaryDirectory
            .appending(components: "CASpec", "tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        return tempRoot
    }
}

extension TestTrait where Self == TemporaryDirectoryScope {
    static var temporaryDirectory: TemporaryDirectoryScope {
        TemporaryDirectoryScope()
    }
}

private enum TemporaryDirectoryScopeError: Error {
    case missingScope
}
