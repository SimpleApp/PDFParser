
import Foundation
import CoreGraphics

func getUInt24() -> UInt32 {
    let first8: UInt8 = UInt8(0x0A)
    let second8: UInt8 = UInt8(0x0B)
    let third8: UInt8 = UInt8(0x0C)
    return UInt32(first8) << 16 + UInt32(second8) << 8 + UInt32(third8)
}

let r = getUInt24()
let expected = 0x0A0B0C
