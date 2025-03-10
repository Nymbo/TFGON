-- game/scenes/gameplay/TargetingSystem.lua
-- Handles targeting system for spells and weapons
-- Manages target selection, validation, and visual feedback
-- Updated to work with camera system

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
--------------------------------------------------
function TargetingSystem:beginTargeting(effectKey, card, cardIndex)
    local gm = self.gameplayScene.gameManager
    
    -- Set pending effect state for targeting
    self.pendingEffect = effectKey
    self.pendingEffectCard = card
    self.pendingEffectCardIndex = cardIndex
    
    -- Remove card from hand to show it's being played
    table.remove(gm:getCurrentPlayer().hand, cardIndex)
    
    -- Start tracking valid targets
    self:updateValidTargets()
    
    -- Publish targeting started event
    EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "TargetingStarted", card, effectKey)
end

--------------------------------------------------
-- cancelTargeting: Cancel the targeting process
--------------------------------------------------
function TargetingSystem:cancelTargeting()
    if not self:hasPendingEffect() then return end
    
    local gm = self.gameplayScene.gameManager
    
    -- Put the card back in hand
    table.insert(
        gm:getCurrentPlayer().hand, 
        self.pendingEffectCardIndex, 
        self.pendingEffectCard
    )
    
    -- Publish a targeting cancelled event
    EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "TargetingCancelled", self.pendingEffectCard)
    
    -- Clear the pending effect state
    self.pendingEffect = nil
    self.pendingEffectCard = nil
    self.pendingEffectCardIndex = nil
    self.validTargets = {}
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
end

--------------------------------------------------
-- drawTargetingIndicators: Visual feedback for targeting
-- Updated to work with camera
--------------------------------------------------
function TargetingSystem:drawTargetingIndicators()
    local boardX, boardY = BoardRenderer.getBoardPosition()
    local TILE_SIZE = BoardRenderer.getTileSize()
    local camera = self.gameplayScene.camera
    
    -- Set drawing to camera space
    if camera then
        camera:attach()
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
    
    -- End camera transformation
    if camera then
        camera:detach()
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

--------------------------------------------------
-- drawPrompt: Draw targeting instruction prompt
--------------------------------------------------
function TargetingSystem:drawPrompt()
    local promptMessage
    if self.pendingEffectCard and self.pendingEffectCard.cardType == "Weapon" then
        promptMessage = "Select a minion to equip " .. (self.pendingEffectCard.name or "the weapon")
    else
        promptMessage = "Select a target for " .. (self.pendingEffectCard and self.pendingEffectCard.name or "the spell")
    end
    
    love.graphics.setFont(Theme.fonts.subtitle)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.printf(promptMessage, 0, 20, love.graphics.getWidth(), "center")
}

--------------------------------------------------
-- selectTarget: Find a target at the given position
-- Updated to work with camera
--------------------------------------------------
function TargetingSystem:selectTarget(x, y)
    local boardX, boardY = BoardRenderer.getBoardPosition()
    local TILE_SIZE = BoardRenderer.getTileSize()
    
    -- Check if the click is in world coordinates
    local isOnBoard = x >= boardX and x < boardX + (self.gameplayScene.gameManager.board.cols * TILE_SIZE) and
                    y >= boardY and y < boardY + (self.gameplayScene.gameManager.board.rows * TILE_SIZE)
    
    if isOnBoard then
        local cellX = math.floor((x - boardX) / TILE_SIZE) + 1
        local cellY = math.floor((y - boardY) / TILE_SIZE) + 1
        
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
-- Updated to work with world coordinates
--------------------------------------------------
function TargetingSystem:handleTargetingClick(wx, wy)
    local target = self:selectTarget(wx, wy)
    if target then
        -- Apply the pending effect with the selected target
        local EffectManager = require("game.managers.effectmanager")
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
        else
            -- If the effect failed to apply, put the card back in hand
            table.insert(
                self.gameplayScene.gameManager:getCurrentPlayer().hand, 
                self.pendingEffectCardIndex, 
                self.pendingEffectCard
            )
            
            -- Publish a card rejected event
            EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "CardRejected", self.pendingEffectCard)
        end
        
        -- Clear the pending effect state
        self.pendingEffect = nil
        self.pendingEffectCard = nil
        self.pendingEffectCardIndex = nil
        self.validTargets = {}
        return
    end
    
    -- If the player clicked outside valid targets, just cancel
    -- Only cancel if clicked on the board or on the cancel button
    local boardX, boardY = BoardRenderer.getBoardPosition()
    local TILE_SIZE = BoardRenderer.getTileSize()
    local boardWidth = TILE_SIZE * self.gameplayScene.gameManager.board.cols
    local boardHeight = TILE_SIZE * self.gameplayScene.gameManager.board.rows
    
    if (wx >= boardX and wx < boardX + boardWidth and
        wy >= boardY and wy < boardY + boardHeight) or
       require("game.scenes.gameplay.InputHandler").checkEndTurnHover(self.gameplayScene) then
        
        -- Put the card back in hand
        table.insert(
            self.gameplayScene.gameManager:getCurrentPlayer().hand, 
            self.pendingEffectCardIndex, 
            self.pendingEffectCard
        )
        
        -- Publish a targeting cancelled event
        EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "TargetingCancelled", self.pendingEffectCard)
        
        -- Clear the pending effect state
        self.pendingEffect = nil
        self.pendingEffectCard = nil
        self.pendingEffectCardIndex = nil
        self.validTargets = {}
    end
end

return TargetingSystem