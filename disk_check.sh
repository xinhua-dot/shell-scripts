#!/bin/bash

disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')

threshold=30

if [ $disk_usage -gt $threshold ];then
	echo "Waring:${disk_usage}%,over threshold${threshold}%"
	echo "time:$(date)"
else
	echo "normal:${disk_usage}%"
fi
