import SwiftUI

let subjects = ["국어", "수학", "영어", "과학", "사회", "한국사", "기타"]

struct EditorFrame<Content: View>: View {
    let title: String, saveTitle: String
    let save: () -> Void
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text(title).font(.title2.bold()); Spacer(); Button { dismiss() } label: { Image(systemName: "xmark") }.buttonStyle(.plain).keyboardShortcut(.cancelAction) }.padding(24)
            Divider()
            content
            Divider()
            HStack { Spacer(); Button("취소") { dismiss() }; Button(saveTitle, action: save).buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction) }.padding(20)
        }.frame(width: 530).fixedSize(horizontal: true, vertical: false)
    }
}
struct InlineError: View {
    let message: String?
    var body: some View { if let message { Label(message, systemImage: "exclamationmark.circle").font(.callout).foregroundStyle(.red).padding(.vertical, 8) } }
}
struct CourseEditor: View {
    @Bindable var app: AppState
    let store: StudyStore
    var course: Course?
    @State private var draft = CourseDraft()
    @State private var hasTarget = false
    @State private var target = Date()
    @State private var error: String?
    @State private var confirmTrim = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        EditorFrame(title: course == nil ? "강좌 등록" : "강좌 수정", saveTitle: "저장", save: { save() }) {
            Form {
                Section {
                    TextField("강좌명", text: $draft.title).accessibilityIdentifier("courseTitle")
                    Picker("과목", selection: $draft.subject) { ForEach(subjects, id: \.self) { Text($0) } }
                    TextField("강사", text: $draft.teacher)
                    TextField("플랫폼", text: $draft.platform)
                    TextField("바로가기 URL", text: $draft.link)
                }
                Section("수강 진도") {
                    TextField("전체 강의 수", value: $draft.total, format: .number).accessibilityIdentifier("courseTotal")
                    if course == nil { TextField("현재 완료한 강의 수", value: $draft.completed, format: .number).accessibilityIdentifier("courseCompleted") }
                    else { Text("강의별 완료 상태는 강좌 상세에서 수정할 수 있습니다.").font(.caption).foregroundStyle(.secondary) }
                    Toggle("완강 목표일", isOn: $hasTarget)
                    if hasTarget { DatePicker("목표일", selection: $target, displayedComponents: .date).environment(\.timeZone, StudyDate.calendar.timeZone) }
                }
                Section("메모") { TextField("선택 사항", text: $draft.notes, axis: .vertical).lineLimit(3...5) }
                InlineError(message: error)
            }.formStyle(.grouped).frame(height: 500)
        }
        .onAppear {
            if let course {
                draft.title = course.title; draft.subject = course.subject; draft.teacher = course.teacher; draft.platform = course.platform; draft.link = course.link; draft.total = course.total; draft.notes = course.notes
                hasTarget = course.targetDate != nil; target = course.targetDate ?? Date()
            }
        }
        .confirmationDialog("전체 강의 수를 줄일까요?", isPresented: $confirmTrim, titleVisibility: .visible) {
            Button("변경 적용", role: .destructive) { save(trim: true) }
        } message: { Text("범위를 벗어난 강의 이력은 보존하고 진도 계산에서 제외합니다. 해당 범위의 미완료 계획은 보관합니다.") }
    }
    private func save(trim: Bool = false) {
        draft.targetDate = hasTarget ? target : nil
        do {
            if let course {
                if !trim && draft.total < course.total && (store.completions.contains { $0.courseID == course.id && $0.lesson > draft.total } || store.blocks.contains { $0.courseID == course.id && ($0.lesson ?? 0) > draft.total }) { confirmTrim = true; return }
                try store.updateCourse(course, draft: draft, confirmTrim: trim)
            } else { try store.addCourse(draft) }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct BlockEditor: View {
    @Bindable var app: AppState
    let store: StudyStore
    var day: String
    var block: StudyBlock?
    var presetCourse: Course?
    @State private var draft = BlockDraft()
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        EditorFrame(title: block == nil ? "학습 추가" : "학습 수정", saveTitle: block == nil ? "추가" : "저장", save: save) {
            Form {
                if block == nil {
                    Picker("학습 유형", selection: $draft.kind) { ForEach(BlockKind.allCases) { Text($0.label).tag($0) } }.pickerStyle(.segmented).labelsHidden()
                }
                if draft.kind == .lecture && block == nil {
                    Section("강좌와 강의") {
                        Picker("강좌", selection: $draft.courseID) {
                            Text("강좌 선택").tag(nil as UUID?)
                            ForEach(store.courses.filter { !$0.archived }) { c in Text(c.title).tag(Optional(c.id)) }
                        }
                        if let c = store.course(draft.courseID) {
                            HStack {
                                TextField("강의 번호", value: $draft.lesson, format: .number)
                                Button("다음 강의") { draft.lesson = store.nextUnplanned(c) }.disabled(store.nextUnplanned(c) == nil)
                            }
                            Text("\(store.completedLessons(c).count) / \(c.total)강 완료 · \(store.nextUnplanned(c).map { "계획 가능한 다음 강의 \($0)강" } ?? "남은 강의가 모두 계획에 있습니다")").font(.caption).foregroundStyle(.secondary)
                        } else { Text("등록된 강좌를 선택해 주세요.").font(.caption).foregroundStyle(.secondary) }
                    }
                } else {
                    Section {
                        TextField("학습 제목", text: $draft.title).accessibilityIdentifier("blockTitle")
                        Picker("과목", selection: $draft.subject) { ForEach(subjects, id: \.self) { Text($0) } }.disabled(draft.kind == .lecture)
                        if draft.kind != .lecture {
                            TextField("학습량", value: $draft.quantity, format: .number)
                            Picker("단위", selection: $draft.unit) { ForEach(["회", "문항", "쪽", "단원", "개"], id: \.self) { Text($0) } }
                        }
                    }
                }
                Section {
                    DatePicker("계획 날짜", selection: Binding(get: { StudyDate.date(draft.day) }, set: { draft.day = StudyDate.key($0) }), displayedComponents: .date).environment(\.timeZone, StudyDate.calendar.timeZone)
                    Picker("중요도", selection: $draft.isCore) { Text("핵심").tag(true); Text("추가").tag(false) }.pickerStyle(.segmented)
                    TextField("세부 설명 (선택)", text: $draft.details, axis: .vertical).lineLimit(2...4)
                }
                InlineError(message: error)
            }.formStyle(.grouped).frame(height: 430)
        }
        .onAppear {
            draft.day = day
            if let block {
                draft.title = block.title; draft.subject = block.subject; draft.kind = block.kind; draft.details = block.details; draft.day = block.day; draft.isCore = block.isCore; draft.courseID = block.courseID; draft.lesson = block.lesson; draft.quantity = block.quantity; draft.unit = block.unit
            } else if let presetCourse {
                draft.kind = .lecture; draft.courseID = presetCourse.id; draft.lesson = store.nextUnplanned(presetCourse)
            }
        }
        .onChange(of: draft.kind) { _, kind in
            if block == nil {
                draft.unit = kind == .lecture ? "강" : kind == .problems ? "문항" : "회"
                if kind == .lecture && draft.courseID == nil, let c = store.courses.first(where: { !$0.archived && store.nextUnplanned($0) != nil }) { draft.courseID = c.id }
            }
        }
        .onChange(of: draft.courseID) { _, id in if block == nil, let c = store.course(id) { draft.lesson = store.nextUnplanned(c) } }
    }
    private func save() {
        do {
            if let block { try store.updateBlock(block, draft: draft) }
            else { try store.addBlock(draft) }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct GoalEditor: View {
    let store: StudyStore
    let week: String
    var goal: WeeklyGoal?
    @State private var subject = "수학"
    @State private var kind = BlockKind.lecture
    @State private var courseID: UUID?
    @State private var target = 4
    @State private var unit = "강"
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        EditorFrame(title: "주간 목표", saveTitle: "저장", save: save) {
            Form {
                Picker("과목", selection: $subject) { ForEach(subjects, id: \.self) { Text($0) } }
                Picker("유형", selection: $kind) { ForEach(BlockKind.allCases) { Text($0.label).tag($0) } }
                if kind == .lecture {
                    Picker("강좌", selection: $courseID) {
                        Text("이 과목의 모든 강좌").tag(nil as UUID?)
                        ForEach(store.courses.filter { $0.subject == subject && !$0.archived }) { c in Text(c.title).tag(Optional(c.id)) }
                    }
                }
                TextField("목표량", value: $target, format: .number)
                if kind != .lecture { Picker("단위", selection: $unit) { ForEach(["회", "문항", "쪽", "단원", "개"], id: \.self) { Text($0) } } }
                InlineError(message: error)
            }.formStyle(.grouped).frame(height: 300)
        }
        .onAppear { if let goal { subject = goal.subject; kind = goal.kind; courseID = goal.courseID; target = goal.target; unit = goal.unit } }
        .onChange(of: subject) { _, value in if let c = store.course(courseID), c.subject != value { courseID = nil } }
        .onChange(of: kind) { _, k in unit = k == .lecture ? "강" : k == .problems ? "문항" : "회" }
    }
    private func save() {
        do { try store.saveGoal(goal, week: week, subject: subject, kind: kind, courseID: kind == .lecture ? courseID : nil, target: target, unit: kind == .lecture ? "강" : unit); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}

struct RuleEditor: View {
    let store: StudyStore
    var rule: RecurrenceRule?
    @State private var title = ""
    @State private var subject = "영어"
    @State private var start = StudyDate.key()
    @State private var weekdays: Set<Int> = [2, 4, 6]
    @State private var interval = 3
    @State private var mode = 0
    @State private var enabled = true
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        EditorFrame(title: "반복 복습", saveTitle: "저장", save: save) {
            Form {
                TextField("학습 제목", text: $title)
                Picker("과목", selection: $subject) { ForEach(subjects, id: \.self) { Text($0) } }
                DatePicker("시작일", selection: Binding(get: { StudyDate.date(start) }, set: { start = StudyDate.key($0) }), displayedComponents: .date).environment(\.timeZone, StudyDate.calendar.timeZone)
                Picker("반복 방식", selection: $mode) { Text("요일마다").tag(0); Text("일정 간격").tag(1) }.pickerStyle(.segmented)
                if mode == 0 {
                    HStack { ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { d in
                        Toggle(["", "일", "월", "화", "수", "목", "금", "토"][d], isOn: Binding(get: { weekdays.contains(d) }, set: { if $0 { weekdays.insert(d) } else { weekdays.remove(d) } })).toggleStyle(.button)
                    } }
                } else { Stepper("\(interval)일마다", value: $interval, in: 1...365) }
                Toggle("반복 사용", isOn: $enabled)
                Text("변경은 새로 생성되는 복습에 적용됩니다. 이미 만든 블록과 과거 기록은 유지됩니다.").font(.caption).foregroundStyle(.secondary)
                InlineError(message: error)
            }.formStyle(.grouped).frame(height: 350)
        }.onAppear { if let rule { title = rule.title; subject = rule.subject; start = rule.startDay; weekdays = Set(rule.weekdays); interval = max(1, rule.interval); mode = rule.interval > 0 ? 1 : 0; enabled = rule.enabled } }
    }
    private func save() {
        do { try store.saveRule(rule, title: title, subject: subject, startDay: start, weekdays: mode == 0 ? Array(weekdays).sorted() : [], interval: mode == 1 ? interval : 0, enabled: enabled); try store.materialize(day: StudyDate.key()); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}
