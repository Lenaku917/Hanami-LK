//
//  SettingsView.swift
//  Hanami
//
//  Created by Oleg on 10/10/2022.
//

import SwiftUI
import ComposableArchitecture

struct SettingsView: View {
    let store: StoreOf<SettingsFeature>
    @State private var showLocalizationView = false
    
    var body: some View {
        NavigationView {
            VStack {
                Text("by oolxg")
                    .font(.caption2)
                    .frame(height: 0)
                    .foregroundColor(.clear)
                
                List {
                    localizationSection
                    
                    readingSection
                    
                    privacySection
                    
                    appearanceSection
                    
                    storageSection
                }
                .navigationTitle("Settings")
                .tint(Color.theme.accent)
                .listStyle(.plain)
            }
        }
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(
            store: Store(
                initialState: SettingsFeature.State(),
                reducer: SettingsFeature()._printChanges()
            )
        )
    }
}
#endif

extension SettingsView {
    private var localizationSection: some View {
        Section {
            WithViewStore(store) { viewStore in
                HStack(spacing: 8) {
                    Text("Language for manga reading")
                    
                    Spacer()
                    
                    Text(viewStore.config.iso639Language.language)
                        .foregroundColor(.theme.accent)
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 12)
                        .foregroundColor(.theme.accent)
                }
                .contentShape(Rectangle())
                .onTapGesture { showLocalizationView = true }
                .fullScreenCover(isPresented: $showLocalizationView) {
                    LocalizationSettingsView(selectedLanugauge: viewStore.binding(\.$config.iso639Language))
                }
            }
        } header: {
            Text("Localization")
        }
    }
    
    private var privacySection: some View {
        Section {
            WithViewStore(store) { viewStore in
                Picker("Auto-lock", selection: viewStore.binding(\.$config.autolockPolicy)) {
                    ForEach(AutoLockPolicy.allCases) { policy in
                        Text(policy.value)
                            .tag(policy)
                    }
                }
                .pickerStyle(.menu)
                
                Slider(
                    value: viewStore.binding(\.$config.blurRadius),
                    in: Defaults.Security.minBlurRadius...Defaults.Security.maxBlurRadius,
                    step: Defaults.Security.blurRadiusStep,
                    minimumValueLabel: Image(systemName: "eye"),
                    maximumValueLabel: Image(systemName: "eye.slash"),
                    label: EmptyView.init
                )
            }
        } header: {
            Text("Privacy")
        }
    }
    
    private var storageSection: some View {
        Section {
            WithViewStore(store) { viewStore in
                Toggle(isOn: viewStore.binding(\.$config.useHigherQualityImagesForOnlineReading)) {
                    Label("Read online manga in higher quality", systemImage: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.theme.foreground)
                }
                
                Toggle(isOn: viewStore.binding(\.$config.useHigherQualityImagesForCaching)) {
                    Label("Save manga in higher quality", systemImage: "antenna.radiowaves.left.and.right.slash")
                        .foregroundColor(.theme.foreground)
                }
                
                HStack {
                    Label("Saved manga size", systemImage: "folder.fill")
                        .foregroundColor(.theme.foreground)
                    
                    Spacer()
                    
                    Text("\(viewStore.usedStorageSpace.clean()) MB")
                }
                
                Button(role: .destructive) {
                    viewStore.send(.clearImageCacheButtonTapped)
                } label: {
                    Label("Clear image cache", systemImage: "photo.stack")
                        .foregroundColor(.red)
                }
                
                if viewStore.usedStorageSpace > 0 {
                    Button(role: .destructive) {
                        viewStore.send(.clearMangaCacheButtonTapped)
                    } label: {
                        Label("Delete all manga", systemImage: "trash")
                            .foregroundColor(.red)
                            .confirmationDialog(
                                store.scope(state: \.confirmationDialog),
                                dismiss: .cancelTapped
                            )
                    }
                }
            }
        } header: {
            Text("Storage and Network")
        }
    }
    
    private var appearanceSection: some View {
        Section {
            WithViewStore(store) { viewStore in
                Picker("Theme", selection: viewStore.binding(\.$config.colorScheme)) {
                    Text("System").tag(0)
                    
                    Text("Light").tag(1)
                    
                    Text("Dark").tag(2)
                }
                .pickerStyle(.menu)
            }
        } header: {
            Text("Appearance")
        }
    }
    
    private var readingSection: some View {
        Section {
            WithViewStore(store) { viewStore in
                Picker("Reading format", selection: viewStore.binding(\.$config.readingFormat)) {
                    ForEach(SettingsConfig.ReadingFormat.allCases, id: \.self) { readingFormat in
                        Text(readingFormat.rawValue).tag(readingFormat)
                    }
                }
                .pickerStyle(.menu)
            }
        } header: {
            Text("Reading")
        }
    }
}
