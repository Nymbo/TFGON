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
        attackReady = {0.188, 0.824, 0.188, 1}, -- Green glow (#30d630)
        targetable = {0.824, 0.098, 0.098, 1},  -- Red glow (#d63031)
        text = {1, 1, 1, 1}
    }
}

local function drawPlayerInfo(player, y, isOpponent, isTargetable)
    -- Draw semi-transparent background
    love.graphics.setColor(COLORS.playerInfo)
    if isTargetable then
        love.graphics.setColor(COLORS.minion.targetable)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", 10, y, love.graphics.getWidth() - 20, 30, 5, 5)
        love.graphics.setLineWidth(1)
    end
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

local function drawMinion(minion, x, y, isAttackable, isTargetable)
    -- Draw minion background
    love.graphics.setColor(COLORS.minion.background)
    love.graphics.rectangle("fill", x, y, MINION_WIDTH, MINION_HEIGHT, 5, 5)
    
    -- Draw border
    love.graphics.setLineWidth(2)
    if isTargetable then
        love.graphics.setColor(COLORS.minion.targetable)
    elseif isAttackable then
        love.graphics.setColor(COLORS.minion.attackReady)
    else
        love.graphics.setColor(COLORS.minion.border)
    end
    love.graphics.rectangle("line", x, y, MINION_WIDTH, MINION_HEIGHT, 5, 5)
    love.graphics.setLineWidth(1)
    
    -- Draw name and stats
    love.graphics.setColor(COLORS.minion.text)
    love.graphics.printf(minion.name, x + 5, y + 5, MINION_WIDTH - 10, "center")
    
    -- Draw attack/health
    love.graphics.printf(tostring(minion.attack), x + 5, y + MINION_HEIGHT - 20, 
                        20, "left")
    love.graphics.printf(tostring(minion.currentHealth), x + MINION_WIDTH - 25, 
                        y + MINION_HEIGHT - 20, 20, "right")
end

function BoardRenderer.drawBoard(board, player1, player2, selectedAttacker, currentPlayer)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Determine target information
    local isAttacking = selectedAttacker ~= nil
    local isPlayer1Turn = currentPlayer == player1
    local targetPlayer = isPlayer1Turn and player2 or player1
    
    -- Draw opponent info (top)
    local isHeroTargetable = isAttacking and selectedAttacker.type == "minion"
    drawPlayerInfo(player2, 10, true, isHeroTargetable and isPlayer1Turn)
    
    -- Calculate vertical positions
    local opponentMinionY = math.floor(screenHeight * 0.25)
    local playerMinionY = math.floor(screenHeight * 0.60)
    
    -- Draw opponent minion area
    love.graphics.setColor(COLORS.minionArea)
    love.graphics.rectangle("fill", 10, opponentMinionY, screenWidth - 20, 120, 5, 5)
    
    -- Draw opponent minions
    local totalWidth = #board.player2Minions * (MINION_WIDTH + SPACING)
    local startX = (screenWidth - totalWidth) / 2
    for i, minion in ipairs(board.player2Minions) do
        local x = startX + (i - 1) * (MINION_WIDTH + SPACING)
        local isTargetable = isAttacking and selectedAttacker.type == "minion"
        drawMinion(minion, x, opponentMinionY + 10, minion.canAttack, isTargetable)
    end
    
    -- Draw player minion area
    love.graphics.setColor(COLORS.minionArea)
    love.graphics.rectangle("fill", 10, playerMinionY, screenWidth - 20, 120, 5, 5)
    
    -- Draw player minions
    totalWidth = #board.player1Minions * (MINION_WIDTH + SPACING)
    startX = (screenWidth - totalWidth) / 2
    for i, minion in ipairs(board.player1Minions) do
        local x = startX + (i - 1) * (MINION_WIDTH + SPACING)
        local isAttackable = minion.canAttack and currentPlayer == player1
        drawMinion(minion, x, playerMinionY + 10, isAttackable, false)
    end
    
    -- Draw player info (bottom)
    local isFriendlyHeroTargetable = isAttacking and selectedAttacker.type == "minion"
    drawPlayerInfo(player1, screenHeight - 40, false, isHeroTargetable and not isPlayer1Turn)
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

return BoardRenderer