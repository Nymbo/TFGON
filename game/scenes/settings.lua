-- game/scenes/settings.lua
-- This scene provides a Master Volume slider for adjusting the game's overall sound.
-- It also includes a "Back" button to return to the main menu.
-- The slider value (0 to 1) is applied using love.audio.setVolume.

local Settings = {}
Settings.__index = Settings

--------------------------------------------------
-- Constructor for the Settings scene.
-- Accepts a changeSceneCallback to switch scenes.
--------------------------------------------------
function Settings:new(changeSceneCallback)
    local self = setmetatable({}, Settings)
    
    self.changeSceneCallback = changeSceneCallback

    -- Get screen dimensions for layout
    self.screenWidth = love.graphics.getWidth()
    self.screenHeight = love.graphics.getHeight()

    -- Define slider properties:
    -- We'll place the slider horizontally centered.
    self.sliderX = self.screenWidth * 0.3            -- left position of the slider track
    self.sliderY = self.screenHeight * 0.5             -- vertical position of the slider track
    self.sliderWidth = self.screenWidth * 0.4          -- width of the slider track
    self.sliderHeight = 10                             -- height (thickness) of the slider track

    -- Initialize the slider value from the current master volume (0-1)
    self.sliderValue = love.audio.getVolume() or 1

    -- Flag to track if the slider knob is being dragged.
    self.dragging = false

    return self
end

--------------------------------------------------
-- update(dt):
-- Called each frame to update slider value when dragging.
--------------------------------------------------
function Settings:update(dt)
    -- If dragging, update sliderValue based on current mouse position.
    if self.dragging then
        local mx = love.mouse.getX()
        local value = (mx - self.sliderX) / self.sliderWidth
        -- Clamp the value between 0 and 1.
        if value < 0 then value = 0 end
        if value > 1 then value = 1 end
        self.sliderValue = value

        -- Apply the new master volume.
        love.audio.setVolume(self.sliderValue)
    else
        -- Ensure dragging is false if the left mouse button is not held.
        if not love.mouse.isDown(1) then
            self.dragging = false
        end
    end
end

--------------------------------------------------
-- draw():
-- Renders the Settings scene, including the title, slider,
-- current volume percentage, and a Back button.
--------------------------------------------------
function Settings:draw()
    -- Draw background.
    love.graphics.setColor(0.1, 0.1, 0.1, 1)
    love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)

    -- Draw the scene title.
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Settings", 0, self.screenHeight * 0.2, self.screenWidth, "center")

    -- Draw Master Volume text above the slider.
    local volumePercent = math.floor(self.sliderValue * 100)
    love.graphics.printf("Master Volume: " .. volumePercent .. "%", 0, self.sliderY - 40, self.screenWidth, "center")

    -- Draw the slider track (a grey rectangle).
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.rectangle("fill", self.sliderX, self.sliderY, self.sliderWidth, self.sliderHeight)

    -- Draw the slider knob as a white circle.
    local knobX = self.sliderX + self.sliderValue * self.sliderWidth
    local knobY = self.sliderY + self.sliderHeight / 2
    local knobRadius = self.sliderHeight * 2
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", knobX, knobY, knobRadius)

    -- Draw the Back button at the bottom.
    local buttonWidth = 200
    local buttonHeight = 40
    local buttonX = (self.screenWidth - buttonWidth) / 2
    local buttonY = self.screenHeight * 0.8
    love.graphics.setColor(0.8, 0.2, 0.2, 1)  -- Red button color.
    love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 5, 5)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Back", buttonX, buttonY + 10, buttonWidth, "center")
end

--------------------------------------------------
-- mousepressed(x, y, button, istouch, presses):
-- Handles mouse clicks for starting slider dragging and for the Back button.
--------------------------------------------------
function Settings:mousepressed(x, y, button, istouch, presses)
    if button ~= 1 then return end  -- Only handle left-click.

    -- Check if the click is within the slider track (allowing a little extra vertical padding).
    if x >= self.sliderX and x <= self.sliderX + self.sliderWidth and 
       y >= self.sliderY - 10 and y <= self.sliderY + self.sliderHeight + 10 then
        self.dragging = true
        return
    end

    -- Check if the Back button was clicked.
    local buttonWidth = 200
    local buttonHeight = 40
    local buttonX = (self.screenWidth - buttonWidth) / 2
    local buttonY = self.screenHeight * 0.8
    if x >= buttonX and x <= buttonX + buttonWidth and 
       y >= buttonY and y <= buttonY + buttonHeight then
        self.changeSceneCallback("mainmenu")
        return
    end
end

--------------------------------------------------
-- keypressed(key):
-- Allows the user to return to the main menu using the ESC key.
--------------------------------------------------
function Settings:keypressed(key)
    if key == "escape" then
        self.changeSceneCallback("mainmenu")
    end
end

return Settings
