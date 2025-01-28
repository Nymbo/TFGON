-- game/managers/gamemanager.lua
local Player = require("game.core.player")
local Board = require("game.core.board")

local GameManager = {}
GameManager.__index = GameManager

function GameManager:new()
    local self = setmetatable({}, GameManager)

    -- Create two players
    self.player1 = Player:new("Player 1")
    self.player2 = Player:new("Player 2")

    -- The board holds each player's minions
    self.board = Board:new()

    -- Whose turn is it? (1 or 2)
    self.currentPlayer = 1

    -- Start each player with 0 current mana
    self.player1.manaCrystals = 0
    self.player2.manaCrystals = 0

    -- Each player draws some initial cards
    self.player1:drawCard(3)
    self.player2:drawCard(3)

    return self
end

function GameManager:update(dt)
    -- If you want timers/animations, handle them here.
end

-- Draws only basic text about the turn, HP, and mana.
-- The board and hand are drawn in the scene (Method #2).
function GameManager:draw()
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
    -- End-of-turn logic for the current player
    local current = self:getCurrentPlayer()
    -- (Placeholder, in future we can handle minion statuses, fatigue, etc.)

    -- Switch player
    if self.currentPlayer == 1 then
        self.currentPlayer = 2
    else
        self.currentPlayer = 1
    end

    -- Start the new player's turn
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
    player.heroAttacked = false
    
    -- Reset minion attack status
    local minions = (player == self.player1) and self.board.player1Minions or self.board.player2Minions
    for _, minion in ipairs(minions) do
        minion.canAttack = true
    end
end

function GameManager:getCurrentPlayer()
    if self.currentPlayer == 1 then
        return self.player1
    else
        return self.player2
    end
end

function GameManager:getEnemyPlayer(player)
    if player == self.player1 then
        return self.player2
    else
        return self.player1
    end
end

-------------------------------------------------------
-- Allows a player to play a card from their hand if
-- they have enough mana. Places Minions on the board,
-- and does placeholders for Spells or Weapons.
-------------------------------------------------------
function GameManager:playCardFromHand(player, cardIndex)
    local card = player.hand[cardIndex]
    if not card then
        return
    end

    -- Check if the player has enough mana
    if card.cost <= player.manaCrystals then
        player.manaCrystals = player.manaCrystals - card.cost

        if card.cardType == "Minion" then
            local minion = {
                name = card.name,
                attack = card.attack,
                maxHealth = card.health,
                currentHealth = card.health,
                canAttack = false
            }
            if player == self.player1 then
                table.insert(self.board.player1Minions, minion)
            else
                table.insert(self.board.player2Minions, minion)
            end

        elseif card.cardType == "Spell" and card.effect then
            card.effect(self, player)

        elseif card.cardType == "Weapon" and card.effect then
            card.effect(self, player)
        end

        -- Remove the card from the player's hand
        table.remove(player.hand, cardIndex)
        
        -- Check win condition
        if self.player1.health <= 0 or self.player2.health <= 0 then
            self:endGame()
        end
    else
        print("Not enough mana to play " .. (card.name or "this card"))
    end
end

function GameManager:endGame()
    -- Transition to game over scene (to be implemented)
    print("Game Over!")
end

return GameManager