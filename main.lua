-- main.lua
-- This is the entry point for the LOVE 2D application.
-- Updated to include EventBus and EventMonitor

--------------------------------------------------
-- Require essential modules
--------------------------------------------------
local SceneManager = require("game.managers.scenemanager")
local Debug = require("game.utils.debug")
local EventBus = require("game.eventbus")
local EventMonitor = require("game.tools.eventmonitor")

-- Global variable for the click sound effect.
local clickSound

--------------------------------------------------
-- love.load():
-- Called once at the start of the program.
--------------------------------------------------
function love.load()
    -- Initialize the random number generator with
    -- the current system time for randomness.
    math.randomseed(os.time())

    -- Load and set a custom fantasy-style font for all drawing operations.
    -- This file must exist at: assets/fonts/InknutAntiqua-Regular.ttf
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
    
    -- Create event loggers for development
    if Debug.ENABLED then
        -- Example: Log certain events to console for debugging
        EventBus.subscribe(EventBus.Events.GAME_INITIALIZED, function(gameManager)
            Debug.info("Game initialized with board size: " .. 
                      gameManager.board.cols .. "x" .. gameManager.board.rows)
        end, "GameLogger")
        
        EventBus.subscribe(EventBus.Events.TURN_STARTED, function(player)
            Debug.info("Turn started: " .. player.name)
        end, "TurnLogger")
    end
    
    -- Publish game initialization event
    EventBus.publish(EventBus.Events.GAME_INITIALIZED)
    
    -- Change to the initial "mainmenu" scene.
    SceneManager:changeScene("mainmenu")
end

--------------------------------------------------
-- love.update(dt):
-- Called every frame to handle logic updates.
--------------------------------------------------
function love.update(dt)
    -- Update the EventBus first
    EventBus.update(dt)
    
    -- Update EventMonitor
    EventMonitor.update(dt)
    
    -- Update the SceneManager
    SceneManager:update(dt)
end

--------------------------------------------------
-- love.draw():
-- Called every frame to handle rendering.
--------------------------------------------------
function love.draw()
    -- Draw the active scene
    SceneManager:draw()
    
    -- Draw the event monitor (if enabled)
    EventMonitor.draw()
end

--------------------------------------------------
-- love.keypressed(key):
-- Passes keyboard inputs to the SceneManager.
--------------------------------------------------
function love.keypressed(key)
    SceneManager:keypressed(key)
end

--------------------------------------------------
-- love.mousepressed(x, y, button, istouch, presses):
-- Handles mouse button presses.
--------------------------------------------------
function love.mousepressed(x, y, button, istouch, presses)
    if button == 1 then
        clickSound:stop() -- Stop any current playback
        clickSound:play() -- Play the click sound for left mouse button
        
        -- Publish event for UI click
        EventBus.publish(EventBus.Events.UI_BUTTON_CLICKED, x, y, button)
    end
    
    SceneManager:mousepressed(x, y, button, istouch, presses)
end

--------------------------------------------------
-- love.mousereleased(x, y, button):
-- Handles mouse button releases.
--------------------------------------------------
function love.mousereleased(x, y, button)
    if SceneManager.currentScene and SceneManager.currentScene.mousereleased then
        SceneManager.currentScene:mousereleased(x, y, button)
    end
end

--------------------------------------------------
-- love.wheelmoved(x, y):
-- Handles mouse wheel movement.
--------------------------------------------------
function love.wheelmoved(x, y)
    -- Try handling wheel event in EventMonitor first
    if not EventMonitor.wheelmoved(x, y) then
        -- If EventMonitor didn't consume it, pass to SceneManager
        SceneManager:wheelmoved(x, y)
    end
end

--------------------------------------------------
-- love.quit():
-- Called when the game is closed.
--------------------------------------------------
function love.quit()
    -- Publish game ended event
    EventBus.publish(EventBus.Events.GAME_ENDED)
    
    -- Print event diagnostics when closing in debug mode
    if Debug.ENABLED then
        EventBus.printDiagnostics()
        Debug.printCallTrace()
    end
    
    Debug.info("TFGON Game Closed")
    return false -- Allow the game to close
end