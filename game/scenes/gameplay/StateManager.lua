-- game/scenes/gameplay/StateManager.lua
-- Manages gameplay state 
-- Handles AI turns, animation states, and game flow

local EventBus = require("game.eventbus")
local ErrorLog = require("game.utils.errorlog")

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
        
        -- Add a specific handler for AI turn end to ensure the game state is updated
        table.insert(self.eventSubscriptions, EventBus.subscribe(
            EventBus.Events.AI_TURN_ENDED,
            function(player)
                self.gameplayScene.aiTurnInProgress = false
                ErrorLog.logError("AI turn marked as completed", true)
            end,
            "StateManager-AITurnEndHandler"
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
    
    -- Add a safety timer to force end AI turns that get stuck
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.AI_ACTION_PERFORMED,
        function(actionType, player)
            -- Reset the safety timer whenever an AI action is performed
            self.aiActionPerformed = true
        end,
        "StateManager-AIActionMonitor"
    ))
end

--------------------------------------------------
-- update: Process state updates each frame
--------------------------------------------------
function StateManager:update(dt)
    -- Check for dragged card updates in InputHandler
    if self.gameplayScene.inputHandler and self.gameplayScene.inputHandler.draggedCard then
        self.gameplayScene.inputHandler:updateDraggedCard(dt)
    end
    
    -- AI turn safety timer - force end the turn if it gets stuck
    if self.gameplayScene.aiOpponent and 
       self.gameplayScene.gameManager.currentPlayer == 2 and
       self.gameplayScene.aiTurnInProgress then
        
        -- Initialize the safety timer if not already set
        if not self.aiSafetyTimer then
            self.aiSafetyTimer = 0
            self.aiActionPerformed = false
        end
        
        -- Increment the timer
        self.aiSafetyTimer = self.aiSafetyTimer + dt
        
        -- If 5 seconds have passed and no AI action was performed, force end the turn
        if self.aiSafetyTimer > 5 and not self.aiActionPerformed then
            ErrorLog.logError("AI turn stuck - forcing turn end", true)
            self.gameplayScene.aiTurnInProgress = false
            EventBus.publish(EventBus.Events.AI_TURN_ENDED, self.gameplayScene.gameManager.player2)
            self.aiSafetyTimer = nil
        end
        
        -- If 10 seconds have passed, force end the turn regardless
        if self.aiSafetyTimer > 10 then
            ErrorLog.logError("AI turn timeout - forcing turn end", true)
            self.gameplayScene.aiTurnInProgress = false
            EventBus.publish(EventBus.Events.AI_TURN_ENDED, self.gameplayScene.gameManager.player2)
            self.aiSafetyTimer = nil
        end
    else
        -- Reset safety timer when it's not AI's turn
        self.aiSafetyTimer = nil
    end
end

--------------------------------------------------
-- handleAITurn: Process AI turn
--------------------------------------------------
function StateManager:handleAITurn(player)
    if not self.gameplayScene.aiManager then
        -- If no AI manager, just end the turn
        self.gameplayScene.aiTurnInProgress = false
        EventBus.publish(EventBus.Events.AI_TURN_ENDED, player)
        return
    end
    
    -- Reset the AI safety timer when a new turn starts
    self.aiSafetyTimer = 0
    self.aiActionPerformed = false
    
    -- Let the AI manager handle the turn via EventBus
    -- The AI manager will publish AI_TURN_ENDED when finished
    ErrorLog.logError("AI turn handling started", true)
end

--------------------------------------------------
-- handleTurnStarted: Process turn started event
--------------------------------------------------
function StateManager:handleTurnStarted(player)
    -- Reset state for the new turn
    self.gameplayScene.selectedMinion = nil
    
    -- Ensure AI turn state is properly reset when player's turn starts
    if player == self.gameplayScene.gameManager.player1 then
        self.gameplayScene.aiTurnInProgress = false
    end
    
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
    if self.gameplayScene.inputHandler and self.gameplayScene.inputHandler.draggedCard then
        self.gameplayScene.inputHandler:cancelDraggedCard()
    end
    
    if self.gameplayScene.targetingSystem and self.gameplayScene.targetingSystem:hasPendingEffect() then
        self.gameplayScene.targetingSystem:cancelTargeting()
    end
    
    -- Reset selection
    self.gameplayScene.selectedMinion = nil
    
    -- Clear AI turn state if the AI's turn is ending
    if player == self.gameplayScene.gameManager.player2 then
        self.gameplayScene.aiTurnInProgress = false
    end
end

return StateManager