// src/logger.ts
import pino from "pino";
import fs from "fs";
import path from "path";
import { v4 as uuidv4 } from "uuid";

const LOG_DIR = "logs/session";
fs.mkdirSync(LOG_DIR, { recursive: true });

export type LogLevel = "trace" | "debug" | "info" | "warn" | "error" | "fatal";

export function initializeSession(sessionId?: string): string {
  return sessionId ?? uuidv4();
}

export function getSessionLogger(sessionId: string, level: LogLevel = "info") {
  const logPath = path.join(LOG_DIR, `${sessionId}.log`);

  return pino({
    level,
    transport: {
      targets: [
        {
          target: "pino-pretty",
          options: { colorize: true },
          level,
        },
        {
          target: "pino/file",
          options: { destination: logPath, mkdir: true },
          level,
        },
      ],
    },
  });
}
