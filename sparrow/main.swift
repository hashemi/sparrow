//
//  main.swift
//  sparrow
//
//  Created by Ahmad Alhashemi on 2017-09-01.
//  Copyright © 2017 Ahmad Alhashemi. All rights reserved.
//

let source = """
1
0b1
0b3
0xfff
0o01234567
0o8
1.31
1.3e-17
1_233_131
1a1
1+1
x.0.1
0xfff.fp
0xa.fp-1
-12.1
"""

let lexer = Lexer(source)
var token: Token
repeat {
    token = lexer.next()
    print(token)
} while token.kind != .eof

