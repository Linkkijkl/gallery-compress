#!/bin/bash

# This script converts big files into smaller ones using imagemagic.
#
# Have backups of directories this script processes, as they will
# get recompressed and the original images removed. 

# Images larger than this will get converted
MAX_FILE_SIZE="2M"

if [ "$#" -lt "1" ]
then
    echo "Usage: $0 directory"
    exit 1
fi

! type magick > /dev/null \
	&& >&2 echo "This script requires imagemagic to work!" && exit 1
! type exiftool > /dev/null \
	&& >&2 echo "This script requires exiftool to work!" && exit 1

# Set terminating character temporarily to only newline, for
# walking over file paths with spaces
oifs="$IFS"
IFS=$'\n'

# Spawn (number of threads / 4) tasks
N=$(( $(nproc)/4 ))

# Walk files
for file in $(find "$1" -type f)
do
	# Spawn jobs
	(
		dir=$(dirname "$file")
		filename=$(basename "$file")
		extension="${filename##*.}"
		name=$(basename "$file" ."$extension") # Removes extension from filename
	
		# Convert only if file type is desired to be converted
		if ! [[ "${extension,,}" =~ jpg|jpeg|png ]]
		then
			exit
		fi
	
		# Don't convert files which are smaller than set treshold
		maxsize=$(numfmt --from auto "$MAX_FILE_SIZE")
		realsize=$(wc -c < "$file")
		if [ "$realsize" -lt "$maxsize" ]
		then
			exit
		fi
	
		# Convert, transfer metadata and remove the original file
		pushd "$dir" > /dev/null

		echo "Converting $file ..."
		with_extension="$name.avif"
		
		magick "$filename" -quality 50 -auto-orient "$with_extension" \
		&& exiftool "$with_extension" "-filecreatedate<datetimeoriginal" \
			"-filemodifydate<datetimeoriginal" &> /dev/null \
		&& rm "$filename" \

		popd > /dev/null
	) &

	# Allow to execute up to $N jobs in parallel
	if [[ $(jobs -r -p | wc -l) -ge $N ]]
	then
		wait -n
	fi
done

# Wait for jobs to terminate
wait

# Restore terminating characters
IFS=oifs

