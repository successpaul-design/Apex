import Foundation
import SwiftUI

class FloorPlanViewModel: ObservableObject {
    @Published var floorPlans: [FloorPlan] = []

    private let storage = StorageService.shared

    init() {
        loadFloorPlans()
    }

    func loadFloorPlans() {
        floorPlans = storage.loadAll()
    }

    func addFloorPlan(_ plan: FloorPlan) {
        floorPlans.insert(plan, at: 0)
        storage.save(plan)
    }

    func deleteFloorPlan(at offsets: IndexSet) {
        for index in offsets {
            let plan = floorPlans[index]
            storage.delete(plan.id)
        }
        floorPlans.remove(atOffsets: offsets)
    }

    func deleteFloorPlan(id: UUID) {
        storage.delete(id)
        floorPlans.removeAll { $0.id == id }
    }

    func floorPlan(for id: UUID) -> FloorPlan? {
        floorPlans.first { $0.id == id }
    }

    // MARK: - Labels

    func addLabel(_ label: RoomLabel, to planId: UUID) {
        guard let index = floorPlans.firstIndex(where: { $0.id == planId }) else { return }
        floorPlans[index].roomLabels.append(label)
        storage.save(floorPlans[index])
    }

    func removeLabel(_ labelId: UUID, from planId: UUID) {
        guard let index = floorPlans.firstIndex(where: { $0.id == planId }) else { return }
        floorPlans[index].roomLabels.removeAll { $0.id == labelId }
        storage.save(floorPlans[index])
    }

    func updateFloorPlan(_ plan: FloorPlan) {
        guard let index = floorPlans.firstIndex(where: { $0.id == plan.id }) else { return }
        floorPlans[index] = plan
        storage.save(plan)
    }

    func renamePlan(id: UUID, name: String) {
        guard let index = floorPlans.firstIndex(where: { $0.id == id }) else { return }
        floorPlans[index].name = name
        storage.save(floorPlans[index])
    }
}
