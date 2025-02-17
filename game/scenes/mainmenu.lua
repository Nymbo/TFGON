-- game/scenes/mainmenu.lua
-- A simple main menu scene that supports a background image and menu navigation.
-- Updated so that the "Play" option now goes to the Deck Selection scene.

--------------------------------------------------
-- Table definition for MainMenu scene
--------------------------------------------------
local MainMenu = {}
MainMenu.__index = MainMenu

--------------------------------------------------
-- Helper function to scale and center a background image.
--------------------------------------------------
local function drawScaledBackground(image)
    local windowW, windowH = love.graphics.getWidth(), love.graphics.getHeight()
    local bgW, bgH = image:getWidth(), image:getHeight()
    local scale = math.max(windowW / bgW, windowH / bgH)
    local offsetX = (windowW - bgW * scale) / 2
    local offsetY = (windowH - bgH * scale) / 2
    love.graphics.draw(image, offsetX, offsetY, 0, scale, scale)
end

--------------------------------------------------
-- Constructor for the MainMenu scene.
--------------------------------------------------
function MainMenu:new(changeSceneCallback)
    local self = setmetatable({}, MainMenu)
    self.changeSceneCallback = changeSceneCallback
    self.title = "The Fine Game of Nil"
    -- Updated menu options: "Play" now leads to deck selection.
    self.menuOptions = { "Play", "Collection", "Exit" }
    self.selectedIndex = 1
    self.background = love.graphics.newImage("assets/images/mainmenu_background.png")
    return self
end

--------------------------------------------------
-- update: (No additional logic for now)
--------------------------------------------------
function MainMenu:update(dt) end

--------------------------------------------------
-- draw: Renders background, title, and menu options.
--------------------------------------------------
function MainMenu:draw()
    love.graphics.setColor(1, 1, 1, 1)
    if self.background then drawScaledBackground(self.background) end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(self.title, 0, 100, love.graphics.getWidth(), "center")
    for i, option in ipairs(self.menuOptions) do
        local y = 200 + (i * 30)
        local color = (i == self.selectedIndex) and {1, 1, 0, 1} or {1, 1, 1, 1}
        love.graphics.setColor(color)
        love.graphics.printf(option, 0, y, love.graphics.getWidth(), "center")
    end
    love.graphics.setColor(1, 1, 1, 1)
end

--------------------------------------------------
-- keypressed: Handles keyboard navigation.
--------------------------------------------------
function MainMenu:keypressed(key)
    if key == "down" then
        self.selectedIndex = self.selectedIndex + 1
        if self.selectedIndex > #self.menuOptions then self.selectedIndex = 1 end
    elseif key == "up" then
        self.selectedIndex = self.selectedIndex - 1
        if self.selectedIndex < 1 then self.selectedIndex = #self.menuOptions end
    elseif key == "return" or key == "space" then
        self:activateMenuOption()
    end
end

--------------------------------------------------
-- mousepressed: Handles mouse-based menu selection.
--------------------------------------------------
function MainMenu:mousepressed(x, y, button, istouch, presses)
    if button == 1 then
        for i, option in ipairs(self.menuOptions) do
            local textY = 200 + (i * 30)
            if y >= textY and y <= textY + 30 then
                self.selectedIndex = i
                self:activateMenuOption()
                break
            end
        end
    end
end

--------------------------------------------------
-- activateMenuOption: Switches scene based on selection.
--------------------------------------------------
function MainMenu:activateMenuOption()
    local selected = self.menuOptions[self.selectedIndex]
    if selected == "Play" then
        -- Go to Deck Selection scene instead of directly to gameplay.
        self.changeSceneCallback("deckselection")
    elseif selected == "Collection" then
        self.changeSceneCallback("collection")
    elseif selected == "Exit" then
        love.event.quit()
    end
end

return MainMenu
