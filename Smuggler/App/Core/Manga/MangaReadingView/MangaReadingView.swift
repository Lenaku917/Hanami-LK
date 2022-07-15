//
//  MangaReadingView.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/06/2022.
//

import SwiftUI
import ComposableArchitecture
import Kingfisher

struct MangaReadingView: View {
    private let store: Store<MangaReadingViewState, MangaReadingViewAction>
    private let viewStore: ViewStore<MangaReadingViewState, MangaReadingViewAction>
    @Environment(\.presentationMode) private var presentationMode
    @State private var shouldShowNavBar = true
    @State private var currentPageIndex = 0
    
    init(store: Store<MangaReadingViewState, MangaReadingViewAction>) {
        self.store = store
        viewStore = ViewStore(store)
        viewStore.send(.userStartedReadingChapter)
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                if shouldShowNavBar {
                    navigationBar
                        .frame(height: geo.size.height * 0.05)
                        .zIndex(1)
                }
                
                readingContent
                    .zIndex(0)
            }
            .frame(height: UIScreen.main.bounds.height * 1.05)
        }
        .navigationBarHidden(true)
        .gesture(tapGesture)
        .gesture(swipeGesture)
        .onChange(of: viewStore.pagesInfo) { _ in
            if viewStore.shouldSendUserToTheLastPage {
                currentPageIndex = viewStore.pagesCount - 1
            } else {
                currentPageIndex = 0
            }
        }
        .onChange(of: currentPageIndex) {
            viewStore.send(.userChangedPage(newPageIndex: $0))
        }
    }
}

extension MangaReadingView {
    private var backButton: some View {
        Button {
            self.presentationMode.wrappedValue.dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.title3)
                .foregroundColor(.white)
                .padding(.vertical)
        }
    }
}

extension MangaReadingView {
    private var readingContent: some View {
        ZStack {
            if let urls = viewStore.pagesInfo?.dataSaverURLs {
                TabView(selection: $currentPageIndex) {
                    Color.clear
                        .tag(-1)
                    
                    ForEach(urls.indices, id: \.self) { pageIndex in
                        ZoomableScrollView {
                            KFImage.url(
                                urls[pageIndex],
                                cacheKey: urls[pageIndex].absoluteString
                            )
                            .placeholder {
                                ActivityIndicator()
                                    .frame(width: 120)
                            }
                            .resizable()
                            .scaledToFit()
                        }
                    }
                    
                    Color.clear
                        .tag(urls.count)
                }
            } else {
                TabView {
                    ActivityIndicator()
                        .frame(width: 120)
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .transition(.opacity)
    }
    
    private var navigationBar: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            HStack(spacing: 15) {
                backButton
                    .padding(.horizontal)
                
                Spacer()
                
                VStack {
                    if let chapterIndex = viewStore.chapterIndex {
                        Text("Chapter \(chapterIndex.clean())")
                    }
                    
                    if currentPageIndex < viewStore.pagesCount && currentPageIndex + 1 > 0 {
                        Text("\(currentPageIndex + 1)/\(viewStore.pagesCount)")
                    }
                }
                .font(.callout)
                .padding(.horizontal)
                
                Spacer()
                
                // to align VStack in center
                backButton
                    .padding(.horizontal)
                    .opacity(0)
                    .disabled(true)
            }
        }
    }
    
    // MARK: - Gestures
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 100, coordinateSpace: .local)
            .onEnded { value in
                if value.translation.height > 100 {
                    viewStore.send(.userLeftMangaReadingView)
                    presentationMode.wrappedValue.dismiss()
                }
            }
    }
    
    private var tapGesture: some Gesture {
        TapGesture().onEnded {
            withAnimation(.linear) {
                shouldShowNavBar.toggle()
            }
        }
    }
}
