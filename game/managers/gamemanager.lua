-- game/managers/gamemanager.lua
-- This module now uses a grid-based board with flipped spawn zones,
-- and it supports selecting any spawn tile when summoning a minion.
-- Also, minion cards (of type "Minion") must be summoned via a pending summon.
local Player = require("game.core.player")
local Board = require("game.core.board")
local EffectManager = require("game.managers.effectmanager")

local GameManager = {}
GameManager.__index = GameManager

function GameManager:new()
    local self = setmetatable({}, GameManager)

    self.player1 = Player:new("Player 1")
    self.player2 = Player:new("Player 2")
    self.board = Board:new()

    self.currentPlayer = 1

    self.player1.manaCrystals = 0
    self.player2.manaCrystals = 0

    self.player1:drawCard(3)
    self.player2:drawCard(3)

    return self
end

-- Helper to find a free spawn tile in the player's spawn zone.
-- (Now unused for minions; summoning will use the player's selection.)
-- For reference: Player 1's spawn zone is the bottom row (row 6), Player 2's is the top row (row 1).
function GameManager:findSpawnTile(player)
    local spawnRow = (player == self.player1) and self.board.rows or 1
    for x = 1, self.board.cols do
        if self.board:isEmpty(x, spawnRow) then
            return x, spawnRow
        end
    end
    return nil, nil
end

function GameManager:update(dt)
    -- No special updates yet
end

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
    if self.currentPlayer == 1 then
        self.currentPlayer = 2
    else
        self.currentPlayer = 1
    end
    self:startTurn()
end

function GameManager:startTurn()
    local player = self:getCurrentPlayer()

    if player.maxManaCrystals < 10 then
        player.maxManaCrystals = player.maxManaCrystals + 1
    end
    player.manaCrystals = player.maxManaCrystals

    player:drawCard(1)

    player.heroAttacked = false

    -- Reset actions for minions that belong to the current player.
    -- (Minions played in a previous turn will be refreshed; newly played ones retain their summoning sickness.)
    self.board:forEachMinion(function(minion, x, y)
        if minion.owner == player then
            minion.summoningSickness = false
            minion.hasMoved = false
            minion.canAttack = true
        end
    end)
end

function GameManager:getCurrentPlayer()
    return (self.currentPlayer == 1) and self.player1 or self.player2
end

function GameManager:getEnemyPlayer(player)
    return (player == self.player1) and self.player2 or self.player1
end

--------------------------------------------------
-- playCardFromHand:
-- Handles playing a card immediately for non-minion types.
-- For minions, players must choose a spawn tile via the pending summon state.
--------------------------------------------------
function GameManager:playCardFromHand(player, cardIndex)
    local card = player.hand[cardIndex]
    if not card then
        return
    end

    if card.cost > player.manaCrystals then
        print("Not enough mana to play " .. (card.name or "this card"))
        return
    end

    if card.cardType == "Minion" then
        print("Select a spawn tile in your spawn zone to summon the minion.")
        return
    elseif card.cardType == "Spell" then
        if card.effectKey then
            EffectManager.applyEffectKey(card.effectKey, self, player)
        end
    elseif card.cardType == "Weapon" then
        if card.effectKey then
            EffectManager.applyEffectKey(card.effectKey, self, player)
        end
    end

    player.manaCrystals = player.manaCrystals - card.cost
    table.remove(player.hand, cardIndex)

    if self.player1.health <= 0 or self.player2.health <= 0 then
        self:endGame()
    end
end

--------------------------------------------------
-- summonMinion:
-- Summons a minion from a card into the specified tile.
-- This function is called when a player selects a spawn tile.
-- It validates that the chosen tile is in the player's spawn zone.
--------------------------------------------------
function GameManager:summonMinion(player, card, cardIndex, x, y)
    local validSpawnRow = (player == self.player1) and self.board.rows or 1
    if y ~= validSpawnRow then
        print("Invalid spawn tile! Please select a tile in your spawn zone.")
        return false
    end
    if not self.board:isEmpty(x, y) then
        print("Selected tile is not empty!")
        return false
    end

    local minion = {
        name = card.name,
        attack = card.attack,
        maxHealth = card.health,
        currentHealth = card.health,
        movement = card.movement or 1,
        archetype = card.archetype or "Melee",
        canAttack = false,
        owner = player,
        hasMoved = false,
        summoningSickness = true  -- Newly played minions cannot act immediately.
    }
    if card.deathrattle then
        minion.deathrattle = card.deathrattle
    end

    local success = self.board:placeMinion(minion, x, y)
    if success then
        EffectManager.triggerBattlecry(card, self, player)
        table.remove(player.hand, cardIndex)
        if self.player1.health <= 0 or self.player2.health <= 0 then
            self:endGame()
        end
        return true
    else
        print("Failed to place minion: spawn zone full!")
        return false
    end
end

function GameManager:endGame()
    print("Game Over!")
    -- Transition to a GameOver scene if desired
end

return GameManager
