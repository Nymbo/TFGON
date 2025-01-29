-- game/managers/scenemanager.lua
-- This manager handles switching between different scenes (main menu, gameplay, etc.)
-- without creating circular references. Scenes are required only when needed.

--------------------------------------------------
-- Table definition for SceneManager
--------------------------------------------------
local SceneManager = {
    -- Holds the currently active scene. Initially nil until set.
    currentScene = nil
}

--------------------------------------------------
-- changeScene(sceneName):
-- Dynamically loads the scene by name and instantiates it.
-- We pass a callback to each scene so that the scene can
-- request a scene change without directly referencing the manager.
--------------------------------------------------
function SceneManager:changeScene(sceneName)
    if sceneName == "mainmenu" then
        -- Require the MainMenu scene on demand
        local MainMenu = require("game.scenes.mainmenu")
        -- Instantiate MainMenu with a callback for changing scenes
        self.currentScene = MainMenu:new(function(newScene)
            self:changeScene(newScene)
        end)

    elseif sceneName == "gameplay" then
        -- Require the Gameplay scene on demand
        local Gameplay = require("game.scenes.gameplay")
        -- Instantiate Gameplay with a callback for changing scenes
        self.currentScene = Gameplay:new(function(newScene)
            self:changeScene(newScene)
        end)

    else
        -- If an unknown scene is requested, throw an error
        error("Unknown scene: " .. tostring(sceneName))
    end
end

--------------------------------------------------
-- update(dt):
-- Passes the update call to the active scene if it has one.
-- This is called every frame by LOVE's main loop.
--------------------------------------------------
function SceneManager:update(dt)
    if self.currentScene and self.currentScene.update then
        self.currentScene:update(dt)
    end
end

--------------------------------------------------
-- draw():
-- Passes the draw call to the active scene if it exists.
-- Responsible for rendering the current scene each frame.
--------------------------------------------------
function SceneManager:draw()
    if self.currentScene and self.currentScene.draw then
        self.currentScene:draw()
    end
end

--------------------------------------------------
-- keypressed(key):
-- Passes keyboard input to the active scene if it has a handler.
-- Enables scenes to respond to key presses.
--------------------------------------------------
function SceneManager:keypressed(key)
    if self.currentScene and self.currentScene.keypressed then
        self.currentScene:keypressed(key)
    end
end

--------------------------------------------------
-- mousepressed(x, y, button, istouch, presses):
-- Passes mouse input (clicks) to the active scene if it has a handler.
-- Enables scenes to respond to mouse clicks.
--------------------------------------------------
function SceneManager:mousepressed(x, y, button, istouch, presses)
    if self.currentScene and self.currentScene.mousepressed then
        self.currentScene:mousepressed(x, y, button, istouch, presses)
    end
end

return SceneManager
