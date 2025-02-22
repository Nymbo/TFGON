-- game/scenes/gameplay/draw.lua
-- Handles drawing the Gameplay scene elements

local BoardRenderer = require("game.ui.boardrenderer")
local CardRenderer = require("game.ui.cardrenderer")
local Theme = require("game.ui.theme")  -- Import the theme

--------------------------------------------------
-- Constants for the 'End Turn' button using Theme
--------------------------------------------------
local END_TURN_BUTTON = {
    width = Theme.dimensions.buttonWidth,
    height = Theme.dimensions.buttonHeight,
    cornerRadius = Theme.dimensions.buttonCornerRadius,
    font = Theme.fonts.button,
    colors = Theme.colors,  -- Direct reference to theme colors
    shadowOffset = Theme.dimensions.buttonShadowOffset,
    glowOffset = Theme.dimensions.buttonGlowOffset
}

local function drawScaledBackground(image, alpha)
    alpha = alpha or 1
    local windowW, windowH = love.graphics.getWidth(), love.graphics.getHeight()
    local bgW, bgH = image:getWidth(), image:getHeight()
    local scale = math.max(windowW / bgW, windowH / bgH)
    local offsetX = (windowW - bgW * scale) / 2
    local offsetY = (windowH - bgH * scale) / 2
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(image, offsetX, offsetY, 0, scale, scale)
    love.graphics.setColor(1, 1, 1, 1)
end

local DrawSystem = {}

function DrawSystem.drawGameplayScene(gameplay)
    if gameplay.background then
        drawScaledBackground(gameplay.background, 0.5)
    end

    local gm = gameplay.gameManager
    BoardRenderer.drawBoard(
        gm.board,
        gm.player1,
        gm.player2,
        gameplay.selectedMinion,
        gm:getCurrentPlayer(),
        gm,
        gameplay.pendingSummon
    )

    local currentPlayer = gm:getCurrentPlayer()
    local hand = currentPlayer.hand
    local cardWidth, cardHeight = CardRenderer.getCardDimensions()
    local totalWidth = #hand * (cardWidth + 10)
    local startX = (love.graphics.getWidth() - totalWidth) / 2
    local cardY = love.graphics.getHeight() - cardHeight - 20

    for i, card in ipairs(hand) do
        local cardX = startX + (i - 1) * (cardWidth + 10)
        local isPlayable = (card.cost <= currentPlayer.manaCrystals)
        CardRenderer.drawCard(card, cardX, cardY, isPlayable)
    end

    -- Draw 'End Turn' button using theme
    local buttonX = love.graphics.getWidth() - END_TURN_BUTTON.width - 20
    local buttonY = love.graphics.getHeight() / 2 - END_TURN_BUTTON.height / 2

    love.graphics.setColor(END_TURN_BUTTON.colors.buttonShadow)
    love.graphics.rectangle(
        "fill",
        buttonX + END_TURN_BUTTON.shadowOffset,
        buttonY + END_TURN_BUTTON.shadowOffset,
        END_TURN_BUTTON.width,
        END_TURN_BUTTON.height,
        END_TURN_BUTTON.cornerRadius
    )

    if gameplay.endTurnHovered then
        love.graphics.setColor(END_TURN_BUTTON.colors.buttonGlowHover)
        love.graphics.rectangle(
            "fill",
            buttonX - END_TURN_BUTTON.glowOffset,
            buttonY - END_TURN_BUTTON.glowOffset,
            END_TURN_BUTTON.width + 2 * END_TURN_BUTTON.glowOffset,
            END_TURN_BUTTON.height + 2 * END_TURN_BUTTON.glowOffset,
            END_TURN_BUTTON.cornerRadius + 2
        )
    end

    love.graphics.setColor(END_TURN_BUTTON.colors.buttonBase)
    love.graphics.rectangle(
        "fill",
        buttonX,
        buttonY,
        END_TURN_BUTTON.width,
        END_TURN_BUTTON.height,
        END_TURN_BUTTON.cornerRadius
    )
    love.graphics.setColor(END_TURN_BUTTON.colors.buttonGradientTop)
    love.graphics.rectangle(
        "fill",
        buttonX + 2,
        buttonY + 2,
        END_TURN_BUTTON.width - 4,
        END_TURN_BUTTON.height / 2,
        END_TURN_BUTTON.cornerRadius
    )

    love.graphics.setColor(END_TURN_BUTTON.colors.buttonBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle(
        "line",
        buttonX,
        buttonY,
        END_TURN_BUTTON.width,
        END_TURN_BUTTON.height,
        END_TURN_BUTTON.cornerRadius
    )
    love.graphics.setLineWidth(1)

    love.graphics.setFont(END_TURN_BUTTON.font)
    love.graphics.setColor(
        gameplay.endTurnHovered and END_TURN_BUTTON.colors.textHover or END_TURN_BUTTON.colors.textPrimary
    )
    love.graphics.printf(
        "End Turn",
        buttonX,
        buttonY + (END_TURN_BUTTON.height - END_TURN_BUTTON.font:getHeight()) / 2,
        END_TURN_BUTTON.width,
        "center"
    )

    local currentTurnText = (gm.currentPlayer == 1) and "Player 1's Turn" or "Player 2's Turn"
    local turnIndicatorY = buttonY + END_TURN_BUTTON.height + 10
    love.graphics.setColor(END_TURN_BUTTON.colors.textPrimary)
    love.graphics.printf(currentTurnText, buttonX, turnIndicatorY, END_TURN_BUTTON.width, "center")

    love.graphics.setColor(1, 1, 1, 1)
end

return DrawSystem