import SwiftUI

struct ChannelListPanel: View {
    @EnvironmentObject private var vm: PlayerViewModel
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            TextField("搜索频道", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundColor(.white)
                .padding(8)
                .background(Color(white: 0.16))
                .cornerRadius(6)
                .padding(.horizontal, 8)
                .padding(.top, 8)

            List {
                ForEach(filtered, id: \.id) { ch in
                    Button {
                        selectChannel(ch)
                    } label: {
                        HStack {
                            Text(ch.name)
                                .foregroundColor(.white)
                                .font(.body)
                                .lineLimit(1)
                            Spacer()
                            if ch.sourceCount > 1 {
                                Text("\(ch.sourceCount)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .listRowSeparator(.hidden)
                    .listRowBackground(
                        (channelsIndex(for: ch) == vm.currentIndex)
                            ? Color(red: 0.035, green: 0.278, blue: 0.443)
                            : Color(white: 0.12)
                    )
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(white: 0.12))

            Text(vm.indicatorText.isEmpty
                 ? "已加载 \(vm.channels.count) 个频道"
                 : vm.indicatorText)
                .font(.caption2)
                .foregroundColor(.gray)
                .padding(4)
        }
        .background(Color(white: 0.12))
    }

    private var filtered: [Channel] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return vm.channels }
        return vm.channels.filter {
            $0.name.lowercased().contains(q) || $0.group.lowercased().contains(q)
        }
    }

    private func selectChannel(_ ch: Channel) {
        let ci = channelsIndex(for: ch)
        guard ci >= 0 else { return }
        vm.currentIndex = ci
        vm.currentSourceIndex = 0
        vm.panelVisible = false
        vm.playCurrent()
    }

    private func channelsIndex(for ch: Channel) -> Int {
        vm.channels.firstIndex(where: { $0.key == ch.key }) ?? -1
    }
}
