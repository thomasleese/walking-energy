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

    let activeEnergyBurned = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
    let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass)!
    let distanceWalkingRunning = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!

    init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
    }

    func calculate() {
        if alreadyCalculating {
            print("Skipping calculation since it's already happening.")
            return
        }

        alreadyCalculating = true
        print("Calculating new energy!")

        let query = HKAnchoredObjectQuery(type: distanceWalkingRunning, predicate: nil, anchor: self.anchor, limit: HKObjectQueryNoLimit) { (query, newSamples, deletedSamples, newAnchor, error) -> Void in

            guard let samples = newSamples as? [HKQuantitySample], let deleted = deletedSamples else {
                // Add proper error handling here...
                print("Unable to query for step counts: \(error?.localizedDescription) ***")
                self.alreadyCalculating = false
                return
            }

            self.anchor = newAnchor

            for sample in samples {
                self.handleStepCountAdded(sample)
            }

            for deletedSample in deleted {
                self.handleStepCountDeleted(deletedSample)
            }

            self.alreadyCalculating = false
        }

        healthStore.execute(query)
    }

    func handleStepCountAdded(_ sample: HKQuantitySample) {
        let distance = sample.quantity.doubleValue(for: HKUnit.meter())
        let time = sample.endDate.timeIntervalSince(sample.startDate)
        guard time > 0 else {
            print("No time!")
            return
        }

        getBodyMass(when: sample.endDate) { (weight) in
            if let weight = weight {
                let energy = self.calculateEnergy(distance: distance, weight: weight, time: time)
                self.recordEnergySample(energy: energy, originalSample: sample)
            }
        }
    }

    func getBodyMass(when date: Date, completionHandler: @escaping (Double?) -> Void) {
        let startDate = date.addingTimeInterval(-1 * 24 * 60 * 60)
        let endDate = date.addingTimeInterval(7 * 24 * 60 * 60)

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate, end: endDate
        )

        let query = HKStatisticsQuery(quantityType: bodyMass, quantitySamplePredicate: predicate, options: .discreteAverage) { query, result, error in

            guard let result = result else {
                completionHandler(nil)
                return
            }

            let quantity = result.averageQuantity()!
            let weight = quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))

            completionHandler(weight)
        }
        
        healthStore.execute(query)
    }

    func handleStepCountDeleted(_ sample: HKDeletedObject) {

    }

    func calculateEnergy(distance: Double, weight: Double, time: Double) -> Double {
        let speed = distance / time
        let met = 1.0374071958881 + 0.46687607081667 * speed
        return met * weight * time
    }

    func checkIfEnergyAlreadyRecorded(uuid: UUID, completionHandler: @escaping (Bool?) -> Void) {
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeyExternalUUID, allowedValues: [uuid.uuidString])

        let query = HKSampleQuery(sampleType: activeEnergyBurned, predicate: predicate, limit: 1, sortDescriptors: nil) { query, results, error in

            guard let results = results else {
                print("Error: \(error?.localizedDescription)")
                return completionHandler(nil)
            }

            completionHandler(results.count > 0)
        }

        healthStore.execute(query)
    }

    func recordEnergySample(energy: Double, originalSample: HKQuantitySample) {
        checkIfEnergyAlreadyRecorded(uuid: originalSample.uuid) { alreadyExists in
            guard let alreadyExists = alreadyExists else {
                return
            }

            if alreadyExists {
                return
            }

            let quantity = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: energy)

            let sample = HKQuantitySample(
                type: self.activeEnergyBurned,
                quantity: quantity,
                start: originalSample.startDate,
                end: originalSample.endDate,
                device: originalSample.device,
                metadata: [
                    HKMetadataKeyExternalUUID: originalSample.uuid.uuidString,
                ]
            )

            self.healthStore.save(sample) { (success, error) in
                if let error = error {
                    print("Error while saving energy: \(error.localizedDescription)")
                }
            }
        }
    }

}
