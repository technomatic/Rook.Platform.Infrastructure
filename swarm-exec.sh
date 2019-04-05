#!/bin/bash
# swarm-exec.sh
set -e

for ((i=1;i<=$#;i++)); do
    val=${!i}
    if [ ${val:0:1} != "-" ]; then
        service_id=$(docker ps -q -f "name=$val");
        if [[ $service_id  == "" ]]; then
            echo "Container $val not found!";
            exit 1;
        fi
        docker exec ${@:1:$i-1} $service_id ${@:$i+1:$#};
        exit 0;
    fi
done
echo "Usage: $0 [OPTIONS] SERVICE_NAME COMMAND [ARG...]";
exit 1;
