<#
.SYNOPSIS
  Rich session activity logger. Appends detailed JSONL per tool call.
.DESCRIPTION
  Provides richer data than the inline hook (includes path + args summary).
  Replace the postToolUse inline command in session-logger.json with:
    "powershell": "& .github/hooks/log-tool-call.ps1"
  to get detailed logging.
#>

$ErrorActionPreference = "SilentlyContinue"

$LogDir = Join-Path (Get-Location).Path ".copilot"
$LogFile = Join-Path $LogDir "session-activity.jsonl"

# Ensure log directory exists
if (-not (Test-Path $LogDir)) {
  New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$ToolName = if ($env:COPILOT_TOOL_NAME) { $env:COPILOT_TOOL_NAME } else { "unknown" }
$ToolArgs = if ($env:COPILOT_TOOL_ARGS) { $env:COPILOT_TOOL_ARGS } else { "{}" }
$Timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

# Extract file path from common tool arg patterns
function Get-FilePath {
  param([string]$InputArgs)
  if ($InputArgs -match '"(?:path|file|filePath|target)"\s*:\s*"([^"]*)"') {
    return $Matches[1]
  }
  return ""
}

# Summarize args (first 200 chars, single line)
function Get-ArgsSummary {
  param([string]$InputArgs)
  $single = $InputArgs -replace "`n", " " -replace "`r", ""
  if ($single.Length -gt 200) { $single = $single.Substring(0, 200) }
  return $single
}

$FilePath = Get-FilePath -InputArgs $ToolArgs
$ArgsSummary = Get-ArgsSummary -InputArgs $ToolArgs

# Escape for JSON
function ConvertTo-JsonString {
  param([string]$Value)
  $Value = $Value -replace '\\', '\\\\'
  $Value = $Value -replace '"', '\"'
  $Value = $Value -replace "`n", '\n'
  $Value = $Value -replace "`r", ''
  $Value = $Value -replace "`t", '\t'
  return $Value
}

$EscapedPath = ConvertTo-JsonString -Value $FilePath
$EscapedSummary = ConvertTo-JsonString -Value $ArgsSummary

# Append JSONL entry
$entry = "{`"ts`":`"$Timestamp`",`"tool`":`"$ToolName`",`"path`":`"$EscapedPath`",`"args_summary`":`"$EscapedSummary`"}"
Add-Content -Path $LogFile -Value $entry -Encoding UTF8
