#!/bin/bash
# Lara Maia © 2012 ~ 2014 <lara@craft.net.br>
# version: 4.0

test $(id -u) == 0 && echo "EPA" && exit 1

NOQUESTION=0
CONFIG="/etc/backup-conf"
_PWD="$PWD"
ARGS=$(getopt -o r:y:h -l "root:,yes:,help" -n "backup-conf" -- "$@");

export TEXTDOMAIN=backup-conf
source gettext.sh

eval set -- "$ARGS"

function help() {
program_name=$0
echo -e "$(eval_gettext "Usage: $program_name [option]... [file]...")\n"
echo -e "$(gettext "No parameter is strictly necessary.")\n"
echo -e " -r, --root $(gettext "<FOLDER>      Use <FOLDER> as ROOT instead of")"
echo -e "                          $(gettext "the current directory.")"
echo -e " -y, --yes                $(gettext "Say yes for all questions")"
echo -e " -h, --help               $(gettext "Show this help and exit.")"
}

while true; do
    case "$1" in
        -r|--root) shift
                   if [ -n "$1" ]; then
                       _PWD="$1"
                       shift
                   else
                       echo -e "$(gettext "Invalid syntax.")\n"
                       exit 1
                   fi
                   ;;

        -y|--yes) NOQUESTION=1
                  shift
                  ;;
        -h|--help) help
                   exit 0
                   ;;
        --) shift
            break
            ;;
    esac
done

function checkfiles() {
    # Accept single update
    test "$1" != "" && FILES=("$1")

    for file in ${FILES[@]}; do
        # expand variables
        file=$(eval echo $file)

        # if is $home
        if [ ${file:0:${#HOME}} == "$HOME" ]; then
            dest="$_PWD/HOME${file:${#HOME}}"
        elif [ ${file:0:1} == "/" ]; then
            dest="$_PWD$file"
        else
            echo -e "\nERROR: $(gettext "Location is not a valid absolute path:") $file"
            echo -e "$(gettext "Exiting")\n"
            exit 1
        fi

        if [ -f "$file" ]; then

            # Prevent destination not found
            test ! -f "$dest" && mkdir -p ${dest%/*} && touch $dest

            if ! colordiff -u "$dest" "$file"; then
                while true; do
                    if [ $NOQUESTION != 1 ]; then
                        echo -e "\n ==> $(gettext "File:") $file)"
                        echo -ne " ==> $(gettext "[C]opy, [R]estore, [I]gnore, [E]xit:")"
                        read -n 1 opc
                    else
                        opc=C
                    fi

                    case $opc in
                        C|c) echo -e "\n\n     |- $(gettext "Backing up") $file"
                             cp -f "$file" "$dest" && break || exit 1 ;;
                        R|r) echo && sudo cp -f "$dest" "$file" && echo -e "\n" && break || exit 1 ;;
                        I|i) test -f $dest && rm $dest; echo -e "\n"
                             git checkout -- $dest 2>/dev/null
                             break ;;
                        S|s|E|e) test ! -s $dest && rm $dest
                                 echo && exit 1 ;;
                        *) echo -ne " < $(gettext "Wrong option")\r\n" && continue ;;
                    esac
                done
            fi
        else
            echo -e "\n     |- $(eval_gettext "The file \$file not found in file system. Ignoring.")"
        fi
    done
}

echo -e "\n ==> $(gettext "Creating file list...")"
declare -x FILES=($(grep -v '^#' $CONFIG))

echo -e "\n ==> $(gettext "Checking files...")"
checkfiles "$1"

echo -e "\n ==> $(gettext "Task completed.")"

exit 0
