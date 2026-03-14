# HuffScan - How To Guide

## What Is HuffScan?

HuffScan is an iPhone app that uses your device's LiDAR sensor and Apple's RoomPlan framework to scan real-world rooms and generate clean, professional 2D floor plans. You can label rooms, customize the look, and export plans as PDF or JPEG.

---

## Requirements

| Requirement | Details |
|---|---|
| **iPhone** | iPhone 12 Pro or newer (must have LiDAR sensor) |
| **iOS** | 17.0 or later |
| **Xcode** | 15.0+ (for building from source) |
| **Permissions** | Camera access, Photo Library (for saving exports) |

> **Note:** HuffScan cannot run in the iOS Simulator. A physical LiDAR-equipped device is required.

---

## Building & Running

1. Open `HuffScan.xcodeproj` in Xcode 15+
2. Select your physical iPhone as the run destination
3. Set your signing team under **Signing & Capabilities**
4. Press **Cmd+R** to build and run

No third-party dependencies are needed — the app uses only Apple system frameworks (RoomPlan, ARKit, SwiftUI, CoreGraphics).

---

## Using the App

### Scanning a Room

1. Open HuffScan and tap **New Scan** on the home screen
2. Choose a scan mode:
   - **Single Room** — scans one room at a time
   - **Whole House** — scans multiple connected rooms in one session
3. Point your iPhone at the room and slowly walk around the perimeter
   - Keep the device at about waist/chest height
   - Move steadily — avoid jerky movements
   - Make sure to capture all walls, corners, doors, and windows
4. When finished, tap **Done Scanning**
5. The app processes the 3D data and generates a 2D floor plan

### Viewing a Floor Plan

- Tap any saved floor plan on the home screen to open it
- **Pinch** to zoom in/out
- **Drag** to pan around
- **Two-finger rotate** to rotate the view
- **Double-tap** to reset the view to default

### Adding Room Labels

1. Open a floor plan and tap **Edit Labels**
2. Tap **Add Label** to create a new room label
3. Enter the room name (e.g., "Master Bedroom", "Kitchen")
4. Choose a pastel color from the 8 available options
5. Position the label by dragging it to the desired location
6. Tap **Done** when finished

### Changing Settings

Access settings from the home screen:

| Setting | Options |
|---|---|
| **Color Theme** | Classic (white), Blueprint (blue), Midnight (dark) |
| **Wall Thickness** | Thin, Standard, Thick |
| **Label Size** | Small, Medium, Large |
| **Measurements** | Show or hide dimensions on walls |
| **Units** | Feet or Meters |

Settings persist across app launches.

### Exporting Floor Plans

1. Open a floor plan and tap the **Share/Export** button
2. Choose your format:
   - **PDF** — scalable vector format, ideal for printing or professional use
   - **JPEG** — raster image at 1x, 2x, or 3x resolution
3. Save to your Camera Roll or share via the system share sheet

---

## How It Works (Technical Overview)

### Scanning Pipeline

1. `ScanningView` wraps Apple's `RoomCaptureView` to capture 3D spatial data
2. The LiDAR sensor detects walls, doors, windows, openings, and fixtures
3. `ScanViewModel` converts 3D coordinates to a 2D top-down view (scale: 100 px/meter)

### Post-Processing (FloorPlanOptimizer)

After scanning, the app automatically:

1. **Straightens walls** — snaps near-horizontal/vertical walls to exact 0/90/180/270 degrees
2. **Merges corners** — groups endpoints within 15 px to clean up junctions
3. **Extends walls** — fills small gaps (up to 25 px) where walls should connect
4. **Detects rooms** — uses a grid-based flood-fill algorithm to identify enclosed spaces
5. **Classifies rooms** — auto-labels rooms (bedroom, bathroom, kitchen, etc.) based on area, shape, and fixture proximity

### Rendering

- Interactive viewing uses SwiftUI `Canvas`
- PDF export uses `UIGraphicsPDFRenderer`
- JPEG export uses `UIGraphicsImageRenderer`
- Three color themes control wall, background, and label colors

### Data Storage

Floor plans are saved to the app's Documents directory:

```
Documents/FloorPlans/{UUID}/
  ├── metadata.json    # Floor plan data (walls, doors, labels, etc.)
  ├── thumbnail.jpg    # Preview image
  └── room.usdz       # Optional 3D model
```

---

## Project Structure

```
HuffScan/
├── HuffScanApp.swift           # App entry point
├── ContentView.swift            # Navigation & routing
├── Models/
│   ├── FloorPlan.swift          # Core data structures (Wall2D, Door2D, etc.)
│   └── AppSettings.swift        # UserDefaults-backed settings
├── ViewModels/
│   ├── ScanViewModel.swift      # State management for scanning
│   └── FloorPlanViewModel.swift # State management for viewing
├── Views/
│   ├── HomeView.swift           # Main list screen
│   ├── ScanningView.swift       # RoomCaptureView bridge
│   ├── FloorPlanDetailView.swift# Detail viewer & editor
│   ├── FloorPlan2DRenderer.swift# Canvas-based rendering
│   └── RoomLabelEditor.swift    # Label management UI
└── Services/
    ├── FloorPlanOptimizer.swift  # Post-scan wall/room processing
    ├── StorageService.swift      # File persistence
    └── ExportService.swift       # PDF/JPEG generation
```

---

## Maintaining the App

### Adding a New Fixture Type

1. Add the fixture case in `FloorPlan.swift` under `Fixture2D`
2. Update the 3D-to-2D mapping in `ScanViewModel.swift`
3. Add rendering logic in `FloorPlan2DRenderer.swift` and `ExportService.swift`

### Adding a New Color Theme

1. Open `AppSettings.swift` and add a new case to `ColorTheme`
2. Define the wall, background, label, and measurement colors
3. Update `FloorPlan2DRenderer.swift` and `ExportService.swift` to use the new theme colors

### Adding a New Export Format

1. Add a new method in `ExportService.swift` following the pattern of `exportAsPDF` or `exportAsJPEG`
2. Wire it up in `FloorPlanDetailView.swift` as a new export option

### Debugging Scan Issues

- Poor scans are usually caused by: insufficient lighting, reflective surfaces, moving too fast, or not covering all walls
- Check the `ScanViewModel` delegate methods for error callbacks
- The optimizer's angle tolerance (15 degrees) and gap tolerance (25 px) can be adjusted in `FloorPlanOptimizer.swift`

### Updating for New iOS Versions

- The app targets iOS 17.0+ — update the deployment target in `project.pbxproj` if raising the minimum
- Watch for RoomPlan API changes in new iOS releases — the `CapturedRoom` structure may gain new fixture/surface types

---

## Tips for Best Scan Results

- Scan in **well-lit** rooms
- Move **slowly and steadily** around the room perimeter
- Keep the phone at **waist to chest height**
- Make sure **all corners** are captured
- For multi-room scans, walk through **doorways** to connect rooms
- **Avoid** scanning rooms with large mirrors or glass walls (confuses LiDAR)
- Re-scan if the result looks incomplete — sometimes a second pass captures details the first one missed
