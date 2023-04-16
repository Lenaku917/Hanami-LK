//
//  MangaChapterLoaderView.swift
//  Hanami
//
//  Created by Oleg on 19.03.23.
//

import SwiftUI
import ComposableArchitecture

struct MangaChapterLoaderView: View {
    let store: StoreOf<MangaChapterLoaderFeature>
    
    struct ViewState: Equatable {
        let allLanguages: [String]
        let prefferedLanguage: String?
        let chapters: IdentifiedArrayOf<ChapterDetails>
        let title: String
        
        init(state: MangaChapterLoaderFeature.State) {
            allLanguages = state.allLanguages
            prefferedLanguage = state.prefferedLanguage
            
            if let filtered = state.filteredChapters {
                chapters = filtered
            } else {
                chapters = state.chapters
            }
            title = state.manga.title
        }
    }
    
    var body: some View {
        NavigationView {
            WithViewStore(store, observe: ViewState.init) { viewStore in
                ScrollView {
                    Menu {
                        ForEach(viewStore.allLanguages, id: \.self) { lang in
                            Button(lang) {
                                viewStore.send(.prefferedLanguageChanged(to: lang))
                            }
                        }
                    } label: {
                        if let lang = viewStore.prefferedLanguage {
                            Text(lang)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            ProgressView()
                                .tint(.theme.accent)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(viewStore.chapters) { chapter in
                            makeViewFor(chapter: chapter)
                            
                            Divider()
                        }
                    }
                    .padding(.horizontal)
                }
                .navigationTitle(viewStore.title)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

#if DEBUG
struct MangaChapterLoaderView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyView()
    }
}
#endif

extension MangaChapterLoaderView {
    @ViewBuilder private func makeViewFor(chapter: ChapterDetails) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(chapter.chapterName)
                    .font(.subheadline)
                
                if let scanlationGroup = chapter.scanlationGroup {
                    Text(scanlationGroup.name)
                        .font(.callout)
                        .foregroundColor(.theme.secondaryText)
                }
            }
            
            Spacer()
            
            if let index = chapter.attributes.index?.clean() {
                Text(index)
                    .font(.headline)
            }
            
            Button {
                ViewStore(store).send(.downloadButtonTapped(chapter: chapter))
            } label: {
                Image(systemName: "arrow.down.to.line.circle")
                    .foregroundColor(Color.theme.foreground)
            }
            .font(.headline)
        }
    }
}
