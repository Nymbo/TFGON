-- game/scenes/deckselection.lua
-- Deck selection scene with unified Theme styling

local DeckSelection = {}
DeckSelection.__index = DeckSelection

local DeckManager = require("game.managers.deckmanager")
local Theme = require("game.ui.theme")

--------------------------------------------------
-- Constructor for the DeckSelection scene
--------------------------------------------------
function DeckSelection:new(changeSceneCallback)
    local self = setmetatable({}, DeckSelection)
    self.changeSceneCallback = changeSceneCallback
    
    -- Ensure decks are loaded
    DeckManager:init()
    self.decks = DeckManager.decks
    self.selectedDeckIndex = 1

    -- Load background image
    self.background = love.graphics.newImage("assets/images/mainmenu_background.png")

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
-- draw: Render the deck selection scene
--------------------------------------------------
--------------------------------------------------
-- Helper: Draw scaled background image
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
        local slotWidth = self.panelWidth - 80
        
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
end

--------------------------------------------------
-- mousepressed: Handle mouse input
--------------------------------------------------
function DeckSelection:mousepressed(x, y, button, istouch, presses)
    if button ~= 1 then return end

    -- Check deck slot clicks
    local slotHeight = 50
    local slotSpacing = 10
    local slotsStartY = self.panelY + 120
    local slotX = self.panelX + 40
    local slotWidth = self.panelWidth - 80

    for i = 1, #self.decks do
        local slotY = slotsStartY + (i-1) * (slotHeight + slotSpacing)
        if x >= slotX and x <= slotX + slotWidth and
           y >= slotY and y <= slotY + slotHeight then
            self.selectedDeckIndex = i
            return
        end
    end

    -- Check button clicks
    if self:isPointInButton(x, y, "play") then
        self.changeSceneCallback("gameplay", self.decks[self.selectedDeckIndex])
    elseif self:isPointInButton(x, y, "back") then
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
    elseif key == "return" or key == "space" then
        if self.selectedDeckIndex > 0 then
            self.changeSceneCallback("gameplay", self.decks[self.selectedDeckIndex])
        end
    end
end

return DeckSelection