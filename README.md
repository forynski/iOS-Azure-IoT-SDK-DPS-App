<img alt="Static Badge" src="https://img.shields.io/badge/build%20and%20deploy-passing-brightgreen">

# How to use Swift to interact with Azure SDK for C?
This example utilizes the [Azure SDK for C](https://github.com/Azure/azure-sdk-for-c) encapsulated within a Swift library available [here](https://github.com/Azure-Samples/azure-sdk-for-c-swift). The Swift library enables users to select their preferred MQTT library and provides APIs that simplify the implementation of Azure IoT concepts.

## Embedded C SDK (Microsoft library):
      D2C messages
      C2D messages
      Device Twin
      Direct Methods
      IoT Plug & Play
      Device Provisioning

## 3rd Party:
      Swift MQTT
      Swift NIO-SSL
      Swift NIO
  
## Key Capabilities:
      IoT Hub client
      DPS client (Device Provisioning Service)
      X.509 certificate authentication
      Telemetry messages (D2C - Device to Cloud)
      Commands (C2D - D2C)

## Requirements:
      Swift development environment installed
      Azure Account
      Device previously created in your IoT Hub or DPS Enrollment.

## Known Issues and Limitations:
      WebSocket Support: Swift MQTT, used in this sample, lacks support for WebSockets. Consider CocoaMQTT as an alternative, leveraging StarScream. MQTT-nio could also serve as an alternative.
      This sample utilizes Swift NIO for network operations and Swift NIO-SSL for TLS, both supported by Apple. However, it's important to note that the Swift MQTT client is a third-party library and is neither created nor supported by Apple.
      SAS Token Utilization: The sample does not implement the use of SAS Tokens.
      Reconnection and Retries: The sample does not include implementation for reconnection or retries. Client applications should handle these functionalities.

## Support:
The Swift sample is an open-source solution and is not officially supported by Microsoft. For any bugs or issues with the codebase, please log them in the repository's issue tracker.

## Architecture:
The diagram depicted below illustrates the Swift sample relying on the Embedded C SDK, furnishing libraries for accessing various Azure IoT functionalities.

This SDK adopts the BYO (bring your own) network stack approach, granting device builders the flexibility to select the MQTT client, TLS, and TCP stack that best suits their target platform.

In this particular instance, the sample utilizes Swift MQTT, Swift NIO-SSL, and Swift NIO.

![Architecture](https://github.com/forynski/iOS-Azure-IoT-SDK-DPS-App/blob/main/resources/architecture.png)
