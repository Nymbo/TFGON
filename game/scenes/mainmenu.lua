-- game/scenes/mainmenu.lua
-- Simple main menu scene. No more direct require of SceneManager.

local MainMenu = {}
MainMenu.__index = MainMenu

function MainMenu:new(changeSceneCallback)
    local self = setmetatable({}, MainMenu)
    self.title = "Hearthstone-Style TCG Prototype"
    self.menuOptions = { "Play", "Exit" }
    self.selectedIndex = 1

    -- We store the callback function to change scenes
    self.changeSceneCallback = changeSceneCallback

    return self
end

function MainMenu:update(dt)
    -- No complex logic here for now
end

function MainMenu:draw()
    love.graphics.printf(self.title, 0, 100, love.graphics.getWidth(), "center")
    for i, option in ipairs(self.menuOptions) do
        local y = 200 + (i * 30)
        local color = {1, 1, 1, 1}
        if i == self.selectedIndex then
            color = {1, 1, 0, 1} -- highlight
        end
        love.graphics.setColor(color)
        love.graphics.printf(option, 0, y, love.graphics.getWidth(), "center")
    end
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
        local selected = self.menuOptions[self.selectedIndex]
        if selected == "Play" then
            -- Use the callback to change to gameplay
            self.changeSceneCallback("gameplay")
        elseif selected == "Exit" then
            love.event.quit()
        end
    end
end

return MainMenu
