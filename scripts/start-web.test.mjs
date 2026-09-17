import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import assert from "node:assert/strict";
import test from "node:test";

test("Windows launcher opens the browser once, only when Next is ready", { skip: process.platform !== "win32" }, () => {
  const bat = readFileSync(new URL("../start-web.bat", import.meta.url), "utf8");
  assert.ok(bat.includes('cd /d "%~dp0"'));
  const command = bat.match(/powershell\.exe -NoProfile -Command "(.+)"/)[1];
  for (const ready of [false, true]) {
    const result = spawnSync("powershell.exe", ["-NoProfile", "-Command", `
      $ErrorActionPreference = 'Stop'
      $script:openedUrls = @()
      function npm.cmd {
        if (($args -join ' ') -ne 'run dev') { throw 'Unexpected npm command' }
        'Starting...'
        ${ready ? "'Ready in 2s'; 'Ready in 3s'" : "'Failed to start'"}
      }
      function Start-Process { param($FilePath) $script:openedUrls += $FilePath }
      ${command}
      if ($script:openedUrls.Count -ne ${ready ? 1 : 0}) { throw 'Unexpected browser open count' }
      if (${ready ? "$script:openedUrls[0] -ne 'http://127.0.0.1:30141'" : "$false"}) { throw 'Wrong URL' }
    `], { encoding: "utf8" });
    assert.equal(result.status, 0, result.stderr || result.error?.message);
  }
});
