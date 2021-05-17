//
//  BLESampleApp.swift
//  TCA-BLE-Sample
//
//  Created by Shinichiro Oba on 2021/05/17.
//

import SwiftUI
import ComposableArchitecture
import ComposableBluetoothCentralManager

@main
struct BLESampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(
                store: Store(
                    initialState: AppState(),
                    reducer: appReducer,
                    environment: AppEnvironment(
                        mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
                        centralManager: CentralManager.live
                    )
                )
            )
        }
    }
}
