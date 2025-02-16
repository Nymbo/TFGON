-- game/scenes/gameplay/input.lua
-- Handles mouse input for the gameplay scene with the new grid board.
-- Now supports a pending summon state: when a minion card is clicked,
-- the player must then click a tile in their spawn zone to summon it.
local CardRenderer = require("game.ui.cardrenderer")

local END_TURN_BUTTON = {
    width = 120,
    height = 40
}

-- Grid board constants
local TILE_SIZE = 80
local BOARD_COLS = 7
local BOARD_ROWS = 6
local boardWidth = TILE_SIZE * BOARD_COLS
local boardHeight = TILE_SIZE * BOARD_ROWS
local boardX = (love.graphics.getWidth() - boardWidth) / 2
local boardY = 50  -- top margin

local function isPointInRect(x, y, rx, ry, rw, rh)
    return x >= rx and x <= rx + rw and y >= ry and y <= ry + rh
end

local InputSystem = {}

function InputSystem.checkEndTurnHover(gameplay)
    local mx, my = love.mouse.getPosition()
    local buttonX = love.graphics.getWidth() - END_TURN_BUTTON.width - 20
    local buttonY = love.graphics.getHeight() / 2 - END_TURN_BUTTON.height / 2
    return isPointInRect(mx, my, buttonX, buttonY, END_TURN_BUTTON.width, END_TURN_BUTTON.height)
end

function InputSystem.mousepressed(gameplay, x, y, button, istouch, presses)
    if button ~= 1 then
        return -- Only handle left-click
    end

    local gm = gameplay.gameManager
    local currentPlayer = gm:getCurrentPlayer()

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

        -- If there's a pending summon, handle summoning first.
        if gameplay.pendingSummon then
            local pending = gameplay.pendingSummon
            local validSpawnRow = (pending.player == gm.player1) and BOARD_ROWS or 1
            if cellY == validSpawnRow then
                local success = gm:summonMinion(pending.player, pending.card, pending.cardIndex, cellX, cellY)
                if success then
                    pending.player.manaCrystals = pending.player.manaCrystals - pending.card.cost
                end
                gameplay.pendingSummon = nil
                return
            else
                print("Please select a tile in your spawn zone (Row " .. validSpawnRow .. ").")
                return
            end
        end

        -- Otherwise, handle selection, movement, and attacks as before.
        local clickedMinion = gm.board:getMinionAt(cellX, cellY)
        
        if not gameplay.selectedMinion then
            -- No minion selected: if the clicked minion belongs to the current player, select it.
            if clickedMinion and clickedMinion.owner == currentPlayer then
                gameplay.selectedMinion = clickedMinion
            end
        else
            local selected = gameplay.selectedMinion

            -- If the selected minion was just played (summoning sickness), it cannot act.
            if selected.summoningSickness then
                print("Minion cannot act on the turn it was played.")
                gameplay.selectedMinion = nil
                return
            end

            local dx = math.abs(cellX - selected.position.x)
            local dy = math.abs(cellY - selected.position.y)
            local distance = math.max(dx, dy)

            if not clickedMinion then
                -- Empty cell: attempt to move (only if the minion hasn't moved yet)
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
                    -- Clicked on another friendly minion: select it instead.
                    gameplay.selectedMinion = clickedMinion
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
