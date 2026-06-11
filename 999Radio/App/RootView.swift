import SwiftUI

struct RootView: View {
    @Environment(RadioLibrary.self) private var library
    @Environment(RadioPlayer.self) private var player
    @State private var selectedTab: AppTab = .library
    @State private var showPlayer = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                LibraryView(showPlayer: $showPlayer)
                    .tag(AppTab.library)
                    .tabItem { Label("Library", systemImage: "music.note.list") }

                HomeView(showPlayer: $showPlayer)
                    .tag(AppTab.home)
                    .tabItem { Label("Listen Now", systemImage: "play.circle.fill") }

                SettingsView()
                    .tag(AppTab.settings)
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            }
            .tint(.orange)

            if player.currentTrack != nil {
                MiniPlayer(showPlayer: $showPlayer)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 54)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.84), value: player.currentTrack?.id)
        .background(Color.radioBackground.ignoresSafeArea())
        .sheet(isPresented: $showPlayer) {
            FullPlayerView()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(28)
        }
        .task {
            while !Task.isCancelled {
                player.tick()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }
}

enum AppTab {
    case home
    case library
    case settings
}
