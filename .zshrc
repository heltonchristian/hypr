#PROMPT='%F{8}$%f '
#PROMPT='%F{243}%1~ %f%F{White}%f  '
PROMPT='%F{#888888}%1~%f %F{White}%f  '

##########################
autoload -U compinit
compinit
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}'
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY

############ ALIAS #####################
alias ls='ls --color=auto'
alias la='ls -a'
alias ll='ls -l'
alias lla='ls -al'
alias rm='rm -r'
alias cp='cp -r'
alias vi='vim'
alias fetch='clear && neofetch'
alias kc='vim ~/.config/kitty/kitty.conf'
alias zshrc='vim ~/.zshrc'

#### Hyprland
alias hc='vim .config/hypr/hyprland.conf'
alias hw='vim .config/hypr/hyprpaper.conf'
alias kc='vim .config/wofi/config.conf'
alias kc='vim .config/kitty/kitty.conf'
alias zshrc='vim ~/.zshrc'
alias tc='vim ~/.config/tofi/config'
alias waybarc='vim .config/waybar/config.jsonc'
alias waybarcss='vim .config/waybar/style.css'
alias hexit='pkill -KILL -u $USER'

############# COLORS #############
LS_COLORS='rs=0:di=1;94:fi=1;37:ln=1;34'
export LS_COLORS
