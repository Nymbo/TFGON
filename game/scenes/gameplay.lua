-- game/scenes/gameplay.lua
local GameManager = require("game.managers.gamemanager")
local CardRenderer = require("game.ui.cardrenderer")

local Gameplay = {}
Gameplay.__index = Gameplay

function Gameplay:new(changeSceneCallback)
    local self = setmetatable({}, Gameplay)
    self.gameManager = GameManager:new()
    self.changeSceneCallback = changeSceneCallback
    return self
end

function Gameplay:update(dt)
    self.gameManager:update(dt)
end

function Gameplay:draw()
    -- Draw the main gameplay info
    self.gameManager:draw()

    -- Let's draw the current player's hand at the bottom
    local currentPlayer = self.gameManager:getCurrentPlayer()
    local hand = currentPlayer.hand

    -- Card dimensions
    local cardWidth, cardHeight = 100, 150
    local spacing = 10

    -- Calculate total width of the row of cards
    local totalWidth = #hand * (cardWidth + spacing)

    -- Center it horizontally
    local startX = (love.graphics.getWidth() - totalWidth) / 2
    -- Position near the bottom (20 px above the bottom edge, for instance)
    local cardY = love.graphics.getHeight() - cardHeight - 20

    for i, card in ipairs(hand) do
        local cardX = startX + (i-1) * (cardWidth + spacing)
        CardRenderer.drawCard(card, cardX, cardY)
    end
end

function Gameplay:keypressed(key)
    -- Press space to end turn (for quick testing)
    if key == "space" then
        self.gameManager:endTurn()
    end

    -- Press escape to go back to main menu (if you wish)
    if key == "escape" then
        self.changeSceneCallback("mainmenu")
    end
end

-- NEW: Handle left-click on a card in the player's hand
function Gameplay:mousepressed(x, y, button, istouch, presses)
    if button == 1 then
        local currentPlayer = self.gameManager:getCurrentPlayer()
        local hand = currentPlayer.hand

        local cardWidth, cardHeight = 100, 150
        local spacing = 10
        local totalWidth = #hand * (cardWidth + spacing)
        local startX = (love.graphics.getWidth() - totalWidth) / 2
        local cardY = love.graphics.getHeight() - cardHeight - 20

        for i, card in ipairs(hand) do
            local cardX = startX + (i-1) * (cardWidth + spacing)
            -- Check if the click is within this card's rectangle
            if x >= cardX and x <= cardX + cardWidth and
               y >= cardY and y <= cardY + cardHeight then

                -- We clicked on this card! Attempt to play it
                self.gameManager:playCardFromHand(currentPlayer, i)
                break
            end
        end
    end
end

return Gameplay
