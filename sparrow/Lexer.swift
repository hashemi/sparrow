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
        
        case "!" where isLeftBound(before: start):
            return formToken(.exclaimPostfix, from: start)
        case "!":
            return operatorIdentifier()
        
        case "?" where isLeftBound(before: start):
            return formToken(.questionPostfix, from: start)
        case "?":
            return operatorIdentifier()
        
        case "/": fallthrough
        case "%": fallthrough
        case "<": fallthrough
        case ">": fallthrough
        case "=": fallthrough
        case "-": fallthrough
        case "+": fallthrough
        case "*": fallthrough
        case "&": fallthrough
        case "|": fallthrough
        case "^": fallthrough
        case "~": fallthrough
        case ".":
            return operatorIdentifier()
        
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
    
    func isLeftBound(before start: String.UnicodeScalarIndex) -> Bool {
        // don't mess with original scanner
        var scanner = self.scanner
        
        scanner.rewind(to: start)
        
        if scanner.isAtStart { return false }
        
        scanner.putback()
        switch scanner.peek {
        case " ": fallthrough
        case "\r": fallthrough
        case "\n": fallthrough
        case "\t": fallthrough // whitespace
        case "(": fallthrough
        case "[": fallthrough
        case "{": fallthrough // opening delimiters
        case ",": fallthrough
        case ";": fallthrough
        case ":": fallthrough // expression separators
        case "\0": // whitespace / last char in file
            return false
            
        case "/":
            if scanner.isAtStart { return true }
            scanner.putback()
            return scanner.peek != "*" // End of a slash-star comment, so whitespace.
        
        default: return true
        }
    }
    
    func isRightBound(after: String.UnicodeScalarIndex, isLeftBound: Bool) -> Bool {
        // don't mess with original scanner
        var scanner = self.scanner
        
        scanner.rewind(to: after)
        
        switch scanner.peek {
        case " ": fallthrough
        case "\r": fallthrough
        case "\n": fallthrough
        case "\t": fallthrough // whitespace
        case ")": fallthrough
        case "]": fallthrough
        case "}": fallthrough // closing delimiters
        case ",": fallthrough
        case ";": fallthrough
        case ":": fallthrough // expression separators
        case "\0": // whitespace / last char in file
            return false
        
        case ".":
            // Prefer the '^' in "x^.y" to be a postfix op, not binary, but the '^' in
            // "^.y" to be a prefix op, not binary.
            return !isLeftBound
            
        case "/" where (scanner.peekNext == "/" || scanner.peekNext == "*"):
            return false
            
        default:
            return true
        }
    }
    
    func operatorIdentifier() -> Token {
        scanner.putback()
        let start = scanner.current
        let canHavePeriods = scanner.peek == "."
        
        _ = scanner.match { $0.isOperatorHead }
        
        scanner.skip {
            if !$0.isOperatorBody { return false }
            if $0 == "." && !canHavePeriods { return false }

            // If there is a "//" or "/*" in the middle of an identifier token,
            // it starts a comment.
            if $0 == "/" && ($1 == "/" || $1 == "*") { return false }
            
            return true
        }
        
        let leftBound = isLeftBound(before: start)
        let rightBound = isRightBound(after: scanner.current, isLeftBound: leftBound)
        
        let text = scanner.text(from: start)
        switch text {
        case "=":
            // FIXME: if leftBound != rightBound then make a fix it suggestion
            // add a space where it isn't bound
            return formToken(.equal, with: text)
        case "&" where !(leftBound == rightBound || leftBound):
            return formToken(.ampPrefix, with: text)
        case "." where leftBound == rightBound:
            return formToken(.period, with: text)
        case "." where rightBound:
            return formToken(.periodPrefix, with: text)
        case ".":
            // If left bound but not right bound because there is just some horizontal
            // whitespace before the next token, its addition is probably incorrect.
            var afterHorzWhitespace = scanner
            afterHorzWhitespace.skip(over: [" ", "\t"])
            if isRightBound(after: afterHorzWhitespace.current, isLeftBound: leftBound)
                // Don't consider comments to be this.  A leading slash is probably
                // either // or /* and most likely occurs just in our testsuite for
                // expected-error lines.
                && afterHorzWhitespace.peek != "/" {
                // FIXME: make a fixit suggestion to remove whitespace between
                // the "." and the end of horizontal whitespace
                return formToken(.period, with: text)
            }
            // Otherwise, it is probably a missing member.
            // FIXME: diagnose expected member name
            return formToken(.unknown, from: start)
        case "?" where leftBound:
            return formToken(.questionPostfix, with: text)
        case "?" where !leftBound:
            return formToken(.questionInfix, with: text)
        case "->": return formToken(.arrow, with: text)
        case "*/":
            // FIXME: diagnose unexpeceted block comment end
            return formToken(.unknown, with: text)
        case _ where text.count > 2:
            var finder = Scanner(text)
            finder.skip { $0 != "*"}
            if finder.peekNext == "/" {
                // FIXME: diagnose unexpeceted block comment end
                return formToken(.unknown, with: text)
            }
        default: break
        }
        
        switch (leftBound, rightBound) {
        case (true, true):
            return formToken(.operBinaryUnspaced, with: text)
        case (false, false):
            return formToken(.operBinarySpaced, with: text)
        case (true, false):
            return formToken(.operPostfix, with: text)
        case (false, true):
            return formToken(.operPrefix, with: text)
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
        return formToken(kind, with: scanner.text(from: start))
    }
    
    func formToken(_ kind: Token.Kind, with text: String) -> Token {
        let token = Token(kind, text, isFirstInLine: firstInLine)
        if token.kind != .whitespace {
            firstInLine = false
        }
        return token
    }
}
