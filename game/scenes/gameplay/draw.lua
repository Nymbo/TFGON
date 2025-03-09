-- game/scenes/gameplay/draw.lua
-- Handles drawing the Gameplay scene elements
-- Updated with support for targeting indicators
-- Now includes animation rendering with safe handling
-- Enhanced with flux-powered card animations

local BoardRenderer = require("game.ui.boardrenderer")
local CardRenderer = require("game.ui.cardrenderer")
local Theme = require("game.ui.theme")  -- Import the theme
local ErrorLog = require("game.utils.errorlog")
local flux = require("libs.flux")  -- Add this for animations

-- Try to load AnimationManager safely
local AnimationManager = nil
local success, result = pcall(function()
    return require("game.managers.animationmanager")
end)

if success then
    AnimationManager = result
    ErrorLog.logError("AnimationManager loaded in DrawSystem", true)
else
    ErrorLog.logError("Failed to load AnimationManager in DrawSystem: " .. tostring(result))
end

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

-- This stores the visual state of cards for smooth animations
local cardVisuals = {
    cards = {},  -- Will store visual state for each card
    lastHandSize = 0,  -- Track changes in hand size
    repositionNeeded = false  -- Flag to trigger repositioning
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

-- Initialize a new card's visual state
local function initCardVisual(card, index, hand)
    local cardWidth, cardHeight = CardRenderer.getCardDimensions()
    local totalWidth = #hand * (cardWidth + 10)
    local startX = (love.graphics.getWidth() - totalWidth) / 2
    local cardY = love.graphics.getHeight() - cardHeight - 20
    local targetX = startX + (index - 1) * (cardWidth + 10)
    
    if not cardVisuals.cards[card] then
        -- If card is newly added, start it from offscreen
        cardVisuals.cards[card] = {
            x = love.graphics.getWidth() + cardWidth, -- Start off-screen to the right
            y = cardY + 50,  -- Slightly below final position
            targetX = targetX,
            targetY = cardY,
            scale = 0.8,  -- Start slightly smaller
            rotation = 0.2,  -- Slight initial rotation
            alpha = 0.8,  -- Start slightly transparent
            isNew = true
        }
        
        -- Animate it into position
        flux.to(cardVisuals.cards[card], 0.5, {
            x = targetX,
            y = cardY,
            scale = 1,
            rotation = 0,
            alpha = 1
        }):ease("backout") -- Bouncy effect
    else
        -- Update the target position for existing card
        cardVisuals.cards[card].targetX = targetX
        cardVisuals.cards[card].targetY = cardY
        
        -- Animate to new position if it's significantly different
        if math.abs(cardVisuals.cards[card].x - targetX) > 5 then
            flux.to(cardVisuals.cards[card], 0.3, {
                x = targetX,
                y = cardY
            }):ease("quadout")
        end
    end
end

-- Clean up card visuals that are no longer in hand
local function cleanupCardVisuals(hand)
    local cardsInHand = {}
    
    -- Mark cards that are currently in hand
    for _, card in ipairs(hand) do
        cardsInHand[card] = true
    end
    
    -- Remove visuals for cards no longer in hand
    for card, visual in pairs(cardVisuals.cards) do
        if not cardsInHand[card] and not visual.removing then
            -- Card is no longer in hand, animate it away
            visual.removing = true
            
            -- Animate the card moving up and fading out
            flux.to(visual, 0.3, {
                y = visual.y - 100,
                alpha = 0,
                scale = 0.8
            }):ease("quadout")
            :oncomplete(function()
                cardVisuals.cards[card] = nil
            end)
        end
    end
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
    
    -- Check if hand size has changed
    if #hand ~= cardVisuals.lastHandSize then
        cardVisuals.repositionNeeded = true
        cardVisuals.lastHandSize = #hand
    end
    
    -- Initialize or update card visuals
    if cardVisuals.repositionNeeded then
        for i, card in ipairs(hand) do
            initCardVisual(card, i, hand)
        end
        cleanupCardVisuals(hand)
        cardVisuals.repositionNeeded = false
    end
    
    -- Draw cards with their current visual state
    for i, card in ipairs(hand) do
        if cardVisuals.cards[card] then
            local visual = cardVisuals.cards[card]
            
            -- Save current graphics state
            love.graphics.push()
            
            -- Apply visual transformations
            love.graphics.translate(
                visual.x + cardWidth/2, 
                visual.y + cardHeight/2
            )
            love.graphics.scale(visual.scale, visual.scale)
            love.graphics.rotate(visual.rotation)
            
            -- Apply alpha
            love.graphics.setColor(1, 1, 1, visual.alpha)
            
            local isPlayable = (card.cost <= currentPlayer.manaCrystals)
            CardRenderer.drawCard(card, -cardWidth/2, -cardHeight/2, isPlayable)
            
            -- Restore previous graphics state
            love.graphics.pop()
            love.graphics.setColor(1, 1, 1, 1)
        else
            -- Fallback for cards without visuals (shouldn't happen)
            local totalWidth = #hand * (cardWidth + 10)
            local startX = (love.graphics.getWidth() - totalWidth) / 2
            local cardY = love.graphics.getHeight() - cardHeight - 20
            local cardX = startX + (i - 1) * (cardWidth + 10)
            
            local isPlayable = (card.cost <= currentPlayer.manaCrystals)
            CardRenderer.drawCard(card, cardX, cardY, isPlayable)
            
            -- Also create visual state for next frame
            initCardVisual(card, i, hand)
        end
    end

    -- Draw all active animations (if available)
    if AnimationManager then
        pcall(function()
            AnimationManager:draw()
        end)
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
        -- Use pcall to handle missing images
        local success, result = pcall(function()
            return love.graphics.newImage("assets/images/FrameRound.png")
        end)
        
        if success then
            DrawSystem.manaFrame = result
            DrawSystem.manaFrameScale = 0.16  -- Scale so that the 512x512 image becomes roughly 80x80
        else
            ErrorLog.logError("Failed to load mana frame image: " .. tostring(result))
            -- Create a placeholder canvas for the mana frame
            DrawSystem.manaFrame = love.graphics.newCanvas(80, 80)
            love.graphics.setCanvas(DrawSystem.manaFrame)
            love.graphics.clear(0.2, 0.4, 0.8, 1)
            love.graphics.setColor(0.1, 0.3, 0.7, 1)
            love.graphics.circle("fill", 40, 40, 35)
            love.graphics.setCanvas()
            DrawSystem.manaFrameScale = 1
        end
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
    
    -- Load mana font safely
    local manaFont
    local success, result = pcall(function()
        return love.graphics.newFont("assets/fonts/InknutAntiqua-Regular.ttf", 24)
    end)
    
    if success then
        manaFont = result
    else
        ErrorLog.logError("Failed to load mana font: " .. tostring(result))
        manaFont = love.graphics.getFont() -- Fallback to current font
    end
    
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

-- Call this when a card is drawn by the player to trigger animations
function DrawSystem.onCardDrawn(card, index, hand)
    cardVisuals.repositionNeeded = true
    
    -- This ensures the new card gets proper animation
    if not cardVisuals.cards[card] then
        -- Initialize the card with offscreen starting position
        initCardVisual(card, index, hand)
    end
end

-- Call this when a card is played to trigger animations
function DrawSystem.onCardPlayed(card)
    if cardVisuals.cards[card] then
        local visual = cardVisuals.cards[card]
        
        -- Mark as removing to prevent cleanup from deleting it prematurely
        visual.removing = true
        
        -- Animate the card moving up and fading out
        flux.to(visual, 0.3, {
            y = visual.y - 200,
            alpha = 0,
            scale = 1.2,
            rotation = math.random(-0.2, 0.2) -- Random slight rotation
        }):ease("quadout")
        :oncomplete(function()
            cardVisuals.cards[card] = nil
            cardVisuals.repositionNeeded = true
        end)
    end
    
    cardVisuals.repositionNeeded = true
end

-- Called when the player's hand changes in any way
function DrawSystem.onHandChanged()
    cardVisuals.repositionNeeded = true
end

return DrawSystem