-- game/scenes/gameplay/StateManager.lua
-- Manages gameplay state 
-- Handles AI turns, animation states, and game flow

local EventBus = require("game.eventbus")

local StateManager = {}
StateManager.__index = StateManager

--------------------------------------------------
-- Constructor for StateManager
--------------------------------------------------
function StateManager:new(gameplayScene)
    local self = setmetatable({}, StateManager)
    self.gameplayScene = gameplayScene
    
    -- Subscribe to events
    self.eventSubscriptions = {}
    self:initEventSubscriptions()
    
    return self
end

--------------------------------------------------
-- destroy: Clean up resources
--------------------------------------------------
function StateManager:destroy()
    -- Clean up event subscriptions
    for _, sub in ipairs(self.eventSubscriptions) do
        EventBus.unsubscribe(sub)
    end
    self.eventSubscriptions = {}
end

--------------------------------------------------
-- initEventSubscriptions: Set up event listeners
--------------------------------------------------
function StateManager:initEventSubscriptions()
    -- Subscribe to AI turn events if AI is enabled
    if self.gameplayScene.aiOpponent then
        table.insert(self.eventSubscriptions, EventBus.subscribe(
            EventBus.Events.AI_TURN_STARTED,
            function(player)
                self:handleAITurn(player)
            end,
            "StateManager-AITurnHandler"
        ))
    end
    
    -- Subscribe to game state change events
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.TURN_STARTED,
        function(player)
            self:handleTurnStarted(player)
        end,
        "StateManager-TurnStartedHandler"
    ))
    
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.TURN_ENDED,
        function(player)
            self:handleTurnEnded(player)
        end,
        "StateManager-TurnEndedHandler"
    ))
end

--------------------------------------------------
-- update: Process state updates each frame
--------------------------------------------------
function StateManager:update(dt)
    -- Check for dragged card updates in InputHandler
    if self.gameplayScene.inputHandler.draggedCard then
        self.gameplayScene.inputHandler:updateDraggedCard(dt)
    end
end

--------------------------------------------------
-- handleAITurn: Process AI turn
--------------------------------------------------
function StateManager:handleAITurn(player)
    if not self.gameplayScene.aiManager then
        -- If no AI manager, just end the turn
        self.gameplayScene:endTurn()
        return
    end
    
    -- Let the AI manager handle the turn via EventBus
    -- The AI manager will publish AI_TURN_ENDED when finished
end

--------------------------------------------------
-- handleTurnStarted: Process turn started event
--------------------------------------------------
function StateManager:handleTurnStarted(player)
    -- Reset state for the new turn
    self.gameplayScene.selectedMinion = nil
    
    -- Publish banner event
    local isPlayerTurn = (player == self.gameplayScene.gameManager.player1)
    local bannerType = isPlayerTurn and "player" or "opponent"
    local bannerText = isPlayerTurn and "YOUR TURN" or 
                     (self.gameplayScene.aiOpponent and "AI OPPONENT'S TURN" or "OPPONENT'S TURN")
    
    EventBus.publish(EventBus.Events.BANNER_DISPLAYED, bannerType, bannerText)
end

--------------------------------------------------
-- handleTurnEnded: Process turn ended event
--------------------------------------------------
function StateManager:handleTurnEnded(player)
    -- Cleanup any lingering state
    if self.gameplayScene.inputHandler.draggedCard then
        self.gameplayScene.inputHandler:cancelDraggedCard()
    end
    
    if self.gameplayScene.targetingSystem:hasPendingEffect() then
        self.gameplayScene.targetingSystem:cancelTargeting()
    end
    
    -- Reset selection
    self.gameplayScene.selectedMinion = nil
end

return StateManager