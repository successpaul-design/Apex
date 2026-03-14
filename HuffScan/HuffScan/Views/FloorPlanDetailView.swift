import SwiftUI

struct FloorPlanDetailView: View {
    let floorPlan: FloorPlan
    @ObservedObject var viewModel: FloorPlanViewModel

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var rotation: Angle = .zero
    @State private var lastRotation: Angle = .zero
    @State private var showingLabelEditor = false
    @State private var tapLocation: CGPoint = .zero
    @State private var editingLabel: RoomLabel?
    @State private var showingExportSheet = false
    @State private var showingSettings = false
    @State private var showMeasurements = true
    @State private var selectedUnit: MeasurementUnit = .feet

    private var currentPlan: FloorPlan {
        viewModel.floorPlan(for: floorPlan.id) ?? floorPlan
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            // Floor plan with gestures
            FloorPlan2DRenderer(
                floorPlan: currentPlan,
                showMeasurements: showMeasurements,
                measurementUnit: selectedUnit,
                roomLabels: currentPlan.roomLabels,
                onTapLocation: { location in
                    tapLocation = location
                    editingLabel = nil
                    showingLabelEditor = true
                }
            )
            .scaleEffect(scale)
            .rotationEffect(rotation)
            .offset(offset)
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        let newScale = lastScale * value.magnification
                        scale = min(max(newScale, 0.5), 5.0)
                    }
                    .onEnded { _ in
                        lastScale = scale
                    }
            )
            .simultaneousGesture(
                RotationGesture()
                    .onChanged { value in
                        rotation = lastRotation + value
                    }
                    .onEnded { _ in
                        lastRotation = rotation
                    }
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
            )
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    withAnimation(.spring(response: 0.3)) {
                        scale = 1.0
                        lastScale = 1.0
                        offset = .zero
                        lastOffset = .zero
                        rotation = .zero
                        lastRotation = .zero
                    }
                }
            )

            // Zoom & rotation indicator
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    Text("\(Int(scale * 100))%")
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                    if abs(rotation.degrees) > 0.5 {
                        Text("\(Int(rotation.degrees))°")
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .navigationTitle(currentPlan.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // Measurements toggle
                Button {
                    showMeasurements.toggle()
                } label: {
                    Image(systemName: showMeasurements ? "ruler.fill" : "ruler")
                }

                // Unit toggle
                Menu {
                    ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                        Button {
                            selectedUnit = unit
                        } label: {
                            Label(unit.rawValue.capitalized, systemImage: selectedUnit == unit ? "checkmark" : "")
                        }
                    }
                } label: {
                    Text(selectedUnit.symbol)
                        .font(.caption.bold())
                }

                // Add label
                Button {
                    editingLabel = nil
                    showingLabelEditor = true
                } label: {
                    Image(systemName: "tag")
                }

                // Export
                Button {
                    showingExportSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }

                // Settings
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showingLabelEditor) {
            RoomLabelEditor(
                existingLabel: editingLabel,
                onSave: { label in
                    viewModel.addLabel(label, to: currentPlan.id)
                    showingLabelEditor = false
                },
                onDelete: editingLabel != nil ? {
                    if let label = editingLabel {
                        viewModel.removeLabel(label.id, from: currentPlan.id)
                    }
                    showingLabelEditor = false
                } : nil
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportSheet(
                floorPlan: currentPlan,
                measurementUnit: selectedUnit,
                showMeasurements: showMeasurements
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet()
                .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Settings Sheet

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Scan") {
                    SettingsRow(icon: "viewfinder", color: .blue, title: "Scan Quality", value: "High")
                    SettingsRow(icon: "square.dashed", color: .orange, title: "Auto-Detect Rooms", value: "On")
                }

                Section("Display") {
                    SettingsRow(icon: "lineweight", color: .purple, title: "Wall Thickness", value: "Standard")
                    SettingsRow(icon: "paintpalette", color: .pink, title: "Color Theme", value: "Default")
                    SettingsRow(icon: "textformat.size", color: .teal, title: "Label Size", value: "Medium")
                }

                Section("Export") {
                    SettingsRow(icon: "arrow.up.doc", color: .green, title: "Default Format", value: "PDF")
                    SettingsRow(icon: "aspectratio", color: .indigo, title: "Export Resolution", value: "2x")
                }

                Section("About") {
                    SettingsRow(icon: "info.circle", color: .gray, title: "Version", value: "1.0")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let color: Color
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 28)
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Export Sheet

struct ExportSheet: View {
    let floorPlan: FloorPlan
    let measurementUnit: MeasurementUnit
    let showMeasurements: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Export Floor Plan")
                    .font(.title2.bold())

                VStack(spacing: 16) {
                    ExportButton(
                        title: "Export as PDF",
                        subtitle: "High quality, scalable",
                        icon: "doc.fill",
                        color: .red
                    ) {
                        exportPDF()
                    }

                    ExportButton(
                        title: "Export as JPEG",
                        subtitle: "Image format, 2x resolution",
                        icon: "photo.fill",
                        color: .blue
                    ) {
                        exportJPEG()
                    }

                    ExportButton(
                        title: "Save to Camera Roll",
                        subtitle: "Save image to Photos",
                        icon: "photo.on.rectangle.angled",
                        color: .green
                    ) {
                        saveToCameraRoll()
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 24)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func exportPDF() {
        let data = ExportService.shared.generatePDF(
            floorPlan: floorPlan,
            unit: measurementUnit,
            showMeasurements: showMeasurements
        )
        shareData(data, filename: "\(floorPlan.name).pdf", mimeType: "application/pdf")
    }

    private func exportJPEG() {
        if let image = ExportService.shared.generateJPEG(
            floorPlan: floorPlan,
            unit: measurementUnit,
            showMeasurements: showMeasurements
        ) {
            let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
            presentActivityVC(activityVC)
        }
    }

    private func saveToCameraRoll() {
        if let image = ExportService.shared.generateJPEG(
            floorPlan: floorPlan,
            unit: measurementUnit,
            showMeasurements: showMeasurements
        ) {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            dismiss()
        }
    }

    private func shareData(_ data: Data, filename: String, mimeType: String) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: tempURL)
        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        presentActivityVC(activityVC)
    }

    private func presentActivityVC(_ vc: UIActivityViewController) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        topVC.present(vc, animated: true)
    }
}

struct ExportButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        }
    }
}
