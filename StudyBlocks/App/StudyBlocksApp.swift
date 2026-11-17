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
        guard let index = args.firstIndex(of: "--verification-report"), args.indices.contains(index + 1) else { return }
        DispatchQueue.main.async {
            let windows = NSApp.windows.map { window -> [String: Any] in
                ["title": window.title, "visible": window.isVisible, "miniaturized": window.isMiniaturized,
                 "frame": NSStringFromRect(window.frame)]
            }
            let report: [String: Any] = [
                "bundleID": Bundle.main.bundleIdentifier ?? "", "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "",
                "rendered": true, "startupError": self.startupError ?? "", "windows": windows,
                "courses": self.store?.courses.map { course -> [String: Any] in
                    ["id": course.id.uuidString, "title": course.title, "completed": self.store!.completedLessons(course).count,
                     "total": course.total, "next": self.store!.nextLesson(course) ?? 0]
                } ?? [],
                "blocks": self.store?.blocks.count ?? 0, "completedBlocks": self.store?.blocks.filter { self.store!.status($0) == .done }.count ?? 0,
                "goals": self.store?.goals.map { ["target": $0.target, "achieved": self.store!.achieved($0)] } ?? []
            ]
            do {
                let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                try data.write(to: URL(fileURLWithPath: args[index + 1]), options: .atomic)
            } catch { NSLog("Launch verification report: %@", error.localizedDescription) }
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
    var symbol: String { switch self { case .today: "square.grid.2x2"; case .courses: "play.rectangle.on.rectangle"; case .plan: "calendar"; case .history: "clock.arrow.circlepath" } }
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

extension Color {
    static let studyAccent = Color(red: 0.18, green: 0.46, blue: 0.37)
    static let card = Color(nsColor: .controlBackgroundColor)
    static let canvas = Color(nsColor: .textBackgroundColor)
    static func subject(_ subject: String) -> Color {
        switch subject { case "수학": Color(red: 0.30, green: 0.46, blue: 0.70); case "국어": Color(red: 0.69, green: 0.42, blue: 0.34); case "영어": Color(red: 0.54, green: 0.44, blue: 0.68); case "과학": Color(red: 0.27, green: 0.54, blue: 0.46); case "사회": Color(red: 0.65, green: 0.52, blue: 0.26); default: .secondary }
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
                    VStack(alignment: .leading, spacing: 24) {
                        Label("공부 블록", systemImage: "square.stack.3d.up.fill").font(.system(size: 19, weight: .bold)).padding(.horizontal, 12).padding(.top, 18)
                        List(selection: Binding<Page?>(get: { app.page }, set: { if let v = $0 { app.page = v } })) {
                            ForEach(Page.allCases) { page in
                                HStack {
                                    Label(page.rawValue, systemImage: page.symbol)
                                    Spacer()
                                    if page == .today {
                                        Text("\(store.dayBlocks(StudyDate.key()).filter { store.status($0) != .done }.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                    }
                                }.tag(page).padding(.vertical, 6)
                            }
                        }.listStyle(.sidebar).scrollContentBackground(.hidden)
                        Spacer(minLength: 0)
                        VStack(alignment: .leading, spacing: 10) {
                            Label("이 Mac에 저장됨", systemImage: "internaldrive").font(.caption).foregroundStyle(.secondary)
                            Button { app.showSettings = true } label: { Label("설정 및 백업", systemImage: "gearshape") }.buttonStyle(.plain).font(.callout)
                        }.padding(16)
                    }.navigationSplitViewColumnWidth(min: 170, ideal: 195, max: 240)
                } detail: {
                    VStack(spacing: 0) {
                        if let notice = app.notice {
                            HStack { Image(systemName: "checkmark.circle.fill"); Text(notice); Spacer(); Button { app.notice = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain) }.font(.callout).padding(12).background(Color.studyAccent.opacity(0.10))
                        }
                        Group {
                            switch app.page {
                            case .today: TodayView(app: app, store: store)
                            case .courses: CoursesView(app: app, store: store)
                            case .plan: PlanView(app: app, store: store)
                            case .history: HistoryView(app: app, store: store)
                            }
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }.background(Color.canvas)
                    .toolbar {
                        ToolbarItem { Button { app.showNewCourse = true } label: { Label("강좌 등록", systemImage: "plus.rectangle.on.rectangle") }.help("강좌 등록 (⇧⌘N)") }
                        ToolbarItem { Button { app.showNewBlock = true } label: { Label("학습 추가", systemImage: "plus") }.help("학습 추가 (⌘N)").keyboardShortcut("n") }
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
                    Text("학습 데이터를 열지 못했습니다").font(.title2.bold())
                    Text(app.startupError ?? "알 수 없는 오류").foregroundStyle(.secondary).textSelection(.enabled)
                    Button("다시 시도") { app.openStore() }.buttonStyle(.borderedProminent)
                    Text("기존 데이터 파일은 그대로 보관되어 있습니다.").font(.caption).foregroundStyle(.secondary)
                }.padding(40)
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

struct PageHeader: View {
    let eyebrow: String
    let title: String
    var body: some View { VStack(alignment: .leading, spacing: 7) { Text(eyebrow).font(.callout).foregroundStyle(.secondary); Text(title).font(.system(size: 30, weight: .bold)) }.frame(maxWidth: .infinity, alignment: .leading) }
}
struct EmptyCard: View {
    let symbol: String, title: String, detail: String, action: String
    let onAction: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol).font(.system(size: 32, weight: .light)).foregroundStyle(Color.studyAccent).padding(.bottom, 4)
            Text(title).font(.title3.weight(.semibold))
            if !detail.isEmpty { Text(detail).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center) }
            Button(action, action: onAction).buttonStyle(.borderedProminent).controlSize(.large)
        }.frame(maxWidth: .infinity).padding(.vertical, 52).background(Color.card, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(.primary.opacity(0.07)))
    }
}
struct SubjectTag: View {
    let subject: String
    var body: some View { Text(subject).font(.system(size: 11, weight: .semibold)).padding(.horizontal, 7).padding(.vertical, 4).foregroundStyle(Color.subject(subject)).background(Color.subject(subject).opacity(0.1), in: RoundedRectangle(cornerRadius: 4)) }
}
struct SectionLabel: View {
    let title: String, count: Int
    var body: some View { HStack(spacing: 8) { Text(title).font(.headline); Text("\(count)").font(.callout.monospacedDigit()).foregroundStyle(.tertiary); Spacer() }.padding(.top, 8).padding(.bottom, 2) }
}
