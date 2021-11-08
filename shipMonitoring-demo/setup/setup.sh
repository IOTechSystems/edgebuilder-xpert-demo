#!/bin/sh
set -x

# this script assumes that core services, export services, influxdb17, and grafana have been up and running.
# For docker deployment, these containers must share the same docker network.

sleep 3h

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

echo "Wait for 10 seconds for device services to be ready with newly added profiles"
sleep 10

# Add simulated devices into Metadata service through REST API
for device in devices/*
do
  execute_command_until_success 1 200 curl -s -o /dev/null -w "%{http_code}" -X POST http://$METADATA_HOST:48081/api/v1/device --data-binary "@$device"
done

# Check if Export-Client REST API is ready prior to adding registration
# The check should be limited to 20 times to avoid infinite loop
execute_command_until_success 20 "pong" curl -s http://"$EXPORT_HOST":48071/api/v1/ping

# Add simulated export registrations into Export-Client service through REST API
for r in registrations/*
do
  execute_command_until_success 1 200 curl -s -o /dev/null -w "%{http_code}" -X POST http://$EXPORT_HOST:48071/api/v1/registration --data-binary "@$r"
done

# Add datasource to Grafana through REST API
execute_command_until_success 1 200 curl -s -o /dev/null -w "%{http_code}" -X POST -H "Content-Type:application/json" http://admin:admin@$GRAFANA_HOST:3000/api/datasources -d '{"name":"InfluxDB","type":"influxdb","url":"http://'"$INFLUXDB_HOST"':8086","access":"proxy","basicAuth":false,"user":"admin","database":"edgex","password":"admin"}'

# Add dashboards to Grafana through REST API
for d in dashboards/*
do
  execute_command_until_success 1 200 curl -s -o /dev/null -w "%{http_code}" -X POST -H "Content-Type:application/json" http://admin:admin@$GRAFANA_HOST:3000/api/dashboards/db -d '{"dashboard":'"$(cat $d | tr -d '\t\n\r ')"'}'
done