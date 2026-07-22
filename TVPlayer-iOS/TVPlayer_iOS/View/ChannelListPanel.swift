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

            ScrollViewReader { proxy in
                List {
                    ForEach(vm.sections(search: searchText)) { section in
                        Section {
                            ForEach(section.channels, id: \.id) { ch in
                                channelRow(ch)
                                    .id(ch.key)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(rowBackground(for: ch))
                            }
                        } header: {
                            Text(section.title)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .textCase(nil)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color(white: 0.12))
                .onAppear { scrollToCurrent(proxy) }
                .onChange(of: vm.panelVisible) { visible in
                    if visible { scrollToCurrent(proxy) }
                }
                .onChange(of: vm.currentIndex) { _ in
                    if vm.panelVisible { scrollToCurrent(proxy) }
                }
            }

            Text(vm.indicatorText.isEmpty
                 ? "已加载 \(vm.channels.count) 个频道"
                 : vm.indicatorText)
                .font(.caption2)
                .foregroundColor(.gray)
                .padding(4)
        }
        .background(Color(white: 0.12))
    }

    private func scrollToCurrent(_ proxy: ScrollViewProxy) {
        guard let key = vm.currentChannel?.key else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(key, anchor: .center)
            }
        }
    }

    private func rowBackground(for ch: Channel) -> Color {
        if vm.channels.firstIndex(where: { $0.key == ch.key }) == vm.currentIndex {
            return Color(red: 0.035, green: 0.278, blue: 0.443)
        }
        return Color(white: 0.12)
    }

    private func channelRow(_ ch: Channel) -> some View {
        HStack(spacing: 8) {
            Button { vm.selectChannel(ch) } label: {
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button { vm.toggleFavorite(for: ch) } label: {
                Text(vm.isFavorite(ch) ? "★" : "☆")
                    .foregroundColor(vm.isFavorite(ch) ? .yellow : .gray)
                    .font(.body)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}
