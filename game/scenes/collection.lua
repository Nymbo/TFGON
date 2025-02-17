-- game/scenes/collection.lua
-- Collection (deck-building) scene.
-- Left 70% of the screen displays the card pool (with scrolling),
-- and the right 30% displays deck slots and the selected deck's contents.

local Collection = {}
Collection.__index = Collection

local DeckManager = require("game.managers.deckmanager")
local cardsData = require("data.cards")

--------------------------------------------------
-- Local function: drawLargeCard
-- Draws a large card for the collection UI using given dimensions.
--------------------------------------------------
local function drawLargeCard(card, x, y, width, height, isPlayable)
    local oldFont = love.graphics.getFont()
    local font = love.graphics.newFont(24)  -- larger font for collection UI
    love.graphics.setFont(font)

    -- Draw a green glow if the card is playable
    if isPlayable then
        local glowOffset = 10
        love.graphics.setColor(0, 1, 0, 0.4)
        love.graphics.rectangle("fill", x - glowOffset, y - glowOffset, width + glowOffset * 2, height + glowOffset * 2, 10, 10)
    end

    -- Card background and border
    love.graphics.setColor(0.204, 0.286, 0.369, 1)
    love.graphics.rectangle("fill", x, y, width, height, 10, 10)
    love.graphics.setColor(0.945, 0.768, 0.058, 1)
    love.graphics.rectangle("line", x, y, width, height, 10, 10)

    -- Draw cost circle (relative to card width)
    local circleRadius = width * 0.1
    love.graphics.setColor(0.204, 0.596, 0.858, 1)
    love.graphics.circle("fill", x + circleRadius + 5, y + circleRadius + 5, circleRadius)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(tostring(card.cost), x + 5, y + 5, circleRadius * 2, "center")

    -- Draw card name centered
    love.graphics.printf(card.name, x + 5, y + height/2 - 12, width - 10, "center")

    love.graphics.setFont(oldFont)
end

--------------------------------------------------
-- Constructor for the Collection scene.
-- Accepts a changeSceneCallback to switch scenes.
--------------------------------------------------
function Collection:new(changeSceneCallback)
    local self = setmetatable({}, Collection)
    
    self.changeSceneCallback = changeSceneCallback

    -- Initialize deck manager and get decks
    DeckManager:init()
    self.decks = DeckManager.decks
    self.selectedDeckIndex = 1

    -- Card pool is all cards from data/cards.lua
    self.cardPool = cardsData
    self.poolScroll = 0  -- Offset index for the card pool (in multiples of 10)

    -- UI dimensions
    self.screenWidth = love.graphics.getWidth()
    self.screenHeight = love.graphics.getHeight()
    self.leftPanelWidth = self.screenWidth * 0.7
    self.rightPanelWidth = self.screenWidth * 0.3

    -- Panel positions
    self.leftPanelX = 0
    self.leftPanelY = 0
    self.rightPanelX = self.leftPanelWidth
    self.rightPanelY = 0

    -- Compute card dimensions for collection UI:
    -- We want 5 columns and 2 rows with a margin.
    local margin = 20
    self.collectionCardWidth = (self.leftPanelWidth - (6 * margin)) / 5
    self.collectionCardHeight = (self.screenHeight - (3 * margin)) / 2

    return self
end

--------------------------------------------------
-- update(dt):
-- Called each frame to update any scene logic.
--------------------------------------------------
function Collection:update(dt)
    -- No dynamic updates for now
end

--------------------------------------------------
-- draw():
-- Renders the collection scene.
--------------------------------------------------
function Collection:draw()
    -- Draw overall background
    love.graphics.setColor(0.1, 0.1, 0.1, 1)
    love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)

    -- Draw left panel (card pool)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", self.leftPanelX, self.leftPanelY, self.leftPanelWidth, self.screenHeight)
    self:drawCardPool()

    -- Draw right panel (deck manager)
    love.graphics.rectangle("line", self.rightPanelX, self.rightPanelY, self.rightPanelWidth, self.screenHeight)
    self:drawDeckManager()
end

--------------------------------------------------
-- drawCardPool():
-- Draws the card pool in the left panel as a grid (2 rows x 5 columns).
--------------------------------------------------
function Collection:drawCardPool()
    local margin = 20
    local startX = margin
    local startY = margin

    -- There are 2 rows and 5 columns per page (10 cards total)
    for row = 0, 1 do
        for col = 0, 4 do
            local cardIndex = self.poolScroll + (row * 5 + col) + 1
            local card = self.cardPool[cardIndex]
            if card then
                local x = startX + col * (self.collectionCardWidth + margin)
                local y = startY + row * (self.collectionCardHeight + margin)
                -- Draw the large card (isPlayable flag set to true for UI highlighting)
                drawLargeCard(card, x, y, self.collectionCardWidth, self.collectionCardHeight, true)
            end
        end
    end
end

--------------------------------------------------
-- drawDeckManager():
-- Draws the deck slots and the contents of the selected deck.
--------------------------------------------------
function Collection:drawDeckManager()
    local x = self.rightPanelX + 10
    local y = 20
    local slotHeight = 30

    -- Title for deck slots
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Deck Slots:", x, y)
    y = y + 30

    -- List deck slots
    for i, deck in ipairs(self.decks) do
        if i == self.selectedDeckIndex then
            love.graphics.setColor(0, 1, 0, 1) -- Highlight selected deck in green
        else
            love.graphics.setColor(1, 1, 1, 1)
        end
        love.graphics.print(deck.name, x, y)
        y = y + slotHeight
    end

    y = y + 20
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Deck Contents (" .. #self.decks[self.selectedDeckIndex].cards .. "/20):", x, y)
    y = y + 20

    -- List cards in the selected deck
    local deck = self.decks[self.selectedDeckIndex]
    for i, card in ipairs(deck.cards) do
        love.graphics.print(card.name, x, y)
        y = y + 20
    end

    -- Draw Validate Deck button
    local buttonX = x
    local validateButtonY = self.screenHeight - 50
    love.graphics.setColor(0.2, 0.8, 0.2, 1)
    love.graphics.rectangle("fill", buttonX, validateButtonY, self.rightPanelWidth - 20, 30, 5, 5)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Validate Deck", buttonX, validateButtonY + 7, self.rightPanelWidth - 20, "center")

    -- Draw Back button above the Validate button
    local backButtonY = validateButtonY - 40
    love.graphics.setColor(0.8, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", buttonX, backButtonY, self.rightPanelWidth - 20, 30, 5, 5)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Back", buttonX, backButtonY + 7, self.rightPanelWidth - 20, "center")
end

--------------------------------------------------
-- mousepressed(x, y, button, istouch, presses):
-- Handles mouse click events.
--------------------------------------------------
function Collection:mousepressed(x, y, button, istouch, presses)
    if button ~= 1 then return end

    if x < self.leftPanelWidth then
        self:handleCardPoolClick(x, y)
    else
        self:handleDeckManagerClick(x, y)
    end
end

--------------------------------------------------
-- handleCardPoolClick(x, y):
-- Determines if a card in the pool was clicked and attempts to add it
-- to the currently selected deck.
--------------------------------------------------
function Collection:handleCardPoolClick(x, y)
    local margin = 20
    local startX = margin
    local startY = margin

    for row = 0, 1 do
        for col = 0, 4 do
            local cardIndex = self.poolScroll + (row * 5 + col) + 1
            local cardX = startX + col * (self.collectionCardWidth + margin)
            local cardY = startY + row * (self.collectionCardHeight + margin)
            if x >= cardX and x <= cardX + self.collectionCardWidth and y >= cardY and y <= cardY + self.collectionCardHeight then
                local card = self.cardPool[cardIndex]
                if card then
                    local success = DeckManager:addCardToDeck(self.selectedDeckIndex, card)
                    if not success then
                        print("Cannot add card: deck full or card limit reached.")
                    else
                        print("Added " .. card.name .. " to deck " .. self.selectedDeckIndex)
                    end
                end
                return
            end
        end
    end
end

--------------------------------------------------
-- handleDeckManagerClick(x, y):
-- Handles clicks in the deck manager panel (deck slot selection, 
-- validating, removing cards, and navigating back).
--------------------------------------------------
function Collection:handleDeckManagerClick(x, y)
    local localX = x - self.rightPanelX
    local localY = y
    local slotHeight = 30
    local startX = 10
    local yPos = 20

    -- Check for deck slot selection
    if localY >= yPos and localY < yPos + (#self.decks * slotHeight) then
        local slotIndex = math.floor((localY - yPos) / slotHeight) + 1
        if slotIndex <= #self.decks then
            self.selectedDeckIndex = slotIndex
            return
        end
    end

    -- Check Validate and Back buttons
    local validateButtonY = self.screenHeight - 50
    local backButtonY = validateButtonY - 40
    local buttonWidth = self.rightPanelWidth - 20

    if localY >= backButtonY and localY <= backButtonY + 30 then
        -- Back button clicked: save decks before returning to Main Menu
        DeckManager:saveDecks()
        self.changeSceneCallback("mainmenu")
        return
    elseif localY >= validateButtonY and localY <= validateButtonY + 30 then
        local valid, message = DeckManager:validateDeck(self.selectedDeckIndex)
        print(message)
        return
    end

    -- Check if clicking on a card in the deck list to remove it.
    local deck = self.decks[self.selectedDeckIndex]
    local deckListStartY = 20 + (#self.decks * slotHeight) + 20 + 20  -- after "Deck Contents:" label
    local currentY = deckListStartY
    for i, card in ipairs(deck.cards) do
        if localY >= currentY and localY <= currentY + 20 then
            DeckManager:removeCardFromDeck(self.selectedDeckIndex, i)
            print("Removed " .. card.name .. " from deck.")
            return
        end
        currentY = currentY + 20
    end
end

--------------------------------------------------
-- wheelmoved(x, y):
-- Handles mouse wheel scrolling for the card pool.
-- Scrolls in pages (10 cards per page).
--------------------------------------------------
function Collection:wheelmoved(x, y)
    if y > 0 then
        self.poolScroll = math.max(self.poolScroll - 10, 0)
    elseif y < 0 then
        self.poolScroll = self.poolScroll + 10
        if self.poolScroll > #self.cardPool - 10 then
            self.poolScroll = math.max(#self.cardPool - 10, 0)
        end
    end
end

--------------------------------------------------
-- keypressed(key):
-- Allows returning to the main menu with ESC.
--------------------------------------------------
function Collection:keypressed(key)
    if key == "escape" then
        DeckManager:saveDecks()
        self.changeSceneCallback("mainmenu")
    end
end

return Collection
