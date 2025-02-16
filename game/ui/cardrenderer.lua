-- game/ui/cardrenderer.lua
-- Renders individual cards. For minions, additional stats are shown.
local CardRenderer = {}

local CARD_WIDTH = 100          -- Width of a card in pixels
local CARD_HEIGHT = 150         -- Height of a card in pixels
local COST_CIRCLE_RADIUS = 12   -- Radius of the cost circle

local CARD_COLORS = {
    background = {0.204, 0.286, 0.369, 1},  -- Dark bluish background
    border = {0.945, 0.768, 0.058, 1},        -- Gold/yellow border
    cost = {0.204, 0.596, 0.858, 1},          -- Blue for cost circle
    text = {1, 1, 1, 1}                       -- White text
}

local defaultCardFont = love.graphics.newFont(14)

function CardRenderer.drawCard(card, x, y, isPlayable)
    local oldFont = love.graphics.getFont()
    love.graphics.setFont(defaultCardFont)

    -- Draw a green glow if the card is playable
    if isPlayable then
        local glowOffset = 5
        love.graphics.setColor(0, 1, 0, 0.4)
        love.graphics.rectangle("fill", x - glowOffset, y - glowOffset, CARD_WIDTH + glowOffset * 2, CARD_HEIGHT + glowOffset * 2, 8, 8)
    end

    --------------------------------------------------
    -- Card background and border
    --------------------------------------------------
    love.graphics.setColor(CARD_COLORS.background)
    love.graphics.rectangle("fill", x, y, CARD_WIDTH, CARD_HEIGHT, 5, 5)
    love.graphics.setColor(CARD_COLORS.border)
    love.graphics.rectangle("line", x, y, CARD_WIDTH, CARD_HEIGHT, 5, 5)

    --------------------------------------------------
    -- Cost circle and cost text
    --------------------------------------------------
    love.graphics.setColor(CARD_COLORS.cost)
    love.graphics.circle("fill", x + 15, y + 15, COST_CIRCLE_RADIUS)
    love.graphics.setColor(CARD_COLORS.text)
    love.graphics.printf(tostring(card.cost), x + 5, y + 7, 20, "center")

    --------------------------------------------------
    -- Card name
    --------------------------------------------------
    love.graphics.printf(card.name, x + 5, y + 35, CARD_WIDTH - 10, "center")

    --------------------------------------------------
    -- For Minion cards, display attack, health, movement, and archetype
    --------------------------------------------------
    if card.cardType == "Minion" then
        love.graphics.printf("Atk:" .. tostring(card.attack), x + 5, y + CARD_HEIGHT - 60, CARD_WIDTH - 10, "center")
        love.graphics.printf("HP:" .. tostring(card.health), x + 5, y + CARD_HEIGHT - 45, CARD_WIDTH - 10, "center")
        love.graphics.printf("Mvt:" .. tostring(card.movement), x + 5, y + CARD_HEIGHT - 30, CARD_WIDTH - 10, "center")
        love.graphics.printf("Arch:" .. tostring(card.archetype), x + 5, y + CARD_HEIGHT - 15, CARD_WIDTH - 10, "center")
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(oldFont)
end

function CardRenderer.getCardDimensions()
    return CARD_WIDTH, CARD_HEIGHT
end

return CardRenderer
