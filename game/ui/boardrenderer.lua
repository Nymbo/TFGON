-- game/ui/boardrenderer.lua
-- Renders the grid-based board with variable dimensions and tooltips

local BoardRenderer = {}
local Theme = require("game.ui.theme")
local Tooltip = require("game.ui.tooltip")

local TILE_SIZE = 100
local boardX = 0  -- Will be calculated based on board size
local boardY = 50 -- Top margin

local boardFonts = nil  -- Initialized in drawMinion

local CIRCLE_RADIUS = 12
local CARD_CORNER_RADIUS = 6
local PAD_X = 14
local PAD_Y = 14

-- Attack pattern overlay image (red diagonal)
local attackPattern = love.graphics.newImage("assets/images/pattern_diagonal_red_small.png")
-- Transparent pattern for valid spawn cells
local transparentPattern = love.graphics.newImage("assets/images/pattern_diagonal_transparent_small.png")

-- Track the currently hovered minion
local hoveredMinion = nil

--------------------------------------------------
-- Helper function to check if a point is within a tile
--------------------------------------------------
local function isPointInTile(x, y, tileX, tileY)
    return x >= tileX and x < tileX + TILE_SIZE and
           y >= tileY and y < tileY + TILE_SIZE
end

--------------------------------------------------
-- Helper: Get the reach of a minion based on its archetype
--------------------------------------------------
local function getMinionReach(minion)
    if minion.archetype == "Melee" then
        return 1
    elseif minion.archetype == "Magic" then
        return 2
    elseif minion.archetype == "Ranged" then
        return 3
    end
    return 1 -- default
end

--------------------------------------------------
-- Helper: Check if a minion is in attack range of another
--------------------------------------------------
local function isInAttackRange(attacker, target)
    if not attacker.position or not target.position then
        return false
    end
    
    local dx = math.abs(attacker.position.x - target.position.x)
    local dy = math.abs(attacker.position.y - target.position.y)
    local distance = math.max(dx, dy)
    local reach = getMinionReach(attacker)
    
    return distance <= reach
end

--------------------------------------------------
-- drawStatCircle: Helper to draw stat circles
--------------------------------------------------
local function drawStatCircle(x, y, value, circleColor, bgColor)
    love.graphics.setColor(bgColor)
    love.graphics.circle("fill", x, y, CIRCLE_RADIUS + 2)
    love.graphics.setColor(circleColor)
    love.graphics.circle("fill", x, y, CIRCLE_RADIUS)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.circle("line", x, y, CIRCLE_RADIUS)

    local valueStr = tostring(value)
    love.graphics.setFont(boardFonts.cardStat)
    local textWidth = boardFonts.cardStat:getWidth(valueStr)
    local textHeight = boardFonts.cardStat:getHeight()
    local textX = x - textWidth / 2
    local textY = y - textHeight / 2

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.print(valueStr, textX - 1, textY)
    love.graphics.print(valueStr, textX + 1, textY)
    love.graphics.print(valueStr, textX, textY - 1)
    love.graphics.print(valueStr, textX, textY + 1)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.print(valueStr, textX, textY)
end

--------------------------------------------------
-- drawMinion: Renders a minion in its grid cell
--------------------------------------------------
local function drawMinion(minion, cellX, cellY, currentPlayer, selectedMinion)
    if not boardFonts then
        boardFonts = Theme.fonts
    end

    local x = boardX + (cellX - 1) * TILE_SIZE
    local y = boardY + (cellY - 1) * TILE_SIZE

    -- Outer border color depends on owner
    love.graphics.setColor(
        minion.owner.name == "Player 1"
            and Theme.colors.cardBorderP1
            or Theme.colors.cardBorderP2
    )
    love.graphics.rectangle("fill", x, y, TILE_SIZE, TILE_SIZE, CARD_CORNER_RADIUS)

    -- Card-like background
    love.graphics.setColor(Theme.colors.cardBackground)
    love.graphics.rectangle("fill", x + 3, y + 3, TILE_SIZE - 6, TILE_SIZE - 6, CARD_CORNER_RADIUS - 2)

    -- Inner rectangle for name area
    love.graphics.setColor(Theme.colors.buttonBase)
    love.graphics.rectangle("fill", x + 7, y + 28, TILE_SIZE - 14, TILE_SIZE - 42)

    -- Minion name
    love.graphics.setFont(boardFonts.cardName)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.printf(minion.name, x + 10, y + 16, TILE_SIZE - 20, "center")

    -- Archetype label at bottom
    love.graphics.setColor(Theme.colors.buttonBase)
    love.graphics.rectangle("fill", x + 3, y + TILE_SIZE - 16, TILE_SIZE - 6, 13, 3)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.setFont(boardFonts.cardType)
    love.graphics.printf(minion.archetype, x + 3, y + TILE_SIZE - 15, TILE_SIZE - 6, "center")

    -- Stat circles
    drawStatCircle(
        x + TILE_SIZE - PAD_X,
        y + PAD_Y,
        minion.movement,
        Theme.colors.movementCircle,
        Theme.colors.movementBg
    )
    drawStatCircle(
        x + PAD_X,
        y + TILE_SIZE - PAD_Y,
        minion.attack,
        Theme.colors.attackCircle,
        Theme.colors.attackBg
    )
    drawStatCircle(
        x + TILE_SIZE - PAD_X,
        y + TILE_SIZE - PAD_Y,
        minion.currentHealth,
        Theme.colors.healthCircle,
        Theme.colors.healthBg
    )

    -- Outline logic
    if minion.owner == currentPlayer then
        -- Now also require minion.canAttack for the blue outline:
        if (not minion.hasMoved) and (not minion.summoningSickness) and minion.canAttack then
            -- Blue outline indicates the minion can still move (hasn't moved yet) AND can still attack
            love.graphics.setColor(Theme.colors.accentBlue)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", x, y, TILE_SIZE, TILE_SIZE, CARD_CORNER_RADIUS)
            love.graphics.setLineWidth(1)
        elseif minion.canAttack then
            -- Green outline if it can attack
            love.graphics.setColor(Theme.colors.accentGreen)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", x, y, TILE_SIZE, TILE_SIZE, CARD_CORNER_RADIUS)
            love.graphics.setLineWidth(1)
        end
    end

    -- If selectedMinion can attack this minion, overlay the "attack range" pattern
    if selectedMinion
       and selectedMinion.owner == currentPlayer
       and selectedMinion.canAttack
       and minion.owner ~= currentPlayer
       and isInAttackRange(selectedMinion, minion)
    then
        love.graphics.setBlendMode("alpha", "alphamultiply")
        love.graphics.setColor(1, 1, 1, 0.7)

        local patternW, patternH = attackPattern:getDimensions()
        local scaleX = TILE_SIZE / patternW
        local scaleY = TILE_SIZE / patternH
        love.graphics.draw(attackPattern, x, y, 0, scaleX, scaleY)

        love.graphics.setBlendMode("alpha")
    end
end

--------------------------------------------------
-- drawTower: Renders a tower in its grid cell
--------------------------------------------------
local function drawTower(tower, currentPlayer)
    local x = boardX + (tower.position.x - 1) * TILE_SIZE
    local y = boardY + (tower.position.y - 1) * TILE_SIZE

    -- Tower image
    love.graphics.setColor(1, 1, 1, 1)
    local scale = TILE_SIZE / tower.image:getWidth()
    love.graphics.draw(tower.image, x, y, 0, scale, scale)

    -- Tower HP
    if not boardFonts then
        boardFonts = Theme.fonts
    end
    love.graphics.setFont(boardFonts.cardName)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.printf(
        tostring(tower.hp),
        x,
        y + (TILE_SIZE - boardFonts.cardName:getHeight()) / 2,
        TILE_SIZE,
        "center"
    )
end

--------------------------------------------------
-- drawMoveRange: Shows valid movement tiles for selected minion
--------------------------------------------------
local function drawMoveRange(board, selectedMinion, gameManager)
    if (not selectedMinion)
       or selectedMinion.summoningSickness
       or selectedMinion.hasMoved
       or (not selectedMinion.position)
    then
        return
    end

    local sx = selectedMinion.position.x
    local sy = selectedMinion.position.y
    local moveRange = selectedMinion.movement or 1

    for row = 1, board.rows do
        for col = 1, board.cols do
            local dist = math.max(math.abs(col - sx), math.abs(row - sy))
            if dist <= moveRange
               and board:isEmpty(col, row)
               and (not gameManager:isTileOccupiedByTower(col, row))
            then
                local tileX = boardX + (col - 1) * TILE_SIZE
                local tileY = boardY + (row - 1) * TILE_SIZE
                love.graphics.setColor(Theme.colors.accentBlue)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", tileX, tileY, TILE_SIZE, TILE_SIZE)
                love.graphics.setLineWidth(1)
            end
        end
    end
end

--------------------------------------------------
-- drawSummonOverlay: Highlights valid spawn cells
-- if there is a pendingSummon. We use a transparent
-- pattern overlay (pattern_diagonal_transparent_small.png)
--------------------------------------------------
local function drawSummonOverlay(board, pendingSummon, gameManager)
    if not pendingSummon then
        return
    end

    -- The spawn row depends on whether it's player1 or player2
    local spawnRow
    if pendingSummon.player == gameManager.player1 then
        spawnRow = board.rows
    else
        spawnRow = 1
    end

    -- Highlight each cell in that row if it's empty and not a tower
    for col = 1, board.cols do
        if board:isEmpty(col, spawnRow) and (not gameManager:isTileOccupiedByTower(col, spawnRow)) then
            local cellX = boardX + (col - 1) * TILE_SIZE
            local cellY = boardY + (spawnRow - 1) * TILE_SIZE

            love.graphics.setBlendMode("alpha", "alphamultiply")
            love.graphics.setColor(1, 1, 1, 0.4) -- 40% opacity

            local patternW, patternH = transparentPattern:getDimensions()
            local scaleX = TILE_SIZE / patternW
            local scaleY = TILE_SIZE / patternH
            love.graphics.draw(transparentPattern, cellX, cellY, 0, scaleX, scaleY)

            love.graphics.setBlendMode("alpha")
        end
    end
end

--------------------------------------------------
-- drawBoard: Main rendering function
-- 'pendingSummon' param to highlight spawn cells.
--------------------------------------------------
function BoardRenderer.drawBoard(
    board,
    player1,
    player2,
    selectedMinion,
    currentPlayer,
    gameManager,
    pendingSummon  -- optional param
)
    if not boardFonts then
        boardFonts = Theme.fonts
    end

    -- Calculate board dimensions
    local boardWidth = TILE_SIZE * board.cols
    local boardHeight = TILE_SIZE * board.rows
    
    -- Center the board horizontally
    boardX = (love.graphics.getWidth() - boardWidth) / 2

    -- Update hoveredMinion based on mouse position
    local mx, my = love.mouse.getPosition()
    hoveredMinion = nil
    
    if mx >= boardX and mx < boardX + boardWidth and
       my >= boardY and my < boardY + boardHeight
    then
        local cellX = math.floor((mx - boardX) / TILE_SIZE) + 1
        local cellY = math.floor((my - boardY) / TILE_SIZE) + 1
        
        if cellX >= 1 and cellX <= board.cols and
           cellY >= 1 and cellY <= board.rows
        then
            hoveredMinion = board:getMinionAt(cellX, cellY)
        end
    end

    -- Draw the grid
    for row = 1, board.rows do
        for col = 1, board.cols do
            local tileX = boardX + (col - 1) * TILE_SIZE
            local tileY = boardY + (row - 1) * TILE_SIZE

            love.graphics.setColor(Theme.colors.gridLine)
            love.graphics.rectangle("line", tileX, tileY, TILE_SIZE, TILE_SIZE)

            -- Cell coordinates (faded)
            local colLetter = string.char(64 + col)
            local cellLabel = colLetter .. tostring(row)
            love.graphics.setFont(boardFonts.cardType)
            love.graphics.setColor(1, 1, 1, 0.5)
            local labelWidth = boardFonts.cardType:getWidth(cellLabel)
            love.graphics.print(cellLabel, tileX + TILE_SIZE - labelWidth - 2, tileY + 2)
        end
    end

    -- Show move range for selected minion
    drawMoveRange(board, selectedMinion, gameManager)

    -- Draw all minions
    board:forEachMinion(function(minion, col, row)
        drawMinion(minion, col, row, currentPlayer, selectedMinion)
    end)

    -- Draw towers
    if player1.tower then
        drawTower(player1.tower, currentPlayer)
    end
    if player2.tower then
        drawTower(player2.tower, currentPlayer)
    end

    -- Bright green outline for the explicitly selected minion
    if selectedMinion and selectedMinion.position then
        local sx = boardX + (selectedMinion.position.x - 1) * TILE_SIZE
        local sy = boardY + (selectedMinion.position.y - 1) * TILE_SIZE
        love.graphics.setColor(Theme.colors.accentGreen)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", sx, sy, TILE_SIZE, TILE_SIZE, CARD_CORNER_RADIUS)
        love.graphics.setLineWidth(1)
    end

    -- Show overlay for possible spawn cells if there's a pending Summon
    drawSummonOverlay(board, pendingSummon, gameManager)

    -- Tooltip
    Tooltip.update(love.timer.getDelta(), mx, my, hoveredMinion)
    Tooltip.draw()

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

--------------------------------------------------
-- Utility: getBoardPosition
--------------------------------------------------
function BoardRenderer.getBoardPosition()
    return boardX, boardY
end

--------------------------------------------------
-- Utility: getTileSize
--------------------------------------------------
function BoardRenderer.getTileSize()
    return TILE_SIZE
end

return BoardRenderer
