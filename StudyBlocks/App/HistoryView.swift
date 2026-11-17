import SwiftUI

struct HistoryView: View {
    @Bindable var app: AppState
    let store: StudyStore
    @State private var showArchived = false
    var body: some View {
        let day = app.selectedDay
        let lectures = store.completions.filter { !$0.isInitial && StudyDate.key($0.completedAt) == day }.sorted { $0.completedAt < $1.completedAt }
        let general = store.blocks.filter { $0.kind != .lecture && store.status($0) == .done && $0.completedAt.map { StudyDate.key($0) == day } == true }
        let pending = store.dayBlocks(day).filter { store.status($0) != .done }
        let events = store.events.filter { StudyDate.key($0.timestamp) == day }
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .bottom) { PageHeader(eyebrow: StudyDate.label(day, format: "yyyy년 M월 d일 EEEE"), title: "학습 기록"); DayPicker(day: $app.selectedDay) }
                HStack(spacing: 40) {
                    Metric(value: "\(lectures.count)", label: "수강한 강의")
                    Metric(value: "\(general.filter { $0.kind == .problems }.reduce(0) { $0 + ($1.unit == "문항" ? $1.quantity : 0) })", label: "풀이한 문항")
                    Metric(value: "\(general.filter { $0.kind == .review }.count)", label: "복습한 학습")
                    Spacer()
                }.padding(24).background(Color.card, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(title: "완료한 학습", count: lectures.count + general.count)
                    if lectures.isEmpty && general.isEmpty { Text("이 날 완료한 학습이 없습니다.").font(.callout).foregroundStyle(.secondary).padding(.vertical, 16) }
                    ForEach(lectures) { c in
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.studyAccent)
                            SubjectTag(subject: store.course(c.courseID)?.subject ?? "기타")
                            Text("\(store.course(c.courseID)?.title ?? "강좌") · \(c.lesson)강").font(.callout)
                            Spacer()
                            Button("완료 취소") { if let course = store.course(c.courseID) { app.perform { try store.setLesson(course, lesson: c.lesson, done: false) } } }.buttonStyle(.borderless).font(.caption)
                        }.padding(16).background(Color.card, in: RoundedRectangle(cornerRadius: 8))
                    }
                    ForEach(general) { b in BlockCard(app: app, store: store, block: b) }
                }
                let weekGoals = store.goals.filter { $0.week == StudyDate.week(day) }
                if !weekGoals.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("이 주의 목표").font(.headline)
                        ForEach(weekGoals) { g in HStack { SubjectTag(subject: g.subject); Text(store.course(g.courseID)?.title ?? g.kind.label); Spacer(); Text("\(store.achieved(g)) / \(g.target)\(g.unit)").monospacedDigit().foregroundStyle(.secondary) }.font(.callout) }
                    }.padding(20).background(Color.card, in: RoundedRectangle(cornerRadius: 10))
                }
                if !pending.isEmpty { DisclosureGroup("미완료 학습 \(pending.count)개") { VStack(spacing: 8) { ForEach(pending) { b in BlockCard(app: app, store: store, block: b) } }.padding(.top, 12) } }
                if !events.isEmpty {
                    DisclosureGroup("변경 및 이월 내역 \(events.count)개") {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(events) { event in
                                HStack(alignment: .top, spacing: 12) {
                                    Circle().fill(.secondary.opacity(0.4)).frame(width: 5, height: 5).padding(.top, 6)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(event.title).font(.callout)
                                        Text(event.action + (event.fromDay.map { " · \($0) → \(event.toDay ?? "")" } ?? "")).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                        }.padding(.top, 16)
                    }
                }
                Divider()
                DisclosureGroup("보관한 학습", isExpanded: $showArchived) {
                    VStack(spacing: 8) {
                        ForEach(store.blocks.filter(\.archived)) { b in
                            HStack { Text(b.title).font(.callout); Spacer(); Text(StudyDate.label(b.day, format: "M/d")).font(.caption).foregroundStyle(.secondary); Button("보관 해제") { app.perform { try store.archive(b) } } }.padding(12).background(Color.card, in: RoundedRectangle(cornerRadius: 6))
                        }
                    }.padding(.top, 12)
                }.foregroundStyle(.secondary)
            }.padding(32).frame(maxWidth: 1080)
        }.navigationTitle("기록")
    }
}

struct SettingsView: View {
    @Bindable var app: AppState
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("automaticRollover") private var automaticRollover = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text("설정 및 백업").font(.title2.bold()); Spacer(); Button("완료") { dismiss() }.keyboardShortcut(.cancelAction) }.padding(24)
            Form {
                Section("일반") {
                    Picker("화면 모드", selection: $appearance) { Text("시스템 설정").tag("system"); Text("라이트").tag("light"); Text("다크").tag("dark") }
                    Toggle("미완료 학습 자동 이월", isOn: $automaticRollover)
                    Text("오늘의 미완료 학습이 12개가 될 때까지만 옮깁니다. 남은 학습은 이전 날짜에서 직접 옮길 수 있어요.").font(.caption).foregroundStyle(.secondary)
                    LabeledContent("날짜 기준", value: "한국 표준시 (Asia/Seoul)")
                }
                Section("이 Mac의 데이터") {
                    HStack { Button("JSON 백업 내보내기…") { app.exportBackup() }; Button("JSON 백업 가져오기…") { app.importBackup() } }
                    Button("데이터 폴더 열기") { NSWorkspace.shared.open(URL.applicationSupportDirectory.appendingPathComponent(StudyStore.bundleID)) }
                    Text("강좌, 진도, 계획과 기록을 백업합니다. 복원 전 데이터는 Backups 폴더에 보관됩니다.").font(.caption).foregroundStyle(.secondary)
                }
                Section("키보드 단축키") {
                    LabeledContent("학습 추가", value: "⌘N")
                    LabeledContent("강좌 등록", value: "⇧⌘N")
                    LabeledContent("화면 이동", value: "⌘1 · ⌘2 · ⌘3 · ⌘4")
                    LabeledContent("오늘로 이동", value: "⌘T")
                    LabeledContent("마지막 블록 완료·이월 취소", value: "⌘Z")
                }
                Text("공부 블록 1.0.0 · macOS 네이티브").font(.caption).foregroundStyle(.tertiary)
            }.formStyle(.grouped)
        }.frame(width: 580, height: 650)
        .onChange(of: automaticRollover) { _, enabled in if enabled { app.prepareDay(StudyDate.key()) } }
    }
}
