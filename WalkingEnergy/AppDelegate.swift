//
//  AppDelegate.swift
//  WalkingEnergy
//
//  Created by Thomas Leese on 27/06/2017.
//  Copyright © 2017 Thomas Leese. All rights reserved.
//

import HealthKit
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    let healthStore = HKHealthStore()

    lazy var energyCalculator: EnergyCalculator = {
        return EnergyCalculator(healthStore: self.healthStore)
    }()

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        let stepCount = HKObjectType.quantityType(forIdentifier: .stepCount)!

        let query = HKObserverQuery(sampleType: stepCount, predicate: nil) {
            query, completionHandler, error in

            if let error = error {
                switch error {
                case HKError.errorAuthorizationNotDetermined:
                    return
                default:
                    fatalError("Unknown error: \(error)")
                }
            }

            print("Got some data!")

            self.energyCalculator.calculate()

            completionHandler()
        }
        
        healthStore.execute(query)
        energyCalculator.calculate()

        return true
    }

}
