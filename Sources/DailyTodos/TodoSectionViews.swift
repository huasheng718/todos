import SwiftUI

struct WorkSectionGroup: Identifiable, Equatable {
    let kind: WorkSectionKind
    let todos: [TodoItem]

    var id: WorkSectionKind { kind }
}

struct DashboardSummaryStrip: View {
    let groups: [WorkSectionGroup]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(groups) { group in
                HStack(spacing: 8) {
                    Image(systemName: group.kind.icon)
                        .font(.system(size: 11, weight: .semibold))
                    Text(group.kind.title)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(group.todos.count)")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(group.kind.color)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(group.kind.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(group.kind.color.opacity(0.24))
                )
            }
        }
    }
}

struct DailySuggestionCard: View {
    let suggestion: String?
    let error: String?
    let trace: AITrace?
    let step: String?
    let isLoading: Bool
    let onGenerate: () -> Void

    @State private var showsTrace = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.accent)

                Text("AI 每日建议")
                    .font(.system(size: 12, weight: .semibold))

                Spacer()

                Button(action: onGenerate) {
                    Label(isLoading ? "生成中" : "生成建议", systemImage: "wand.and.stars")
                        .font(.caption.weight(.semibold))
                        .frame(width: 94, height: 28)
                }
                .buttonStyle(.tactilePlain)
                .tactilePlainControlAppearance(
                    isDisabled: isLoading,
                    enabledForeground: AppTheme.workspaceTokens.accent,
                    enabledBackground: AppTheme.workspaceTokens.accentSoft,
                    enabledBorder: AppTheme.workspaceTokens.accent.opacity(0.20),
                    shape: .capsule
                )
                .interactionHitArea()
                .disabled(isLoading)
            }

            if let step {
                HStack(spacing: 6) {
                    Image(systemName: isLoading ? "arrow.triangle.2.circlepath" : (error == nil ? "checkmark.circle" : "exclamationmark.triangle"))
                        .font(.system(size: 10, weight: .bold))
                    Text(step)
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    if let trace {
                        Text("\(trace.model) · \(trace.durationText)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                .foregroundStyle(error == nil ? AppTheme.mutedInk : TodoPriority.high.displayColor)
            }

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在读取当前待办并生成推进顺序")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                }
                .transition(.opacity)
            } else if let error {
                Text("生成失败：\(error)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TodoPriority.high.displayColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            } else if let suggestion, !suggestion.isEmpty {
                Text(suggestion)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(AppMotion.inlineTransition)
            } else {
                Text("用当前未完成事项生成今天的推进顺序。")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            }

            if let trace {
                AITraceDisclosure(trace: trace, isExpanded: $showsTrace)
            }
        }
        .padding(12)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(AppTheme.accent.opacity(0.18))
        )
        .animation(AppMotion.reveal, value: suggestion)
        .animation(AppMotion.reveal, value: error)
        .animation(AppMotion.reveal, value: isLoading)
        .animation(AppMotion.reveal, value: showsTrace)
    }
}

struct AITraceCompactView: View {
    let trace: AITrace

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 10, weight: .bold))
            Text("AI 已调用")
                .font(.system(size: 11, weight: .semibold))
            Text("\(trace.model) · \(trace.durationText) · 输入 \(trace.inputCharacters) 字 / 输出 \(trace.outputCharacters) 字")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.mutedInk)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .foregroundStyle(AppTheme.accent)
    }
}

struct AITraceDisclosure: View {
    let trace: AITrace
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button {
                withAnimation(AppMotion.reveal) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                    Text("查看 AI 调用详情")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Text("\(trace.statusCode) · \(trace.startedAtText)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                }
                .foregroundStyle(AppTheme.accent)
                .contentShape(Rectangle())
            }
            .buttonStyle(.tactilePlain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 5) {
                    AITraceLine(label: "场景", value: trace.scenario)
                    AITraceLine(label: "模型", value: trace.model)
                    AITraceLine(label: "接口", value: trace.endpoint)
                    AITraceLine(label: "耗时", value: trace.durationText)
                    AITraceLine(label: "规模", value: "输入 \(trace.inputCharacters) 字，输出 \(trace.outputCharacters) 字")
                    AITraceLine(label: "返回", value: trace.responsePreview.isEmpty ? "空返回" : trace.responsePreview)
                }
                .padding(9)
                .background(AppTheme.adaptiveWhite(0.86), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppTheme.hairline)
                )
                .transition(AppMotion.inlineTransition)
            }
        }
    }
}

struct AITraceLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.mutedInk)
                .frame(width: 30, alignment: .leading)
            Text(value)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct WorkSection<Content: View>: View {
    let group: WorkSectionGroup
    let row: (TodoItem) -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Image(systemName: group.kind.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(group.kind.color)
                Text(group.kind.title)
                    .font(.system(size: 12, weight: .semibold))
                Text(group.kind.subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.mutedInk)
                Spacer()
                Text("\(group.todos.count) 项")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            }
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .padding(.bottom, 2)

            ForEach(group.todos) { todo in
                row(todo)
            }
        }
    }
}

struct TodoDateGroupHeader: View {
    let date: Date
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
            Text(date.formatted(.dateTime.year().month().day().weekday(.wide)))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.mutedInk)
            Spacer()
            Text("\(count) 项")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.mutedInk)
        }
        .padding(.horizontal, 8)
        .padding(.top, 9)
        .padding(.bottom, 1)
    }

    private var title: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInTomorrow(date) { return "明天" }
        if calendar.isDateInYesterday(date) { return "昨天" }
        return date.formatted(.dateTime.month(.wide).day())
    }
}

struct TodoTableHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            tableHeaderText("状态")
                .frame(width: statusColumnWidth, alignment: .leading)
            tableHeaderText("待办")
                .frame(minWidth: 190, maxWidth: .infinity, alignment: .leading)
            tableHeaderText("进度")
                .frame(width: progressColumnWidth, alignment: .leading)
            tableHeaderText("优先级")
                .frame(width: priorityColumnWidth, alignment: .leading)
            tableHeaderText("跟进日")
                .frame(width: followUpColumnWidth, alignment: .leading)
            Color.clear
                .frame(width: todoActionColumnWidth)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func tableHeaderText(_ value: String) -> some View {
        Text(value)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.mutedInk)
    }
}
