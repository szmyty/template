#!/usr/bin/env node

import { Command } from "commander";
import { initializeSession, getSessionLogger } from "./logger";
import { readFileSync } from "fs";

const program = new Command();

let sessionId = ""; // Will store --session or generated UUID
let logger: ReturnType<typeof getSessionLogger>;

program
  .name("my-cli")
  .version("1.0.0")
  .option("--session <uuid>", "Session ID for logging")
  .option("--verbose", "Enable debug logging")
  .option("--config <path>", "Path to config file", "config.json")
  .hook("preAction", (thisCommand) => {
    // Session setup
    const opts = thisCommand.opts();
    sessionId = initializeSession(opts.session);
    logger = getSessionLogger(sessionId);

    logger.info({ event: "cli-start", args: process.argv.slice(2), session: sessionId });
    if (opts.verbose) {
      logger.info("Verbose logging enabled");
      console.log("[DEBUG] Logger initialized for session:", sessionId);
    }
  });

program
  .command("convert <input> [output]")
  .description("Convert a file")
  .option("-f, --format <format>", "Target format", "json")
  .action((input, output, options) => {
    logger.info({ event: "convert", input, output, format: options.format });
    console.log(`Converting ${input} to ${options.format}...`);
  });

program
  .command("config get <key>")
  .description("Fetch config value")
  .action((key) => {
    const config = JSON.parse(readFileSync(program.opts().config, "utf-8"));
    logger.info({ event: "config:get", key, value: config[key] });
    console.log(`Config[${key}]: ${config[key]}`);
  });

program
  .command("sleep <ms>")
  .description("Sleep for N milliseconds")
  .action(async (ms) => {
    const delay = parseInt(ms, 10);
    logger.info({ event: "sleep:start", ms: delay });
    await new Promise((r) => setTimeout(r, delay));
    logger.info("Woke up");
    console.log("Done sleeping.");
  });

program.parse();
