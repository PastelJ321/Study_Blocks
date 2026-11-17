import SwiftUI

struct PlanView: View {
    @Bindable var app: AppState
    let store: StudyStore
    @State private var showGoal = false
    @State private var editGoal: WeeklyGoal?
    @State private var showRule = false
    @State private var editRule: RecurrenceRule?
    @State private var showSuggestions = false
    @State private var proposals: [PlanSuggestion] = []
    @Environment(\.isSnapshotCapture) private var isSnapshotCapture

    var body: some View {
        let week = StudyDate.week(app.selectedDay)
        let goals = store.goals.filter { $0.week == week }
        let dayList = store.dayBlocks(app.selectedDay)
        let dayDone = dayList.filter { store.status($0) == .done }.count

        IndexScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .bottom, spacing: 12) {
                    PageHeader(
                        eyebrow: "\(StudyDate.label(week, format: "yyyy년 M월 d일")) – \(StudyDate.label(StudyDate.adding(week, days: 6), format: "M월 d일"))",
                        title: "주간 계획과 목표"
                    )
                    HStack(spacing: 6) {
                        Button {
                            app.selectedDay = StudyDate.adding(app.selectedDay, days: -7)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain)
                        .help("이전 주")

                        Button {
                            app.selectedDay = StudyDate.key()
                        } label: {
                            Text("이번 주")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.graphite)
                                .padding(.horizontal, 6)
                        }
                        .buttonStyle(.plain)

                        Button {
                            app.selectedDay = StudyDate.adding(app.selectedDay, days: 7)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain)
                        .help("다음 주")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.card, in: RoundedRectangle(cornerRadius: IndexTokens.compactRadius))
                    .overlay(RoundedRectangle(cornerRadius: IndexTokens.compactRadius).stroke(Color.cardBorder, lineWidth: 1))
                }

                // 7-Day Weekly Index Strip
                HStack(spacing: 8) {
                    ForEach(0..<7, id: \.self) { offset in
                        let day = StudyDate.adding(week, days: offset)
                        let list = store.dayBlocks(day)
                        let doneCount = list.filter { store.status($0) == .done }.count
                        let isSelected = app.selectedDay == day
                        let isToday = day == StudyDate.key()

                        Button {
                            app.selectedDay = day
                        } label: {
                            VStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    Text(StudyDate.label(day, format: "E"))
                                        .font(.system(size: 11, weight: isSelected || isToday ? .semibold : .regular))
                                    if isToday {
                                        Circle()
                                            .fill(isSelected ? Color.white : Color.studyAccent)
                                            .frame(width: 4.5, height: 4.5)
                                    }
                                }
                                .foregroundStyle(isSelected ? Color.white.opacity(0.9) : (isToday ? Color.studyAccent : .secondary))

                                Text(StudyDate.label(day, format: "d"))
                                    .font(.system(size: 19, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(isSelected ? Color.white : Color.graphite)

                                if list.isEmpty {
                                    Text("—")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(isSelected ? Color.white.opacity(0.65) : .secondary)
                                } else {
                                    HStack(spacing: 3) {
                                        if doneCount == list.count {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 8, weight: .bold))
                                        }
                                        Text("\(doneCount)/\(list.count)")
                                            .font(.caption2.weight(.medium).monospacedDigit())
                                    }
                                    .foregroundStyle(isSelected ? Color.white.opacity(0.92) : (doneCount == list.count ? Color.studyAccent : .secondary))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                isSelected ? Color.studyAccent : Color.card,
                                in: RoundedRectangle(cornerRadius: IndexTokens.compactRadius)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: IndexTokens.compactRadius)
                                    .stroke(
                                        isSelected ? Color.studyAccent : (isToday ? Color.studyAccent.opacity(0.45) : Color.cardBorder),
                                        lineWidth: isSelected || isToday ? 1.5 : 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .modifier(DayDropModifier(enabled: !isSnapshotCapture) { sourceID in
                            if let b = store.blocks.first(where: { $0.id == sourceID }) {
                                app.move(b, to: day)
                            }
                        })
                    }
                }

                // Weekly Workload Goals Section
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("주간 학습량 목표")
                                .font(.headline)
                                .foregroundStyle(Color.graphite)
                            Text("이번 주에 완료한 학습량과 남은 목표 분량을 확인합니다.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            proposals = store.suggestions(week: week)
                            showSuggestions = true
                        } label: {
                            Text("계획 제안")
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .foregroundStyle(Color.graphite)
                                .background(Color.surfaceSubtle, in: RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.cardBorderStrong, lineWidth: 0.75))
                        }
                        .buttonStyle(.plain)
                        Button {
                            showGoal = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("목표 추가")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .foregroundStyle(.white)
                            .background(Color.studyAccent, in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }

                    if goals.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "flag")
                                .foregroundStyle(.secondary)
                            Text("이번 주에 끝낼 강의 수나 문제 풀이 분량 목표를 정해 보세요.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 10)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(goals) { goal in
                                let achieved = store.achieved(goal)
                                let planned = store.plannedPending(goal)
                                let remaining = max(0, goal.target - achieved)
                                let isMet = achieved >= goal.target

                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 10) {
                                        SubjectTag(subject: goal.subject)
                                        Text(store.course(goal.courseID)?.title ?? goal.kind.label)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.graphite)
                                            .lineLimit(1)
                                        if store.course(goal.courseID) != nil {
                                            Text("인강")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()

                                        HStack(spacing: 10) {
                                            Text("완료 \(achieved) / \(goal.target)\(goal.unit)")
                                                .font(.callout.weight(.semibold).monospacedDigit())
                                                .foregroundStyle(isMet ? Color.studyAccent : Color.graphite)

                                            if planned > 0 {
                                                Text("계획됨 \(planned)\(goal.unit)")
                                                    .font(.caption.monospacedDigit())
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.surfaceSubtle, in: RoundedRectangle(cornerRadius: 4))
                                                    .foregroundStyle(.secondary)
                                            }

                                            if isMet {
                                                Text(achieved > goal.target ? "초과 달성 +\(achieved - goal.target)\(goal.unit)" : "목표 달성")
                                                    .font(.caption.weight(.semibold).monospacedDigit())
                                                    .foregroundStyle(Color.studyAccent)
                                            } else {
                                                Text("남은 \(remaining)\(goal.unit)")
                                                    .font(.caption.weight(.semibold).monospacedDigit())
                                                    .foregroundStyle(Color.studyAccent)
                                            }
                                        }

                                        if isSnapshotCapture {
                                            Image(systemName: "ellipsis")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                                .frame(width: 20, height: 20)
                                        } else {
                                            Menu {
                                                Button("목표 수정") { editGoal = goal }
                                                Button("삭제", role: .destructive) { app.perform { try store.deleteGoal(goal) } }
                                            } label: {
                                                Image(systemName: "ellipsis")
                                                    .frame(width: 20, height: 20)
                                            }
                                            .menuStyle(.borderlessButton)
                                            .fixedSize()
                                        }
                                    }

                                    IndexProgressBar(
                                        value: Double(min(goal.target, achieved)),
                                        total: Double(max(1, goal.target)),
                                        tint: isMet ? .studyAccent : Color.subject(goal.subject),
                                        height: 6
                                    )
                                }
                                .padding(12)
                                .background(Color.surfaceSubtle.opacity(0.6), in: RoundedRectangle(cornerRadius: IndexTokens.compactRadius))
                            }
                        }
                    }
                }
                .padding(18)
                .background(Color.card, in: RoundedRectangle(cornerRadius: IndexTokens.cardRadius))
                .overlay(RoundedRectangle(cornerRadius: IndexTokens.cardRadius).stroke(Color.cardBorder, lineWidth: 1))

                // Selected Day Blocks Section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        SectionLabel(
                            title: "\(StudyDate.label(app.selectedDay)) 학습 배치",
                            count: dayList.count,
                            trailing: dayList.isEmpty ? nil : "완료 \(dayDone) · 남은 \(dayList.count - dayDone)"
                        )
                        Button {
                            app.showNewBlock = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("상세 추가")
                                    .font(.system(size: 11.5, weight: .medium))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .foregroundStyle(Color.graphite)
                            .background(Color.card, in: RoundedRectangle(cornerRadius: 5))
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.cardBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }

                    if !isSnapshotCapture {
                        QuickAddBar(app: app, store: store, day: app.selectedDay)
                    }

                    if dayList.isEmpty {
                        Text("이 날짜에 배치된 학습이 없습니다. 위 빠른 추가 바에서 학습을 배치하거나 다른 날짜의 카드를 드래그해 놓을 수 있습니다.")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                            .padding(.vertical, 16)
                    } else {
                        ForEach(dayList) { b in
                            BlockCard(app: app, store: store, block: b)
                        }
                    }
                }

                Divider()

                // Recurring Review Rules Section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("반복 복습 규칙")
                                .font(.headline)
                                .foregroundStyle(Color.graphite)
                            Text("지정한 요일이나 간격마다 해당 날짜를 열 때 복습 블록을 자동으로 준비합니다.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            showRule = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("반복 추가")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .foregroundStyle(Color.graphite)
                            .background(Color.card, in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.cardBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }

                    if store.rules.isEmpty {
                        Text("등록된 반복 복습 규칙이 없습니다.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(store.rules) { r in
                            HStack(spacing: 10) {
                                Image(systemName: "repeat")
                                    .font(.caption)
                                    .foregroundStyle(r.enabled ? Color.studyAccent : .secondary)
                                SubjectTag(subject: r.subject)
                                Text(r.title)
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(r.enabled ? Color.graphite : .secondary)
                                Spacer()
                                Text(
                                    r.enabled
                                    ? (r.interval > 0 ? "\(r.interval)일마다" : r.weekdays.sorted().map { ["", "일", "월", "화", "수", "목", "금", "토"][$0] }.joined(separator: "·"))
                                    : "중단됨"
                                )
                                .font(.caption.monospacedDigit())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.surfaceSubtle, in: RoundedRectangle(cornerRadius: 4))
                                .foregroundStyle(.secondary)

                                Button {
                                    editRule = r
                                } label: {
                                    Text("수정")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.card, in: RoundedRectangle(cornerRadius: IndexTokens.compactRadius))
                            .overlay(RoundedRectangle(cornerRadius: IndexTokens.compactRadius).stroke(Color.cardBorder, lineWidth: 1))
                        }
                    }
                }
                Spacer(minLength: 16)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: IndexTokens.pageMaxWidth)
        }
        .navigationTitle("계획")
        .sheet(isPresented: $showGoal) { GoalEditor(store: store, week: week) }
        .sheet(item: $editGoal) { goal in GoalEditor(store: store, week: week, goal: goal) }
        .sheet(isPresented: $showRule) { RuleEditor(store: store) }
        .sheet(item: $editRule) { rule in RuleEditor(store: store, rule: rule) }
        .sheet(isPresented: $showSuggestions) { SuggestionsView(app: app, store: store, suggestions: proposals) }
    }
}

struct SuggestionsView: View {
    let app: AppState, store: StudyStore
    let suggestions: [PlanSuggestion]
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?
    var body: some View {
        EditorFrame(title: "이번 주 계획 제안", saveTitle: "계획에 추가", save: apply) {
            VStack(alignment: .leading, spacing: 14) {
                Text("주간 목표와 완강 목표일을 기준으로 아직 배치하지 않은 다음 강의를 배분했습니다. 기존 수동 계획은 그대로 유지됩니다.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if suggestions.isEmpty {
                    Text("추가할 제안이 없습니다. 강좌의 완강 목표일이나 이번 주 인강 목표를 먼저 설정해 주세요.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 30)
                }
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(suggestions) { s in
                            HStack(spacing: 12) {
                                Text(StudyDate.label(s.day, format: "M/d (E)"))
                                    .font(.caption.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 72, alignment: .leading)
                                if let c = store.course(s.courseID) {
                                    SubjectTag(subject: c.subject)
                                }
                                Text("\(s.title) · \(s.lesson)강")
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(Color.graphite)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            Divider()
                        }
                    }
                }
                InlineError(message: error)
            }
            .padding(22)
            .frame(height: 360)
        }
    }
    private func apply() {
        do {
            try store.apply(suggestions)
            app.notice = "제안한 학습 \(suggestions.count)건을 계획에 추가했습니다."
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct DayDropModifier: ViewModifier {
    let enabled: Bool
    let onDropID: (UUID) -> Void
    func body(content: Content) -> some View {
        if enabled {
            content.dropDestination(for: String.self) { items, _ in
                guard let id = items.first.flatMap(UUID.init(uuidString:)) else { return false }
                onDropID(id)
                return true
            }
        } else {
            content
        }
    }
}
