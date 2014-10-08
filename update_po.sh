#!/bin/sh
# Lara Maia © 2012 ~ 2014 <lara@craft.net.br>

if [ "$1" == "" ]; then
	pofile=backup-conf
	sufix=pot
	if [ -f ${pofile}.${sufix} ]; then
		rm po/${pofile}.${sufix}
	fi
else
	pofile=${1}
	sufix=po
fi

if [ -e po/${pofile}.${sufix}.bkp ]; then
	echo "Apagando backup antigo de po/${pofile}.${sufix}"
	rm -f po/${pofile}.${sufix}.bkp
fi

if [ -f po/${pofile}.${sufix} ]; then
echo "Criando backup de po/${pofile}.${sufix} para po/${pofile}.${sufix}.bkp"
	cp po/${pofile}.${sufix} po/${pofile}.${sufix}.bkp
fi
            
function create() {
echo "Criando po/${pofile}.${sufix} a partir de backup-conf.sh"
xgettext -d backup-conf -o po/${pofile}.${sufix} -s backup-conf.sh
sed --in-place po/${pofile}.${sufix} --expression=s/CHARSET/UTF-8/
}

function update() {
echo "Atualizando po/${pofile}.${sufix} a partir de backup-conf.sh"
xgettext -d backup-conf -o po/${pofile}.${sufix} -j -s backup-conf.sh
}

if [ "$2" == "--new" ]; then
	if [ ! -f "po/${pofile}.${sufix}" ]; then
		unset nofirst
	fi
	
	if [ ! -n "$nofirst" ]; then
		sufix=pot
		create $file
		nofirst=true
	else
		update $file
	fi
else
	if [ -f "po/${pofile}.${sufix}" ]; then
		update $file
	else
		echo "Arquivo não encontrado."
		create $file
	fi
fi
