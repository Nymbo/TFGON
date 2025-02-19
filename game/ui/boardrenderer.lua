-- game/ui/boardrenderer.lua
-- Renders the grid-based board with spawn zones, minions, towers, and cell coordinate labels.
-- Also uses a default simple font when drawing minion info.
-- Highlights minions that can attack with a green outline, but only if it’s their owner's turn.
-- Highlights possible movement tiles in blue if a minion is selected and can still move.

local BoardRenderer = {}

local TILE_SIZE = 100  -- Tile size for better visibility
local BOARD_COLS = 9
local BOARD_ROWS = 9
local boardWidth = TILE_SIZE * BOARD_COLS
local boardHeight = TILE_SIZE * BOARD_ROWS
local boardX = (love.graphics.getWidth() - boardWidth) / 2
local boardY = 50

-- Define a default board font (without the custom fancy font)
local defaultBoardFont = love.graphics.newFont(12)
-- Define a small font for cell labels
local cellLabelFont = love.graphics.newFont(10)
-- Load the custom font for tower HP display
local towerFont = love.graphics.newFont("assets/fonts/InknutAntiqua-Regular.ttf", 14)

local COLORS = {
    gridLine = {0, 0, 0, 1},
    -- Spawn zones: row 1 is Player 2's spawn zone; row 9 is Player 1's spawn zone.
    spawnZoneP1 = {0.8, 0.8, 0.8, 0.3},  -- Player 1 (bottom row)
    spawnZoneP2 = {0.8, 0.8, 0.8, 0.3},  -- Player 2 (top row)
    text = {1, 1, 1, 1},
    selectedOutline = {0, 1, 0, 1}  -- used for selected minion highlight (green)
}

--------------------------------------------------
-- Draw an individual minion in its grid cell.
-- Passes in 'currentPlayer' to check if it's that
-- minion's owner's turn before showing green outline.
--------------------------------------------------
local function drawMinion(minion, cellX, cellY, currentPlayer)
    local x = boardX + (cellX - 1) * TILE_SIZE
    local y = boardY + (cellY - 1) * TILE_SIZE

    -- Background color based on owner:
    -- Dark blue for Player 1, red for Player 2.
    if minion.owner.name == "Player 1" then
        love.graphics.setColor(0.173, 0.243, 0.314, 1)  -- Dark blue
    else
        love.graphics.setColor(1, 0, 0, 1)              -- Red
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

    -- If it's this player's turn and the minion can attack, draw a green outline.
    if minion.canAttack and (minion.owner == currentPlayer) then
        love.graphics.setColor(COLORS.selectedOutline)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x, y, TILE_SIZE, TILE_SIZE, 5, 5)
        love.graphics.setLineWidth(1)
    end
end

--------------------------------------------------
-- BoardRenderer.drawBoard
-- Draws the grid-based board, spawn zones, towers,
-- minions, and highlights movement range for a
-- selected minion.
--
-- Params:
--   board          - The Board object
--   player1        - Player 1 object
--   player2        - Player 2 object
--   selectedMinion - The currently selected minion (if any)
--   currentPlayer  - The player whose turn it is
--   gameManager    - The GameManager (for checking towers, etc.)
--------------------------------------------------
function BoardRenderer.drawBoard(board, player1, player2, selectedMinion, currentPlayer, gameManager)
    -- 1) Draw the grid cells, spawn zones, and cell coordinate labels.
    for y = 1, BOARD_ROWS do
        for x = 1, BOARD_COLS do
            local cellX = boardX + (x - 1) * TILE_SIZE
            local cellY = boardY + (y - 1) * TILE_SIZE

            if y == 1 then
                -- Row 1: Player 2's spawn zone.
                love.graphics.setColor(COLORS.spawnZoneP2)
                love.graphics.rectangle("fill", cellX, cellY, TILE_SIZE, TILE_SIZE)
            elseif y == BOARD_ROWS then
                -- Row 9: Player 1's spawn zone.
                love.graphics.setColor(COLORS.spawnZoneP1)
                love.graphics.rectangle("fill", cellX, cellY, TILE_SIZE, TILE_SIZE)
            else
                love.graphics.setColor(1, 1, 1, 0) -- transparent for non-spawn cells
                love.graphics.rectangle("fill", cellX, cellY, TILE_SIZE, TILE_SIZE)
            end

            love.graphics.setColor(COLORS.gridLine)
            love.graphics.rectangle("line", cellX, cellY, TILE_SIZE, TILE_SIZE)
            
            -- Draw small cell label (e.g., A1, B1, etc.)
            local colLetter = string.char(64 + x)  -- 65 is 'A'
            local cellLabel = colLetter .. tostring(y)
            love.graphics.setFont(cellLabelFont)
            love.graphics.setColor(1, 1, 1, 0.5)  -- semi-transparent white
            local labelWidth = cellLabelFont:getWidth(cellLabel)
            love.graphics.print(cellLabel, cellX + TILE_SIZE - labelWidth - 2, cellY + 2)
        end
    end

    -- 2) If we have a selectedMinion that belongs to currentPlayer,
    --    highlight all valid move tiles in blue.
    if selectedMinion
       and selectedMinion.owner == currentPlayer
       and not selectedMinion.summoningSickness
       and not selectedMinion.hasMoved
       and selectedMinion.position
    then
        local sx = selectedMinion.position.x
        local sy = selectedMinion.position.y
        local moveRange = selectedMinion.movement or 1

        for yy = 1, BOARD_ROWS do
            for xx = 1, BOARD_COLS do
                local dist = math.max(math.abs(xx - sx), math.abs(yy - sy))
                if dist <= moveRange then
                    -- Must be empty and not occupied by tower
                    if board:isEmpty(xx, yy) and not gameManager:isTileOccupiedByTower(xx, yy) then
                        local tileX = boardX + (xx - 1) * TILE_SIZE
                        local tileY = boardY + (yy - 1) * TILE_SIZE
                        love.graphics.setColor(0, 0.4, 1, 1) -- medium bright blue
                        love.graphics.setLineWidth(3)
                        love.graphics.rectangle("line", tileX, tileY, TILE_SIZE, TILE_SIZE)
                        love.graphics.setLineWidth(1)
                    end
                end
            end
        end
    end

    -- 3) Draw each minion on the board.
    board:forEachMinion(function(minion, x, y)
        drawMinion(minion, x, y, currentPlayer)
    end)

    -- 4) Draw towers for both players using their images.
    -- Player 1's tower
    if player1.tower then
        local tower = player1.tower
        local towerX = boardX + (tower.position.x - 1) * TILE_SIZE
        local towerY = boardY + (tower.position.y - 1) * TILE_SIZE
        love.graphics.setColor(1, 1, 1, 1)
        -- Scale the image to fit the cell
        local scale = TILE_SIZE / tower.image:getWidth()
        love.graphics.draw(tower.image, towerX, towerY, 0, scale, scale)
        -- Draw tower HP in the center using the custom font.
        love.graphics.setFont(towerFont)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(tostring(tower.hp), towerX, towerY + (TILE_SIZE - towerFont:getHeight())/2, TILE_SIZE, "center")
    end

    -- Player 2's tower
    if player2.tower then
        local tower = player2.tower
        local towerX = boardX + (tower.position.x - 1) * TILE_SIZE
        local towerY = boardY + (tower.position.y - 1) * TILE_SIZE
        love.graphics.setColor(1, 1, 1, 1)
        local scale = TILE_SIZE / tower.image:getWidth()
        love.graphics.draw(tower.image, towerX, towerY, 0, scale, scale)
        love.graphics.setFont(towerFont)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(tostring(tower.hp), towerX, towerY + (TILE_SIZE - towerFont:getHeight())/2, TILE_SIZE, "center")
    end

    -- 5) Highlight the selectedMinion's cell with a thicker green outline (if any).
    if selectedMinion and selectedMinion.position then
        local sx = boardX + (selectedMinion.position.x - 1) * TILE_SIZE
        local sy = boardY + (selectedMinion.position.y - 1) * TILE_SIZE
        love.graphics.setColor(0, 1, 0, 1)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", sx, sy, TILE_SIZE, TILE_SIZE, 5, 5)
        love.graphics.setLineWidth(1)
    end
end

return BoardRenderer
