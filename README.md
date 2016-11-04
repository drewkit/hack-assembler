# hack-assembler
Ruby implementation of an assembler for the Hack machine language


Takes Hack assembly code as input:

```
// This file is part of www.nand2tetris.org
// and the book "The Elements of Computing Systems"
// by Nisan and Schocken, MIT Press.
// File name: projects/06/add/Add.asm

// Computes R0 = 2 + 3

@2
D=A
@3
D=D+A
@0
M=D
```

And when passing along to the ruby assembler script:

```
ruby hack_assembler.rb add.asm
```

Maps the Hack assembly language to machine code:

```
0000000000000010
1110110000010000
0000000000000011
1110000010010000
0000000000000000
1110001100001000
```
