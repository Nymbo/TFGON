-- game/scenes/gameplay/InputHandler.lua
-- Handles all input processing for the gameplay scene
-- Manages card dragging, minion selection, and button interactions
-- Updated to work with camera system

local CardRenderer = require("game.ui.cardrenderer")
local BoardRenderer = require("game.ui.boardrenderer")
local Theme = require("game.ui.theme")
local EventBus = require("game.eventbus")
local flux = require("libs.flux")  -- For animations

local InputHandler = {}
InputHandler.__index = InputHandler

local END_TURN_BUTTON = {
    width = Theme.dimensions.buttonWidth,
    height = Theme.dimensions.buttonHeight
}

local TILE_SIZE = BoardRenderer.getTileSize()

--------------------------------------------------
-- Constructor for InputHandler
--------------------------------------------------
function InputHandler:new(gameplayScene)
    local self = setmetatable({}, InputHandler)
    self.gameplayScene = gameplayScene
    
    -- Properties for drag-and-drop with improved physics
    self.draggedCard = nil
    self.draggedCardIndex = nil
    
    -- Subscribe to events
    self.eventSubscriptions = {}
    self:initEventSubscriptions()
    
    return self
end

--------------------------------------------------
-- initEventSubscriptions: Set up event listeners
--------------------------------------------------
function InputHandler:initEventSubscriptions()
    -- Add event subscriptions for input handling
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.UI_BUTTON_CLICKED,
        function(x, y, button)
            -- Could handle global UI clicks here if needed
        end,
        "InputHandler-ButtonClick"
    ))
    
    -- Add more event subscriptions as needed
end

--------------------------------------------------
-- destroy: Clean up resources
--------------------------------------------------
function InputHandler:destroy()
    -- Clean up event subscriptions
    for _, sub in ipairs(self.eventSubscriptions) do
        EventBus.unsubscribe(sub)
    end
    self.eventSubscriptions = {}
end

--------------------------------------------------
-- isPointInRect: Helper function to check if a point is in a rectangle
--------------------------------------------------
local function isPointInRect(x, y, rx, ry, rw, rh)
    return x >= rx and x <= rx + rw and y >= ry and y <= ry + rh
end

--------------------------------------------------
-- checkEndTurnHover: Check if mouse is over End Turn button
--------------------------------------------------
function InputHandler.checkEndTurnHover(gameplayScene)
    local mx, my = love.mouse.getPosition()
    local buttonX = love.graphics.getWidth() - END_TURN_BUTTON.width - 20
    local buttonY = love.graphics.getHeight() / 2 - END_TURN_BUTTON.height / 2
    return isPointInRect(mx, my, buttonX, buttonY, END_TURN_BUTTON.width, END_TURN_BUTTON.height)
end

--------------------------------------------------
-- updateDraggedCard: Update physics for dragged card
--------------------------------------------------
function InputHandler:updateDraggedCard(dt)
    if not self.draggedCard then return end
    
    local cardWidth, cardHeight = CardRenderer.getCardDimensions()
    local mx, my = love.mouse.getPosition()
    
    -- Calculate target position (where the card should go)
    local targetX = mx - cardWidth / 2
    local targetY = my - cardHeight / 2
    
    -- Set the target transform
    self.draggedCard.target_transform = self.draggedCard.target_transform or {}
    self.draggedCard.target_transform.x = targetX
    self.draggedCard.target_transform.y = targetY
    
    -- Initialize transform if needed
    self.draggedCard.transform = self.draggedCard.transform or {x = targetX, y = targetY}
    self.draggedCard.velocity = self.draggedCard.velocity or {x = 0, y = 0}
    
    -- Calculate distance from current to target
    local distX = targetX - self.draggedCard.transform.x
    local distY = targetY - self.draggedCard.transform.y
    
    -- Calculate new velocity with smoothing
    local elasticity = 8.0  -- Higher values make card more responsive/elastic
    local damping = 0.8    -- Damping factor to prevent oscillation
    
    -- Apply forces to velocity
    self.draggedCard.velocity.x = self.draggedCard.velocity.x * damping + distX * elasticity * dt
    self.draggedCard.velocity.y = self.draggedCard.velocity.y * damping + distY * elasticity * dt
    
    -- Apply velocity to position
    self.draggedCard.transform.x = self.draggedCard.transform.x + self.draggedCard.velocity.x
    self.draggedCard.transform.y = self.draggedCard.transform.y + self.draggedCard.velocity.y
    
    -- Add a slight rotation based on horizontal velocity
    -- This creates a natural "turning" effect when moving the card
    local maxRotation = 0.1  -- Maximum rotation in radians
    self.draggedCard.rotation = -self.draggedCard.velocity.x * 0.01  -- Scale factor to control rotation amount
    
    -- Clamp rotation to prevent excessive spinning
    self.draggedCard.rotation = math.max(-maxRotation, math.min(maxRotation, self.draggedCard.rotation))
    
    -- Publish card movement event so other systems can react
    EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "CardDragged", self.draggedCard, self.draggedCard.transform.x, self.draggedCard.transform.y)
end

--------------------------------------------------
-- drawDraggedCard: Render dragged card with physics effects
--------------------------------------------------
function InputHandler:drawDraggedCard()
    if not self.draggedCard then return end
    
    local cardWidth, cardHeight = CardRenderer.getCardDimensions()
    
    love.graphics.setColor(1, 1, 1, 0.5)
    
    -- Save the current transform state
    love.graphics.push()
    
    -- Move to the card's position
    love.graphics.translate(
        self.draggedCard.transform.x + cardWidth/2,
        self.draggedCard.transform.y + cardHeight/2
    )
    
    -- Apply rotation
    love.graphics.rotate(self.draggedCard.rotation or 0)
    
    -- Draw the card centered at the origin
    CardRenderer.drawCard(
        self.draggedCard, 
        -cardWidth/2,
        -cardHeight/2, 
        true
    )
    
    -- Restore the previous transform state
    love.graphics.pop()
    
    love.graphics.setColor(1, 1, 1, 1)
end

--------------------------------------------------
-- convertScreenToWorldCoords: Convert screen coordinates to world coordinates
--------------------------------------------------
function InputHandler:convertScreenToWorldCoords(x, y)
    if self.gameplayScene.camera then
        return self.gameplayScene.camera:worldCoords(x, y)
    else
        return x, y -- fallback if no camera
    end
end

--------------------------------------------------
-- convertWorldToScreenCoords: Convert world coordinates to screen coordinates
--------------------------------------------------
function InputHandler:convertWorldToScreenCoords(x, y)
    if self.gameplayScene.camera then
        return self.gameplayScene.camera:cameraCoords(x, y)
    else
        return x, y -- fallback if no camera
    end
end

--------------------------------------------------
-- isBoardPointInScreenRect: Check if a board point is within a screen rectangle
--------------------------------------------------
function InputHandler:isBoardPointInScreenRect(worldX, worldY, screenRX, screenRY, rw, rh)
    local screenX, screenY = self:convertWorldToScreenCoords(worldX, worldY)
    return isPointInRect(screenX, screenY, screenRX, screenRY, rw, rh)
end

--------------------------------------------------
-- handleMousePressed: Process mouse input
-- Now accepts world coordinates
--------------------------------------------------
function InputHandler:handleMousePressed(wx, wy, button, istouch, presses)
    local gameplay = self.gameplayScene
    local gm = gameplay.gameManager
    local currentPlayer = gm:getCurrentPlayer()
    
    -- Get the original screen coordinates
    local x, y = love.mouse.getPosition()

    -- End Turn button check (using screen coordinates)
    local buttonX = love.graphics.getWidth() - END_TURN_BUTTON.width - 20
    local buttonY = love.graphics.getHeight() / 2 - END_TURN_BUTTON.height / 2
    if isPointInRect(x, y, buttonX, buttonY, END_TURN_BUTTON.width, END_TURN_BUTTON.height) then
        gameplay:endTurn()
        gameplay.selectedMinion = nil
        gameplay.pendingSummon = nil
        return
    }

    -- Possibly clicking on a card in hand (using screen coordinates)
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
                -- Defer to targeting system
                gameplay.targetingSystem:beginTargeting(card.effectKey, card, i)
                return
                
            elseif card.cardType == "Spell" and card.effectKey and require("game.managers.effectmanager").requiresTarget(card.effectKey) then
                -- Defer to targeting system
                gameplay.targetingSystem:beginTargeting(card.effectKey, card, i)
                return
                
            elseif card.cardType == "Minion" then
                -- If it's a minion, set pendingSummon
                gameplay.pendingSummon = { card = card, cardIndex = i, player = currentPlayer }
                
                -- Remove from hand and mark as dragged for drag-and-drop
                self.draggedCard = card
                self.draggedCardIndex = i
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
    
    -- Board click handling - use the world coordinates (wx, wy) here
    local boardX, boardY = BoardRenderer.getBoardPosition()
    local boardWidth = TILE_SIZE * gm.board.cols
    local boardHeight = TILE_SIZE * gm.board.rows
    
    -- Check if click is on the board by comparing world coordinates
    local isOnBoard = wx >= boardX and wx < boardX + boardWidth and
                     wy >= boardY and wy < boardY + boardHeight
                     
    if isOnBoard then
        self:handleBoardClick(wx, wy, boardX, boardY)
    else
        -- Clicked outside the board
        self:handleOutsideBoardClick()
    end
end

--------------------------------------------------
-- handleBoardClick: Process clicks on the game board
-- Now using world coordinates
--------------------------------------------------
function InputHandler:handleBoardClick(wx, wy, boardX, boardY)
    local gameplay = self.gameplayScene
    local gm = gameplay.gameManager
    local currentPlayer = gm:getCurrentPlayer()
    
    local cellX = math.floor((wx - boardX) / TILE_SIZE) + 1
    local cellY = math.floor((wy - boardY) / TILE_SIZE) + 1

    -- Check for a tower on this tile
    local towerOnTile = gm:isTileOccupiedByTower(cellX, cellY)

    -- If a card is being dragged (for minion placement)
    if self.draggedCard then
        if self.draggedCard.cardType == "Minion" then
            local validSpawnRow = (currentPlayer == gm.player1) and gm.board.rows or 1
            
            if cellY == validSpawnRow and (towerOnTile == nil) and gm.board:isEmpty(cellX, cellY) then
                -- SIMPLIFIED APPROACH: First place the minion, then clear drag state, then animate
                local card = self.draggedCard
                local cardIndex = self.draggedCardIndex
                
                -- First clear the dragged card references - fixes stuck card issue
                local draggedCard = self.draggedCard
                self.draggedCard = nil
                gameplay.pendingSummon = nil
                
                -- Place the minion immediately - game state change is immediate
                local success = gm:summonMinion(currentPlayer, draggedCard, cardIndex, cellX, cellY)
                
                -- Publish event after successful placement
                if success then
                    EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "CardSummoned", cellX, cellY)
                else
                    -- If placement fails, return card to hand
                    table.insert(currentPlayer.hand, cardIndex, draggedCard)
                    EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "CardReturnedToHand", draggedCard)
                end
                
                return
            else
                -- Invalid placement - return the card to the hand
                local card = self.draggedCard
                local cardIndex = self.draggedCardIndex
                
                -- Clear drag state immediately to avoid stuck cards
                self.draggedCard = nil
                gameplay.pendingSummon = nil
                
                -- Return card to hand
                table.insert(currentPlayer.hand, cardIndex, card)
                
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
        self:handleSelectedMinionAction(cellX, cellY, towerOnTile)
    end
end

--------------------------------------------------
-- handleSelectedMinionAction: Process actions with a selected minion
--------------------------------------------------
function InputHandler:handleSelectedMinionAction(cellX, cellY, towerOnTile)
    local gameplay = self.gameplayScene
    local gm = gameplay.gameManager
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
        if clickedMinion.owner ~= gm:getCurrentPlayer() then
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

--------------------------------------------------
-- handleOutsideBoardClick: Process clicks outside the board
--------------------------------------------------
function InputHandler:handleOutsideBoardClick()
    local gameplay = self.gameplayScene
    local currentPlayer = gameplay.gameManager:getCurrentPlayer()
    
    if self.draggedCard then
        -- Immediately return the card to hand with no animation to prevent stuck cards
        local cardIndex = self.draggedCardIndex
        local card = self.draggedCard
        
        -- Clear drag state before inserting to avoid issues
        self.draggedCard = nil
        gameplay.pendingSummon = nil
        
        -- Return card to hand and publish event
        table.insert(currentPlayer.hand, cardIndex, card)
        EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "CardReturnedToHand", card)
    end
    
    if gameplay.selectedMinion then
        -- Deselect minion with event
        EventBus.publish(EventBus.Events.MINION_DESELECTED, gameplay.selectedMinion)
        gameplay.selectedMinion = nil
    end
end

--------------------------------------------------
-- handleMouseReleased: Process mouse button release
--------------------------------------------------
function InputHandler:handleMouseReleased(wx, wy)
    -- Currently no special handling needed for mouse release
    -- Drag and drop is handled via clicks not drag/release
}

--------------------------------------------------
-- cancelDraggedCard: Used to safely cancel dragging
--------------------------------------------------
function InputHandler:cancelDraggedCard()
    if not self.draggedCard then
        return false
    end
    
    local hand = self.gameplayScene.gameManager:getCurrentPlayer().hand
    local cardIndex = self.draggedCardIndex
    local card = self.draggedCard
    
    -- Clear drag state
    self.draggedCard = nil
    self.gameplayScene.pendingSummon = nil
    
    -- Return card to hand
    table.insert(hand, cardIndex, card)
    
    -- Notify system
    EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "CardDragCancelled", card)
    
    return true
end

return InputHandler