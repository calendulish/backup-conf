#!/bin/sh
# Lara Maia © 2012 ~ 2014 <lara@craft.net.br>
# version: 4.0

test $(id -u) == 0 && echo "EPA" && exit 1

NOQUESTION=0
CONFIG="/etc/backup-conf"

case "$1" in
    -y|--yes) NOQUESTION=1
              shift
              ;;
esac

function checkfiles() {
    # Accept single update
    test "$1" != "" && FILES=("$1")

    for file in ${FILES[@]}; do

        # if is $home
        if [ ${file:0:${#HOME}} == "$HOME" ]; then
            dest=HOME${file:${#HOME}}
        elif [ ${file:0:1} == "/" ]; then
            dest=${file:1}
        fi

        if [ -f "$file" ]; then

            # Prevent destination not found
            test ! -f "$dest" && mkdir -p ${dest%/*} && touch $dest

            if ! colordiff -u "$dest" "$file"; then
                while true; do
                    if [ $NOQUESTION != 1 ]; then
                        echo -e "\n==> Arquivo $file"
                        echo -ne "==> [C]opiar, [R]estaurar, [I]gnorar, [S]air: "
                        read -n 1 opc
                    else
                        opc=C
                    fi

                    case $opc in
                        C|c) echo -e "\n==> Fazendo backup de '$file'"
                             cp -f "$file" "$dest" && echo -e "\n" && break || exit 1 ;;
                        R|r) echo && sudo cp -f "$dest" "$file" && echo -e "\n" && break || exit 1 ;;
                        I|i) test -f $dest && rm $dest; echo -e "\n"
                             git checkout -- $dest 2>/dev/null
                             break ;;
                        S|s|E|e) exit 1 ;;
                        *) echo -ne " < Opção incorreta\r\n" && continue ;;
                    esac
                done
            fi
        else
            echo -e "\n * O arquivo $file não existe no sistema de arquivos, ignorando."
        fi
    done
}

echo -e "\nCriando lista de arquivos..."
declare -x FILES=($(grep -v '^#' $CONFIG))

echo "Verificando arquivos..."
checkfiles "$1"

echo -e "\nTarefa completada com sucesso!"

exit 0
