# VBO SkAgent — MCP Layer (v1.2.0+)

MCP (Model Context Protocol) transport cho VBO SkAgent — cho phép agent (Claude Code, Cursor, etc.) gọi trực tiếp `execute_ruby`, `reload_file`, `list_instances`, `get_console_output` mà không qua file polling.

> **Performance:** P50 ≈ 13ms (so với 500ms+ của file-based bridge — nhanh ~30 lần)

---

## Cấu trúc folder

```
mcp/
├── server.rb            # HTTP server V3 (TCPServer + UI.start_timer + accept_nonblock)
├── tools.rb             # 4 MCP tool definitions
├── console_capture.rb   # 3-layer output capture (StringIO + TracePoint + Exception.prepend)
├── instances.rb         # Global instances.json registry
├── vendor/              # Bundled gems (~1.2MB)
│   ├── mcp-0.13.0/
│   ├── json-schema-6.2.0/
│   ├── addressable-2.9.0/
│   └── public_suffix-7.0.5/
└── README.md            # File này
```

---

## Lifecycle

1. `loader.rb` gọi `McpServer.start` qua `UI.start_timer(1.5, false)` (nếu `Config.mcp_auto_start` = true)
2. `start` đọc `Config.mcp_port` (default `7891`), bind `TCPServer.new('127.0.0.1', port)`
3. Nếu port chiếm → fallback ephemeral (random port)
4. Sau bind: ghi `.port`, `info.json`, đăng ký vào `instances.json`
5. Khởi động `UI.start_timer(0.01)` — main loop drain max 3 connections/tick
6. Lazy MCP setup — chỉ load `mcp` gem khi nhận request đầu tiên `POST /mcp`

---

## Multi-Instance Handling

Nhiều SU chạy đồng thời → chỉ 1 instance chiếm được port preferred (7891), các instance sau fallback ephemeral.

**Files chia sẻ:**
- `%APPDATA%/VBO/SkAgent/instances.json` — danh sách tất cả instances đang chạy
- `%APPDATA%/VBO/SkAgent/mcp/.port` — port của instance ghi cuối (instance khởi động sau ghi đè)
- `%APPDATA%/VBO/SkAgent/mcp/info.json` — info chi tiết của instance ghi cuối

**Tool `list_instances` trả về:**
```json
{
  "total": 2,
  "multi_instance": true,
  "current": { "pid": 12345, "mcp_port": 7891, ... },
  "others":  [{ "pid": 67890, "mcp_port": 56432, ... }],
  "warning": "Multi-instance detected: 2 SketchUp instances..."
}
```

Khi `multi_instance == true`, agent BẮT BUỘC cảnh báo user trước khi tiếp tục thao tác.

---

## Endpoints

| Method | Path | Mục đích |
|--------|------|----------|
| `GET`  | `/health`   | Health check + status (port, uptime, version) |
| `POST` | `/mcp`      | MCP JSON-RPC endpoint (4 tools) |
| `POST` | `/shutdown` | Graceful shutdown |

---

## Bug Fixes Applied (từ LoadPlugins Phase 3)

1. **`format_execute` scope** — capture `method(:format_execute)` thành local var (MCP gem dùng `instance_exec` đổi `self`)
2. **Orphan TCPServer** — wrap post-bind init trong begin/rescue, close `@server` on fail
3. **TracePoint flooding** — `accept_nonblock(exception: false)` + thêm `IO::WaitReadable/WaitWritable/Errno::EAGAIN/EWOULDBLOCK` vào `IGNORE_CLASSES`

---

## Manual Test

```ruby
# Start
Sketchup.require File.join(__dir__, 'vbo_sk_agent', 'mcp', 'server')
VBO::SkAgent::McpServer.start
# => 7891 (or ephemeral)

# Status
VBO::SkAgent::McpServer.status
# => { running: true, port: 7891, ... }

# Stop
VBO::SkAgent::McpServer.stop
```

Test với curl:
```bash
curl http://127.0.0.1:7891/health
```

---

## Reference

Production-ready từ Load Plugins (workspace internal). Session log: `.agent/sessions/2026-04-26_loadplugins-phase3-production.md`
