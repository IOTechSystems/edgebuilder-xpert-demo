#!/bin/sh
set -x

# this script assumes that core services, and device-virtual have been up and running.
# For docker deployment, these containers must share the same docker network.

execute_command_until_success(){
  max_attempts="$1"
  shift
  expect_resp="$1"
  shift
  cmd="$@"
  attempts=0
  cmd_status=1
  cmd_resp=""
  until [ $cmd_status -eq 0 ] && [ "$cmd_resp" = "$expect_resp" ]
  do
    echo "cmd_status: $cmd_status"
    echo "cmd_resp: $cmd_resp"
    echo "max_attempts: $max_attempts"

    if [ ${attempts} -eq ${max_attempts} ];then
      echo "max attempts reached"
      exit 1
    fi

    sleep 5
    cmd_resp=$($cmd)
    cmd_status=$?
    attempts=$(($attempts+1))
  done
}

# Check if Metadata REST API is ready prior to adding device profiles/devices
# The check should be limited to 20 times to avoid infinite loop
execute_command_until_success 20 "pong" curl -s http://"$METADATA_HOST":48081/api/v1/ping

# Add simulated device profiles into Metadata service through REST API
for profile in profiles/*
do
  execute_command_until_success 1 200 curl -s -o /dev/null -w "%{http_code}" -X POST -F "file=@$profile" http://$METADATA_HOST:48081/api/v1/deviceprofile/uploadfile
done

echo "Wait for 20 seconds for device services to be ready with newly added profiles"
sleep 20

# Add simulated devices into Metadata service through REST API
for device in devices/*
do
  execute_command_until_success 1 200 curl -s -o /dev/null -w "%{http_code}" -X POST http://$METADATA_HOST:48081/api/v1/device --data-binary "@$device"
done
