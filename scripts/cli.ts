#!/usr/bin/env node

import { Command, InvalidArgumentError } from "commander";
import { readFileSync } from "fs";
import path from "path";

const program = new Command();

program
  .name("my-cli")
  .description("A powerful CLI tool")
  .version("1.0.0")
  .option("-v, --verbose", "enable verbose logging")
  .option("-c, --config <path>", "path to config file", "config.json")
  .hook("preAction", (thisCommand) => {
    if (thisCommand.opts().verbose) {
      console.log("[DEBUG] Verbose mode enabled");
    }
  });

/**
 * validatePort: parse int and throw on invalid input
 */
function validatePort(value: string): number {
  const port = parseInt(value, 10);
  if (isNaN(port) || port <= 0 || port > 65535) {
    throw new InvalidArgumentError("Port must be a number between 1 and 65535.");
  }
  return port;
}

/**
 * convert command
 */
program
  .command("convert <input> [output]")
  .description("Convert a file from one format to another")
  .option("-f, --format <format>", "Target format (json, csv, xml)", "json")
  .action((input, output, options, command) => {
    console.log(">> convert:");
    console.log({ input, output, format: options.format });
    if (command.parent?.opts().verbose) {
      console.log("[DEBUG] convert options:", command.opts());
    }
  });

/**
 * serve command
 */
program
  .command("serve")
  .description("Start a local server")
  .option("-p, --port <number>", "Port to listen on", validatePort, 8080)
  .option("--host <string>", "Hostname", "localhost")
  .action((options) => {
    console.log(">> serve:");
    console.log(`Starting server on ${options.host}:${options.port}`);
  });

/**
 * analyze command with variadic input
 */
program
  .command("analyze [files...]")
  .description("Analyze one or more files")
  .option("--report <type>", "Report type (summary, full)", "summary")
  .action((files, options) => {
    console.log(">> analyze:");
    console.log({ files, report: options.report });
  });

/**
 * config command that loads a file
 */
program
  .command("config get <key>")
  .description("Get a config value")
  .action((key, options, command) => {
    const configPath = command.parent?.opts().config ?? "config.json";
    const config = JSON.parse(readFileSync(configPath, "utf-8"));
    console.log(`Config value for "${key}":`, config[key]);
  });

/**
 * async example
 */
program
  .command("sleep <ms>")
  .description("Wait for N milliseconds then exit")
  .action(async (ms: string) => {
    const delay = parseInt(ms, 10);
    if (isNaN(delay)) throw new Error("Invalid number");
    console.log(`Sleeping for ${delay}ms...`);
    await new Promise((res) => setTimeout(res, delay));
    console.log("Awake!");
  });

program.parse();
