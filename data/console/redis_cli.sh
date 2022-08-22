#!/bin/bash 

function connect() {
        port=$1
        a=$(redis-cli -p $port ping) # Connects to the redis server at the address 127.0.0.1 with $port.
        if [ "$a" = "PONG" ]
        then
                echo 'redis-server is running'
        else
                echo 'Failed: redis-server is not started'
                exit 1
        fi
}

function exec_redis() {
        cmd=$1
        expec_res=$2
        res=$($cmd)
        if [ "$res" = "$expec_res" ]
        then
                echo "$cmd: $expec_res"
        else
                echo 'Failed: redis-cli command '"$cmd"' execution'
                exit 1
        fi
}

## ==== Prepare environment ================================================= ##
set -o pipefail
connect 6379
# Execute redis-cli commands  
exec_redis 'redis-cli set foo bar' 'OK'
exec_redis 'redis-cli get foo'  'bar'
exec_redis 'redis-cli pfselftest' 'OK'
exec_redis 'redis-cli flushdb' 'OK'
out=$(redis-cli -p 6379 get foo)
if [ "$out" = "" ] || [ $out = "(nil)" ]
then
        echo "redis-cli -p 6379 get foo: $out"
else
        echo 'Failed: redis-cli command 'redis-cli get foo' failed to execute'
        exit 1
fi

# Load a test db from the data directory
out=$(redis-cli -h localhost -p 6379 < ./movies.redis)
exec_redis 'redis-cli HMGET movie:343 title' 'Spider-Man'

# Connect to the new instance of redis-server with port 6380 and make 6380 instance a 
# replica of redis instance running on port 6379 and verify the result
connect 6380
exec_redis 'redis-cli -p 6380 replicaof 127.0.0.1 6379' 'OK'
sleep 10 

out=$(redis-cli info replication)

if [[ "$out" =~ "connected_slaves:1" ]]
then
        echo "redis-cli info replication on master"
else
        echo "Failed: redis-cli info replication on master, slave took longer than 10 seconds to show up"
        exit 1
fi
out=$(redis-cli -p 6380 info replication)

if [[ "$out" =~ "role:slave" ]]
then
        echo "Role:slave in redis-cli on replica"
else
        echo "Failed: redis-cli info replication on replica"
        exit 1 
fi
out=$(redis-cli -p 6380 HMGET "movie:343" title)
if [ "$out" = "Spider-Man" ]
then 
	echo "redis-cli replicaof done" 
else	
	echo "Failed: redis-cli replication on replica "
        exit 1
fi
