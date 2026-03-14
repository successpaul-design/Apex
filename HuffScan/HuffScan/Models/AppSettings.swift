import SwiftUI

// MARK: - Settings Enums

enum WallThicknessSetting: String, CaseIterable {
    case thin = "Thin"
    case standard = "Standard"
    case thick = "Thick"

    /// Multiplier applied to the base wall thickness calculation
    var multiplier: CGFloat {
        switch self {
        case .thin: return 0.6
        case .standard: return 1.0
        case .thick: return 1.5
        }
    }
}

enum ColorTheme: String, CaseIterable {
    case classic = "Classic"
    case blueprint = "Blueprint"
    case midnight = "Midnight"

    var backgroundColor: Color {
        switch self {
        case .classic: return .white
        case .blueprint: return Color(red: 0.12, green: 0.22, blue: 0.42)
        case .midnight: return Color(red: 0.08, green: 0.08, blue: 0.12)
        }
    }

    var wallColor: Color {
        switch self {
        case .classic: return Color(red: 0.1, green: 0.1, blue: 0.1)
        case .blueprint: return .white
        case .midnight: return Color(red: 0.85, green: 0.85, blue: 0.85)
        }
    }

    var doorColor: Color {
        switch self {
        case .classic: return Color(red: 0.3, green: 0.3, blue: 0.3)
        case .blueprint: return Color(red: 0.7, green: 0.8, blue: 1.0)
        case .midnight: return Color(red: 0.6, green: 0.6, blue: 0.65)
        }
    }

    var windowColor: Color {
        switch self {
        case .classic: return Color(red: 0.45, green: 0.73, blue: 1.0)
        case .blueprint: return Color(red: 0.5, green: 0.8, blue: 1.0)
        case .midnight: return Color(red: 0.3, green: 0.6, blue: 0.9)
        }
    }

    var fixtureColor: Color {
        switch self {
        case .classic: return Color(red: 0.35, green: 0.35, blue: 0.35)
        case .blueprint: return Color(red: 0.6, green: 0.7, blue: 0.9)
        case .midnight: return Color(red: 0.55, green: 0.55, blue: 0.6)
        }
    }

    var measurementColor: Color {
        switch self {
        case .classic: return Color(red: 0.4, green: 0.4, blue: 0.4)
        case .blueprint: return Color(red: 0.65, green: 0.75, blue: 0.95)
        case .midnight: return Color(red: 0.5, green: 0.5, blue: 0.55)
        }
    }

    var labelColor: Color {
        switch self {
        case .classic: return .black
        case .blueprint: return .white
        case .midnight: return .white
        }
    }

    var dimColor: Color {
        switch self {
        case .classic: return Color(red: 0.5, green: 0.5, blue: 0.5)
        case .blueprint: return Color(red: 0.55, green: 0.65, blue: 0.85)
        case .midnight: return Color(red: 0.45, green: 0.45, blue: 0.5)
        }
    }

    // UIColor variants for ExportService (CoreGraphics drawing)
    var bgUIColor: UIColor {
        switch self {
        case .classic: return .white
        case .blueprint: return UIColor(red: 0.12, green: 0.22, blue: 0.42, alpha: 1)
        case .midnight: return UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1)
        }
    }

    var wallUIColor: UIColor {
        switch self {
        case .classic: return UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
        case .blueprint: return .white
        case .midnight: return UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1)
        }
    }

    var doorUIColor: UIColor {
        switch self {
        case .classic: return UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1)
        case .blueprint: return UIColor(red: 0.7, green: 0.8, blue: 1.0, alpha: 1)
        case .midnight: return UIColor(red: 0.6, green: 0.6, blue: 0.65, alpha: 1)
        }
    }

    var windowUIColor: UIColor {
        switch self {
        case .classic: return UIColor(red: 0.45, green: 0.73, blue: 1.0, alpha: 1)
        case .blueprint: return UIColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 1)
        case .midnight: return UIColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 1)
        }
    }

    var fixtureUIColor: UIColor {
        switch self {
        case .classic: return UIColor(red: 0.35, green: 0.35, blue: 0.35, alpha: 1)
        case .blueprint: return UIColor(red: 0.6, green: 0.7, blue: 0.9, alpha: 1)
        case .midnight: return UIColor(red: 0.55, green: 0.55, blue: 0.6, alpha: 1)
        }
    }

    var measureUIColor: UIColor {
        switch self {
        case .classic: return UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)
        case .blueprint: return UIColor(red: 0.65, green: 0.75, blue: 0.95, alpha: 1)
        case .midnight: return UIColor(red: 0.5, green: 0.5, blue: 0.55, alpha: 1)
        }
    }

    var labelUIColor: UIColor {
        switch self {
        case .classic: return .black
        case .blueprint: return .white
        case .midnight: return .white
        }
    }
}

enum LabelSizeSetting: String, CaseIterable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"

    var nameFontSize: CGFloat {
        switch self {
        case .small: return 9
        case .medium: return 11
        case .large: return 14
        }
    }

    var dimFontSize: CGFloat {
        switch self {
        case .small: return 7
        case .medium: return 9
        case .large: return 11
        }
    }

    var dimYOffset: CGFloat {
        switch self {
        case .small: return 11
        case .medium: return 14
        case .large: return 18
        }
    }

    // Export label sizes (slightly smaller for print)
    var exportNameFontSize: CGFloat {
        switch self {
        case .small: return 8
        case .medium: return 10
        case .large: return 13
        }
    }
}

enum ExportFormat: String, CaseIterable {
    case pdf = "PDF"
    case jpeg = "JPEG"
}

enum ExportResolution: String, CaseIterable {
    case standard = "1x"
    case high = "2x"
    case ultra = "3x"

    var scale: CGFloat {
        switch self {
        case .standard: return 1.0
        case .high: return 2.0
        case .ultra: return 3.0
        }
    }

    var jpegSize: CGSize {
        switch self {
        case .standard: return CGSize(width: 600, height: 450)
        case .high: return CGSize(width: 1200, height: 900)
        case .ultra: return CGSize(width: 1800, height: 1350)
        }
    }
}

// MARK: - AppSettings (UserDefaults-backed)

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("wallThickness") var wallThickness: String = WallThicknessSetting.standard.rawValue
    @AppStorage("colorTheme") var colorTheme: String = ColorTheme.classic.rawValue
    @AppStorage("labelSize") var labelSize: String = LabelSizeSetting.medium.rawValue
    @AppStorage("defaultExportFormat") var defaultExportFormat: String = ExportFormat.pdf.rawValue
    @AppStorage("exportResolution") var exportResolution: String = ExportResolution.high.rawValue
    @AppStorage("showMeasurementsByDefault") var showMeasurementsByDefault: Bool = true
    @AppStorage("defaultUnit") var defaultUnit: String = MeasurementUnit.feet.rawValue

    var wallThicknessValue: WallThicknessSetting {
        get { WallThicknessSetting(rawValue: wallThickness) ?? .standard }
        set { wallThickness = newValue.rawValue }
    }

    var colorThemeValue: ColorTheme {
        get { ColorTheme(rawValue: colorTheme) ?? .classic }
        set { colorTheme = newValue.rawValue }
    }

    var labelSizeValue: LabelSizeSetting {
        get { LabelSizeSetting(rawValue: labelSize) ?? .medium }
        set { labelSize = newValue.rawValue }
    }

    var defaultExportFormatValue: ExportFormat {
        get { ExportFormat(rawValue: defaultExportFormat) ?? .pdf }
        set { defaultExportFormat = newValue.rawValue }
    }

    var exportResolutionValue: ExportResolution {
        get { ExportResolution(rawValue: exportResolution) ?? .high }
        set { exportResolution = newValue.rawValue }
    }

    var defaultUnitValue: MeasurementUnit {
        get { MeasurementUnit(rawValue: defaultUnit) ?? .feet }
        set { defaultUnit = newValue.rawValue }
    }
}
