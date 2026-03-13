import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: FloorPlanViewModel
    let onNewScan: () -> Void
    @Binding var navigationPath: NavigationPath

    var body: some View {
        ZStack {
            Color(hex: "#0E1117").ignoresSafeArea()

            if viewModel.floorPlans.isEmpty {
                emptyState
            } else {
                floorPlanList
            }
        }
        .navigationTitle("Huff Scan")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onNewScan) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 64))
                .foregroundColor(Color("AccentColor"))

            VStack(spacing: 8) {
                Text("No Floor Plans Yet")
                    .font(.title2.bold())
                Text("Scan a room with your iPhone's LiDAR\nsensor to create a 2D floor plan.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onNewScan) {
                Label("Start Scanning", systemImage: "camera.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color("AccentColor"), in: Capsule())
            }
            .padding(.top, 8)

            // Feature highlights
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "viewfinder", title: "LiDAR Scanning", subtitle: "Walk through rooms to capture walls, doors & windows")
                FeatureRow(icon: "ruler", title: "Measurements", subtitle: "Automatic dimensions in feet or meters")
                FeatureRow(icon: "tag", title: "Room Labels", subtitle: "Name and color-code each room")
                FeatureRow(icon: "square.and.arrow.up", title: "Export", subtitle: "Share as PDF or JPEG")
            }
            .padding(.top, 24)
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Floor Plan List

    private var floorPlanList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // New scan card
                Button(action: onNewScan) {
                    HStack(spacing: 14) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(Color("AccentColor"))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("New Scan")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Single room or whole house")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color("AccentColor").opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color("AccentColor").opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Saved plans
                ForEach(viewModel.floorPlans) { plan in
                    Button {
                        navigationPath.append(plan)
                    } label: {
                        FloorPlanCard(plan: plan)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.deleteFloorPlan(id: plan.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Floor Plan Card

struct FloorPlanCard: View {
    let plan: FloorPlan

    var body: some View {
        HStack(spacing: 14) {
            // Mini preview
            FloorPlanMiniPreview(plan: plan)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(plan.name)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label("\(plan.walls.count) walls", systemImage: "square")
                    if !plan.doors.isEmpty {
                        Label("\(plan.doors.count) doors", systemImage: "door.left.hand.open")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)

                Text(plan.createdAt, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Mini Preview

struct FloorPlanMiniPreview: View {
    let plan: FloorPlan

    var body: some View {
        Canvas { context, size in
            let bounds = plan.boundingRect
            guard bounds.width > 0 && bounds.height > 0 else { return }

            let scaleX = size.width / bounds.width
            let scaleY = size.height / bounds.height
            let scale = min(scaleX, scaleY) * 0.8

            let offsetX = (size.width - bounds.width * scale) / 2 - bounds.origin.x * scale
            let offsetY = (size.height - bounds.height * scale) / 2 - bounds.origin.y * scale

            func transform(_ point: CGPoint) -> CGPoint {
                CGPoint(x: point.x * scale + offsetX, y: point.y * scale + offsetY)
            }

            for wall in plan.walls {
                var path = Path()
                path.move(to: transform(wall.start))
                path.addLine(to: transform(wall.end))
                context.stroke(path, with: .color(.white.opacity(0.6)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }
        .background(Color(hex: "#1A1D24"))
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(Color("AccentColor"))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
