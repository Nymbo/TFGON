-- game/scenes/mainmenu.lua
-- A simple main menu scene. It transitions into the gameplay scene or quits.

local MainMenu = {}
MainMenu.__index = MainMenu

function MainMenu:new(changeSceneCallback)
    local self = setmetatable({}, MainMenu)

    self.changeSceneCallback = changeSceneCallback

    self.title = "Hearthstone-Style TCG Prototype"
    self.menuOptions = { "Play", "Exit" }
    self.selectedIndex = 1

    return self
end

function MainMenu:update(dt)
    -- No complex logic for now
end

function MainMenu:draw()
    love.graphics.printf(self.title, 0, 100, love.graphics.getWidth(), "center")

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
        local selected = self.menuOptions[self.selectedIndex]
        if selected == "Play" then
            self.changeSceneCallback("gameplay")
        elseif selected == "Exit" then
            love.event.quit()
        end
    end
end

-- We don't need mousepressed for a simple keyboard menu, but you could add it.

return MainMenu
