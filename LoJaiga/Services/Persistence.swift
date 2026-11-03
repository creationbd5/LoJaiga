import Foundation

/// Small JSON-file store in Application Support. Writes happen off the main thread.
enum Persistence {
    private static let queue = DispatchQueue(label: "com.lojaiga.io", qos: .utility)

    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("LoJaiga", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func load<T: Decodable>(_ type: T.Type, name: String) -> T? {
        let url = directory.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func save<T: Encodable>(_ value: T, name: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        let url = directory.appendingPathComponent(name)
        queue.async {
            try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
    }

    static func delete(name: String) {
        let url = directory.appendingPathComponent(name)
        queue.async { try? FileManager.default.removeItem(at: url) }
    }
}
