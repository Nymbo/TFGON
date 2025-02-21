-- main.lua
-- This is the entry point for the LOVE 2D application.
-- It sets up a random seed, loads a custom font, and delegates
-- updates/draw calls to the SceneManager.
-- 
-- New additions:
-- 1. A custom cursor is loaded from "assets/images/cursor.png" and applied with adjusted hotspot.
-- 2. A click sound is loaded from "assets/sounds/click1.ogg" and played on each left click.

--------------------------------------------------
-- Require the SceneManager, which handles which
-- scene (mainmenu, gameplay, etc.) is currently active.
--------------------------------------------------
local SceneManager = require("game.managers.scenemanager")

-- Global variable for the click sound effect.
local clickSound

--------------------------------------------------
-- love.load():
-- Called once at the start of the program.
-- Sets the random seed for any random operations,
-- loads a custom font, sets the custom cursor, loads the click sound,
-- and initializes the initial scene.
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
    -- The hotspot values (30, 18) represent the point where clicks are registered,
    -- fixing the alignment issue without needing coordinate transformations.
    local customCursor = love.mouse.newCursor("assets/images/cursor.png", 30, 18)
    love.mouse.setCursor(customCursor)
    
    -- Load the click sound effect.
    -- Ensure that "assets/sounds/click1.ogg" exists in your repository.
    clickSound = love.audio.newSource("assets/sounds/click1.ogg", "static")
    
    -- Change to the initial "mainmenu" scene.
    SceneManager:changeScene("mainmenu")
end

--------------------------------------------------
-- love.update(dt):
-- Called every frame to handle logic updates.
-- We pass dt (delta time) along to the SceneManager,
-- which in turn updates the current scene.
--------------------------------------------------
function love.update(dt)
    SceneManager:update(dt)
end

--------------------------------------------------
-- love.draw():
-- Called every frame to handle rendering.
-- Delegates to the SceneManager, which draws the active scene.
--------------------------------------------------
function love.draw()
    SceneManager:draw()
end

--------------------------------------------------
-- love.keypressed(key):
-- Passes keyboard inputs to the SceneManager,
-- allowing scenes to handle key presses.
--------------------------------------------------
function love.keypressed(key)
    SceneManager:keypressed(key)
end

--------------------------------------------------
-- love.mousepressed(x, y, button, istouch, presses):
-- Plays the click sound on left-click and then passes mouse inputs to the SceneManager,
-- allowing scenes to handle mouse clicks.
--------------------------------------------------
function love.mousepressed(x, y, button, istouch, presses)
    if button == 1 then
        clickSound:stop() -- Stop any current playback (in case clicks occur rapidly)
        clickSound:play() -- Play the click sound for left mouse button
    end
    SceneManager:mousepressed(x, y, button, istouch, presses)
end