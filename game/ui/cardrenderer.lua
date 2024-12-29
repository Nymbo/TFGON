-- game/ui/cardrenderer.lua
-- Responsible for drawing cards. For now, just a placeholder.

local CardRenderer = {}

function CardRenderer.drawCard(card, x, y)
    -- For now, just draw a rectangle with the card's name
    love.graphics.rectangle("line", x, y, 100, 150)
    love.graphics.printf(card.name, x, y + 60, 100, "center")
end

return CardRenderer
