-- game/ui/boardrenderer.lua
-- Renders the grid-based board with spawn zones, minions, towers, and cell coordinate labels.
-- Uses the centralized UI theme from game/ui/theme.lua.

local BoardRenderer = {}
local Theme = require("game.ui.theme")

local TILE_SIZE = 100
local BOARD_COLS = 9
local BOARD_ROWS = 9
local boardWidth = TILE_SIZE * BOARD_COLS
local boardHeight = TILE_SIZE * BOARD_ROWS
local boardX = (love.graphics.getWidth() - boardWidth) / 2
local boardY = 50

local boardFonts = nil  -- Initialized in drawMinion

local CIRCLE_RADIUS = 12
local CARD_CORNER_RADIUS = 6
local PAD_X = 14
local PAD_Y = 14

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
    love.graphics.setFont(boardFonts.cardStat)  -- Changed from .stat to .cardStat
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
local function drawMinion(minion, cellX, cellY, currentPlayer)
    if not boardFonts then boardFonts = Theme.fonts end

    local x = boardX + (cellX - 1) * TILE_SIZE
    local y = boardY + (cellY - 1) * TILE_SIZE

    love.graphics.setColor(minion.owner.name == "Player 1" and Theme.colors.cardBorderP1 or Theme.colors.cardBorderP2)
    love.graphics.rectangle("fill", x, y, TILE_SIZE, TILE_SIZE, CARD_CORNER_RADIUS)
    love.graphics.setColor(Theme.colors.cardBackground)
    love.graphics.rectangle("fill", x + 3, y + 3, TILE_SIZE - 6, TILE_SIZE - 6, CARD_CORNER_RADIUS - 2)
    love.graphics.setColor(Theme.colors.buttonBase)
    love.graphics.rectangle("fill", x + 7, y + 28, TILE_SIZE - 14, TILE_SIZE - 42)

    love.graphics.setFont(boardFonts.cardName)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.printf(minion.name, x + 10, y + 16, TILE_SIZE - 20, "center")

    love.graphics.setColor(Theme.colors.buttonBase)
    love.graphics.rectangle("fill", x + 3, y + TILE_SIZE - 16, TILE_SIZE - 6, 13, 3)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.setFont(boardFonts.cardType)
    love.graphics.printf(minion.archetype, x + 3, y + TILE_SIZE - 15, TILE_SIZE - 6, "center")

    drawStatCircle(x + TILE_SIZE - PAD_X, y + PAD_Y, minion.movement, Theme.colors.movementCircle, Theme.colors.movementBg)
    drawStatCircle(x + PAD_X, y + TILE_SIZE - PAD_Y, minion.attack, Theme.colors.attackCircle, Theme.colors.attackBg)
    drawStatCircle(x + TILE_SIZE - PAD_X, y + TILE_SIZE - PAD_Y, minion.currentHealth, Theme.colors.healthCircle, Theme.colors.healthBg)

    if minion.canAttack and minion.owner == currentPlayer then
        love.graphics.setColor(Theme.colors.accentGreen)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x, y, TILE_SIZE, TILE_SIZE, CARD_CORNER_RADIUS)
        love.graphics.setLineWidth(1)
    end
end

--------------------------------------------------
-- drawBoard: Main rendering function
--------------------------------------------------
function BoardRenderer.drawBoard(board, player1, player2, selectedMinion, currentPlayer, gameManager)
    if not boardFonts then boardFonts = Theme.fonts end

    for y = 1, BOARD_ROWS do
        for x = 1, BOARD_COLS do
            local cellX = boardX + (x - 1) * TILE_SIZE
            local cellY = boardY + (y - 1) * TILE_SIZE

            if y == 1 or y == BOARD_ROWS then
                love.graphics.setColor(Theme.colors.spawnZone)
                love.graphics.rectangle("fill", cellX, cellY, TILE_SIZE, TILE_SIZE)
            end

            love.graphics.setColor(Theme.colors.gridLine)
            love.graphics.rectangle("line", cellX, cellY, TILE_SIZE, TILE_SIZE)

            local colLetter = string.char(64 + x)
            local cellLabel = colLetter .. tostring(y)
            love.graphics.setFont(boardFonts.cardType)
            love.graphics.setColor(1, 1, 1, 0.5)
            local labelWidth = boardFonts.cardType:getWidth(cellLabel)
            love.graphics.print(cellLabel, cellX + TILE_SIZE - labelWidth - 2, cellY + 2)
        end
    end

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
                    love.graphics.setColor(Theme.colors.accentBlue)
                    love.graphics.setLineWidth(3)
                    love.graphics.rectangle("line", tileX, tileY, TILE_SIZE, TILE_SIZE)
                    love.graphics.setLineWidth(1)
                end
            end
        end
    end

    board:forEachMinion(function(minion, x, y)
        drawMinion(minion, x, y, currentPlayer)
    end)

    if player1.tower then
        local tower = player1.tower
        local towerX = boardX + (tower.position.x - 1) * TILE_SIZE
        local towerY = boardY + (tower.position.y - 1) * TILE_SIZE
        love.graphics.setColor(1, 1, 1, 1)
        local scale = TILE_SIZE / tower.image:getWidth()
        love.graphics.draw(tower.image, towerX, towerY, 0, scale, scale)
        love.graphics.setFont(boardFonts.cardName)
        love.graphics.setColor(Theme.colors.textPrimary)
        love.graphics.printf(tostring(tower.hp), towerX, towerY + (TILE_SIZE - boardFonts.cardName:getHeight()) / 2, TILE_SIZE, "center")
    end
    if player2.tower then
        local tower = player2.tower
        local towerX = boardX + (tower.position.x - 1) * TILE_SIZE
        local towerY = boardY + (tower.position.y - 1) * TILE_SIZE
        love.graphics.setColor(1, 1, 1, 1)
        local scale = TILE_SIZE / tower.image:getWidth()
        love.graphics.draw(tower.image, towerX, towerY, 0, scale, scale)
        love.graphics.setFont(boardFonts.cardName)
        love.graphics.setColor(Theme.colors.textPrimary)
        love.graphics.printf(tostring(tower.hp), towerX, towerY + (TILE_SIZE - boardFonts.cardName:getHeight()) / 2, TILE_SIZE, "center")
    end

    if selectedMinion and selectedMinion.position then
        local sx = boardX + (selectedMinion.position.x - 1) * TILE_SIZE
        local sy = boardY + (selectedMinion.position.y - 1) * TILE_SIZE
        love.graphics.setColor(Theme.colors.accentGreen)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", sx, sy, TILE_SIZE, TILE_SIZE, CARD_CORNER_RADIUS)
        love.graphics.setLineWidth(1)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return BoardRenderer