import SwiftUI

struct QuickCaptureBar: View {
    @Binding var title: String
    @Binding var priority: TodoPriority
    @Binding var progress: TodoProgress
    @Binding var date: Date
    let previewDate: Date
    @Binding var notes: String
    @Binding var isWeekly: Bool
    @Binding var isExpanded: Bool
    var focusedField: FocusState<FocusField?>.Binding
    let onActivate: () -> Void
    let onCreate: () -> Void
    let onClear: () -> Void
    let isCreating: Bool
    let aiStatusMessage: String?
    let aiTrace: AITrace?
    let aiResultSummary: String?
    let isAIEnabled: Bool
    @State private var isHovered = false

    private var isFocused: Bool {
        focusedField.wrappedValue == .newTitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 9 : 5) {
            HStack(alignment: .center, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppTheme.accent.opacity(isFocused ? 0.22 : 0.16),
                                    AppTheme.accentWarm.opacity(isFocused ? 0.18 : 0.13)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(AppTheme.accent.opacity(0.16), lineWidth: 1)
                        )
                    Image(systemName: "command")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                }
                .frame(width: 28, height: 28)
                .scaleEffect(isFocused ? 1.04 : 1)

                TextField("快速记录：要推进什么…", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                    .focused(focusedField, equals: .newTitle)
                    .submitLabel(.done)
                    .onSubmit(submitQuickRecord)
                    .disabled(isCreating)
                    .onTapGesture {
                        onActivate()
                    }
                    .frame(minWidth: 190, maxWidth: .infinity, alignment: .leading)

                Button {
                    guard !isCreating else { return }
                    if !isExpanded {
                        onActivate()
                        return
                    }
                    withAnimation(AppMotion.revealAware) {
                        isExpanded = false
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "slider.horizontal.3")
                        .font(.system(size: 12, weight: .semibold))
                        .interactionHitArea()
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(AppTheme.mutedInk)
                .help(isExpanded ? "收起记录字段" : "展开记录字段")
                .accessibilityLabel("记录字段")
                .accessibilityValue(isExpanded ? "已展开" : "已收起")
                .disabled(isCreating)

                Button(action: onCreate) {
                    Label(isCreating ? "解析" : "记录", systemImage: isCreating ? "sparkles" : "arrow.down.to.line.compact")
                        .font(.caption.weight(.semibold))
                        .frame(width: 70, height: 30)
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(.white)
                .background(canCreate && !isCreating ? AppTheme.accentWarm : AppTheme.adaptiveBlack(0.28), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(canCreate && !isCreating ? AppTheme.adaptiveWhite(0.52) : AppTheme.adaptiveBlack(0.05))
                )
                .shadow(color: canCreate && !isCreating ? AppTheme.accentWarm.opacity(0.20) : .clear, radius: 10, x: 0, y: 6)
                .scaleEffect(canCreate && isFocused ? 1.02 : 1)
                .interactionHitArea()
                .disabled(!canCreate || isCreating)
                .help("记录新的待办")

                if isExpanded || hasDraft {
                    Button(action: onClear) {
                        Image(systemName: "xmark")
                            .interactionHitArea()
                    }
                    .buttonStyle(.tactilePlain)
                    .foregroundStyle(AppTheme.mutedInk)
                    .help("清空记录")
                    .accessibilityLabel("清空记录")
                    .disabled(isCreating)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isCreating else { return }
                onActivate()
            }

            if hasDraft {
                QuickCapturePreview(
                    title: parsedPreview.title,
                    notes: parsedPreview.notes,
                    priority: parsedPreview.priority,
                    progress: parsedPreview.progress,
                    date: parsedPreview.date,
                    isWeekly: parsedPreview.isWeekly
                )
                .transition(AppMotion.inlineTransition)
            }

            if let aiStatusMessage {
                HStack(spacing: 6) {
                    Image(systemName: aiStatusMessage.contains("失败") ? "exclamationmark.triangle" : "sparkles")
                        .font(.system(size: 10, weight: .bold))
                    Text(aiStatusMessage)
                        .font(.system(size: 11, weight: .semibold))
                    if isCreating {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
                .foregroundStyle(aiStatusMessage.contains("失败") ? TodoPriority.high.displayColor : AppTheme.accent)
                .padding(.leading, 32)
                .transition(AppMotion.inlineTransition)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(aiStatusMessage)
                .accessibilityAddTraits(.updatesFrequently)
            } else if isAIEnabled && hasDraft {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                    Text("提交时使用 AI 解析")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(AppTheme.accent)
                .padding(.leading, 32)
                .transition(AppMotion.inlineTransition)
            }

            if let aiTrace {
                VStack(alignment: .leading, spacing: 4) {
                    if let aiResultSummary {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal")
                                .font(.system(size: 10, weight: .bold))
                            Text(aiResultSummary)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(AppTheme.accent)
                    }
                    AITraceCompactView(trace: aiTrace)
                }
                .padding(.leading, 32)
                .transition(AppMotion.inlineTransition)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        PriorityPicker(priority: $priority)
                            .frame(width: 78, alignment: .leading)
                            .disabled(isCreating)

                        ProgressPicker(progress: $progress)
                            .frame(width: 104, alignment: .leading)
                            .disabled(isCreating)

                        DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .frame(width: 150, alignment: .leading)
                            .disabled(isCreating)

                        Toggle(isOn: $isWeekly) {
                            Label("每周固定", systemImage: "repeat")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.mutedInk)
                        }
                        .toggleStyle(.checkbox)
                        .help("完成后自动生成下周同一天")
                        .disabled(isCreating)

                        Spacer(minLength: 0)
                    }

                    CompactNotesField(text: $notes, onSubmit: submitQuickRecord)
                        .frame(maxWidth: .infinity)
                        .disabled(isCreating)
                }
                .padding(.leading, 32)
                .transition(AppMotion.inlineTransition)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.panel)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(canCreate ? AppTheme.accentWarm : AppTheme.accent)
                        .frame(width: 3)
                        .opacity(canCreate || isExpanded ? 0.95 : 0.34)
                        .padding(.vertical, 10)
                }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(captureStrokeColor, lineWidth: isFocused ? 1.35 : 1)
        )
        .shadow(
            color: AppTheme.rowShadow,
            radius: hasDraft || isHovered || isFocused ? 15 : 8,
            x: 0,
            y: hasDraft || isHovered || isFocused ? 7 : 4
        )
        .onHover { hovered in
            withAnimation(AppMotion.hoverAware) {
                isHovered = hovered
            }
        }
        .animation(AppMotion.revealAware, value: isExpanded)
        .animation(AppMotion.captureAware, value: hasDraft)
        .animation(AppMotion.captureAware, value: isCreating)
        .animation(AppMotion.captureAware, value: aiStatusMessage)
        .animation(AppMotion.captureAware, value: aiTrace)
        .animation(AppMotion.hoverAware, value: isHovered)
        .animation(AppMotion.hoverAware, value: isFocused)
    }

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasDraft: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || priority != .medium
            || progress != .pending
            || isWeekly
    }

    private var captureStrokeColor: Color {
        if isFocused {
            return AppTheme.accent.opacity(0.36)
        }
        if isExpanded || isHovered {
            return AppTheme.accent.opacity(0.24)
        }
        return AppTheme.border.opacity(0.86)
    }

    private var parsedPreview: ParsedTodoInput {
        TodoQuickInputParser.parse(
            title: title,
            notes: notes,
            priority: priority,
            date: previewDate,
            progress: progress,
            isWeekly: isWeekly
        )
    }

    private func submitQuickRecord() {
        guard canCreate else { return }
        onCreate()
    }
}

struct QuickCapturePreview: View {
    let title: String
    let notes: String
    let priority: TodoPriority
    let progress: TodoProgress
    let date: Date
    let isWeekly: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title.isEmpty ? "待识别事项" : title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .frame(minWidth: 150, maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 5) {
                PreviewChip(text: priority.label, color: priority.displayColor, systemImage: "flag.fill")
                PreviewChip(text: progress.shortLabel, color: progress.displayColor, systemImage: progress.previewIcon)
                PreviewChip(text: previewDateText, color: dateColor, systemImage: "calendar")
                if isWeekly {
                    PreviewChip(text: "固定", color: AppTheme.mutedInk, systemImage: "repeat")
                }
                if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    PreviewChip(text: notes.trimmingCharacters(in: .whitespacesAndNewlines), color: AppTheme.mutedInk, systemImage: "text.alignleft")
                        .frame(maxWidth: 190)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 32)
        .padding(.trailing, 4)
    }

    private var previewDateText: String {
        let calendar = Calendar.current
        let timeText = timeSuffix(for: date, calendar: calendar)
        if calendar.isDateInToday(date) { return "今天\(timeText)" }
        if calendar.isDateInTomorrow(date) { return "明天\(timeText)" }
        if calendar.isDateInYesterday(date) { return "昨天\(timeText)" }
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return "\(month)/\(day)\(timeText)"
    }

    private var dateColor: Color {
        Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
            ? TodoPriority.high.displayColor
            : AppTheme.mutedInk
    }
}

struct PreviewChip: View {
    let text: String
    let color: Color
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.08), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.18), lineWidth: 1)
            )
    }
}
