import Dispatch
import Foundation
import Testing
@testable import AgentAdapterCore

struct FileManagerFileSystemTests {
    @Test(.temporaryDirectory) func createsReadsAndListsFiles() throws {
        let fileSystem: FileSystem = FileManager.default
        let root = try temporaryRootPath()
        try fileSystem.createDirectory(at: root, withIntermediateDirectories: true)

        let fileURL = root.appendingPathComponent("file.txt")
        try fileSystem.writeString("Hello", to: fileURL, atomically: true, encoding: .utf8)

        let contents = try fileSystem.readString(at: fileURL, encoding: .utf8)
        #expect(contents == "Hello")
        #expect(fileSystem.fileExists(atPath: fileURL.path))
        #expect(try fileSystem.isDirectory(at: root))
        #expect(!(try fileSystem.isDirectory(at: fileURL)))

        let listed = try fileSystem.contentsOfDirectory(at: root)
            .map(\.lastPathComponent)
            .sorted()
        #expect(listed == ["file.txt"])
    }

    @Test(.temporaryDirectory) func copiesAndRemovesItems() throws {
        let fileSystem: FileSystem = FileManager.default
        let root = try temporaryRootPath()
        try fileSystem.createDirectory(at: root, withIntermediateDirectories: true)

        let original = root.appendingPathComponent("original.txt")
        try fileSystem.writeString("Copy Me", to: original, atomically: true, encoding: .utf8)

        let copy = root.appendingPathComponent("copy.txt")
        try fileSystem.copyItem(at: original, to: copy)

        let copiedContents = try fileSystem.readString(at: copy, encoding: .utf8)
        #expect(copiedContents == "Copy Me")

        try fileSystem.removeItem(at: original)
        #expect(!fileSystem.fileExists(atPath: original.path))
        #expect(fileSystem.fileExists(atPath: copy.path))
    }

    @Test(.temporaryDirectory) func serializesAccessToTheSameDirectory() throws {
        let directory = try temporaryRootPath().appendingPathComponent("skills")
        let firstEntered = DispatchSemaphore(value: 0)
        let releaseFirst = DispatchSemaphore(value: 0)
        let secondAttempted = DispatchSemaphore(value: 0)
        let secondEntered = DispatchSemaphore(value: 0)
        let completed = DispatchSemaphore(value: 0)
        let failed = DispatchSemaphore(value: 0)

        DispatchQueue.global().async {
            defer { completed.signal() }
            do {
                try FileManager.default.withExclusiveAccess(to: directory) {
                    firstEntered.signal()
                    releaseFirst.wait()
                }
            } catch { failed.signal() }
        }
        defer { releaseFirst.signal() }
        try #require(firstEntered.wait(timeout: .now() + 5) == .success)
        DispatchQueue.global().async {
            defer { completed.signal() }
            secondAttempted.signal()
            do {
                try FileManager.default.withExclusiveAccess(to: directory) { _ = secondEntered.signal() }
            } catch { failed.signal() }
        }
        try #require(secondAttempted.wait(timeout: .now() + 5) == .success)
        #expect(secondEntered.wait(timeout: .now() + .milliseconds(200)) == .timedOut)
        releaseFirst.signal()
        #expect(secondEntered.wait(timeout: .now() + 5) == .success)
        #expect(completed.wait(timeout: .now() + 5) == .success)
        #expect(completed.wait(timeout: .now() + 5) == .success)
        #expect(failed.wait(timeout: .now()) == .timedOut)
    }

    @Test(.temporaryDirectory) func throwsOnMissingPaths() throws {
        let fileSystem: FileSystem = FileManager.default
        let root = try temporaryRootPath()
        try fileSystem.createDirectory(at: root, withIntermediateDirectories: true)

        let missing = root.appendingPathComponent("missing")
        #expect(throws: FileSystemError.self) {
            _ = try fileSystem.isDirectory(at: missing)
        }
    }
}
