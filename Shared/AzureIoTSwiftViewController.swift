//
//  AzureIoTSwiftViewController.swift
//  AzureIoTSwiftSample
//
//
//

import Foundation
import MQTT
import NIOSSL
import CAzureSDKForCSwift

let sem = DispatchSemaphore(value: 0)
let queue = DispatchQueue(label: "a", qos: .background)

class AzureIoTHubClientSwift: ObservableObject {
    private var sendTelemetry: Bool = false;
    private(set) var isSendingTelemetry: Bool = false;
    @Published private(set) var numSentMessages: Int = 0;
    @Published private(set) var numSentMessagesGood: Int = 0;
    
    @Published var shouldStartAccelerometerUpdates: Bool = false
    
    private(set) var scopeID: String
    private(set) var registrationID: String
    
    @Published private(set) var isHubConnected: Bool = false
    @Published private(set) var isProvisioned: Bool = false
    
    var provisioningDemoClient: DemoProvisioningClient! = nil
    var hubDemoHubClient: DemoHubClient! = nil
    
    private func telemAckCallback() {
        DispatchQueue.main.async { self.numSentMessagesGood = self.numSentMessagesGood + 1 }
    }
    
    public init(myScopeID: String, myRegistrationID: String)
    {
        self.scopeID = myScopeID
        self.registrationID = myRegistrationID
    }
    
    public func startDPSWorkflow()
    {
        provisioningDemoClient = DemoProvisioningClient(idScope: scopeID, registrationID: registrationID)

        provisioningDemoClient.connectToProvisioning()

        while(!provisioningDemoClient.isProvisioningConnected) {}

        provisioningDemoClient.subscribeToAzureDeviceProvisioningFeature()

        provisioningDemoClient.sendDeviceProvisioningRequest()

        queue.asyncAfter(deadline: .now() + 4)
        {
            self.provisioningDemoClient.sendDeviceProvisioningPollingRequest(operationID: self.provisioningDemoClient.gOperationID)
        }

        while(!provisioningDemoClient.isDeviceProvisioned) {}
        
        isProvisioned = true;

        provisioningDemoClient.disconnectFromProvisioning()
    }
    
    public func startIoTHubWorkflow()
    {
        hubDemoHubClient = DemoHubClient(iothub: provisioningDemoClient.assignedHub, deviceId: provisioningDemoClient.assignedDeviceID, telemCallback: telemAckCallback)

        hubDemoHubClient.connectToIoTHub()
        
        self.isHubConnected = true

        while(!hubDemoHubClient.sendTelemetry) {}

        hubDemoHubClient.subscribeToAzureIoTHubFeatures()
    }
    
    public func sendTelemetryMessage()
    {
        self.hubDemoHubClient.sendMessage()
        DispatchQueue.main.async { self.numSentMessages = self.numSentMessages + 1 }
    }

    
    func toggleAccelerometerUpdates() {
            shouldStartAccelerometerUpdates.toggle()

            // Call the corresponding method in your DemoHubClient or any other relevant class
            if let hubDemoHubClient = hubDemoHubClient {
                hubDemoHubClient.toggleAccelerometerUpdates()
                DispatchQueue.main.async { self.numSentMessages = self.numSentMessages + 1 }
            } else {
                print("DemoHubClient is not initialized or hubDemoHubClient is nil.")
            }
        }
}
