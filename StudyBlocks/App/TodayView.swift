import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct TodayView: View {
    @Bindable var app: AppState
    let store: StudyStore
    @State private var showCompleted = true
    @State private var showOverdue = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let blocks = store.dayBlocks(app.selectedDay)
        let done = blocks.filter { store.status($0) == .done }
        let pending = blocks.filter { store.status($0) != .done }
        let overdue = store.blocks.filter { !$0.archived && $0.day < StudyDate.key() && store.status($0) != .done }

        IndexScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .bottom, spacing: 16) {
                    PageHeader(
                        eyebrow: StudyDate.label(app.selectedDay, format: "yyyy년 M월 d일 EEEE"),
                        title: app.selectedDay == StudyDate.key() ? "오늘의 학습" : "하루의 학습"
                    )
                    DayPicker(day: $app.selectedDay)
                }

                TodayStatusStrip(blocks: blocks, done: done, pending: pending)

                QuickAddBar(app: app, store: store, day: app.selectedDay)

                if !overdue.isEmpty && app.selectedDay == StudyDate.key() {
                    IndexDisclosure(isExpanded: $showOverdue) {
                        VStack(spacing: 6) {
                            ForEach(overdue.sorted { $0.day < $1.day }) { b in
                                HStack(spacing: 10) {
                                    SubjectTag(subject: b.subject)
                                    Text(b.title)
                                        .font(.callout)
                                        .foregroundStyle(Color.graphite)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(StudyDate.label(b.day, format: "M/d"))
                                        .font(.system(size: 12.5).monospacedDigit())
                                        .foregroundStyle(.secondary)
                                    Button("오늘로") {
                                        app.move(b, to: StudyDate.key())
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        HStack(spacing: 8) {
                            Label("이전 날짜의 미완료 학습 \(overdue.count)개", systemImage: "tray.full")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(Color.graphite)
                            Spacer()
                            Button("모두 오늘로 이월") {
                                app.perform {
                                    let count = try store.rollover(to: StudyDate.key())
                                    if count > 0 { app.notice = "미완료 학습 \(count)개를 오늘로 옮겼습니다." }
                                }
                            }
                            .buttonStyle(.borderless)
                            .font(.system(size: 12.5).weight(.semibold))
                            .foregroundStyle(Color.studyAccent)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.surfaceSubtle, in: RoundedRectangle(cornerRadius: IndexTokens.compactRadius))
                    .overlay(RoundedRectangle(cornerRadius: IndexTokens.compactRadius).stroke(Color.cardBorder, lineWidth: 1))
                }

                if blocks.isEmpty {
                    EmptyCard(
                        symbol: "square.stack.3d.up",
                        title: "할 공부를 하나씩 꺼내 놓으세요",
                        detail: "위 빠른 추가 바에서 바로 입력하거나, 상세 학습 블록을 추가할 수 있습니다.",
                        action: "상세 학습 추가 (⌘N)"
                    ) {
                        app.showNewBlock = true
                    }
                    if store.courses.filter({ !$0.archived }).isEmpty {
                        Button {
                            app.showNewCourse = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "play.rectangle")
                                Text("인강을 듣고 있다면 강좌부터 등록하세요 (⇧⌘N)")
                            }
                            .font(.callout.weight(.medium))
                            .foregroundStyle(Color.studyAccent)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 4)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        if !pending.isEmpty {
                            SectionLabel(
                                title: "할 학습",
                                count: pending.count,
                                trailing: pending.filter(\.isCore).count > 0 ? "핵심 \(pending.filter(\.isCore).count)개" : nil
                            )
                            ForEach(pending) { b in
                                BlockCard(app: app, store: store, block: b)
                            }
                        }

                        if !done.isEmpty {
                            IndexDisclosure(isExpanded: $showCompleted) {
                                VStack(spacing: 12) {
                                    ForEach(done) { b in
                                        BlockCard(app: app, store: store, block: b)
                                    }
                                }
                                .padding(.top, 8)
                            } label: {
                                SectionLabel(title: "완료한 학습", count: done.count)
                            }
                            .padding(.top, pending.isEmpty ? 0 : 8)
                        }
                    }
                }
                Spacer(minLength: 16)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: IndexTokens.pageMaxWidth)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: blocks.map { store.status($0).rawValue })
        .navigationTitle("오늘")
    }
}

// MARK: - Compact Top Status Bar

struct TodayStatusStrip: View {
    let blocks: [StudyBlock]
    let done: [StudyBlock]
    let pending: [StudyBlock]

    var body: some View {
        let total = blocks.count
        let doneCount = done.count
        let corePending = pending.filter(\.isCore).count
        let pct = total == 0 ? 0 : Int(round(Double(doneCount) / Double(total) * 100))
        let lectureBlocks = blocks.filter { $0.kind == .lecture }
        let lectureDone = done.filter { $0.kind == .lecture }.count

        let progress = HStack(spacing: 10) {
            Text("진도").font(.system(size: 12.5)).foregroundStyle(.secondary)
            Text("\(doneCount) / \(total)")
                .font(.system(size: 16, weight: .semibold).monospacedDigit())
                .foregroundStyle(Color.graphite)
            IndexProgressBar(value: Double(doneCount), total: Double(max(1, total)), tint: .studyAccent, height: 6)
                .frame(width: 96)
            Text(total == 0 ? "—" : "\(pct)%")
                .font(.system(size: 12.5, weight: .medium).monospacedDigit())
                .foregroundStyle(doneCount == total && total > 0 ? Color.studyAccent : .secondary)
        }
        let core = HStack(spacing: 6) {
            Text("남은 핵심").font(.system(size: 12.5)).foregroundStyle(.secondary)
            Text("\(corePending)개")
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(corePending > 0 ? Color.graphite : .secondary)
        }
        let lecture = Label("인강 \(lectureDone)/\(lectureBlocks.count)강", systemImage: "play.rectangle")
            .font(.system(size: 12.5).monospacedDigit())
            .foregroundStyle(.secondary)
        let remaining = Group {
            if total > 0 && pending.isEmpty {
                Label("오늘 계획 완료", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.studyAccent)
            } else if pending.count > 0 {
                Text("남은 학습 \(pending.count)개")
                    .font(.system(size: 12.5).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                progress
                Divider().frame(height: 14)
                core
                if !lectureBlocks.isEmpty {
                    Divider().frame(height: 14)
                    lecture
                }
                Spacer(minLength: 0)
                remaining
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack { progress; Spacer(); core }
                HStack {
                    if !lectureBlocks.isEmpty { lecture }
                    Spacer()
                    remaining
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(Color.card, in: RoundedRectangle(cornerRadius: IndexTokens.compactRadius))
        .overlay(RoundedRectangle(cornerRadius: IndexTokens.compactRadius).stroke(Color.cardBorder, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("완료한 학습 \(doneCount)/\(total), 남은 핵심 학습 \(corePending)개")
    }
}

// MARK: - Inline Quick Add Bar (Section 6)

struct QuickAddBar: View {
    @Bindable var app: AppState
    let store: StudyStore
    let day: String

    @Environment(\.isSnapshotCapture) private var isSnapshotCapture
    @State private var kind: BlockKind = .study
    @State private var subject: String = "수학"
    @State private var title: String = ""
    @State private var quantity: Int = 10
    @State private var unit: String = "문항"
    @State private var isCore: Bool = true
    @State private var courseID: UUID?
    @State private var lesson: Int?

    var body: some View {
        let activeCourses = store.courses.filter { !$0.archived }

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    ForEach(BlockKind.allCases) { k in
                        Button {
                            selectKind(k)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: k.symbol)
                                    .font(.system(size: 12))
                                Text(k.label)
                                    .font(.system(size: 13, weight: kind == k ? .semibold : .regular))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .foregroundStyle(kind == k ? Color.graphite : .secondary)
                            .background(kind == k ? Color.card : Color.clear, in: RoundedRectangle(cornerRadius: 5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(kind == k ? Color.cardBorderStrong : Color.clear, lineWidth: 0.75)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(Color.surfaceSubtle, in: RoundedRectangle(cornerRadius: 6))

                Button {
                    isCore.toggle()
                } label: {
                    Text(isCore ? "핵심" : "추가")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundStyle(isCore ? Color.studyAccent : .secondary)
                        .background(isCore ? Color.studyAccent.opacity(0.12) : Color.surfaceSubtle, in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help("핵심 / 추가 학습 전환")

                Spacer()

                Button {
                    app.showNewBlock = true
                } label: {
                    HStack(spacing: 3) {
                        Text("상세 입력")
                        Text("⌘N")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if isSnapshotCapture {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        SubjectTag(subject: subject)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.surfaceSubtle, in: RoundedRectangle(cornerRadius: 5))

                    Text("학습 제목 입력 후 Return (예: 미적분Ⅰ 45~60번 풀이)")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.surfaceSubtle.opacity(0.65), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.cardBorder, lineWidth: 1))

                    HStack(spacing: 4) {
                        Text("10문항")
                            .font(.system(size: 12, weight: .medium).monospacedDigit())
                            .foregroundStyle(Color.graphite)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.surfaceSubtle, in: RoundedRectangle(cornerRadius: 5))

                    Text("추가")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .foregroundStyle(.white)
                        .background(Color.studyAccent, in: RoundedRectangle(cornerRadius: 6))
                }
            } else if kind == .lecture {
                HStack(spacing: 10) {
                    if activeCourses.isEmpty {
                        Text("등록된 강좌가 없습니다.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Button("강좌 등록…") {
                            app.showNewCourse = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        Spacer()
                    } else {
                        Picker("강좌", selection: $courseID) {
                            Text("강좌 선택").tag(nil as UUID?)
                            ForEach(activeCourses) { c in
                                let nextText = store.nextUnplanned(c).map { "다음 \($0)강" } ?? "계획 완료"
                                Text("[\(c.subject)] \(c.title) (\(nextText))").tag(Optional(c.id))
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 340)

                        if let c = store.course(courseID) {
                            HStack(spacing: 6) {
                                TextField("강의", value: $lesson, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 58)
                                    .monospacedDigit()
                                Text("강")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                Stepper("", value: Binding(
                                    get: { lesson ?? store.nextUnplanned(c) ?? 1 },
                                    set: { lesson = max(1, min(c.total, $0)) }
                                ), in: 1...max(1, c.total))
                                .labelsHidden()
                                .controlSize(.small)

                                if let next = store.nextUnplanned(c), lesson != next {
                                    Button("다음(\(next)강)") {
                                        lesson = next
                                    }
                                    .buttonStyle(.borderless)
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(Color.studyAccent)
                                }
                            }
                            Text("\(store.completedLessons(c).count)/\(c.total)강 완료")
                                .font(.system(size: 12.5).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)

                        Button("인강 추가") {
                            quickAdd()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .disabled(courseID == nil || lesson == nil)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Picker("과목", selection: $subject) {
                        ForEach(subjects, id: \.self) { Text($0) }
                    }
                    .labelsHidden()
                    .frame(width: 82)

                    TextField(
                        kind == .problems ? "풀 문제 입력 (예: 미적분Ⅰ 45~60번)" :
                        kind == .review ? "복습할 내용 입력 (예: 영어 빈칸 추론 오답)" :
                        "학습 제목 입력 후 Return",
                        text: $title
                    )
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { quickAdd() }

                    HStack(spacing: 4) {
                        TextField("분량", value: $quantity, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 52)
                            .monospacedDigit()
                        Picker("단위", selection: $unit) {
                            ForEach(["문항", "회", "쪽", "단원", "개"], id: \.self) { Text($0) }
                        }
                        .labelsHidden()
                        .frame(width: 68)
                    }

                    Button("추가") {
                        quickAdd()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(12)
        .background(Color.card, in: RoundedRectangle(cornerRadius: IndexTokens.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: IndexTokens.cardRadius).stroke(Color.cardBorder, lineWidth: 1))
        .onAppear { syncLectureSelection() }
        .onChange(of: courseID) { _, id in
            if let c = store.course(id) { lesson = store.nextUnplanned(c) }
        }
        .onChange(of: store.blocks.count) { _, _ in
            if kind == .lecture, let c = store.course(courseID) { lesson = store.nextUnplanned(c) }
        }
    }

    private func selectKind(_ newKind: BlockKind) {
        kind = newKind
        switch newKind {
        case .lecture:
            unit = "강"
            syncLectureSelection()
        case .problems:
            unit = "문항"
            if quantity == 1 { quantity = 10 }
        case .review, .study:
            unit = "회"
            quantity = 1
        }
    }

    private func syncLectureSelection() {
        if courseID == nil || store.course(courseID) == nil {
            if let c = store.courses.first(where: { !$0.archived && store.nextUnplanned($0) != nil }) ?? store.courses.first(where: { !$0.archived }) {
                courseID = c.id
                lesson = store.nextUnplanned(c)
            }
        } else if let c = store.course(courseID), lesson == nil {
            lesson = store.nextUnplanned(c)
        }
    }

    private func quickAdd() {
        var draft = BlockDraft()
        draft.day = day
        draft.kind = kind
        draft.isCore = isCore
        if kind == .lecture {
            guard let cid = courseID, let l = lesson else { return }
            draft.courseID = cid
            draft.lesson = l
            app.perform {
                try store.addBlock(draft)
                if let c = store.course(cid) {
                    lesson = store.nextUnplanned(c)
                }
            }
        } else {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            draft.title = trimmed
            draft.subject = subject
            draft.quantity = max(1, quantity)
            draft.unit = unit
            app.perform {
                try store.addBlock(draft)
                title = ""
            }
        }
    }
}

// MARK: - Metric & DayPicker

struct Metric: View {
    let value: String, label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .semibold).monospacedDigit())
                .foregroundStyle(Color.graphite)
            Text(label)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
        }
    }
}

struct DayPicker: View {
    @Binding var day: String
    @Environment(\.isSnapshotCapture) private var isSnapshotCapture
    var body: some View {
        HStack(spacing: 6) {
            if day != StudyDate.key() {
                Button {
                    day = StudyDate.key()
                } label: {
                    Text("오늘")
                        .font(.system(size: 12.5, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .foregroundStyle(Color.graphite)
                        .background(Color.card, in: RoundedRectangle(cornerRadius: IndexTokens.compactRadius))
                        .overlay(RoundedRectangle(cornerRadius: IndexTokens.compactRadius).stroke(Color.cardBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("오늘로 이동 (⌘T)")
            }
            HStack(spacing: 6) {
                Button {
                    day = StudyDate.adding(day, days: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("이전 날짜")

                if isSnapshotCapture {
                    Text(StudyDate.label(day, format: "yyyy. MM. dd."))
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundStyle(Color.graphite)
                        .padding(.horizontal, 6)
                } else {
                    DatePicker("날짜", selection: Binding(get: { StudyDate.date(day) }, set: { day = StudyDate.key($0) }), displayedComponents: .date)
                        .labelsHidden()
                        .environment(\.timeZone, StudyDate.calendar.timeZone)
                        .frame(width: 108)
                }

                Button {
                    day = StudyDate.adding(day, days: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("다음 날짜")
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.card, in: RoundedRectangle(cornerRadius: IndexTokens.compactRadius))
            .overlay(RoundedRectangle(cornerRadius: IndexTokens.compactRadius).stroke(Color.cardBorder, lineWidth: 1))
        }
    }
}

// MARK: - Study Block Card (Index & Graphite Core Component)

struct BlockCard: View {
    @Bindable var app: AppState
    let store: StudyStore
    let block: StudyBlock
    @State private var editing = false
    @State private var isTargeted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isSnapshotCapture) private var isSnapshotCapture

    var body: some View {
        let status = store.status(block)
        let done = status == .done
        let active = status == .active
        let course = store.course(block.courseID)
        let courseURL = store.courseURL(for: block)

        HStack(spacing: 12) {
            // Left Subject Index Bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.subject(block.subject).opacity(done ? 0.55 : 0.95))
                .frame(width: block.isCore ? 5 : 3)
                .padding(.vertical, 10)

            // Completion Button
            Button {
                if reduceMotion {
                    app.toggle(block)
                } else {
                    withAnimation(.easeInOut(duration: 0.18)) { app.toggle(block) }
                }
            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : (active ? "play.circle.fill" : "circle"))
                    .font(.system(size: 25, weight: done ? .regular : .light))
                    .frame(width: 30, height: 36)
                    .foregroundStyle(done || active ? Color.studyAccent : Color.secondary.opacity(0.55))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .help(done ? "완료 취소" : "학습 완료")
            .accessibilityLabel(done ? "\(block.title) 완료 취소" : "\(block.title) 완료")

            // Primary & Secondary Information Hierarchy
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    SubjectTag(subject: block.subject)
                        .fixedSize()

                    if block.isCore {
                        Text("핵심")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .foregroundStyle(Color.subject(block.subject))
                            .background(Color.subject(block.subject).opacity(done ? 0.08 : 0.14), in: RoundedRectangle(cornerRadius: 3))
                            .fixedSize()
                    } else if !block.isCore {
                        Text("추가")
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .foregroundStyle(.secondary)
                            .background(Color.surfaceSubtle.opacity(0.7), in: RoundedRectangle(cornerRadius: 3))
                            .fixedSize()
                    }

                    if active {
                        Text("진행 중")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .foregroundStyle(Color.studyAccent)
                            .background(Color.studyAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
                            .fixedSize()
                    }

                    if block.recurrenceID != nil {
                        Image(systemName: "repeat")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .help("반복 복습")
                    }
                }

                Button {
                    editing = true
                } label: {
                    Text(block.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(done ? Color.graphite.opacity(0.78) : Color.graphite)
                        .strikethrough(done, color: .secondary.opacity(0.45))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .layoutPriority(1)

                if !block.details.isEmpty {
                    Text(block.details)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                let metadata = Text(buildMetadata(course: course, done: done))
                    .font(.system(size: 12.5).monospacedDigit())
                    .foregroundStyle(.secondary)
                let actions = HStack(spacing: 8) {
                    if block.kind == .lecture {
                        if let lesson = block.lesson {
                            Text("\(lesson)강")
                                .font(.system(size: 12.5, weight: .medium).monospacedDigit())
                                .foregroundStyle(done ? .secondary : Color.graphite)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 5)
                                .background(Color.surfaceSubtle, in: RoundedRectangle(cornerRadius: 4))
                        }
                        if let url = courseURL {
                            Link(destination: url) {
                                HStack(spacing: 3) {
                                    Text("강좌 열기")
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 9, weight: .semibold))
                                }
                                .font(.system(size: 12.5, weight: .medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .foregroundStyle(Color.studyAccent)
                                .background(Color.studyAccent.opacity(0.11), in: RoundedRectangle(cornerRadius: 5))
                            }
                            .buttonStyle(.plain)
                            .help("외부 인강 플랫폼에서 강좌 열기")
                        }
                    } else {
                        Text("\(block.quantity)\(block.unit)")
                            .font(.system(size: 12.5, weight: .medium).monospacedDigit())
                            .foregroundStyle(done ? .secondary : Color.graphite)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.surfaceSubtle, in: RoundedRectangle(cornerRadius: 4))
                    }

                    if !done {
                        Button {
                            app.move(block, to: StudyDate.adding(block.day, days: 1))
                        } label: {
                            Image(systemName: "arrow.turn.up.right")
                                .font(.system(size: 12))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("다음 날로 미루기")
                    }

                    if isSnapshotCapture {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 24)
                    } else {
                        Menu {
                            cardMenuItems(done: done, active: active, course: course, courseURL: courseURL)
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 12))
                                .frame(width: 22, height: 24)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .help("학습 메뉴")
                    }

                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .help("드래그하여 순서 변경")
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        metadata.lineLimit(1)
                        Spacer(minLength: 8)
                        actions.fixedSize()
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        metadata.lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        actions
                    }
                }
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.trailing, 14)
        .padding(.leading, 0)
        .frame(minHeight: 104)
        .background {
            RoundedRectangle(cornerRadius: IndexTokens.cardRadius)
                .fill(done ? Color.cardMuted : Color.card)
                .overlay {
                    RoundedRectangle(cornerRadius: IndexTokens.cardRadius)
                        .fill(Color.subject(block.subject).opacity(done ? 0.045 : (block.isCore ? 0.10 : 0.045)))
                }
        }
        .overlay(
            RoundedRectangle(cornerRadius: IndexTokens.cardRadius)
                .stroke(
                    isTargeted ? Color.studyAccent : Color.subject(block.subject).opacity(active ? 0.65 : (done ? 0.18 : (block.isCore ? 0.32 : 0.20))),
                    lineWidth: isTargeted ? 2 : 1
                )
        )
        .contextMenu {
            cardMenuItems(done: done, active: active, course: course, courseURL: courseURL)
        }
        .modifier(BlockDragModifier(enabled: !isSnapshotCapture, idString: block.id.uuidString, isTargeted: $isTargeted) { sourceID in
            app.perform { try store.reorder(sourceID, before: block.id, day: block.day) }
        })
        .sheet(isPresented: $editing) {
            BlockEditor(app: app, store: store, day: block.day, block: block)
        }
    }

    private func buildMetadata(course: Course?, done: Bool) -> String {
        if block.kind == .lecture, let course {
            let progress = "\(store.completedLessons(course).count)/\(course.total)강"
            if done {
                if let next = store.nextLesson(course) {
                    return "인강 · \(progress) (다음 \(next)강)"
                } else {
                    return "인강 · \(progress) (완강)"
                }
            }
            let info = [course.teacher, course.platform].filter { !$0.isEmpty }.joined(separator: " · ")
            return info.isEmpty ? "인강 · 진도 \(progress)" : "인강 · \(info) · \(progress)"
        }
        return block.kind.label
    }

    @ViewBuilder
    private func cardMenuItems(done: Bool, active: Bool, course: Course?, courseURL: URL?) -> some View {
        Button("세부 사항 수정") { editing = true }
        Button(done ? "완료 취소" : "완료") { app.toggle(block) }
        if !done {
            Button(active ? "대기로 변경" : "진행 중으로 변경") {
                app.perform { try store.setStatus(block, active ? .pending : .active) }
            }
            Button("다음 날로 미루기") {
                app.move(block, to: StudyDate.adding(block.day, days: 1))
            }
        }
        if let url = courseURL {
            Divider()
            Button("강좌 바로가기 열기 ↗") {
                NSWorkspace.shared.open(url)
            }
        }
        if let course, let next = store.nextUnplanned(course) {
            Button("다음 강의(\(next)강) 오늘에 추가") {
                var draft = BlockDraft()
                draft.kind = .lecture
                draft.courseID = course.id
                draft.lesson = next
                draft.day = StudyDate.key()
                app.perform {
                    try store.addBlock(draft)
                    app.notice = "\(course.title) · \(next)강을 오늘 학습에 추가했습니다."
                }
            }
        }
        Divider()
        Button("위로 이동") { moveUp() }
        Button("아래로 이동") { moveDown() }
        Button("보관") { app.perform { try store.archive(block) } }
    }

    private func moveUp() {
        let list = store.dayBlocks(block.day)
        if let index = list.firstIndex(where: { $0.id == block.id }), index > 0 {
            app.perform { try store.reorder(block.id, before: list[index - 1].id, day: block.day) }
        }
    }

    private func moveDown() {
        let list = store.dayBlocks(block.day)
        if let index = list.firstIndex(where: { $0.id == block.id }), index + 1 < list.count {
            app.perform { try store.reorder(list[index + 1].id, before: block.id, day: block.day) }
        }
    }
}

private struct BlockDragModifier: ViewModifier {
    let enabled: Bool
    let idString: String
    @Binding var isTargeted: Bool
    let onDropID: (UUID) -> Void

    func body(content: Content) -> some View {
        if enabled {
            content
                .draggable(idString)
                .dropDestination(for: String.self) { items, _ in
                    guard let id = items.first.flatMap(UUID.init(uuidString:)) else { return false }
                    onDropID(id)
                    return true
                } isTargeted: { isTargeted = $0 }
        } else {
            content
        }
    }
}
