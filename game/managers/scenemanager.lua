-- game/managers/scenemanager.lua
-- This manager handles switching between different scenes (main menu, deck selection, gameplay, collection, settings, etc.)
-- without creating circular references. Scenes are required only when needed.
-- Enhanced with better error handling and logging

local ErrorLog = require("game.utils.errorlog")

--------------------------------------------------
-- Table definition for SceneManager
--------------------------------------------------
local SceneManager = {
    -- Holds the currently active scene. Initially nil until set.
    currentScene = nil,
    
    -- Track the current scene name
    currentSceneName = nil,
    
    -- Track scene loading attempts to prevent infinite recursion
    sceneLoadAttempts = {}
}

--------------------------------------------------
-- changeScene(sceneName, ...):
-- Dynamically loads the scene by name and instantiates it.
-- Extra parameters (if any) are passed to the scene's constructor.
--------------------------------------------------
function SceneManager:changeScene(sceneName, ...)
    ErrorLog.logError("Changing scene to: " .. tostring(sceneName), true)
    
    -- Remember what we're loading to prevent recursion
    if self.sceneLoadAttempts[sceneName] then
        ErrorLog.logError("ERROR: Recursive scene loading detected for: " .. sceneName)
        return false
    end
    
    -- Mark this scene as being loaded
    self.sceneLoadAttempts[sceneName] = true
    
    -- Track arguments for error reporting
    local args = {...}  -- Capture varargs
    local argTypes = {}
    for i, arg in ipairs(args) do
        argTypes[i] = type(arg)
        if type(arg) == "table" and arg.name then
            argTypes[i] = argTypes[i] .. ":" .. arg.name
        end
    end
    
    ErrorLog.logError("Scene change arguments: " .. table.concat(argTypes, ", "), true)
    
    -- Attempt to load and initialize the new scene
    if sceneName == "mainmenu" then
        local success, result = pcall(function()
            local MainMenu = require("game.scenes.mainmenu")
            return MainMenu:new(function(newScene, ...)
                self:changeScene(newScene, ...)
            end, unpack(args))  -- Use unpack to pass the captured args
        end)
        
        if success then
            self.currentScene = result
            self.currentSceneName = "mainmenu"
            ErrorLog.logError("Main menu scene loaded successfully", true)
        else
            ErrorLog.logError("Failed to load main menu scene: " .. tostring(result))
            -- Fall back to current scene
            self.sceneLoadAttempts[sceneName] = nil
            return false
        end
    elseif sceneName == "deckselection" then
        local success, result = pcall(function()
            local DeckSelection = require("game.scenes.deckselection")
            return DeckSelection:new(function(newScene, ...)
                self:changeScene(newScene, ...)
            end, unpack(args))  -- Use unpack to pass the captured args
        end)
        
        if success then
            self.currentScene = result
            self.currentSceneName = "deckselection"
            ErrorLog.logError("Deck selection scene loaded successfully", true)
        else
            ErrorLog.logError("Failed to load deck selection scene: " .. tostring(result))
            -- Fall back to current scene
            self.sceneLoadAttempts[sceneName] = nil
            return false
        end
    elseif sceneName == "gameplay" then
        -- The gameplay scene is the most complex and prone to errors
        -- Handle it with extra care
        ErrorLog.logError("Loading gameplay scene...", true)
        
        -- Check if we have required arguments
        if #args < 1 then
            ErrorLog.logError("ERROR: Missing deck argument for gameplay scene")
            self.sceneLoadAttempts[sceneName] = nil
            return false
        end
        
        local deck = args[1]
        local board = args[2]
        local aiOpponent = args[3]
        
        -- Validate deck
        if not deck or type(deck) ~= "table" or not deck.cards then
            ErrorLog.logError("ERROR: Invalid deck argument: " .. tostring(deck))
            self.sceneLoadAttempts[sceneName] = nil
            return false
        end
        
        -- Validate board
        if not board or type(board) ~= "table" then
            ErrorLog.logError("ERROR: Invalid board argument: " .. tostring(board))
            self.sceneLoadAttempts[sceneName] = nil
            return false
        end
        
        -- Log key parameters
        ErrorLog.logError("Starting gameplay with deck: " .. 
                       deck.name .. " (" .. #deck.cards .. " cards), " ..
                       "board: " .. board.name .. ", AI: " .. tostring(aiOpponent), true)
        
        -- Try to load the gameplay scene
        local success, result = pcall(function()
            local Gameplay = require("game.scenes.gameplay")
            return Gameplay:new(function(newScene, ...)
                self:changeScene(newScene, ...)
            end, unpack(args))  -- Use unpack to pass the captured args
        end)
        
        if success then
            self.currentScene = result
            self.currentSceneName = "gameplay"
            ErrorLog.logError("Gameplay scene loaded successfully", true)
        else
            ErrorLog.logError("ERROR: Failed to load gameplay scene: " .. tostring(result))
            -- Fall back to current scene or go back to deck selection as a safe fallback
            if self.currentSceneName ~= "deckselection" then
                ErrorLog.logError("Falling back to deck selection", true)
                self.sceneLoadAttempts[sceneName] = nil
                self:changeScene("deckselection")
            end
            return false
        end
    elseif sceneName == "collection" then
        local success, result = pcall(function()
            local Collection = require("game.scenes.collection")
            return Collection:new(function(newScene, ...)
                self:changeScene(newScene, ...)
            end, unpack(args))  -- Use unpack to pass the captured args
        end)
        
        if success then
            self.currentScene = result
            self.currentSceneName = "collection"
            ErrorLog.logError("Collection scene loaded successfully", true)
        else
            ErrorLog.logError("Failed to load collection scene: " .. tostring(result))
            -- Fall back to current scene
            self.sceneLoadAttempts[sceneName] = nil
            return false
        end
    elseif sceneName == "settings" then
        local success, result = pcall(function()
            local Settings = require("game.scenes.settings")
            return Settings:new(function(newScene, ...)
                self:changeScene(newScene, ...)
            end, unpack(args))  -- Use unpack to pass the captured args
        end)
        
        if success then
            self.currentScene = result
            self.currentSceneName = "settings"
            ErrorLog.logError("Settings scene loaded successfully", true)
        else
            ErrorLog.logError("Failed to load settings scene: " .. tostring(result))
            -- Fall back to current scene
            self.sceneLoadAttempts[sceneName] = nil
            return false
        end
    else
        ErrorLog.logError("ERROR: Unknown scene: " .. tostring(sceneName))
        self.sceneLoadAttempts[sceneName] = nil
        return false
    end
    
    -- Clear the loading flag
    self.sceneLoadAttempts[sceneName] = nil
    return true
end

--------------------------------------------------
-- update(dt):
-- Passes the update call to the active scene if it has one.
--------------------------------------------------
function SceneManager:update(dt)
    if self.currentScene and self.currentScene.update then
        -- Use pcall to catch update errors
        local success, err = pcall(function()
            self.currentScene:update(dt)
        end)
        
        if not success then
            ErrorLog.logError("Error updating scene: " .. tostring(err))
        end
    end
end

--------------------------------------------------
-- draw():
-- Passes the draw call to the active scene if it exists.
--------------------------------------------------
function SceneManager:draw()
    if self.currentScene and self.currentScene.draw then
        -- Use pcall to catch drawing errors
        local success, err = pcall(function()
            self.currentScene:draw()
        end)
        
        if not success then
            ErrorLog.logError("Error drawing scene: " .. tostring(err))
            
            -- Display error message on screen so user knows something is wrong
            love.graphics.setColor(1, 0, 0, 1)
            love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), 30)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf("Error in current scene. Check error log.", 
                               0, 5, love.graphics.getWidth(), "center")
        end
    end
end

--------------------------------------------------
-- keypressed(key):
-- Passes keyboard input to the active scene if it has a handler.
--------------------------------------------------
function SceneManager:keypressed(key)
    if self.currentScene and self.currentScene.keypressed then
        -- Use pcall to catch input handling errors
        local success, err = pcall(function()
            self.currentScene:keypressed(key)
        end)
        
        if not success then
            ErrorLog.logError("Error handling keypressed: " .. tostring(err))
        end
    end
end

--------------------------------------------------
-- mousepressed(x, y, button, istouch, presses):
-- Passes mouse input (clicks) to the active scene if it has a handler.
--------------------------------------------------
function SceneManager:mousepressed(x, y, button, istouch, presses)
    if self.currentScene and self.currentScene.mousepressed then
        -- Use pcall to catch input handling errors
        local success, err = pcall(function()
            self.currentScene:mousepressed(x, y, button, istouch, presses)
        end)
        
        if not success then
            ErrorLog.logError("Error handling mousepressed: " .. tostring(err))
        end
    end
end

--------------------------------------------------
-- wheelmoved(x, y):
-- Passes mouse wheel movement to the active scene if it has a handler.
--------------------------------------------------
function SceneManager:wheelmoved(x, y)
    if self.currentScene and self.currentScene.wheelmoved then
        -- Use pcall to catch input handling errors
        local success, err = pcall(function()
            self.currentScene:wheelmoved(x, y)
        end)
        
        if not success then
            ErrorLog.logError("Error handling wheelmoved: " .. tostring(err))
        end
    end
end

return SceneManager