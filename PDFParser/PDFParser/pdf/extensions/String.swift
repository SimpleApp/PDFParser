//
//  String.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 24/07/2018.
//  Copyright © 2018 SimpleApp. All rights reserved.
//

import Foundation
extension String {
    static func decodePDFInt8CString(_ cString: UnsafePointer<Int8>?, repairingInvalidCodeUnits: Bool = false) -> String? {
        guard let cString = cString else { return nil }
        let str  = cString.withMemoryRebound(to: UInt8.self, capacity: 1) {
                                                    (bytes: UnsafePointer<UInt8>) in
            return String.decodeCString(bytes, as: UTF8.self, repairingInvalidCodeUnits:repairingInvalidCodeUnits)
        }
        return str?.result
    }
}
