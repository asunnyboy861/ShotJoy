import Foundation
import HealthKit

@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()
    private let store = HKHealthStore()

    @Published var authorized = false
    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "healthKitEnabled") }
    }

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: "healthKitEnabled")
        if isEnabled {
            requestAuthorization { _ in }
        }
    }

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard Self.isAvailable else {
            completion(false)
            return
        }
        var read: Set<HKObjectType> = []
        if let t = HKObjectType.quantityType(forIdentifier: .bodyMass) { read.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .stepCount) { read.insert(t) }
        if let t = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { read.insert(t) }
        var write: Set<HKSampleType> = []
        if let t = HKObjectType.quantityType(forIdentifier: .bodyMass) { write.insert(t) }

        store.requestAuthorization(toShare: write, read: read) { [weak self] success, _ in
            DispatchQueue.main.async {
                self?.authorized = success
                completion(success)
            }
        }
    }

    func writeWeight(kg: Double, date: Date = Date()) async -> Bool {
        guard Self.isAvailable, isEnabled, let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return false }
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        do {
            try await store.save(sample)
            return true
        } catch {
            return false
        }
    }

    func readLatestWeight() async -> Double? {
        guard Self.isAvailable, let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return nil }
        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    func readTodaySteps() async -> Double {
        guard Self.isAvailable, let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                let value = stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    func readLastNightSleep() async -> Double {
        guard Self.isAvailable, let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
        let start = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 100, sortDescriptors: nil) { _, samples, _ in
                var total: Double = 0
                for s in samples ?? [] {
                    guard let cat = (s as? HKCategorySample)?.value,
                          cat == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                          cat == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                          cat == HKCategoryValueSleepAnalysis.asleepREM.rawValue else { continue }
                    total += s.endDate.timeIntervalSince(s.startDate)
                }
                continuation.resume(returning: total / 3600)
            }
            store.execute(query)
        }
    }
}
