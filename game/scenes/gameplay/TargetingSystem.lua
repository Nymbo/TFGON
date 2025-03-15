-- game/scenes/gameplay/TargetingSystem.lua
-- Handles targeting system for spells and weapons
-- Manages target selection, validation, and visual feedback

local BoardRenderer = require("game.ui.boardrenderer")
local Theme = require("game.ui.theme")
local EffectManager = require("game.managers.effectmanager")
local EventBus = require("game.eventbus")

local TargetingSystem = {}
TargetingSystem.__index = TargetingSystem

--------------------------------------------------
-- Constructor for TargetingSystem
--------------------------------------------------
function TargetingSystem:new(gameplayScene)
    local self = setmetatable({}, TargetingSystem)
    self.gameplayScene = gameplayScene
    
    -- Properties for targeting effects and weapons
    self.pendingEffect = nil
    self.pendingEffectCard = nil
    self.pendingEffectCardIndex = nil
    self.validTargets = {}
    
    -- Subscribe to events
    self.eventSubscriptions = {}
    self:initEventSubscriptions()
    
    return self
end

--------------------------------------------------
-- destroy: Clean up resources
--------------------------------------------------
function TargetingSystem:destroy()
    -- Clean up event subscriptions
    for _, sub in ipairs(self.eventSubscriptions) do
        EventBus.unsubscribe(sub)
    end
    self.eventSubscriptions = {}
end

--------------------------------------------------
-- initEventSubscriptions: Set up event listeners
--------------------------------------------------
function TargetingSystem:initEventSubscriptions()
    -- Subscribe to events related to targeting
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.SPELL_TARGET_SELECTED,
        function(targetData, spellCard)
            -- Handle target selection confirmation
        end,
        "TargetingSystem-TargetSelected"
    ))
    
    -- Add more event subscriptions as needed
end

--------------------------------------------------
-- update: Process updates each frame
--------------------------------------------------
function TargetingSystem:update(dt)
    -- Currently no update logic needed for targeting system
end

--------------------------------------------------
-- hasPendingEffect: Check if there is a pending effect
--------------------------------------------------
function TargetingSystem:hasPendingEffect()
    return self.pendingEffect ~= nil
end

--------------------------------------------------
-- beginTargeting: Start the targeting process
-- Modified to work with dragged card visuals
--------------------------------------------------
function TargetingSystem:beginTargeting(effectKey, card, cardIndex)
    local gm = self.gameplayScene.gameManager
    
    -- Set pending effect state for targeting
    self.pendingEffect = effectKey
    self.pendingEffectCard = card
    self.pendingEffectCardIndex = cardIndex
    
    -- NOTE: We no longer remove the card from hand here
    -- The InputHandler has already done this and is now
    -- handling the dragged card visuals
    
    -- Start tracking valid targets
    self:updateValidTargets()
    
    -- Publish targeting started event
    EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "TargetingStarted", card, effectKey)
end

--------------------------------------------------
-- cancelTargeting: Cancel the targeting process
-- Modified to work with dragged card system
--------------------------------------------------
function TargetingSystem:cancelTargeting()
    if not self:hasPendingEffect() then return end
    
    -- The card is already being handled by InputHandler's draggedCard system
    -- So we don't need to reinsert it into the hand

    -- Publish a targeting cancelled event
    EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "TargetingCancelled", self.pendingEffectCard)
    
    -- Clear the pending effect state
    self.pendingEffect = nil
    self.pendingEffectCard = nil
    self.pendingEffectCardIndex = nil
    self.validTargets = {}
    self.isNonTargetingEffect = false
end

--------------------------------------------------
-- updateValidTargets: Update list of valid targets
--------------------------------------------------
function TargetingSystem:updateValidTargets()
    local gm = self.gameplayScene.gameManager
    local currentPlayer = gm:getCurrentPlayer()
    local enemyPlayer = gm:getEnemyPlayer(currentPlayer)
    
    self.validTargets = {}
    
    local targetType = EffectManager.getTargetType(self.pendingEffect)
    
    if targetType == "EnemyTower" then
        -- Add all enemy towers as valid targets
        for _, tower in ipairs(enemyPlayer.towers) do
            table.insert(self.validTargets, { 
                type = "tower", 
                tower = tower,
                position = tower.position 
            })
        end
    elseif targetType == "AnyTower" then
        -- Add all towers as valid targets
        for _, tower in ipairs(currentPlayer.towers) do
            table.insert(self.validTargets, { 
                type = "tower", 
                tower = tower,
                position = tower.position 
            })
        end
        for _, tower in ipairs(enemyPlayer.towers) do
            table.insert(self.validTargets, { 
                type = "tower", 
                tower = tower,
                position = tower.position 
            })
        end
    elseif targetType == "EnemyMinion" then
        -- Find all enemy minions
        gm.board:forEachMinion(function(minion, x, y)
            if minion.owner == enemyPlayer then
                table.insert(self.validTargets, {
                    type = "minion",
                    minion = minion,
                    position = { x = x, y = y }
                })
            end
        end)
    elseif targetType == "AnyMinion" then
        -- Find all minions
        gm.board:forEachMinion(function(minion, x, y)
            table.insert(self.validTargets, {
                type = "minion",
                minion = minion,
                position = { x = x, y = y }
            })
        end)
    elseif targetType == "FriendlyMinion" then
        -- Find minions belonging to the current player
        gm.board:forEachMinion(function(minion, x, y)
            if minion.owner == currentPlayer then
                -- If we're equipping a weapon, check if this minion can use it
                if self.pendingEffectCard and self.pendingEffectCard.cardType == "Weapon" then
                    if EffectManager.validateTarget(self.pendingEffect, minion, self.pendingEffectCard) then
                        table.insert(self.validTargets, {
                            type = "minion",
                            minion = minion,
                            position = { x = x, y = y }
                        })
                    end
                else
                    -- For other effects targeting friendly minions
                    table.insert(self.validTargets, {
                        type = "minion",
                        minion = minion,
                        position = { x = x, y = y }
                    })
                end
            end
        end)
    end
    
    -- ADDED: If this effect doesn't require a target, create a dummy "board" target
    -- This allows non-targeting spells to be played with a board click
    if not EffectManager.requiresTarget(self.pendingEffect) then
        self.isNonTargetingEffect = true
    else 
        self.isNonTargetingEffect = false
    end
end

--------------------------------------------------
-- drawTargetingIndicators: Visual feedback for targeting
--------------------------------------------------
function TargetingSystem:drawTargetingIndicators()
    local boardX, boardY = BoardRenderer.getBoardPosition()
    local TILE_SIZE = BoardRenderer.getTileSize()
    
    -- For non-targeting spells, show a global highlight on the board
    if self.isNonTargetingEffect then
        local gm = self.gameplayScene.gameManager
        local board = gm.board
        local boardWidth = TILE_SIZE * board.cols
        local boardHeight = TILE_SIZE * board.rows
        
        -- Draw a pulsing highlight effect around the whole board
        local pulseAmount = 0.7 + math.sin(love.timer.getTime() * 5) * 0.3
        love.graphics.setColor(0, 0.7, 0.7, pulseAmount * 0.3)  -- Cyan color for non-targeting spells
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", 
            boardX - 10, 
            boardY - 10, 
            boardWidth + 20, 
            boardHeight + 20, 
            10) -- Rounded corners
        love.graphics.setLineWidth(1)
        
        -- Add a text hint
        love.graphics.setFont(Theme.fonts.body)
        love.graphics.setColor(1, 1, 1, pulseAmount)
        love.graphics.printf(
            "Click anywhere on the board to cast",
            boardX, 
            boardY + boardHeight + 10, 
            boardWidth, 
            "center"
        )
        
        return
    end
    
    -- Draw targeting indicator for each valid target
    for _, target in ipairs(self.validTargets) do
        local tx = boardX + (target.position.x - 1) * TILE_SIZE
        local ty = boardY + (target.position.y - 1) * TILE_SIZE
        
        -- Draw a pulsing highlight effect
        local pulseAmount = 0.7 + math.sin(love.timer.getTime() * 5) * 0.3
        
        -- Use different colors based on target type
        local targetColor
        if self.pendingEffectCard and self.pendingEffectCard.cardType == "Weapon" then
            -- Weapons use green targeting
            targetColor = {0, 1, 0.2, pulseAmount}
        else
            -- Spells use orange targeting
            targetColor = {1, 0.5, 0, pulseAmount}
        end
        
        -- Draw targeting circle
        love.graphics.setColor(targetColor)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", tx + TILE_SIZE/2, ty + TILE_SIZE/2, TILE_SIZE/2 + 5)
        
        -- Draw crosshair or symbol based on what we're targeting
        if self.pendingEffectCard and self.pendingEffectCard.cardType == "Weapon" then
            -- For weapons, draw a small sword icon or similar
            -- Here we'll use a simple "+" symbol
            local symbolSize = TILE_SIZE * 0.3
            love.graphics.line(
                tx + TILE_SIZE/2 - symbolSize, ty + TILE_SIZE/2,
                tx + TILE_SIZE/2 + symbolSize, ty + TILE_SIZE/2
            )
            love.graphics.line(
                tx + TILE_SIZE/2, ty + TILE_SIZE/2 - symbolSize,
                tx + TILE_SIZE/2, ty + TILE_SIZE/2 + symbolSize
            )
        else
            -- For spells, draw a targeting reticle
            local crosshairSize = TILE_SIZE * 0.3
            love.graphics.circle("line", tx + TILE_SIZE/2, ty + TILE_SIZE/2, crosshairSize / 2)
            love.graphics.line(
                tx + TILE_SIZE/2 - crosshairSize, ty + TILE_SIZE/2,
                tx + TILE_SIZE/2 + crosshairSize, ty + TILE_SIZE/2
            )
            love.graphics.line(
                tx + TILE_SIZE/2, ty + TILE_SIZE/2 - crosshairSize,
                tx + TILE_SIZE/2, ty + TILE_SIZE/2 + crosshairSize
            )
        end
        
        love.graphics.setLineWidth(1)
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

--------------------------------------------------
-- drawPrompt: Draw targeting instruction prompt
--------------------------------------------------
function TargetingSystem:drawPrompt()
    local promptMessage
    
    if self.isNonTargetingEffect then
        promptMessage = "Click anywhere on the board to cast " .. (self.pendingEffectCard and self.pendingEffectCard.name or "the spell")
    elseif self.pendingEffectCard and self.pendingEffectCard.cardType == "Weapon" then
        promptMessage = "Select a minion to equip " .. (self.pendingEffectCard.name or "the weapon")
    else
        promptMessage = "Select a target for " .. (self.pendingEffectCard and self.pendingEffectCard.name or "the spell")
    end
    
    love.graphics.setFont(Theme.fonts.subtitle)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.printf(promptMessage, 0, 20, love.graphics.getWidth(), "center")
end

--------------------------------------------------
-- selectTarget: Find a target at the given position
--------------------------------------------------
function TargetingSystem:selectTarget(x, y)
    local boardX, boardY = BoardRenderer.getBoardPosition()
    local TILE_SIZE = BoardRenderer.getTileSize()
    
    -- Check if the click is on the board
    local isOnBoard = x >= boardX and x < boardX + (self.gameplayScene.gameManager.board.cols * TILE_SIZE) and
                    y >= boardY and y < boardY + (self.gameplayScene.gameManager.board.rows * TILE_SIZE)
    
    if isOnBoard then
        local cellX = math.floor((x - boardX) / TILE_SIZE) + 1
        local cellY = math.floor((y - boardY) / TILE_SIZE) + 1
        
        -- For non-targeting effects, any board click is valid
        if self.isNonTargetingEffect then
            return {
                type = "board",
                position = { x = cellX, y = cellY }
            }
        end
        
        -- Check if this cell contains a valid target
        for _, target in ipairs(self.validTargets) do
            if target.position.x == cellX and target.position.y == cellY then
                return target.tower or target.minion
            end
        end
    end
    
    return nil
end

--------------------------------------------------
-- handleTargetingClick: Process click during targeting
-- Modified to work with dragged card system
--------------------------------------------------
function TargetingSystem:handleTargetingClick(x, y)
    local target = self:selectTarget(x, y)
    
    -- Store a reference to the InputHandler for draggedCard management
    local inputHandler = self.gameplayScene.inputHandler
    
    if target then
        -- For non-targeting effects that received a board click
        if self.isNonTargetingEffect and target.type == "board" then
            -- Apply the non-targeting effect (target is not used)
            local success = EffectManager.applyEffectKey(
                self.pendingEffect,
                self.gameplayScene.gameManager,
                self.gameplayScene.gameManager:getCurrentPlayer(),
                nil,  -- No target needed
                self.pendingEffectCard
            )
            
            if success then
                -- Spend mana for the card 
                local currentPlayer = self.gameplayScene.gameManager:getCurrentPlayer()
                currentPlayer:spendMana(self.pendingEffectCard.cost)
                
                -- Publish card played event
                EventBus.publish(EventBus.Events.CARD_PLAYED, currentPlayer, self.pendingEffectCard)
                
                -- Clear the dragged card in InputHandler
                if inputHandler and inputHandler.draggedCard then
                    inputHandler.draggedCard = nil
                    inputHandler.draggedCardIndex = nil
                end
            else
                -- If the effect failed to apply, return the card to hand
                -- Let InputHandler handle this
                if inputHandler then
                    inputHandler:cancelDraggedCard()
                end
                
                -- Publish a card rejected event
                EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "CardRejected", self.pendingEffectCard)
            end
            
            -- Clear the pending effect state
            self.pendingEffect = nil
            self.pendingEffectCard = nil
            self.pendingEffectCardIndex = nil
            self.validTargets = {}
            self.isNonTargetingEffect = false
            return
        end
        
        -- Apply the pending effect with the selected target
        local success = EffectManager.applyEffectKey(
            self.pendingEffect,
            self.gameplayScene.gameManager,
            self.gameplayScene.gameManager:getCurrentPlayer(),
            target,
            self.pendingEffectCard  -- Pass the card data for weapons
        )
        
        if success then
            -- Spend mana for the card 
            local currentPlayer = self.gameplayScene.gameManager:getCurrentPlayer()
            currentPlayer:spendMana(self.pendingEffectCard.cost)
            
            -- Publish card played event
            EventBus.publish(EventBus.Events.CARD_PLAYED, currentPlayer, self.pendingEffectCard)
            
            -- Clear the dragged card in InputHandler
            if inputHandler and inputHandler.draggedCard then
                inputHandler.draggedCard = nil
                inputHandler.draggedCardIndex = nil
            end
        else
            -- If the effect failed to apply, return the card to hand
            -- Let InputHandler handle this
            if inputHandler then
                inputHandler:cancelDraggedCard()
            end
            
            -- Publish a card rejected event
            EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "CardRejected", self.pendingEffectCard)
        end
        
        -- Clear the pending effect state
        self.pendingEffect = nil
        self.pendingEffectCard = nil
        self.pendingEffectCardIndex = nil
        self.validTargets = {}
        self.isNonTargetingEffect = false
        return
    end
    
    -- If the player clicked outside valid targets, just cancel
    -- Only cancel if clicked on the board or on the cancel button
    local boardX, boardY = BoardRenderer.getBoardPosition()
    local TILE_SIZE = BoardRenderer.getTileSize()
    local boardWidth = TILE_SIZE * self.gameplayScene.gameManager.board.cols
    local boardHeight = TILE_SIZE * self.gameplayScene.gameManager.board.rows
    
    if (x >= boardX and x < boardX + boardWidth and
        y >= boardY and y < boardY + boardHeight) or
       require("game.scenes.gameplay.InputHandler").checkEndTurnHover(self.gameplayScene) then
        
        -- Let InputHandler handle returning the card to hand
        if inputHandler then
            inputHandler:cancelDraggedCard()
        end
        
        -- Publish a targeting cancelled event
        EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "TargetingCancelled", self.pendingEffectCard)
        
        -- Clear the pending effect state
        self.pendingEffect = nil
        self.pendingEffectCard = nil
        self.pendingEffectCardIndex = nil
        self.validTargets = {}
        self.isNonTargetingEffect = false
    end
end

return TargetingSystem