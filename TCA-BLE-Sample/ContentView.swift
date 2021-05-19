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
import ComposableBluetoothPeripheralManager

struct AppState: Equatable {
    var isEnableBLE = false
    var isScanning = false
    var discoveredPeripherals: [CBPeripheral] = []
    var isConnectingPeripheral = false
}

enum AppAction: Equatable {
    case centralManager(CentralManager.Action)
    case peripheralManager(PeripheralManager.Action)
    
    case onAppear
    case onDisappear
    case scanButtonTapped
    case stopButtonTapped
    case connectButtonTapped(uuid: UUID)
}

struct AppEnvironment {
    var mainQueue: AnySchedulerOf<DispatchQueue>
    var centralManager: CentralManager
    var peripheralManager: PeripheralManager
}

struct CentralManagerId: Hashable {}
struct PeripheralManagerId: Hashable {}

let appReducer = Reducer<AppState, AppAction, AppEnvironment> { state, action, environment in
    
    switch action {
    case .centralManager(let action):
        switch action {
        case .centralManagerDidUpdateState:
            state.isEnableBLE = environment.centralManager.state(id: CentralManagerId()) == .poweredOn
            return .none
            
        case let .didDiscover(peripheral: peripheral, advertisementData: advertisementData, rssi: rssi):
            print("Discovered:", peripheral, advertisementData, rssi)
            if !state.discoveredPeripherals.contains(peripheral) {
                state.discoveredPeripherals.append(peripheral)
            }
            return .none
            
        case let .didConnect(peripheral: peripheral):
            print("Connected:", peripheral.name ?? "nil")
            state.isConnectingPeripheral = true
            return environment.peripheralManager.addPeripheral(id: PeripheralManagerId(), peripheral: peripheral, services: nil)
                .fireAndForget()
            
        case let .didDisconnect(peripheral: peripheral, error: error):
            print("Disconnected", peripheral, error ?? "nil")
            return .none
            
        default:
            return .none
        }
        
    case .peripheralManager(let action):
        switch action {
        case let .didDiscoverServices(peripheral, error: error):
            print("Discovered Services:", peripheral.services ?? "nil")
            return .none
            
        default:
            return .none
        }
        
    case .onAppear:
        return .merge(
            environment.centralManager.create(id: CentralManagerId(), queue: DispatchQueue(label: "com.bricklife.tca-ble"))
                .receive(on: environment.mainQueue)
                .eraseToEffect()
                .map(AppAction.centralManager),
            environment.peripheralManager.create(id: PeripheralManagerId())
                .receive(on: environment.mainQueue)
                .eraseToEffect()
                .map(AppAction.peripheralManager)
        )
        
    case .onDisappear:
        return .merge(
            environment.centralManager.destroy(id: CentralManagerId())
                .fireAndForget(),
            environment.peripheralManager.destroy(id: PeripheralManagerId())
                .fireAndForget()
        )
        
    case .scanButtonTapped:
        state.discoveredPeripherals = []
        state.isScanning = true
        return environment.centralManager.scanForPeripherals(id: CentralManagerId(), withServices: nil, options: nil)
            .fireAndForget()
        
    case .stopButtonTapped:
        state.isScanning = false
        return environment.centralManager.stopScan(id: CentralManagerId())
            .fireAndForget()
        
    case .connectButtonTapped(let uuid):
        if let peripheral = state.discoveredPeripherals.first(where: { $0.identifier == uuid }) {
            return environment.centralManager.connect(id: CentralManagerId(), peripheral: peripheral, options: nil)
                .fireAndForget()
        }
        return .none
    }
}

struct ContentView: View {
    let store: Store<AppState, AppAction>
    
    var body: some View {
        WithViewStore(store) { viewStore in
            VStack(alignment: .leading ,spacing: 10) {
                HStack(spacing: 10) {
                    if viewStore.state.isScanning {
                        Button("Stop") {
                            viewStore.send(.stopButtonTapped)
                        }.disabled(!viewStore.isEnableBLE)
                    } else {
                        Button("Scan") {
                            viewStore.send(.scanButtonTapped)
                        }.disabled(!viewStore.isEnableBLE)
                    }
                    Text("Discovered \(viewStore.discoveredPeripherals.count) peripherals")
                }
                
                Divider()
                
                List(viewStore.discoveredPeripherals, id: \.self) { peripheral in
                    Button(peripheral.name ?? "Unknown") {
                        viewStore.send(.connectButtonTapped(uuid: peripheral.identifier))
                    }
                }
            }
            .padding()
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
                    centralManager: CentralManager.live,
                    peripheralManager: PeripheralManager.live
                )
            )
        )
    }
}
