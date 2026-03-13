#!/bin/bash
# 这是一个无限循环，每隔5秒记录一次当前时间
while true; do
    echo "我还活着！当前时间是：$(date)"
    sleep 5
done
