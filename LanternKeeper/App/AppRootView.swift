import SwiftUI

struct AppRootView: View {
    @State private var harbour: HarbourModel

    init(environment: AppEnvironment) {
        _harbour = State(initialValue: HarbourModel(
            clock: environment.clock,
            preferences: environment.preferences,
            format: environment.format
        ))
    }

    var body: some View {
        HarbourView(model: harbour)
            .themed(.night)
            .preferredColorScheme(.dark)
    }
}
