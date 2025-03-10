-- game/scenes/gameplay/GameplayScene.lua
-- Core gameplay scene that orchestrates all components
-- Acts as the main entry point for the gameplay scene
-- Now with camera system integration for dynamic view

local GameManager = require("game.managers.gamemanager")
local EventBus = require("game.eventbus")
local ErrorLog = require("game.utils.errorlog")
local flux = require("libs.flux")  -- For animations
local Camera = require("libs.hump.camera")  -- Added camera module

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
    
    -- Initialize camera
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local centerX, centerY = screenWidth / 2, screenHeight / 2
    
    -- Create camera with slight angle and zoom
    self.camera = Camera(centerX, centerY, 1.0) -- Initial position at center
    self.camera:rotate(math.rad(15)) -- 15 degree angle like MTG Arena
    
    -- Camera settings
    self.cameraSettings = {
        targetZoom = 1.0,
        rotationAngle = math.rad(15),
        initialOffset = {x = 0, y = 0}, -- For adjusting camera position
        damping = 0.1, -- For smooth camera movement
        zoomSpeed = 0.1 -- For smooth zoom
    }
    
    -- Set camera smoother for more natural movements
    self.camera.smoother = Camera.smooth.damped(5)
    
    -- Initialize components
    self.stateManager = StateManager:new(self)
    self.targetingSystem = TargetingSystem:new(self)
    self.animationController = AnimationController:new(self)
    self.eventHandlers = EventHandlers:new(self)
    self.gameOverManager = GameOverManager:new(self)
    self.inputHandler = InputHandler:new(self)

    -- Setup callback for game over
    self.gameManager.onGameOver = function(winner)
        ErrorLog.logError("Game over triggered. Winner: " .. (winner and winner.name or "none"), true)
        self.showGameOverPopup = true
        self.gameOverWinner = winner
        self.gameOverManager:handleGameOver(winner)
    end
    
    -- Legacy callback to maintain compatibility
    self.gameManager.onTurnStart = function(whichPlayer)
        -- This is kept for backward compatibility but no longer sets banner properties
        -- Banner display is now managed through events
    end

    -- Start the first turn to initialize the game
    ErrorLog.logError("Starting first turn", true)
    success, err = pcall(function()
        self.gameManager:startTurn()
    end)
    
    if not success then
        ErrorLog.logError("ERROR starting first turn: " .. tostring(err))
    end
    
    -- Subscribe to events that might affect camera
    self:setupCameraEvents()
    
    ErrorLog.logError("Gameplay scene initialization complete", true)
    return self
end

--------------------------------------------------
-- setupCameraEvents: Set up event subscriptions for camera effects
--------------------------------------------------
function GameplayScene:setupCameraEvents()
    table.insert(self.eventHandlers.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.MINION_ATTACKED,
        function(attacker, target)
            -- Add camera shake effect on attacks
            self:shakeCamera(0.5) -- Mild shake
        end,
        "CameraShakeOnAttack"
    ))
    
    table.insert(self.eventHandlers.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.TOWER_DAMAGED,
        function(tower, attacker, damage)
            -- More intense shake when towers are damaged
            self:shakeCamera(1.0) -- Stronger shake
        end,
        "CameraShakeOnTowerDamage"
    ))
    
    table.insert(self.eventHandlers.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.CARD_PLAYED,
        function(player, card)
            -- Subtle camera movement when a card is played
            if card.cardType == "Spell" then
                self:shakeCamera(0.7) -- Medium shake for spells
            end
        end,
        "CameraEffectOnCardPlay"
    ))
end

--------------------------------------------------
-- shakeCamera: Add a shake effect to the camera
--------------------------------------------------
function GameplayScene:shakeCamera(intensity)
    local shake = intensity or 0.5
    local screenW, screenH = love.graphics.getDimensions()
    
    -- Cancel any existing shake animations
    if self.shakeAnimation then
        flux.cancel(self.shakeAnimation)
    end
    
    -- Current camera position
    local currentX, currentY = self.camera:position()
    
    -- Apply random offset based on intensity
    local offsetX = (math.random() - 0.5) * shake * 10
    local offsetY = (math.random() - 0.5) * shake * 10
    
    -- Move camera to create shake
    self.camera:lookAt(currentX + offsetX, currentY + offsetY)
    
    -- Animate back to original position
    self.shakeAnimation = flux.to(self, 0.3, { 
        dummy = 1  -- Dummy property for the animation
    }):onupdate(function()
        -- Gradually move back to center during the animation
        local factor = 1 - self.shakeAnimation._t -- Remaining animation time (0 to 1)
        local dampenedX = currentX + offsetX * factor
        local dampenedY = currentY + offsetY * factor
        self.camera:lookAt(dampenedX, dampenedY)
    end)
end

--------------------------------------------------
-- updateCamera: Handle camera updates
--------------------------------------------------
function GameplayScene:updateCamera(dt)
    -- Example of camera movement based on mouse position if desired
    -- local mx, my = love.mouse.getPosition()
    -- local windowW, windowH = love.graphics.getDimensions()
    -- local edgeThreshold = 100 -- pixels from edge to start moving
    
    -- -- Move camera if mouse is near the edge
    -- if mx < edgeThreshold then
    --     self.camera:move(-2, 0) -- Move left
    -- elseif mx > windowW - edgeThreshold then
    --     self.camera:move(2, 0) -- Move right
    -- end
    
    -- if my < edgeThreshold then
    --     self.camera:move(0, -2) -- Move up
    -- elseif my > windowH - edgeThreshold then
    --     self.camera:move(0, 2) -- Move down
    -- end
    
    -- Optional: smooth zoom animation
    if self.camera.scale ~= self.cameraSettings.targetZoom then
        local zoomDiff = self.cameraSettings.targetZoom - self.camera.scale
        self.camera.scale = self.camera.scale + zoomDiff * self.cameraSettings.zoomSpeed
    end
end

--------------------------------------------------
-- update: Main update function called every frame
--------------------------------------------------
function GameplayScene:update(dt)
    -- Update flux animations
    flux.update(dt)
    
    pcall(function()
        -- Update camera
        self:updateCamera(dt)
    
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
                        EventBus.publish(EventBus.Events.AI_TURN_STARTED, self.gameManager.player2)
                    end
                end
            end
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
    
        -- Game over popup and other UI elements are drawn outside the camera
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
    
    -- Convert screen coordinates to world coordinates for camera
    local wx, wy = self.camera:worldCoords(x, y)
    
    -- Let targeting system handle clicks if there is a pending effect
    if self.targetingSystem:hasPendingEffect() then
        self.targetingSystem:handleTargetingClick(wx, wy)
        return
    end
    
    -- Otherwise, delegate to input handler with world coordinates
    self.inputHandler:handleMousePressed(wx, wy, button, istouch, presses)
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
    elseif key == "=" or key == "+" then
        -- Zoom in
        self.cameraSettings.targetZoom = self.cameraSettings.targetZoom * 1.1
        if self.cameraSettings.targetZoom > 1.5 then
            self.cameraSettings.targetZoom = 1.5 -- Max zoom
        end
    elseif key == "-" or key == "_" then
        -- Zoom out
        self.cameraSettings.targetZoom = self.cameraSettings.targetZoom / 1.1
        if self.cameraSettings.targetZoom < 0.7 then
            self.cameraSettings.targetZoom = 0.7 -- Min zoom
        end
    elseif key == "r" then
        -- Reset camera
        local screenWidth, screenHeight = love.graphics.getDimensions()
        self.camera:lookAt(screenWidth / 2, screenHeight / 2)
        self.cameraSettings.targetZoom = 1.0
        self.camera.scale = 1.0
        self.camera:rotateTo(self.cameraSettings.rotationAngle)
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
    -- Convert to world coordinates for camera
    local wx, wy = self.camera:worldCoords(x, y)
    
    -- Delegate to input handler
    if button == 1 then
        self.inputHandler:handleMouseReleased(wx, wy)
    end
end

--------------------------------------------------
-- wheelmoved: Handle mouse wheel for zooming
--------------------------------------------------
function GameplayScene:wheelmoved(x, y)
    -- Use mouse wheel for camera zoom
    if y > 0 then
        -- Zoom in
        self.cameraSettings.targetZoom = self.cameraSettings.targetZoom * 1.05
        if self.cameraSettings.targetZoom > 1.5 then
            self.cameraSettings.targetZoom = 1.5 -- Max zoom
        end
    elseif y < 0 then
        -- Zoom out
        self.cameraSettings.targetZoom = self.cameraSettings.targetZoom / 1.05
        if self.cameraSettings.targetZoom < 0.7 then
            self.cameraSettings.targetZoom = 0.7 -- Min zoom
        end
    end
end

--------------------------------------------------
-- destroy: Clean up resources when scene is unloaded
--------------------------------------------------
function GameplayScene:destroy()
    ErrorLog.logError("Destroying gameplay scene", true)
    
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