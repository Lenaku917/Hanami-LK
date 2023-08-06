//
//  ChapterFeature.swift
//  Hanami
//
//  Created by Oleg on 22/05/2022.
//

import Foundation
import ComposableArchitecture
import class SwiftUI.UIImage
import ModelKit
import Utils

struct ChapterFeature: ReducerProtocol {
    struct State: Equatable, Identifiable {
        // Chapter basic info
        let chapter: Chapter
        let online: Bool
        let parentManga: Manga
        
        init(chapter: Chapter, parentManga: Manga, online: Bool = false) {
            self.chapter = chapter
            self.online = online
            self.parentManga = parentManga
            downloader = ChapterLoaderFeature.State(parentManga: parentManga, online: online)
        }
        
        var downloader: ChapterLoaderFeature.State
        
        // we can have many 'chapterDetailsList' in one ChapterState because one chapter can be translated by different scanlation groups
        var chapterDetailsList: IdentifiedArrayOf<ChapterDetails> = []
        // '_chapterDetails' is only to accumulate all ChapterDetails and then show it at all once
        // swiftlint:disable:next identifier_name
        var _chapterDetailsList: [ChapterDetails] = [] {
            didSet {
                // if all chapters fetched, this container is no longer needed
                // so we put all chapterDetails in 'chapterDetailsList' and clear this one
                if _chapterDetailsList.count == chaptersCount {
                    chapterDetailsList = _chapterDetailsList.sorted { lhs, rhs in
                        // sort by lang and by ScanlationGroup's name
                        if lhs.attributes.translatedLanguage == rhs.attributes.translatedLanguage,
                           let lhsName = lhs.scanlationGroup?.name, let rhsName = rhs.scanlationGroup?.name {
                            return lhsName < rhsName
                        }
                        
                        if let lhsLang = lhs.attributes.translatedLanguage,
                           let rhsLang = rhs.attributes.translatedLanguage {
                            return lhsLang < rhsLang
                        }
                        
                        return false
                    }
                    .asIdentifiedArray
                    
                    _chapterDetailsList = []
                }
            }
        }
        var chaptersCount: Int {
            // need this for offline reading
            // when user deletes chapter, `chapter.others.count` doesn't change himself, only `chapterDetailsList.count`
            chapterDetailsList.isEmpty ? chapter.others.count + 1 : chapterDetailsList.count
        }
        
        var id: UUID { chapter.id }
        
        var areChaptersShown = false
        
        var confirmationDialog: ConfirmationDialogState<Action>?
    }
    
    struct CancelChapterFetch: Hashable { let id: UUID }
    
    enum Action: Equatable {
        case onAppear
        case fetchChapterDetailsIfNeeded
        
        case userTappedOnChapterDetails(ChapterDetails)
        case chapterDeleteButtonTapped(chapterID: UUID)
        case downloadChapterButtonTapped(chapter: ChapterDetails)
        case chapterDeletionConfirmed(chapterID: UUID)
        case cancelChapterDownloadButtonTapped(chapterID: UUID)
        case cancelTapped
        
        case chapterDetailsFetched(Result<Response<ChapterDetails>, AppError>)
        case downloaderAction(ChapterLoaderFeature.Action)
    }
    
    @Dependency(\.mangaClient) private var mangaClient
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.logger) private var logger
    @Dependency(\.mainQueue) private var mainQueue

    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .task { .downloaderAction(.retrieveCachedChaptersFromMemory) }
                
            case .fetchChapterDetailsIfNeeded:
                var effects: [EffectTask<Action>] = []
                
                let allChapterIDs = [state.chapter.id] + state.chapter.others
                
                for chapterID in allChapterIDs {
                    let possiblyCachedChapterEntry = databaseClient.retrieveChapter(chapterID: chapterID)
                    
                    if state.chapterDetailsList[id: chapterID].isNil {
                        // if chapter is cached - no need to fetch it from API
                        if let cachedChapterDetails = possiblyCachedChapterEntry?.chapter {
                            if !state._chapterDetailsList.contains(where: { $0.id == chapterID }) {
                                state._chapterDetailsList.append(cachedChapterDetails)
                            }
                        } else if state.online {
                            // chapter is not cached, need to fetch
                            effects.append(
                                mangaClient.fetchChapterDetails(chapterID)
                                    .delay(for: .seconds(0.3), scheduler: mainQueue)
                                    .receive(on: mainQueue)
                                    .catchToEffect(Action.chapterDetailsFetched)
                                    .animation(.linear)
                                    .cancellable(id: CancelChapterFetch(id: chapterID), cancelInFlight: true)
                            )
                        }
                    }
                }
                
                state.areChaptersShown.toggle()
                
                return .merge(effects)
                
            case .userTappedOnChapterDetails:
                return .none
                
            case .chapterDetailsFetched(let result):
                switch result {
                case .success(let response):
                    let chapter = response.data
                    
                    if !state._chapterDetailsList.contains(where: { $0.id == chapter.id }) {
                        state._chapterDetailsList.append(chapter)
                    }
                    
                    return .none
                    
                case .failure(let error):
                    logger.error(
                        "Failed to fetch chapterDetails: \(error)",
                        context: ["mangaID": "\(state.parentManga.id.uuidString.lowercased())"]
                    )
                    return .none
                }
                // MARK: - Caching
            case .chapterDeleteButtonTapped(let chapterID):
                state.confirmationDialog = ConfirmationDialogState(
                    title: TextState("Delete this chapter from device?"),
                    message: TextState("Delete this chapter from device?"),
                    buttons: [
                        .destructive(
                            TextState("Delete"),
                            action: .send(.chapterDeletionConfirmed(chapterID: chapterID))
                        ),
                        .cancel(TextState("Cancel"), action: .send(.cancelTapped))
                    ]
                )
                
                return .none
                
            case .cancelTapped:
                state.confirmationDialog = nil
                return .none
                
            case .chapterDeletionConfirmed(let chapterID):
                if !state.online {
                    state.chapterDetailsList.remove(id: chapterID)
                }
                
                state.confirmationDialog = nil
                
                return .task { .downloaderAction(.chapterDeletionConfirmed(chapterID: chapterID)) }
                
            case .downloadChapterButtonTapped(let chapter):
                return .task { .downloaderAction(.downloadChapterButtonTapped(chapter: chapter)) }
                
            case .cancelChapterDownloadButtonTapped(let chapterID):
                state.confirmationDialog = ConfirmationDialogState(
                    title: TextState("Stop chapter download?"),
                    message: TextState("Stop chapter download?"),
                    buttons: [
                        .destructive(
                            TextState("Stop download"),
                            action: .send(.downloaderAction(.chapterDeletionConfirmed(chapterID: chapterID)))
                        ),
                        .cancel(TextState("Cancel"), action: .send(.cancelTapped))
                    ]
                )
                
                return .none
                // MARK: - Caching END
                
            case .downloaderAction:
                return .none
            }
        }
        Scope(state: \.downloader, action: /Action.downloaderAction) {
            ChapterLoaderFeature()
        }
    }
}
