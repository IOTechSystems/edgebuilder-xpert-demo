#!/bin/sh
#set -x

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
      echo "[ERROR] max attempts reached"
      exit 1
    elif [ ${attempts} -ne 0 ]; then
      sleep 5s
    fi

    cmd_resp=$($cmd)
    cmd_status=$?
    attempts=$(($attempts+1)) 
    
    echo "[INFO] cmd_status: $cmd_status, cmd_resp: $cmd_resp, attempts: $attempts"

  done
  echo "[INFO] execute command successfully"
}

# Check if Metadata REST API is ready prior to adding device profiles/devices
# The check should be limited to 20 times to avoid infinite loop
echo "[INFO] Checking the Metadata Service is running, max retries=10..."
execute_command_until_success 10 200 curl -s -o /dev/null -w "%{http_code}" http://$METADATA_HOST:59881/api/v2/ping

# Add simulated device profiles into Metadata service through REST API
echo "[INFO] Uploading device profiles..."
for profile in profiles/*
do
  execute_command_until_success 1 201 curl -s -o /dev/null -w "%{http_code}" -X POST -F "file=@$profile" http://$METADATA_HOST:59881/api/v2/deviceprofile/uploadfile
done

echo "[INFO] Wait for 10 seconds for device services to be ready with newly added profiles"
sleep 10

# Add simulated devices into Metadata service through REST API
echo "[INFO] Onboarding devices..."
for device in devices/*
do
  execute_command_until_success 1 207 curl -s -o /dev/null -w "%{http_code}" -X POST http://$METADATA_HOST:59881/api/v2/device --data-binary "@$device"
done

echo "[INFO] Setting Node-RED flows logic..."
execute_command_until_success 1 204 curl -s -o /dev/null -w "%{http_code}" -X POST http://NODERED:1880/flows -H "Content-Type:application/json" --data-binary "@nodered/flows.json"


# Add datasource to Grafana through REST API
echo "[INFO] Configuring the Grafana InfluxDB datasource..."
execute_command_until_success 1 200 curl -s -o /dev/null -w "%{http_code}" -X POST -H "Content-Type:application/json" http://admin:admin@$GRAFANA_HOST:3000/api/datasources -d '{"name":"InfluxDB","type":"influxdb","url":"http://influxdb2:8086","access":"proxy","basicAuth":false,"jsonData":{"organization":"my-org","defaultBucket":"my-bucket","version":"Flux"},"secureJsonData":{"token":"custom-token"}}'

# Add dashboards to Grafana through REST API
echo "[INFO] Configuring the Grafana dashboard..."
for d in dashboards/*
do
  execute_command_until_success 1 200 curl -s -o /dev/null -w "%{http_code}" -X POST -H "Content-Type:application/json" http://admin:admin@$GRAFANA_HOST:3000/api/dashboards/db -d '{"dashboard":'"$(cat $d | tr -d '\t\n\r ')"'}'
done
