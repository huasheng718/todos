import SwiftUI

struct HandbookEmptyState: View {
    let category: HandbookCategory?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: category?.icon ?? "book.closed")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 54, height: 54)
                .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text(category == nil ? "还没有手记" : "还没有\(category?.title ?? "")")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.ink)

            Text("在上方输入标题和内容，沉淀可复用的信息。")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.mutedInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 62)
    }
}

struct HandbookLoadingState: View {
    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .frame(width: 54, height: 54)
                .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text("正在载入手记")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.ink)

            Text("先打开工作台，手记数据稍后进入。")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.mutedInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 62)
    }
}

struct HandbookFilteredEmptyState: View {
    let filter: HandbookListFilter

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: filter.icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 52, height: 52)
                .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 17, style: .continuous))

            Text(filter.emptyText)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.ink)

            Text("切回全部，或在上方继续收集新的手记。")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.mutedInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 62)
    }
}
