#!/usr/bin/env bash

DOTFILES="$(pwd)"

command_exists() {
    type "$1" /dev/null 2>&1
}

seperator() {
    echo -e "==============================\n"
}

backeup() {
    BACKUP_DIR=$HOME/dotfiles-backup

    set -e # Exit immediately if a command exits with a non-zero status.

    echo "Creating backup directory at $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"

    linkables=$( find -H "$DOTFILES" -maxdepth 3 -name '*.symlink' )

    for file in $linkables; do
        filename=".$( basename "$file" '.symlink' )"
        target="$HOME/$filename"
        if [ -f "$target" ]; then
            echo "backing up $filename"
            cp "$target" "$BACKUP_DIR"
        else
            echo -e "$filename does not exist at this location or is a symlink"
        fi
    done

    for filename in "$HOME/.config/nvim" "$HOME/.vim" "$HOME/.vimrc"; do
        if [ ! -L "$filename" ]; then
            echo "backing up $filename"
            cp -rf "$filename" "$BACKUP_DIR"
        else
            echo -e "$filename does not exist at this location or is a symlink"
        fi
    done
}


link() {
    echo -e "\nCreating symlinks"
    seperator

    linkables=$( find -H "$DOTFILES" -maxdepth 3 -name '*.symlink' )
    for file in $linkables ; do
        target="$HOME/.$( basename "$file" '.symlink' )"
        if [ -e "$target" ]; then
            echo "~${target#$HOME} already exists... Skipping."
        else
            echo "Creating symlink for $file"
            ln -s "$file" "$target"
        fi
    done

    echo -e "\n\ninstalling to ~/.config"
    seperator
    if [ ! -d "$HOME/.config" ]; then
        echo "Creating ~/.config"
        mkdir -p "$HOME/.config"
    fi

    config_files=$( find "$DOTFILES/config" -maxdepth 1 2>/dev/null )
    for config in $config_files; do
        target="$HOME/.config/$( basename "$config" )"
        if [ -e "$target" ]; then
            echo "~${target#$HOME} already exists... Skipping."
        else
            echo "Creating symlink for $config"
            ln -s "$config" "$target"
        fi
    done

    # create vim symlinks
    # As I have moved off of vim as my full time editor in favor of neovim,
    # I feel it doesn't make sense to leave my vimrc intact in the dotfiles repo
    # as it is not really being actively maintained. However, I would still
    # like to configure vim, so lets symlink ~/.vimrc and ~/.vim over to their
    # neovim equivalent.

    echo -e "\nCreating vim symlinks"
    seperator
    VIMFILES=( "$HOME/.vim:$DOTFILES/config/nvim"
            "$HOME/.vimrc:$DOTFILES/config/nvim/init.vim" )

    for file in "${VIMFILES[@]}"; do
        KEY=${file%%:*}
        VALUE=${file#*:}
        if [ -e "${KEY}" ]; then
            echo "${KEY} already exists... skipping."
        else
            echo "Creating symlink for $KEY"
            ln -s "${VALUE}" "${KEY}"
        fi
    done
}

git() {
    echo -e "\nSetting up Git."
    seperator
    echo -e "\n"

    defaultName=$( git config --global user.name )
    defaultEmail=$( git config --global user.email )
    defaultGithub=$( git config --global github.user )

    read -rp "Name [$defaultName] " name
    read -rp "Email [$defaultEmail] " email
    read -rp "Github username [$defaultGithub] " github

    git config --global user.name "${name:-$defaultName}"
    git config --global user.email "${email:-$defaultEmail}"
    git config --global github.user "${github:-$defaultGithub}"

    if [[ "$( uname )" == "Darwin" ]]; then
        git config --global credential.helper "osxkeychain"
    else
        read -rn 1 -p "Save user and password to an unencrypted file to avoid writing? [y/N] " save
        if [[ $save =~ ^([Yy])$ ]]; then
            git config --global credential.helper "store"
        else
            git config --global credential.helper "cache --timeout 3600"
        fi
    fi
}

homebrew() {
    echo -e "\nSetting up Homebrew"
    seperator

    if test ! "$(command -v brew)"; then
        echo -e "Homebrew not installed. Installing."
        # Run as a login shell (non-interactive) so that the script doesn't pause for user input
        curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh | bash --login
    fi

    if [ "$(uname)" == "Linux" ]; then
        test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
        test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        test -r ~/.bash_profile && echo "eval \$($(brew --prefix)/bin/brew shellenv)" >>~/.bash_profile
    fi

    # install brew dependencies from Brewfile
    brew bundle

    # install fzf
    echo -e "\nInstalling fzf"
    "$(brew --prefix)"/opt/fzf/install --key-bindings --completion --no-update-rc --no-bash --no-fish
}

function shell() {
    echo -e "\nSetting up ZSH"
    seperator

    [[ -n "$(command -v brew)" ]] && zsh_path="$(brew --prefix)/bin/zsh" || zsh_path="$(which zsh)"
    if ! grep "$zsh_path" /etc/shells; then
        echo "adding $zsh_path to /etc/shells"
        echo "$zsh_path" | sudo tee -a /etc/shells
    fi

    if [[ "$SHELL" != "$zsh_path" ]]; then
        chsh -s "$zsh_path"
        echo "default shell changed to $zsh_path"
    fi
}

function terminfo() {
    echo -e "\nSetting up terminfo"
    seperator
    tic -x "$DOTFILES/resources/tmux.terminfo"
    tic -x "$DOTFILES/resources/xterm-256color-italic.terminfo"
}

macos() {
    if [[ "$( uname )" == "Darwin" ]]; then
        echo -e "\nConfiguring macOS"
        seperator

        echo "Finder: show all filename extensions"
        defaults write NSGlobalDomain AppleShowAllExtensions -bool true

        echo "show hidden files by default"
        defaults write com.apple.Finder AppleShowAllFiles -bool false

        echo "only use UTF-8 in Terminal.app"
        defaults write com.apple.terminal StringEncodings -array 4

        echo "expand save dialog by default"
        defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true

        echo "show the ~/Library folder in Finder"
        chflags nohidden ~/Library

        echo "Enable full keyboard access for all controls (e.g. enable Tab in modal dialogs)"
        defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

        echo "Enable subpixel font rendering on non-Apple LCDs"
        defaults write NSGlobalDomain AppleFontSmoothing -int 2

        echo "Use current directory as default search scope in Finder"
        defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

        echo "Show Path bar in Finder"
        defaults write com.apple.finder ShowPathbar -bool true

        echo "Show Status bar in Finder"
        defaults write com.apple.finder ShowStatusBar -bool true

        echo "Disable press-and-hold for keys in favor of key repeat"
        defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

        echo "Set a blazingly fast keyboard repeat rate"
        defaults write NSGlobalDomain KeyRepeat -int 1

        echo "Set a shorter Delay until key repeat"
        defaults write NSGlobalDomain InitialKeyRepeat -int 15

        echo "Enable tap to click (Trackpad)"
        defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true

        echo "Enable Safari’s debug menu"
        defaults write com.apple.Safari IncludeInternalDebugMenu -bool true

        echo "Kill affected applications"

        for app in Safari Finder Dock Mail SystemUIServer; do killall "$app" >/dev/null 2>&1; done
    fi
}

case "$1" in
    backup)
        backup
        ;;
    link)
        link
        ;;
    git)
        git
        ;;
    brew)
        homebrew
        ;;
    shell)
        shell
        ;;
    terminfo)
        terminfo
        ;;
    macos)
        macos
        ;;
    all)
        link
        terminfo
        homebrew
        shell
        git
        macos
        ;;
    *)
        echo $"Usage: $(basename "$0") {backup|link|git|brew|shell|terminfo|macos|all}"
        exit 1
        ;;
esac
