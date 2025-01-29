-- game/ui/cardrenderer.lua
local CardRenderer = {}

-- Constants for card dimensions and styling
local CARD_WIDTH = 100
local CARD_HEIGHT = 150
local COST_CIRCLE_RADIUS = 12
local CARD_COLORS = {
    background = {0.204, 0.286, 0.369, 1},  -- #34495e
    border = {0.945, 0.768, 0.058, 1},      -- #f1c40f
    cost = {0.204, 0.596, 0.858, 1},        -- #3498db
    text = {1, 1, 1, 1}                     -- white
}

----------------------------------------------------------
-- Create a default font for card text. This is LÖVE’s
-- built-in font if you call newFont() with no file path.
-- If you want a different size, adjust the number below.
----------------------------------------------------------
local defaultCardFont = love.graphics.newFont(14)

-------------------------------------------------------
-- Draw a green "glow" rectangle behind the card if it's
-- playable this turn (i.e., the player has enough mana).
-- Then switch to a default font, draw the card text, and
-- revert back to the old font (the fancy one) afterward.
-------------------------------------------------------
function CardRenderer.drawCard(card, x, y, isPlayable)
    -- Save the current font (the fancy Inknut Antiqua font).
    local oldFont = love.graphics.getFont()

    -- Temporarily switch to default font for card text.
    love.graphics.setFont(defaultCardFont)

    -- Draw a green glow if playable
    if isPlayable then
        local glowOffset = 5
        love.graphics.setColor(0, 1, 0, 0.4)
        love.graphics.rectangle(
            "fill", 
            x - glowOffset, 
            y - glowOffset, 
            CARD_WIDTH + glowOffset * 2, 
            CARD_HEIGHT + glowOffset * 2, 
            8, 8
        )
    end

    -- Draw card background
    local alpha = 1
    love.graphics.setColor(CARD_COLORS.background[1], CARD_COLORS.background[2],
                           CARD_COLORS.background[3], alpha)
    love.graphics.rectangle("fill", x, y, CARD_WIDTH, CARD_HEIGHT, 5, 5)
    
    -- Draw card border
    love.graphics.setColor(CARD_COLORS.border[1], CARD_COLORS.border[2],
                           CARD_COLORS.border[3], alpha)
    love.graphics.rectangle("line", x, y, CARD_WIDTH, CARD_HEIGHT, 5, 5)
    
    -- Draw mana cost circle
    love.graphics.setColor(CARD_COLORS.cost[1], CARD_COLORS.cost[2],
                           CARD_COLORS.cost[3], alpha)
    love.graphics.circle("fill", x + 15, y + 15, COST_CIRCLE_RADIUS)
    
    -- Draw cost number
    love.graphics.setColor(CARD_COLORS.text[1], CARD_COLORS.text[2],
                           CARD_COLORS.text[3], alpha)
    love.graphics.printf(tostring(card.cost), x + 5, y + 7, 20, "center")
    
    -- Draw card name
    love.graphics.printf(card.name, x + 5, y + 35, CARD_WIDTH - 10, "center")
    
    -- Draw stats for minions
    if card.cardType == "Minion" then
        -- Draw attack/health at bottom
        love.graphics.printf(
            tostring(card.attack), 
            x + 5, 
            y + CARD_HEIGHT - 20, 
            30, 
            "left"
        )
        love.graphics.printf(
            tostring(card.health), 
            x + CARD_WIDTH - 35, 
            y + CARD_HEIGHT - 20, 
            30, 
            "right"
        )
    end
    
    -- Reset color to white
    love.graphics.setColor(1, 1, 1, 1)

    -- Restore the old font (the fancy one) for everything else.
    love.graphics.setFont(oldFont)
end

-- Get card dimensions for hit testing
function CardRenderer.getCardDimensions()
    return CARD_WIDTH, CARD_HEIGHT
end

return CardRenderer
