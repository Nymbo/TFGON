-- game/core/boardregistry.lua
local BoardRegistry = {}

-- Store board definitions
BoardRegistry.boards = {
    -- Standard 9x9 board with towers
    {
        name = "Standard Arena",
        description = "Classic 9x9 grid with centered towers",
        rows = 9,
        cols = 9,
        towerPositions = {
            player1 = { x = 5, y = 8 },
            player2 = { x = 5, y = 2 }
        },
        imagePath = "assets/images/standard_board.png"
    },
    -- New 7x7 board with towers
    {
        name = "Compact Arena",
        description = "Compact 7x7 grid with centered towers",
        rows = 7,
        cols = 7,
        towerPositions = {
            player1 = { x = 4, y = 6 },
            player2 = { x = 4, y = 2 }
        },
        imagePath = "assets/images/open_field_board.png"
    },
    -- New 8x8 board with no towers
    {
        name = "Open Field",
        description = "Open 8x8 grid with no defensive structures",
        rows = 8,
        cols = 8,
        towerPositions = nil, -- No towers on this board
        imagePath = "assets/images/open_field_board.png"
    }
}

-- Function to get board by index
function BoardRegistry.getBoard(index)
    return BoardRegistry.boards[index]
end

-- Function to get total number of boards
function BoardRegistry.getBoardCount()
    return #BoardRegistry.boards
end

return BoardRegistry