-- main.lua
-- Main entry point for the game.

local SceneManager = require("game.managers.scenemanager")

function love.load()
    -- Initialize random seed for card draws
    math.randomseed(os.time())

    -- Load the initial scene (e.g., main menu)
    SceneManager:changeScene("mainmenu")
end

function love.update(dt)
    -- Update current scene
    SceneManager:update(dt)
end

function love.draw()
    -- Draw current scene
    SceneManager:draw()
end

function love.keypressed(key)
    -- Pass input events to current scene
    SceneManager:keypressed(key)
end
