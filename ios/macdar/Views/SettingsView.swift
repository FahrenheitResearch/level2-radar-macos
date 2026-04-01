import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var dbzThreshold: Float = 5.0
    @State private var stormSpeed: Double = 15.0
    @State private var stormDir: Double = 225.0

    private var appVersionLabel: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (shortVersion, buildNumber) {
        case let (version?, build?) where !version.isEmpty && !build.isEmpty:
            return "v\(version) (\(build))"
        case let (version?, _):
            return "v\(version)"
        case let (_, build?) where !build.isEmpty:
            return "Build \(build)"
        default:
            return "Release"
        }
    }

    var body: some View {
        ZStack {
            radarChromeBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    sectionCard(title: "LIVE LOOP", subtitle: "Deeper loop caches use more memory, but give the Mac build more history to scrub.") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("BACKFILLED FRAMES")
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                    .tracking(1.0)
                                    .foregroundColor(.white.opacity(0.58))
                                Spacer()
                                Text("\(appState.liveLoopTargetFrames)")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                            }

                            Slider(
                                value: Binding(
                                    get: { Double(appState.liveLoopTargetFrames) },
                                    set: { appState.setLiveLoopLength(Int($0.rounded())) }
                                ),
                                in: Double(appState.supportsDesktopPerformanceControls ? 4 : 1)...Double(max(appState.liveLoopMaxFrames, appState.supportsDesktopPerformanceControls ? 4 : 1)),
                                step: 1
                            )
                            .tint(radarChromeAccent)
                        }

                        if appState.supportsDesktopPerformanceControls {
                            settingToggle(title: "Full-resolution pan and zoom",
                                          subtitle: "Uses more GPU so the radar stays sharp while you interact on Mac.",
                                          isOn: Binding(
                                            get: { appState.prefersFullResolutionInteraction },
                                            set: { appState.setFullResolutionInteraction($0) }
                                          ))
                        }
                    }

                    sectionCard(title: "DISPLAY", subtitle: "Tighten the raster to avoid weak low-end clutter.") {
                        sliderBlock(title: "MIN DBZ THRESHOLD",
                                    valueText: "\(Int(dbzThreshold)) dBZ",
                                    value: Binding(
                                        get: { Double(dbzThreshold) },
                                        set: { dbzThreshold = Float($0) }
                                    ),
                                    range: -30...50,
                                    step: 1) { val in
                            appState.setDbzThreshold(Float(val))
                        }

                        settingToggle(title: "Storm-relative velocity",
                                      subtitle: "Switches velocity product into SRV mode.",
                                      isOn: Binding(
                                        get: { appState.engine.srvMode },
                                        set: { appState.setSRVMode($0) }
                                      ))

                        if appState.engine.srvMode {
                            sliderBlock(title: "STORM SPEED",
                                        valueText: "\(Int(stormSpeed.rounded())) m/s",
                                        value: $stormSpeed,
                                        range: 0...45,
                                        step: 1) { val in
                                appState.setStormSpeed(Float(val))
                            }

                            sliderBlock(title: "STORM DIRECTION",
                                        valueText: "\(Int(stormDir.rounded()))°",
                                        value: $stormDir,
                                        range: 0...359,
                                        step: 1) { val in
                                appState.setStormDir(Float(val))
                            }
                        }
                    }

                    sectionCard(title: "ALERTS", subtitle: "Storm-focused defaults stay on. Other alert classes are opt-in.") {
                        settingToggle(title: "Alert polygons",
                                      subtitle: "Shows warning and watch outlines on top of radar.",
                                      isOn: Binding(
                                        get: { appState.engine.warningsEnabled },
                                        set: { appState.setWarningsEnabled($0) }
                                      ))

                        HStack {
                            statTile(label: "WARN", value: "\(appState.warningCount)")
                            statTile(label: "QUALITY", value: appState.orchestrator.renderQuality.rawValue)
                        }
                    }

                    sectionCard(title: "ALERT FILTERS", subtitle: "Tornado, severe thunderstorm, and flood warnings ship enabled by default.") {
                        settingToggle(title: "Tornado warnings",
                                      subtitle: "Keep tornado warning polygons visible.",
                                      isOn: Binding(
                                        get: { appState.engine.tornadoAlertsEnabled },
                                        set: { appState.setTornadoAlertsEnabled($0) }
                                      ))

                        settingToggle(title: "Severe thunderstorm warnings",
                                      subtitle: "Shows severe thunderstorm warning polygons.",
                                      isOn: Binding(
                                        get: { appState.engine.severeAlertsEnabled },
                                        set: { appState.setSevereAlertsEnabled($0) }
                                      ))

                        settingToggle(title: "Flood warnings",
                                      subtitle: "Shows flood and flash flood warning polygons.",
                                      isOn: Binding(
                                        get: { appState.engine.floodAlertsEnabled },
                                        set: { appState.setFloodAlertsEnabled($0) }
                                      ))

                        settingToggle(title: "Watches",
                                      subtitle: "Opt-in SPC and NWS watch polygons.",
                                      isOn: Binding(
                                        get: { appState.engine.watchAlertsEnabled },
                                        set: { appState.setWatchAlertsEnabled($0) }
                                      ))

                        settingToggle(title: "Statements",
                                      subtitle: "Opt-in weather statements and special weather statements.",
                                      isOn: Binding(
                                        get: { appState.engine.statementAlertsEnabled },
                                        set: { appState.setStatementAlertsEnabled($0) }
                                      ))

                        settingToggle(title: "Advisories",
                                      subtitle: "Opt-in advisory polygons.",
                                      isOn: Binding(
                                        get: { appState.engine.advisoryAlertsEnabled },
                                        set: { appState.setAdvisoryAlertsEnabled($0) }
                                      ))

                        settingToggle(title: "Fire weather",
                                      subtitle: "Opt-in red flag and fire weather products.",
                                      isOn: Binding(
                                        get: { appState.engine.fireAlertsEnabled },
                                        set: { appState.setFireAlertsEnabled($0) }
                                      ))

                        settingToggle(title: "Marine",
                                      subtitle: "Opt-in marine polygons and small-craft style alerts.",
                                      isOn: Binding(
                                        get: { appState.engine.marineAlertsEnabled },
                                        set: { appState.setMarineAlertsEnabled($0) }
                                      ))

                        settingToggle(title: "Other",
                                      subtitle: "Opt-in miscellaneous unclassified alert polygons.",
                                      isOn: Binding(
                                        get: { appState.engine.otherAlertsEnabled },
                                        set: { appState.setOtherAlertsEnabled($0) }
                                      ))
                    }

                    sectionCard(title: "ALERT COLORS", subtitle: "Tune the outline colors for each alert class.") {
                        colorRow(title: "Tornado", subtitle: "Primary tornado warning color.",
                                 color: alertColorBinding(get: { appState.engine.tornadoAlertColor },
                                                          set: { appState.setTornadoAlertColor($0) }))
                        colorRow(title: "Severe", subtitle: "Primary severe thunderstorm warning color.",
                                 color: alertColorBinding(get: { appState.engine.severeAlertColor },
                                                          set: { appState.setSevereAlertColor($0) }))
                        colorRow(title: "Flood", subtitle: "Primary flood and flash flood warning color.",
                                 color: alertColorBinding(get: { appState.engine.floodAlertColor },
                                                          set: { appState.setFloodAlertColor($0) }))
                        colorRow(title: "Watch", subtitle: "Watch polygon color when watches are enabled.",
                                 color: alertColorBinding(get: { appState.engine.watchAlertColor },
                                                          set: { appState.setWatchAlertColor($0) }))
                        colorRow(title: "Statement", subtitle: "Statement polygon color when statements are enabled.",
                                 color: alertColorBinding(get: { appState.engine.statementAlertColor },
                                                          set: { appState.setStatementAlertColor($0) }))
                        colorRow(title: "Advisory", subtitle: "Advisory polygon color when advisories are enabled.",
                                 color: alertColorBinding(get: { appState.engine.advisoryAlertColor },
                                                          set: { appState.setAdvisoryAlertColor($0) }))
                        colorRow(title: "Fire", subtitle: "Fire weather polygon color.",
                                 color: alertColorBinding(get: { appState.engine.fireAlertColor },
                                                          set: { appState.setFireAlertColor($0) }))
                        colorRow(title: "Marine", subtitle: "Marine polygon color.",
                                 color: alertColorBinding(get: { appState.engine.marineAlertColor },
                                                          set: { appState.setMarineAlertColor($0) }))
                        colorRow(title: "Other", subtitle: "Fallback color for uncategorized alerts.",
                                 color: alertColorBinding(get: { appState.engine.otherAlertColor },
                                                          set: { appState.setOtherAlertColor($0) }))
                    }

                    sectionCard(title: "DATA", subtitle: "Manual controls for the live feed.") {
                        Button(action: { appState.engine.refreshData() }) {
                            HStack {
                                Text("REFRESH ALL STATIONS")
                                Spacer()
                                Image(systemName: "arrow.clockwise")
                            }
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .tracking(0.8)
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(radarChromeAccent.opacity(0.22))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(radarChromeAccent.opacity(0.9), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)

                        HStack {
                            statTile(label: "LOADED", value: "\(appState.stationsLoaded)")
                            statTile(label: "TOTAL", value: "\(appState.engine.stationsTotal)")
                        }
                    }

                    sectionCard(title: "ABOUT", subtitle: "Device-first Metal radar shell.") {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("LEVEL2 RADAR")
                                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Text(appState.supportsDesktopPerformanceControls
                                     ? "Mac Catalyst shell with a fast Metal radar path"
                                     : "SwiftUI shell with a fast Metal radar path")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.62))
                            }
                            Spacer()
                            Text(appVersionLabel)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(radarChromeWarm)
                        }

                        Divider()
                            .overlay(radarChromePanelEdge.opacity(0.42))

                        Text("Radar data from public NEXRAD Level II feeds and active NWS alert sources.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.62))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
        }
        .onAppear {
            dbzThreshold = appState.engine.dbzThreshold
            stormSpeed = Double(appState.engine.stormSpeed)
            stormDir = Double(appState.engine.stormDir)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("CONTROL ROOM")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.4)
                    .foregroundColor(radarChromeAccent.opacity(0.86))
                Text("Runtime settings")
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

    private func sectionCard<Content: View>(title: String,
                                            subtitle: String,
                                            @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(radarChromeWarm.opacity(0.82))
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.56))
            }

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(radarChromePanel.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(radarChromePanelEdge.opacity(0.78), lineWidth: 1)
                )
        )
    }

    private func settingToggle(title: String,
                               subtitle: String,
                               isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.56))
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(radarChromeAccent)
        }
    }

    private func sliderBlock(title: String,
                             valueText: String,
                             value: Binding<Double>,
                             range: ClosedRange<Double>,
                             step: Double,
                             onChange: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(1.0)
                    .foregroundColor(.white.opacity(0.58))
                Spacer()
                Text(valueText)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }

            Slider(value: value, in: range, step: step)
                .tint(radarChromeAccent)
                .onChange(of: value.wrappedValue) { _, newValue in
                    onChange(newValue)
                }
        }
    }

    private func statTile(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1.1)
                .foregroundColor(.white.opacity(0.56))
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(radarChromePanelEdge.opacity(0.68), lineWidth: 1)
                )
        )
    }

    private func colorRow(title: String,
                          subtitle: String,
                          color: Binding<Color>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.56))
            }

            Spacer()

            ColorPicker("", selection: color, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 42, height: 28)
        }
    }

    private func alertColorBinding(get: @escaping () -> UInt32,
                                   set: @escaping (UInt32) -> Void) -> Binding<Color> {
        Binding(
            get: { colorFromPackedRGBA(get()) },
            set: { set(packedRGBA(from: $0)) }
        )
    }

    private func colorFromPackedRGBA(_ value: UInt32) -> Color {
        Color(
            .sRGB,
            red: Double(value & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double((value >> 16) & 0xFF) / 255.0,
            opacity: Double((value >> 24) & 0xFF) / 255.0
        )
    }

    private func packedRGBA(from color: Color) -> UInt32 {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        func channel(_ value: CGFloat) -> UInt32 {
            UInt32(max(0, min(255, Int((value * 255.0).rounded()))))
        }

        return channel(red) |
            (channel(green) << 8) |
            (channel(blue) << 16) |
            (channel(alpha) << 24)
    }
}
