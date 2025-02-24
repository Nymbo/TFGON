-- game/scenes/gameplay/gameplay.lua
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
local CombatSystem = require("game.scenes/gameplay.combat")
local BoardRenderer = require("game.ui.boardrenderer")
local AIManager = require("game.managers.aimanager")
local Theme = require("game.ui.theme")
local CardRenderer = require("game.ui.cardrenderer")
local Animation = require("game.managers.animation")  -- Import our Animation manager

-- Local helper function to draw a themed button (similar to settings.lua)
local function drawThemedButton(text, x, y, width, height, isHovered, isSelected)
    love.graphics.setColor(Theme.colors.buttonShadow)
    love.graphics.rectangle(
        "fill",
        x + Theme.dimensions.buttonShadowOffset,
        y + Theme.dimensions.buttonShadowOffset,
        width,
        height,
        Theme.dimensions.buttonCornerRadius
    )
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
    love.graphics.setColor(Theme.colors.buttonBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, width, height, Theme.dimensions.buttonCornerRadius)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(Theme.fonts.button)
    love.graphics.setColor(isHovered and Theme.colors.textHover or Theme.colors.textPrimary)
    love.graphics.printf(text, x, y + (height - Theme.fonts.button:getHeight())/2, width, "center")
end

-- Local function to update the position of a dragged card using manual momentum
-- (While dragging, we keep the manual update for responsiveness.)
local function updateDraggedCard(card, dt)
    local cardWidth, cardHeight = CardRenderer.getCardDimensions()
    local mx, my = love.mouse.getPosition()
    card.target_transform.x = mx - cardWidth / 2
    card.target_transform.y = my - cardHeight / 2
    -- Here you could add momentum-based logic; for now, we update directly.
    card.transform.x = card.target_transform.x
    card.transform.y = card.target_transform.y
end

local Gameplay = {}
Gameplay.__index = Gameplay

-- Constructor for Gameplay scene.
-- 'selectedDeck' is passed in from Deck Selection.
-- 'selectedBoard' is passed in from Deck Selection.
-- 'aiOpponent' enables the AI opponent.
function Gameplay:new(changeSceneCallback, selectedDeck, selectedBoard, aiOpponent)
    local self = setmetatable({}, Gameplay)
    
    self.selectedDeck = selectedDeck
    self.selectedBoard = selectedBoard
    self.aiOpponent = aiOpponent or false

    self.gameManager = GameManager:new(selectedDeck, selectedBoard)
    self.changeSceneCallback = changeSceneCallback
    self.selectedBoard = selectedBoard

    if self.aiOpponent then
        self.aiManager = AIManager:new(self.gameManager)
        if love.filesystem.getInfo("difficulty.txt") then
            local content = love.filesystem.read("difficulty.txt")
            local difficultyIndex = tonumber(content)
            if difficultyIndex then
                local difficultyMap = { [1] = "easy", [2] = "normal", [3] = "hard" }
                local difficulty = difficultyMap[difficultyIndex] or "normal"
                self.aiManager:setDifficulty(difficulty)
            end
        end
    end

    if selectedBoard and selectedBoard.imagePath and love.filesystem.getInfo(selectedBoard.imagePath) then
        self.background = love.graphics.newImage(selectedBoard.imagePath)
    else
        self.background = love.graphics.newImage("assets/images/background.png")
    end

    self.endTurnHovered = false
    self.selectedMinion = nil

    self.bannerImage = nil
    self.bannerText = ""
    self.bannerTimer = 0
    self.bannerDuration = 1.5

    -- FIX: Initialize bannerFont to avoid nil error.
    self.bannerFont = love.graphics.newFont("assets/fonts/InknutAntiqua-Regular.ttf", 16)

    self.gameManager.onTurnStart = function(whichPlayer)
        if whichPlayer == "player1" then
            self.bannerImage = love.graphics.newImage("assets/images/Ribbon_Blue_3Slides.png")
            self.bannerText = "YOUR TURN"
        else
            self.bannerImage = love.graphics.newImage("assets/images/Ribbon_Red_3Slides.png")
            local bannerMsg = self.aiOpponent and "AI OPPONENT'S TURN" or "OPPONENT'S TURN"
            self.bannerText = bannerMsg
        end
        self.bannerTimer = self.bannerDuration
    end

    self.showGameOverPopup = false
    self.gameOverWinner = nil
    self.gameManager.onGameOver = function(winner)
        self.showGameOverPopup = true
        self.gameOverWinner = winner
    end

    self.aiTurnTimer = 0
    self.aiTurnDelay = 0.5

    -- New properties for drag-and-drop
    self.draggedCard = nil
    self.draggedCardIndex = nil

    return self
end

function Gameplay:update(dt)
    self.gameManager:update(dt)
    self.endTurnHovered = InputSystem.checkEndTurnHover(self)

    if self.bannerTimer > 0 then
        self.bannerTimer = self.bannerTimer - dt
        if self.bannerTimer < 0 then self.bannerTimer = 0 end
    end

    if self.aiOpponent and self.gameManager.currentPlayer == 2 and not self.showGameOverPopup then
        self.aiTurnTimer = self.aiTurnTimer - dt
        if self.aiTurnTimer <= 0 then
            self.aiTurnTimer = self.aiTurnDelay
            self.aiManager:takeTurn()
        end
    end

    -- Update any active tweens.
    Animation.update(dt)

    -- If a card is being dragged, update its position.
    if self.draggedCard then
        updateDraggedCard(self.draggedCard, dt)
    end
end

function Gameplay:draw()
    DrawSystem.drawGameplayScene(self)

    -- Draw dragged card with 50% opacity.
    if self.draggedCard then
        love.graphics.setColor(1, 1, 1, 0.5)
        CardRenderer.drawCard(self.draggedCard, self.draggedCard.transform.x, self.draggedCard.transform.y, true)
        love.graphics.setColor(1, 1, 1, 1)
    end

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

    if self.showGameOverPopup then
        self:drawGameOverPopup()
    end
end

function Gameplay:drawGameOverPopup()
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local popupW, popupH = 400, 300
    local popupX = (screenW - popupW) / 2
    local popupY = (screenH - popupH) / 2

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    love.graphics.setColor(Theme.colors.backgroundLight)
    love.graphics.rectangle("fill", popupX, popupY, popupW, popupH, 10)
    love.graphics.setColor(Theme.colors.buttonBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", popupX, popupY, popupW, popupH, 10)
    love.graphics.setLineWidth(1)

    local gameOverTitle = "GAME OVER"
    love.graphics.setFont(Theme.fonts.title)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.printf(gameOverTitle, popupX, popupY + 40, popupW, "center")

    self.popupButtons = {}
    local buttonW, buttonH = 150, 50
    local spacing = 20
    local totalButtonsW = 2 * buttonW + spacing
    local startX = popupX + (popupW - totalButtonsW) / 2
    local buttonY = popupY + popupH - buttonH - 40

    local mx, my = love.mouse.getPosition()
    local buttons = {"Restart", "Main Menu"}
    for i, btnText in ipairs(buttons) do
        local btnX = startX + (i - 1) * (buttonW + spacing)
        local isHovered = mx >= btnX and mx <= btnX + buttonW and my >= buttonY and my <= buttonY + buttonH
        drawThemedButton(btnText, btnX, buttonY, buttonW, buttonH, isHovered, false)
        self.popupButtons[btnText] = {x = btnX, y = buttonY, width = buttonW, height = buttonH}
    end
end

function Gameplay:mousepressed(x, y, button, istouch, presses)
    if button ~= 1 then return end

    if self.showGameOverPopup then
        self:handleGameOverPopupClick(x, y)
        return
    end

    if self.aiOpponent and self.gameManager.currentPlayer == 2 then
        return
    end
    
    InputSystem.mousepressed(self, x, y, button, istouch, presses)
end

function Gameplay:handleGameOverPopupClick(x, y)
    for btnText, area in pairs(self.popupButtons) do
        if x >= area.x and x <= area.x + area.width and
           y >= area.y and y <= area.y + area.height then
            if btnText == "Restart" then
                self.changeSceneCallback("gameplay", self.selectedDeck, self.selectedBoard, self.aiOpponent)
            elseif btnText == "Main Menu" then
                self.changeSceneCallback("mainmenu")
            end
        end
    end
end

function Gameplay:endTurn()
    self.gameManager:endTurn()
    if self.aiOpponent and self.gameManager.currentPlayer == 2 then
        self.aiTurnTimer = self.aiTurnDelay
    end
end

function Gameplay:keypressed(key)
    if key == "escape" then
        self.changeSceneCallback("mainmenu")
    end
end

function Gameplay:resolveAttack(attacker, target)
    CombatSystem.resolveAttack(self, attacker, target)
end

return Gameplay
