-- game/scenes/gameplay/GameOverManager.lua
-- Manages game over conditions and UI
-- Handles the game over popup and its interactions
-- Refactored to be fully event-based for tower destruction

local Theme = require("game.ui.theme")
local EventBus = require("game.eventbus")
local ErrorLog = require("game.utils.errorlog")

local GameOverManager = {}
GameOverManager.__index = GameOverManager

--------------------------------------------------
-- Constructor for GameOverManager
--------------------------------------------------
function GameOverManager:new(gameplayScene)
    local self = setmetatable({}, GameOverManager)
    self.gameplayScene = gameplayScene
    
    -- Storage for popup buttons
    self.popupButtons = {}
    
    -- Subscribe to events
    self.eventSubscriptions = {}
    self:initEventSubscriptions()
    
    return self
end

--------------------------------------------------
-- destroy: Clean up resources
--------------------------------------------------
function GameOverManager:destroy()
    -- Clean up event subscriptions
    for _, sub in ipairs(self.eventSubscriptions) do
        EventBus.unsubscribe(sub)
    end
    self.eventSubscriptions = {}
end

--------------------------------------------------
-- initEventSubscriptions: Set up event listeners
--------------------------------------------------
function GameOverManager:initEventSubscriptions()
    -- Subscribe to game ended event
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.GAME_ENDED,
        function(winner)
            self:handleGameOver(winner)
        end,
        "GameOverManager-GameEnded"
    ))
    
    -- Subscribe to tower destroyed event to check win condition
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.TOWER_DESTROYED,
        function(tower, destroyer)
            -- Check if this triggers game over
            self:checkGameOverCondition()
        end,
        "GameOverManager-TowerDestroyed"
    ))
end

--------------------------------------------------
-- checkGameOverCondition: Check if game is over
--------------------------------------------------
function GameOverManager:checkGameOverCondition()
    local gm = self.gameplayScene.gameManager
    
    -- If game is already over, don't check
    if self.gameplayScene.showGameOverPopup then
        return
    end
    
    -- Check if either player has no towers left
    if #gm.player1.towers == 0 or #gm.player2.towers == 0 then
        -- We no longer directly end the game here
        -- Instead, we publish an event that GameManager will handle
        EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "GameOverConditionMet")
    end
end

--------------------------------------------------
-- handleGameOver: Process game over event
--------------------------------------------------
function GameOverManager:handleGameOver(winner)
    ErrorLog.logError("Game over triggered. Winner: " .. (winner and winner.name or "none"), true)
    
    -- Set game over state
    self.gameplayScene.showGameOverPopup = true
    self.gameplayScene.gameOverWinner = winner
    
    -- Publish banner displayed event
    local winnerText = winner and winner.name .. " wins!" or "Game Over - Draw!"
    EventBus.publish(EventBus.Events.BANNER_DISPLAYED, "gameOver", winnerText)
end

--------------------------------------------------
-- drawGameOverPopup: Render game over UI
--------------------------------------------------
function GameOverManager:drawGameOverPopup()
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local popupW, popupH = 400, 300
    local popupX = (screenW - popupW) / 2
    local popupY = (screenH - popupH) / 2

    -- Darken the background
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Draw popup panel
    love.graphics.setColor(Theme.colors.backgroundLight)
    love.graphics.rectangle("fill", popupX, popupY, popupW, popupH, 10)
    love.graphics.setColor(Theme.colors.buttonBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", popupX, popupY, popupW, popupH, 10)
    love.graphics.setLineWidth(1)

    -- Draw game over title
    local gameOverTitle = "GAME OVER"
    love.graphics.setFont(Theme.fonts.title)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.printf(gameOverTitle, popupX, popupY + 40, popupW, "center")
    
    -- Draw winner text
    local winnerText
    if self.gameplayScene.gameOverWinner then
        winnerText = self.gameplayScene.gameOverWinner.name .. " wins!"
    else
        winnerText = "It's a draw!"
    end
    
    love.graphics.setFont(Theme.fonts.subtitle)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.printf(winnerText, popupX, popupY + 100, popupW, "center")

    -- Draw buttons
    self.popupButtons = {}
    local buttonW, buttonH = 150, 50
    local spacing = 20
    local totalButtonsW = 2 * buttonW + spacing
    local startX = popupX + (popupW - totalButtonsW) / 2
    local buttonY = popupY + popupH - buttonH - 40

    local mx, my = love.mouse.getPosition()
    local buttons = {"Restart", "Main Menu"}
    for i, btnText in ipairs(buttons) do
        local btnX = startX + (i - 1) * (buttonW + spacing)
        local isHovered = mx >= btnX and mx <= btnX + buttonW and my >= buttonY and my <= buttonY + buttonH
        
        -- Draw button with theme styling
        self:drawThemedButton(btnText, btnX, buttonY, buttonW, buttonH, isHovered, false)
        
        -- Store button data for click detection
        self.popupButtons[btnText] = {x = btnX, y = buttonY, width = buttonW, height = buttonH}
    end
end

--------------------------------------------------
-- drawThemedButton: Helper to draw themed button
--------------------------------------------------
function GameOverManager:drawThemedButton(text, x, y, width, height, isHovered, isSelected)
    -- Shadow
    love.graphics.setColor(Theme.colors.buttonShadow)
    love.graphics.rectangle(
        "fill",
        x + Theme.dimensions.buttonShadowOffset,
        y + Theme.dimensions.buttonShadowOffset,
        width,
        height,
        Theme.dimensions.buttonCornerRadius
    )

    -- Hover glow
    if isHovered then
        love.graphics.setColor(Theme.colors.buttonGlowHover)
        love.graphics.rectangle(
            "fill",
            x - Theme.dimensions.buttonGlowOffset,
            y - Theme.dimensions.buttonGlowOffset,
            width + 2 * Theme.dimensions.buttonGlowOffset,
            height + 2 * Theme.dimensions.buttonGlowOffset,
            Theme.dimensions.buttonCornerRadius + 2
        )
    end

    -- Base and gradient
    if isSelected then
        love.graphics.setColor(Theme.colors.buttonHover)
    else
        love.graphics.setColor(Theme.colors.buttonBase)
    end
    love.graphics.rectangle("fill", x, y, width, height, Theme.dimensions.buttonCornerRadius)
    
    if isSelected then
        love.graphics.setColor(Theme.colors.buttonGlowHover)
    else
        love.graphics.setColor(Theme.colors.buttonGradientTop)
    end
    love.graphics.rectangle("fill", x + 2, y + 2, width - 4, height/2 - 2, Theme.dimensions.buttonCornerRadius)

    -- Border
    love.graphics.setColor(Theme.colors.buttonBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, width, height, Theme.dimensions.buttonCornerRadius)
    love.graphics.setLineWidth(1)

    -- Text
    love.graphics.setFont(Theme.fonts.button)
    love.graphics.setColor(isHovered and Theme.colors.textHover or Theme.colors.textPrimary)
    love.graphics.printf(text, x, y + (height - Theme.fonts.button:getHeight())/2, width, "center")
end

--------------------------------------------------
-- handlePopupClick: Process clicks on game over popup
--------------------------------------------------
function GameOverManager:handlePopupClick(x, y)
    for btnText, area in pairs(self.popupButtons) do
        if x >= area.x and x <= area.x + area.width and
           y >= area.y and y <= area.y + area.height then
            if btnText == "Restart" then
                ErrorLog.logError("Restart game requested", true)
                
                -- Publish restart requested event
                EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "RestartRequested")
                
                self.gameplayScene.changeSceneCallback("gameplay", 
                    self.gameplayScene.selectedDeck, 
                    self.gameplayScene.selectedBoard, 
                    self.gameplayScene.aiOpponent)
            elseif btnText == "Main Menu" then
                ErrorLog.logError("Return to main menu requested", true)
                
                -- Publish main menu requested event
                EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "MainMenuRequested")
                
                self.gameplayScene.changeSceneCallback("mainmenu")
            end
        end
    end
end

return GameOverManager