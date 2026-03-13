import Foundation
import SwiftUI

// MARK: - Measurement Unit

enum MeasurementUnit: String, Codable, CaseIterable {
    case feet
    case meters

    var symbol: String {
        switch self {
        case .feet: return "ft"
        case .meters: return "m"
        }
    }

    func convert(meters: Double) -> Double {
        switch self {
        case .feet: return meters * 3.28084
        case .meters: return meters
        }
    }

    func formatted(meters: Double) -> String {
        let value = convert(meters: meters)
        return String(format: "%.1f %@", value, symbol)
    }
}

// MARK: - 2D Geometry Types

struct Wall2D: Codable, Identifiable {
    let id: UUID
    var start: CGPoint
    var end: CGPoint
    var thickness: CGFloat
    var lengthMeters: Double

    init(start: CGPoint, end: CGPoint, thickness: CGFloat = 6.0, lengthMeters: Double) {
        self.id = UUID()
        self.start = start
        self.end = end
        self.thickness = thickness
        self.lengthMeters = lengthMeters
    }
}

struct Door2D: Codable, Identifiable {
    let id: UUID
    var position: CGPoint
    var width: CGFloat
    var angle: Double // rotation angle in radians
    var widthMeters: Double
    var isOpen: Bool

    init(position: CGPoint, width: CGFloat, angle: Double, widthMeters: Double, isOpen: Bool = false) {
        self.id = UUID()
        self.position = position
        self.width = width
        self.angle = angle
        self.widthMeters = widthMeters
        self.isOpen = isOpen
    }
}

struct Window2D: Codable, Identifiable {
    let id: UUID
    var start: CGPoint
    var end: CGPoint
    var widthMeters: Double

    init(start: CGPoint, end: CGPoint, widthMeters: Double) {
        self.id = UUID()
        self.start = start
        self.end = end
        self.widthMeters = widthMeters
    }
}

// MARK: - Room Label

struct RoomLabel: Codable, Identifiable {
    let id: UUID
    var name: String
    var position: CGPoint
    var colorHex: String

    init(name: String, position: CGPoint, colorHex: String = "#A8D8EA") {
        self.id = UUID()
        self.name = name
        self.position = position
        self.colorHex = colorHex
    }

    var color: Color {
        Color(hex: colorHex)
    }
}

// MARK: - Floor Plan

struct FloorPlan: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var createdAt: Date
    var walls: [Wall2D]
    var doors: [Door2D]
    var windows: [Window2D]
    var roomLabels: [RoomLabel]
    var usdzFileName: String?
    var boundingRect: CGRect

    init(
        name: String = "Untitled Scan",
        walls: [Wall2D] = [],
        doors: [Door2D] = [],
        windows: [Window2D] = [],
        roomLabels: [RoomLabel] = []
    ) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.walls = walls
        self.doors = doors
        self.windows = windows
        self.roomLabels = roomLabels
        self.usdzFileName = nil
        self.boundingRect = Self.computeBounds(walls: walls, doors: doors, windows: windows)
    }

    static func computeBounds(walls: [Wall2D], doors: [Door2D], windows: [Window2D]) -> CGRect {
        var allPoints: [CGPoint] = []
        for wall in walls {
            allPoints.append(wall.start)
            allPoints.append(wall.end)
        }
        for door in doors {
            allPoints.append(door.position)
        }
        for window in windows {
            allPoints.append(window.start)
            allPoints.append(window.end)
        }

        guard !allPoints.isEmpty else {
            return CGRect(x: 0, y: 0, width: 400, height: 400)
        }

        let minX = allPoints.map(\.x).min()! - 20
        let maxX = allPoints.map(\.x).max()! + 20
        let minY = allPoints.map(\.y).min()! - 20
        let maxY = allPoints.map(\.y).max()! + 20

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    // Hashable conformance using id only (for NavigationStack)
    static func == (lhs: FloorPlan, rhs: FloorPlan) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 168, 216, 234)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Pastel Colors

struct PastelColors {
    static let palette: [(name: String, hex: String)] = [
        ("Sky Blue", "#A8D8EA"),
        ("Lavender", "#D4A5FF"),
        ("Mint", "#A8E6CF"),
        ("Peach", "#FFD3B6"),
        ("Rose", "#FFAAA5"),
        ("Lemon", "#FCF4A3"),
        ("Lilac", "#C9B1FF"),
        ("Seafoam", "#88D8B0"),
    ]
}
