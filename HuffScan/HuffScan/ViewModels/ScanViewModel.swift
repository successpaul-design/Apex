import Foundation
import RoomPlan
import SwiftUI
import simd

class ScanViewModel: ObservableObject {
    @Published var capturedRoom: CapturedRoom?
    @Published var isScanning = false
    @Published var scanError: String?
    @Published var showResults = false

    let roomCaptureView = RoomCaptureView(frame: .zero)
    var scanMode: ScanMode = .singleRoom
    private var capturedRooms: [CapturedRoom] = []
    private var delegate: ScanViewDelegate?

    init() {
        let del = ScanViewDelegate(viewModel: self)
        self.delegate = del
        roomCaptureView.delegate = del
    }

    func startSession() {
        isScanning = true
        scanError = nil
        capturedRoom = nil
        capturedRooms = []

        let config = RoomCaptureSession.Configuration()
        roomCaptureView.captureSession.run(configuration: config)
    }

    func stopSession() {
        isScanning = false
        roomCaptureView.captureSession.stop()
    }

    // MARK: - 3D to 2D Conversion

    func convertToFloorPlan(name: String = "Untitled Scan") -> FloorPlan? {
        guard let room = capturedRoom else { return nil }

        let pixelsPerMeter: CGFloat = 100.0

        var walls2D: [Wall2D] = []
        var doors2D: [Door2D] = []
        var windows2D: [Window2D] = []

        for surface in room.walls {
            walls2D.append(convertSurfaceToWall2D(surface: surface, scale: pixelsPerMeter))
        }
        for surface in room.doors {
            doors2D.append(convertSurfaceToDoor2D(surface: surface, scale: pixelsPerMeter))
        }
        for surface in room.windows {
            windows2D.append(convertSurfaceToWindow2D(surface: surface, scale: pixelsPerMeter))
        }

        let (normalizedWalls, normalizedDoors, normalizedWindows) = normalizeCoordinates(
            walls: walls2D, doors: doors2D, windows: windows2D
        )

        return FloorPlan(
            name: name,
            walls: normalizedWalls,
            doors: normalizedDoors,
            windows: normalizedWindows
        )
    }

    private func convertSurfaceToWall2D(surface: CapturedRoom.Surface, scale: CGFloat) -> Wall2D {
        let transform = surface.transform
        let dimensions = surface.dimensions

        let posX = CGFloat(transform.columns.3.x)
        let posZ = CGFloat(transform.columns.3.z)
        let halfWidth = CGFloat(dimensions.x) / 2.0
        let rotY = atan2(Double(transform.columns.0.z), Double(transform.columns.0.x))

        let dx = halfWidth * CGFloat(cos(rotY))
        let dz = halfWidth * CGFloat(sin(rotY))

        let start = CGPoint(x: (posX - dx) * scale, y: (posZ - dz) * scale)
        let end = CGPoint(x: (posX + dx) * scale, y: (posZ + dz) * scale)

        return Wall2D(start: start, end: end, thickness: 6.0, lengthMeters: Double(dimensions.x))
    }

    private func convertSurfaceToDoor2D(surface: CapturedRoom.Surface, scale: CGFloat) -> Door2D {
        let transform = surface.transform
        let dimensions = surface.dimensions

        let posX = CGFloat(transform.columns.3.x) * scale
        let posZ = CGFloat(transform.columns.3.z) * scale
        let rotY = atan2(Double(transform.columns.0.z), Double(transform.columns.0.x))
        let doorWidth = CGFloat(dimensions.x) * scale

        var isOpen = false
        if case .door(let open) = surface.category {
            isOpen = open
        }

        return Door2D(
            position: CGPoint(x: posX, y: posZ),
            width: doorWidth,
            angle: rotY,
            widthMeters: Double(dimensions.x),
            isOpen: isOpen
        )
    }

    private func convertSurfaceToWindow2D(surface: CapturedRoom.Surface, scale: CGFloat) -> Window2D {
        let transform = surface.transform
        let dimensions = surface.dimensions

        let posX = CGFloat(transform.columns.3.x)
        let posZ = CGFloat(transform.columns.3.z)
        let halfWidth = CGFloat(dimensions.x) / 2.0
        let rotY = atan2(Double(transform.columns.0.z), Double(transform.columns.0.x))

        let dx = halfWidth * CGFloat(cos(rotY))
        let dz = halfWidth * CGFloat(sin(rotY))

        let start = CGPoint(x: (posX - dx) * scale, y: (posZ - dz) * scale)
        let end = CGPoint(x: (posX + dx) * scale, y: (posZ + dz) * scale)

        return Window2D(start: start, end: end, widthMeters: Double(dimensions.x))
    }

    private func normalizeCoordinates(
        walls: [Wall2D],
        doors: [Door2D],
        windows: [Window2D]
    ) -> ([Wall2D], [Door2D], [Window2D]) {
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

        guard !allPoints.isEmpty else { return (walls, doors, windows) }

        let minX = allPoints.map(\.x).min()! - 40
        let minY = allPoints.map(\.y).min()! - 40
        let offset = CGPoint(x: -minX, y: -minY)

        let normalizedWalls = walls.map { wall in
            Wall2D(
                start: CGPoint(x: wall.start.x + offset.x, y: wall.start.y + offset.y),
                end: CGPoint(x: wall.end.x + offset.x, y: wall.end.y + offset.y),
                thickness: wall.thickness,
                lengthMeters: wall.lengthMeters
            )
        }

        let normalizedDoors = doors.map { door in
            Door2D(
                position: CGPoint(x: door.position.x + offset.x, y: door.position.y + offset.y),
                width: door.width,
                angle: door.angle,
                widthMeters: door.widthMeters,
                isOpen: door.isOpen
            )
        }

        let normalizedWindows = windows.map { window in
            Window2D(
                start: CGPoint(x: window.start.x + offset.x, y: window.start.y + offset.y),
                end: CGPoint(x: window.end.x + offset.x, y: window.end.y + offset.y),
                widthMeters: window.widthMeters
            )
        }

        return (normalizedWalls, normalizedDoors, normalizedWindows)
    }
}

// MARK: - Separate Delegate (RoomCaptureViewDelegate requires NSCoding)

class ScanViewDelegate: NSObject, RoomCaptureViewDelegate, NSCoding {
    weak var viewModel: ScanViewModel?

    init(viewModel: ScanViewModel) {
        self.viewModel = viewModel
        super.init()
    }

    // NSCoding conformance (required by RoomCaptureViewDelegate)
    required init?(coder: NSCoder) {
        super.init()
    }

    func encode(with coder: NSCoder) {}

    // MARK: - RoomCaptureViewDelegate

    func captureView(shouldPresent roomDataForProcessing: CapturedRoom, error: (Error)?) -> Bool {
        if let error = error {
            DispatchQueue.main.async {
                self.viewModel?.scanError = error.localizedDescription
            }
        }
        return true
    }

    func captureView(didPresent processedResult: CapturedRoom, error: (Error)?) {
        DispatchQueue.main.async {
            if let error = error {
                self.viewModel?.scanError = error.localizedDescription
                return
            }
            self.viewModel?.capturedRoom = processedResult
            self.viewModel?.isScanning = false
            self.viewModel?.showResults = true
        }
    }
}
