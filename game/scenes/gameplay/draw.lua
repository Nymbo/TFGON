-- game/scenes/gameplay/draw.lua
-- Handles drawing the Gameplay scene elements
-- Updated with support for targeting indicators

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
        END_TURN_BUTTON.height/2 - 2,
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
        buttonY + (END_TURN_BUTTON.height - END_TURN_BUTTON.font:getHeight())/2,
        END_TURN_BUTTON.width,
        "center"
    )

    local currentTurnText = (gm.currentPlayer == 1) and "Player 1's Turn" or "Player 2's Turn"
    local turnIndicatorY = buttonY + END_TURN_BUTTON.height + 10
    love.graphics.setColor(END_TURN_BUTTON.colors.textPrimary)
    love.graphics.printf(currentTurnText, buttonX, turnIndicatorY, END_TURN_BUTTON.width, "center")

    -- Ensure the mana frame image is loaded only once
    if not DrawSystem.manaFrame then
        DrawSystem.manaFrame = love.graphics.newImage("assets/images/FrameRound.png")
        DrawSystem.manaFrameScale = 0.16  -- Scale so that the 512x512 image becomes roughly 80x80
    end
    local manaFrame = DrawSystem.manaFrame
    local manaScale = DrawSystem.manaFrameScale
    local frameWidth = manaFrame:getWidth() * manaScale
    local frameHeight = manaFrame:getHeight() * manaScale

    -- Draw Player 2's Mana (displayed near the top of the screen)
    local p2ManaText = tostring(gm.player2.manaCrystals) .. "/" .. tostring(gm.player2.maxManaCrystals)
    local p2X = buttonX  -- align x with End Turn button
    local p2Y = 20       -- near the top
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(manaFrame, p2X, p2Y, 0, manaScale, manaScale)
    local manaFont = love.graphics.newFont("assets/fonts/InknutAntiqua-Regular.ttf", 24)
    love.graphics.setFont(manaFont)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.printf(p2ManaText, p2X, p2Y + (frameHeight - manaFont:getHeight())/2, frameWidth, "center")

    -- Draw Player 1's Mana (displayed near the bottom of the screen)
    local p1ManaText = tostring(gm.player1.manaCrystals) .. "/" .. tostring(gm.player1.maxManaCrystals)
    local p1X = buttonX
    local p1Y = love.graphics.getHeight() - frameHeight - 20
    love.graphics.draw(manaFrame, p1X, p1Y, 0, manaScale, manaScale)
    love.graphics.printf(p1ManaText, p1X, p1Y + (frameHeight - manaFont:getHeight())/2, frameWidth, "center")

    -- If we have a pending effect, draw the card being played near the cursor
    if gameplay.pendingEffectCard then
        local mx, my = love.mouse.getPosition()
        -- Draw a small version of the card following the cursor
        local miniScale = 0.7
        local miniCardWidth = cardWidth * miniScale
        local miniCardHeight = cardHeight * miniScale
        
        love.graphics.setColor(1, 1, 1, 0.7)  -- Semi-transparent
        love.graphics.push()
        love.graphics.translate(mx - miniCardWidth/2, my - miniCardHeight - 20)
        love.graphics.scale(miniScale, miniScale)
        CardRenderer.drawCard(gameplay.pendingEffectCard, 0, 0, true)
        love.graphics.pop()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return DrawSystem