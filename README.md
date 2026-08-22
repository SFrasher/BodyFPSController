# BodyFPSController

A simulated-body first-person controller for Godot — you ride a real IK-driven
body rather than a floating gun. Converted from Brok3ncircuit's "Godot 4.6 New
IK" third-person aiming template.

Target feel: DayZ / Escape from Tarkov / Ready or Not / Ground Branch.

> **Private repo, and it needs to stay that way.** The base template is a paid
> asset from Brok3ncircuit (brokencircuit.itch.io). Its source and assets are in
> this history and are not mine to redistribute.

---

## Requirements

| Thing | Version | Needed for |
|---|---|---|
| Godot | **4.6.2 stable**, forward_plus | the project |
| Node.js | **22.x** | the `godot_mcp` dev addon only — not the game |

The game itself has no Node dependency. Node is only there so the MCP editor
bridge works.

---

## First-time setup on a new machine

### 1. Give the machine an SSH key GitHub trusts

Each machine gets its own key. Do this once per machine.

```bash
ssh-keygen -t ed25519 -C "frashersebastian@gmail.com ($(hostname))" -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub
```

Paste that public key at <https://github.com/settings/ssh/new>, then verify:

```bash
ssh -T git@github.com      # expect: "Hi SFrasher! You've successfully authenticated..."
```

### 2. Clone

```bash
git clone git@github.com:SFrasher/BodyFPSController.git
cd BodyFPSController
```

Clone **once** per machine. After that it's `pull` and `push` — cloning again
throws away whatever hasn't been pushed.

### 3. Install the MCP addon's Node dependencies

`node_modules/` is gitignored (~125 MB, and it's reinstallable), so a fresh
clone won't have it. The addon won't connect until you do this:

```bash
cd addons/godot_mcp/server
npm install
cd ../../..
```

`build/` **is** committed, so there's no TypeScript build step — `npm install`
is enough.

### 4. Open in Godot

First open regenerates `.godot/` (import caches, shader caches). It takes a
minute or two and churns the disk. That directory is gitignored on purpose —
it's machine-specific and would conflict constantly if shared.

### 5. Optional — point VS Code at your Godot binary

`.vscode/settings.json` is deliberately **untracked**, because it stores an
absolute path to the Godot executable that is different on every machine.
Create your own:

```json
{
    "godotTools.editorPath.godot4": "/your/path/to/Godot_v4.6-stable_linux.x86_64",
    "editor.tabSize": 4,
    "editor.insertSpaces": false,
    "files.eol": "\n",
    "files.exclude": { "**/*.gd.uid": true }
}
```

`.vscode/extensions.json` **is** tracked — the recommended extensions are the
same everywhere.

### 6. Optional — wire up the Claude MCP bridge

Lives outside the repo, in `~/.config/Claude/claude_desktop_config.json`. Paths
are absolute, so they differ per machine:

```json
"godot-mcp-pro": {
  "command": "/home/<you>/.nvm/versions/node/v22.x.x/bin/node",
  "args": ["/path/to/BodyFPSController/addons/godot_mcp/server/build/index.js"]
}
```

---

## Working across two machines

GitHub holds the authoritative copy. The laptop and the desktop are both just
working copies of it.

```bash
git pull        # ALWAYS, before you touch anything
# ... work ...
git add -A
git commit -m "what changed and why"
git push        # ALWAYS, before you walk away from the machine
```

`pull.rebase` is set to `true`, so pulling replays your local commits on top of
whatever came from the other machine. Linear history, no merge commit every
time you switch desks.

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
| `.vscode/settings.json` | Holds a machine-specific absolute path to the Godot binary. |
| `/android/` | Generated Android build template. |

---

## Project background

- `PROJECT_CONTEXT.md` — scene structure, IK system, exported properties,
  current camera setup
- `FIRSTPERSON_ANALYSIS.md` — the conversion breakdown

Scope for now is **walk, look, aim**. The template's cover, weapon-switch, and
fire-mode inputs are inert leftovers and out of scope.
