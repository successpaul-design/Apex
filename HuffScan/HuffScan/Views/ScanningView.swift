import SwiftUI
import RoomPlan

struct ScanningView: View {
    let scanMode: ScanMode
    let onComplete: (FloorPlan) -> Void

    @StateObject private var viewModel = ScanViewModel()
    @State private var showingNamePrompt = false
    @State private var planName = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // RoomCaptureView bridge
            RoomCaptureViewRepresentable(viewModel: viewModel)
                .ignoresSafeArea()

            // Top overlay
            VStack {
                if viewModel.isScanning {
                    HStack {
                        Image(systemName: "camera.viewfinder")
                            .font(.title3)
                        Text(scanMode == .singleRoom ? "Scanning Room..." : "Scanning House...")
                            .font(.headline)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 60)
                }

                Spacer()

                // Bottom controls
                if viewModel.isScanning {
                    Button(action: {
                        viewModel.stopSession()
                    }) {
                        Label("Done Scanning", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(Color("AccentColor"), in: Capsule())
                    }
                    .padding(.bottom, 40)
                }
            }

            // Error overlay
            if let error = viewModel.scanError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.yellow)
                    Text("Scan Error")
                        .font(.title2.bold())
                    Text(error)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Button("Try Again") {
                        viewModel.scanError = nil
                        viewModel.startSession()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(32)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .padding()
            }
        }
        .navigationBarBackButtonHidden(viewModel.isScanning)
        .toolbar {
            if !viewModel.isScanning {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            viewModel.scanMode = scanMode
            viewModel.startSession()
        }
        .onChange(of: viewModel.showResults) { _, showResults in
            if showResults {
                showingNamePrompt = true
            }
        }
        .alert("Name Your Floor Plan", isPresented: $showingNamePrompt) {
            TextField("e.g., First Floor", text: $planName)
            Button("Save") {
                let name = planName.isEmpty ? "Untitled Scan" : planName
                if let rawPlan = viewModel.convertToFloorPlan(name: name) {
                    let optimizer = FloorPlanOptimizer()
                    let optimizedPlan = optimizer.optimize(rawPlan)
                    onComplete(optimizedPlan)
                }
            }
            Button("Cancel", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Give this scan a name to identify it later.")
        }
    }
}

// MARK: - UIViewRepresentable Bridge

struct RoomCaptureViewRepresentable: UIViewRepresentable {
    let viewModel: ScanViewModel

    func makeUIView(context: Context) -> RoomCaptureView {
        return viewModel.roomCaptureView
    }

    func updateUIView(_ uiView: RoomCaptureView, context: Context) {}
}
