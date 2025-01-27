# The Fine Game of Nil (TFGON)

A trading card game built with LÖVE2D framework.

## Description

The Fine Game of Nil is a turn-based digital card game where two players battle using minions, spells, and weapons. Each player starts with 30 health and must reduce their opponent's health to zero to win.

## Features

- Turn-based gameplay with mana crystal system
- Different card types (Minions, Spells, Weapons)
- Interactive card placement and battlefield management

## Prerequisites

- LÖVE2D (version 11.4 or higher) - [Download Here](https://love2d.org/)

### Installation Instructions

1. Install LÖVE2D for your operating system:
   - **Windows**: Download and install from love2d.org
   - **macOS**: `brew install love` (using Homebrew)
   - **Linux**: `sudo apt-get install love` (Ubuntu/Debian)

2. Clone this repository:
```bash
git clone https://github.com/yourusername/nymbo-tfgon.git
cd nymbo-tfgon
```

3. Run the game:
   - **Windows**: Drag the game folder onto love.exe, or run `"C:\Program Files\LOVE\love.exe" .` from the game directory
   - **macOS**: `love .` from the game directory
   - **Linux**: `love .` from the game directory

## How to Play

1. **Starting the Game**
   - Launch the game
   - Click "Play" in the main menu
   - Each player starts with:
     - 30 health
     - 3 cards in hand
     - 0 mana crystals

2. **Game Mechanics**
   - Each turn:
     - Gain one mana crystal (up to 10)
     - Draw one card
     - Play cards by clicking them in your hand
   - Click "End Turn" to pass the turn to your opponent

3. **Card Types**
   - **Minions**: Creatures with Attack/Health stats that can fight
   - **Spells**: One-time effects
   - **Weapons**: Equipment that gives your hero attack power

## Project Structure

```
nymbo-tfgon/
├── README.md
├── conf.lua            # LÖVE configuration
├── main.lua           # Entry point
├── assets/           # Game resources
│   └── images/      # Artwork and sprites
├── data/            # Game data
│   └── cards.lua    # Card definitions
└── game/            # Core game logic
    ├── core/        # Basic game elements
    ├── managers/    # Game state management
    ├── scenes/      # Game screens
    └── ui/          # Visual components
```

## Development

The game is built using the LÖVE2D framework and pure Lua. Key components:

- Scene management system for different game states
- Card and board rendering systems
- Game state management
- Player action handling

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b new-feature`
3. Commit your changes: `git commit -am 'Add new feature'`
4. Push to the branch: `git push origin new-feature`
5. Submit a pull request

## License

This project is licensed under the DAE Ventures Non-Commercial License - see the LICENSE file for details.