#!/bin/bash


src_dir="/home/hash/Downloads/Data/conv_tidigits_comp/data/adults/train/man/"
dir_list=$(find $src_dir -type d)
curr_dir=$(pwd)

for dir in $dir_list
do
        cd $dir
	new_dir=$(echo $dir | sed 's/\(^.*\/\)conv\(\_tidigits\_comp.*$\)/\1raw\2/')
	mkdir -p $new_dir

done
cd $curr_dir
file_list=$(find /home/hash/Downloads/Data/conv_tidigits_comp/data/adults/train/man/  -type f -iname "*.wav")	
for file_name in $file_list
do
	#echo $file_name
	new_file=$(echo $file_name | sed 's/\(^.*\/\)conv\(\_tidigits\_comp.*$\)/\1raw\2/')
	sox $file_name -r 16000 $new_file
	raw_file=$(echo $file_name | sed 's/\(^.*\/\)conv\(\_tidigits\_comp.*\)\.wav$/\1raw\2.raw/')
	"$curr_dir"/wav_raw $new_file temp
	mv  "temp" $raw_file
done


