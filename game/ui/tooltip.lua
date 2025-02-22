-- game/ui/tooltip.lua
-- Manages tooltips that appear when hovering over cards on the board

local CardRenderer = require("game.ui.cardrenderer")
local Theme = require("game.ui.theme")

local Tooltip = {}

-- Constants for tooltip behavior and appearance
local HOVER_DELAY = 2.0  -- Seconds before tooltip appears
local CARD_SCALE = 2.0   -- How much larger the tooltip card should be
local CURSOR_OFFSET_X = 20  -- Distance from cursor horizontally
local CURSOR_OFFSET_Y = 20  -- Distance from cursor vertically

-- State variables
local currentHoverTarget = nil  -- The card/minion being hovered over
local hoverStartTime = 0        -- When the hover started
local isTooltipVisible = false  -- Whether tooltip should be shown
local tooltipX = 0             -- Current tooltip X position
local tooltipY = 0             -- Current tooltip Y position

-- Get the dimensions of a tooltip card (scaled up from normal card size)
local function getTooltipDimensions()
    local cardWidth, cardHeight = CardRenderer.getCardDimensions()
    return cardWidth * CARD_SCALE, cardHeight * CARD_SCALE
end

-- Convert a minion object to a card-compatible format
local function minionToCard(minion)
    return {
        name = minion.name,
        cardType = "Minion",
        cost = 0,  -- We don't know the original cost, could store it if needed
        attack = minion.attack,
        health = minion.currentHealth,
        maxHealth = minion.maxHealth,
        movement = minion.movement,
        archetype = minion.archetype,
        battlecry = minion.battlecry,
        deathrattle = minion.deathrattle
    }
end

-- Check if the tooltip would go off screen and adjust position if needed
local function adjustTooltipPosition(x, y)
    local tooltipWidth, tooltipHeight = getTooltipDimensions()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Adjust X position if tooltip would go off right edge
    if x + tooltipWidth > screenWidth then
        x = x - tooltipWidth - CURSOR_OFFSET_X * 2
    end
    
    -- Adjust Y position if tooltip would go off bottom edge
    if y + tooltipHeight > screenHeight then
        y = screenHeight - tooltipHeight
    end
    
    return x, y
end

-- Update the tooltip state
function Tooltip.update(dt, mx, my, hoveredCard)
    -- If we're hovering over a new card or no card
    if hoveredCard ~= currentHoverTarget then
        currentHoverTarget = hoveredCard
        hoverStartTime = love.timer.getTime()
        isTooltipVisible = false
    end
    
    -- Check if we've been hovering long enough to show tooltip
    if currentHoverTarget and love.timer.getTime() - hoverStartTime >= HOVER_DELAY then
        isTooltipVisible = true
        
        -- Position tooltip relative to cursor with adjustments for screen edges
        tooltipX, tooltipY = adjustTooltipPosition(
            mx + CURSOR_OFFSET_X,
            my + CURSOR_OFFSET_Y
        )
    end
end

-- Draw the tooltip if visible
function Tooltip.draw()
    if isTooltipVisible and currentHoverTarget then
        -- Save current graphics state
        love.graphics.push()
        
        -- Move to tooltip position and scale up
        love.graphics.translate(tooltipX, tooltipY)
        love.graphics.scale(CARD_SCALE, CARD_SCALE)
        
        -- Draw semi-transparent black background
        love.graphics.setColor(0, 0, 0, 0.8)
        local cardWidth, cardHeight = CardRenderer.getCardDimensions()
        love.graphics.rectangle(
            "fill",
            -5, -5,  -- Slight padding around the card
            cardWidth + 10,
            cardHeight + 10,
            10  -- Rounded corners
        )
        
        -- Convert minion to card format and draw
        local cardData = minionToCard(currentHoverTarget)
        CardRenderer.drawCard(cardData, 0, 0, false)
        
        -- Restore graphics state
        love.graphics.pop()
        
        -- Reset color
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return Tooltip