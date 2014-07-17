#!/bin/sh
# Lara Maia © 2012 ~ 2014 <lara@craft.net.br>
# version: 4.0

test $(id -u) == 0 && echo "EPA" && exit 1

NOQUESTION=0
CONFIG="/etc/backup-conf"
_PWD="$PWD"
ARGS=$(getopt -o r:y:h -l "root:,yes:,help" -n "backup-conf" -- "$@");

eval set -- "$ARGS"

function help() {
cat << EOF
Uso: $0 [opção]... [arquivo]..."

Nenhum parâmetro é estritamente necessário.

 -r, --root <PASTA>       Usa <PASTA> como ROOT ao em vez
                          do diretório atual.
 -y, --yes                Responde sim automaticamente para
                          todas as pergunta
 -h, --help               Mostra esta ajuda e finaliza.
EOF
}

while true; do
    case "$1" in
        -r|--root) shift
                   if [ -n "$1" ]; then
                       _PWD="$1"
                       shift
                   else
                       echo "Sintaxe inválida."
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

        # if is $home
        if [ ${file:0:${#HOME}} == "$HOME" ]; then
            dest="$_PWD/HOME${file:${#HOME}}"
        elif [ ${file:0:1} == "/" ]; then
            dest="$_PWD$file"
        else
            echo "Não é um caminho absoluto: $file"
            echo "Isso é um erro fatal! Saindo..."
            exit 1
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
                        S|s|E|e) test ! -s $dest && rm $dest
                                 exit 1 ;;
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
