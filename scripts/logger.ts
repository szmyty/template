import fs from "fs";
import path from "path";
import pino from "pino";
import { v4 as uuidv4 } from "uuid";

const LOG_DIR = "logs/session";
fs.mkdirSync(LOG_DIR, { recursive: true }); // ✅ Ensure logs dir exists

export function initializeSession(sessionId?: string): string {
  return sessionId ?? uuidv4();
}

export function getSessionLogger(sessionId: string) {
  const logPath = path.join(LOG_DIR, `${sessionId}.log`);
  return pino(
    {
      level: "info",
      formatters: {
        level: (label) => ({ level: label }),
      },
      timestamp: pino.stdTimeFunctions.isoTime,
    },
    pino.destination({
      dest: logPath,
      minLength: 4096,
      sync: false,
    })
  );
}
