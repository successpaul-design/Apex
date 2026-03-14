import Foundation
import SwiftUI

/// Post-scan optimizer that cleans up raw LiDAR wall data into a professional floor plan.
/// Performs wall straightening, corner snapping, room detection, and auto-labeling — all on-device.
struct FloorPlanOptimizer {

    // MARK: - Configuration

    /// Max angle deviation (radians) to snap a wall to the nearest cardinal direction
    private let angleSnapThreshold: Double = .pi / 12  // 15°

    /// Max distance (in scaled units) to merge two wall endpoints into one corner
    private let cornerMergeDistance: CGFloat = 15.0

    /// Max gap to extend a wall endpoint to meet another wall's line
    private let cornerExtendDistance: CGFloat = 25.0

    /// Scale used during conversion (pixels per meter)
    private let pixelsPerMeter: CGFloat = 100.0

    // MARK: - Main Entry

    func optimize(_ plan: FloorPlan) -> FloorPlan {
        var walls = plan.walls

        // Step 1: Snap wall angles to nearest 0°/90°/180°/270°
        walls = straightenWalls(walls)

        // Step 2: Merge close endpoints into shared corners
        walls = mergeCorners(walls)

        // Step 3: Extend walls to meet at clean T-joints and L-joints
        walls = extendToIntersections(walls)

        // Step 4: Detect rooms and generate labels
        let roomLabels = detectRooms(walls: walls, doors: plan.doors, openings: plan.openings)

        return FloorPlan(
            name: plan.name,
            walls: walls,
            doors: plan.doors,
            windows: plan.windows,
            openings: plan.openings,
            fixtures: plan.fixtures,
            roomLabels: roomLabels
        )
    }

    // MARK: - Step 1: Wall Straightening

    /// Snaps each wall's angle to the nearest cardinal direction (0°, 90°, 180°, 270°)
    /// if within the threshold. Preserves the wall's midpoint and length.
    private func straightenWalls(_ walls: [Wall2D]) -> [Wall2D] {
        return walls.map { wall in
            let dx = wall.end.x - wall.start.x
            let dy = wall.end.y - wall.start.y
            let angle = atan2(dy, dx)
            let length = hypot(dx, dy)
            let mid = CGPoint(x: (wall.start.x + wall.end.x) / 2,
                              y: (wall.start.y + wall.end.y) / 2)

            // Find nearest cardinal angle
            let cardinals: [Double] = [0, .pi / 2, .pi, -.pi / 2, -.pi]
            var bestAngle = angle
            var bestDiff = Double.infinity

            for cardinal in cardinals {
                let diff = abs(angleDifference(angle, cardinal))
                if diff < bestDiff {
                    bestDiff = diff
                    bestAngle = cardinal
                }
            }

            // Only snap if close enough
            guard bestDiff < angleSnapThreshold else {
                return wall
            }

            let halfLen = length / 2
            let newDx = halfLen * CGFloat(cos(bestAngle))
            let newDy = halfLen * CGFloat(sin(bestAngle))
            let newStart = CGPoint(x: mid.x - newDx, y: mid.y - newDy)
            let newEnd = CGPoint(x: mid.x + newDx, y: mid.y + newDy)

            return Wall2D(start: newStart, end: newEnd,
                          thickness: wall.thickness, lengthMeters: wall.lengthMeters)
        }
    }

    // MARK: - Step 2: Corner Merging

    /// Finds wall endpoints that are close together and merges them to a single point.
    private func mergeCorners(_ walls: [Wall2D]) -> [Wall2D] {
        var result = walls

        // Collect all endpoints with their indices and which end (start/end)
        struct Endpoint {
            let wallIndex: Int
            let isStart: Bool
            var point: CGPoint
        }

        var endpoints: [Endpoint] = []
        for (i, wall) in result.enumerated() {
            endpoints.append(Endpoint(wallIndex: i, isStart: true, point: wall.start))
            endpoints.append(Endpoint(wallIndex: i, isStart: false, point: wall.end))
        }

        // Group close endpoints using union-find
        var groups: [[Int]] = []  // groups of endpoint indices
        var assigned = Set<Int>()

        for i in 0..<endpoints.count {
            guard !assigned.contains(i) else { continue }
            var group = [i]
            assigned.insert(i)

            for j in (i + 1)..<endpoints.count {
                guard !assigned.contains(j) else { continue }
                let dist = hypot(endpoints[i].point.x - endpoints[j].point.x,
                                 endpoints[i].point.y - endpoints[j].point.y)
                if dist < cornerMergeDistance {
                    group.append(j)
                    assigned.insert(j)
                }
            }

            if group.count > 1 {
                groups.append(group)
            }
        }

        // Merge each group to centroid
        for group in groups {
            let avgX = group.map { endpoints[$0].point.x }.reduce(0, +) / CGFloat(group.count)
            let avgY = group.map { endpoints[$0].point.y }.reduce(0, +) / CGFloat(group.count)
            let merged = CGPoint(x: avgX, y: avgY)

            for idx in group {
                let ep = endpoints[idx]
                if ep.isStart {
                    result[ep.wallIndex] = Wall2D(
                        start: merged, end: result[ep.wallIndex].end,
                        thickness: result[ep.wallIndex].thickness,
                        lengthMeters: result[ep.wallIndex].lengthMeters
                    )
                } else {
                    result[ep.wallIndex] = Wall2D(
                        start: result[ep.wallIndex].start, end: merged,
                        thickness: result[ep.wallIndex].thickness,
                        lengthMeters: result[ep.wallIndex].lengthMeters
                    )
                }
            }
        }

        return result
    }

    // MARK: - Step 3: Extend to Intersections

    /// Extends wall endpoints to meet nearby wall lines, forming clean T-joints and L-joints.
    private func extendToIntersections(_ walls: [Wall2D]) -> [Wall2D] {
        var result = walls

        for i in 0..<result.count {
            for j in 0..<result.count where i != j {
                // Try extending wall i's start to wall j's line
                if let projected = projectPointOntoSegment(result[i].start,
                                                           segStart: result[j].start,
                                                           segEnd: result[j].end) {
                    let dist = hypot(result[i].start.x - projected.x,
                                     result[i].start.y - projected.y)
                    if dist > 1 && dist < cornerExtendDistance {
                        result[i] = Wall2D(
                            start: projected, end: result[i].end,
                            thickness: result[i].thickness,
                            lengthMeters: result[i].lengthMeters
                        )
                    }
                }

                // Try extending wall i's end to wall j's line
                if let projected = projectPointOntoSegment(result[i].end,
                                                           segStart: result[j].start,
                                                           segEnd: result[j].end) {
                    let dist = hypot(result[i].end.x - projected.x,
                                     result[i].end.y - projected.y)
                    if dist > 1 && dist < cornerExtendDistance {
                        result[i] = Wall2D(
                            start: result[i].start, end: projected,
                            thickness: result[i].thickness,
                            lengthMeters: result[i].lengthMeters
                        )
                    }
                }
            }
        }

        return result
    }

    // MARK: - Step 4: Room Detection

    /// Detects enclosed rooms using grid-based flood fill, then auto-labels them.
    private func detectRooms(walls: [Wall2D], doors: [Door2D], openings: [Opening2D]) -> [RoomLabel] {
        guard !walls.isEmpty else { return [] }

        // Compute bounds
        var allPoints: [CGPoint] = []
        for wall in walls {
            allPoints.append(wall.start)
            allPoints.append(wall.end)
        }
        let minX = allPoints.map(\.x).min()! - 10
        let maxX = allPoints.map(\.x).max()! + 10
        let minY = allPoints.map(\.y).min()! - 10
        let maxY = allPoints.map(\.y).max()! + 10

        let gridScale: CGFloat = 4.0  // each grid cell = 4 scaled units
        let gridW = Int((maxX - minX) / gridScale) + 1
        let gridH = Int((maxY - minY) / gridScale) + 1

        guard gridW > 0, gridH > 0, gridW < 2000, gridH < 2000 else { return [] }

        // Rasterize walls onto grid
        var grid = Array(repeating: Array(repeating: 0, count: gridW), count: gridH)

        for wall in walls {
            rasterizeLine(
                grid: &grid,
                x0: (wall.start.x - minX) / gridScale,
                y0: (wall.start.y - minY) / gridScale,
                x1: (wall.end.x - minX) / gridScale,
                y1: (wall.end.y - minY) / gridScale,
                thickness: max(wall.thickness / gridScale, 2)
            )
        }

        // Flood fill from edges (mark exterior as -1)
        floodFill(grid: &grid, startX: 0, startY: 0, fillValue: -1)

        // Find remaining unfilled regions (rooms)
        var roomId = 1
        var roomCells: [Int: [(Int, Int)]] = [:]

        for y in 0..<gridH {
            for x in 0..<gridW {
                if grid[y][x] == 0 {
                    roomId += 1
                    floodFill(grid: &grid, startX: x, startY: y, fillValue: roomId)
                    // Collect cells for this room
                    var cells: [(Int, Int)] = []
                    for ry in 0..<gridH {
                        for rx in 0..<gridW {
                            if grid[ry][rx] == roomId {
                                cells.append((rx, ry))
                            }
                        }
                    }
                    if cells.count >= 4 {  // Minimum room size
                        roomCells[roomId] = cells
                    }
                }
            }
        }

        // Convert room cells to labels
        var labels: [RoomLabel] = []
        let sortedRooms = roomCells.sorted { $0.value.count > $1.value.count }

        for (index, (_, cells)) in sortedRooms.enumerated() {
            // Compute centroid in original coordinates
            let avgX = cells.map { CGFloat($0.0) }.reduce(0, +) / CGFloat(cells.count)
            let avgY = cells.map { CGFloat($0.1) }.reduce(0, +) / CGFloat(cells.count)
            let centroid = CGPoint(x: avgX * gridScale + minX,
                                   y: avgY * gridScale + minY)

            // Estimate area in square meters
            let cellAreaSqm = (gridScale / pixelsPerMeter) * (gridScale / pixelsPerMeter)
            let areaSqm = Double(cells.count) * Double(cellAreaSqm)

            // Estimate dimensions for naming heuristic
            let roomMinX = cells.map(\.0).min()!
            let roomMaxX = cells.map(\.0).max()!
            let roomMinY = cells.map(\.1).min()!
            let roomMaxY = cells.map(\.1).max()!
            let widthM = Double(roomMaxX - roomMinX) * Double(gridScale) / Double(pixelsPerMeter)
            let heightM = Double(roomMaxY - roomMinY) * Double(gridScale) / Double(pixelsPerMeter)

            // Check if room has doors
            let hasDoor = doors.contains { door in
                let dist = hypot(door.position.x - centroid.x, door.position.y - centroid.y)
                return dist < CGFloat(max(widthM, heightM)) * pixelsPerMeter * 0.8
            }

            let roomName = classifyRoom(
                areaSqm: areaSqm,
                widthM: widthM,
                heightM: heightM,
                hasDoor: hasDoor,
                roomIndex: index,
                totalRooms: sortedRooms.count
            )

            let colorIndex = index % PastelColors.palette.count
            labels.append(RoomLabel(
                name: roomName,
                position: centroid,
                colorHex: PastelColors.palette[colorIndex].hex
            ))
        }

        return labels
    }

    // MARK: - Room Classification

    private func classifyRoom(
        areaSqm: Double,
        widthM: Double,
        heightM: Double,
        hasDoor: Bool,
        roomIndex: Int,
        totalRooms: Int
    ) -> String {
        let aspect = max(widthM, heightM) / max(min(widthM, heightM), 0.1)

        // Narrow corridor/hallway
        if aspect > 3.0 && min(widthM, heightM) < 2.0 {
            return "HALLWAY"
        }

        // Very small — likely closet or bathroom
        if areaSqm < 3.0 {
            return "CLOSET"
        }
        if areaSqm < 5.0 {
            return "BATHROOM"
        }

        // Small room
        if areaSqm < 10.0 {
            return "BEDROOM"
        }

        // Medium room
        if areaSqm < 16.0 {
            if roomIndex == 0 {
                return "LIVING ROOM"
            }
            return "BEDROOM"
        }

        // Large room — likely living/dining or open plan
        if areaSqm < 25.0 {
            return "LIVING ROOM"
        }

        // Very large — open plan
        return "GREAT ROOM"
    }

    // MARK: - Geometry Helpers

    private func angleDifference(_ a: Double, _ b: Double) -> Double {
        var diff = a - b
        while diff > .pi { diff -= 2 * .pi }
        while diff < -.pi { diff += 2 * .pi }
        return diff
    }

    /// Projects a point onto a line segment. Returns the projected point if it falls on the segment
    /// (with small extension tolerance).
    private func projectPointOntoSegment(_ point: CGPoint,
                                          segStart: CGPoint,
                                          segEnd: CGPoint) -> CGPoint? {
        let dx = segEnd.x - segStart.x
        let dy = segEnd.y - segStart.y
        let lenSq = dx * dx + dy * dy
        guard lenSq > 1 else { return nil }

        var t = ((point.x - segStart.x) * dx + (point.y - segStart.y) * dy) / lenSq
        // Allow slight extension past segment ends
        t = max(-0.1, min(1.1, t))

        return CGPoint(x: segStart.x + t * dx, y: segStart.y + t * dy)
    }

    // MARK: - Grid Rasterization

    /// Rasterizes a thick line onto the grid using Bresenham-like approach with thickness.
    private func rasterizeLine(grid: inout [[Int]],
                                x0: CGFloat, y0: CGFloat,
                                x1: CGFloat, y1: CGFloat,
                                thickness: CGFloat) {
        let gridH = grid.count
        let gridW = grid[0].count
        let steps = Int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        let halfT = Int(ceil(thickness / 2))

        for s in 0...steps {
            let t = steps > 0 ? CGFloat(s) / CGFloat(steps) : 0
            let cx = Int(x0 + (x1 - x0) * t)
            let cy = Int(y0 + (y1 - y0) * t)

            for dy in -halfT...halfT {
                for dx in -halfT...halfT {
                    let gx = cx + dx
                    let gy = cy + dy
                    if gx >= 0 && gx < gridW && gy >= 0 && gy < gridH {
                        grid[gy][gx] = 1  // wall
                    }
                }
            }
        }
    }

    /// Stack-based flood fill (avoids stack overflow from recursion).
    private func floodFill(grid: inout [[Int]], startX: Int, startY: Int, fillValue: Int) {
        let gridH = grid.count
        let gridW = grid[0].count
        guard startX >= 0, startX < gridW, startY >= 0, startY < gridH else { return }
        let target = grid[startY][startX]
        guard target != fillValue, target != 1 else { return }

        var stack: [(Int, Int)] = [(startX, startY)]
        grid[startY][startX] = fillValue

        while let (x, y) = stack.popLast() {
            let neighbors = [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
            for (nx, ny) in neighbors {
                if nx >= 0 && nx < gridW && ny >= 0 && ny < gridH && grid[ny][nx] == target {
                    grid[ny][nx] = fillValue
                    stack.append((nx, ny))
                }
            }
        }
    }
}
