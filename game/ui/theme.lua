-- game/ui/theme.lua
local Theme = {}

Theme.colors = {
    -- Base Colors
    primary = {0.8, 0.7, 0.5, 1},    -- Gold/Tan (Main accent color)
    secondary = {0.2, 0.4, 0.8, 1},  -- Blue (Secondary accent)
    background = {0.1, 0.1, 0.1, 1},   -- Very dark gray (Main background)
    backgroundLight = {0.15, 0.15, 0.18, 1}, -- Slightly lighter background for panels
    gridLine = {0, 0, 0, 1},       -- Grid lines

    -- Text Colors
    textPrimary = {1, 0.95, 0.8, 1},     -- Light cream (Main text)
    textSecondary = {0.7, 0.7, 0.8, 1},   -- Light blue-gray (Less important text)
    textHover = {1, 0.8, 0.2, 1},        -- Yellow (For hover states)
    textMuted = {0.5, 0.5, 0.5, 1},      -- Gray (For disabled or less important text)

    -- Button Colors
    buttonBase = {0.3, 0.3, 0.35, 1},
    buttonGradientTop = {0.5, 0.5, 0.55, 1},
    buttonBorder = {0.8, 0.7, 0.5, 1},
    buttonText = {1, 0.95, 0.8, 1},
    buttonHover = {0.4, 0.4, 0.45, 1},
    buttonActive = {0.2, 0.2, 0.25, 1}, -- darker shade for when the button is pressed
    buttonShadow = {0, 0, 0, 0.5},
    buttonGlowHover = {1, 0.6, 0, 0.3},

    -- Card Colors
    cardBackground = {0.2, 0.2, 0.25, 1},
    cardBorderP1 = {0.173, 0.243, 0.314, 1},
    cardBorderP2 = {1, 0, 0, 1},
    cardText = {0.9, 0.9, 0.9, 1},
    cardType = {0.7, 0.7, 0.8, 1},
    typeBanner = {0.25, 0.25, 0.3, 1},

    -- Stat Circle Colors
    manaCircle = {0.2, 0.4, 0.8, 1},
    manaBg = {0.15, 0.25, 0.5, 1},
    attackCircle = {0.9, 0.8, 0.2, 1},
    attackBg = {0.5, 0.4, 0.1, 1},
    healthCircle = {0.8, 0.2, 0.2, 1},
    healthBg = {0.5, 0.15, 0.15, 1},
    movementCircle = {0.9, 0.9, 0.9, 1},
    movementBg = {0.4, 0.4, 0.4, 1},

    -- Slider Colors
    sliderTrackBase = {0.2, 0.2, 0.25, 1},
    sliderTrackTop = {0.4, 0.4, 0.45, 1},
    sliderKnob = {0.8, 0.7, 0.5, 1},
    sliderKnobShine = {1, 0.9, 0.6, 1},
    sliderKnobShadow = {0, 0, 0, 0.5},
    sliderGlowDrag = {0, 1, 0, 0.3},

    -- Other UI Elements
    accentGreen = {0, 1, 0, 1},
    accentBlue = {0, 0.4, 1, 1},
    spawnZone = {0.8, 0.8, 0.8, 0.3},
    selectionOutline = {1, 1, 0, 1},  -- Yellow, for highlighting selected units
    validMove = {0, 1, 0, 0.3},      -- Green, for valid move squares
    invalidMove = {1, 0, 0, 0.3},    -- Red, for invalid move squares
}

Theme.fonts = {
    title = love.graphics.newFont("assets/fonts/InknutAntiqua-Regular.ttf", 48),
    subtitle = love.graphics.newFont("assets/fonts/InknutAntiqua-Regular.ttf", 24),
    body = love.graphics.newFont("assets/fonts/InknutAntiqua-Regular.ttf", 14),
    button = love.graphics.newFont("assets/fonts/InknutAntiqua-Regular.ttf", 16),
    label = love.graphics.newFont("assets/fonts/InknutAntiqua-Regular.ttf", 14),  --same as body
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
    buttonActiveOffset = 2, -- how much the button moves down when pressed
    sliderWidth = 400,
    sliderHeight = 12,
    sliderKnobRadius = 18,
    sliderShadowOffset = 4,
    sliderGlowOffset = 6,
    cardDepressedOffset = 2,    -- How much card visuals "sink" when played.
}

Theme.sounds = {
    click = "assets/sounds/click1.ogg",  -- We already have this one
    cardPlay = "assets/sounds/card_play.ogg", -- Add this sound
    cardDraw = "assets/sounds/card_draw.ogg", -- Add this sound
    minionAttack = "assets/sounds/minion_attack.ogg", -- Add this sound
    minionDeath = "assets/sounds/minion_death.ogg", -- Add this sound
    turnStart = "assets/sounds/turn_start.ogg",      -- Add this sound
    invalidAction = "assets/sounds/invalid_action.ogg", -- Add this
    buttonPress = "assets/sounds/button_press.ogg",
    cardHover = "assets/sounds/card_hover.ogg",
}

Theme.images = {
    --  Example:  You might have a common background for panels
    panelBackground = "assets/images/panel_background.png",
    --  You could have icons for mana, health, attack, etc.
    manaIcon = "assets/images/mana_icon.png",
    healthIcon = "assets/images/health_icon.png",
    attackIcon = "assets/images/attack_icon.png",
}

-- Conceptual section for animations (implementation later)
Theme.animations = {
    cardDrawDuration = 0.5,   -- seconds
    cardPlayDuration = 0.3,
    minionMoveDuration = 0.4,
    attackAnimationDuration = 0.2,
    fadeInDuration = 0.3,
    fadeOutDuration = 0.3,
    easing = "outQuad",       -- Example easing function (we'd need to implement this)
}

return Theme