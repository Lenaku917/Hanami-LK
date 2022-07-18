//
//  ThumbnailFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 15/05/2022.
//

import Foundation
import ComposableArchitecture
import SwiftUI

struct MangaThumbnailState: Equatable, Identifiable {
    init(manga: Manga) {
        self.manga = manga
        self.mangaState = MangaViewState(manga: manga)
    }
    
    var mangaState: MangaViewState
    let manga: Manga
    var coverArtInfo: CoverArtInfo?
    
    var mangaStatistics: MangaStatistics? {
        mangaState.statistics
    }
    
    var id: UUID { manga.id }
}

enum MangaThumbnailAction {
    case onAppear
    case thumbnailInfoLoaded(Result<Response<CoverArtInfo>, AppError>)
    case userOpenedMangaView
    case userLeftMangaView
    case userLeftMangaViewDelayCompleted
    case mangaAction(MangaViewAction)
}

struct MangaThumbnailEnvironment {
    var databaseClient: DatabaseClient
    let mangaClient: MangaClient
}

let mangaThumbnailReducer = Reducer<MangaThumbnailState, MangaThumbnailAction, MangaThumbnailEnvironment>.combine(
    mangaViewReducer.pullback(
        state: \.mangaState,
        action: /MangaThumbnailAction.mangaAction,
        environment: { .init(
            databaseClient: $0.databaseClient,
            mangaClient: $0.mangaClient
        ) }
    ),
    Reducer { state, action, env in
        switch action {
            case .onAppear:
                // if we already loaded info about cover, we don't need to do it one more time
                guard state.coverArtInfo == nil else { return .none }

                guard let coverArtID = state.manga.relationships.first(where: { $0.type == .coverArt })?.id else {
                    return .none
                }
                
                return env.mangaClient.fetchCoverArtInfo(coverArtID)
                    .receive(on: DispatchQueue.main)
                    .catchToEffect(MangaThumbnailAction.thumbnailInfoLoaded)
                
            case .thumbnailInfoLoaded(let result):
                switch result {
                    case .success(let response):
                        state.coverArtInfo = response.data
                        state.mangaState.mainCoverArtURL = state.coverArtInfo?.coverArtURL
                        state.mangaState.coverArtURL512 = state.coverArtInfo?.coverArtURL512
                        return .none
                        
                    case .failure(let error):
                        print("error on downloading thumbnail info: \(error)")
                        return .none
                }
                
            case .userOpenedMangaView:
                // when users enters the view, we must cancel clearing manga info
                return .cancel(id: MangaViewState.CancelClearCacheForManga(mangaID: state.manga.id))
                
            case .userLeftMangaView:
                // Runs a delay(60 sec.) when user leaves MangaView, after that all downloaded data will be deleted to save RAM
                // Can be cancelled if user returns wihing 60 sec.
                return Effect(value: MangaThumbnailAction.userLeftMangaViewDelayCompleted)
                    .delay(for: .seconds(60), scheduler: DispatchQueue.main)
                    .eraseToEffect()
                    .cancellable(id: MangaViewState.CancelClearCacheForManga(mangaID: state.manga.id))
                
            case .userLeftMangaViewDelayCompleted:
                state.mangaState.reset()
                return .none
                
            case .mangaAction:
                return .none
        }
    }
)
