#!/bin/bash
# Lara Maia © 2012 ~ 2015 <lara@craft.net.br>
# version: 5.0

test $(id -u) == 0 && echo "EPA" && exit 1

NOQUESTION=0
SINGLEFILE=
RM_OBSOLETE=
_PWD="$PWD"
export TEXTDOMAIN=backup-conf
source gettext.sh
IFS=$'\n\b'

if [ -f $XDG_CONFIG_HOME/backup-conf.conf ]; then
    CONFIG="$XDG_CONFIG_HOME"/backup-conf.conf
elif [ -f "/etc/backup-conf.conf" ]; then
    CONFIG="/etc/backup-conf.conf"
else
    echo -e "\nERROR: $(gettext "The Configuration file was not found")"
    echo "$(eval_gettext "Copy the example to \$XDG_CONFIG_HOME/backup-conf.conf or")"
    echo "/etc/bakcup-conf.conf $(gettext "and edit with your files/directories.")"
    echo -e "$(gettext "Exiting")\n" && exit 1
fi

DIFFPROGRAM=$(grep '^#?DIFFPROGRAM' $CONFIG | cut -d' ' -f2-)
if [ "$DIFFPROGRAM" == "" -o ! -f "$DIFFPROGRAM" ]; then
    echo -e "\nERROR: $(gettext "The path of your diff tool is incorrect or not set.")"
    echo -e "$(gettext "Please, check your configuration file. The variable")"
    echo -e "$(gettext "#?DIFFPROGRAM must be set or the program will not work.")"
    echo -e "$(gettext "Exiting")\n"
    exit
fi

function help() {
    local program_name=$0
    local msg1=$(eval_gettext "Usage: \$program_name [option]... [file]...")
    local msg2=$(gettext "Parameters is not strictly necessary.")
    local msg3=$(gettext "FOLDER")
    local msg4=$(gettext "Use <FOLDER> as ROOT instead of")
    local msg5=$(gettext "the current directory.")
    local msg6=$(gettext "Say yes for all questions.")
    local msg7=$(gettext "FILE")
    local msg8=$(gettext "Update only the <FILE> instead of")
    local msg9=$(gettext "file list at config file.")
    local msg10=$(gettext "PATH")
    local msg11=$(gettext "load config file from <PATH>")
    local msg12=$(gettext "Remove all files in current folder that")
    local msg13=$(gettext "doesn't have a entry on config file")
    local msg14=$(gettext "Show this help and exit.")

    printf "$msg1\n$msg2\n\n"
    printf " -r, --root <$msg3>%$[15-${#msg3}]c $msg4\n%29c $msg5\n"
    printf " -y, --yes %18c $msg6\n"
    printf " -f, --file <$msg7>%$[15-${#msg7}]c $msg8\n%29c $msg9\n"
    printf " -c, --config <$msg10>%$[13-${#msg10}]c $msg11\n"
    printf " -R, --remove-obsoletes %5c $msg12\n%29c $msg13\n"
    printf " -h, --help %17c $msg14\n\n"
}

while true; do
    case "$1" in
        -r|--root)
            shift
            value=$1
            if [ -n "$value" -a "${value:0:1}" != "-" ]; then
                if [ -d "$value" ]; then
                    _PWD="$value"
                    unset value
                    shift
                else
                    echo -e "$(eval_gettext "Directory \$value not found.")\n"
                    exit 1
                fi
            else
                echo -e "$(gettext "Invalid syntax.")\n"
                exit 1
            fi
            ;;
        -y|--yes)
            NOQUESTION=1
            shift
            ;;
        -c|--config)
            shift
            value=$1
            if [ -n $value -a "${value:0:1}" != "-" -a -f $value ]; then
                CONFIG="$value"
                unset value
                shift
            else
                echo -e "$(eval_gettext "File \$value not found.")\n"
                exit 1
            fi
            ;;
        -f|--file)
            shift
            value=$1
            if [ -n "$value" -a "${value:0:1}" != "-" ]; then
                SINGLEFILE="$value"
                unset value
                shift
            else
                echo -e "$(eval_gettext "File \$value not found.")\n"
                exit 1
            fi
            ;;
        -R|--remove-obsolete)
            RM_OBSOLETE=1
            shift
            ;;
        -h|--help)
            help
            exit 0
            ;;
        "") shift
            break
            ;;
         *) echo -e "$(gettext "Invalid option.")\n"
            exit 1
            ;;
    esac
done

function checkfiles() {
    # Accept single update
    test "$SINGLEFILE" != "" && FILES=("$SINGLEFILE")

    for file in ${FILES[@]}; do
        # if is $home
        if [ ${file:0:${#HOME}} == "$HOME" ]; then
            dest="$_PWD/HOME${file:${#HOME}}"
        elif [ ${file:0:1} == "/" ]; then
            dest="$_PWD$file"
        else
            echo -e "\n     |- $(eval_gettext "WARNING: Location \$file is not a valid absolute path.")"
            continue
        fi

        if [ -f "$file" ]; then

            # Prevent destination not found
            test ! -f "$dest" && mkdir -p ${dest%/*} && touch $dest

            if ! cmp -s "$dest" "$file"; then
                while true; do
                    if [ $NOQUESTION != 1 ]; then
                        $DIFFPROGRAM -u "$dest" "$file"
                        echo -e "\n ==> $(gettext "File:") $file)"
                        echo -ne " ==> $(gettext "[C]Copy, [A]Copy all, [R]Restore, [I]Ignore, [E]Exit:")"
                        read -n 1 opc
                        case $opc in
                            A|a)
                                NOQUESTION=1
                                opc=c
                                ;;
                        esac
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
                        E|e) test ! -s $dest && rm $dest
                                 echo && exit 1 ;;
                        *) echo -ne " < $(gettext "Wrong option")\r\n" && continue ;;
                    esac
                done
            fi
        else
            echo -e "\n     |- $(eval_gettext "WARNING: File \$file without read permission or not found.")"
        fi
    done
}

function rmfiles() {
    pushd $_PWD >/dev/null
    local unset IFS
    echo -e "\n ==> $(gettext "Creating exclude list...")"
    declare -x CURRENT_FILES=($(find * -type f -not -wholename '*.git*'))
    for file in ${CURRENT_FILES[@]}; do
        for match in ${FILES[@]}; do
            match="${match/\/home\/lara/HOME/}"
            match="${match/\//}"
            #echo "$file == $match"
            if [ $file == ${match/\/home\/lara/HOME} ]; then
                CURRENT_FILES=(${CURRENT_FILES[@]/$file/})
            fi
        done
    done

    for file in ${CURRENT_FILES[@]}; do
        if [ "$NOQUESTION" != 1 ]; then
            echo -ne "\n  * $(gettext "$file file is no longer needed. Delete it? [s/N]")"
            read -n 1 opc
        else
            opc=s
        fi
        case "$opc" in
            s|S) echo; rm -fv $file
        esac
    done
    popd >/dev/null
}

echo -e "\n ==> $(gettext "Creating file list...")"
declare -x FILES=($(eval echo "\"`grep -v '^#' $CONFIG`\""))

if test "$RM_OBSOLETE"; then
    echo -e "\n ==> $(gettext "Removing obsolete files...")"
    rmfiles
else
    echo -e "\n ==> $(gettext "Checking files...")"
    checkfiles
fi

echo -e "\n ==> $(gettext "Task completed.")"

exit 0
