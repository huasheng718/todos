import SwiftUI

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
