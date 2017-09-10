//
//  main.swift
//  sparrow
//
//  Created by Ahmad Alhashemi on 2017-09-01.
//  Copyright © 2017 Ahmad Alhashemi. All rights reserved.
//

let source = """
let a = 12.3e-5
0xfff/*
*/ while true { break }
"\\(i + v + '' + "\\()") \\(a * (x + y) * z)" + ""
"""

let lexer = Lexer(source)
var token: Token
repeat {
    token = lexer.next()
    print(token)
} while token.kind != .eof

