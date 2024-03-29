//
//  DemoIoTClient.swift
//  AzureIoTSwiftSample
//
//  Handling MQTT communication events and messages
//

import Foundation
import MQTT
import NIOSSL
import CAzureSDKForCSwift
import CoreMotion

public class DemoProvisioningClient: MQTTClientDelegate {
    
    public var isProvisioningConnected: Bool = false;
    public var isDeviceProvisioned: Bool = false;
    public var gOperationID: String = ""
    
    /// Azure IoT Client
    private var AzProvClient: AzureIoTDeviceProvisioningClient! = nil
    
    /// MQTT Client
    private var mqttClient: MQTTClient! = nil
    
    public var assignedHub: String! = nil
    public var assignedDeviceID: String! = nil
    
    public var delegateDispatchQueue: DispatchQueue {
        queue
    }

    public init(idScope: String, registrationID: String)
    {
        AzProvClient = AzureIoTDeviceProvisioningClient(idScope: idScope, registrationID: registrationID)

        let clientCert: [UInt8] = Array(myCert.utf8)
        let keyCert: [UInt8] = Array(myCertKey.utf8)
        
        var tlsConfiguration = TLSConfiguration.makeClientConfiguration()
        tlsConfiguration.minimumTLSVersion = .tlsv11
        tlsConfiguration.maximumTLSVersion = .tlsv12
        tlsConfiguration.certificateVerification = .fullVerification
        tlsConfiguration.certificateChain = try! NIOSSLCertificate.fromPEMBytes(clientCert).map { .certificate($0) }
        tlsConfiguration.privateKey = try! NIOSSLPrivateKeySource.privateKey(NIOSSLPrivateKey(bytes: keyCert, format: .pem))

        print("Client ID: \(AzProvClient.GetDeviceProvisioningClientID())")
        print("Username: \(AzProvClient.GetDeviceProvisioningUsername())")

        mqttClient = MQTTClient(
            host: "global.azure-devices-provisioning.net",
            port: 8883,
            clientID: AzProvClient.GetDeviceProvisioningClientID(),
            cleanSession: true,
            keepAlive: 30,
            username: AzProvClient.GetDeviceProvisioningUsername(),
            password: "",
            tlsConfiguration: tlsConfiguration
        )
        mqttClient.tlsConfiguration = tlsConfiguration
        mqttClient.delegate = self
    }

/// Needed Functions for MQTTClientDelegate
    public func mqttClient(_ client: MQTTClient, didReceive packet: MQTTPacket) {
        switch packet {
        case let packet as ConnAckPacket:
            print("[Provisioning] Connack Received: \(packet)")
            isProvisioningConnected = true;
            
        case let packet as PublishPacket:
            print("[Provisioning] Publish Received");
            print("[Provisioning] Publish Topic: \(packet.topic)");
            print("[Provisioning] Publish Payload \(String(decoding: packet.payload, as: UTF8.self))");

            let provResponse: AzureIoTProvisioningRegisterResponse = AzProvClient.ParseRegistrationTopicAndPayload(topic: packet.topic, payload: String(decoding: packet.payload, as: UTF8.self))
            gOperationID = provResponse.OperationID

            if provResponse.RegistrationState.AssignedHubHostname.count > 0
            {
                print("[Provisioning] Assigned Hub: \(provResponse.RegistrationState.AssignedHubHostname)")
                isDeviceProvisioned = true;
                
                assignedHub = provResponse.RegistrationState.AssignedHubHostname
                assignedDeviceID = provResponse.RegistrationState.DeviceID
            }
            
        case let packet as SubAckPacket:
            print("[Provisioning] Suback Received: \(packet)");

        default:
            print("[Provisioning] Packet Received: \(packet)")
        }
    }

    public func mqttClient(_: MQTTClient, didChange state: ConnectionState) {
        if state == .disconnected {
            print("[Provisioning] MQTT state:\(state)")
        }
    }

    public func mqttClient(_: MQTTClient, didCatchError error: Error) {
        print("[Provisioning] Error: \(error)")
    }

    public func connectToProvisioning() {
        print("[Provisioning] Connecting to Provisioning")
        mqttClient.connect()
    }
    
    public func disconnectFromProvisioning() {
        print("[Provisioning] Disconnecting from Provisioning")
        mqttClient.disconnect()
    }

    public func subscribeToAzureDeviceProvisioningFeature() {
        print("[Provisioning] Subscribing to Provisioning")
        let deviceProvisioningTopic = AzProvClient.GetDeviceProvisioningSubscribeTopic()
        print("[Provisioning] Subscribing to topic: \(deviceProvisioningTopic)")
        mqttClient.subscribe(topic: deviceProvisioningTopic, qos: QOS.1)
    }

    public func sendDeviceProvisioningRequest() {
        print("[Provisioning] Requesting to be Provisioned")
        let deviceProvisioningRequestTopic = AzProvClient.GetDeviceProvisioningRegistrationPublishTopic()
        mqttClient.publish(topic: deviceProvisioningRequestTopic, retain: false, qos: QOS.1, payload: "")
    }

    public func sendDeviceProvisioningPollingRequest(operationID: String) {
        print("[Provisioning] Quering Provisioning")
        let deviceProvisioningQueryTopic = AzProvClient.GetDeviceProvisioningQueryTopic(operationID: operationID)
        mqttClient.publish(topic: deviceProvisioningQueryTopic, retain: false, qos: QOS.1, payload: "")
    }
}

class DemoHubClient: MQTTClientDelegate {

    public var sendTelemetry: Bool = false
    private var telemetryAckCallback: (() -> Void?)? = nil
    
    private var shouldSendTelemetry: Bool = false
    private var shouldStartAccelerometerUpdates: Bool = false

    /// Azure IoT Client
    private var AzHubClient : AzureIoTHubClient! = nil

    /// MQTT Client
    private var mqttClient: MQTTClient! = nil
    
    var delegateDispatchQueue: DispatchQueue {
        queue
    }

    // Create a motion manager for accessing accelerometer data
    let motionManager = CMMotionManager()

    public init(iothub: String, deviceId: String, telemCallback: @escaping () -> Void) {
        AzHubClient = AzureIoTHubClient(iothubUrl: iothub, deviceId: deviceId)

        let clientCert: [UInt8] = Array(myCert.utf8)
        let keyCert: [UInt8] = Array(myCertKey.utf8)

        var tlsConfiguration = TLSConfiguration.makeClientConfiguration()
        tlsConfiguration.minimumTLSVersion = .tlsv11
        tlsConfiguration.maximumTLSVersion = .tlsv12
        tlsConfiguration.certificateVerification = .fullVerification
        tlsConfiguration.certificateChain = try! NIOSSLCertificate.fromPEMBytes(clientCert).map { .certificate($0) }
        tlsConfiguration.privateKey = try! NIOSSLPrivateKeySource.privateKey(NIOSSLPrivateKey(bytes: keyCert, format: .pem))
        
        mqttClient = MQTTClient(
            host: iothub,
            port: 8883,
            clientID: AzHubClient.GetClientID(),
            cleanSession: true,
            keepAlive: 30,
            username: AzHubClient.GetUserName(),
            password: "",
            tlsConfiguration: tlsConfiguration
        )
        mqttClient.tlsConfiguration = tlsConfiguration
        mqttClient.delegate = self

        telemetryAckCallback = telemCallback

        // Start accelerometer updates
//        startAccelerometerUpdates()
    }

    // Start accelerometer updates
    private func startAccelerometerUpdates() {
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 1.0 / 5.0  // Update every 0.2 seconds
            motionManager.startAccelerometerUpdates(to: .main) { (accelerometerData, error) in
                guard let acceleration = accelerometerData?.acceleration else { return }
                // Update the telemetry payload with accelerometer data
                let payload = "X: \(acceleration.x), Y: \(acceleration.y), Z: \(acceleration.z)"
                self.sendTelemetryPayload(payload)
            }
        } else {
            print("Accelerometer is not available.")
        }
    }

    // Stop accelerometer updates when disconnecting
    private func stopAccelerometerUpdates() {
        if motionManager.isAccelerometerActive {
            motionManager.stopAccelerometerUpdates()
        }
    }

    // Send telemetry payload with accelerometer data
    private func sendTelemetryPayload(_ payload: String) {
        let swiftString = AzHubClient.GetTelemetryPublishTopic()
        print("[IoT Hub] Sending a message to topic: \(swiftString)")
        print("[IoT Hub] Sending a message: \(payload)")

        mqttClient.publish(topic: swiftString, retain: false, qos: QOS.1, payload: payload)
        
    }
    
    // Public method to toggle telemetry sending
        public func toggleTelemetrySending() {
            shouldSendTelemetry.toggle()
            manageAccelerometerUpdates()
        }
    
    // Start or stop accelerometer updates based on the state of shouldStartAccelerometerUpdates
        private func manageAccelerometerUpdates() {
            if shouldStartAccelerometerUpdates {
                startAccelerometerUpdates()
            } else {
                stopAccelerometerUpdates()
            }
        }
    
    // Public method to toggle starting accelerometer updates
        public func toggleAccelerometerUpdates() {
            shouldStartAccelerometerUpdates.toggle()
            manageAccelerometerUpdates()
        }

    // Needed Functions for MQTTClientDelegate
    func mqttClient(_ client: MQTTClient, didReceive packet: MQTTPacket) {
        switch packet {
        case let packet as ConnAckPacket:
            print("[IoT Hub] Connack Received: \(packet)")
            sendTelemetry = true;
            
        case let packet as PublishPacket:
            print("[IoT Hub] Publish Received: \(packet)")
            print("[IoT Hub] Publish Topic: \(packet.topic)")
            print("[IoT Hub] Publish Payload \(String(decoding: packet.payload, as: UTF8.self))")
            
        case let packet as PubAckPacket:
            print("[IoT Hub] PubAck Received: \(packet)")
            telemetryAckCallback!()

        default:
            print("[IoT Hub] Packet Received: \(packet)")
        }
    }

    func mqttClient(_: MQTTClient, didChange state: ConnectionState) {
        if state == .disconnected {
            stopAccelerometerUpdates()
            sem.signal()
        }
        print("[IoT Hub] MQTT state: \(state)")
    }

    func mqttClient(_: MQTTClient, didCatchError error: Error) {
        print("[IoT Hub] Error: \(error)")
    }

    // Public methods
    public func sendMessage() {
        // This method can be used if you want to send a specific message, but the accelerometer updates will already be sending telemetry.
        let swiftString = AzHubClient.GetTelemetryPublishTopic()

                let telem_payload = "Hello there (test message)"
                print("[IoT Hub] Sending a message to topic: \(swiftString)")
                print("[IoT Hub] Sending a message: \(telem_payload)")

                mqttClient.publish(topic: swiftString, retain: false, qos: QOS.1, payload: telem_payload)
    }

    public func connectToIoTHub() {
        print("[IoT Hub] Connecting to IoT Hub")
        mqttClient.connect()
    }

    public func disconnectFromIoTHub() {
        mqttClient.disconnect()
    }

    public func subscribeToAzureIoTHubFeatures() {
        print("[IoT Hub] Subscribing to IoT Hub Features")
        // Methods
        let methodsTopic = AzHubClient.GetCommandsSubscribeTopic()
        mqttClient.subscribe(topic: methodsTopic, qos: QOS.1)
        
        // Twin Response
        let twinResponseTopic = AzHubClient.GetPropertiesResponseSubscribeTopic()
        mqttClient.subscribe(topic: twinResponseTopic, qos: QOS.1)

        // Twin Patch
        let twinPatchTopic = AzHubClient.GetPropertiesWritablePatchSubscribeTopic()
        mqttClient.subscribe(topic: twinPatchTopic, qos: QOS.1)
    }
}
