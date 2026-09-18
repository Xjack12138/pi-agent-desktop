import { getAgentDir } from "@earendil-works/pi-coding-agent";
import { join, resolve } from "path";

export function getSessionStorageRoot(): string {
  const configured = process.env.PI_CODING_AGENT_SESSION_DIR?.trim();
  return configured ? resolve(configured) : join(getAgentDir(), "sessions");
}

export function getProjectSessionDir(cwd: string): string {
  const safePath = `--${resolve(cwd).replace(/^[/\\]/, "").replace(/[/\\:]/g, "-")}--`;
  return join(getSessionStorageRoot(), safePath);
}
