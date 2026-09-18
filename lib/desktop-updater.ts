export type DesktopUpgradePhase = "checking" | "downloading" | "installing";

export interface DesktopUpgradeProgress {
  phase: DesktopUpgradePhase;
  downloadedBytes?: number;
  totalBytes?: number;
  targetVersion?: string;
}

export interface DesktopUpgradeResult {
  installed: boolean;
  targetVersion?: string;
}

declare global {
  interface Window {
    __TAURI_INTERNALS__?: unknown;
  }
}

export function isTauriDesktop(): boolean {
  return typeof window !== "undefined" && Boolean(window.__TAURI_INTERNALS__);
}

export async function isDesktopUpdaterAvailable(): Promise<boolean> {
  if (!isTauriDesktop()) return false;
  const { invoke } = await import("@tauri-apps/api/core");
  return invoke<boolean>("is_desktop_updater_available");
}

export async function installLatestDesktopRelease(
  onProgress: (progress: DesktopUpgradeProgress) => void,
): Promise<DesktopUpgradeResult> {
  if (!isTauriDesktop()) {
    throw new Error("Automatic installation is only available in the packaged desktop app.");
  }

  onProgress({ phase: "checking" });
  const [{ check }, { relaunch }] = await Promise.all([
    import("@tauri-apps/plugin-updater"),
    import("@tauri-apps/plugin-process"),
  ]);
  const update = await check({ timeout: 30_000 });
  if (!update) return { installed: false };

  let downloadedBytes = 0;
  let totalBytes: number | undefined;
  await update.downloadAndInstall((event) => {
    if (event.event === "Started") {
      totalBytes = event.data.contentLength;
      onProgress({
        phase: "downloading",
        downloadedBytes,
        totalBytes,
        targetVersion: update.version,
      });
    } else if (event.event === "Progress") {
      downloadedBytes += event.data.chunkLength;
      onProgress({
        phase: "downloading",
        downloadedBytes,
        totalBytes,
        targetVersion: update.version,
      });
    } else {
      onProgress({ phase: "installing", targetVersion: update.version });
    }
  });

  onProgress({ phase: "installing", targetVersion: update.version });
  await relaunch();
  return { installed: true, targetVersion: update.version };
}
