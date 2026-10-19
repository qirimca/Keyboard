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
    ///
    /// The lookup goes through private KVC, `PKService` and XPC,
    /// which is far too expensive to repeat on every keystroke.
    /// The result is cached until ``resetHostBundleIdCache()`` is
    /// called (call it when a new input session starts); a failed
    /// lookup is retried at most once per second.
    var hostBundleId: String? {
        let cache = hostBundleIdCache
        if let id = cache.value { return id }
        if let failedAt = cache.failedAt, Date().timeIntervalSince(failedAt) < 1 { return nil }
        let id = hostBundleIdValueBefore16 ?? hostBundleIdValueFor16
        cache.value = id
        cache.failedAt = id == nil ? Date() : nil
        return id
    }

    /// Forget the cached host bundle ID (new input session or field).
    func resetHostBundleIdCache() {
        hostBundleIdCache.value = nil
        hostBundleIdCache.failedAt = nil
    }
}

private final class HostBundleIdCache {
    var value: String?
    var failedAt: Date?
}

private var hostBundleIdCacheKey: UInt8 = 0

private extension KeyboardInputViewController {

    var hostBundleIdCache: HostBundleIdCache {
        if let cache = objc_getAssociatedObject(self, &hostBundleIdCacheKey) as? HostBundleIdCache {
            return cache
        }
        let cache = HostBundleIdCache()
        objc_setAssociatedObject(self, &hostBundleIdCacheKey, cache, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return cache
    }
}

private extension KeyboardInputViewController {

    var hostBundleIdValueBefore16: String? {
        let selector = NSSelectorFromString("_hostBundleID")
        var current: UIViewController? = self
        while let vc = current {
            if vc.responds(to: selector),
               let value = vc.value(forKey: "_hostBundleID") as? String,
               !value.isEmpty,
               value != "<null>" {
                return value
            }
            current = vc.parent
        }
        return nil
    }

    var hostBundleIdValueFor16: String? {
        let pidSelector = NSSelectorFromString("_hostPID")
        var pidValue: Any?
        var current: UIViewController? = self
        while let vc = current {
            if vc.responds(to: pidSelector), let val = vc.value(forKey: "_hostPID") {
                pidValue = val
                break
            }
            current = vc.parent
        }
        let selector = NSSelectorFromString("defaultService")
        guard let anyClass: AnyObject = NSClassFromString("PKService"),
           let pkService = anyClass as? NSObjectProtocol,
           pkService.responds(to: selector),
           let serverInis = pkService.perform(selector)?.takeUnretainedValue() as? NSObjectProtocol
        else { return nil }
        guard let lities = serverInis.perform(NSSelectorFromString("personalities"))?.takeUnretainedValue() as? NSObjectProtocol else { return nil }
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        guard let infos = (lities as AnyObject).object(forKey: bundleId) as? AnyObject else { return nil }
        let resolvedInfo: AnyObject? = {
            if let pid = pidValue, let byPid = infos.object(forKey: pid) as? AnyObject {
                return byPid
            }
            return (infos as? NSDictionary)?.allValues.first as AnyObject?
        }()
        guard let info = resolvedInfo,
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
