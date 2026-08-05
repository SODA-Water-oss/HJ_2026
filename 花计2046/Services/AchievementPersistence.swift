import Foundation

struct AchievementPersistence {
    let fileURL: URL

    init(fileURL: URL = AchievementPersistence.defaultFileURL()) {
        self.fileURL = fileURL
    }

    func load() -> AchievementSnapshot? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: fileURL),
           let snapshot = try? decoder.decode(AchievementSnapshot.self, from: data) {
            return snapshot
        }
        let backupURL = backupURL()
        if let data = try? Data(contentsOf: backupURL),
           let snapshot = try? decoder.decode(AchievementSnapshot.self, from: data) {
            return snapshot
        }
        return nil
    }

    func save(_ snapshot: AchievementSnapshot) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: backupURL())
            try? FileManager.default.copyItem(at: fileURL, to: backupURL())
        }
        try data.write(to: fileURL, options: .atomic)
    }

    private func backupURL() -> URL {
        URL(fileURLWithPath: fileURL.path + ".bak")
    }

    private static func defaultFileURL() -> URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = directory.appendingPathComponent("花计2046", isDirectory: true)
        return appDirectory.appendingPathComponent("achievements.json")
    }
}
