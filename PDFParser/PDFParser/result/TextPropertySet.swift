//
//  TextPropertySet.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 27/06/2018.

import Foundation

public struct TextPropertySet {
    private(set) var properties = [TextProperty]()
    mutating func insert(_ tp: TextProperty) {
        for p in properties {
            if p.isSamePropertyAs(tp) { return }
        }
        properties.append(tp)
    }
    mutating func update(_ tp: TextProperty) {
        properties = properties.map {
            if $0.isSamePropertyAs(tp){ return tp }
            else { return $0 } }
    }
    public init(){}
}


extension TextPropertySet {
    init(renderingState: PDFRenderingState) {
        
    }
}
