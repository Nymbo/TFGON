-- game/scenes/mainmenu.lua
-- A simple main menu scene. Supports background image, scaling, and clicking menu items.

local MainMenu = {}
MainMenu.__index = MainMenu

--------------------------------------------------
-- Helper function to scale and center a background
-- image so that it covers the entire screen area.
--------------------------------------------------
local function drawScaledBackground(image)
    local windowW, windowH = love.graphics.getWidth(), love.graphics.getHeight()
    local bgW, bgH = image:getWidth(), image:getHeight()

    -- "Cover" style scaling
    local scale = math.max(windowW / bgW, windowH / bgH)

    -- Calculate offsets to center the image
    local offsetX = (windowW - bgW * scale) / 2
    local offsetY = (windowH - bgH * scale) / 2

    love.graphics.draw(image, offsetX, offsetY, 0, scale, scale)
end

function MainMenu:new(changeSceneCallback)
    local self = setmetatable({}, MainMenu)

    self.changeSceneCallback = changeSceneCallback

    self.title = "The Fine Game of Nil"
    self.menuOptions = { "Play", "Exit" }
    self.selectedIndex = 1

    -- Load a background image (ensure the file exists in 'assets/images/')
    self.background = love.graphics.newImage("assets/images/mainmenu_background.png")

    return self
end

function MainMenu:update(dt)
    -- No complex logic for now
end

function MainMenu:draw()
    love.graphics.setColor(1, 1, 1, 1)  -- reset to white for the background
    if self.background then
        -- Draw the scaled, centered background
        drawScaledBackground(self.background)
    end

    -- Draw the title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(self.title, 0, 100, love.graphics.getWidth(), "center")

    -- Draw the menu options
    for i, option in ipairs(self.menuOptions) do
        local y = 200 + (i * 30)
        local color = {1, 1, 1, 1}
        if i == self.selectedIndex then
            color = {1, 1, 0, 1} -- highlight the current selection
        end
        love.graphics.setColor(color)
        love.graphics.printf(option, 0, y, love.graphics.getWidth(), "center")
    end

    -- Reset color to white
    love.graphics.setColor(1, 1, 1, 1)
end

function MainMenu:keypressed(key)
    if key == "down" then
        self.selectedIndex = self.selectedIndex + 1
        if self.selectedIndex > #self.menuOptions then
            self.selectedIndex = 1
        end
    elseif key == "up" then
        self.selectedIndex = self.selectedIndex - 1
        if self.selectedIndex < 1 then
            self.selectedIndex = #self.menuOptions
        end
    elseif key == "return" or key == "space" then
        self:activateMenuOption()
    end
end

-- Mouse support for menu selection
function MainMenu:mousepressed(x, y, button, istouch, presses)
    if button == 1 then
        -- Each option is rendered at y = 200 + (i * 30)
        -- We'll check if the mouse clicked within the bounding box for that option
        for i, option in ipairs(self.menuOptions) do
            local textY = 200 + (i * 30)
            local textHeight = 30  -- approximate area of each menu line

            if y >= textY and y <= textY + textHeight then
                self.selectedIndex = i
                self:activateMenuOption()
                break
            end
        end
    end
end

-- Activates whichever menu option is currently selected
function MainMenu:activateMenuOption()
    local selected = self.menuOptions[self.selectedIndex]
    if selected == "Play" then
        self.changeSceneCallback("gameplay")
    elseif selected == "Exit" then
        love.event.quit()
    end
end

return MainMenu
