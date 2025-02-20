-- game/ui/theme.lua
local Theme = {}
Theme.colors = {
    -- Existing colors...
    background = {0.1, 0.1, 0.1, 1},
    textPrimary = {1, 0.95, 0.8, 1},
    textHover = {1, 0.8, 0.2, 1},
    buttonBase = {0.3, 0.3, 0.35, 1},
    buttonGradientTop = {0.5, 0.5, 0.55, 1},
    buttonBorder = {0.8, 0.7, 0.5, 1},
    buttonShadow = {0, 0, 0, 0.5},
    buttonGlowHover = {1, 0.6, 0, 0.3},
    sliderTrackBase = {0.2, 0.2, 0.25, 1},
    sliderTrackTop = {0.4, 0.4, 0.45, 1},
    sliderKnob = {0.8, 0.7, 0.5, 1},
    sliderKnobShine = {1, 0.9, 0.6, 1},
    sliderKnobShadow = {0, 0, 0, 0.5},
    sliderGlowDrag = {0, 1, 0, 0.3},
    cardBackground = {0.2, 0.2, 0.25, 1},
    cardBorderP1 = {0.173, 0.243, 0.314, 1},
    cardBorderP2 = {1, 0, 0, 1},
    accentGreen = {0, 1, 0, 1},
    accentBlue = {0, 0.4, 1, 1},
    -- New additions
    spawnZone = {0.8, 0.8, 0.8, 0.3},  -- For spawn zones
    gridLine = {0, 0, 0, 1},           -- Grid lines
    movementCircle = {0.9, 0.9, 0.9, 1},
    movementBg = {0.4, 0.4, 0.4, 1},
    attackCircle = {0.9, 0.8, 0.2, 1},
    attackBg = {0.5, 0.4, 0.1, 1},
    healthCircle = {0.8, 0.2, 0.2, 1},
    healthBg = {0.5, 0.15, 0.15, 1}
}
Theme.fonts = {
    button = love.graphics.newFont("assets/fonts/InknutAntiqua-Regular.ttf", 16),
    label = love.graphics.newFont("assets/fonts/InknutAntiqua-Regular.ttf", 14),
    cardName = love.graphics.newFont("assets/fonts/InknutAntiqua-Regular.ttf", 10),
    cardStat = love.graphics.newFont(12),
    cardType = love.graphics.newFont(9)
}
Theme.dimensions = {
    buttonWidth = 140,
    buttonHeight = 50,
    buttonCornerRadius = 8,
    buttonShadowOffset = 4,
    buttonGlowOffset = 8,
    sliderWidth = 400,
    sliderHeight = 12,
    sliderKnobRadius = 18,
    sliderShadowOffset = 4,
    sliderGlowOffset = 6
}
return Theme