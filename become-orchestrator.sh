#!/usr/bin/env bash
# Накатывает модуль "оркестратор" на уже существующего агента — даёт ему
# способность создавать своих суб-агентов (отделы) и консультироваться с ними.
# Использование: ./become-orchestrator.sh <путь-к-папке-агента>
set -euo pipefail

KIT_REPO="https://github.com/andersmicha2000-vitek2026/novyj_agent_kit.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_CLONE=""

cleanup() {
  if [ -n "$TMP_CLONE" ]; then rm -rf "$TMP_CLONE"; fi
  return 0
}
trap cleanup EXIT

if [ -z "${1:-}" ]; then
  echo "Использование: ./become-orchestrator.sh <путь-к-папке-агента>"
  exit 1
fi
TARGET="$1"

if [ ! -d "$TARGET" ]; then
  echo "Папка \"$TARGET\" не найдена — этот модуль для уже существующего агента, не для установки с нуля (для установки с нуля — install.sh)."
  exit 1
fi
if [ ! -f "$TARGET/AGENTS.md" ]; then
  echo "В \"$TARGET\" нет AGENTS.md — не похоже на агента из novyj_agent_kit, останавливаюсь."
  exit 1
fi

if [ -d "$SCRIPT_DIR/orchestrator" ]; then
  ORCH_DIR="$SCRIPT_DIR/orchestrator"
else
  TMP_CLONE="$(mktemp -d)"
  git clone --depth 1 "$KIT_REPO" "$TMP_CLONE" >/dev/null
  ORCH_DIR="$TMP_CLONE/orchestrator"
fi

if [ -d "$TARGET/agents/_template" ]; then
  echo "В \"$TARGET\" уже есть agents/_template — модуль оркестратора, похоже, уже накатан, не трогаю."
  exit 1
fi

mkdir -p "$TARGET/agents" "$TARGET/scripts" "$TARGET/.claude/skills"
cp -r "$ORCH_DIR/agents/_template" "$TARGET/agents/_template"
cp -r "$ORCH_DIR/.claude/skills/spawn-subagent" "$TARGET/.claude/skills/spawn-subagent"
cp "$ORCH_DIR/scripts/ask_colleague.mjs" "$TARGET/scripts/ask_colleague.mjs"

if [ -f "$TARGET/MEMORY.md" ] && ! grep -q "^## Что я строю$" "$TARGET/MEMORY.md"; then
  printf '\n' >> "$TARGET/MEMORY.md"
  cat "$ORCH_DIR/MEMORY.append.md" >> "$TARGET/MEMORY.md"
  echo "MEMORY.md дополнен разделами оркестратора."
else
  echo "MEMORY.md уже содержит раздел «Что я строю», либо файла нет — не трогаю, чтобы не задвоить."
fi

echo "Готово: $TARGET теперь умеет создавать суб-агентов."
echo "Дальше: попроси агента создать суб-агента — он использует .claude/skills/spawn-subagent."
