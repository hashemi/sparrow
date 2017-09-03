//
//  Lexer.swift
//  sparrow
//
//  Created by Ahmad Alhashemi on 2017-09-02.
//  Copyright © 2017 Ahmad Alhashemi. All rights reserved.
//

class Lexer {
    var scanner: Scanner
    var firstInLine: Bool = true
    
    init(_ source: String) {
        scanner = Scanner(source)
    }
    
    func next() -> Token {
        guard !scanner.isAtEnd else {
            return Token(.eof, "", isFirstInLine: firstInLine)
        }
        
        let start = scanner.current
        
        let c = scanner.advance()
        
        switch c {
        case "\n": fallthrough
        case "\r":
            firstInLine = true
            return whitespace()
        case _ where c.isWhitespace: return whitespace()
        
        case "@": return formToken(.atSign, from: start)
        case "{": return formToken(.lBrace, from: start)
        case "[": return formToken(.lSquare, from: start)
        case "(": return formToken(.lParen, from: start)
        case "}": return formToken(.rBrace, from: start)
        case "]": return formToken(.rSquare, from: start)
        case ")": return formToken(.rParen, from: start)
        case ",": return formToken(.comma, from: start)
        case ";": return formToken(.semi, from: start)
        case ":": return formToken(.colon, from: start)
        case "\\": return formToken(.backslash, from: start)
        
        case "#": return hash()
            
        case "/" where scanner.match("/"):
            skipSlashSlashComment()
            return Token(.comment, "")
        
        case "/" where scanner.match("*"):
            skipSlashStarComment()
            return Token(.comment, "")
        
        default: return formToken(.unknown, from: start)
        }
        
    }
    
    func whitespace() -> Token {
        let newlineScalars: Set<UnicodeScalar> = ["\n", "\r"]
        while !scanner.isAtEnd && scanner.peek.isWhitespace {
            if newlineScalars.contains(scanner.advance()) {
                firstInLine = true
            }
        }
        return Token(.whitespace, "")
    }
    
    func hash() -> Token {
        // Allow a hashbang #! line at the beginning of the file.
        scanner.putback()
        let beforePound = scanner.current
        if scanner.isAtStart && scanner.peekNext == "!" {
            skipHashbang()
            return next()
        }
        scanner.advance()
        
        let afterPound = scanner.current
        
        // Scan for [a-zA-Z]+ to see what we match.
        if scanner.peek.isClangIdentifierHead {
            scanner.advance()
            scanner.skip { $0.isClangIdentifierBody }
        }
        
        let identifier = scanner.text(from: afterPound)
        
        // If we found something specific, we will return it.
        switch identifier {
        case "if": return formToken(.poundIf, from: beforePound)
        case "else": return formToken(.poundElse, from: beforePound)
        case "elseif": return formToken(.poundElseif, from: beforePound)
        case "endif": return formToken(.poundEndif, from: beforePound)
        case "keyPath": return formToken(.poundKeyPath, from: beforePound)
        case "line": return formToken(.poundLine, from: beforePound)
        case "sourceLocation": return formToken(.poundSourceLocation, from: beforePound)
        case "selector": return formToken(.poundSelector, from: beforePound)
        case "file": return formToken(.poundFile, from: beforePound)
        case "column": return formToken(.poundColumn, from: beforePound)
        case "function": return formToken(.poundFunction, from: beforePound)
        case "dsohandle": return formToken(.poundDsohandle, from: beforePound)
        default:
            // Otherwise, unwind the parser to identifier found and just return a .pound token.
            scanner.rewind(to: beforePound)
            scanner.advance() // over the pound
            return formToken(.pound, from: beforePound)
        }
    }
    
    func skipToEndOfLine() {
        while !scanner.isAtEnd {
            switch scanner.advance() {
            case "\n": fallthrough
            case "\r":
                firstInLine = true
                return
            default: break
            }
        }
    }
    
    func skipHashbang() {
        skipToEndOfLine()
    }
    
    func skipSlashSlashComment() {
        skipToEndOfLine()
    }
    
    func skipSlashStarComment() {
        var depth: UInt = 1
        
        while !scanner.isAtEnd {
            switch scanner.advance() {
            case "*" where scanner.match("/"):
                depth -= 1
                if depth == 0 { return }
            case "/" where scanner.match("*"):
                depth += 1

            case "\n": fallthrough
            case "\r": firstInLine = true
            
            default: break
            }
        }
        
        // unterminated slash star comment at eof
    }
    
    func formToken(_ kind: Token.Kind, from start: String.UnicodeScalarIndex) -> Token {
        let token = Token(kind, scanner.text(from: start), isFirstInLine: firstInLine)
        if token.kind != .whitespace {
            firstInLine = false
        }
        return token
    }
}
