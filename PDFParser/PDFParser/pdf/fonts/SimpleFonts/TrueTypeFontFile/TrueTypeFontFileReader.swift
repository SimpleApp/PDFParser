//
//  PDFTrueTypeFontFileReader.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 20/07/2018.
//

import Foundation
import CoreGraphics

//Based on http://stevehanov.ca/blog/TrueType.js
class TrueTypeFontFileReader {



    var pos:Int = 0
    var glyphWidths = [unichar: CGFloat]()
    var data: Data
    var currentSystemIsLittleEndian: Bool
    var trueTypeReferenceDate: Date

    init(_ data: Data) {
        self.data = data
        var dc = DateComponents()
        dc.year = 1904
        dc.month = 1
        dc.day = 1
        trueTypeReferenceDate = Calendar.current.date(from: dc)!
        currentSystemIsLittleEndian = Int(littleEndian: 1) == 1
    }

    func seek(pos: Int) -> Int {
        assert(pos >= 0 && pos <= data.count , "seek out of bounds")
        let oldPos = self.pos
        self.pos = pos
        return oldPos
    }

    func tell() -> Int {
        return pos
    }

   /*func get<T>() -> T where T: FixedWidthInteger {
        let res = data[pos...].withUnsafeBytes {
            (pointer: UnsafePointer<T>) -> T in
            return currentSystemIsLittleEndian ? pointer.pointee.byteSwapped : pointer.pointee
        }
        pos += MemoryLayout<T>.size
        return res
    }*/

    func get<T>() -> T where T: FixedWidthInteger {
        let res = data[pos...].withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> T in
            let typedPointer: UnsafeBufferPointer<T> = pointer.bindMemory(to: T.self)

            return currentSystemIsLittleEndian ? typedPointer[0].byteSwapped : typedPointer[0]
        }
        pos += MemoryLayout<T>.size
        return res
    }

    func getUInt24() -> UInt24 {
        let first8: UInt8 = get()
        let second8: UInt8 = get()
        let third8: UInt8 = get()
        return UInt32(first8) << 16 + UInt32(second8) << 8 + UInt32(third8)
    }

    func getFWord() -> Int16 {
        return get()
    }
    func getFixed() -> Float {
        return Float(get() as Int32) / ( Float(1 << 16) )
    }
    func get2Dot14() -> Float {
        return Float(get() as Int32) / ( Float(1 << 14) )
    }

    func getString(length: Int) -> String {
        let res = String(bytes: data[pos..<pos+length], encoding: .utf8) ?? ""
        pos += length
        return res
    }

    func getDate() -> Date {
        let macTime = get() as Int64
        return Date(timeInterval: TimeInterval(macTime), since: trueTypeReferenceDate)
    }

    func getArray<T>(count: Int) -> [T] where T: FixedWidthInteger {
        var res = [T]()
        guard count > 0 else { return res }
        for _ in 0 ..< count {
            res.append(get())
        }
        return res
    }

}
