import SwiftUI

struct AccountContextSidebar: View {
    @Binding var isSecondarySidebarCollapsed: Bool

    var body: some View {
        Group {
            if isSecondarySidebarCollapsed {
                CollapsedContextRail(title: "账户", isCollapsed: $isSecondarySidebarCollapsed)
                    .frame(width: collapsedSecondarySidebarWidth)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    WorkspaceContextHeader(
                        title: "账户",
                        subtitle: "空间、会员、账单",
                        isCollapsed: $isSecondarySidebarCollapsed
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        SidebarSectionLabel("边界")
                        accountRow(
                            title: "个人空间",
                            subtitle: "当前版本只展示本地空间边界"
                        )
                        accountRow(
                            title: "会员与账单",
                            subtitle: "保留商业化入口，不连接支付"
                        )
                    }
                    .padding(.horizontal, 17)
                    .padding(.top, 12)

                    Spacer(minLength: 0)
                }
                .frame(width: secondarySidebarWidth)
                .frame(maxHeight: .infinity, alignment: .topLeading)
                .background(AppTheme.workspaceTokens.contextSidebar)
            }
        }
    }

    private func accountRow(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.workspaceTokens.textPrimary)
            Text(subtitle)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.workspaceTokens.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.workspaceTokens.contentSurface.opacity(0.52))
        )
    }
}

struct AccountModuleView: View {
    var body: some View {
        WorkspaceContentContainer {
            ContentHeader(
                title: "账户",
                subtitle: "个人空间、订阅和 Billing 边界"
            )
        } toolbar: {
            ContentToolbar {
                Label("商业化能力占位", systemImage: "creditcard")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.mutedInk)
            }
        } bodyContent: {
            VStack(alignment: .leading, spacing: 14) {
                Label("账户系统尚未启用", systemImage: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Text("当前版本保留账户、空间和 Billing 的产品边界，不连接远端服务，不处理支付。")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.workspaceSurface)
        }
    }
}
