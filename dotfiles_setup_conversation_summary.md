# Linux Dotfiles Setup — Conversation Summary

## 1. Goal

The original dotfiles repository contained a Zsh-based `install.sh` that:

- backed up existing dotfiles;
- created symlinks into `$HOME`;
- installed Oh My Zsh plugins;
- symlinked VS Code settings/keybindings;
- configured SSH on macOS;
- restarted Zsh.

The goal evolved into a **fresh-Linux-machine setup tool** that can be started with a single `curl` command, without requiring the user to clone the repository first.

The desired mental model is similar to installing a Python package:

> Fresh Linux installation → one command → complete development environment setup.

---

# 2. Important architectural decision

The setup was split into phases:

```text
curl
  ↓
setup.sh                  # remote entrypoint / orchestrator
  ↓
clone dotfiles repository
  ↓
setup/bootstrap.sh        # base system requirements
  ↓
setup/system.sh           # system applications
  ↓
setup/user.sh             # user environment
```

The preferred filenames became:

```text
setup.sh
setup/
├── bootstrap.sh
├── system.sh
└── user.sh
```

We decided **not** to use numeric filenames such as `0-bootstrap.sh`, because the numbers are unnecessary when the orchestrator explicitly controls the order. Numeric filenames are valid Unix filenames, but descriptive names are cleaner here.

---

# 3. The most important part: starting everything with curl

The intended documented usage is:

```bash
REPO="your-fork/dotfiles"
curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/setup.sh" | bash
```

For the author's own repository, the documentation can simply show:

```bash
curl -fsSL "https://raw.githubusercontent.com/your-username/dotfiles/main/setup.sh" | bash
```

## Why `REPO` must be assigned separately

This does **not** work as intended:

```bash
REPO="your-fork/dotfiles" \
curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/setup.sh" | bash
```

The shell expands `${REPO}` while constructing the `curl` command. The temporary environment assignment belongs to the `curl` process; it does not affect the shell's expansion of the URL.

Therefore use:

```bash
REPO="your-fork/dotfiles"
curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/setup.sh" | bash
```

This is the preferred pattern.

---

# 4. Does the downloaded script know its GitHub repository automatically?

No.

When running:

```bash
curl -fsSL "https://raw.githubusercontent.com/user/dotfiles/main/setup.sh" | bash
```

`curl` downloads the file and pipes its contents into Bash.

The Bash process does not automatically receive:

```text
user/dotfiles
```

as metadata.

Therefore the script needs a repository value if it must later clone the repository.

A useful pattern is:

```bash
REPO="${REPO:-your-username/your-dotfiles}"
REPO_URL="${REPO_URL:-https://github.com/${REPO}.git}"
```

This means:

- if `REPO` is already defined, use it;
- otherwise use the default repository;
- construct `REPO_URL` from it;
- `REPO_URL` can also be overridden independently.

Example:

```bash
REPO="some-user/dotfiles"
```

produces:

```text
https://github.com/some-user/dotfiles.git
```

---

# 5. Why the first clone should use HTTPS

The initial repository clone should use HTTPS:

```bash
REPO_URL="https://github.com/${REPO}.git"
```

Reason:

A fresh machine may not yet have:

- an SSH key;
- an SSH agent;
- the public key registered with GitHub;
- SSH authentication configured.

A public GitHub repository can be cloned through HTTPS without authentication:

```bash
git clone https://github.com/user/dotfiles.git
```

An SSH clone:

```bash
git clone git@github.com:user/dotfiles.git
```

still requires SSH to be configured, even though the repository is public.

Therefore the desired flow is:

```text
Initial bootstrap
      ↓
HTTPS clone
      ↓
Install/configure SSH + GitHub CLI
      ↓
Authenticate with GitHub
      ↓
Optionally switch repository remote to SSH
```

For example, after SSH is configured:

```bash
git remote set-url origin "git@github.com:${REPO}.git"
```

---

# 6. `setup.sh` — the remote entrypoint

The entrypoint is responsible only for obtaining the repository and starting the real setup.

A suitable structure is:

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO="${REPO:-your-username/your-dotfiles}"
REPO_URL="${REPO_URL:-https://github.com/${REPO}.git}"
INSTALL_DIR="$HOME/.dotfiles"

echo "===> Starting setup..."

echo "===> Requesting sudo access..."
sudo -v

# Install git if missing
if ! command -v git >/dev/null 2>&1; then
  echo "===> Installing git..."

  if command -v apt >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y git
  else
    echo "Unsupported package manager. Please install git manually."
    exit 1
  fi
fi

# Clone or update repository
if [ ! -d "$INSTALL_DIR" ]; then
  echo "===> Cloning dotfiles..."
  git clone "$REPO_URL" "$INSTALL_DIR"
else
  echo "===> Updating dotfiles..."
  git -C "$INSTALL_DIR" pull
fi

cd "$INSTALL_DIR"

# Run setup
bash setup/bootstrap.sh
```

The key point is that **Git belongs here**, because Git is required to obtain the repository.

There is no reason to install Git again in `bootstrap.sh`.

---

# 7. `set -euo pipefail`

The setup scripts use:

```bash
set -euo pipefail
```

Meaning:

### `-e`

Exit when a command fails.

### `-u`

Treat references to unset variables as errors.

### `pipefail`

A pipeline fails if any command in the pipeline fails, not only the last command.

Together they make setup scripts much safer than silently continuing after an error.

---

# 8. `bootstrap.sh` responsibilities

`bootstrap.sh` is the minimum system preparation layer.

It should install foundational packages required by later stages.

Current intended packages:

```bash
BASE_PACKAGES=(
  curl
  ca-certificates
  gnupg
  lsb-release
  zsh
  vim
  unzip
  jq
  tree
)
```

Git is deliberately **not** included because `setup.sh` already had to install it before cloning the repository.

The bootstrap phase should also:

- verify that `apt` exists;
- request/maintain sudo access;
- run `apt update`;
- install missing base packages;
- generate `en_US.UTF-8`.

---

# 9. Sudo handling

A useful pattern is:

```bash
if ! sudo -n true 2>/dev/null; then
  echo "===> Requesting sudo access..."
  sudo -v
fi
```

This means:

1. try to use existing cached sudo credentials without prompting;
2. if that fails, explicitly ask for the password.

The shell that executes `setup.sh` does **not** need to stay the same for sudo credentials to persist. Sudo's authentication cache is independent of the individual Bash child process.

However, sudo credentials can expire, so a long-running script can use a keep-alive:

```bash
while true; do
  sudo -n true
  sleep 60
done >/dev/null 2>&1 &

SUDO_KEEPALIVE_PID=$!

trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT
```

The `trap` is important because it ensures the background process is cleaned up even if the setup fails.

The exact need for repeating `sudo -v` in every phase is therefore mostly about robustness and making individual scripts runnable independently, not because the child shell loses sudo state.

---

# 10. `system.sh` responsibilities

`system.sh` is for larger applications and system-level development tools.

Current planned responsibilities:

```text
system.sh
├── VS Code
├── VS Code extensions
└── GitHub CLI (gh)
```

These are different from the minimal packages in `bootstrap.sh`.

---

# 11. VS Code installation

The intended Linux installation uses Microsoft's APT repository.

Dependencies such as `wget` and `gpg` should be available before using the repository setup. Since `bootstrap.sh` currently installs `gnupg` but not `wget`, either:

- add `wget` to the bootstrap package list, or
- install it in `system.sh`.

The repository setup is conceptually:

```bash
wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
  | gpg --dearmor \
  | sudo tee /etc/apt/trusted.gpg.d/packages.microsoft.gpg >/dev/null

echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
  | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null

sudo apt update
sudo apt install -y code
```

The improved implementation should make the repository/key setup **idempotent**, meaning re-running the script should not unnecessarily recreate configuration.

Check first:

```bash
if ! command -v code >/dev/null 2>&1; then
    # install VS Code
fi
```

---

# 12. VS Code extensions

Current extension list:

```text
ms-vscode.sublime-keybindings
emmanuelbeziat.vscode-great-icons
github.github-vscode-theme
alexcvzz.vscode-sqlite
anteprimorac.html-end-tag-labels
```

Install with:

```bash
code --install-extension ms-vscode.sublime-keybindings
code --install-extension emmanuelbeziat.vscode-great-icons
code --install-extension github.github-vscode-theme
code --install-extension alexcvzz.vscode-sqlite
code --install-extension anteprimorac.html-end-tag-labels
```

For idempotency, retrieve installed extensions:

```bash
INSTALLED_EXTENSIONS=$(code --list-extensions || true)
```

and install only extensions that are missing.

Later, the extension list could be moved to a file such as:

```text
vscode/extensions.txt
```

instead of hardcoding it in the shell script.

---

# 13. GitHub CLI (`gh`)

The GitHub CLI installation belongs in `system.sh`.

Original commands:

```bash
sudo apt remove -y gitsome

curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

sudo apt update
sudo apt install -y gh

gh --version
```

The installation should also be made idempotent.

`gitsome` is an older/unrelated CLI that can conflict with the `gh` command, so the setup can remove it if present.

The architectural distinction is:

```text
system.sh:
    install gh

user.sh:
    authenticate gh
```

---

# 14. Oh My Zsh

Oh My Zsh belongs in `user.sh`, not `system.sh`.

Reason:

It modifies the user's shell environment and user-level files.

The original command was:

```bash
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

A better invocation is to prevent Oh My Zsh from automatically changing the shell while the setup is still running:

```bash
RUNZSH=no CHSH=no \
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

Also check whether it already exists:

```bash
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    # install
fi
```

This makes the operation idempotent.

---

# 15. Zsh plugins

The original dotfiles setup installs:

- `zsh-autosuggestions`
- `zsh-syntax-highlighting`

These are user-level configuration, so they belong in `user.sh`.

A reusable helper can install plugins:

```bash
install_plugin() {
  local repo="$1"
  local name
  name="$(basename "$repo")"

  if [ ! -d "$PLUGINS_DIR/$name" ]; then
    git clone "https://github.com/$repo.git" "$PLUGINS_DIR/$name"
  fi
}
```

Then:

```bash
install_plugin "zsh-users/zsh-autosuggestions"
install_plugin "zsh-users/zsh-syntax-highlighting"
```

---

# 16. `user.sh` responsibilities

`user.sh` should turn the installed system into the user's personal environment.

Its responsibilities are:

```text
user.sh
├── Oh My Zsh
├── Zsh plugins
├── Dotfile symlinks
├── VS Code settings/keybindings
├── GitHub authentication
├── GitHub username/workspace
├── SSH-related user setup
└── optionally set Zsh as default shell
```

The original dotfiles are:

```text
aliases
gitconfig
irbrc
pryrc
rspec
zprofile
zshrc
```

They are linked to:

```text
~/.aliases
~/.gitconfig
~/.irbrc
~/.pryrc
~/.rspec
~/.zprofile
~/.zshrc
```

Existing real files should be backed up before replacing them.

A robust helper:

```bash
backup() {
  local target="$1"

  if [ -e "$target" ] && [ ! -L "$target" ]; then
    mv "$target" "$target.backup"
    echo "-----> Backed up $target → $target.backup"
  fi
}
```

---

# 17. Symlink behavior

The original script only created a symlink when the target didn't exist.

The improved design should handle all three cases:

```text
target doesn't exist
    → create symlink

target is already the correct symlink
    → do nothing

target exists as a real file
    → back it up, then create symlink
```

This makes repeated executions safe.

---

# 18. VS Code user configuration

The dotfiles repository contains:

```text
settings.json
keybindings.json
```

On Linux:

```text
~/.config/Code/User
```

On macOS:

```text
~/Library/Application Support/Code/User
```

The current project is primarily Linux-oriented, so Linux can be the main supported path. WSL can optionally use:

```text
~/.vscode-server/data/Machine
```

The configuration files should be symlinked just like the shell dotfiles.

---

# 19. GitHub authentication

Authentication belongs in `user.sh` because it is tied to the user's GitHub identity.

The original command:

```bash
gh auth login -s 'user:email' -w --git-protocol ssh
```

is interactive and requires the user to answer questions/use the browser.

A better pattern:

```bash
if ! gh auth status >/dev/null 2>&1; then
  echo "===> Please authenticate with GitHub..."
  gh auth login -s 'user:email' -w --git-protocol ssh
else
  echo "-----> GitHub already authenticated"
fi
```

Then verify:

```bash
gh auth status
```

---

# 20. GitHub username and workspace

After authentication:

```bash
GITHUB_USERNAME=$(gh api user | jq -r '.login')

echo "===> GitHub user: $GITHUB_USERNAME"

mkdir -p "$HOME/code/$GITHUB_USERNAME"
```

This creates a personal workspace such as:

```text
~/code/my-github-username/
```

The `jq` package is therefore useful in `bootstrap.sh`.

---

# 21. SSH and GitHub

The setup should eventually configure SSH and use GitHub CLI authentication with SSH as the preferred Git protocol.

However, the **initial dotfiles clone should remain HTTPS** because SSH may not yet be configured.

After GitHub/SSH configuration is complete, the dotfiles remote can optionally be changed:

```bash
git -C "$INSTALL_DIR" remote set-url origin "git@github.com:${REPO}.git"
```

A possible safety check is:

```bash
if ssh -T git@github.com 2>/dev/null; then
    git -C "$INSTALL_DIR" remote set-url origin "git@github.com:${REPO}.git"
fi
```

This is optional and should only happen after SSH authentication has actually been established.

---

# 22. Shell choice for setup scripts

All setup scripts should remain:

```bash
#!/usr/bin/env bash
```

even though the final environment is Zsh.

Reason:

> The installer should not depend on the environment it is in the process of building.

Using:

```bash
#!/usr/bin/env zsh
```

would unnecessarily couple the installer to Zsh and potentially to `.zshrc`/`.zprofile` configuration that the installer is itself modifying.

Recommended:

```text
setup.sh       → Bash
bootstrap.sh   → Bash
system.sh      → Bash
user.sh        → Bash
zshrc          → Zsh
zprofile       → Zsh
```

Zsh is installed during the bootstrap phase and can then be made the user's default shell near the end.

---

# 23. Final intended architecture

```text
                         curl
                          │
                          ▼
              ┌─────────────────────┐
              │      setup.sh       │
              │                     │
              │ - determine REPO    │
              │ - ensure git        │
              │ - clone/update repo │
              └──────────┬──────────┘
                         │
                         ▼
              ┌─────────────────────┐
              │    bootstrap.sh     │
              │                     │
              │ - apt               │
              │ - sudo              │
              │ - curl              │
              │ - zsh               │
              │ - vim               │
              │ - jq                │
              │ - unzip              │
              │ - tree              │
              │ - locale            │
              └──────────┬──────────┘
                         │
                         ▼
              ┌─────────────────────┐
              │     system.sh       │
              │                     │
              │ - VS Code           │
              │ - VS Code extensions│
              │ - GitHub CLI        │
              └──────────┬──────────┘
                         │
                         ▼
              ┌─────────────────────┐
              │      user.sh        │
              │                     │
              │ - Oh My Zsh         │
              │ - Zsh plugins       │
              │ - dotfiles          │
              │ - VS Code config    │
              │ - gh authentication │
              │ - GitHub username   │
              │ - ~/code/...        │
              │ - SSH configuration │
              └─────────────────────┘
```

---

# 24. The key principle

The most important design decision from the conversation is:

> **`setup.sh` is the bootstrap entrypoint that makes it possible to obtain the repository. The scripts inside the repository should assume that the repository has already been cloned.**

Therefore:

```text
setup.sh
    └── Git is special:
        it must be available BEFORE cloning.

bootstrap.sh
    └── Everything required AFTER cloning.

system.sh
    └── Applications/tools.

user.sh
    └── User-specific configuration/authentication.
```

This prevents redundant installations and gives every phase a clear responsibility.

---

# 25. Recommended documented one-liner

For a fork:

```bash
REPO="your-github-user/dotfiles"
curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/setup.sh" | bash
```

For the canonical repository:

```bash
curl -fsSL "https://raw.githubusercontent.com/your-username/dotfiles/main/setup.sh" | bash
```

This is the core UX the entire architecture is being designed around.

---

# 26. Future improvements discussed

Potential future improvements include:

- support for `--repo`, `--branch`, `--minimal`, etc.;
- dry-run mode;
- centralized logging;
- debug mode;
- an extension list file;
- OS-specific internal scripts;
- better SSH key setup;
- automatically switching the dotfiles Git remote from HTTPS to SSH;
- adding additional development tools in another phase if needed.

The current design should remain simple until those features are actually needed.
