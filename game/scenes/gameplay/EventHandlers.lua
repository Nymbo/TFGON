-- game/scenes/gameplay/EventHandlers.lua
-- Centralizes all event subscriptions for the gameplay scene
-- Makes event handling more organized and maintainable

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
    -- Subscribe to turn events
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.TURN_STARTED,
        function(player)
            local bannerType = (player == self.gameplayScene.gameManager.player1) and "player" or "opponent"
            local text = (player == self.gameplayScene.gameManager.player1) and "YOUR TURN" or 
                       (self.gameplayScene.aiOpponent and "AI OPPONENT'S TURN" or "OPPONENT'S TURN")
            
            -- Simply publish the event - the banner display is handled elsewhere now
            EventBus.publish(EventBus.Events.BANNER_DISPLAYED, bannerType, text)
        end,
        "EventHandlers-BannerHandler"
    ))
    
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
end

return EventHandlers