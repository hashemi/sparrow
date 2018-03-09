# sparrow

This is an attempt to port Swift's parser to Swift. The motivation behind this project is to explore ways of writing a complex parser in idiomatic Swift.

The project is currently limited to lexical analysis. Swift's original lexer is written in C++ and is full of raw pointer manipualation. This Swift port adds a thin abstraction layer to improve the ergonomics of dealing with the parser and improve memory safety without sacrificying performance.

The next step is building an AST.
