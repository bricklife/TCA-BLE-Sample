//
//  Peripheral.swift
//  TCA-BLE-Sample
//
//  Created by Shinichiro Oba on 2021/05/18.
//

import Combine
import ComposableArchitecture
import CoreBluetooth

public struct Peripheral: Equatable {
    public enum Action: Equatable {
        case didDiscoverServices(error: Error?)
    }
    
    public struct Error: Swift.Error, Equatable {
        public let error: NSError?
        
        public init(_ error: Swift.Error?) {
            self.error = error as NSError?
        }
    }
    
    public func create(id: AnyHashable, peripheral: CBPeripheral) -> Effect<Action, Never> {
        Effect.run { subscriber in
            let delegate = PeripheralDelegate(subscriber)
            peripheral.delegate = delegate
            
            dependencies[id] = Dependencies(delegate: delegate,
                                            peripheral: peripheral,
                                            subscriber: subscriber)
            return AnyCancellable {
                dependencies[id] = nil
            }
        }
    }
    
    public func destroy(id: AnyHashable) -> Effect<Never, Never> {
        .fireAndForget {
            dependencies[id]?.subscriber.send(completion: .finished)
            dependencies[id] = nil
        }
    }
    
    public func discoverServices(id: AnyHashable, serviceUUIDs: [CBUUID]? = nil) -> Effect<Never, Never> {
        .fireAndForget {
            dependencies[id]?.peripheral.discoverServices(serviceUUIDs)
        }
    }
    
    public func services(id: AnyHashable) -> [CBService]? {
        return dependencies[id]?.peripheral.services
    }
}

private struct Dependencies {
    let delegate: CBPeripheralDelegate
    let peripheral: CBPeripheral
    let subscriber: Effect<Peripheral.Action, Never>.Subscriber
}

private var dependencies: [AnyHashable: Dependencies] = [:]

private class PeripheralDelegate: NSObject, CBPeripheralDelegate {
    let subscriber: Effect<Peripheral.Action, Never>.Subscriber
    
    init(_ subscriber: Effect<Peripheral.Action, Never>.Subscriber) {
        self.subscriber = subscriber
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        subscriber.send(.didDiscoverServices(error: Peripheral.Error(error)))
    }
}

public extension Peripheral {
    static let live = Peripheral()
}
