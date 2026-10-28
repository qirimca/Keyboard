#!/usr/bin/env swift
// Lists iOS devices that expose their screen as a capture device (same mechanism as QuickTime "New Movie Recording").
// Usage: swift list_ios_capture_devices.swift
import AVFoundation
import CoreMediaIO

var prop = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
                                     mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                                     mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
var allow: UInt32 = 1
CMIOObjectSetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &prop, 0, nil, UInt32(MemoryLayout<UInt32>.size), &allow)
RunLoop.current.run(until: Date().addingTimeInterval(2.5))
let types: [AVCaptureDevice.DeviceType] = [.external]
let s = AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .muxed, position: .unspecified)
print("muxed devices:", s.devices.count)
for d in s.devices { print(" -", d.localizedName, d.modelID, d.uniqueID) }
let v = AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: .unspecified)
print("video external devices:", v.devices.map { $0.localizedName })
print("auth:", AVCaptureDevice.authorizationStatus(for: .video).rawValue)
