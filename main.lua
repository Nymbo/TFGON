-- main.lua
-- This is the entry point for the LOVE 2D application.
-- It sets up a random seed, loads a custom font, and delegates
-- updates/draw calls to the SceneManager.

--------------------------------------------------
-- Require the SceneManager, which handles which
-- scene (mainmenu, gameplay, etc.) is currently active.
--------------------------------------------------
local SceneManager = require("game.managers.scenemanager")

--------------------------------------------------
-- love.load():
-- Called once at the start of the program.
-- Sets the random seed for any random operations,
-- loads a custom font, and initializes the scene.
--------------------------------------------------
function love.load()
    -- Initialize the random number generator with
    -- the current system time for randomness.
    math.randomseed(os.time())

    -- Load and set a smaller custom fantasy-style font
    -- for all subsequent drawing operations.
    -- This file must exist at:
    -- assets/fonts/InknutAntiqua-Regular.ttf
    local fancyFont = love.graphics.newFont("assets/fonts/InknutAntiqua-Regular.ttf", 14)
    love.graphics.setFont(fancyFont)
    
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
-- Delegates to the SceneManager, which draws
-- the active scene.
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
-- Passes mouse inputs to the SceneManager,
-- allowing scenes to handle mouse clicks.
--------------------------------------------------
function love.mousepressed(x, y, button, istouch, presses)
    SceneManager:mousepressed(x, y, button, istouch, presses)
end
