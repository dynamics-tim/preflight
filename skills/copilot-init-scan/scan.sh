#!/usr/bin/env bash
set -euo pipefail

DIR="${1:-.}"
DIR="$(cd "$DIR" && pwd)"

EXCLUDE_DIRS="node_modules|\.git|dist|build|target|venv|__pycache__|\.next|\.venv|vendor|\.cache|\.output"

stderr() { echo "$@" >&2; }

stderr "Scanning: $DIR"

# ── Languages ────────────────────────────────────────────────────────────────
detect_languages() {
  local langs=()
  local found

  found=$(find "$DIR" -maxdepth 4 -type f \( -name '*.ts' -o -name '*.tsx' \) \
    | grep -Ev "$EXCLUDE_DIRS" | head -1 || true)
  [ -n "$found" ] && langs+=("TypeScript")

  found=$(find "$DIR" -maxdepth 4 -type f \( -name '*.js' -o -name '*.jsx' \) \
    | grep -Ev "$EXCLUDE_DIRS" | head -1 || true)
  [ -n "$found" ] && langs+=("JavaScript")

  found=$(find "$DIR" -maxdepth 4 -type f -name '*.py' \
    | grep -Ev "$EXCLUDE_DIRS" | head -1 || true)
  [ -n "$found" ] && langs+=("Python")

  found=$(find "$DIR" -maxdepth 4 -type f -name '*.rs' \
    | grep -Ev "$EXCLUDE_DIRS" | head -1 || true)
  [ -n "$found" ] && langs+=("Rust")

  found=$(find "$DIR" -maxdepth 4 -type f -name '*.go' \
    | grep -Ev "$EXCLUDE_DIRS" | head -1 || true)
  [ -n "$found" ] && langs+=("Go")

  found=$(find "$DIR" -maxdepth 4 -type f -name '*.java' \
    | grep -Ev "$EXCLUDE_DIRS" | head -1 || true)
  [ -n "$found" ] && langs+=("Java")

  found=$(find "$DIR" -maxdepth 4 -type f -name '*.cs' \
    | grep -Ev "$EXCLUDE_DIRS" | head -1 || true)
  [ -n "$found" ] && langs+=("C#")

  found=$(find "$DIR" -maxdepth 4 -type f -name '*.rb' \
    | grep -Ev "$EXCLUDE_DIRS" | head -1 || true)
  [ -n "$found" ] && langs+=("Ruby")

  found=$(find "$DIR" -maxdepth 4 -type f -name '*.php' \
    | grep -Ev "$EXCLUDE_DIRS" | head -1 || true)
  [ -n "$found" ] && langs+=("PHP")

  found=$(find "$DIR" -maxdepth 4 -type f -name '*.swift' \
    | grep -Ev "$EXCLUDE_DIRS" | head -1 || true)
  [ -n "$found" ] && langs+=("Swift")

  found=$(find "$DIR" -maxdepth 4 -type f -name '*.kt' \
    | grep -Ev "$EXCLUDE_DIRS" | head -1 || true)
  [ -n "$found" ] && langs+=("Kotlin")

  json_array "${langs[@]}"
}

# ── Package Manager ──────────────────────────────────────────────────────────
detect_package_manager() {
  if   [ -f "$DIR/pnpm-lock.yaml" ];  then echo "pnpm"
  elif [ -f "$DIR/yarn.lock" ];       then echo "yarn"
  elif [ -f "$DIR/bun.lockb" ];       then echo "bun"
  elif [ -f "$DIR/package-lock.json" ]; then echo "npm"
  elif [ -f "$DIR/poetry.lock" ];     then echo "poetry"
  elif [ -f "$DIR/Pipfile.lock" ] || [ -f "$DIR/Pipfile" ]; then echo "pipenv"
  elif [ -f "$DIR/requirements.txt" ]; then echo "pip"
  elif [ -f "$DIR/Cargo.lock" ];      then echo "cargo"
  elif [ -f "$DIR/go.sum" ];          then echo "go modules"
  elif [ -f "$DIR/Gemfile.lock" ];    then echo "bundler"
  elif [ -f "$DIR/composer.lock" ];   then echo "composer"
  else echo ""
  fi
}

# ── Frameworks ───────────────────────────────────────────────────────────────
detect_frameworks() {
  local fw=()

  if [ -f "$DIR/package.json" ]; then
    local pkg
    pkg=$(cat "$DIR/package.json" 2>/dev/null || true)

    has_dep() { echo "$pkg" | grep -qE "\"$1\"" 2>/dev/null; }

    has_dep "next"     && fw+=("Next.js")
    has_dep "astro"    && fw+=("Astro")
    has_dep "react"    && fw+=("React")
    has_dep "vue"      && fw+=("Vue")
    has_dep "@angular/core" && fw+=("Angular")
    has_dep "svelte"   && fw+=("Svelte")
    has_dep "express"  && fw+=("Express")
    has_dep "fastify"  && fw+=("Fastify")
    has_dep "nuxt"     && fw+=("Nuxt")
    has_dep "remix"    && fw+=("Remix")
    has_dep "gatsby"   && fw+=("Gatsby")
    has_dep "nestjs"   && fw+=("NestJS")
    has_dep "@nestjs/core" && fw+=("NestJS")
    has_dep "hono"     && fw+=("Hono")
    has_dep "electron" && fw+=("Electron")
  fi

  if [ -f "$DIR/pyproject.toml" ]; then
    local pyp
    pyp=$(cat "$DIR/pyproject.toml" 2>/dev/null || true)
    echo "$pyp" | grep -qi "django"  2>/dev/null && fw+=("Django")
    echo "$pyp" | grep -qi "flask"   2>/dev/null && fw+=("Flask")
    echo "$pyp" | grep -qi "fastapi" 2>/dev/null && fw+=("FastAPI")
  fi

  if [ -f "$DIR/requirements.txt" ]; then
    local req
    req=$(cat "$DIR/requirements.txt" 2>/dev/null || true)
    echo "$req" | grep -qi "^django"  2>/dev/null && fw+=("Django")
    echo "$req" | grep -qi "^flask"   2>/dev/null && fw+=("Flask")
    echo "$req" | grep -qi "^fastapi" 2>/dev/null && fw+=("FastAPI")
  fi

  if [ -f "$DIR/Cargo.toml" ]; then
    local cargo
    cargo=$(cat "$DIR/Cargo.toml" 2>/dev/null || true)
    echo "$cargo" | grep -qi "actix-web" 2>/dev/null && fw+=("Actix-web")
    echo "$cargo" | grep -qi "rocket"    2>/dev/null && fw+=("Rocket")
    echo "$cargo" | grep -qi "axum"      2>/dev/null && fw+=("Axum")
  fi

  if [ -f "$DIR/go.mod" ]; then
    local gomod
    gomod=$(cat "$DIR/go.mod" 2>/dev/null || true)
    echo "$gomod" | grep -qi "gin-gonic" 2>/dev/null && fw+=("Gin")
    echo "$gomod" | grep -qi "labstack/echo" 2>/dev/null && fw+=("Echo")
    echo "$gomod" | grep -qi "gofiber"   2>/dev/null && fw+=("Fiber")
  fi

  # deduplicate
  local unique=()
  local seen=""
  for f in "${fw[@]}"; do
    if [[ "$seen" != *"|$f|"* ]]; then
      unique+=("$f")
      seen="$seen|$f|"
    fi
  done

  json_array "${unique[@]}"
}

# ── Test Framework ───────────────────────────────────────────────────────────
detect_test_framework() {
  if [ -f "$DIR/package.json" ]; then
    local pkg
    pkg=$(cat "$DIR/package.json" 2>/dev/null || true)

    echo "$pkg" | grep -qE "\"vitest\""      2>/dev/null && { echo "vitest"; return; }
    echo "$pkg" | grep -qE "\"jest\""         2>/dev/null && { echo "jest"; return; }
    echo "$pkg" | grep -qE "\"mocha\""        2>/dev/null && { echo "mocha"; return; }
    echo "$pkg" | grep -qE "\"playwright\""   2>/dev/null && { echo "playwright"; return; }
    echo "$pkg" | grep -qE "\"cypress\""      2>/dev/null && { echo "cypress"; return; }
    echo "$pkg" | grep -qE "\"@playwright\""  2>/dev/null && { echo "playwright"; return; }
  fi

  if [ -f "$DIR/pyproject.toml" ]; then
    grep -qi "pytest" "$DIR/pyproject.toml" 2>/dev/null && { echo "pytest"; return; }
  fi
  if [ -f "$DIR/requirements.txt" ]; then
    grep -qi "pytest" "$DIR/requirements.txt" 2>/dev/null && { echo "pytest"; return; }
  fi

  local py_test
  py_test=$(find "$DIR" -maxdepth 4 -type f -name '*.py' \
    | grep -Ev "$EXCLUDE_DIRS" \
    | head -20 \
    | xargs grep -l "import unittest" 2>/dev/null | head -1 || true)
  [ -n "$py_test" ] && { echo "unittest"; return; }

  local rs_test
  rs_test=$(find "$DIR" -maxdepth 4 -type f -name '*.rs' \
    | grep -Ev "$EXCLUDE_DIRS" \
    | head -20 \
    | xargs grep -l '#\[cfg(test)\]' 2>/dev/null | head -1 || true)
  [ -n "$rs_test" ] && { echo "rust-builtin"; return; }

  local go_test
  go_test=$(find "$DIR" -maxdepth 4 -type f -name '*_test.go' \
    | grep -Ev "$EXCLUDE_DIRS" | head -1 || true)
  [ -n "$go_test" ] && { echo "go-test"; return; }

  echo ""
}

# ── Build Tool ───────────────────────────────────────────────────────────────
detect_build_tool() {
  local found
  found=$(find "$DIR" -maxdepth 2 -type f -name 'vite.config.*' | head -1 2>/dev/null || true)
  [ -n "$found" ] && { echo "vite"; return; }

  found=$(find "$DIR" -maxdepth 2 -type f -name 'webpack.config.*' | head -1 2>/dev/null || true)
  [ -n "$found" ] && { echo "webpack"; return; }

  found=$(find "$DIR" -maxdepth 2 -type f -name 'rollup.config.*' | head -1 2>/dev/null || true)
  [ -n "$found" ] && { echo "rollup"; return; }

  [ -f "$DIR/tsconfig.json" ] && { echo "tsc"; return; }
  [ -f "$DIR/Makefile" ] && { echo "make"; return; }
  [ -f "$DIR/CMakeLists.txt" ] && { echo "cmake"; return; }
  [ -f "$DIR/build.gradle" ] || [ -f "$DIR/build.gradle.kts" ] && { echo "gradle"; return; }
  [ -f "$DIR/pom.xml" ] && { echo "maven"; return; }

  echo ""
}

# ── Folder Structure ─────────────────────────────────────────────────────────
detect_folder_structure() {
  local dirs=("src" "lib" "app" "pages" "components" \
              "tests" "test" "spec" "__tests__" \
              "docs" "scripts" "config" "public" "static")
  local first=true
  echo -n "{"
  for d in "${dirs[@]}"; do
    $first || echo -n ","
    first=false
    if [ -d "$DIR/$d" ]; then
      echo -n "\"$d\":true"
    else
      echo -n "\"$d\":false"
    fi
  done
  echo -n "}"
}

# ── CI/CD ────────────────────────────────────────────────────────────────────
detect_cicd() {
  [ -d "$DIR/.github/workflows" ] && { echo "github-actions"; return; }
  [ -f "$DIR/.gitlab-ci.yml" ]    && { echo "gitlab-ci"; return; }
  [ -f "$DIR/Jenkinsfile" ]       && { echo "jenkins"; return; }
  [ -d "$DIR/.circleci" ]         && { echo "circleci"; return; }
  [ -f "$DIR/.travis.yml" ]       && { echo "travis-ci"; return; }
  echo ""
}

# ── Monorepo ─────────────────────────────────────────────────────────────────
detect_monorepo() {
  [ -d "$DIR/packages" ] && { echo "true"; return; }
  [ -d "$DIR/apps" ]     && { echo "true"; return; }
  [ -f "$DIR/pnpm-workspace.yaml" ] && { echo "true"; return; }
  [ -f "$DIR/lerna.json" ] && { echo "true"; return; }

  if [ -f "$DIR/package.json" ]; then
    grep -q '"workspaces"' "$DIR/package.json" 2>/dev/null && { echo "true"; return; }
  fi

  local pkg_count
  pkg_count=$(find "$DIR" -maxdepth 3 -name 'package.json' \
    | grep -Ev "$EXCLUDE_DIRS" | wc -l | tr -d ' ')
  [ "$pkg_count" -gt 1 ] 2>/dev/null && { echo "true"; return; }

  echo "false"
}

# ── Existing Copilot Config ──────────────────────────────────────────────────
detect_copilot_config() {
  local ci=false pi=false ag=false sk=false hk=false amd=false

  [ -f "$DIR/.github/copilot-instructions.md" ] && ci=true
  [ -d "$DIR/.github/instructions" ] && pi=true
  [ -d "$DIR/.github/agents" ] && ag=true
  [ -d "$DIR/.github/skills" ] && sk=true
  [ -d "$DIR/.github/hooks" ] && hk=true
  [ -f "$DIR/AGENTS.md" ] || [ -f "$DIR/CLAUDE.md" ] && amd=true
  [ -d "$DIR/.copilot" ] && ci=true  # .copilot/ dir counts as config

  cat <<EOF
{"copilotInstructions":$ci,"pathInstructions":$pi,"agents":$ag,"skills":$sk,"hooks":$hk,"agentsMd":$amd}
EOF
}

# ── JSON helpers ─────────────────────────────────────────────────────────────
json_array() {
  local arr=("$@")
  if [ ${#arr[@]} -eq 0 ]; then
    echo -n "[]"
    return
  fi
  local first=true
  echo -n "["
  for item in "${arr[@]}"; do
    $first || echo -n ","
    first=false
    echo -n "\"$item\""
  done
  echo -n "]"
}

json_string_or_null() {
  local val="$1"
  if [ -z "$val" ]; then
    echo -n "null"
  else
    echo -n "\"$val\""
  fi
}

# ── Main ─────────────────────────────────────────────────────────────────────
LANGUAGES=$(detect_languages)
PACKAGE_MANAGER=$(detect_package_manager)
FRAMEWORKS=$(detect_frameworks)
TEST_FRAMEWORK=$(detect_test_framework)
BUILD_TOOL=$(detect_build_tool)
FOLDER_STRUCTURE=$(detect_folder_structure)
CICD=$(detect_cicd)
MONOREPO=$(detect_monorepo)
COPILOT_CONFIG=$(detect_copilot_config)

cat <<EOF
{
  "languages": $LANGUAGES,
  "packageManager": $(json_string_or_null "$PACKAGE_MANAGER"),
  "frameworks": $FRAMEWORKS,
  "testFramework": $(json_string_or_null "$TEST_FRAMEWORK"),
  "buildTool": $(json_string_or_null "$BUILD_TOOL"),
  "folderStructure": $FOLDER_STRUCTURE,
  "cicd": $(json_string_or_null "$CICD"),
  "monorepo": $MONOREPO,
  "existingCopilotConfig": $COPILOT_CONFIG
}
EOF
