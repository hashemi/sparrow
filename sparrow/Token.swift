//
//  Token.swift
//  sparrow
//
//  Created by Ahmad Alhashemi on 2017-09-02.
//  Copyright © 2017 Ahmad Alhashemi. All rights reserved.
//

struct Token {
    enum Kind {
        case whitespace
        case comment

        case poundIf
        case poundElse
        case poundElseif
        case poundEndif
        case poundKeyPath
        case poundLine
        case poundSourceLocation
        case poundSelector
        case poundFile
        case poundColumn
        case poundFunction
        case poundDsohandle

        case lParen
        case rParen
        case lBrace
        case rBrace
        case lSquare
        case rSquare
        
        case comma
        case colon
        case semi
        case atSign
        case pound
        
        case backslash
        
        case equal
        case ampPrefix
        case period
        case periodPrefix
        case exclaimPostfix
        case questionPostfix
        case questionInfix
        case arrow
        case operBinaryUnspaced
        case operBinarySpaced
        case operPostfix
        case operPrefix
        
        case eof
        case unknown
    }
    
    let kind: Kind
    let isFirstInLine: Bool
    let text: String
    
    init(_ kind: Kind, _ text: String, isFirstInLine: Bool = false) {
        self.kind = kind
        self.text = text
        self.isFirstInLine = isFirstInLine
    }
}

extension Token: CustomStringConvertible {
    var description: String {
        return "\(kind)(\"\(text)\")"
    }
}
