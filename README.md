# MinerU Paper Reading Skill

这是一个面向论文阅读的 Codex + MinerU 工作流项目。它的目标不是简单地“把 PDF 变成文本”，而是把论文 PDF 解析成更适合大模型阅读的结构化材料，再让 Codex 按固定的论文阅读方法完成预精读、图文结合讲解和逐句精读。

本项目适合以下场景：

- 想快速判断一篇论文是否值得继续精读；
- 想让 Codex 先给出论文主旨、章节结构、贡献和图表解释；
- 想对论文某一节或全文做逐句精读；
- 想让图、表、公式和正文解释结合在一起，而不是分开阅读；
- 想把 PDF 论文阅读流程做成可复用的自动化 pipeline。

---

## 为什么需要 MinerU？

直接把 PDF 扔给大模型阅读，经常会遇到几个问题：

1. PDF 的版面结构复杂，标题、正文、脚注、公式、图表、参考文献容易混在一起。
2. 图表和正文之间的对应关系容易丢失。
3. 公式、表格、图片可能无法被普通文本抽取完整保留。
4. 长论文直接阅读时上下文太长，模型容易遗漏关键信息。
5. 如果只复制 PDF 文本，论文的逻辑层级、图表位置和引用信息会被破坏。

MinerU 的作用是把 PDF 解析成更适合后续处理的结构化输出。它可以把论文转换成 Markdown，并同时保留图片、表格、公式、JSON、layout PDF 等辅助材料。这样 Codex 在阅读论文时，不是只面对一大段纯文本，而是可以围绕主 Markdown，把图表、公式和 PDF 原始版面一起作为证据进行解释。

简单来说：

```text
PDF 论文
  ↓
MinerU 解析
  ↓
Markdown + images + tables + formulas + JSON + layout PDF
  ↓
Codex 使用 mineru-paper-reading skill 进行论文阅读
```

---

## 项目整体流程

```text
1. 用户把论文 PDF 放到本地 input_pdfs 文件夹
        ↓
2. Codex 运行本地 PowerShell pipeline
        ↓
3. pipeline 通过 scp 把 PDF 上传到 AutoDL 服务器
        ↓
4. 服务器激活 MinerU 环境并运行 MinerU
        ↓
5. MinerU 把 PDF 解析成 Markdown 和相关资源
        ↓
6. pipeline 把解析结果下载回本地 mineru_result 文件夹
        ↓
7. Codex 使用 mineru-paper-reading skill 阅读解析结果
```

当前版本默认 AutoDL 服务器需要用户手动开机。开机后，Codex 可以自动完成上传、解析、下载和阅读。

---

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
│   └── autodl_config.json
├── input_pdfs/
└── mineru_result/
```

各部分作用如下：

| 路径 | 作用 |
|---|---|
| `AGENTS.md` | 给 Codex 的项目级指令，告诉它遇到 PDF 阅读任务时如何运行 pipeline、如何调用 skill |
| `.agents/skills/mineru-paper-reading/SKILL.md` | 论文阅读 skill 的具体规则，定义预精读、逐句精读、图文结合讲解等工作方式 |
| `scripts/autodl_mineru_manual_pipeline.ps1` | 本地 PowerShell pipeline，用于上传 PDF、远程运行 MinerU、下载解析结果 |
| `scripts/autodl_config.example.json` | 配置模板，展示需要配置哪些字段 |
| `scripts/autodl_config.json` | 本地实际配置文件，用于记录自己的服务器地址、端口、私钥路径等 |
| `input_pdfs/` | 放置待解析的 PDF |
| `mineru_result/` | 存放 MinerU 下载回本地的解析结果 |

---

## 配置说明

使用前需要准备一个本地配置文件：

```powershell
Copy-Item .\scripts\autodl_config.example.json .\scripts\autodl_config.json
```

然后编辑：

```text
scripts/autodl_config.json
```

示例结构如下：

```json
{
  "remote_base": "/root/autodl-tmp",
  "remote_input": "/root/autodl-tmp/input",
  "remote_output": "/root/autodl-tmp/demo_1",
  "local_input_dir": "input_pdfs",
  "local_result_dir": "mineru_result",
  "mineru_args": "",
  "ssh_host": "connect.example.seetacloud.com",
  "ssh_port": "41084",
  "ssh_private_key": "C:\\Users\\YOUR_NAME\\.ssh\\autodl_mineru_ed25519",
  "mineru_venv_dir": "/root/autodl-tmp/mineru_env",
  "mineru_bin": "/root/autodl-tmp/mineru_env/bin/mineru",
  "mineru_venv_activate": "/root/autodl-tmp/mineru_env/bin/activate"
}
```

其中最重要的是：

- `ssh_host`：AutoDL 提供的 SSH 连接域名；
- `ssh_port`：AutoDL 提供的 SSH 端口；
- `ssh_private_key`：本地 SSH 私钥路径；
- `remote_input`：服务器上接收 PDF 的目录；
- `remote_output`：服务器上 MinerU 输出结果的目录；
- `local_input_dir`：本地 PDF 输入目录；
- `local_result_dir`：本地解析结果保存目录；
- `mineru_venv_activate`：服务器上 MinerU 虚拟环境的激活脚本。

默认情况下：

```json
"mineru_args": ""
```

也就是说，pipeline 会复刻已经验证成功的 MinerU 调用方式：

```bash
source /root/autodl-tmp/mineru_env/bin/activate
mineru -p xxx.pdf -o /root/autodl-tmp/demo_1
```

---

## 如何运行 pipeline

在 PowerShell 中进入项目目录：

```powershell
cd D:\skills_demo\demo_1
```

处理指定 PDF：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\autodl_mineru_manual_pipeline.ps1 -PdfPath "D:\skills_demo\demo_1\input_pdfs\LoRA.pdf"
```

如果不指定 PDF，pipeline 会自动选择 `input_pdfs` 中最近修改的 PDF：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\autodl_mineru_manual_pipeline.ps1
```

运行成功后，输出一般会出现在：

```text
mineru_result/<paper_name>/hybrid_auto/<paper_name>.md
```

例如：

```text
mineru_result/LoRA/hybrid_auto/LoRA.md
```

---

## 如何让 Codex 自动执行

本项目的重点是让 Codex 读取 `AGENTS.md` 后自动完成 pipeline 调用。

在 VS Code 中打开项目根目录后，你可以直接对 Codex 说：

```text
帮我预精读 LoRA.pdf，我想知道它的核心思想、方法脉络，以及是否值得后续精读。
```

Codex 应该自动完成：

```text
1. 找到 input_pdfs/LoRA.pdf
2. 运行 scripts/autodl_mineru_manual_pipeline.ps1
3. 等待 MinerU 解析完成
4. 下载结果到 mineru_result/LoRA
5. 找到 hybrid_auto/LoRA.md
6. 使用 mineru-paper-reading skill 进行预精读
```

如果你没有指定 PDF，Codex 会默认处理 `input_pdfs` 中最新的 PDF。

---

## 论文阅读 skill 的能力

本项目的核心 skill 是：

```text
.agents/skills/mineru-paper-reading/SKILL.md
```

它主要支持两种模式。

### 1. 预精读模式

适合在正式精读前快速判断论文价值。输出包括：

- 为什么写这篇论文；
- 这篇论文解决什么问题；
- 这篇论文写了什么；
- 全文主线；
- 核心贡献；
- 每章每节概括；
- 关键图表解释；
- 文章总结；
- 是否值得后续继续精读。

### 2. 逐句精读模式

适合已经确定要深入阅读的论文。输出包括：

- 一句原文；
- 一句翻译；
- 一句解析；
- 术语解释；
- 逻辑作用；
- 相关图表、表格、公式融合解释；
- 每节总结；
- 每章解读；
- 全文解析。

---

## 图文结合阅读原则

这个 workflow 的一个重要设计是：不要把正文和图表分开讲。

当正文提到 Figure、Table、Equation 或 Algorithm 时，Codex 需要在 MinerU 输出中定位对应资源，并把它们融合进当前段落或句子的解释中。

也就是说，阅读输出不应该是：

```text
先总结正文
最后单独列出所有图表
```

而应该是：

```text
讲到某一段正文时，立刻解释它对应的图、表、公式或算法。
```

这可以让论文阅读更接近真实精读过程。

---

## 如何在 README 中添加图片

如果你想在 README 里加入项目流程图或截图，可以这样做。

### 第一步：创建图片文件夹

在项目根目录下创建：

```text
assets/
```

### 第二步：把图片放进去

例如：

```text
assets/workflow.png
```

### 第三步：在 README 中引用图片

Markdown 写法如下：

```markdown
![Workflow](assets/workflow.png)
```

如果想控制展示宽度，可以写成：

```html
<p align="center">
  <img src="assets/workflow.png" alt="Workflow" width="800">
</p>
```

推荐放置图片的位置：

1. 在“项目整体流程”下面放一张 workflow 图；
2. 在“如何让 Codex 自动执行”下面放一张 VS Code/Codex 截图；
3. 在“论文阅读 skill 的能力”下面放一张预精读输出示例截图。

---

## 展示建议

如果在组会中展示这个项目，可以按照以下顺序讲：

1. 为什么直接读 PDF 不稳定；
2. MinerU 如何把 PDF 转成结构化材料；
3. Codex 如何调用 pipeline 自动上传、解析、下载；
4. `mineru-paper-reading` 如何做预精读和逐句精读；
5. 展示一个实际例子，例如 `LoRA.pdf`；
6. 展示最终生成的 Markdown 路径和 Codex 阅读输出；
7. 总结这个 workflow 对文献阅读效率的提升。

---

## 最小使用流程

```text
1. 手动启动 AutoDL 服务器
2. 把 PDF 放到 input_pdfs/
3. 在 VS Code 中向 Codex 说：帮我预精读这篇论文
4. Codex 自动运行 pipeline
5. MinerU 输出下载到 mineru_result/
6. Codex 使用 skill 完成论文阅读
```

这个项目的目标不是替代人的阅读，而是把论文从“难以处理的 PDF”变成“可以被系统化分析的结构化阅读材料”，再让 Codex 帮助用户快速建立论文全局理解，并在需要时进入逐句精读。
