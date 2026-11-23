# Route Studio

<img src="Resources/AppIcon-master.png" width="136" alt="Route Studio icon">

原生 macOS iPhone 定位模拟工具。通过 USB 连接开发设备，在地图上编辑路线，按设定配速回放位置，并支持暂停、继续和恢复真实定位。

A native macOS route editor and USB location simulator for development iPhones. Built with SwiftUI, MapKit, and pymobiledevice3.

## 下载与使用

在 [Releases](https://github.com/cheng01023-ops/route-studio/releases) 下载 `RouteStudio-Mac.zip`，完整解压后双击 **启动定位工具.app**。两个 App 应保持在同一文件夹。

1. USB 连接并解锁 iPhone，信任这台 Mac，开启开发者模式。
2. 应用会自动连接单台 USB iPhone；多台设备时手动选择目标。
3. 查看路线和配速，点击顶部“开始”。打开应用和插入 USB 只会准备连接。
4. 暂停、继续或结束回放；路线完成或正常退出时会尝试清除模拟位置，请在手机地图核对。

安装包已内置 Python 运行组件。首次准备开发镜像可能需要联网。预编译 App 为本地签名版本，未经过 Apple 公证。

详细步骤、路线文件与坐标说明见 [使用指南](docs/USAGE.zh-CN.md)。

## 功能

- 地图搜索、点击选点、拖动与排序、删除和撤销。
- 配速按分钟/公里设置；闭合路线、多圈回放、距离和预计时长。
- 离线预览、固定位置、USB 设备回放、暂停和继续。
- 默认地图描线示例、JSON/GPX 导入导出、上次路线与配速记忆。
- 国内高德底图 GCJ-02 与设备 WGS84 双向转换；路线文件始终使用 WGS84。
- 单调时钟调度、连接中断提示、恢复定位按钮和运行日志。
- 中文原生启动入口及完整图标资源。

## 支持范围

| 项目 | 要求 / 验证范围 |
| --- | --- |
| Mac | Apple Silicon（M 系列），构建目标 macOS 15+ |
| iPhone | 定位连接代码面向 iOS 17+；真机流程已在 iOS 27.0.1 验证 |
| 开发模式 | 需要 iPhone 信任电脑并启用开发者模式 |
| 地图 | 使用 MapKit；国内高德底图需保持坐标校准开启 |

系统、设备或第三方应用版本变化后可能需要重新验证。回放轨迹能否被其他应用接受取决于其实现。

## 从源码构建

需要 Apple Silicon Mac、Xcode / Command Line Tools，以及 Python 3.14。正常使用已打包 App 不需要安装这些开发依赖。

```sh
git clone https://github.com/cheng01023-ops/route-studio.git
cd route-studio
python3 build.py
```

构建会安装锁定的依赖、运行 Python 与 Swift 测试、打包定位组件、编译两个 App，并进行本地签名。

签名会使用系统临时目录中的短暂副本，避免 iCloud 等同步目录添加的 Finder 元数据干扰；完成后自动清理临时副本。

产物位于 `dist/`：

```text
dist/
  Route Studio.app
  启动定位工具.app
  启动定位工具.command
```

源码目录中也可以双击 `launch.command` 打开构建结果。已有虚拟环境可用 `ROUTE_STUDIO_PYTHON` 指定；`ROUTE_STUDIO_BUILD` 和 `ROUTE_STUDIO_OUTPUT` 可覆盖构建与输出目录。

构建后生成完整分发包：

```sh
python3 package_release.py
```

分发包为 `dist/RouteStudio-Mac.zip`，含 App、源码 ZIP、公开使用文档、示例路线及许可文件。构建目录、虚拟环境、Git 元数据和本机记录不会进入源码包。

## 开发结构

```text
Sources/           SwiftUI / MapKit 界面、连接与启动状态、坐标转换
backend/           Python 设备桥接、路线插值与回放时钟
tests/             路线、恢复逻辑、文件格式和启动流程测试
tools/             中文启动器和示例路线生成工具
Resources/         默认路线、原始图标、ICNS 和图标设计说明
examples/          可导入的 JSON / GPX 示例
docs/              使用指南、公开验证范围和第三方源码来源
Licenses/          第三方许可全文
```

界面通过私有 stdin/stdout JSON 行协议与独立 Python 进程通信，控制端不监听网络端口。定位连接使用 pymobiledevice3 的 `PreferredRsdTunnel`、`DvtProvider` 和 `LocationSimulation`。路线和地图校准设置仅保存在本机应用偏好中；设备标识用于当前连接，不硬编码进项目。

测试范围见 [VALIDATION](docs/VALIDATION.md)。问题反馈请提交 [Issue](https://github.com/cheng01023-ops/route-studio/issues)，并提供系统版本、错误信息和复现步骤；上传日志前请去除个人信息。

## 许可

项目源码采用 **GPL-3.0-or-later**，参见 [LICENSE](LICENSE)。第三方组件保留各自许可，参见 [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.txt)、[许可全文](Licenses/) 和 [对应源码来源](docs/THIRD_PARTY_SOURCES.md)。

本工具使用设备开发定位服务，适用于自有或获授权设备的位置服务开发与测试。项目与 Apple、微信或任何第三方服务无隶属关系。
