## Edge Builder and Edge Xpert Integration Examples

### Overview
This repository hosts various Edge Xpert examples that could be deployed by Edge Builder.

### List of Examples
Please see the README.md in each example for more details.

| <div style="width:250px">Example Name</div> | Description |
| ------------ | ----------- |
| [v1.8_simple-demo](./v1.8_simple-demo) | Demonstrates a simple integration example of Device-Virtual sending events to EdgeX Core-Data and an application service exporting events to MQTT broker. |
| [v1.8_shipMonitoring-demo](./v1.8_shipMonitoring-demo) | Demonstrates a ship monitoring example of Device-Modbus and Device-OPC-UA sending events to EdgeX Core-Data, and then exporting events to InfluxDB and AWS IoT Core. The Grafana dashboard is provided. |
| [v2.0_chemical-tank-demo](./v2.0_chemical-tank-demo) | Demonstrates a Modbus-based chemical tank producing temperature, pressure and level values, and an OPC-UA outlet valve with a setting to open and close the valve. Then exports events to InfluxDB, HiveMQ and Node-RED via EdgeX application services. |
| [v2.0_large-signals-demo](./v2.0_large-signals-demo) | Demonstrates a large signals example of Device-Modbus and Device-OPC-UA sending 2000 readings per second for each device, and then exporting events to InfluxDB and AWS IoT Core. The Grafana dashboard is provided. |