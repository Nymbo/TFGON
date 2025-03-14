-- game/scenes/gameplay/EventHandlers.lua
-- Centralizes all event subscriptions for the gameplay scene
-- Makes event handling more organized and maintainable
-- Added debugging for Glancing Blows effect
-- UPDATED: Removed banner system references and redundant code

local EventBus = require("game.eventbus")
local ErrorLog = require("game.utils.errorlog")
local DrawSystem = require("game.scenes.gameplay.draw")

local EventHandlers = {}
EventHandlers.__index = EventHandlers

--------------------------------------------------
-- Constructor for EventHandlers
--------------------------------------------------
function EventHandlers:new(gameplayScene)
    local self = setmetatable({}, EventHandlers)
    self.gameplayScene = gameplayScene
    
    -- Store event subscriptions
    self.eventSubscriptions = {}
    
    -- Initialize event subscriptions
    self:initEventSubscriptions()
    
    return self
end

--------------------------------------------------
-- destroy: Clean up resources
--------------------------------------------------
function EventHandlers:destroy()
    -- Clean up event subscriptions
    for _, sub in ipairs(self.eventSubscriptions) do
        EventBus.unsubscribe(sub)
    end
    self.eventSubscriptions = {}
end

--------------------------------------------------
-- initEventSubscriptions: Set up all event listeners
--------------------------------------------------
function EventHandlers:initEventSubscriptions()
    -- If AI opponent is enabled, subscribe to turn events
    if self.gameplayScene.aiOpponent then
        -- Listen for turn started events to trigger AI turn
        table.insert(self.eventSubscriptions, EventBus.subscribe(
            EventBus.Events.TURN_STARTED,
            function(player)
                if player == self.gameplayScene.gameManager.player2 then
                    -- Add a small delay before triggering AI turn
                    self.gameplayScene.aiTurnTimer = 0.5
                end
            end,
            "EventHandlers-TurnHandler"
        ))
    end
    
    -- Subscribe to card events
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.CARD_DRAWN,
        function(player, card)
            if player == self.gameplayScene.gameManager:getCurrentPlayer() then
                -- Get the index of the card in the hand
                local index = 0
                for i, handCard in ipairs(player.hand) do
                    if handCard == card then
                        index = i
                        break
                    end
                end
                
                -- Trigger the card drawing animation
                if index > 0 then
                    DrawSystem.onCardDrawn(card, index, player.hand)
                end
            end
        end,
        "EventHandlers-CardDrawnHandler"
    ))

    -- Subscribe to card played events to trigger animations
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.CARD_PLAYED,
        function(player, card)
            if player == self.gameplayScene.gameManager:getCurrentPlayer() then
                -- Trigger the card playing animation
                DrawSystem.onCardPlayed(card)
                
                -- Tell the DrawSystem that the hand has changed
                DrawSystem.onHandChanged()
            end
        end,
        "EventHandlers-CardPlayedHandler"
    ))

    -- Subscribe to hand changed events (like when cards are added or removed)
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.CARD_ADDED_TO_HAND,
        function(player, card)
            if player == self.gameplayScene.gameManager:getCurrentPlayer() then
                DrawSystem.onHandChanged()
            end
        end,
        "EventHandlers-CardAddedHandler"
    ))

    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.CARD_DISCARDED,
        function(player, card)
            if player == self.gameplayScene.gameManager:getCurrentPlayer() then
                DrawSystem.onHandChanged()
            end
        end,
        "EventHandlers-CardDiscardedHandler"
    ))

    -- Subscribe to card being returned to hand
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.EFFECT_TRIGGERED,
        function(effectType, card)
            if effectType == "CardReturnedToHand" and card then
                DrawSystem.onHandChanged()
            end
        end,
        "EventHandlers-CardReturnedHandler"
    ))

    -- Subscribe to turn started events to reset the card visuals
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.TURN_STARTED,
        function(player)
            -- Reset card animations when turn changes
            DrawSystem.onHandChanged()
        end,
        "EventHandlers-TurnStartCardHandler"
    ))
    
    -- Subscribe to effect events
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.EFFECT_TRIGGERED,
        function(effectType, player, target)
            -- Track specific effect events
            if effectType == "SpellCastFailed" or effectType == "WeaponEquipFailed" then
                -- Show failure feedback
                ErrorLog.logError("Effect failed: " .. effectType, true)
            end
        end,
        "EventHandlers-EffectHandler"
    ))
    
    -- Add subscription for card drag effects
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.EFFECT_TRIGGERED,
        function(effectType, card, x, y)
            if effectType == "CardDragged" and card then
                -- Apply card dragging effects here if needed
                -- For example, you might want to trigger sounds or visual effects
            end
        end,
        "EventHandlers-CardDragHandler"
    ))
    
    -- Add special debugging for Glancing Blows effect
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.EFFECT_TRIGGERED,
        function(effectType, attacker, target)
            if effectType == "GlancingBlows" and attacker then
                -- Log when Glancing Blows triggers
                ErrorLog.logError("GLANCING BLOWS: " .. attacker.name .. " avoided counter-damage!", true)
                
                -- Log debug info about the minion
                local debugInfo = "Minion Properties: "
                if attacker.glancingBlows then
                    debugInfo = debugInfo .. "glancingBlows=true, "
                else
                    debugInfo = debugInfo .. "glancingBlows=false, "
                end
                
                debugInfo = debugInfo .. "name=" .. attacker.name .. 
                            ", attack=" .. attacker.attack .. 
                            ", health=" .. attacker.currentHealth .. "/" .. attacker.maxHealth
                            
                ErrorLog.logError(debugInfo, true)
            end
        end,
        "EventHandlers-GlancingBlowsDebug"
    ))
    
    -- Debug logging for minion summoning
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.MINION_SUMMONED,
        function(player, minion, x, y)
            if minion.glancingBlows then
                ErrorLog.logError("SUMMONED MINION WITH GLANCING BLOWS: " .. 
                                minion.name .. " at position " .. x .. "," .. y, true)
            end
        end,
        "EventHandlers-MinionSummonDebug"
    ))
end

return EventHandlers