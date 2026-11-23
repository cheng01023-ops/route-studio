import SwiftUI
import MapKit

private let teal = Color(red: 0.02, green: 0.47, blue: 0.44)

struct ContentView: View {
    @ObservedObject var model: StudioModel
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var showLog = false
    @State private var confirmClear = false
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            quickStartBar
            Divider()
            HSplitView {
                mapPanel.frame(minWidth: 570, idealWidth: 800)
                sidebar.frame(minWidth: 345, idealWidth: 370, maxWidth: 440)
            }
            Divider()
            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(teal)
        .frame(minWidth: 1000, minHeight: 720)
        .alert("操作提示", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button("知道了") { model.error = nil } } message: { Text(model.error ?? "") }
        .confirmationDialog("清空这条路线？", isPresented: $confirmClear) { Button("清空路线", role: .destructive) { model.clear() } } message: { Text("可以通过撤销找回。") }
        .sheet(isPresented: $model.showSetup) { setupSheet }
        .sheet(isPresented: $showLog) { logSheet }
    }
    var quickStartBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.route.name.isEmpty ? "我的路线" : model.route.name).font(.system(size: 14, weight: .semibold))
                Text("\(Int(model.route.totalDistance.rounded())) 米  ·  配速 \(durationText(model.route.paceSeconds))/公里  ·  预计 \(durationText(model.route.duration))")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            if model.active {
                Text("\(Int(model.travelled.rounded())) / \(Int(model.playbackDistance.rounded())) 米")
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(teal)
                Button("结束并恢复定位") { model.send("stop") }.disabled(model.commandBusy)
            } else {
                Text(model.connected ? "USB 已就绪" : (model.state == "connecting" ? "正在准备设备…" : "接上 USB 后自动连接"))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Button { model.quickStart() } label: {
                Label(model.quickStartTitle, systemImage: model.active && model.state != "paused" ? "pause.fill" : "play.fill")
                    .frame(minWidth: 160).padding(.vertical, 5)
            }.buttonStyle(.borderedProminent).disabled(!model.canQuickStart)
        }.padding(.horizontal, 24).padding(.vertical, 13)
        .background(teal.opacity(0.035))
    }
    var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath").font(.system(size: 24, weight: .semibold)).foregroundStyle(teal)
                .frame(width: 46, height: 46).background(teal.opacity(0.09), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 3) {
                Text("Route Studio").font(.system(size: 21, weight: .bold, design: .rounded))
                Text("画一条路线，设定你的配速").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Label(model.statusTitle, systemImage: model.connected ? "iphone.gen3.radiowaves.left.and.right" : "map")
                .font(.system(size: 12, weight: .medium)).padding(.horizontal, 12).padding(.vertical, 8)
                .background(teal.opacity(0.08), in: Capsule()).foregroundStyle(teal)
            Button { model.showSetup = true } label: { Image(systemName: "questionmark.circle").font(.title3) }.buttonStyle(.plain).help("连接与使用说明")
        }.padding(.horizontal, 24).padding(.vertical, 15)
    }
    var mapPanel: some View {
        ZStack(alignment: .topLeading) {
            MapEditor(model: model)
            VStack(alignment: .leading, spacing: 10) {
                searchBar
                if !model.searchResults.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(model.searchResults.enumerated()), id: \.offset) { _, item in
                            Button {
                                model.focusRequest = item.placemark.coordinate; model.searchResults = []
                            } label: {
                                HStack {
                                    Image(systemName: "mappin.circle.fill").foregroundStyle(teal)
                                    VStack(alignment: .leading) { Text(item.name ?? "地点").font(.system(size: 12, weight: .medium)); Text(item.placemark.title ?? "").font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1) }
                                    Spacer()
                                }.padding(10).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            Divider()
                        }
                    }.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                HStack(spacing: 0) {
                    Button { model.editMode.toggle() } label: { Label(model.editMode ? "点选画路线" : "浏览地图", systemImage: model.editMode ? "pencil.tip.crop.circle.fill" : "hand.draw") }.disabled(model.locked)
                    Divider().frame(height: 18).padding(.horizontal, 10)
                    Button { model.fitRevision += 1 } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }.help("显示整条路线")
                    Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward") }.disabled(model.undoStack.isEmpty || model.locked).help("撤销")
                    Menu {
                        Toggle("国内高德底图校准", isOn: $model.mainlandMap)
                        Text("仅在国际 Apple 底图下关闭")
                    } label: { Image(systemName: "slider.horizontal.3") }.disabled(model.locked).help("地图坐标校准")
                        .onChange(of: model.mainlandMap) { _, _ in model.fitRevision += 1 }
                }.buttonStyle(.plain).font(.system(size: 12, weight: .medium)).padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }.padding(18).frame(maxWidth: 390)
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.active ? "\(model.mode == "preview" ? "离线预览" : "设备回放") · 第 \(model.currentLap) / \(model.route.loops) 圈" : (model.editMode ? "点击地图添加途经点" : "拖动地图浏览，切换画路线后选点"))
                            .font(.system(size: 12, weight: .semibold))
                        Text(model.active ? "当前位置按设定配速更新" : "拖动标记可调整位置 · 直线连接途经点")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }.padding(13).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    Spacer()
                    if model.route.points.isEmpty { Button("载入示例") { model.loadExample() }.buttonStyle(.borderedProminent).disabled(model.locked) }
                }.padding(18)
            }.allowsHitTesting(!model.active)
        }
    }
    var searchBar: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("搜索地点或学校", text: $model.searchText).textFieldStyle(.plain).onSubmit { model.searchPlace() }
            if model.searching { ProgressView().controlSize(.small) }
            else if !model.searchText.isEmpty { Button { model.searchText = ""; model.searchResults = [] } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain) }
        }.padding(13).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                deviceSection
                Divider()
                routeSection
                Divider()
                paceSection
                Divider()
                playbackSection
            }.padding(22)
        }.background(Color(nsColor: .controlBackgroundColor))
    }
    func sectionTitle(_ number: String, _ title: String) -> some View {
        HStack(spacing: 8) {
            Text(number).font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(teal).frame(width: 21, height: 21).background(teal.opacity(0.1), in: Circle())
            Text(title).font(.system(size: 13, weight: .semibold))
        }
    }
    var deviceSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack { sectionTitle("1", "连接 iPhone"); Spacer(); Button { model.scan() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain).disabled(model.scanning || model.locked).help("刷新 USB 设备") }
            if model.devices.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "cable.connector").font(.title2).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 3) { Text(model.scanning ? "正在查找设备…" : "等待 USB 连接").font(.system(size: 12, weight: .medium)); Text("解锁手机，并选择信任此电脑").font(.system(size: 10)).foregroundStyle(.secondary) }
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
            } else {
                Picker("设备", selection: $model.selectedDevice) {
                    ForEach(model.devices) { device in Text(device.name + (device.version.isEmpty ? "" : " · iOS \(device.version)")).tag(device.id) }
                }.labelsHidden().disabled(model.locked || (model.connected && (model.simulated || model.uncertain)))
                Button(model.state == "connecting" ? "正在连接…" : (model.connected ? "重新连接" : "连接所选设备")) { model.connect() }
                    .frame(maxWidth: .infinity).disabled(model.locked || (model.connected && (model.simulated || model.uncertain)))
            }
            Button("首次连接设置") { model.showSetup = true }.font(.system(size: 11)).buttonStyle(.link)
        }
    }
    var routeSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack { sectionTitle("2", "编辑路线"); Spacer(); Text("\(model.route.points.count) 个点").font(.system(size: 10)).foregroundStyle(.secondary) }
            TextField("路线名称", text: $model.route.name).textFieldStyle(.roundedBorder).disabled(model.locked)
            HStack {
                Button { model.importRoute() } label: { Label("导入", systemImage: "square.and.arrow.down") }.disabled(model.locked)
                Menu { Button("保存路线 JSON") { model.exportRoute(gpx: false) }; Button("导出 GPX（含配速时间）") { model.exportRoute(gpx: true) } } label: { Label("保存 / 导出", systemImage: "square.and.arrow.up") }.disabled(model.route.points.isEmpty)
                Spacer()
                Button(role: .destructive) { confirmClear = true } label: { Image(systemName: "trash") }.disabled(model.locked || model.route.points.isEmpty).help("清空路线")
            }.controlSize(.small)
            if !model.route.points.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 5) {
                        ForEach(Array(model.route.points.enumerated()), id: \.element.id) { i, point in
                            HStack(spacing: 8) {
                                Text("\(i + 1)").font(.system(size: 10, weight: .bold)).frame(width: 22, height: 22).background(teal.opacity(0.1), in: Circle()).foregroundStyle(teal)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(i == 0 ? "起点" : (i == model.route.points.count - 1 ? "末点" : "途经点")).font(.system(size: 11, weight: .medium))
                                    Text(String(format: "%.6f, %.6f", point.latitude, point.longitude)).font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                if model.selectedPoint == point.id {
                                    Button { model.reorder(point.id, by: -1) } label: { Image(systemName: "chevron.up") }.disabled(i == 0 || model.locked)
                                    Button { model.reorder(point.id, by: 1) } label: { Image(systemName: "chevron.down") }.disabled(i == model.route.points.count - 1 || model.locked)
                                    Button { model.deleteSelected() } label: { Image(systemName: "xmark") }.disabled(model.locked)
                                }
                            }.buttonStyle(.plain).font(.system(size: 10)).padding(7)
                                .background(model.selectedPoint == point.id ? teal.opacity(0.08) : Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 8))
                                .contentShape(Rectangle()).onTapGesture { model.selectedPoint = point.id }
                        }
                    }
                }.frame(maxHeight: 170)
            }
            DisclosureGroup("输入经纬度（WGS84）") {
                VStack(spacing: 7) {
                    HStack { TextField("纬度", text: $latitude); TextField("经度", text: $longitude) }.textFieldStyle(.roundedBorder)
                    Button("添加途经点") {
                        guard let lat = Double(latitude), let lon = Double(longitude), RoutePoint(latitude: lat, longitude: lon).valid else { model.error = "请输入有效的经纬度。"; return }
                        let point = CLLocationCoordinate2D(latitude: lat, longitude: lon); model.add(point); model.focusRequest = model.mapCoordinate(RoutePoint(point))
                    }.disabled(model.locked)
                }.padding(.top, 7)
            }.font(.system(size: 11))
            Toggle("闭合路线，末点连回起点", isOn: $model.route.closed).font(.system(size: 11)).disabled(model.locked)
                .onChange(of: model.route.closed) { _, closed in if !closed { model.route.loops = 1 } }
            if model.route.closed { Stepper("循环 \(model.route.loops) 圈", value: $model.route.loops, in: 1...1000).font(.system(size: 11)).disabled(model.locked) }
            if model.selected != nil {
                Button("将手机定位到选中点") { model.holdSelected() }.font(.system(size: 11)).disabled(!model.connected || model.locked)
            }
        }
    }
    var paceSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle("3", "设置配速")
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Picker("分钟", selection: Binding(get: { Int(model.route.paceSeconds) / 60 }, set: { model.route.paceSeconds = Double(max(30, min(3600, $0 * 60 + Int(model.route.paceSeconds) % 60))) })) {
                    ForEach(0...60, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                }.labelsHidden().frame(width: 75)
                Text(":").font(.title3)
                Picker("秒", selection: Binding(get: { Int(model.route.paceSeconds) % 60 }, set: { model.route.paceSeconds = Double(max(30, min(3600, Int(model.route.paceSeconds) / 60 * 60 + $0))) })) {
                    ForEach(0...59, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                }.labelsHidden().frame(width: 75)
                Text("分钟 / 公里").font(.system(size: 11)).foregroundStyle(.secondary)
            }.disabled(model.locked)
            HStack(spacing: 8) {
                metric("总距离", String(format: "%.2f", model.route.totalDistance / 1000), "km")
                metric("预计时长", durationText(model.route.duration), "")
            }
        }
    }
    func metric(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) { Text(value).font(.system(size: 20, weight: .semibold, design: .rounded)).monospacedDigit(); Text(unit).font(.system(size: 10)).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(11).background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
    }
    var playbackSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle("4", "回放路线")
            if model.active || model.elapsed > 0 {
                ProgressView(value: model.playbackDistance > 0 ? min(1, model.travelled / model.playbackDistance) : 0)
                HStack { Text(String(format: "%.2f km", model.travelled / 1000)); Spacer(); Text("\(durationText(model.elapsed)) / \(durationText(model.playbackDuration))") }.font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
            }
            if model.active {
                HStack {
                    Button { model.send(model.state == "paused" ? "resume" : "pause") } label: { Label(model.state == "paused" ? "继续" : "暂停", systemImage: model.state == "paused" ? "play.fill" : "pause.fill").frame(maxWidth: .infinity) }.disabled(model.commandBusy)
                    Button { model.send("stop") } label: { Label("结束", systemImage: "stop.fill").frame(maxWidth: .infinity) }.disabled(model.commandBusy)
                }.buttonStyle(.bordered)
            } else {
                Button { model.play(preview: false) } label: { Label("开始设备回放", systemImage: "play.fill").frame(maxWidth: .infinity).padding(.vertical, 4) }
                    .buttonStyle(.borderedProminent).disabled(!model.canPlay || !model.connected)
                Button { model.play(preview: true) } label: { Label("离线预览路线", systemImage: "play.rectangle").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered).disabled(!model.canPlay || model.simulated || model.uncertain)
            }
            Button { model.send("restore") } label: { Label("恢复真实定位", systemImage: "location.fill").frame(maxWidth: .infinity) }
                .buttonStyle(.bordered).disabled(!model.connected || model.commandBusy || model.state == "connecting")
            Text(model.connected ? "设备回放会改变手机报告的位置，路线结束时自动发送恢复指令。" : "离线预览仅在地图展示移动，连接设备后可回放到手机。")
                .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
    var footer: some View {
        HStack(spacing: 9) {
            Circle().fill((model.uncertain || model.state == "error") ? Color.orange : teal).frame(width: 6, height: 6)
            Text(model.message).font(.system(size: 10)).lineLimit(2)
            Spacer()
            Button("运行日志") { showLog = true }.buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(.secondary)
        }.padding(.horizontal, 20).padding(.vertical, 10)
    }
    var setupSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("连接你的 iPhone").font(.title2.bold())
            Text("1. 使用支持数据传输的 USB 线连接 Mac 和 iPhone。\n\n2. 解锁 iPhone，在手机上点“信任此电脑”。\n\n3. 在 iPhone 设置 → 隐私与安全性中开启“开发者模式”，按提示重启并确认。若看不到该选项，先用 Xcode 的设备窗口与手机配对。\n\n4. 回到应用，刷新设备列表并点击连接。首次准备开发镜像时需要联网。\n\n5. 先离线预览，再验证设备回放；结束后在手机地图检查真实定位。")
                .font(.system(size: 13)).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            Divider()
            Text("路线使用 WGS84 经纬度，途经点之间按直线连接。导入 GPX 时使用轨迹形状，配速由右侧设置决定。小程序是否接收并认可轨迹，需要在真机上验证。")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            HStack { Spacer(); Button("知道了") { model.showSetup = false }.keyboardShortcut(.defaultAction) }
        }.padding(28).frame(width: 490)
    }
    var logSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("运行日志").font(.title2.bold())
            ScrollView { Text(model.events.joined(separator: "\n")).font(.system(size: 11, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(height: 350)
            HStack { Button("复制") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(model.events.joined(separator: "\n"), forType: .string) }; Spacer(); Button("关闭") { showLog = false }.keyboardShortcut(.defaultAction) }
        }.padding(24).frame(width: 620)
    }
}
