### bash .profile script
### Michael S. Fischer <michael@dynamine.net>, 2011

# Bash configuration.
shopt -s cdspell;
shopt -s checkhash;
shopt -s checkwinsize;
shopt -s cmdhist;
shopt -s dotglob;
shopt -s extglob;
shopt -s histappend;
shopt -s no_empty_cmd_completion;

# Various settings.
export LESS='-MRX';		# `less' options.
export GOPATH=$HOME/src/go
HISTSIZE=2000;		# At most 2000 entries.
HISTIGNORE="&:[bf]g:exit"
IGNOREEOF=0;		# Exit bash at the first EOF.
HISTFILE=~/.bash_history;
FIGNORE='.o:.lo:.class:~';  # Ignore some files in file name completion.

# Pager functions.
if type -p less >/dev/null 2>&1; then
  function pager() { less "$@"; }
  function more()  { less "$@"; }
  PAGER=less;
else
  function pager() { more "$@"; }
  PAGER=more;
fi

# GIT stuff.
GIT_PAGER="$PAGER";
GIT_BROWSER="browser";

# Set OS environment variable
OS="$(uname -sr|awk '$1=="SunOS"&&$2>5{print"Solaris";exit};{print$1}')"

# Check for the presence of 'vim'.
VIMPATH=$(type -path vim 2>/dev/null);
if [ $? -eq 0 ]; then HAVE_VIM=yes; else unset -v HAVE_VIM; fi

if [ "$HAVE_VIM" ]; then
  function vi { $VIMPATH -O "$@"; }
  function vim { $VIMPATH -O "$@"; }
  EDITOR=vim;
else
  EDITOR=vi;
fi

export EDITOR;

FCEDIT="$EDITOR";	# The editor used by the 'fc' builtin command.
TEXTEDIT="$EDITOR";	# Some programs use TEXTEDIT instead.

# Set up completion.
if [ -z "$BASH_COMPLETION" ]; then
  if [ \( "${BASH_VERSINFO[0]}" -eq 2 -a "${BASH_VERSINFO[1]}" \< 05 \) -o "${BASH_VERSINFO[0]}" -lt 2 ]; then
    : # skip
  else
    case "$OS" in
      Darwin)
        __BASH_COMPLETION_PREFIX=$(brew --prefix);;
      Linux)
        __BASH_COMPLETION_PREFIX="";;
    esac
    if [ -f $__BASH_COMPLETION_PREFIX/etc/bash_completion ]; then
      source $__BASH_COMPLETION_PREFIX/etc/bash_completion
    fi
  fi
fi

# This is exported at `su' with the wrong value.
unset -v MAIL;
unset -v MAIL_WARNING;

# Set the hostname.
if [ -n "$HOSTNAME" ]; then
  HOSTNAME="$(hostname)";
fi
HOST="$HOSTNAME";

# Configure the USER and LOGNAME variables.  They should contain
# the same value.
#
# There is no easy, portable way of doing this.  bash provides only
# the user id and we cannot look at the password database - it won't
# work on systems that use NIS.  And we want to reflect `su' changes
# as well.  Hopefully, each user's home directory will be named after
# the user's login name.  For `root' this might not be true, but we
# know that root's UID is 0...

if [ "$UID" -eq 0 ]; then
  USER="root";
else
  USER="$(whoami)";
fi

LOGNAME="$USER";

# user: umask=002 (UPG), umask=022 (!UPG).
# root: umask=022, for convenience.
if [ "$USER" = "root" ]; then
  umask 022;
else
  if [ "$USER" = $(id -gn) ]; then
    umask 002;
  else
    umask 022;
  fi
fi

# Create my local ~/tmp directory.
mkdir ~/tmp 2>/dev/null;
TMPDIR=~/tmp;

# Set the PATH environment variable.  Add here as needed.  The system
# provided PATH is ignored because we need to start from scratch every
# time the shell is launched under a different user id.  Doing
# otherwise would propagate user specific path components (like
# ~/bin) into the new user environment.  If you feel that this is
# not what you want, just add `:$PATH' at the end of the first line.
# The system provided PATH is saved in SYSTEM_PATH.
if [ ! "$SYSTEM_PATH" ]; then
    SYSTEM_PATH="$PATH";
fi

# Use $HOME here, `/usr/bin/which' doesn't know how to expand `~'.
PATH="$HOME/bin:$HOME/sbin:$HOME/.rbenv/bin:/opt/rbenv/bin:/usr/local/bin:/usr/local/sbin";
PATH="$PATH:/usr/bin:/usr/sbin:/bin:/sbin";

# Set the MANPATH environment variable.  Add here as needed.
MANPATH="$MANPATH:/usr/local/man";

# We don't want to display the full host name on the xterm title...
BASEHOSTNAME="`echo "$HOSTNAME" | cut -d. -f1`";

if type -p rbenv >/dev/null; then
  if [ -d /usr/local/var/rbenv ]; then
    export RBENV_ROOT=/usr/local/var/rbenv
  fi
  eval "$(rbenv init -)"
fi

##############################################################################
# Functions and aliases
##############################################################################

__SSH=$(type -path ssh 2>/dev/null);
function ssh()
{
  # This function overrides ssh to rsync all files listed in $HOME/.briefcase to
  # the remote server before logging in.  It tries very hard to skip this if
  # you're logging in as another user, but it cannot detect whether you have an
  # alternate "User" defined in $HOME/.ssh/config or its /etc equivalent.
  # USE WITH CAUTION!
  local skip_sync;
  if ! type -f rsync 2>&1 >/dev/null; then
    # we don't have rsync.
    skip_sync=1;
  fi
  if [ ! -f "$HOME/.briefcase" ]; then
    skip_sync=1;
  fi
  # skip ssh options to find hostname
  while getopts ":1246AaCfgKkMNnqsTtVvXxYyb:c:D:e:F:i:L:l:m:O:o:p:R:S:w:" Option; do
    if [ "$Option" = "l" ]; then
      # don't sync if we're logging into a different user's account
      skip_sync=1;
      break;
    fi
  done
  server=`eval echo "$"$OPTIND`
  # reset $OPTIND so that subsequent invocations work properly
  OPTIND=1;
  if echo "$server" | grep "@"; then
    # don't sync if we're logging into a different user's account
    skip_sync=1;
  fi
  if [ -z "$skip_sync" -a -z "$DISABLE_BRIEFCASE" ]; then
    rsync -vurptgoDL -e ssh --files-from="$HOME/.briefcase" "$HOME" "$server":
  fi
  $__SSH "$@";
}

# Fixup ssh authentication socket.  This is useful in the context of resuming a
# screen(1) or tmux(1) session, where the SSH_AUTH_SOCK environment variable
# could point to a socket that was created when the session was launched but
# no longer exists.

if [ -n "$SSH_AUTH_SOCK" ] && [ "$SSH_AUTH_SOCK" != "$HOME/.tmp/ssh_auth.sock" ]; then
  mkdir -p $HOME/.tmp
  ln -sf "$SSH_AUTH_SOCK" $HOME/.tmp/ssh_auth.sock
  export SSH_AUTH_SOCK=$HOME/.tmp/ssh_auth.sock
fi

alias ls='ls -FA' 2>/dev/null
alias ll='ls -lFA' 2>/dev/null
alias l.='ls -dFA .*' 2>/dev/null

function rsa_modulus { openssl rsa -modulus -noout -in $1; }
function x509_modulus { openssl x509 -modulus -noout -in $1; }
function pick { git cherry-pick "$@"; }
function myexternalip { curl http://jsonip.com/; echo; }
function cheftrace { sudo $PAGER /var/chef/cache/chef-stacktrace.out; }
function cheflog { $PAGER /var/log/chef/client.log; }

##############################################################################
# Only terminal-related stuff beyond this point
##############################################################################

# Quit .profile if stdin is not a terminal.
if [ -t 0 ]; then
  NCOLORS=`tty -s && tput colors 2>/dev/null`
  if [ -n "$NCOLORS" -a "$NCOLORS" -gt 1 -a -n "$PS1" ] ; then
    __TERM_HAS_COLORS="yes"
    if [ "$OS" = "Linux" ]; then
      COLORS=
      for colors in "$HOME/.dir_colors.$TERM" "$HOME/.dircolors.$TERM" \
          "$HOME/.dir_colors" "$HOME/.dircolors"; do
        [ -e "$colors" ] && COLORS="$colors" && break
      done

      [ -z "$COLORS" ] && [ -e "/etc/DIR_COLORS.256color" ] && \
          [ "x`tty -s && tput colors 2>/dev/null`" = "x256" ] && \
          COLORS="/etc/DIR_COLORS.256color"

      if [ -z "$COLORS" ]; then
        for colors in "/etc/DIR_COLORS.$TERM" "/etc/DIR_COLORS" ; do
          [ -e "$colors" ] && COLORS="$colors" && break
        done
      fi

      # Existence of $COLORS already checked above.
      if [ -n "$COLORS" ]; then
        eval "`dircolors --sh "$COLORS" 2>/dev/null`"
        if ! grep -qi "^COLOR.*none" $COLORS >/dev/null 2>/dev/null; then
          alias ls='ls -FA --color=auto' 2>/dev/null
          alias ll='ls -lFA --color=auto' 2>/dev/null
          alias l.='ls -dFA .* --color=auto' 2>/dev/null
        fi
      fi
    elif [ "$OS" = "Darwin" ]; then
      export LSCOLORS="exfxcxdxbxegedabagacad"
      export CLICOLOR=1
    fi
  fi

  # System dependent terminal settings.
  #
  # In order to be able to use C-s with bash to perform
  # forward-search-history, add `stty stop "^-"' to undefine the stop
  # character (the default on my Linux box).
  #
  stty hupcl isig -ixon kill "^U" intr "^C" eof "^D";
  stty stop "^-" erase "^?";

  # Set the window title and icon strings, if TERM supports it.
  if [ "$TERM" = "xterm" -o\
       "$TERM" = "xterm-color" -o\
       "$TERM" = "xterm-256color" -o\
       "$TERM" = "xterm-debian" -o\
       "$TERM" = "rxvt" ]; then
    PROMPT_COMMAND='echo -ne "\033]1;$BASEHOSTNAME\007\033]2;$OS Shell"';
    PROMPT_COMMAND="$PROMPT_COMMAND"'" - $USER@$BASEHOSTNAME : $PWD\007"';
  else
      unset -v PROMPT_COMMAND;
  fi

  # __USER, __HOST & __PATH can be defined in .sitedep, if colors are
  # supported.  Suggested by Andrei Pitis <pink@roedu.net>.
  if [ "$__TERM_HAS_COLORS" = "yes" ]; then
    if [ -n $__USER ]; then __USER="\[\033[31m\]"; fi
    if [ -n $__HOST ]; then __HOST="\[\033[32m\]"; fi
    if [ -n $__PATH ]; then __PATH="\[\033[36m\]"; fi
    __DFLT="\[\033[0m\]";
  else
    __USER="";
    __HOST="";
    __PATH="";
    __DFLT="";
  fi


  # Only do this stuff if we're a non-interactive shell
  if [ -n "$PS1" ]; then
    # Linux >= 2.2.x supports fancy text mode cursors.
    if [ "$OS" = "Linux" -a "$TERM" = "linux" ]; then
      __RELEASE=`uname -r`;
      if [ $(echo $__RELEASE | cut -d. -f1) -ge 2 -a $(echo $__RELEASE | cut -d. -f1) -ge 2 ]; then
        echo -ne '\033[?64c';
      fi
    fi

    if type -t __git_ps1 >/dev/null 2>&1; then
      GIT_INFO="\$(__git_ps1)"
    else
      GIT_INFO=""
    fi
    PS1="$__DFLT[$__USER$USER$__DFLT@$__HOST\h$__DFLT]:$__PATH\w$__DFLT$GIT_INFO "'\$ ';

    fortune 2> /dev/null;
    echo "Happy hacking!";
  fi
fi

# Read the personal/site-dependent configuration file.
if [ -f ~/.bashrc_local ]; then
  . ~/.bashrc_local;
fi

# vim:syn=sh:ts=2:sw=2:et:ai
