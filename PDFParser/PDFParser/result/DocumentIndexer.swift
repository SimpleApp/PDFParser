//
//  DocumentIndexBuilder.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 27/06/2018.
//

import Foundation
import CoreGraphics

//DocumentIndexBuilder Manages the creation of a document index.

public protocol DocumentIndexer: class {
    func beginNewPage(pageNumber: Int, pageSize: CGSize)
    func didScanTextBlock(_ textBlock: TextBlock)
}

