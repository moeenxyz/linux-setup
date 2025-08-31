#!/bin/bash
# Essential tools installation module

install_essential_tools() {
    if [[ ${INSTALL_ESSENTIAL_TOOLS:-Y} =~ ^[Yy]$ ]]; then
        log "Installing essential tools..."

        # Install essential packages (try apt first, fallback to snap for some packages)
        sudo apt install -y \
            curl \
            wget \
            unzip \
            zip \
            build-essential \
            software-properties-common \
            apt-transport-https \
            ca-certificates \
            gnupg \
            lsb-release \
            screen \
            git-core \
            openssh-server \
            net-tools \
            htop \
            vim \
            nano \
            jq \
            bc

        # Try to install tree via apt, fallback to snap
        if ! sudo apt install -y tree 2>/dev/null; then
            log "Installing tree via snap..."
            sudo snap install tree
        fi

        log "Essential tools installed successfully"
    fi
}

install_git_package() {
    if [[ ${INSTALL_GIT:-Y} =~ ^[Yy]$ ]]; then
        log "Installing and configuring Git..."

        # Install Git
        sudo apt install -y git

        # Configure Git if credentials are provided
        local git_username="${GIT_USERNAME:-}"
        local git_email="${GIT_EMAIL:-}"

        if [[ -n "$git_username" ]]; then
            git config --global user.name "$git_username"
            log "Git username set to: $git_username"
        fi

        if [[ -n "$git_email" ]]; then
            git config --global user.email "$git_email"
            log "Git email set to: $git_email"
        fi

        # Set useful Git defaults
        git config --global init.defaultBranch main
        git config --global pull.rebase false

        log "Git installed and configured successfully"
    fi
}

install_nodejs_package() {
    if [[ ${INSTALL_NODEJS:-Y} =~ ^[Yy]$ ]]; then
        log "Installing Node.js (LTS version)..."

        # Use NodeSource repository for latest LTS
        log "Adding NodeSource repository for Node.js LTS..."
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -

        # Install Node.js LTS
        sudo apt install -y nodejs

        # Verify installation
        local node_version=$(node --version 2>/dev/null || echo "unknown")
        local npm_version=$(npm --version 2>/dev/null || echo "unknown")

        log "Node.js $node_version and npm $npm_version (LTS) installed successfully"

        # Update npm to latest version
        log "Updating npm to latest version..."
        sudo npm install -g npm@latest

        log "Node.js LTS setup completed successfully"
    fi
}

install_zsh_package() {
    if [[ ${INSTALL_ZSH:-Y} =~ ^[Yy]$ ]]; then
        log "Installing and configuring Zsh..."

        # Install Zsh
        sudo apt install -y zsh

        # Install Oh My Zsh for current user
        if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
            log "Installing Oh My Zsh..."
            sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        fi

        # Install useful plugins
        log "Installing Zsh plugins..."

        # zsh-autosuggestions
        if [[ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]]; then
            git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
        fi

        # zsh-syntax-highlighting
        if [[ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]]; then
            git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
        fi

        # Create optimized .zshrc
        log "Creating optimized .zshrc configuration..."

        tee ~/.zshrc > /dev/null <<'EOF'
# Path to your oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="robbyrussell"

# Plugins
plugins=(
    git
    docker
    docker-compose
    zsh-autosuggestions
    zsh-syntax-highlighting
    history-substring-search
    sudo
    systemd
)

source $ZSH/oh-my-zsh.sh

# User configuration
export LANG=en_US.UTF-8
export EDITOR='vim'

# Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Docker aliases
alias d='docker'
alias dc='docker-compose'
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'

# System aliases
alias syslog='sudo tail -f /var/log/syslog'
alias ports='ss -tulanp'
alias update='sudo apt update && sudo apt upgrade'

# ZFS aliases (if installed)
alias zl='zfs list'
alias zs='zfs list -t snapshot'
alias zp='zpool status'

# History settings
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_REDUCE_BLANKS

# Auto-completion
autoload -U compinit
compinit

# Custom functions
function mkcd() {
    mkdir -p "$1" && cd "$1"
}

function extract() {
    if [ -f $1 ] ; then
        case $1 in
            *.tar.bz2)   tar xjf $1     ;;
            *.tar.gz)    tar xzf $1     ;;
            *.bz2)       bunzip2 $1     ;;
            *.rar)       unrar e $1     ;;
            *.gz)        gunzip $1      ;;
            *.tar)       tar xf $1      ;;
            *.tbz2)      tar xjf $1     ;;
            *.tgz)       tar xzf $1     ;;
            *.zip)       unzip $1       ;;
            *.7z)        7z x $1        ;;
            *)     echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}
EOF

        # Ask if user wants to change default shell using config or prompt
        local change_shell="${CHANGE_DEFAULT_SHELL:-}"
        if [[ -z "$change_shell" ]]; then
            log "Using default: Zsh will be set as default shell"
            change_shell="Y"
        fi

        if [[ $change_shell =~ ^[Yy]$ ]]; then
            sudo chsh -s $(which zsh) $USER
            log "Default shell changed to Zsh"
            warn "Please log out and log back in for shell change to take effect"
        fi

        log "Zsh and Oh My Zsh installed and configured successfully"
        info "Useful Zsh features enabled: autosuggestions, syntax highlighting, better history"
    fi
}
