#!/bin/bash

while true;do
    curl -s http://127.0.0.1 > /dev/null
    if [ $? -eq 0 ];then
        echo "%$(date) - Web service normal"
    else
	echo "$(date) - Web servicr Unnomal..." >&2
    fi

    sleep 10
done

