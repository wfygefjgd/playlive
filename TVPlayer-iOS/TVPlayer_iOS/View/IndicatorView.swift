import SwiftUI

/// 指示器视图 — 居中显示状态/错误信息，带弹性动画
struct IndicatorView: View {
    let text: String

    var body: some View {
        if !text.isEmpty {
            Text(text)
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .medium))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.65))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: text)
        }
    }
}
