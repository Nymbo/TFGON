-- game/scenes/deckselection.lua
-- Deck selection scene with unified Theme styling and board selection
-- Now with AI opponent option
-- UPDATED with error logging

local DeckSelection = {}
DeckSelection.__index = DeckSelection

local DeckManager = require("game.managers.deckmanager")
local BoardRegistry = require("game.core.boardregistry")
local Theme = require("game.ui.theme")
local ErrorLog = require("game.utils.errorlog")

--------------------------------------------------
-- Constructor for the DeckSelection scene
--------------------------------------------------
function DeckSelection:new(changeSceneCallback)
    local self = setmetatable({}, DeckSelection)
    
    ErrorLog.logError("DeckSelection scene initialization started", true)
    
    self.changeSceneCallback = changeSceneCallback
    
    -- Ensure decks are loaded
    DeckManager:init()
    self.decks = DeckManager.decks
    self.selectedDeckIndex = 1
    
    -- Initialize board selection
    self.selectedBoardIndex = 1
    self.boards = BoardRegistry.boards

    -- Add AI opponent option
    self.aiOpponent = true  -- Default to enabled

    -- Load background image
    local bgPath = "assets/images/mainmenu_background.png"
    if love.filesystem.getInfo(bgPath) then
        ErrorLog.logError("Loading background image: " .. bgPath, true)
        self.background = love.graphics.newImage(bgPath)
    else
        ErrorLog.logError("Background image not found: " .. bgPath)
        -- Create a placeholder background
        self.background = love.graphics.newCanvas(800, 600)
        love.graphics.setCanvas(self.background)
        love.graphics.clear(0.1, 0.1, 0.1, 1)
        love.graphics.setCanvas()
    end

    -- Screen dimensions
    self.screenWidth = love.graphics.getWidth()
    self.screenHeight = love.graphics.getHeight()

    -- Calculate panel dimensions (centered panel)
    self.panelWidth = self.screenWidth * 0.5
    self.panelHeight = self.screenHeight * 0.7
    self.panelX = (self.screenWidth - self.panelWidth) / 2
    self.panelY = (self.screenHeight - self.panelHeight) / 2

    -- Button dimensions from Theme
    self.buttonWidth = Theme.dimensions.buttonWidth * 1.5  -- Slightly wider buttons
    self.buttonHeight = Theme.dimensions.buttonHeight
    self.buttonSpacing = 20
    
    -- Board selector dimensions and state
    self.boardSelectorRadius = 120
    self.boardSelectorCenterX = self.panelX + self.panelWidth * 0.75
    self.boardSelectorCenterY = self.panelY + self.panelHeight * 0.45
    self.boardItemRadius = 40
    self.boardHoveredIndex = nil

    ErrorLog.logError("DeckSelection scene initialized successfully", true)
    
    return self
end

--------------------------------------------------
-- update: Check button hover states
--------------------------------------------------
function DeckSelection:update(dt)
    local mx, my = love.mouse.getPosition()
    
    -- Update hover states for buttons
    self.playHovered = self:isPointInButton(mx, my, "play")
    self.backHovered = self:isPointInButton(mx, my, "back")
    
    -- Update hover state for AI option
    local checkboxX = self.panelX + 40
    local checkboxY = self:getButtonY("play") - 40
    local checkboxSize = 20
    self.aiCheckboxHovered = mx >= checkboxX and mx <= checkboxX + checkboxSize and
                            my >= checkboxY and my <= checkboxY + checkboxSize
    
    -- Update hover state for board selector
    self.boardHoveredIndex = nil
    for i = 1, #self.boards do
        local angle = (i - 1) * (2 * math.pi / #self.boards)
        local itemX = self.boardSelectorCenterX + math.cos(angle) * self.boardSelectorRadius
        local itemY = self.boardSelectorCenterY + math.sin(angle) * self.boardSelectorRadius
        
        -- Check if mouse is hovering over this board item
        local dist = math.sqrt((mx - itemX)^2 + (my - itemY)^2)
        if dist <= self.boardItemRadius then
            self.boardHoveredIndex = i
            break
        end
    end
end

--------------------------------------------------
-- Helper: Check if point is within a button
--------------------------------------------------
function DeckSelection:isPointInButton(x, y, buttonType)
    local buttonY
    if buttonType == "play" then
        buttonY = self.panelY + self.panelHeight - self.buttonHeight * 2 - self.buttonSpacing
    else -- "back"
        buttonY = self.panelY + self.panelHeight - self.buttonHeight
    end
    local buttonX = (self.screenWidth - self.buttonWidth) / 2

    return x >= buttonX and x <= buttonX + self.buttonWidth and
           y >= buttonY and y <= buttonY + self.buttonHeight
end

--------------------------------------------------
-- Helper: Get button Y position
--------------------------------------------------
function DeckSelection:getButtonY(buttonType)
    if buttonType == "play" then
        return self.panelY + self.panelHeight - self.buttonHeight * 2 - self.buttonSpacing
    else -- "back"
        return self.panelY + self.panelHeight - self.buttonHeight
    end
end

--------------------------------------------------
-- Helper: Draw themed button
--------------------------------------------------
function DeckSelection:drawThemedButton(text, x, y, width, height, isHovered)
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
    love.graphics.setColor(Theme.colors.buttonBase)
    love.graphics.rectangle("fill", x, y, width, height, Theme.dimensions.buttonCornerRadius)
    love.graphics.setColor(Theme.colors.buttonGradientTop)
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

--------------------------------------------------
-- Helper: Draw scaled background
--------------------------------------------------
function DeckSelection:drawScaledBackground()
    local bgW, bgH = self.background:getWidth(), self.background:getHeight()
    local scale = math.max(self.screenWidth / bgW, self.screenHeight / bgH)
    local offsetX = (self.screenWidth - bgW * scale) / 2
    local offsetY = (self.screenHeight - bgH * scale) / 2
    
    -- Draw background with slight dimming
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.draw(self.background, offsetX, offsetY, 0, scale, scale)
end

--------------------------------------------------
-- draw: Render the deck selection scene
--------------------------------------------------
function DeckSelection:draw()
    -- Draw the background image
    self:drawScaledBackground()
    
    -- Semi-transparent overlay to ensure UI readability
    love.graphics.setColor(Theme.colors.background[1], Theme.colors.background[2], Theme.colors.background[3], 0.7)
    love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)

    -- Main panel background
    love.graphics.setColor(Theme.colors.backgroundLight)
    love.graphics.rectangle("fill", self.panelX, self.panelY, self.panelWidth, self.panelHeight, 10)
    
    -- Panel border
    love.graphics.setColor(Theme.colors.buttonBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", self.panelX, self.panelY, self.panelWidth, self.panelHeight, 10)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setFont(Theme.fonts.title)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.printf("Select Your Deck", 0, self.panelY + 30, self.screenWidth, "center")

    -- Draw deck slots
    local slotHeight = 50
    local slotSpacing = 10
    local slotsStartY = self.panelY + 120

    for i, deck in ipairs(self.decks) do
        local slotY = slotsStartY + (i-1) * (slotHeight + slotSpacing)
        local slotX = self.panelX + 40
        local slotWidth = self.panelWidth * 0.4 - 60  -- Narrower to make room for board selector
        
        -- Slot background
        love.graphics.setColor(i == self.selectedDeckIndex and Theme.colors.buttonHover or Theme.colors.buttonBase)
        love.graphics.rectangle("fill", slotX, slotY, slotWidth, slotHeight, 5)
        
        -- Slot border
        if i == self.selectedDeckIndex then
            love.graphics.setColor(Theme.colors.buttonBorder)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", slotX, slotY, slotWidth, slotHeight, 5)
            love.graphics.setLineWidth(1)
        end

        -- Deck name and card count
        love.graphics.setFont(Theme.fonts.body)
        love.graphics.setColor(i == self.selectedDeckIndex and Theme.colors.textHover or Theme.colors.textPrimary)
        local deckText = string.format("%s (%d/20 cards)", deck.name, #deck.cards)
        love.graphics.printf(
            deckText,
            slotX + 10,
            slotY + (slotHeight - Theme.fonts.body:getHeight())/2,
            slotWidth - 20,
            "left"
        )
    end

    -- Draw the board selector section
    love.graphics.setFont(Theme.fonts.subtitle)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.printf("Select Board", self.boardSelectorCenterX - 150, self.panelY + 130, 300, "center")
    
    -- Draw center label with selected board name
    love.graphics.setFont(Theme.fonts.body)
    love.graphics.setColor(Theme.colors.textHover)
    love.graphics.printf(
        self.boards[self.selectedBoardIndex].name,
        self.boardSelectorCenterX - 100,
        self.boardSelectorCenterY - 10,
        200,
        "center"
    )
    
    -- Draw the board selector ring
    love.graphics.setColor(Theme.colors.buttonBorder)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", self.boardSelectorCenterX, self.boardSelectorCenterY, self.boardSelectorRadius)
    
    -- Draw board options around the circle
    for i = 1, #self.boards do
        local angle = (i - 1) * (2 * math.pi / #self.boards)
        local itemX = self.boardSelectorCenterX + math.cos(angle) * self.boardSelectorRadius
        local itemY = self.boardSelectorCenterY + math.sin(angle) * self.boardSelectorRadius
        
        -- Draw board item circle
        local isSelected = (i == self.selectedBoardIndex)
        local isHovered = (i == self.boardHoveredIndex)
        
        -- Glow effect for hover/selection
        if isSelected or isHovered then
            love.graphics.setColor(Theme.colors.buttonGlowHover)
            love.graphics.circle("fill", itemX, itemY, self.boardItemRadius + 5)
        end
        
        -- Board item background
        love.graphics.setColor(isSelected and Theme.colors.buttonBorder or Theme.colors.buttonBase)
        love.graphics.circle("fill", itemX, itemY, self.boardItemRadius)
        
        -- Draw board number
        love.graphics.setFont(Theme.fonts.body)
        love.graphics.setColor(Theme.colors.textPrimary)
        local str = tostring(i)
        local textWidth = Theme.fonts.body:getWidth(str)
        local textHeight = Theme.fonts.body:getHeight()
        love.graphics.print(str, itemX - textWidth/2, itemY - textHeight/2)
    end
    
    -- Draw AI opponent checkbox
    local checkboxX = self.panelX + 40
    local checkboxY = self:getButtonY("play") - 40
    local checkboxSize = 20
    
    -- Checkbox outline (with glow when hovered)
    if self.aiCheckboxHovered then
        love.graphics.setColor(Theme.colors.buttonGlowHover)
        love.graphics.rectangle("fill", 
            checkboxX - 2, 
            checkboxY - 2, 
            checkboxSize + 4, 
            checkboxSize + 4, 
            3)
    end
    
    love.graphics.setColor(Theme.colors.buttonBorder)
    love.graphics.rectangle("line", checkboxX, checkboxY, checkboxSize, checkboxSize, 3)
    
    -- Checkbox fill if selected
    if self.aiOpponent then
        love.graphics.setColor(Theme.colors.buttonBorder)
        love.graphics.rectangle("fill", checkboxX + 3, checkboxY + 3, checkboxSize - 6, checkboxSize - 6, 2)
    end
    
    -- Checkbox label
    love.graphics.setFont(Theme.fonts.body)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.print("Play against AI", checkboxX + checkboxSize + 10, checkboxY + (checkboxSize - Theme.fonts.body:getHeight()) / 2)
    
    -- Draw buttons
    local buttonX = (self.screenWidth - self.buttonWidth) / 2
    
    -- Play button
    self:drawThemedButton(
        "Play",
        buttonX,
        self:getButtonY("play"),
        self.buttonWidth,
        self.buttonHeight,
        self.playHovered
    )

    -- Back button
    self:drawThemedButton(
        "Back",
        buttonX,
        self:getButtonY("back"),
        self.buttonWidth,
        self.buttonHeight,
        self.backHovered
    )
    
    -- Draw board description below the board selector
    love.graphics.setFont(Theme.fonts.body)
    love.graphics.setColor(Theme.colors.textSecondary)
    love.graphics.printf(
        self.boards[self.selectedBoardIndex].description,
        self.boardSelectorCenterX - 150,
        self.boardSelectorCenterY + self.boardSelectorRadius + 20,
        300,
        "center"
    )
end

--------------------------------------------------
-- mousepressed: Handle mouse input
--------------------------------------------------
function DeckSelection:mousepressed(x, y, button, istouch, presses)
    if button ~= 1 then return end

    -- Check AI checkbox click
    local checkboxX = self.panelX + 40
    local checkboxY = self:getButtonY("play") - 40
    local checkboxSize = 20
    
    if x >= checkboxX and x <= checkboxX + checkboxSize and
       y >= checkboxY and y <= checkboxY + checkboxSize then
        self.aiOpponent = not self.aiOpponent
        return
    end

    -- Check deck slot clicks
    local slotHeight = 50
    local slotSpacing = 10
    local slotsStartY = self.panelY + 120
    local slotX = self.panelX + 40
    local slotWidth = self.panelWidth * 0.4 - 60  -- Same as in draw

    for i = 1, #self.decks do
        local slotY = slotsStartY + (i-1) * (slotHeight + slotSpacing)
        if x >= slotX and x <= slotX + slotWidth and
           y >= slotY and y <= slotY + slotHeight then
            self.selectedDeckIndex = i
            return
        end
    end
    
    -- Check board selector clicks
    for i = 1, #self.boards do
        local angle = (i - 1) * (2 * math.pi / #self.boards)
        local itemX = self.boardSelectorCenterX + math.cos(angle) * self.boardSelectorRadius
        local itemY = self.boardSelectorCenterY + math.sin(angle) * self.boardSelectorRadius
        
        local dist = math.sqrt((x - itemX)^2 + (y - itemY)^2)
        if dist <= self.boardItemRadius then
            self.selectedBoardIndex = i
            return
        end
    end

    -- Check button clicks
    if self:isPointInButton(x, y, "play") then
        -- Log what we're about to do
        ErrorLog.logError("Play button clicked - selected deck: " .. 
                       self.decks[self.selectedDeckIndex].name .. 
                       ", board: " .. self.boards[self.selectedBoardIndex].name ..
                       ", AI: " .. tostring(self.aiOpponent), true)
                       
        -- Check if the board has an imagePath and if it exists
        local boardConfig = self.boards[self.selectedBoardIndex]
        if boardConfig.imagePath and not love.filesystem.getInfo(boardConfig.imagePath) then
            ErrorLog.logError("WARNING: Board image not found: " .. boardConfig.imagePath)
            -- Remove the imagePath to avoid crashes
            boardConfig.imagePath = nil
        end
        
        -- Change to gameplay scene
        self.changeSceneCallback("gameplay", self.decks[self.selectedDeckIndex], self.boards[self.selectedBoardIndex], self.aiOpponent)
    elseif self:isPointInButton(x, y, "back") then
        ErrorLog.logError("Back button clicked - returning to main menu", true)
        self.changeSceneCallback("mainmenu")
    end
end

--------------------------------------------------
-- keypressed: Handle keyboard input
--------------------------------------------------
function DeckSelection:keypressed(key)
    if key == "escape" then
        self.changeSceneCallback("mainmenu")
    elseif key == "up" then
        self.selectedDeckIndex = math.max(1, self.selectedDeckIndex - 1)
    elseif key == "down" then
        self.selectedDeckIndex = math.min(#self.decks, self.selectedDeckIndex + 1)
    elseif key == "left" then
        self.selectedBoardIndex = (self.selectedBoardIndex - 2) % #self.boards + 1
    elseif key == "right" then
        self.selectedBoardIndex = self.selectedBoardIndex % #self.boards + 1
    elseif key == "space" then
        self.aiOpponent = not self.aiOpponent
    elseif key == "return" then
        if self.selectedDeckIndex > 0 then
            ErrorLog.logError("Enter key pressed - starting game with selected deck", true)
            self.changeSceneCallback("gameplay", self.decks[self.selectedDeckIndex], self.boards[self.selectedBoardIndex], self.aiOpponent)
        end
    end
end

return DeckSelection