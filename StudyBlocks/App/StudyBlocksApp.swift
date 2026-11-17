import SwiftUI
import AppKit
import UniformTypeIdentifiers
import SwiftData
import Observation
import Combine

@MainActor @Observable final class AppState {
    var store: StudyStore?
    var startupError: String?
    var error: String?
    var notice: String?
    var page: Page = .today
    var selectedDay = StudyDate.key()
    var showNewBlock = false
    var showNewCourse = false
    var showSettings = false
    var undoAction: (() throws -> Void)?
    var undoLabel = "마지막 변경 취소"
    init() { openStore() }
    func openStore() {
        do {
            let args = ProcessInfo.processInfo.arguments
            let url = args.firstIndex(of: "--store-path").flatMap { args.indices.contains($0 + 1) ? URL(fileURLWithPath: args[$0 + 1]) : nil }
            store = try StudyStore(container: StudyStore.makeContainer(url: url)); startupError = nil
        } catch { startupError = error.localizedDescription }
    }
    func perform(_ action: () throws -> Void) {
        do { try action() } catch { self.error = "변경을 저장하지 못했습니다.\n\(error.localizedDescription)" }
    }
    func toggle(_ block: StudyBlock) {
        guard let store else { return }
        let id = block.id, old = store.status(block)
        perform {
            try store.setStatus(block, old == .done ? .pending : .done)
            undoAction = { if let b = store.blocks.first(where: { $0.id == id }) { try store.setStatus(b, old) } }
            undoLabel = "학습 상태 변경 취소"
        }
    }
    func move(_ block: StudyBlock, to day: String) {
        guard let store else { return }
        let id = block.id, old = block.day
        perform {
            try store.move(block, to: day)
            undoAction = { if let b = store.blocks.first(where: { $0.id == id }) { try store.move(b, to: old) } }
            undoLabel = "날짜 변경 취소"
        }
    }
    func undo() { if let action = undoAction { perform { try action(); undoAction = nil } } }
    func prepareDay(_ day: String) {
        perform {
            try store?.materialize(day: day)
            if UserDefaults.standard.bool(forKey: "automaticRollover"), day == StudyDate.key() { _ = try store?.rollover(to: day) }
        }
    }
    // Opt-in launch report for native app regression checks. No effect during ordinary use.
    func writeVerificationReport() {
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "--verification-report"), args.indices.contains(index + 1) {
            let reportPath = args[index + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                let windows = NSApp.windows.map { window -> [String: Any] in
                    ["title": window.title, "visible": window.isVisible, "miniaturized": window.isMiniaturized,
                     "frame": NSStringFromRect(window.frame)]
                }
                let report: [String: Any] = [
                    "bundleID": Bundle.main.bundleIdentifier ?? "",
                    "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "",
                    "displayVersion": "1.1",
                    "rendered": true,
                    "startupError": self.startupError ?? "",
                    "windows": windows,
                    "courses": self.store?.courses.map { course -> [String: Any] in
                        ["id": course.id.uuidString, "title": course.title, "completed": self.store!.completedLessons(course).count,
                         "total": course.total, "next": self.store!.nextLesson(course) ?? 0]
                    } ?? [],
                    "blocks": self.store?.blocks.count ?? 0,
                    "completedBlocks": self.store?.blocks.filter { self.store!.status($0) == .done }.count ?? 0,
                    "goals": self.store?.goals.map { ["target": $0.target, "achieved": self.store!.achieved($0)] } ?? []
                ]
                do {
                    let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                    try data.write(to: URL(fileURLWithPath: reportPath), options: .atomic)
                } catch { NSLog("Launch verification report: %@", error.localizedDescription) }
            }
        }
        if let sIndex = args.firstIndex(of: "--capture-screenshots"), args.indices.contains(sIndex + 1) {
            let outDir = URL(fileURLWithPath: args[sIndex + 1], isDirectory: true)
            captureScreenshots(to: outDir)
        }
    }
    private func captureScreenshots(to folder: URL) {
        guard let store else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let steps: [(Page, Bool, CGSize, String)] = [
            (.today, false, CGSize(width: 1180, height: 800), "today-light.png"),
            (.courses, false, CGSize(width: 1180, height: 800), "courses-light.png"),
            (.plan, false, CGSize(width: 1180, height: 800), "plan-light.png"),
            (.history, false, CGSize(width: 1180, height: 800), "history-light.png"),
            (.today, true, CGSize(width: 1180, height: 800), "today-dark.png"),
            (.courses, true, CGSize(width: 1180, height: 800), "courses-dark.png"),
            (.plan, true, CGSize(width: 1180, height: 800), "plan-dark.png"),
            (.plan, false, CGSize(width: 800, height: 600), "plan-compact.png"),
            (.today, true, CGSize(width: 800, height: 600), "today-dark-compact.png"),
            (.today, false, CGSize(width: 840, height: 600), "today-compact.png")
        ]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            for (page, isDark, size, filename) in steps {
                self.page = page
                let appearance = NSAppearance(named: isDark ? .darkAqua : .aqua) ?? NSAppearance.currentDrawing()
                appearance.performAsCurrentDrawingAppearance {
                    let view = SnapshotShellView(app: self, store: store, page: page)
                        .frame(width: size.width, height: size.height)
                        .environment(\.colorScheme, isDark ? .dark : .light)
                        .environment(\.isSnapshotCapture, true)
                        .tint(.studyAccent)
                    let renderer = ImageRenderer(content: view)
                    renderer.scale = 2.0
                    renderer.proposedSize = ProposedViewSize(size)
                    if let cgImage = renderer.cgImage {
                        let rep = NSBitmapImageRep(cgImage: cgImage)
                        if let png = rep.representation(using: .png, properties: [:]) {
                            try? png.write(to: folder.appendingPathComponent(filename), options: .atomic)
                        }
                    }
                }
            }
            NSApp.terminate(nil)
        }
    }
    func exportBackup() {
        guard let store else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "공부블록-\(StudyDate.key()).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        perform { try store.exportJSON().write(to: url, options: .atomic); notice = "백업을 저장했습니다." }
    }
    func importBackup() {
        guard let store else { return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        perform {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 20_000_000 else { throw StudyError.invalid("백업 파일은 20MB 이하만 가져올 수 있습니다.") }
            let data = try Data(contentsOf: url), b = try StudyStore.inspectBackup(data)
            let alert = NSAlert(); alert.messageText = "백업으로 복원할까요?"
            alert.informativeText = "현재 데이터를 강좌 \(b.courses.count)개, 학습 블록 \(b.blocks.count)개로 교체합니다. 현재 데이터는 복원 전 백업으로 보관합니다."
            alert.addButton(withTitle: "복원"); alert.addButton(withTitle: "취소")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            let folder = URL.applicationSupportDirectory.appendingPathComponent(StudyStore.bundleID).appendingPathComponent("Backups")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let backup = folder.appendingPathComponent("before-restore-\(UUID().uuidString).json")
            try store.exportJSON().write(to: backup, options: .atomic)
            try store.restoreJSON(data); undoAction = nil; notice = "백업을 복원했습니다."
        }
    }
}

enum Page: String, CaseIterable, Identifiable {
    case today = "오늘", courses = "강좌", plan = "계획", history = "기록"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .today: "checklist"
        case .courses: "play.rectangle.on.rectangle"
        case .plan: "calendar"
        case .history: "clock.arrow.circlepath"
        }
    }
}

@main struct StudyBlocksApp: App {
    @State private var app = AppState()
    @AppStorage("appearance") private var appearance = "system"
    var body: some Scene {
        WindowGroup("공부 블록") {
            RootView(app: app)
                .frame(minWidth: 800, minHeight: 580)
                .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
                .tint(.studyAccent)
        }
        .defaultSize(width: 1180, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("학습 블록 추가") { app.showNewBlock = true }.keyboardShortcut("n").disabled(app.store == nil)
                Button("강좌 등록") { app.showNewCourse = true }.keyboardShortcut("n", modifiers: [.command, .shift]).disabled(app.store == nil)
            }
            CommandGroup(replacing: .undoRedo) { Button(app.undoLabel) { app.undo() }.keyboardShortcut("z").disabled(app.undoAction == nil) }
            CommandGroup(after: .importExport) {
                Button("JSON 백업 내보내기…") { app.exportBackup() }.disabled(app.store == nil)
                Button("JSON 백업 가져오기…") { app.importBackup() }.disabled(app.store == nil)
            }
            CommandMenu("이동") {
                ForEach(Array(Page.allCases.enumerated()), id: \.element) { i, page in
                    Button(page.rawValue) { app.page = page }.keyboardShortcut(KeyEquivalent(Character(String(i + 1))))
                }
                Button("오늘로 이동") { app.selectedDay = StudyDate.key(); app.page = .today }.keyboardShortcut("t")
            }
            CommandGroup(replacing: .appSettings) { Button("설정…") { app.showSettings = true }.keyboardShortcut(",") }
        }
    }
}

// MARK: - Index & Graphite Design System Tokens

private struct SnapshotCaptureKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isSnapshotCapture: Bool {
        get { self[SnapshotCaptureKey.self] }
        set { self[SnapshotCaptureKey.self] = newValue }
    }
}

struct IndexScrollView<Content: View>: View {
    @Environment(\.isSnapshotCapture) private var isSnapshotCapture
    @ViewBuilder let content: Content
    var body: some View {
        if isSnapshotCapture {
            GeometryReader { geo in
                content
                    .frame(width: geo.size.width, alignment: .top)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
            .clipped()
        } else {
            ScrollView {
                content
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

struct IndexDisclosure<LabelContent: View, BodyContent: View>: View {
    @Binding var isExpanded: Bool
    @ViewBuilder let content: BodyContent
    @ViewBuilder let label: LabelContent
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.16)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                    label
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isExpanded {
                content
            }
        }
    }
}

enum IndexTokens {
    static let cardRadius: CGFloat = 10
    static let compactRadius: CGFloat = 7
    static let tagRadius: CGFloat = 4
    static let pageMaxWidth: CGFloat = 1060
}

extension Color {
    private static func dynamic(light: (CGFloat, CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat, CGFloat)) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let c = isDark ? dark : light
            return NSColor(calibratedRed: c.0, green: c.1, blue: c.2, alpha: c.3)
        })
    }

    /// Sage Green: Inherited & refined accent with balanced contrast in both Light and Dark environments
    static let studyAccent = dynamic(
        light: (0.17, 0.45, 0.36, 1.0),
        dark: (0.30, 0.62, 0.50, 1.0)
    )

    /// Paper / Deep Graphite workspace canvas
    static let canvas = dynamic(
        light: (0.969, 0.965, 0.952, 1.0),
        dark: (0.090, 0.094, 0.098, 1.0)
    )

    /// Opaque Index Card surface
    static let card = dynamic(
        light: (0.994, 0.992, 0.986, 1.0),
        dark: (0.129, 0.135, 0.142, 1.0)
    )

    /// Muted card surface for completed items
    static let cardMuted = dynamic(
        light: (0.948, 0.944, 0.932, 1.0),
        dark: (0.108, 0.112, 0.118, 1.0)
    )

    /// Subtle recessed surface for metadata strips, pills, and secondary containers
    static let surfaceSubtle = dynamic(
        light: (0.935, 0.929, 0.914, 1.0),
        dark: (0.160, 0.168, 0.176, 1.0)
    )

    /// Graphite primary ink (deep graphite rather than pure black in light mode; warm off-white in dark mode)
    static let graphite = dynamic(
        light: (0.125, 0.133, 0.141, 1.0),
        dark: (0.925, 0.920, 0.904, 1.0)
    )

    /// Crisp index hairline border
    static let cardBorder = dynamic(
        light: (0.14, 0.15, 0.16, 0.10),
        dark: (1.0, 1.0, 1.0, 0.09)
    )

    /// Stronger index border for active or emphasized states
    static let cardBorderStrong = dynamic(
        light: (0.14, 0.15, 0.16, 0.18),
        dark: (1.0, 1.0, 1.0, 0.17)
    )

    /// Subject inks with enough color and contrast on Paper and Graphite surfaces
    static func subject(_ subject: String) -> Color {
        switch subject {
        case "수학":
            return dynamic(light: (0.16, 0.38, 0.73, 1.0), dark: (0.48, 0.69, 0.98, 1.0))
        case "국어":
            return dynamic(light: (0.72, 0.29, 0.23, 1.0), dark: (0.97, 0.57, 0.48, 1.0))
        case "영어":
            return dynamic(light: (0.52, 0.32, 0.74, 1.0), dark: (0.76, 0.61, 0.98, 1.0))
        case "과학":
            return dynamic(light: (0.08, 0.48, 0.37, 1.0), dark: (0.35, 0.81, 0.64, 1.0))
        case "사회":
            return dynamic(light: (0.66, 0.43, 0.10, 1.0), dark: (0.95, 0.75, 0.34, 1.0))
        case "한국사":
            return dynamic(light: (0.57, 0.34, 0.23, 1.0), dark: (0.85, 0.62, 0.45, 1.0))
        default:
            return dynamic(light: (0.40, 0.43, 0.46, 1.0), dark: (0.64, 0.67, 0.70, 1.0))
        }
    }
}

struct RootView: View {
    @Bindable var app: AppState
    @Environment(\.scenePhase) private var scenePhase
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    @State private var today = StudyDate.key()
    var body: some View {
        Group {
            if let store = app.store {
                NavigationSplitView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.studyAccent)
                                    .frame(width: 26, height: 26)
                                Image(systemName: "square.stack.3d.up.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text("공부 블록")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.graphite)
                                Text("학습량 · 진도 플래너")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 16)

                        List(selection: Binding<Page?>(get: { app.page }, set: { if let v = $0 { app.page = v } })) {
                            ForEach(Page.allCases) { page in
                                HStack(spacing: 8) {
                                    Label(page.rawValue, systemImage: page.symbol)
                                        .font(.system(size: 13, weight: app.page == page ? .semibold : .regular))
                                    Spacer()
                                    if page == .today {
                                        let todayBlocks = store.dayBlocks(StudyDate.key())
                                        let remaining = todayBlocks.filter { store.status($0) != .done }.count
                                        if remaining > 0 {
                                            Text("\(remaining)")
                                                .font(.caption2.weight(.semibold).monospacedDigit())
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.studyAccent.opacity(0.14), in: Capsule())
                                                .foregroundStyle(Color.studyAccent)
                                        } else if !todayBlocks.isEmpty {
                                            Image(systemName: "checkmark")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(Color.studyAccent)
                                        }
                                    } else if page == .courses {
                                        let activeCourses = store.courses.filter { !$0.archived && store.nextLesson($0) != nil }.count
                                        if activeCourses > 0 {
                                            Text("\(activeCourses)")
                                                .font(.caption2.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .tag(page)
                                .padding(.vertical, 5)
                            }
                        }
                        .listStyle(.sidebar)
                        .scrollContentBackground(.hidden)

                        Spacer(minLength: 0)

                        VStack(alignment: .leading, spacing: 10) {
                            if app.undoAction != nil {
                                Button {
                                    app.undo()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.uturn.backward")
                                        Text(app.undoLabel)
                                            .lineLimit(1)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(Color.studyAccent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.studyAccent.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                            }
                            Divider()
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.studyAccent)
                                    .frame(width: 6, height: 6)
                                Text("이 Mac에 저장됨")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Button {
                                app.showSettings = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "gearshape")
                                    Text("설정 및 백업")
                                    Spacer()
                                    Text("⌘,")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.tertiary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .font(.callout)
                            .foregroundStyle(Color.graphite)
                        }
                        .padding(14)
                    }
                    .navigationSplitViewColumnWidth(min: 176, ideal: 200, max: 240)
                } detail: {
                    VStack(spacing: 0) {
                        if let notice = app.notice {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.studyAccent)
                                Text(notice)
                                    .font(.callout)
                                    .foregroundStyle(Color.graphite)
                                Spacer()
                                if app.undoAction != nil {
                                    Button("실행 취소") { app.undo(); app.notice = nil }
                                        .buttonStyle(.borderless)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.studyAccent)
                                }
                                Button {
                                    app.notice = nil
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.surfaceSubtle)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Color.cardBorder).frame(height: 1)
                            }
                        }
                        Group {
                            switch app.page {
                            case .today: TodayView(app: app, store: store)
                            case .courses: CoursesView(app: app, store: store)
                            case .plan: PlanView(app: app, store: store)
                            case .history: HistoryView(app: app, store: store)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .background(Color.canvas)
                    .toolbar {
                        ToolbarItemGroup(placement: .primaryAction) {
                            Button {
                                app.showNewCourse = true
                            } label: {
                                Label("강좌 등록", systemImage: "plus.rectangle.on.rectangle")
                            }
                            .help("강좌 등록 (⇧⌘N)")

                            Button {
                                app.showNewBlock = true
                            } label: {
                                Label("학습 추가", systemImage: "plus")
                            }
                            .help("학습 추가 (⌘N)")
                        }
                    }
                }
                .sheet(isPresented: $app.showNewBlock) { BlockEditor(app: app, store: store, day: app.selectedDay) }
                .sheet(isPresented: $app.showNewCourse) { CourseEditor(app: app, store: store) }
                .sheet(isPresented: $app.showSettings) { SettingsView(app: app) }
                .onAppear { app.prepareDay(StudyDate.key()); app.writeVerificationReport() }
                .onChange(of: app.page) { _, page in if page == .today { app.selectedDay = StudyDate.key() } }
                .onChange(of: app.selectedDay) { _, day in app.prepareDay(day) }
            } else {
                VStack(spacing: 18) {
                    Image(systemName: "externaldrive.badge.exclamationmark").font(.system(size: 42)).foregroundStyle(.secondary)
                    Text("학습 데이터를 열지 못했습니다").font(.title2.bold()).foregroundStyle(Color.graphite)
                    Text(app.startupError ?? "알 수 없는 오류").foregroundStyle(.secondary).textSelection(.enabled)
                    Button("다시 시도") { app.openStore() }.buttonStyle(.borderedProminent)
                    Text("기존 데이터 파일은 그대로 보관되어 있습니다.").font(.caption).foregroundStyle(.secondary)
                }.padding(40).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.canvas)
            }
        }
        .alert("저장 오류", isPresented: Binding(get: { app.error != nil }, set: { if !$0 { app.error = nil } })) { Button("확인", role: .cancel) { app.error = nil } } message: { Text(app.error ?? "") }
        .onReceive(timer) { _ in refreshDate() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refreshDate() } }
    }
    private func refreshDate() {
        let new = StudyDate.key()
        if today != new { if app.selectedDay == today { app.selectedDay = new }; today = new }
        app.prepareDay(new)
    }
}

// MARK: - Shared Index & Graphite Components

struct PageHeader: View {
    let eyebrow: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(eyebrow)
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.graphite)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EmptyCard: View {
    let symbol: String, title: String, detail: String, action: String
    let onAction: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.studyAccent)
                .padding(.bottom, 2)
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.graphite)
            if !detail.isEmpty {
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button(action, action: onAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .padding(.horizontal, 24)
        .background(Color.card, in: RoundedRectangle(cornerRadius: IndexTokens.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: IndexTokens.cardRadius).stroke(Color.cardBorder, lineWidth: 1))
    }
}

struct SubjectTag: View {
    let subject: String
    var body: some View {
        let tint = Color.subject(subject)
        HStack(spacing: 4) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
            Text(subject)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(tint)
        .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: IndexTokens.tagRadius))
        .overlay(
            RoundedRectangle(cornerRadius: IndexTokens.tagRadius)
                .stroke(tint.opacity(0.20), lineWidth: 0.75)
        )
    }
}

struct SectionLabel: View {
    let title: String, count: Int
    var trailing: String? = nil
    var body: some View {
        HStack(spacing: 7) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.graphite)
            Text("\(count)")
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1.5)
                .background(Color.surfaceSubtle, in: Capsule())
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 12.5).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
    }
}

struct IndexProgressBar: View {
    let value: Double
    let total: Double
    var tint: Color = .studyAccent
    var height: CGFloat = 6
    var body: some View {
        GeometryReader { geo in
            let ratio = total > 0 ? min(1, max(0, value / total)) : 0
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.surfaceSubtle)
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(tint)
                    .frame(width: max(ratio > 0 ? height : 0, geo.size.width * ratio))
            }
        }
        .frame(height: height)
    }
}

struct SnapshotShellView: View {
    @Bindable var app: AppState
    let store: StudyStore
    let page: Page

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    Circle().fill(Color(red: 0.96, green: 0.37, blue: 0.34)).frame(width: 12, height: 12)
                    Circle().fill(Color(red: 0.98, green: 0.74, blue: 0.18)).frame(width: 12, height: 12)
                    Circle().fill(Color(red: 0.16, green: 0.78, blue: 0.25)).frame(width: 12, height: 12)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)

                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.studyAccent)
                            .frame(width: 26, height: 26)
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("공부 블록")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.graphite)
                        Text("학습량 · 진도 플래너")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)

                VStack(spacing: 4) {
                    ForEach(Page.allCases) { item in
                        let selected = item == page
                        HStack(spacing: 8) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                                .foregroundStyle(selected ? Color.studyAccent : .secondary)
                                .frame(width: 18)
                            Text(item.rawValue)
                                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                                .foregroundStyle(selected ? Color.graphite : .secondary)
                            Spacer()
                            if item == .today {
                                let remaining = store.dayBlocks(StudyDate.key()).filter { store.status($0) != .done }.count
                                if remaining > 0 {
                                    Text("\(remaining)")
                                        .font(.caption2.weight(.semibold).monospacedDigit())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.studyAccent.opacity(0.14), in: Capsule())
                                        .foregroundStyle(Color.studyAccent)
                                }
                            } else if item == .courses {
                                let activeCourses = store.courses.filter { !$0.archived && store.nextLesson($0) != nil }.count
                                if activeCourses > 0 {
                                    Text("\(activeCourses)")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(selected ? Color.studyAccent.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(.horizontal, 10)

                Spacer()

                VStack(alignment: .leading, spacing: 10) {
                    Divider()
                    HStack(spacing: 6) {
                        Circle().fill(Color.studyAccent).frame(width: 6, height: 6)
                        Text("이 Mac에 저장됨").font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape")
                        Text("설정 및 백업")
                        Spacer()
                        Text("⌘,").font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
                    }
                    .font(.callout)
                    .foregroundStyle(Color.graphite)
                }
                .padding(14)
            }
            .frame(width: 205)
            .background(Color.surfaceSubtle.opacity(0.65))

            Rectangle().fill(Color.cardBorder).frame(width: 1)

            // Main Detail Content + Toolbar Header
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text(page.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.graphite)
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "plus.rectangle.on.rectangle")
                        Text("강좌 등록")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.card, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.cardBorder, lineWidth: 1))
                    .foregroundStyle(Color.graphite)

                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                        Text("학습 추가")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.card, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.cardBorder, lineWidth: 1))
                    .foregroundStyle(Color.graphite)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.canvas)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.cardBorder).frame(height: 1) }

                Group {
                    switch page {
                    case .today: TodayView(app: app, store: store)
                    case .courses: CoursesView(app: app, store: store)
                    case .plan: PlanView(app: app, store: store)
                    case .history: HistoryView(app: app, store: store)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .background(Color.canvas)
        }
        .background(Color.canvas)
    }
}
