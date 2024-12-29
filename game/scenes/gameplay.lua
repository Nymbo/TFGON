-- game/scenes/gameplay.lua
-- The main in-game scene, showing board + hand + text from GameManager.

local GameManager = require("game.managers.gamemanager")
local CardRenderer = require("game.ui.cardrenderer")

-- We'll create a simple BoardRenderer for method #2:
local BoardRenderer = {}

-- Draw each player's minions on the board in two rows
function BoardRenderer.drawBoard(board)
    local p1Minions = board.player1Minions
    local p2Minions = board.player2Minions

    -- Dimensions for minion placeholders
    local MINION_WIDTH = 80
    local MINION_HEIGHT = 80
    local SPACING = 10

    -- Player 1's row (bottom)
    local totalWidth1 = #p1Minions * (MINION_WIDTH + SPACING)
    local startX1 = (love.graphics.getWidth() - totalWidth1) / 2
    local y1 = love.graphics.getHeight()/2 + 50

    for i, minion in ipairs(p1Minions) do
        local x = startX1 + (i-1)*(MINION_WIDTH + SPACING)
        -- Draw a placeholder rectangle or image
        love.graphics.setColor(0.6, 0.8, 0.6, 1)
        love.graphics.rectangle("fill", x, y1, MINION_WIDTH, MINION_HEIGHT)

        -- Draw the minion's name, stats
        love.graphics.setColor(0, 0, 0)
        love.graphics.printf(
            minion.name .. "\n" .. minion.attack .. "/" .. minion.health,
            x, y1 + 20, MINION_WIDTH, "center"
        )
        love.graphics.setColor(1, 1, 1)
    end

    -- Player 2's row (top)
    local totalWidth2 = #p2Minions * (MINION_WIDTH + SPACING)
    local startX2 = (love.graphics.getWidth() - totalWidth2) / 2
    local y2 = love.graphics.getHeight()/2 - (MINION_HEIGHT + 50)

    for i, minion in ipairs(p2Minions) do
        local x = startX2 + (i-1)*(MINION_WIDTH + SPACING)
        love.graphics.setColor(0.8, 0.6, 0.6, 1)
        love.graphics.rectangle("fill", x, y2, MINION_WIDTH, MINION_HEIGHT)

        love.graphics.setColor(0, 0, 0)
        love.graphics.printf(
            minion.name .. "\n" .. minion.attack .. "/" .. minion.health,
            x, y2 + 20, MINION_WIDTH, "center"
        )
        love.graphics.setColor(1, 1, 1)
    end
end

------------------------------------------------
-- Actual Gameplay scene
------------------------------------------------
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
    -- Clear the screen with a dark color or background
    love.graphics.clear(0.1, 0.1, 0.15, 1)

    -- Draw the basic game info (turn, HP, mana)
    self.gameManager:draw()

    -- Draw the minions on the board (Method #2 approach)
    BoardRenderer.drawBoard(self.gameManager.board)

    -- Now draw the current player's hand at the bottom
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
    -- Press escape to return to main menu
    elseif key == "escape" then
        self.changeSceneCallback("mainmenu")
    end
end

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
            local cardX = startX + (i-1)*(cardWidth + spacing)
            -- Check if the click is within this card's rectangle
            if x >= cardX and x <= cardX + cardWidth and
               y >= cardY and y <= cardY + cardHeight then

                -- Play that card (if mana is sufficient)
                self.gameManager:playCardFromHand(currentPlayer, i)
                break
            end
        end
    end
end

return Gameplay
