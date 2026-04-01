import SwiftUI

struct StationPickerSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var onlyReady = false

    private var usingSections: Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var favoriteStations: [RadarStationInfo] {
        sortedStations(appState.favoriteStations.filter(matchesFilters))
    }

    private var recentStations: [RadarStationInfo] {
        sortedStations(
            appState.recentStations.filter(matchesFilters).filter { !appState.isFavorite($0) }
        )
    }

    private var allStations: [RadarStationInfo] {
        let hiddenICAOs = Set((favoriteStations + recentStations).map(\.icao))
        let base = appState.stations.filter(matchesFilters)
        let trimmed = usingSections ? base.filter { !hiddenICAOs.contains($0.icao) } : base
        return sortedStations(trimmed)
    }

    var body: some View {
        ZStack {
            radarChromeBackground.ignoresSafeArea()

            VStack(spacing: 16) {
                header
                searchBar
                readyToggle

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 14) {
                        if usingSections {
                            stationSection(
                                title: "FAVORITES",
                                subtitle: favoriteStations.isEmpty ? "Pin the stations you keep coming back to." : "Pinned radar sites.",
                                stations: favoriteStations,
                                showWhenEmpty: true
                            )

                            stationSection(
                                title: "RECENT",
                                subtitle: recentStations.isEmpty ? "Your recent station changes will show up here." : "Latest stations from this device.",
                                stations: recentStations,
                                showWhenEmpty: true
                            )
                        }

                        stationSection(
                            title: usingSections ? "ALL STATIONS" : "RESULTS",
                            subtitle: usingSections ? "Full NEXRAD site list with active and loaded sites sorted first." : "\(allStations.count) matches",
                            stations: allStations,
                            showWhenEmpty: true
                        )
                    }
                    .padding(.bottom, 16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("STATION BROWSER")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.3)
                    .foregroundColor(radarChromeAccent.opacity(0.86))
                Text("Select a radar site")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(radarChromePanelEdge.opacity(0.7), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.54))
            TextField("ICAO, city, state", text: $searchText)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .foregroundColor(.white)
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.34))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(radarChromePanel.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(radarChromePanelEdge.opacity(0.76), lineWidth: 1)
                )
        )
    }

    private var readyToggle: some View {
        Toggle(isOn: $onlyReady) {
            Text("Only loaded or active downloads")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
        }
        .tint(radarChromeAccent)
    }

    private func stationSection(title: String,
                                subtitle: String,
                                stations: [RadarStationInfo],
                                showWhenEmpty: Bool) -> some View {
        Group {
            if !stations.isEmpty || showWhenEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1.1)
                            .foregroundColor(radarChromeWarm.opacity(0.88))
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.56))
                    }

                    if stations.isEmpty {
                        emptySectionCard(title == "FAVORITES" ? "No favorites yet" : "Nothing here yet")
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(stations, id: \.index) { station in
                                stationRow(station)
                            }
                        }
                    }
                }
            }
        }
    }

    private func emptySectionCard(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white.opacity(0.56))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(radarChromePanel.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(radarChromePanelEdge.opacity(0.5), lineWidth: 1)
                    )
            )
    }

    private func stationRow(_ station: RadarStationInfo) -> some View {
        let isActive = Int(station.index) == appState.activeStationIndex
        let isFavorite = appState.isFavorite(station)

        return HStack(spacing: 10) {
            Button(action: {
                appState.selectStation(station)
                dismiss()
            }) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text(station.icao)
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)

                            if isActive {
                                statusPill("ACTIVE", color: radarChromeWarm)
                            } else if station.loaded {
                                statusPill("LIVE", color: radarChromeAccent)
                            } else if station.downloading {
                                statusPill("FETCH", color: .white.opacity(0.8))
                            }
                        }

                        Text(stationLocation(station))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.72))

                        Text(stationStatus(station))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.52))

                        if station.tdsCount > 0 || station.hailCount > 0 || station.mesoCount > 0 {
                            HStack(spacing: 6) {
                                if station.tdsCount > 0 {
                                    signalBadge(label: "TDS", value: Int(station.tdsCount), tint: radarChromeWarm)
                                }
                                if station.hailCount > 0 {
                                    signalBadge(label: "HAIL", value: Int(station.hailCount), tint: radarChromeAccent)
                                }
                                if station.mesoCount > 0 {
                                    signalBadge(label: "MESO", value: Int(station.mesoCount), tint: .white.opacity(0.85))
                                }
                            }
                        }
                    }

                    Spacer()

                    statusGlyph(for: station)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isActive ? radarChromeAccent.opacity(0.16) : radarChromePanel.opacity(0.94))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(isActive ? radarChromeAccent.opacity(0.88) : radarChromePanelEdge.opacity(0.74),
                                        lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            Button(action: {
                appState.toggleFavorite(station)
            }) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(isFavorite ? radarChromeWarm : .white.opacity(0.48))
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black.opacity(0.22))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(radarChromePanelEdge.opacity(0.68), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func matchesFilters(_ station: RadarStationInfo) -> Bool {
        let matchesReady = !onlyReady || station.loaded || station.downloading
        guard matchesReady else { return false }

        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return true }

        let searchBlob = [
            station.icao,
            station.siteName,
            station.stateCode
        ]
        .joined(separator: " ")

        return searchBlob.localizedCaseInsensitiveContains(trimmedSearch)
    }

    private func sortedStations(_ stations: [RadarStationInfo]) -> [RadarStationInfo] {
        stations.sorted { lhs, rhs in
            let lhsActive = Int(lhs.index) == appState.activeStationIndex
            let rhsActive = Int(rhs.index) == appState.activeStationIndex
            if lhsActive != rhsActive { return lhsActive }

            let lhsFavorite = appState.isFavorite(lhs)
            let rhsFavorite = appState.isFavorite(rhs)
            if lhsFavorite != rhsFavorite { return lhsFavorite }

            if lhs.loaded != rhs.loaded { return lhs.loaded }
            if lhs.downloading != rhs.downloading { return lhs.downloading }

            if lhs.stateCode != rhs.stateCode { return lhs.stateCode < rhs.stateCode }
            return lhs.icao < rhs.icao
        }
    }

    private func stationLocation(_ station: RadarStationInfo) -> String {
        let locationParts = [station.siteName, station.stateCode].filter { !$0.isEmpty }
        if !locationParts.isEmpty {
            return locationParts.joined(separator: ", ")
        }
        return String(format: "%.2f, %.2f", station.lat, station.lon)
    }

    private func stationStatus(_ station: RadarStationInfo) -> String {
        if !station.errorMessage.isEmpty {
            return station.errorMessage.uppercased()
        }

        if !station.scanTime.isEmpty {
            var parts = ["SCAN \(radarTimestampLabel(station.scanTime))"]
            if station.sweepCount > 0 {
                parts.append("\(Int(station.sweepCount)) SWEEPS")
                parts.append(String(format: "%.1f° LOWEST", station.lowestElevationDeg))
            }
            return parts.joined(separator: "  ")
        }

        if station.downloading {
            return "FETCHING LATEST VOLUME"
        }

        return String(format: "%.2f, %.2f", station.lat, station.lon)
    }

    private func statusGlyph(for station: RadarStationInfo) -> some View {
        Group {
            if station.loaded {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(radarChromeAccent)
            } else if station.downloading {
                ProgressView()
                    .tint(radarChromeAccent)
            } else {
                Image(systemName: "circle")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.22))
            }
        }
    }

    private func statusPill(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .tracking(1.0)
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(0.14))
            )
    }

    private func signalBadge(label: String, value: Int, tint: Color) -> some View {
        Text("\(label) \(value)")
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .tracking(0.8)
            .foregroundColor(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
    }
}
