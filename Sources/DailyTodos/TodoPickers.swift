import SwiftUI

struct PriorityPicker: View {
    @Binding var priority: TodoPriority

    var body: some View {
        Picker("优先级", selection: $priority) {
            ForEach(TodoPriority.allCases) { priority in
                Text(priority.label).tag(priority)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(width: 82)
    }
}

struct ProgressPicker: View {
    @Binding var progress: TodoProgress

    var body: some View {
        Picker("推进状态", selection: $progress) {
            ForEach(TodoProgress.allCases) { progress in
                Text(progress.label).tag(progress)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(width: 96)
    }
}
