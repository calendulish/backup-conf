#!/bin/bash
# Lara Maia <dev@lara.monster> 2012 ~ 2024
# version: 5.2.3

NOQUESTION=
SINGLEFILE=
RM_OBSOLETE=
_PWD="$PWD"
export TEXTDOMAIN=backup-conf
source gettext.sh
IFS=$'\n\b'

test $(id -u) == 0 && echo -e "\nWARNING: $(gettext "running as root")" && sleep 5

if [ -f ${XDG_CONFIG_HOME-$HOME/.config}/backup-conf.conf ]; then
    CONFIG="${XDG_CONFIG_HOME-$HOME/.config}"/backup-conf.conf
elif [ -f "/etc/backup-conf.conf" ]; then
    CONFIG="/etc/backup-conf.conf"
else
    echo -e "\nERROR: $(gettext "The Configuration file was not found")"
    echo "$(gettext "You can use the example file located at:")"
    echo "/usr/share/backup-conf/backup-conf.conf.example"
    echo "$(gettext "edit with the files/directories you want to backup.")"
    echo "$(gettext "The valid paths for the config file are:")"
    echo "${XDG_CONFIG_HOME-$HOME/.config}/backup-conf.conf"
    echo "/etc/backup-conf.conf"
    echo -e "\n$(gettext "Exiting")\n" && exit 1
fi

DIFFPROGRAM=$(grep '^#?DIFFPROGRAM' $CONFIG | cut -d' ' -f2-)
if [ "$DIFFPROGRAM" == "" -o ! -f "$DIFFPROGRAM" ]; then
    echo -e "\nERROR: $(gettext "The path of your diff tool is incorrect or not set.")"
    echo -e "$(gettext "Please, check your configuration file. The variable")"
    echo -e "$(gettext "#?DIFFPROGRAM must be set or the program will not work.")"
    echo -e "$(gettext "Exiting")\n"
    exit
fi

USE_GIT=$(grep '^#?USE_GIT' $CONFIG | cut -d' ' -f2-)
test "$USE_GIT" == "0" && USE_GIT=

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
    local msg14=$(gettext "If the ROOT is a git repository then use git functions")
    local msg16=$(gettext "Show this help and exit.")

    printf "$msg1\n$msg2\n\n"
    printf " -r, --root <$msg3>%$[15-${#msg3}]c $msg4\n%29c $msg5\n"
    printf " -y, --yes %18c $msg6\n"
    printf " -f, --file <$msg7>%$[15-${#msg7}]c $msg8\n%29c $msg9\n"
    printf " -c, --config <$msg10>%$[13-${#msg10}]c $msg11\n"
    printf " -R, --remove-obsoletes %5c $msg12\n%29c $msg13\n"
    printf " -G, --use-git %14c $msg14\n"
    printf " -h, --help %17c $msg16\n\n"
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
        -G|--use-git)
            USE_GIT=1
            shift
            ;;
        -h|--help)
            help
            exit 0
            ;;
        "")
            shift
            break
            ;;
         *)
            echo -e "$(gettext "Invalid option.")\n"
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
            echo -e "\n\n     |- $(eval_gettext "WARNING: Location \$file is not a valid absolute path.")"
            continue
        fi

        if [ -f "$file" ]; then

            if test ! -s "$file"; then
                echo -en "\n\n     |- $(eval_gettext "WARNING: The file \$file is empty.")"
                if test -f "$dest"; then
                    echo -e " $(gettext "Removing from backup.")"
                    if test "$USE_GIT"; then
                        git rm -f $dest
                    else
                        rm -fv $dest
                    fi
                else
                    echo -e " $(gettext "Ignoring.")"
                fi
                continue
            fi

            # Prevent destination not found
            test ! -f "$dest" && mkdir -p ${dest%/*} && touch $dest

            if ! cmp -s "$dest" "$file"; then
                while true; do
                    if test "$NOQUESTION"; then
                        opc=C
                    else
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
                    fi

                    case $opc in
                        C|c)
                            echo -e "\n\n     |- $(gettext "Backing up") $file"
                            cp -f "$file" "$dest" || exit 1
                            if test "$USE_GIT"; then
                                pushd $_PWD 1>/dev/null || exit 1
                                git add "${dest/$_PWD\/}"
                                popd 1>/dev/null || exit 1
                            fi
                            break
                            ;;
                        R|r)
                            echo
                            which sudo >/dev/null 2>&1
                            if [ $? == 0 ]; then
                                sudo cp -f "$dest" "$file" || exit 1
                            else
                                echo -e "\n\n     |- $(gettext "Warning: Sudo unavailable. Ignoring Restore.")"
                            fi
                            echo -e "\n"
                            break
                            ;;
                        I|i)
                            test -f "$dest" && rm "$dest"
                            echo -e "\n"
                            if test "$USE_GIT"; then
                                git checkout -- "$dest" 2>/dev/null
                            fi
                            break
                            ;;
                        E|e)
                            test ! -s "$dest" && rm "$dest"
                            echo
                            exit 1
                            ;;
                        *)
                            echo -ne " < $(gettext "Wrong option")\r\n"
                            continue
                            ;;
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
            match="${match/$HOME/HOME/}"
            match="${match/\//}"
            #echo "$file == $match"
            if [ $file == ${match/$HOME/HOME} ]; then
                CURRENT_FILES=(${CURRENT_FILES[@]/$file/})
            fi
        done
    done

    for file in ${CURRENT_FILES[@]}; do
        if test "$NOQUESTION"; then
            opc=s
        else
            echo -ne "\n  * $(eval_gettext "File \$file is no longer needed. Delete it? [y/N]")"
            read -n 1 opc
        fi
        case "$opc" in
            s|S|y|Y)
                echo
                if test "$USE_GIT"; then
                    git rm -f $file
                else
                    rm -fv $file
                fi
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
