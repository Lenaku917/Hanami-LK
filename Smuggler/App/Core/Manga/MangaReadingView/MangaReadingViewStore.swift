//
//  MangaReadingViewFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/06/2022.
//

import Foundation
import ComposableArchitecture
import Kingfisher

struct MangaReadingViewState: Equatable {
    init(chapterID: UUID, chapterIndex: Double?, shoudSendUserToTheLastPage: Bool = false) {
        self.chapterID = chapterID
        self.chapterIndex = chapterIndex
        self.shouldSendUserToTheLastPage = shoudSendUserToTheLastPage
    }
    
    let chapterID: UUID
    let chapterIndex: Double?
    // this will be used, when user get to this chapter from the next following one
    let shouldSendUserToTheLastPage: Bool
    
    var pagesInfo: ChapterPagesInfo?
    var pagesCount: Int {
        pagesInfo?.dataSaverURLs.count ?? 0
    }
}

enum MangaReadingViewAction {
    case userStartedReadingChapter
    case chapterPagesInfoFetched(Result<ChapterPagesInfo, AppError>)
    case userChangedPage(newPageIndex: Int)

    // MARK: - Actions to be hijacked in MangaFeature
    case userHitLastPage
    case userHitTheMostFirstPage
    case userLeftMangaReadingView
}

struct MangaReadingViewEnvironment {
    var mangaClient: MangaClient
}

// swiftlint:disable:next line_length
let mangaReadingViewReducer = Reducer<MangaReadingViewState, MangaReadingViewAction, MangaReadingViewEnvironment> { state, action, env in
    switch action {
        case .userStartedReadingChapter:
            guard state.pagesInfo == nil else {
                return .none
            }
            
            return env.mangaClient.fetchPagesInfo(state.chapterID)
                .receive(on: DispatchQueue.main)
                .catchToEffect(MangaReadingViewAction.chapterPagesInfoFetched)
            
        case .chapterPagesInfoFetched(let result):
            switch result {
                case .success(let chapterPagesInfo):
                    state.pagesInfo = chapterPagesInfo
                    
                    ImagePrefetcher(
                        urls: chapterPagesInfo.dataSaverURLs,
                        options: [.memoryCacheExpiration(.days(1))]
                    ).start()
                    
                    return .none

                case .failure(let error):
                    print("error on fetching chapterPagesInfo: \(error)")
                    return .none
            }
            
        case .userChangedPage(let newPageIndex):
            if newPageIndex == -1 {
                return Effect(value: MangaReadingViewAction.userHitTheMostFirstPage)
            } else if newPageIndex == state.pagesInfo?.dataSaverURLs.count {
                return Effect(value: MangaReadingViewAction.userHitLastPage)
            }

            return .none
            
        // MARK: - Actions to be hijacked in MangaFeature
        case .userHitLastPage:
            return .none
            
        case .userHitTheMostFirstPage:
            return .none
            
        case .userLeftMangaReadingView:
            return .none
    }
}
