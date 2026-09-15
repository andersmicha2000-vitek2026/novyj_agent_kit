#!/usr/bin/env bash
# Ставит основу нового самостоятельного агента из template/ в указанную папку.
# Использование: ./install.sh <путь-к-новой-папке-агента>
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
  echo "Использование: ./install.sh <путь-к-новой-папке-агента>"
  exit 1
fi
TARGET="$1"

if [ -e "$TARGET" ] && [ -n "$(ls -A "$TARGET" 2>/dev/null)" ]; then
  echo "Папка \"$TARGET\" уже существует и не пустая — не трогаю её, укажи новый путь."
  exit 1
fi

if [ -d "$SCRIPT_DIR/template" ]; then
  TEMPLATE_DIR="$SCRIPT_DIR/template"
else
  TMP_CLONE="$(mktemp -d)"
  git clone --depth 1 "$KIT_REPO" "$TMP_CLONE" >/dev/null
  TEMPLATE_DIR="$TMP_CLONE/template"
fi

mkdir -p "$TARGET"
cp -r "$TEMPLATE_DIR"/. "$TARGET"/

(cd "$TARGET" && git init -q)

# Провенанс: если файлы когда-нибудь утекут или всплывут у конкурента — по
# этой строке видно, что это конкретная установка отсюда, и когда создана.
# Не защита от копирования как такового (см. README), а доказательство
# происхождения.
AGENT_ID="$(date +%Y%m%d)-$(head -c4 /dev/urandom | od -An -tx1 | tr -d ' \n')"
{
  head -n 1 "$TARGET/AGENTS.md"
  echo ""
  echo "<!-- agent-id: ${AGENT_ID} · создан: $(date +%Y-%m-%d) · владелец: Victor · из novyj_agent_kit (приватный репозиторий) -->"
  tail -n +2 "$TARGET/AGENTS.md"
} > "$TARGET/AGENTS.md.tmp" && mv "$TARGET/AGENTS.md.tmp" "$TARGET/AGENTS.md"

sed -i "s/{{YEAR}}/$(date +%Y)/" "$TARGET/LICENSE"

# Знание о собственном коде/заметках агента — по умолчанию, но не критично:
# если graphify не стоит на машине, просто пропускаем, ничего не ломаем.
if command -v graphify >/dev/null 2>&1; then
  (
    cd "$TARGET"
    graphify install --project >/dev/null
    graphify install --project --platform codex >/dev/null
    # graphify дописывает секцию "## graphify" в CLAUDE.md — у нас CLAUDE.md
    # это только указатель на AGENTS.md, сама секция уже отдельно легла в
    # AGENTS.md той же командой — возвращаем CLAUDE.md к одной строке.
    printf '@AGENTS.md\n' > CLAUDE.md
  )
  echo "graphify подключён (Claude Code + Codex) — граф строится по команде"
  echo "\`graphify .\` / \`/graphify .\`, когда в папке появится что реально мапить."
else
  echo "graphify не найден в PATH — пропускаю (не обязателен, ставится позже:"
  echo "  uv tool install graphifyy && cd \"$TARGET\" && graphify install --project)"
fi

echo "Готово: $TARGET"
echo "Дальше: открой Claude Code в этой папке (cwd = $TARGET) и напиши любое"
echo "первое сообщение, например «привет» — агент сам начнёт знакомство."
