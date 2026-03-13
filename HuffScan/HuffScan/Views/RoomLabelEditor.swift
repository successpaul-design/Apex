import SwiftUI

struct RoomLabelEditor: View {
    let existingLabel: RoomLabel?
    let onSave: (RoomLabel) -> Void
    var onDelete: (() -> Void)?

    @State private var name: String = ""
    @State private var selectedColorHex: String = PastelColors.palette[0].hex
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(existingLabel != nil ? "Edit Room Label" : "Add Room Label")
                    .font(.title2.bold())

                // Name field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Room Name")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("e.g., Living Room, Kitchen, Bedroom", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                }
                .padding(.horizontal)

                // Color picker
                VStack(alignment: .leading, spacing: 12) {
                    Text("Label Color")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(PastelColors.palette, id: \.hex) { color in
                            Button {
                                selectedColorHex = color.hex
                            } label: {
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(hex: color.hex))
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: selectedColorHex == color.hex ? 3 : 0)
                                        )
                                    Text(color.name)
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Preview
                HStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: selectedColorHex).opacity(0.3))
                        .frame(height: 36)
                        .overlay(
                            Text(name.isEmpty ? "Room Name" : name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(name.isEmpty ? .secondary : .white)
                        )
                }
                .padding(.horizontal)

                Spacer()

                // Delete button
                if let onDelete = onDelete {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Remove Label", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top, 20)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let label = RoomLabel(
                            name: name.isEmpty ? "Room" : name,
                            position: existingLabel?.position ?? CGPoint(x: 200, y: 200),
                            colorHex: selectedColorHex
                        )
                        onSave(label)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty && existingLabel == nil)
                }
            }
        }
        .onAppear {
            if let existing = existingLabel {
                name = existing.name
                selectedColorHex = existing.colorHex
            }
        }
    }
}
