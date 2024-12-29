-- game/ui/boardrenderer.lua
-- Responsible for rendering each player's minions on the board.

local BoardRenderer = {}

-- Load the minion image
-- Ensure you have "Nymbo-TFGON/assets/images/minion.png" in place.
local minionImage = love.graphics.newImage("assets/images/minion.png")

-- Dimensions used for drawing each minion
local MINION_WIDTH = 80
local MINION_HEIGHT = 80
local SPACING = 10

function BoardRenderer.drawBoard(board)
    ---------------------
    -- Player 1 minions
    ---------------------
    local p1Minions = board.player1Minions
    local totalWidth1 = #p1Minions * (MINION_WIDTH + SPACING)
    local startX1 = (love.graphics.getWidth() - totalWidth1) / 2
    -- We'll draw them near the bottom half of the screen
    local y1 = (love.graphics.getHeight() / 2) + 50

    for i, minion in ipairs(p1Minions) do
        local x = startX1 + (i - 1) * (MINION_WIDTH + SPACING)

        -- Draw the minion image scaled to our desired width/height
        local scaleX = MINION_WIDTH / minionImage:getWidth()
        local scaleY = MINION_HEIGHT / minionImage:getHeight()
        love.graphics.draw(minionImage, x, y1, 0, scaleX, scaleY)

        -- Optionally draw the minion's name/stats
        love.graphics.setColor(0, 0, 0)
        love.graphics.printf(
            minion.name .. "\n" .. minion.attack .. "/" .. minion.health,
            x, y1 + (MINION_HEIGHT * 0.25),
            MINION_WIDTH,
            "center"
        )
        -- Reset color to white
        love.graphics.setColor(1, 1, 1)
    end

    ---------------------
    -- Player 2 minions
    ---------------------
    local p2Minions = board.player2Minions
    local totalWidth2 = #p2Minions * (MINION_WIDTH + SPACING)
    local startX2 = (love.graphics.getWidth() - totalWidth2) / 2
    -- We'll draw them near the top half of the screen
    local y2 = (love.graphics.getHeight() / 2) - (MINION_HEIGHT + 50)

    for i, minion in ipairs(p2Minions) do
        local x = startX2 + (i - 1) * (MINION_WIDTH + SPACING)

        -- Same minion image
        local scaleX = MINION_WIDTH / minionImage:getWidth()
        local scaleY = MINION_HEIGHT / minionImage:getHeight()
        love.graphics.draw(minionImage, x, y2, 0, scaleX, scaleY)

        -- Optionally draw the minion's name/stats
        love.graphics.setColor(0, 0, 0)
        love.graphics.printf(
            minion.name .. "\n" .. minion.attack .. "/" .. minion.health,
            x, y2 + (MINION_HEIGHT * 0.25),
            MINION_WIDTH,
            "center"
        )
        -- Reset color
        love.graphics.setColor(1, 1, 1)
    end
end

return BoardRenderer
