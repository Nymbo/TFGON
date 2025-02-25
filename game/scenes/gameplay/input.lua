-- game/scenes/gameplay/input.lua
-- Updated to handle multiple towers. If a tile is occupied by *any* tower,
-- we retrieve that tower object from isTileOccupiedByTower().
-- Now also handles targeting for spell effects.

local CardRenderer = require("game.ui.cardrenderer")
local BoardRenderer = require("game.ui.boardrenderer")
local Theme = require("game.ui.theme")
local Animation = require("game.managers.animation")
local EffectManager = require("game.managers.effectmanager") -- Added for target checking

local END_TURN_BUTTON = {
    width = Theme.dimensions.buttonWidth,
    height = Theme.dimensions.buttonHeight
}

local TILE_SIZE = BoardRenderer.getTileSize()

local function isPointInRect(x, y, rx, ry, rw, rh)
    return x >= rx and x <= rx + rw and y >= ry and y <= ry + rh
end

local InputSystem = {}

--------------------------------------------------
-- checkEndTurnHover: used by gameplay scene to highlight "End Turn" button
--------------------------------------------------
function InputSystem.checkEndTurnHover(gameplay)
    local mx, my = love.mouse.getPosition()
    local buttonX = love.graphics.getWidth() - END_TURN_BUTTON.width - 20
    local buttonY = love.graphics.getHeight() / 2 - END_TURN_BUTTON.height / 2
    return isPointInRect(mx, my, buttonX, buttonY, END_TURN_BUTTON.width, END_TURN_BUTTON.height)
end

--------------------------------------------------
-- mousepressed: Main input logic
--------------------------------------------------
function InputSystem.mousepressed(gameplay, x, y, button, istouch, presses)
    local gm = gameplay.gameManager
    local currentPlayer = gm:getCurrentPlayer()

    if button ~= 1 then
        return -- Only handle left-click
    end

    -- End Turn button check
    local buttonX = love.graphics.getWidth() - END_TURN_BUTTON.width - 20
    local buttonY = love.graphics.getHeight() / 2 - END_TURN_BUTTON.height / 2
    if isPointInRect(x, y, buttonX, buttonY, END_TURN_BUTTON.width, END_TURN_BUTTON.height) then
        gm:endTurn()
        gameplay.selectedMinion = nil
        gameplay.pendingSummon = nil
        return
    end

    -- Possibly dragging a card from hand
    local hand = currentPlayer.hand
    local cardWidth, cardHeight = CardRenderer.getCardDimensions()
    local totalWidth = #hand * (cardWidth + 10)
    local startX = (love.graphics.getWidth() - totalWidth) / 2
    local cardY = love.graphics.getHeight() - cardHeight - 20

    for i, card in ipairs(hand) do
        local cardX = startX + (i - 1) * (cardWidth + 10)
        if isPointInRect(x, y, cardX, cardY, cardWidth, cardHeight) then
            if card.cost > currentPlayer.manaCrystals then
                print("Not enough mana to play " .. card.name)
                return
            end
            
            -- Check if this card effect requires targeting
            if card.effectKey and EffectManager.requiresTarget(card.effectKey) then
                -- Set pending effect state for targeting
                gameplay.pendingEffect = card.effectKey
                gameplay.pendingEffectCard = card
                gameplay.pendingEffectCardIndex = i
                -- Remove card from hand to show it's being played
                table.remove(hand, i)
                -- Start tracking valid targets
                gameplay:updateValidTargets()
                return
            elseif card.cardType == "Minion" then
                -- If it's a minion, set pendingSummon
                gameplay.pendingSummon = { card = card, cardIndex = i, player = currentPlayer }
            else
                -- For non-targeting cards (like weapons)
                gm:playCardFromHand(currentPlayer, i)
                return
            end
            
            -- Remove from hand and mark as dragged
            gameplay.draggedCard = card
            gameplay.draggedCardIndex = i
            card.dragging = true
            card.transform = { x = cardX, y = cardY, width = cardWidth, height = cardHeight }
            card.target_transform = { x = cardX, y = cardY }
            card.velocity = { x = 0, y = 0 }
            table.remove(hand, i)
            return
        end
    end

    -- Board click
    local boardX, boardY = BoardRenderer.getBoardPosition()
    local boardWidth = TILE_SIZE * gm.board.cols
    local boardHeight = TILE_SIZE * gm.board.rows

    if isPointInRect(x, y, boardX, boardY, boardWidth, boardHeight) then
        local cellX = math.floor((x - boardX) / TILE_SIZE) + 1
        local cellY = math.floor((y - boardY) / TILE_SIZE) + 1

        -- Check for a tower on this tile
        local towerOnTile = gm:isTileOccupiedByTower(cellX, cellY)

        -- If a card is being dragged
        if gameplay.draggedCard then
            if gameplay.draggedCard.cardType == "Minion" then
                local validSpawnRow = (currentPlayer == gm.player1) and gm.board.rows or 1
                if cellY == validSpawnRow and (towerOnTile == nil) and gm.board:isEmpty(cellX, cellY) then
                    local success = gm:summonMinion(currentPlayer, gameplay.draggedCard, gameplay.draggedCardIndex, cellX, cellY)
                    gameplay.draggedCard = nil
                    gameplay.pendingSummon = nil
                    return
                else
                    print("Invalid spawn position for minion.")
                    return
                end
            else
                -- Non-minion (e.g. Spell/Weapon) drag-drop is not strictly implemented here
                print("Cannot drop this card on the board. Try clicking the card from your hand.")
                return
            end
        end

        -- If we are not dragging a card:
        -- 1) Check if there's a selectedMinion
        if not gameplay.selectedMinion then
            -- Try selecting your own minion
            local clickedMinion = gm.board:getMinionAt(cellX, cellY)
            if clickedMinion and clickedMinion.owner == currentPlayer then
                if clickedMinion.canAttack then
                    gameplay.selectedMinion = clickedMinion
                else
                    print("This minion has already attacked this turn.")
                end
            end
        else
            -- We have a minion selected
            local selected = gameplay.selectedMinion
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

            -- Attack tower?
            if towerOnTile then
                -- Attack the tower
                if selected.canAttack then
                    gameplay:resolveAttack({type = "minion", minion = selected}, {type = "tower", tower = towerOnTile})
                else
                    print("This minion cannot attack right now.")
                end
                gameplay.selectedMinion = nil
                return
            end

            -- Attack or move to a minion tile?
            local clickedMinion = gm.board:getMinionAt(cellX, cellY)
            if not clickedMinion then
                -- Move attempt
                if (not selected.hasMoved) and (distance <= selected.movement) and gm.board:isEmpty(cellX, cellY) then
                    local moved = gm.board:moveMinion(selected.position.x, selected.position.y, cellX, cellY)
                    if moved then
                        selected.hasMoved = true
                    end
                    gameplay.selectedMinion = nil
                    return
                else
                    print("Minion has already moved or target cell is out of range.")
                    gameplay.selectedMinion = nil
                    return
                end
            else
                -- There's a minion here
                if clickedMinion.owner ~= currentPlayer then
                    -- Enemy minion => Attack
                    local reach = 1
                    if selected.archetype == "Magic" then
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
                    -- It's a friendly minion: switch selection
                    if clickedMinion.canAttack then
                        gameplay.selectedMinion = clickedMinion
                    else
                        print("This minion has already attacked this turn.")
                        gameplay.selectedMinion = nil
                    end
                    return
                end
            end
        end
    else
        -- Clicked outside the board
        if gameplay.draggedCard then
            -- Snap the dragged card back to hand
            local card = gameplay.draggedCard
            local cardWidth, cardHeight = CardRenderer.getCardDimensions()
            local hand = currentPlayer.hand
            local totalWidth = (#hand + 1) * (cardWidth + 10)
            local startX = (love.graphics.getWidth() - totalWidth) / 2
            local targetX = startX + (gameplay.draggedCardIndex - 1) * (cardWidth + 10)
            local targetY = love.graphics.getHeight() - cardHeight - 20
            card.transform.x = targetX
            card.transform.y = targetY
            table.insert(hand, gameplay.draggedCardIndex, card)
            gameplay.draggedCard = nil
            gameplay.pendingSummon = nil
        end
        gameplay.selectedMinion = nil
    end
end

return InputSystem