-- game/core/boardregistry.lua
local BoardRegistry = {}

-- Store board definitions

-- BOARD Y COORDINATES ARE FLIPPED IN LOVE2D (TOP-LEFT TO BOTTOM-RIGHT)

BoardRegistry.boards = {
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
    {
        name = "Wide Arena",
        description = "Classic 11x8 grid with centered towers",
        rows = 8,
        cols = 11,
        towerPositions = {
            player1 = { x = 6, y = 7 },
            player2 = { x = 6, y = 2 }
        },
        imagePath = "assets/images/open_field_board.png"
    },
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