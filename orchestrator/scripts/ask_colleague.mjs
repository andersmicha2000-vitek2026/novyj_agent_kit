#!/usr/bin/env node
// Консультация между суб-агентами внутри одного оркестратора.
// Использование: node scripts/ask_colleague.mjs <кто_спрашивает> <кого_спросить> "<вопрос>"
//
// Нарочно НЕ использует --dangerously-skip-permissions: консультация — это
// вопрос и рассуждение в ответ, не поручение выполнить действие. Замки
// безопасности целевого суб-агента (.claude/settings.json, .codex/config.toml)
// действуют как обычно. Если ответ на вопрос потребовал бы действия из
// красной зоны светофора — целевой суб-агент должен отказаться и сказать
// почему, а не тихо обойти запрет.

import { spawn } from "node:child_process";
import { existsSync, mkdirSync, appendFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const [, , callerName, targetName, question] = process.argv;

if (!callerName || !targetName || !question) {
  console.error('Использование: node ask_colleague.mjs <кто_спрашивает> <кого_спросить> "<вопрос>"');
  process.exit(1);
}

const TIMEOUT_MS = 120_000;
const root = path.resolve(__dirname, ".."); // папка агента-оркестратора
const targetCwd = path.join(root, "agents", targetName);

if (!existsSync(targetCwd)) {
  console.error(`Суб-агент "${targetName}" не найден по пути ${targetCwd}`);
  process.exit(1);
}

function parseAnswer(stdout) {
  try {
    const parsed = JSON.parse(stdout);
    return (parsed.result ?? "").trim();
  } catch {
    return stdout.trim(); // неожиданный формат вывода — не теряем ответ целиком
  }
}

function askColleague() {
  return new Promise((resolve) => {
    const child = spawn("claude", ["-p", question, "--output-format", "json"], { cwd: targetCwd });

    let stdout = "";
    let stderr = "";
    let settled = false;

    const timer = setTimeout(() => {
      if (settled) return;
      settled = true;
      child.kill();
      resolve({ ok: false, answer: `Таймаут (${TIMEOUT_MS / 1000} сек) — ${targetName} не ответил вовремя.` });
    }, TIMEOUT_MS);

    child.stdout.on("data", (d) => (stdout += d));
    child.stderr.on("data", (d) => (stderr += d));

    child.on("close", (code) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      if (code === 0) {
        resolve({ ok: true, answer: parseAnswer(stdout) });
      } else {
        resolve({ ok: false, answer: `Ошибка (код ${code}): ${stderr.trim() || "нет вывода"}` });
      }
    });
  });
}

const startedAt = new Date();
const result = await askColleague();
const durationSec = Math.round((Date.now() - startedAt.getTime()) / 1000);

// Лог — в тот же дневник memory/ГГГГ-ММ-ДД.md, что уже описан в AGENTS.md,
// не отдельная новая сущность.
const memoryDir = path.join(root, "memory");
mkdirSync(memoryDir, { recursive: true });
const today = startedAt.toISOString().slice(0, 10);
const logFile = path.join(memoryDir, `${today}.md`);
const entry = `\n## Консультация ${startedAt.toISOString()} — ${callerName} → ${targetName} (${durationSec} сек)\n\n**Вопрос:** ${question}\n\n**Ответ${result.ok ? "" : " (ошибка/таймаут)"}:** ${result.answer}\n`;

if (existsSync(logFile)) {
  appendFileSync(logFile, entry);
} else {
  writeFileSync(logFile, `# Дневник — ${today}\n${entry}`);
}

console.log(result.answer);
process.exit(result.ok ? 0 : 1);
