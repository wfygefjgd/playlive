import SwiftUI
import AVKit

struct ContentView: View {
    @EnvironmentObject private var vm: PlayerViewModel

    // 数字键选台
    @State private var numberInput = ""
    @State private var numberInputTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.clear

            VideoPlayerView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)

            if !vm.panelVisible {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { vm.showFloat() }
                    .simultaneousGesture(playerDragGesture())
                    .simultaneousGesture(doubleTapGesture())
            }

            if vm.panelVisible && !vm.locked {
                GeometryReader { geo in
                    let w = max(geo.size.width, 1)
                    HStack(spacing: 0) {
                        ChannelListPanel()
                            .frame(width: min(300, w * 0.32))
                            .frame(maxHeight: .infinity)
                            .background(Color(white: 0.12).opacity(0.96))
                        Color.black.opacity(0.25)
                            .contentShape(Rectangle())
                            .onTapGesture { vm.panelVisible = false }
                    }
                }
                .zIndex(50)
            }

            if vm.isBootstrapping {
                VStack(spacing: 10) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                    Text(vm.bootstrapMessage)
                        .foregroundColor(.white.opacity(0.9))
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .background(Color.black.opacity(0.55))
                .cornerRadius(12)
                .zIndex(9)
            } else if vm.channels.isEmpty {
                VStack(spacing: 12) {
                    Text("暂无频道")
                        .foregroundColor(.white)
                    Button("重新加载源") { vm.retryLoadSources() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(24)
                .background(Color.black.opacity(0.55))
                .cornerRadius(12)
                .zIndex(8)
            }

            ChannelOSDView(text: vm.channelOSD)
                .allowsHitTesting(false)
                .zIndex(5)
            if !vm.isBootstrapping {
                IndicatorView(text: vm.indicatorText)
                    .allowsHitTesting(false)
                    .zIndex(5)
            }

            // 数字键选台输入显示
            if !numberInput.isEmpty {
                VStack {
                    Text(numberInput)
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(16)
                    Text("按数字键选台")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .zIndex(70)
            }

            if vm.showFloatOverlay || vm.locked {
                floatingButtons
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                    .zIndex(60)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .ignoresSafeArea(.all, edges: .all)
        .persistentSystemOverlays(.hidden)
        .defersSystemGestures(on: .all)
        .onAppear {
            vm.startup()
            NotificationCenter.default.post(name: .tvPlayerNeedsRelayout, object: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            vm.pause()
            cancelNumberInput()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            vm.resume()
            vm.onAppBecameActive()
            NotificationCenter.default.post(name: .tvPlayerNeedsRelayout, object: nil)
        }
        .sheet(isPresented: $vm.showSourceSheet) {
            SourceManagementSheet()
                .environmentObject(vm)
        }
        .modifier(KeyboardHandler(handleKeyPress: handleKeyPress))
    }

    private var floatingButtons: some View {
        FloatingButtons(
            panelVisible: vm.panelVisible,
            locked: vm.locked,
            onTogglePanel: { vm.togglePanel() },
            onLongPanel: { vm.showSourceSheet = true },
            onToggleLock: { vm.toggleLock() },
            onLongLock: { vm.confirmDeleteLine() }
        )
        .alert("删除线路", isPresented: $vm.showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) { vm.doDeleteLine() }
        } message: {
            Text("确定删除当前线路？")
        }
    }

    private func playerDragGesture() -> some Gesture {
        DragGesture(minimumDistance: 24)
            .onChanged { value in
                guard !vm.locked, !vm.panelVisible else { return }
                let w = max(UIScreen.main.bounds.width, UIScreen.main.bounds.height, 1)
                let sx = value.startLocation.x
                let dy = value.translation.height
                guard abs(dy) > abs(value.translation.width), sx > w * 0.65 else { return }
                vm.handleVolumeDrag(translationHeight: dy, ended: false)
            }
            .onEnded { value in
                guard !vm.locked, !vm.panelVisible else { return }
                let w = max(UIScreen.main.bounds.width, UIScreen.main.bounds.height, 1)
                let sx = value.startLocation.x
                let dx = value.translation.width
                let dy = value.translation.height
                if sx > w * 0.65 {
                    vm.handleVolumeDrag(translationHeight: dy, ended: true)
                }
                if abs(dx) > abs(dy), abs(dx) > 50 {
                    if dx > 0 { vm.switchSource(direction: -1) }
                    else { vm.switchSource(direction: 1) }
                    return
                }
                if abs(dy) > abs(dx), abs(dy) > 40, sx >= w * 0.30, sx <= w * 0.65 {
                    if dy < 0 { vm.nextChannel() }
                    else { vm.prevChannel() }
                }
            }
    }

    private func doubleTapGesture() -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                guard !vm.locked else { return }
                vm.togglePanel()
            }
    }

    // MARK: - 数字键选台

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        guard !vm.panelVisible else { return .ignored }

        if let digit = press.characters.first(where: { $0.isNumber }) {
            appendNumber(digit)
            return .handled
        }

        if press.key == .return {
            confirmNumberInput()
            return .handled
        }

        if press.key == .escape {
            cancelNumberInput()
            return .handled
        }
        if press.key == .delete {
            if !numberInput.isEmpty {
                numberInput.removeLast()
                if numberInput.isEmpty {
                    cancelNumberInput()
                }
                return .handled
            }
        }

        if press.key == .upArrow {
            vm.prevChannel()
            return .handled
        }
        if press.key == .downArrow {
            vm.nextChannel()
            return .handled
        }

        if press.key == .leftArrow {
            vm.switchSource(direction: -1)
            return .handled
        }
        if press.key == .rightArrow {
            vm.switchSource(direction: 1)
            return .handled
        }

        if press.characters == " " {
            if vm.player.isPlaying {
                vm.player.pause()
            } else {
                vm.player.resume()
            }
            return .handled
        }

        return .ignored
    }

    private func appendNumber(_ digit: Character) {
        numberInput.append(digit)
        numberInputTask?.cancel()
        numberInputTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { confirmNumberInput() }
        }
        // 超过 4 位自动确认
        if numberInput.count >= 4 {
            confirmNumberInput()
        }
    }

    private func confirmNumberInput() {
        guard let num = Int(numberInput), num > 0 else {
            cancelNumberInput()
            return
        }
        let index = num - 1
        if index < vm.channels.count {
            vm.selectChannel(vm.channels[index])
        } else if !vm.channels.isEmpty {
            vm.selectChannel(vm.channels[vm.channels.count - 1])
        }
        cancelNumberInput()
    }

    private func cancelNumberInput() {
        numberInput = ""
        numberInputTask?.cancel()
        numberInputTask = nil
    }
}

private struct KeyboardHandler: ViewModifier {
    @EnvironmentObject private var vm: PlayerViewModel
    let handleKeyPress: (KeyPress) -> KeyPress.Result

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.onKeyPress { press in
                guard !vm.panelVisible else { return .ignored }
                return handleKeyPress(press)
            }
        } else {
            content.background(
                KeyCommandView(onKeyCommand: { key in
                    guard !vm.panelVisible else { return false }
                    return Self.handleCommand(key, handleKeyPress: handleKeyPress, vm: vm)
                })
            )
        }
    }

    @MainActor
    static func handleCommand(_ key: String, handleKeyPress: (KeyPress) -> KeyPress.Result, vm: PlayerViewModel) -> Bool {
        return false
    }
}

private struct KeyCommandView: UIViewControllerRepresentable {
    let onKeyCommand: (String) -> Bool

    func makeUIViewController(context: Context) -> KeyCommandViewController {
        let vc = KeyCommandViewController()
        vc.onKeyCommand = onKeyCommand
        return vc
    }

    func updateUIViewController(_ uiViewController: KeyCommandViewController, context: Context) {
        uiViewController.onKeyCommand = onKeyCommand
    }
}

private final class KeyCommandViewController: UIViewController {
    var onKeyCommand: ((String) -> Bool)?

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override var keyCommands: [UIKeyCommand]? {
        return [
            UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(handleUp:)),
            UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(handleDown:)),
            UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], action: #selector(handleLeft:)),
            UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [], action: #selector(handleRight:)),
            UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(handleReturn:)),
            UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(handleEscape:)),
            UIKeyCommand(input: UIKeyCommand.inputDelete, modifierFlags: [], action: #selector(handleDelete:)),
            UIKeyCommand(input: " ", modifierFlags: [], action: #selector(handleSpace:)),
            UIKeyCommand(input: "0", modifierFlags: [], action: #selector(handleDigit:)),
            UIKeyCommand(input: "1", modifierFlags: [], action: #selector(handleDigit:)),
            UIKeyCommand(input: "2", modifierFlags: [], action: #selector(handleDigit:)),
            UIKeyCommand(input: "3", modifierFlags: [], action: #selector(handleDigit:)),
            UIKeyCommand(input: "4", modifierFlags: [], action: #selector(handleDigit:)),
            UIKeyCommand(input: "5", modifierFlags: [], action: #selector(handleDigit:)),
            UIKeyCommand(input: "6", modifierFlags: [], action: #selector(handleDigit:)),
            UIKeyCommand(input: "7", modifierFlags: [], action: #selector(handleDigit:)),
            UIKeyCommand(input: "8", modifierFlags: [], action: #selector(handleDigit:)),
            UIKeyCommand(input: "9", modifierFlags: [], action: #selector(handleDigit:)),
        ]
    }

    @objc private func handleUp(_ sender: UIKeyCommand) { _ = onKeyCommand?("up") }
    @objc private func handleDown(_ sender: UIKeyCommand) { _ = onKeyCommand?("down") }
    @objc private func handleLeft(_ sender: UIKeyCommand) { _ = onKeyCommand?("left") }
    @objc private func handleRight(_ sender: UIKeyCommand) { _ = onKeyCommand?("right") }
    @objc private func handleReturn(_ sender: UIKeyCommand) { _ = onKeyCommand?("return") }
    @objc private func handleEscape(_ sender: UIKeyCommand) { _ = onKeyCommand?("escape") }
    @objc private func handleDelete(_ sender: UIKeyCommand) { _ = onKeyCommand?("delete") }
    @objc private func handleSpace(_ sender: UIKeyCommand) { _ = onKeyCommand?("space") }
    @objc private func handleDigit(_ sender: UIKeyCommand) { _ = onKeyCommand?(sender.input ?? "") }
}
