# A simple demo tutorial to set up Edge Xpert service through Edge Builder
## Overview
This simple demo provides a pair of appDefinition file **app-def-config.json** and corresponding docker-compose file **docker-compose.yml** as an 
example that could be deployed by Edge Builder.

The docker-compose file contains various Edge Xpert services, including a [Virtual Device Service](https://docs.iotechsys.com/Content/UserGuide/DeviceServices/CH-DS-Virtual.htm) 
will various simulated devices that will periodically send events to EdgeX Core-Data service for persistence, and an 
EdgeX application service will subscribe for these events and then publishes these events to external 
[HiveMQ MQTT broker](http://www.mqtt-dashboard.com/).

To set up the virtual device service with simulated devices, including a loadcell device, a temperature device, and a 
powermeter device, this tutorial will build a special container to add device profiles and devices into EdgeX 
Core-Metadata service for provisioning.  This special container--**metadata-setup**--is part of docker-compose file, and it will be 
automatically started up when being deployed by Edge Builder.    
## Prerequisite
1. This example requires basic knowledge about Edge Xpert, and you could refer to [Edge Xpert documentaiton](https://docs.iotechsys.com/Content/UserGuide/Edge%20Xpert%20User%20Guide.htm) 
for reference.
2. Before running this simple demo, you must have Edge Builder environment up and running:
    * Edge Builder Server
    * Edge Builder Node
    * Edge Builder CLI
3. Copy this sample into your local environment

## Prepare metadata-setup container
This main purpose of this tutorial is to demonstrate a special purpose container, **metadata-setup**, to set up device profiles and three 
simulated devices--*LoadCell-Device*, *Powermeter-Device*, and *Temperature-Device*--into EdgeX Core-Metadata service.

Examine the **setup** folder of this sample, there are various files and folders:
* **Dockerfile** - the Dockerfile used to build metadata-setup docker image
* **setup.sh** - the entrypoint script inside the metadata-setup container to add profiles and devices into EdgeX Core-Metadata service
* **build.sh** - the shell script to build the docker image for metadata-setup container
* **devices** - folder containing payload files for adding simulated devices: *LoadCell-Device*, *Powermeter-Device*, and *Temperature-Device*
* **profiles** - folder containing payload files for adding device profiles

### 1. Examine the content of Dockerfile
**Dockerfile** is used to build the docker image for metadata-setup container.  The content of **Dockerfile** is quite simple: use alpine 3.12 as base image, install *curl* utility, 
set *METADATA_HOST* environment variable, copy payload files for adding device profiles from **profiles** folder, copy payload files for adding devices from **devices** folder, 
copy and set **setup.sh** as the entrypoint script:
```dockerfile
FROM alpine:3.12

LABEL maintainer="iotech <support@iotechsys.com>"

# install necessary tools
RUN apk add --update --no-cache curl

ENV BASE_DIR=/metadata-setup METADATA_HOST=core-metadata

WORKDIR $BASE_DIR

# Copy device profiles into profiles under working dir
COPY ./profiles/profile.*.yaml profiles/
# Copy devices creation payload into devices under working dir
COPY ./devices/device-*.json devices/
# Copy setup script into working dir
COPY setup.sh .

RUN chmod 755 ./setup.sh

ENTRYPOINT ["/metadata-setup/setup.sh"]
```
### 2. Examine the content of entrypoint script
The entrypoint script, **setup.sh**, hosts the necessary commands to set up the metadata service.  In this simple example, **setup.sh** will issue several REST calls to metadata service 
to add new device profiles and new devices:
```shell
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
```
As most of Edge Xpert services provide REST API for manipulation, users could refer to **setup.sh** as a sample and then revise the script as needed to satisfy specific setup requirements.
Please refer to [API documentation](https://docs.iotechsys.com/Content/UserGuide/API/CH-API-Overview.htm) for more details about Edge Xpert REST API.  

### 3. Build the docker image for metadata-setup container
Use command below to build the docker image for **metadata-setup**.  Note that specifying *true* for the first argument to push the
docker image to [Docker Hub](https://hub.docker.com/).  This docker image on Docker Hub must be accessible to your target Edge Builder node, so that 
metadata-setup container could be properly started up on your target node to setup EdgeX Core-Metadata service.  The second argument, with default 
value *iotechsys/edgexpert-demo-lua*, specifies the name of metadata-setup docker image.
```shell
cd setup
./build.sh true <image name for metadata-setup container>
```

### 4. Update the compose file
Once the metadata-setup docker image is successfully built and pushed to Docker Hub, remember to update **docker-compose.yml** 
file with the correct image name, so that the target Edge Builder node can pull the image later:
```yaml
metadata-setup:
    image: <image name for metadata-setup container>:metadata-setup-x86_64
```
## Run this simple demo
Once the metadata-setup docker image is ready, user can deploy the simple demo through Edge Builder.
### 1. Examine the content of app-def-config.json
This simple demo uses **app-def-config.json** file to define the app definition for Edge Builder: 
```json
{
  "AppDefinitionConfig": [
    {
      "Name": "simple-demo",
      "Description": "A simple demo to deploy virtual device and an app service to export events to HiveMQ mqtt broker",
      "ComposeFile": "/vagrant/simple-demo/docker-compose.yml"
    }
  ]
}
```
Make sure you update *ComposeFile* with the proper file location of **docker-compose.yml** accessible to *edgebuilder-cli* utility.
### 2. Examine the content of docker-compose.yml
The **docker-compose.yml** defines all the services required to run this simple demo, including redis, device-virtual, core services, an application service, and metadata-setup service:
```yaml
version: "3.7"

networks:
  edgex-network:
    driver: bridge

volumes:
  db-data:
  nodered-data:
  license-data:

# all common shared environment variables defined here:
x-common-env-variables: &common-variables
  EDGEX_SECURITY_SECRET_STORE: "false"
  Clients_Data_Host: edgex-core-data
  Clients_CoreData_Host: edgex-core-data
  Clients_Metadata_Host: edgex-core-metadata
  Clients_Command_Host: edgex-core-command
  Clients_VirtualDevice_Host: device-virtual
  Databases_Primary_Host: edgex-redis
  # license
  EDGEXPERT_LICENSE_PATH: /edgexpert/licenses/

services:

  #################################################################
  # Database Services
  #################################################################

  redis:
    image: redis:6.2.3
    container_name: redis
    hostname: redis
    networks:
      edgex-network:
        aliases:
          - edgex-redis
    read_only: true
    security_opt:
      - no-new-privileges:true
    volumes:
      - db-data:/data:z
    logging:
      driver: "json-file"
      options:
        max-size: "10mb"
        max-file: "20"

  #################################################################
  # Core Services
  #################################################################

  core-metadata:
    image: iotechsys/edgexpert-core-metadata:1.8
    container_name: core-metadata
    hostname: core-metadata
    command: "--confdir=/res"
    ports:
      - "48081:48081"
    networks:
      edgex-network:
        aliases:
          - edgex-core-metadata
    read_only: true
    security_opt:
      - no-new-privileges:true
    environment:
      <<: *common-variables
      Service_Host: core-metadata
    volumes:
      - license-data:/edgexpert/licenses/:ro
    logging:
      driver: "json-file"
      options:
        max-size: "10mb"
        max-file: "20"
    depends_on:
      - edgexpert-license
      - redis

  core-data:
    image: iotechsys/edgexpert-core-data:1.8
    container_name: core-data
    hostname: core-data
    command: "--confdir=/res"
    ports:
      - "48080:48080"
      - "5563:5563"
    networks:
      edgex-network:
        aliases:
          - edgex-core-data
    read_only: true
    security_opt:
      - no-new-privileges:true
    environment:
      <<: *common-variables
      Service_Host: core-data
    volumes:
      - license-data:/edgexpert/licenses/:ro
    logging:
      driver: "json-file"
      options:
        max-size: "10mb"
        max-file: "20"
    depends_on:
      - edgexpert-license
      - redis
      - core-metadata

  core-command:
    image: iotechsys/edgexpert-core-command:1.8
    container_name: core-command
    hostname: core-command
    command: "--confdir=/res"
    ports:
      - "48082:48082"
    networks:
      edgex-network:
        aliases:
          - edgex-core-command
    read_only: true
    security_opt:
      - no-new-privileges:true
    environment:
      <<: *common-variables
      Service_Host: core-command
    volumes:
      - license-data:/edgexpert/licenses/:ro
    logging:
      driver: "json-file"
      options:
        max-size: "10mb"
        max-file: "20"
    depends_on:
      - edgexpert-license
      - redis
      - core-metadata

  #################################################################
  # Device Services
  #################################################################

  device-virtual:
    image: iotechsys/edgexpert-device-virtual:1.8
    container_name: device-virtual
    hostname: device-virtual
    command: "--confdir=/res"
    ports:
      - "49990:49990"
    networks:
      edgex-network:
        aliases:
          - device-virtual
    read_only: true
    security_opt:
      - no-new-privileges:true
    environment:
      <<: *common-variables
      Service_Host: device-virtual
    logging:
      driver: "json-file"
      options:
        max-size: "10mb"
        max-file: "20"
    depends_on:
      - edgexpert-license
      - core-data
      - core-metadata

  #################################################################
  # App Services
  #################################################################

  app-service-mqtt-export:
    image: iotechsys/edgexpert-app-configurable:1.8
    container_name: app-service-mqtt-export
    hostname: app-service-mqtt-export
    networks:
      edgex-network:
        aliases:
          - app-service-mqtt-export
    read_only: true
    security_opt:
      - no-new-privileges:true
    environment:
      <<: *common-variables
      Service_Host: app-service-mqtt-export
      Database_Host: edgex-redis
      MessageBus_SubscribeHost_Host: edgex-core-data
      # pipeline overrides
      WRITABLE_PIPELINE_FUNCTIONS_MQTTSECRETSEND_PARAMETERS_BROKERADDRESS: tcp://broker.hivemq.com:1883
      WRITABLE_PIPELINE_FUNCTIONS_MQTTSECRETSEND_PARAMETERS_TOPIC: iotech_topic
      WRITABLE_PIPELINE_FUNCTIONS_MQTTSECRETSEND_PARAMETERS_CLIENTID: iotech
    command: "--confdir=/res --profile=mqtt-export"
    volumes:
      - license-data:/edgexpert/licenses/:ro
    logging:
      driver: "json-file"
      options:
        max-size: "10mb"
        max-file: "20"
    depends_on:
      - edgexpert-license
      - core-data

  #################################################################
  # EdgeXpert License
  #################################################################

  edgexpert-license:
    image: iotechsys/sys-mgmt-demo-license-prov:nova-demo
    container_name: edgexpert-license
    hostname: edgexpert-license
    read_only: true
    security_opt:
      - no-new-privileges:true
    environment:
      <<: *common-variables
    volumes:
      - license-data:/lic:ro
    logging:
      driver: "json-file"
      options:
        max-size: "10mb"
        max-file: "20"

  #################################################################
  # Metadata Setup
  #################################################################

  metadata-setup:
    image: iotechsys/edgexpert-demo-lua:metadata-setup-x86_64
    container_name: metadata-setup
    hostname: metadata-setup
    read_only: true
    security_opt:
      - no-new-privileges:true
    networks:
      edgex-network:
        aliases:
          - metadata-setup
    logging:
      driver: "json-file"
      options:
        max-size: "10mb"
        max-file: "20"
    depends_on:
      - core-metadata

```
### 3. Create app definition for the simple demo
Please use edgebuilder-cli command below to create an app definition as defined by **app-def-config** file:
```shell
edgebuilder-cli appDefinition add -f app-def-config.json
```
### 4. Deploy the simple-demo app on the target Edge Builder node
Please use edgebuilder-cli command below to deploy the app *simple-demo* to the target node:
```shell
edgebuilder-cli app create -d simple-demo -n <name of target node>
```
### 5. Start the simple-demo app on the target Edge Builder node
Please use edgebuilder-cli command below to start the app on the target node:
```shell
edgebuilder-cli app start -a <app id>
```
### 6. Verify events exported to HiveMQ
Once this simple demo app is up and running, a virtual device service with simulated devices will periodically send events to EdgeX Core-Data service, and an application service will 
export these events to a public MQTT broker: [HiveMQ MQTT broker](http://www.mqtt-dashboard.com/). To verify if EdgeX events are being successfully 
exported, you could either use *mosquitto_sub* command to subscribe for messages from HiveMQ MQTT broker on *iotech_topic* topic:
```shell
mosquitto_sub -h broker.hivemq.com -d -v -t iotech_topic
```
or use [HiveMQ Websocket Client](http://www.hivemq.com/demos/websocket-client/) online tool to subscribe for messages with *iotech_topic* topic.

If everything works fine, user shall expect to see new EdgeX events flows in periodically, and note that some of these events shall come from three simulated devices--*LoadCell-Device*, *Powermeter-Device*, and *Temperature-Device*--set up by **metadata-setup** container:
```shell
Client mosq-z5nNReb9pVlwK7NI4g received PUBLISH (d0, q0, r0, m0, 'iotech_topic', ... (362 bytes))
iotech_topic {"id":"370d528f-7148-4544-bc7a-ee281a93f05f","device":"LoadCell-Device","created":1622462358533,"origin":1622462358532334382,"readings":[{"id":"23e51991-938d-4465-b0dd-9df346a90dba","origin":1622462358532023810,"device":"LoadCell-Device","name":"ShelfWeight","value":"6.108322e+02","valueType":"Float32","floatEncoding":"eNotation"}],"commandName":"ShelfWeight"}
.
.
.
Client mosq-z5nNReb9pVlwK7NI4g received PUBLISH (d0, q0, r0, m0, 'iotech_topic', ... (328 bytes))
iotech_topic {"id":"53318f1f-1e8d-449c-8af6-f39aa1e22763","device":"Powermeter-Device","created":1622462363538,"origin":1622462363536622830,"readings":[{"id":"843013cf-8294-4b30-89ef-a5757c3ab0ef","origin":1622462363536250366,"device":"Powermeter-Device","name":"FridgePower","value":"341","valueType":"Uint16"}],"commandName":"FridgePower"}
.
.
.
Client mosq-z5nNReb9pVlwK7NI4g received PUBLISH (d0, q0, r0, m0, 'iotech_topic', ... (366 bytes))
iotech_topic {"id":"c1665144-624b-43c2-85d2-de1325844252","device":"Temperature-Device","created":1622462368569,"origin":1622462368567101268,"readings":[{"id":"813c12d8-2850-4983-b920-e05e177e073e","origin":1622462368566652602,"device":"Temperature-Device","name":"FridgeTemp","value":"1.003703e+01","valueType":"Float32","floatEncoding":"eNotation"}],"commandName":"FridgeTemp"}
Client mosq-z5nNReb9pVlwK7NI4g received PUBLISH (d0, q0, r0, m0, 'iotech_topic', ... (364 bytes))
iotech_topic {"id":"7d8affc5-c066-481b-85db-52be412c59c9","device":"Temperature-Device","created":1622462368569,"origin":1622462368565848561,"readings":[{"id":"57a2ab60-aa1a-4acf-968e-a7ba8044c53d","origin":1622462368564540533,"device":"Temperature-Device","name":"AisleTemp","value":"2.901214e+01","valueType":"Float32","floatEncoding":"eNotation"}],"commandName":"AisleTemp"}
```