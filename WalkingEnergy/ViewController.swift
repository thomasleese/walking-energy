//
//  ViewController.swift
//  WalkingEnergy
//
//  Created by Thomas Leese on 27/06/2017.
//  Copyright © 2017 Thomas Leese. All rights reserved.
//

import HealthKit
import UIKit

class ViewController: UIViewController {

    let healthStore = HKHealthStore()

    let healthDataToWrite: Set<HKQuantityType> = [
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
    ]

    let healthDataToRead: Set<HKQuantityType> = [
        HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKObjectType.quantityType(forIdentifier: .bodyMass)!,
    ]

    override func viewDidLoad() {
        super.viewDidLoad()

        guard HKHealthStore.isHealthDataAvailable() else {
            return
        }

        healthStore.requestAuthorization(toShare: healthDataToWrite, read: healthDataToRead) { success, error in

            self.healthStore.enableBackgroundDelivery(for: EnergyCalculator.distanceWalkingRunning, frequency: .immediate) { success, error in
                print("Background delivery enabled!")
            }
        }
    }

}
