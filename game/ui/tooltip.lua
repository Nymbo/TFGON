-- game/ui/tooltip.lua
-- Manages tooltips that appear when hovering over cards on the board
-- Enhanced to show weapon information in the minion tooltip
-- Now displays weapon to the side of the minion card rather than below

local CardRenderer = require("game.ui.cardrenderer")
local Theme = require("game.ui.theme")

local Tooltip = {}

-- Constants for tooltip behavior and appearance
local HOVER_DELAY = 0.5  -- Seconds before tooltip appears
local CARD_SCALE = 2.0   -- How much larger the tooltip card should be
local CURSOR_OFFSET_X = 20  -- Distance from cursor horizontally
local CURSOR_OFFSET_Y = 20  -- Distance from cursor vertically
local WEAPON_SCALE = 1.5  -- Scale for the weapon card (slightly smaller than minion)
local WEAPON_SPACING = 15  -- Space between cards

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

-- Get the dimensions of a weapon tooltip card (scaled up from normal card size)
local function getWeaponTooltipDimensions()
    local cardWidth, cardHeight = CardRenderer.getCardDimensions()
    return cardWidth * WEAPON_SCALE, cardHeight * WEAPON_SCALE
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

-- Convert a weapon object to a card-compatible format
local function weaponToCard(weapon)
    return {
        name = weapon.name,
        cardType = "Weapon",
        cost = 0,  -- Not relevant for the display
        attack = weapon.attack,
        durability = weapon.durability
    }
end

-- Check if the tooltip would go off screen and adjust position if needed
local function adjustTooltipPosition(x, y, width, height)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Adjust X position if tooltip would go off right edge
    if x + width > screenWidth then
        x = x - width - CURSOR_OFFSET_X * 2
    end
    
    -- Adjust Y position if tooltip would go off bottom edge
    if y + height > screenHeight then
        y = screenHeight - height
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
        
        -- Calculate total tooltip dimensions based on layout
        local minionWidth, minionHeight = getTooltipDimensions()
        local tooltipWidth = minionWidth
        local tooltipHeight = minionHeight
        
        -- If there's a weapon, account for side-by-side layout
        if currentHoverTarget.weapon then
            local weaponWidth, weaponHeight = getWeaponTooltipDimensions()
            tooltipWidth = minionWidth + weaponWidth + WEAPON_SPACING
            tooltipHeight = math.max(minionHeight, weaponHeight)
        end
        
        -- Position tooltip relative to cursor with adjustments for screen edges
        tooltipX, tooltipY = adjustTooltipPosition(
            mx + CURSOR_OFFSET_X,
            my + CURSOR_OFFSET_Y,
            tooltipWidth,
            tooltipHeight
        )
    end
end

-- Draw the tooltip if visible
function Tooltip.draw()
    if not isTooltipVisible or not currentHoverTarget then
        return
    end
    
    -- Get minion card dimensions
    local minionWidth, minionHeight = getTooltipDimensions()
    
    -- Calculate total dimensions and layout
    local totalWidth = minionWidth
    local totalHeight = minionHeight
    
    -- If minion has a weapon, calculate side-by-side layout
    local weaponWidth, weaponHeight = 0, 0
    if currentHoverTarget.weapon then
        weaponWidth, weaponHeight = getWeaponTooltipDimensions()
        totalWidth = minionWidth + weaponWidth + WEAPON_SPACING
        totalHeight = math.max(minionHeight, weaponHeight)
    end
    
    -- Save current graphics state
    love.graphics.push()
    
    -- Draw semi-transparent black background with padding
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle(
        "fill",
        tooltipX - 10,
        tooltipY - 10,
        totalWidth + 20,
        totalHeight + 20,
        10  -- Rounded corners
    )
    
    -- Draw minion card
    love.graphics.translate(tooltipX, tooltipY)
    love.graphics.scale(CARD_SCALE, CARD_SCALE)
    local cardData = minionToCard(currentHoverTarget)
    CardRenderer.drawCard(cardData, 0, 0, false)
    
    -- If minion has a weapon, draw it to the right
    if currentHoverTarget.weapon then
        -- Reset transform to prepare for weapon card
        love.graphics.origin()
        
        -- Draw "Equipped Weapon:" label above the weapon card
        local labelX = tooltipX + minionWidth + WEAPON_SPACING/2
        local labelY = tooltipY - 25
        
        love.graphics.setFont(Theme.fonts.body)
        love.graphics.setColor(Theme.colors.textPrimary)
        love.graphics.printf(
            "Equipped Weapon:",
            labelX - weaponWidth/2,
            labelY,
            weaponWidth,
            "center"
        )
        
        -- Position for weapon card (to the right of minion)
        local weaponX = tooltipX + minionWidth + WEAPON_SPACING
        local weaponY = tooltipY + (minionHeight - weaponHeight) / 2  -- Vertically centered
        
        -- Draw vertical dividing line
        love.graphics.setColor(Theme.colors.buttonBorder)
        love.graphics.setLineWidth(1)
        love.graphics.line(
            tooltipX + minionWidth + WEAPON_SPACING/2,
            tooltipY,
            tooltipX + minionWidth + WEAPON_SPACING/2,
            tooltipY + totalHeight
        )
        
        -- Draw weapon card
        love.graphics.translate(weaponX, weaponY)
        love.graphics.scale(WEAPON_SCALE, WEAPON_SCALE)
        
        local weaponData = weaponToCard(currentHoverTarget.weapon)
        CardRenderer.drawCard(weaponData, 0, 0, false)
    end
    
    -- Restore graphics state
    love.graphics.pop()
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

return Tooltip