//
//  TrueTypeCMAPFormat.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 20/07/2018.
//

import Foundation

//MARK: - CMAP Subtables in all formats
/*
 As specification mentions:
 Many of the cmap formats are either obsolete or were designed to meet anticipated needs which never materialized. Modern font generation tools need not be able to write general-purpose cmaps in formats other than 4, 6, and 12. Formats 13 and 14 are both for specialized uses. Of the two, only support for format 14 is likely to be needed

    So, implementation will focus on formats 4, 6 and 12.

 */
struct TTCMapSubtableFormat0 {
    let format          : UInt16 // Set to 0
    let length          : UInt16 // Length in bytes of the subtable (set to 262 for format 0)
    let language        : UInt16  // Language code (see above)
    let glyphIndexArray : [UInt8] // [256] array that maps character codes to glyph index values
}
struct TTCMapSubtableFormat2 {

    struct SubHeader {
        let firstCode     : UInt16
        let entryCode     : UInt16
        let idDelta       : UInt16
        let idRangeOffset : UInt16
    }

    let format          : UInt16  // Set to 2
    let length          : UInt16  // Length in bytes
    let language        : UInt16  // Language code (see above)

    let subHeaderKeys   : [UInt16] // [256] array that maps high bytes to subHeaders: value is index * 8
    let subHeaders      : [SubHeader] // Variable length array of subHeader structures
    let glyphIndexArray : [UInt16] // Variable length array containing subarrays
}

struct TTCMapSubtableFormat4 {
    let format          : UInt16 // Set to 4
    let length          : UInt16 // Length in bytes
    let language        : UInt16 // Language code (see above)

    let segCountX2      : UInt16 // 2 * segCount
    let searchRange     : UInt16 // 2 * (2**FLOOR(log2(segCount)))
    let entrySelector   : UInt16 // log2(searchRange/2)
    let rangeShift      : UInt16 // 2 * segCount) - searchRange
    var endCode         : [UInt16] // Ending character code for each segment, last = 0xFFFF.
    var reservedPad     : UInt16 // This value should be zero
    var startCode       : [UInt16] // Starting character code for each segment
    var idDelta         : [UInt16] // Delta for all character codes in segment
    var idRangeOffset   : [UInt16] // Offset in bytes to glyph indexArray, or 0
    var glyphIndexArray : [UInt16] // Glyph index array
}

struct TTCMapSubtableFormat6 {
    let format          : UInt16 // Set to 6
    let length          : UInt16 // Length in bytes of the subtable (set to 262 for format 0)
    let language        : UInt16  // Language code (see above)

    let firstCode       : UInt16 // First character code of subrange
    let entryCount      : UInt16 // Number of character codes in subrange
    var glyphIndexArray : [UInt16] // Array of glyph index values for character codes in the range
}

struct TTCMapSubtableFormat8 {
    struct Group {
        let startCharCode  : UInt32
        let endCharCode    : UInt32
        let startGlyphCode : UInt32
    }

    let format        : UInt16 // Set to 8
    let formatPadding : UInt16 // Always 0
    let length        : UInt32 // Length in bytes of the subtable (set to 262 for format 0)
    let language      : UInt32  // Language code (see above)

    let is32          : [UInt8] //[65536] Tightly packed array of bits (8K bytes total) indicating whether the particular 16-bit (index) value is the start of a 32-bit character code
    let nGroups       :  UInt32
    let groups        : [Group]
}


//RARE format. Not supported.
struct TTCMapSubtableFormat10 {
    let format          : UInt16 // Set to 10
    let formatPadding   : UInt16 // Always 0
    let length          : UInt32 // Length in bytes of the subtable (set to 262 for format 0)
    let language        : UInt32  // Language code (see above)
    let startCharCode   : UInt32  // First character code covered
    let numChars        : UInt32  // Number of character codes covered
    let glyphs          : [UInt16] // Array of glyph indices for the character codes covered
}

/*
 - Format 12.0 is required for Unicode fonts covering characters above U+FFFF on Windows. It is the most useful of the cmap formats with 32-bit support.
 - Format 13.0 is a modified version of the type 12.0 'cmap' subtable, used internally by Apple for its LastResort font. It would, in general, not be appropriate for any font other than a last resort font.
 */
struct TTCMapSubtableFormat12Or13 {
    struct Group {
        let startCharCode  : UInt32
        let endCharCode    : UInt32
        let startGlyphCode : UInt32
    }
    let format        : UInt16 // Set to 12 or 13
    let formatPadding : UInt16 // Always 0
    let length        : UInt32 // Length in bytes of the subtable (set to 262 for format 0)
    let language      : UInt32  // Language code (see above)

    let nGroups       : UInt32 // Number of groupings which follow
    var groups        : [Group]
}

struct TTCMapSubtableFormat14 {
    struct Header {
        let format               : UInt16
        let length               : UInt32
        let numVarSelectorRecords: UInt32 //Number of variation Selector Records
        let selectorRecords      : [VariationSelectorRecord]
    }
    struct VariationSelectorRecord {
        let varSelector         : UInt24 // Variation selector
        let defaultUVSOffset    : UInt32 // Offset to Default UVS Table. May be 0.
        let nonDefaultUVSOffset : UInt32 // Offset to Non-Default UVS Table. May be 0.
    }
    struct DefaultUVSTable {
        struct UnicodeValueRange {
            let startUnicodeValue : UInt24 // First value in this range
            let additionalCount   : UInt8  // Number of additional values in this range
        }
        let numUnicodeValueRanges : UInt32
        let valueRanges           : [UnicodeValueRange]
    }

    struct NonDefaultUVSTable {
        struct UVSMapping {
            let unicodeValue : UInt24
            let glyphID      : UInt16
        }

        let numUVSMappings : UInt32
        let uvsMappings    : [UVSMapping]
    }
}
