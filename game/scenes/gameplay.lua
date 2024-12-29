-- game/scenes/gameplay.lua
-- The main in-game scene.

local GameManager = require("game.managers.gamemanager")

local Gameplay = {}
Gameplay.__index = Gameplay

function Gameplay:new(changeSceneCallback)
    local self = setmetatable({}, Gameplay)
    self.gameManager = GameManager:new()
    self.changeSceneCallback = changeSceneCallback
    return self
end

function Gameplay:update(dt)
    self.gameManager:update(dt)
end

function Gameplay:draw()
    self.gameManager:draw()
end

function Gameplay:keypressed(key)
    if key == "space" then
        self.gameManager:endTurn()
    end

    if key == "escape" then
        -- Possibly go back to main menu on Escape
        self.changeSceneCallback("mainmenu")
    end
end

return Gameplay
