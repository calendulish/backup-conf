PREFIX := /usr
DESTDIR := /

all: clean

clean:
	rm -f po/*.mo

install:
	msgfmt --check po/pt_BR.po
	mkdir -p $(DESTDIR)$(PREFIX)/share/locale/pt_BR/LC_MESSAGES/
	msgfmt -o $(DESTDIR)$(PREFIX)/share/locale/pt_BR/LC_MESSAGES/backup-conf.mo po/pt_BR.po
	mkdir -p $(DESTDIR)$(PREFIX)/bin/
	mkdir -p $(DESTDIR)/etc/
	install -Dm755 backup-conf.sh $(DESTDIR)$(PREFIX)/bin/backup-conf
	install -Dm644 backup-conf $(DESTDIR)/etc/backup-conf
	
.PHONY: clean
