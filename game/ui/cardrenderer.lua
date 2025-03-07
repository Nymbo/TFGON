-- game/ui/cardrenderer.lua
-- Renders cards with an improved visual design:
-- - Blue mana circle (top left)
-- - White movement circle (top right)
-- - Yellow attack circle (bottom left)
-- - Red health circle (bottom right)
-- - Card name in custom font (positioned lower)
-- - Card text area for effects (middle)
-- - Archetype text (for minions) just above the card type banner
-- - Card type at the very bottom (centered)

local CardRenderer = {}

-- Card dimensions
local CARD_WIDTH = 120          -- Slightly wider card for better layout
local CARD_HEIGHT = 180         -- Taller card to accommodate all elements
local CIRCLE_RADIUS = 14        -- Radius for all stat circles
local CARD_CORNER_RADIUS = 8    -- Rounded corners

-- Card color palette
local COLORS = {
    background = {0.2, 0.2, 0.25, 1},      -- Dark slate background
    border = {0.8, 0.7, 0.5, 1},           -- Gold/tan border
    innerBorder = {0.3, 0.3, 0.35, 1},     -- Inner border/frame
    manaCircle = {0.2, 0.4, 0.8, 1},       -- Blue mana cost
    attackCircle = {0.9, 0.8, 0.2, 1},     -- Yellow attack
    healthCircle = {0.8, 0.2, 0.2, 1},     -- Red health
    movementCircle = {0.9, 0.9, 0.9, 1},   -- White movement
    manaBg = {0.15, 0.25, 0.5, 1},         -- Darker blue for mana bg
    attackBg = {0.5, 0.4, 0.1, 1},         -- Darker yellow for attack bg
    healthBg = {0.5, 0.15, 0.15, 1},       -- Darker red for health bg
    movementBg = {0.4, 0.4, 0.4, 1},       -- Gray for movement bg
    statText = {1, 1, 1, 1},               -- White text for stats
    cardName = {1, 0.95, 0.8, 1},          -- Light cream for card name
    cardText = {0.9, 0.9, 0.9, 1},         -- Light gray for card text
    cardType = {0.7, 0.7, 0.8, 1},         -- Light blue-gray for card type and archetype text
    typeBanner = {0.25, 0.25, 0.3, 1},     -- Dark banner for card type
    glowPlayable = {0, 1, 0, 0.3}          -- Green glow for playable cards
}

-- Load fonts
local function getCardFonts()
    -- Fancy font for card names
    local nameFont = love.graphics.newFont("assets/fonts/InknutAntiqua-Regular.ttf", 10)
    -- Larger font for stats (increased as requested)
    local statFont = love.graphics.newFont(13)
    -- Font for card text
    local textFont = love.graphics.newFont(10)
    -- Small font for card type and archetype text
    local typeFont = love.graphics.newFont(9)
    
    return {
        name = nameFont,
        stat = statFont,
        text = textFont,
        type = typeFont
    }
end

-- Cache fonts to avoid reloading them every frame
local cardFonts = nil

--------------------------------------------------
-- drawStatCircle: Helper to draw the stat circles
-- with optional background, border, and text outline
--------------------------------------------------
local function drawStatCircle(x, y, value, circleColor, bgColor)
    -- Draw background circle (slightly larger)
    love.graphics.setColor(bgColor)
    love.graphics.circle("fill", x, y, CIRCLE_RADIUS + 2)
    
    -- Draw main circle
    love.graphics.setColor(circleColor)
    love.graphics.circle("fill", x, y, CIRCLE_RADIUS)
    
    -- Draw border
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.circle("line", x, y, CIRCLE_RADIUS)
    
    -- Draw the stat value with black outline
    local valueStr = tostring(value)
    local font = cardFonts.stat
    love.graphics.setFont(font)
    
    -- Calculate text position for proper centering
    local textWidth = font:getWidth(valueStr)
    local textHeight = font:getHeight()
    local textX = x - textWidth / 2
    local textY = y - textHeight / 2
    
    -- Draw black outline by drawing text multiple times with slight offsets
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.print(valueStr, textX - 1, textY)
    love.graphics.print(valueStr, textX + 1, textY)
    love.graphics.print(valueStr, textX, textY - 1)
    love.graphics.print(valueStr, textX, textY + 1)
    
    -- Draw the main text on top
    love.graphics.setColor(COLORS.statText)
    love.graphics.print(valueStr, textX, textY)
end

--------------------------------------------------
-- getCardEffectText: Get appropriate text for card effects
-- For Minions, only return battlecry/deathrattle text if present.
--------------------------------------------------
local function getCardEffectText(card)
    if card.cardType == "Minion" then
        if card.battlecry then
            return "Battlecry: Draw a card"  -- Example text; adjust as needed
        elseif card.deathrattle then
            return "Deathrattle: Deal 2 damage"  -- Example text; adjust as needed
        else
            return ""  -- Do not show archetype here; it will be rendered separately
        end
    elseif card.cardType == "Spell" then
        return "Deal 6 damage to enemy hero"
    elseif card.cardType == "Weapon" then
        return "Equip a " .. card.attack .. "/" .. card.durability .. " weapon"
    end
    return ""
end

--------------------------------------------------
-- drawCard: Main function to render a card
--------------------------------------------------
function CardRenderer.drawCard(card, x, y, isPlayable)
    -- Initialize fonts if not already done
    if not cardFonts then
        cardFonts = getCardFonts()
    end

    local oldFont = love.graphics.getFont()
    
    -- Draw a green glow if the card is playable
    if isPlayable then
        local glowOffset = 6
        love.graphics.setColor(COLORS.glowPlayable)
        love.graphics.rectangle("fill", 
                                x - glowOffset, 
                                y - glowOffset, 
                                CARD_WIDTH + glowOffset * 2, 
                                CARD_HEIGHT + glowOffset * 2, 
                                CARD_CORNER_RADIUS + 2)
    end

    --------------------------------------------------
    -- 1. Card background and border
    --------------------------------------------------
    love.graphics.setColor(COLORS.border)
    love.graphics.rectangle("fill", x, y, CARD_WIDTH, CARD_HEIGHT, CARD_CORNER_RADIUS)
    
    love.graphics.setColor(COLORS.background)
    love.graphics.rectangle("fill", 
                            x + 3, 
                            y + 3, 
                            CARD_WIDTH - 6, 
                            CARD_HEIGHT - 6, 
                            CARD_CORNER_RADIUS - 2)
    
    love.graphics.setColor(COLORS.innerBorder)
    love.graphics.rectangle("fill",
                            x + 8,
                            y + 40, -- Moved down more to accommodate lower card name
                            CARD_WIDTH - 16,
                            CARD_HEIGHT - 60) -- Shorter to make room for type at bottom

    --------------------------------------------------
    -- 2. Card Name (in fancy font, positioned lower)
    --------------------------------------------------
    love.graphics.setFont(cardFonts.name)
    love.graphics.setColor(COLORS.cardName)
    love.graphics.printf(card.name, 
                         x + 10, 
                         y + 24, -- Moved down further as requested
                         CARD_WIDTH - 20, 
                         "center")

    --------------------------------------------------
    -- 3. Card Text Area (for battlecry, deathrattle, etc.)
    --------------------------------------------------
    local cardText = getCardEffectText(card)
    if cardText and cardText ~= "" then
        love.graphics.setFont(cardFonts.text)
        love.graphics.setColor(COLORS.cardText)
        love.graphics.printf(cardText,
                             x + 15,
                             y + 75, -- Adjusted for new layout
                             CARD_WIDTH - 30,
                             "center")
    end

    --------------------------------------------------
    -- 3.5 Archetype Text for Minions
    -- Render archetype text just above the card type banner if available.
    --------------------------------------------------
    if card.cardType == "Minion" and card.archetype and card.archetype ~= "" then
        love.graphics.setFont(cardFonts.type)
        love.graphics.setColor(COLORS.cardType)
        love.graphics.printf(card.archetype,
                             x + 3,
                             y + CARD_HEIGHT - 35,  -- Position adjusted for archetype text
                             CARD_WIDTH - 6,
                             "center")
    end

    --------------------------------------------------
    -- 4. Card Type at bottom
    --------------------------------------------------
    love.graphics.setColor(COLORS.typeBanner)
    love.graphics.rectangle("fill",
                            x + 3,
                            y + CARD_HEIGHT - 18,
                            CARD_WIDTH - 6,
                            15,
                            3)
    
    love.graphics.setFont(cardFonts.type)
    love.graphics.setColor(COLORS.cardType)
    love.graphics.printf(card.cardType, 
                         x + 3,
                         y + CARD_HEIGHT - 17,
                         CARD_WIDTH - 6,
                         "center")

    --------------------------------------------------
    -- 5. Stat Circles (drawn last to be on top layer)
    --------------------------------------------------
    local padX = 18
    local padY = 18
    
    -- Mana cost (top left, blue)
    drawStatCircle(x + padX, 
                   y + padY, 
                   card.cost, 
                   COLORS.manaCircle, 
                   COLORS.manaBg)
    
    if card.cardType == "Minion" then
        -- Movement (top right, white)
        drawStatCircle(x + CARD_WIDTH - padX, 
                       y + padY, 
                       card.movement or 1, 
                       COLORS.movementCircle, 
                       COLORS.movementBg)
                      
        -- Attack (bottom left, yellow)
        drawStatCircle(x + padX, 
                       y + CARD_HEIGHT - padY, 
                       card.attack, 
                       COLORS.attackCircle, 
                       COLORS.attackBg)
                      
        -- Health (bottom right, red)
        drawStatCircle(x + CARD_WIDTH - padX, 
                       y + CARD_HEIGHT - padY, 
                       card.health, 
                       COLORS.healthCircle, 
                       COLORS.healthBg)
    elseif card.cardType == "Weapon" then
        -- For weapons, display attack and durability
        drawStatCircle(x + padX, 
                       y + CARD_HEIGHT - padY, 
                       card.attack, 
                       COLORS.attackCircle, 
                       COLORS.attackBg)
                      
        drawStatCircle(x + CARD_WIDTH - padX, 
                       y + CARD_HEIGHT - padY, 
                       card.durability, 
                       COLORS.healthCircle, 
                       COLORS.healthBg)
    end

    -- Reset color and font
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(oldFont)
end

--------------------------------------------------
-- getCardDimensions: Return card size for layout
--------------------------------------------------
function CardRenderer.getCardDimensions()
    return CARD_WIDTH, CARD_HEIGHT
end

return CardRenderer
