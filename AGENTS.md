# Project Instructions: MinerU Paper Reading Workspace

This workspace is used for MinerU-based research-paper reading.

Prefer the skill:

`mineru-paper-reading`

Use it when the user asks to:

- 预精读论文并判断是否值得自己继续精读
- 精读论文
- 逐句精读
- 总结论文
- 图文结合讲解论文
- 读取 MinerU 输出文件夹
- 按 How to Read a Paper 的方法读论文

---

## Universal PDF → AutoDL MinerU → Local Reading Workflow

When the user asks to parse, process, convert, read, pre-read, summarize, deeply read, or sentence-by-sentence read a PDF paper, automatically use the local MinerU pipeline first.

Current project root:

`D:\skills_demo\demo_1`

Important files:

- Manual MinerU pipeline:

  `scripts\autodl_mineru_manual_pipeline.ps1`

- MinerU reading skill:

  `.agents\skills\mineru-paper-reading\SKILL.md`

- Default PDF input folder:

  `input_pdfs\`

- Default MinerU local result folder:

  `mineru_result\`

AutoDL is NOT controlled by API in this project.

The user will manually start the AutoDL server before asking for parsing or reading.

Do not try to use AutoDL Pro API in this project.

Do not ask the user to manually run the MinerU pipeline unless debugging is needed.

Default execution rule:

1. If the user specifies a PDF filename or PDF path, use that PDF.
2. If the user does not specify a PDF, choose the newest `.pdf` file under `input_pdfs\`.
3. Run the local manual MinerU pipeline.

   If a PDF path is specified, run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\autodl_mineru_manual_pipeline.ps1 -PdfPath "<PDF_PATH>"
   ```

   If no PDF path is specified, run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\autodl_mineru_manual_pipeline.ps1
   ```

4. Wait until the command finishes successfully.
5. Find the downloaded MinerU output under:

   `mineru_result\<paper_name>\`

6. Locate the main Markdown recursively. It is usually:

   `mineru_result\<paper_name>\hybrid_auto\<paper_name>.md`

7. Then use `mineru-paper-reading` to read the MinerU output.
8. If the skill is not exposed in the available skills list, manually read:

   `.agents\skills\mineru-paper-reading\SKILL.md`

   and follow Workflow A for pre-reading or Workflow B for sentence-by-sentence deep reading.

The pipeline already handles:

- Uploading the PDF to the server.
- Running MinerU on the AutoDL server.
- Downloading the MinerU output folder back to local `mineru_result\<paper_name>\`.
- Keeping the output assets together, including Markdown, images, JSON files, formulas, tables, and layout assets.

Do not separate the pipeline step and reading step unless the user explicitly asks only to parse/convert the PDF.

---

## Pipeline Assumptions

The manual pipeline assumes:

- AutoDL server has already been manually started by the user.
- SSH key login is already configured.
- Server SSH target is configured in the pipeline/config.
- MinerU is installed in:

  `/root/autodl-tmp/mineru_env`

- MinerU should be run in the same style as the user's known successful command:

  ```bash
  source /root/autodl-tmp/mineru_env/bin/activate
  mineru -p xxx.pdf -o /root/autodl-tmp/demo_1
  ```

Do not add `-m`, `-l`, `-l en`, or `-l latin` unless the user explicitly asks or the config already contains those args.

Default `mineru_args` should remain empty:

```json
"mineru_args": ""
```

If the pipeline fails, inspect the actual error message before changing anything.

Do not reinstall MinerU, recreate environments, or upgrade core dependencies unless the error explicitly requires it.

---

## Default Reading Behavior

1. Treat the source as a MinerU output folder, not only a PDF.
2. Read the main Markdown first.
3. Use the original PDF/layout PDF as auxiliary verification.
4. Use images/tables/formulas/JSON assets when relevant.
5. Do not separate text and figures; explain figures/tables/formulas inside the relevant section/sentence.
6. Scan references internally, but do not display reference clues unless the user asks.
7. Do not show Source inventory or Five Cs by default.
8. If the user says something like:

   `为我先精读一下这里的文章，然后我会根据你的输出而选择要不要亲自精读`

   use the pre-reading decision report:

   - 为什么写这篇论文
   - 这篇论文写了什么
   - 全文主线
   - 核心贡献详解
   - 每章每节概括
   - 关键图表解释
   - 文章总结
   - 后续选择依据

9. If the user says `逐句精读`, use Intensive sentence-by-sentence mode:

   - 一句原文
   - 一句翻译
   - 一句解析
   - 相关图表/公式/参考文献融合进解析
   - 每节解析
   - 每章解读
   - 全文解析

---

## Output Rules

Do not show Source Inventory unless the user asks for debugging.

Do not show Five Cs explicitly unless the user asks.

Do not show key reference clues by default.

For pre-reading, focus on:

- why the paper was written
- what the paper says
- chapter/section summaries
- key figures integrated into the corresponding sections
- final paper summary
- whether the paper is worth further close reading

For close reading, explain sentence by sentence with:

- original sentence
- Chinese translation
- explanation
- related figures/tables/equations integrated into the explanation

---

## Skill fallback rule

If the user asks to use `mineru-paper-reading` but the skill is not exposed in the available skills list, do not ignore the skill.

Manually read and follow:

`.agents/skills/mineru-paper-reading/SKILL.md`

Before doing any paper-reading work, use that file as the authoritative workflow.

For paper-reading tasks, the local `SKILL.md` has priority over this AGENTS.md summary.

Do not merely follow the simplified AGENTS.md rules if the full SKILL.md exists.

---

## Example User Intents and Required Agent Behavior

User says:

`帮我预精读 LoRA.pdf，我想知道它是否值得后续精读。`

Agent should:

1. Use `input_pdfs\LoRA.pdf`.
2. Run the manual MinerU pipeline.
3. Locate `mineru_result\LoRA\hybrid_auto\LoRA.md`.
4. Use `mineru-paper-reading`.
5. Produce a pre-reading decision report.

User says:

`帮我精读 input_pdfs 里最新的论文，我关注它的方法和贡献。`

Agent should:

1. Pick the newest PDF under `input_pdfs\`.
2. Run the manual MinerU pipeline without asking the user to type commands.
3. Locate the downloaded MinerU output.
4. Use `mineru-paper-reading`.
5. Produce the requested reading output.

User says:

`逐句精读第 3 节。`

Agent should:

1. Use the existing MinerU result folder if it already exists.
2. If no MinerU result exists, run the manual MinerU pipeline first.
3. Locate the main Markdown.
4. Read section 3 sentence by sentence.
5. Integrate related figures/tables/equations into the explanation.
