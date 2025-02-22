-- game/scenes/settings.lua
-- Settings scene with unified Theme styling and matching layout
-- Now with AI difficulty settings
local Settings = {}
Settings.__index = Settings

local Theme = require("game.ui.theme")

--------------------------------------------------
-- Constructor for Settings scene
--------------------------------------------------
function Settings:new(changeSceneCallback)
    local self = setmetatable({}, Settings)
    self.changeSceneCallback = changeSceneCallback

    -- Load background image
    self.background = love.graphics.newImage("assets/images/mainmenu_background.png")

    -- Screen dimensions
    self.screenWidth = love.graphics.getWidth()
    self.screenHeight = love.graphics.getHeight()

    -- Calculate panel dimensions (matching deck selection)
    self.panelWidth = self.screenWidth * 0.5
    self.panelHeight = self.screenHeight * 0.7
    self.panelX = (self.screenWidth - self.panelWidth) / 2
    self.panelY = (self.screenHeight - self.panelHeight) / 2

    -- Slider settings
    self.sliderX = self.panelX + 100
    self.sliderY = self.panelY + self.panelHeight * 0.3
    self.sliderWidth = self.panelWidth - 200
    self.sliderValue = love.audio.getVolume() or 1
    self.dragging = false

    -- AI Difficulty settings
    self.difficulties = {"Easy", "Normal", "Hard"}
    
    -- Load saved difficulty or default to Normal
    self.selectedDifficulty = self:loadDifficultySetting() or 2  -- Index 2 is "Normal"
    
    -- Button dimensions from Theme
    self.buttonWidth = Theme.dimensions.buttonWidth * 1.5
    self.buttonHeight = Theme.dimensions.buttonHeight
    
    -- Tracking hover states
    self.difficultyButtonsHovered = {false, false, false}

    return self
end

--------------------------------------------------
-- Helper: Load difficulty setting from file
--------------------------------------------------
function Settings:loadDifficultySetting()
    if love.filesystem.getInfo("difficulty.txt") then
        local content = love.filesystem.read("difficulty.txt")
        local difficulty = tonumber(content)
        if difficulty and difficulty >= 1 and difficulty <= 3 then
            return difficulty
        end
    end
    return 2  -- Default to Normal if no valid setting found
end

--------------------------------------------------
-- Helper: Save difficulty setting to file
--------------------------------------------------
function Settings:saveDifficultySetting()
    love.filesystem.write("difficulty.txt", tostring(self.selectedDifficulty))
end

--------------------------------------------------
-- Helper: Draw scaled background image
--------------------------------------------------
function Settings:drawScaledBackground()
    local bgW, bgH = self.background:getWidth(), self.background:getHeight()
    local scale = math.max(self.screenWidth / bgW, self.screenHeight / bgH)
    local offsetX = (self.screenWidth - bgW * scale) / 2
    local offsetY = (self.screenHeight - bgH * scale) / 2
    
    -- Draw background with slight dimming
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.draw(self.background, offsetX, offsetY, 0, scale, scale)
end

--------------------------------------------------
-- Helper: Draw themed button
--------------------------------------------------
function Settings:drawThemedButton(text, x, y, width, height, isHovered, isSelected)
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

    -- Base and gradient (special color for selected buttons)
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

--------------------------------------------------
-- update: Handle slider dragging and button hover
--------------------------------------------------
function Settings:update(dt)
    local mx, my = love.mouse.getPosition()
    
    -- Update slider if dragging
    if self.dragging then
        local value = (mx - self.sliderX) / self.sliderWidth
        self.sliderValue = math.max(0, math.min(1, value))
        love.audio.setVolume(self.sliderValue)
    end

    -- Update button hover states
    local buttonX = (self.screenWidth - self.buttonWidth) / 2
    local backY = self.panelY + self.panelHeight - self.buttonHeight - 40
    self.backHovered = mx >= buttonX and mx <= buttonX + self.buttonWidth and
                      my >= backY and my <= backY + self.buttonHeight
                      
    -- Update difficulty button hover states
    local difficultyWidth = self.buttonWidth * 0.6
    local difficultySpacing = 20
    local totalWidth = (#self.difficulties * difficultyWidth) + ((#self.difficulties - 1) * difficultySpacing)
    local startX = (self.screenWidth - totalWidth) / 2
    local difficultyY = self.sliderY + 120
    
    for i = 1, #self.difficulties do
        local btnX = startX + (i-1) * (difficultyWidth + difficultySpacing)
        self.difficultyButtonsHovered[i] = mx >= btnX and mx <= btnX + difficultyWidth and
                                           my >= difficultyY and my <= difficultyY + self.buttonHeight
    end
end

--------------------------------------------------
-- draw: Render the settings scene
--------------------------------------------------
function Settings:draw()
    -- Draw background
    self:drawScaledBackground()
    
    -- Semi-transparent overlay
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
    love.graphics.printf("Settings", 0, self.panelY + 30, self.screenWidth, "center")

    -- Volume label and percentage
    local volumePercent = math.floor(self.sliderValue * 100)
    love.graphics.setFont(Theme.fonts.subtitle)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.printf(
        "Master Volume: " .. volumePercent .. "%",
        self.panelX,
        self.sliderY - 60,
        self.panelWidth,
        "center"
    )

    -- Draw slider track
    love.graphics.setColor(Theme.colors.sliderTrackBase)
    love.graphics.rectangle("fill", self.sliderX, self.sliderY, self.sliderWidth, Theme.dimensions.sliderHeight, 4)
    love.graphics.setColor(Theme.colors.sliderTrackTop)
    love.graphics.rectangle(
        "fill",
        self.sliderX + 2,
        self.sliderY + 2,
        self.sliderWidth - 4,
        Theme.dimensions.sliderHeight / 2,
        4
    )

    -- Draw slider knob
    local knobX = self.sliderX + self.sliderValue * self.sliderWidth
    local knobY = self.sliderY + Theme.dimensions.sliderHeight / 2

    -- Knob shadow
    love.graphics.setColor(Theme.colors.sliderKnobShadow)
    love.graphics.circle(
        "fill",
        knobX + Theme.dimensions.sliderShadowOffset,
        knobY + Theme.dimensions.sliderShadowOffset,
        Theme.dimensions.sliderKnobRadius
    )

    -- Knob glow when dragging
    if self.dragging then
        love.graphics.setColor(Theme.colors.sliderGlowDrag)
        love.graphics.circle(
            "fill",
            knobX,
            knobY,
            Theme.dimensions.sliderKnobRadius + Theme.dimensions.sliderGlowOffset
        )
    end

    -- Main knob
    love.graphics.setColor(Theme.colors.sliderKnob)
    love.graphics.circle("fill", knobX, knobY, Theme.dimensions.sliderKnobRadius)
    
    -- Knob shine
    love.graphics.setColor(Theme.colors.sliderKnobShine)
    love.graphics.circle(
        "fill",
        knobX - Theme.dimensions.sliderKnobRadius / 2,
        knobY - Theme.dimensions.sliderKnobRadius / 2,
        Theme.dimensions.sliderKnobRadius / 4
    )
    
    -- AI Difficulty section
    love.graphics.setFont(Theme.fonts.subtitle)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.printf(
        "AI Difficulty",
        self.panelX,
        self.sliderY + 60,
        self.panelWidth,
        "center"
    )
    
    -- Draw difficulty buttons
    local difficultyWidth = self.buttonWidth * 0.6
    local difficultySpacing = 20
    local totalWidth = (#self.difficulties * difficultyWidth) + ((#self.difficulties - 1) * difficultySpacing)
    local startX = (self.screenWidth - totalWidth) / 2
    local difficultyY = self.sliderY + 120
    
    for i = 1, #self.difficulties do
        local btnX = startX + (i-1) * (difficultyWidth + difficultySpacing)
        local isSelected = (i == self.selectedDifficulty)
        
        self:drawThemedButton(
            self.difficulties[i],
            btnX,
            difficultyY,
            difficultyWidth,
            self.buttonHeight,
            self.difficultyButtonsHovered[i],
            isSelected
        )
    end
    
    -- Difficulty description
    love.graphics.setFont(Theme.fonts.body)
    love.graphics.setColor(Theme.colors.textSecondary)
    
    local difficultyDescriptions = {
        "The AI will make basic moves and avoid complex strategies.",
        "The AI will play with balanced strategy and tactical decisions.",
        "The AI will aggressively target your tower and make optimal plays."
    }
    
    love.graphics.printf(
        difficultyDescriptions[self.selectedDifficulty],
        self.panelX + 50,
        difficultyY + self.buttonHeight + 20,
        self.panelWidth - 100,
        "center"
    )

    -- Back button
    local buttonX = (self.screenWidth - self.buttonWidth) / 2
    local backY = self.panelY + self.panelHeight - self.buttonHeight - 40
    self:drawThemedButton("Back", buttonX, backY, self.buttonWidth, self.buttonHeight, self.backHovered)
end

--------------------------------------------------
-- mousepressed: Handle mouse input
--------------------------------------------------
function Settings:mousepressed(x, y, button, istouch, presses)
    if button ~= 1 then return end

    -- Check for slider interaction
    local knobX = self.sliderX + self.sliderValue * self.sliderWidth
    local knobY = self.sliderY + Theme.dimensions.sliderHeight / 2
    
    if math.sqrt((x - knobX)^2 + (y - knobY)^2) <= Theme.dimensions.sliderKnobRadius + 10 then
        self.dragging = true
        return
    elseif x >= self.sliderX and x <= self.sliderX + self.sliderWidth and
           y >= self.sliderY - 10 and y <= self.sliderY + Theme.dimensions.sliderHeight + 10 then
        self.dragging = true
        self.sliderValue = (x - self.sliderX) / self.sliderWidth
        love.audio.setVolume(self.sliderValue)
        return
    end
    
    -- Check for difficulty button clicks
    local difficultyWidth = self.buttonWidth * 0.6
    local difficultySpacing = 20
    local totalWidth = (#self.difficulties * difficultyWidth) + ((#self.difficulties - 1) * difficultySpacing)
    local startX = (self.screenWidth - totalWidth) / 2
    local difficultyY = self.sliderY + 120
    
    for i = 1, #self.difficulties do
        local btnX = startX + (i-1) * (difficultyWidth + difficultySpacing)
        if x >= btnX and x <= btnX + difficultyWidth and
           y >= difficultyY and y <= difficultyY + self.buttonHeight then
            self.selectedDifficulty = i
            self:saveDifficultySetting()
            return
        end
    end

    -- Check for back button click
    local buttonX = (self.screenWidth - self.buttonWidth) / 2
    local backY = self.panelY + self.panelHeight - self.buttonHeight - 40
    if x >= buttonX and x <= buttonX + self.buttonWidth and
       y >= backY and y <= backY + self.buttonHeight then
        self:saveDifficultySetting()
        self.changeSceneCallback("mainmenu")
    end
end

--------------------------------------------------
-- mousereleased: Stop slider dragging
--------------------------------------------------
function Settings:mousereleased(x, y, button)
    if button == 1 then
        self.dragging = false
    end
end

--------------------------------------------------
-- keypressed: Handle keyboard input
--------------------------------------------------
function Settings:keypressed(key)
    if key == "escape" then
        self:saveDifficultySetting()
        self.changeSceneCallback("mainmenu")
    elseif key == "left" then
        self.selectedDifficulty = math.max(1, self.selectedDifficulty - 1)
        self:saveDifficultySetting()
    elseif key == "right" then
        self.selectedDifficulty = math.min(#self.difficulties, self.selectedDifficulty + 1)
        self:saveDifficultySetting()
    end
end

return Settings