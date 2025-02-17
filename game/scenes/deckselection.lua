-- game/scenes/deckselection.lua
-- This scene allows the player to choose one of their saved decks
-- before entering the game.

local DeckSelection = {}
DeckSelection.__index = DeckSelection

local DeckManager = require("game.managers.deckmanager")

--------------------------------------------------
-- Constructor for the DeckSelection scene.
--------------------------------------------------
function DeckSelection:new(changeSceneCallback)
    local self = setmetatable({}, DeckSelection)
    self.changeSceneCallback = changeSceneCallback
    -- Ensure decks are loaded
    DeckManager:init()
    self.decks = DeckManager.decks
    self.selectedDeckIndex = 1

    self.screenWidth = love.graphics.getWidth()
    self.screenHeight = love.graphics.getHeight()

    return self
end

--------------------------------------------------
-- update: (No dynamic updates needed for now)
--------------------------------------------------
function DeckSelection:update(dt) end

--------------------------------------------------
-- draw: Renders the list of decks and Play/Back buttons.
--------------------------------------------------
function DeckSelection:draw()
    love.graphics.setColor(0.1, 0.1, 0.1, 1)
    love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Select Your Deck", 0, 50, self.screenWidth, "center")

    local startY = 100
    local slotHeight = 40
    for i, deck in ipairs(self.decks) do
        if i == self.selectedDeckIndex then
            love.graphics.setColor(0, 1, 0, 1) -- highlighted in green
        else
            love.graphics.setColor(1, 1, 1, 1)
        end
        local text = deck.name .. " (" .. #deck.cards .. "/20 cards)"
        love.graphics.printf(text, 0, startY + (i-1) * slotHeight, self.screenWidth, "center")
    end

    -- Draw Play button
    local playButtonY = self.screenHeight - 100
    love.graphics.setColor(0.2, 0.8, 0.2, 1)
    love.graphics.rectangle("fill", self.screenWidth/2 - 100, playButtonY, 200, 40, 5, 5)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Play", self.screenWidth/2 - 100, playButtonY + 10, 200, "center")

    -- Draw Back button
    local backButtonY = playButtonY - 60
    love.graphics.setColor(0.8, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", self.screenWidth/2 - 100, backButtonY, 200, 40, 5, 5)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Back", self.screenWidth/2 - 100, backButtonY + 10, 200, "center")
end

--------------------------------------------------
-- mousepressed: Handles clicks for deck selection, Play, and Back.
--------------------------------------------------
function DeckSelection:mousepressed(x, y, button, istouch, presses)
    if button ~= 1 then return end

    local startY = 100
    local slotHeight = 40
    -- Check if a deck slot was clicked
    for i = 1, #self.decks do
        local slotY = startY + (i-1)*slotHeight
        if y >= slotY and y <= slotY + slotHeight then
            self.selectedDeckIndex = i
            return
        end
    end

    -- Check Play button (centered)
    local playButtonY = self.screenHeight - 100
    if x >= self.screenWidth/2 - 100 and x <= self.screenWidth/2 + 100 and y >= playButtonY and y <= playButtonY + 40 then
        -- Start game and pass the selected deck to gameplay
        self.changeSceneCallback("gameplay", self.decks[self.selectedDeckIndex])
        return
    end

    -- Check Back button
    local backButtonY = self.screenHeight - 160
    if x >= self.screenWidth/2 - 100 and x <= self.screenWidth/2 + 100 and y >= backButtonY and y <= backButtonY + 40 then
        self.changeSceneCallback("mainmenu")
        return
    end
end

--------------------------------------------------
-- keypressed: Pressing ESC returns to Main Menu.
--------------------------------------------------
function DeckSelection:keypressed(key)
    if key == "escape" then
        self.changeSceneCallback("mainmenu")
    end
end

return DeckSelection
