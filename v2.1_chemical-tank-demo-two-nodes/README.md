# Edge Xpert Chemical Tank Demo with Edge Builder
## Overview

This demo performs the following egde tasks:
* Collecting and ingesting data from two simulated data sources (in this case Modbus and OPC-UA)
* Delivering the data to an InfluxDB time-series database
* Visualization of the data via a user-configured Grafana dashboard
* Edge decision making, control and actuation via Node-RED
* Streaming data northbound to a Cloud/IT system (in this case represented by HiveMQ)

This demo provides the following Edge Builder configs to deploy and config Edge Xpert services on the remote node(s):
* a node config: **node-config.json**
* an app definition: **app-def.json**
* an app config: **app-config.json**
* an app file config: **app-config-file.json**
* two docker compose files: **docker-compose.yml**

The docker-compose file contains various Edge Xpert services, including **device-modbus** and **device-opc-ua** that collect and ingest the simulated data, and the events are sent through internally MQTT broker to EdgeX app services directly, and then the app services publish these events to InfluxDB, HiveMQ and Node-RED.

To set up the device-modbus and device-opc-ua services with simulated devices, this tutorial will use **support-provision** service to add device profiles and devices into EdgeX 
Core-Metadata service for provisioning. The **support-provision** service will also add InfluxDB datasource, a default dashboard for Grafana, and a Node-RED flow. The **support-provision** service is part of docker-compose file, and it will be 
automatically started up when being deployed by Edge Builder.    

## Preparation
* Install [Edge Builder 1.3.0](https://docs.iotechsys.com/edge-builder13/installation/installation.html) and start running:   

  To obtain the Edge Builder license, please contact [IOTech Support](https://www.iotechsys.com/contact/contact-us/).
  
  * Edge Builder Server on the server (machine A)
  * Edge Builder CLI on the server (machine A)
  * Edge Builder Node on the node1 (machine B)
  * Edge Builder Node on the node2 (machine C)
  
  Run the following commands to start Edge Builder and add license on the server
  ```shell
  # Run on server (machine A)
  # Start Edge Builder Server: 
  edgebuilder-server up -a <server-ip-address>
  e.g. edgebuilder-server up -a 192.168.56.10
  
  # Log in to Edge Builder with a default admin user account: username/password = iotech/EdgeBuilder123
  edgebuilder-cli user login -u iotech -p EdgeBuilder123 -c "http://<server-ip-address>:8085"
  e.g. edgebuilder-cli user login -u iotech -p EdgeBuilder123 -c "http://192.168.56.10:8085"
  
  # Add valid license: 
  edgebuilder-cli license add -l <license-name> --file <path-to-edge-builder-license>
  e.g. edgebuilder-cli license add -l DemoLicense --file EdgeBuilder_IoTech_Evaluation.lic
  ```

* Start [ModbusPal](https://sourceforge.net/projects/modbuspal/) on the node#1
  1. Execute command `sudo java -jar ModbusPal.jar` (JDK and librxtx-java required)
  2. Load the simulator config **ModbusSimulator.xmpp**
  3. Start all -> Run
  
* Start [Prosys OPC UA Simulation Server](https://downloads.prosysopc.com/opc-ua-simulation-server-downloads.php) on the node#1
  1. Execute Command `./prosys-opc-ua-simulation-server/UaSimulationServer `
  2. Verify that the attribute exists: Switch to expert mode -> Address Space -> Objects -> Static Data -> Static Variables -> UInt16 (ns=5, s=UInt16)
  

## The support-provision service
This main purpose of **support-provision** is to set up the EdgeX configs, including:
* add device profiles into Core-Metadata
* add devices into Core-Metadata
* add datasource and dashboard into Grafana 
* add flows into Node-RED

Examine the **node1** folder of this sample, there are various files and folders prepared for node1 deployment:
* **app-service** - folder containing three app-services configuration
* **docker-compose.yml** - the compose file to deploy edgexpert services for Edge Xpert Chemical Tank Demo on node1 
* **ModbusSimulation.xmpp** - the project file used to simulate modbus devices via ModbusPalm for Edge Xpert Chemical Tank Demo on node1
* **provision-data/configuration.toml** - the configuration file used by **support-provision** service on node2
* **provision-data/devices** - folder containing payload files for adding devices **(must be a json file ending with ".json", e.g. device-ChemicalTank.json)**: *Chemical-Tank*, and *Outlet-Valve*
* **provision-data/profiles** - folder containing payload files for adding device profiles **(must be a yaml file ending with ".yml", e.g. ChemicalTank-profile.yml)**: *Chemical-Tank*, and *Outlet-Valve*
* **provision-data/nodered** - folder containing payload files for adding Node-RED flows **(must be json files ending with ".json", e.g. flows.json)**

Examine the **node2** folder of this sample, there are various files and folders prepared for node2 deployment:
* **docker-compose.yml** - the compose file to deploy grafana and influxdb for Edge Xpert Chemical Tank Demo on node2
* **provision-data/configuration.toml** - the configuration file used by **support-provision** service on node2
* **provision-data/grafana/datasources** - folder containing payload files for adding Grafana datasource **(must be json files ending with ".json", e.g. datasources.json)**
* **provision-data/grafana/dashboards** - folder containing payload files for adding Grafana dashboards **(must be json files ending with ".json", e.g. dashboards.json)**

## Run the Demo
> **⚠ Must have already logged in Edge Builder and added the license.**

1. Put the Edge Xpert license file in this sample folder, and copy the folder into the server (machine A)
2. Add node configuration

    The **node-config.json** file defines the node name, node ip addresses(192.168.56.11/12), node username/password for SSH, and the master ip(192.168.56.10). In this demo, the node configuration file defines two nodes: node1 and node2.
    
    ```json
    {
      "NodeConfig": [
        {
          "name": "node1",
          "description": "virtual node 1",
          "nodeaddress": "192.168.56.11",
          "username" : "vagrant",
          "password" : "vagrant",
          "serveraddress": "192.168.56.10"
        },
        {
          "name": "node2",
          "description": "virtual node 2",
          "nodeaddress": "192.168.56.12",
          "username" : "vagrant",
          "password" : "vagrant",
          "serveraddress": "192.168.56.10"
        }
      ]
    }
    ```
   
    Run the command to add node:
    ```shell
    edgebuilder-cli node add -f <path-to-node-config.json>
    e.g. edgebuilder-cli node add -f node-config.json
    ```
    Check the status of the node if it is "Up":
    ```shell
    edgebuilder-cli node view --all
    ```

3. Add app definition

    The **app-def.json** file contains two app definitions: one for node1 and the other one for node2, and the path of their corresponding docker-compose files. 
    ```json
    {
      "AppDefinitionConfig": [
        {
          "Name": "chemical-tank-demo-node1",
          "Description": "Chemical Tank Control Demo Deployment for Node1",
          "FilePath": "/vagrant/v2.1_chemical-tank-demo-two-nodes/node1/docker-compose.yml",
          "Type": "docker-compose"
        },
        {
          "Name": "chemical-tank-demo-node2",
          "Description": "Chemical Tank Control Demo Deployment for Node2",
          "FilePath": "/vagrant/v2.1_chemical-tank-demo-two-nodes/node2/docker-compose.yml",
          "Type": "docker-compose"
        }
      ]
    }
    ```
   
    Run the command to add appDefinition:
    ```shell
    edgebuilder-cli appDefinition add -f <path-to-app-def.json>
    e.g. edgebuilder-cli appDefinition add -f app-def.json
    ```
   > **⚠ If you update the compose file, please remove the appDefinition and recreate it.**

4. Add app config and config files
   
    The **app-config-file.json** defines the paths to app config files.
   > ⚠ Replace \<edge-xpert-license> with the Edge Xpert License file name
    ```json
    {
      "AppConfigFileConfig": [
        {
          "Name": "licnese-data-file",
          "Description": "a file to configure license",
          "FileName": "license.lic",
          "FilePath": "/vagrant/v2.1_chemical-tank-demo-two-nodes/EdgeXpert_EXP_Evaluation.lic"
        },
        {
          "Name": "node1-asc-config",
          "Description": "app service config files",
          "FileName": "asc-config.tar",
          "FilePath": "/vagrant/v2.1_chemical-tank-demo-two-nodes/node1/asc-config.tar"
        },
        {
          "Name": "node1-provision-data",
          "Description": "files to provision device profiles, devices, and nodered flow on node1",
          "FileName": "node1-provision-data.tar",
          "FilePath": "/vagrant/v2.1_chemical-tank-demo-two-nodes/node1/node1-provision-data.tar"
        },
        {
          "Name": "node2-provision-data",
          "Description": "files to provision grafana datasources and dashboards on node2",
          "FileName": "node2-provision-data.tar",
          "FilePath": "/vagrant/v2.1_chemical-tank-demo-two-nodes/node2/node2-provision-data.tar"
        }
      ]
    }
    ```
   
    The **app-config.json** file defines the mappings of the app config files to volumes used in the compose file on the node(s).
    > ⚠ replace the \<app-def-id-node1> and \<app-def-id-node2> with the app definition id as generated on step 3
    ```json
    {
      "AppConfig": [
        {
          "Name": "node1-config",
          "Description": "config to inject license file, app service configuration, and provision data",
          "AppDefinitionID": "<app-def-id-node1>",
          "ConfigMappings": [
            {
              "Destination": "license-data",
              "AppConfigFiles": [
                "licnese-data-file"
              ]
            },
            {
              "Destination": "asc-config",
              "AppConfigFiles": [
                "node1-asc-config"
              ]
            },
            {
              "Destination": "provision-data",
              "AppConfigFiles": [
                "node1-provision-data"
              ]
            }
          ]
        },
        {
          "Name": "node2-config",
          "Description": "config to add datasources and dashboards into the grafana",
          "AppDefinitionID": "<app-def-id-node2>",
          "ConfigMappings": [
            {
              "Destination": "provision-data",
              "AppConfigFiles": [
                "node2-provision-data"
              ]
            }
          ]
        }
      ]
    }
    ```
    Run the command to add appDefinition:
    ```shell
    # add app config files
    edgebuilder-cli appConfigFile add -f <path-to-app-config-file.json>
    e.g. edgebuilder-cli appConfigFile add -f app-config-file.json
   
    # add app config
    edgebuilder-cli appConfig add -f <path-to-app-config.json>
    e.g. edgebuilder-cli appConfig add -f app-config.json
    ```

   > **⚠ If you update the app-config-file.json, please remove the appConfigFile and recreate it (and maybe appConfig as well).**

   > **⚠ If you update the app-config.json or recreate the app, please remove the appConfig and recreate it.**

5. Create and start an app instance on the node

    Run the command to create app:
    ```shell
    # edgebuilder-cli app create -d <app-def-name> -n <node-name> -c <app-config-name>
    # for node1, run command below:
    edgebuilder-cli app create -d chemical-tank-demo-node1 -n node1 -c node1-config
    # for node2, run command below:
    edgebuilder-cli app create -d chemical-tank-demo-node2 -n node2 -c node2-config
    ```
    Run the command to start app:
    ```shell
    edgebuilder-cli app start -a <app-name or app-id>
    ```
    Check the status of the app, it will take some time to become "Running":
    ```shell
    edgebuilder-cli app view --all
    ```

6. Open Browser to Grafana, HiveMQ Websockets Client and Node-RED to see the results.
   
    Wait for the service-setup container to finish the setup (~ 1 min).
    * Grafana: `http://192.168.56.12:3000/d/_6OKnhHnk/chemicaltankdashboard?orgId=1&refresh=5s`
    * HiveMQ Websockets Client: `http://www.hivemq.com/demos/websocket-client/`, subscribe topic "Chemical-Tank"
    * Node-Red: the Outlet Valve is opened (set to 1) on Grafana when any of the Modbus values go above 80 (per the rule as defined in the Node-RED flows.json)
   

### Remove app, appConfig, appConfigFile, appDefinition and node

* Run the command to remove app:
  ```shell
  edgebuilder-cli app rm -a <app-name or app-id>
   ```
* Run the command to remove app config:
  > **⚠ Must remove the associated apps before removing an app config.**

  ```shell
  # edgebuilder-cli appConfig rm -c <app-config-name or app-config-id>
  e.g. edgebuilder-cli appConfig rm -c node1-config
  ```
* Run the command to remove app config file:
  > **⚠ Must remove the associated appConfigs before removing an app config file.**

  ```shell
  # remove all appConfigFile or use "-d" to remove a specified appConfigFile
  edgebuilder-cli appConfigFile rm --all 
  ```
* Run the command to remove appDefinition:
  > **⚠ Must remove the associated apps before removing an app definition.**
  
  ```shell
  edgebuilder-cli appDefinition rm -d <app-def-name or app-def-id>
  e.g. edgebuilder-cli appDefinition rm -d chemical-tank-demo-node1
  ```
* Run the command to remove node:
  ```shell
  edgebuilder-cli node rm -n <node name>
  e.g. edgebuilder-cli node rm -n node1
  ```
* Run the command to bring down server:
  ```shell
  edgebuilder-server down
  ```
