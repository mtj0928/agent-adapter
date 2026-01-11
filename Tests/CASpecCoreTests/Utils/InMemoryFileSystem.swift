import Foundation
@testable import CASpecCore

final class InMemoryFileSystem: FileSystem {
    private enum Node {
        case file(Data)
        case directory(Set<String>)
    }

    private var nodes: [String: Node] = ["/": .directory([])]

    func fileExists(atPath: String) -> Bool {
        nodes[normalize(atPath)] != nil
    }

    func isDirectory(at url: URL) throws -> Bool {
        let path = normalize(url.path)
        guard let node = nodes[path] else {
            throw InMemoryFileSystemError.notFound(path)
        }
        if case .directory = node {
            return true
        }
        return false
    }

    func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws {
        let path = normalize(url.path)
        if path == "/" { return }

        let components = split(path)
        var currentPath = ""
        for (index, component) in components.enumerated() {
            currentPath += "/" + component
            if nodes[currentPath] == nil {
                if !withIntermediateDirectories && index != components.count - 1 {
                    throw InMemoryFileSystemError.missingParent(currentPath)
                }
                try insertDirectory(atPath: currentPath)
            } else if case .file = nodes[currentPath] {
                throw InMemoryFileSystemError.notDirectory(currentPath)
            }
        }
    }

    func contentsOfDirectory(at url: URL) throws -> [URL] {
        let path = normalize(url.path)
        guard case .directory(let children) = nodes[path] else {
            throw InMemoryFileSystemError.notDirectory(path)
        }
        return children.sorted().map { URL(fileURLWithPath: path).appendingPathComponent($0) }
    }

    func removeItem(at url: URL) throws {
        let path = normalize(url.path)
        guard let node = nodes[path] else {
            throw InMemoryFileSystemError.notFound(path)
        }
        if case .directory(let children) = node {
            for child in children {
                let childPath = path == "/" ? "/\(child)" : "\(path)/\(child)"
                try removeItem(at: URL(fileURLWithPath: childPath))
            }
        }
        nodes[path] = nil
        removeChild(path)
    }

    func copyItem(at sourceURL: URL, to destinationURL: URL) throws {
        let sourcePath = normalize(sourceURL.path)
        let destinationPath = normalize(destinationURL.path)
        guard let node = nodes[sourcePath] else {
            throw InMemoryFileSystemError.notFound(sourcePath)
        }
        switch node {
        case .file(let data):
            try writeData(data, toPath: destinationPath)
        case .directory(let children):
            try createDirectory(at: destinationURL, withIntermediateDirectories: true)
            for child in children {
                let childSource = URL(fileURLWithPath: sourcePath).appendingPathComponent(child)
                let childDestination = URL(fileURLWithPath: destinationPath).appendingPathComponent(child)
                try copyItem(at: childSource, to: childDestination)
            }
        }
    }

    func readData(at url: URL) throws -> Data {
        let path = normalize(url.path)
        guard case .file(let data) = nodes[path] else {
            throw InMemoryFileSystemError.notFile(path)
        }
        return data
    }

    func readString(at url: URL, encoding: String.Encoding) throws -> String {
        let data = try readData(at: url)
        guard let string = String(data: data, encoding: encoding) else {
            throw InMemoryFileSystemError.invalidString(url.path)
        }
        return string
    }

    func writeString(_ string: String, to url: URL, atomically: Bool, encoding: String.Encoding) throws {
        guard let data = string.data(using: encoding) else {
            throw InMemoryFileSystemError.invalidString(url.path)
        }
        try writeData(data, toPath: normalize(url.path))
    }

    private func writeData(_ data: Data, toPath path: String) throws {
        let parentPath = parent(of: path)
        guard case .directory = nodes[parentPath] else {
            throw InMemoryFileSystemError.missingParent(parentPath)
        }
        nodes[path] = .file(data)
        addChild(path)
    }

    private func insertDirectory(atPath path: String) throws {
        let parentPath = parent(of: path)
        guard case .directory = nodes[parentPath] else {
            throw InMemoryFileSystemError.missingParent(parentPath)
        }
        nodes[path] = .directory([])
        addChild(path)
    }

    private func addChild(_ path: String) {
        let parentPath = parent(of: path)
        guard case .directory(var children) = nodes[parentPath] else { return }
        let name = URL(fileURLWithPath: path).lastPathComponent
        children.insert(name)
        nodes[parentPath] = .directory(children)
    }

    private func removeChild(_ path: String) {
        let parentPath = parent(of: path)
        guard case .directory(var children) = nodes[parentPath] else { return }
        let name = URL(fileURLWithPath: path).lastPathComponent
        children.remove(name)
        nodes[parentPath] = .directory(children)
    }

    private func parent(of path: String) -> String {
        if path == "/" { return "/" }
        let url = URL(fileURLWithPath: path)
        let parent = url.deletingLastPathComponent().path
        return parent.isEmpty ? "/" : parent
    }

    private func split(_ path: String) -> [String] {
        path.split(separator: "/").map(String.init)
    }

    private func normalize(_ path: String) -> String {
        let normalized = URL(fileURLWithPath: path).standardizedFileURL.path
        return normalized.isEmpty ? "/" : normalized
    }
}

enum InMemoryFileSystemError: Error {
    case notFound(String)
    case notDirectory(String)
    case notFile(String)
    case missingParent(String)
    case invalidString(String)
}
