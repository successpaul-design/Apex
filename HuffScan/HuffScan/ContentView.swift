import SwiftUI

struct ContentView: View {
    @StateObject private var floorPlanVM = FloorPlanViewModel()
    @State private var showingScanModeSheet = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            HomeView(
                viewModel: floorPlanVM,
                onNewScan: { showingScanModeSheet = true },
                navigationPath: $navigationPath
            )
            .navigationDestination(for: FloorPlan.self) { plan in
                FloorPlanDetailView(
                    floorPlan: plan,
                    viewModel: floorPlanVM
                )
            }
            .navigationDestination(for: ScanMode.self) { mode in
                ScanningView(scanMode: mode) { newPlan in
                    floorPlanVM.addFloorPlan(newPlan)
                    navigationPath = NavigationPath()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        navigationPath.append(newPlan)
                    }
                }
            }
        }
        .tint(Color("AccentColor"))
        .confirmationDialog("Scan Mode", isPresented: $showingScanModeSheet) {
            Button("Single Room") {
                navigationPath.append(ScanMode.singleRoom)
            }
            Button("Whole House") {
                navigationPath.append(ScanMode.multiRoom)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose how you'd like to scan")
        }
    }
}

enum ScanMode: Hashable {
    case singleRoom
    case multiRoom
}
