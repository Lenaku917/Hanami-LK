//
//  Defaults.swift
//  Hanami
//
//  Created by Oleg on 12/10/2022.
//

import Foundation

enum Defaults {
    enum FilePath {
        static let logs = "logs"
        static let hanamiLog = "Hanami.log"
    }
    
    enum Security {
        // set `minBlurRadius` to 0.1 because setting it lower value causes UI bug
        static let minBlurRadius = 0.1
        static let maxBlurRadius = 20.1
        static let blurRadiusStep = 1.0
    }
    
    enum Storage {
        static let settingsConfig = "settingsConfig"
    }
}
