import SwiftUI

struct SearchField: View {
    @Binding var text: String
    var placeholder = "搜索标题或备注"

    var body: some View {
        WorkspaceSearchField(text: $text, placeholder: placeholder, isFocused: nil)
    }
}

struct AllTodosViewModePicker: View {
    @Binding var selection: AllTodosViewMode

    var body: some View {
        WorkspaceSegmentedControl(selection: $selection)
            .frame(width: 232)
    }
}

extension AllTodosViewMode: WorkspaceSegmentedOption {}
