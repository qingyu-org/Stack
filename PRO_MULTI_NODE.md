# 1Panel Pro 多机与发布说明

本分支在 Mono Dash 上游基础上移除了内购与服务器数量限制，并增加了对
1Panel 专业版（XPack / Pro）多机管理的支持。本文说明实现方式、接口边界和
GitHub Actions 发布流程。

## 1. 多机路由

1Panel 主面板对 `/api/v2/*` 的请求按节点路由：

- `/api/v2/core/*`（`/api/v2/core/xpack/*` 除外）始终由主面板处理；
- 其余接口会读取 `CurrentNode` 请求头，把请求代理到对应子节点；
- 查询参数 `operateNode` 的优先级高于请求头，值为节点名（URL 编码）。

App 中的实现：

- `AuthInterceptor` 为每个请求统一写入
  `CurrentNode: Uri.encodeComponent(nodeName)`；
- 同时删除业务层历史遗留的 `operateNode=local` 查询参数，避免切节点后
  仍访问主面板；
- 每个 `(serverId, nodeName)` 拥有独立的 `DioClient`，切换节点只切换使用
  哪个客户端，不销毁其他节点的连接池；
- 终端、下载跟踪、进程 WebSocket 也使用当前节点（`operateNode` 查询参数 +
  `CurrentNode` 头）。

## 2. 数据模型

- `Server` 代表一个**主面板**，不是单个节点；
- `Server.nodes` 保存节点拓扑快照（`PanelNode`），包含 `local` 主节点；
- `Server.isPro` 是最近一次探测结果；
- `Server.editionOverride` 支持 `auto / pro / community` 手动覆盖；
- 当前选中的节点按面板保存在本地（`active_node_v1_<serverId>`），不参与
  WebDAV / iCloud 同步；节点拓扑也不会写入云同步 payload。

## 3. 自动探测

添加或编辑面板时，App 会：

1. 调用 `/api/v2/core/licenses/status`，`status == "Bound"` 视为专业版；
2. 调用 `POST /api/v2/core/nodes/list`，body `{"type":"all"}` 拉取节点；
3. 调用 `GET /api/v2/core/nodes/simple/all` 合并 CPU / 内存概览；
4. 接口 403/404 或网络失败时降级为社区版，不阻塞添加流程。

探测失败但确认是专业版时，可在面板编辑页把「面板版本」改为「专业版」，
专业版入口仍会显示，页面内部会给出接口不可用的原因。

## 4. 已接入的专业版接口

只读看板（页面会对未知字段做通用渲染，接口不可用时显示可恢复空态）：

- WAF：`GET /xpack/waf/status`、`GET /xpack/waf/stat`、
  `POST /xpack/waf/attack/stat`、`POST /xpack/waf/relation/stat`、
  `GET /xpack/waf/websites`、`POST /xpack/waf/log/search`、
  `POST /xpack/waf/cdn`
- 网站监控：`GET /xpack/monitor/status`、`POST /xpack/monitor/stat`、
  `POST /xpack/monitor/visitors`、`POST /xpack/monitor/visitors/loc`、
  `POST /xpack/monitor/qps`、`POST /xpack/monitor/trend`、
  `POST /xpack/monitor/rank`、`POST /xpack/monitor/websites`、
  `POST /xpack/monitor/logs/search`、`POST /xpack/monitor/logs/stat`
- 运维报表：`POST /core/ops-report/context`（body 显式带 `node`）、
  `POST /xpack/ops-report/snapshot`、`POST /xpack/ops-report/runs/search`
- 网站防篡改：`POST /xpack/tampers/search`、`/template/list`、
  `/template/search`、`/search/log`
- 资源同步：`POST /core/xpack/exchange/file|image|app|ssl`
- 节点：`/core/nodes/list`、`/core/nodes/simple/all`、
  `/dashboard/current/node`

WAF / 网站监控只做查看，不提供规则修改。运维报表只查看已有快照与历史记录，
不在手机上触发报表生成。

## 5. GitHub Actions

### CI

`.github/workflows/ci.yml`：

- Flutter `3.50.1`
- `flutter pub get` → `flutter gen-l10n` → `flutter analyze` → `flutter test`

### Release

`.github/workflows/release.yml` 在推送 `v*` tag 或手动 `workflow_dispatch`
时构建并发布：

- Android：通用 APK、三种 ABI APK（arm64-v8a / armeabi-v7a / x86_64）、AAB
- iOS：无签名 IPA（`flutter build ios --no-codesign` 后打包）
- Windows：x64 zip
- 产物统一附加到 GitHub Release

Android 签名需要的 Repository secrets：

| Secret | 说明 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | keystore 文件的 base64 |
| `ANDROID_KEYSTORE_PASSWORD` | storePassword |
| `ANDROID_KEY_ALIAS` | keyAlias |
| `ANDROID_KEY_PASSWORD` | keyPassword |

未配置 keystore 时，release 包会回退为 debug 签名，方便 fork 直接出包；
正式分发请务必配置以上 secrets。

本地生成 base64：

```bash
base64 -w 0 android/upload-keystore.jks
```

Windows 构建需要项目 `windows/CMakeLists.txt` 中的
`_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` 定义，因为部分
Windows 插件仍引用已弃用的 `<experimental/coroutine>`。

## 6. 已知限制

- 专业版接口的请求体在 1Panel 不同小版本之间可能变化。页面采用多候选
  请求 + 通用字段渲染，拿不到数据时展示空态而不是崩溃。
- 网站监控默认取站点列表中的第一个站点；更完整的站点切换器可后续补充。
- 现有终端 / 下载会话不会在切换节点时强制重连；新会话使用新节点。
- 无 Pro 面板实机时无法验证 WAF / 监控 / 报表字段，欢迎提供
  `doc.json` 或 HAR 以补齐精确 DTO。
