#!/bin/bash

docker="sudo docker"
local_mount="/home/workdir"

if [ $# -gt 0 ]; then
	if [ $1 == prune ]; then 
		$docker container prune -f
		$docker network prune -f
		$docker volume prune -f
		exit
	fi
else
	network=${1:-shared_bridge}
	volume=${2:-shared_volume}
fi

echo building "alpine:nc" image ...
$docker build --rm -t alpine:nc $(pwd)

if [ -z "$($docker network ls | egrep " ${network} ")" ]; then
	echo "creating \"$network\" network..."
	$docker network create $network
fi
printf "used network:\t\"$network\"\t$($docker network inspect ${network} | grep Gateway | sed 's/  //g' | sed 's/"//g' | sed 's/ /\t/g')\n"

if [ -z "$($docker volume ls | egrep " ${volume}$")" ]; then
	echo "creating \"$volume\" volume..."
	$docker volume create $volume
fi

Mountpoint=$($docker volume inspect ${volume} | grep Mountpoint | sed 's/  //g' | sed 's/"//g' | sed 's/ /\t/g')
printf "used volume:\t\"$volume\"\t${Mountpoint:0:-1}\n"

Mountpoint=$(echo $(printf "${Mountpoint:0:-1}" | cut -d$'\t' -f2))
chmod +x $(pwd)/server.sh $(pwd)/client.sh

echo "creating and starting \"server\" container..."
$docker run --rm -d \
	 --mount type=volume,source=$volume,destination="/$volume" \
	 -v "$(pwd):$local_mount:rw" \
	 --network $network\
	 --name server \
	 alpine:nc /bin/ash $local_mount/server.sh
	

IP=$($docker container inspect server | grep IPAddress | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
echo server IP: $IP
sudo sed -i -r "s/[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/${IP}/g" client.sh 
cat ${Mountpoint}/client.sh 
echo "creating and starting \"client\" container..."
$docker run --rm -it \
	 --mount type=volume,source=$volume,destination="/$volume" \
	 -v "$(pwd):$local_mount:rw" \
	 --network $network \
	 --name client \
	 alpine:nc /bin/ash $local_mount/client.sh

echo logs from server:	
$docker container logs server

$docker container kill server

