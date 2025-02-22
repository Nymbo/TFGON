-- game/scenes/mainmenu.lua
-- A polished main menu scene with consistent button styling
-- Now with horizontally arranged buttons positioned higher on the screen

local MainMenu = {}
MainMenu.__index = MainMenu
local Theme = require("game.ui.theme")

--------------------------------------------------
-- Helper: Draw themed button
--------------------------------------------------
function MainMenu:drawThemedButton(text, x, y, width, height, isHovered)
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
-- Constructor for the MainMenu scene
--------------------------------------------------
function MainMenu:new(changeSceneCallback)
    local self = setmetatable({}, MainMenu)
    self.changeSceneCallback = changeSceneCallback
    self.menuOptions = { "Play", "Collection", "Settings", "Exit" }
    self.selectedIndex = 1
    self.background = love.graphics.newImage("assets/images/mainmenu_background.png")
    
    -- Screen dimensions
    self.screenWidth = love.graphics.getWidth()
    self.screenHeight = love.graphics.getHeight()
    
    -- Button dimensions
    self.buttonWidth = Theme.dimensions.buttonWidth * 1.2  -- Slightly wider buttons
    self.buttonHeight = Theme.dimensions.buttonHeight
    self.buttonSpacing = 20  -- Space between buttons
    
    -- Calculate total menu width for horizontal centering
    self.menuWidth = #self.menuOptions * (self.buttonWidth + self.buttonSpacing) - self.buttonSpacing
    
    -- Position buttons higher on the screen (10% from the top instead of middle)
    self.menuStartY = self.screenHeight * 0.1
    self.menuStartX = (self.screenWidth - self.menuWidth) / 2
    
    -- Initialize hover states for all buttons
    self.buttonHovered = {}
    for i = 1, #self.menuOptions do
        self.buttonHovered[i] = false
    end

    return self
end

--------------------------------------------------
-- Helper: Draw scaled background
--------------------------------------------------
function MainMenu:drawScaledBackground()
    local bgW, bgH = self.background:getWidth(), self.background:getHeight()
    local scale = math.max(self.screenWidth / bgW, self.screenHeight / bgH)
    local offsetX = (self.screenWidth - bgW * scale) / 2
    local offsetY = (self.screenHeight - bgH * scale) / 2
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.background, offsetX, offsetY, 0, scale, scale)
end

--------------------------------------------------
-- update: Check button hover states
--------------------------------------------------
function MainMenu:update(dt)
    local mx, my = love.mouse.getPosition()
    
    for i = 1, #self.menuOptions do
        local buttonX = self.menuStartX + (i-1) * (self.buttonWidth + self.buttonSpacing)
        local buttonY = self.menuStartY
        self.buttonHovered[i] = mx >= buttonX and mx <= buttonX + self.buttonWidth and
                               my >= buttonY and my <= buttonY + self.buttonHeight
    end
end

--------------------------------------------------
-- draw: Render the main menu
--------------------------------------------------
function MainMenu:draw()
    -- Draw background
    self:drawScaledBackground()
    
    -- Draw buttons in a horizontal line
    for i, option in ipairs(self.menuOptions) do
        local buttonX = self.menuStartX + (i-1) * (self.buttonWidth + self.buttonSpacing)
        local buttonY = self.menuStartY
        
        self:drawThemedButton(
            option,
            buttonX,
            buttonY,
            self.buttonWidth,
            self.buttonHeight,
            self.buttonHovered[i]
        )
    end
end

--------------------------------------------------
-- mousepressed: Handle mouse input
--------------------------------------------------
function MainMenu:mousepressed(x, y, button, istouch, presses)
    if button ~= 1 then return end
    
    for i, option in ipairs(self.menuOptions) do
        local buttonX = self.menuStartX + (i-1) * (self.buttonWidth + self.buttonSpacing)
        local buttonY = self.menuStartY
        
        if x >= buttonX and x <= buttonX + self.buttonWidth and
           y >= buttonY and y <= buttonY + self.buttonHeight then
            self:activateMenuOption(i)
            return
        end
    end
end

--------------------------------------------------
-- activateMenuOption: Handle menu selection
--------------------------------------------------
function MainMenu:activateMenuOption(index)
    local selected = self.menuOptions[index]
    if selected == "Play" then
        self.changeSceneCallback("deckselection")
    elseif selected == "Collection" then
        self.changeSceneCallback("collection")
    elseif selected == "Settings" then
        self.changeSceneCallback("settings")
    elseif selected == "Exit" then
        love.event.quit()
    end
end

--------------------------------------------------
-- keypressed: Handle keyboard navigation
--------------------------------------------------
function MainMenu:keypressed(key)
    if key == "left" then
        self.selectedIndex = ((self.selectedIndex - 2) % #self.menuOptions) + 1
    elseif key == "right" then
        self.selectedIndex = (self.selectedIndex % #self.menuOptions) + 1
    elseif key == "return" or key == "space" then
        self:activateMenuOption(self.selectedIndex)
    elseif key == "escape" then
        love.event.quit()
    end
end

return MainMenu