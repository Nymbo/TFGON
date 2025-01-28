-- game/ui/boardrenderer.lua
local BoardRenderer = {}

-- Constants for layout and styling
local MINION_WIDTH = 80
local MINION_HEIGHT = 100
local SPACING = 10
local COLORS = {
    playerInfo = {0, 0, 0, 0.3},            -- Semi-transparent black
    minionArea = {1, 1, 1, 0.1},            -- Very light semi-transparent white
    minion = {
        background = {0.173, 0.243, 0.314, 1},  -- #2c3e50
        border = {0.902, 0.494, 0.133, 1},      -- #e67e22
        text = {1, 1, 1, 1}
    }
}

local function drawPlayerInfo(player, y, isOpponent)
    -- Draw semi-transparent background
    love.graphics.setColor(COLORS.playerInfo)
    love.graphics.rectangle("fill", 10, y, love.graphics.getWidth() - 20, 30, 5, 5)
    
    -- Draw player information
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(player.name, 20, y + 5)
    love.graphics.printf(
        string.format("HP: %d", player.health),
        0, y + 5, love.graphics.getWidth(), "center"
    )
    love.graphics.printf(
        string.format("Mana: %d/%d", player.manaCrystals, player.maxManaCrystals),
        0, y + 5, love.graphics.getWidth() - 20, "right"
    )
end

local function drawMinion(minion, x, y)
    -- Draw minion background
    love.graphics.setColor(COLORS.minion.background)
    love.graphics.rectangle("fill", x, y, MINION_WIDTH, MINION_HEIGHT, 5, 5)
    
    -- Draw border
    love.graphics.setColor(COLORS.minion.border)
    love.graphics.rectangle("line", x, y, MINION_WIDTH, MINION_HEIGHT, 5, 5)
    
    -- Draw name and stats
    love.graphics.setColor(COLORS.minion.text)
    love.graphics.printf(minion.name, x + 5, y + 5, MINION_WIDTH - 10, "center")
    
    -- Draw attack/health
    love.graphics.printf(tostring(minion.attack), x + 5, y + MINION_HEIGHT - 20, 
                        20, "left")
    love.graphics.printf(tostring(minion.currentHealth), x + MINION_WIDTH - 25, 
                        y + MINION_HEIGHT - 20, 20, "right")
end

function BoardRenderer.drawBoard(board, player1, player2)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Draw opponent info (top)
    drawPlayerInfo(player2, 10, true)
    
    -- Calculate vertical positions for better centering
    local opponentMinionY = math.floor(screenHeight * 0.25) -- Around 25% down from top
    local playerMinionY = math.floor(screenHeight * 0.60)   -- Around 60% down from top
    
    -- Draw opponent minion area
    love.graphics.setColor(COLORS.minionArea)
    love.graphics.rectangle("fill", 10, opponentMinionY, screenWidth - 20, 120, 5, 5)
    
    -- Draw opponent minions
    local totalWidth = #board.player2Minions * (MINION_WIDTH + SPACING)
    local startX = (screenWidth - totalWidth) / 2
    for i, minion in ipairs(board.player2Minions) do
        local x = startX + (i - 1) * (MINION_WIDTH + SPACING)
        drawMinion(minion, x, opponentMinionY + 10)
    end
    
    -- Draw player minion area
    love.graphics.setColor(COLORS.minionArea)
    love.graphics.rectangle("fill", 10, playerMinionY, screenWidth - 20, 120, 5, 5)
    
    -- Draw player minions
    totalWidth = #board.player1Minions * (MINION_WIDTH + SPACING)
    startX = (screenWidth - totalWidth) / 2
    for i, minion in ipairs(board.player1Minions) do
        local x = startX + (i - 1) * (MINION_WIDTH + SPACING)
        drawMinion(minion, x, playerMinionY + 10)
    end
    
    -- Draw player info (bottom)
    drawPlayerInfo(player1, screenHeight - 40, false)
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

return BoardRenderer