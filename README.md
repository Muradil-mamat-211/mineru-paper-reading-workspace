# MinerU Paper Reading Workspace

这是一个面向研究论文阅读的本地工作区。它把 PDF 论文、AutoDL 上的 MinerU 解析流程、下载后的 MinerU 结果，以及 Codex 的论文阅读 skill 串成一个可复用工作流：用户把 PDF 放进本地目录，Codex 自动调用脚本上传到 AutoDL 解析，再基于 MinerU 输出做预精读、总结、图文结合讲解或逐句精读。

## 项目目标

- 用 MinerU 把论文 PDF 转换为 Markdown、图片、JSON、版面 PDF 等结构化材料。
- 保留原始 PDF、layout PDF、图片和表格等上下文，避免只读纯文本造成图文割裂。
- 让 Codex 按固定读论文方法工作，尤其适合：
  - 预精读论文并判断是否值得继续精读；
  - 总结论文主线、贡献、章节和关键图表；
  - 对指定章节或全文逐句精读；
  - 读取已有 `mineru_result` 输出文件夹。

## 工作流概览

1. 用户手动启动 AutoDL 服务器，并确保 SSH key 登录可用。
2. 将论文 PDF 放入 `input_pdfs/`，或在请求中给出 PDF 路径。
3. Codex 运行本地脚本：

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\autodl_mineru_manual_pipeline.ps1
   ```

   指定 PDF 时：

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\autodl_mineru_manual_pipeline.ps1 -PdfPath ".\input_pdfs\paper.pdf"
   ```

4. 脚本上传 PDF 到 AutoDL，激活远端 MinerU 环境并运行：

   ```bash
   source /root/autodl-tmp/mineru_env/bin/activate
   mineru -p xxx.pdf -o /root/autodl-tmp/demo_1
   ```

5. 脚本把解析结果下载到 `mineru_result/<paper_name>/`。
6. Codex 根据 `.agents/skills/mineru-paper-reading/SKILL.md` 读取主 Markdown，并结合 PDF、图片、表格、公式和 JSON 做阅读输出。

## 目录结构

```text
.
├── AGENTS.md
├── README.md
├── .gitignore
├── .agents/
│   └── skills/
│       └── mineru-paper-reading/
│           └── SKILL.md
├── scripts/
│   ├── autodl_mineru_manual_pipeline.ps1
│   ├── autodl_config.example.json
│   └── autodl_config.json        # 本地私有配置，不提交
├── input_pdfs/                   # 本地 PDF 输入，不提交
└── mineru_result/                # MinerU 解析结果，不提交
```

## 配置方式

复制示例配置：

```powershell
Copy-Item .\scripts\autodl_config.example.json .\scripts\autodl_config.json
```

然后编辑 `scripts/autodl_config.json`，填写自己的 AutoDL SSH 连接信息和本地 SSH 私钥路径。默认建议保持：

```json
"mineru_args": ""
```

除非明确需要，否则不要额外添加 `-m`、`-l`、`-l en` 或 `-l latin`。当前脚本按用户已验证成功的远端执行方式设计：先 `source` 激活虚拟环境，再调用 `mineru` 命令。

## 运行方式

使用 `input_pdfs/` 中最新 PDF：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\autodl_mineru_manual_pipeline.ps1
```

指定 PDF：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\autodl_mineru_manual_pipeline.ps1 -PdfPath ".\input_pdfs\LoRA.pdf"
```

指定论文名：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\autodl_mineru_manual_pipeline.ps1 -PdfPath ".\input_pdfs\LoRA.pdf" -PaperName "LoRA"
```

完成后，主要 Markdown 通常位于：

```text
mineru_result/<paper_name>/hybrid_auto/<paper_name>.md
```

## Codex 使用方式

这个仓库为 Codex 提供两层指令：

- `AGENTS.md`：项目级规则，定义默认 PDF 选择、AutoDL MinerU 管线、输出目录、安全边界和读论文默认行为。
- `.agents/skills/mineru-paper-reading/SKILL.md`：论文阅读 skill 的完整规则，是读论文任务的权威流程。

你可以这样向 Codex 提问：

```text
帮我预精读 input_pdfs 里最新的论文，我想知道是否值得后续精读。
```

```text
帮我精读 LoRA.pdf，我关注方法和贡献。
```

```text
逐句精读第 3 节。
```

```text
读取 mineru_result/LoRA 的输出，图文结合讲解这篇论文。
```

## Skills 整体结构

当前项目内置一个本地 skill：

```text
.agents/skills/mineru-paper-reading/SKILL.md
```

它的核心职责是读取 MinerU 输出文件夹，而不是只读取 PDF。skill 会优先使用主 Markdown 作为阅读主线，同时把原始 PDF、layout PDF、图片、表格、公式和 JSON 作为辅助证据。

这个 skill 主要支持两种模式：

- 预精读决策报告：按 Keshav 的 How to Read a Paper 方法做 first pass、second pass 和轻量 third-pass 检查，输出论文为什么写、写了什么、全文主线、贡献、章节/小节概括、关键图表解释、总结和后续精读建议。
- 逐句精读：对指定章节或论文分批输出一句原文、一句翻译、一句解析，并把相关图表、公式、表格和参考文献信息融合到对应句子的解释中。

默认不展示 source inventory、Five Cs 或关键参考文献线索，除非用户明确要求调试或参考文献分析。

## 常见问题

**找不到 SSH 私钥怎么办？**

检查 `scripts/autodl_config.json` 中的 `ssh_private_key` 是否指向本机真实私钥路径，并确认该私钥已配置 AutoDL 服务器登录。

**脚本提示 SSH 测试失败怎么办？**

先确认 AutoDL 实例已启动，再单独测试脚本输出中提示的 `ssh -i ...` 命令。不要优先重装 MinerU，先看真实 SSH 错误。

**MinerU 解析失败怎么办？**

读取脚本输出中的 MinerU 原始报错。除非错误明确要求，否则不要升级核心依赖、重建环境或额外添加语言参数。

**为什么不提交 `input_pdfs` 和 `mineru_result`？**

PDF 论文可能有版权限制，MinerU 输出也可能包含论文全文、图像和中间文件。它们应保留在本地，不进入 GitHub 仓库。

**为什么 README 中只说明 `autodl_config.example.json`？**

真实 `autodl_config.json` 可能包含个人路径、远端连接信息或其他本地配置，应由每个使用者在本机自行创建。

## 安全说明

- 不要提交 PDF、MinerU 输出、日志、`.env`、GitHub token、AutoDL 密码、SSH 私钥或任何凭据。
- `scripts/autodl_config.json` 是本地私有配置，已被 `.gitignore` 排除。
- `scripts/autodl_config.example.json` 只能保留占位符和非敏感默认值。
- 提交前建议运行：

  ```powershell
  git status --short
  git diff --cached --name-only
  ```

  确认只包含计划上传的文件。
