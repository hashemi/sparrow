//
//  main.swift
//  sparrow
//
//  Created by Ahmad Alhashemi on 2017-09-01.
//  Copyright © 2017 Ahmad Alhashemi. All rights reserved.
//

func findFirstNumber(_ source: String) -> String {
    var scanner = Scanner(source)

    // skip over anything that's not a digit
    scanner.skip { !$0.isDigit }

    // this should be start of digits (or end of string)
    let firstDigit = scanner.current

    // scan all digits
    scanner.skip { $0.isDigit }

    // if there's a decimal point followed by a digit, scan all of those digits
    if scanner.peek == "." && scanner.peekNext.isDigit {
        scanner.advance() // once over the dicimal
        scanner.skip { $0.isDigit }
    }
    
    return scanner.text(from: firstDigit)
}

let sources = [
    "The price of admission is: 12.34 USD",
    "This one does not have a number.",
    "This one does not have a decimal component: 123.",
    "9",
    "l33t",
    ""]

for source in sources {
    print("IN:    \(source)")
    print("FOUND: \(findFirstNumber(source))")
}
