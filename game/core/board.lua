-- game/core/board.lua
-- This module now implements a 9x9 grid board.
local Board = {}
Board.__index = Board

function Board:new()
    local self = setmetatable({}, Board)
    self.cols = 9  -- Updated from 7 to 9 columns
    self.rows = 9  -- Updated from 6 to 9 rows
    -- Initialize a 2D array for tiles: tiles[y][x]
    self.tiles = {}
    for y = 1, self.rows do
        self.tiles[y] = {}
        for x = 1, self.cols do
            self.tiles[y][x] = nil
        end
    end
    return self
end

function Board:isEmpty(x, y)
    return self.tiles[y] and self.tiles[y][x] == nil
end

function Board:placeMinion(minion, x, y)
    if self:isEmpty(x, y) then
        self.tiles[y][x] = minion
        minion.position = { x = x, y = y }
        return true
    else
        return false
    end
end

function Board:moveMinion(fromX, fromY, toX, toY)
    if self.tiles[fromY] and self.tiles[fromY][fromX] and self:isEmpty(toX, toY) then
        local minion = self.tiles[fromY][fromX]
        self.tiles[fromY][fromX] = nil
        self.tiles[toY][toX] = minion
        minion.position = { x = toX, y = toY }
        return true
    end
    return false
end

function Board:getMinionAt(x, y)
    if self.tiles[y] then
        return self.tiles[y][x]
    end
    return nil
end

function Board:removeMinion(x, y)
    if self.tiles[y] then
        self.tiles[y][x] = nil
    end
end

-- Helper to iterate over all minions on the board
function Board:forEachMinion(callback)
    for y = 1, self.rows do
        for x = 1, self.cols do
            local minion = self.tiles[y][x]
            if minion then
                callback(minion, x, y)
            end
        end
    end
end

return Board
