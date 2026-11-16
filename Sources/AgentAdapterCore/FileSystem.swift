#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import Foundation

/// Abstraction over filesystem operations used by AgentAdapter.
public protocol FileSystem {
    /// Runs an operation while holding an exclusive lock on the directory.
    /// Implementations must serialize operations across processes sharing this directory.
    func withExclusiveAccess<T>(to directory: URL, perform: () throws -> T) throws -> T

    /// Returns true if a filesystem entry exists at the provided path.
    func fileExists(atPath: String) -> Bool

    /// Returns true if the URL points to a directory, throws if the entry is missing.
    func isDirectory(at url: URL) throws -> Bool

    /// Creates a directory at the given URL.
    func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws

    /// Returns direct children of the given directory URL.
    func contentsOfDirectory(at url: URL) throws -> [URL]

    /// Removes the item at the given URL.
    func removeItem(at url: URL) throws

    /// Copies an item from the source URL to the destination URL.
    func copyItem(at sourceURL: URL, to destinationURL: URL) throws

    /// Reads raw data from the given URL.
    func readData(at url: URL) throws -> Data

    /// Reads a string from the given URL using the provided encoding.
    func readString(at url: URL, encoding: String.Encoding) throws -> String

    /// Writes a string to the given URL using the provided encoding.
    func writeString(_ string: String, to url: URL, atomically: Bool, encoding: String.Encoding) throws
}

extension FileManager: FileSystem {
    public func withExclusiveAccess<T>(to directory: URL, perform: () throws -> T) throws -> T {
        try createDirectory(at: directory, withIntermediateDirectories: true)
        let descriptor = open(directory.path, O_RDONLY)
        guard descriptor != -1 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        defer { close(descriptor) }
        while flock(descriptor, LOCK_EX) == -1 {
            if errno != EINTR { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        }
        defer { flock(descriptor, LOCK_UN) }
        return try perform()
    }

    public func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws {
        try createDirectory(at: url, withIntermediateDirectories: withIntermediateDirectories, attributes: nil)
    }

    public func isDirectory(at url: URL) throws -> Bool {
        var isDirectory: ObjCBool = false
        let exists = fileExists(atPath: url.path, isDirectory: &isDirectory)
        if !exists {
            throw FileSystemError.notFound(url)
        }
        return isDirectory.boolValue
    }

    public func contentsOfDirectory(at url: URL) throws -> [URL] {
        try contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
    }

    public func readData(at url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    public func readString(at url: URL, encoding: String.Encoding) throws -> String {
        try String(contentsOf: url, encoding: encoding)
    }

    public func writeString(_ string: String, to url: URL, atomically: Bool, encoding: String.Encoding) throws {
        try string.write(to: url, atomically: atomically, encoding: encoding)
    }
}

enum FileSystemError: Error {
    case notFound(URL)
}
