-- main.lua
-- This is the entry point for the LOVE 2D application.
-- Updated to include EventBus, EventMonitor, and AnimationManager
-- Now with dedicated error logging and flux animation library

--------------------------------------------------
-- First, load the error logging system right away
--------------------------------------------------
local ErrorLog = require("game.utils.errorlog")
ErrorLog.logError("Game starting - " .. os.date())

--------------------------------------------------
-- Require essential modules
--------------------------------------------------
local SceneManager = require("game.managers.scenemanager")
local Debug = require("game.utils.debug")
local EventBus = require("game.eventbus")
local EventMonitor = require("game.tools.eventmonitor")
local flux = require("libs.flux")  -- Add flux for animations

-- Try to load Animation Manager but fail gracefully
local AnimationManager = nil
local success, result = pcall(function()
    return require("game.managers.animationmanager")
end)

if success then
    AnimationManager = result
    ErrorLog.logError("AnimationManager loaded successfully", true)
else
    ErrorLog.logError("Failed to load AnimationManager: " .. tostring(result))
end

-- Global variable for the click sound effect.
local clickSound

--------------------------------------------------
-- love.load():
-- Called once at the start of the program.
--------------------------------------------------
function love.load()
    ErrorLog.logError("love.load() started", true)
    
    -- Use pcall for everything to catch errors
    pcall(function()
        -- Initialize the random number generator with
        -- the current system time for randomness.
        math.randomseed(os.time())
    
        -- Load and set a custom fantasy-style font for all drawing operations.
        local fancyFont = love.graphics.newFont("assets/fonts/InknutAntiqua-Regular.ttf", 14)
        love.graphics.setFont(fancyFont)
        
        -- Load and set the custom cursor with adjusted hotspot coordinates.
        local customCursor = love.mouse.newCursor("assets/images/cursor.png", 30, 18)
        love.mouse.setCursor(customCursor)
        
        -- Load the click sound effect.
        clickSound = love.audio.newSource("assets/sounds/click1.ogg", "static")
        
        -- Initialize Debug system
        Debug.installErrorHandler()
        Debug.info("TFGON Game Starting")
        
        -- Initialize EventBus
        EventBus.setDebugMode(Debug.ENABLED)
        Debug.info("EventBus initialized")
        
        -- Check AnimationManager status
        if AnimationManager then
            Debug.info("Animation Manager ready")
        else
            Debug.error("Animation Manager not available - game will run without animations")
        end
        
        -- Create event loggers for development
        if Debug.ENABLED then
            -- Example: Log certain events to console for debugging
            EventBus.subscribe(EventBus.Events.GAME_INITIALIZED, function(gameManager)
                ErrorLog.logError("Game initialized with board size: " .. 
                          (gameManager and gameManager.board and 
                           gameManager.board.cols .. "x" .. gameManager.board.rows or "unknown"), true)
            end, "GameLogger")
            
            EventBus.subscribe(EventBus.Events.TURN_STARTED, function(player)
                ErrorLog.logError("Turn started: " .. (player and player.name or "unknown"), true)
            end, "TurnLogger")
            
            -- Add animation event logging
            if AnimationManager then
                EventBus.subscribe(EventBus.Events.ANIMATION_STARTED, function(animType, gridX, gridY)
                    ErrorLog.logError(string.format("Animation started: %s at %d,%d", 
                                    animType, gridX or 0, gridY or 0), true)
                end, "AnimationLogger")
            end
            
            -- Add flux animation event logging
            EventBus.subscribe(EventBus.Events.EFFECT_TRIGGERED, function(effectType, ...)
                if effectType:match("Card") then  -- Match card-related events
                    ErrorLog.logError("Card effect: " .. effectType, true)
                end
            end, "CardAnimationLogger")
        end
        
        -- Publish game initialization event
        EventBus.publish(EventBus.Events.GAME_INITIALIZED)
        
        -- Change to the initial "mainmenu" scene.
        SceneManager:changeScene("mainmenu")
    end)
    
    ErrorLog.logError("love.load() completed", true)
end

--------------------------------------------------
-- love.update(dt):
-- Called every frame to handle logic updates.
--------------------------------------------------
function love.update(dt)
    -- Wrap in pcall to catch any errors
    pcall(function()
        -- Update flux animations first
        flux.update(dt)
        
        -- Update the EventBus
        EventBus.update(dt)
        
        -- Update EventMonitor
        EventMonitor.update(dt)
        
        -- Update the SceneManager
        SceneManager:update(dt)
    end)
end

--------------------------------------------------
-- love.draw():
-- Called every frame to handle rendering.
--------------------------------------------------
function love.draw()
    -- Wrap in pcall to catch any rendering errors
    pcall(function()
        -- Draw the active scene
        SceneManager:draw()
        
        -- Draw the event monitor (if enabled)
        EventMonitor.draw()
    end)
end

--------------------------------------------------
-- love.keypressed(key):
-- Passes keyboard inputs to the SceneManager.
--------------------------------------------------
function love.keypressed(key)
    -- Log critical keystrokes
    if key == "escape" then
        ErrorLog.logError("Escape key pressed", true)
    end
    
    -- Wrap in pcall to catch errors
    pcall(function()
        SceneManager:keypressed(key)
    end)
end

--------------------------------------------------
-- love.mousepressed(x, y, button, istouch, presses):
-- Handles mouse button presses.
--------------------------------------------------
function love.mousepressed(x, y, button, istouch, presses)
    -- Wrap in pcall to catch errors
    pcall(function()
        if button == 1 then
            clickSound:stop() -- Stop any current playback
            clickSound:play() -- Play the click sound for left mouse button
            
            -- Publish event for UI click
            EventBus.publish(EventBus.Events.UI_BUTTON_CLICKED, x, y, button)
        end
        
        SceneManager:mousepressed(x, y, button, istouch, presses)
    end)
end

--------------------------------------------------
-- love.mousereleased(x, y, button):
-- Handles mouse button releases.
--------------------------------------------------
function love.mousereleased(x, y, button)
    -- Wrap in pcall to catch errors
    pcall(function()
        if SceneManager.currentScene and SceneManager.currentScene.mousereleased then
            SceneManager.currentScene:mousereleased(x, y, button)
        end
    end)
end

--------------------------------------------------
-- love.wheelmoved(x, y):
-- Handles mouse wheel movement.
--------------------------------------------------
function love.wheelmoved(x, y)
    -- Wrap in pcall to catch errors
    pcall(function()
        -- Try handling wheel event in EventMonitor first
        if not EventMonitor.wheelmoved(x, y) then
            -- If EventMonitor didn't consume it, pass to SceneManager
            SceneManager:wheelmoved(x, y)
        end
    end)
end

--------------------------------------------------
-- love.quit():
-- Called when the game is closed.
--------------------------------------------------
function love.quit()
    ErrorLog.logError("Game is exiting normally", true)
    
    -- Wrap in pcall to catch errors
    pcall(function()
        -- Publish game ended event
        EventBus.publish(EventBus.Events.GAME_ENDED)
        
        -- Print event diagnostics when closing in debug mode
        if Debug.ENABLED then
            EventBus.printDiagnostics()
            Debug.printCallTrace()
        end
        
        Debug.info("TFGON Game Closed")
    end)
    
    return false -- Allow the game to close
end