// src/logger.ts
import pino from "pino";
import path from "path";
import fs from "fs";
import { v4 as uuidv4 } from "uuid";

const LOG_DIR = "logs/session";
fs.mkdirSync(LOG_DIR, { recursive: true });

export function initializeSession(sessionId?: string): string {
  return sessionId ?? uuidv4();
}

export function getSessionLogger(sessionId: string) {
  const filePath = path.join(LOG_DIR, `${sessionId}.log`);

  return pino({
    level: "info",
    transport: {
      targets: [
        {
          target: "pino-pretty", // ✅ human-readable console
          options: { colorize: true },
          level: "info",
        },
        {
          target: "pino/file",   // ✅ file output
          options: { destination: filePath, mkdir: true },
          level: "info",
        },
      ],
    },
  });
}
