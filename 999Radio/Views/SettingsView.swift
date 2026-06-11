import SwiftUI

struct SettingsView: View {
    @Environment(RadioLibrary.self) private var library
    @Environment(RadioPlayer.self) private var player

    var body: some View {
        NavigationStack {
            Form {
                Section("Source") {
                    LabeledContent("API", value: "juicewrldapi.com")
                    LabeledContent("State", value: "Persisted locally")
                    LabeledContent("App", value: "Native SwiftUI")
                }

                Section("Stats") {
                    LabeledContent("Songs", value: String(library.stats?.totalSongs ?? library.tracks.count))
                    LabeledContent("Released", value: String(library.stats?.releasedSongs ?? library.released.count))
                    LabeledContent("Unreleased", value: String(library.stats?.unreleasedSongs ?? library.unreleased.count))
                }

                Section("Library") {
                    LabeledContent("Liked", value: String(player.likedIDs.count))
                    LabeledContent("Recently Played", value: String(player.recentlyPlayed.count))
                    LabeledContent("Queue", value: String(player.queue.count))
                    LabeledContent("Repeat", value: player.repeatMode.title)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.radioBackground)
            .navigationTitle("Settings")
        }
    }
}
