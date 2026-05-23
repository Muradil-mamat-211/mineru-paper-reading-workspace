param(
    [string]$PdfPath = "",
    [string]$PaperName = ""
)

$ErrorActionPreference = "Stop"

function Write-Step($Text) {
    Write-Host ""
    Write-Host "============================================================"
    Write-Host $Text
    Write-Host "============================================================"
}

function Safe-Name([string]$Name) {
    $safe = $Name -replace '[\\/:*?"<>|]', '_'
    $safe = $safe -replace '\s+', '_'
    return $safe
}

# ============================================================
# Manual AutoDL + MinerU pipeline v4 EXACT-ACTIVATE
# ------------------------------------------------------------
# This version intentionally mimics your successful manual style:
#
#   source /root/autodl-tmp/mineru_env/bin/activate
#   mineru -p xxx.pdf -o /root/autodl-tmp/demo_1
#
# Key difference from older scripts:
# - It does NOT call /root/autodl-tmp/mineru_env/bin/mineru directly.
# - It activates the venv first, then calls `mineru`.
# - It does NOT append -m or -l unless mineru_args is non-empty.
# ============================================================

$Workspace = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ConfigPath = Join-Path $Workspace "scripts\autodl_config.json"

$SshHost = "connect.westb.seetacloud.com"
$SshPort = "41084"
$KeyPath = "$env:USERPROFILE\.ssh\autodl_mineru_ed25519"

$RemoteInput = "/root/autodl-tmp/input"
$RemoteOutputBase = "/root/autodl-tmp/demo_1"

$LocalInputDirName = "input_pdfs"
$LocalResultDirName = "mineru_result"

$MineruVenvActivate = "/root/autodl-tmp/mineru_env/bin/activate"
$MineruArgs = ""

if (Test-Path $ConfigPath) {
    $Config = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

    if ($Config.ssh_host) { $SshHost = [string]$Config.ssh_host }
    if ($Config.ssh_port) { $SshPort = [string]$Config.ssh_port }
    if ($Config.ssh_private_key) { $KeyPath = [Environment]::ExpandEnvironmentVariables([string]$Config.ssh_private_key) }

    if ($Config.remote_input) { $RemoteInput = [string]$Config.remote_input }
    if ($Config.remote_output) { $RemoteOutputBase = [string]$Config.remote_output }

    if ($Config.local_input_dir) { $LocalInputDirName = [string]$Config.local_input_dir }
    if ($Config.local_result_dir) { $LocalResultDirName = [string]$Config.local_result_dir }

    if ($Config.mineru_venv_activate) { $MineruVenvActivate = [string]$Config.mineru_venv_activate }

    if ($null -ne $Config.mineru_args) { $MineruArgs = [string]$Config.mineru_args }
}

if (!(Test-Path $KeyPath)) {
    throw "找不到 SSH 私钥：$KeyPath"
}

if (-not $PdfPath) {
    $InputDir = Join-Path $Workspace $LocalInputDirName
    if (!(Test-Path $InputDir)) {
        throw "找不到输入目录：$InputDir"
    }

    $Pdf = Get-ChildItem -Path $InputDir -Recurse -Filter *.pdf |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $Pdf) {
        throw "输入目录中没有 PDF：$InputDir"
    }

    $PdfPath = $Pdf.FullName
}

if (!(Test-Path $PdfPath)) {
    throw "找不到 PDF：$PdfPath"
}

if (-not $PaperName) {
    $PaperName = [System.IO.Path]::GetFileNameWithoutExtension($PdfPath)
}

$PaperNameSafe = Safe-Name $PaperName
$RemotePdfName = "$PaperNameSafe.pdf"

$LocalResultRoot = Join-Path $Workspace $LocalResultDirName
$LocalPaperResult = Join-Path $LocalResultRoot $PaperNameSafe
New-Item -ItemType Directory -Force -Path $LocalPaperResult | Out-Null

$RemotePdf = "$RemoteInput/$RemotePdfName"
$RemoteOutputRoot = $RemoteOutputBase
$RemoteExpectedPaperDir = "$RemoteOutputBase/$PaperNameSafe"

Write-Host "Workspace:              $Workspace"
Write-Host "PDF:                    $PdfPath"
Write-Host "PaperName:              $PaperName"
Write-Host "PaperNameSafe:          $PaperNameSafe"
Write-Host "Local result dir:       $LocalPaperResult"
Write-Host "SSH host:               $SshHost"
Write-Host "SSH port:               $SshPort"
Write-Host "SSH key:                $KeyPath"
Write-Host "MinerU activate:        $MineruVenvActivate"
Write-Host "MinerU args:            [$MineruArgs]"
Write-Host "Remote PDF:             $RemotePdf"
Write-Host "Remote output root:     $RemoteOutputRoot"
Write-Host "Expected paper dir:     $RemoteExpectedPaperDir"

Write-Step "[1/6] Test SSH"
& ssh -i "$KeyPath" -p "$SshPort" "root@$SshHost" "echo ssh-ok"
if ($LASTEXITCODE -ne 0) {
    throw "SSH 测试失败。请单独测试：ssh -i `"$KeyPath`" -p $SshPort root@$SshHost `"echo ssh-ok`""
}

Write-Step "[2/6] Test activated MinerU"
$TestCmd = "source '$MineruVenvActivate' && which mineru && mineru --version && python - <<'PY'
import sys
print('python:', sys.executable)
try:
    import torch
    print('torch ok:', torch.__version__)
except Exception as e:
    print('torch import failed:', repr(e))
    raise
PY"
& ssh -i "$KeyPath" -p "$SshPort" "root@$SshHost" "$TestCmd"
if ($LASTEXITCODE -ne 0) {
    throw "激活 mineru_env 后 MinerU 测试失败。请检查 mineru_venv_activate。"
}

Write-Step "[3/6] Prepare remote dirs"
$PrepareCmd = "mkdir -p '$RemoteInput' '$RemoteOutputRoot' && rm -rf '$RemoteExpectedPaperDir'"
& ssh -i "$KeyPath" -p "$SshPort" "root@$SshHost" "$PrepareCmd"
if ($LASTEXITCODE -ne 0) {
    throw "创建远程目录失败。"
}

Write-Step "[4/6] Upload PDF"
& scp -i "$KeyPath" -P "$SshPort" "$PdfPath" "root@${SshHost}:$RemotePdf"
if ($LASTEXITCODE -ne 0) {
    throw "上传 PDF 失败。"
}

Write-Step "[5/6] Run MinerU EXACTLY like manual successful style"
$MineruCmd = "unset OMP_NUM_THREADS; export OMP_NUM_THREADS=1; source '$MineruVenvActivate' && mineru -p '$RemotePdf' -o '$RemoteOutputRoot'"
if ($MineruArgs.Trim().Length -gt 0) {
    $MineruCmd = "$MineruCmd $MineruArgs"
}

Write-Host "Remote MinerU command:"
Write-Host $MineruCmd

& ssh -i "$KeyPath" -p "$SshPort" "root@$SshHost" "$MineruCmd"
if ($LASTEXITCODE -ne 0) {
    throw "MinerU 解析失败。上面已经输出真实 MinerU 报错。"
}

Write-Step "[6/6] Download result"
Write-Host "Remote output listing:"
& ssh -i "$KeyPath" -p "$SshPort" "root@$SshHost" "find '$RemoteOutputBase' -maxdepth 4 -type f | head -100"

& ssh -i "$KeyPath" -p "$SshPort" "root@$SshHost" "test -d '$RemoteExpectedPaperDir'"
if ($LASTEXITCODE -eq 0) {
    & scp -i "$KeyPath" -P "$SshPort" -r "root@${SshHost}:$RemoteExpectedPaperDir/*" "$LocalPaperResult\"
} else {
    Write-Host "Expected paper dir not found, downloading all files directly under output root."
    & scp -i "$KeyPath" -P "$SshPort" -r "root@${SshHost}:$RemoteOutputRoot/*" "$LocalPaperResult\"
}

if ($LASTEXITCODE -ne 0) {
    throw "下载结果失败。"
}

Write-Step "Done"

Write-Host "Local result dir:"
Write-Host $LocalPaperResult

Write-Host ""
Write-Host "Markdown files:"
Get-ChildItem -Path $LocalPaperResult -Recurse -Filter *.md | ForEach-Object {
    Write-Host $_.FullName
}

Write-Host ""
Write-Host "RESULT_DIR=$LocalPaperResult"
