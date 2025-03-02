-- game/managers/gamemanager.lua
-- Updated to handle multiple towers per player.
--   * player1.towers and player2.towers now each hold a list of towers.
--   * The game ends when a player's towers list is empty.
--   * isTileOccupiedByTower(x, y) returns the specific tower at that tile (if any).
--   * Summoning minions logic remains the same.
--   * Now with support for targeting effects
--   * Integrated with EventBus for better decoupling

local Player = require("game.core.player")
local Board = require("game.core.board")
local EffectManager = require("game.managers.effectmanager")
local Deck = require("game/core/deck")
local Tower = require("game.core.tower")  -- Tower module
local EventBus = require("game.eventbus")  -- Added for event-based architecture

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

    --------------------------------------------------
    -- Multiple Towers Setup
    -- Each player gets a towers table. If the config
    -- has multiple tower positions, create them all.
    --------------------------------------------------
    self.player1.towers = {}
    self.player2.towers = {}

    if selectedBoard and selectedBoard.towerPositions then
        -- Player 1 towers
        if selectedBoard.towerPositions.player1 then
            -- If the board config is an array of positions, create a tower for each
            if type(selectedBoard.towerPositions.player1) == "table" and selectedBoard.towerPositions.player1[1] then
                -- It's an array of tower positions
                for _, tPos in ipairs(selectedBoard.towerPositions.player1) do
                    local twr = Tower:new({
                        owner = self.player1,
                        position = tPos,
                        hp = 30,
                        imagePath = "assets/images/blue_tower.png"
                    })
                    table.insert(self.player1.towers, twr)
                end
            else
                -- It's a single tower position
                local twr = Tower:new({
                    owner = self.player1,
                    position = selectedBoard.towerPositions.player1,
                    hp = 30,
                    imagePath = "assets/images/blue_tower.png"
                })
                table.insert(self.player1.towers, twr)
            end
        end

        -- Player 2 towers
        if selectedBoard.towerPositions.player2 then
            if type(selectedBoard.towerPositions.player2) == "table" and selectedBoard.towerPositions.player2[1] then
                -- It's an array of tower positions
                for _, tPos in ipairs(selectedBoard.towerPositions.player2) do
                    local twr = Tower:new({
                        owner = self.player2,
                        position = tPos,
                        hp = 30,
                        imagePath = "assets/images/red_tower.png"
                    })
                    table.insert(self.player2.towers, twr)
                end
            else
                -- It's a single tower position
                local twr = Tower:new({
                    owner = self.player2,
                    position = selectedBoard.towerPositions.player2,
                    hp = 30,
                    imagePath = "assets/images/red_tower.png"
                })
                table.insert(self.player2.towers, twr)
            end
        end
    end

    -- Callback that the Gameplay scene can set
    self.onTurnStart = nil
    -- Callback triggered when the game is over
    self.onGameOver = nil
    -- Flag to indicate game is over
    self.gameOver = false
    
    -- Initialize event subscriptions
    self.eventSubscriptions = {}
    
    -- Setup event subscriptions
    self:initEventSubscriptions()
    
    -- Publish game initialized event
    EventBus.publish(EventBus.Events.GAME_INITIALIZED, self)

    return self
end

--------------------------------------------------
-- initEventSubscriptions():
-- Set up event listeners for game-related events
--------------------------------------------------
function GameManager:initEventSubscriptions()
    -- Clean up any existing subscriptions
    for _, sub in ipairs(self.eventSubscriptions) do
        EventBus.unsubscribe(sub)
    end
    self.eventSubscriptions = {}
    
    -- Subscribe to tower destroyed events to check game end condition
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.TOWER_DESTROYED,
        function(tower, destroyer)
            -- Check if this destroys all of a player's towers
            -- We'll let the update() method handle actual game end
        end,
        "GameManager-TowerHandler"
    ))
    
    -- Subscribe to battlecry triggered events
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.BATTLECRY_TRIGGERED,
        function(minion, player, gameManager)
            -- This will be handled by EffectManager, we just listen for logging
        end,
        "GameManager-BattlecryHandler"
    ))
    
    -- Subscribe to deathrattle triggered events
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.DEATHRATTLE_TRIGGERED,
        function(minion, player, gameManager)
            -- This will be handled by EffectManager, we just listen for logging
        end,
        "GameManager-DeathrattleHandler"
    ))
    
    -- Subscribe to specific effect events
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.EFFECT_TRIGGERED,
        function(effectName, player, target)
            -- Handle special effect logic here if needed
        end,
        "GameManager-EffectHandler"
    ))
end

--------------------------------------------------
-- update(dt):
-- Continuously checks the win condition.
-- Removes towers that have 0 or less HP.
-- The game ends if a player has no remaining towers.
--------------------------------------------------
function GameManager:update(dt)
    if not self.gameOver then
        -- Check all towers for player1
        for i = #self.player1.towers, 1, -1 do
            local t = self.player1.towers[i]
            if t.hp <= 0 then
                -- Publish tower destroyed event before removing
                EventBus.publish(EventBus.Events.TOWER_DESTROYED, t, nil)
                table.remove(self.player1.towers, i)
            end
        end

        -- Check all towers for player2
        for i = #self.player2.towers, 1, -1 do
            local t = self.player2.towers[i]
            if t.hp <= 0 then
                -- Publish tower destroyed event before removing
                EventBus.publish(EventBus.Events.TOWER_DESTROYED, t, nil)
                table.remove(self.player2.towers, i)
            end
        end

        -- If either player has no towers left, game ends
        if #self.player1.towers == 0 or #self.player2.towers == 0 then
            self:endGame()
        end
    end
end

--------------------------------------------------
-- draw():
-- Example debug: displays current turn info
-- (Tower HP is now displayed via boardRenderer or scene)
--------------------------------------------------
function GameManager:draw()
    love.graphics.printf("Current Turn: " .. self:getCurrentPlayer().name, 0, 20, love.graphics.getWidth(), "center")
end

--------------------------------------------------
-- endTurn():
-- Switches the current player and starts their turn.
--------------------------------------------------
function GameManager:endTurn()
    -- Publish turn ended event
    EventBus.publish(EventBus.Events.TURN_ENDED, self:getCurrentPlayer())
    
    if self.currentPlayer == 1 then
        self.currentPlayer = 2
    else
        self.currentPlayer = 1
    end
    self:startTurn()
end

--------------------------------------------------
-- startTurn():
-- Gains mana, draws a card, resets minions, triggers onTurnStart.
--------------------------------------------------
function GameManager:startTurn()
    local player = self:getCurrentPlayer()
    if player.maxManaCrystals < 10 then
        player.maxManaCrystals = player.maxManaCrystals + 1
    end
    
    -- Store old mana value for event
    local oldMana = player.manaCrystals
    player.manaCrystals = player.maxManaCrystals
    
    -- Publish mana changed event
    EventBus.publish(EventBus.Events.PLAYER_MANA_CHANGED, player, oldMana, player.manaCrystals)
    
    -- Draw a card using the player's method instead of accessing deck directly
    player:drawCard(1)
    
    -- Publish card drawn event for the most recently drawn card
    if #player.hand > 0 then
        local lastCard = player.hand[#player.hand]
        EventBus.publish(EventBus.Events.CARD_DRAWN, player, lastCard)
    end
    
    player.heroAttacked = false

    self.board:forEachMinion(function(minion, x, y)
        if minion.owner == player then
            minion.summoningSickness = false
            minion.hasMoved = false
            minion.canAttack = true
        end
    end)

    -- Maintain compatibility with existing callbacks
    if self.onTurnStart then
        if self.currentPlayer == 1 then
            self.onTurnStart("player1")
        else
            self.onTurnStart("player2")
        end
    end
    
    -- Publish turn started event with the player object
    EventBus.publish(EventBus.Events.TURN_STARTED, player)
end

--------------------------------------------------
-- getCurrentPlayer():
-- Returns player1 if currentPlayer == 1, else player2.
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
-- Returns the tower object occupying (x,y), or nil if none.
--------------------------------------------------
function GameManager:isTileOccupiedByTower(x, y)
    for _, tower in ipairs(self.player1.towers) do
        if tower.position.x == x and tower.position.y == y then
            return tower
        end
    end
    for _, tower in ipairs(self.player2.towers) do
        if tower.position.x == x and tower.position.y == y then
            return tower
        end
    end
    return nil
end

--------------------------------------------------
-- playCardFromHand(player, cardIndex):
-- Attempts to play the specified card from the player's hand.
-- Now with support for effects that require targeting.
--------------------------------------------------
function GameManager:playCardFromHand(player, cardIndex)
    local card = player.hand[cardIndex]
    if not card then return false end
    
    if card.cost > player.manaCrystals then
        print("Not enough mana to play " .. (card.name or "this card"))
        return false
    end
    
    -- If this card has an effect that requires targeting,
    -- it should be handled in the gameplay scene, not here
    if card.cardType == "Spell" and card.effectKey and EffectManager.requiresTarget(card.effectKey) then
        print("This spell requires a target. Cannot play it directly.")
        return false
    elseif card.cardType == "Minion" then
        print("Select a spawn tile in your spawn zone to summon the minion.")
        return false
    else
        -- Apply non-targeting effect
        if card.effectKey then
            local success = EffectManager.applyEffectKey(card.effectKey, self, player)
            if not success then
                print("Failed to apply effect: " .. (card.effectKey or "unknown"))
                return false
            end
        end
    end
    
    -- Store old mana for event
    local oldMana = player.manaCrystals
    player.manaCrystals = player.manaCrystals - card.cost
    
    -- Publish mana changed event
    EventBus.publish(EventBus.Events.PLAYER_MANA_CHANGED, player, oldMana, player.manaCrystals)
    
    -- Remove the card from hand
    local playedCard = table.remove(player.hand, cardIndex)
    
    -- Publish card played event
    EventBus.publish(EventBus.Events.CARD_PLAYED, player, playedCard)
    
    return true
end

--------------------------------------------------
-- summonMinion(player, card, cardIndex, x, y):
-- Places a minion on the board if valid.
-- Now publishes events for minion summoning and card playing.
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
    
    -- Create minion from card data
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
        summoningSickness = true,
        battlecry = card.battlecry,
        deathrattle = card.deathrattle
    }
    
    -- Place on board
    local success = self.board:placeMinion(minion, x, y)
    if success then
        -- Trigger battlecry effects
        if minion.battlecry then
            -- Publish battlecry event for EffectManager and other listeners
            EventBus.publish(EventBus.Events.BATTLECRY_TRIGGERED, minion, player, self)
        end
        
        -- Store old mana for event
        local oldMana = player.manaCrystals
        
        -- Update player's hand and mana
        table.remove(player.hand, cardIndex)
        player.manaCrystals = player.manaCrystals - card.cost
        
        -- Publish related events in logical order
        EventBus.publish(EventBus.Events.CARD_PLAYED, player, card)
        EventBus.publish(EventBus.Events.MINION_SUMMONED, player, minion, x, y)
        EventBus.publish(EventBus.Events.PLAYER_MANA_CHANGED, player, oldMana, player.manaCrystals)
        
        return true
    else
        print("Failed to place minion: spawn zone full!")
        return false
    end
end

--------------------------------------------------
-- endGame():
-- Ends the game. Winner is whoever still has towers alive.
-- If both or neither have towers, it's a draw.
--------------------------------------------------
function GameManager:endGame()
    if self.gameOver then return end
    self.gameOver = true

    print("Game Over!")

    local p1Alive = (#self.player1.towers > 0)
    local p2Alive = (#self.player2.towers > 0)
    local winner = nil

    if p1Alive and not p2Alive then
        winner = self.player1
    elseif p2Alive and not p1Alive then
        winner = self.player2
    else
        winner = nil -- Draw
    end

    if winner then
        print(winner.name .. " wins the match!")
    else
        print("The match ends in a draw.")
    end

    -- Call legacy callback for backward compatibility
    if self.onGameOver then
        self.onGameOver(winner)
    end
    
    -- Publish game ended event
    EventBus.publish(EventBus.Events.GAME_ENDED, winner)
end

--------------------------------------------------
-- getTowerAt(x, y):
-- Returns the tower at x,y if any, else nil
-- (Optional helper if you want direct lookups).
--------------------------------------------------
function GameManager:getTowerAt(x, y)
    local tower = self:isTileOccupiedByTower(x, y)
    return tower
end

--------------------------------------------------
-- destroy():
-- Clean up resources and subscriptions.
--------------------------------------------------
function GameManager:destroy()
    -- Clean up event subscriptions
    for _, sub in ipairs(self.eventSubscriptions) do
        EventBus.unsubscribe(sub)
    end
    self.eventSubscriptions = {}
end

return GameManager