import SwiftUI

struct LiveTVView: View {
    @EnvironmentObject private var appState: AppState
    @State private var tab: Tab = .guide
    @State private var data: LiveTVData?
    @State private var loading = true
    @State private var error: String?
    @State private var timerTitle = ""
    @State private var timerChannelID = ""
    @State private var timerSeries = false
    @State private var timerMsg: String?

    enum Tab: String, CaseIterable { case guide, recordings, timers }

    var body: some View {
        VStack(spacing: 12) {
            Picker("Tab", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { t in
                    Text(t.rawValue.capitalized).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if loading { LoadingStateView() }
            else if let error { ErrorStateView(message: error) }
            else if let data {
                switch tab {
                case .guide:
                    List(data.channels) { ch in
                        VStack(alignment: .leading) {
                            Text(ch.name).font(.headline)
                            Text("Ch \(ch.number)").font(.caption).foregroundStyle(.secondary)
                            if let now = ch.nowPlayingTitle {
                                Text(now).font(.caption)
                            }
                        }
                    }
                case .recordings:
                    List(data.recordings) { rec in
                        VStack(alignment: .leading) {
                            Text(rec.title)
                            Text(rec.status).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                case .timers:
                    Form {
                        Section("Schedule timer") {
                            TextField("Title", text: $timerTitle)
                            TextField("Channel ID", text: $timerChannelID)
                            Toggle("Series", isOn: $timerSeries)
                            Button("Schedule") { Task { await schedule() } }
                        }
                        if let timerMsg {
                            Section { Text(timerMsg) }
                        }
                        Section("Timers") {
                            ForEach(data.timers) { timer in
                                VStack(alignment: .leading) {
                                    Text(timer.title)
                                    Text(timer.channelID).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Live TV")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loading = true
        do {
            data = try await appState.api.listLiveTV()
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    private func schedule() async {
        do {
            try await appState.api.createLiveTVTimer(channelID: timerChannelID, title: timerTitle, series: timerSeries)
            timerMsg = "Timer scheduled."
            await load()
        } catch {
            timerMsg = error.localizedDescription
        }
    }
}
