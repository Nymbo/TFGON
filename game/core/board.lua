-- game/core/board.lua
-- Manages the state of the board, specifically
-- where each player's minions are placed.

--------------------------------------------------
-- Table definition for Board
--------------------------------------------------
local Board = {}
Board.__index = Board

--------------------------------------------------
-- Constructor for the Board.
-- Initializes two lists: one for Player 1's minions
-- and another for Player 2's minions.
--------------------------------------------------
function Board:new()
    local self = setmetatable({}, Board)
    
    -- Track Player 1's minions on the field
    self.player1Minions = {}
    
    -- Track Player 2's minions on the field
    self.player2Minions = {}
    
    return self
end

return Board
