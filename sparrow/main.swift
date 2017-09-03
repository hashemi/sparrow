//
//  main.swift
//  sparrow
//
//  Created by Ahmad Alhashemi on 2017-09-01.
//  Copyright © 2017 Ahmad Alhashemi. All rights reserved.
//

let source = """
#! /bin/sparrow
#if // this is commented
/**/#elseif/**/
/* /* /* this is commented */ */ */
/*/ this is commented */
#endif
"""

let lexer = Lexer(source)
var token: Token
repeat {
    token = lexer.next()
    print(token)
} while token.kind != .eof

