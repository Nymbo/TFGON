-- game/managers/scenemanager.lua
-- This manager handles switching between different scenes (main menu, deck selection, gameplay, collection, settings, etc.)
-- without creating circular references. Scenes are required only when needed.

--------------------------------------------------
-- Table definition for SceneManager
--------------------------------------------------
local SceneManager = {
    -- Holds the currently active scene. Initially nil until set.
    currentScene = nil
}

--------------------------------------------------
-- changeScene(sceneName, ...):
-- Dynamically loads the scene by name and instantiates it.
-- Extra parameters (if any) are passed to the scene's constructor.
--------------------------------------------------
function SceneManager:changeScene(sceneName, ...)
    if sceneName == "mainmenu" then
        local MainMenu = require("game.scenes.mainmenu")
        self.currentScene = MainMenu:new(function(newScene, ...)
            self:changeScene(newScene, ...)
        end, ...)
    elseif sceneName == "deckselection" then
        local DeckSelection = require("game.scenes.deckselection")
        self.currentScene = DeckSelection:new(function(newScene, ...)
            self:changeScene(newScene, ...)
        end, ...)
    elseif sceneName == "gameplay" then
        local Gameplay = require("game.scenes.gameplay")
        self.currentScene = Gameplay:new(function(newScene, ...)
            self:changeScene(newScene, ...)
        end, ...)
    elseif sceneName == "collection" then
        local Collection = require("game.scenes.collection")
        self.currentScene = Collection:new(function(newScene, ...)
            self:changeScene(newScene, ...)
        end, ...)
    elseif sceneName == "settings" then
        local Settings = require("game.scenes.settings")
        self.currentScene = Settings:new(function(newScene, ...)
            self:changeScene(newScene, ...)
        end, ...)
    else
        error("Unknown scene: " .. tostring(sceneName))
    end
end

--------------------------------------------------
-- update(dt):
-- Passes the update call to the active scene if it has one.
--------------------------------------------------
function SceneManager:update(dt)
    if self.currentScene and self.currentScene.update then
        self.currentScene:update(dt)
    end
end

--------------------------------------------------
-- draw():
-- Passes the draw call to the active scene if it exists.
--------------------------------------------------
function SceneManager:draw()
    if self.currentScene and self.currentScene.draw then
        self.currentScene:draw()
    end
end

--------------------------------------------------
-- keypressed(key):
-- Passes keyboard input to the active scene if it has a handler.
--------------------------------------------------
function SceneManager:keypressed(key)
    if self.currentScene and self.currentScene.keypressed then
        self.currentScene:keypressed(key)
    end
end

--------------------------------------------------
-- mousepressed(x, y, button, istouch, presses):
-- Passes mouse input (clicks) to the active scene if it has a handler.
--------------------------------------------------
function SceneManager:mousepressed(x, y, button, istouch, presses)
    if self.currentScene and self.currentScene.mousepressed then
        self.currentScene:mousepressed(x, y, button, istouch, presses)
    end
end

--------------------------------------------------
-- wheelmoved(x, y):
-- Passes mouse wheel movement to the active scene if it has a handler.
--------------------------------------------------
function SceneManager:wheelmoved(x, y)
    if self.currentScene and self.currentScene.wheelmoved then
        self.currentScene:wheelmoved(x, y)
    end
end

return SceneManager