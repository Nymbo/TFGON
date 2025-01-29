-- game/scenes/gameplay.lua

--------------------------------------------------
-- Require necessary modules that manage and render
-- core aspects of the game (game logic, card visuals, etc.)
--------------------------------------------------
local GameManager = require("game.managers.gamemanager")      -- Handles overarching game logic (turns, mana, health, etc.)
local CardRenderer = require("game.ui.cardrenderer")          -- Handles how individual cards are drawn to the screen
local BoardRenderer = require("game.ui.boardrenderer")        -- Handles how the overall board is drawn to the screen (minions, players, etc.)

--------------------------------------------------
-- Table definition for Gameplay scene
--------------------------------------------------
local Gameplay = {}
Gameplay.__index = Gameplay

--------------------------------------------------
-- Button dimensions and styling
-- These define the size and colors (normal, hover, text)
-- for the 'End Turn' button on screen
--------------------------------------------------
local END_TURN_BUTTON = {
    width = 120,
    height = 40,
    colors = {
        normal = {0.905, 0.298, 0.235, 1},    -- #e74c3c (bright red)
        hover = {0.753, 0.224, 0.169, 1},     -- #c0392b (darker red when hovered)
        text = {1, 1, 1, 1}                  -- white text color
    }
}

--------------------------------------------------
-- Constants for minion dimensions and spacing
-- used when drawing or detecting interactions.
--------------------------------------------------
local MINION_WIDTH = 80
local MINION_HEIGHT = 100
local SPACING = 10

--------------------------------------------------
-- Helper function to scale and center a background
-- image so that it covers the entire screen area.
-- Also adjusts the image's alpha (transparency).
--------------------------------------------------
local function drawScaledBackground(image, alpha)
    alpha = alpha or 1
    local windowW, windowH = love.graphics.getWidth(), love.graphics.getHeight()
    local bgW, bgH = image:getWidth(), image:getHeight()

    -- "Cover" style scaling: use whichever scale is larger
    -- so the image can fully cover the screen.
    local scale = math.max(windowW / bgW, windowH / bgH)

    -- Calculate offsets to center the image after scaling
    local offsetX = (windowW - bgW * scale) / 2
    local offsetY = (windowH - bgH * scale) / 2

    -- Draw the background with desired alpha
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(image, offsetX, offsetY, 0, scale, scale)
    -- Reset color back to full white, opaque
    love.graphics.setColor(1, 1, 1, 1)
end

--------------------------------------------------
-- Constructor for the Gameplay scene.
-- Accepts a callback to change scenes (e.g., main menu).
-- Sets up the game manager and loads assets like a background image.
--------------------------------------------------
function Gameplay:new(changeSceneCallback)
    local self = setmetatable({}, Gameplay)
    
    self.gameManager = GameManager:new()      -- Creates a new GameManager instance
    self.changeSceneCallback = changeSceneCallback

    -- Load a background image for the board
    -- Make sure there's a file named 'background.png' in 'assets/images/'
    self.background = love.graphics.newImage("assets/images/background.png")
    
    -- State tracking for end turn button hover and selected attacker
    self.endTurnHovered = false
    self.selectedAttacker = nil
    
    return self
end

--------------------------------------------------
-- LOVE update function for the Gameplay scene.
-- Called every frame to handle real-time logic
-- such as hover detection for the End Turn button.
--------------------------------------------------
function Gameplay:update(dt)
    self.gameManager:update(dt)  -- Let the GameManager handle overall game logic each frame

    -- Check if the mouse is hovering over the end turn button
    local mx, my = love.mouse.getPosition()
    local buttonX = love.graphics.getWidth() - END_TURN_BUTTON.width - 20
    local buttonY = love.graphics.getHeight() / 2 - END_TURN_BUTTON.height / 2
    
    self.endTurnHovered = mx >= buttonX and mx <= buttonX + END_TURN_BUTTON.width and
                          my >= buttonY and my <= buttonY + END_TURN_BUTTON.height
end

--------------------------------------------------
-- LOVE draw function for the Gameplay scene.
-- Renders the background, the board, the player's hand,
-- and the 'End Turn' button along with other UI elements.
--------------------------------------------------
function Gameplay:draw()
    -- Draw scaled, centered background at 50% opacity
    if self.background then
        drawScaledBackground(self.background, 0.5)
    end

    -- Draw the board state (minions, health, mana, etc.)
    BoardRenderer.drawBoard(
        self.gameManager.board,
        self.gameManager.player1,
        self.gameManager.player2
    )
    
    -- Draw the current player's hand of cards
    local currentPlayer = self.gameManager:getCurrentPlayer()
    local hand = currentPlayer.hand
    local cardWidth, cardHeight = CardRenderer.getCardDimensions()
    
    -- Calculate how wide the hand will be when laid out
    local totalWidth = #hand * (cardWidth + 10)
    local startX = (love.graphics.getWidth() - totalWidth) / 2
    local cardY = love.graphics.getHeight() - cardHeight - 20
    
    -- Draw each card in hand
    for i, card in ipairs(hand) do
        local cardX = startX + (i - 1) * (cardWidth + 10)
        -- Check if the card is playable (cost <= player's available mana)
        local isPlayable = (card.cost <= currentPlayer.manaCrystals)
        CardRenderer.drawCard(card, cardX, cardY, isPlayable)
    end
    
    -- Draw the End Turn button
    local buttonX = love.graphics.getWidth() - END_TURN_BUTTON.width - 20
    local buttonY = love.graphics.getHeight() / 2 - END_TURN_BUTTON.height / 2
    
    -- Button background (change color if hovered)
    love.graphics.setColor(
        self.endTurnHovered and END_TURN_BUTTON.colors.hover or 
        END_TURN_BUTTON.colors.normal
    )
    love.graphics.rectangle("fill", buttonX, buttonY, END_TURN_BUTTON.width, 
                            END_TURN_BUTTON.height, 5, 5)  -- Rounded corners: 5
    
    -- Draw button text
    love.graphics.setColor(END_TURN_BUTTON.colors.text)
    love.graphics.printf("End Turn", buttonX, buttonY + 10, END_TURN_BUTTON.width, "center")
    
    -- Turn indicator text (shows whose turn it is)
    local turnIndicatorY = buttonY + END_TURN_BUTTON.height + 10
    local currentTurnText = (self.gameManager.currentPlayer == 1) and "Player 1's turn" 
                                                             or "Player 2's turn"
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(currentTurnText, buttonX, turnIndicatorY, END_TURN_BUTTON.width, "center")
    
    -- Reset the color to white (no transparency)
    love.graphics.setColor(1, 1, 1, 1)
end

--------------------------------------------------
-- Handles mouse presses for playing cards, attacking,
-- and ending the turn.
--------------------------------------------------
function Gameplay:mousepressed(x, y, button, istouch, presses)
    if button == 1 then  -- Left click
        -- Check if the user clicked the End Turn button
        local buttonX = love.graphics.getWidth() - END_TURN_BUTTON.width - 20
        local buttonY = love.graphics.getHeight() / 2 - END_TURN_BUTTON.height / 2
        
        if x >= buttonX and x <= buttonX + END_TURN_BUTTON.width and
           y >= buttonY and y <= buttonY + END_TURN_BUTTON.height then
            -- If the button is clicked, end the current turn
            self.gameManager:endTurn()
            return
        end
        
        -- Check if the user clicked a card in hand
        local currentPlayer = self.gameManager:getCurrentPlayer()
        local hand = currentPlayer.hand
        local cardWidth, cardHeight = CardRenderer.getCardDimensions()
        
        -- Calculate the area where the hand is drawn
        local totalWidth = #hand * (cardWidth + 10)
        local startX = (love.graphics.getWidth() - totalWidth) / 2
        local cardY = love.graphics.getHeight() - cardHeight - 60
        
        for i, card in ipairs(hand) do
            local cardX = startX + (i - 1) * (cardWidth + 10)
            -- Check card click boundaries and if player has enough mana
            if x >= cardX and x <= cardX + cardWidth and
               y >= cardY and y <= cardY + cardHeight and
               (card.cost <= currentPlayer.manaCrystals) then
                -- Play the card from hand if conditions are met
                self.gameManager:playCardFromHand(currentPlayer, i)
                break
            end
        end

        -- Attack handling: either select an attacker or choose a target
        local isPlayer1 = (currentPlayer == self.gameManager.player1)
        
        -- If no attacker is currently selected
        if not self.selectedAttacker then
            -- Check if a minion is clicked to set it as the attacker
            local minions, minionY = self:getPlayerMinionArea(currentPlayer)
            local startX = (love.graphics.getWidth() - (#minions * (MINION_WIDTH + SPACING))) / 2
            
            for i, minion in ipairs(minions) do
                local minionX = startX + (i - 1) * (MINION_WIDTH + SPACING)
                -- Check if the click is within the bounding box of a minion
                if self:isPointInRect(x, y, minionX, minionY, MINION_WIDTH, MINION_HEIGHT) then
                    -- Only allow selection if the minion can currently attack
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

            -- Check if the player's hero can attack (they have a weapon and haven't attacked yet)
            if currentPlayer.weapon and not currentPlayer.heroAttacked then
                local heroY = isPlayer1 and (love.graphics.getHeight() - 40) or 10
                -- If the hero is clicked
                if self:isPointInRect(x, y, 10, heroY, love.graphics.getWidth() - 20, 30) then
                    self.selectedAttacker = {
                        type = "hero",
                        player = currentPlayer
                    }
                end
            end
        else
            -- If an attacker (minion or hero) has been selected,
            -- then the next click is for choosing a target.
            local targetPlayer = self.gameManager:getEnemyPlayer(currentPlayer)
            local targetMinions = (targetPlayer == self.gameManager.player1)
                and self.gameManager.board.player1Minions
                or self.gameManager.board.player2Minions
            
            -- Check if the selected target is an enemy minion
            local _, targetMinionY = self:getPlayerMinionArea(targetPlayer)
            local targetStartX = (love.graphics.getWidth() - (#targetMinions * (MINION_WIDTH + SPACING))) / 2
            
            for i, minion in ipairs(targetMinions) do
                local minionX = targetStartX + (i - 1) * (MINION_WIDTH + SPACING)
                if self:isPointInRect(x, y, minionX, targetMinionY, MINION_WIDTH, MINION_HEIGHT) then
                    -- Resolve the attack on the enemy minion
                    self:resolveAttack(self.selectedAttacker, {type = "minion", minion = minion, index = i})
                    self.selectedAttacker = nil
                    return
                end
            end

            -- Check if the selected target is the enemy hero
            local targetHeroY = isPlayer1 and 10 or (love.graphics.getHeight() - 40)
            if self:isPointInRect(x, y, 10, targetHeroY, love.graphics.getWidth() - 20, 30) then
                -- Resolve the attack on the enemy hero
                self:resolveAttack(self.selectedAttacker, {type = "hero"})
                self.selectedAttacker = nil
                return
            end

            -- If none of the above targets were selected, reset the attacker selection
            self.selectedAttacker = nil
        end
    end
end

--------------------------------------------------
-- resolveAttack:
-- This function performs the actual attack logic
-- between an attacker (minion/hero) and a target (minion/hero).
--------------------------------------------------
function Gameplay:resolveAttack(attacker, target)
    local gameManager = self.gameManager
    local currentPlayer = gameManager:getCurrentPlayer()
    
    -- If the attacker is a minion
    if attacker.type == "minion" then
        local minion = attacker.minion
        -- Target is the hero
        if target.type == "hero" then
            local enemy = gameManager:getEnemyPlayer(currentPlayer)
            enemy.health = enemy.health - minion.attack    -- Reduce enemy hero's health
            minion.canAttack = false                       -- Minion can only attack once per turn
        else
            -- Target is another minion
            local targetMinion = target.minion
            -- Each minion damages the other
            targetMinion.currentHealth = targetMinion.currentHealth - minion.attack
            minion.currentHealth = minion.currentHealth - targetMinion.attack
            
            -- Remove the target minion if it has died
            if targetMinion.currentHealth <= 0 then
                local enemyMinions = (gameManager:getEnemyPlayer(currentPlayer) == gameManager.player1)
                    and gameManager.board.player1Minions
                    or gameManager.board.player2Minions
                table.remove(enemyMinions, target.index)
            end
            
            -- Remove the attacking minion if it has died
            if minion.currentHealth <= 0 then
                table.remove(
                    attacker.player == gameManager.player1 and gameManager.board.player1Minions
                    or gameManager.board.player2Minions,
                    attacker.index
                )
            end
        end
    -- If the attacker is a hero with a weapon
    elseif attacker.type == "hero" and currentPlayer.weapon then
        currentPlayer.heroAttacked = true                        -- Mark hero as having attacked
        local enemy = gameManager:getEnemyPlayer(currentPlayer)
        enemy.health = enemy.health - currentPlayer.weapon.attack -- Deal damage to the enemy hero
        currentPlayer.weapon.durability = currentPlayer.weapon.durability - 1
        
        -- If the weapon breaks (durability <= 0), remove it
        if currentPlayer.weapon.durability <= 0 then
            currentPlayer.weapon = nil
        end
    end
    
    -- Check if either hero has 0 or less health -> game ends
    if gameManager.player1.health <= 0 or gameManager.player2.health <= 0 then
        gameManager:endGame()
    end
end

--------------------------------------------------
-- keypressed handles keyboard inputs.
-- Press ESC to return to the main menu.
--------------------------------------------------
function Gameplay:keypressed(key)
    if key == "escape" then
        self.changeSceneCallback("mainmenu")
    end
end

--------------------------------------------------
-- Helper functions for managing and positioning minions
-- and checking if a point (x, y) is inside a rectangle.
--------------------------------------------------
function Gameplay:getPlayerMinionArea(player)
    local isPlayer1 = (player == self.gameManager.player1)
    -- Determine Y position for player minions
    local yPos = isPlayer1
        and math.floor(love.graphics.getHeight() * 0.6) + 10
        or math.floor(love.graphics.getHeight() * 0.25) + 10
    
    -- Return the list of minions for the given player
    local minions = isPlayer1 and self.gameManager.board.player1Minions 
                    or self.gameManager.board.player2Minions
    return minions, yPos
end

-- Simple utility to check if an (x, y) coordinate
-- is inside a rectangle defined by (rectX, rectY, width, height).
function Gameplay:isPointInRect(x, y, rectX, rectY, width, height)
    return x >= rectX and x <= rectX + width and y >= rectY and y <= rectY + height
end

return Gameplay
