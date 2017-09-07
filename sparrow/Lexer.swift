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
    var lastToken: Token = Token(.whitespace, "")
    
    init(_ source: String) {
        scanner = Scanner(source)
    }
    
    func next() -> Token {
        lastToken = lexToken()
        return lastToken
    }
    
    func lexToken() -> Token {
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
        

        case _ where c.isIdentifierHead:
            return identifier()

        case "$": return dollarIdent()
        
        case _ where c.isDigit:
            return number()
        
        case "`": return escapedIdentifier()
            
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
    
    func identifier() -> Token {
        scanner.putback()
        let start = scanner.current
        
        _ = scanner.match { $0.isIdentifierHead }
        scanner.skip { $0.isIdentifierBody }
        
        let text = scanner.text(from: start)
        let kind = Token.Kind(keyword: text) ?? .identifier
        return formToken(kind, with: text)
    }
    
    func dollarIdent() -> Token {
        scanner.putback()
        let start = scanner.current
        
        _ = scanner.match("$")
        
        var isAllDigits = true
        scanner.skip {
            if $0.isDigit {
                return true
            } else if ($0.isClangIdentifierHead || $0 == "$") {
                isAllDigits = false
                return true
            } else {
                return false
            }
        }
        
        let text = scanner.text(from: start)
        
        if text.count == 1 {
            // FIXME: diagnose standalone dollar identifier and offer fix it to replace $ with `$`
            return formToken(.identifier, with: text)
        }
        
        if !isAllDigits {
            // FIXIT: diagnose expected dollar numeric
            
            // Even if we diagnose, we go ahead and form an identifier token,
            // in part to ensure that the basic behavior of the lexer is
            // independent of language mode.
            return formToken(.identifier, with: text)
        } else {
            return formToken(.dollarIdent, with: text)
        }
    }
    
    enum ExpectedDigitKind {
        case binary, octal, decimal, hex
    }

    func hexNumber() -> Token {
        let start = scanner.current
        
        func expectedDigit() -> Token {
            scanner.skip { $0.isIdentifierBody }
            return formToken(.unknown, from: start)
        }
        
        func expectedHexDigit() -> Token {
            // FIXME: diagnose invalid digit in int literal
            return expectedDigit()
        }
        
        scanner.advance() // skip over 0
        scanner.advance() // skip over x
        
        // 0x[0-9a-fA-F][0-9a-fA-F_]*
        if !scanner.match({ $0.isHexDigit }) {
            return expectedHexDigit()
        }
        
        scanner.skip { $0.isHexDigit || $0 == "_" }
        
        if scanner.peek != "." && scanner.peek != "p" && scanner.peek != "P" {
            if scanner.match({ $0.isIdentifierBody }) {
                return expectedHexDigit()
            }
            
            return formToken(.integerLiteral, from: start)
        }
        
        var maybeOnDot: Scanner?
        
        // (\.[0-9A-Fa-f][0-9A-Fa-f_]*)?
        if scanner.peek == "." {
            maybeOnDot = scanner
            let onDot = scanner
            
            scanner.advance() // over the "."
            
            // If the character after the '.' is not a digit, assume we have an int
            // literal followed by a dot expression.
            if !scanner.peek.isHexDigit {
                scanner.putback()
                return formToken(.integerLiteral, from: start)
            }
            
            scanner.skip { $0.isHexDigit || $0 == "_" }
            
            if scanner.peek != "p" && scanner.peek != "P" {
                if !onDot.peekNext.isDigit {
                    // e.g: 0xff.description
                    scanner = onDot
                    return formToken(.integerLiteral, from: start)
                }
                
                // FIXME: diagnose expected binary exponent in hex flaot literal
                return formToken(.unknown, from: start)
            }
        }
        
        // [pP][+-]?[0-9][0-9_]*
        scanner.advance() // skip over p or P
        
        let signedExponent = scanner.match({ $0 == "+" || $0 == "-" })
        
        if !scanner.peek.isDigit {
            if let onDot = maybeOnDot, !onDot.peekNext.isDigit && !signedExponent {
                // e.g: 0xff.fpValue, 0xff.fp
                scanner = onDot
                return formToken(.integerLiteral, from: start)
            }
            // Note: 0xff.fp+otherExpr can be valid expression. But we don't accept it.
            
            // There are 3 cases to diagnose if the exponent starts with a non-digit:
            // identifier (invalid character), underscore (invalid first character),
            // non-identifier (empty exponent)
            if scanner.match({ $0.isIdentifierBody }) {
                // FIXME: diagnose invalid digit in fp exponent
                return expectedDigit()
            } else {
                // FIXME: diagnose expected digit in fp exponent
                return expectedDigit()
            }
        }
        
        scanner.skip { $0.isDigit || $0 == "_" }
        
        if scanner.match({ $0.isIdentifierBody }) {
            // FIXME: diagnose invalid digit in fp exponent
            return expectedDigit()
        }
        
        return formToken(.floatingLiteral, from: start)
    }
    
    // integer_literal  ::= [0-9][0-9_]*
    // integer_literal  ::= 0x[0-9a-fA-F][0-9a-fA-F_]*
    // integer_literal  ::= 0o[0-7][0-7_]*
    // integer_literal  ::= 0b[01][01_]*
    // floating_literal ::= [0-9][0-9]_*\.[0-9][0-9_]*
    // floating_literal ::= [0-9][0-9]*\.[0-9][0-9_]*[eE][+-]?[0-9][0-9_]*
    // floating_literal ::= [0-9][0-9_]*[eE][+-]?[0-9][0-9_]*
    // floating_literal ::= 0x[0-9A-Fa-f][0-9A-Fa-f_]*
    //                        (\.[0-9A-Fa-f][0-9A-Fa-f_]*)?[pP][+-]?[0-9][0-9_]*
    func number() -> Token {
        scanner.putback()
        let start = scanner.current
        
        func expectedDigit() -> Token {
            scanner.skip { $0.isIdentifierBody }
            return formToken(.unknown, from: start)
        }
        
        func expectedIntDigit(_ digitKind: ExpectedDigitKind) -> Token {
            // FIXME: diagnose invalid digit in int literal
            return expectedDigit()
        }
        
        if scanner.peek == "0" && scanner.peekNext == "x" {
            return hexNumber()
        }
        
        if scanner.peek == "0" && scanner.peekNext == "o" {
            // 0o[0-7][0-7_]*
            scanner.advance() // advance over "0"
            scanner.advance() // advance over "o"
            
            if scanner.peek < "0" || scanner.peek > "7" {
                return expectedIntDigit(.octal)
            }
            
            scanner.skip { ($0 >= "0" && $0 <= "7") || $0 == "_" }
            
            if scanner.match({ $0.isIdentifierBody }) {
                return expectedIntDigit(.octal)
            }
            
            return formToken(.integerLiteral, from: start)
        }

        if scanner.peek == "0" && scanner.peekNext == "b" {
            // 0b[01][01_]*
            scanner.advance() // advance over "0"
            scanner.advance() // advance over "b"
            
            if scanner.peek != "0" && scanner.peek != "1" {
                return expectedIntDigit(.binary)
            }
            
            scanner.skip(over: ["0", "1", "_"])
            
            if scanner.match({ $0.isIdentifierBody }) {
                return expectedIntDigit(.octal)
            }
            
            return formToken(.integerLiteral, from: start)
        }

        // Handle a leading [0-9]+, lexing an integer or falling through if we have a
        // floating point value.
        scanner.skip { $0.isDigit || $0 == "_" }

        // Lex things like 4.x as '4' followed by a .period.
        if scanner.peek == "." {
            // NextToken is the soon to be previous token
            // Therefore: x.0.1 is sub-tuple access, not x.floatLiteral
            if !scanner.peekNext.isDigit || lastToken.kind == .period {
                return formToken(.integerLiteral, from: start)
            }
        } else {
            // Floating literals must have '.', 'e', or 'E' after digits.  If it is
            // something else, then this is the end of the token.
            if scanner.peek != "e" && scanner.peek != "E" {
                if scanner.match({ $0.isIdentifierBody }) {
                    return expectedIntDigit(.octal)
                }
                
                return formToken(.integerLiteral, from: start)
            }
        }
        
        // Lex decimal point.
        if scanner.match(".") {
            scanner.skip { $0.isDigit || $0 == "_" }
        }
        
        // Lex exponent.
        if scanner.match({ $0 == "e" || $0 == "E" }) {
            _ = scanner.match({ $0 == "+" || $0 == "-" })
            
            if !scanner.peek.isDigit {
                // FIXME: diagnose invalid digit in fp exponent or expected digit in fp exponent
                return expectedDigit()
            }
            
            scanner.skip { $0.isDigit || $0 == "_" }
            
            if scanner.match({ $0.isIdentifierBody }) {
                // FIXME: diagnose invalid digit in fp exponent
                return expectedDigit()
            }
        }
        
        return formToken(.floatingLiteral, from: start)
    }
    
    func escapedIdentifier() -> Token {
        scanner.putback()
        let quote = scanner.current
        scanner.advance()
        
        if scanner.match({ $0.isIdentifierHead }) {
            scanner.skip { $0.isIdentifierBody }
            
            // If we have the terminating "`", it's an escaped identifier.
            if scanner.match("`") {
                // FIXME: mark it as an escaped identifier?
                return formToken(.identifier, from: quote)
            }
        }
        
        // Special case; allow '`$`'.
        if scanner.peek == "$" && scanner.peekNext == "`" {
            scanner.advance() // advance over "$"
            scanner.advance() // advance over "`"
            
            // FIXME: mark it as an escaped identifier?
            return formToken(.identifier, from: quote)
        }
        
        // The backtick is punctuation.
        return formToken(.backtick, from: quote)
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
