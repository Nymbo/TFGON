-- game/scenes/gameplay.lua
-- Main gameplay scene with full EventBus integration
-- Now using board and player methods for state changes
-- Improved event handling for effects, battlecries, and targeting

local GameManager = require("game.managers.gamemanager")
local DrawSystem = require("game.scenes.gameplay.draw")
local InputSystem = require("game.scenes.gameplay.input")
local CombatSystem = require("game.scenes.gameplay.combat")
local BoardRenderer = require("game.ui.boardrenderer")
local AIManager = require("game.managers.aimanager")
local Theme = require("game.ui.theme")
local CardRenderer = require("game.ui.cardrenderer")
local EffectManager = require("game.managers.effectmanager")
local EventBus = require("game.eventbus")

-- Local helper function to draw a themed button
local function drawThemedButton(text, x, y, width, height, isHovered, isSelected)
    love.graphics.setColor(Theme.colors.buttonShadow)
    love.graphics.rectangle(
        "fill",
        x + Theme.dimensions.buttonShadowOffset,
        y + Theme.dimensions.buttonShadowOffset,
        width,
        height,
        Theme.dimensions.buttonCornerRadius
    )
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
    love.graphics.setColor(Theme.colors.buttonBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, width, height, Theme.dimensions.buttonCornerRadius)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(Theme.fonts.button)
    love.graphics.setColor(isHovered and Theme.colors.textHover or Theme.colors.textPrimary)
    love.graphics.printf(text, x, y + (height - Theme.fonts.button:getHeight())/2, width, "center")
end

-- Local function to update dragged card position
local function updateDraggedCard(card, dt)
    local cardWidth, cardHeight = CardRenderer.getCardDimensions()
    local mx, my = love.mouse.getPosition()
    card.target_transform.x = mx - cardWidth / 2
    card.target_transform.y = my - cardHeight / 2
    card.transform.x = card.target_transform.x
    card.transform.y = card.target_transform.y
end

local Gameplay = {}
Gameplay.__index = Gameplay

-- Constructor for Gameplay scene
function Gameplay:new(changeSceneCallback, selectedDeck, selectedBoard, aiOpponent)
    local self = setmetatable({}, Gameplay)
    
    self.selectedDeck = selectedDeck
    self.selectedBoard = selectedBoard
    self.aiOpponent = aiOpponent or false

    self.gameManager = GameManager:new(selectedDeck, selectedBoard, self.aiOpponent)
    self.changeSceneCallback = changeSceneCallback
    self.selectedBoard = selectedBoard

    -- Initialize event subscriptions storage
    self.eventSubscriptions = {}

    if self.aiOpponent then
        self.aiManager = AIManager:new(self.gameManager)
        if love.filesystem.getInfo("difficulty.txt") then
            local content = love.filesystem.read("difficulty.txt")
            local difficultyIndex = tonumber(content)
            if difficultyIndex then
                local difficultyMap = { [1] = "easy", [2] = "normal", [3] = "hard" }
                local difficulty = difficultyMap[difficultyIndex] or "normal"
                self.aiManager:setDifficulty(difficulty)
            end
        end
    end

    if selectedBoard and selectedBoard.imagePath and love.filesystem.getInfo(selectedBoard.imagePath) then
        self.background = love.graphics.newImage(selectedBoard.imagePath)
    else
        self.background = love.graphics.newImage("assets/images/background.png")
    end

    self.endTurnHovered = false
    self.selectedMinion = nil

    -- Legacy callback to maintain compatibility
    self.gameManager.onTurnStart = function(whichPlayer)
        -- This is kept for backward compatibility but no longer sets banner properties
        -- Banner display is now managed through events
    end

    self.showGameOverPopup = false
    self.gameOverWinner = nil
    self.gameManager.onGameOver = function(winner)
        self.showGameOverPopup = true
        self.gameOverWinner = winner
    end

    -- Properties for drag-and-drop
    self.draggedCard = nil
    self.draggedCardIndex = nil

    -- Properties for targeting effects and weapons
    self.pendingEffect = nil
    self.pendingEffectCard = nil
    self.pendingEffectCardIndex = nil
    self.validTargets = {}
    
    -- Setup event subscriptions
    self:initEventSubscriptions()
    
    -- Start the first turn to initialize the game
    self.gameManager:startTurn()

    return self
end

--------------------------------------------------
-- initEventSubscriptions():
-- Set up all event listeners for the Gameplay scene.
--------------------------------------------------
function Gameplay:initEventSubscriptions()
    -- Clear any existing subscriptions
    self:clearEventSubscriptions()
    
    -- Subscribe to turn events
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.TURN_STARTED,
        function(player)
            local bannerType = (player == self.gameManager.player1) and "player" or "opponent"
            local text = (player == self.gameManager.player1) and "YOUR TURN" or 
                       (self.aiOpponent and "AI OPPONENT'S TURN" or "OPPONENT'S TURN")
            
            -- Simply publish the event - the banner display is handled elsewhere now
            EventBus.publish(EventBus.Events.BANNER_DISPLAYED, bannerType, text)
        end,
        "GameplayScene-BannerHandler"
    ))
    
    -- If AI opponent is enabled, subscribe to turn events
    if self.aiOpponent then
        -- Listen for turn started events to trigger AI turn
        table.insert(self.eventSubscriptions, EventBus.subscribe(
            EventBus.Events.TURN_STARTED,
            function(player)
                if player == self.gameManager.player2 then
                    -- Add a small delay before triggering AI turn
                    self.aiTurnTimer = 0.5
                end
            end,
            "GameplayScene-TurnHandler"
        ))
    end
    
    -- Subscribe to card events
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.CARD_PLAYED,
        function(player, card)
            -- Add to animation queue (to be implemented with new animation system)
            self:queueAnimation("cardPlayed", {card = card, player = player})
        end,
        "GameplayScene-CardHandler"
    ))
    
    -- Subscribe to minion events
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.MINION_DAMAGED,
        function(minion, source, damage, oldHealth, newHealth)
            -- Add to animation queue (to be implemented with new animation system)
            self:queueAnimation("damage", {
                target = minion, 
                amount = damage,
                position = {x = minion.position.x, y = minion.position.y}
            })
        end,
        "GameplayScene-DamageHandler"
    ))
    
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.MINION_HEALED,
        function(minion, source, amount, oldHealth, newHealth)
            -- Add to animation queue (to be implemented with new animation system)
            self:queueAnimation("heal", {
                target = minion, 
                amount = amount,
                position = {x = minion.position.x, y = minion.position.y}
            })
        end,
        "GameplayScene-HealHandler"
    ))
    
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.MINION_DIED,
        function(minion, killer)
            -- Add to animation queue (to be implemented with new animation system)
            self:queueAnimation("death", {
                minion = minion,
                position = {x = minion.position.x, y = minion.position.y}
            })
        end,
        "GameplayScene-DeathHandler"
    ))
    
    -- Subscribe to tower events
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.TOWER_DAMAGED,
        function(tower, attacker, damage, oldHealth, newHealth)
            -- Add to animation queue (to be implemented with new animation system)
            self:queueAnimation("towerDamage", {
                tower = tower,
                amount = damage,
                position = {x = tower.position.x, y = tower.position.y}
            })
        end,
        "GameplayScene-TowerHandler"
    ))
    
    -- Subscribe to effect events
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.EFFECT_TRIGGERED,
        function(effectType, player, target)
            -- Add to animation queue (to be implemented with new animation system)
            if effectType == "SpellCastFailed" or effectType == "WeaponEquipFailed" then
                -- Show failure feedback
                self:queueAnimation("effectFailed", {
                    type = effectType,
                    player = player
                })
            end
        end,
        "GameplayScene-EffectHandler"
    ))
    
    -- Listen for board state changes
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.MINION_MOVED,
        function(minion, oldPosition, newPosition)
            -- Add to animation queue (to be implemented with new animation system)
            self:queueAnimation("movement", {
                minion = minion,
                from = oldPosition,
                to = newPosition
            })
        end,
        "GameplayScene-MovementHandler"
    ))
    
    -- Listen for mana changes to update UI
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.PLAYER_MANA_CHANGED,
        function(player, oldValue, newValue)
            -- Add to animation queue (to be implemented with new animation system)
            self:queueAnimation("manaChange", {
                player = player,
                oldValue = oldValue,
                newValue = newValue
            })
        end,
        "GameplayScene-ManaHandler"
    ))
end

--------------------------------------------------
-- clearEventSubscriptions():
-- Clean up event subscriptions to prevent memory leaks.
--------------------------------------------------
function Gameplay:clearEventSubscriptions()
    for _, sub in ipairs(self.eventSubscriptions) do
        EventBus.unsubscribe(sub)
    end
    self.eventSubscriptions = {}
end

--------------------------------------------------
-- queueAnimation: Queue an animation for later processing
-- This is a stub for future animation enhancements
--------------------------------------------------
function Gameplay:queueAnimation(animType, data)
    -- This is now just a stub function that will be replaced with a new animation system
    -- For now, we'll leave it as an empty function to avoid errors
end

function Gameplay:update(dt)
    self.gameManager:update(dt)
    self.endTurnHovered = InputSystem.checkEndTurnHover(self)

    -- Handle AI turns with traditional timer (will migrate to events fully later)
    if self.aiOpponent and self.gameManager.currentPlayer == 2 and not self.showGameOverPopup then
        if self.aiTurnTimer and self.aiTurnTimer > 0 then
            self.aiTurnTimer = self.aiTurnTimer - dt
            if self.aiTurnTimer <= 0 then
                -- Trigger the AI turn via an event
                EventBus.publish(EventBus.Events.AI_TURN_STARTED, self.gameManager.player2)
            end
        end
    end

    -- If a card is being dragged, update its position.
    if self.draggedCard then
        updateDraggedCard(self.draggedCard, dt)
    end
    
    -- If we have a pending effect, update valid targets
    if self.pendingEffect then
        self:updateValidTargets()
    end
    
    -- Process EventBus events
    EventBus.update(dt)
end

-- Updated function to filter valid targets based on effect/card type
function Gameplay:updateValidTargets()
    local gm = self.gameManager
    local currentPlayer = gm:getCurrentPlayer()
    local enemyPlayer = gm:getEnemyPlayer(currentPlayer)
    
    self.validTargets = {}
    
    local targetType = EffectManager.getTargetType(self.pendingEffect)
    
    if targetType == "EnemyTower" then
        -- Add all enemy towers as valid targets
        for _, tower in ipairs(enemyPlayer.towers) do
            table.insert(self.validTargets, { 
                type = "tower", 
                tower = tower,
                position = tower.position 
            })
        end
    elseif targetType == "AnyTower" then
        -- Add all towers as valid targets
        for _, tower in ipairs(currentPlayer.towers) do
            table.insert(self.validTargets, { 
                type = "tower", 
                tower = tower,
                position = tower.position 
            })
        end
        for _, tower in ipairs(enemyPlayer.towers) do
            table.insert(self.validTargets, { 
                type = "tower", 
                tower = tower,
                position = tower.position 
            })
        end
    elseif targetType == "EnemyMinion" then
        -- Find all enemy minions
        gm.board:forEachMinion(function(minion, x, y)
            if minion.owner == enemyPlayer then
                table.insert(self.validTargets, {
                    type = "minion",
                    minion = minion,
                    position = { x = x, y = y }
                })
            end
        end)
    elseif targetType == "AnyMinion" then
        -- Find all minions
        gm.board:forEachMinion(function(minion, x, y)
            table.insert(self.validTargets, {
                type = "minion",
                minion = minion,
                position = { x = x, y = y }
            })
        end)
    elseif targetType == "FriendlyMinion" then
        -- Find minions belonging to the current player
        gm.board:forEachMinion(function(minion, x, y)
            if minion.owner == currentPlayer then
                -- If we're equipping a weapon, check if this minion can use it
                if self.pendingEffectCard and self.pendingEffectCard.cardType == "Weapon" then
                    if EffectManager.validateTarget(self.pendingEffect, minion, self.pendingEffectCard) then
                        table.insert(self.validTargets, {
                            type = "minion",
                            minion = minion,
                            position = { x = x, y = y }
                        })
                    end
                else
                    -- For other effects targeting friendly minions
                    table.insert(self.validTargets, {
                        type = "minion",
                        minion = minion,
                        position = { x = x, y = y }
                    })
                end
            end
        end)
    end
end

function Gameplay:draw()
    DrawSystem.drawGameplayScene(self)

    -- Draw dragged card with 50% opacity.
    if self.draggedCard then
        love.graphics.setColor(1, 1, 1, 0.5)
        CardRenderer.drawCard(self.draggedCard, self.draggedCard.transform.x, self.draggedCard.transform.y, true)
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Draw targeting indicator if we have a pending effect
    if self.pendingEffect then
        self:drawTargetingIndicators()
    end

    -- Draw turn banners (will be reimplemented with a new system)
    self:drawTurnBanner()

    if self.showGameOverPopup then
        self:drawGameOverPopup()
    end
    
    -- If we have a pending effect, show a text prompt
    if self.pendingEffect then
        local promptMessage
        if self.pendingEffectCard and self.pendingEffectCard.cardType == "Weapon" then
            promptMessage = "Select a minion to equip " .. (self.pendingEffectCard.name or "the weapon")
        else
            promptMessage = "Select a target for " .. (self.pendingEffectCard and self.pendingEffectCard.name or "the spell")
        end
        
        love.graphics.setFont(Theme.fonts.subtitle)
        love.graphics.setColor(Theme.colors.textPrimary)
        love.graphics.printf(promptMessage, 0, 20, love.graphics.getWidth(), "center")
    end
end

-- Simple turn banner implementation to replace the BannerSystem
function Gameplay:drawTurnBanner()
    -- This is a minimal implementation to replace the banner system
    -- We'll implement a more sophisticated system in the future
    
    -- For now, just display the current player's turn at the top
    local turnText = "Player " .. self.gameManager.currentPlayer .. "'s Turn"
    love.graphics.setFont(Theme.fonts.subtitle)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.printf(turnText, 0, 30, love.graphics.getWidth(), "center")
end

-- Draw targeting indicators
function Gameplay:drawTargetingIndicators()
    local boardX, boardY = BoardRenderer.getBoardPosition()
    local TILE_SIZE = BoardRenderer.getTileSize()
    
    -- Draw targeting indicator for each valid target
    for _, target in ipairs(self.validTargets) do
        local tx = boardX + (target.position.x - 1) * TILE_SIZE
        local ty = boardY + (target.position.y - 1) * TILE_SIZE
        
        -- Draw a pulsing highlight effect
        local pulseAmount = 0.7 + math.sin(love.timer.getTime() * 5) * 0.3
        
        -- Use different colors based on target type
        local targetColor
        if self.pendingEffectCard and self.pendingEffectCard.cardType == "Weapon" then
            -- Weapons use green targeting
            targetColor = {0, 1, 0.2, pulseAmount}
        else
            -- Spells use orange targeting
            targetColor = {1, 0.5, 0, pulseAmount}
        end
        
        -- Draw targeting circle
        love.graphics.setColor(targetColor)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", tx + TILE_SIZE/2, ty + TILE_SIZE/2, TILE_SIZE/2 + 5)
        
        -- Draw crosshair or symbol based on what we're targeting
        if self.pendingEffectCard and self.pendingEffectCard.cardType == "Weapon" then
            -- For weapons, draw a small sword icon or similar
            -- Here we'll use a simple "+" symbol
            local symbolSize = TILE_SIZE * 0.3
            love.graphics.line(
                tx + TILE_SIZE/2 - symbolSize, ty + TILE_SIZE/2,
                tx + TILE_SIZE/2 + symbolSize, ty + TILE_SIZE/2
            )
            love.graphics.line(
                tx + TILE_SIZE/2, ty + TILE_SIZE/2 - symbolSize,
                tx + TILE_SIZE/2, ty + TILE_SIZE/2 + symbolSize
            )
        else
            -- For spells, draw a targeting reticle
            local crosshairSize = TILE_SIZE * 0.3
            love.graphics.circle("line", tx + TILE_SIZE/2, ty + TILE_SIZE/2, crosshairSize / 2)
            love.graphics.line(
                tx + TILE_SIZE/2 - crosshairSize, ty + TILE_SIZE/2,
                tx + TILE_SIZE/2 + crosshairSize, ty + TILE_SIZE/2
            )
            love.graphics.line(
                tx + TILE_SIZE/2, ty + TILE_SIZE/2 - crosshairSize,
                tx + TILE_SIZE/2, ty + TILE_SIZE/2 + crosshairSize
            )
        end
        
        love.graphics.setLineWidth(1)
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

function Gameplay:drawGameOverPopup()
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local popupW, popupH = 400, 300
    local popupX = (screenW - popupW) / 2
    local popupY = (screenH - popupH) / 2

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    love.graphics.setColor(Theme.colors.backgroundLight)
    love.graphics.rectangle("fill", popupX, popupY, popupW, popupH, 10)
    love.graphics.setColor(Theme.colors.buttonBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", popupX, popupY, popupW, popupH, 10)
    love.graphics.setLineWidth(1)

    local gameOverTitle = "GAME OVER"
    love.graphics.setFont(Theme.fonts.title)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.printf(gameOverTitle, popupX, popupY + 40, popupW, "center")

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
        drawThemedButton(btnText, btnX, buttonY, buttonW, buttonH, isHovered, false)
        self.popupButtons[btnText] = {x = btnX, y = buttonY, width = buttonW, height = buttonH}
    end
end

function Gameplay:mousepressed(x, y, button, istouch, presses)
    if button ~= 1 then return end

    if self.showGameOverPopup then
        self:handleGameOverPopupClick(x, y)
        return
    end

    if self.aiOpponent and self.gameManager.currentPlayer == 2 then
        return
    end
    
    -- Check if we need to handle a pending effect target selection
    if self.pendingEffect then
        local target = self:selectTarget(x, y)
        if target then
            -- Apply the pending effect with the selected target
            local success = EffectManager.applyEffectKey(
                self.pendingEffect,
                self.gameManager,
                self.gameManager:getCurrentPlayer(),
                target,
                self.pendingEffectCard  -- Pass the card data for weapons
            )
            
            if success then
                -- Spend mana for the card 
                local currentPlayer = self.gameManager:getCurrentPlayer()
                currentPlayer:spendMana(self.pendingEffectCard.cost)
                
                -- Publish card played event
                EventBus.publish(EventBus.Events.CARD_PLAYED, currentPlayer, self.pendingEffectCard)
            else
                -- If the effect failed to apply, put the card back in hand
                table.insert(
                    self.gameManager:getCurrentPlayer().hand, 
                    self.pendingEffectCardIndex, 
                    self.pendingEffectCard
                )
                
                -- Publish a card rejected event
                EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "CardRejected", self.pendingEffectCard)
            end
            
            -- Clear the pending effect state
            self.pendingEffect = nil
            self.pendingEffectCard = nil
            self.pendingEffectCardIndex = nil
            self.validTargets = {}
            return
        end
        
        -- If the player clicked outside valid targets, just cancel
        -- Only cancel if clicked on the board or on the cancel button
        local boardX, boardY = BoardRenderer.getBoardPosition()
        local TILE_SIZE = BoardRenderer.getTileSize()
        local boardWidth = TILE_SIZE * self.gameManager.board.cols
        local boardHeight = TILE_SIZE * self.gameManager.board.rows
        
        if (x >= boardX and x < boardX + boardWidth and
            y >= boardY and y < boardY + boardHeight) or
           InputSystem.checkEndTurnHover(self) then
            
            -- Put the card back in hand
            table.insert(
                self.gameManager:getCurrentPlayer().hand, 
                self.pendingEffectCardIndex, 
                self.pendingEffectCard
            )
            
            -- Publish a targeting cancelled event
            EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "TargetingCancelled", self.pendingEffectCard)
            
            -- Clear the pending effect state
            self.pendingEffect = nil
            self.pendingEffectCard = nil
            self.pendingEffectCardIndex = nil
            self.validTargets = {}
            return
        end
    end
    
    InputSystem.mousepressed(self, x, y, button, istouch, presses)
end

-- New function to select a target for an effect
function Gameplay:selectTarget(x, y)
    local boardX, boardY = BoardRenderer.getBoardPosition()
    local TILE_SIZE = BoardRenderer.getTileSize()
    
    -- Check if the click is on the board
    local isOnBoard = x >= boardX and x < boardX + (self.gameManager.board.cols * TILE_SIZE) and
                    y >= boardY and y < boardY + (self.gameManager.board.rows * TILE_SIZE)
    
    if isOnBoard then
        local cellX = math.floor((x - boardX) / TILE_SIZE) + 1
        local cellY = math.floor((y - boardY) / TILE_SIZE) + 1
        
        -- Check if this cell contains a valid target
        for _, target in ipairs(self.validTargets) do
            if target.position.x == cellX and target.position.y == cellY then
                return target.tower or target.minion
            end
        end
    end
    
    return nil
end

function Gameplay:handleGameOverPopupClick(x, y)
    for btnText, area in pairs(self.popupButtons) do
        if x >= area.x and x <= area.x + area.width and
           y >= area.y and y <= area.y + area.height then
            if btnText == "Restart" then
                self.changeSceneCallback("gameplay", self.selectedDeck, self.selectedBoard, self.aiOpponent)
            elseif btnText == "Main Menu" then
                self.changeSceneCallback("mainmenu")
            end
        end
    end
end

function Gameplay:endTurn()
    -- Publish turn ending event
    EventBus.publish(EventBus.Events.TURN_ENDED, self.gameManager:getCurrentPlayer())
    
    -- Call game manager to end turn
    self.gameManager:endTurn()
end

function Gameplay:keypressed(key)
    if key == "escape" then
        -- If there's a pending effect, cancel it and return the card to hand
        if self.pendingEffect then
            table.insert(
                self.gameManager:getCurrentPlayer().hand, 
                self.pendingEffectCardIndex, 
                self.pendingEffectCard
            )
            
            -- Publish a targeting cancelled event
            EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "TargetingCancelled", self.pendingEffectCard)
            
            self.pendingEffect = nil
            self.pendingEffectCard = nil
            self.pendingEffectCardIndex = nil
            self.validTargets = {}
            return
        end
        
        self.changeSceneCallback("mainmenu")
    end
end

function Gameplay:resolveAttack(attacker, target)
    CombatSystem.resolveAttack(self, attacker, target)
end

--------------------------------------------------
-- Cleanup function to properly dispose resources
--------------------------------------------------
function Gameplay:destroy()
    -- Clean up our event subscriptions
    self:clearEventSubscriptions()
    
    -- Clean up AI manager if it exists
    if self.aiManager then
        if self.aiManager.destroy then
            self.aiManager:destroy()
        end
    end
    
    -- Publish scene exit event
    EventBus.publish(EventBus.Events.SCENE_EXITED, "gameplay")
end

return Gameplay