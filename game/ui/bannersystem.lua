-- game/ui/bannersystem.lua
-- A dedicated module to handle banner display in response to game events
-- Uses the event-based architecture for better decoupling

local BannerSystem = {}
BannerSystem.__index = BannerSystem

local EventBus = require("game/eventbus")

--------------------------------------------------
-- Constructor for BannerSystem.
-- Creates a new banner system that listens for banner events.
--------------------------------------------------
function BannerSystem:new()
    local self = setmetatable({}, BannerSystem)
    self.currentBanner = nil
    self.bannerDuration = 1.5  -- Duration in seconds
    
    -- Initialize event subscriptions
    self.eventSubscriptions = {}
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.BANNER_DISPLAYED,
        function(bannerType, text)
            self:showBanner(bannerType, text)
        end,
        "BannerSystem"
    ))
    
    return self
end

--------------------------------------------------
-- showBanner(bannerType, text):
-- Display a banner of the specified type with the given text.
--------------------------------------------------
function BannerSystem:showBanner(bannerType, text)
    local imagePath
    if bannerType == "player" then
        imagePath = "assets/images/Ribbon_Blue_3Slides.png"
    else
        imagePath = "assets/images/Ribbon_Red_3Slides.png"
    end
    
    self.currentBanner = {
        image = love.graphics.newImage(imagePath),
        text = text,
        timer = self.bannerDuration
    }
    
    -- Could play sound here
    -- love.audio.play(self.bannerSound)
end

--------------------------------------------------
-- update(dt):
-- Update the banner timer.
--------------------------------------------------
function BannerSystem:update(dt)
    if self.currentBanner and self.currentBanner.timer > 0 then
        self.currentBanner.timer = self.currentBanner.timer - dt
    end
end

--------------------------------------------------
-- draw():
-- Draw the current banner if active.
--------------------------------------------------
function BannerSystem:draw()
    if self.currentBanner and self.currentBanner.timer > 0 then
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()
        
        local iw = self.currentBanner.image:getWidth()
        local ih = self.currentBanner.image:getHeight()
        local scale = 2  -- Same scale used in gameplay.lua
        local scaledWidth = iw * scale
        local scaledHeight = ih * scale
        
        -- Position in center of screen
        local cx = screenWidth / 2
        local cy = screenHeight / 2
        
        -- Draw banner image
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(
            self.currentBanner.image, 
            cx - (scaledWidth / 2), 
            cy - (scaledHeight / 2), 
            0, 
            scale, 
            scale
        )
        
        -- Get font or use default
        local oldFont = love.graphics.getFont()
        local bannerFont = love.graphics.newFont("assets/fonts/InknutAntiqua-Regular.ttf", 16)
        love.graphics.setFont(bannerFont)
        
        -- Draw banner text with outline
        love.graphics.setColor(1, 1, 1, 1)
        local textX = cx - (scaledWidth / 2)
        local textY = cy - (scaledHeight / 2) + (scaledHeight * 0.3) - 5
        
        -- Draw text outline
        love.graphics.printf(self.currentBanner.text, textX + 1, textY, scaledWidth, "center")
        love.graphics.printf(self.currentBanner.text, textX - 1, textY, scaledWidth, "center")
        love.graphics.printf(self.currentBanner.text, textX, textY + 1, scaledWidth, "center")
        love.graphics.printf(self.currentBanner.text, textX, textY - 1, scaledWidth, "center")
        
        -- Draw main text
        love.graphics.printf(self.currentBanner.text, textX, textY, scaledWidth, "center")
        
        -- Restore original font
        love.graphics.setFont(oldFont)
    end
end

--------------------------------------------------
-- destroy():
-- Clean up event subscriptions to prevent memory leaks.
--------------------------------------------------
function BannerSystem:destroy()
    for _, sub in ipairs(self.eventSubscriptions) do
        EventBus.unsubscribe(sub)
    end
    self.eventSubscriptions = {}
end

return BannerSystem