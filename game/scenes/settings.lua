-- game/scenes/settings.lua
-- Settings scene with a themed slider and button

local Settings = {}
Settings.__index = Settings

local Theme = require("game.ui.theme")  -- Import the theme

--------------------------------------------------
-- Constants using Theme
--------------------------------------------------
local BUTTON = {
    width = 220,  -- Override for larger button
    height = Theme.dimensions.buttonHeight,
    cornerRadius = Theme.dimensions.buttonCornerRadius,
    font = Theme.fonts.button,
    colors = Theme.colors,
    shadowOffset = Theme.dimensions.buttonShadowOffset,
    glowOffset = Theme.dimensions.buttonGlowOffset
}

local SLIDER = {
    width = Theme.dimensions.sliderWidth,
    height = Theme.dimensions.sliderHeight,
    knobRadius = Theme.dimensions.sliderKnobRadius,
    font = Theme.fonts.label,
    colors = Theme.colors,
    shadowOffset = Theme.dimensions.sliderShadowOffset,
    glowOffset = Theme.dimensions.sliderGlowOffset
}

function Settings:new(changeSceneCallback)
    local self = setmetatable({}, Settings)
    self.changeSceneCallback = changeSceneCallback

    self.screenWidth = love.graphics.getWidth()
    self.screenHeight = love.graphics.getHeight()

    self.sliderX = (self.screenWidth - SLIDER.width) / 2
    self.sliderY = self.screenHeight * 0.5
    self.sliderValue = love.audio.getVolume() or 1
    self.dragging = false

    return self
end

function Settings:update(dt)
    if self.dragging then
        local mx = love.mouse.getX()
        local value = (mx - self.sliderX) / SLIDER.width
        self.sliderValue = math.max(0, math.min(1, value))
        love.audio.setVolume(self.sliderValue)
    end
    if not love.mouse.isDown(1) then
        self.dragging = false
    end
end

function Settings:draw()
    love.graphics.setColor(Theme.colors.background)
    love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)

    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.setFont(BUTTON.font)
    love.graphics.printf("Settings", 0, self.screenHeight * 0.2, self.screenWidth, "center")

    local volumePercent = math.floor(self.sliderValue * 100)
    love.graphics.setColor(SLIDER.colors.textPrimary)
    love.graphics.setFont(SLIDER.font)
    love.graphics.printf("Master Volume: " .. volumePercent .. "%", 0, self.sliderY - 50, self.screenWidth, "center")

    love.graphics.setColor(SLIDER.colors.sliderTrackBase)
    love.graphics.rectangle("fill", self.sliderX, self.sliderY, SLIDER.width, SLIDER.height, 4)
    love.graphics.setColor(SLIDER.colors.sliderTrackTop)
    love.graphics.rectangle("fill", self.sliderX + 2, self.sliderY + 2, SLIDER.width - 4, SLIDER.height / 2, 4)

    local knobX = self.sliderX + self.sliderValue * SLIDER.width
    local knobY = self.sliderY + SLIDER.height / 2

    love.graphics.setColor(SLIDER.colors.sliderKnobShadow)
    love.graphics.circle("fill", knobX + SLIDER.shadowOffset, knobY + SLIDER.shadowOffset, SLIDER.knobRadius)

    if self.dragging then
        love.graphics.setColor(SLIDER.colors.sliderGlowDrag)
        love.graphics.circle("fill", knobX, knobY, SLIDER.knobRadius + SLIDER.glowOffset)
    end

    love.graphics.setColor(SLIDER.colors.sliderKnob)
    love.graphics.circle("fill", knobX, knobY, SLIDER.knobRadius)
    love.graphics.setColor(SLIDER.colors.sliderKnobShine)
    love.graphics.circle("fill", knobX - SLIDER.knobRadius / 2, knobY - SLIDER.knobRadius / 2, SLIDER.knobRadius / 4)

    local buttonX = (self.screenWidth - BUTTON.width) / 2
    local buttonY = self.screenHeight * 0.8
    local isHovered = love.mouse.getX() >= buttonX and love.mouse.getX() <= buttonX + BUTTON.width and
                      love.mouse.getY() >= buttonY and love.mouse.getY() <= buttonY + BUTTON.height

    love.graphics.setColor(BUTTON.colors.buttonShadow)
    love.graphics.rectangle(
        "fill",
        buttonX + BUTTON.shadowOffset,
        buttonY + BUTTON.shadowOffset,
        BUTTON.width,
        BUTTON.height,
        BUTTON.cornerRadius
    )

    if isHovered then
        love.graphics.setColor(BUTTON.colors.buttonGlowHover)
        love.graphics.rectangle(
            "fill",
            buttonX - BUTTON.glowOffset,
            buttonY - BUTTON.glowOffset,
            BUTTON.width + 2 * BUTTON.glowOffset,
            BUTTON.height + 2 * BUTTON.glowOffset,
            BUTTON.cornerRadius + 2
        )
    end

    love.graphics.setColor(BUTTON.colors.buttonBase)
    love.graphics.rectangle("fill", buttonX, buttonY, BUTTON.width, BUTTON.height, BUTTON.cornerRadius)
    love.graphics.setColor(BUTTON.colors.buttonGradientTop)
    love.graphics.rectangle("fill", buttonX + 2, buttonY + 2, BUTTON.width - 4, BUTTON.height / 2, BUTTON.cornerRadius)

    love.graphics.setColor(BUTTON.colors.buttonBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", buttonX, buttonY, BUTTON.width, BUTTON.height, BUTTON.cornerRadius)
    love.graphics.setLineWidth(1)

    love.graphics.setFont(BUTTON.font)
    love.graphics.setColor(isHovered and BUTTON.colors.textHover or BUTTON.colors.textPrimary)
    love.graphics.printf("Back", buttonX, buttonY + (BUTTON.height - BUTTON.font:getHeight()) / 2, BUTTON.width, "center")

    love.graphics.setColor(1, 1, 1, 1)
end

function Settings:mousepressed(x, y, button, istouch, presses)
    if button ~= 1 then return end

    local knobX = self.sliderX + self.sliderValue * SLIDER.width
    local knobY = self.sliderY + SLIDER.height / 2
    if math.sqrt((x - knobX)^2 + (y - knobY)^2) <= SLIDER.knobRadius + 10 then
        self.dragging = true
        return
    elseif x >= self.sliderX and x <= self.sliderX + SLIDER.width and
           y >= self.sliderY - 10 and y <= self.sliderY + SLIDER.height + 10 then
        self.dragging = true
        self.sliderValue = (x - self.sliderX) / SLIDER.width
        love.audio.setVolume(self.sliderValue)
        return
    end

    local buttonX = (self.screenWidth - BUTTON.width) / 2
    local buttonY = self.screenHeight * 0.8
    if x >= buttonX and x <= buttonX + BUTTON.width and y >= buttonY and y <= buttonY + BUTTON.height then
        self.changeSceneCallback("mainmenu")
    end
end

function Settings:keypressed(key)
    if key == "escape" then
        self.changeSceneCallback("mainmenu")
    end
end

return Settings