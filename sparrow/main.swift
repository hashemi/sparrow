//
//  main.swift
//  sparrow
//
//  Created by Ahmad Alhashemi on 2017-09-01.
//  Copyright © 2017 Ahmad Alhashemi. All rights reserved.
//

import Foundation

func showInfo(_ scalar: UnicodeScalar) {
    print("""
    Scalar: \(scalar)
        ASCII: \(scalar.isASCII)
        Value: \(scalar.value)
        Alphanumeric: \(scalar.isAlphanumeric)
        Digit: \(scalar.isDigit)
        Hex: \(scalar.isHexDigit)
        Horz WS: \(scalar.isHorizontalWhitespace)
        WS: \(scalar.isWhitespace)
        Printable: \(scalar.isPrintable)
    """)
}

let scalars: [UnicodeScalar] = ["a", " ", "g", "Z", "9", "{", "\t", "~", ".", "\u{ffff}"]
for s in scalars { showInfo(s) }

print("Hello, World!")
