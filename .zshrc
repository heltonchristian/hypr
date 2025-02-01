#----------- sets -------------
xrandr --output DP-1 --primary --mode 1920x1080 --rotate normal --rate 240 --output DVI-I-1 --right-of DP-1  --mode 1920x1080 --rotate normal --rate 144

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
alias vim ='nvim'
alias fetch='clear && neofetch'
alias zshrc='nvim ~/.zshrc'
alias ac='nvim ~/.config/alacritty/alacritty.toml'
alias vimrc='nvim ~/.config/nvim/init.vim'

#------------ HYPRLAND ------------
alias hc='nvim ~/.config/hypr/hyprland.conf'
alias hw='nvim ~/.config/hypr/hyprpaper.conf'
alias zshrc='nvim ~/.zshrc'
alias tc='nvim ~/.config/tofi/config'
alias waybarc='nvim .config/waybar/config.jsonc'
alias waybarcss='nvim .config/waybar/style.css'
alias hexit='pkill -KILL -u $USER'
