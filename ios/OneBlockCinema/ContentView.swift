import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = FilmSessionViewModel()
    @State private var selectedTab: AppTab = .create

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Create", systemImage: "film", value: .create) {
                NavigationStack {
                    HomeView(viewModel: viewModel)
                }
            }

            Tab("My Films", systemImage: "rectangle.stack.fill", value: .films) {
                NavigationStack {
                    MyFilmsView(viewModel: viewModel)
                }
            }
        }
        .tint(CinemaColors.amber)
        .task {
            await viewModel.loadSessions()
        }
        .onChange(of: scenePhase) { _, phase in
            viewModel.handleScenePhase(phase)
        }
    }
}

nonisolated enum AppTab: String, Hashable, Sendable {
    case create
    case films
}
