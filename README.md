# uLisp for terminals (ulisp-tio)

A version of [uLisp](http://www.ulisp.com) ESP Release 4.9b for ESP32 boards, changed so that
you can write, edit, run and save programs **entirely on the board**, from a terminal program such
as `tio`, `picocom`, `minicom` or `screen`.

> **Based on uLisp by David Johnson-Davies.** uLisp is a Lisp for microcontrollers, with
> versions for many boards, a large library of examples and full documentation at
> [www.ulisp.com](http://www.ulisp.com). The language, the interpreter, the garbage collector and
> nearly all of the code in `ulisp-tio.ino` are his work, from the ESP Release 4.9b sketch
> (14th May 2026). This project only adds a terminal front end and file handling around it.
> If you want the official, supported uLisp, get it from the
> [uLisp download page](http://www.ulisp.com). Please don't report problems with this version to
> the uLisp project.

## Why: on-device, retro-style development

Home computers of the late 1970s and 1980s booted straight into a language. You typed a line,
it ran, you edited a definition, saved it to tape or disk, and the machine was the whole
development environment. An ESP32 has far more memory and speed than those machines, and uLisp
already gives it an interactive language, but stock uLisp is designed to be used through the
Arduino IDE's Serial Monitor: you type a line into a box, you can't move the cursor or recall
earlier lines, and anything longer than a few lines is written on the computer and pasted in.
Programs live on the computer, not on the board.

This version aims for the other model: **the board is the computer, and the terminal is its
screen and keyboard.** Plug it in, open `tio`, and everything you need is on the device:

- a REPL with a proper **line editor**, the way a shell or a BASIC prompt works
- a **full-screen editor**, `ed`, for functions, variables and files, which saves to the
  board's own flash and evaluates the code when you leave it
- **files on the flash** to keep programs in, `load` them, and an autorun file, so the board
  starts up with your program the way a ROM cartridge or boot disk would
- **Ctrl-C** to stop a runaway program, as on most systems

The computer is only a terminal. It can also be the "disk drive": YMODEM, the protocol used by
modems and bulletin boards, copies files between it and the board reliably, which pasting into
an editor never quite is.

## What changed

- **Terminal input that works.** `tio` and other terminals send CR for Enter, which stock uLisp
  doesn't treat as a newline. CR, LF and CRLF are all accepted, and the serial speed is 115200,
  `tio`'s default.
- **Line editor** at the REPL prompt: cursor keys, Home/End, word moves, kill and yank, history,
  tab completion of symbol names, matching-paren highlighting, multi-line input that waits for
  closing parens and indents continuation lines.
- **`ed`, a full-screen editor** for a function or variable (`(ed 'name)`), a flash file
  (`(ed "file.lsp")`), or a scratch buffer (`(ed)`). Arrays such as a 9x9 board are laid out one
  row per line. It uses the terminal's alternate screen, so your REPL session is back when you
  leave.
- **Flash files**: `load`, `delete-file`, `directory`, and `with-sd-card` streams on the flash
  (LittleFS) when there is no SD card. `/autorun.lsp` is loaded at startup.
- **YMODEM transfer**: `(ymodem-receive)` and `(ymodem-send "file")`, which work with `tio`'s
  built-in sender and with lrzsz.
- **Pasting** is reliable: bracketed paste mode stops pasted code being re-indented, and a 2
  Kbyte receive buffer plus a type-ahead buffer keep keys typed while a program runs.
- **A bigger stack** (48 Kbytes instead of 8), so recursive functions can go about 500 levels
  deep instead of about 80.

Everything else is standard uLisp 4.9b: the same language, functions and documentation. See
[Differences from stock uLisp](#differences-from-stock-ulisp) for a table.

---

## Contents

1. [Building and connecting](#building-and-connecting)
2. [The line editor](#the-line-editor)
3. [The full-screen editor: ed](#the-full-screen-editor-ed)
4. [Files on the flash](#files-on-the-flash)
5. [Example: Sudoku solver](#example-sudoku-solver)
6. [Compile options](#compile-options)
7. [Differences from stock uLisp](#differences-from-stock-ulisp)
8. [Limitations](#limitations)
9. [Credits and license](#credits-and-license)

---

## Building and connecting

### Build and upload

Open `ulisp-tio/ulisp-tio.ino` in the Arduino IDE (ESP32 core 3.x or 4.x), or use `arduino-cli`.

For an **ESP32-S3 connected through its built-in USB port** (shows up as `/dev/ttyACM*`, USB ID
`303a:1001`), you must enable **Tools > USB CDC On Boot: Enabled**. Without it, uLisp talks on the
UART pins and the terminal stays silent. With `arduino-cli`:

```sh
arduino-cli compile --fqbn esp32:esp32:esp32s3:CDCOnBoot=cdc -u -p /dev/ttyACM0 ulisp-tio
```

Boards connected through a USB-to-serial chip (`/dev/ttyUSB*`) don't need this option.

Pick a partition scheme that has a file system partition (any of the schemes with "SPIFFS" in
the name, such as the default). See [SPIFFS and LittleFS](#spiffs-and-littlefs).

### Connect

```sh
tio /dev/ttyACM0     # or /dev/ttyUSB0, depending on the board
```

The serial speed is **115200 baud**, which is `tio`'s default (stock uLisp uses 9600). Quit `tio`
with `Ctrl-t q`.

Any VT100/ANSI terminal works. The editors ask the terminal for its size, so they adapt to the
window. Press `Ctrl-L` after resizing the window.

### Arduino IDE Serial Monitor

The Serial Monitor is not a terminal: it can't show the editors' escape codes. To use it, comment
out `#define termeditor` and set the monitor to 115200 baud. You then get plain line-at-a-time
input, as in stock uLisp, without `ed`.

---

## The line editor

The prompt behaves like a shell prompt.

### Entering code

- **Enter** submits the line. `tio` sends CR; LF and CRLF also work.
- If the parentheses aren't balanced yet (or a string is still open), Enter starts a new line,
  indented to the nesting depth, and the input continues until the expression is complete.
  Backspace at the start of a continuation line joins it to the line above.
- Pressing Enter on an empty line, or on a line with only a comment, just gives a new prompt.
- **Pasting** multi-line code works. Pasted text keeps its own indentation. (The editors turn on
  the terminal's *bracketed paste* mode, so they can tell pasted text from typing even when it
  arrives in pieces over USB.)
- When you type `)`, its matching `(` is highlighted. An unmatched `)` beeps.
- Lines longer than the window scroll sideways. `<` and `>` at the edges show there is more text.

### Keys

| Key | Action |
|---|---|
| Left / Right, `Ctrl-B` / `Ctrl-F` | Move by character |
| `Ctrl`+Left / Right, `Alt-B` / `Alt-F` | Move by word |
| Home / End, `Ctrl-A` / `Ctrl-E` | Start / end of line |
| Up / Down, `Ctrl-P` / `Ctrl-N` | Previous / next history entry (32 entries; multi-line input is recalled as one line) |
| Backspace, `Ctrl-H` | Delete the character before the cursor |
| Delete, `Ctrl-D` | Delete the character at the cursor |
| `Ctrl-K` / `Ctrl-U` | Cut to end / start of line |
| `Ctrl-W`, `Alt-Backspace` | Cut the word before the cursor |
| `Alt-D` | Cut the word after the cursor |
| `Ctrl-Y` | Paste the last cut text |
| Tab | Complete the symbol before the cursor (built-ins and your own definitions). Press twice to list the choices. At the start of a word it inserts two spaces. |
| `Ctrl-L` | Clear the screen and redraw the input |
| `Ctrl-C` | Cancel the input and give a new prompt |

### Interrupting a program

Press **`Ctrl-C`** to stop a running program. (Stock uLisp uses `~`, which this version no longer
uses, because `~` appears in pasted code such as `(format t "~a" x)`.)

Keys you type while a program is running are kept and appear at the next prompt.

### Programs that read input

`read-line` and `read` use the line editor too, so the user gets the same editing keys. In
`read-line`, Enter always finishes the line. `Ctrl-C` while a program waits for input stops the
program.

---

## The full-screen editor: ed

```lisp
(ed 'sq)            ; edit the definition of sq
(ed "sudoku.lsp")   ; edit a file on the flash
(ed)                ; go back to the last buffer
```

The editor uses the terminal's alternate screen (like `vim` or `nano`), so the REPL session
reappears when you leave.

### What you can edit

**A function or variable**: `(ed 'name)` loads its current definition, pretty-printed:

- a function as `(defun name (args) ...)`
- a variable as `(defvar name value)`
- an array of two or more dimensions one row per line, so a board or grid is easy to edit:

  ```lisp
  (defvar board
    #2A((0 0 5 3 0 0 0 0 0)
        (8 0 0 0 0 0 0 2 0)
        ...
        (0 0 0 0 0 9 7 0 0)))
  ```

- if `name` isn't defined yet, a template `(defun name ( ... ))` with the cursor between the
  parentheses.

The text is rebuilt from the current value each time, so comments and your own layout are not
kept. Use a file for that.

**A file**: `(ed "name.lsp")` opens a file on the flash, or starts a new one. A `/` is added in
front of the name. What you type is saved exactly as typed, comments included.

**Several definitions at once**: the buffer can hold any number of forms; `^X` evaluates them
all in order.

### Running and leaving

| Key | Action |
|---|---|
| `^X` | Evaluate every form in the buffer and return to the REPL. For a file, it saves first. Each form's result is printed; the last one is returned. |
| `^Q` | Return to the REPL without evaluating. |
| `^S` | Save to the flash. In a buffer that isn't a file yet, it asks for a filename, and the buffer becomes that file. |

The buffer is **kept** after you leave, so `(ed)` takes you back to it with the cursor where it
was. If evaluation stops with an error, type `(ed)`, fix the code and press `^X` again.

When you open a different function or file while the buffer has unsaved changes, the editor
asks before discarding them. Opening the same target again keeps your changes.

### Keys

| Key | Action |
|---|---|
| Arrows | Move |
| `Ctrl`+Left / Right | Move by word |
| Home, `^A` | First non-blank character of the line; press again for column 1 |
| End, `^E` | End of line |
| PgUp / PgDn | Up / down one screen |
| `Ctrl-Home` / `Ctrl-End` | Start / end of the buffer |
| Enter | New line, indented to fit the Lisp structure |
| Tab | Re-indent the current line |
| Backspace / Delete, `^D` | Delete before / at the cursor |
| `^K` | Cut to the end of the line. At the end of a line it cuts the line break. Repeated `^K` presses collect everything into one cut, so `^K ^K` cuts a whole line. |
| `^U` | Cut to the start of the line |
| `^W` | Cut the word before the cursor |
| `^Y` | Paste the cut text |
| `^F` | Find text (case-sensitive, wraps around). Enter on an empty prompt repeats the last search. |
| `^G` | Go to a line number |
| `^L` | Redraw, and check the window size again |

In prompts (find, go to line, filename), Enter accepts, and `^C`, `^G` or Esc cancels.

The top line shows the buffer name, `*` if there are unsaved changes, and the cursor's line and
column. When the cursor is next to a parenthesis, its partner is highlighted.

### Indentation

New lines are indented two spaces past the innermost open parenthesis, which is the style the
uLisp pretty-printer uses:

```lisp
(defun hi ()
  (list 'hi
    'there))
```

---

## Files on the flash

### SPIFFS and LittleFS

Files are stored with **LittleFS** in the flash partition that the Arduino partition scheme menu
calls "SPIFFS". Any scheme with "SPIFFS" in its name works; the ESP32-S3 default gives 1.5 MB.
The older **SPIFFS file system format is not supported**: SPIFFS is deprecated in ESP-IDF, and
uLisp for ESP32 uses LittleFS for everything, including `save-image`.

If the partition doesn't hold a LittleFS file system (it's blank, or it was formatted as SPIFFS
by another firmware such as ESP32forth), it has to be formatted first, which **erases everything
in the partition**:

- **`ed`** asks first: *Flash has no LittleFS file system. Format it?* Answer `n` and nothing
  is changed (the file can't be opened or saved).
- **`save-image`** formats without asking (stock uLisp behavior, unchanged).
- **`load`**, **`delete-file`** and **`directory`** never format; they report an error.

While it checks the flash, ESP-IDF may print messages such as `mount failed` or
`Corrupted dir pair`. These mean the partition isn't LittleFS yet; the editor redraws over them.

### Functions

| Function | Description |
|---|---|
| `(ed "file")` | Edit a file (see above). `^S` saves, `^X` saves and evaluates it. |
| `(load "file")` | Read and evaluate every form in the file. Returns `t`. If a form fails, loading stops at that form; forms before it have already been evaluated. Files can `load` other files (up to 4 deep). |
| `(directory)` | List the files on the flash, for example `("autorun.lsp" "sudoku.lsp")`. With `sdcardsupport` enabled it lists the SD card instead, as in stock uLisp. |
| `(delete-file "file")` | Delete a file. Returns `t`, or `nil` if there was no such file. |
| `(with-sd-card (str "file" [mode]) forms...)` | Open a file as a stream for `read-line`, `read`, `print`, `format` and so on. Without SD card support, this uses the flash. mode 0 (default) reads, 1 appends, 2 writes (replacing the file). |

Reading a file line by line:

```lisp
(with-sd-card (s "problems.csv")
  (loop
   (let ((line (read-line s)))
     (unless line (return))
     (print line))))
```

Writing a file:

```lisp
(with-sd-card (s "log.txt" 2)
  (format s "Started at ~a ms~%" (millis)))
```

Filenames get a `/` in front automatically, so `"sudoku.lsp"` and `"/sudoku.lsp"` are the same
file. Names can be up to about 34 characters.

### Transferring files to and from the computer

Use YMODEM, which `tio` has built in. YMODEM sends the file in numbered blocks with a checksum,
the board acknowledges each one, and damaged blocks are sent again, so files arrive exactly as
sent, binary files included. It also sends the filename and exact size. This is much more
reliable than pasting into the editor, which has no error checking.

**Computer to board:**

1. Type `(ymodem-receive)`. The board prints a message and then a `C` every second while it
   waits (that's the YMODEM "ready" signal).
2. Press **`ctrl-t y`** in tio and enter the path of the file on the computer.
3. The file is saved on the flash under its own name, replacing any file with that name:

   ```
   21900> (ymodem-receive)
   Waiting for a YMODEM upload: in tio press ctrl-t y. Ctrl-C cancels.
   CCC
   Received /sudoku.lsp (9491 bytes)
   ("sudoku.lsp")
   ```

`(ymodem-receive "name.lsp")` saves the file under a different name. tio sends one file at a
time; other YMODEM programs can send several in one go, and they're all saved.

**Board to computer** (needs `lrzsz`: `sudo apt install lrzsz`):

1. Type `(ymodem-send "sudoku.lsp")`.
2. Press **`ctrl-t R`** in tio and enter the command **`rb`**. The file is saved in the directory
   where you started tio. (`rb` won't overwrite an existing file; use `rb -y` to allow that.)

| Function | Description |
|---|---|
| `(ymodem-receive ["file"])` | Receive files with YMODEM and save them on the flash. Returns the list of filenames, or `nil` if nothing was received. Waits up to 60 seconds for the transfer to start; Ctrl-C cancels. |
| `(ymodem-send "file")` | Send a file from the flash with YMODEM. Returns `t` if it was sent. Waits up to 60 seconds for the receiver; Ctrl-C cancels. |

A file is received into a temporary file and only renamed when it's complete, so a transfer
that fails or is cancelled never damages an existing file. On the ESP32-S3's USB port transfers
run at about 50 Kbytes per second.

### Autorun

If **`/autorun.lsp`** exists, it is loaded once at startup, before the first prompt. Use it to
load your programs or start an application:

```lisp
; /autorun.lsp
(load "sudoku.lsp")
(load "solver.lsp")
```

Make one with `(ed "autorun.lsp")`. `Ctrl-C` stops a program started by autorun. To turn autorun
off, delete the file with `(delete-file "autorun.lsp")`, or comment out `#define autorunfile` at
the top of the sketch (you can also change the filename there).

Output printed while autorun runs is lost if no terminal is connected yet, which is common with
the S3's built-in USB port right after a reset.

### A typical workflow

```lisp
(ed "sudoku.lsp")    ; write the program, ^X to save and load it
(solve board)        ; try it
(ed)                 ; back to the file, fix things, ^X again
(ed "autorun.lsp")   ; type (load "sudoku.lsp"), ^S, ^Q
```

After a reset, the program is loaded automatically.

---

## Example: Sudoku solver

`sudoku.lsp` is a Sudoku solver, rewritten from the example on the uLisp website.
`problems.csv` holds 999 example puzzles with their solutions (about 5 minutes to solve them all). Copy both to the board with
YMODEM (see [Transferring files](#transferring-files-to-and-from-the-computer)), then:

```lisp
(load "sudoku.lsp")
(print-board (solve board))     ; board is an example puzzle defined in the file
(solve-all "problems.csv")      ; solve, verify and time every puzzle in a CSV file
```

| Function | Description |
|---|---|
| `(solve board)` | Returns a solved copy of a 9x9 array (0 = empty cell), or `nil` if there is no solution (including a puzzle with a repeated clue). The board passed in is not changed. |
| `(print-board board)` | Prints a board, with `.` for empty cells. |
| `(valid-solution-p puzzle solution)` | `t` if the solution is complete, has 1 to 9 once in every row, column and box, and keeps the puzzle's clues. |
| `(solve-all "file.csv")` | Solves every puzzle in a CSV file on the flash, verifies each solution (with `valid-solution-p`, and against the solution in the file if there is one), and prints statistics. Returns `t` if every puzzle was solved and matched. |
| `(string-to-board string start)` | Makes a board from 81 characters of a string (0 or `.` for empty). |

The CSV format is one puzzle per line: `puzzle,solution`, each 81 digits read row by row, with 0
or `.` for an empty cell. The solution column is optional. A header line and blank lines are
skipped. `solve-all` prints one line per puzzle and then, for a file of 12 puzzles:

```
Puzzles:            12
Solved and valid:   12
Match the file:     12
Total solve time:   3787 ms
Average:            315.6 ms
Median:             297.0 ms
Fastest:            255 ms (puzzle 7)
Slowest:            409 ms (puzzle 11)
Wall time:          4370 ms (including reading and checking)
```

### What was wrong with the original

1. **Stack overflow.** The original recurses once per cell, 81 levels deep, and stock uLisp on
   the ESP32-S3 allows only 6.5 Kbytes of stack. This version of uLisp has a bigger stack
   (`LOOPSTACKSIZE`), and the new solver only recurses once per empty cell.
2. **It used a global board** and changed it while solving, so a second `(solve)` "solved" the
   already-solved board. The new `solve` takes the board as a parameter and works on a copy.

### How the new solver works

- Bit masks record which digits are used in each row, column and 3x3 box, so checking a digit
  is one `logand` instead of 27 array lookups.
- At each step it fills the empty cell with the fewest possible digits ("minimum remaining
  values"), and gives up on a branch as soon as some cell has no possible digit.
- The hot loop is written out inline, because function calls are slow in uLisp.

Times on the ESP32-S3 (240 MHz):

| | Original | New |
|---|---|---|
| Example board in the file | 7.8 s | 1.0 s |
| The 12 puzzles in `problems.csv` | 7.6 s | 3.8 s |
| A 17-clue puzzle (the minimum; very hard) | | 98 s |
| Empty board | stack overflow | 3.2 s |

---

## Compile options

At the top of the sketch:

| Option | Default | Effect |
|---|---|---|
| `#define termeditor` | on | Line editor and `ed`. Comment out for the Arduino Serial Monitor. |
| `#define SERIALBAUD 115200` | 115200 | Serial speed. |
| `#define autorunfile "/autorun.lsp"` | on | File loaded at startup. Comment out to disable. |
| `#define LOOPSTACKSIZE 49152` | 48 Kbytes | Stack for Lisp (the Arduino default is 8 Kbytes). Sets uLisp's `MAX_STACK` to 4 Kbytes less. Comment out to use each board's stock setting. |

The other options (`printfreespace`, `sdcardsupport`, `gfxsupport`, `lisplibrary`, ...) are
standard uLisp options. The old `lineeditor` and `vt100` options have been replaced by
`termeditor`.

Editor settings, as constants in the source:

| Constant | Value | Meaning |
|---|---|---|
| `EdBufSize` | 2048 | Longest input at the prompt, in characters |
| `EdHistSize` | 32 | History entries |
| `EdEscTimeout` | 200 ms | Time to wait for the rest of an escape sequence |
| `EbSize` | 16384 | Largest buffer in `ed`, in characters |
| `EbKillSize` | 2048 | Largest cut in `ed` |

The editor buffers are allocated on the heap (`ed`'s only on first use), so they don't use any
of the Lisp workspace.

---

## Differences from stock uLisp

| | Stock uLisp 4.9b | This version |
|---|---|---|
| Serial speed | 9600 | 115200 |
| Enter from a terminal (CR) | Cursor goes back to the start of the line without moving down | Works |
| Interrupt key | `~` | `Ctrl-C` |
| Typed-ahead keys while a program runs | Discarded | Kept |
| Serial receive buffer | 256 bytes | 2048 bytes (room for pasted code while it's evaluated) |
| `directory`, `with-sd-card` | SD card only | SD card, or the flash |
| Stack for Lisp | 6.5 to 8 Kbytes (about 80 levels of recursion) | 48 Kbytes (about 500 levels) |
| New functions | | `ed`, `load`, `delete-file`, `ymodem-receive`, `ymodem-send` |

The new functions are in uLisp's second ("extensions") symbol table, so the numbering of
built-in symbols is unchanged. This also means `#define extensions` with your own Extensions
file would conflict with them.

---

## Limitations

- **`read-byte` from the terminal** returns only the first character of each line typed (the
  rest of the line is discarded). The original `lineeditor` option behaves the same way.
- **Non-ASCII characters** can be typed, but cursor positions are counted in bytes, so lines
  containing UTF-8 characters display slightly off.
- **`ed` on a symbol doesn't keep comments**, because it rebuilds the text from the value. Use
  files for code you want to keep.
- **Classic ESP32 boards** (not S2/S3/C3): with ESP32 core 4.0.0, both stock uLisp 4.9b and this
  version run out of static RAM at build time. Reduce `WORKSPACESIZE` for your board, or use an
  older core.
- The old structure editor `(edit 'function)` is still there, unchanged.

### Tested

On an ESP32-S3 dev board (core 4.0.0, built-in USB port) with keystrokes sent the way `tio` sends
them: CR/LF/CRLF, multi-line input, editing keys, history, completion, `Ctrl-C`, pasting
(including bracketed paste arriving in pieces), `ed` on functions, new functions, a 9x9 array
and files, `load` (including after errors and missing files), `directory`, `delete-file`,
`with-sd-card` reading flash files, autorun across a reset, recursion depth, and the Sudoku
solver. YMODEM: text and a 50 Kbyte random binary file sent with tio's own sender
(`ctrl-t y`) and received back with lrzsz's `rb` were byte-for-byte identical (SHA-256);
cancelling with Ctrl-C and receiving under another name also tested. The format prompt in `ed` has
not been tested on hardware, because that needs a flash without LittleFS on it.

---

## Credits and license

uLisp is by David Johnson-Davies ([www.ulisp.com](http://www.ulisp.com),
[www.technoblogy.com](http://www.technoblogy.com)) and is released under the MIT license. This
version adds the terminal line editor, the `ed` screen editor, flash file functions, YMODEM
transfer and the Sudoku example, under the same license. See [LICENSE](LICENSE).
