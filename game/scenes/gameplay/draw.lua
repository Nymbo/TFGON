-- game/scenes/gameplay/draw.lua
-- Handles drawing the Gameplay scene elements:
--  - Background
--  - Board (delegates to BoardRenderer)
--  - Player hand (delegates to CardRenderer)
--  - End Turn button and turn indicator
--
-- This keeps all "draw" code in one place.

--------------------------------------------------
-- Require modules for drawing the board and cards
--------------------------------------------------
local BoardRenderer = require("game.ui.boardrenderer")
local CardRenderer = require("game.ui.cardrenderer")

--------------------------------------------------
-- Constants for the 'End Turn' button
--------------------------------------------------
local END_TURN_BUTTON = {
    width = 120,
    height = 40,
    colors = {
        normal = {0.905, 0.298, 0.235, 1},    -- #e74c3c bright red
        hover = {0.753, 0.224, 0.169, 1},     -- #c0392b darker red on hover
        text = {1, 1, 1, 1}                  -- white text
    }
}

--------------------------------------------------
-- We'll draw the background scaled to cover
-- the screen with optional transparency
--------------------------------------------------
local function drawScaledBackground(image, alpha)
    alpha = alpha or 1
    local windowW, windowH = love.graphics.getWidth(), love.graphics.getHeight()
    local bgW, bgH = image:getWidth(), image:getHeight()

    -- "Cover" style scaling: pick whichever axis needs a bigger scale
    local scale = math.max(windowW / bgW, windowH / bgH)

    -- Center the image after scaling
    local offsetX = (windowW - bgW * scale) / 2
    local offsetY = (windowH - bgH * scale) / 2

    -- Draw background with chosen alpha
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(image, offsetX, offsetY, 0, scale, scale)
    love.graphics.setColor(1, 1, 1, 1)
end

--------------------------------------------------
-- The main function to draw the Gameplay scene.
-- We'll call this from gameplay.lua's :draw().
--------------------------------------------------
local DrawSystem = {}

function DrawSystem.drawGameplayScene(gameplay)
    -- 1) Draw scaled, centered background at 50% opacity
    if gameplay.background then
        drawScaledBackground(gameplay.background, 0.5)
    end

    -- 2) Draw the board (minions, hero info, etc.)
    local gm = gameplay.gameManager
    BoardRenderer.drawBoard(
        gm.board,
        gm.player1,
        gm.player2,
        gameplay.selectedAttacker,   -- if an attack is in progress
        gm:getCurrentPlayer()        -- which player's turn it is
    )

    -- 3) Draw the current player's hand
    local currentPlayer = gm:getCurrentPlayer()
    local hand = currentPlayer.hand
    local cardWidth, cardHeight = CardRenderer.getCardDimensions()

    -- We'll lay out the hand in a row at the bottom of the screen
    local totalWidth = #hand * (cardWidth + 10)
    local startX = (love.graphics.getWidth() - totalWidth) / 2
    local cardY = love.graphics.getHeight() - cardHeight - 20

    for i, card in ipairs(hand) do
        local cardX = startX + (i - 1) * (cardWidth + 10)
        local isPlayable = (card.cost <= currentPlayer.manaCrystals)
        CardRenderer.drawCard(card, cardX, cardY, isPlayable)
    end

    -- 4) Draw the 'End Turn' button and turn indicator
    local buttonX = love.graphics.getWidth() - END_TURN_BUTTON.width - 20
    local buttonY = love.graphics.getHeight() / 2 - END_TURN_BUTTON.height / 2

    -- Button background color
    love.graphics.setColor(
        gameplay.endTurnHovered and END_TURN_BUTTON.colors.hover
            or END_TURN_BUTTON.colors.normal
    )
    love.graphics.rectangle(
        "fill",
        buttonX, buttonY,
        END_TURN_BUTTON.width, END_TURN_BUTTON.height,
        5, 5
    )

    -- Button text
    love.graphics.setColor(END_TURN_BUTTON.colors.text)
    love.graphics.printf("End Turn", buttonX, buttonY + 10, END_TURN_BUTTON.width, "center")

    -- Turn indicator text
    local currentTurnText = (gm.currentPlayer == 1) and "Player 1's turn" or "Player 2's turn"
    local turnIndicatorY = buttonY + END_TURN_BUTTON.height + 10
    love.graphics.printf(currentTurnText, buttonX, turnIndicatorY, END_TURN_BUTTON.width, "center")

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

return DrawSystem
