// src/logger.ts
import fs from "fs";
import path from "path";
import pino from "pino";
import { v4 as uuidv4 } from "uuid";

export type LogLevel = "trace" | "debug" | "info" | "warn" | "error" | "fatal";

interface LoggerInitOptions {
  session?: string;
  level?: LogLevel;
  logDir?: string;
  namePrefix?: string;
}

let loggerInstance: pino.Logger | null = null;
let sessionId: string = uuidv4(); // fallback early session ID
let isLocked = false;

/**
 * Initializes the global logger singleton.
 */
export function initializeLogger({
  session,
  level = "info",
  logDir = "logs/session",
  namePrefix = "",
}: LoggerInitOptions = {}): pino.Logger {
  if (!loggerInstance) {
    // first-time initialization
    sessionId = session ?? sessionId;
    const logPath = prepareLogPath(logDir, namePrefix, sessionId);
    loggerInstance = createLogger(level, logPath);
    loggerInstance.info({ event: "logger-initialized", sessionId, level });
    return loggerInstance;
  }

  // already initialized — allow one-time override
  if (!isLocked && session && session !== sessionId) {
    sessionId = session;
    const logPath = prepareLogPath(logDir, namePrefix, sessionId);
    loggerInstance.info({ event: "logger-session-updated", newSessionId: sessionId });
  }

  isLocked = true;
  return loggerInstance;
}

/**
 * Returns the current logger instance.
 */
export function getLogger(): pino.Logger {
  if (!loggerInstance) {
    throw new Error("Logger not initialized. Call initializeLogger() first.");
  }
  return loggerInstance;
}

/**
 * Returns the current session ID used for logging.
 */
export function getSessionId(): string {
  return sessionId;
}

function prepareLogPath(logDir: string, namePrefix: string, sessionId: string): string {
  fs.mkdirSync(logDir, { recursive: true });
  return path.join(logDir, `${namePrefix}${sessionId}.log`);
}

function createLogger(level: LogLevel, path: string): pino.Logger {
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
          options: { destination: path, mkdir: true },
          level,
        },
      ],
    },
  });
}
