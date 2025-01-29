-- game/ui/boardrenderer.lua
-- Handles the visual representation of the board,
-- including player info, minion areas, and minion cards.

--------------------------------------------------
-- Table definition for BoardRenderer
--------------------------------------------------
local BoardRenderer = {}

--------------------------------------------------
-- Constants for layout and styling
--------------------------------------------------
local MINION_WIDTH = 80             -- Width of each minion card
local MINION_HEIGHT = 100           -- Height of each minion card
local SPACING = 10                  -- Horizontal spacing between minions

-- Color configuration used throughout the board
local COLORS = {
    playerInfo = {0, 0, 0, 0.3},         -- Semi-transparent black for player info background
    minionArea = {1, 1, 1, 0.1},        -- Very light semi-transparent white for minion area
    minion = {
        background = {0.173, 0.243, 0.314, 1},  -- #2c3e50  (dark bluish)
        border = {0.902, 0.494, 0.133, 1},      -- #e67e22  (orange)
        attackReady = {0.188, 0.824, 0.188, 1}, -- #30d630  (green) indicates minion can attack
        targetable = {0.824, 0.098, 0.098, 1},  -- #d63031  (red) indicates minion/hero is a valid target
        text = {1, 1, 1, 1}                    -- White text
    }
}

--------------------------------------------------
-- drawPlayerInfo(player, y, isOpponent, isTargetable):
-- Renders the player info (name, HP, mana) in a semi-transparent box.
-- Highlights the box outline if 'isTargetable' is true.
--------------------------------------------------
local function drawPlayerInfo(player, y, isOpponent, isTargetable)
    -- Draw semi-transparent background for player info area
    love.graphics.setColor(COLORS.playerInfo)
    
    -- If this player is a valid attack target, draw a colored outline
    if isTargetable then
        love.graphics.setColor(COLORS.minion.targetable)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", 10, y, love.graphics.getWidth() - 20, 30, 5, 5)
        love.graphics.setLineWidth(1)
    end
    
    -- Fill the rectangle (player info background)
    love.graphics.setColor(COLORS.playerInfo)
    love.graphics.rectangle("fill", 10, y, love.graphics.getWidth() - 20, 30, 5, 5)
    
    -- Draw player name
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(player.name, 20, y + 5)
    
    -- Centered HP
    love.graphics.printf(
        string.format("HP: %d", player.health),
        0, y + 5, love.graphics.getWidth(), "center"
    )
    
    -- Right-aligned mana
    love.graphics.printf(
        string.format("Mana: %d/%d", player.manaCrystals, player.maxManaCrystals),
        0, y + 5, love.graphics.getWidth() - 20, "right"
    )
end

--------------------------------------------------
-- drawMinion(minion, x, y, isAttackable, isTargetable):
-- Renders an individual minion's background, border,
-- and textual info (name, attack, health).
-- Highlights the minion if it can attack or if it's targetable.
--------------------------------------------------
local function drawMinion(minion, x, y, isAttackable, isTargetable)
    -- Draw the minion's background rectangle
    love.graphics.setColor(COLORS.minion.background)
    love.graphics.rectangle("fill", x, y, MINION_WIDTH, MINION_HEIGHT, 5, 5)
    
    -- Configure border style
    love.graphics.setLineWidth(2)
    if isTargetable then
        -- If this minion can be targeted by an attack, use the targetable color
        love.graphics.setColor(COLORS.minion.targetable)
    elseif isAttackable then
        -- If minion can attack, use the "attackReady" color
        love.graphics.setColor(COLORS.minion.attackReady)
    else
        -- Otherwise, use the standard border color
        love.graphics.setColor(COLORS.minion.border)
    end
    
    -- Draw the minion's border
    love.graphics.rectangle("line", x, y, MINION_WIDTH, MINION_HEIGHT, 5, 5)
    love.graphics.setLineWidth(1)
    
    -- Draw minion's name at the top
    love.graphics.setColor(COLORS.minion.text)
    love.graphics.printf(minion.name, x + 5, y + 5, MINION_WIDTH - 10, "center")
    
    -- Draw attack (left bottom) and health (right bottom)
    love.graphics.printf(
        tostring(minion.attack), 
        x + 5, 
        y + MINION_HEIGHT - 20,
        20, 
        "left"
    )
    love.graphics.printf(
        tostring(minion.currentHealth), 
        x + MINION_WIDTH - 25, 
        y + MINION_HEIGHT - 20, 
        20, 
        "right"
    )
end

--------------------------------------------------
-- BoardRenderer.drawBoard(board, player1, player2, selectedAttacker, currentPlayer):
-- Orchestrates rendering of:
--   - Opponent (player2) info and minions (top)
--   - Player1 info and minions (bottom)
--   - Highlights any valid targets based on selectedAttacker
--------------------------------------------------
function BoardRenderer.drawBoard(board, player1, player2, selectedAttacker, currentPlayer)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Determine if there's an ongoing attack (someone has selected an attacker)
    local isAttacking = (selectedAttacker ~= nil)
    
    -- Check which player's turn it is
    local isPlayer1Turn = (currentPlayer == player1)
    
    -- The 'targetPlayer' is the opposite player of the current turn,
    -- which might be the hero we can target if there's a selected attacker.
    local targetPlayer = isPlayer1Turn and player2 or player1
    
    -- If we have a selected attacker who is a minion, the enemy hero might be targetable
    -- (This logic can be adjusted as needed depending on your game rules.)
    local isHeroTargetable = (isAttacking and selectedAttacker.type == "minion")
    
    --------------------------------------------------
    -- 1) Draw the opponent's (player2) info at the top
    --------------------------------------------------
    drawPlayerInfo(
        player2,
        10,                      -- Y position for the top bar
        true,                    -- This is the opponent
        (isHeroTargetable and isPlayer1Turn)  -- Only highlight if targetable by the attacker
    )
    
    -- Calculate the vertical positions for the opponent's minions and player's minions
    local opponentMinionY = math.floor(screenHeight * 0.25)
    local playerMinionY   = math.floor(screenHeight * 0.60)
    
    --------------------------------------------------
    -- 2) Draw the opponent's minion area (top middle)
    --------------------------------------------------
    love.graphics.setColor(COLORS.minionArea)
    love.graphics.rectangle("fill", 10, opponentMinionY, screenWidth - 20, 120, 5, 5)
    
    -- Draw the opponent's minions
    local totalWidth = #board.player2Minions * (MINION_WIDTH + SPACING)
    local startX = (screenWidth - totalWidth) / 2
    
    for i, minion in ipairs(board.player2Minions) do
        local x = startX + (i - 1) * (MINION_WIDTH + SPACING)
        -- If we're attacking, is this minion targetable?
        -- For simplicity, we check if the attacker is a minion,
        -- meaning we might allow attacking these minions.
        local isTargetable = (isAttacking and selectedAttacker.type == "minion")
        
        -- isAttackable for an opponent's minion doesn't really apply
        -- but we pass 'minion.canAttack' for completeness (though it might be false).
        drawMinion(minion, x, opponentMinionY + 10, minion.canAttack, isTargetable)
    end
    
    --------------------------------------------------
    -- 3) Draw the current player's minion area (bottom middle)
    --------------------------------------------------
    love.graphics.setColor(COLORS.minionArea)
    love.graphics.rectangle("fill", 10, playerMinionY, screenWidth - 20, 120, 5, 5)
    
    -- Draw the current player's minions
    totalWidth = #board.player1Minions * (MINION_WIDTH + SPACING)
    startX = (screenWidth - totalWidth) / 2
    
    for i, minion in ipairs(board.player1Minions) do
        local x = startX + (i - 1) * (MINION_WIDTH + SPACING)
        
        -- A minion is "attackable" if it canAttack == true and it belongs to the current player
        local isAttackable = (minion.canAttack and currentPlayer == player1)
        
        -- Since these are friendly minions, we generally won't mark them as "targetable" by default.
        drawMinion(minion, x, playerMinionY + 10, isAttackable, false)
    end
    
    --------------------------------------------------
    -- 4) Draw the current player's (player1) info at the bottom
    --------------------------------------------------
    local isFriendlyHeroTargetable = (isAttacking and selectedAttacker.type == "minion")
    drawPlayerInfo(
        player1,
        screenHeight - 40,                  -- Y position near the bottom
        false,                              -- This is not the opponent
        (isHeroTargetable and not isPlayer1Turn)
    )
    
    -- Reset the color to fully opaque white for subsequent rendering
    love.graphics.setColor(1, 1, 1, 1)
end

return BoardRenderer
