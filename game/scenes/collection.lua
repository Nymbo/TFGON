-- game/scenes/collection.lua
-- Collection (deck-building) scene using the unified Theme

local Collection = {}
Collection.__index = Collection

local DeckManager = require("game.managers.deckmanager")
local cardsData = require("data.cards")
local Theme = require("game.ui.theme")
local CardRenderer = require("game.ui.cardrenderer")

--------------------------------------------------
-- Constructor for the Collection scene.
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
    self.poolScroll = 0  -- Offset index for the card pool

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

    -- Get card dimensions from CardRenderer
    self.cardWidth, self.cardHeight = CardRenderer.getCardDimensions()
    
    -- Grid layout for card pool (5 columns x 2 rows)
    local margin = 20
    self.gridColumns = 5
    self.gridRows = 2
    self.gridMargin = margin
    
    -- Calculate card spacing
    self.cardSpacingX = (self.leftPanelWidth - (self.gridColumns + 1) * margin) / self.gridColumns
    self.cardSpacingY = (self.screenHeight - (self.gridRows + 1) * margin) / self.gridRows

    return self
end

--------------------------------------------------
-- update(dt): Handle any frame-based updates
--------------------------------------------------
function Collection:update(dt)
    -- No dynamic updates needed yet
end

--------------------------------------------------
-- draw(): Render the collection scene
--------------------------------------------------
function Collection:draw()
    -- Draw overall background
    love.graphics.setColor(Theme.colors.background)
    love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)

    -- Draw left panel (card pool)
    love.graphics.setColor(Theme.colors.backgroundLight)
    love.graphics.rectangle("fill", self.leftPanelX, self.leftPanelY, self.leftPanelWidth, self.screenHeight)

    -- Draw decorative separator between panels
    love.graphics.setColor(Theme.colors.buttonBorder)
    love.graphics.setLineWidth(2)
    -- Main vertical line
    love.graphics.line(self.leftPanelWidth, 0, self.leftPanelWidth, self.screenHeight)
    
    -- Decorative elements
    local decorSize = 40
    local ySpacing = 120
    for y = ySpacing, self.screenHeight - ySpacing, ySpacing do
        -- Diamond shape
        love.graphics.polygon('fill', 
            self.leftPanelWidth - decorSize/2, y,
            self.leftPanelWidth, y - decorSize/2,
            self.leftPanelWidth + decorSize/2, y,
            self.leftPanelWidth, y + decorSize/2
        )
        -- Inner diamond (negative space)
        love.graphics.setColor(Theme.colors.background)
        love.graphics.polygon('fill',
            self.leftPanelWidth - decorSize/4, y,
            self.leftPanelWidth, y - decorSize/4,
            self.leftPanelWidth + decorSize/4, y,
            self.leftPanelWidth, y + decorSize/4
        )
        love.graphics.setColor(Theme.colors.buttonBorder)
    end
    love.graphics.setLineWidth(1)

    -- Draw panels
    self:drawCardPool()

    -- Draw right panel (deck manager)
    love.graphics.setColor(Theme.colors.backgroundLight)
    love.graphics.rectangle("fill", self.rightPanelX, self.rightPanelY, self.rightPanelWidth, self.screenHeight)
    self:drawDeckManager()
end

--------------------------------------------------
-- drawCardPool(): Draw the scrollable card grid
--------------------------------------------------
function Collection:drawCardPool()
    local margin = self.gridMargin
    local startX = margin
    local startY = margin

    -- Title for card pool
    love.graphics.setFont(Theme.fonts.subtitle)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.print("Card Collection", startX, startY)
    startY = startY + Theme.fonts.subtitle:getHeight() + margin

    -- Draw cards in a grid
    for row = 0, self.gridRows - 1 do
        for col = 0, self.gridColumns - 1 do
            local cardIndex = self.poolScroll + (row * self.gridColumns + col) + 1
            local card = self.cardPool[cardIndex]
            if card then
                local x = startX + col * (self.cardWidth + margin)
                local y = startY + row * (self.cardHeight + margin)
                -- Draw the card with CardRenderer
                CardRenderer.drawCard(card, x, y, true)
            end
        end
    end
end

--------------------------------------------------
-- drawDeckManager(): Draw deck slots and contents
--------------------------------------------------
function Collection:drawDeckManager()
    local x = self.rightPanelX + 20
    local y = 20
    local width = self.rightPanelWidth - 40

    -- Title
    love.graphics.setFont(Theme.fonts.subtitle)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.print("Deck Builder", x, y)
    y = y + Theme.fonts.subtitle:getHeight() + 10

    -- Deck slots
    for i, deck in ipairs(self.decks) do
        local isSelected = (i == self.selectedDeckIndex)
        local slotHeight = 40

        -- Draw slot background
        love.graphics.setColor(isSelected and Theme.colors.buttonHover or Theme.colors.buttonBase)
        love.graphics.rectangle("fill", x, y, width, slotHeight, 5)

        -- Draw deck name and card count
        love.graphics.setFont(Theme.fonts.body)
        love.graphics.setColor(isSelected and Theme.colors.textHover or Theme.colors.textPrimary)
        local deckText = string.format("%s (%d/20)", deck.name, #deck.cards)
        love.graphics.print(deckText, x + 10, y + (slotHeight - Theme.fonts.body:getHeight())/2)

        y = y + slotHeight + 5
    end

    -- Selected deck contents
    y = y + 20
    love.graphics.setFont(Theme.fonts.body)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.print("Deck Contents:", x, y)
    y = y + Theme.fonts.body:getHeight() + 10

    local deck = self.decks[self.selectedDeckIndex]
    for i, card in ipairs(deck.cards) do
        love.graphics.setColor(Theme.colors.textSecondary)
        love.graphics.print(card.name, x + 10, y)
        y = y + 20
    end

    -- Buttons
    local buttonWidth = width
    local buttonHeight = Theme.dimensions.buttonHeight
    local validateY = self.screenHeight - buttonHeight * 2 - 30
    local backY = validateY + buttonHeight + 10

    -- Check button hover states
    local mx, my = love.mouse.getPosition()
    local validateHovered = mx >= x and mx <= x + buttonWidth and my >= validateY and my <= validateY + buttonHeight
    local backHovered = mx >= x and mx <= x + buttonWidth and my >= backY and my <= backY + buttonHeight

    -- Validate button
    -- Shadow
    love.graphics.setColor(Theme.colors.buttonShadow)
    love.graphics.rectangle(
        "fill", 
        x + Theme.dimensions.buttonShadowOffset,
        validateY + Theme.dimensions.buttonShadowOffset,
        buttonWidth,
        buttonHeight,
        Theme.dimensions.buttonCornerRadius
    )

    -- Hover glow
    if validateHovered then
        love.graphics.setColor(Theme.colors.buttonGlowHover)
        love.graphics.rectangle(
            "fill",
            x - Theme.dimensions.buttonGlowOffset,
            validateY - Theme.dimensions.buttonGlowOffset,
            buttonWidth + 2 * Theme.dimensions.buttonGlowOffset,
            buttonHeight + 2 * Theme.dimensions.buttonGlowOffset,
            Theme.dimensions.buttonCornerRadius + 2
        )
    end

    -- Base and gradient
    love.graphics.setColor(Theme.colors.buttonBase)
    love.graphics.rectangle("fill", x, validateY, buttonWidth, buttonHeight, Theme.dimensions.buttonCornerRadius)
    love.graphics.setColor(Theme.colors.buttonGradientTop)
    love.graphics.rectangle("fill", x + 2, validateY + 2, buttonWidth - 4, buttonHeight/2 - 2, Theme.dimensions.buttonCornerRadius)

    -- Border
    love.graphics.setColor(Theme.colors.buttonBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, validateY, buttonWidth, buttonHeight, Theme.dimensions.buttonCornerRadius)
    love.graphics.setLineWidth(1)

    -- Text
    love.graphics.setFont(Theme.fonts.button)
    love.graphics.setColor(validateHovered and Theme.colors.textHover or Theme.colors.textPrimary)
    love.graphics.printf("Validate Deck", x, validateY + (buttonHeight - Theme.fonts.button:getHeight())/2, buttonWidth, "center")

    -- Back button
    -- Shadow
    love.graphics.setColor(Theme.colors.buttonShadow)
    love.graphics.rectangle(
        "fill",
        x + Theme.dimensions.buttonShadowOffset,
        backY + Theme.dimensions.buttonShadowOffset,
        buttonWidth,
        buttonHeight,
        Theme.dimensions.buttonCornerRadius
    )

    -- Hover glow
    if backHovered then
        love.graphics.setColor(Theme.colors.buttonGlowHover)
        love.graphics.rectangle(
            "fill",
            x - Theme.dimensions.buttonGlowOffset,
            backY - Theme.dimensions.buttonGlowOffset,
            buttonWidth + 2 * Theme.dimensions.buttonGlowOffset,
            buttonHeight + 2 * Theme.dimensions.buttonGlowOffset,
            Theme.dimensions.buttonCornerRadius + 2
        )
    end

    -- Base and gradient
    love.graphics.setColor(Theme.colors.buttonBase)
    love.graphics.rectangle("fill", x, backY, buttonWidth, buttonHeight, Theme.dimensions.buttonCornerRadius)
    love.graphics.setColor(Theme.colors.buttonGradientTop)
    love.graphics.rectangle("fill", x + 2, backY + 2, buttonWidth - 4, buttonHeight/2 - 2, Theme.dimensions.buttonCornerRadius)

    -- Border
    love.graphics.setColor(Theme.colors.buttonBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, backY, buttonWidth, buttonHeight, Theme.dimensions.buttonCornerRadius)
    love.graphics.setLineWidth(1)

    -- Text
    love.graphics.setFont(Theme.fonts.button)
    love.graphics.setColor(backHovered and Theme.colors.textHover or Theme.colors.textPrimary)
    love.graphics.printf("Back", x, backY + (buttonHeight - Theme.fonts.button:getHeight())/2, buttonWidth, "center")
end

--------------------------------------------------
-- mousepressed: Handle mouse input
--------------------------------------------------
function Collection:mousepressed(x, y, button, istouch, presses)
    if button ~= 1 then return end

    if x < self.leftPanelWidth then
        self:handleCardPoolClick(x, y)
    else
        self:handleDeckManagerClick(x - self.rightPanelX, y)
    end
end

--------------------------------------------------
-- handleCardPoolClick: Process card pool clicks
--------------------------------------------------
function Collection:handleCardPoolClick(x, y)
    local margin = self.gridMargin
    local startX = margin
    local startY = margin + Theme.fonts.subtitle:getHeight() + margin

    -- Calculate which card was clicked
    local col = math.floor((x - startX) / (self.cardWidth + margin))
    local row = math.floor((y - startY) / (self.cardHeight + margin))
    
    if col >= 0 and col < self.gridColumns and row >= 0 and row < self.gridRows then
        local cardIndex = self.poolScroll + (row * self.gridColumns + col) + 1
        local card = self.cardPool[cardIndex]
        
        if card then
            local success = DeckManager:addCardToDeck(self.selectedDeckIndex, card)
            if not success then
                print("Cannot add card: deck full or card limit reached.")
            end
        end
    end
end

--------------------------------------------------
-- handleDeckManagerClick: Process deck manager clicks
--------------------------------------------------
function Collection:handleDeckManagerClick(x, y)
    local margin = 20
    local slotHeight = 40
    local width = self.rightPanelWidth - 40
    local deckStartY = 20 + Theme.fonts.subtitle:getHeight() + 10

    -- Check deck slot clicks
    for i = 1, #self.decks do
        local slotY = deckStartY + (i-1) * (slotHeight + 5)
        if y >= slotY and y <= slotY + slotHeight and x >= margin and x <= margin + width then
            self.selectedDeckIndex = i
            return
        end
    end

    -- Check button clicks
    local buttonWidth = width
    local buttonHeight = Theme.dimensions.buttonHeight
    local validateY = self.screenHeight - buttonHeight * 2 - 30
    local backY = validateY + buttonHeight + 10

    if x >= margin and x <= margin + buttonWidth then
        if y >= validateY and y <= validateY + buttonHeight then
            -- Validate button clicked
            local valid, message = DeckManager:validateDeck(self.selectedDeckIndex)
            print(message)
            return
        elseif y >= backY and y <= backY + buttonHeight then
            -- Back button clicked
            DeckManager:saveDecks()
            self.changeSceneCallback("mainmenu")
            return
        end
    end

    -- Check for card removal clicks in deck contents
    local contentsStartY = deckStartY + (#self.decks * (slotHeight + 5)) + 60
    local cardY = math.floor((y - contentsStartY) / 20)
    if cardY >= 0 and cardY < #self.decks[self.selectedDeckIndex].cards then
        DeckManager:removeCardFromDeck(self.selectedDeckIndex, cardY + 1)
    end
end

--------------------------------------------------
-- wheelmoved: Handle scrolling
--------------------------------------------------
function Collection:wheelmoved(x, y)
    if y > 0 then
        self.poolScroll = math.max(0, self.poolScroll - self.gridColumns)
    elseif y < 0 then
        local maxScroll = math.max(0, #self.cardPool - (self.gridColumns * self.gridRows))
        self.poolScroll = math.min(maxScroll, self.poolScroll + self.gridColumns)
    end
end

--------------------------------------------------
-- keypressed: Handle keyboard input
--------------------------------------------------
function Collection:keypressed(key)
    if key == "escape" then
        DeckManager:saveDecks()
        self.changeSceneCallback("mainmenu")
    end
end

return Collection