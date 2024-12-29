-- game/ui/boardrenderer.lua
-- Renders minions on the board for each player.

local BoardRenderer = {}

-- If you have a specific minion image, load it here.
-- Otherwise, we'll just draw rectangles as placeholders.
local minionImage = love.graphics.newImage("assets/images/minion.png")

-- Let’s define constants for placing minions
local MINION_WIDTH = 80
local MINION_HEIGHT = 80
local SPACING = 10

function BoardRenderer.drawBoard(board)
    -- Player 1's minions: draw them near the bottom
    local p1Minions = board.player1Minions

    -- We'll center them horizontally
    local totalWidth1 = #p1Minions * (MINION_WIDTH + SPACING)
    local startX1 = (love.graphics.getWidth() - totalWidth1) / 2
    local y1 = love.graphics.getHeight() / 2 + 50  -- near the bottom half

    for i, minion in ipairs(p1Minions) do
        local x = startX1 + (i-1) * (MINION_WIDTH + SPACING)
        -- If you want to draw an image:
        love.graphics.draw(minionImage, x, y1, 0, 
            MINION_WIDTH / minionImage:getWidth(), 
            MINION_HEIGHT / minionImage:getHeight())
        
        -- Optionally draw minion stats on top
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(
            minion.name .. "\n" .. minion.attack .. "/" .. minion.health,
            x, y1 + (MINION_HEIGHT * 0.2),
            MINION_WIDTH,
            "center"
        )
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Player 2's minions: draw them near the top
    local p2Minions = board.player2Minions
    local totalWidth2 = #p2Minions * (MINION_WIDTH + SPACING)
    local startX2 = (love.graphics.getWidth() - totalWidth2) / 2
    local y2 = love.graphics.getHeight() / 2 - (MINION_HEIGHT + 50)

    for i, minion in ipairs(p2Minions) do
        local x = startX2 + (i-1) * (MINION_WIDTH + SPACING)
        love.graphics.draw(minionImage, x, y2, 0, 
            MINION_WIDTH / minionImage:getWidth(), 
            MINION_HEIGHT / minionImage:getHeight())

        -- Draw minion stats
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(
            minion.name .. "\n" .. minion.attack .. "/" .. minion.health,
            x, y2 + (MINION_HEIGHT * 0.2),
            MINION_WIDTH,
            "center"
        )
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return BoardRenderer
