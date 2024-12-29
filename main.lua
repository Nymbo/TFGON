-- main.lua
local SceneManager = require("game.managers.scenemanager")

function love.load()
    math.randomseed(os.time())
    SceneManager:changeScene("mainmenu")
end

function love.update(dt)
    SceneManager:update(dt)
end

function love.draw()
    SceneManager:draw()
end

function love.keypressed(key)
    SceneManager:keypressed(key)
end

-- NEW: forward mouse clicks to the SceneManager
function love.mousepressed(x, y, button, istouch, presses)
    SceneManager:mousepressed(x, y, button, istouch, presses)
end
