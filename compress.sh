#!/bin/bash

# This script converts big files into more efficently compressed formats.
#
# Have backups of directories this script processes, as they will
# get recompressed and the original images removed. 

# Images larger than this will get converted
max_file_size=$(numfmt --from auto "2M")

if [ "$#" -lt "1" ]
then
    echo "Usage: $0 directory"
    exit 1
fi

! type magick |: \
	&& >&2 echo "This script requires imagemagic to work!" && exit 1
! type exiftool |: \
	&& >&2 echo "This script requires exiftool to work!" && exit 1

# Spawn (number of threads / 2) tasks
N=$(( $(nproc)/2 ))

# Walk over files in target directory
while IFS= read -r -d '' input_file
do
	# Spawn jobs
	(
		# Convert only if file type is desired to be converted
		extension="${input_file##*.}"
		if ! [[ "${extension,,}" =~ jpg|jpeg|png ]]
		then
			exit
		fi
	
		# Don't convert files which are smaller in size than set treshold
		realsize=$(wc -c < "$input_file")
		if [ "$realsize" -lt "$max_file_size" ]
		then
			exit
		fi
	
		echo "Converting $input_file ..."
		input_file_without_extension="$(
			dirname "$input_file")/$(basename "$input_file" ."$extension"
		)"
		output_file="$input_file_without_extension".webp

		# Convert, transfer file modification date metadata, and remove the original file
		magick "$input_file" -quality 50 -define webp:image-hint=picture \
			-define webp:method=6 -define webp:thread-level=0 \
			-auto-orient "$output_file" \
		&& touch -d "$( \
			exiftool -d "%r %a, %B %e, %Y" -DateTimeOriginal -S -s "$input_file" \
		)" "$output_file" \
		&& rm "$input_file"
	) &

	# Allow to execute up to $N jobs in parallel
	if [ "$(jobs -r -p | wc -l)" -ge $N ]
	then
		wait -n
	fi

done < <(find "$1" -type f -print0)

# Wait for jobs to terminate
wait
