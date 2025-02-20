-- game/ui/boardrenderer.lua
-- Renders the grid-based board with spawn zones, minions, towers, and cell coordinate labels.
-- Updated to match the visual style of cardrenderer.lua: rounded cards with stat circles,
-- consistent colors, and structured layout within 100x100 tiles.

local BoardRenderer = {}

local TILE_SIZE = 100  -- Tile size for the grid
local BOARD_COLS = 9
local BOARD_ROWS = 9
local boardWidth = TILE_SIZE * BOARD_COLS
local boardHeight = TILE_SIZE * BOARD_ROWS
local boardX = (love.graphics.getWidth() - boardWidth) / 2
local boardY = 50

-- Fonts: Reusing the same fonts as cardrenderer.lua for consistency
local function getBoardFonts()
    return {
        name = love.graphics.newFont("assets/fonts/InknutAntiqua-Regular.ttf", 10), -- Card name
        stat = love.graphics.newFont(12),                                           -- Stats (slightly smaller than cardrenderer)
        type = love.graphics.newFont(9),                                            -- Archetype/type at bottom
        cellLabel = love.graphics.newFont(10)                                       -- Cell coordinates
    }
end
local boardFonts = nil  -- Initialized in drawMinion

-- Color palette aligned with cardrenderer.lua
local COLORS = {
    gridLine = {0, 0, 0, 1},
    spawnZoneP1 = {0.8, 0.8, 0.8, 0.3},  -- Player 1 spawn (bottom row)
    spawnZoneP2 = {0.8, 0.8, 0.8, 0.3},  -- Player 2 spawn (top row)
    background = {0.2, 0.2, 0.25, 1},    -- Dark slate background
    borderP1 = {0.173, 0.243, 0.314, 1}, -- Player 1 dark blue border
    borderP2 = {1, 0, 0, 1},             -- Player 2 red border
    innerBorder = {0.3, 0.3, 0.35, 1},   -- Inner frame
    attackCircle = {0.9, 0.8, 0.2, 1},   -- Yellow attack
    healthCircle = {0.8, 0.2, 0.2, 1},   -- Red health
    movementCircle = {0.9, 0.9, 0.9, 1}, -- White movement
    attackBg = {0.5, 0.4, 0.1, 1},       -- Darker yellow
    healthBg = {0.5, 0.15, 0.15, 1},     -- Darker red
    movementBg = {0.4, 0.4, 0.4, 1},     -- Gray
    statText = {1, 1, 1, 1},             -- White stat text
    cardName = {1, 0.95, 0.8, 1},        -- Light cream name
    cardType = {0.7, 0.7, 0.8, 1},       -- Light blue-gray type
    typeBanner = {0.25, 0.25, 0.3, 1},   -- Dark type banner
    selectedOutline = {0, 1, 0, 1},      -- Green for attackable
    moveHighlight = {0, 0.4, 1, 1}       -- Blue for movement range
}

-- Constants for minion card layout within 100x100 tile
local CIRCLE_RADIUS = 12        -- Smaller than cardrenderer's 14 for tile fit
local CARD_CORNER_RADIUS = 6    -- Slightly smaller corners
local PAD_X = 14                -- Padding for stat circles
local PAD_Y = 14

--------------------------------------------------
-- drawStatCircle: Helper to draw stat circles with background and outlined text
--------------------------------------------------
local function drawStatCircle(x, y, value, circleColor, bgColor)
    love.graphics.setColor(bgColor)
    love.graphics.circle("fill", x, y, CIRCLE_RADIUS + 2)
    love.graphics.setColor(circleColor)
    love.graphics.circle("fill", x, y, CIRCLE_RADIUS)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.circle("line", x, y, CIRCLE_RADIUS)

    local valueStr = tostring(value)
    love.graphics.setFont(boardFonts.stat)
    local textWidth = boardFonts.stat:getWidth(valueStr)
    local textHeight = boardFonts.stat:getHeight()
    local textX = x - textWidth / 2
    local textY = y - textHeight / 2

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.print(valueStr, textX - 1, textY)
    love.graphics.print(valueStr, textX + 1, textY)
    love.graphics.print(valueStr, textX, textY - 1)
    love.graphics.print(valueStr, textX, textY + 1)
    love.graphics.setColor(COLORS.statText)
    love.graphics.print(valueStr, textX, textY)
end

--------------------------------------------------
-- drawMinion: Renders a minion in its grid cell with cardrenderer.lua style
--------------------------------------------------
local function drawMinion(minion, cellX, cellY, currentPlayer)
    if not boardFonts then boardFonts = getBoardFonts() end

    local x = boardX + (cellX - 1) * TILE_SIZE
    local y = boardY + (cellY - 1) * TILE_SIZE

    -- 1) Background and border (owner-specific)
    love.graphics.setColor(minion.owner.name == "Player 1" and COLORS.borderP1 or COLORS.borderP2)
    love.graphics.rectangle("fill", x, y, TILE_SIZE, TILE_SIZE, CARD_CORNER_RADIUS)
    love.graphics.setColor(COLORS.background)
    love.graphics.rectangle("fill", x + 3, y + 3, TILE_SIZE - 6, TILE_SIZE - 6, CARD_CORNER_RADIUS - 2)
    love.graphics.setColor(COLORS.innerBorder)
    love.graphics.rectangle("fill", x + 7, y + 28, TILE_SIZE - 14, TILE_SIZE - 42)

    -- 2) Card Name (centered, lower as in cardrenderer)
    love.graphics.setFont(boardFonts.name)
    love.graphics.setColor(COLORS.cardName)
    love.graphics.printf(minion.name, x + 10, y + 16, TILE_SIZE - 20, "center")

    -- 3) Archetype at bottom (like card type)
    love.graphics.setColor(COLORS.typeBanner)
    love.graphics.rectangle("fill", x + 3, y + TILE_SIZE - 16, TILE_SIZE - 6, 13, 3)
    love.graphics.setColor(COLORS.cardType)
    love.graphics.setFont(boardFonts.type)
    love.graphics.printf(minion.archetype, x + 3, y + TILE_SIZE - 15, TILE_SIZE - 6, "center")

    -- 4) Stat Circles (movement top-right, attack bottom-left, health bottom-right)
    drawStatCircle(x + TILE_SIZE - PAD_X, y + PAD_Y, minion.movement, COLORS.movementCircle, COLORS.movementBg)
    drawStatCircle(x + PAD_X, y + TILE_SIZE - PAD_Y, minion.attack, COLORS.attackCircle, COLORS.attackBg)
    drawStatCircle(x + TILE_SIZE - PAD_X, y + TILE_SIZE - PAD_Y, minion.currentHealth, COLORS.healthCircle, COLORS.healthBg)

    -- 5) Green outline if attackable and it's their owner's turn
    if minion.canAttack and minion.owner == currentPlayer then
        love.graphics.setColor(COLORS.selectedOutline)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x, y, TILE_SIZE, TILE_SIZE, CARD_CORNER_RADIUS)
        love.graphics.setLineWidth(1)
    end
end

--------------------------------------------------
-- drawBoard: Main rendering function
--------------------------------------------------
function BoardRenderer.drawBoard(board, player1, player2, selectedMinion, currentPlayer, gameManager)
    if not boardFonts then boardFonts = getBoardFonts() end

    -- 1) Grid, spawn zones, and cell labels
    for y = 1, BOARD_ROWS do
        for x = 1, BOARD_COLS do
            local cellX = boardX + (x - 1) * TILE_SIZE
            local cellY = boardY + (y - 1) * TILE_SIZE

            if y == 1 then
                love.graphics.setColor(COLORS.spawnZoneP2)
                love.graphics.rectangle("fill", cellX, cellY, TILE_SIZE, TILE_SIZE)
            elseif y == BOARD_ROWS then
                love.graphics.setColor(COLORS.spawnZoneP1)
                love.graphics.rectangle("fill", cellX, cellY, TILE_SIZE, TILE_SIZE)
            end

            love.graphics.setColor(COLORS.gridLine)
            love.graphics.rectangle("line", cellX, cellY, TILE_SIZE, TILE_SIZE)

            local colLetter = string.char(64 + x)
            local cellLabel = colLetter .. tostring(y)
            love.graphics.setFont(boardFonts.cellLabel)
            love.graphics.setColor(1, 1, 1, 0.5)
            local labelWidth = boardFonts.cellLabel:getWidth(cellLabel)
            love.graphics.print(cellLabel, cellX + TILE_SIZE - labelWidth - 2, cellY + 2)
        end
    end

    -- 2) Movement range highlights (blue outlines)
    if selectedMinion and selectedMinion.owner == currentPlayer and not selectedMinion.summoningSickness and not selectedMinion.hasMoved and selectedMinion.position then
        local sx = selectedMinion.position.x
        local sy = selectedMinion.position.y
        local moveRange = selectedMinion.movement or 1
        for yy = 1, BOARD_ROWS do
            for xx = 1, BOARD_COLS do
                local dist = math.max(math.abs(xx - sx), math.abs(yy - sy))
                if dist <= moveRange and board:isEmpty(xx, yy) and not gameManager:isTileOccupiedByTower(xx, yy) then
                    local tileX = boardX + (xx - 1) * TILE_SIZE
                    local tileY = boardY + (yy - 1) * TILE_SIZE
                    love.graphics.setColor(COLORS.moveHighlight)
                    love.graphics.setLineWidth(3)
                    love.graphics.rectangle("line", tileX, tileY, TILE_SIZE, TILE_SIZE)
                    love.graphics.setLineWidth(1)
                end
            end
        end
    end

    -- 3) Minions
    board:forEachMinion(function(minion, x, y)
        drawMinion(minion, x, y, currentPlayer)
    end)

    -- 4) Towers
    if player1.tower then
        local tower = player1.tower
        local towerX = boardX + (tower.position.x - 1) * TILE_SIZE
        local towerY = boardY + (tower.position.y - 1) * TILE_SIZE
        love.graphics.setColor(1, 1, 1, 1)
        local scale = TILE_SIZE / tower.image:getWidth()
        love.graphics.draw(tower.image, towerX, towerY, 0, scale, scale)
        love.graphics.setFont(boardFonts.name) -- Using name font for tower HP
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(tostring(tower.hp), towerX, towerY + (TILE_SIZE - boardFonts.name:getHeight()) / 2, TILE_SIZE, "center")
    end
    if player2.tower then
        local tower = player2.tower
        local towerX = boardX + (tower.position.x - 1) * TILE_SIZE
        local towerY = boardY + (tower.position.y - 1) * TILE_SIZE
        love.graphics.setColor(1, 1, 1, 1)
        local scale = TILE_SIZE / tower.image:getWidth()
        love.graphics.draw(tower.image, towerX, towerY, 0, scale, scale)
        love.graphics.setFont(boardFonts.name)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(tostring(tower.hp), towerX, towerY + (TILE_SIZE - boardFonts.name:getHeight()) / 2, TILE_SIZE, "center")
    end

    -- 5) Selected minion highlight (thicker green outline)
    if selectedMinion and selectedMinion.position then
        local sx = boardX + (selectedMinion.position.x - 1) * TILE_SIZE
        local sy = boardY + (selectedMinion.position.y - 1) * TILE_SIZE
        love.graphics.setColor(COLORS.selectedOutline)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", sx, sy, TILE_SIZE, TILE_SIZE, CARD_CORNER_RADIUS)
        love.graphics.setLineWidth(1)
    end

    love.graphics.setColor(1, 1, 1, 1) -- Reset color
end

return BoardRenderer