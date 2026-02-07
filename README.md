# LangChain Skills Agent

使用 LangChain 1.0 + LangGraph 构建的 Skills Agent，演示 Anthropic Skills **三层加载机制**的底层原理。

通过实际代码展示 Skills 如何在 Agent 中运作：启动时注入元数据 → 按需加载完整指令 → 执行脚本而不污染上下文窗口。

## 特性

- **Extended Thinking** — 显示模型的思考过程（蓝色面板），让推理链路透明可见
- **流式输出** — Token 级实时响应，支持 CLI 和 Web 双端
- **工具调用可视化** — 实时显示工具名称、参数、执行结果及状态
- **三层 Skills 加载** — Level 1 元数据注入 → Level 2 指令加载 → Level 3 脚本执行
- **Web UI** — React + FastAPI + SSE，支持多轮对话与 Skills 面板

## 快速开始

### 1. 克隆并安装

```bash
git clone https://github.com/NanmiCoder/skills-agent-proto.git
cd skills-agent-proto
uv sync
```

### 2. 配置环境变量

创建 `.env` 文件：

```bash
# 必填：Anthropic API Key
ANTHROPIC_AUTH_TOKEN=sk-xxx

# 可选：使用第三方代理地址
# ANTHROPIC_BASE_URL=https://api.anthropic.com
```

### 3. 交互式验证

```bash
uv run langchain-skills --interactive
```

## Skills 三层加载机制

核心设计：让大模型成为真正的"智能体"——自己阅读指令、发现脚本、决定执行。

| 层级 | 时机 | Token 消耗 | 内容 |
|------|------|------------|------|
| **Level 1** | 启动时 | ~100/Skill | YAML frontmatter（name + description）注入 system prompt |
| **Level 2** | 触发时 | <5000 | `load_skill` 工具读取 SKILL.md 完整指令 |
| **Level 3** | 执行时 | 仅输出 | `bash` 工具执行脚本，脚本代码不进入上下文 |

### 三层加载演示

启动后可以观察到完整的三层加载过程：

**Level 1：启动时 — 元数据注入**

```
✓ Discovered 6 skills
  - tornado-erp-module-dev
  - web-design-guidelines
  - news-extractor
  ...
```

Skills 的 name + description 已注入 system prompt，模型知道有哪些能力可用。

**Level 2：请求匹配时 — 指令加载**

```
You: 总结这篇文章 https://mp.weixin.qq.com/s/ohsU1xRrYu9xcVD7qu5lNw

● load_skill(news-extractor)
  └ # Skill: news-extractor
    ## Instructions
    从主流新闻平台提取文章内容...
```

用户请求匹配到 Skill 描述，模型主动调用 `load_skill` 获取完整指令。

**Level 3：执行时 — 脚本运行**

```
● Bash(uv run .../extract_news.py https://mp.weixin.qq.com/s/ohsU1xRrYu9xcVD7qu5lNw)
  └ [OK]
    [SUCCESS] Saved: output/xxx.md
```

模型根据指令执行脚本，**脚本代码不进入上下文，只有输出进入**。

## CLI 命令

```bash
# 交互式模式（推荐）
uv run langchain-skills --interactive

# 单次执行
uv run langchain-skills "列出当前目录"

# 禁用 Thinking（降低延迟）
uv run langchain-skills --no-thinking "执行 pwd"

# 查看发现的 Skills
uv run langchain-skills --list-skills

# 查看 System Prompt（Level 1 注入内容）
uv run langchain-skills --show-prompt
```

## Web Demo（React + FastAPI + SSE）

### 一键启动（推荐）

```bash
# Linux / macOS
./start.sh

# Windows
start.bat
```

启动脚本会自动执行：
- `uv sync` — 后端依赖安装
- `npm install` — 前端依赖安装（`web/` 目录）
- 启动 FastAPI 后端（默认端口 8000）
- 启动 Vite 开发服务器（默认端口 5173）

### 手动启动

**启动后端 API（端口 8000）：**

```bash
uv run langchain-skills-web
```

等价命令：

```bash
uv run uvicorn langchain_skills.web_api:app --reload --port 8000
```

**启动前端（端口 5173）：**

```bash
cd web
npm install
npm run dev
```

如需修改后端地址：

```bash
VITE_API_BASE_URL=http://127.0.0.1:8000 npm run dev
```

### Web 交互能力

- 打开页面即显示已发现 Skills（name / description / path）
- 底部输入框支持多轮对话和手动新建 thread
- SSE 实时显示 `thinking`、`tool_call`、`tool_result`、`text`、`done`、`error` 事件
- 当调用 `load_skill` 时，UI 会明确标记当前识别到的 Skill
- 支持命令：
  - `/skills` — 显示可用技能列表
  - `/prompt` — 显示当前 system prompt

## 项目结构

```
skills-agent-proto/
├── src/langchain_skills/         # 核心包
│   ├── agent.py                  # LangChain Agent（Extended Thinking）
│   ├── cli.py                    # CLI 入口（Rich 流式输出）
│   ├── web_api.py                # FastAPI Web API（SSE）
│   ├── tools.py                  # 工具定义（load_skill, bash, read_file, write_file, glob, grep, edit, list_dir）
│   ├── skill_loader.py           # Skills 发现和加载
│   └── stream/                   # 流式处理模块
│       ├── emitter.py            # 事件发射器
│       ├── tracker.py            # 工具调用追踪（支持增量 JSON）
│       ├── formatter.py          # 结果格式化器
│       └── utils.py              # 常量和工具函数
├── web/                          # React 前端
│   └── src/
│       ├── App.tsx               # 主应用组件
│       ├── components/           # UI 组件（ChatTimeline, Composer, SkillPanel, ToolCallItem）
│       ├── state/                # 状态管理（chatReducer）
│       ├── lib/                  # SSE 通信层
│       └── types/                # TypeScript 类型定义
├── tests/                        # 单元测试
│   ├── test_stream.py            # 流式处理测试
│   ├── test_cli.py               # CLI 测试
│   ├── test_tools.py             # 工具测试
│   └── test_web_api.py           # Web API 测试
├── docs/                         # 文档
│   ├── skill_introduce.md        # Skills 机制详解
│   ├── langchain_agent_skill.md  # LangChain Skills 模式说明
│   └── architecture_sequence.md  # 架构时序图
├── .claude/skills/               # 示例 Skills
│   └── news-extractor/           # 新闻提取技能
│       ├── SKILL.md              # Skill 指令（YAML frontmatter + 正文）
│       ├── scripts/              # 可执行脚本
│       └── references/           # 参考文档
├── start.sh                      # 一键启动脚本（Linux/macOS）
├── start.bat                     # 一键启动脚本（Windows）
└── pyproject.toml                # 项目配置与依赖
```

## 流式处理架构

```
agent.py: stream_events()
  │  使用 stream_mode="messages" 获取 LangChain 流式输出
  ▼
stream/tracker.py: ToolCallTracker
  │  追踪工具调用，处理增量 JSON (input_json_delta)
  ▼
stream/emitter.py: StreamEventEmitter
  │  生成标准化事件 (thinking / text / tool_call / tool_result / done)
  ▼
stream/formatter.py: ToolResultFormatter
  │  格式化输出，检测 [OK] / [FAILED] 前缀
  ▼
cli.py / web_api.py
  │  CLI: Rich Live Display 渲染到终端
  │  Web: FastAPI SSE 推送到前端
```

## 运行测试

```bash
uv run python -m pytest tests/ -v
```

## 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `ANTHROPIC_AUTH_TOKEN` / `ANTHROPIC_API_KEY` | API Key | 必填 |
| `ANTHROPIC_BASE_URL` | 代理地址 | 官方 API |
| `CLAUDE_MODEL` | 模型名称 | `claude-sonnet-4-5-20250929` |
| `MAX_TOKENS` | 最大 tokens | `16000` |
| `MAX_TURNS` | Agent 最大交互轮次 | `20` |
| `SKILLS_WEB_HOST` | Web 服务监听地址 | `127.0.0.1` |
| `SKILLS_WEB_PORT` | Web 服务端口 | `8000` |
| `SKILLS_WEB_RELOAD` | 热重载 | `false` |

## Skills 目录结构

```
.claude/skills/skill-name/
├── SKILL.md          # 必需：YAML frontmatter + 指令
├── scripts/          # 可选：可执行脚本
├── references/       # 可选：参考文档
└── assets/           # 可选：模板和资源
```

Skills 搜索路径（优先级从高到低）：
1. `.claude/skills/`（项目级）
2. `~/.claude/skills/`（用户级）

## 参考文档

- [Skills 机制详解](./docs/skill_introduce.md) — Anthropic Skills 三层加载原理
- [LangChain Skills 模式](./docs/langchain_agent_skill.md) — LangChain 官方 Skills 架构说明
- [架构时序图](./docs/architecture_sequence.md) — 系统交互流程

## License

MIT
