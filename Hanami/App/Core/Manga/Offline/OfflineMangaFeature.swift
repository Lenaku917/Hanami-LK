//
//  OfflineMangaViewStore.swift
//  Hanami
//
//  Created by Oleg on 23/07/2022.
//

import Foundation
import ComposableArchitecture

struct OfflineMangaFeature: ReducerProtocol {
    struct State: Equatable {
        let manga: Manga
        var coverArtPath: URL?
        
            // to compare with cached chapters, we retrieved last time
        var lastRetrievedChapterIDs: Set<UUID> = []
        
        init(manga: Manga) {
            self.manga = manga
        }
        
        var pagesState: PagesFeature.State?
        
        var selectedTab: Tab = .chapters
        
        // MARK: - Props for MangaReadingView
        @BindableState var isUserOnReadingView = false
        var mangaReadingViewState: OfflineMangaReadingFeature.State?
    }
    
    enum Tab: String, CaseIterable, Identifiable {
        case chapters = "Chapters"
        case info = "Info"
        
        var id: String { rawValue }
    }
    
    enum Action: BindableAction {
        case onAppear
        case cachedChaptersRetrieved(Result<[CachedChapterEntry], AppError>)
        case mangaTabChanged(Tab)
        case deleteManga
        case chaptersForMangaDeletionRetrieved(Result<[CachedChapterEntry], AppError>)
        
        case mangaReadingViewAction(OfflineMangaReadingFeature.Action)
        case pagesAction(PagesFeature.Action)
        
        case binding(BindingAction<State>)
    }
    
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.mangaClient) private var mangaClient
    @Dependency(\.cacheClient) private var cacheClient
    @Dependency(\.hudClient) private var hudClient
    @Dependency(\.logger) private var logger

    var body: some ReducerProtocol<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
                case .onAppear:
                    return databaseClient
                        .retrieveChaptersForManga(mangaID: state.manga.id)
                        .receive(on: DispatchQueue.main)
                        .catchToEffect(Action.cachedChaptersRetrieved)
                    
                case .cachedChaptersRetrieved(let result):
                    switch result {
                        case .success(let chapters):
                            // here we're checking if chapters, we've fetched, and chapters, we've fetched before are same
                            // if yes, we should do nothing
                            let chaptersIDsSet = Set(chapters.map(\.chapter.id))
                            guard state.lastRetrievedChapterIDs != chaptersIDsSet else {
                                return .none
                            }
                            
                            state.lastRetrievedChapterIDs = chaptersIDsSet
                            state.pagesState = PagesFeature.State(
                                manga: state.manga,
                                chaptersDetailsList: chapters.map(\.chapter),
                                chaptersPerPages: 10
                            )
                            return cacheClient
                                .saveCachedChaptersInMemory(state.manga.id, chaptersIDsSet)
                                .fireAndForget()
                            
                        case .failure(let error):
                            logger.error(
                                "Failed to retrieve chapters from disk: \(error)",
                                context: [
                                    "mangaID": "\(state.manga.id.uuidString.lowercased())",
                                    "mangaName": "\(state.manga.title)"
                                ]
                            )
                            return .none
                    }
                    
                case .mangaTabChanged(let tab):
                    state.selectedTab = tab
                    return .none
                    
                case .deleteManga:
                    return databaseClient
                        .retrieveChaptersForManga(mangaID: state.manga.id)
                        .catchToEffect(Action.chaptersForMangaDeletionRetrieved)
                    
                case .chaptersForMangaDeletionRetrieved(let result):
                    switch result {
                        case .success(let chapters):
                            var effects: [Effect<Action, Never>] = [
                                databaseClient.deleteManga(mangaID: state.manga.id)
                                    .fireAndForget(),
                                
                                cacheClient
                                    .removeAllCachedChapterIDsFromMemory(state.manga.id)
                                    .fireAndForget()
                            ]
                            
                            effects.append(
                                contentsOf: chapters.map { chapterEntity in
                                    mangaClient
                                        .removeCachedPagesForChapter(chapterEntity.chapter.id, chapterEntity.pagesCount, cacheClient)
                                        .fireAndForget()
                                }
                            )
                            return .merge(effects)
                            
                        case .failure(let error):
                            logger.error(
                                "Failed to retrieve chapters from disk for manga deletion: \(error)",
                                context: [
                                    "mangaID": "\(state.manga.id.uuidString.lowercased())",
                                    "mangaName": "\(state.manga.title)"
                                ]
                            )
                            return .none
                    }
                    
                    
                case .pagesAction:
                    return .none
                    
                case .mangaReadingViewAction:
                    return .none
                    
                case .binding:
                    return .none
            }
        }
        Reduce { state, action in
            switch action {
                case .pagesAction(.volumeTabAction(_, .chapterAction(_, .userTappedOnChapterDetails(let chapter)))):
                    guard let retrievedChapter = databaseClient.fetchChapter(chapterID: chapter.id) else {
                        hudClient.show(message: "😢 Error on retrieving saved chapter")
                        return .none
                    }
                    
                    state.mangaReadingViewState = OfflineMangaReadingFeature.State(
                        mangaID: state.manga.id,
                        chapter: retrievedChapter.chapter,
                        pagesCount: retrievedChapter.pagesCount,
                        startFromLastPage: false
                    )
                    
                    state.isUserOnReadingView = true
                    
                    return .task { .mangaReadingViewAction(.userStartedReadingChapter) }
                    
                case .mangaReadingViewAction(.userStartedReadingChapter):
                    if let pageIndex = mangaClient.getMangaPageForReadingChapter(
                        state.mangaReadingViewState?.chapter.attributes.chapterIndex,
                        state.pagesState!.splitIntoPagesVolumeTabStates
                    ) {
                        return .task { .pagesAction(.changePage(newPageIndex: pageIndex)) }
                    }
                    
                    return .none
                    
                case .mangaReadingViewAction(.userLeftMangaReadingView):
                    defer { state.isUserOnReadingView = false }
                    
                    let chapterIndex = state.mangaReadingViewState!.chapter.attributes.chapterIndex
                    let volumes = state.pagesState!.volumeTabStatesOnCurrentPage
                    
                    guard let info = mangaClient.findDidReadChapterOnMangaPage(chapterIndex, volumes) else {
                        return .none
                    }
                    
                        // chapterState, on which user has left MangaReadingView
                    let chapterState = state.pagesState!
                        .volumeTabStatesOnCurrentPage[id: info.volumeID]!
                        .chapterStates[id: info.chapterID]!
                    
                    if chapterState.areChaptersShown {
                        return .none
                    }
                    
                    return .task {
                        .pagesAction(
                            .volumeTabAction(
                                volumeID: info.volumeID,
                                volumeAction: .chapterAction(
                                    id: info.chapterID,
                                    action: .fetchChapterDetailsIfNeeded
                                )
                            )
                        )
                    }
                    
                default:
                    return .none
            }
        }
        .ifLet(\.pagesState, action: /Action.pagesAction) {
            PagesFeature()
        }
        .ifLet(\.mangaReadingViewState, action: /Action.mangaReadingViewAction) {
            OfflineMangaReadingFeature()
        }
    }
}
