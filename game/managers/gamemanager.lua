-- game/managers/gamemanager.lua
-- Handles overall game flow: players, turn order, playing cards, etc.
-- Now refactored to call EffectManager for spells/weapons, and
-- triggerBattlecry for minions.

local Player = require("game.core.player")
local Board = require("game.core.board")
local EffectManager = require("game.managers.effectmanager")  -- NEW: For applying effects

local GameManager = {}
GameManager.__index = GameManager

function GameManager:new()
    local self = setmetatable({}, GameManager)

    self.player1 = Player:new("Player 1")
    self.player2 = Player:new("Player 2")
    self.board = Board:new()

    self.currentPlayer = 1

    -- Give each player 0 starting mana, and 3 initial cards
    self.player1.manaCrystals = 0
    self.player2.manaCrystals = 0

    self.player1:drawCard(3)
    self.player2:drawCard(3)

    return self
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
    local current = self:getCurrentPlayer()
    -- Any end-of-turn logic goes here

    -- Switch active player
    if self.currentPlayer == 1 then
        self.currentPlayer = 2
    else
        self.currentPlayer = 1
    end

    -- Start next player's turn
    self:startTurn()
end

function GameManager:startTurn()
    local player = self:getCurrentPlayer()

    -- Increase max mana (up to 10), refill mana
    if player.maxManaCrystals < 10 then
        player.maxManaCrystals = player.maxManaCrystals + 1
    end
    player.manaCrystals = player.maxManaCrystals

    -- Draw a card at the start of turn
    player:drawCard(1)

    -- Reset hero attack
    player.heroAttacked = false

    -- Reset each minion's ability to attack
    local minions = (player == self.player1) and self.board.player1Minions
                                           or self.board.player2Minions
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

--------------------------------------------------
-- playCardFromHand:
--  1) Check mana
--  2) Subtract cost
--  3) Handle card type
--     - Minion -> place on board, triggerBattlecry if present
--     - Spell  -> applyEffectKey
--     - Weapon -> applyEffectKey
--  4) Remove from hand
--  5) Check if game is over
--------------------------------------------------
function GameManager:playCardFromHand(player, cardIndex)
    local card = player.hand[cardIndex]
    if not card then
        return
    end

    -- Check if enough mana
    if card.cost <= player.manaCrystals then
        player.manaCrystals = player.manaCrystals - card.cost

        if card.cardType == "Minion" then
            -- Place minion on board
            local minion = {
                name = card.name,
                attack = card.attack,
                maxHealth = card.health,
                currentHealth = card.health,
                canAttack = false,

                -- If a minion has a deathrattle function, store it in the minion table
                -- so that we can trigger it upon death in combat.lua
                deathrattle = card.deathrattle
            }

            -- Insert into the correct board list
            if player == self.player1 then
                table.insert(self.board.player1Minions, minion)
            else
                table.insert(self.board.player2Minions, minion)
            end

            -- Trigger battlecry if present
            EffectManager.triggerBattlecry(card, self, player)

        elseif card.cardType == "Spell" then
            -- Spells use effectKey to do something immediate
            if card.effectKey then
                EffectManager.applyEffectKey(card.effectKey, self, player)
            end

        elseif card.cardType == "Weapon" then
            -- Weapons use effectKey to equip or do something
            if card.effectKey then
                EffectManager.applyEffectKey(card.effectKey, self, player)
            end
        end

        -- Remove card from the player's hand
        table.remove(player.hand, cardIndex)

        -- Check if game is over
        if self.player1.health <= 0 or self.player2.health <= 0 then
            self:endGame()
        end
    else
        print("Not enough mana to play " .. (card.name or "this card"))
    end
end

function GameManager:endGame()
    print("Game Over!")
    -- Could change to a 'GameOver' scene if desired
end

return GameManager
