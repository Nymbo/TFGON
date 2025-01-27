-- game/scenes/gameplay.lua
local GameManager = require("game.managers.gamemanager")
local CardRenderer = require("game.ui.cardrenderer")
local BoardRenderer = require("game.ui.boardrenderer")

local Gameplay = {}
Gameplay.__index = Gameplay

-- Button dimensions and styling
local END_TURN_BUTTON = {
    width = 120,
    height = 40,
    colors = {
        normal = {0.905, 0.298, 0.235, 1},    -- #e74c3c
        hover = {0.753, 0.224, 0.169, 1},     -- #c0392b
        text = {1, 1, 1, 1}
    }
}

function Gameplay:new(changeSceneCallback)
    local self = setmetatable({}, Gameplay)
    
    self.gameManager = GameManager:new()
    self.changeSceneCallback = changeSceneCallback
    self.background = love.graphics.newImage("assets/images/background.png")
    
    -- Track button state
    self.endTurnHovered = false
    
    return self
end

function Gameplay:update(dt)
    self.gameManager:update(dt)
    
    -- Update end turn button hover state
    local mx, my = love.mouse.getPosition()
    local buttonX = love.graphics.getWidth() - END_TURN_BUTTON.width - 20
    local buttonY = love.graphics.getHeight() / 2 - END_TURN_BUTTON.height / 2
    
    self.endTurnHovered = mx >= buttonX and mx <= buttonX + END_TURN_BUTTON.width and
                         my >= buttonY and my <= buttonY + END_TURN_BUTTON.height
end

function Gameplay:draw()
    -- Draw background at 50% opacity
    love.graphics.setColor(1, 1, 1, 0.5)
    if self.background then
        love.graphics.draw(self.background, 0, 0)
    end
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Draw the board state
    BoardRenderer.drawBoard(
        self.gameManager.board,
        self.gameManager.player1,
        self.gameManager.player2
    )
    
    -- Draw the current player's hand
    local currentPlayer = self.gameManager:getCurrentPlayer()
    local hand = currentPlayer.hand
    local cardWidth, cardHeight = CardRenderer.getCardDimensions()
    
    local totalWidth = #hand * (cardWidth + 10)  -- 10px spacing
    local startX = (love.graphics.getWidth() - totalWidth) / 2
    local cardY = love.graphics.getHeight() - cardHeight - 20
    
    for i, card in ipairs(hand) do
        local cardX = startX + (i - 1) * (cardWidth + 10)
        local isPlayable = card.cost <= currentPlayer.manaCrystals
        CardRenderer.drawCard(card, cardX, cardY, isPlayable)
    end
    
    -- Draw end turn button
    local buttonX = love.graphics.getWidth() - END_TURN_BUTTON.width - 20
    local buttonY = love.graphics.getHeight() / 2 - END_TURN_BUTTON.height / 2
    
    -- Button background
    love.graphics.setColor(self.endTurnHovered and END_TURN_BUTTON.colors.hover or 
                          END_TURN_BUTTON.colors.normal)
    love.graphics.rectangle("fill", buttonX, buttonY, END_TURN_BUTTON.width, 
                          END_TURN_BUTTON.height, 5, 5)
    
    -- Button text
    love.graphics.setColor(END_TURN_BUTTON.colors.text)
    love.graphics.printf("End Turn", buttonX, buttonY + 10, END_TURN_BUTTON.width, "center")
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

function Gameplay:mousepressed(x, y, button, istouch, presses)
    if button == 1 then  -- Left click
        -- Check end turn button
        local buttonX = love.graphics.getWidth() - END_TURN_BUTTON.width - 20
        local buttonY = love.graphics.getHeight() / 2 - END_TURN_BUTTON.height / 2
        
        if x >= buttonX and x <= buttonX + END_TURN_BUTTON.width and
           y >= buttonY and y <= buttonY + END_TURN_BUTTON.height then
            self.gameManager:endTurn()
            return
        end
        
        -- Check card clicks
        local currentPlayer = self.gameManager:getCurrentPlayer()
        local hand = currentPlayer.hand
        local cardWidth, cardHeight = CardRenderer.getCardDimensions()
        
        local totalWidth = #hand * (cardWidth + 10)
        local startX = (love.graphics.getWidth() - totalWidth) / 2
        local cardY = love.graphics.getHeight() - cardHeight - 60
        
        for i, card in ipairs(hand) do
            local cardX = startX + (i - 1) * (cardWidth + 10)
            if x >= cardX and x <= cardX + cardWidth and
               y >= cardY and y <= cardY + cardHeight and
               card.cost <= currentPlayer.manaCrystals then
                self.gameManager:playCardFromHand(currentPlayer, i)
                break
            end
        end
    end
end

function Gameplay:keypressed(key)
    if key == "escape" then
        self.changeSceneCallback("mainmenu")
    end
end

return Gameplay