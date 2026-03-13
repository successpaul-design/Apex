import Foundation
import UIKit

class StorageService {
    static let shared = StorageService()

    private let fileManager = FileManager.default
    private let baseDirectory: URL

    private init() {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        baseDirectory = documents.appendingPathComponent("FloorPlans", isDirectory: true)

        // Ensure directory exists
        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Save

    func save(_ plan: FloorPlan) {
        let planDir = baseDirectory.appendingPathComponent(plan.id.uuidString, isDirectory: true)
        try? fileManager.createDirectory(at: planDir, withIntermediateDirectories: true)

        let metadataURL = planDir.appendingPathComponent("metadata.json")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        if let data = try? encoder.encode(plan) {
            try? data.write(to: metadataURL, options: .atomic)
        }
    }

    // MARK: - Load

    func loadAll() -> [FloorPlan] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var plans: [FloorPlan] = []

        for dir in contents {
            let metadataURL = dir.appendingPathComponent("metadata.json")
            guard let data = try? Data(contentsOf: metadataURL),
                  let plan = try? decoder.decode(FloorPlan.self, from: data) else {
                continue
            }
            plans.append(plan)
        }

        return plans.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Delete

    func delete(_ id: UUID) {
        let planDir = baseDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
        try? fileManager.removeItem(at: planDir)
    }

    // MARK: - USDZ Storage

    func saveUSDZ(data: Data, for planId: UUID) -> String {
        let planDir = baseDirectory.appendingPathComponent(planId.uuidString, isDirectory: true)
        try? fileManager.createDirectory(at: planDir, withIntermediateDirectories: true)

        let fileName = "room.usdz"
        let fileURL = planDir.appendingPathComponent(fileName)
        try? data.write(to: fileURL, options: .atomic)

        return fileName
    }

    func usdzURL(for planId: UUID, fileName: String) -> URL? {
        let fileURL = baseDirectory
            .appendingPathComponent(planId.uuidString, isDirectory: true)
            .appendingPathComponent(fileName)

        return fileManager.fileExists(atPath: fileURL.path) ? fileURL : nil
    }

    // MARK: - Thumbnail

    func saveThumbnail(_ image: UIImage, for planId: UUID) {
        let planDir = baseDirectory.appendingPathComponent(planId.uuidString, isDirectory: true)
        try? fileManager.createDirectory(at: planDir, withIntermediateDirectories: true)

        let fileURL = planDir.appendingPathComponent("thumbnail.jpg")
        if let data = image.jpegData(compressionQuality: 0.7) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func loadThumbnail(for planId: UUID) -> UIImage? {
        let fileURL = baseDirectory
            .appendingPathComponent(planId.uuidString, isDirectory: true)
            .appendingPathComponent("thumbnail.jpg")

        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
}
