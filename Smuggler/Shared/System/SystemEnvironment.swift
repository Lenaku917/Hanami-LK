//
//  AppEnvironment.swift
//  Smuggler
//
//  Created by mk.pwnz on 13/05/2022.
//

import ComposableArchitecture
import SwiftUI

@dynamicMemberLookup
public struct SystemEnvironment<Environment> {
    var environment: Environment
    
    subscript<Dependency>(
        dynamicMember keyPath: WritableKeyPath<Environment, Dependency>
    ) -> Dependency {
        get { self.environment[keyPath: keyPath] }
        set { self.environment[keyPath: keyPath] = newValue }
    }
    
    var mainQueue: () -> AnySchedulerOf<DispatchQueue>
    var decoder: () -> JSONDecoder
    
    private static func decoder() -> JSONDecoder {
        AppUtil.decoder
    }
    
    static func live(environment: Environment, isMainQueueAnimated: Bool = false) -> Self {
        Self(
            environment: environment,
            mainQueue: { isMainQueueAnimated ? .main.animation(.linear) : .main },
            decoder: decoder
        )
    }
}
