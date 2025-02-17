-- game/scenes/gameplay.lua
-- Main scene file for the Gameplay state.
-- Delegates draw, input, and combat logic to smaller modules:
-- draw.lua, input.lua, and combat.lua (all in game/scenes/gameplay/).

--------------------------------------------------
-- Requires
--------------------------------------------------
local GameManager = require("game.managers.gamemanager")   -- Overarching game logic
local DrawSystem = require("game.scenes.gameplay.draw")    -- Our new drawing module
local InputSystem = require("game.scenes.gameplay.input")  -- Our new input module
local CombatSystem = require("game.scenes.gameplay.combat")-- Our new combat module

--------------------------------------------------
-- Table definition for Gameplay scene
--------------------------------------------------
local Gameplay = {}
Gameplay.__index = Gameplay

--------------------------------------------------
-- Constructor for the Gameplay scene
-- Accepts 'changeSceneCallback' for returning to menu or changing scenes.
--------------------------------------------------
function Gameplay:new(changeSceneCallback)
    local self = setmetatable({}, Gameplay)
    
    -- Create a GameManager instance (manages players, turns, etc.)
    self.gameManager = GameManager:new()
    
    -- Store the scene-change callback
    self.changeSceneCallback = changeSceneCallback

    -- Load background image once; we'll draw it in draw.lua
    self.background = love.graphics.newImage("assets/images/background.png")

    -- Track hover state for the End Turn button
    self.endTurnHovered = false

    -- Tracks the currently selected minion (if any)
    self.selectedMinion = nil

    return self
end

--------------------------------------------------
-- update(dt):
-- Called each frame to update game logic.
--------------------------------------------------
function Gameplay:update(dt)
    -- Let the GameManager update any internal logic
    self.gameManager:update(dt)

    -- Check if the mouse is hovering over "End Turn" button
    -- This sets self.endTurnHovered to true or false
    self.endTurnHovered = InputSystem.checkEndTurnHover(self)
end

--------------------------------------------------
-- draw():
-- Called each frame to render the gameplay.
-- Delegates to DrawSystem to keep this file small.
--------------------------------------------------
function Gameplay:draw()
    DrawSystem.drawGameplayScene(self)
end

--------------------------------------------------
-- mousepressed(x, y, button, istouch, presses):
-- Handles left-click events, e.g. playing cards,
-- selecting attackers, or ending turn.
--------------------------------------------------
function Gameplay:mousepressed(x, y, button, istouch, presses)
    InputSystem.mousepressed(self, x, y, button, istouch, presses)
end

--------------------------------------------------
-- keypressed(key):
-- Allows returning to main menu with ESC or other key-based logic.
--------------------------------------------------
function Gameplay:keypressed(key)
    if key == "escape" then
        -- Go back to main menu
        self.changeSceneCallback("mainmenu")
    end
end

--------------------------------------------------
-- resolveAttack(attacker, target):
-- Delegates to the CombatSystem for the actual logic
-- of minion/hero attacks.
--------------------------------------------------
function Gameplay:resolveAttack(attacker, target)
    CombatSystem.resolveAttack(self, attacker, target)
end

return Gameplay
