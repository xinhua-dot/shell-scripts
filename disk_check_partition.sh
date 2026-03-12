#!/bin/bash

threshold=30

for mount_point in "/" "/home" "/var";do
	disk_usage=$(df -h $mount_point | awk 'NR==2 {print $5}' | sed 's/%//')
	if [ $disk_usage -gt ${threshold} ];then
		echo "Waring:$mount_point has already arrived ${disk_usage}% bigger than ${threshold}%"
		echo "Time:$(date)"
		echo "Waring:$mount_point has already arrived ${disk_usage}% bigger than ${threshold}%" >> test_result.txt
		logger "The server's disk is full：utilization rate${disk_usage}%"
	else
		echo "The disk usage is normal：${disk_usage}%"
		echo "Time:$(date)"
		echo "The disk usage is normal：${disk_usage}%" >> test_result.txt
		echo "Time:$(date)" >> test_result.txt
	fi
done
