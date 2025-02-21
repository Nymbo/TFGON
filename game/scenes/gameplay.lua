-- game/scenes/gameplay.lua
-- Main gameplay scene.
-- Now accepts a selected deck for player 1 via its constructor.
-- Also accepts a selected board configuration.
-- Displays a banner (banner image plus text) at the start of each turn.
-- The banner is now positioned so its center aligns with the center of the board.

local GameManager = require("game.managers.gamemanager")
local DrawSystem = require("game.scenes.gameplay.draw")
local InputSystem = require("game.scenes.gameplay.input")
local CombatSystem = require("game.scenes.gameplay.combat")
local BoardRenderer = require("game.ui.boardrenderer")

local Gameplay = {}
Gameplay.__index = Gameplay

--------------------------------------------------
-- Constructor for Gameplay scene.
-- 'selectedDeck' is passed in from Deck Selection.
-- 'selectedBoard' is passed in from Deck Selection.
-- We load the banner images and set up a callback to display them
-- for a brief duration (bannerTimer).
--------------------------------------------------
function Gameplay:new(changeSceneCallback, selectedDeck, selectedBoard)
    local self = setmetatable({}, Gameplay)
    
    -- Pass the selectedDeck and selectedBoard to GameManager for player 1.
    self.gameManager = GameManager:new(selectedDeck, selectedBoard)
    self.changeSceneCallback = changeSceneCallback
    
    -- Store the selected board config
    self.selectedBoard = selectedBoard

    -- Background image - use board-specific image if provided
    if selectedBoard and selectedBoard.imagePath and love.filesystem.getInfo(selectedBoard.imagePath) then
        self.background = love.graphics.newImage(selectedBoard.imagePath)
    else
        self.background = love.graphics.newImage("assets/images/background.png")
    end

    -- End turn button hover flag
    self.endTurnHovered = false

    -- Selected minion for movement/attack
    self.selectedMinion = nil

    -- Banner images for turn announcements
    self.blueRibbon = love.graphics.newImage("assets/images/Ribbon_Blue_3Slides.png")
    self.redRibbon = love.graphics.newImage("assets/images/Ribbon_Red_3Slides.png")

    -- Font for the banner text (16 pt)
    self.bannerFont = love.graphics.newFont("assets/fonts/InknutAntiqua-Regular.ttf", 16)

    -- Banner display state
    self.bannerImage = nil     -- which image to display
    self.bannerText = ""       -- text to show
    self.bannerTimer = 0       -- countdown timer
    self.bannerDuration = 1.5  -- how many seconds the banner remains visible

    -- Set a callback in the GameManager to handle the start of each turn.
    self.gameManager.onTurnStart = function(whichPlayer)
        if whichPlayer == "player1" then
            self.bannerImage = self.blueRibbon
            self.bannerText = "YOUR TURN"
        else
            self.bannerImage = self.redRibbon
            self.bannerText = "OPPONENT'S TURN"
        end
        self.bannerTimer = self.bannerDuration
    end

    return self
end

--------------------------------------------------
-- update: Update game logic, end turn hover,
-- and decrement banner timer if active.
--------------------------------------------------
function Gameplay:update(dt)
    self.gameManager:update(dt)
    self.endTurnHovered = InputSystem.checkEndTurnHover(self)

    if self.bannerTimer > 0 then
        self.bannerTimer = self.bannerTimer - dt
        if self.bannerTimer < 0 then
            self.bannerTimer = 0
        end
    end
end

--------------------------------------------------
-- draw: Render gameplay.
-- Also draws the turn announcement banner if bannerTimer > 0.
--------------------------------------------------
function Gameplay:draw()
    -- Draw the standard gameplay scene elements
    DrawSystem.drawGameplayScene(self)

    -- If a banner is active, draw it in the specified position over the board.
    if self.bannerTimer > 0 and self.bannerImage then
        -- Get the board dimensions from the renderer
        local boardX, boardY = BoardRenderer.getBoardPosition()
        local TILE_SIZE = BoardRenderer.getTileSize()
        
        -- Calculate the center of the board
        local boardWidth = TILE_SIZE * self.gameManager.board.cols
        local boardHeight = TILE_SIZE * self.gameManager.board.rows
        local cx = boardX + boardWidth / 2
        local cy = boardY + boardHeight / 2

        local iw = self.bannerImage:getWidth()
        local ih = self.bannerImage:getHeight()

        -- Scale the banner images by 2 (100% larger)
        local scale = 2
        local scaledWidth = iw * scale
        local scaledHeight = ih * scale

        -- Draw the ribbon image centered at (cx, cy) with scaling
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(
            self.bannerImage,
            cx - (scaledWidth / 2),
            cy - (scaledHeight / 2),
            0,
            scale,
            scale
        )

        -- Prepare to draw the bold text on top of the banner
        local oldFont = love.graphics.getFont()
        love.graphics.setFont(self.bannerFont)
        love.graphics.setColor(1, 1, 1, 1)

        -- Calculate text position: base it on the scaled image.
        local textX = cx - (scaledWidth / 2)
        local textY = cy - (scaledHeight / 2) + (scaledHeight * 0.3) - 5

        -- Simulate bold text by drawing it multiple times with slight offsets.
        love.graphics.printf(self.bannerText, textX + 1, textY, scaledWidth, "center")
        love.graphics.printf(self.bannerText, textX - 1, textY, scaledWidth, "center")
        love.graphics.printf(self.bannerText, textX, textY + 1, scaledWidth, "center")
        love.graphics.printf(self.bannerText, textX, textY - 1, scaledWidth, "center")
        -- Draw the text normally on top
        love.graphics.printf(self.bannerText, textX, textY, scaledWidth, "center")

        love.graphics.setFont(oldFont)
    end
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