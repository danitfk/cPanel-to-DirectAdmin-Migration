# cPanel to DirectAdmin Account Migration Perl Script

This is a painless perl script to migrate accounts from cPanel to DirectAdmin. Originally It released on DirectAdmin's forum by `l0rdphi1`.

# INSTRUCTIONS

* Download and extract the version URL (from above) that you wish to use. (wget and tar xzf)

* Create import and export directories for the tool to use. (mkdir import export)

* Copy your cPanel user backups into the import directory.

* Edit defaults.conf to match the DA server you will be restoring to. The only fields you must change are the IP and name server fields. The tool will not work if you fail to do this!

* Execute perl da.cpanel.import.pl and follow the on-screen instructions (which will duplicate the steps here to a degree).

* After the tool is finished converting (or as it completes each individual user), move your new DA user backups from the export directory to any DA /home/RESELLER/user_backups directory*

* Restore the DA user backups in DA's reseller-level Manage User Backups tool.

### How to Get Backup in cPanel?

You can get a backup from user(s) with GUI or `pkgacct` command.
Command line way:
```
BACKUP_DIR=/root/username
mkdir -p $BACKUP_DIR
/scripts/pkgacct USERNAME $BACKUP_DIR
cd $BACKUP_DIR
ls -ls

```


[[ Original Link: http://forum.directadmin.com/showthread.php?t=2247 ]]
