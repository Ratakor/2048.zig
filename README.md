2048.zig
========
2048 in zig with undo, automatic save and other cool stuff

![preview](/preview.gif)

Installation
------------
Pick one of the release or build it yourself ;)
To build have a look at `zig build --help` or just run
`zig build -Doptimize=ReleaseSafe` the executable will be at ./zig-out/bin/2048.

Usage
-----
```
$ 2048 --help
Usage: 2048 [options]

Options:
-s, --size [n]    | Set the board size to n
-h, --help        │ Print this help message
-v, --version     | Print version information

Commands:
  ↑    w    k     | Classic movements
 ←↓→  asd  hjl    |
 q                | Quit the game
 r                | Restart the game
 u                | Undo one action
 ```
