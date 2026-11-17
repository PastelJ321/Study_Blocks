import SwiftUI

struct CoursesView: View {
    @Bindable var app: AppState
    let store: StudyStore
    @State private var selected: Course?
    @State private var showArchived = false
    @Environment(\.isSnapshotCapture) private var isSnapshotCapture

    var body: some View {
        let courses = store.courses.filter { $0.archived == showArchived }
        let activeCourses = courses.filter { store.nextLesson($0) != nil }
        let completedCourses = courses.filter { store.nextLesson($0) == nil }

        IndexScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .bottom, spacing: 12) {
                    PageHeader(
                        eyebrow: "\(courses.count)개 강좌 · 수강 중 \(activeCourses.count)개 · 완강 \(completedCourses.count)개",
                        title: showArchived ? "보관한 강좌" : "나의 강좌"
                    )
                    Button {
                        showArchived.toggle()
                    } label: {
                        Text(showArchived ? "수강 목록 보기" : "보관함")
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .foregroundStyle(showArchived ? Color.studyAccent : Color.graphite)
                            .background(Color.card, in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.cardBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button {
                        app.showNewCourse = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .semibold))
                            Text("강좌 등록")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .foregroundStyle(.white)
                        .background(Color.studyAccent, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }

                if courses.isEmpty {
                    EmptyCard(
                        symbol: "play.rectangle",
                        title: showArchived ? "보관한 강좌가 없습니다" : "수강 중인 강좌를 등록하세요",
                        detail: showArchived ? "" : "전체 강의 수와 현재 완료한 진도를 한 번 입력하면 다음 강의가 자동으로 이어집니다.",
                        action: "강좌 등록 (⇧⌘N)"
                    ) {
                        app.showNewCourse = true
                    }
                } else {
                    if !activeCourses.isEmpty {
                        if !completedCourses.isEmpty {
                            SectionLabel(title: "수강 중인 강좌", count: activeCourses.count)
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 16)], spacing: 16) {
                            ForEach(activeCourses) { c in
                                CourseCard(app: app, store: store, course: c, onSelect: { selected = c }, onAddNext: { addNext(c) })
                            }
                        }
                    }

                    if !completedCourses.isEmpty {
                        if !activeCourses.isEmpty {
                            SectionLabel(title: "완강한 강좌", count: completedCourses.count)
                                .padding(.top, 8)
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 16)], spacing: 16) {
                            ForEach(completedCourses) { c in
                                CourseCard(app: app, store: store, course: c, onSelect: { selected = c }, onAddNext: { addNext(c) })
                            }
                        }
                    }
                }
                Spacer(minLength: 16)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: 1140)
        }
        .navigationTitle("강좌")
        .sheet(item: $selected) { c in
            CourseDetail(app: app, store: store, course: c)
        }
    }

    private func addNext(_ c: Course) {
        guard let lesson = store.nextUnplanned(c) else { return }
        var draft = BlockDraft()
        draft.kind = .lecture
        draft.courseID = c.id
        draft.lesson = lesson
        draft.day = StudyDate.key()
        app.perform {
            try store.addBlock(draft)
            app.notice = "\(c.title) · \(lesson)강을 오늘 학습에 추가했습니다."
        }
    }
}

struct CourseCard: View {
    @Bindable var app: AppState
    let store: StudyStore
    let course: Course
    let onSelect: () -> Void
    let onAddNext: () -> Void

    var body: some View {
        let completedCount = store.completedLessons(course).count
        let total = max(1, course.total)
        let remaining = max(0, course.total - completedCount)
        let nextLesson = store.nextLesson(course)
        let isFinished = nextLesson == nil
        let pct = Int(round(Double(completedCount) / Double(total) * 100))
        let auxInfo = [course.teacher, course.platform].filter { !$0.isEmpty }.joined(separator: " · ")

        VStack(alignment: .leading, spacing: 14) {
            // Top Row: Subject, Auxiliary Info (Teacher/Platform), Status Badge
            HStack(spacing: 8) {
                SubjectTag(subject: course.subject)
                if !auxInfo.isEmpty {
                    Text(auxInfo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if isFinished {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                        Text("완강")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .foregroundStyle(Color.studyAccent)
                    .background(Color.studyAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                } else {
                    Text(completedCount == 0 ? "시작 전" : "수강 중")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            // 1. Course Title
            Button(action: onSelect) {
                Text(course.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isFinished ? .secondary : Color.graphite)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            // 2. Current Progress (Completed vs Total comparison)
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(completedCount)")
                        .font(.system(size: 20, weight: .bold).monospacedDigit())
                        .foregroundStyle(isFinished ? Color.studyAccent : Color.graphite)
                    Text("/ \(course.total)강")
                        .font(.system(size: 13, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !isFinished {
                        Text("남은 \(remaining)강 · ")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Text("\(pct)%")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(isFinished ? Color.studyAccent : .secondary)
                }
                IndexProgressBar(
                    value: Double(completedCount),
                    total: Double(total),
                    tint: isFinished ? .studyAccent.opacity(0.75) : Color.subject(course.subject),
                    height: 6
                )
            }

            // 3 & 4. Next Lesson & Target/Completion Status Strip
            HStack(spacing: 8) {
                if let next = nextLesson {
                    HStack(spacing: 5) {
                        Text("다음 강의")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(next)강")
                            .font(.system(size: 13, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Color.graphite)
                    }
                } else {
                    Label("전 강의 수강 완료", systemImage: "checkmark")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let target = course.targetDate {
                    HStack(spacing: 4) {
                        Image(systemName: "flag")
                            .font(.system(size: 10))
                        Text("목표 \(StudyDate.label(StudyDate.key(target), format: "M. d."))")
                            .font(.caption.monospacedDigit())
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.surfaceSubtle.opacity(isFinished ? 0.55 : 1.0), in: RoundedRectangle(cornerRadius: IndexTokens.compactRadius))

            // Action Footer
            HStack(spacing: 8) {
                if !course.archived, let unplanned = store.nextUnplanned(course) {
                    Button(action: onAddNext) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .semibold))
                            Text("다음(\(unplanned)강) 오늘에 추가")
                                .font(.system(size: 12, weight: .medium).monospacedDigit())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .foregroundStyle(Color.graphite)
                        .background(Color.surfaceSubtle, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.cardBorderStrong, lineWidth: 0.75))
                    }
                    .buttonStyle(.plain)
                } else if !isFinished && !course.archived {
                    Text("남은 강의가 계획에 배치됨")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Spacer()
                }

                if let url = course.validURL {
                    Link(destination: url) {
                        HStack(spacing: 3) {
                            Text("강좌 열기")
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .foregroundStyle(Color.studyAccent)
                        .background(Color.studyAccent.opacity(0.11), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .help("외부 인강 플랫폼에서 강좌 열기")
                }

                Button(action: onSelect) {
                    Text("상세 보기")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(isFinished ? Color.cardMuted : Color.card, in: RoundedRectangle(cornerRadius: IndexTokens.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: IndexTokens.cardRadius)
                .stroke(isFinished ? Color.cardBorder.opacity(0.75) : Color.cardBorder, lineWidth: 1)
        )
    }
}

struct CourseDetail: View {
    @Bindable var app: AppState
    let store: StudyStore
    let course: Course
    @State private var editing = false
    @State private var showBlock = false
    @State private var lessonPage = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let completedSet = store.completedLessons(course)
        let completedCount = completedSet.count
        let remainingCount = max(0, course.total - completedCount)
        let nextLesson = store.nextLesson(course)
        let auxInfo = [course.teacher, course.platform].filter { !$0.isEmpty }.joined(separator: " · ")

        VStack(spacing: 0) {
            HStack(spacing: 10) {
                SubjectTag(subject: course.subject)
                if !auxInfo.isEmpty {
                    Text(auxInfo)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("강좌 수정") { editing = true }
                Button("닫기") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(Color.card)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.cardBorder).frame(height: 1) }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(course.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.graphite)

                        HStack(spacing: 24) {
                            Metric(value: "\(completedCount) / \(course.total)강", label: "완료한 강의")
                            Divider().frame(height: 30)
                            Metric(value: "\(remainingCount)강", label: "남은 강의")
                            Divider().frame(height: 30)
                            Metric(value: nextLesson.map { "\($0)강" } ?? "완강", label: "다음 수강 강의")
                            Spacer()
                        }

                        IndexProgressBar(
                            value: Double(completedCount),
                            total: Double(max(1, course.total)),
                            tint: Color.subject(course.subject),
                            height: 8
                        )

                        if let target = course.targetDate {
                            Label("완강 목표일: \(StudyDate.label(StudyDate.key(target), format: "yyyy년 M월 d일"))", systemImage: "flag")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        if !course.notes.isEmpty {
                            Text(course.notes)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }

                        HStack(spacing: 10) {
                            if let next = nextLesson {
                                Button("\(next)강 수강 완료") {
                                    app.perform { try store.setLesson(course, lesson: next, done: true) }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            if let unplanned = store.nextUnplanned(course) {
                                Button("다음(\(unplanned)강) 오늘에 추가") {
                                    var draft = BlockDraft()
                                    draft.kind = .lecture
                                    draft.courseID = course.id
                                    draft.lesson = unplanned
                                    draft.day = StudyDate.key()
                                    app.perform {
                                        try store.addBlock(draft)
                                        app.notice = "\(unplanned)강을 오늘 학습에 추가했습니다."
                                    }
                                }
                                Button("날짜 지정 추가…") { showBlock = true }
                            }
                            Spacer()
                            if let url = course.validURL {
                                Link("강좌 바로가기 ↗", destination: url)
                                    .font(.callout.weight(.medium))
                            }
                        }
                    }
                    .padding(18)
                    .background(Color.card, in: RoundedRectangle(cornerRadius: IndexTokens.cardRadius))
                    .overlay(RoundedRectangle(cornerRadius: IndexTokens.cardRadius).stroke(Color.cardBorder, lineWidth: 1))

                    // Lesson Grid Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("강의별 진도")
                                .font(.headline)
                                .foregroundStyle(Color.graphite)
                            Spacer()
                            HStack(spacing: 12) {
                                HStack(spacing: 4) {
                                    Circle().fill(Color.studyAccent).frame(width: 6, height: 6)
                                    Text("완료").font(.caption2).foregroundStyle(.secondary)
                                }
                                HStack(spacing: 4) {
                                    Circle().stroke(Color.studyAccent, lineWidth: 1.5).frame(width: 6, height: 6)
                                    Text("다음 강의").font(.caption2).foregroundStyle(.secondary)
                                }
                                HStack(spacing: 4) {
                                    Circle().fill(Color.graphite.opacity(0.45)).frame(width: 5, height: 5)
                                    Text("계획됨").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            if course.total > 50 {
                                Divider().frame(height: 12)
                                Button { lessonPage = max(0, lessonPage - 1) } label: { Image(systemName: "chevron.left") }
                                    .disabled(lessonPage == 0)
                                Text("\(lessonPage * 50 + 1)–\(min(course.total, (lessonPage + 1) * 50))")
                                    .font(.caption.monospacedDigit())
                                Button { lessonPage += 1 } label: { Image(systemName: "chevron.right") }
                                    .disabled((lessonPage + 1) * 50 >= course.total)
                            }
                        }
                        Text("강의 번호를 누르면 수강 완료 또는 취소를 직접 전환합니다. 건너뛴 강의도 개별 관리할 수 있습니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 68), spacing: 8)], spacing: 8) {
                            ForEach(Array((min(lessonPage * 50 + 1, course.total))...min(course.total, (lessonPage + 1) * 50)), id: \.self) { lesson in
                                let done = completedSet.contains(lesson)
                                let isNext = nextLesson == lesson
                                let planned = store.plannedBlock(for: course, lesson: lesson) != nil

                                Button {
                                    app.perform { try store.setLesson(course, lesson: lesson, done: !done) }
                                } label: {
                                    HStack(spacing: 4) {
                                        if done {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10, weight: .bold))
                                        } else if planned {
                                            Circle()
                                                .fill(Color.graphite.opacity(0.45))
                                                .frame(width: 4.5, height: 4.5)
                                        }
                                        Text("\(lesson)강")
                                            .font(.system(size: 12, weight: isNext || done ? .semibold : .regular).monospacedDigit())
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .foregroundStyle(done ? Color.studyAccent : (isNext ? Color.graphite : .secondary))
                                    .background(
                                        done ? Color.studyAccent.opacity(0.13) : Color.card,
                                        in: RoundedRectangle(cornerRadius: 6)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(
                                                isNext ? Color.studyAccent : (done ? Color.studyAccent.opacity(0.28) : Color.cardBorder),
                                                lineWidth: isNext ? 1.5 : 1
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(lesson)강 \(done ? "완료 취소" : "완료")")
                            }
                        }
                    }

                    Divider()

                    HStack {
                        Button(course.archived ? "보관 해제" : "강좌 보관") {
                            app.perform { try store.archiveCourse(course); dismiss() }
                        }
                        .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
                .padding(24)
            }
            .background(Color.canvas)
        }
        .frame(width: 660, height: 720)
        .sheet(isPresented: $editing) { CourseEditor(app: app, store: store, course: course) }
        .sheet(isPresented: $showBlock) { BlockEditor(app: app, store: store, day: app.selectedDay, presetCourse: course) }
        .onChange(of: course.total) { _, _ in lessonPage = min(lessonPage, (course.total - 1) / 50) }
    }
}
