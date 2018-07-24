//
//  PDFTrueTypeFontFile.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 18/07/2018.
//

import Foundation
import CoreGraphics

typealias UInt24 = UInt32

struct TrueTypeFontFile {



    enum FontFileError: Error {
        case invalidTableChecksum(tag: String)
        case tableIndexNotFound(table: String)
        case tableDependencyMissing(table: String, dependency: String)
        case invalidMagicNumber(number: UInt32)
        case unsupportedFormat(feature: String)
    }


    //FONT table
    private var scalarType = UInt32(0)
    private var numTables = UInt16(0)
    private var searchRange = UInt16(0)
    private var entrySelector = UInt16(0)
    private var rangeShift = UInt16(0)
    private var tableOffsets = [String: TTTableOffset]()

    //Other tables
    private var headTable: TTHeadTable?
    private var hheaTable: TTHHEATable?
    private var hmtxTable: TTHMTXTable?
    private var maxpTable: TTMAXPTable?
    private var cmapTable: TTCMAPTable?
    private var locaTable: TTLOCATable?
    private var glyfTable: TTGLYFTable?

    init(data: CFData) throws {
        let reader = TrueTypeFontFileReader(data as Data)
        try readOffsetTables(reader)
        try readHeadTable(reader)
        try readMAXPTable(reader)
        try readHHEATable(reader)
        try readHMTXTable(reader)
        try readCMAPTable(reader)
        try readLOCATable(reader)
        try readGLYFTable(reader)
    }


    //MARK: - TrueType Table Parsing
    private mutating func readOffsetTables(_ r: TrueTypeFontFileReader) throws  {
        scalarType = r.get()
        let numTables = r.get() as UInt16
        searchRange = r.get()
        entrySelector = r.get()
        rangeShift = r.get()

        for _ in 0..<numTables {
            let tag = r.getString(length:4)
            let table = TTTableOffset( checksum: r.get(),
                                       offset: r.get(),
                                       length: r.get())

            if  tag != "head" &&
                table.checksum != calculateTableChecksum(r,
                                                         offset: table.offset,
                                                         length: table.length) {
                if table.checksum == 0 {
                    //TODO: use correct logging mechanism.
                    print("table \(tag) has no checksum. ignore.")
                } else {
                    throw FontFileError.invalidTableChecksum(tag: tag)
                }
            }
            tableOffsets[tag] = table
        }
    }


    static let checksumModulo : UInt64 = 1<<32
    private mutating func calculateTableChecksum(_ r: TrueTypeFontFileReader, offset: UInt32, length: UInt32) -> UInt32 {
        let old = r.seek(pos: Int(offset))
        var sum = UInt64(0)
        let nbLongs = (length + 3) / 4
        for  _ in 0 ..< nbLongs {
            sum = (sum + UInt64(r.get() as UInt32)) % TrueTypeFontFile.checksumModulo
        }
        _ = r.seek(pos: old)
        return UInt32(sum)
    }

    private mutating func readHeadTable(_ r: TrueTypeFontFileReader) throws {
        guard let headTableIndex = tableOffsets["head"] else {
            throw FontFileError.tableIndexNotFound(table:"head")
        }

        let oldPos = r.seek(pos:Int(headTableIndex.offset))
        let headTable = TTHeadTable(version: r.getFixed(),
                                  fontRevision: r.getFixed(),
                                  checksumAdjustment: r.get(),
                                  magicNumber: r.get(),
                                  flags: r.get(),
                                  unitsPerEm: r.get(),
                                  created: r.getDate(),
                                  modified: r.getDate(),
                                  xMin: r.getFWord(),
                                  yMin: r.getFWord(),
                                  xMax: r.getFWord(),
                                  yMax: r.getFWord(),
                                  macStyle: r.get(),
                                  lowestRecPPEM: r.get(),
                                  fontDirectionHint: r.get(),
                                  indexToLocFormat: r.get(),
                                  glyphDataFormat: r.get())
        if headTable.magicNumber != 0x5f0f3cf5 {
            throw FontFileError.invalidMagicNumber(number: headTable.magicNumber)
        }

        self.headTable = headTable
        _ = r.seek(pos: oldPos)
    }

    mutating private func readHHEATable(_ r: TrueTypeFontFileReader) throws {
        guard let hheaTableIndex = tableOffsets["hhea"] else {
            throw FontFileError.tableIndexNotFound(table: "hhea")
        }

        let oldPos  = r.seek(pos: Int(hheaTableIndex.offset))

        let hheaTable = TTHHEATable(version: r.getFixed(),
                                  ascent: r.getFWord(),
                                  descent: r.getFWord(),
                                  lineGap: r.getFWord(),
                                  advanceWidthMax: r.get(),
                                  minLeftSideBearing: r.getFWord(),
                                  minRightSideBearing: r.getFWord(),
                                  xMaxExtent: r.getFWord(),
                                  caretSlopeRise: r.get(),
                                  caretSlopeRun: r.get(),
                                  caretOffset: r.getFWord(),
                                  reserved1: r.get(),
                                  reserved2: r.get(),
                                  reserved3: r.get(),
                                  reserved4: r.get(),
                                  metricDataFormat: r.get(),
                                  numOfLongHorMetrics: r.get())

        self.hheaTable = hheaTable

        _ = r.seek(pos: oldPos)
    }

    mutating private func readMAXPTable( _ r: TrueTypeFontFileReader) throws {
        guard let maxpTableIndex = tableOffsets["maxp"] else {
            throw FontFileError.tableIndexNotFound(table: "maxp")
        }
        let oldPos = r.seek(pos: Int(maxpTableIndex.offset))

        self.maxpTable = TTMAXPTable(version: r.getFixed(),
                                   numGlyphs: r.get(),
                                   maxPoints: r.get(),
                                   maxContours: r.get(),
                                   maxComponentPoints: r.get(),
                                   maxComponentContours: r.get(),
                                   maxZones: r.get(),
                                   maxTwilightPoints: r.get(),
                                   maxStorage: r.get(),
                                   maxFunctionDefs: r.get(),
                                   maxInstructionDefs: r.get(),
                                   maxStackElements: r.get(),
                                   maxSizeOfInstructions: r.get(),
                                   maxComponentElements: r.get(),
                                   maxComponentDepth: r.get())
        _ = r.seek(pos: oldPos)

    }

    mutating private func readHMTXTable(_ r: TrueTypeFontFileReader) throws {

        guard let maxPTable = self.maxpTable else {
            throw FontFileError.tableDependencyMissing(table: "hmtx", dependency: "maxp")
        }
        guard let hheaTable = self.hheaTable else {
            throw FontFileError.tableDependencyMissing(table: "hmtx", dependency: "hhea")
        }
        guard let hmtxTableIndex = tableOffsets["hmtx"] else {
            throw FontFileError.tableIndexNotFound(table: "hmtx")
        }
        let oldPos = r.seek(pos: Int(hmtxTableIndex.offset))

        var horMetrics = [TTHMTXTable.HorMetric]()
        for _ in 0..<hheaTable.numOfLongHorMetrics {
            horMetrics.append(TTHMTXTable.HorMetric(
                advanceWidth: r.get(),
                leftSideBearing: r.get()))
        }
        var lsbs = [Int16]()
        for _ in 0 ..< Int(maxPTable.numGlyphs) - Int(hheaTable.numOfLongHorMetrics) {
            lsbs.append(r.get())
        }
        self.hmtxTable = TTHMTXTable(horMetrics: horMetrics,
                                   leftSideBearings: lsbs)

        _ = r.seek(pos: oldPos)
    }

    mutating private func readLOCATable(_ r: TrueTypeFontFileReader) throws {
        guard let locaTableIndex = tableOffsets["loca"] else {
            throw FontFileError.tableIndexNotFound(table: "loca")
        }
        guard let headTable = self.headTable else {
            throw FontFileError.tableDependencyMissing(table: "loca", dependency: "head")
        }
        guard let maxPTable = self.maxpTable else {
            throw FontFileError.tableDependencyMissing(table: "loca", dependency: "maxP")
        }
        let oldPos = r.seek(pos: Int(locaTableIndex.offset))

        if headTable.indexToLocFormat == 0 {
            //Short
            self.locaTable = TTLOCATable(offsets: TTLOCATable.Offsets.short(offsets: r.getArray(count: Int(maxPTable.numGlyphs) + 1)))
        } else {
            //Long
            self.locaTable = TTLOCATable(offsets: TTLOCATable.Offsets.long(offsets: r.getArray(count: Int(maxPTable.numGlyphs) + 1)))
        }
        _ = r.seek(pos: oldPos)
    }

    mutating private func readGLYFTable(_ r: TrueTypeFontFileReader) throws {
        guard let glyfTableIndex = tableOffsets["glyf"] else {
            throw FontFileError.tableIndexNotFound(table: "glyf")
        }
        guard let maxpTable = self.maxpTable else {
            throw FontFileError.tableDependencyMissing(table: "glyf", dependency: "maxp")
        }
        guard let locaTable = self.locaTable else {
            throw FontFileError.tableDependencyMissing(table: "glyf", dependency: "loca")
        }
        let oldPos = r.seek(pos: Int(glyfTableIndex.offset))

        var items = [TTGLYFTable.GlyfTableItem]()
        switch locaTable.offsets {
        case .short(let offsets):
            for glId in  0 ..< maxpTable.numGlyphs {
                let offset = offsets[Int(glId)]
                _ = r.seek(pos: Int(glyfTableIndex.offset) + Int(offset * 2))
                items.append(TTGLYFTable.GlyfTableItem(
                    numberOfContours: r.get(),
                    xMin: r.get(),
                    yMin: r.get(),
                    xMax: r.get(),
                    yMax: r.get()))
            }
        case .long(let offsets):
            for glId in  0 ..< maxpTable.numGlyphs {
                let offset = offsets[Int(glId)]
                _ = r.seek(pos: Int(glyfTableIndex.offset) + Int(offset))
                items.append(TTGLYFTable.GlyfTableItem(
                    numberOfContours: r.get(),
                    xMin: r.get(),
                    yMin: r.get(),
                    xMax: r.get(),
                    yMax: r.get()))
            }
        }

        self.glyfTable = TTGLYFTable(items: items)
        _ = r.seek(pos: oldPos)
    }


    mutating private func readCMAPTable(_ r: TrueTypeFontFileReader) throws {

        guard let cmapTableIndex = tableOffsets["cmap"] else {
            throw FontFileError.tableIndexNotFound(table: "cmap")
        }
        let oldPos = r.seek(pos: Int(cmapTableIndex.offset))

        let cmapIndex = TTCMAPTable.Index(version: r.get(),
                                          numberSubtables: r.get())

        var preferedSubtable: (index:Int, subtableIndex: TTCMAPTable.EncodingSubtableIndex)?
        var subtableIndexes = [TTCMAPTable.EncodingSubtableIndex]()
        for i in 0 ..< cmapIndex.numberSubtables {
            let subtableIndex = TTCMAPTable.EncodingSubtableIndex(
                platformId: r.get(),
                platformSpecificID: r.get(),
                offset: r.get())
            subtableIndexes.append(subtableIndex)

            /* Subtable encoding picking
             https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6cmap.html
             see "Platform Identifiers" table */
            if
                // we haven't picked any yet.
                preferedSubtable == nil ||
                // lowest plaform higher priority
                subtableIndex.platformId < preferedSubtable!.subtableIndex.platformId ||
                // if same platform, then highest specificID wins.
                (subtableIndex.platformId == preferedSubtable!.subtableIndex.platformId &&
                subtableIndex.platformSpecificID > preferedSubtable!.subtableIndex.platformSpecificID) {
                preferedSubtable = (Int(i), subtableIndex)
            }
        }


        var subtables = [TTCMAPTable.Subtable]()
        for subtableIndex in subtableIndexes {
            _ = r.seek(pos: Int(cmapTableIndex.offset + subtableIndex.offset))
            let format: UInt16  = r.get()
            switch format {
            case 4:
                subtables.append(readCMapSubTableFormat4(r, tableBeginOffset: Int(subtableIndex.offset) ))
            case 6:
                subtables.append(readCMapSubTableFormat6(r))
            case 12, 13:
                _ = r.get() as UInt16 // format padding.
                subtables.append(readCMapSubTableFormat12Or13(r, format: format))
            default:
                throw FontFileError.unsupportedFormat(feature: "CMap subtable format \(format)")

            }
        }
        self.cmapTable = TTCMAPTable(index: cmapIndex,
                                     subtableIndexes: subtableIndexes,
                                     subtables: subtables,
                                     preferedSubtable: preferedSubtable)
        _ = r.seek(pos: oldPos)
    }

    func readCMapSubTableFormat4(_ r: TrueTypeFontFileReader, tableBeginOffset: Int) -> TTCMAPTable.Subtable {
        var res = TTCMapSubtableFormat4(format: UInt16(4), //already parsed
                                        length: r.get(),
                                        language: r.get(),
                                        segCountX2: r.get(),
                                        searchRange: r.get(),
                                        entrySelector: r.get(),
                                        rangeShift: r.get(),
                                        endCode: [UInt16](),
                                        reservedPad: UInt16(0),
                                        startCode: [UInt16](),
                                        idDelta: [UInt16](),
                                        idRangeOffset: [UInt16](),
                                        glyphIndexArray: [UInt16]())

        let segCount = res.segCountX2 / 2
        res.endCode = r.getArray(count: Int(segCount))
        res.reservedPad = r.get()
        res.startCode = r.getArray(count: Int(segCount))
        res.idDelta = r.getArray(count: Int(segCount))
        res.idRangeOffset = r.getArray(count: Int(segCount))
        let currentOffset = r.tell()
        let endOfTableOffset = tableBeginOffset + Int(res.length)
        let numberOfBytesLeft = endOfTableOffset - currentOffset
        res.glyphIndexArray = r.getArray(count:numberOfBytesLeft / 2 )

        return .format4(subtable: res)
    }
    func readCMapSubTableFormat6(_ r: TrueTypeFontFileReader) -> TTCMAPTable.Subtable {
        var res = TTCMapSubtableFormat6(format: UInt16(6),
                                        length: r.get(),
                                        language: r.get(),
                                        firstCode: r.get(),
                                        entryCount: r.get(),
                                        glyphIndexArray: [UInt16]())

        res.glyphIndexArray = r.getArray(count: Int(res.entryCount))

        return .format6(subtable: res)
    }
    func readCMapSubTableFormat12Or13(_ r: TrueTypeFontFileReader, format: UInt16) -> TTCMAPTable.Subtable {
        var res = TTCMapSubtableFormat12Or13(format: format,
                                              formatPadding: UInt16(0),
                                              length: r.get(),
                                              language: r.get(),
                                              nGroups: r.get(),
                                              groups: [TTCMapSubtableFormat12Or13.Group]())
        var groups = [TTCMapSubtableFormat12Or13.Group]()
        for _ in 0 ..< res.nGroups {
            groups.append(TTCMapSubtableFormat12Or13.Group(startCharCode: r.get(),
                                                           endCharCode: r.get(),
                                                           startGlyphCode: r.get()))
        }
        res.groups = groups
        return .format12Or13(subtable: res)
    }


}


extension TrueTypeFontFile: PDFFontFile {
    func glyphName(forChar originalCharCode: PDFCharacterCode) -> String? {
        return nil
    }
    func glyphWidthInThousandthOfEM(forChar char:unichar, originalCharCode oChar: PDFCharacterCode) -> CGFloat? {
        guard
            let headTable = self.headTable,
            let cmapTable = self.cmapTable,
            let subtableIndex = cmapTable.preferedSubtable,
            let hmtx = self.hmtxTable else { return nil }

        let glId = glyphId(forChar: Int(oChar), in: cmapTable.subtables[subtableIndex.index]) ?? 0

        //Logging. TODO: Debug only.
        /*
        if glId == 0 {
            var charTmp = char
            print ("char \(String(utf16CodeUnits: &charTmp, count: 1)) using glid 0")
        } else {
            var charTmp = char
            print ("char \(String(utf16CodeUnits: &charTmp, count: 1)) found in font")
        }
        */


        /* Using HMTX */
        var res: CGFloat
        if glId < hmtx.horMetrics.count {
            res = CGFloat(hmtx.horMetrics[glId].advanceWidth)
        } else {
            res = CGFloat(hmtx.horMetrics.last?.advanceWidth ?? 0)
        }


        /* GLYF box fallback */
        if let glyfTable = self.glyfTable,
            res == 0,
            glId < glyfTable.items.count {
                let glyfItem = glyfTable.items[glId]
                res = CGFloat(glyfItem.xMax - glyfItem.xMin)
        }

        return res * 1000 / CGFloat(headTable.unitsPerEm)
    }



    func glyphId(forChar char:Int, in subtable: TTCMAPTable.Subtable) -> Int? {
        switch subtable {
        case .format4(let subtable):
            return subtable.glyphId(forChar: char)
        case .format6(let subtable):
            return subtable.glyphId(forChar: char)
        case .format12Or13(let subtable):
            return subtable.glyphId(forChar: char, format: subtable.format)
        default:
            assertionFailure("subtable not supported")
            return nil
        }
    }
}

extension TTCMapSubtableFormat4 {
    func glyphId(forChar char:Int) -> Int? {
        var segmentTmp: Int? = nil
        for (i, endCharCode) in endCode.enumerated() {
            if char <= endCharCode {
                segmentTmp = i
                break
            }
        }
        guard let segment = segmentTmp,
            startCode[segment] <= char else { return nil }

        let idDelta = self.idDelta[segment]
        let idRangeOffset = self.idRangeOffset[segment]

        if idRangeOffset != 0 {
            /* From the spec :
             If the idRangeOffset value for the segment is not 0, the mapping of the character codes relies on the glyphIndexArray. The character code offset from startCode is added to the idRangeOffset value. This sum is used as an offset from the current location within idRangeOffset itself to index out the correct glyphIdArray value. This indexing method works because glyphIdArray immediately follows idRangeOffset in the font file. The address of the glyph index is given by the following equation:

             glyphIndexAddress = idRangeOffset[i] + 2 * (c - startCode[i]) + (Ptr) &idRangeOffset[i]

             Multiplication by 2 in this equation is required to convert the value into bytes.

             Alternatively, one may use an expression such as:

             glyphIndex = *( &idRangeOffset[i] + idRangeOffset[i] / 2 + (c - startCode[i]) )

             This form depends on idRangeOffset being an array of UInt16's.

             Once the glyph indexing operation is complete, the glyph ID at the indicated address is checked. If it's not 0 (that is, if it's not the missing glyph), the value is added to idDelta[i] to get the actual glyph ID to use.
             */

            //We can't use cross arrays offset. We need to recompute the offset from inside glyphIndexArray.
            let distanceToEndOfIdRange = (self.idRangeOffset.count - segment)
            let idRangeOffsetAdjusted = Int(idRangeOffset / 2) - distanceToEndOfIdRange
            let glyphId = self.glyphIndexArray[idRangeOffsetAdjusted + char - Int(startCode[segment])]
            if glyphId == 0 { return 0 }
            //NOTE: All idDelta[i] arithmetic is modulo 65536.
            return Int(glyphId + idDelta) % 65536

        } else {
            //If the idRangeOffset is 0, the idDelta value is added directly to the character code to get the corresponding glyph index
            //NOTE: All idDelta[i] arithmetic is modulo 65536.
            return (Int(idDelta) + char) % 65536
        }
    }
}

extension TTCMapSubtableFormat6 {
    func glyphId(forChar char:Int) -> Int? {
        guard char >= firstCode && char < firstCode + entryCount else { return 0 }
        return Int(glyphIndexArray[char - Int(firstCode)])
    }
}

extension TTCMapSubtableFormat12Or13 {
    func glyphId(forChar char:Int, format: UInt16) -> Int? {
        var groupTmp: TTCMapSubtableFormat12Or13.Group?
        for g in groups {
            if char <= g.endCharCode {
                groupTmp = g
                break
            }
        }
        guard let group = groupTmp else { return nil }
        if format == 12 {
            return Int(group.startGlyphCode) + char - Int(group.startCharCode)
        } else {
            assert(format == 13, "invalid format for glyphId lookup in TTCMapSubtableFormat12Or13")
            return Int(group.startGlyphCode)
        }
    }
}




