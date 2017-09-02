//
//  Scanner.swift
//  sparrow
//
//  Created by Ahmad Alhashemi on 2017-09-01.
//  Copyright © 2017 Ahmad Alhashemi. All rights reserved.
//

struct Scanner {
    private let source: String
    private(set) var current: String.UnicodeScalarIndex
    
    func text(from start: String.UnicodeScalarIndex) -> String {
        return String(source.unicodeScalars[start..<current])
    }
    
    var isAtEnd: Bool {
        return current >= source.unicodeScalars.endIndex
    }
    
    var peek: UnicodeScalar {
        if isAtEnd { return "\0" }
        return source.unicodeScalars[current]
    }
    
    var peekNext: UnicodeScalar {
        let next = source.unicodeScalars.index(after: current)
        if next >= source.unicodeScalars.endIndex { return "\0" }
        return source.unicodeScalars[next]
    }
    
    init(_ source: String) {
        self.source = source
        self.current = source.unicodeScalars.startIndex
    }
    
    @discardableResult mutating func advance() -> UnicodeScalar {
        let result = peek
        current = source.unicodeScalars.index(after: current)
        return result
    }
    
    mutating func match(_ expected: UnicodeScalar) -> Bool {
        if isAtEnd { return false }
        if peek != expected { return false }
        
        advance()
        return true
    }
    
    mutating func skip(over skippable: Set<UnicodeScalar>) {
        while !isAtEnd && skippable.contains(peek) { advance() }
    }
    
    mutating func skip(while filter: (UnicodeScalar) -> Bool) {
        while !isAtEnd && filter(peek) { advance() }
    }
}
