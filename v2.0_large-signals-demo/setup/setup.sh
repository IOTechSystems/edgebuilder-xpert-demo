#!/bin/sh
set -x

# this script assumes that core services, influxdb, and grafana have been up and running.
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

    if [ ${attempts} -eq ${max_attempts} ];then
      echo "max attempts reached"
      exit 1
    elif [ ${attempts} -ne 0 ]; then
      sleep 5s
    fi

    cmd_resp=$($cmd)
    cmd_status=$?
    attempts=$(($attempts+1)) 
    
    echo "cmd_status: $cmd_status"
    echo "cmd_resp: $cmd_resp"
    echo "attempts: $attempts"  

  done
}

# Check if Metadata REST API is ready prior to adding device profiles/devices
# The check should be limited to 20 times to avoid infinite loop
execute_command_until_success 20 200 curl -s -o /dev/null -w "%{http_code}" http://$METADATA_HOST:59881/api/v2/ping

# Add simulated device profiles into Metadata service through REST API
for profile in profiles/*
do
  execute_command_until_success 1 201 curl -s -o /dev/null -w "%{http_code}" -X POST -F "file=@$profile" http://$METADATA_HOST:59881/api/v2/deviceprofile/uploadfile
done

echo "Wait for 10 seconds for device services to be ready with newly added profiles"
sleep 10

# Add simulated devices into Metadata service through REST API
for device in devices/*
do
  execute_command_until_success 1 207 curl -s -o /dev/null -w "%{http_code}" -X POST http://$METADATA_HOST:59881/api/v2/device --data-binary "@$device"
done

# Add datasource to Grafana through REST API
execute_command_until_success 1 200 curl -s -o /dev/null -w "%{http_code}" -X POST -H "Content-Type:application/json" http://admin:admin@$GRAFANA_HOST:3000/api/datasources -d '{"name":"InfluxDB","type":"influxdb","url":"http://influxdb2:8086","access":"proxy","basicAuth":false,"jsonData":{"organization":"my-org","defaultBucket":"my-bucket","version":"Flux"},"secureJsonData":{"token":"token"}}'


# Add dashboards to Grafana through REST API
for d in dashboards/*
do
  execute_command_until_success 1 200 curl -s -o /dev/null -w "%{http_code}" -X POST -H "Content-Type:application/json" http://admin:admin@$GRAFANA_HOST:3000/api/dashboards/db --data-binary "@$d"
done
