-- game/scenes/gameplay/AnimationController.lua
-- Manages animations during gameplay
-- Handles animation queuing, sequencing, and feedback

local EventBus = require("game.eventbus")
local ErrorLog = require("game.utils.errorlog")
local Theme = require("game.ui.theme")

-- Try to load AnimationManager safely
local AnimationManager = nil
local success, result = pcall(function()
    return require("game.managers.animationmanager")
end)

if success then
    AnimationManager = result
    ErrorLog.logError("AnimationManager loaded in AnimationController", true)
else
    ErrorLog.logError("Failed to load AnimationManager in AnimationController: " .. tostring(result))
end

local AnimationController = {}
AnimationController.__index = AnimationController

--------------------------------------------------
-- Constructor for AnimationController
--------------------------------------------------
function AnimationController:new(gameplayScene)
    local self = setmetatable({}, AnimationController)
    self.gameplayScene = gameplayScene
    
    -- Animation queue
    self.animationQueue = {}
    
    -- Subscribe to events
    self.eventSubscriptions = {}
    self:initEventSubscriptions()
    
    return self
end

--------------------------------------------------
-- destroy: Clean up resources
--------------------------------------------------
function AnimationController:destroy()
    -- Clean up event subscriptions
    for _, sub in ipairs(self.eventSubscriptions) do
        EventBus.unsubscribe(sub)
    end
    self.eventSubscriptions = {}
end

--------------------------------------------------
-- initEventSubscriptions: Set up event listeners
--------------------------------------------------
function AnimationController:initEventSubscriptions()
    -- Subscribe to events related to animations
    if AnimationManager then
        table.insert(self.eventSubscriptions, EventBus.subscribe(
            EventBus.Events.ANIMATION_STARTED,
            function(animType, gridX, gridY)
                -- Set waiting flag when animation starts
                self.gameplayScene.waitingForAnimation = true
                ErrorLog.logError("Animation started: " .. animType, true)
            end,
            "AnimationController-AnimationStart"
        ))
        
        table.insert(self.eventSubscriptions, EventBus.subscribe(
            EventBus.Events.ANIMATION_COMPLETED,
            function(animType, gridX, gridY)
                -- Clear waiting flag when animation completes
                self.gameplayScene.waitingForAnimation = false
                ErrorLog.logError("Animation completed: " .. animType, true)
            end,
            "AnimationController-AnimationComplete"
        ))
    end
    
    -- Subscribe to events that trigger animations
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.CARD_PLAYED,
        function(player, card)
            -- Add to animation queue 
            self:queueAnimation("cardPlayed", {card = card, player = player})
        end,
        "AnimationController-CardPlayed"
    ))
    
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.MINION_DAMAGED,
        function(minion, source, damage, oldHealth, newHealth)
            -- Add to animation queue
            self:queueAnimation("damage", {
                target = minion, 
                amount = damage,
                position = {x = minion.position.x, y = minion.position.y}
            })
        end,
        "AnimationController-Damage"
    ))
    
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.MINION_HEALED,
        function(minion, source, amount, oldHealth, newHealth)
            -- Add to animation queue
            self:queueAnimation("heal", {
                target = minion, 
                amount = amount,
                position = {x = minion.position.x, y = minion.position.y}
            })
        end,
        "AnimationController-Heal"
    ))
    
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.MINION_DIED,
        function(minion, killer)
            -- Add to animation queue
            self:queueAnimation("death", {
                minion = minion,
                position = {x = minion.position.x, y = minion.position.y}
            })
        end,
        "AnimationController-Death"
    ))
    
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.TOWER_DAMAGED,
        function(tower, attacker, damage, oldHealth, newHealth)
            -- Add to animation queue
            self:queueAnimation("towerDamage", {
                tower = tower,
                amount = damage,
                position = {x = tower.position.x, y = tower.position.y}
            })
        end,
        "AnimationController-TowerDamage"
    ))
    
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.MINION_MOVED,
        function(minion, oldPosition, newPosition)
            -- Add to animation queue
            self:queueAnimation("movement", {
                minion = minion,
                from = oldPosition,
                to = newPosition
            })
        end,
        "AnimationController-Movement"
    ))
end

--------------------------------------------------
-- update: Process animations
--------------------------------------------------
function AnimationController:update(dt)
    -- Process the animation queue if needed
    self:processAnimationQueue()
end

--------------------------------------------------
-- processAnimationQueue: Execute queued animations
--------------------------------------------------
function AnimationController:processAnimationQueue()
    -- If we're already animating, don't start a new one
    if self.gameplayScene.waitingForAnimation or 
       (AnimationManager and AnimationManager:hasActiveAnimations()) then
        return
    end
    
    -- Process the next animation in the queue
    if #self.animationQueue > 0 then
        local nextAnimation = table.remove(self.animationQueue, 1)
        self:playAnimation(nextAnimation.type, nextAnimation.data)
    end
end

--------------------------------------------------
-- queueAnimation: Add an animation to the queue
--------------------------------------------------
function AnimationController:queueAnimation(animType, data)
    -- Add animation to the queue
    table.insert(self.animationQueue, {
        type = animType,
        data = data
    })
    
    -- Process the queue immediately
    self:processAnimationQueue()
end

--------------------------------------------------
-- drawAnimatingIndicator: Show animation in progress indicator
--------------------------------------------------
function AnimationController:drawAnimatingIndicator()
    -- Add a visual "Animating..." indication
    love.graphics.setColor(1, 1, 0, 0.7)
    love.graphics.setFont(Theme.fonts.body)
    love.graphics.print("Animating...", 20, 20)
    love.graphics.setColor(1, 1, 1, 1)
end

--------------------------------------------------
-- playAnimation: Execute a specific animation
--------------------------------------------------
function AnimationController:playAnimation(animType, data)
    -- This function safely delegates to the AnimationManager
    -- Additional animation types will be added as needed
    if not AnimationManager then
        return
    end
    
    if animType == "cardPlayed" and data.card.cardType == "Spell" and data.card.name == "Fireball" then
        -- Fireball animations are handled by event subscriptions in AnimationManager
    elseif animType == "damage" or animType == "heal" or animType == "death" or 
           animType == "movement" or animType == "towerDamage" then
        -- These will be implemented as AnimationManager capabilities expand
    end
    
    -- If we have no specific animation, just mark as not waiting
    self.gameplayScene.waitingForAnimation = false
end

return AnimationController