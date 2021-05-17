//
//  ContentView.swift
//  TCA-BLE-Sample
//
//  Created by Shinichiro Oba on 2021/05/17.
//

import SwiftUI
import CoreBluetooth
import ComposableArchitecture
import ComposableBluetoothCentralManager

struct AppState: Equatable {
    var isEnableBLE = false
    var isScanning = false
    var discoveredDevices: [CBPeripheral] = []
}

enum AppAction: Equatable {
    case centralManager(CentralManager.Action)
    
    case onAppear
    case onDisappear
    case scanButtonTapped
    case stopButtonTapped
}

struct AppEnvironment {
    var mainQueue: AnySchedulerOf<DispatchQueue>
    var centralManager: CentralManager
}

struct CentralManagerId: Hashable {}

let appReducer = Reducer<AppState, AppAction, AppEnvironment> { state, action, environment in
    switch action {
    case .centralManager(let action):
        switch action {
        case .centralManagerDidUpdateState:
            state.isEnableBLE = environment.centralManager.state(id: CentralManagerId()) == .poweredOn
            
        case let .didDiscover(peripheral: peripheral, advertisementData: advertisementData, rssi: rssi):
            print("Discovered:", peripheral, advertisementData, rssi)
            state.discoveredDevices.append(peripheral)
            
        default:
            break
        }
        return .none
        
    case .onAppear:
        return environment.centralManager.create(id: CentralManagerId())
            .map(AppAction.centralManager)
        
    case .onDisappear:
        return environment.centralManager.destroy(id: CentralManagerId())
            .fireAndForget()
        
    case .scanButtonTapped:
        state.discoveredDevices = []
        state.isScanning = true
        return environment.centralManager.scanForPeripherals(id: CentralManagerId(), withServices: nil, options: nil)
            .fireAndForget()
        
    case .stopButtonTapped:
        state.isScanning = false
        return environment.centralManager.stopScan(id: CentralManagerId())
            .fireAndForget()
    }
}

struct ContentView: View {
    let store: Store<AppState, AppAction>
    
    var body: some View {
        WithViewStore(store) { viewStore in
            VStack(spacing: 10) {
                Text("Discovered \(viewStore.discoveredDevices.count) devices")
                if viewStore.state.isScanning {
                    Button("Stop") {
                        viewStore.send(.stopButtonTapped)
                    }.disabled(!viewStore.isEnableBLE)
                } else {
                    Button("Scan") {
                        viewStore.send(.scanButtonTapped)
                    }.disabled(!viewStore.isEnableBLE)
                }
            }
            .onAppear { viewStore.send(.onAppear) }
            .onDisappear { viewStore.send(.onDisappear) }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
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
