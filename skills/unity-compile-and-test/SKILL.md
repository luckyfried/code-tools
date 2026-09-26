---
name: unity-compile-and-test
description: Use after any C# script, assembly definition, package, or asset change in a Unity 6 (6000.x) project, to prove the project compiles with a clean Console and the Edit Mode and Play Mode tests pass before you report done. Covers both paths - editor open (Unity CLI `unity recompile` / Pipeline commands, or the Unity MCP tools) and editor closed (headless `-batchmode` compile and `-runTests` with NUnit XML results) - plus connecting the Unity MCP server and fixing common compile, license, and lock failures. Triggers - "does it compile", "run the tests", "run the Unity tests", "batchmode", "headless Unity", "check the console", "red console", "compile errors", "CS0246", "error CS", "Test Runner", "EditMode tests", "PlayMode tests". This is the verify workflow; for the full Unity CLI command reference use Unity's own unity-cli skill.
---

# Unity compile and test

The loop is: change, get the project to compile with a clean Console, run the tests that cover the change, report. Commands below are for Unity 6 (6000.x). Differences from 2022.3 are noted where they matter.

Placeholders used throughout:

- `<ProjectDir>`: the folder that contains `Assets/`, `Packages/` and `ProjectSettings/`.
- `<Version>`: the editor version the project uses, for example `6000.3.7f1`.
- `<Unity>`: the full path to that editor's executable (step 1 of the editor-closed path).

## The rule

After any C# or asset change, you are not done until:

1. The project compiles with zero `error CS####` lines, and the Console has no errors you caused (fix warnings you introduced too).
2. The tests that cover the change have run, at least one test actually ran, and every one passed.

Then report exactly what you ran and what it showed: the full command (or the MCP tool call), its exit code, the error count, the test platform and filter, total/passed/failed/skipped counts, and the name and first failure line of every failing test. If you could not compile or test (no editor found, license failure, no tests exist, the project is open and no connection is available), say so plainly. Never report "done" or "should work" on a change that was not compiled, and never report done with a red Console.

## Pick the path

A project can be open in only one Unity instance at a time; batch mode cannot open a project the editor already has open. So first find out whether the editor has this project open:

```
Windows:      tasklist /FI "IMAGENAME eq Unity.exe"
macOS/Linux:  pgrep -fl Unity
```

`pgrep` also matches Unity Hub; look for a Unity process whose command line contains this project's path. With the Unity CLI installed, `unity status` shows each connected editor's project path, version and process ID.

- Editor open: use path A. Do not kill the editor; it may hold unsaved scenes. If path A is not available, ask the user to save and close the editor, then use path B.
- Editor closed: use path B.

## Path A: editor open

### A1. Check what is connected before relying on it

Two official ways in, both needing Unity 6.0 or later (not available on 2022.3):

- **Unity CLI** (experimental) with the Unity Pipeline package in the project. Check with `unity --version`, then `unity status`. If the Pipeline package is missing, the user runs `unity pipeline install` in the project; setup is on docs.unity.com under Unity CLI > Install Pipeline package.
- **Unity MCP tools**. List the MCP servers your client has connected (in Claude Code, `claude mcp list`) and the tools they expose. Do not assume a Unity server is there, approved, or pointed at this project. Setup is in [references/unity-mcp-setup.md](references/unity-mcp-setup.md).

If neither is connected, use path B once the editor is closed.

### A2. Compile

```
unity recompile
```

Run it from `<ProjectDir>`. It recompiles the running editor's scripts, lists each compiler error with file and line, and exits `0` on success, `6` on compile errors, `7` when no editor answered. `unity recompile --strict` also fails on warnings. For targeting a specific editor, run `unity recompile --help`.

Through MCP: there is no single documented "recompile" tool name; use whatever compile or refresh tool the connected server lists, then read the Console (A3).

### A3. Read the Console

- Unity CLI: `unity command` (alias `unity cmd`) lists the commands the connected editor exposes; `unity list` lists its tools with parameter schemas. Use the console-reading command it lists. Recent Pipeline versions expose `recompile`, `recompile_status`, `run_tests` and `test_status`; call one with `unity command <name>`.
- Unity MCP: `Unity_ReadConsole` reads the Console. Filter to errors first, then warnings.

A clean compile with Console errors still in it is not clean. Errors from before your change: say they were already there; do not count them as yours, and do not hide them.

### A4. Run the tests

- `unity command run_tests`, then `unity command test_status` for the result. Check `unity command` for the parameters your Pipeline version takes (platform, filter).
- `unity test` is not the editor-open path: it runs tests in a batch-mode editor and refuses a project that is already open. Use it in path B.
- Through MCP: use the test-running tool the server lists, if any. If none, the user can run the Test Runner window (Window > General > Test Runner) and you read the result from the Console, or the user closes the editor and you use path B.

The full Unity CLI command reference is Unity's own `unity-cli` agent skill (`unity skill show` prints it; `unity skill install <client>` installs it). Use it for commands and flags not covered here, and `unity <command> --help` as the authority for the installed version.

### Unity's official skills

Unity publishes its own agent skills (UI, 2D and tilemaps, URP, multiplayer and live services, packages, and more) under the Unity Companion License. They are not bundled with these skills; each user installs them from Unity:

- Claude Code: `claude plugin marketplace add Unity-Technologies/unity-agent-plugin`, then `claude plugin install unity@unity-agent-plugin` (inside a session: `/plugin marketplace add …` and `/plugin install …`).
- Codex: `codex plugin marketplace add Unity-Technologies/unity-agent-plugin`, then `codex plugin add unity@unity-agent-plugin`.
- The `unity-cli` skill alone: `unity skill install <client>`.

Other skills here name Unity's skills (`unity-cli`, `ui-uitk`, `setup-multiplayer-services` and so on) where the topics meet. When one is not installed and the task needs it, tell the user how to install it rather than guessing its content.

## Path B: editor closed (headless batch mode)

### B1. Find the editor

Read the version from `<ProjectDir>/ProjectSettings/ProjectVersion.txt`, line `m_EditorVersion: <Version>`. Use exactly that version. Do not open the project in a different version: it upgrades or reimports the project.

With the Unity CLI installed, `unity editors -i` lists installed editors and their paths, and `unity install-path` shows where the CLI and Hub install them. Otherwise, the executable under a Unity Hub install is at:

| OS | Executable |
|---|---|
| Windows | `C:\Program Files\Unity\Hub\Editor\<Version>\Editor\Unity.exe` |
| macOS | `/Applications/Unity/Hub/Editor/<Version>/Unity.app/Contents/MacOS/Unity` |
| Linux | `<HubInstallDir>/<Version>/Editor/Unity` (Unity's own example uses `/opt/Unity/Hub/Editor`) |

The Hub install location can be changed, so if the file is not there, check `unity editors -i` or ask the user. If the required version is not installed, say so; `unity install <Version>` installs it, but ask before downloading an editor.

Write `<Unity>` down once found and reuse it.

### B2. Compile

Opening a project in batch mode imports assets and compiles scripts. Capture the log to a file and read the exit code separately; never pipe into `tail` or `head`, which hides the exit code.

macOS / Linux:

```
"<Unity>" -batchmode -nographics -quit -projectPath "<ProjectDir>" -logFile "<ProjectDir>/Logs/compile.log"; echo $?
```

Windows (cmd):

```
"<Unity>" -batchmode -nographics -quit -projectPath "<ProjectDir>" -logFile "<ProjectDir>\Logs\compile.log"
echo %ERRORLEVEL%
```

| Flag | Effect |
|---|---|
| `-batchmode` | No human interaction, no dialogs. When an operation or script code fails, Unity exits with return code 1. |
| `-nographics` | Does not initialize the graphics device, so it runs on machines without a GPU. Output logs are off unless you pass `-logFile`. |
| `-quit` | Quits after other commands finish. Can hide errors from the console, but they stay in the log. Never use it with `-runTests` (B4). |
| `-projectPath` | The project to open. Quote paths with spaces. |
| `-logFile <path>` | Writes the editor log to that file. `-` writes to the console instead. |
| `-accept-apiupdate` | Runs the API Updater in batch mode; it does not run otherwise, which can leave compile errors in code using obsolete APIs. Add it after an editor upgrade. |

Never add `-ignorecompilererrors` to a verify run; it starts the project despite compile errors.

### B3. Read the log

Exit code `0` is necessary but not sufficient; read the log either way. Search it for compiler errors:

```
grep -n "error CS" "<ProjectDir>/Logs/compile.log"
```

Compiler errors look like:

```
Assets/Scripts/Player.cs(42,13): error CS0246: The type or namespace name 'Foo' could not be found (are you missing a using directive or an assembly reference?)
```

That is file, (line, column), error code, message. Errors cascade: fix the first one, compile again, repeat. Also look for exceptions, `Error` lines from package resolution, and license errors near the top of the log.

Without `-logFile`, the editor log is at: Windows `%LOCALAPPDATA%\Unity\Editor\Editor.log`, macOS `~/Library/Logs/Unity/Editor.log`, Linux `~/.config/unity3d/Editor.log`. The Package Manager log `upm.log` sits in the same folder.

### B4. Run the tests

Unity Test Framework adds these arguments. Do not pass `-quit`: the Test Framework does not support it while tests run, and it makes the editor quit before in-progress tests finish.

macOS / Linux:

```
"<Unity>" -batchmode -projectPath "<ProjectDir>" -runTests -testPlatform EditMode -testResults "<ProjectDir>/Logs/editmode-results.xml" -logFile "<ProjectDir>/Logs/editmode.log"; echo $?
```

Windows (cmd):

```
"<Unity>" -batchmode -projectPath "<ProjectDir>" -runTests -testPlatform EditMode -testResults "<ProjectDir>\Logs\editmode-results.xml" -logFile "<ProjectDir>\Logs\editmode.log"
echo %ERRORLEVEL%
```

Run again with `-testPlatform PlayMode` and a different results file for Play Mode tests.

| Argument | Effect |
|---|---|
| `-runTests` | Runs tests in the project. |
| `-testPlatform` | `EditMode`, `PlayMode` (Play Mode in the editor), or a `BuildTarget` value (Play Mode on a built player). Defaults to `EditMode`. |
| `-testResults <path>` | Where the NUnit XML result file goes. Defaults to the project root. |
| `-testFilter "<a;b>"` | Semicolon-separated full test names, or a regex on full names. `!` negates. |
| `-testCategory "<a;b>"` | Semicolon-separated categories, or a regex. `!` negates. With `-testFilter`, only tests matching both run. |
| `-assemblyNames "<a;b>"` | Only these test assemblies. |
| `-runSynchronously` | Edit Mode only; all tests in one editor update. Filters out `[UnityTest]` and tests with `[UnitySetUp]`/`[UnityTearDown]`. |
| `-retry <n>` / `-repeat <n>` | Retry failing tests / repeat passing tests up to n times. |

Pick the narrowest filter that covers your change first (the test class for the code you edited), then run the whole platform before reporting.

`-nographics` disables the graphics device; Play Mode tests that render need it, so leave `-nographics` off for those.

Alternative with the Unity CLI (batch mode; refuses a project that is open): `unity test` runs Edit Mode and Play Mode tests and writes NUnit XML to `test-results.xml` by default (`--output` changes it). It takes `--mode` and `--filter`; check `unity test --help` for the exact values. Exit codes: `0` passed, `8` tests ran and one or more failed, `6` the run did not reach a verdict (compile error, license, crash, timeout).

### B5. Read the results

The Test Framework has no common exit-code definition, so the XML is the verdict, not the exit code.

- Missing results file: the run did not finish. Read the `-logFile` log from the end for compile errors, a crash, or a license failure.
- Open the XML. The root `<test-run>` carries `total`, `passed`, `failed`, `skipped` and `result`. Each `<test-case>` has `fullname` and `result`; a failed one has `<failure><message>` and `<stack-trace>`.
- `total="0"` (zero tests matched) is a failure, not a pass. Check the filter against the test's full name (`Namespace.Class.Method`), and check the test assembly definition references the assembly under test and is set up for the right platform.

2022.3: the Test Framework is the `com.unity.test-framework` package with the same arguments and the same `-quit` rule; its docs are in the package documentation rather than the Unity Manual.

### B6. Fix and repeat

A compile error or failing test means back to the code: fix, compile (B2), rerun the same tests (B4). Stop only when the compile is clean and the tests pass, then report as in "The rule".

## Troubleshooting

| Symptom | Fix |
|---|---|
| Batch mode refuses to open the project, or says another Unity instance has it open | The editor (or a hung batch run) holds the project. Find it with the process check under "Pick the path"; ask the user to close it; do not kill an editor you did not start. |
| `error CS0246` / `CS0234` for a type that exists in the project | The type lives in another assembly definition (`.asmdef`) that yours does not reference. Add that assembly to the `.asmdef`'s Assembly Definition References. Test assemblies need references to the assemblies they test. |
| Code inside `#if SOME_SYMBOL` does or does not compile unexpectedly | Scripting define symbols are set per platform in Project Settings > Player > Other Settings > Scripting Define Symbols, and an `.asmdef`'s Define Constraints decide whether that whole assembly compiles. A batch run compiles for the active build target. |
| Compile errors in packages, or the log shows package resolution errors | Read `upm.log` (B3 locations). Check `Packages/manifest.json` for a bad version or unreachable registry. Fix resolution first; script errors after it are often a side effect. |
| Batch run exits at startup with a license error | The machine has no active license for batch mode. The user activates one (Unity Hub, `unity license`, or the `-username`/`-password`/`-serial` arguments with `-batchmode`). Never put credentials in a command you log or report. |
| Editor open, but `unity recompile` or the MCP tools time out | The editor is busy importing, compiling, or stuck in a domain reload. Wait for the progress bar to finish; if it never does, ask the user to restart the editor. `unity recompile` exits `7` when no editor answered. |
| Unity MCP client connects but no tools work | The connection is pending approval. See [references/unity-mcp-setup.md](references/unity-mcp-setup.md). |
| Test run ends early with no results file | `-quit` was passed with `-runTests`; it quits before tests finish. Remove it. |
| Test run hangs | A Play Mode test waits on something that never happens. Read the log's last lines to find the test. |
| Zero tests ran | Wrong filter, wrong `-testPlatform`, or the test assembly is not compiled for that platform. |
