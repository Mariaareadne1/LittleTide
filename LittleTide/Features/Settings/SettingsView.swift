import SwiftUI
import TideKit
import TideUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var isChoosingCoast = false
    @State private var isConfirmingClear = false

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section("Coast") {
                    if let station = model.station {
                        LabeledContent(station.displayName.title, value: "Station \(station.id)")
                    }
                    Button("Change coast") { isChoosingCoast = true }
                }
                Section("Display") {
                    Picker("Heights", selection: $model.unit) {
                        Text("Feet").tag(HeightUnit.feet)
                        Text("Meters").tag(HeightUnit.meters)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("unitPicker")
                    Toggle("Haptics at highs and lows", isOn: $model.isHapticsEnabled)
                }
                Section {
                    NavigationLink("Add a home-screen widget") { WidgetGuideView() }
                }
                Section("Data") {
                    Button {
                        model.refresh(manual: true)
                    } label: {
                        HStack {
                            Text("Refresh predictions now")
                            Spacer()
                            if model.isRefreshing { ProgressView() }
                        }
                    }
                    .disabled(model.isRefreshing || model.station == nil)
                    Button("Clear saved predictions", role: .destructive) { isConfirmingClear = true }
                }
                Section("About") {
                    NavigationLink("Privacy") { LegalTextView(title: "Privacy", text: LegalText.privacy) }
                    Link("Full privacy policy", destination: LegalText.privacyPolicyURL)
                    NavigationLink("Data source & credits") { LegalTextView(title: "Credits", text: LegalText.credits) }
                    Link("Support & feedback", destination: LegalText.supportURL)
                    LabeledContent("Version", value: Bundle.main.versionString)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $isChoosingCoast) { CoastSearchView() }
            .confirmationDialog("Clear saved predictions?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
                Button("Clear", role: .destructive) { Task { await model.clearCachedPredictions() } }
            } message: {
                Text("Little Tide will download new predictions from NOAA. Your chosen coast is kept.")
            }
        }
    }
}

struct WidgetGuideView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            Section("Your widgets right now") {
                let now = model.clock.now()
                let content = CoastWidgetContent(date: now, station: model.station, forecast: model.forecastState.forecast, unit: model.unit)
                VStack(alignment: .leading, spacing: 14) {
                    SmallCoastCard(content: content, rendering: .fullColor)
                        .padding(16)
                        .frame(width: 170, height: 170)
                        .background(CoastWidgetBackground(content: content, family: .small))
                        .clipShape(.rect(cornerRadius: 22, style: .continuous))
                    MediumCoastCard(content: content, rendering: .fullColor)
                        .padding(16)
                        .frame(width: 364, height: 170)
                        .background(CoastWidgetBackground(content: content, family: .medium))
                        .clipShape(.rect(cornerRadius: 22, style: .continuous))
                }
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Preview of the small and medium widgets with your current coast.")
            }
            Section {
                Text("Little Tide can’t add widgets for you, but it only takes a moment:")
                Label("Touch and hold an empty area of your Home Screen until the apps jiggle.", systemImage: "1.circle")
                Label("Tap Edit in the top corner, then Add Widget.", systemImage: "2.circle")
                Label("Search for Little Tide and choose the small or medium size.", systemImage: "3.circle")
                Label("Tap Add Widget, then Done.", systemImage: "4.circle")
            }
            Section {
                Text("Widgets show your chosen coast. They update from saved predictions through the day; iOS decides exactly when they refresh, so open the app if the widget asks you to.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Add a widget")
    }
}

struct LegalTextView: View {
    let title: String
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .typeStyle(.body)
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
        }
        .background(Palette.paper)
        .navigationTitle(title)
    }
}

extension Bundle {
    var versionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
