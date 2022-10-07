//
//  FiltersFeature.swift
//  Hanami
//
//  Created by Oleg on 30/05/2022.
//

import Foundation
import ComposableArchitecture

struct FiltersState: Equatable {
    // MARK: - Tags
    var allTags: IdentifiedArrayOf<FilterTag> = []

    // All the types defined inside one enum to display more comfortable
    var genres: IdentifiedArrayOf<FilterTag> {
        allTags.filter { $0.type == .genre }
    }
    var themeTypes: IdentifiedArrayOf<FilterTag> {
        allTags.filter { $0.type == .theme }
    }
    var formatTypes: IdentifiedArrayOf<FilterTag> {
        allTags.filter { $0.type == .format }
    }
    var contentTypes: IdentifiedArrayOf<FilterTag> {
        allTags.filter { $0.type == .content }
    }
    // MARK: - Options
    var publicationDemographics: IdentifiedArrayOf<FilterPublicationDemographic> = .init(uniqueElements: [
        .init(tag: .josei), .init(tag: .seinen), .init(tag: .shoujo), .init(tag: .shounen)
    ])
    var contentRatings: IdentifiedArrayOf<FilterContentRatings> = .init(uniqueElements: [
        .init(tag: .erotica), .init(tag: .pornographic), .init(tag: .safe), .init(tag: .suggestive, state: .selected)
    ])
    var mangaStatuses: IdentifiedArrayOf<FilterMangaStatus> = .init(uniqueElements: [
        .init(tag: .cancelled), .init(tag: .completed), .init(tag: .hiatus), .init(tag: .ongoing)
    ])
    
    var isAnyFilterApplied: Bool {
        !allTags.filter { $0.state == .selected || $0.state == .banned }.isEmpty ||
        // 'mangaStatuses', 'publicationDemographics' and 'contentRatings' can't have .state as 'banned', so we don't check this type
        !publicationDemographics.filter { $0.state == .selected }.isEmpty ||
        !contentRatings.filter { $0.state == .selected && $0.tag != .suggestive }.isEmpty ||
        !mangaStatuses.filter { $0.state == .selected }.isEmpty
    }
}

enum FiltersAction {
    case onAppear
    case filterListDownloaded(Result<Response<[Tag]>, AppError>)
    case filterTagButtonTapped(FilterTag)
    case resetFilters
    
    case mangaStatusButtonTapped(FilterMangaStatus)
    case contentRatingButtonTapped(FilterContentRatings)
    case publicationDemographicButtonTapped(FilterPublicationDemographic)
}

struct FiltersEnvironment {
    let searchClient: SearchClient
}

let filterReducer = Reducer<FiltersState, FiltersAction, FiltersEnvironment> { state, action, env in
    switch action {
        case .onAppear:
            guard state.allTags.isEmpty else { return .none }
            
            return env.searchClient.fetchTags()
                .receive(on: DispatchQueue.main)
                .catchToEffect(FiltersAction.filterListDownloaded)
            
        case .filterListDownloaded(let result):
            switch result {
                case .success(let response):
                    state.allTags = .init(uniqueElements: response.data.map { FilterTag(tag: $0, state: .notSelected) })
                    state.allTags.sort(by: <)
                    
                    return .none
                    
                case .failure(let error):
                    print("error on downloading tags list \(error.description)")
                    return .none
            }
            
        case .filterTagButtonTapped(let tappedTag):
            state.allTags[id: tappedTag.id]?.toggleState()
            return .none
            
        case .resetFilters:
            for tagID in state.allTags.map(\.id) {
                state.allTags[id: tagID]!.state = .notSelected
            }

            for tagID in state.mangaStatuses.map(\.id) {
                state.mangaStatuses[id: tagID]!.state = .notSelected
            }

            for tagID in state.publicationDemographics.map(\.id) {
                state.publicationDemographics[id: tagID]!.state = .notSelected
            }

            for tagID in state.contentRatings.map(\.id) {
                if state.contentRatings[id: tagID]!.tag != .suggestive {
                    state.contentRatings[id: tagID]!.state = .notSelected
                } else {
                    state.contentRatings[id: tagID]!.state = .selected
                }
            }
            
            return .none
            
        case .mangaStatusButtonTapped(let tag):
            if tag.state == .selected {
                state.mangaStatuses[id: tag.id]!.state = .notSelected
            } else {
                state.mangaStatuses[id: tag.id]!.state = .selected
            }
            
            return .none
            
        case .contentRatingButtonTapped(let tag):
            if tag.state == .selected {
                state.contentRatings[id: tag.id]!.state = .notSelected
            } else {
                state.contentRatings[id: tag.id]!.state = .selected
            }
            
            return .none
            
        case .publicationDemographicButtonTapped(let tag):
            if tag.state == .selected {
                state.publicationDemographics[id: tag.id]!.state = .notSelected
            } else {
                state.publicationDemographics[id: tag.id]!.state = .selected
            }
            
            return .none
    }
}
