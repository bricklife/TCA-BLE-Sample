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
    var discoveredPeripherals: [UUID : CBPeripheral] = [:]
    var isConnectingPeripheral = false
}

enum AppAction: Equatable {
    case centralManager(CentralManager.Action)
    case peripheral(Peripheral.Action)
    
    case onAppear
    case onDisappear
    case scanButtonTapped
    case stopButtonTapped
    case connectButtonTapped(uuid: UUID)
    case discoverButtonTapped
}

struct AppEnvironment {
    var mainQueue: AnySchedulerOf<DispatchQueue>
    var centralManager: CentralManager
    var peripheral: Peripheral
}

struct CentralManagerId: Hashable {}
struct PeripheralId: Hashable {}

let appReducer = Reducer<AppState, AppAction, AppEnvironment> { state, action, environment in
    switch action {
    case .centralManager(let action):
        switch action {
        case .centralManagerDidUpdateState:
            state.isEnableBLE = environment.centralManager.state(id: CentralManagerId()) == .poweredOn
            return .none
            
        case let .didDiscover(peripheral: peripheral, advertisementData: advertisementData, rssi: rssi):
            print("Discovered:", peripheral, advertisementData, rssi)
            state.discoveredPeripherals[peripheral.identifier] = peripheral
            return .none
            
        case let .didConnect(peripheral: peripheral):
            print("Connected:", peripheral.name ?? "nil")
            state.isConnectingPeripheral = true
            return environment.peripheral.create(id: PeripheralId(), peripheral: peripheral)
                .receive(on: environment.mainQueue)
                .eraseToEffect()
                .map(AppAction.peripheral)
            
        case let .didDisconnect(peripheral: peripheral, error: error):
            print("Disconnected", peripheral, error ?? "nil")
            return .none
            
        default:
            return .none
        }
        
    case .peripheral(let action):
        switch action {
        case .didDiscoverServices:
            print("Discovered Services:", environment.peripheral.services(id: PeripheralId()) ?? "nil")
            return .none
        }
        
    case .onAppear:
        return environment.centralManager.create(id: CentralManagerId(), queue: DispatchQueue(label: "com.bricklife.tca-ble"))
            .receive(on: environment.mainQueue)
            .eraseToEffect()
            .map(AppAction.centralManager)
        
    case .onDisappear:
        return environment.centralManager.destroy(id: CentralManagerId())
            .fireAndForget()
        
    case .scanButtonTapped:
        state.discoveredPeripherals = [:]
        state.isScanning = true
        return environment.centralManager.scanForPeripherals(id: CentralManagerId(), withServices: nil, options: nil)
            .fireAndForget()
        
    case .stopButtonTapped:
        state.isScanning = false
        return environment.centralManager.stopScan(id: CentralManagerId())
            .fireAndForget()
        
    case .connectButtonTapped(let uuid):
        if let peripheral = state.discoveredPeripherals[uuid] {
            return environment.centralManager.connect(id: CentralManagerId(), peripheral: peripheral, options: nil)
                .fireAndForget()
        }
        return .none
        
    case .discoverButtonTapped:
        return environment.peripheral.discoverServices(id: PeripheralId())
            .fireAndForget()
    }
}

struct ContentView: View {
    let store: Store<AppState, AppAction>
    
    var body: some View {
        WithViewStore(store) { viewStore in
            VStack(spacing: 10) {
                Text("Discovered \(viewStore.discoveredPeripherals.count) peripherals")
                if viewStore.state.isScanning {
                    Button("Stop") {
                        viewStore.send(.stopButtonTapped)
                    }.disabled(!viewStore.isEnableBLE)
                } else {
                    Button("Scan") {
                        viewStore.send(.scanButtonTapped)
                    }.disabled(!viewStore.isEnableBLE)
                }
                ForEach(Array(viewStore.discoveredPeripherals.keys), id: \.self) { uuid in
                    if let name = viewStore.discoveredPeripherals[uuid]?.name {
                        Button("Connect \"\(name)\"") {
                            viewStore.send(.connectButtonTapped(uuid: uuid))
                        }
                    }
                }
                Button("Discover Services") {
                    viewStore.send(.discoverButtonTapped)
                }.disabled(!viewStore.isConnectingPeripheral)
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
                    centralManager: CentralManager.live,
                    peripheral: Peripheral.live
                )
            )
        )
    }
}
