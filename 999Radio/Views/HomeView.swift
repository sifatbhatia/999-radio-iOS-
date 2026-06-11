import SwiftUI

struct HomeView: View {
    @Environment(RadioLibrary.self) private var library
    @Environment(RadioPlayer.self) private var player
    @Binding var showPlayer: Bool

    var body: some View {
        @Bindable var library = library
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HeroStats(stats: library.stats)

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                        TextField("Search the archive", text: $library.query)
                            .textInputAutocapitalization(.never)
                            .submitLabel(.search)
                            .onSubmit { Task { await library.search() } }
                    }
                    .padding(14)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    if !player.recentlyPlayed.isEmpty {
                        SectionHeader(title: "Recently Played", subtitle: "Your latest sessions")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(player.recentlyPlayed.prefix(12)) { track in
                                    TrackCard(track: track) {
                                        player.play(track, from: player.queue.isEmpty ? library.tracks : player.queue)
                                        showPlayer = true
                                    }
                                    .frame(width: 156)
                                }
                            }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    if !player.likedIDs.isEmpty {
                        let likedTracks = library.tracks.filter { player.likedIDs.contains($0.id) }
                        SectionHeader(title: "Liked Songs", subtitle: "\(likedTracks.count) saved tracks")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(likedTracks.prefix(12)) { track in
                                    TrackCard(track: track) {
                                        player.play(track, from: likedTracks)
                                        showPlayer = true
                                    }
                                    .frame(width: 156)
                                }
                            }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    SectionHeader(title: "All Songs", subtitle: "\(library.tracks.count) songs loaded from the API")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(library.tracks.prefix(8)) { track in
                            TrackCard(track: track) {
                                player.play(track, from: library.tracks)
                                showPlayer = true
                            }
                        }
                    }
                    .animation(.spring(response: 0.36, dampingFraction: 0.86), value: library.tracks.map(\.id))
                    .animation(.smooth(duration: 0.24), value: player.recentlyPlayed.map(\.id))
                    .animation(.smooth(duration: 0.24), value: player.likedIDs)

                    SectionHeader(title: "Up Next", subtitle: player.isShuffle ? "Shuffle is on" : "Sequential")
                    VStack(spacing: 8) {
                        ForEach(library.tracks.dropFirst(8).prefix(8)) { track in
                            TrackRow(track: track) {
                                player.play(track, from: library.tracks)
                            }
                        }
                    }
                    .animation(.spring(response: 0.34, dampingFraction: 0.88), value: library.tracks.map(\.id))
                }
                .padding(18)
                .padding(.bottom, 96)
            }
            .refreshable { await library.loadInitialContent() }
            .navigationTitle("999 Radio")
            .toolbarBackground(.hidden, for: .navigationBar)
            .overlay {
                if library.isLoading && library.tracks.isEmpty {
                    ProgressView("Tuning station...")
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
            }
            .animation(.smooth(duration: 0.25), value: library.isLoading)
            .alert("Signal lost", isPresented: .constant(library.errorMessage != nil)) {
                Button("Retry") { Task { await library.search() } }
                Button("Dismiss", role: .cancel) { library.errorMessage = nil }
            } message: {
                Text(library.errorMessage ?? "")
            }
        }
    }
}
