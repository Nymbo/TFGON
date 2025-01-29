-- game/scenes/mainmenu.lua
-- A simple main menu scene. It supports displaying a background image,
-- scaling it to cover the whole screen, and allows navigating menu
-- items via keyboard or mouse.

--------------------------------------------------
-- Table definition for MainMenu scene
--------------------------------------------------
local MainMenu = {}
MainMenu.__index = MainMenu

--------------------------------------------------
-- Helper function to scale and center a background
-- image so that it covers the entire screen area.
--
-- 'Cover' style means we choose whichever scale
-- dimension is bigger so that the image will fill
-- the screen without leaving black bars.
--------------------------------------------------
local function drawScaledBackground(image)
    local windowW, windowH = love.graphics.getWidth(), love.graphics.getHeight()
    local bgW, bgH = image:getWidth(), image:getHeight()

    -- Determine how much to scale based on screen vs. image size
    local scale = math.max(windowW / bgW, windowH / bgH)

    -- Offset to center the image horizontally and vertically
    local offsetX = (windowW - bgW * scale) / 2
    local offsetY = (windowH - bgH * scale) / 2

    -- Draw the background image with the calculated scale and offsets
    love.graphics.draw(image, offsetX, offsetY, 0, scale, scale)
end

--------------------------------------------------
-- Constructor for the MainMenu scene.
-- The 'changeSceneCallback' is a function that allows
-- switching scenes (e.g., to the Gameplay scene).
--------------------------------------------------
function MainMenu:new(changeSceneCallback)
    local self = setmetatable({}, MainMenu)

    self.changeSceneCallback = changeSceneCallback  -- Store the callback function

    self.title = "The Fine Game of Nil"             -- Title text displayed at the top
    self.menuOptions = { "Play", "Exit" }           -- List of menu items
    self.selectedIndex = 1                          -- Which menu item is currently selected

    -- Load a background image for the main menu
    -- Make sure there's a file named 'mainmenu_background.png'
    -- in 'assets/images/'
    self.background = love.graphics.newImage("assets/images/mainmenu_background.png")

    return self
end

--------------------------------------------------
-- 'update' function called each frame (if needed).
-- Currently, there is no complex menu logic to update.
--------------------------------------------------
function MainMenu:update(dt)
    -- No complex logic for now
end

--------------------------------------------------
-- 'draw' function renders everything for the main menu,
-- including the background, title, and menu options.
--------------------------------------------------
function MainMenu:draw()
    -- Reset the color to white for drawing the background
    love.graphics.setColor(1, 1, 1, 1)
    
    -- If a background image is loaded, draw it scaled to fill the screen
    if self.background then
        drawScaledBackground(self.background)
    end

    -- Draw the title text in the middle of the screen, near the top
    love.graphics.setColor(1, 1, 1, 1)  -- white text
    love.graphics.printf(self.title, 0, 100, love.graphics.getWidth(), "center")

    -- Draw the menu options (e.g., "Play", "Exit")
    for i, option in ipairs(self.menuOptions) do
        local y = 200 + (i * 30)           -- Vertical position for each option
        local color = {1, 1, 1, 1}        -- Default text color is white
        
        -- If this option is the currently selected one, highlight it (yellow)
        if i == self.selectedIndex then
            color = {1, 1, 0, 1}          -- Yellow color for highlighting
        end
        
        -- Apply chosen color and render the menu text
        love.graphics.setColor(color)
        love.graphics.printf(option, 0, y, love.graphics.getWidth(), "center")
    end

    -- Reset color to white afterward
    love.graphics.setColor(1, 1, 1, 1)
end

--------------------------------------------------
-- 'keypressed' handles keyboard inputs for navigating
-- the menu: up/down to move selection, return/space to confirm.
--------------------------------------------------
function MainMenu:keypressed(key)
    if key == "down" then
        -- Move selection down through the menu options
        self.selectedIndex = self.selectedIndex + 1
        -- Wrap around if we go past the last option
        if self.selectedIndex > #self.menuOptions then
            self.selectedIndex = 1
        end
    elseif key == "up" then
        -- Move selection up through the menu options
        self.selectedIndex = self.selectedIndex - 1
        -- Wrap around if we go above the first option
        if self.selectedIndex < 1 then
            self.selectedIndex = #self.menuOptions
        end
    elseif key == "return" or key == "space" then
        -- Activate the selected menu option
        self:activateMenuOption()
    end
end

--------------------------------------------------
-- 'mousepressed' adds mouse-based support for the menu.
-- Clicking on an option will select and activate it.
--------------------------------------------------
function MainMenu:mousepressed(x, y, button, istouch, presses)
    if button == 1 then  -- Left click
        -- Calculate approximate bounding boxes for each menu option
        -- Then see if the click happened within one of them
        for i, option in ipairs(self.menuOptions) do
            local textY = 200 + (i * 30)
            local textHeight = 30  -- Approx. height for each line of menu text

            -- If the mouse click is within the vertical bounds of a menu item
            if y >= textY and y <= textY + textHeight then
                -- Update the selected menu item and activate it
                self.selectedIndex = i
                self:activateMenuOption()
                break
            end
        end
    end
end

--------------------------------------------------
-- 'activateMenuOption' is called whenever the user
-- confirms a menu choice (via keyboard or mouse).
--------------------------------------------------
function MainMenu:activateMenuOption()
    local selected = self.menuOptions[self.selectedIndex]
    
    if selected == "Play" then
        -- Switch to the gameplay scene
        self.changeSceneCallback("gameplay")
    elseif selected == "Exit" then
        -- Quit the LOVE app
        love.event.quit()
    end
end

return MainMenu
