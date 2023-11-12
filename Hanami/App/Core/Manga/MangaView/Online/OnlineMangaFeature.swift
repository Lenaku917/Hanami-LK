//
//  MangaFeature.swift
//  Hanami
//
//  Created by Oleg on 16/05/2022.
//

import Foundation
import ComposableArchitecture
import class SwiftUI.UIImage
import ModelKit
import Utils
import DataTypeExtensions
import Logger
import ImageClient
import SettingsClient

// swiftlint:disable:next type_body_length
struct OnlineMangaFeature: Reducer {
    struct State: Equatable {
        // MARK: - Props for view
        let manga: Manga
        var pagesState: PagesFeature.State?
        
        init(manga: Manga) {
            self.manga = manga
        }
        
        var statistics: MangaStatistics?
        
        var allCoverArtsInfo: [CoverArtInfo] = []
        var selectedTab: Tab = .chapters
        var lastReadChapterID: UUID?
        
        var mainCoverArtURL: URL?
        var coverArtURL256: URL?
        var croppedCoverArtURLs: [URL] {
            allCoverArtsInfo.compactMap(\.coverArtURL512)
        }
        var isErrorOccured = false
        
        // different chapter option to start reading manga
        // swiftlint:disable:next identifier_name
        var _firstChapterOptions: [ChapterDetails]?
        var firstChapterOptions: [ChapterDetails]?
        // MARK: END Props for view
        
        // MARK: - Props for MangaReadingView
        var isMangaReadingViewPresented = false
        var mangaReadingViewState: OnlineMangaReadingFeature.State? {
            didSet { isMangaReadingViewPresented = mangaReadingViewState.hasValue }
        }
        // MARK: END Props for MangaReadingView
        
        // MARK: - Props for inner states/views
        var authorViewState: AuthorFeature.State?
        var chapterLoaderState: MangaChapterLoaderFeature.State?
        var showAuthorView = false
        // MARK: END Props for inner states/views
        
        // MARK: - Behavior props
        var lastRefreshedAt: Date?
        // preffered lang for reading manga
        var prefferedLanguage: ISO639Language?
        // MARK: END Behavior props
    }
    
    enum Tab: String, CaseIterable, Identifiable {
        case chapters = "Chapters"
        case info = "Info"
        case coverArt = "Art"
        
        var id: String { rawValue }
    }
    
    enum Action {
        // MARK: - Actions to be called from view
        case onAppear
        case navigationTabButtonTapped(Tab)
        case authorNameTapped(Author)
        case refreshButtonTapped
        case continueReadingButtonTapped
        case startReadingButtonTapped
        case userTappedOnFirstChapterOption(ChapterDetails)
        case userTappedOnChapterLoaderButton
        case showAuthorViewValueDidChange(to: Bool)
        case nowReadingViewStateDidUpdate(to: Bool)
        
        // MARK: - Actions to be called from reducer
        case volumesRetrieved(Result<VolumesContainer, AppError>)
        case lastReadChapterRetrieved(Result<UUID, AppError>)
        case mangaStatisticsDownloaded(Result<MangaStatisticsContainer, AppError>)
        case allCoverArtsInfoFetched(Result<Response<[CoverArtInfo]>, AppError>)
        case chapterDetailsForContinueReadingFetched(Result<Response<ChapterDetails>, AppError>)
        case settingsConfigRetrieved(Result<SettingsConfig, AppError>)
        case firstChapterOptionRetrieved(Result<Response<ChapterDetails>, AppError>)
        case allFirstChaptersRetrieved
        
        // MARK: - Substate actions
        case mangaReadingViewAction(OnlineMangaReadingFeature.Action)
        case pagesAction(PagesFeature.Action)
        case authorViewAction(AuthorFeature.Action)
        case chapterLoaderAcion(MangaChapterLoaderFeature.Action)

        // MARK: - Actions for saving chapters for offline reading
        case coverArtForCachingFetched(Result<UIImage, AppError>)
    }
    
    @Dependency(\.mangaClient) private var mangaClient
    @Dependency(\.cacheClient) private var cacheClient
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.imageClient) private var imageClient
    @Dependency(\.settingsClient) private var settingsClient
    @Dependency(\.hudClient) private var hudClient
    @Dependency(\.openURL) private var openURL
    @Dependency(\.hapticClient) private var hapticClient
    @Dependency(\.logger) private var logger
    @Dependency(\.mainQueue) private var mainQueue

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            struct FirstChapterCancel: Hashable { let chapterID: UUID }
            switch action {
            // MARK: - Actions to be called from view
            case .onAppear:
                state.isErrorOccured = false

                var effects = [
                    databaseClient.getLastReadChapterID(mangaID: state.manga.id)
                        .receive(on: mainQueue)
                        .catchToEffect(Action.lastReadChapterRetrieved)
                ]
                
                if state.allCoverArtsInfo.isEmpty {
                    effects.append(
                        mangaClient.fetchAllCoverArtsForManga(state.manga.id)
                            .receive(on: mainQueue)
                            .catchToEffect(Action.allCoverArtsInfoFetched)
                    )
                }
                
                if state.pagesState.isNil {
                    effects.append(
                        mangaClient.fetchMangaChapters(state.manga.id, nil, nil)
                            .receive(on: mainQueue)
                            .catchToEffect(Action.volumesRetrieved)
                    )
                }
                
                if state.statistics.isNil {
                    effects.append(
                        mangaClient.fetchStatistics([state.manga.id])
                            .receive(on: mainQueue)
                            .catchToEffect(Action.mangaStatisticsDownloaded)
                    )
                }
                
                return .merge(effects)
                
            case .navigationTabButtonTapped(let newTab):
                state.selectedTab = newTab
                return .none
                
            case .authorNameTapped(let author):
                state.showAuthorView = true
                
                if state.authorViewState?.authorID != author.id {
                    state.authorViewState = AuthorFeature.State(authorID: author.id)
                }
                
                return .none
                
            case .refreshButtonTapped:
                if let lastRefreshedAt = state.lastRefreshedAt, (.now - lastRefreshedAt) < 10 {
                    hudClient.show(
                        message: "Wait a little to refresh this page",
                        iconName: "clock",
                        backgroundColor: .theme.yellow
                    )
                    return hapticClient
                        .generateNotificationFeedback(.error)
                        .fireAndForget()
                }
                
                state.lastRefreshedAt = .now
                
                return .merge(
                    mangaClient.fetchMangaChapters(state.manga.id, nil, nil)
                        .receive(on: mainQueue)
                        .delay(for: .seconds(0.7), scheduler: mainQueue)
                        .catchToEffect(Action.volumesRetrieved),
                    
                    hapticClient.generateFeedback(.medium).fireAndForget()
                )
                
            case .continueReadingButtonTapped:
                guard let chapterID = state.lastReadChapterID else { return .none }
                
                return mangaClient.fetchChapterDetails(chapterID)
                    .receive(on: mainQueue)
                    .catchToEffect(Action.chapterDetailsForContinueReadingFetched)
                
            // user wants to start reading manga from first chapter, have to retrieve preffered lang for reading
            case .startReadingButtonTapped:
                if let chapterLang = state.firstChapterOptions?.first?.attributes.translatedLanguage,
                   chapterLang == state.prefferedLanguage?.rawValue {
                    return .none
                }
                
                return .run { send in
                    do {
                        let config = try await settingsClient.retireveSettingsConfig()
                        await send(.settingsConfigRetrieved(.success(config)))
                    } catch {
                        if let error = error as? AppError {
                            await send(.settingsConfigRetrieved(.failure(error)))
                        }
                    }
                }
                
            case .userTappedOnFirstChapterOption(let chapter):
                if let url = chapter.attributes.externalURL {
                    return .fireAndForget { await openURL(url) }
                }
                
                state.mangaReadingViewState = OnlineMangaReadingFeature.State(
                    manga: state.manga,
                    chapterID: chapter.id,
                    chapterIndex: chapter.attributes.index,
                    scanlationGroupID: chapter.scanlationGroupID,
                    translatedLanguage: chapter.attributes.translatedLanguage
                )
                
                return .task { .mangaReadingViewAction(.userStartedReadingChapter) }
                
            case .userTappedOnChapterLoaderButton:
                guard state.chapterLoaderState.isNil else { return .none }
                
                state.chapterLoaderState = MangaChapterLoaderFeature.State(manga: state.manga)
                return .task { .chapterLoaderAcion(.initLoader) }
            // MARK: - END Actions to be called from view
                
            case .volumesRetrieved(let result):
                switch result {
                case .success(let response):
                    let allowHaptic = state.pagesState.hasValue
                    
                    if state.pagesState.hasValue {
                        hudClient.show(message: "Updated!", backgroundColor: .theme.green)
                    }
                    
                    let currentPageIndex = state.pagesState?.currentPageIndex
                    
                    state.pagesState = PagesFeature.State(
                        manga: state.manga,
                        mangaVolumes: response.volumes,
                        chaptersPerPage: 10,
                        online: true
                    )
                    
                    if let currentPageIndex {
                        state.pagesState?.currentPageIndex = currentPageIndex
                    }
                    
                    return allowHaptic ? hapticClient.generateNotificationFeedback(.success).fireAndForget() : .none
                    
                case .failure(let error):
                    logger.error(
                        "Failed to fetch volumes: \(error)",
                        context: [
                            "mangaID": "\(state.manga.id.uuidString.lowercased())",
                            "mangaName": "\(state.manga.title)"
                        ]
                    )
                    
                    hudClient.show(message: "Failed to fetch: \(error.description)")
                    
                    state.isErrorOccured = true
                    
                    return hapticClient.generateNotificationFeedback(.error).fireAndForget()
                }
                
            case .lastReadChapterRetrieved(let result):
                switch result {
                case .success(let lastReadChapterID):
                    state.lastReadChapterID = lastReadChapterID
                    return .none
                    
                case .failure:
                    return .none
                }
                
            case .mangaStatisticsDownloaded(let result):
                switch result {
                case .success(let response):
                    state.statistics = response.statistics[state.manga.id]
                    return .none
                    
                case .failure(let error):
                    logger.error(
                        "Failed to fetch statistics for manga: \(error)",
                        context: [
                            "mangaID": "\(state.manga.id.uuidString.lowercased())",
                            "mangaName": "\(state.manga.title)"
                        ]
                    )
                    return .none
                }
                
            case .allCoverArtsInfoFetched(let result):
                switch result {
                case .success(let response):
                    state.allCoverArtsInfo = response.data
                    imageClient.prefetchImages(with: state.croppedCoverArtURLs)
                    return .none
                    
                case .failure(let error):
                    logger.error(
                        "Failed to fetch list of cover arts: \(error)",
                        context: [
                            "mangaID": "\(state.manga.id.uuidString.lowercased())",
                            "mangaName": "\(state.manga.title)"
                        ]
                    )
                    hudClient.show(message: error.description)
                    return .none
                }
                
            case .chapterDetailsForContinueReadingFetched(let result):
                switch result {
                case .success(let response):
                    let chapter = response.data
                    
                    state.mangaReadingViewState = OnlineMangaReadingFeature.State(
                        manga: state.manga,
                        chapterID: chapter.id,
                        chapterIndex: chapter.attributes.index,
                        scanlationGroupID: chapter.scanlationGroupID,
                        translatedLanguage: chapter.attributes.translatedLanguage
                    )
                    
                    return .task { .mangaReadingViewAction(.userStartedReadingChapter) }
                    
                case .failure(let error):
                    hudClient.show(message: "Failed to fetch chapter\n\(error.description)", backgroundColor: .red)
                    return .none
                }
                
            // after we retrieved preffered lang, have to find `first` chapters
            case .settingsConfigRetrieved(let result):
                switch result {
                case .success(let config):
                    state.prefferedLanguage = config.iso639Language
                    
                    state._firstChapterOptions = []

                    let firstChapterOptionsIDs = state.pagesState!.firstChapterOptionsIDs
                    
                    return .merge(
                        firstChapterOptionsIDs.map { chapterID in
                            mangaClient.fetchChapterDetails(chapterID)
                                .cancellable(id: FirstChapterCancel(chapterID: chapterID), cancelInFlight: true)
                                .receive(on: mainQueue)
                                .catchToEffect(Action.firstChapterOptionRetrieved)
                        }
                    )
                    
                case .failure(let error):
                    logger.error("Failed to retrieve settings config: \(error)")
                    state.prefferedLanguage = .en
                    return .none
                }
                
            case .firstChapterOptionRetrieved(let result):
                switch result {
                case .success(let response):
                    state._firstChapterOptions!.append(response.data)
                    
                    if state.pagesState!.firstChapterOptionsIDs.count == state._firstChapterOptions?.count {
                        return .task { .allFirstChaptersRetrieved }
                    }
                    
                    return .none
                    
                case .failure(let error):
                    logger.error("Failed to fetch chapter details for first chapter: \(error)")
                    return .none
                }
                
            // when all first chapters fetched, have to filter only with matched preffered lang
            // if nothing found, show all (maximum 12, because of screen size).
            // if there's only one chapter with preffered lang, automatically send user to manga reading view
            case .allFirstChaptersRetrieved:
                let prefferedLang = state.prefferedLanguage!.rawValue
                let chaptersWithSamePrefferedLang = state._firstChapterOptions!.filter {
                    $0.attributes.translatedLanguage == prefferedLang
                }
                
                if !chaptersWithSamePrefferedLang.isEmpty {
                    if chaptersWithSamePrefferedLang.ids != state.firstChapterOptions?.ids {
                        state.firstChapterOptions = chaptersWithSamePrefferedLang
                    }
                } else {
                    // showing all translations from first chapter
                    state.firstChapterOptions = state._firstChapterOptions
                }
                
                state.firstChapterOptions = Array(state.firstChapterOptions!.prefix(10))
                
                let onlyOneChapterAndLangMatches = state.firstChapterOptions?.count == 1 &&
                    state.firstChapterOptions!.first!.attributes.translatedLanguage == prefferedLang &&
                    state.firstChapterOptions!.first!.attributes.externalURL.isNil
                    
                
                if onlyOneChapterAndLangMatches {
                    let chapter = state.firstChapterOptions!.first!
                    state.mangaReadingViewState = OnlineMangaReadingFeature.State(
                        manga: state.manga,
                        chapterID: chapter.id,
                        chapterIndex: chapter.attributes.index,
                        scanlationGroupID: chapter.scanlationGroupID,
                        translatedLanguage: chapter.attributes.translatedLanguage
                    )
                    
                    return .task { .mangaReadingViewAction(.userStartedReadingChapter) }
                }
                
                return .none
                
            case .showAuthorViewValueDidChange(let newValue):
                state.showAuthorView = newValue
                return .none
                
            case .nowReadingViewStateDidUpdate(let newValue):
                state.isMangaReadingViewPresented = newValue
                return .none
                
            case .mangaReadingViewAction:
                return .none
                
            case .pagesAction:
                return .none
                
            case .coverArtForCachingFetched:
                return .none
                
            case .authorViewAction:
                return .none
                
            case .chapterLoaderAcion:
                return .none
            }
        }
        Reduce { state, action in
            switch action {
            // MARK: - hijacking download chapter actions
            case .pagesAction(.volumeTabAction(_, .chapterAction(_, .downloadChapterButtonTapped))),
                    .mangaReadingViewAction(.downloadChapterButtonTapped):
                // check if we already loaded this manga and if yes, means cover art is cached already, so we don't do it again
                if !mangaClient.isCoverArtCached(state.manga.id, cacheClient), let coverArtURL = state.mainCoverArtURL {
                    return .run { send in
                        do {
                            let coverArt = try await imageClient.downloadImage(from: coverArtURL)
                            await send(.coverArtForCachingFetched(.success(coverArt)))
                        } catch {
                            if let error = error as? AppError {
                                await send(.coverArtForCachingFetched(.failure(error)))
                            }
                        }
                    }
                }
                
                return .none
                
            case .coverArtForCachingFetched(.success(let coverArt)):
                return mangaClient
                    .saveCoverArt(coverArt, state.manga.id, cacheClient)
                    .fireAndForget()
                
            case .coverArtForCachingFetched(.failure(let error)):
                logger.error(
                    "Failed to fetch main cover art for caching: \(error)",
                    context: [
                        "mangaID": "\(state.manga.id.uuidString.lowercased())",
                        "mangaName": "\(state.manga.title)"
                    ]
                )
                return .none
                
            default:
                return .none
            }
        }
        Reduce { state, action in
            switch action {
            case .pagesAction(.volumeTabAction(_, .chapterAction(_, .userTappedOnChapterDetails(let chapter)))):
                if let url = chapter.attributes.externalURL {
                    return .fireAndForget { await openURL(url) }
                }
                
                state.mangaReadingViewState = OnlineMangaReadingFeature.State(
                    manga: state.manga,
                    chapterID: chapter.id,
                    chapterIndex: chapter.attributes.index,
                    scanlationGroupID: chapter.scanlationGroupID,
                    translatedLanguage: chapter.attributes.translatedLanguage
                )
                
                return .task { .mangaReadingViewAction(.userStartedReadingChapter) }
                
            case .mangaReadingViewAction(.userStartedReadingChapter):
                let chapterIndex = state.mangaReadingViewState?.chapterIndex
                let volumes = state.pagesState!.splitIntoPagesVolumeTabStates
                
                var effects: [EffectTask<Action>] = [
                    databaseClient.setLastReadChapterID(
                        for: state.manga,
                        chapterID: state.mangaReadingViewState!.chapterID
                    )
                    .fireAndForget()
                ]
                
                if let pageIndex = mangaClient.getMangaPageForReadingChapter(chapterIndex, volumes) {
                    effects.append(.task { .pagesAction(.pageIndexButtonTapped(newPageIndex: pageIndex)) })
                }
                
                return .merge(effects)
                
                
            case .mangaReadingViewAction(.userLeftMangaReadingView):
                defer { state.isMangaReadingViewPresented = false }
                
                state.lastReadChapterID = state.mangaReadingViewState?.chapterID
                
                let chapterIndex = state.mangaReadingViewState!.chapterIndex
                let volumes = state.pagesState!.volumeTabStatesOnCurrentPage
                
                guard let info = mangaClient.findDidReadChapterOnMangaPage(chapterIndex, volumes) else {
                    return .none
                }
                
                if state.pagesState!
                    .volumeTabStatesOnCurrentPage[id: info.volumeID]!
                    .chapterStates[id: info.chapterID]!
                    .areChaptersShown {
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
            OnlineMangaReadingFeature()
        }
        .ifLet(\.authorViewState, action: /Action.authorViewAction) {
            AuthorFeature()
        }
        .ifLet(\.chapterLoaderState, action: /Action.chapterLoaderAcion) {
            MangaChapterLoaderFeature()
        }
    }
}
