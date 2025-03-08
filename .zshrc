#------------ ZSHRC ------------
PROMPT='%F{#888888}%1~%f %F{White}%f  '
autoload -U compinit
compinit
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}'
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY

#------------ PATH ------------
export PATH=$PATH:/usr/bin/wl-gammarelay-rs

#------------ ALIAS ------------
alias ls='ls --color=auto'
alias la='ls -a'
alias ll='ls -l'
alias lla='ls -al'
alias rm='rm -r'
alias cp='cp -r'
alias vi='nvim'
alias vim='nvim'
alias fc='nvim ~/.config/neofetch/config.conf'
alias fetch='clear && neofetch'
alias zshrc='nvim ~/.zshrc'
alias ac='nvim ~/.config/alacritty/alacritty.toml'
alias vimrc='nvim ~/.config/nvim/init.vim'
alias spotify='spotify_player'

#------------ HYPRLAND ------------
alias hc='nvim ~/.config/hypr/hyprland.conf'
alias hw='nvim ~/.config/hypr/hyprpaper.conf'
alias tc='nvim ~/.config/tofi/config'
alias waybarc='nvim .config/waybar/config.jsonc'
alias waybarcss='nvim .config/waybar/style.css'
alias hexit='pkill -KILL -u $USER'
