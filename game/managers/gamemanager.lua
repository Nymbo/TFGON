-- game/managers/gamemanager.lua
-- Updated to accept a selected deck for player 1.
local Player = require("game.core.player")
local Board = require("game.core.board")
local EffectManager = require("game.managers.effectmanager")
local Deck = require("game/core/deck")

local GameManager = {}
GameManager.__index = GameManager

--------------------------------------------------
-- Constructor for GameManager.
-- 'selectedDeck' is used for player 1.
--------------------------------------------------
function GameManager:new(selectedDeck)
    local self = setmetatable({}, GameManager)

    -- Create players; assign custom deck to player 1 if provided.
    self.player1 = Player:new("Player 1", selectedDeck)
    self.player2 = Player:new("Player 2")
    self.board = Board:new()

    self.currentPlayer = 1

    self.player1.manaCrystals = 0
    self.player2.manaCrystals = 0

    self.player1:drawCard(3)
    self.player2:drawCard(3)
    
    -- Initialize towers for each player.
    self.player1.tower = { position = { x = 5, y = 8 }, hp = 30 }
    self.player2.tower = { position = { x = 5, y = 2 }, hp = 30 }

    return self
end

-- The rest of the file remains unchanged...
function GameManager:update(dt) end
function GameManager:draw()
    love.graphics.printf("Current Turn: " .. self:getCurrentPlayer().name, 0, 20, love.graphics.getWidth(), "center")
    love.graphics.printf(self.player1.name .. " Tower HP: " .. self.player1.tower.hp, 0, 60, love.graphics.getWidth(), "left")
    love.graphics.printf(self.player2.name .. " Tower HP: " .. self.player2.tower.hp, 0, 80, love.graphics.getWidth(), "left")
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
    if player.maxManaCrystals < 10 then player.maxManaCrystals = player.maxManaCrystals + 1 end
    player.manaCrystals = player.maxManaCrystals
    player:drawCard(1)
    player.heroAttacked = false
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
function GameManager:isTileOccupiedByTower(x, y)
    local p1Tower = self.player1.tower
    local p2Tower = self.player2.tower
    if p1Tower and p1Tower.position.x == x and p1Tower.position.y == y then return true end
    if p2Tower and p2Tower.position.x == x and p2Tower.position.y == y then return true end
    return false
end
function GameManager:playCardFromHand(player, cardIndex)
    local card = player.hand[cardIndex]
    if not card then return end
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
    if self.player1.tower.hp <= 0 or self.player2.tower.hp <= 0 then
        self:endGame()
    end
end
function GameManager:summonMinion(player, card, cardIndex, x, y)
    local validSpawnRow = (player == self.player1) and self.board.rows or 1
    if y ~= validSpawnRow then
        print("Invalid spawn tile! Please select a tile in your spawn zone.")
        return false
    end
    if self:isTileOccupiedByTower(x, y) then
        print("Cannot summon minion onto a tower!")
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
        summoningSickness = true
    }
    if card.deathrattle then
        minion.deathrattle = card.deathrattle
    end
    local success = self.board:placeMinion(minion, x, y)
    if success then
        EffectManager.triggerBattlecry(card, self, player)
        table.remove(player.hand, cardIndex)
        if self.player1.tower.hp <= 0 or self.player2.tower.hp <= 0 then
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
end

return GameManager
