-- game/managers/scenemanager.lua

local SceneManager = {
    currentScene = nil
}

function SceneManager:changeScene(sceneName)
    if sceneName == "mainmenu" then
        local MainMenu = require("game.scenes.mainmenu")
        self.currentScene = MainMenu:new(function(newScene)
            self:changeScene(newScene)
        end)
    elseif sceneName == "gameplay" then
        local Gameplay = require("game.scenes.gameplay")
        self.currentScene = Gameplay:new(function(newScene)
            self:changeScene(newScene)
        end)
    else
        error("Unknown scene: " .. tostring(sceneName))
    end
end

function SceneManager:update(dt)
    if self.currentScene and self.currentScene.update then
        self.currentScene:update(dt)
    end
end

function SceneManager:draw()
    if self.currentScene and self.currentScene.draw then
        self.currentScene:draw()
    end
end

function SceneManager:keypressed(key)
    if self.currentScene and self.currentScene.keypressed then
        self.currentScene:keypressed(key)
    end
end

-- NEW: Pass mouse click events to the current scene
function SceneManager:mousepressed(x, y, button, istouch, presses)
    if self.currentScene and self.currentScene.mousepressed then
        self.currentScene:mousepressed(x, y, button, istouch, presses)
    end
end

return SceneManager
