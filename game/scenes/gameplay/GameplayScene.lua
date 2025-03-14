-- game/scenes/gameplay/GameplayScene.lua
-- Core gameplay scene that orchestrates all components
-- Acts as the main entry point for the gameplay scene
-- UPDATED: Removed legacy callbacks and banner system references

local GameManager = require("game.managers.gamemanager")
local EventBus = require("game.eventbus")
local ErrorLog = require("game.utils.errorlog")
local flux = require("libs.flux")  -- For animations

-- Load component modules
local DrawSystem = require("game.scenes.gameplay.draw")
local InputHandler = require("game.scenes.gameplay.InputHandler")
local TargetingSystem = require("game.scenes.gameplay.TargetingSystem")
local AnimationController = require("game.scenes.gameplay.AnimationController")
local EventHandlers = require("game.scenes.gameplay.EventHandlers")
local GameOverManager = require("game.scenes.gameplay.GameOverManager")
local StateManager = require("game.scenes.gameplay.StateManager")

-- Try to load AnimationManager safely
local AnimationManager = nil
local success, result = pcall(function()
    return require("game.managers.animationmanager")
end)

if success then
    AnimationManager = result
    ErrorLog.logError("AnimationManager loaded in gameplay scene", true)
else
    ErrorLog.logError("Failed to load AnimationManager in GameplayScene: " .. tostring(result))
end

local GameplayScene = {}
GameplayScene.__index = GameplayScene

--------------------------------------------------
-- Constructor for GameplayScene
--------------------------------------------------
function GameplayScene:new(changeSceneCallback, selectedDeck, selectedBoard, aiOpponent)
    local self = setmetatable({}, GameplayScene)
    
    ErrorLog.logError("Initializing gameplay scene", true)
    
    self.selectedDeck = selectedDeck
    self.selectedBoard = selectedBoard
    self.aiOpponent = aiOpponent or false
    self.changeSceneCallback = changeSceneCallback

    -- Validate crucial parameters
    if not selectedDeck or not selectedDeck.cards then
        ErrorLog.logError("ERROR: Invalid deck parameter in gameplay initialization")
        error("Invalid deck parameter")
    end
    
    if not selectedBoard then
        ErrorLog.logError("ERROR: Invalid board parameter in gameplay initialization")
        error("Invalid board parameter")
    end
    
    ErrorLog.logError("Creating GameManager with deck: " .. 
                   selectedDeck.name .. ", board: " .. 
                   selectedBoard.name .. ", AI: " .. tostring(self.aiOpponent), true)
    
    -- Initialize game manager with error handling
    local success, result = pcall(function()
        return GameManager:new(selectedDeck, selectedBoard, self.aiOpponent)
    end)
    
    if not success then
        ErrorLog.logError("ERROR creating GameManager: " .. tostring(result))
        error("Failed to create game manager: " .. tostring(result))
    end
    
    self.gameManager = result
    
    -- Initialize AI if needed
    if self.aiOpponent then
        ErrorLog.logError("Initializing AI Manager", true)
        
        success, result = pcall(function()
            local AIManager = require("game.managers.aimanager")
            local aiManager = AIManager:new(self.gameManager)
            
            -- Set AI difficulty if available
            if love.filesystem.getInfo("difficulty.txt") then
                local content = love.filesystem.read("difficulty.txt")
                local difficultyIndex = tonumber(content)
                if difficultyIndex then
                    local difficultyMap = { [1] = "easy", [2] = "normal", [3] = "hard" }
                    local difficulty = difficultyMap[difficultyIndex] or "normal"
                    aiManager:setDifficulty(difficulty)
                end
            end
            
            return aiManager
        end)
        
        if not success then
            ErrorLog.logError("WARNING: Failed to initialize AI Manager: " .. tostring(result))
            -- Continue without AI - this isn't fatal
            self.aiOpponent = false
        else
            self.aiManager = result
        end
    end

    -- Safely load background image
    ErrorLog.logError("Loading game background", true)
    
    if selectedBoard and selectedBoard.imagePath and love.filesystem.getInfo(selectedBoard.imagePath) then
        ErrorLog.logError("Using board-specific background: " .. selectedBoard.imagePath, true)
        self.background = love.graphics.newImage(selectedBoard.imagePath)
    else
        -- Use default background
        local defaultBgPath = "assets/images/background.png"
        if love.filesystem.getInfo(defaultBgPath) then
            ErrorLog.logError("Using default background", true)
            self.background = love.graphics.newImage(defaultBgPath)
        else
            ErrorLog.logError("WARNING: Default background not found, creating placeholder")
            -- Create a placeholder background if image is missing
            self.background = love.graphics.newCanvas(800, 600)
            love.graphics.setCanvas(self.background)
            love.graphics.clear(0.1, 0.1, 0.1, 1)
            love.graphics.setCanvas()
        end
    end

    -- Initialize gameplay state
    self.selectedMinion = nil
    self.endTurnHovered = false
    self.showGameOverPopup = false
    self.gameOverWinner = nil
    self.waitingForAnimation = false
    self.aiTurnInProgress = false  -- Track when an AI turn is being processed
    
    -- Initialize components
    self.stateManager = StateManager:new(self)
    self.targetingSystem = TargetingSystem:new(self)
    self.animationController = AnimationController:new(self)
    self.eventHandlers = EventHandlers:new(self)
    self.gameOverManager = GameOverManager:new(self)
    self.inputHandler = InputHandler:new(self)

    -- Setup event subscriptions for game over and other events
    self:initEventSubscriptions()

    -- Start the first turn to initialize the game
    ErrorLog.logError("Starting first game turn", true)
    success, err = pcall(function()
        self.gameManager:startTurn()
    end)
    
    if not success then
        ErrorLog.logError("ERROR starting first turn: " .. tostring(err))
    end
    
    ErrorLog.logError("Gameplay scene initialization complete", true)
    return self
end

--------------------------------------------------
-- initEventSubscriptions: Set up event listeners
--------------------------------------------------
function GameplayScene:initEventSubscriptions()
    self.eventSubscriptions = {}
    
    -- Subscribe to game ended event to handle game over
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.GAME_ENDED,
        function(winner)
            self.showGameOverPopup = true
            self.gameOverWinner = winner
        end,
        "GameplayScene-GameOverHandler"
    ))
    
    -- Subscribe to turn started events for any scene-level handling needed
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.TURN_STARTED,
        function(player)
            -- Any scene-level turn handling goes here (if needed in the future)
        end,
        "GameplayScene-TurnStartHandler"
    ))
end

--------------------------------------------------
-- update: Main update function called every frame
--------------------------------------------------
function GameplayScene:update(dt)
    -- Update flux animations
    flux.update(dt)
    
    pcall(function()
        self.gameManager:update(dt)
        self.endTurnHovered = InputHandler.checkEndTurnHover(self)
        
        -- Update animations if available
        if AnimationManager then
            AnimationManager:update(dt)
        end
    
        -- Update components
        self.stateManager:update(dt)
        self.targetingSystem:update(dt)
        self.animationController:update(dt)
        
        -- Handle AI turns with traditional timer (will migrate to events fully later)
        if self.aiOpponent and self.gameManager.currentPlayer == 2 and not self.showGameOverPopup then
            -- Only proceed with AI turn if no animations are playing
            if not self.waitingForAnimation and not (AnimationManager and AnimationManager:hasActiveAnimations()) then
                if self.aiTurnTimer and self.aiTurnTimer > 0 then
                    self.aiTurnTimer = self.aiTurnTimer - dt
                    if self.aiTurnTimer <= 0 then
                        -- Trigger the AI turn via an event
                        -- Only trigger if we're still on the AI's turn
                        if self.gameManager.currentPlayer == 2 then
                            -- Add safety check to prevent multiple AI turn triggers
                            if not self.aiTurnInProgress then
                                self.aiTurnInProgress = true
                                EventBus.publish(EventBus.Events.AI_TURN_STARTED, self.gameManager.player2)
                            end
                        end
                    end
                end
            end
        end
        
        -- Reset AI turn state when turn changes
        if self.gameManager.currentPlayer == 1 then
            self.aiTurnInProgress = false
        end
    end)
    
    -- Process EventBus events
    EventBus.update(dt)
end

--------------------------------------------------
-- draw: Main render function called every frame
--------------------------------------------------
function GameplayScene:draw()
    -- Use pcall to safely call draw methods
    pcall(function()
        DrawSystem.drawGameplayScene(self)
    
        -- Draw dragged card if there is one
        self.inputHandler:drawDraggedCard()
    
        -- Draw targeting indicators if there's a pending effect
        if self.targetingSystem:hasPendingEffect() then
            self.targetingSystem:drawTargetingIndicators()
        end
    
        if self.showGameOverPopup then
            self.gameOverManager:drawGameOverPopup()
        end
        
        -- If we have a pending effect, show a text prompt
        if self.targetingSystem:hasPendingEffect() then
            self.targetingSystem:drawPrompt()
        end
        
        -- If waiting for animation, show a visual indicator
        if self.waitingForAnimation or (AnimationManager and AnimationManager:hasActiveAnimations()) then
            self.animationController:drawAnimatingIndicator()
        end
    end)
end

--------------------------------------------------
-- mousepressed: Handle mouse input
--------------------------------------------------
function GameplayScene:mousepressed(x, y, button, istouch, presses)
    if button ~= 1 then return end

    if self.showGameOverPopup then
        self.gameOverManager:handlePopupClick(x, y)
        return
    end

    if self.aiOpponent and self.gameManager.currentPlayer == 2 then
        return
    end
    
    -- If animations are playing, don't allow interaction
    if self.waitingForAnimation or (AnimationManager and AnimationManager:hasActiveAnimations()) then
        return
    end
    
    -- Let targeting system handle clicks if there is a pending effect
    if self.targetingSystem:hasPendingEffect() then
        self.targetingSystem:handleTargetingClick(x, y)
        return
    end
    
    -- Otherwise, delegate to input handler
    self.inputHandler:handleMousePressed(x, y, button, istouch, presses)
end

--------------------------------------------------
-- endTurn: End the current player's turn
--------------------------------------------------
function GameplayScene:endTurn()
    -- Don't allow ending turn if animations are playing
    if self.waitingForAnimation or (AnimationManager and AnimationManager:hasActiveAnimations()) then
        return
    end
    
    -- Publish turn ending event
    EventBus.publish(EventBus.Events.TURN_ENDED, self.gameManager:getCurrentPlayer())
    
    -- Call game manager to end turn
    self.gameManager:endTurn()
end

--------------------------------------------------
-- keypressed: Handle keyboard input
--------------------------------------------------
function GameplayScene:keypressed(key)
    if key == "escape" then
        -- If there's a pending effect, cancel it
        if self.targetingSystem:hasPendingEffect() then
            self.targetingSystem:cancelTargeting()
            return
        end
        
        self.changeSceneCallback("mainmenu")
    end
end

--------------------------------------------------
-- resolveAttack: Handle attack resolution
--------------------------------------------------
function GameplayScene:resolveAttack(attacker, target)
    -- Don't allow attacks if animations are playing
    if self.waitingForAnimation or (AnimationManager and AnimationManager:hasActiveAnimations()) then
        return
    end
    
    local CombatSystem = require("game.scenes.gameplay.combat")
    CombatSystem.resolveAttack(self, attacker, target)
end

--------------------------------------------------
-- mousereleased: Handle mouse button release
--------------------------------------------------
function GameplayScene:mousereleased(x, y, button)
    -- Delegate to input handler
    if button == 1 then
        self.inputHandler:handleMouseReleased(x, y)
    end
end

--------------------------------------------------
-- destroy: Clean up resources when scene is unloaded
--------------------------------------------------
function GameplayScene:destroy()
    ErrorLog.logError("Destroying gameplay scene", true)
    
    -- Clean up event subscriptions
    for _, sub in ipairs(self.eventSubscriptions) do
        EventBus.unsubscribe(sub)
    end
    
    -- Clean up components
    if self.stateManager.destroy then self.stateManager:destroy() end
    if self.targetingSystem.destroy then self.targetingSystem:destroy() end
    if self.animationController.destroy then self.animationController:destroy() end
    if self.eventHandlers.destroy then self.eventHandlers:destroy() end
    if self.gameOverManager.destroy then self.gameOverManager:destroy() end
    if self.inputHandler.destroy then self.inputHandler:destroy() end
    
    -- Clean up AI manager if it exists
    if self.aiManager then
        if self.aiManager.destroy then
            self.aiManager:destroy()
        end
    end
    
    -- Publish scene exit event
    EventBus.publish(EventBus.Events.SCENE_EXITED, "gameplay")
end

return GameplayScene