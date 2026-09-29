# Connecting Unity to an MCP client

Two official MCP servers reach a running Unity editor. Both need Unity 6 (6000.0) or later.

Before relying on either, list the MCP servers your client has connected and the tools they expose. A server that is configured but not approved, not running, or pointed at a different project is not a connection.

## Option 1: Unity CLI `unity mcp` (current)

Unity has deprecated the MCP server built into the AI Assistant package (`com.unity.ai.assistant`) and replaced it with `unity mcp` in the Unity CLI. It uses the same protocol, so clients connect the same way. Third-party MCP packages are not affected.

1. Install the Unity CLI (docs.unity.com, Unity CLI > Use the Unity CLI).
2. In the project, run `unity pipeline install` and let the editor recompile.
3. Run `unity mcp configure <client>` (for example `claude`, `cursor`, `vscode`, `windsurf`). It writes the client's own config file. `unity mcp configure --list` shows supported clients and their status.
4. Optionally `unity skill install <client>` to install Unity's agent skills.

The CLI drives the editor over a localhost-only server. If the agent can run shell commands, `unity command` and `unity eval` are faster than MCP and use fewer tokens.

If the project also has the AI Assistant package, use version 2.13 or later; earlier versions conflict with the CLI.

## Option 2: AI Assistant package relay (deprecated)

For projects still on the `com.unity.ai.assistant` MCP server.

1. Open the project. In Edit > Project Settings > AI > Unity MCP, check that Unity Bridge shows Running. Select Start if it shows Stopped.
2. On startup Unity installs the relay binary to `.unity/relay/` in the user's home folder:

   | Platform | Relay executable |
   |---|---|
   | macOS (Apple silicon) | `~/.unity/relay/relay_mac_arm64.app/Contents/MacOS/relay_mac_arm64` |
   | macOS (Intel) | `~/.unity/relay/relay_mac_x64.app/Contents/MacOS/relay_mac_x64` |
   | Windows | `%USERPROFILE%\.unity\relay\relay_win.exe` |
   | Linux | `~/.unity/relay/relay_linux` |

3. Configure the client. The Integrations section of that settings page can do it (select the client, then Configure). Manually, add a server entry that launches the relay with `--mcp`:

   ```json
   {
     "mcpServers": {
       "unity-mcp": {
         "command": "<ABSOLUTE_HOME>/.unity/relay/relay_mac_arm64.app/Contents/MacOS/relay_mac_arm64",
         "args": ["--mcp"]
       }
     }
   }
   ```

   Replace `<ABSOLUTE_HOME>` with the user's absolute home path; clients may not expand `~`. `--mcp` is required. With several editors open, the relay connects to the first it finds; add `"--project-path", "<ProjectDir>"` to `args` (or set `UNITY_PROJECT_PATH` in `env`), or `--instance-id <editor PID>` (`UNITY_INSTANCE_ID`).

4. Approve the first connection: Edit > Project Settings > AI > Unity MCP > Pending Connections > Accept. Approved clients reconnect without asking again. A setting, Auto-approve in Batch Mode, approves every client when Unity runs in batch mode.
5. Test: the client appears under Connected Clients, and the client lists tools such as `Unity_ManageScene` and `Unity_ReadConsole`.

## When it does not connect

| Symptom | Fix |
|---|---|
| Bridge shows Stopped or will not start | Compile errors stop it. Fix them (path B of the skill if needed), then Start. |
| Client cannot start the server | Relay missing from `.unity/relay/`, wrong path in the config, or `--mcp` missing. Restarting the editor reinstalls the relay; the Locate Server button shows where it is. |
| Connects but tools fail | Connection is pending approval (step 4). |
| Tools time out | The editor is importing or compiling. Wait for it to finish. |
