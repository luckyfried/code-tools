---
name: ue-build-and-verify
description: Use when you must compile an Unreal Engine 5 C++ project from the command line and prove the change works - locating the engine, building the <Project>Editor target with Build.bat/Build.sh/UnrealBuildTool, reading compiler/UHT/linker errors and logs, and running automation tests headless with UnrealEditor-Cmd. Not for C++ language questions, Build.cs/module setup (ue-module-build-system), or writing tests (ue-test-authoring).
---

# UE build and verify

The loop is: edit, build the editor target, fix every error, run the relevant automation tests headless, report. Commands below are for UE 5.8 and are unchanged back to 5.4 unless noted.

Placeholders used throughout:

- `<EngineRoot>`: the folder that contains `Engine/` (for example `C:\Program Files\Epic Games\UE_5.8`).
- `<ProjectDir>`: the folder that contains `<Project>.uproject`.
- `<Project>`: the `.uproject` file name without the extension.

## The rule

After any C++ change, you are not done until:

1. The editor target builds with exit code 0.
2. Every compiler, UHT and linker error you caused is fixed (warnings you introduced are fixed too).
3. The automation tests that cover the change have been run and pass.

Then report exactly what you ran and what happened: the full build command and its result, the full test command, the test filter, pass/fail counts, and the name and first error line of every failing test. If you could not build or test (no engine found, editor open, no tests exist), say so plainly. Never report "done" or "should work" on code that was not compiled.

## Workflow

### 1. Find the engine

Read `EngineAssociation` in `<ProjectDir>/<Project>.uproject`:

| Value | Meaning | Where the engine is |
|---|---|---|
| A version such as `"5.8"` | Launcher (installed) engine | Windows default: `C:\Program Files\Epic Games\UE_5.8`. macOS default: `/Users/Shared/Epic Games/UE_5.8`. The `UE_<version>` folder name is fixed; the parent folder can be changed at install time. |
| Empty `""` | Engine sits in the same tree as the project | Walk up from `<ProjectDir>` until you find a folder containing `Engine/Build/BatchFiles`. |
| Anything else (an identifier) | A source build registered on this machine | Ask the user for the engine path. |

Linux has no launcher: the engine is either a source build or Epic's precompiled Linux zip, extracted wherever the user chose. Ask for the path if it is not obvious.

Confirm the engine by checking that `<EngineRoot>/Engine/Build/BatchFiles` exists. Once found, write the path down and reuse it; do not search again every build.

### 2. Find the editor target

```
ls <ProjectDir>/Source/*.Target.cs
```

The editor target is the file whose class sets `Type = TargetType.Editor`; by convention it is `<Project>Editor.Target.cs`, and the target name is the file name without `.Target.cs` (for example `MyGameEditor`).

### 3. Make sure the editor is closed

Close the editor before a command-line build. Live Coding is on by default in the editor, and while it is active UnrealBuildTool refuses to build:

```
Unable to build while Live Coding is active. Exit the editor and game, or press Ctrl+Alt+F11 if iterating on code in the editor or game
```

Check for a running editor:

```
Windows:      tasklist /FI "IMAGENAME eq UnrealEditor.exe"
macOS/Linux:  pgrep -fl UnrealEditor
```

If one is running, ask the user to save and close it. Do not kill it yourself; it may hold unsaved work. Turning Live Coding off (Editor Preferences > General > Live Coding) is the user's choice, not a substitute for closing the editor before a clean command-line build.

### 4. Build the editor target (Development)

Run from any directory; use absolute paths. Capture output to a file so you can read it after.

Windows (cmd):

```
"<EngineRoot>\Engine\Build\BatchFiles\Build.bat" -Target="<Project>Editor Win64 Development" -Project="<ProjectDir>\<Project>.uproject" > build.log 2>&1
echo %ERRORLEVEL%
```

macOS:

```
"<EngineRoot>/Engine/Build/BatchFiles/Mac/Build.sh" -Target="<Project>Editor Mac Development" -Project="<ProjectDir>/<Project>.uproject" > build.log 2>&1; echo $?
```

Linux:

```
"<EngineRoot>/Engine/Build/BatchFiles/Linux/Build.sh" -Target="<Project>Editor Linux Development" -Project="<ProjectDir>/<Project>.uproject" > build.log 2>&1; echo $?
```

Notes:

- `Development` with the `Editor` target is the "Development Editor" configuration the IDE uses. Keep it unless the user asks for another.
- To rebuild just one module while iterating, add `-Module="<ModuleName>"` to the same command. Always finish with a full target build before reporting.
- In PowerShell, call the batch file with `& "<EngineRoot>\Engine\Build\BatchFiles\Build.bat" ...` and read `$LASTEXITCODE`.
- Do not pipe the build into `tail` or `head` to shorten it; the pipe hides the build's exit code. Redirect to a file, then read the file.
- `RunUAT BuildCookRun` is for building, cooking and packaging a game, not for this loop. For reference, Epic's documented form is:
  ```
  "<EngineRoot>/Engine/Build/BatchFiles/RunUAT.sh" BuildCookRun -project="<ProjectDir>/<Project>.uproject" -platform=Linux -configuration=Development -build -cook -pak -stage
  ```
  (`RunUAT.bat` and `-platform=Win64` on Windows, `-platform=Mac` on macOS.)

### 5. Read and fix errors

Exit code 0 means the build succeeded. Anything else: open `build.log` and find the first real error, not the last line. Errors cascade; fix the first one, rebuild, repeat.

| What you see | Stage | What it usually means |
|---|---|---|
| `File.h(12): Error: ...` before any compile step | UnrealHeaderTool (reflection) | Bad `UCLASS`/`USTRUCT`/`UPROPERTY`/`UFUNCTION` specifier, missing `GENERATED_BODY()`, or `#include "X.generated.h"` not the last include in the header. |
| `File.cpp(40): error C2065: ...` (MSVC) or `File.cpp:40:12: error: ...` (clang) | Compiler | Ordinary C++ error at that file and line. |
| `error LNK2019: unresolved external symbol` (MSVC) or `undefined symbol` / `undefined reference` (clang/ld) | Linker | Usually a missing module dependency in a `Build.cs` or a missing `<MODULE>_API` export. Module setup is covered by the `ue-module-build-system` skill. |
| `Unable to build while Live Coding is active` | UBT | Editor is running. See step 3. |
| UBT says it cannot find the target | UBT | Wrong target name. Recheck step 2. |

Logs:

- Build output: the `build.log` you captured.
- Editor and test runs: `<ProjectDir>/Saved/Logs/`, or the exact file you pass with `-abslog=`.

### 6. Regenerate project files only when the IDE needs them

Command-line builds do not use IDE project files; UnrealBuildTool reads the `.Build.cs` and `.Target.cs` files directly. Regenerate only so an IDE picks up new files or modules:

- Any OS: right-click the `.uproject` and choose Generate Visual Studio Files (Windows) or Generate Xcode Files (macOS).
- Source engine, Windows: `GenerateProjectFiles.bat "<ProjectDir>\<Project>.uproject" -Game` from `<EngineRoot>`.
- Source engine, macOS: run `GenerateProjectFiles.command` in `<EngineRoot>`.
- Source engine, Linux: `./GenerateProjectFiles.sh` in `<EngineRoot>` (add `-vscode` for a VS Code workspace).

These scripts are wrappers that run UnrealBuildTool with `-ProjectFiles`.

### 7. Run automation tests headless

The editor must be closed and the build must have succeeded first.

Windows:

```
"<EngineRoot>\Engine\Binaries\Win64\UnrealEditor-Cmd.exe" "<ProjectDir>\<Project>.uproject" -ExecCmds="Automation RunTest <Filter>;Quit" -unattended -nullrhi -nosplash -stdout -ReportExportPath="<ProjectDir>\Saved\TestReport" -abslog="<ProjectDir>\Saved\Logs\TestRun.log"
```

macOS / Linux (`<Platform>` is `Mac` or `Linux`):

```
"<EngineRoot>/Engine/Binaries/<Platform>/UnrealEditor-Cmd" "<ProjectDir>/<Project>.uproject" -ExecCmds="Automation RunTest <Filter>;Quit" -unattended -nullrhi -nosplash -stdout -ReportExportPath="<ProjectDir>/Saved/TestReport" -abslog="<ProjectDir>/Saved/Logs/TestRun.log"
```

If `UnrealEditor-Cmd` is not present on Linux, `Engine/Binaries/Linux/UnrealEditor` takes the same arguments.

What the flags do:

| Flag | Effect |
|---|---|
| `-ExecCmds="...;Quit"` | Runs the console command, then quits when the tests finish. |
| `-unattended` | No user input; no dialogs that wait for someone. |
| `-nullrhi` | No rendering; runs headless. Tests that need rendering (screenshot comparison) will not work with it. |
| `-nosplash` | No splash screen. |
| `-stdout` | Log to stdout so you can see progress. |
| `-ReportExportPath=` | Writes `index.json` and `index.html` with per-test results to that folder. |
| `-abslog=` | Writes the run's log to that exact file. |
| `-ResumeRunTest` | With `-ReportExportPath`, resumes an interrupted run from the first test that did not finish. |

Filters (`<Filter>`):

| Filter | Runs |
|---|---|
| `MyGame.Inventory.AddItem` | That one test (full test name). |
| `MyGame.Inventory` | Every test whose name is under that section. |
| `MyGame.Inventory.AddItem+MyGame.Inventory.RemoveItem` | Several named tests. |
| `Group:MyGroup` | A test group defined in `DefaultEngine.ini` (see Configure Automation Tests in Epic's docs). |

Pick the narrowest filter that covers your change: the tests for the class or feature you edited first, then the wider section for that module.

Alternative runner (Gauntlet, via UAT), which boots the editor and runs the named tests:

```
"<EngineRoot>\Engine\Build\BatchFiles\RunUAT.bat" RunUnreal -test=UE.EditorAutomation -runtest=<Filter> -project="<ProjectDir>\<Project>.uproject" -build=editor
```

### 8. Read the results

- Open `<ReportExportPath>/index.json` and check every test's result and error messages. Do not rely only on the process exit code.
- If `index.json` is missing, the run did not finish: read the `-abslog` file from the end, looking for a crash, an `Error:` line, or a test that never completed.
- If the filter matched zero tests, that is not a pass. Check the test name against the test's registration (the `ue-test-authoring` skill covers how tests are named) and rerun.

### 9. Fix and repeat

A failing test means back to step 5 or the code: fix, rebuild (step 4), rerun the same filter (step 7). Stop only when the build is clean and the tests pass, then report as described in "The rule".

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Unable to build while Live Coding is active` | Ask the user to close the editor, then rebuild. |
| Build succeeds but the editor or test run still shows old behavior | You built a different target or configuration than the one you ran. Build `<Project>Editor ... Development` and run `UnrealEditor-Cmd` from the same `<EngineRoot>`. |
| `.uproject` names a version you cannot find | That engine version is not installed at the default path. Ask the user where it is; do not build against a different engine version. |
| UHT error in a header you did not touch | A header you changed is included there, or a `*.generated.h` include is not last. Fix the first UHT error only, then rebuild. |
| Linker errors after adding an include from another module | The module dependency is missing from `Build.cs`. Use the `ue-module-build-system` skill. |
| Test run hangs | Something is waiting for input or rendering. Confirm `-unattended` and `-nullrhi` are present and `;Quit` is inside the `-ExecCmds` quotes. |
| Test run exits and `index.json` is missing | The editor crashed or failed to load the project. Read the `-abslog` file; a crash callstack or a module load failure is usually near the end. |
| Zero tests ran | Filter does not match any test name, or the test's module or plugin is not enabled or not built. |
| Quoting breaks in PowerShell | Run the command in `cmd /c "..."`, or build the argument list as an array and pass it with `&`. |
