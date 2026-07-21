import SwiftUI

struct SourceManagementSheet: View {
    @EnvironmentObject private var vm: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var inputUrl = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    TextField("输入 m3u / m3u8 地址", text: $inputUrl)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    Button("添加") { add() }
                        .buttonStyle(.borderedProminent)
                }

                List {
                    ForEach(Array(vm.sourceUrls.enumerated()), id: \.offset) { (i, url) in
                        HStack {
                            Button {
                                vm.selectSource(url)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(url == vm.activeSourceUrl ? "●" : "○")
                                        .foregroundColor(url == vm.activeSourceUrl ? .blue : .gray)
                                        .font(.title3)
                                    Text(label(for: url))
                                        .lineLimit(1)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if url != DEFAULT_SOURCE_URL {
                                Button("删除", role: .destructive) {
                                    vm.deleteSourceUrl(url)
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        for i in offsets {
                            let url = vm.sourceUrls[i]
                            if url != DEFAULT_SOURCE_URL {
                                vm.deleteSourceUrl(url)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .padding()
            .navigationTitle("管理直播源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func label(for url: String) -> String {
        if url == DEFAULT_SOURCE_URL { return "默认源" }
        return url
    }

    private func add() {
        let url = inputUrl.trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty else { return }
        vm.selectSource(url)
        inputUrl = ""
        dismiss()
    }
}
