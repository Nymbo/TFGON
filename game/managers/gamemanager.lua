-- game/managers/gamemanager.lua
-- Updated to accept a selected board configuration as well as deck.
-- Now supports AI opponent with custom deck and improved win condition checking based solely on Towers.
-- When a tower reaches 0 HP, it is removed from the board.
-- When a player has no towers remaining, the game is over.
-- An onGameOver callback is provided so that the gameplay scene can display a popup.

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
-- 'isAIOpponent' determines if player 2 should use an AI deck.
-- onTurnStart and onGameOver callbacks can be set.
--------------------------------------------------
function GameManager:new(selectedDeck, selectedBoard, isAIOpponent)
    local self = setmetatable({}, GameManager)

    -- Create players; assign custom deck to player 1 if provided.
    self.player1 = Player:new("Player 1", selectedDeck)
    
    -- If AI opponent, set up the AI deck.
    if isAIOpponent then
        local AIDeck = require("game.data.aidecks")
        local cardsData = require("data.cards")
        local aiDeck = AIDeck.normalDeck(cardsData)
        self.player2 = Player:new("AI Opponent", aiDeck)
    else
        self.player2 = Player:new("Player 2")
    end
    
    -- Create board from selected configuration or use default.
    self.board = Board:new(selectedBoard)

    self.currentPlayer = 1

    self.player1.manaCrystals = 0
    self.player2.manaCrystals = 0

    self.player1:drawCard(3)
    self.player2:drawCard(3)
    
    -- Initialize towers if the board has tower positions.
    if selectedBoard and selectedBoard.towerPositions then
        -- Player 1 tower.
        if selectedBoard.towerPositions.player1 then
            self.player1.tower = Tower:new({
                owner = self.player1,
                position = selectedBoard.towerPositions.player1,
                hp = 30,
                imagePath = "assets/images/blue_tower.png"
            })
        end
        
        -- Player 2 tower.
        if selectedBoard.towerPositions.player2 then
            self.player2.tower = Tower:new({
                owner = self.player2,
                position = selectedBoard.towerPositions.player2,
                hp = 30,
                imagePath = "assets/images/red_tower.png"
            })
        end
    end

    -- Callback that the Gameplay scene can set to display banners, etc.
    self.onTurnStart = nil

    -- Callback to be triggered when the game is over (for a popup menu, etc.)
    self.onGameOver = nil

    -- Flag to indicate that the game is over so no further actions are processed.
    self.gameOver = false

    return self
end

--------------------------------------------------
-- update(dt):
-- Continuously checks the win condition.
-- If a tower's HP falls to 0, it is removed.
-- The game ends when a player has no tower.
--------------------------------------------------
function GameManager:update(dt)
    if not self.gameOver then
        -- Remove towers that have 0 or less HP.
        if self.player1.tower and self.player1.tower.hp <= 0 then
            self.player1.tower = nil
        end
        if self.player2.tower and self.player2.tower.hp <= 0 then
            self.player2.tower = nil
        end
        -- Game over if a player no longer has a tower.
        if not self.player1.tower or not self.player2.tower then
            self:endGame()
        end
    end
end

--------------------------------------------------
-- draw():
-- Displays current turn info and tower HP for debugging.
--------------------------------------------------
function GameManager:draw()
    love.graphics.printf("Current Turn: " .. self:getCurrentPlayer().name, 0, 20, love.graphics.getWidth(), "center")
    
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
-- Gains mana, draws a card, resets minions, and triggers onTurnStart callback.
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
-- Ends the game and determines the winner based solely on towers.
-- Triggers the onGameOver callback if one is set.
--------------------------------------------------
function GameManager:endGame()
    if self.gameOver then return end  -- Prevent multiple calls.
    self.gameOver = true

    print("Game Over!")
    
    local winner = nil
    if not self.player1.tower and not self.player2.tower then
        winner = nil  -- Draw
    elseif not self.player1.tower then
        winner = self.player2
    elseif not self.player2.tower then
        winner = self.player1
    end
    
    if winner then
        print(winner.name .. " wins the match!")
    else
        print("The match ends in a draw.")
    end

    if self.onGameOver then
        self.onGameOver(winner)
    end
end

return GameManager