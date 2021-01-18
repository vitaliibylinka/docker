#!/bin/ash

ip=192.168.0.3

echo starting client script ...

for value in 1 2 3 4 5 6
do
	echo "sending test$value to $ip:666"
	echo "test$value" | nc -w 0 $ip 666
done

echo end of client script.
