import SwiftUI

@main
struct NineNineNineRadioApp: App {
    @State private var library = RadioLibrary()
    @State private var player = RadioPlayer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
                .environment(player)
                .task {
                    await library.loadInitialContent()
                }
        }
    }
}
