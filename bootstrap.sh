#!/bin/bash

GIT_REPO=""
CONF_DIR_NAME=".dotfiles"
CURRENT_TIME=$(date +"%Y-%m-%dT%H-%M-%S")
BACKUP_DIR="config-backup-$CURRENT_TIME"

if [[ $(ssh -T git@github.com) == *"success"* ]]; then
	echo "Using SSH-authentication to connect to github"
	GIT_REPO="git@github.com:binaryplease/dotfiles.git"
else
	echo "Using HTTPS-authentication to connect to github"
	GIT_REPO="https://github.com/binaryplease/dotfiles/"
fi

function backup_conf() {
	while read -r fn
	do
		con="$(dirname "$fn")"
		con="$BACKUP_DIR/$con"
		mkdir -p "$con"
		mv "$fn" "$(realpath "$con")"
	done
}

function setup_dotfiles() {
	mv $CONF_DIR_NAME "dotfiles-repo-backup-$CURRENT_TIME"
	echo "Setting up dotfiles..."
	cd ~
	git clone --bare $GIT_REPO "$HOME/$CONF_DIR_NAME"
	function config {
		git --git-dir="$HOME/$CONF_DIR_NAME/" --work-tree="$HOME" "$@"
	}
	if grep -Fxq ".gitignore" $CONF_DIR_NAME
	then
		echo "$CONF_DIR_NAME already in .gitignore"
	else
		echo "$CONF_DIR_NAME" >> .gitignore
	fi
	mkdir -p "$BACKUP_DIR"
	echo "Backing up pre-existing dot files.";
	config checkout 2>&1 | awk '/^[[:space:]]/{print $1}' | backup_conf
	config checkout
	config config status.showUntrackedFiles no
	config  submodule update --init --recursive

}

function setup_vim() {

	echo "Setting up vim/neovim..."
	if type "nvim" > /dev/null
	then
		nvim -c 'PlugClean|PlugInstall|qa'
	elif type "vim" > /dev/null
	then
		vim -c 'PlugClean|PlugInstall|qa'
	else
		echo "Vim/Neovim doesn't seem to be installed"
	fi
}

function check_dependencies() {
	echo "Checking dependencies..."
	declare -a arr=("git" "nvim")

	for i in "${arr[@]}"
	do
		if ! [ -x "$(command -v "$i")" ]; then
			echo "Error: $i is not installed." >&2
			exit 1
		fi
	done
}



last_version_antibody() {
	curl -s https://raw.githubusercontent.com/getantibody/homebrew-tap/master/Formula/antibody.rb |
		grep url |
		cut -f8 -d'/'
}

function install_antibody() {
	curl -sfL git.io/antibody | sh -s - -b .local/bin
}

function setup_git {
	git config --global user.name "Pablo Ovelleiro Corral"
	git config --global user.email "pablo1@mailbox.org"
	git config --global commit.gpgsign true
}

function setup_terminfo {
	wget https://raw.githubusercontent.com/thestinger/termite/master/termite.terminfo
	tic -x termite.terminfo
}

# Function to confirm execution. Call confirmExecute <message> <command>
confirmExecute() { read -p "$1" -n 1 -r; echo; shift; [[ $REPLY = [yY] || -z $REPLY ]] && "$@"; }

confirmExecute "Check for missing dependencies? [Y/n]" check_dependencies
confirmExecute "Setup dotfiles? [Y/n]"  setup_dotfiles
confirmExecute "Setup VIM/Neovim? [Y/n]" setup_vim
confirmExecute "Set ZSH as shell? [Y/n]" chsh -s /bin/zsh
confirmExecute "Install antibody? [Y/n]" install_antibody
confirmExecute "Install termite terminfo? [Y/n]" setup_terminfo
confirmExecute "Setup git configuration? [Y/n]" setup_git

