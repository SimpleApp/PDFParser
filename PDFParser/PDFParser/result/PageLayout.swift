//
//  Layout.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 27/06/2018.

import Foundation

public class PageLayout {

}

public class UnknownLayout: PageLayout {

}

public class SingleColumnLayout: PageLayout {

}


public class PageLayoutPicker {
    func layout(forPage pageNumber:Int ) -> PageLayout {
        return SingleColumnLayout()
    }
}
