//
//  KeyboardViewController+Host.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2023-03-27.
//  Copyright © 2023-2024 Daniel Saidi. All rights reserved.
//

#if os(iOS) || os(tvOS) || os(visionOS)
import SwiftUI
import UIKit

public extension KeyboardInputViewController {

    /// The bundle ID of the host application, if any.
    ///
    /// The property uses technologies that may stop working
    /// in any future iOS version. Do not rely solely on the
    /// function, and design the app to be able to work even
    /// if this feature suddenly stops working.
    var hostBundleId: String? {
        if let id = hostBundleIdValueBefore16 { return id }
        return hostBundleIdValueFor16
    }
}

private extension KeyboardInputViewController {
    
    var hostBundleIdValueBefore16: String? {
        let value = parent?.value(forKey: "_hostBundleID") as? String
        return value != "<null>" ? value : nil
    }
    
    var hostBundleIdValueFor16: String? {
        guard let pid = parent?.value(forKey: "_hostPID") else { return nil }
        let selector = NSSelectorFromString("defaultService")
        guard let anyClass: AnyObject = NSClassFromString("PKService"),
           let pkService = anyClass as? NSObjectProtocol,
           pkService.responds(to: selector),
           let serverInis = pkService.perform(selector)?.takeUnretainedValue() as? NSObjectProtocol
        else { return nil }
        guard let lities = serverInis.perform(NSSelectorFromString("personalities"))?.takeUnretainedValue() as? NSObjectProtocol else { return nil }
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        guard let infos = (lities as AnyObject).object(forKey: bundleId) as? AnyObject,
           let info = infos.object(forKey: pid) as? AnyObject,
           let con = info.perform(NSSelectorFromString("connection"))?.takeUnretainedValue() as? NSObjectProtocol
        else { return nil }
        guard let xpcCon = con.perform(NSSelectorFromString("_xpcConnection"))?.takeUnretainedValue() else { return nil }
        guard let handle = dlopen("/usr/lib/libc.dylib", RTLD_NOW) else { return nil }
        defer { dlclose(handle) }
        guard let sym = dlsym(handle, "xpc_connection_copy_bundle_id") else { return nil }
        typealias xpcFunc = @convention(c) (AnyObject) -> UnsafeMutablePointer<CChar>?
        let cFunc = unsafeBitCast(sym, to: xpcFunc.self)
        guard let response = cFunc(xpcCon) else { return nil }
        defer { free(response) }
        return String(cString: response)
    }
}
#endif
