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
    var body: some View {
        let week = StudyDate.week(app.selectedDay)
        let goals = store.goals.filter { $0.week == week }
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .bottom) {
                    PageHeader(eyebrow: "\(StudyDate.label(week, format: "M월 d일")) – \(StudyDate.label(StudyDate.adding(week, days: 6), format: "M월 d일"))", title: "이번 주의 학습량")
                    HStack { Button { app.selectedDay = StudyDate.adding(app.selectedDay, days: -7) } label: { Image(systemName: "chevron.left") }; Button("이번 주") { app.selectedDay = StudyDate.key() }; Button { app.selectedDay = StudyDate.adding(app.selectedDay, days: 7) } label: { Image(systemName: "chevron.right") } }.buttonStyle(.borderless)
                }
                HStack(spacing: 8) {
                    ForEach(0..<7) { offset in
                        let day = StudyDate.adding(week, days: offset), list = store.dayBlocks(day)
                        Button { app.selectedDay = day } label: {
                            VStack(spacing: 10) {
                                Text(StudyDate.label(day, format: "E")).font(.caption)
                                Text(StudyDate.label(day, format: "d")).font(.system(size: 21, weight: .semibold))
                                Text(list.isEmpty ? "—" : "\(list.filter { store.status($0) == .done }.count)/\(list.count)").font(.caption2.monospacedDigit())
                            }.foregroundStyle(app.selectedDay == day ? Color.white : day == StudyDate.key() ? Color.studyAccent : .secondary).frame(maxWidth: .infinity).padding(.vertical, 16).background(app.selectedDay == day ? Color.studyAccent : Color.card, in: RoundedRectangle(cornerRadius: 9))
                        }.buttonStyle(.plain).dropDestination(for: String.self) { items, _ in
                            guard let id = items.first.flatMap(UUID.init(uuidString:)), let b = store.blocks.first(where: { $0.id == id }) else { return false }
                            app.move(b, to: day); return true
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("주간 목표").font(.headline); Spacer()
                        Button("계획 제안") { proposals = store.suggestions(week: week); showSuggestions = true }
                        Button { showGoal = true } label: { Label("목표 추가", systemImage: "plus") }
                    }
                    if goals.isEmpty { Text("이번 주에 끝낼 강의 수나 문제 수를 정해 보세요.").font(.callout).foregroundStyle(.secondary).padding(.vertical, 12) }
                    ForEach(goals) { goal in
                        HStack(spacing: 14) {
                            SubjectTag(subject: goal.subject)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(store.course(goal.courseID)?.title ?? goal.kind.label).font(.callout.weight(.medium)).lineLimit(1)
                                    Spacer()
                                    Text("\(store.achieved(goal)) / \(goal.target)\(goal.unit)").font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                                }
                                ProgressView(value: Double(min(goal.target, store.achieved(goal))), total: Double(goal.target))
                            }
                            Text("남은 \(max(0, goal.target - store.achieved(goal)))\(goal.unit)").font(.caption).foregroundStyle(Color.studyAccent)
                            Menu { Button("수정") { editGoal = goal }; Button("삭제", role: .destructive) { app.perform { try store.deleteGoal(goal) } } } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).fixedSize()
                        }.padding(.vertical, 8)
                    }
                }.padding(22).background(Color.card, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(.primary.opacity(0.08)))
                VStack(alignment: .leading, spacing: 10) {
                    HStack { Text(StudyDate.label(app.selectedDay) + " 학습").font(.headline); Spacer(); Button("학습 추가") { app.showNewBlock = true } }
                    if store.dayBlocks(app.selectedDay).isEmpty { Text("아직 배치한 학습이 없어요.").foregroundStyle(.secondary).font(.callout).padding(.vertical, 20) }
                    ForEach(store.dayBlocks(app.selectedDay)) { b in BlockCard(app: app, store: store, block: b) }
                }
                Divider()
                VStack(alignment: .leading, spacing: 14) {
                    HStack { Text("반복 복습").font(.headline); Spacer(); Button { showRule = true } label: { Label("반복 추가", systemImage: "plus") } }
                    ForEach(store.rules) { r in
                        HStack {
                            Image(systemName: "repeat").foregroundStyle(.secondary)
                            Text(r.title).font(.callout)
                            Spacer()
                            Text(r.enabled ? (r.interval > 0 ? "\(r.interval)일마다" : r.weekdays.sorted().map { ["", "일", "월", "화", "수", "목", "금", "토"][$0] }.joined(separator: "·")) : "중단됨").font(.caption).foregroundStyle(.secondary)
                            Button("수정") { editRule = r }
                        }.padding(14).background(Color.card, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }.padding(32).frame(maxWidth: 1080)
        }.navigationTitle("계획")
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
            VStack(alignment: .leading, spacing: 16) {
                Text("주간 목표와 완강 목표일을 기준으로 남은 강의를 배분했어요. 이미 배치한 학습은 유지됩니다.").font(.callout).foregroundStyle(.secondary)
                if suggestions.isEmpty { Text("추가할 제안이 없어요. 강좌의 완강 목표일이나 이번 주 인강 목표를 설정해 주세요.").padding(.vertical, 30) }
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(suggestions) { s in
                            HStack { Text(StudyDate.label(s.day, format: "M/d E")).font(.caption.monospacedDigit()).frame(width: 64, alignment: .leading); Text("\(s.title) · \(s.lesson)강").font(.callout); Spacer() }.padding(.vertical, 12)
                            Divider()
                        }
                    }
                }
                InlineError(message: error)
            }.padding(24).frame(height: 360)
        }
    }
    private func apply() {
        do { try store.apply(suggestions); app.notice = "제안한 학습을 계획에 추가했습니다."; dismiss() }
        catch { self.error = error.localizedDescription }
    }
}
