-- game/scenes/gameplay/input.lua
-- Handles mouse input for the gameplay scene with variable board sizes,
-- including drag-and-drop support for cards from the hand.
-- Now uses the Animation manager for smooth tweening when returning a card to the hand,
-- but if the card is dropped outside the play area, it snaps back instantly.

local CardRenderer = require("game.ui.cardrenderer")
local BoardRenderer = require("game.ui.boardrenderer")
local Theme = require("game.ui.theme")
local Animation = require("game.managers.animation")  -- New animation module

-- Use dimensions from the theme for the End Turn button
local END_TURN_BUTTON = {
    width = Theme.dimensions.buttonWidth,
    height = Theme.dimensions.buttonHeight
}

local TILE_SIZE = BoardRenderer.getTileSize()

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

-- Modified mousepressed to support starting a drag from the hand.
function InputSystem.mousepressed(gameplay, x, y, button, istouch, presses)
    local gm = gameplay.gameManager
    local currentPlayer = gm:getCurrentPlayer()
    
    -- We removed right-click cancellation. Instead, clicking outside the play area (handled in mousereleased)
    if button ~= 1 then
        return -- Only handle left-click for drag initiation
    end

    -- End Turn button check
    local boardX, boardY = BoardRenderer.getBoardPosition()
    local board = gm.board
    local boardWidth = TILE_SIZE * board.cols
    local boardHeight = TILE_SIZE * board.rows
    local buttonX = love.graphics.getWidth() - END_TURN_BUTTON.width - 20
    local buttonY = love.graphics.getHeight() / 2 - END_TURN_BUTTON.height / 2
    if isPointInRect(x, y, buttonX, buttonY, END_TURN_BUTTON.width, END_TURN_BUTTON.height) then
        gm:endTurn()
        gameplay.selectedMinion = nil
        gameplay.pendingSummon = nil
        return
    end

    -- Check if a card in hand was clicked to start dragging
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
            -- For minion cards, also set pendingSummon so the board shows the spawn overlay.
            if card.cardType == "Minion" then
                gameplay.pendingSummon = { card = card, cardIndex = i, player = currentPlayer }
            end
            -- Remove card from hand and mark it as being dragged.
            gameplay.draggedCard = card
            gameplay.draggedCardIndex = i
            card.dragging = true
            -- Initialize card position info.
            card.transform = { x = cardX, y = cardY, width = cardWidth, height = cardHeight }
            card.target_transform = { x = cardX, y = cardY, width = cardWidth, height = cardHeight }
            card.velocity = { x = 0, y = 0 }
            table.remove(hand, i)
            return
        end
    end

    -- Board click handling (for summoning, movement, attack) remains unchanged.
    if isPointInRect(x, y, boardX, boardY, boardWidth, boardHeight) then
        local cellX = math.floor((x - boardX) / TILE_SIZE) + 1
        local cellY = math.floor((y - boardY) / TILE_SIZE) + 1
        local enemy = gm:getEnemyPlayer(currentPlayer)

        -- Tower attack check.
        if enemy.tower and cellX == enemy.tower.position.x and cellY == enemy.tower.position.y then
            if gameplay.selectedMinion then
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

        -- Handle pending summon drop if a card is being dragged.
        if gameplay.draggedCard then
            if gameplay.draggedCard.cardType == "Minion" then
                local validSpawnRow = (currentPlayer == gm.player1) and board.rows or 1
                if cellY == validSpawnRow and not gm:isTileOccupiedByTower(cellX, cellY) and board:isEmpty(cellX, cellY) then
                    local success = gm:summonMinion(currentPlayer, gameplay.draggedCard, gameplay.draggedCardIndex, cellX, cellY)
                    gameplay.draggedCard = nil
                    gameplay.pendingSummon = nil
                    return
                else
                    print("Invalid spawn position for minion.")
                    return
                end
            else
                -- For non-minion cards.
                if board:isEmpty(cellX, cellY) then
                    gm:playCardFromHand(currentPlayer, nil, gameplay.draggedCard)
                    gameplay.draggedCard = nil
                    return
                else
                    print("Invalid drop location for card.")
                    return
                end
            end
        end

        -- If no card is being dragged, handle board interactions for minions.
        local clickedMinion = gm.board:getMinionAt(cellX, cellY)
        if not gameplay.selectedMinion then
            if clickedMinion and clickedMinion.owner == currentPlayer then
                if clickedMinion.canAttack then
                    gameplay.selectedMinion = clickedMinion
                else
                    print("This minion has already attacked this turn.")
                end
            end
        else
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
            if not clickedMinion then
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
                    print("Minion has already moved or target cell is out of range.")
                    gameplay.selectedMinion = nil
                    return
                end
            else
                if clickedMinion.owner ~= currentPlayer then
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
        -- Click outside the board area:
        -- If a card is being dragged, return it to your hand instantly (snap back).
        if gameplay.draggedCard then
            local card = gameplay.draggedCard
            local cardWidth, cardHeight = CardRenderer.getCardDimensions()
            local hand = currentPlayer.hand
            local totalWidth = (#hand + 1) * (cardWidth + 10)
            local startX = (love.graphics.getWidth() - totalWidth) / 2
            local targetX = startX + (gameplay.draggedCardIndex - 1) * (cardWidth + 10)
            local targetY = love.graphics.getHeight() - cardHeight - 20
            -- Snap back instantly.
            card.transform.x = targetX
            card.transform.y = targetY
            table.insert(currentPlayer.hand, gameplay.draggedCardIndex, card)
            gameplay.draggedCard = nil
            gameplay.pendingSummon = nil
        end
        gameplay.selectedMinion = nil
    end
end

return InputSystem
