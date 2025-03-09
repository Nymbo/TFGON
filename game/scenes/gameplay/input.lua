-- game/scenes/gameplay/input.lua
-- Updated to handle multiple towers. If a tile is occupied by *any* tower,
-- we retrieve that tower object from isTileOccupiedByTower().
-- Now also handles targeting for spell effects and minion weapons!
-- Enhanced with physics-based card handling

local CardRenderer = require("game.ui.cardrenderer")
local BoardRenderer = require("game.ui.boardrenderer")
local Theme = require("game.ui.theme")
local EffectManager = require("game.managers.effectmanager") -- Added for target checking
local EventBus = require("game.eventbus")
local flux = require("libs.flux")  -- Add flux for smooth animations

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
        gameplay:endTurn()
        gameplay.selectedMinion = nil
        gameplay.pendingSummon = nil
        return
    end

    -- Possibly clicking on a card in hand
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
                
                -- Trigger feedback animation
                flux.to({x = cardX, y = cardY}, 0.1, {x = cardX - 5, y = cardY})
                    :after({x = cardX - 5, y = cardY}, 0.1, {x = cardX + 5, y = cardY})
                    :after({x = cardX + 5, y = cardY}, 0.1, {x = cardX, y = cardY})
                
                -- Publish not enough mana event
                EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "NotEnoughMana", card)
                return
            end
            
            -- Handle card play based on type
            if card.cardType == "Weapon" then
                -- Set pending effect state for targeting a minion with the weapon
                gameplay.pendingEffect = card.effectKey
                gameplay.pendingEffectCard = card
                gameplay.pendingEffectCardIndex = i
                -- Remove card from hand to show it's being played
                table.remove(hand, i)
                -- Start tracking valid targets
                gameplay:updateValidTargets()
                return
                
            elseif card.cardType == "Spell" and card.effectKey and EffectManager.requiresTarget(card.effectKey) then
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
                
                -- Remove from hand and mark as dragged for drag-and-drop
                gameplay.draggedCard = card
                gameplay.draggedCardIndex = i
                card.dragging = true
                
                -- Set up card transform properties with physics
                card.transform = { 
                    x = cardX, 
                    y = cardY, 
                    width = cardWidth, 
                    height = cardHeight 
                }
                card.target_transform = { x = cardX, y = cardY }
                card.velocity = { x = 0, y = 0 }
                card.rotation = 0  -- Add rotation property
                
                -- Play a card pickup sound effect
                -- This is using the existing click sound for now, but could be custom
                EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "CardPickedUp", card)
                
                -- Apply a "pop up" animation when card is selected
                flux.to(card.transform, 0.2, { 
                    y = cardY - 20  -- Lift the card slightly
                }):ease("backout")  -- Use a bounce effect
                
                table.remove(hand, i)
                return
                
            else
                -- For non-targeting cards
                local success = gm:playCardFromHand(currentPlayer, i)
                
                if success then
                    -- Play card effect animation
                    flux.to({scale = 1}, 0.3, {scale = 1.2})
                        :after({scale = 1.2}, 0.1, {scale = 0})
                        :oncomplete(function()
                            -- This would be where we'd show the card effect visually
                        end)
                end
                return
            end
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

        -- If a card is being dragged (for minion placement)
        if gameplay.draggedCard then
            if gameplay.draggedCard.cardType == "Minion" then
                local validSpawnRow = (currentPlayer == gm.player1) and gm.board.rows or 1
                
                if cellY == validSpawnRow and (towerOnTile == nil) and gm.board:isEmpty(cellX, cellY) then
                    -- SIMPLIFIED APPROACH: First place the minion, then clear drag state, then animate
                    local card = gameplay.draggedCard
                    local cardIndex = gameplay.draggedCardIndex
                    
                    -- First clear the dragged card references - fixes stuck card issue
                    local draggedCard = gameplay.draggedCard
                    gameplay.draggedCard = nil
                    gameplay.pendingSummon = nil
                    
                    -- Place the minion immediately - game state change is immediate
                    local success = gm:summonMinion(currentPlayer, draggedCard, cardIndex, cellX, cellY)
                    
                    -- Publish event after successful placement
                    if success then
                        EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "CardSummoned", cellX, cellY)
                    else
                        -- If placement fails, return card to hand
                        table.insert(hand, cardIndex, draggedCard)
                        EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "CardReturnedToHand", draggedCard)
                    end
                    
                    return
                else
                    -- Invalid placement - return the card to the hand
                    local card = gameplay.draggedCard
                    local cardIndex = gameplay.draggedCardIndex
                    
                    -- Clear drag state immediately to avoid stuck cards
                    gameplay.draggedCard = nil
                    gameplay.pendingSummon = nil
                    
                    -- Return card to hand
                    table.insert(hand, cardIndex, card)
                    
                    -- Visual feedback for invalid placement
                    EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "InvalidPlacement", cellX, cellY)
                    
                    print("Invalid spawn position for minion.")
                    return
                end
            else
                -- Non-minion drag-drop is not implemented
                print("Cannot drop this card on the board. Try clicking the card from your hand.")
                return
            end
        end

        -- If no card is being dragged, check for minion selection/movement/attack
        if not gameplay.selectedMinion then
            -- Try selecting your own minion
            local clickedMinion = gm.board:getMinionAt(cellX, cellY)
            if clickedMinion and clickedMinion.owner == currentPlayer then
                if clickedMinion.canAttack then
                    gameplay.selectedMinion = clickedMinion
                    
                    -- Publish minion selected event
                    EventBus.publish(EventBus.Events.MINION_SELECTED, clickedMinion)
                    
                    -- Apply selection animation
                    -- This could be a pulsing highlight or other visual effect
                    flux.to({scale = 1}, 0.2, {scale = 1.2})
                       :after({scale = 1.2}, 0.2, {scale = 1})
                else
                    print("This minion has already attacked this turn.")
                    
                    -- Show visual feedback
                    flux.to({x = clickedMinion.position.x, y = clickedMinion.position.y}, 0.1, 
                           {x = clickedMinion.position.x - 0.1, y = clickedMinion.position.y})
                       :after({x = clickedMinion.position.x - 0.1, y = clickedMinion.position.y}, 0.1, 
                             {x = clickedMinion.position.x + 0.1, y = clickedMinion.position.y})
                       :after({x = clickedMinion.position.x + 0.1, y = clickedMinion.position.y}, 0.1, 
                             {x = clickedMinion.position.x, y = clickedMinion.position.y})
                end
            end
        else
            -- We have a minion selected
            local selected = gameplay.selectedMinion
            if selected.summoningSickness then
                print("Minion cannot act on the turn it was played.")
                
                -- Show visual feedback with flux
                flux.to({alpha = 1}, 0.2, {alpha = 0.5})
                   :after({alpha = 0.5}, 0.2, {alpha = 1})
                   
                gameplay.selectedMinion = nil
                
                -- Publish minion deselected event
                EventBus.publish(EventBus.Events.MINION_DESELECTED, selected)
                return
            end
            if not selected.canAttack then
                print("This minion has already attacked this turn.")
                gameplay.selectedMinion = nil
                
                -- Publish minion deselected event
                EventBus.publish(EventBus.Events.MINION_DESELECTED, selected)
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
                
                -- Publish minion deselected event
                EventBus.publish(EventBus.Events.MINION_DESELECTED, selected)
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
                        
                        -- Publish minion moved event with more details
                        local oldPos = {x = selected.position.x, y = selected.position.y}
                        local newPos = {x = cellX, y = cellY}
                        EventBus.publish(EventBus.Events.MINION_MOVED, selected, oldPos, newPos)
                    end
                    gameplay.selectedMinion = nil
                    
                    -- Publish minion deselected event
                    EventBus.publish(EventBus.Events.MINION_DESELECTED, selected)
                    return
                else
                    print("Minion has already moved or target cell is out of range.")
                    
                    -- Visual feedback for invalid move
                    flux.to({x = 0}, 0.1, {x = 5})
                       :after({x = 5}, 0.1, {x = -5})
                       :after({x = -5}, 0.1, {x = 0})
                    
                    gameplay.selectedMinion = nil
                    
                    -- Publish minion deselected event
                    EventBus.publish(EventBus.Events.MINION_DESELECTED, selected)
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
                        
                        -- Visual feedback for out of range
                        flux.to({alpha = 1}, 0.2, {alpha = 0.5})
                           :after({alpha = 0.5}, 0.2, {alpha = 1})
                    end
                    gameplay.selectedMinion = nil
                    
                    -- Publish minion deselected event
                    EventBus.publish(EventBus.Events.MINION_DESELECTED, selected)
                    return
                else
                    -- It's a friendly minion: switch selection
                    if clickedMinion.canAttack then
                        -- Deselect previous minion
                        EventBus.publish(EventBus.Events.MINION_DESELECTED, selected)
                        
                        gameplay.selectedMinion = clickedMinion
                        
                        -- Select new minion
                        EventBus.publish(EventBus.Events.MINION_SELECTED, clickedMinion)
                    else
                        print("This minion has already attacked this turn.")
                        gameplay.selectedMinion = nil
                        
                        -- Publish minion deselected event
                        EventBus.publish(EventBus.Events.MINION_DESELECTED, selected)
                    end
                    return
                end
            end
        end
    else
        -- Clicked outside the board
        if gameplay.draggedCard then
            -- Immediately return the card to hand with no animation to prevent stuck cards
            local cardIndex = gameplay.draggedCardIndex
            local card = gameplay.draggedCard
            
            -- Clear drag state before inserting to avoid issues
            gameplay.draggedCard = nil
            gameplay.pendingSummon = nil
            
            -- Return card to hand and publish event
            table.insert(hand, cardIndex, card)
            EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "CardReturnedToHand", card)
        end
        
        if gameplay.selectedMinion then
            -- Deselect minion with event
            EventBus.publish(EventBus.Events.MINION_DESELECTED, gameplay.selectedMinion)
            gameplay.selectedMinion = nil
        end
    end
end

--------------------------------------------------
-- cancel dragged card: Used to safely cancel dragging
--------------------------------------------------
function InputSystem.cancelDraggedCard(gameplay)
    if not gameplay.draggedCard then
        return false
    end
    
    local hand = gameplay.gameManager:getCurrentPlayer().hand
    local cardIndex = gameplay.draggedCardIndex
    local card = gameplay.draggedCard
    
    -- Clear drag state
    gameplay.draggedCard = nil
    gameplay.pendingSummon = nil
    
    -- Return card to hand
    table.insert(hand, cardIndex, card)
    
    -- Notify system
    EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "CardDragCancelled", card)
    
    return true
end

return InputSystem