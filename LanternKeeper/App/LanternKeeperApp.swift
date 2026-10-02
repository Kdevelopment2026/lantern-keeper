import SwiftUI

@main
struct LanternKeeperApp: App {
    @State private var environment = AppEnvironment.makeForLaunch()

    var body: some Scene {
        WindowGroup {
            AppRootView(environment: environment)
        }
    }
}
