#!/usr/bin/env bash

# Versioned daily rsync snapshots with weekly and monthly purge.
# Uses rsync and hardlinks to create snapshots that looks like full backups
# and saves space by linking to files already copied in a previos snapshot.
# Don't use/change files in a snapshot. Copy the files/snapshot first.
# Don't store anything but snapshots in $destination

# Change these variables to customize:
destination='/sharedfolders/nas3/snapshots/nas0/local_media'
source='/srv/nfs/nas0/local_media'
snapshot_name=local_media_$(date +%F_%T)

# Set number of daily, weekly and monthly backups to keep
keep_daily=7    # keep this number of daily backups
keep_weekly=4   # keep this number of weekly backups
keep_monthly=4  # keep this number of monthly backups

# Announcement
echo "Snapshot: " "$source" to "$destination"

# Delete earlier failed attempt at making a snapshot, if any
# rm -rf "$destination"/.unfinished		

# Find latest snapshot, if any
latest_snapshot=$(ls -rt "$destination" | tail -1)

# Create folder for this snapshot, unfinished so far...
mkdir -p "$destination"/.unfinished

# Grab new snapshot. Use rsync to create hard links to files already in 
# latest previous snapshot(s)
rsync -a --delete --stats --inplace \
      --link-dest="$destination"/"$latest_snapshot" \
      "$source" \
      "$destination"/.unfinished > "$destination"/.unfinished/rsync.log 

# Finished!
if [ $? -eq 0 ]; then
	mv "$destination"/.unfinished "$destination"/"$snapshot_name"
else
	exit 1
fi

# Purge old backups 

#
# Echo age of file $1 in days
#
age_in_days ()
{
	(( age = ( $(date -d 'now' +%s) - $(date -r "$destination/$1" +%s) ) / 60 / 60 / 24 ))
	echo $age
}

#
# Compare time diffs between an old backup and the two next newer
# $1 = Old backup
# $2 = Next next newer backup
# $3 = Target age interval between backups
# Echo 1 if the age interval between backups means that a snapshot
# between $1 and $2 can be purged
#
can_purge_next ()
{
	(( diff2 = "$3" - ( $(age_in_days "$1" ) - $(age_in_days "$2" )) ))

	# Can purge next?
	if (( diff2 >= 0 )); then
		echo 1
	else
		echo 
	fi
}

#
# Echo 1 if file $1 is older than $2 days
#
older ()
{
	(( age = $(age_in_days "$1") ))

	if (( age > "$2" )); then
		echo 1
	else
		echo 
	fi
}

#
# Purge a set of backups
# $1 = Start age for backups to possibly purge, in days
# $2 = Stop age for backups to possibly purge, in days
# $3 = Target interval for backups to keep, in days
# $4-$# = Backups to check, sorted with oldest first
#
purge ()
{
	days_start=$1
	days_stop=$2
	days_interval=$3 

	shift 3

	# Fast forward to first snapshot to test   
	while [[ "$#" && $(older "$1" "$days_start") ]]; do
		shift
	done

	# purge snapshots until stop
	while [[ "$#" && $(older "$1" "$days_stop") ]]; do
		curr=$1
		next1=$2
		next2=$3

		# really purge snapshots
		while [[ $(older "$next1" "$days_stop") && $(can_purge_next "$curr" "$next2" "$days_interval") ]]; do
			rm "$destination/$next1" -rf
			shift
			next1=$next2
			next2=$3
		done
		shift
	done
}

# calculate boundaries between daily/weekly/monthly
((max_age_daily = keep_daily))
((max_age_weekly = max_age_daily + 7 * keep_weekly))
((max_age_monthly = max_age_weekly + 30 * keep_monthly))

# delete all backups older than max_age_monthly
find $destination -maxdepth 1 -type d -mtime +$max_age_monthly -print0 | xargs -0 rm -rf

# Purge monthly start stop interval snapshots oldest first
purge $max_age_monthly $max_age_weekly 30 $(ls -rt "$destination")

# Purge weekly
purge $max_age_weekly $max_age_daily 7 $(ls -rt "$destination")

exit 0
