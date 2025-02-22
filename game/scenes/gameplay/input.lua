-- game/scenes/gameplay/input.lua
-- Handles mouse input for the gameplay scene with variable board sizes
-- Now includes mouse coordinate scaling

local CardRenderer = require("game.ui.cardrenderer")
local BoardRenderer = require("game.ui.boardrenderer")
local Theme = require("game.ui.theme")

-- Use dimensions from the theme for the End Turn button
local END_TURN_BUTTON = {
    width = Theme.dimensions.buttonWidth,
    height = Theme.dimensions.buttonHeight
}

-- Get the tile size from BoardRenderer
local TILE_SIZE = BoardRenderer.getTileSize()

local function isPointInRect(x, y, rx, ry, rw, rh)
    return x >= rx and x <= rx + rw and y >= ry and y <= ry + rh
end

-- Helper function to get scaled mouse position (same as in main.lua)
-- This is a duplicate to keep the module self-contained
local function getScaledMousePosition()
    local mx, my = love.mouse.getPosition()
    -- Access the global scale and offset variables from main.lua
    local scale = _G.scale or {x = 1, y = 1}
    local offset = _G.offset or {x = 0, y = 0}
    return mx * scale.x + offset.x, my * scale.y + offset.y
end

local InputSystem = {}

function InputSystem.checkEndTurnHover(gameplay)
    -- Use scaled mouse coordinates
    local mx, my = getScaledMousePosition()
    local buttonX = love.graphics.getWidth() - END_TURN_BUTTON.width - 20
    local buttonY = love.graphics.getHeight() / 2 - END_TURN_BUTTON.height / 2
    return isPointInRect(mx, my, buttonX, buttonY, END_TURN_BUTTON.width, END_TURN_BUTTON.height)
end

function InputSystem.mousepressed(gameplay, x, y, button, istouch, presses)
    if button ~= 1 then
        return -- Only handle left-click
    end

    -- Note: x and y coming in should already be scaled by love.mousepressed in main.lua

    local gm = gameplay.gameManager
    local board = gm.board
    local currentPlayer = gm:getCurrentPlayer()
    local enemy = gm:getEnemyPlayer(currentPlayer)

    -- Get current board position from the renderer
    local boardX, boardY = BoardRenderer.getBoardPosition()
    local boardWidth = TILE_SIZE * board.cols
    local boardHeight = TILE_SIZE * board.rows

    --------------------------------------------------
    -- 1) End Turn button click check
    --------------------------------------------------
    local buttonX = love.graphics.getWidth() - END_TURN_BUTTON.width - 20
    local buttonY = love.graphics.getHeight() / 2 - END_TURN_BUTTON.height / 2
    if isPointInRect(x, y, buttonX, buttonY, END_TURN_BUTTON.width, END_TURN_BUTTON.height) then
        gm:endTurn()
        gameplay.selectedMinion = nil
        gameplay.pendingSummon = nil
        return
    end

    --------------------------------------------------
    -- 2) Check if a card in hand was clicked
    --------------------------------------------------
    local hand = currentPlayer.hand
    local cardWidth, cardHeight = CardRenderer.getCardDimensions()
    local totalWidth = #hand * (cardWidth + 10)
    local startX = (love.graphics.getWidth() - totalWidth) / 2
    local cardY = love.graphics.getHeight() - cardHeight - 20

    for i, card in ipairs(hand) do
        local cardX = startX + (i - 1) * (cardWidth + 10)
        if isPointInRect(x, y, cardX, cardY, cardWidth, cardHeight) then
            if card.cost <= currentPlayer.manaCrystals then
                if card.cardType == "Minion" then
                    -- Set pending summon state
                    gameplay.pendingSummon = { card = card, cardIndex = i, player = currentPlayer }
                    print("Minion card selected. Now click a tile in your spawn zone to summon it.")
                else
                    gm:playCardFromHand(currentPlayer, i)
                end
            end
            gameplay.selectedMinion = nil
            return
        end
    end

    --------------------------------------------------
    -- 3) Board (grid) click handling
    --------------------------------------------------
    if isPointInRect(x, y, boardX, boardY, boardWidth, boardHeight) then
        local cellX = math.floor((x - boardX) / TILE_SIZE) + 1
        local cellY = math.floor((y - boardY) / TILE_SIZE) + 1

        -- Check if clicked cell is the enemy tower's location (for tower attacks)
        if enemy.tower and cellX == enemy.tower.position.x and cellY == enemy.tower.position.y then
            if gameplay.selectedMinion then
                -- If the minion is not allowed to attack, clear selection.
                if not gameplay.selectedMinion.canAttack then
                    print("This minion has already attacked this turn.")
                    gameplay.selectedMinion = nil
                    return
                end
                gameplay:resolveAttack({type = "minion", minion = gameplay.selectedMinion}, {type = "tower", tower = enemy.tower})
                gameplay.selectedMinion = nil
                return
            elseif currentPlayer.weapon then
                gameplay:resolveAttack({type = "hero"}, {type = "tower", tower = enemy.tower})
                return
            else
                print("No attacker selected for tower attack!")
                return
            end
        end

        -- If there's a pending summon, handle summoning first.
        if gameplay.pendingSummon then
            local pending = gameplay.pendingSummon
            local validSpawnRow = (pending.player == gm.player1) and board.rows or 1
            if gm:isTileOccupiedByTower(cellX, cellY) then
                print("Cannot summon minion onto a tower!")
                return
            end
            if cellY == validSpawnRow then
                local success = gm:summonMinion(pending.player, pending.card, pending.cardIndex, cellX, cellY)
                -- Removed duplicate mana cost subtraction here.
                gameplay.pendingSummon = nil
                return
            else
                print("Please select a tile in your spawn zone (Row " .. validSpawnRow .. ").")
                return
            end
        end

        -- Otherwise, handle selection, movement, and attacks.
        local clickedMinion = gm.board:getMinionAt(cellX, cellY)
        
        if not gameplay.selectedMinion then
            -- No minion selected: if the clicked minion belongs to the current player and is allowed to attack, select it.
            if clickedMinion and clickedMinion.owner == currentPlayer then
                if clickedMinion.canAttack then
                    gameplay.selectedMinion = clickedMinion
                else
                    print("This minion has already attacked this turn.")
                end
            end
        else
            local selected = gameplay.selectedMinion

            -- Prevent action if minion was just played or already attacked.
            if selected.summoningSickness then
                print("Minion cannot act on the turn it was played.")
                gameplay.selectedMinion = nil
                return
            end

            if not selected.canAttack then
                print("This minion has already attacked this turn.")
                gameplay.selectedMinion = nil
                return
            end

            local dx = math.abs(cellX - selected.position.x)
            local dy = math.abs(cellY - selected.position.y)
            local distance = math.max(dx, dy)

            if not clickedMinion then
                -- Empty cell: attempt to move (only if the minion hasn't moved yet)
                if gm:isTileOccupiedByTower(cellX, cellY) then
                    print("Cannot move into a tower tile!")
                    gameplay.selectedMinion = nil
                    return
                end

                if (not selected.hasMoved) and (distance <= selected.movement) then
                    local fromX, fromY = selected.position.x, selected.position.y
                    local moved = gm.board:moveMinion(fromX, fromY, cellX, cellY)
                    if moved then
                        selected.hasMoved = true
                    end
                    gameplay.selectedMinion = nil
                    return
                else
                    print("Minion has already moved or target cell is out of movement range.")
                    gameplay.selectedMinion = nil
                    return
                end
            else
                if clickedMinion.owner ~= currentPlayer then
                    -- Enemy minion: check if within attack range (based on archetype)
                    local reach = 1
                    if selected.archetype == "Melee" then
                        reach = 1
                    elseif selected.archetype == "Magic" then
                        reach = 2
                    elseif selected.archetype == "Ranged" then
                        reach = 3
                    end
                    if distance <= reach then
                        gameplay:resolveAttack({type = "minion", minion = selected}, {type = "minion", minion = clickedMinion})
                    else
                        print("Target out of attack range.")
                    end
                    gameplay.selectedMinion = nil
                    return
                else
                    -- Clicked on another friendly minion: select it instead if it can attack.
                    if clickedMinion.canAttack then
                        gameplay.selectedMinion = clickedMinion
                    else
                        print("This minion has already attacked this turn.")
                    end
                    return
                end
            end
            gameplay.selectedMinion = nil
            return
        end
    else
        -- Click outside the board clears any pending summon or selection.
        gameplay.selectedMinion = nil
        gameplay.pendingSummon = nil
    end
end

return InputSystem
