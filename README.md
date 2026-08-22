# BodyFPSController

A simulated-body first-person controller for Godot — you ride a real IK-driven
body rather than a floating gun. Converted from Brok3ncircuit's "Godot 4.6 New
IK" third-person aiming template.

Target feel: DayZ / Escape from Tarkov / Ready or Not / Ground Branch.

> **Private repo, and it needs to stay that way.** The base template is a paid
> asset from Brok3ncircuit (brokencircuit.itch.io). Its source and assets are in
> this history and are not mine to redistribute.

**Machines:** ThinkPad (Pop!_OS) and desktop (Windows). GitHub holds the
authoritative copy; both are working copies of it.

---

## Requirements

| Thing | Version | Needed for |
|---|---|---|
| Godot | **4.6.2 stable**, forward_plus | the project |
| Node.js | **22.x** | the `godot_mcp` dev addon only — not the game |
| Git | any recent | on Windows, install **Git for Windows** |

The game itself has no Node dependency. Node is only there so the MCP editor
bridge works.

---

# Setup — Linux

### 1. SSH key

Each machine gets its own key. Never copy a private key between machines.

```bash
ssh-keygen -t ed25519 -C "$(hostname)" -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub
```

Paste the public key at <https://github.com/settings/ssh/new>, then verify:

```bash
ssh -T git@github.com      # expect: "Hi SFrasher! You've successfully authenticated..."
```

### 2. Clone

```bash
git clone git@github.com:SFrasher/BodyFPSController.git
cd BodyFPSController
```

### 3. MCP addon dependencies

```bash
cd addons/godot_mcp/server
npm install
cd ../../..
```

### 4. Open in Godot

First open regenerates `.godot/`. Takes a minute or two.

### 5. Optional — VS Code

Create `.vscode/settings.json` (untracked by design):

```json
{
    "godotTools.editorPath.godot4": "/your/path/to/Godot_v4.6.2-stable_linux.x86_64",
    "editor.tabSize": 4,
    "editor.insertSpaces": false,
    "files.eol": "\n",
    "files.exclude": { "**/*.gd.uid": true }
}
```

### 6. Optional — Claude MCP bridge

`~/.config/Claude/claude_desktop_config.json`:

```json
"godot-mcp-pro": {
  "command": "/home/<you>/.nvm/versions/node/v22.x.x/bin/node",
  "args": ["/path/to/BodyFPSController/addons/godot_mcp/server/build/index.js"]
}
```

---

# Setup — Windows

### 0. Install the tooling

| | Where | Notes |
|---|---|---|
| Git for Windows | <https://git-scm.com/download/win> | Ships Git Bash **and** the `ssh-keygen` you need |
| Node.js 22.x | <https://nodejs.org> or [nvm-windows](https://github.com/coreybutler/nvm-windows) | nvm-windows if you want to juggle versions |
| Godot 4.6.2 | <https://godotengine.org/download/windows/> | Grab `Godot_v4.6.2-stable_win64.exe` — the **standard** build, not .NET |

The commands below work in **PowerShell** (Windows 10/11 ship OpenSSH) or in
**Git Bash**. Git Bash lets you use the Linux commands above verbatim, which is
often the path of least resistance.

### 1. SSH key

PowerShell:

```powershell
ssh-keygen -t ed25519 -C "$env:COMPUTERNAME" -f "$env:USERPROFILE\.ssh\id_ed25519"
Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub"
```

Paste the public key at <https://github.com/settings/ssh/new>. Give it a
different title than the laptop's key — `Desktop (Windows)`. Then verify:

```powershell
ssh -T git@github.com      # expect: "Hi SFrasher! You've successfully authenticated..."
```

**Generate a fresh key here.** Do not copy `id_ed25519` over from the ThinkPad.
Separate keys mean losing one machine doesn't mean revoking both.

### 2. Clone

```powershell
cd $env:USERPROFILE\Documents
git clone git@github.com:SFrasher/BodyFPSController.git
cd BodyFPSController
```

Avoid cloning into a OneDrive-synced folder. OneDrive and Godot's `.godot/`
cache fight each other, and you'll get file-lock errors mid-import.

### 3. MCP addon dependencies

```powershell
cd addons\godot_mcp\server
npm install
cd ..\..\..
```

### 4. Open in Godot

Launch `Godot_v4.6.2-stable_win64.exe`, Import, point it at `project.godot`.
First open regenerates `.godot/` — a minute or two of disk churn.

If Windows Defender slows the import to a crawl, adding the project folder as
an exclusion helps a lot.

### 5. Optional — VS Code

Create `.vscode/settings.json`. Backslashes must be **doubled** in JSON:

```json
{
    "godotTools.editorPath.godot4": "C:\\Godot\\Godot_v4.6.2-stable_win64.exe",
    "editor.tabSize": 4,
    "editor.insertSpaces": false,
    "files.eol": "\n",
    "files.exclude": { "**/*.gd.uid": true }
}
```

Forward slashes also work if you'd rather: `"C:/Godot/Godot_v4.6.2-stable_win64.exe"`.

### 6. Optional — Claude MCP bridge

Config lives at `%APPDATA%\Claude\claude_desktop_config.json`. Paste that path
into Explorer's address bar to find it. Doubled backslashes again:

```json
"godot-mcp-pro": {
  "command": "C:\\Program Files\\nodejs\\node.exe",
  "args": ["C:\\Users\\<you>\\Documents\\BodyFPSController\\addons\\godot_mcp\\server\\build\\index.js"]
}
```

Using nvm-windows, `command` is something like
`C:\\Users\\<you>\\AppData\\Roaming\\nvm\\v22.23.2\\node.exe`. Find it with
`where.exe node`.

---

## Two gotchas specific to running Linux + Windows on one repo

### Line endings — already handled, don't fight it

`.gitattributes` pins `* text=auto eol=lf`, so every text file is LF in the repo
**and** LF in your working tree on Windows. This deliberately overrides
`core.autocrlf`, whatever the Git for Windows installer set it to. Godot and VS
Code both handle LF on Windows fine.

If you ever see a diff where every single line changed, that's a line-ending
problem — don't commit it, say something. It means something bypassed the
attribute.

### Filename case — Windows won't catch your mistakes

Windows treats `res://Node/Player.tscn` and `res://node/player.tscn` as the same
file. Linux does not. A path typo you write on the desktop will load fine there
and **break on the ThinkPad**.

Match real casing exactly in every `res://` path and `preload()`. If you need to
change a file's capitalization, do it explicitly so git records it:

```bash
git mv -f OldName.gd NewName.gd
```

There are currently no case-colliding filenames in the repo — worth keeping it
that way.

---

## Working across two machines

```bash
git pull        # ALWAYS, before you touch anything
# ... work ...
git add -A
git commit -m "what changed and why"
git push        # ALWAYS, before you walk away from the machine
```

Clone **once** per machine. After that it's `pull` and `push` — cloning again
throws away whatever hasn't been pushed.

`pull.rebase` is set to `true` on the laptop; set it on the desktop too:

```bash
git config pull.rebase true
```

That replays your local commits on top of whatever came from the other machine.
Linear history, no merge commit every time you switch desks.

### The one rule that actually matters

**Never leave uncommitted work on one machine and start editing on the other.**

`Node/Player.tscn` is 3 MB of Godot's text scene format. `AnimLib/Global.tres`
is another 2 MB. These are technically text, so git *will* try to merge them —
and it will produce garbage. A scene conflict is not something you resolve by
hand; you pick one side and lose the other.

Pull before, push after. That's the whole discipline.

If you do get a conflict in a `.tscn` or `.tres`, don't hand-edit it:

```bash
git checkout --theirs Node/Player.tscn   # keep the remote version
# or
git checkout --ours   Node/Player.tscn   # keep the local version
git add Node/Player.tscn
git rebase --continue
```

---

## What's ignored, and why

| Path | Reason |
|---|---|
| `.godot/` | Per-machine import/shader caches. Regenerated on first open. |
| `node_modules/` | ~125 MB across three copies of the addon's Node server. Reinstallable. Matched at any depth so a stray `npm install` can't sneak it into history. |
| `.vscode/settings.json` | Machine-specific absolute path to the Godot binary. `extensions.json` **is** tracked — recommended extensions are portable. |
| `/GAME/` | Export output. The preset targets Windows Desktop → `GAME/NewIK.exe`, so exporting on the desktop drops a build here. Builds don't belong in history. |
| `/android/` | Generated Android build template. |

---

## Project background

- `PROJECT_CONTEXT.md` — scene structure, IK system, exported properties,
  current camera setup
- `FIRSTPERSON_ANALYSIS.md` — the conversion breakdown

Scope for now is **walk, look, aim**. The template's cover, weapon-switch, and
fire-mode inputs are inert leftovers and out of scope.
