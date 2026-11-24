import SwiftUI

private let dualTeal = Color(red: 0.02, green: 0.47, blue: 0.44)

struct DualContentView: View {
    @ObservedObject var model: DualStudioModel
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "iphone.gen3.radiowaves.left.and.right").font(.system(size: 25)).foregroundStyle(dualTeal)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Route Studio Dual").font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("两台 iPhone · 两条独立路线 · 各自配速").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { model.refreshDevices() } label: { Label("刷新设备", systemImage: "arrow.clockwise") }
                    .disabled(model.batchBusy || model.sessions.allSatisfy { $0.locked })
                Button { model.current.showSetup = true } label: { Image(systemName: "questionmark.circle") }.buttonStyle(.plain)
            }.padding(.horizontal, 24).padding(.top, 17).padding(.bottom, 12)
            HStack(spacing: 12) {
                DualChannelCard(dual: model, session: model.a, channel: 0)
                DualChannelCard(dual: model, session: model.b, channel: 1)
            }.padding(.horizontal, 24)
            HStack(spacing: 9) {
                Button("一起连接") { Task { await model.connectBoth() } }.disabled(!model.canConnectBoth)
                Button { Task { await model.startBoth() } } label: { Label("一起开始", systemImage: "play.fill") }
                    .buttonStyle(.borderedProminent).disabled(!model.canStartBoth)
                Button(model.batchPauseTitle) { Task { await model.pauseOrResumeBoth() } }.disabled(!model.canPauseOrResumeBoth)
                Button("全部结束并恢复") { Task { await model.stopBoth() } }.disabled(model.batchBusy)
                Spacer()
                Button("复制当前路线到 \(model.name(1 - model.activeChannel))") { model.copyCurrentRoute() }.disabled(!model.canCopyRoute)
            }.controlSize(.small).padding(.horizontal, 24).padding(.top, 12)
            HStack(spacing: 8) {
                if model.batchBusy { ProgressView().controlSize(.mini) }
                Text(model.batchMessage).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2)
                Spacer()
                Text("正在查看 / 编辑通道 \(model.name(model.activeChannel))").font(.system(size: 10, weight: .medium)).foregroundStyle(dualTeal)
            }.padding(.horizontal, 24).padding(.vertical, 10)
            Divider()
            ContentView(model: model.current, embeddedInDual: true)
                .id(model.activeChannel).disabled(model.batchBusy)
        }
        .background(Color(nsColor: .windowBackgroundColor)).tint(dualTeal)
        .frame(minWidth: 1100, minHeight: 850)
        .alert("双设备操作提示", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("知道了") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
}

private struct DualChannelCard: View {
    @ObservedObject var dual: DualStudioModel
    @ObservedObject var session: StudioModel
    let channel: Int
    private var selected: Bool { dual.activeChannel == channel }
    private var options: [DeviceInfo] { dual.availableDevices(for: channel) }
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Text(dual.name(channel)).font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white).frame(width: 25, height: 25).background(dualTeal, in: RoundedRectangle(cornerRadius: 7))
                Text(session.statusTitle).font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(session.uncertain || session.state == "error" ? Color.orange : dualTeal)
                Spacer()
                if session.active {
                    Text("\(Int(session.travelled.rounded())) m · \(durationText(session.elapsed))").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                }
                Button(selected ? "正在编辑" : "查看 / 编辑") { dual.activeChannel = channel }
                    .buttonStyle(.bordered).controlSize(.mini).tint(selected ? dualTeal : .secondary)
            }
            HStack(spacing: 8) {
                Picker("通道 \(dual.name(channel)) 设备", selection: Binding(get: { session.selectedDevice }, set: { dual.assignDevice($0, to: channel) })) {
                    Text("选择 iPhone").tag("")
                    ForEach(options) { device in
                        Text("\(device.name) · \(device.id.suffix(6))").tag(device.id)
                    }
                    if !session.selectedDevice.isEmpty && !options.contains(where: { $0.id == session.selectedDevice }) {
                        Text("所选设备未发现 · \(session.selectedDevice.suffix(6))").tag(session.selectedDevice)
                    }
                }.labelsHidden().disabled(!session.canChangeDevice || dual.batchBusy)
                Button(session.state == "connecting" ? "连接中…" : "连接所选设备") {
                    Task { await dual.connectChannel(channel) }
                }.disabled(!session.canConnectAssigned || dual.batchBusy)
                if session.connected {
                    Button("断开") { Task { await dual.disconnectChannel(channel) } }
                        .disabled(!session.canChangeDevice || dual.batchBusy)
                }
            }.controlSize(.small)
            HStack(spacing: 8) {
                Text("实际连接：\(dual.deviceLabel(session.connectedDeviceID))")
                if session.connected && session.connectedDeviceID != session.selectedDevice {
                    Text("请连接新选择").foregroundStyle(.orange)
                }
                Spacer()
                Text("配速 \(durationText(session.route.paceSeconds))/km").monospacedDigit()
            }.font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? dualTeal.opacity(0.055) : Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? dualTeal.opacity(0.55) : Color.primary.opacity(0.07), lineWidth: selected ? 1.5 : 1))
    }
}
