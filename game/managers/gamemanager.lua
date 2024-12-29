-- game/managers/gamemanager.lua
-- Manages the turn cycle, updates players, etc.

local Player = require("game.core.player")
local Board = require("game.core.board")

local GameManager = {}
GameManager.__index = GameManager

function GameManager:new()
    local self = setmetatable({}, GameManager)

    -- Create two players
    self.player1 = Player:new("Player 1")
    self.player2 = Player:new("Player 2")

    -- The board: for now we’ll keep it simple
    self.board = Board:new()

    -- Whose turn is it? (1 or 2)
    self.currentPlayer = 1

    -- Start each player with 0 current mana
    self.player1.manaCrystals = 0
    self.player2.manaCrystals = 0
    -- Draw some initial cards
    self.player1:drawCard(3)
    self.player2:drawCard(3)

    return self
end

function GameManager:update(dt)
    -- For now, no complex turn timer logic. 
    -- In a real game, we'd handle animations or countdowns here.
end

function GameManager:draw()
    -- Prototype UI: just show some basic text about each player
    love.graphics.printf(
        "Current Turn: " .. self:getCurrentPlayer().name,
        0, 20, love.graphics.getWidth(), "center"
    )
    love.graphics.printf(
        self.player1.name .. " HP: " .. self.player1.health .. 
        " | Mana: " .. self.player1.manaCrystals .. "/" .. self.player1.maxManaCrystals,
        0, 60, love.graphics.getWidth(), "left"
    )
    love.graphics.printf(
        self.player2.name .. " HP: " .. self.player2.health .. 
        " | Mana: " .. self.player2.manaCrystals .. "/" .. self.player2.maxManaCrystals,
        0, 80, love.graphics.getWidth(), "left"
    )
end

function GameManager:endTurn()
    -- 1) End actions for the current player
    local current = self:getCurrentPlayer()
    
    -- 2) Switch player
    if self.currentPlayer == 1 then
        self.currentPlayer = 2
    else
        self.currentPlayer = 1
    end

    -- 3) Start turn for the new current player
    self:startTurn()
end

function GameManager:startTurn()
    local player = self:getCurrentPlayer()
    -- Increase mana crystals by 1 (max 10)
    if player.maxManaCrystals < 10 then
        player.maxManaCrystals = player.maxManaCrystals + 1
    end
    player.manaCrystals = player.maxManaCrystals

    -- Draw a card at the start of turn
    player:drawCard(1)
end

function GameManager:getCurrentPlayer()
    if self.currentPlayer == 1 then
        return self.player1
    else
        return self.player2
    end
end

return GameManager
