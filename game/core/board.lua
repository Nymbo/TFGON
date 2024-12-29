-- game/core/board.lua
-- For placing minions on the field, etc. For now, it's a placeholder.

local Board = {}
Board.__index = Board

function Board:new()
    local self = setmetatable({}, Board)
    -- We might track each player's minions:
    self.player1Minions = {}
    self.player2Minions = {}
    return self
end

return Board
