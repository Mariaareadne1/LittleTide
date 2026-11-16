import SwiftUI
import TideKit
import TideUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var isChoosingCoast = false

    var body: some View {
        Group {
            if let station = model.station {
                CoastHomeView(station: station)
            } else {
                OnboardingView { isChoosingCoast = true }
            }
        }
        .sheet(isPresented: $isChoosingCoast) {
            CoastSearchView()
        }
    }
}
