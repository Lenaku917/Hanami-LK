//
//  HomeFeature.swift
//  Hanami
//
//  Created by Oleg on 13/05/2022.
//

import Foundation
import ComposableArchitecture

struct HomeFeature: ReducerProtocol {
    struct State: Equatable {
        var latestUpdatesMangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailFeature.State> = []
        var seasonalMangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailFeature.State> = []
        var awardWinningMangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailFeature.State> = []
        var mostFollowedMangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailFeature.State> = []
        
        var isRefreshActionInProgress = false
        var lastRefreshDate: Date?
        var seasonalMangaListID: UUID?
        var seasonalTabName: String?
    }
    
    enum Action {
        case onAppear
        case refreshButtonTapped
        case refreshDelayCompleted
        case statisticsFetched(
            Result<MangaStatisticsContainer, AppError>,
            WritableKeyPath<State, IdentifiedArrayOf<MangaThumbnailFeature.State>>
        )
        case mangaListFetched(
            Result<Response<[Manga]>, AppError>,
            WritableKeyPath<State, IdentifiedArrayOf<MangaThumbnailFeature.State>>
        )
        
        case allSeasonalListsFetched(Result<Response<[CustomMangaList]>, AppError>)
        case seasonalMangaListFetched(Result<Response<CustomMangaList>, AppError>)
        
        case onAppearAwardWinningManga
        case onAppearMostFollewedManga
        
        case lastUpdatesMangaThumbnailAction(UUID, MangaThumbnailFeature.Action)
        case seasonalMangaThumbnailAction(UUID, MangaThumbnailFeature.Action)
        case awardWinningMangaThumbnailAction(UUID, MangaThumbnailFeature.Action)
        case mostFollowedMangaThumbnailAction(UUID, MangaThumbnailFeature.Action)
    }
    
    @Dependency(\.homeClient) private var homeClient
    @Dependency(\.hudClient) private var hudClient
    @Dependency(\.hapticClient) private var hapticClient
    @Dependency(\.logger) private var logger
    @Dependency(\.imageClient) private var imageClient
    
    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.latestUpdatesMangaThumbnailStates.isEmpty else { return .none }
                
                return .merge(
                    homeClient.fetchLastUpdates()
                        .receive(on: DispatchQueue.main)
                        .catchToEffect { .mangaListFetched($0, \.latestUpdatesMangaThumbnailStates) },
                    
                    homeClient.fetchAllSeasonalTitlesLists()
                        .receive(on: DispatchQueue.main)
                        .catchToEffect(Action.allSeasonalListsFetched)
                )
                
            case .refreshButtonTapped:
                let now = Date()
                
                guard state.lastRefreshDate == nil || now - state.lastRefreshDate! > 10 else {
                    hudClient.show(message: "Wait a little to refresh home page", backgroundColor: .yellow)
                    return hapticClient
                        .generateNotificationFeedback(.error)
                        .fireAndForget()
                }
                
                state.isRefreshActionInProgress = true
                state.lastRefreshDate = now
                
                var fetchedMangaIDs: [UUID] = []
                
                fetchedMangaIDs.append(contentsOf: state.awardWinningMangaThumbnailStates.map(\.id))
                fetchedMangaIDs.append(contentsOf: state.mostFollowedMangaThumbnailStates.map(\.id))
                fetchedMangaIDs.append(contentsOf: state.latestUpdatesMangaThumbnailStates.map(\.id))
                fetchedMangaIDs.append(contentsOf: state.seasonalMangaThumbnailStates.map(\.id))
                
                state.awardWinningMangaThumbnailStates.removeAll()
                state.mostFollowedMangaThumbnailStates.removeAll()
                
                struct UpdateDebounce: Hashable { }
                
                var effects = [
                    hapticClient.generateNotificationFeedback(.success).fireAndForget(),
                    
                    .cancel(ids: fetchedMangaIDs.map { OnlineMangaFeature.CancelClearCache(mangaID: $0) }),
                    
                    homeClient.fetchLastUpdates()
                        .receive(on: DispatchQueue.main)
                        .catchToEffect { Action.mangaListFetched($0, \.latestUpdatesMangaThumbnailStates) }
                        .cancellable(id: UpdateDebounce(), cancelInFlight: true),
                    
                    .task { .refreshDelayCompleted }
                        .delay(for: .seconds(3), scheduler: DispatchQueue.main)
                        .eraseToEffect()
                ]
                
                if let seasonalListID = state.seasonalMangaListID {
                    effects.append(
                        homeClient.fetchCustomTitlesList(seasonalListID)
                            .receive(on: DispatchQueue.main)
                            .catchToEffect(Action.seasonalMangaListFetched)
                    )
                }
                
                return .merge(effects)
                
            case .refreshDelayCompleted:
                state.isRefreshActionInProgress = false
                return .none
                
            case .onAppearAwardWinningManga:
                guard state.awardWinningMangaThumbnailStates.isEmpty else { return .none }
                
                return homeClient.fetchAwardWinningManga()
                    .receive(on: DispatchQueue.main)
                    .catchToEffect { .mangaListFetched($0, \.awardWinningMangaThumbnailStates) }
                
            case .onAppearMostFollewedManga:
                guard state.mostFollowedMangaThumbnailStates.isEmpty else { return .none }
                
                return homeClient.fetchMostFollowedManga()
                    .receive(on: DispatchQueue.main)
                    .catchToEffect { .mangaListFetched($0, \.mostFollowedMangaThumbnailStates) }
                
            case .allSeasonalListsFetched(let result):
                switch result {
                case .success(let response):
                    let seasonaMangalList = homeClient.getCurrentSeasonTitlesListID(response.data)
                    
                    let seasonalMangaIDs = seasonaMangalList.relationships
                        .filter { $0.type == .manga }
                        .map(\.id)
                    
                    state.seasonalMangaListID = seasonaMangalList.id
                    state.seasonalTabName = seasonaMangalList.attributes.name
                    
                    return homeClient
                        .fetchMangaByIDs(seasonalMangaIDs)
                        .receive(on: DispatchQueue.main)
                        .catchToEffect { .mangaListFetched($0, \.seasonalMangaThumbnailStates) }
                    
                case .failure(let error):
                    logger.error("Failed to load list of seasonal titles: \(error)")
                    return .none
                }
                
            case .mangaListFetched(let result, let keyPath):
                switch result {
                case .success(let response):
                    let mangaIDsList = state[keyPath: keyPath].map(\.id)
                    let fetchedMangaIDsList = Array(response.data.map(\.id)[0..<25])
                    
                    guard mangaIDsList != fetchedMangaIDsList else {
                        return .none
                    }
                    
                    state[keyPath: keyPath] = .init(
                        uniqueElements: response.data[0..<25].map { MangaThumbnailFeature.State(manga: $0) }
                    )
                    
                    let coverArtURLs = state[keyPath: keyPath].compactMap(\.thumbnailURL)
                    
                    return .merge(
                        homeClient.fetchStatistics(response.data.map(\.id))
                            .receive(on: DispatchQueue.main)
                            .catchToEffect { .statisticsFetched($0, keyPath) },
                        
                        imageClient.prefetchImages(coverArtURLs)
                            .fireAndForget()
                    )
                    
                case .failure(let error):
                    hudClient.show(message: error.description)
                    state.lastRefreshDate = nil
                    logger.error(
                        "Failed to load manga list: \(error)",
                        context: ["keyPath": "`\(keyPath.customDumpDescription)`"]
                    )
                    return hapticClient.generateNotificationFeedback(.error).fireAndForget()
                }
                
            case .statisticsFetched(let result, let keyPath):
                switch result {
                case .success(let response):
                    for stat in response.statistics {
                        state[keyPath: keyPath][id: stat.key]?.onlineMangaState!.statistics = stat.value
                    }
                    
                    return .none
                    
                case .failure(let error):
                    logger.error(
                        "Failed to load statistics for manga list: \(error)",
                        context: ["keyPath": "`\(keyPath.customDumpDescription)`"]
                    )
                    return .none
                }
                
            case .seasonalMangaListFetched(let result):
                switch result {
                case .success(let response):
                    let mangaIDs = response.data.relationships.filter { $0.type == .manga }.map(\.id)
                    
                    return homeClient
                        .fetchMangaByIDs(mangaIDs)
                        .receive(on: DispatchQueue.main)
                        .catchToEffect { .mangaListFetched($0, \.seasonalMangaThumbnailStates) }
                    
                case .failure(let error):
                    logger.error("Failed to load list of seasonal titles: \(error)")
                    return .none
                }
                
            case .lastUpdatesMangaThumbnailAction:
                return .none
                
            case .seasonalMangaThumbnailAction:
                return .none
                
            case .awardWinningMangaThumbnailAction:
                return .none
                
            case .mostFollowedMangaThumbnailAction:
                return .none
            }
        }
        .forEach(\.latestUpdatesMangaThumbnailStates, action: /Action.lastUpdatesMangaThumbnailAction) {
            MangaThumbnailFeature()
        }
        .forEach(\.seasonalMangaThumbnailStates, action: /Action.seasonalMangaThumbnailAction) {
            MangaThumbnailFeature()
        }
        .forEach(\.awardWinningMangaThumbnailStates, action: /Action.awardWinningMangaThumbnailAction) {
            MangaThumbnailFeature()
        }
        .forEach(\.mostFollowedMangaThumbnailStates, action: /Action.mostFollowedMangaThumbnailAction) {
            MangaThumbnailFeature()
        }
    }
}
