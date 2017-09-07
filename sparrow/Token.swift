//
//  Token.swift
//  sparrow
//
//  Created by Ahmad Alhashemi on 2017-09-02.
//  Copyright © 2017 Ahmad Alhashemi. All rights reserved.
//

struct Token {
    enum Kind {
        case `associatedtype`
        case `class`
        case `deinit`
        case `enum`
        case `extension`
        case `func`
        case `import`
        case `_init` // we can't use init as that conflicts with Kind's initializers
        case `inout`
        case `let`
        case `operator`
        case `precedencegroup`
        case `protocol`
        case `struct`
        case `subscript`
        case `typealias`
        case `var`
        case __shared
        case __owned

        case `fileprivate`
        case `internal`
        case `private`
        case `public`
        case `static`
        
        case `defer`
        case `if`
        case `guard`
        case `do`
        case `repeat`
        case `else`
        case `for`
        case `in`
        case `while`
        case `return`
        case `break`
        case `continue`
        case `fallthrough`
        case `switch`
        case `case`
        case `default`
        case `where`
        case `catch`
        
        case `as`
        case `Any`
        case `false`
        case `is`
        case `nil`
        case `rethrows`
        case `super`
        case `self`
        case `Self`
        case `throw`
        case `true`
        case `try`
        case `throws`
        case `__FILE__`
        case `__LINE__`
        case `__COLUMN__`
        case `__FUNCTION__`
        case `__DSO_HANDLE__`
        
        case `_`
        
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
        
        case backtick
        
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
        
        case integerLiteral
        case floatingLiteral
        case stringLiteral
        
        case identifier
        case dollarIdent
        
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

extension Token.Kind {
    init?(keyword: String) {
        switch keyword {
        case "associatedtype": self = .associatedtype
        case "class": self = .class
        case "deinit": self = .deinit
        case "enum": self = .enum
        case "extension": self = .extension
        case "func": self = .func
        case "import": self = .import
        case "init": self = ._init
        case "inout": self = .inout
        case "let": self = .let
        case "operator": self = .operator
        case "precedencegroup": self = .precedencegroup
        case "protocol": self = .protocol
        case "struct": self = .struct
        case "subscript": self = .subscript
        case "typealias": self = .typealias
        case "var": self = .var
        case "__shared": self = .__shared
        case "__owned": self = .__owned
        
        case "fileprivate": self = .fileprivate
        case "internal": self = .internal
        case "private": self = .private
        case "public": self = .public
        case "static": self = .static
        
        case "defer": self = .defer
        case "if": self = .if
        case "guard": self = .guard
        case "do": self = .do
        case "repeat": self = .repeat
        case "else": self = .else
        case "for": self = .for
        case "in": self = .in
        case "while": self = .while
        case "return": self = .return
        case "break": self = .break
        case "continue": self = .continue
        case "fallthrough": self = .fallthrough
        case "switch": self = .switch
        case "case": self = .case
        case "default": self = .default
        case "where": self = .where
        case "catch": self = .catch
        
        case "as": self = .as
        case "Any": self = .Any
        case "false": self = .false
        case "is": self = .is
        case "nil": self = .nil
        case "rethrows": self = .rethrows
        case "super": self = .super
        case "self": self = .self
        case "Self": self = .Self
        case "throw": self = .throw
        case "true": self = .true
        case "try": self = .try
        case "throws": self = .throws
        case "__FILE__": self = .__FILE__
        case "__LINE__": self = .__LINE__
        case "__COLUMN__": self = .__COLUMN__
        case "__FUNCTION__": self = .__FUNCTION__
        case "__DSO_HANDLE__": self = .__DSO_HANDLE__
        case "_": self = ._
        default: return nil
        }
    }
}
