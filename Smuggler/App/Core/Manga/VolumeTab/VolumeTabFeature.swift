//
//  VolumeFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 26/05/2022.
//

import Foundation
import ComposableArchitecture

struct VolumeTabState: Equatable {
    init(volume: Volume) {
        self.volume = volume
        chapterStates = .init(uniqueElements: volume.chapters.map { ChapterState(chapter: $0) })
    }
    
    let volume: Volume
    var chapterStates: IdentifiedArrayOf<ChapterState> = []
    
    var chapters: [ChapterDetails] = []
}

extension VolumeTabState: Identifiable {
    var id: UUID {
        volume.id
    }
}

enum VolumeTabAction: Equatable {
    case onTapGesture
    case chapterAction(id: UUID, action: ChapterAction)
}

struct VolumeTabEnvironment {
    
}

let volumeTabReducer: Reducer<VolumeTabState, VolumeTabAction, SystemEnvironment<VolumeTabEnvironment>> = .combine(
    chapterReducer.forEach(
        state: \.chapterStates,
        action: /VolumeTabAction.chapterAction,
        environment:  { _ in .live(
            environment: .init(
                downloadPagesInfo: downloadPageInfoForChapter,
                downloadChapterInfo: downloadChapterInfo
            ),
            isMainQueueWithAnimation: true
        ) }
    ),
    Reducer { state, action, env in
        switch action {
            case .onTapGesture:
                return .none
            case .chapterAction(_, _):
                return .none
        }
    }
)
