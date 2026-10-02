import Foundation
import SwiftData

enum Persistence {
    static func makeContainer(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let schema = Schema([WatchSession.self])
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else if let url {
            configuration = ModelConfiguration(schema: schema, url: url)
        } else {
            configuration = ModelConfiguration(schema: schema, url: try defaultStoreURL())
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// `Application Support/LanternKeeper.store`, creating the directory on first launch.
    static func defaultStoreURL() throws -> URL {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        return directory.appendingPathComponent("LanternKeeper.store")
    }
}
