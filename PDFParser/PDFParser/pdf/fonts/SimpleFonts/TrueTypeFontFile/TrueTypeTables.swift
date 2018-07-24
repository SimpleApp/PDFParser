//
//  TrueTypeTables.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 20/07/2018.
//

import Foundation

struct TTTableOffset {
    let checksum: UInt32
    let offset: UInt32
    let length: UInt32
}
typealias Fixed = Float32
struct TTHeadTable {
    let version             : Fixed
    let fontRevision        : Fixed
    let checksumAdjustment  : UInt32
    let magicNumber         : UInt32
    let flags               : UInt16
    let unitsPerEm          : UInt16
    let created             : Date
    let modified            : Date
    let xMin                : Int16
    let yMin                : Int16
    let xMax                : Int16
    let yMax                : Int16
    let macStyle            : UInt16
    let lowestRecPPEM       : UInt16
    let fontDirectionHint   : UInt16
    let indexToLocFormat    : UInt16
    let glyphDataFormat     : UInt16
}

struct TTHHEATable {
    let version             : Fixed
    let ascent              : Int16  // Distance from baseline of highest ascender
    let descent             : Int16  // Distance from baseline of lowest descender
    let lineGap             : Int16  // typographic line gap
    let advanceWidthMax     : UInt16 // must be consistent with horizontal metrics
    let minLeftSideBearing  : Int16  // must be consistent with horizontal metrics
    let minRightSideBearing : Int16  // must be consistent with horizontal metrics
    let xMaxExtent          : Int16  // max(lsb + (xMax-xMin))
    let caretSlopeRise      : Int16  // used to calculate the slope of the caret (rise/run) set to 1 for vertical caret
    let caretSlopeRun       : Int16  // 0 for vertical
    let caretOffset         : Int16  // set value to 0 for non-slanted fonts
    let reserved1           : Int16  // set value to 0
    let reserved2           : Int16  // set value to 0
    let reserved3           : Int16  // set value to 0
    let reserved4           : Int16  // set value to 0
    let metricDataFormat    : Int16  // 0 for current format
    let numOfLongHorMetrics : UInt16 // number of advance widths in metrics table
}

struct TTHMTXTable {
    struct HorMetric {
        let advanceWidth: UInt16
        let leftSideBearing: Int16
    }
    var horMetrics = [HorMetric]()
    var leftSideBearings = [Int16]()
}

struct TTNameTable {
    enum NameId: UInt16 {
        case copyright = 0
        case fontFamily = 1
        case fontSubfamily = 2
        case fontSubfamilyUniqueId = 3
        case fontFullname = 4
        case nameTableVersion = 5
        case postscriptFontName = 6
        case trademark = 7
        case manufacturerName = 8
        case designerName = 9
        case description = 10
        case vendorURL = 11
        case designerURL = 12
        case licenseDescription = 13
        case licenseInformationURL = 14
        case reserved15 = 15
        case preferedFamily = 16
        case preferedSubfamily = 17
        case compatibleFullname = 18 // mac only
    }
    struct NameRecordIndex {
        let platformId: UInt16
        let platformSpecificId : UInt16
        let languageId: UInt16
        let nameId: UInt16
        let length: UInt16 // Name string length in bytes.
        let offset: UInt16 // Name string offset in bytes from stringOffset.
    }
    typealias LanguageId = UInt16

    let format: UInt16
    let count: UInt16
    let stringOffset: UInt16
    var nameRecords: [NameRecordIndex]

    //computed
    var names: [LanguageId: [NameId: String]]
}

struct TTMAXPTable {
    let version              : Fixed
    let numGlyphs            : UInt16 // the number of glyphs in the font
    let maxPoints            : UInt16 // points in non-compound glyph
    let maxContours          : UInt16 // contours in non-compound glyph
    let maxComponentPoints   : UInt16 // points in compound glyph
    let maxComponentContours : UInt16 // contours in compound glyph
    let maxZones             : UInt16 // set to 2
    let maxTwilightPoints    : UInt16 // points used in Twilight Zone (Z0)
    let maxStorage           : UInt16 // number of Storage Area locations
    let maxFunctionDefs      : UInt16 // number of FDEFs
    let maxInstructionDefs   : UInt16 // number of IDEFs
    let maxStackElements     : UInt16 // maximum stack depth
    let maxSizeOfInstructions: UInt16 // byte count for glyph instructions
    let maxComponentElements : UInt16 // number of glyphs referenced at top level
    let maxComponentDepth    : UInt16 // levels of recursion, set to 0 if font has only simple glyphs
}

struct TTGLYFTable {
    struct GlyfTableItem {
        let numberOfContours: Int16
        let xMin: Int16
        let yMin: Int16
        let xMax: Int16
        let yMax: Int16
        //TODO: Glyph Data
    }
    let items:[GlyfTableItem] // indexed by glyphId
}

struct TTLOCATable {
    enum Offsets {
        case short(offsets: [UInt16])
        case long(offsets: [UInt32])
    }
    let offsets: Offsets
}

struct TTCMAPTable {
    struct Index {
        let version         : UInt16 // Version number (Set to zero)
        let numberSubtables : UInt16 // Number of encoding subtables
    }

    struct EncodingSubtableIndex {
        let platformId         : UInt16 // Platform identifier
        let platformSpecificID : UInt16 // Platform-specific encoding identifier
        let offset             : UInt32 // Offset of the mapping table

        var encoding: SubtableEncoding {
            switch PlatformId(rawValue: platformId) {
            case .unicode?:
                return .unicode(id: UnicodePlatformSpecificID(rawValue:platformSpecificID) ?? .defaultSemantic)
            case .macintosh?:
                return .macintosh(quickDrawScriptCode: platformSpecificID)
            case .reserved?:
                return .reserved
            case .microsoft?:
                return .microsoft(id: WindowPlatformSpecificID(rawValue: platformSpecificID) ?? .symbol)
            default:
                return .unknown
            }
        }

        enum SubtableEncoding {
            case unknown
            case unicode(id: UnicodePlatformSpecificID)
            case macintosh(quickDrawScriptCode: UInt16)
            case reserved
            case microsoft(id: WindowPlatformSpecificID)
        }

        enum PlatformId: UInt16 {
            case unicode    = 0
            case macintosh  = 1
            case reserved   = 2 // do not use
            case microsoft  = 3
        }

        enum UnicodePlatformSpecificID: UInt16 {
            case defaultSemantic           = 0 // Default semantics
            case version1dot1Semantic      = 1 // Version 1.1 semantics
            case iso10646                  = 2 // ISO 10646 1993 semantics (deprecated)
            case unicode2BMP               = 3 // Unicode 2.0 or later semantics (BMP only)
            case unicode2NonBMP            = 4 // Unicode 2.0 or later semantics (non-BMP characters allowed)
            case unicodeVariationSequences = 5 // Unicode Variation Sequences
            case fullUnicodeCoverage       = 6 // Full Unicode coverage (used with type 13.0 cmaps by OpenType)
        }

        enum WindowPlatformSpecificID: UInt16 {
            case symbol     = 0 // Symbol
            case ucs2       = 1 // Unicode BMP-only (UCS-2)
            case shiftJIS   = 2 // Shift-JIS
            case prc        = 3 // PRC
            case bigFive    = 4 // BigFive
            case johab      = 5 // Johab
            case ucs4       = 6 // Unicode UCS-4
        }
    }

    enum Subtable {
        case format0(subtable: TTCMapSubtableFormat0)
        case format2(subtable: TTCMapSubtableFormat2)
        case format4(subtable: TTCMapSubtableFormat4)
        case format6(subtable: TTCMapSubtableFormat6)
        case format8(subtable: TTCMapSubtableFormat8)
        case format10(subtable: TTCMapSubtableFormat10)
        case format12Or13(subtable: TTCMapSubtableFormat12Or13)
        case format14(subtable: TTCMapSubtableFormat14)
    }

    let index: Index
    let subtableIndexes : [EncodingSubtableIndex]
    let subtables: [Subtable]
    let preferedSubtable: (index:Int, subtableIndex:EncodingSubtableIndex)?
}
