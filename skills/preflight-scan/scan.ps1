<#
.SYNOPSIS
  Codebase scanner for preflight. Outputs structured JSON to stdout.
.PARAMETER Directory
  Directory to scan (defaults to current directory).
#>
param(
  [string]$Directory = "."
)

$ErrorActionPreference = "SilentlyContinue"
$Dir = (Resolve-Path $Directory).Path
Write-Host "Scanning: $Dir" -ForegroundColor DarkGray

$ExcludeDirs = @("node_modules", ".git", "dist", "build", "target", "venv",
                  "__pycache__", ".next", ".venv", "vendor", ".cache", ".output")

function Get-FilteredFiles {
  param([string[]]$Extensions, [int]$Depth = 4)
  Get-ChildItem -Path $Dir -Recurse -File -Depth $Depth -ErrorAction SilentlyContinue |
    Where-Object {
      $rel = $_.FullName.Substring($Dir.Length)
      $dominated = $false
      foreach ($ex in $ExcludeDirs) {
        if ($rel -match "(\\|/)$([regex]::Escape($ex))(\\|/)") { $dominated = $true; break }
      }
      if (-not $dominated) {
        $_.Extension -in $Extensions
      }
    }
}

# ── Languages ────────────────────────────────────────────────────────────────
function Detect-Languages {
  $map = [ordered]@{
    "TypeScript"  = @(".ts", ".tsx")
    "JavaScript"  = @(".js", ".jsx")
    "Python"      = @(".py")
    "Rust"        = @(".rs")
    "Go"          = @(".go")
    "Java"        = @(".java")
    "C#"          = @(".cs")
    "Ruby"        = @(".rb")
    "PHP"         = @(".php")
    "Swift"       = @(".swift")
    "Kotlin"      = @(".kt")
  }
  $langs = @()
  foreach ($kv in $map.GetEnumerator()) {
    $files = Get-FilteredFiles -Extensions $kv.Value
    if ($files) { $langs += $kv.Key }
  }
  return $langs
}

# ── Package Manager ──────────────────────────────────────────────────────────
function Detect-PackageManager {
  $checks = [ordered]@{
    "pnpm-lock.yaml"    = "pnpm"
    "yarn.lock"         = "yarn"
    "bun.lockb"         = "bun"
    "package-lock.json" = "npm"
    "poetry.lock"       = "poetry"
    "Pipfile.lock"      = "pipenv"
    "Pipfile"           = "pipenv"
    "requirements.txt"  = "pip"
    "Cargo.lock"        = "cargo"
    "go.sum"            = "go modules"
    "Gemfile.lock"      = "bundler"
    "composer.lock"     = "composer"
  }
  foreach ($kv in $checks.GetEnumerator()) {
    if (Test-Path (Join-Path $Dir $kv.Key)) { return $kv.Value }
  }
  return $null
}

# ── Frameworks ───────────────────────────────────────────────────────────────
function Detect-Frameworks {
  $fw = @()
  $pkgPath = Join-Path $Dir "package.json"
  if (Test-Path $pkgPath) {
    $pkg = Get-Content $pkgPath -Raw -ErrorAction SilentlyContinue
    if ($pkg) {
      $depMap = [ordered]@{
        "next"           = "Next.js"
        "astro"          = "Astro"
        "react"          = "React"
        "vue"            = "Vue"
        "@angular/core"  = "Angular"
        "svelte"         = "Svelte"
        "express"        = "Express"
        "fastify"        = "Fastify"
        "nuxt"           = "Nuxt"
        "remix"          = "Remix"
        "gatsby"         = "Gatsby"
        "@nestjs/core"   = "NestJS"
        "nestjs"         = "NestJS"
        "hono"           = "Hono"
        "electron"       = "Electron"
      }
      foreach ($kv in $depMap.GetEnumerator()) {
        if ($pkg -match [regex]::Escape("`"$($kv.Key)`"")) {
          if ($kv.Value -notin $fw) { $fw += $kv.Value }
        }
      }
    }
  }

  $pyprojectPath = Join-Path $Dir "pyproject.toml"
  if (Test-Path $pyprojectPath) {
    $pyp = Get-Content $pyprojectPath -Raw -ErrorAction SilentlyContinue
    if ($pyp) {
      if ($pyp -match "(?i)django")  { $fw += "Django" }
      if ($pyp -match "(?i)flask")   { $fw += "Flask" }
      if ($pyp -match "(?i)fastapi") { $fw += "FastAPI" }
    }
  }

  $reqPath = Join-Path $Dir "requirements.txt"
  if (Test-Path $reqPath) {
    $req = Get-Content $reqPath -Raw -ErrorAction SilentlyContinue
    if ($req) {
      if ($req -match "(?im)^django")  { if ("Django"  -notin $fw) { $fw += "Django" } }
      if ($req -match "(?im)^flask")   { if ("Flask"   -notin $fw) { $fw += "Flask" } }
      if ($req -match "(?im)^fastapi") { if ("FastAPI" -notin $fw) { $fw += "FastAPI" } }
    }
  }

  $cargoPath = Join-Path $Dir "Cargo.toml"
  if (Test-Path $cargoPath) {
    $cargo = Get-Content $cargoPath -Raw -ErrorAction SilentlyContinue
    if ($cargo) {
      if ($cargo -match "(?i)actix-web") { $fw += "Actix-web" }
      if ($cargo -match "(?i)rocket")    { $fw += "Rocket" }
      if ($cargo -match "(?i)axum")      { $fw += "Axum" }
    }
  }

  $gomodPath = Join-Path $Dir "go.mod"
  if (Test-Path $gomodPath) {
    $gomod = Get-Content $gomodPath -Raw -ErrorAction SilentlyContinue
    if ($gomod) {
      if ($gomod -match "(?i)gin-gonic")     { $fw += "Gin" }
      if ($gomod -match "(?i)labstack/echo") { $fw += "Echo" }
      if ($gomod -match "(?i)gofiber")       { $fw += "Fiber" }
    }
  }

  return $fw
}

# ── Test Framework ───────────────────────────────────────────────────────────
function Detect-TestFramework {
  $pkgPath = Join-Path $Dir "package.json"
  if (Test-Path $pkgPath) {
    $pkg = Get-Content $pkgPath -Raw -ErrorAction SilentlyContinue
    if ($pkg) {
      if ($pkg -match '"vitest"')       { return "vitest" }
      if ($pkg -match '"jest"')         { return "jest" }
      if ($pkg -match '"mocha"')        { return "mocha" }
      if ($pkg -match '"playwright"')   { return "playwright" }
      if ($pkg -match '"@playwright"')  { return "playwright" }
      if ($pkg -match '"cypress"')      { return "cypress" }
    }
  }

  $pyprojectPath = Join-Path $Dir "pyproject.toml"
  if (Test-Path $pyprojectPath) {
    $pyp = Get-Content $pyprojectPath -Raw -ErrorAction SilentlyContinue
    if ($pyp -and $pyp -match "(?i)pytest") { return "pytest" }
  }

  $reqPath = Join-Path $Dir "requirements.txt"
  if (Test-Path $reqPath) {
    $req = Get-Content $reqPath -Raw -ErrorAction SilentlyContinue
    if ($req -and $req -match "(?i)pytest") { return "pytest" }
  }

  $pyFiles = Get-FilteredFiles -Extensions @(".py")
  if ($pyFiles) {
    foreach ($f in ($pyFiles | Select-Object -First 20)) {
      $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
      if ($content -and $content -match "import unittest") { return "unittest" }
    }
  }

  $rsFiles = Get-FilteredFiles -Extensions @(".rs")
  if ($rsFiles) {
    foreach ($f in ($rsFiles | Select-Object -First 20)) {
      $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
      if ($content -and $content -match '#\[cfg\(test\)\]') { return "rust-builtin" }
    }
  }

  $goTests = Get-ChildItem -Path $Dir -Recurse -File -Depth 4 -Filter "*_test.go" -ErrorAction SilentlyContinue |
    Where-Object {
      $rel = $_.FullName.Substring($Dir.Length)
      $dominated = $false
      foreach ($ex in $ExcludeDirs) {
        if ($rel -match "(\\|/)$([regex]::Escape($ex))(\\|/)") { $dominated = $true; break }
      }
      -not $dominated
    } | Select-Object -First 1
  if ($goTests) { return "go-test" }

  return $null
}

# ── Build Tool ───────────────────────────────────────────────────────────────
function Detect-BuildTool {
  $vite = Get-ChildItem -Path $Dir -Depth 2 -File -Filter "vite.config.*" -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($vite) { return "vite" }

  $webpack = Get-ChildItem -Path $Dir -Depth 2 -File -Filter "webpack.config.*" -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($webpack) { return "webpack" }

  $rollup = Get-ChildItem -Path $Dir -Depth 2 -File -Filter "rollup.config.*" -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($rollup) { return "rollup" }

  if (Test-Path (Join-Path $Dir "tsconfig.json"))      { return "tsc" }
  if (Test-Path (Join-Path $Dir "Makefile"))            { return "make" }
  if (Test-Path (Join-Path $Dir "CMakeLists.txt"))      { return "cmake" }
  if (Test-Path (Join-Path $Dir "build.gradle"))        { return "gradle" }
  if (Test-Path (Join-Path $Dir "build.gradle.kts"))    { return "gradle" }
  if (Test-Path (Join-Path $Dir "pom.xml"))             { return "maven" }

  return $null
}

# ── Folder Structure ─────────────────────────────────────────────────────────
function Detect-FolderStructure {
  $dirs = @("src","lib","app","pages","components",
            "tests","test","spec","__tests__",
            "docs","scripts","config","public","static")
  $result = [ordered]@{}
  foreach ($d in $dirs) {
    $result[$d] = (Test-Path (Join-Path $Dir $d) -PathType Container)
  }
  return $result
}

# ── CI/CD ────────────────────────────────────────────────────────────────────
function Detect-CICD {
  if (Test-Path (Join-Path $Dir ".github\workflows"))  { return "github-actions" }
  if (Test-Path (Join-Path $Dir ".gitlab-ci.yml"))     { return "gitlab-ci" }
  if (Test-Path (Join-Path $Dir "Jenkinsfile"))        { return "jenkins" }
  if (Test-Path (Join-Path $Dir ".circleci"))          { return "circleci" }
  if (Test-Path (Join-Path $Dir ".travis.yml"))        { return "travis-ci" }
  return $null
}

# ── Monorepo ─────────────────────────────────────────────────────────────────
function Detect-Monorepo {
  if (Test-Path (Join-Path $Dir "packages") -PathType Container)   { return $true }
  if (Test-Path (Join-Path $Dir "apps") -PathType Container)       { return $true }
  if (Test-Path (Join-Path $Dir "pnpm-workspace.yaml"))            { return $true }
  if (Test-Path (Join-Path $Dir "lerna.json"))                     { return $true }

  $pkgPath = Join-Path $Dir "package.json"
  if (Test-Path $pkgPath) {
    $pkg = Get-Content $pkgPath -Raw -ErrorAction SilentlyContinue
    if ($pkg -and $pkg -match '"workspaces"') { return $true }
  }

  $pkgCount = (Get-ChildItem -Path $Dir -Recurse -Depth 3 -File -Filter "package.json" -ErrorAction SilentlyContinue |
    Where-Object {
      $rel = $_.FullName.Substring($Dir.Length)
      $dominated = $false
      foreach ($ex in $ExcludeDirs) {
        if ($rel -match "(\\|/)$([regex]::Escape($ex))(\\|/)") { $dominated = $true; break }
      }
      -not $dominated
    }).Count
  if ($pkgCount -gt 1) { return $true }

  return $false
}

# ── Existing Copilot Config ──────────────────────────────────────────────────
function Detect-CopilotConfig {
  $result = [ordered]@{
    copilotInstructions = (Test-Path (Join-Path $Dir ".github\copilot-instructions.md"))
    pathInstructions    = (Test-Path (Join-Path $Dir ".github\instructions") -PathType Container)
    agents              = (Test-Path (Join-Path $Dir ".github\agents") -PathType Container)
    skills              = (Test-Path (Join-Path $Dir ".github\skills") -PathType Container)
    hooks               = (Test-Path (Join-Path $Dir ".github\hooks") -PathType Container)
    agentsMd            = ((Test-Path (Join-Path $Dir "AGENTS.md")) -or (Test-Path (Join-Path $Dir "CLAUDE.md")))
  }

  if (Test-Path (Join-Path $Dir ".copilot") -PathType Container) {
    $result.copilotInstructions = $true
  }

  return $result
}

# ── Main ─────────────────────────────────────────────────────────────────────
$output = [ordered]@{
  languages            = @(Detect-Languages)
  packageManager       = Detect-PackageManager
  frameworks           = @(Detect-Frameworks)
  testFramework        = Detect-TestFramework
  buildTool            = Detect-BuildTool
  folderStructure      = Detect-FolderStructure
  cicd                 = Detect-CICD
  monorepo             = Detect-Monorepo
  existingCopilotConfig = Detect-CopilotConfig
}

$output | ConvertTo-Json -Depth 3 -Compress:$false
