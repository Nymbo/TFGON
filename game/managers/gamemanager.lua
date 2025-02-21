-- game/managers/gamemanager.lua
-- Updated to accept a selected board configuration as well as deck

local Player = require("game.core.player")
local Board = require("game.core.board")
local EffectManager = require("game.managers.effectmanager")
local Deck = require("game/core/deck")
local Tower = require("game.core.tower")  -- Newly added Tower module

local GameManager = {}
GameManager.__index = GameManager

--------------------------------------------------
-- Constructor for GameManager.
-- 'selectedDeck' is used for player 1.
-- 'selectedBoard' is the board configuration to use.
-- Added "self.onTurnStart = nil" for hooking into turn-start events.
--------------------------------------------------
function GameManager:new(selectedDeck, selectedBoard)
    local self = setmetatable({}, GameManager)

    -- Create players; assign custom deck to player 1 if provided.
    self.player1 = Player:new("Player 1", selectedDeck)
    self.player2 = Player:new("Player 2")
    
    -- Create board from selected configuration or use default
    self.board = Board:new(selectedBoard)

    self.currentPlayer = 1

    self.player1.manaCrystals = 0
    self.player2.manaCrystals = 0

    self.player1:drawCard(3)
    self.player2:drawCard(3)
    
    -- Initialize towers if the board has tower positions
    if selectedBoard and selectedBoard.towerPositions then
        -- Player 1 tower
        if selectedBoard.towerPositions.player1 then
            self.player1.tower = Tower:new({
                owner = self.player1,
                position = selectedBoard.towerPositions.player1,
                hp = 30,
                imagePath = "assets/images/panel_grey_bolts_blue.png"
            })
        end
        
        -- Player 2 tower
        if selectedBoard.towerPositions.player2 then
            self.player2.tower = Tower:new({
                owner = self.player2,
                position = selectedBoard.towerPositions.player2,
                hp = 30,
                imagePath = "assets/images/panel_grey_bolts_red.png"
            })
        end
    end

    -- Callback that the Gameplay scene can set to display banners, etc.
    self.onTurnStart = nil

    return self
end

--------------------------------------------------
-- update(dt):
-- Currently does nothing, but is here if needed later.
--------------------------------------------------
function GameManager:update(dt) end

--------------------------------------------------
-- draw():
-- Basic turn info and tower health for debugging.
--------------------------------------------------
function GameManager:draw()
    love.graphics.printf("Current Turn: " .. self:getCurrentPlayer().name, 0, 20, love.graphics.getWidth(), "center")
    
    -- Only display tower HP if towers exist
    if self.player1.tower then
        love.graphics.printf(self.player1.name .. " Tower HP: " .. self.player1.tower.hp, 0, 60, love.graphics.getWidth(), "left")
    end
    
    if self.player2.tower then
        love.graphics.printf(self.player2.name .. " Tower HP: " .. self.player2.tower.hp, 0, 80, love.graphics.getWidth(), "left")
    end
end

--------------------------------------------------
-- endTurn():
-- Switches the current player and starts their turn.
--------------------------------------------------
function GameManager:endTurn()
    if self.currentPlayer == 1 then
        self.currentPlayer = 2
    else
        self.currentPlayer = 1
    end
    self:startTurn()
end

--------------------------------------------------
-- startTurn():
-- Gains mana, draws a card, resets minions, triggers onTurnStart callback.
--------------------------------------------------
function GameManager:startTurn()
    local player = self:getCurrentPlayer()
    if player.maxManaCrystals < 10 then
        player.maxManaCrystals = player.maxManaCrystals + 1
    end
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

    -- Trigger the "onTurnStart" callback so the gameplay scene can show banners, etc.
    if self.onTurnStart then
        if self.currentPlayer == 1 then
            self.onTurnStart("player1")
        else
            self.onTurnStart("player2")
        end
    end
end

--------------------------------------------------
-- getCurrentPlayer():
-- Returns player1 if currentPlayer == 1, otherwise player2.
--------------------------------------------------
function GameManager:getCurrentPlayer()
    return (self.currentPlayer == 1) and self.player1 or self.player2
end

--------------------------------------------------
-- getEnemyPlayer(player):
-- Returns the opponent of the given player.
--------------------------------------------------
function GameManager:getEnemyPlayer(player)
    return (player == self.player1) and self.player2 or self.player1
end

--------------------------------------------------
-- isTileOccupiedByTower(x, y):
-- Checks if the given tile coordinates are occupied by a tower.
--------------------------------------------------
function GameManager:isTileOccupiedByTower(x, y)
    if self.player1.tower and self.player1.tower.position.x == x and self.player1.tower.position.y == y then
        return true
    end
    if self.player2.tower and self.player2.tower.position.x == x and self.player2.tower.position.y == y then
        return true
    end
    return false
end

--------------------------------------------------
-- playCardFromHand(player, cardIndex):
-- Attempts to play the specified card from the player's hand.
--------------------------------------------------
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
    
    -- Only check tower health if towers exist
    if (self.player1.tower and self.player1.tower.hp <= 0) or 
       (self.player2.tower and self.player2.tower.hp <= 0) then
        self:endGame()
    end
end

--------------------------------------------------
-- summonMinion(player, card, cardIndex, x, y):
-- Places a minion on the board at (x, y), if valid.
--------------------------------------------------
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
        player.manaCrystals = player.manaCrystals - card.cost
        
        -- Only check tower health if towers exist
        if (self.player1.tower and self.player1.tower.hp <= 0) or 
           (self.player2.tower and self.player2.tower.hp <= 0) then
            self:endGame()
        end
        
        return true
    else
        print("Failed to place minion: spawn zone full!")
        return false
    end
end

--------------------------------------------------
-- endGame():
-- Currently just prints "Game Over!" but can trigger a scene change or message.
--------------------------------------------------
function GameManager:endGame()
    print("Game Over!")
    
    -- Determine the winner based on tower health or other conditions
    local winner = nil
    
    -- If there are towers, check which one is destroyed
    if self.player1.tower and self.player2.tower then
        if self.player1.tower.hp <= 0 then
            winner = self.player2
        elseif self.player2.tower.hp <= 0 then
            winner = self.player1
        end
    end
    
    -- If no towers, maybe check player health instead
    if not winner then
        if self.player1.health <= 0 then
            winner = self.player2
        elseif self.player2.health <= 0 then
            winner = self.player1
        end
    end
    
    if winner then
        print(winner.name .. " wins the match!")
    else
        print("The match ends in a draw.")
    end
end

return GameManager