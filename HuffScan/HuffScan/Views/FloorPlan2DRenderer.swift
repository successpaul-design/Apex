import SwiftUI

struct FloorPlan2DRenderer: View {
    let floorPlan: FloorPlan
    let showMeasurements: Bool
    let measurementUnit: MeasurementUnit
    let roomLabels: [RoomLabel]
    var onTapLocation: ((CGPoint) -> Void)?

    // Colors
    private let wallColor = Color(hex: "#2C3E50")
    private let doorColor = Color(hex: "#8B7355")
    private let windowColor = Color(hex: "#74B9FF")
    private let measurementColor = Color(hex: "#95A5A6")
    private let gridColor = Color.white.opacity(0.03)

    var body: some View {
        Canvas { context, size in
            let bounds = floorPlan.boundingRect

            // Calculate scale to fit
            let scaleX = size.width / bounds.width
            let scaleY = size.height / bounds.height
            let scale = min(scaleX, scaleY) * 0.85

            let offsetX = (size.width - bounds.width * scale) / 2 - bounds.origin.x * scale
            let offsetY = (size.height - bounds.height * scale) / 2 - bounds.origin.y * scale

            func transform(_ point: CGPoint) -> CGPoint {
                CGPoint(x: point.x * scale + offsetX, y: point.y * scale + offsetY)
            }

            // Draw grid
            drawGrid(context: context, size: size, scale: scale)

            // Draw room label fills (behind walls)
            for label in roomLabels {
                let center = transform(label.position)
                let fillColor = Color(hex: label.colorHex).opacity(0.15)
                let radius: CGFloat = 40 * scale
                let rect = CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(fillColor)
                )
            }

            // Draw walls
            for wall in floorPlan.walls {
                let start = transform(wall.start)
                let end = transform(wall.end)
                let thickness = max(wall.thickness * scale, 3.0)

                var path = Path()
                path.move(to: start)
                path.addLine(to: end)

                context.stroke(
                    path,
                    with: .color(wallColor),
                    style: StrokeStyle(lineWidth: thickness, lineCap: .round)
                )

                // Measurement annotation
                if showMeasurements && wall.lengthMeters > 0.3 {
                    let midPoint = CGPoint(
                        x: (start.x + end.x) / 2,
                        y: (start.y + end.y) / 2
                    )
                    let text = measurementUnit.formatted(meters: wall.lengthMeters)
                    let angle = atan2(end.y - start.y, end.x - start.x)

                    // Offset text perpendicular to wall
                    let perpX = -sin(angle) * 12
                    let perpY = cos(angle) * 12
                    let textPoint = CGPoint(x: midPoint.x + perpX, y: midPoint.y + perpY)

                    context.draw(
                        Text(text)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(measurementColor),
                        at: textPoint
                    )
                }
            }

            // Draw windows (dashed)
            for window in floorPlan.windows {
                let start = transform(window.start)
                let end = transform(window.end)

                var path = Path()
                path.move(to: start)
                path.addLine(to: end)

                // Light blue dashed line
                context.stroke(
                    path,
                    with: .color(windowColor),
                    style: StrokeStyle(lineWidth: 4 * scale, lineCap: .round, dash: [6, 4])
                )

                // Window measurement
                if showMeasurements {
                    let midPoint = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
                    let text = measurementUnit.formatted(meters: window.widthMeters)
                    context.draw(
                        Text(text)
                            .font(.system(size: 8, weight: .regular, design: .monospaced))
                            .foregroundColor(windowColor.opacity(0.8)),
                        at: CGPoint(x: midPoint.x, y: midPoint.y - 10)
                    )
                }
            }

            // Draw doors (arc indicator)
            for door in floorPlan.doors {
                let pos = transform(door.position)
                let doorWidth = door.width * scale

                // Door arc
                let arcRadius = doorWidth / 2
                var arcPath = Path()
                let startAngle = Angle(radians: door.angle)
                let endAngle = Angle(radians: door.angle + .pi / 2)
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
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )

                // Door line
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
                if showMeasurements {
                    let text = measurementUnit.formatted(meters: door.widthMeters)
                    context.draw(
                        Text(text)
                            .font(.system(size: 8, weight: .regular, design: .monospaced))
                            .foregroundColor(doorColor.opacity(0.8)),
                        at: CGPoint(x: pos.x, y: pos.y - arcRadius - 8)
                    )
                }
            }

            // Draw room labels
            for label in roomLabels {
                let center = transform(label.position)

                // Label background
                let labelBgRect = CGRect(x: center.x - 36, y: center.y - 10, width: 72, height: 20)
                context.fill(
                    Path(roundedRect: labelBgRect, cornerRadius: 4),
                    with: .color(Color(hex: label.colorHex).opacity(0.3))
                )

                // Label text
                context.draw(
                    Text(label.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white),
                    at: center
                )
            }
        }
        .background(Color(hex: "#0E1117"))
        .contentShape(Rectangle())
        .onTapGesture { location in
            onTapLocation?(location)
        }
    }

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
}
