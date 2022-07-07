//
//  ChapterView.swift
//  Smuggler
//
//  Created by mk.pwnz on 22/05/2022.
//

import SwiftUI
import ComposableArchitecture

struct ChapterView: View {
    let store: Store<ChapterState, ChapterAction>
    @Environment(\.openURL) var openURL

    var body: some View {
        WithViewStore(store) { viewStore in
            DisclosureGroup(isExpanded: viewStore.binding(\.$areChaptersShown)) {
                VStack(spacing: 0) {
                    ForEach(viewStore.chapterDetails) { chapter in
                        makeChapterView(chapter: chapter)
                        
                        Rectangle()
                            .fill(.white)
                            .frame(height: 1.5)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                HStack {
                    Text(viewStore.chapter.chapterName)
                        .font(.title3)
                        .fontWeight(.heavy)
                        .padding(.vertical, 3)
                    
                    if !viewStore.areAllChapterDetailsDownloaded {
                        Spacer()
                        
                        ActivityIndicator(lineWidth: 2)
                            .frame(width: 15)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewStore.send(.userTappedOnChapter, animation: .linear(duration: 0.7))
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding()
        }
    }
}

struct ChapterView_Previews: PreviewProvider {
    static var previews: some View {
        ChapterView(
            store: .init(
                initialState: ChapterState(chapter: dev.chapter),
                reducer: chapterReducer,
                environment: .live(
                    environment: .init(
                        downloadChapterInfo: downloadChapterInfo,
                        fetchScanlationGroupInfo: fetchScanlationGroupInfo
                    )
                )
            )
        )
    }
}

extension ChapterView {
    @ViewBuilder private func makeChapterView(chapter: ChapterDetails) -> some View {
        WithViewStore(store) { viewStore in
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    HStack(alignment: .top) {
                        Text(chapter.chapterName)
                            .fontWeight(.medium)
                            .font(.headline)
                            .lineLimit(nil)
                            .padding(5)
                        
                        if chapter.attributes.externalURL != nil {
                            Spacer()
                            
                            Image(systemName: "arrow.up.forward.square")
                                .foregroundColor(.theme.secondaryText)
                                .font(.callout)
                                .padding(5)
                        }
                    }
                    
                    makeScanlationGroupSection(for: chapter)
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // if manga has externalURL, means we can only read it on some other website, not in app
                if let url = chapter.attributes.externalURL {
                    openURL(url)
                } else {
                    viewStore.send(
                        .userTappedOnChapterDetails(chapter: chapter)
                    )
                }
            }
        }
        .padding(0)
    }

    @ViewBuilder private func makeScanlationGroupSection(for chapter: ChapterDetails) -> some View {
        WithViewStore(store) { viewStore in
            HStack {
                VStack(alignment: .leading) {
                    Text("Translated by:")
                        .fontWeight(.light)
                    
                    if viewStore.chapterDetails[id: chapter.id]?.scanltaionGroupID != nil {
                        Text(viewStore.scanlationGroups[chapter.id]?.name ?? .placeholder(length: 35))
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .redacted(if: viewStore.scanlationGroups[chapter.id]?.name == nil)
                    } else {
                        Text("No group")
                            .fontWeight(.bold)
                    }
                }
                .font(.caption)
                .foregroundColor(.theme.secondaryText)
                .padding(.horizontal, 5)
                .padding(.bottom, 5)
                
                Spacer()
                
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundColor(.theme.secondaryText)
                
                Text(chapter.attributes.createdAt.timeAgo)
                    .font(.caption)
                    .foregroundColor(.theme.secondaryText)
            }
            .transition(.opacity)
        }
    }
}
