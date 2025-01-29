-- game/managers/gamemanager.lua
-- Handles overall game flow: tracks players, turn order,
-- mana, drawing cards, playing cards, and ending the game.

--------------------------------------------------
-- Requires for core objects that the GameManager
-- needs (Player, Board).
--------------------------------------------------
local Player = require("game.core.player")   -- Handles player properties (e.g., health, mana, hand)
local Board = require("game.core.board")     -- Manages minions on the board

--------------------------------------------------
-- Table definition for GameManager
--------------------------------------------------
local GameManager = {}
GameManager.__index = GameManager

--------------------------------------------------
-- Constructor for the GameManager.
-- Creates two players, initializes the board,
-- sets starting mana to 0, draws initial cards, etc.
--------------------------------------------------
function GameManager:new()
    local self = setmetatable({}, GameManager)

    -- Create two players with generic names
    self.player1 = Player:new("Player 1")
    self.player2 = Player:new("Player 2")

    -- The board holds each player's minions
    self.board = Board:new()

    -- 1 or 2 to indicate whose turn it is
    self.currentPlayer = 1

    -- Start each player with 0 mana
    self.player1.manaCrystals = 0
    self.player2.manaCrystals = 0

    -- Give each player an initial set of cards
    -- (3 cards for demonstration)
    self.player1:drawCard(3)
    self.player2:drawCard(3)

    return self
end

--------------------------------------------------
-- update(dt):
-- Called once per frame; can be used for animations,
-- timers, or other time-based logic if needed.
--------------------------------------------------
function GameManager:update(dt)
    -- Currently no ongoing animations/timers
end

--------------------------------------------------
-- draw():
-- Draws some basic text about the turn, HP, and mana.
-- The actual board and hand are drawn in the scene.
--------------------------------------------------
function GameManager:draw()
    -- Display whose turn it is
    love.graphics.printf(
        "Current Turn: " .. self:getCurrentPlayer().name,
        0, 20, love.graphics.getWidth(), "center"
    )

    -- Display Player 1's health and mana
    love.graphics.printf(
        self.player1.name .. " HP: " .. self.player1.health ..
        " | Mana: " .. self.player1.manaCrystals .. "/" .. self.player1.maxManaCrystals,
        0, 60, love.graphics.getWidth(), "left"
    )

    -- Display Player 2's health and mana
    love.graphics.printf(
        self.player2.name .. " HP: " .. self.player2.health ..
        " | Mana: " .. self.player2.manaCrystals .. "/" .. self.player2.maxManaCrystals,
        0, 80, love.graphics.getWidth(), "left"
    )
end

--------------------------------------------------
-- endTurn():
-- Called when the current player ends their turn.
-- Performs end-of-turn logic, then switches player
-- and starts the new turn.
--------------------------------------------------
function GameManager:endTurn()
    local current = self:getCurrentPlayer()
    -- End-of-turn logic can be expanded here if needed
    -- (e.g., applying fatigue, removing temporary buffs, etc.)

    -- Switch active player
    if self.currentPlayer == 1 then
        self.currentPlayer = 2
    else
        self.currentPlayer = 1
    end

    -- Start the new player's turn
    self:startTurn()
end

--------------------------------------------------
-- startTurn():
-- Called at the beginning of a player's turn.
-- Increases mana crystals (up to 10), refills mana,
-- draws a card, and resets minion attacks.
--------------------------------------------------
function GameManager:startTurn()
    local player = self:getCurrentPlayer()

    -- Increase the player's max mana crystals by 1,
    -- up to a max of 10
    if player.maxManaCrystals < 10 then
        player.maxManaCrystals = player.maxManaCrystals + 1
    end
    -- Refill current mana to match max
    player.manaCrystals = player.maxManaCrystals

    -- Draw one card at the start of each turn
    player:drawCard(1)

    -- Reset hero attack status if they had a weapon
    player.heroAttacked = false
    
    -- Allow all minions controlled by this player to attack again
    local minions = (player == self.player1)
                    and self.board.player1Minions
                    or self.board.player2Minions
    for _, minion in ipairs(minions) do
        minion.canAttack = true
    end
end

--------------------------------------------------
-- getCurrentPlayer():
-- Returns the Player object for the current player
-- (player1 or player2).
--------------------------------------------------
function GameManager:getCurrentPlayer()
    if self.currentPlayer == 1 then
        return self.player1
    else
        return self.player2
    end
end

--------------------------------------------------
-- getEnemyPlayer(player):
-- Given a Player object, returns that player's
-- opponent (the other Player).
--------------------------------------------------
function GameManager:getEnemyPlayer(player)
    if player == self.player1 then
        return self.player2
    else
        return self.player1
    end
end

--------------------------------------------------
-- playCardFromHand(player, cardIndex):
-- Allows the specified 'player' to play a card
-- (if they have enough mana) from their hand at
-- the given 'cardIndex'. Supports Minions, Spells,
-- and Weapons. Also removes the card from the hand.
--------------------------------------------------
function GameManager:playCardFromHand(player, cardIndex)
    local card = player.hand[cardIndex]
    if not card then
        return -- Invalid card index
    end

    -- Check if the player has sufficient mana
    if card.cost <= player.manaCrystals then
        -- Subtract mana cost
        player.manaCrystals = player.manaCrystals - card.cost

        if card.cardType == "Minion" then
            -- Create a minion on the board
            local minion = {
                name = card.name,
                attack = card.attack,
                maxHealth = card.health,
                currentHealth = card.health,
                canAttack = false -- Minions can't attack the turn they're played
            }
            -- Insert into the correct list of minions
            if player == self.player1 then
                table.insert(self.board.player1Minions, minion)
            else
                table.insert(self.board.player2Minions, minion)
            end

        elseif card.cardType == "Spell" and card.effect then
            -- Spells have an 'effect' function that is invoked
            card.effect(self, player)

        elseif card.cardType == "Weapon" and card.effect then
            -- Weapons also have an 'effect' function for equipping
            card.effect(self, player)
        end

        -- Remove the card from the player's hand
        table.remove(player.hand, cardIndex)
        
        -- Check for a win condition
        if self.player1.health <= 0 or self.player2.health <= 0 then
            self:endGame()
        end
    else
        -- Not enough mana
        print("Not enough mana to play " .. (card.name or "this card"))
    end
end

--------------------------------------------------
-- endGame():
-- Triggered if a player's health drops to 0 or below.
-- Currently prints a message but can transition to
-- a dedicated "Game Over" scene.
--------------------------------------------------
function GameManager:endGame()
    print("Game Over!")
    -- You might call a scene change here, e.g.:
    -- sceneManager:changeScene("gameover")
end

return GameManager
