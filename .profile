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
HISTSIZE=2000;		# At most 2000 entries.
HISTCONTROL=ignoredups;	# No duplicates.
HISTIGNORE="&:ls:ls *:[bf]g:exit"
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
type -path vim >/dev/null 2>&1;
if [ $? -eq 0 ]; then HAVE_VIM=yes; else unset -v HAVE_VIM; fi

if [ "$HAVE_VIM" ]; then
    function vi { vim "$@"; }
    EDITOR=vim;
else
    EDITOR=vi;
fi

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

# Link .bashrc to .profile
if [ ! -L ~/.bashrc ]; then
  rm ~/.bashrc 2> /dev/null;
  ln -s ~/.profile ~/.bashrc;
fi

# Create my local ~/tmp directory.
mkdir ~/tmp 2>/dev/null;
TMPDIR=~/tmp;

# Read the personal/site-dependent configuration file.
if [ -f ~/.bashrc_local ]; then
  . ~/.bashrc_local;
fi

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
PATH="$HOME/bin:$HOME/sbin:/usr/local/bin:/usr/local/sbin";
PATH="$PATH:/usr/bin:/usr/sbin:/bin:sbin";

# Set the MANPATH environment variable.  Add here as needed.
MANPATH="$MANPATH:/usr/local/man";

# We don't want to display the full host name on the xterm title...
BASEHOSTNAME="`echo "$HOSTNAME" | cut -d. -f1`";

# rvm initialization
if [[ -s "$HOME/.rvm/scripts/rvm" ]]; then
  source "$HOME/.rvm/scripts/rvm"
elif [[ -s "/usr/local/lib/rvm" ]]; then
  source "/usr/local/lib/rvm"
fi

##############################################################################
# Functions and aliases
##############################################################################

__SSH=$(type -path ssh 2>/dev/null);
function ssh()
{
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

function rsa_modulus { openssl rsa -modulus -noout -in $1; }
function x509_modulus { openssl x509 -modulus -noout -in $1; }

##############################################################################
# Only terminal-related stuff beyond this point
##############################################################################

# Quit .profile if stdin is not a terminal.
if [ ! -t 0 ]; then
  return 0;
fi

if [ "$TERM" = "linux" -o\
     "$TERM" = "aixterm" -o\
     "$TERM" = "dtterm" -o\
     "$TERM" = "iris-ansi" -o\
     "$TERM" = "iris-ansi-net" -o\
     "$TERM" = "xterm" -o\
     "$TERM" = "xterm-256color" -o\
     "$TERM" = "xterms" -o\
     "$TERM" = "xterm-debian" -o\
     "$TERM" = "rxvt" -o\
     "$TERM" = "screen" -o\
     "$TERM" = "xterm-color" -o\
     "$TERM" = "cygwin" ]; then
    __TERM_HAS_COLORS=yes;
else
    __TERM_HAS_COLORS=no;
fi

# Unset COLORTERM if we're not running on a xterm-like terminal emulator.
if [ "$__TERM_HAS_COLORS" = "no" ]; then
    unset -v COLORTERM;
fi

# Fancy ls.  You still get colors under Linux, even when you use a pipe.
# Make sure you use the regular ls (which is not modified by this file)
# when you _really_ need to filter out the color codes in pipes.
#
# This works for Linux only, the -C & -p options are different for HP-UX,
# Sun, etc.  To be fixed.
#
# Overwrite LS_OPTIONS defined by Linux in /etc/profile.
# BLACK/RED/GREEN/YELLOW/BLUE/MAGENTA/CYAN/WHITE: 0/../7
LS_COLORS="\
or=41:ln=34:bd=34:cd=35:pi=45;32:\
*.c=32:*.cc=32:*.cpp=32:*.h=32:*.java=32:*.l=32:*.y=32:*.s=32:\
*.m4=32:*.pl=32:*.el=32:*.lisp=32:*.in=32:\
*.o=34:*.a=34:*.so=34:*.lo=34:*.la=34:*.elc=34:*.class=34:\
*.ps=35:*.eps=35:*.fig=35:*.dvi=35:*.pdf=35:*.gif=35:*.jpg=35:*.jpeg=35:\
*.djv=35:*.tif=35:*.tiff=35:*.bmp=35:*.png=35:*.ppm=35:*.pgm=35:*.pbm=35:\
*.xpm=35:*.xpm=35:*.icon=35:*.ras=35:*.tga=35:*.mov=35:*.mpg=35:*.mpeg=35:\
*.avi=35:*.fli=35:*.flc=35:\
*.au=33:*.wav=33:*.mp3=33:*.ra=33:*.ram=33:*.mod=33:*.midi=33:*.voc=33:\
*.aiff=33:*.rmd=33:\
*.Z=31:*.bz2=31:*.gz=31:*.uu=31:*.shar=31:*.arj=31:*.zip=31:*.rar=31:\
*.jar=31:*.tar=31:*.tgz=31:*.taz=31:*.rpm=31:";

if [ "$TERM" = "linux" ]; then
    LS_COLORS="$LS_COLORS:di=36;1:so=45;33;1:ex=44;33;1:";
else
    LS_COLORS="$LS_COLORS:di=36:so=45;33:ex=44;33:";
fi

# OS X uses LSCOLORS instead.
LSCOLORS="hxfxcxdxbxegedabagacad"

if [ "$__TERM_HAS_COLORS" = "yes" -a -t 1 ]; then
  __LS=$(type -p ls)
  if [ "$OS" = "Linux" ]; then
    function ls() { $__LS -CFp --color=yes "$@"; };
  elif [ "$OS" = "Darwin" ]; then
    function ls() { $__LS -CFpG "$@"; };
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


if [ -n "$PS1" ]; then
  # Linux >= 2.2.x supports fancy text mode cursors.
  if [ "$OS" = "Linux" -a "$TERM" = "linux" ]; then
    __RELEASE=`uname -r`;
    if [ $(echo $__RELEASE | cut -d. -f1) -ge 2 -a $(echo $__RELEASE | cut -d. -f1) -ge 2 ]; then
      echo -ne '\033[?64c';
    fi
  fi

  PS1="$__DFLT[$__USER$USER$__DFLT@$__HOST\h$__DFLT]:$__PATH\w$__DFLT "'\$ ';

  fortune 2> /dev/null;
  echo "Happy hacking!";
fi

# vim:syn=sh:ts=2:sw=2:et:ai
