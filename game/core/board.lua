-- game/core/board.lua
-- This module now creates boards based on provided configuration.
-- Integrated with EventBus for movement events.
local Board = {}
Board.__index = Board

local EventBus = require("game/eventbus")  -- Added EventBus import

function Board:new(config)
    local self = setmetatable({}, Board)
    
    -- Use config or default to 9x9
    config = config or {}
    self.cols = config.cols or 9
    self.rows = config.rows or 9
    
    -- Initialize a 2D array for tiles: tiles[y][x]
    self.tiles = {}
    for y = 1, self.rows do
        self.tiles[y] = {}
        for x = 1, self.cols do
            self.tiles[y][x] = nil
        end
    end
    
    -- Store the tower positions if any
    self.towerPositions = config.towerPositions
    
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
        
        -- Store old position for event
        local oldPosition = { x = fromX, y = fromY }
        
        -- Update board state
        self.tiles[fromY][fromX] = nil
        self.tiles[toY][toX] = minion
        minion.position = { x = toX, y = toY }
        
        -- Publish movement event with before/after positions
        EventBus.publish(EventBus.Events.MINION_MOVED, minion, oldPosition, minion.position)
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