//
//  EnergyCalculator.swift
//  WalkingEnergy
//
//  Created by Thomas Leese on 27/06/2017.
//  Copyright © 2017 Thomas Leese. All rights reserved.
//

import HealthKit

class EnergyCalculator {

    var alreadyCalculating = false

    let healthStore: HKHealthStore

    var anchor: HKQueryAnchor? = nil

    static let activeEnergyBurned = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
    static let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass)!
    static let distanceWalkingRunning = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!

    init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
    }

    func calculate() {
        if alreadyCalculating {
            print("Skipping calculation since it's already happening.")
            return
        }

        alreadyCalculating = true

        let predicate = HKQuery.predicateForObjects(from: [HKDevice.local()])

        let query = HKAnchoredObjectQuery(type: EnergyCalculator.distanceWalkingRunning, predicate: predicate, anchor: self.anchor, limit: HKObjectQueryNoLimit) { query, newSamples, deletedSamples, newAnchor, error in
            guard let samples = newSamples as? [HKQuantitySample], let deleted = deletedSamples else {
                print("Unable to query for step counts: \(error?.localizedDescription ?? "unknown") ***")
                self.alreadyCalculating = false
                return
            }

            self.anchor = newAnchor

            for sample in samples {
                self.handleStepCountAdded(sample)
            }

            print(samples.count)

            for deletedSample in deleted {
                self.handleStepCountDeleted(deletedSample)
            }

            self.alreadyCalculating = false
        }

        healthStore.execute(query)
    }

    func handleStepCountAdded(_ sample: HKQuantitySample) {
        let distance = sample.quantity.doubleValue(for: HKUnit.meterUnit(with: .kilo))
        let seconds = sample.endDate.timeIntervalSince(sample.startDate)

        guard seconds > 0 else {
            print("No time!")
            return
        }

        let hours = seconds / 60.0 / 60.0

        getBodyMass(when: sample.endDate) { weight in
            if let weight = weight {
                let energy = self.calculateEnergy(distance: distance, weight: weight, hours: hours)
                self.saveHealthKitSample(activeEnergy: energy, originalSample: sample)
            }
        }
    }

    func getBodyMass(when date: Date, completionHandler: @escaping (Double?) -> Void) {
        let startDate = date.addingTimeInterval(-14 * 24 * 60 * 60)
        let endDate = date.addingTimeInterval(24 * 60 * 60)

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate, end: endDate
        )

        let query = HKStatisticsQuery(quantityType: EnergyCalculator.bodyMass, quantitySamplePredicate: predicate, options: .discreteAverage) { query, result, error in
            if let error = error {
                print("Error! \(error)")
                completionHandler(nil)
                return
            }
            
            guard let result = result else {
                completionHandler(nil)
                return
            }

            print("Result: \(result)")

            let quantity = result.averageQuantity()!
            let weight = quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))

            completionHandler(weight)
        }
        
        healthStore.execute(query)
    }

    func handleStepCountDeleted(_ sample: HKDeletedObject) {

    }

    func calculateEnergy(distance: Double, weight: Double, hours: Double) -> Double {
        let speed = distance / hours
        let met = 1.0374071958881 + 0.46687607081667 * speed
        return met * weight * hours
    }

    func checkIfEnergyAlreadyRecorded(uuid: UUID, completionHandler: @escaping (Bool?) -> Void) {
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeyExternalUUID, allowedValues: [uuid.uuidString])

        let query = HKSampleQuery(sampleType: EnergyCalculator.activeEnergyBurned, predicate: predicate, limit: 1, sortDescriptors: nil) { query, results, error in
            guard let results = results else {
                print("Error: \(error?.localizedDescription ?? "unknown")")
                return completionHandler(nil)
            }

            completionHandler(results.count > 0)
        }

        healthStore.execute(query)
    }

    private func saveHealthKitSample(activeEnergy: Double, originalSample: HKQuantitySample) {
        checkIfEnergyAlreadyRecorded(uuid: originalSample.uuid) { alreadyExists in
            guard let alreadyExists = alreadyExists else {
                return
            }

            if alreadyExists {
                return
            }

            let sample = self.buildHealthKitSample(
                activeEnergy: activeEnergy, originalSample: originalSample
            )

            self.healthStore.save(sample) { (success, error) in
                if let error = error {
                    print("Error while saving energy: \(error.localizedDescription)")
                }
            }
        }
    }

    private func buildHealthKitSample(activeEnergy: Double, originalSample: HKQuantitySample) -> HKQuantitySample {
        let quantity = HKQuantity(
            unit: HKUnit.kilocalorie(),
            doubleValue: activeEnergy
        )

        return HKQuantitySample(
            type: EnergyCalculator.activeEnergyBurned,
            quantity: quantity,
            start: originalSample.startDate,
            end: originalSample.endDate,
            device: originalSample.device,
            metadata: [
                HKMetadataKeyExternalUUID: originalSample.uuid.uuidString,
            ]
        )
    }

}
