-- game/ui/boardrenderer.lua
-- Renders the grid-based board with spawn zones and minions.
-- Also uses a default simple font when drawing minion info.
-- Minions that are able to attack are highlighted with a green outline.
local BoardRenderer = {}

local TILE_SIZE = 80
local BOARD_COLS = 7
local BOARD_ROWS = 6
local boardWidth = TILE_SIZE * BOARD_COLS
local boardHeight = TILE_SIZE * BOARD_ROWS
local boardX = (love.graphics.getWidth() - boardWidth) / 2
local boardY = 50

-- Define a default board font (without the custom fancy font)
local defaultBoardFont = love.graphics.newFont(12)

local COLORS = {
    gridLine = {0, 0, 0, 1},
    -- Spawn zones: row 1 is Player 2's spawn zone; row 6 is Player 1's spawn zone.
    spawnZoneP1 = {0.8, 0.8, 0.8, 0.3},  -- Player 1 (bottom row)
    spawnZoneP2 = {0.8, 0.8, 0.8, 0.3},  -- Player 2 (top row)
    text = {1, 1, 1, 1},
    selectedOutline = {0, 1, 0, 1}  -- used for selected minion highlight
}

-- Draws an individual minion in its grid cell.
local function drawMinion(minion, cellX, cellY)
    local x = boardX + (cellX - 1) * TILE_SIZE
    local y = boardY + (cellY - 1) * TILE_SIZE

    -- Set background color based on owner:
    -- Dark blue for Player 1, red for Player 2.
    if minion.owner.name == "Player 1" then
        love.graphics.setColor(0.173, 0.243, 0.314, 1)  -- Dark blue
    else
        love.graphics.setColor(1, 0, 0, 1)  -- Red
    end
    love.graphics.rectangle("fill", x, y, TILE_SIZE, TILE_SIZE, 5, 5)

    -- Use the default board font for text.
    love.graphics.setFont(defaultBoardFont)
    love.graphics.setColor(COLORS.text)
    love.graphics.printf(minion.name, x, y + 5, TILE_SIZE, "center")
    love.graphics.printf("Atk:" .. minion.attack, x, y + 25, TILE_SIZE, "center")
    love.graphics.printf("HP:" .. minion.currentHealth, x, y + 40, TILE_SIZE, "center")
    love.graphics.printf("Mvt:" .. minion.movement, x, y + 55, TILE_SIZE, "center")
    love.graphics.printf(minion.archetype, x, y + 70, TILE_SIZE, "center")

    -- If the minion is able to attack, draw a green outline.
    if minion.canAttack then
         love.graphics.setColor(0, 1, 0, 1)  -- green color
         love.graphics.setLineWidth(3)
         love.graphics.rectangle("line", x, y, TILE_SIZE, TILE_SIZE, 5, 5)
         love.graphics.setLineWidth(1)
    end
end

function BoardRenderer.drawBoard(board, currentPlayer, selectedMinion)
    -- Draw the grid cells and highlight spawn zones.
    for y = 1, BOARD_ROWS do
        for x = 1, BOARD_COLS do
            local cellX = boardX + (x - 1) * TILE_SIZE
            local cellY = boardY + (y - 1) * TILE_SIZE
            if y == 1 then
                -- Row 1: Player 2's spawn zone.
                love.graphics.setColor(COLORS.spawnZoneP2)
                love.graphics.rectangle("fill", cellX, cellY, TILE_SIZE, TILE_SIZE)
            elseif y == BOARD_ROWS then
                -- Row 6: Player 1's spawn zone.
                love.graphics.setColor(COLORS.spawnZoneP1)
                love.graphics.rectangle("fill", cellX, cellY, TILE_SIZE, TILE_SIZE)
            else
                love.graphics.setColor(1, 1, 1, 0) -- transparent for non-spawn cells
                love.graphics.rectangle("fill", cellX, cellY, TILE_SIZE, TILE_SIZE)
            end
            love.graphics.setColor(COLORS.gridLine)
            love.graphics.rectangle("line", cellX, cellY, TILE_SIZE, TILE_SIZE)
        end
    end

    -- Draw each minion on the board.
    board:forEachMinion(function(minion, x, y)
        drawMinion(minion, x, y)
    end)

    -- Highlight the selected minion's cell, if any.
    if selectedMinion and selectedMinion.position then
        local sx = boardX + (selectedMinion.position.x - 1) * TILE_SIZE
        local sy = boardY + (selectedMinion.position.y - 1) * TILE_SIZE
        love.graphics.setColor(COLORS.selectedOutline)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", sx, sy, TILE_SIZE, TILE_SIZE, 5, 5)
        love.graphics.setLineWidth(1)
    end
end

return BoardRenderer
