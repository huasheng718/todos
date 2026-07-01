import SwiftUI

struct AccountSettingsContent: View {
    var body: some View {
        accountSummaryCard
    }

    private var accountSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                Circle()
                    .fill(AppTheme.accentSoft)
                    .overlay(
                        Text("我")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppTheme.accent)
                    )
                    .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text("个人空间")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.ink)
                    Text("本地账户模式，商业化能力边界已预留。")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Text("本地")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(AppTheme.accentSoft, in: Capsule())
            }

            Divider()
                .overlay(AppTheme.hairline.opacity(0.72))

            VStack(spacing: 0) {
                accountBoundaryRow(
                    icon: "person.crop.circle",
                    title: "个人空间",
                    detail: "当前数据保存在本机；后续登录、云同步和团队空间会接入这里。"
                )
                Divider()
                    .overlay(AppTheme.hairline.opacity(0.58))
                accountBoundaryRow(
                    icon: "creditcard",
                    title: "会员与账单",
                    detail: "保留订阅、账单和发票入口；当前不连接支付，不采集付款信息。"
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.adaptiveWhite(0.76), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.border.opacity(0.78))
        )
    }

    private func accountBoundaryRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 28, height: 28)
                .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Text(detail)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .frame(maxWidth: 540, alignment: .leading)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
    }
}
