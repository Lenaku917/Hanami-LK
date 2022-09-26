//
//  OnlineMangaView.swift
//  Hanami
//
//  Created by Oleg on 16/05/2022.
//

import SwiftUI
import ComposableArchitecture
import NukeUI

struct OnlineMangaView: View {
    let store: Store<OnlineMangaViewState, OnlineMangaViewAction>
    // i don't know how does it work https://www.youtube.com/watch?v=ATi5EnY5IYE
    @State private var headerOffset: CGFloat = 0
    @Namespace private var tabAnimationNamespace
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var isViewScrolledDown: Bool {
        headerOffset < -350
    }
    
    var body: some View {
        WithViewStore(store) { viewStore in
            ScrollView(showsIndicators: false) {
                ScrollViewReader { proxy in
                    header
                        .id("header")
                    
                    LazyVStack(pinnedViews: .sectionHeaders) {
                        Section {
                            mangaBodyView
                        } header: {
                            pinnedNavigation
                        } footer: {
                            footer
                        }
                    }
                    .onChange(of: viewStore.pagesState?.currentPageIndex) { _ in
                        scrollToHeader(proxy: proxy)
                    }
                    .onChange(of: viewStore.selectedTab) { _ in
                        scrollToHeader(proxy: proxy)
                    }
                }
            }
            .animation(.linear, value: isViewScrolledDown)
            .animation(.default, value: viewStore.pagesState?.currentPageIndex)
            .onAppear { viewStore.send(.onAppear) }
            .overlay(
                Rectangle()
                    .fill(.black)
                    .frame(height: 50)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .opacity(isViewScrolledDown ? 1 : 0)
            )
            .navigationBarHidden(true)
            .coordinateSpace(name: "scroll")
            .ignoresSafeArea(edges: .top)
            .fullScreenCover(isPresented: viewStore.binding(\.$isUserOnReadingView), content: { mangaReadingView })
            .accentColor(.theme.accent)
        }
    }
}


struct MangaView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyView()
    }
}


extension OnlineMangaView {
    private var footer: some View {
        HStack(spacing: 0) {
            Text("All information on this page provided by ")
            
            Text("MANGADEX")
                .fontWeight(.semibold)
                .onTapGesture {
                    openURL(URL(string: "https://mangadex.org/")!)
                }
        }
        .font(.caption2)
        .foregroundColor(.gray)
        .padding(.horizontal)
        .padding(.bottom, 5)
    }
    
    private var mangaReadingView: some View {
        IfLetStore(
            store.scope(
                state: \.mangaReadingViewState,
                action: OnlineMangaViewAction.mangaReadingViewAction
            ),
            then: OnlineMangaReadingView.init
        )
    }
    
    private func scrollToHeader(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.linear) {
                proxy.scrollTo("header")
            }
        }
    }
    
    @MainActor private var header: some View {
        WithViewStore(store) { viewStore in
            GeometryReader { geo in
                let minY = geo.frame(in: .named("scroll")).minY
                let height = geo.size.height + minY
                
                ZStack {
                    LazyImage(url: viewStore.mainCoverArtURL) { state in
                        if let image = state.image {
                            image.resizingMode(.aspectFill)
                        } else if state.isLoading || state.error != nil {
                            LazyImage(url: viewStore.coverArtURL256, resizingMode: .aspectFill)
                        }
                    }
                    .animation(nil)
                }
                .frame(width: geo.size.width, height: height > 0 ? height : 0, alignment: .center)
                .overlay(headerOverlay)
                .cornerRadius(0)
                .offset(y: -minY)
            }
            .frame(height: 350)
        }
    }
    
    private var headerOverlay: some View {
        WithViewStore(store.actionless) { viewStore in
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [ .black.opacity(0.1), .black.opacity(0.8) ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                VStack(alignment: .leading, spacing: 12) {
                    backButton
                    
                    Spacer()
                    
                    HStack {
                        Text("MANGA")
                            .font(.callout)
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 5) {
                            Circle()
                                .fill(viewStore.manga.attributes.status.color)
                                .frame(width: 10, height: 10)
                                // circle disappears on scroll down, 'drawingGroup' helps to fix it
                                .drawingGroup()
                            
                            Text(viewStore.manga.attributes.status.rawValue.capitalized)
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                    }
                    
                    Text(viewStore.manga.title)
                        .font(.title.bold())
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(5)
                }
                .padding(.horizontal)
                .padding(.top, 40)
                .padding(.bottom, 25)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .opacity(headerOverlayOpacity)
        }
    }

    // when user scrolls up, we make all text and gradient on header slowly disappear
    private var headerOverlayOpacity: Double {
        if headerOffset < 0 { return 1 }
        
        let opacity = 1 - headerOffset * 0.01
        
        return opacity >= 0 ? opacity : 0
    }
    
    
    @MainActor private var mangaBodyView: some View {
        WithViewStore(store.actionless) { viewStore in
            switch viewStore.selectedTab {
                case .info:
                    aboutTab
                case .chapters:
                    IfLetStore(
                        store.scope(
                            state: \.pagesState,
                            action: OnlineMangaViewAction.pagesAction
                        ),
                        then: PagesView.init,
                        else: {
                            ProgressView()
                                .padding(.top, 50)
                                .padding(.bottom, 20)
                        }
                    )
                case .coverArt:
                    coverArtTab
            }
        }
        .padding(.horizontal, 5)
    }
    
    @MainActor private var coverArtTab: some View {
        WithViewStore(store.actionless) { viewStore in
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 10)]) {
                ForEach(viewStore.croppedCoverArtURLs.indices, id: \.self) { coverArtIndex in
                    LazyImage(url: viewStore.croppedCoverArtURLs[coverArtIndex]) { state in
                        if let image = state.image {
                            image
                                .resizingMode(.aspectFit)
                                .overlay(
                                    ZStack(alignment: .bottom) {
                                        if let volume = viewStore.allCoverArtsInfo[coverArtIndex].attributes.volume {
                                            LinearGradient(
                                                colors: [.clear, .clear, .black],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                            
                                            Text("Volume \(volume)")
                                                .font(.callout)
                                        }
                                    }
                                )
                        } else if state.isLoading || state.error != nil {
                            ProgressView()
                        }
                    }
                    .frame(height: 240)
                    .padding(.horizontal, 5)
                }
            }
            .padding()
        }
    }
    
    private var aboutTab: some View {
        WithViewStore(store.actionless) { viewStore in
            VStack(alignment: .leading, spacing: 15) {
                if let statistics = viewStore.statistics {
                    HStack(alignment: .top, spacing: 10) {
                        HStack(alignment: .top, spacing: 0) {
                            Image(systemName: "star.fill")
                            
                            Text(statistics.rating.average?.clean() ?? statistics.rating.bayesian.clean())
                        }
                        
                        HStack(alignment: .top, spacing: 0) {
                            Image(systemName: "bookmark.fill")
                            
                            Text(statistics.follows.abbreviation)
                        }
                    }
                    .padding(.vertical)
                    .font(.subheadline)
                }
                
                if !viewStore.manga.authors.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Author")
                            .font(.headline)
                            .fontWeight(.black)
                        
                        Divider()
                        
                        FlexibleView(
                            data: viewStore.manga.authors.map(\.name),
                            spacing: 10,
                            alignment: .leading
                        ) { authorName in
                            makeChipsView(text: authorName)
                        }
                        .padding(.horizontal, 5)
                    }
                }
                
                if let description = viewStore.manga.description {
                    VStack(alignment: .leading) {
                        Text("Description")
                            .font(.headline)
                            .fontWeight(.black)
                        
                        Divider()
                        
                        Text(LocalizedStringKey(description))
                            .padding(.horizontal, 10)
                    }
                }
                
                tags
            }
        }
    }
    
    private var tags: some View {
        WithViewStore(store.actionless) { viewStore in
            VStack(alignment: .leading, spacing: 15) {
                Text("Tags")
                    .font(.headline)
                    .fontWeight(.black)
                
                Divider()
                
                FlexibleView(
                    data: viewStore.manga.attributes.tags,
                    spacing: 10,
                    alignment: .leading
                ) { tag in
                    makeChipsView(text: tag.name.capitalized)
                }
                .padding(.horizontal, 5)

                if let demographic = viewStore.manga.attributes.publicationDemographic?.rawValue {
                    VStack(alignment: .leading) {
                        Text("Demographic")
                            .font(.headline)
                            .fontWeight(.black)
                        
                        Divider()
                        
                        makeChipsView(text: demographic.capitalized)
                            .padding(.horizontal, 5)
                    }
                    .frame(minHeight: 20)
                }
            }
        }
    }
    
    @ViewBuilder private func makeChipsView(text: String) -> some View {
        Text(text)
            .font(.callout)
            .lineLimit(1)
            .padding(10)
            .foregroundColor(.white)
            .background(Color.theme.darkGray)
            .cornerRadius(10)
    }
     
    private var backButton: some View {
        Button {
            self.dismiss()
        } label: {
            Image(systemName: "arrow.left")
                .foregroundColor(.white)
                .padding(.vertical)
        }
        .transition(.opacity)
    }
    
    private var pinnedNavigation: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 25) {
                backButton
                    .opacity(isViewScrolledDown ? 1 : 0)
                
                ForEach(OnlineMangaViewState.Tab.allCases, content: makeTabLabel)
                    .offset(x: isViewScrolledDown ? 0 : -40)
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 5)
        }
        .animation(.linear(duration: 0.2), value: isViewScrolledDown)
        .background(Color.black)
        .offset(y: headerOffset > 0 ? 0 : -headerOffset / 15)
        .modifier(
            MangaViewOffsetModifier(
                offset: $headerOffset
            )
        )
    }
    
    /// Makes label for navigation through MangaView
    private func makeTabLabel(for tab: OnlineMangaViewState.Tab) -> some View {
        WithViewStore(store) { viewStore in
            VStack(spacing: 12) {
                Text(tab.rawValue)
                    .fontWeight(.semibold)
                    .foregroundColor(viewStore.selectedTab == tab ? .white : .gray)
                
                ZStack {
                    if viewStore.selectedTab == tab {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(.white)
                            .matchedGeometryEffect(id: "tab", in: tabAnimationNamespace)
                    }
                }
                .padding(.horizontal, 4)
                .frame(height: 6)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                viewStore.send(.mangaTabChanged(tab), animation: .easeInOut)
            }
        }
    }
    
    struct MangaViewOffsetModifier: ViewModifier {
        @Binding var offset: CGFloat
        @State private var startValue: CGFloat = 0
        
        func body(content: Content) -> some View {
            content
                .overlay(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: MangaViewOffsetKey.self, value: geo.frame(in: .named("scroll")).minY)
                            .onPreferenceChange(MangaViewOffsetKey.self) { value in
                                if startValue == 0 {
                                    startValue = value
                                }
                                
                                offset = value - startValue
                            }
                    }
                )
        }
    }
    
    struct MangaViewOffsetKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }
}
