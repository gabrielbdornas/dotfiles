ZSH=$HOME/.oh-my-zsh

# You can change the theme with another one from https://github.com/robbyrussell/oh-my-zsh/wiki/themes
ZSH_THEME="robbyrussell"

# Useful oh-my-zsh plugins for Le Wagon bootcamps
plugins=(git gitfast last-working-dir common-aliases zsh-syntax-highlighting history-substring-search ssh-agent poetry)

# (macOS-only) Prevent Homebrew from reporting - https://github.com/Homebrew/brew/blob/master/docs/Analytics.md
export HOMEBREW_NO_ANALYTICS=1

# Disable warning about insecure completion-dependent directories
ZSH_DISABLE_COMPFIX=true

# Actually load Oh-My-Zsh
source "${ZSH}/oh-my-zsh.sh"
unalias rm # No interactive rm by default (brought by plugins/common-aliases)
unalias lt # we need `lt` for https://github.com/localtunnel/localtunnel

# Load rbenv if installed (to manage your Ruby versions)
export PATH="${HOME}/.rbenv/bin:${PATH}" # Needed for Linux/WSL
type -a rbenv > /dev/null && eval "$(rbenv init -)"

# Load pyenv (to manage your Python versions)
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# Load nvm (to manage your node versions)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Call `nvm use` automatically in a directory with a `.nvmrc` file
autoload -U add-zsh-hook
load-nvmrc() {
  if nvm -v &> /dev/null; then
    local node_version="$(nvm version)"
    local nvmrc_path="$(nvm_find_nvmrc)"

    if [ -n "$nvmrc_path" ]; then
      local nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")

      if [ "$nvmrc_node_version" = "N/A" ]; then
        nvm install
      elif [ "$nvmrc_node_version" != "$node_version" ]; then
        nvm use --silent
      fi
    elif [ "$node_version" != "$(nvm version default)" ]; then
      nvm use default --silent
    fi
  fi
}
type -a nvm > /dev/null && add-zsh-hook chpwd load-nvmrc
type -a nvm > /dev/null && load-nvmrc

# Rails and Ruby uses the local `bin` folder to store binstubs.
# So instead of running `bin/rails` like the doc says, just run `rails`
# Same for `./node_modules/.bin` and nodejs
export PATH="./bin:./node_modules/.bin:${PATH}:/usr/local/sbin"

# Store your own aliases in the ~/.aliases file and load the here.
[[ -f "$HOME/.aliases" ]] && source "$HOME/.aliases"

# Encoding stuff for the terminal
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

export BUNDLER_EDITOR=code
export EDITOR=code
export PATH="/usr/share/code/bin:$PATH"

# Set ipdb as the default Python debugger
export PYTHONBREAKPOINT=ipdb.set_trace

export NGROK=evident-repeatedly-troll.ngrok-free.app

# Poetry tab completation configuration
fpath+=~/.zfunc
autoload -Uz compinit && compinit

# My own zshrc commands
mkfile() { mkdir -p "$(dirname "$1")" && touch "$1" ;  }
# https://docs.gitignore.io/install/command-line#linux-zsh
gi() { curl -sLw "\n" https://www.toptal.com/developers/gitignore/api/$@ ;}
# Python c
pyc() { python3 -c "print($1)"  }

# Inside WSL, start PostgreSQL manually
if grep -qi microsoft /proc/sys/kernel/osrelease; then
    # Inside WSL, start PostgreSQL manually
    sudo /etc/init.d/postgresql start
fi

# Created by `pipx` on 2025-01-23 17:38:47
export PATH="$PATH:/home/gabrielbdornas/.local/bin"

# track issue timelapse
start() {
    if [ -z "$1" ]; then
        echo "Usage: start <issue_number>"
        return 1
    fi
    git commit --allow-empty -m "$1-start" -m "See #$1"
    echo "Started tracking Issue #$1"
}

stop() {
    if [ -z "$1" ]; then
        echo "Usage: stop <issue_number>"
        return 1
    fi
    git commit --allow-empty -m "$1-stop" -m "See #$1"
    echo "Stopped tracking Issue #$1"
}

  [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# fzf search
# See https://chatgpt.com/share/67defe4a-20e4-8003-b854-d66745edd913
export FD_OPTIONS="--ignore-file=$HOME/.ignore"

cdh() {
    cd "$(fdfind --type d --hidden "$1" ~ | fzf)"
}

cda() {
    cd "$(fdfind --type d --hidden "$1" / | fzf)"
}

cursor() {
    nohup /opt/cursor.AppImage "$@" > /dev/null 2>&1 &!
}
