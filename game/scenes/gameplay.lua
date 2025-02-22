-- game/scenes/gameplay.lua
-- Main gameplay scene.
-- Now accepts a selected deck for player 1 via its constructor.
-- Also accepts a selected board configuration.
-- Displays a banner at the start of each turn.
-- Includes AI opponent functionality.
-- A game over popup menu is displayed when a player's tower is destroyed,
-- styled similarly to the Settings menu using theme.lua.

local GameManager = require("game.managers.gamemanager")
local DrawSystem = require("game.scenes.gameplay.draw")
local InputSystem = require("game.scenes.gameplay.input")
local CombatSystem = require("game.scenes.gameplay.combat")
local BoardRenderer = require("game.ui.boardrenderer")
local AIManager = require("game.managers.aimanager") -- New AI Manager import
local Theme = require("game.ui.theme")

-- Local helper function to draw a themed button (similar to settings.lua)
local function drawThemedButton(text, x, y, width, height, isHovered, isSelected)
    -- Shadow
    love.graphics.setColor(Theme.colors.buttonShadow)
    love.graphics.rectangle(
        "fill",
        x + Theme.dimensions.buttonShadowOffset,
        y + Theme.dimensions.buttonShadowOffset,
        width,
        height,
        Theme.dimensions.buttonCornerRadius
    )
    -- Hover glow
    if isHovered then
        love.graphics.setColor(Theme.colors.buttonGlowHover)
        love.graphics.rectangle(
            "fill",
            x - Theme.dimensions.buttonGlowOffset,
            y - Theme.dimensions.buttonGlowOffset,
            width + 2 * Theme.dimensions.buttonGlowOffset,
            height + 2 * Theme.dimensions.buttonGlowOffset,
            Theme.dimensions.buttonCornerRadius + 2
        )
    end
    -- Base and gradient
    if isSelected then
        love.graphics.setColor(Theme.colors.buttonHover)
    else
        love.graphics.setColor(Theme.colors.buttonBase)
    end
    love.graphics.rectangle("fill", x, y, width, height, Theme.dimensions.buttonCornerRadius)
    if isSelected then
        love.graphics.setColor(Theme.colors.buttonGlowHover)
    else
        love.graphics.setColor(Theme.colors.buttonGradientTop)
    end
    love.graphics.rectangle("fill", x + 2, y + 2, width - 4, height/2 - 2, Theme.dimensions.buttonCornerRadius)
    -- Border
    love.graphics.setColor(Theme.colors.buttonBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, width, height, Theme.dimensions.buttonCornerRadius)
    love.graphics.setLineWidth(1)
    -- Text
    love.graphics.setFont(Theme.fonts.button)
    love.graphics.setColor(isHovered and Theme.colors.textHover or Theme.colors.textPrimary)
    love.graphics.printf(text, x, y + (height - Theme.fonts.button:getHeight())/2, width, "center")
end

local Gameplay = {}
Gameplay.__index = Gameplay

--------------------------------------------------
-- Constructor for Gameplay scene.
-- 'selectedDeck' is passed in from Deck Selection.
-- 'selectedBoard' is passed in from Deck Selection.
-- 'aiOpponent' enables the AI opponent.
--------------------------------------------------
function Gameplay:new(changeSceneCallback, selectedDeck, selectedBoard, aiOpponent)
    local self = setmetatable({}, Gameplay)
    
    -- Store parameters for potential restart.
    self.selectedDeck = selectedDeck
    self.selectedBoard = selectedBoard
    self.aiOpponent = aiOpponent or false

    -- Create the game manager.
    self.gameManager = GameManager:new(selectedDeck, selectedBoard)
    self.changeSceneCallback = changeSceneCallback
    
    -- Store the selected board config.
    self.selectedBoard = selectedBoard

    -- Initialize AI opponent if enabled.
    if self.aiOpponent then
        self.aiManager = AIManager:new(self.gameManager)
        
        -- Load difficulty setting if available.
        if love.filesystem.getInfo("difficulty.txt") then
            local content = love.filesystem.read("difficulty.txt")
            local difficultyIndex = tonumber(content)
            if difficultyIndex then
                local difficultyMap = {
                    [1] = "easy",
                    [2] = "normal",
                    [3] = "hard"
                }
                local difficulty = difficultyMap[difficultyIndex] or "normal"
                self.aiManager:setDifficulty(difficulty)
            end
        end
    end

    -- Background image - use board-specific image if provided.
    if selectedBoard and selectedBoard.imagePath and love.filesystem.getInfo(selectedBoard.imagePath) then
        self.background = love.graphics.newImage(selectedBoard.imagePath)
    else
        self.background = love.graphics.newImage("assets/images/background.png")
    end

    -- End turn button hover flag.
    self.endTurnHovered = false

    -- Selected minion for movement/attack.
    self.selectedMinion = nil

    -- Banner images for turn announcements.
    self.blueRibbon = love.graphics.newImage("assets/images/Ribbon_Blue_3Slides.png")
    self.redRibbon = love.graphics.newImage("assets/images/Ribbon_Red_3Slides.png")

    -- Font for the banner text.
    self.bannerFont = love.graphics.newFont("assets/fonts/InknutAntiqua-Regular.ttf", 16)

    -- Banner display state.
    self.bannerImage = nil     -- Which image to display.
    self.bannerText = ""       -- Text to show.
    self.bannerTimer = 0       -- Countdown timer.
    self.bannerDuration = 1.5  -- Duration for which the banner remains visible.

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

    -- Set the GameManager's onGameOver callback to trigger our popup.
    self.showGameOverPopup = false
    self.gameOverWinner = nil
    self.gameManager.onGameOver = function(winner)
        self.showGameOverPopup = true
        self.gameOverWinner = winner
    end

    -- Initialize AI turn timer.
    self.aiTurnTimer = 0
    self.aiTurnDelay = 0.5  -- Delay before AI starts its turn

    return self
end

--------------------------------------------------
-- update: Update game logic, end turn hover,
-- and decrement banner timer if active.
-- Also handles AI turns.
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

    -- Handle AI turns.
    if self.aiOpponent and self.gameManager.currentPlayer == 2 and not self.showGameOverPopup then
        self.aiTurnTimer = self.aiTurnTimer - dt
        if self.aiTurnTimer <= 0 then
            self.aiTurnTimer = self.aiTurnDelay
            self.aiManager:takeTurn()
        end
    end
end

--------------------------------------------------
-- draw: Render gameplay.
-- Also draws the turn announcement banner if active.
-- If the game is over, displays a styled popup menu overlay.
--------------------------------------------------
function Gameplay:draw()
    -- Draw the standard gameplay scene elements.
    DrawSystem.drawGameplayScene(self)

    -- Draw turn banner if active.
    if self.bannerTimer > 0 and self.bannerImage then
        local boardX, boardY = BoardRenderer.getBoardPosition()
        local TILE_SIZE = BoardRenderer.getTileSize()
        local boardWidth = TILE_SIZE * self.gameManager.board.cols
        local boardHeight = TILE_SIZE * self.gameManager.board.rows
        local cx = boardX + boardWidth / 2
        local cy = boardY + boardHeight / 2

        local iw = self.bannerImage:getWidth()
        local ih = self.bannerImage:getHeight()
        local scale = 2
        local scaledWidth = iw * scale
        local scaledHeight = ih * scale

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.bannerImage, cx - (scaledWidth / 2), cy - (scaledHeight / 2), 0, scale, scale)

        local oldFont = love.graphics.getFont()
        love.graphics.setFont(self.bannerFont)
        love.graphics.setColor(1, 1, 1, 1)
        local textX = cx - (scaledWidth / 2)
        local textY = cy - (scaledHeight / 2) + (scaledHeight * 0.3) - 5
        love.graphics.printf(self.bannerText, textX + 1, textY, scaledWidth, "center")
        love.graphics.printf(self.bannerText, textX - 1, textY, scaledWidth, "center")
        love.graphics.printf(self.bannerText, textX, textY + 1, scaledWidth, "center")
        love.graphics.printf(self.bannerText, textX, textY - 1, scaledWidth, "center")
        love.graphics.printf(self.bannerText, textX, textY, scaledWidth, "center")
        love.graphics.setFont(oldFont)
    end

    -- If game over, draw the popup menu.
    if self.showGameOverPopup then
        self:drawGameOverPopup()
    end
end

--------------------------------------------------
-- drawGameOverPopup: Draws a modal popup overlay for game over.
-- The popup uses Theme styling similar to the Settings menu.
-- It has two buttons: "Restart" and "Main Menu".
-- The title displays "DEFEAT" if Player 1's tower is gone and "VICTORY" if Player 2's tower is gone.
--------------------------------------------------
function Gameplay:drawGameOverPopup()
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local popupW, popupH = 400, 300
    local popupX = (screenW - popupW) / 2
    local popupY = (screenH - popupH) / 2

    -- Semi-transparent overlay.
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Popup background using Theme colors.
    love.graphics.setColor(Theme.colors.backgroundLight)
    love.graphics.rectangle("fill", popupX, popupY, popupW, popupH, 10)
    love.graphics.setColor(Theme.colors.buttonBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", popupX, popupY, popupW, popupH, 10)
    love.graphics.setLineWidth(1)

    -- Determine title text based on the game over winner.
    local gameOverTitle = ""
    if self.gameOverWinner == self.gameManager.player2 then
        gameOverTitle = "DEFEAT"
    elseif self.gameOverWinner == self.gameManager.player1 then
        gameOverTitle = "VICTORY"
    else
        gameOverTitle = "DRAW"
    end

    -- Draw the title using Theme fonts.
    love.graphics.setFont(Theme.fonts.title)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.printf(gameOverTitle, popupX, popupY + 40, popupW, "center")

    -- Draw buttons: Restart and Main Menu.
    self.popupButtons = {}  -- Store button areas for input handling.
    local buttonW, buttonH = 150, 50
    local spacing = 20
    local totalButtonsW = 2 * buttonW + spacing
    local startX = popupX + (popupW - totalButtonsW) / 2
    local buttonY = popupY + popupH - buttonH - 40

    local buttons = {"Restart", "Main Menu"}
    for i, btnText in ipairs(buttons) do
        local btnX = startX + (i - 1) * (buttonW + spacing)
        drawThemedButton(btnText, btnX, buttonY, buttonW, buttonH, false, false)
        self.popupButtons[btnText] = {x = btnX, y = buttonY, width = buttonW, height = buttonH}
    end
end

--------------------------------------------------
-- mousepressed: Handle mouse input.
-- If game over popup is active, handle popup clicks; otherwise delegate to input system.
--------------------------------------------------
function Gameplay:mousepressed(x, y, button, istouch, presses)
    if button ~= 1 then return end

    if self.showGameOverPopup then
        self:handleGameOverPopupClick(x, y)
        return
    end

    -- Do not allow user input during AI's turn.
    if self.aiOpponent and self.gameManager.currentPlayer == 2 then
        return
    end
    
    InputSystem.mousepressed(self, x, y, button, istouch, presses)
end

--------------------------------------------------
-- handleGameOverPopupClick: Process clicks on the game over popup buttons.
-- Only "Restart" and "Main Menu" are available.
--------------------------------------------------
function Gameplay:handleGameOverPopupClick(x, y)
    for btnText, area in pairs(self.popupButtons) do
        if x >= area.x and x <= area.x + area.width and
           y >= area.y and y <= area.y + area.height then
            if btnText == "Restart" then
                -- Restart the current gameplay scene.
                self.changeSceneCallback("gameplay", self.selectedDeck, self.selectedBoard, self.aiOpponent)
            elseif btnText == "Main Menu" then
                self.changeSceneCallback("mainmenu")
            end
        end
    end
end

--------------------------------------------------
-- endTurn: Custom end turn function that handles the AI turn timer.
--------------------------------------------------
function Gameplay:endTurn()
    self.gameManager:endTurn()
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
