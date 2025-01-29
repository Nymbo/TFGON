-- game/scenes/gameplay/input.lua
-- Handles mouse/keyboard input for the gameplay scene,
-- so gameplay.lua remains compact.

--------------------------------------------------
-- Require the CardRenderer so we can compute
-- card click areas
--------------------------------------------------
local CardRenderer = require("game.ui.cardrenderer")

--------------------------------------------------
-- We re-use the "End Turn" button geometry
-- to detect clicks/hover.
--------------------------------------------------
local END_TURN_BUTTON = {
    width = 120,
    height = 40
}

--------------------------------------------------
-- Constants for minion dimensions & spacing (for click detection)
--------------------------------------------------
local MINION_WIDTH = 80
local MINION_HEIGHT = 100
local SPACING = 10

--------------------------------------------------
-- Helper: checks if (x, y) is within the rect
-- (rx, ry, rw, rh).
--------------------------------------------------
local function isPointInRect(x, y, rx, ry, rw, rh)
    return x >= rx and x <= rx + rw and y >= ry and y <= ry + rh
end

--------------------------------------------------
-- Retrieve the minions and their Y position
-- for a given player (this helps with click detection).
--------------------------------------------------
local function getPlayerMinionArea(gameManager, player)
    local isPlayer1 = (player == gameManager.player1)
    local screenHeight = love.graphics.getHeight()

    -- The Y position is different for top or bottom player
    local yPos = isPlayer1
        and math.floor(screenHeight * 0.6) + 10
        or math.floor(screenHeight * 0.25) + 10

    local minions = isPlayer1 and gameManager.board.player1Minions
                               or gameManager.board.player2Minions
    return minions, yPos
end

--------------------------------------------------
-- We'll define a table to export our input logic
--------------------------------------------------
local InputSystem = {}

--------------------------------------------------
-- Checks if the mouse is hovering over the End Turn button
--------------------------------------------------
function InputSystem.checkEndTurnHover(gameplay)
    local mx, my = love.mouse.getPosition()
    local buttonX = love.graphics.getWidth() - END_TURN_BUTTON.width - 20
    local buttonY = love.graphics.getHeight() / 2 - END_TURN_BUTTON.height / 2

    return isPointInRect(mx, my, buttonX, buttonY, END_TURN_BUTTON.width, END_TURN_BUTTON.height)
end

--------------------------------------------------
-- Main mousepressed logic:
--  1) Check End Turn button
--  2) Check for card clicks in hand
--  3) Check for selecting an attacker
--  4) Check for choosing a target (if an attacker is selected)
--------------------------------------------------
function InputSystem.mousepressed(gameplay, x, y, button, istouch, presses)
    if button ~= 1 then
        return -- We only care about left-click for now
    end

    local gm = gameplay.gameManager
    local currentPlayer = gm:getCurrentPlayer()

    --------------------------------------------------
    -- 1) End Turn button click check
    --------------------------------------------------
    local buttonX = love.graphics.getWidth() - END_TURN_BUTTON.width - 20
    local buttonY = love.graphics.getHeight() / 2 - END_TURN_BUTTON.height / 2

    if isPointInRect(x, y, buttonX, buttonY, END_TURN_BUTTON.width, END_TURN_BUTTON.height) then
        gm:endTurn()
        return
    end

    --------------------------------------------------
    -- 2) Check if a card in the player's hand was clicked
    --------------------------------------------------
    local hand = currentPlayer.hand
    local cardWidth, cardHeight = CardRenderer.getCardDimensions()
    local totalWidth = #hand * (cardWidth + 10)
    local startX = (love.graphics.getWidth() - totalWidth) / 2
    local cardY = love.graphics.getHeight() - cardHeight - 60

    for i, card in ipairs(hand) do
        local cardX = startX + (i - 1) * (cardWidth + 10)

        if isPointInRect(x, y, cardX, cardY, cardWidth, cardHeight) then
            -- Check if there's enough mana
            if card.cost <= currentPlayer.manaCrystals then
                gm:playCardFromHand(currentPlayer, i)
            end
            -- We stop after playing one card
            return
        end
    end

    --------------------------------------------------
    -- 3) Selecting an attacker if none is already selected
    --------------------------------------------------
    if not gameplay.selectedAttacker then
        local minions, minionY = getPlayerMinionArea(gm, currentPlayer)
        local totalMinionWidth = #minions * (MINION_WIDTH + SPACING)
        local startMinionX = (love.graphics.getWidth() - totalMinionWidth) / 2

        -- Check if we clicked on a minion
        for i, minion in ipairs(minions) do
            local minX = startMinionX + (i - 1) * (MINION_WIDTH + SPACING)
            if isPointInRect(x, y, minX, minionY, MINION_WIDTH, MINION_HEIGHT) then
                -- Only select if it can attack
                if minion.canAttack then
                    gameplay.selectedAttacker = {
                        type = "minion",
                        minion = minion,
                        index = i,
                        player = currentPlayer
                    }
                end
                return
            end
        end

        -- Check if hero can attack (has a weapon + hasn't attacked yet)
        if currentPlayer.weapon and not currentPlayer.heroAttacked then
            local isPlayer1 = (currentPlayer == gm.player1)
            local heroY = isPlayer1 and (love.graphics.getHeight() - 40) or 10

            if isPointInRect(x, y, 10, heroY, love.graphics.getWidth() - 20, 30) then
                gameplay.selectedAttacker = {
                    type = "hero",
                    player = currentPlayer
                }
            end
        end

    --------------------------------------------------
    -- 4) If an attacker is already selected, we are choosing a target
    --------------------------------------------------
    else
        local attacker = gameplay.selectedAttacker
        local enemyPlayer = gm:getEnemyPlayer(currentPlayer)
        local targetMinions = (enemyPlayer == gm.player1)
            and gm.board.player1Minions
            or gm.board.player2Minions

        local _, targetMinionY = getPlayerMinionArea(gm, enemyPlayer)
        local targetTotalWidth = #targetMinions * (MINION_WIDTH + SPACING)
        local targetStartX = (love.graphics.getWidth() - targetTotalWidth) / 2

        -- 4a) Check if we clicked an enemy minion
        for i, minion in ipairs(targetMinions) do
            local minX = targetStartX + (i - 1) * (MINION_WIDTH + SPACING)
            if isPointInRect(x, y, minX, targetMinionY, MINION_WIDTH, MINION_HEIGHT) then
                gameplay:resolveAttack(attacker, {type = "minion", minion = minion, index = i})
                gameplay.selectedAttacker = nil
                return
            end
        end

        -- 4b) Check if we clicked the enemy hero
        local isPlayer1 = (currentPlayer == gm.player1)
        local enemyHeroY = isPlayer1 and 10 or (love.graphics.getHeight() - 40)
        if isPointInRect(x, y, 10, enemyHeroY, love.graphics.getWidth() - 20, 30) then
            gameplay:resolveAttack(attacker, {type = "hero"})
            gameplay.selectedAttacker = nil
            return
        end

        -- 4c) If we clicked somewhere else, clear the selection
        gameplay.selectedAttacker = nil
    end
end

return InputSystem
