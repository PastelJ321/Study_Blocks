import SwiftUI
import UniformTypeIdentifiers

struct TodayView: View {
    @Bindable var app: AppState
    let store: StudyStore
    @State private var showCompleted = true
    @State private var showOverdue = false
    var body: some View {
        let blocks = store.dayBlocks(app.selectedDay)
        let done = blocks.filter { store.status($0) == .done }
        let pending = blocks.filter { store.status($0) != .done }
        let overdue = store.blocks.filter { !$0.archived && $0.day < StudyDate.key() && store.status($0) != .done }
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .bottom) {
                    PageHeader(eyebrow: StudyDate.label(app.selectedDay, format: "yyyy년 M월 d일 EEEE"), title: app.selectedDay == StudyDate.key() ? "오늘의 학습" : "하루의 학습")
                    DayPicker(day: $app.selectedDay)
                }
                HStack(spacing: 0) {
                    Metric(value: "\(done.count) / \(blocks.count)", label: "완료한 학습")
                    Divider().frame(height: 34).padding(.horizontal, 32)
                    Metric(value: "\(pending.filter(\.isCore).count)", label: "남은 핵심 학습")
                    Spacer()
                    ZStack {
                        Circle().stroke(Color.studyAccent.opacity(0.1), lineWidth: 5)
                        Circle().trim(from: 0, to: blocks.isEmpty ? 0 : Double(done.count) / Double(blocks.count)).stroke(Color.studyAccent, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
                        Text(blocks.isEmpty ? "—" : "\(Int(Double(done.count) / Double(blocks.count) * 100))%").font(.caption.monospacedDigit())
                    }.frame(width: 52, height: 52)
                }.padding(24).background(Color.card, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(.primary.opacity(0.07)))
                if !overdue.isEmpty && app.selectedDay == StudyDate.key() {
                    DisclosureGroup(isExpanded: $showOverdue) {
                        VStack(spacing: 8) { ForEach(overdue.sorted { $0.day < $1.day }) { b in
                            HStack { Text(b.title).lineLimit(1); Spacer(); Text(StudyDate.label(b.day, format: "M/d")).foregroundStyle(.secondary); Button("오늘로") { app.move(b, to: StudyDate.key()) } }.padding(.vertical, 5)
                        } }.padding(.top, 8)
                    } label: { Label("이전 날짜의 미완료 학습 \(overdue.count)개", systemImage: "tray") }.font(.callout).padding(16).background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                }
                if blocks.isEmpty {
                    EmptyCard(symbol: "square.stack.3d.up", title: "할 공부를 하나씩 꺼내 놓으세요", detail: "다음 강의, 풀 문제, 복습할 내용을 추가할 수 있어요.", action: "학습 추가") { app.showNewBlock = true }
                    if store.courses.filter({ !$0.archived }).isEmpty {
                        Button { app.showNewCourse = true } label: { Label("인강을 듣고 있다면 강좌부터 등록", systemImage: "play.rectangle") }.buttonStyle(.plain).foregroundStyle(Color.studyAccent)
                    }
                } else {
                    VStack(spacing: 10) {
                        if !pending.isEmpty {
                            SectionLabel(title: "할 학습", count: pending.count)
                            ForEach(pending) { b in BlockCard(app: app, store: store, block: b) }
                        }
                        Button { app.showNewBlock = true } label: { Label("학습 추가", systemImage: "plus").frame(maxWidth: .infinity).padding(14) }.buttonStyle(.plain).foregroundStyle(.secondary).background(RoundedRectangle(cornerRadius: 10).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4])).foregroundStyle(.primary.opacity(0.14)))
                        if !done.isEmpty {
                            DisclosureGroup(isExpanded: $showCompleted) {
                                VStack(spacing: 8) { ForEach(done) { b in BlockCard(app: app, store: store, block: b) } }.padding(.top, 10)
                            } label: { SectionLabel(title: "완료한 학습", count: done.count) }.padding(.top, 12)
                        }
                    }
                }
                Spacer(minLength: 20)
            }.padding(32).frame(maxWidth: 1080)
        }.animation(.easeInOut(duration: 0.2), value: blocks.map { store.status($0).rawValue }).navigationTitle("오늘")
    }
}

struct Metric: View {
    let value: String, label: String
    var body: some View { VStack(alignment: .leading, spacing: 6) { Text(value).font(.system(size: 27, weight: .semibold, design: .rounded)).monospacedDigit(); Text(label).font(.caption).foregroundStyle(.secondary) } }
}
struct DayPicker: View {
    @Binding var day: String
    var body: some View {
        HStack(spacing: 8) {
            Button { day = StudyDate.adding(day, days: -1) } label: { Image(systemName: "chevron.left") }.help("이전 날짜")
            DatePicker("날짜", selection: Binding(get: { StudyDate.date(day) }, set: { day = StudyDate.key($0) }), displayedComponents: .date).labelsHidden().environment(\.timeZone, StudyDate.calendar.timeZone).frame(width: 112)
            Button { day = StudyDate.adding(day, days: 1) } label: { Image(systemName: "chevron.right") }.help("다음 날짜")
        }.buttonStyle(.borderless)
    }
}

struct BlockCard: View {
    @Bindable var app: AppState
    let store: StudyStore
    let block: StudyBlock
    @State private var editing = false
    @State private var isTargeted = false
    var body: some View {
        let done = store.status(block) == .done
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 2).fill(Color.subject(block.subject).opacity(done ? 0.35 : 0.85)).frame(width: 3).padding(.vertical, 12)
            Button { withAnimation(.easeInOut(duration: 0.2)) { app.toggle(block) } } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle").font(.system(size: 25, weight: .light)).foregroundStyle(done ? Color.studyAccent : Color.secondary.opacity(0.5)).contentTransition(.symbolEffect(.replace))
            }.buttonStyle(.plain).help(done ? "완료 취소" : "학습 완료").accessibilityLabel(done ? "\(block.title) 완료 취소" : "\(block.title) 완료")
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    SubjectTag(subject: block.subject)
                    Label(block.kind.label, systemImage: block.kind.symbol).font(.caption).foregroundStyle(.secondary)
                    if !block.isCore { Text("추가").font(.caption).foregroundStyle(.tertiary) }
                    if store.status(block) == .active { Text("진행 중").font(.caption).foregroundStyle(Color.studyAccent) }
                    if block.recurrenceID != nil { Image(systemName: "repeat").font(.caption2).foregroundStyle(.tertiary) }
                }
                Button { editing = true } label: { Text(block.title).font(.system(size: 15, weight: .medium)).foregroundStyle(done ? .secondary : .primary).strikethrough(done, color: .secondary.opacity(0.5)).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.plain)
                if !block.details.isEmpty { Text(block.details).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
            }.padding(.vertical, 16)
            Spacer(minLength: 0)
            if block.kind != .lecture { Text("\(block.quantity)\(block.unit)").font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
            if !done {
                Button { app.move(block, to: StudyDate.adding(block.day, days: 1)) } label: { Image(systemName: "arrow.turn.up.right") }.buttonStyle(.plain).foregroundStyle(.secondary).help("다음 날로 미루기")
            }
            Menu {
                Button("세부 사항 수정") { editing = true }
                Button(done ? "완료 취소" : "완료") { app.toggle(block) }
                if !done { Button(store.status(block) == .active ? "대기로 변경" : "진행 중으로 변경") { app.perform { try store.setStatus(block, store.status(block) == .active ? .pending : .active) } } }
                Divider()
                Button("위로 이동") { moveUp() }
                Button("아래로 이동") { moveDown() }
                Button("보관") { app.perform { try store.archive(block) } }
            } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).fixedSize().help("학습 메뉴")
            Image(systemName: "line.3.horizontal").font(.caption).foregroundStyle(.tertiary).help("드래그하여 순서 변경")
        }.padding(.trailing, 16).padding(.leading, 0)
        .background(done ? Color.card.opacity(0.65) : Color.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(isTargeted ? Color.studyAccent : .primary.opacity(0.08), lineWidth: isTargeted ? 2 : 1))
        .draggable(block.id.uuidString)
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.first.flatMap(UUID.init(uuidString:)) else { return false }
            app.perform { try store.reorder(id, before: block.id, day: block.day) }; return true
        } isTargeted: { isTargeted = $0 }
        .sheet(isPresented: $editing) { BlockEditor(app: app, store: store, day: block.day, block: block) }
    }
    private func moveUp() {
        let list = store.dayBlocks(block.day)
        if let index = list.firstIndex(where: { $0.id == block.id }), index > 0 { app.perform { try store.reorder(block.id, before: list[index - 1].id, day: block.day) } }
    }
    private func moveDown() {
        let list = store.dayBlocks(block.day)
        if let index = list.firstIndex(where: { $0.id == block.id }), index + 1 < list.count { app.perform { try store.reorder(list[index + 1].id, before: block.id, day: block.day) } }
    }
}
