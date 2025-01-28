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

local MINION_WIDTH = 80
local MINION_HEIGHT = 100
local SPACING = 10

function Gameplay:new(changeSceneCallback)
    local self = setmetatable({}, Gameplay)
    
    self.gameManager = GameManager:new()
    self.changeSceneCallback = changeSceneCallback
    self.background = love.graphics.newImage("assets/images/background.png")
    
    -- Track button state
    self.endTurnHovered = false
    self.selectedAttacker = nil
    
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

        -- Attack handling
        local currentPlayer = self.gameManager:getCurrentPlayer()
        local isPlayer1 = currentPlayer == self.gameManager.player1
        
        if not self.selectedAttacker then
            -- Check minion clicks
            local minions, minionY = self:getPlayerMinionArea(currentPlayer)
            local startX = (love.graphics.getWidth() - (#minions * (MINION_WIDTH + SPACING))) / 2
            
            for i, minion in ipairs(minions) do
                local minionX = startX + (i-1)*(MINION_WIDTH + SPACING)
                if self:isPointInRect(x, y, minionX, minionY, MINION_WIDTH, MINION_HEIGHT) then
                    if minion.canAttack then
                        self.selectedAttacker = {
                            type = "minion",
                            minion = minion,
                            index = i,
                            player = currentPlayer
                        }
                    end
                    return
                end
            end

            -- Check hero attack
            if currentPlayer.weapon and not currentPlayer.heroAttacked then
                local heroY = isPlayer1 and (love.graphics.getHeight() - 40) or 10
                if self:isPointInRect(x, y, 10, heroY, love.graphics.getWidth()-20, 30) then
                    self.selectedAttacker = {type = "hero", player = currentPlayer}
                end
            end
        else
            -- Handle target selection
            local targetPlayer = self.gameManager:getEnemyPlayer(currentPlayer)
            local targetMinions = targetPlayer == self.gameManager.player1 and 
                self.gameManager.board.player1Minions or self.gameManager.board.player2Minions
            
            -- Check minion targets
            local _, targetMinionY = self:getPlayerMinionArea(targetPlayer)
            local targetStartX = (love.graphics.getWidth() - (#targetMinions * (MINION_WIDTH + SPACING))) / 2
            
            for i, minion in ipairs(targetMinions) do
                local minionX = targetStartX + (i-1)*(MINION_WIDTH + SPACING)
                if self:isPointInRect(x, y, minionX, targetMinionY, MINION_WIDTH, MINION_HEIGHT) then
                    self:resolveAttack(self.selectedAttacker, {type = "minion", minion = minion, index = i})
                    self.selectedAttacker = nil
                    return
                end
            end

            -- Check hero target
            local targetHeroY = isPlayer1 and 10 or (love.graphics.getHeight() - 40)
            if self:isPointInRect(x, y, 10, targetHeroY, love.graphics.getWidth()-20, 30) then
                self:resolveAttack(self.selectedAttacker, {type = "hero"})
                self.selectedAttacker = nil
                return
            end

            self.selectedAttacker = nil
        end
    end
end

function Gameplay:resolveAttack(attacker, target)
    local gameManager = self.gameManager
    local currentPlayer = gameManager:getCurrentPlayer()
    
    if attacker.type == "minion" then
        local minion = attacker.minion
        if target.type == "hero" then
            local enemy = gameManager:getEnemyPlayer(currentPlayer)
            enemy.health = enemy.health - minion.attack
            minion.canAttack = false
        else
            local targetMinion = target.minion
            targetMinion.currentHealth = targetMinion.currentHealth - minion.attack
            minion.currentHealth = minion.currentHealth - targetMinion.attack
            
            -- Remove dead minions
            if targetMinion.currentHealth <= 0 then
                local enemyMinions = gameManager:getEnemyPlayer(currentPlayer) == gameManager.player1 and 
                    gameManager.board.player1Minions or gameManager.board.player2Minions
                table.remove(enemyMinions, target.index)
            end
            
            if minion.currentHealth <= 0 then
                table.remove(attacker.player == gameManager.player1 and 
                    gameManager.board.player1Minions or gameManager.board.player2Minions, attacker.index)
            end
        end
    elseif attacker.type == "hero" and currentPlayer.weapon then
        currentPlayer.heroAttacked = true
        local enemy = gameManager:getEnemyPlayer(currentPlayer)
        enemy.health = enemy.health - currentPlayer.weapon.attack
        currentPlayer.weapon.durability = currentPlayer.weapon.durability - 1
        
        if currentPlayer.weapon.durability <= 0 then
            currentPlayer.weapon = nil
        end
    end
    
    -- Check win condition
    if gameManager.player1.health <= 0 or gameManager.player2.health <= 0 then
        gameManager:endGame()
    end
end

function Gameplay:keypressed(key)
    if key == "escape" then
        self.changeSceneCallback("mainmenu")
    end
end

-- Helper functions
function Gameplay:getPlayerMinionArea(player)
    local isPlayer1 = player == self.gameManager.player1
    local yPos = isPlayer1 and math.floor(love.graphics.getHeight() * 0.6) + 10
        or math.floor(love.graphics.getHeight() * 0.25) + 10
    local minions = isPlayer1 and self.gameManager.board.player1Minions 
        or self.gameManager.board.player2Minions
    return minions, yPos
end

function Gameplay:isPointInRect(x, y, rectX, rectY, width, height)
    return x >= rectX and x <= rectX + width and y >= rectY and y <= rectY + height
end

return Gameplay