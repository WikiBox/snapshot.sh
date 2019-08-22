# snapshot.sh
Bash script for versioned snapshots using rsync, with purging

This is how I do my first level automatic backups of my servers. I run a couple of Odroid HC2 ARM SBCs with the Openmediavault NAS software and a 12TB drive. nas0 to nas5. I run them in pairs where the first NAS in the pair is used to share files on my LAN and the second NAS in the pair is used to take daily automatic versioned backup snapshots of the first NAS. 

I use a couple of bash-scripts, one per major folder on the NAS. And I have a cron job setup to, at 03:00, run a "master script" that in turn run all the snapshot scripts. All my NAS are connected to each other using GbE, NFS4 and autofs. The autofs mounts are in /srv/nfs/nas#.

I have a separate script for each backup job. The scripts are all identical except for some paths, names and constants modified at the beginning of the script. 
```
# Change these variables to customize:
destination='/sharedfolders/nas1/snapshots/nas0/local_media'
source='/srv/nfs/nas0/local_media'
snapshot_name=local_media_$(date +%F_%T)

# Set number of daily, weekly and monthly backups to keep
keep_daily=7    # keep this number of daily backups
keep_weekly=4   # keep this number of weekly backups
keep_monthly=4  # keep this number of monthly backups
```
As can be seen above this script was used to update a snapshot of local_media from nas0 to nas1. And snapshots are automatically purged so that no more than 7 daily, 4 weekly and 4 monthly snapshots are retained.

The script creates a full snapshot backup copy by hardlinking unmodified files from the previous snapshot and copying over only modified files, if any. This means that the script is usually very fast. A snapshot with several TB of data and many thousands of files and folders can be updated in about a minute or so, if no files need to be copied. 

This is of course inspired by "Easy Automated Snapshots, Mike Rubel". 

See: http://www.mikerubel.org/computers/rsync_snapshots/


