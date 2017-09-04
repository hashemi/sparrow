//
//  main.swift
//  sparrow
//
//  Created by Ahmad Alhashemi on 2017-09-01.
//  Copyright © 2017 Ahmad Alhashemi. All rights reserved.
//

let source = """
#! /bin/sparrow
let x = /* something */
#if // comment
#endif
x * y
while true {
    let x = y.ident()
    let b: Array<Int> = []
}
+
?// and this is the same operator
*/ // this is identified as an unknown
..*/.. // unknown
+.+ // three tokens
.+. // one token
/**/#elseif/**/
/* /* /* this is commented */ */ */
/*/ this is commented */
"""

let lexer = Lexer(source)
var token: Token
repeat {
    token = lexer.next()
    print(token)
} while token.kind != .eof

