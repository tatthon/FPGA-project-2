# VGA Hangman

This project implements a Hangman game on a VGA text screen. The game logic and text rendering are in [`src/hangman.v`](src/hangman.v), in the `text_screen_gen` module. `top_module.v` connects it to the VGA timing generator and gamepad interface.

## How to Play

- Press **Start** to begin a new game. The game selects one of three words: `APPLE`, `HOUSE`, or `TIGER`.
- Press **Up** to select the next letter or **Down** to select the previous letter. Selection wraps around: Up after `Z` selects `A`, and Down before `A` selects `Z`.
- Press **Y** to guess the selected letter.
- You start with 3 lives. Each incorrect new guess costs one life.
- Correctly guessed letters are revealed in every matching position in the word.
- Guessing a letter again displays a notice and does not cost a life.
- Guess all letters in the word to win. Losing all lives displays `GAME OVER`.
- Press **Start** at any time to reset the round and select a new word.

## `hangman` Interface

| Port | Direction | Width | Description |
|---|---|---:|---|
| `clk` | Input | 1 | Main clock |
| `reset` | Input | 1 | Asynchronous, active-high reset |
| `video_off` | Input | 1 | Forces the RGB output to black when high |
| `gamepad_in` | Input | 12 | Active-high gamepad button states |
| `x`, `y` | Input | 10 each | VGA pixel coordinates |
| `rgb` | Output | 6 | RGB color, 2 bits per color channel |

Gamepad bit mapping: `[11]=B`, `[10]=Y`, `[9]=Select`, `[8]=Start`, `[7]=Up`, `[6]=Down`, `[5]=Left`, `[4]=Right`, `[3]=A`, `[2]=X`, `[1]=L`, `[0]=R`. This game uses Start, Up, Down, and Y. Button presses are debounced by `debouncer.v`.

## VGA Rendering

The renderer uses 8×16 pixel character cells. It derives the character position from `x[9:3]` and `y[8:4]`, then reads glyph rows from `ascii_rom.v`. Text is green and the background is black. The screen shows the game title, remaining lives, concealed or revealed word, selected letter, control hints, and game status messages. Pixel coordinates are delayed to align with the font ROM output.

## Related Modules

- `src/debouncer.v` — filters button input and generates press ticks.
- `src/ascii_rom.v` — ASCII font used to render text.
- `src/hvsync_generator.v` — generates VGA timing and pixel coordinates.
- `src/gamepad_pmod.v` — reads the PMOD gamepad.
- `src/top_module.v` — connects the game, gamepad, and VGA signals.

The current word list contains three five-letter words. Word selection uses the low bits of a free-running counter as a simple source of variation; it is not intended for cryptographic use.
