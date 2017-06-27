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

    var healthStore: HKHealthStore {
        get {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            return appDelegate.healthStore
        }
    }

    let healthDataToWrite: Set<HKQuantityType> = [
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
    ]

    let healthDataToRead: Set<HKQuantityType> = [
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKObjectType.quantityType(forIdentifier: .bodyMass)!,
    ]

    override func viewDidLoad() {
        super.viewDidLoad()

        guard HKHealthStore.isHealthDataAvailable() else {
            return
        }

        healthStore.requestAuthorization(toShare: healthDataToWrite, read: healthDataToRead) { (success, error) in

            let stepCount = HKObjectType.quantityType(forIdentifier: .stepCount)!

            self.healthStore.enableBackgroundDelivery(for: stepCount, frequency: .immediate) { (success, error) in
                print("Background delivery enabled!")
            }
        }
    }

}

