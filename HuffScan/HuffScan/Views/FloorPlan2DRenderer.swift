import SwiftUI

struct FloorPlan2DRenderer: View {
    let floorPlan: FloorPlan
    let showMeasurements: Bool
    let measurementUnit: MeasurementUnit
    let roomLabels: [RoomLabel]
    var onTapLocation: ((CGPoint) -> Void)?

    // Architectural colors
    private let wallColor = Color.white
    private let wallFillColor = Color.white.opacity(0.85)
    private let doorColor = Color.white.opacity(0.7)
    private let windowColor = Color(hex: "#74B9FF")
    private let measurementColor = Color.white.opacity(0.6)
    private let gridColor = Color.white.opacity(0.04)
    private let dimColor = Color.white.opacity(0.45)

    var body: some View {
        Canvas { context, size in
            let bounds = floorPlan.boundingRect
            guard bounds.width > 0, bounds.height > 0 else { return }

            // Calculate scale to fit with padding
            let scaleX = size.width / bounds.width
            let scaleY = size.height / bounds.height
            let scale = min(scaleX, scaleY) * 0.80

            let offsetX = (size.width - bounds.width * scale) / 2 - bounds.origin.x * scale
            let offsetY = (size.height - bounds.height * scale) / 2 - bounds.origin.y * scale

            // Wall thickness in screen points (thick architectural style)
            let wallThickness: CGFloat = max(8 * scale, 4.0)

            func transform(_ point: CGPoint) -> CGPoint {
                CGPoint(x: point.x * scale + offsetX, y: point.y * scale + offsetY)
            }

            // 1. Draw subtle grid
            drawGrid(context: context, size: size, scale: scale)

            // 2. Draw room label fills (behind walls)
            for label in roomLabels {
                let center = transform(label.position)
                let fillColor = Color(hex: label.colorHex).opacity(0.1)
                // Large rectangular fill for the room area
                let rectSize: CGFloat = 60 * scale
                let rect = CGRect(
                    x: center.x - rectSize,
                    y: center.y - rectSize * 0.7,
                    width: rectSize * 2,
                    height: rectSize * 1.4
                )
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 4),
                    with: .color(fillColor)
                )
            }

            // 3. Draw walls as thick filled rectangles (architectural style)
            for wall in floorPlan.walls {
                let start = transform(wall.start)
                let end = transform(wall.end)

                let angle = atan2(end.y - start.y, end.x - start.x)
                let perpX = -sin(angle) * wallThickness / 2
                let perpY = cos(angle) * wallThickness / 2

                // Create a filled rectangle for the wall
                var wallPath = Path()
                wallPath.move(to: CGPoint(x: start.x + perpX, y: start.y + perpY))
                wallPath.addLine(to: CGPoint(x: end.x + perpX, y: end.y + perpY))
                wallPath.addLine(to: CGPoint(x: end.x - perpX, y: end.y - perpY))
                wallPath.addLine(to: CGPoint(x: start.x - perpX, y: start.y - perpY))
                wallPath.closeSubpath()

                context.fill(wallPath, with: .color(wallFillColor))

                // Thin outline for crispness
                context.stroke(
                    wallPath,
                    with: .color(wallColor),
                    style: StrokeStyle(lineWidth: 0.5)
                )
            }

            // 4. Draw wall corner joints (fill gaps where walls meet)
            drawCornerJoints(
                context: context,
                walls: floorPlan.walls,
                scale: scale,
                wallThickness: wallThickness,
                transform: transform
            )

            // 5. Draw windows (triple-line architectural style)
            for window in floorPlan.windows {
                let start = transform(window.start)
                let end = transform(window.end)
                let angle = atan2(end.y - start.y, end.x - start.x)

                // Clear the wall behind the window
                let clearPerpX = -sin(angle) * wallThickness / 2
                let clearPerpY = cos(angle) * wallThickness / 2
                var clearPath = Path()
                clearPath.move(to: CGPoint(x: start.x + clearPerpX, y: start.y + clearPerpY))
                clearPath.addLine(to: CGPoint(x: end.x + clearPerpX, y: end.y + clearPerpY))
                clearPath.addLine(to: CGPoint(x: end.x - clearPerpX, y: end.y - clearPerpY))
                clearPath.addLine(to: CGPoint(x: start.x - clearPerpX, y: start.y - clearPerpY))
                clearPath.closeSubpath()
                context.fill(clearPath, with: .color(Color(hex: "#0E1117")))

                // Draw window lines (two parallel lines with a center line)
                let winOffset = wallThickness * 0.35
                for offset in [-winOffset, 0, winOffset] {
                    let px = -sin(angle) * offset
                    let py = cos(angle) * offset
                    var linePath = Path()
                    linePath.move(to: CGPoint(x: start.x + px, y: start.y + py))
                    linePath.addLine(to: CGPoint(x: end.x + px, y: end.y + py))
                    context.stroke(
                        linePath,
                        with: .color(windowColor),
                        style: StrokeStyle(lineWidth: offset == 0 ? 1.0 : 1.5)
                    )
                }

                // Window measurement
                if showMeasurements && window.widthMeters > 0.3 {
                    let midPoint = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
                    let text = measurementUnit.formatted(meters: window.widthMeters)
                    let perpOffset: CGFloat = wallThickness / 2 + 12
                    context.draw(
                        Text(text)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(windowColor.opacity(0.7)),
                        at: CGPoint(
                            x: midPoint.x - sin(angle) * perpOffset,
                            y: midPoint.y + cos(angle) * perpOffset
                        )
                    )
                }
            }

            // 6. Draw doors (quarter-circle arc swing + clear wall gap)
            for door in floorPlan.doors {
                let pos = transform(door.position)
                let arcRadius = door.width * scale / 2

                // Clear the wall behind the door
                let clearAngle = door.angle
                let clearDx = cos(clearAngle) * Double(arcRadius)
                let clearDy = sin(clearAngle) * Double(arcRadius)
                let perpX = -sin(clearAngle) * Double(wallThickness) / 2
                let perpY = cos(clearAngle) * Double(wallThickness) / 2

                var clearPath = Path()
                clearPath.move(to: CGPoint(x: pos.x + perpX - clearDx, y: pos.y + perpY - clearDy))
                clearPath.addLine(to: CGPoint(x: pos.x + perpX + clearDx, y: pos.y + perpY + clearDy))
                clearPath.addLine(to: CGPoint(x: pos.x - perpX + clearDx, y: pos.y - perpY + clearDy))
                clearPath.addLine(to: CGPoint(x: pos.x - perpX - clearDx, y: pos.y - perpY - clearDy))
                clearPath.closeSubpath()
                context.fill(clearPath, with: .color(Color(hex: "#0E1117")))

                // Door arc (quarter circle swing)
                var arcPath = Path()
                let startAngle = Angle(radians: door.angle - .pi / 2)
                let endAngle = Angle(radians: door.angle)
                arcPath.addArc(
                    center: pos,
                    radius: arcRadius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: false
                )
                context.stroke(
                    arcPath,
                    with: .color(doorColor),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )

                // Door panel line (the door itself)
                let doorEnd = CGPoint(
                    x: pos.x + arcRadius * CGFloat(cos(door.angle)),
                    y: pos.y + arcRadius * CGFloat(sin(door.angle))
                )
                var doorLine = Path()
                doorLine.move(to: pos)
                doorLine.addLine(to: doorEnd)
                context.stroke(
                    doorLine,
                    with: .color(doorColor),
                    style: StrokeStyle(lineWidth: 2)
                )

                // Door measurement
                if showMeasurements && door.widthMeters > 0.3 {
                    let text = measurementUnit.formatted(meters: door.widthMeters)
                    context.draw(
                        Text(text)
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(doorColor),
                        at: CGPoint(x: pos.x, y: pos.y - arcRadius - 10)
                    )
                }
            }

            // 7. Draw wall measurements (outside the walls)
            if showMeasurements {
                for wall in floorPlan.walls {
                    guard wall.lengthMeters > 0.3 else { continue }

                    let start = transform(wall.start)
                    let end = transform(wall.end)
                    let midPoint = CGPoint(
                        x: (start.x + end.x) / 2,
                        y: (start.y + end.y) / 2
                    )
                    let text = measurementUnit.formatted(meters: wall.lengthMeters)
                    let angle = atan2(end.y - start.y, end.x - start.x)

                    // Offset text perpendicular to wall (outside)
                    let perpOffset = wallThickness / 2 + 14
                    let perpX = -sin(angle) * perpOffset
                    let perpY = cos(angle) * perpOffset
                    let textPoint = CGPoint(x: midPoint.x + perpX, y: midPoint.y + perpY)

                    // Background pill for readability
                    let textStr = text
                    let estimatedWidth = CGFloat(textStr.count) * 6.5
                    let bgRect = CGRect(
                        x: textPoint.x - estimatedWidth / 2 - 4,
                        y: textPoint.y - 7,
                        width: estimatedWidth + 8,
                        height: 14
                    )
                    context.fill(
                        Path(roundedRect: bgRect, cornerRadius: 3),
                        with: .color(Color(hex: "#0E1117").opacity(0.7))
                    )

                    context.draw(
                        Text(text)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(measurementColor),
                        at: textPoint
                    )
                }
            }

            // 8. Draw room labels with dimensions
            for label in roomLabels {
                let center = transform(label.position)

                // Room name
                context.draw(
                    Text(label.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white),
                    at: center
                )

                // If this label has dimensions, show them below the name
                // (dimensions are computed from nearby walls)
            }

            // 9. Draw total area at bottom
            if !floorPlan.walls.isEmpty {
                let totalArea = estimateTotalArea()
                if totalArea > 0 {
                    let areaText: String
                    switch measurementUnit {
                    case .feet:
                        let sqFt = totalArea * 10.7639
                        areaText = String(format: "TOTAL: %.0f sq. ft", sqFt)
                    case .meters:
                        areaText = String(format: "TOTAL: %.1f sq. m", totalArea)
                    }
                    context.draw(
                        Text(areaText)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(dimColor),
                        at: CGPoint(x: size.width / 2, y: size.height - 30)
                    )
                }
            }
        }
        .background(Color(hex: "#0E1117"))
        .contentShape(Rectangle())
        .onTapGesture { location in
            onTapLocation?(location)
        }
    }

    // MARK: - Corner Joints

    private func drawCornerJoints(
        context: GraphicsContext,
        walls: [Wall2D],
        scale: CGFloat,
        wallThickness: CGFloat,
        transform: (CGPoint) -> CGPoint
    ) {
        // Find endpoints that are close together and fill the corner
        let threshold: CGFloat = wallThickness * 1.5

        var endpoints: [(point: CGPoint, original: CGPoint)] = []
        for wall in walls {
            endpoints.append((transform(wall.start), wall.start))
            endpoints.append((transform(wall.end), wall.end))
        }

        for i in 0..<endpoints.count {
            for j in (i+1)..<endpoints.count {
                let p1 = endpoints[i].point
                let p2 = endpoints[j].point
                let dist = hypot(p1.x - p2.x, p1.y - p2.y)

                if dist < threshold {
                    // Fill a square at the junction
                    let mid = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
                    let half = wallThickness / 2
                    let rect = CGRect(x: mid.x - half, y: mid.y - half, width: wallThickness, height: wallThickness)
                    context.fill(Path(rect), with: .color(wallFillColor))
                }
            }
        }
    }

    // MARK: - Grid

    private func drawGrid(context: GraphicsContext, size: CGSize, scale: CGFloat) {
        let gridSpacing: CGFloat = 50 * scale
        guard gridSpacing > 5 else { return }

        var gridPath = Path()
        var x: CGFloat = 0
        while x < size.width {
            gridPath.move(to: CGPoint(x: x, y: 0))
            gridPath.addLine(to: CGPoint(x: x, y: size.height))
            x += gridSpacing
        }
        var y: CGFloat = 0
        while y < size.height {
            gridPath.move(to: CGPoint(x: 0, y: y))
            gridPath.addLine(to: CGPoint(x: size.width, y: y))
            y += gridSpacing
        }

        context.stroke(gridPath, with: .color(gridColor), style: StrokeStyle(lineWidth: 0.5))
    }

    // MARK: - Area Estimation

    private func estimateTotalArea() -> Double {
        // Estimate area from bounding rect of walls (rough approximation in sq meters)
        let bounds = floorPlan.boundingRect
        let widthMeters = Double(bounds.width) / 100.0
        let heightMeters = Double(bounds.height) / 100.0
        return widthMeters * heightMeters * 0.7 // 0.7 factor since rooms don't fill the bounding box
    }
}
