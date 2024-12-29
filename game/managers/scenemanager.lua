-- game/managers/scenemanager.lua
-- Manages which scene is currently active.

local SceneManager = {
    currentScene = nil
}

function SceneManager:changeScene(sceneName)
    -- We only require the scene modules here *when* we need them,
    -- not at the top of the file, to avoid circular references.

    if sceneName == "mainmenu" then
        local MainMenu = require("game.scenes.mainmenu")
        -- Pass a function to the scene so it can change scenes
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

return SceneManager
