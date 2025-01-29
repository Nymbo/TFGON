-- game/ui/cardrenderer.lua
-- Handles the visual representation of individual cards.

--------------------------------------------------
-- Table definition for CardRenderer
--------------------------------------------------
local CardRenderer = {}

--------------------------------------------------
-- Constants for card layout and styling
--------------------------------------------------
local CARD_WIDTH = 100          -- Pixel width of a card
local CARD_HEIGHT = 150         -- Pixel height of a card
local COST_CIRCLE_RADIUS = 12   -- Radius of the cost circle in the top-left corner

-- Colors used throughout the card drawing process
local CARD_COLORS = {
    background = {0.204, 0.286, 0.369, 1},  -- #34495e (a dark bluish color)
    border = {0.945, 0.768, 0.058, 1},      -- #f1c40f (gold/yellow)
    cost = {0.204, 0.596, 0.858, 1},        -- #3498db (blue)
    text = {1, 1, 1, 1}                     -- white
}

--------------------------------------------------
-- Create a default font for card text. If you want
-- a larger or smaller font, adjust the number below.
-- (LÖVE uses a default font if nil is provided, but we
-- explicitly define a size for consistency.)
--------------------------------------------------
local defaultCardFont = love.graphics.newFont(14)

--------------------------------------------------
-- drawCard(card, x, y, isPlayable):
-- Renders a card at position (x, y). If 'isPlayable'
-- is true, a subtle green glow is drawn behind the card
-- to signify it can be played. Then the card’s cost,
-- name, and any additional stats (e.g., attack/health)
-- are drawn using the default font.
--------------------------------------------------
function CardRenderer.drawCard(card, x, y, isPlayable)
    -- Save the current font (potentially a fancy font).
    local oldFont = love.graphics.getFont()

    -- Temporarily switch to a simpler default font for card text.
    love.graphics.setFont(defaultCardFont)

    -- If the card is playable, draw a green glow behind it
    if isPlayable then
        local glowOffset = 5
        love.graphics.setColor(0, 1, 0, 0.4)  -- a semi-transparent green
        love.graphics.rectangle(
            "fill", 
            x - glowOffset, 
            y - glowOffset, 
            CARD_WIDTH + glowOffset * 2, 
            CARD_HEIGHT + glowOffset * 2, 
            8, 8
        )
    end

    --------------------------------------------------
    -- Card background
    --------------------------------------------------
    local alpha = 1  -- Full opacity
    love.graphics.setColor(
        CARD_COLORS.background[1],
        CARD_COLORS.background[2],
        CARD_COLORS.background[3],
        alpha
    )
    love.graphics.rectangle("fill", x, y, CARD_WIDTH, CARD_HEIGHT, 5, 5)

    --------------------------------------------------
    -- Card border
    --------------------------------------------------
    love.graphics.setColor(
        CARD_COLORS.border[1],
        CARD_COLORS.border[2],
        CARD_COLORS.border[3],
        alpha
    )
    love.graphics.rectangle("line", x, y, CARD_WIDTH, CARD_HEIGHT, 5, 5)

    --------------------------------------------------
    -- Cost circle
    --------------------------------------------------
    love.graphics.setColor(
        CARD_COLORS.cost[1],
        CARD_COLORS.cost[2],
        CARD_COLORS.cost[3],
        alpha
    )
    love.graphics.circle("fill", x + 15, y + 15, COST_CIRCLE_RADIUS)

    -- Draw cost text inside the circle
    love.graphics.setColor(
        CARD_COLORS.text[1],
        CARD_COLORS.text[2],
        CARD_COLORS.text[3],
        alpha
    )
    love.graphics.printf(tostring(card.cost), x + 5, y + 7, 20, "center")

    --------------------------------------------------
    -- Card name
    --------------------------------------------------
    love.graphics.printf(card.name, x + 5, y + 35, CARD_WIDTH - 10, "center")

    --------------------------------------------------
    -- If this is a Minion, draw its attack and health
    --------------------------------------------------
    if card.cardType == "Minion" then
        -- Attack in the bottom-left
        love.graphics.printf(
            tostring(card.attack),
            x + 5,
            y + CARD_HEIGHT - 20,
            30,
            "left"
        )

        -- Health in the bottom-right
        love.graphics.printf(
            tostring(card.health),
            x + CARD_WIDTH - 35,
            y + CARD_HEIGHT - 20,
            30,
            "right"
        )
    end

    -- Reset color to white for subsequent rendering
    love.graphics.setColor(1, 1, 1, 1)

    -- Restore the old font to continue drawing with the original style
    love.graphics.setFont(oldFont)
end

--------------------------------------------------
-- getCardDimensions():
-- Returns the width and height of the card, useful
-- for positioning or collision checks.
--------------------------------------------------
function CardRenderer.getCardDimensions()
    return CARD_WIDTH, CARD_HEIGHT
end

return CardRenderer
