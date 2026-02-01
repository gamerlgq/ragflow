# 本地知识库与 Cursor MCP 集成 - 搭建与操作说明

本文档说明如何在本仓库中搭建 RAGFlow、创建「流量相关文章」等本地知识库，并配置 MCP 供 Cursor 与在线大模型调用。

## 一、已完成的配置

- **Docker Compose**：`docker/docker-compose.yml` 已启用 MCP 服务（`ragflow-cpu` 与 `ragflow-gpu` 的 `command` 均包含 `--enable-mcpserver` 等参数）。
- **MCP 端口**：`docker/.env` 中 `SVR_MCP_PORT=9382`，与容器内 9382 映射。
- **Cursor MCP**：项目根目录 `.cursor/mcp.json` 已配置为连接 `http://127.0.0.1:9382/mcp`（Streamable HTTP）。

你仍需完成：替换 API Key、设置 `vm.max_map_count`、启动服务、在 Web 中创建数据集并上传文档。

---

## 二、环境与前置条件

- **系统**：x86（ARM64 需自建镜像，见官方文档）。
- **资源**：CPU ≥ 4 核，RAM ≥ 16 GB，磁盘 ≥ 50 GB。
- **软件**：Docker ≥ 24.0.0，Docker Compose ≥ v2.26.1。

### vm.max_map_count（必做）

Elasticsearch 需要 `vm.max_map_count` ≥ 262144。

- **Linux**  
  - 检查：`sysctl vm.max_map_count`  
  - 设置：`sudo sysctl -w vm.max_map_count=262144`  
  - 持久化：在 `/etc/sysctl.conf` 中增加一行 `vm.max_map_count=262144`

- **macOS（Docker Desktop）**  
  ```bash
  docker run --rm --privileged --pid=host alpine sysctl -w vm.max_map_count=262144
  ```  
  重启后会失效，需每次启动 Docker 后重跑，或按 [RAGFlow 文档](https://ragflow.io/docs/) 配置 LaunchDaemon plist 持久化。

- **Windows（WSL2）**  
  在 WSL 中执行：`wsl -d docker-desktop -u root` 后运行 `sysctl -w vm.max_map_count=262144`；持久化可配置 `%USERPROFILE%\.wslconfig` 的 `kernelCommandLine`。

---

## 三、替换 API Key 并启动 RAGFlow

1. **先启动一次服务（不启用 MCP 也可）并获取 API Key**
   - 若尚未获取 API Key，可暂时在 `docker-compose.yml` 中改回仅 `--enable-adminserver` 的 command，启动后登录 Web 获取 Key。
   - 浏览器访问 `http://localhost`（或本机 IP），完成初始化与登录。
   - 点击右上角头像 → **API** → 创建并复制 API Key（形如 `ragflow-xxxxx`）。

2. **在 docker-compose 中填入 API Key**
   - 编辑 `docker/docker-compose.yml`，将两处  
     `--mcp-host-api-key=ragflow-REPLACE_WITH_YOUR_API_KEY`  
     替换为你的真实 API Key（例如 `--mcp-host-api-key=ragflow-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`）。
   - 若只使用 CPU 版，只需修改 `ragflow-cpu` 下的那一处；使用 GPU 则修改 `ragflow-gpu` 下的那一处。

3. **启动服务**
   ```bash
   cd docker
   docker compose -f docker-compose.yml up -d
   ```
   或使用脚本（在已安装 Docker 的终端中）：
   ```bash
   cd docker && ./start_ragflow.sh
   ```

4. **确认 RAGFlow 与 MCP 已就绪**
   ```bash
   docker logs -f docker-ragflow-cpu-1
   ```
   - 应看到主服务 “Running on all addresses (0.0.0.0)” 及 9380。
   - 应看到 “Starting MCP Server on 0.0.0.0:9382” 和 “Uvicorn running on http://0.0.0.0:9382”。

---

## 四、创建「流量相关文章」知识库

1. **配置 LLM（若尚未配置）**  
   头像 → **Model providers**：填写 Chat/Embedding 所用 LLM 的 API Key；头像 → **System Model Settings** 选择默认模型。

2. **创建数据集**  
   - 顶部 **Dataset** → **Create dataset**，名称例如「流量知识库」。
   - 在 **Configuration** 页选择 Parser、Chunk 模板、Embedding 模型（一旦用该 Embedding 解析过文件，不可再改）。

3. **上传流量相关文章**  
   - 进入该数据集 → **+ Add file** → **Local files**。
   - 支持 PDF、DOC/DOCX、TXT、MD、MDX、CSV、XLSX、PPT、图片等；上传你的流量相关文档。

4. **解析与优化**  
   - 每个文件右侧点击「播放」开始解析。
   - 解析完成后可进入 **Chunk** 页为 chunk 补充关键词或问题，在 **Retrieval testing** 中验证检索效果。

5. **记录数据集 ID**  
   创建 Chat 或通过 API/MCP 检索时需指定 `dataset_ids`；在数据集详情或 URL 中可看到 ID，建议记下。

---

## 五、Cursor 使用本地知识库（MCP）

- 本项目已包含 **项目级** MCP 配置：`.cursor/mcp.json`，内容为连接 `http://127.0.0.1:9382/mcp`。
- 确保 RAGFlow 与 MCP 已按上文启动且日志正常。
- 在 Cursor 中打开本仓库，重启或重新加载 MCP 后，在 MCP/工具列表中应看到 **ragflow** 及 **retrieve** 工具。
- 在对话中直接提问与「流量」或知识库相关的问题，Agent 会通过 `retrieve` 从你配置的数据集中检索并回答。

若希望所有项目都能用该知识库，可将 `.cursor/mcp.json` 中的 `ragflow` 配置复制到全局配置 `~/.cursor/mcp.json`。

### 使用 SSE 端点（可选）

若希望使用 Legacy SSE 而非 Streamable HTTP，将 `.cursor/mcp.json` 中的 `url` 改为：

```json
"url": "http://127.0.0.1:9382/sse"
```

---

## 六、参考链接

| 目的           | 链接 |
|----------------|------|
| RAGFlow 快速入门 | [Get started](https://ragflow.io/docs/) |
| 获取 API Key   | [Acquire RAGFlow API key](https://ragflow.io/docs/acquire_ragflow_api_key) |
| MCP 启动与安全  | [Launch RAGFlow MCP server](https://ragflow.io/docs/launch_mcp_server) |
| MCP 能力说明    | [RAGFlow MCP server overview](https://ragflow.io/docs/dev/mcp_server) |
| Cursor MCP 配置 | [Cursor MCP Docs](https://cursor.com/docs/context/mcp) |
