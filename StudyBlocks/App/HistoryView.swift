import SwiftUI
import AppKit

struct HistoryView: View {
    @Bindable var app: AppState
    let store: StudyStore
    @State private var showPending = false
    @State private var showEvents = false
    @State private var showArchived = false

    var body: some View {
        let day = app.selectedDay
        let lectures = store.completions
            .filter { !$0.isInitial && StudyDate.key($0.completedAt) == day }
            .sorted { $0.completedAt < $1.completedAt }
        let general = store.blocks
            .filter { $0.kind != .lecture && store.status($0) == .done && $0.completedAt.map { StudyDate.key($0) == day } == true }
            .sorted { ($0.completedAt ?? $0.createdAt) < ($1.completedAt ?? $1.createdAt) }
        let pending = store.dayBlocks(day).filter { store.status($0) != .done }
        let events = store.events.filter { StudyDate.key($0.timestamp) == day }
        let solvedProblems = general.filter { $0.kind == .problems }.reduce(0) { $0 + ($1.unit == "문항" ? $1.quantity : 0) }
        let reviewAndStudyCount = general.filter { $0.kind == .review || $0.kind == .study }.count

        IndexScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .bottom, spacing: 16) {
                    PageHeader(
                        eyebrow: StudyDate.label(day, format: "yyyy년 M월 d일 EEEE"),
                        title: "학습 기록"
                    )
                    DayPicker(day: $app.selectedDay)
                }

                // Compact Daily Achievement Summary Bar
                HStack(spacing: 28) {
                    Metric(value: "\(lectures.count)강", label: "수강한 강의")
                    Divider().frame(height: 30)
                    Metric(value: "\(solvedProblems)문항", label: "풀이한 문항")
                    Divider().frame(height: 30)
                    Metric(value: "\(reviewAndStudyCount)건", label: "복습 · 일반 학습")
                    Spacer()
                    Text("총 완료 \(lectures.count + general.count)건")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.surfaceSubtle, in: Capsule())
                        .foregroundStyle(lectures.count + general.count > 0 ? Color.studyAccent : .secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.card, in: RoundedRectangle(cornerRadius: IndexTokens.cardRadius))
                .overlay(RoundedRectangle(cornerRadius: IndexTokens.cardRadius).stroke(Color.cardBorder, lineWidth: 1))

                // Primary Section: Completed Study Records
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: "완료한 학습 기록", count: lectures.count + general.count)

                    if lectures.isEmpty && general.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.text")
                                .foregroundStyle(.secondary)
                            Text("이 날짜에 완료한 학습 기록이 없습니다.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(18)
                        .background(Color.card, in: RoundedRectangle(cornerRadius: IndexTokens.cardRadius))
                        .overlay(RoundedRectangle(cornerRadius: IndexTokens.cardRadius).stroke(Color.cardBorder, lineWidth: 1))
                    } else {
                        ForEach(lectures) { c in
                            let course = store.course(c.courseID)
                            let subject = course?.subject ?? "기타"
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.subject(subject).opacity(0.8))
                                    .frame(width: 3.5)
                                    .padding(.vertical, 6)

                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.studyAccent)

                                SubjectTag(subject: subject)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(course?.title ?? "강좌") · \(c.lesson)강")
                                        .font(.system(size: 14.5, weight: .medium))
                                        .foregroundStyle(Color.graphite)
                                    Text("인강 수강 완료 · \(Self.timeString(c.completedAt))")
                                        .font(.system(size: 11.5).monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if let url = course?.validURL {
                                    Link(destination: url) {
                                        HStack(spacing: 3) {
                                            Text("강좌 열기")
                                            Image(systemName: "arrow.up.right")
                                                .font(.system(size: 9, weight: .semibold))
                                        }
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }

                                Button {
                                    if let course {
                                        app.perform { try store.setLesson(course, lesson: c.lesson, done: false) }
                                    }
                                } label: {
                                    Text("완료 취소")
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.surfaceSubtle, in: RoundedRectangle(cornerRadius: 5))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.trailing, 14)
                            .padding(.vertical, 6)
                            .background(Color.card, in: RoundedRectangle(cornerRadius: IndexTokens.cardRadius))
                            .overlay(RoundedRectangle(cornerRadius: IndexTokens.cardRadius).stroke(Color.cardBorder, lineWidth: 1))
                        }

                        ForEach(general) { b in
                            BlockCard(app: app, store: store, block: b)
                        }
                    }
                }

                // Weekly Goals Progress Snapshot
                let weekGoals = store.goals.filter { $0.week == StudyDate.week(day) }
                if !weekGoals.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("이 주의 목표 달성 현황")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.graphite)
                        ForEach(weekGoals) { g in
                            let achieved = store.achieved(g)
                            HStack(spacing: 10) {
                                SubjectTag(subject: g.subject)
                                Text(store.course(g.courseID)?.title ?? g.kind.label)
                                    .font(.callout)
                                    .foregroundStyle(Color.graphite)
                                Spacer()
                                IndexProgressBar(
                                    value: Double(min(g.target, achieved)),
                                    total: Double(max(1, g.target)),
                                    tint: achieved >= g.target ? .studyAccent : Color.subject(g.subject),
                                    height: 5
                                )
                                .frame(width: 90)
                                Text("\(achieved) / \(g.target)\(g.unit)")
                                    .font(.callout.monospacedDigit())
                                    .foregroundStyle(achieved >= g.target ? Color.studyAccent : .secondary)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.card, in: RoundedRectangle(cornerRadius: IndexTokens.cardRadius))
                    .overlay(RoundedRectangle(cornerRadius: IndexTokens.cardRadius).stroke(Color.cardBorder, lineWidth: 1))
                }

                // Secondary / Auxiliary Sections (Collapsed by default to keep daily view clean)
                VStack(alignment: .leading, spacing: 10) {
                    if !pending.isEmpty {
                        IndexDisclosure(isExpanded: $showPending) {
                            VStack(spacing: 8) {
                                ForEach(pending) { b in
                                    BlockCard(app: app, store: store, block: b)
                                }
                            }
                            .padding(.top, 10)
                        } label: {
                            HStack(spacing: 6) {
                                Text("이 날의 미완료 학습")
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(Color.graphite)
                                Text("\(pending.count)개")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                        .padding(12)
                        .background(Color.surfaceSubtle.opacity(0.6), in: RoundedRectangle(cornerRadius: IndexTokens.compactRadius))
                    }

                    if !events.isEmpty {
                        IndexDisclosure(isExpanded: $showEvents) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(events) { event in
                                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                                        Text(Self.timeString(event.timestamp))
                                            .font(.caption2.monospacedDigit())
                                            .foregroundStyle(.tertiary)
                                            .frame(width: 38, alignment: .leading)
                                        Text(event.action)
                                            .font(.system(size: 11, weight: .semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.card, in: RoundedRectangle(cornerRadius: 4))
                                            .foregroundStyle(.secondary)
                                        Text(event.title)
                                            .font(.caption)
                                            .foregroundStyle(Color.graphite)
                                            .lineLimit(1)
                                        if let fromDay = event.fromDay {
                                            Text("\(fromDay) → \(event.toDay ?? "")")
                                                .font(.caption2.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                            .padding(.top, 10)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("변경 및 이월 내역")
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(.secondary)
                                Text("\(events.count)건")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.tertiary)
                                Spacer()
                            }
                        }
                        .padding(12)
                        .background(Color.surfaceSubtle.opacity(0.45), in: RoundedRectangle(cornerRadius: IndexTokens.compactRadius))
                    }

                    let archivedBlocks = store.blocks.filter(\.archived)
                    if !archivedBlocks.isEmpty {
                        IndexDisclosure(isExpanded: $showArchived) {
                            VStack(spacing: 6) {
                                ForEach(archivedBlocks) { b in
                                    HStack(spacing: 10) {
                                        SubjectTag(subject: b.subject)
                                        Text(b.title)
                                            .font(.callout)
                                            .foregroundStyle(Color.graphite)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(StudyDate.label(b.day, format: "M/d"))
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                        Button("보관 해제") {
                                            app.perform { try store.archive(b) }
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                    .padding(10)
                                    .background(Color.card, in: RoundedRectangle(cornerRadius: 6))
                                }
                            }
                            .padding(.top, 10)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "archivebox")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("보관한 학습")
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(.secondary)
                                Text("\(archivedBlocks.count)개")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.tertiary)
                                Spacer()
                            }
                        }
                        .padding(12)
                        .background(Color.surfaceSubtle.opacity(0.45), in: RoundedRectangle(cornerRadius: IndexTokens.compactRadius))
                    }
                }
                Spacer(minLength: 16)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: IndexTokens.pageMaxWidth)
        }
        .navigationTitle("기록")
    }

    private static func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.timeZone = StudyDate.calendar.timeZone
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

struct SettingsView: View {
    @Bindable var app: AppState
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("automaticRollover") private var automaticRollover = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("설정 및 백업")
                    .font(.title2.bold())
                    .foregroundStyle(Color.graphite)
                Spacer()
                Button("완료") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(Color.card)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.cardBorder).frame(height: 1) }

            Form {
                Section("화면 및 동작") {
                    Picker("화면 모드", selection: $appearance) {
                        Text("시스템 설정").tag("system")
                        Text("라이트 (Paper)").tag("light")
                        Text("다크 (Graphite)").tag("dark")
                    }
                    Toggle("미완료 학습 자동 이월", isOn: $automaticRollover)
                    Text("자동 이월을 켜면 오늘의 미완료 학습이 12개가 될 때까지만 이전 날짜의 미완료 항목을 옮깁니다. 남은 학습은 오늘 화면에서 직접 선택해 옮길 수 있습니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    LabeledContent("날짜 및 주간 기준", value: "한국 표준시 (Asia/Seoul) · 월요일 시작")
                }

                Section("이 Mac의 데이터 및 백업") {
                    HStack(spacing: 10) {
                        Button("JSON 백업 내보내기…") { app.exportBackup() }
                        Button("JSON 백업 가져오기…") { app.importBackup() }
                    }
                    Button("데이터 저장 폴더 열기") {
                        NSWorkspace.shared.open(URL.applicationSupportDirectory.appendingPathComponent(StudyStore.bundleID))
                    }
                    Text("강좌, 수강 진도, 학습 블록, 주간 목표, 반복 규칙, 변경 기록을 JSON 파일로 백업하거나 복원합니다. 복원 직전 데이터는 Backups 폴더에 자동 보관됩니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("키보드 단축키") {
                    LabeledContent("학습 추가", value: "⌘N")
                    LabeledContent("강좌 등록", value: "⇧⌘N")
                    LabeledContent("화면 이동 (오늘·강좌·계획·기록)", value: "⌘1 ~ ⌘4")
                    LabeledContent("오늘로 이동", value: "⌘T")
                    LabeledContent("마지막 상태·날짜 변경 취소", value: "⌘Z")
                }

                Section("정보 및 라이선스") {
                    LabeledContent("버전", value: "Study Blocks (공부 블록) 1.1 (1.1.0)")
                    LabeledContent("프로젝트", value: "QuadraJ · PastelJ321")
                    LabeledContent("라이선스", value: "MIT License (오픈소스 소프트웨어)")
                    if let repoURL = URL(string: "https://github.com/PastelJ321/Study_Blocks") {
                        Link("GitHub 저장소 열기 ↗", destination: repoURL)
                            .font(.callout)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 580, height: 670)
        .onChange(of: automaticRollover) { _, enabled in
            if enabled { app.prepareDay(StudyDate.key()) }
        }
    }
}
