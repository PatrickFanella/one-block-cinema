import SwiftUI

struct ContentView: View {
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
    }
}

nonisolated enum AppTab: String, Hashable, Sendable {
    case create
    case films
}
