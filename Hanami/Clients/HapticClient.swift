//
//  HapticClient.swift
//  Hanami
//
//  Created by tatsuz0u
//  https://github.com/EhPanda-Team/EhPanda/blob/main/EhPanda/App/Tools/Clients/HapticClient.swift
//

import SwiftUI
import ComposableArchitecture
import Utils

extension DependencyValues {
    var hapticClient: HapticClient {
        get { self[HapticClient.self] }
        set { self[HapticClient.self] = newValue }
    }
}

struct HapticClient {
    let generateFeedback: (UIImpactFeedbackGenerator.FeedbackStyle) -> EffectTask<Never>
    let generateNotificationFeedback: (UINotificationFeedbackGenerator.FeedbackType) -> EffectTask<Never>
}

extension HapticClient: DependencyKey {
    static let liveValue: HapticClient = .init(
        generateFeedback: { style in
            .run { _ in
                HapticUtil.generateFeedback(style: style)
            }
        },
        generateNotificationFeedback: { style in
            .run { _ in
                HapticUtil.generateNotificationFeedback(style: style)
            }
        }
    )
}
