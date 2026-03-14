import SwiftUI

struct FloorPlan2DRenderer: View {
    let floorPlan: FloorPlan
    let showMeasurements: Bool
    let measurementUnit: MeasurementUnit
    let roomLabels: [RoomLabel]
    var theme: ColorTheme = .classic
    var wallThicknessSetting: WallThicknessSetting = .standard
    var labelSizeSetting: LabelSizeSetting = .medium
    var onTapLocation: ((CGPoint) -> Void)?

    var body: some View {
        Canvas { context, size in
            let bounds = floorPlan.boundingRect
            guard bounds.width > 0, bounds.height > 0 else { return }

            // Background
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(theme.backgroundColor))

            // Scale to fit with padding
            let scaleX = size.width / bounds.width
            let scaleY = size.height / bounds.height
            let scale = min(scaleX, scaleY) * 0.78

            let offsetX = (size.width - bounds.width * scale) / 2 - bounds.origin.x * scale
            let offsetY = (size.height - bounds.height * scale) / 2 - bounds.origin.y * scale

            // Wall thickness with setting multiplier
            let wallThickness: CGFloat = max(10 * scale * wallThicknessSetting.multiplier, 5.0 * wallThicknessSetting.multiplier)

            func transform(_ point: CGPoint) -> CGPoint {
                CGPoint(x: point.x * scale + offsetX, y: point.y * scale + offsetY)
            }

            // 1. Draw walls
            for wall in floorPlan.walls {
                let start = transform(wall.start)
                let end = transform(wall.end)
                drawThickWall(context: context, start: start, end: end, thickness: wallThickness, color: theme.wallColor)
            }

            // 2. Corner joints
            drawCornerJoints(context: context, walls: floorPlan.walls, scale: scale, wallThickness: wallThickness, transform: transform)

            // 3. Openings
            for opening in floorPlan.openings {
                let start = transform(opening.start)
                let end = transform(opening.end)
                let angle = atan2(end.y - start.y, end.x - start.x)
                clearWallGap(context: context, start: start, end: end, angle: angle, wallThickness: wallThickness)
            }

            // 4. Windows
            for window in floorPlan.windows {
                let start = transform(window.start)
                let end = transform(window.end)
                let angle = atan2(end.y - start.y, end.x - start.x)

                clearWallGap(context: context, start: start, end: end, angle: angle, wallThickness: wallThickness)

                let winOffset = wallThickness * 0.3
                for offset in [-winOffset, winOffset] {
                    let px = -sin(angle) * offset
                    let py = cos(angle) * offset
                    var linePath = Path()
                    linePath.move(to: CGPoint(x: start.x + px, y: start.y + py))
                    linePath.addLine(to: CGPoint(x: end.x + px, y: end.y + py))
                    context.stroke(linePath, with: .color(theme.wallColor), style: StrokeStyle(lineWidth: 1.5))
                }
            }

            // 5. Doors
            for door in floorPlan.doors {
                let pos = transform(door.position)
                let arcRadius = door.width * scale / 2

                let da = door.angle
                let dCos = cos(da) * Double(arcRadius)
                let dSin = sin(da) * Double(arcRadius)
                let s = CGPoint(x: pos.x - dCos, y: pos.y - dSin)
                let e = CGPoint(x: pos.x + dCos, y: pos.y + dSin)
                clearWallGap(context: context, start: s, end: e, angle: CGFloat(da), wallThickness: wallThickness)

                var arcPath = Path()
                arcPath.addArc(
                    center: pos,
                    radius: arcRadius,
                    startAngle: Angle(radians: door.angle - .pi / 2),
                    endAngle: Angle(radians: door.angle),
                    clockwise: false
                )
                context.stroke(arcPath, with: .color(theme.doorColor), style: StrokeStyle(lineWidth: 1.0, lineCap: .round))

                let doorEnd = CGPoint(
                    x: pos.x + arcRadius * CGFloat(cos(door.angle)),
                    y: pos.y + arcRadius * CGFloat(sin(door.angle))
                )
                var doorLine = Path()
                doorLine.move(to: pos)
                doorLine.addLine(to: doorEnd)
                context.stroke(doorLine, with: .color(theme.doorColor), style: StrokeStyle(lineWidth: 2))
            }

            // 6. Fixtures (stairs only — other fixtures are excluded)
            for fixture in floorPlan.fixtures where fixture.type == .stairs {
                let center = transform(fixture.position)
                let w = fixture.size.width * scale
                let h = fixture.size.height * scale
                drawFixtureSymbol(
                    context: context,
                    center: center,
                    width: max(w, 12),
                    height: max(h, 12),
                    angle: fixture.angle,
                    type: fixture.type
                )
            }

            // 7. Room labels
            for label in roomLabels {
                let center = transform(label.position)

                context.draw(
                    Text(label.name)
                        .font(.system(size: labelSizeSetting.nameFontSize, weight: .bold))
                        .foregroundColor(theme.labelColor),
                    at: center
                )

                let dims = estimateRoomDimensions(label: label, walls: floorPlan.walls)
                if let dims = dims {
                    let dimText: String
                    switch measurementUnit {
                    case .feet:
                        let w = dims.width * 3.28084
                        let h = dims.height * 3.28084
                        dimText = formatFeetInches(w) + " x " + formatFeetInches(h)
                    case .meters:
                        dimText = String(format: "%.1f x %.1f m", dims.width, dims.height)
                    }
                    context.draw(
                        Text(dimText)
                            .font(.system(size: labelSizeSetting.dimFontSize, weight: .medium))
                            .foregroundColor(theme.dimColor),
                        at: CGPoint(x: center.x, y: center.y + labelSizeSetting.dimYOffset)
                    )
                }
            }

            // 8. Wall measurements
            if showMeasurements {
                for wall in floorPlan.walls {
                    guard wall.lengthMeters > 0.3 else { continue }
                    let start = transform(wall.start)
                    let end = transform(wall.end)
                    let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
                    let angle = atan2(end.y - start.y, end.x - start.x)
                    let perpOffset = wallThickness / 2 + 12
                    let textPoint = CGPoint(
                        x: mid.x - sin(angle) * perpOffset,
                        y: mid.y + cos(angle) * perpOffset
                    )

                    let text = measurementUnit.formatted(meters: wall.lengthMeters)
                    context.draw(
                        Text(text)
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(theme.measurementColor),
                        at: textPoint
                    )
                }
            }

            // 9. Total area
            if !floorPlan.walls.isEmpty {
                let totalArea = estimateTotalArea()
                if totalArea > 0 {
                    let areaText: String
                    switch measurementUnit {
                    case .feet:
                        areaText = String(format: "TOTAL: %.0f sq. ft", totalArea * 10.7639)
                    case .meters:
                        areaText = String(format: "TOTAL: %.1f sq. m", totalArea)
                    }
                    context.draw(
                        Text(areaText)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.dimColor),
                        at: CGPoint(x: size.width / 2, y: size.height - 24)
                    )
                }
            }

            // 10. Floor label
            context.draw(
                Text("Floor 1")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundColor(theme.dimColor),
                at: CGPoint(x: 40, y: size.height - 24)
            )
        }
        .background(theme.backgroundColor)
        .contentShape(Rectangle())
        .onTapGesture { location in
            onTapLocation?(location)
        }
    }

    // MARK: - Thick Wall Drawing

    private func drawThickWall(context: GraphicsContext, start: CGPoint, end: CGPoint, thickness: CGFloat, color: Color) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let perpX = -sin(angle) * thickness / 2
        let perpY = cos(angle) * thickness / 2

        var wallPath = Path()
        wallPath.move(to: CGPoint(x: start.x + perpX, y: start.y + perpY))
        wallPath.addLine(to: CGPoint(x: end.x + perpX, y: end.y + perpY))
        wallPath.addLine(to: CGPoint(x: end.x - perpX, y: end.y - perpY))
        wallPath.addLine(to: CGPoint(x: start.x - perpX, y: start.y - perpY))
        wallPath.closeSubpath()
        context.fill(wallPath, with: .color(color))
    }

    // MARK: - Clear Wall Gap

    private func clearWallGap(context: GraphicsContext, start: CGPoint, end: CGPoint, angle: CGFloat, wallThickness: CGFloat) {
        let expand: CGFloat = 1.5
        let perpX = -sin(angle) * wallThickness * expand / 2
        let perpY = cos(angle) * wallThickness * expand / 2

        var clearPath = Path()
        clearPath.move(to: CGPoint(x: start.x + perpX, y: start.y + perpY))
        clearPath.addLine(to: CGPoint(x: end.x + perpX, y: end.y + perpY))
        clearPath.addLine(to: CGPoint(x: end.x - perpX, y: end.y - perpY))
        clearPath.addLine(to: CGPoint(x: start.x - perpX, y: start.y - perpY))
        clearPath.closeSubpath()
        context.fill(clearPath, with: .color(theme.backgroundColor))
    }

    // MARK: - Corner Joints

    private func drawCornerJoints(
        context: GraphicsContext,
        walls: [Wall2D],
        scale: CGFloat,
        wallThickness: CGFloat,
        transform: (CGPoint) -> CGPoint
    ) {
        let threshold: CGFloat = wallThickness * 1.5
        var endpoints: [CGPoint] = []
        for wall in walls {
            endpoints.append(transform(wall.start))
            endpoints.append(transform(wall.end))
        }

        for i in 0..<endpoints.count {
            for j in (i+1)..<endpoints.count {
                let dist = hypot(endpoints[i].x - endpoints[j].x, endpoints[i].y - endpoints[j].y)
                if dist < threshold {
                    let mid = CGPoint(x: (endpoints[i].x + endpoints[j].x) / 2, y: (endpoints[i].y + endpoints[j].y) / 2)
                    let half = wallThickness / 2
                    context.fill(
                        Path(CGRect(x: mid.x - half, y: mid.y - half, width: wallThickness, height: wallThickness)),
                        with: .color(theme.wallColor)
                    )
                }
            }
        }
    }

    // MARK: - Fixture Symbols

    private func drawFixtureSymbol(
        context: GraphicsContext,
        center: CGPoint,
        width: CGFloat,
        height: CGFloat,
        angle: Double,
        type: FixtureType
    ) {
        let strokeStyle = StrokeStyle(lineWidth: 1.0)
        let rect = CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)

        switch type {
        case .toilet:
            context.stroke(Path(rect), with: .color(theme.fixtureColor), style: strokeStyle)
            let circleSize = min(width, height) * 0.6
            let circleRect = CGRect(
                x: center.x - circleSize / 2,
                y: center.y - circleSize / 2 - height * 0.1,
                width: circleSize,
                height: circleSize
            )
            context.stroke(Path(ellipseIn: circleRect), with: .color(theme.fixtureColor), style: strokeStyle)

        case .bathtub:
            let outer = Path(roundedRect: rect, cornerRadius: min(width, height) * 0.2)
            context.stroke(outer, with: .color(theme.fixtureColor), style: strokeStyle)
            let inner = CGRect(x: rect.minX + 3, y: rect.minY + 3, width: rect.width - 6, height: rect.height - 6)
            context.stroke(Path(roundedRect: inner, cornerRadius: min(width, height) * 0.15), with: .color(theme.fixtureColor), style: strokeStyle)

        case .sink:
            context.stroke(Path(rect), with: .color(theme.fixtureColor), style: strokeStyle)
            let r = min(width, height) * 0.35
            context.stroke(
                Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                with: .color(theme.fixtureColor),
                style: strokeStyle
            )

        case .stove, .oven:
            context.stroke(Path(rect), with: .color(theme.fixtureColor), style: strokeStyle)
            let br: CGFloat = min(width, height) * 0.15
            let offsets: [(CGFloat, CGFloat)] = [(-0.25, -0.25), (0.25, -0.25), (-0.25, 0.25), (0.25, 0.25)]
            for (ox, oy) in offsets {
                let cx = center.x + width * ox
                let cy = center.y + height * oy
                context.stroke(
                    Path(ellipseIn: CGRect(x: cx - br, y: cy - br, width: br * 2, height: br * 2)),
                    with: .color(theme.fixtureColor),
                    style: strokeStyle
                )
            }

        case .refrigerator:
            context.stroke(Path(rect), with: .color(theme.fixtureColor), style: strokeStyle)
            var divider = Path()
            divider.move(to: CGPoint(x: rect.minX, y: center.y - height * 0.15))
            divider.addLine(to: CGPoint(x: rect.maxX, y: center.y - height * 0.15))
            context.stroke(divider, with: .color(theme.fixtureColor), style: strokeStyle)

        case .bed:
            context.stroke(Path(rect), with: .color(theme.fixtureColor), style: strokeStyle)
            let pillowH = height * 0.15
            let pillowW = width * 0.4
            context.stroke(
                Path(CGRect(x: center.x - width * 0.4, y: rect.minY + 3, width: pillowW, height: pillowH)),
                with: .color(theme.fixtureColor), style: strokeStyle
            )
            context.stroke(
                Path(CGRect(x: center.x + width * 0.0, y: rect.minY + 3, width: pillowW, height: pillowH)),
                with: .color(theme.fixtureColor), style: strokeStyle
            )

        case .sofa:
            context.stroke(Path(rect), with: .color(theme.fixtureColor), style: strokeStyle)
            let backRect = CGRect(x: rect.minX + 2, y: rect.minY + 2, width: rect.width - 4, height: height * 0.25)
            context.stroke(Path(backRect), with: .color(theme.fixtureColor), style: strokeStyle)

        case .table:
            context.stroke(Path(rect), with: .color(theme.fixtureColor), style: strokeStyle)

        case .stairs:
            context.stroke(Path(rect), with: .color(theme.fixtureColor), style: strokeStyle)
            let steps = 6
            for i in 1..<steps {
                let y = rect.minY + rect.height * CGFloat(i) / CGFloat(steps)
                var stepLine = Path()
                stepLine.move(to: CGPoint(x: rect.minX, y: y))
                stepLine.addLine(to: CGPoint(x: rect.maxX, y: y))
                context.stroke(stepLine, with: .color(theme.fixtureColor), style: strokeStyle)
            }
            var arrow = Path()
            arrow.move(to: CGPoint(x: center.x, y: rect.minY + 4))
            arrow.addLine(to: CGPoint(x: center.x, y: rect.maxY - 4))
            context.stroke(arrow, with: .color(theme.fixtureColor), style: StrokeStyle(lineWidth: 1.5))

        case .fireplace:
            context.stroke(Path(rect), with: .color(theme.fixtureColor), style: strokeStyle)
            var arc = Path()
            arc.addArc(center: CGPoint(x: center.x, y: rect.maxY), radius: width * 0.3,
                       startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            context.stroke(arc, with: .color(theme.fixtureColor), style: strokeStyle)

        default:
            context.stroke(Path(rect), with: .color(theme.fixtureColor), style: strokeStyle)
            var x1 = Path()
            x1.move(to: CGPoint(x: rect.minX, y: rect.minY))
            x1.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            var x2 = Path()
            x2.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            x2.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            context.stroke(x1, with: .color(theme.fixtureColor), style: StrokeStyle(lineWidth: 0.5))
            context.stroke(x2, with: .color(theme.fixtureColor), style: StrokeStyle(lineWidth: 0.5))
        }
    }

    // MARK: - Room Dimensions

    private func estimateRoomDimensions(label: RoomLabel, walls: [Wall2D]) -> CGSize? {
        let pos = label.position
        let searchRadius: CGFloat = 200

        var horizontalLengths: [Double] = []
        var verticalLengths: [Double] = []

        for wall in walls {
            let midX = (wall.start.x + wall.end.x) / 2
            let midY = (wall.start.y + wall.end.y) / 2
            let dist = hypot(midX - pos.x, midY - pos.y)
            guard dist < searchRadius else { continue }

            let angle = atan2(wall.end.y - wall.start.y, wall.end.x - wall.start.x)
            let absAngle = abs(angle)

            if absAngle < 0.3 || absAngle > (.pi - 0.3) {
                horizontalLengths.append(wall.lengthMeters)
            }
            if abs(absAngle - .pi / 2) < 0.3 {
                verticalLengths.append(wall.lengthMeters)
            }
        }

        guard let maxH = horizontalLengths.max(), let maxV = verticalLengths.max() else { return nil }
        return CGSize(width: maxH, height: maxV)
    }

    // MARK: - Formatting

    private func formatFeetInches(_ feet: Double) -> String {
        let wholeFeet = Int(feet)
        let inches = Int((feet - Double(wholeFeet)) * 12)
        if inches == 0 {
            return "\(wholeFeet)'"
        }
        return "\(wholeFeet)'\(inches)\""
    }

    // MARK: - Area Estimation

    private func estimateTotalArea() -> Double {
        let bounds = floorPlan.boundingRect
        let widthMeters = Double(bounds.width) / 100.0
        let heightMeters = Double(bounds.height) / 100.0
        return widthMeters * heightMeters * 0.7
    }
}
