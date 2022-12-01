//
//  SettingsConfig.swift
//  Hanami
//
//  Created by Oleg on 21.11.22.
//

import Foundation

struct SettingsConfig: Codable, Equatable {
    var autolockPolicy: AutoLockPolicy
    var blurRadius: Double
    var useHigherQualityImagesForOnlineReading: Bool
    var useHigherQualityImagesForCaching: Bool
}
