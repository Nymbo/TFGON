-- game/scenes/gameplay.lua
-- Scene responsible for handling the main gameplay loop and drawing the board + hand.

local GameManager = require("game.managers.gamemanager")
local CardRenderer = require("game.ui.cardrenderer")
local BoardRenderer = require("game.ui.boardrenderer")

local Gameplay = {}
Gameplay.__index = Gameplay

function Gameplay:new(changeSceneCallback)
    local self = setmetatable({}, Gameplay)

    -- Create a new GameManager instance
    self.gameManager = GameManager:new()

    -- Store the callback so we can change scenes
    self.changeSceneCallback = changeSceneCallback

    -- Load the background image
    -- Make sure you have "Nymbo-TFGON/assets/images/background.png" in place.
    self.background = love.graphics.newImage("assets/images/background.png")

    return self
end

function Gameplay:update(dt)
    -- Update the game logic (turn timers, etc.) if needed
    self.gameManager:update(dt)
end

function Gameplay:draw()
    -- 1) Draw the background
    if self.background then
        love.graphics.draw(self.background, 0, 0)
    else
        -- If no background image loaded for some reason,
        -- we clear the screen with a simple color
        love.graphics.clear(0.1, 0.1, 0.15, 1)
    end

    -- 2) Draw text from the game manager (turn info, HP, mana)
    self.gameManager:draw()

    -- 3) Draw the board with minions for both players
    BoardRenderer.drawBoard(self.gameManager.board)

    -- 4) Draw the current player's hand at the bottom
    local currentPlayer = self.gameManager:getCurrentPlayer()
    local hand = currentPlayer.hand

    local cardWidth, cardHeight = 100, 150
    local spacing = 10
    local totalWidth = #hand * (cardWidth + spacing)
    local startX = (love.graphics.getWidth() - totalWidth) / 2
    local cardY = love.graphics.getHeight() - cardHeight - 20

    for i, card in ipairs(hand) do
        local cardX = startX + (i - 1) * (cardWidth + spacing)
        CardRenderer.drawCard(card, cardX, cardY)
    end
end

function Gameplay:keypressed(key)
    -- Press space to end turn
    if key == "space" then
        self.gameManager:endTurn()
    -- Press escape to go back to main menu
    elseif key == "escape" then
        self.changeSceneCallback("mainmenu")
    end
end

function Gameplay:mousepressed(x, y, button, istouch, presses)
    if button == 1 then
        -- Left-click
        local currentPlayer = self.gameManager:getCurrentPlayer()
        local hand = currentPlayer.hand

        local cardWidth, cardHeight = 100, 150
        local spacing = 10
        local totalWidth = #hand * (cardWidth + spacing)
        local startX = (love.graphics.getWidth() - totalWidth) / 2
        local cardY = love.graphics.getHeight() - cardHeight - 20

        for i, card in ipairs(hand) do
            local cardX = startX + (i - 1) * (cardWidth + spacing)
            if x >= cardX and x <= cardX + cardWidth and
               y >= cardY and y <= cardY + cardHeight then

                -- If the player can afford it, this will remove it from hand and
                -- place it on the board (for Minions), or do placeholder logic for Spells/Weapons.
                self.gameManager:playCardFromHand(currentPlayer, i)
                break
            end
        end
    end
end

return Gameplay
