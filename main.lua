-- main.lua
local SceneManager = require("game.managers.scenemanager")

function love.load()
    math.randomseed(os.time())

    -- Load and set a smaller custom fantasy-style font for the whole UI.
    -- Make sure the TTF file is located at assets/fonts/InknutAntiqua-Regular.ttf
    local fancyFont = love.graphics.newFont("assets/fonts/InknutAntiqua-Regular.ttf", 14)
    love.graphics.setFont(fancyFont)
    
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

function love.mousepressed(x, y, button, istouch, presses)
    SceneManager:mousepressed(x, y, button, istouch, presses)
end
