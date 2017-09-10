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
    var lastToken: Token?
    
    init(_ source: String) {
        scanner = Scanner(source)
    }
    
    func next() -> Token {
        let token = lexToken()
        lastToken = token
        return token
    }
    
    func lexToken() -> Token {
        guard !scanner.isAtEnd else {
            return formToken(.eof, with: "")
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
            return lexToken()
        
        case "/" where scanner.match("*"):
            skipSlashStarComment()
            return lexToken()
        
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
            
        case "\"": fallthrough
        case "'": return string()
        
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
        return lexToken()
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
            if !scanner.peekNext.isDigit || lastToken?.kind == .period {
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
    
    struct CharValue: Equatable {
        private let value: UInt32
        
        static let error = CharValue(UInt32.max - 1)
        static let end = CharValue(UInt32.max)
        
        init(_ value: UInt32) {
            self.value = value
        }
        
        init(_ scalar: UnicodeScalar) {
            self.value = scalar.value
        }
        
        var scalar: UnicodeScalar? {
            return UnicodeScalar(value)
        }
        
        static func ==(lhs: Lexer.CharValue, rhs: Lexer.CharValue) -> Bool {
            return lhs.value == rhs.value
        }
    }
    
    /// lexStringLiteral:
    ///   string_literal ::= ["]([^"\\\n\r]|character_escape)*["]
    ///   string_literal ::= ["]["]["].*["]["]["] - approximately
    func string() -> Token {
        scanner.putback()
        let start = scanner.current
        let stopQuote = scanner.advance()

        // NOTE: We only allow single-quote string literals so we can emit useful
        // diagnostics about changing them to double quotes.

        var wasErroneous = false
        var multiline = false
        
        // Is this the start of a multiline string literal?
        if stopQuote == "\"" && scanner.peek == "\"" && scanner.peekNext == "\"" {
            multiline = true
            scanner.advance()
            scanner.advance()
            
            if scanner.peek != "\n" && scanner.peek != "\r" {
                // FIXME: diagnose illegal multiline string start, fixit: insert \n
            }
        }
        
        while true {
            if scanner.peek == "\\" && scanner.peekNext == "(" {
                scanner.advance() // skip the "\"
                scanner.advance() // skip the "("
                // Consume tokens until we hit the corresponding ')'.
                skipToEndOfInterpolatedExpression(multiline)
                
                if !scanner.match(")") {
                    wasErroneous = true
                }
                
                continue
            }
            
            // String literals cannot have \n or \r in them (unless multiline).
            if ((scanner.peek == "\r" || scanner.peek == "\n") && !multiline) || scanner.isAtEnd {
                // FIXME: diagnose unterminated string
                return formToken(.unknown, from: start)
            }
            
            let charValue = character(multiline, stopQuote: stopQuote)
            wasErroneous = wasErroneous || charValue == .error
            
            // If this is the end of string, we are done.  If it is a normal character
            // or an already-diagnosed error, just munch it.
            if charValue == .end {
                scanner.advance()
                if wasErroneous {
                    return formToken(.unknown, from: start)
                }
                
                if stopQuote == "'" {
                    // Complain about single-quote string and suggest replacement with
                    // double-quoted equivalent.
                
                    // FIXME: diagnose single quote string, fixit: replace ' with ", unescape \', escape "
                }
                
                if multiline {
                    if scanner.advance() == "\"" && scanner.peek == "\"" && scanner.peekNext == "\"" {
                        scanner.advance() // advance over second "
                        scanner.advance() // advance over third "
                        
                        // FIXME: validateMultilineIdents of string & diagnose errors in it

                        // FIXME: indicate that token is of a multiline string
                        return formToken(.stringLiteral, from: start)
                    } else {
                        continue
                    }
                }
                
                // FIXME: indiate that token is of a multiline string, if applicable
                return formToken(.stringLiteral, from: start)
            }
        }
    }
    
    ///   unicode_character_escape ::= [\]u{hex+}
    ///   hex                      ::= [0-9a-fA-F]
    func unicodeEscape() -> CharValue {
        _ = scanner.match("{")
        
        let digitStart = scanner.current
        
        scanner.skip { $0.isHexDigit }
        
        guard scanner.peek == "}" else {
            // FIXME: diagnose invalid u escape rbrace
            return .error
        }
        let digits = scanner.text(from: digitStart)
        
        scanner.advance() // over the "}"
        
        if digits.count < 1 || digits.count > 8 {
            // FIXME: diagnose invalid u escape
            return .error
        }
        
        return CharValue(UInt32(digits, radix: 16)!)
    }
    
    /// lexCharacter - Read a character and return its UTF32 code.  If this is the
    /// end of enclosing string/character sequence (i.e. the character is equal to
    /// 'StopQuote'), this returns ~0U and leaves 'CurPtr' pointing to the terminal
    /// quote.  If this is a malformed character sequence, it emits a diagnostic
    /// (when EmitDiagnostics is true) and returns ~1U.
    ///
    ///   character_escape  ::= [\][\] | [\]t | [\]n | [\]r | [\]" | [\]' | [\]0
    ///   character_escape  ::= unicode_character_escape
    func character(_ multiline: Bool, stopQuote: UnicodeScalar) -> CharValue {
        if scanner.isAtEnd {
            // FIXME: diagnose unterminated string
            return .error
        }
        
        let c = scanner.advance()
        switch c {
        case "\"": fallthrough
        case "'":
            // If we found a closing quote character, we're done.
            if stopQuote == c {
                scanner.putback()
                return .end
            }
            // Otherwise, this is just a character.
            return CharValue(c)
        
        case "\n": fallthrough // String literals cannot have \n or \r in them.
        case "\r":
            if multiline { // ... unless they are multiline
                return CharValue(c)
            }
            
            // FIXME: diagnose unterminated string
            return .error
        
        case "\\":  // Escapes.
            break

        default:
            // Normal characters are part of the string.
            // If this is a "high" UTF-8 character, validate it.
            if !c.isASCII {
                if !c.isPrintable {
                    if !multiline && c == "\t" {
                        // FIXME: diagnose unprintable ascii character
                    }
                }
            }
            return CharValue(c)
        }
        
        // Escape processing.  We already ate the "\".
        switch scanner.peek {
            
        // Simple single-character escapes.
        case "0": scanner.advance(); return CharValue("\0")
        case "n": scanner.advance(); return CharValue("\n")
        case "r": scanner.advance(); return CharValue("\r")
        case "t": scanner.advance(); return CharValue("\t")
        case "\"": scanner.advance(); return CharValue("\"")
        case "'": scanner.advance(); return CharValue("'")
        case "\\": scanner.advance(); return CharValue("\\")
        
        case "u": //  \u HEX HEX HEX HEX
            scanner.advance()
            if scanner.peek != "{" {
                // FIXME: diagnose unicode escape braces
                return .error
            }
            
            let charValue = unicodeEscape()
            
            if charValue == .error {
                return .error
            }
            
            // Check to see if the encoding is valid.
            guard let scalar = charValue.scalar else {
                // FIXME diagnose invalid scalar
                return .error
            }
            
            return CharValue(scalar)
            
        case " ": fallthrough
        case "\t": fallthrough
        case "\n": fallthrough
        case "\r":
            if multiline && maybeConsumeNewlineEscape() {
                return CharValue("\n")
            }
            fallthrough

        default: // Invalid escape.
            // FIXME: diagnose invalid escape
            
            // If this looks like a plausible escape character, recover as though this
            // is an invalid escape.
            _ = scanner.match { $0.isAlphanumeric }
            return .error
        }
    }
    
    /// maybeConsumeNewlineEscape - Check for valid elided newline escape and
    /// move pointer passed in to the character after the end of the line.
    func maybeConsumeNewlineEscape() -> Bool {
        scanner.skip(over: [" ", "\t"])
        
        if scanner.isAtEnd { return false }
        
        if scanner.match("\r") {
            _ = scanner.match("\n")
            return true
        }
        
        return scanner.match("\n")
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
    
    /// skipToEndOfInterpolatedExpression - Given the first character after a \(
    /// sequence in a string literal (the start of an interpolated expression),
    /// scan forward to the end of the interpolated expression and return the end.
    /// On success, the returned pointer will point to the ')' at the end of the
    /// interpolated expression.  On failure, it will point to the first character
    /// that cannot be lexed as part of the interpolated expression; this character
    /// will never be ')'.
    ///
    /// This function performs brace and quote matching, keeping a stack of
    /// outstanding delimiters as it scans the string.
    func skipToEndOfInterpolatedExpression(_ multiline: Bool) {
        var openDelimiters: [UnicodeScalar] = []
        var allowNewline: [Bool] = []
        allowNewline.append(multiline)
        
        func inStringLiteral() -> Bool {
            return openDelimiters.last == "\"" || openDelimiters.last == "'"
        }
        
        while !scanner.isAtEnd {
            // This is a simple scanner, capable of recognizing nested parentheses and
            // string literals but not much else.  The implications of this include not
            // being able to break an expression over multiple lines in an interpolated
            // string.  This limitation allows us to recover from common errors though.
            //
            // On success scanning the expression body, the real lexer will be used to
            // relex the body when parsing the expressions.  We let it diagnose any
            // issues with malformed tokens or other problems.
            let c = scanner.advance()
            switch c {
            // String literals in general cannot be split across multiple lines;
            // interpolated ones are no exception - unless multiline literals.
            case "\n": fallthrough
            case "\r":
                if allowNewline.last! {
                    continue
                }

                // Will be diagnosed as an unterminated string literal.
                scanner.putback()
                return
            
            case "\"": fallthrough
            case "'":
                if !allowNewline.last! && inStringLiteral() {
                    if openDelimiters.last == c {
                        // Closing single line string literal.
                        _ = openDelimiters.popLast()
                        _ = allowNewline.popLast()
                    }
                    // Otherwise, it's just a quote in string literal. e.g. "foo's".
                    continue
                }
                
                let isMultilineQuote = c == "\"" && scanner.peek == "\"" && scanner.peekNext == "\""
                if isMultilineQuote {
                    scanner.advance()
                    scanner.advance()
                }
                
                if !inStringLiteral() {
                    // Open string literal
                    openDelimiters.append(c)
                    _ = allowNewline.append(isMultilineQuote)
                    continue
                }
                
                // We are in multiline string literal.
                if isMultilineQuote {
                    // Close multiline string literal.
                    _ = openDelimiters.popLast()
                    _ = allowNewline.popLast()
                }
                
                // Otherwise, it's just a normal character in multiline string.
                continue
                
            case "\\":
                if inStringLiteral() {
                    let escapedChar = scanner.advance()
                    switch escapedChar {
                    case "(":
                        // Entering a recursive interpolated expression
                        openDelimiters.append("(")
                        continue
                    case "\n": fallthrough
                    case "\r":
                        if allowNewline.last! {
                            continue
                        }
                        // Don't jump over newline due to preceding backslash!
                        scanner.putback()
                        return
                    default:
                        continue
                    }
                }
                continue

            // Paren nesting deeper to support "foo = \((a+b)-(c*d)) bar".
            case "(":
                if !inStringLiteral() {
                    openDelimiters.append("(")
                }
                continue
            
            case ")" where openDelimiters.isEmpty:
                // No outstanding open delimiters; we're done.
                scanner.putback()
                return

            case ")" where openDelimiters.last == "(":
                // Pop the matching bracket and keep going.
                _ = openDelimiters.popLast()
                continue
            
            case ")":
                // It's a right parenthesis in a string literal.
                continue
            
            // Normal token character.
            default: continue
            }

        }
        
        // If we hit EOF, we fail.
        if scanner.isAtEnd {
            // FIXMe: diagnose unterminated string
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
        firstInLine = false
        return token
    }
}
