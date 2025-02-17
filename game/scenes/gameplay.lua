-- game/scenes/gameplay.lua
-- Main gameplay scene.
-- Now accepts a selected deck for player 1 via its constructor.

local GameManager = require("game.managers.gamemanager")
local DrawSystem = require("game.scenes.gameplay.draw")
local InputSystem = require("game.scenes.gameplay.input")
local CombatSystem = require("game.scenes.gameplay.combat")

local Gameplay = {}
Gameplay.__index = Gameplay

--------------------------------------------------
-- Constructor for Gameplay scene.
-- 'selectedDeck' is passed in from Deck Selection.
--------------------------------------------------
function Gameplay:new(changeSceneCallback, selectedDeck)
    local self = setmetatable({}, Gameplay)
    
    -- Pass the selectedDeck to GameManager for player 1.
    self.gameManager = GameManager:new(selectedDeck)
    self.changeSceneCallback = changeSceneCallback

    self.background = love.graphics.newImage("assets/images/background.png")
    self.endTurnHovered = false
    self.selectedMinion = nil

    return self
end

--------------------------------------------------
-- update: Update game logic.
--------------------------------------------------
function Gameplay:update(dt)
    self.gameManager:update(dt)
    self.endTurnHovered = InputSystem.checkEndTurnHover(self)
end

--------------------------------------------------
-- draw: Render gameplay.
--------------------------------------------------
function Gameplay:draw()
    DrawSystem.drawGameplayScene(self)
end

--------------------------------------------------
-- mousepressed: Delegate to input system.
--------------------------------------------------
function Gameplay:mousepressed(x, y, button, istouch, presses)
    InputSystem.mousepressed(self, x, y, button, istouch, presses)
end

--------------------------------------------------
-- keypressed: Allow exiting with ESC.
--------------------------------------------------
function Gameplay:keypressed(key)
    if key == "escape" then
        self.changeSceneCallback("mainmenu")
    end
end

--------------------------------------------------
-- resolveAttack: Delegate to combat system.
--------------------------------------------------
function Gameplay:resolveAttack(attacker, target)
    CombatSystem.resolveAttack(self, attacker, target)
end

return Gameplay
