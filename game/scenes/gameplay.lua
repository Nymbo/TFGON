-- game/scenes/gameplay.lua
-- Main gameplay scene.
-- Now accepts a selected deck for player 1 via its constructor.
-- Also accepts a selected board configuration.
-- Displays a banner (banner image plus text) at the start of each turn.
-- The banner is now positioned so its center aligns with the center of the board.
-- Updated to include AI opponent functionality

local GameManager = require("game.managers.gamemanager")
local DrawSystem = require("game.scenes.gameplay.draw")
local InputSystem = require("game.scenes.gameplay.input")
local CombatSystem = require("game.scenes.gameplay.combat")
local BoardRenderer = require("game.ui.boardrenderer")
local AIManager = require("game.managers.aimanager") -- New AI Manager import

local Gameplay = {}
Gameplay.__index = Gameplay

--------------------------------------------------
-- Constructor for Gameplay scene.
-- 'selectedDeck' is passed in from Deck Selection.
-- 'selectedBoard' is passed in from Deck Selection.
-- Added 'aiOpponent' parameter to enable AI opponent.
--------------------------------------------------
function Gameplay:new(changeSceneCallback, selectedDeck, selectedBoard, aiOpponent)
    local self = setmetatable({}, Gameplay)
    
    -- Pass the selectedDeck and selectedBoard to GameManager for player 1.
    self.gameManager = GameManager:new(selectedDeck, selectedBoard)
    self.changeSceneCallback = changeSceneCallback
    
    -- Store the selected board config
    self.selectedBoard = selectedBoard

    -- Initialize AI opponent if enabled
    self.aiOpponent = aiOpponent or false
    if self.aiOpponent then
        self.aiManager = AIManager:new(self.gameManager)
    end

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
            local bannerMsg = self.aiOpponent and "AI OPPONENT'S TURN" or "OPPONENT'S TURN"
            self.bannerText = bannerMsg
        end
        self.bannerTimer = self.bannerDuration
    end

    -- Initialize AI turn timer
    self.aiTurnTimer = 0
    self.aiTurnDelay = 0.5  -- Delay before AI starts its turn

    return self
end

--------------------------------------------------
-- update: Update game logic, end turn hover,
-- and decrement banner timer if active.
-- Now also handles AI turns.
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

    -- Handle AI turns
    if self.aiOpponent and self.gameManager.currentPlayer == 2 then
        -- Add a small delay before the AI takes its turn
        self.aiTurnTimer = self.aiTurnTimer - dt
        if self.aiTurnTimer <= 0 then
            -- Reset the timer for next AI turn
            self.aiTurnTimer = self.aiTurnDelay
            
            -- Execute AI turn
            self.aiManager:takeTurn()
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
-- Updated to handle AI opponent.
--------------------------------------------------
function Gameplay:mousepressed(x, y, button, istouch, presses)
    -- Don't allow user input during AI's turn
    if self.aiOpponent and self.gameManager.currentPlayer == 2 then
        return
    end
    
    InputSystem.mousepressed(self, x, y, button, istouch, presses)
end

--------------------------------------------------
-- endTurn: Custom end turn function that handles the AI turn timer
--------------------------------------------------
function Gameplay:endTurn()
    self.gameManager:endTurn()
    
    -- If it's now the AI's turn, set the AI turn timer
    if self.aiOpponent and self.gameManager.currentPlayer == 2 then
        self.aiTurnTimer = self.aiTurnDelay
    end
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