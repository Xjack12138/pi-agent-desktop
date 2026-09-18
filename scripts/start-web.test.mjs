import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import assert from "node:assert/strict";
import test from "node:test";

test("Windows launcher opens the browser once, only when Next is ready", { skip: process.platform !== "win32" }, () => {
  const bat = readFileSync(new URL("../start-web.bat", import.meta.url), "utf8");
  assert.ok(bat.includes('cd /d "%~dp0"'));
  assert.ok(bat.includes('set "PI_CODING_AGENT_DIR=%~dp0.pi-agent"'));
  assert.ok(bat.includes('set "PI_CODING_AGENT_SESSION_DIR=%USERPROFILE%\\.pi\\agent\\sessions"'));
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

test("desktop launcher uses the portable Pi profile", () => {
  const bat = readFileSync(new URL("../start-desktop.bat", import.meta.url), "utf8");
  assert.ok(bat.includes('set "PI_CODING_AGENT_DIR=%~dp0.pi-agent"'));
  assert.ok(bat.includes('set "PI_CODING_AGENT_SESSION_DIR=%USERPROFILE%\\.pi\\agent\\sessions"'));
  assert.ok(bat.includes('set "CARGO_HOME=%~dp0.tools\\cargo"'));
  assert.ok(bat.includes('set "RUSTUP_HOME=%~dp0.tools\\rustup"'));
  assert.ok(bat.includes('.tools\\node\\node.exe'));
  assert.ok(bat.includes('%CARGO_HOME%\\bin\\cargo.exe'));
  assert.ok(bat.includes("call npm.cmd run desktop:dev"));
});

test("desktop setup script is syntactically valid and installs every required tool", { skip: process.platform !== "win32" }, () => {
  const setup = new URL("./setup-desktop.ps1", import.meta.url);
  const parse = spawnSync("powershell.exe", ["-NoProfile", "-Command", `
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile('${setup.pathname.slice(1).replaceAll("'", "''")}', [ref]$null, [ref]$errors) | Out-Null
    if ($errors.Count) { $errors | ForEach-Object { Write-Error $_ }; exit 1 }
  `], { encoding: "utf8" });
  assert.equal(parse.status, 0, parse.stderr || parse.stdout);

  const source = readFileSync(setup, "utf8");
  assert.match(source, /latest-v22\.x/);
  assert.match(source, /win\.rustup\.rs\/x86_64/);
  assert.match(source, /Microsoft\.VisualStudio\.Workload\.VCTools/);
  assert.match(source, /DisplayName -eq "Microsoft Edge WebView2 Runtime"/);
  assert.match(source, /msedgewebview2\.exe/);
  assert.match(source, /winget\.exe/);
  assert.match(source, /LinkId=2124703/);
  assert.match(source, /npm\.cmd"\) ci/);
});
