Backup Conf (Old update.sh)
---------------------------

This script create a backup of your config files in a tree format
on current folder. The config file can be used for backup specific
files that you want backup, in any folder. If the file is on $HOME,
the script create a folder named "HOME" and put the files on it.


Install
-------
Copy backup-conf.sh into PATH. E.g:

```
cp backup-conf.sh /usr/bin/backup-conf
chmod 755 /usr/bin/backup-conf
```

And the config file in /etc folder:

```
cp backup-conf /etc/
chmod 644 /etc/backup-conf
```

[*Still in Development*]
