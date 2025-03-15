-- game/managers/animationmanager.lua
-- Manages and plays animations in the game using anim8 library
-- Fully integrated with the EventBus system

local AnimationManager = {}
AnimationManager.__index = AnimationManager

local EventBus = require("game.eventbus")
local BoardRenderer = require("game.ui.boardrenderer")
local Debug = require("game.utils.debug")

-- First check if anim8 is available, and handle errors gracefully
local anim8
local hasAnim8 = pcall(function()
    anim8 = require("libs.anim8")
end)

if not hasAnim8 then
    Debug.error("Failed to load anim8 library from libs/anim8.lua")
    -- Create a dummy anim8 implementation to prevent crashes
    anim8 = {
        newGrid = function() return {} end,
        newAnimation = function() return {
            update = function() end,
            draw = function() end,
            clone = function() return {
                update = function() end,
                draw = function() end,
                pauseAtEnd = function() end
            } end,
            pauseAtEnd = function() end
        } end
    }
end

-- Store active animations
AnimationManager.activeAnimations = {}

-- Store loaded spritesheets and animations
AnimationManager.resources = {
    images = {},    -- Spritesheet images
    grids = {},     -- anim8 grids for spritesheets
    animations = {} -- Animation definitions
}

-- Animation registry - maps event types to animation configurations
AnimationManager.animationRegistry = {
    ["Fireball"] = {
        spritesheet = "explosion",
        framerate = 0.1,
        loop = false,
        offset = {x = 0, y = 0},
        scale = "auto", -- Will be calculated to fit the tile
        soundEffect = "fireball"
    },
    ["Arcane Shot"] = {  -- Add Arcane Shot animation
        spritesheet = "explosion", -- Using the same explosion sprite
        framerate = 0.1,
        loop = false,
        offset = {x = 0, y = 0},
        scale = "auto",
        soundEffect = "arcane_shot" -- Optional: different sound effect if available
    }
}

-- Event subscriptions
AnimationManager.eventSubscriptions = {}

-- Flag to track if the manager initialized successfully
AnimationManager.initialized = false

--------------------------------------------------
-- init(): Initialize the animation manager
--------------------------------------------------
function AnimationManager:init()
    Debug.addToCallTrace("AnimationManager:init")
    
    -- Clean up any existing subscriptions
    self:clearEventSubscriptions()
    
    -- Flag to allow the game to run even without animations
    self.disableAnimations = false
    
    -- Try to load resources
    local success = self:loadResources()
    
    -- If loading resources failed, make a note but allow the game to continue
    if not success then
        Debug.error("Failed to load animation resources - disabling animations")
        self.disableAnimations = true
    end
    
    -- Subscribe to animation-related events
    self:initEventSubscriptions()
    
    self.initialized = true
    Debug.info("Animation Manager initialized with animations " .. 
               (self.disableAnimations and "DISABLED" or "ENABLED"))
    
    return self
end

--------------------------------------------------
-- clearEventSubscriptions(): Clean up subscriptions
--------------------------------------------------
function AnimationManager:clearEventSubscriptions()
    for _, sub in ipairs(self.eventSubscriptions) do
        EventBus.unsubscribe(sub)
    end
    self.eventSubscriptions = {}
end

--------------------------------------------------
-- initEventSubscriptions(): Set up event listeners
--------------------------------------------------
function AnimationManager:initEventSubscriptions()
    -- Listen for spell cast events
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.SPELL_CAST,
        function(player, spellName, target)
            if spellName == "Fireball" and target then
                self:playAnimation("Fireball", target.position.x, target.position.y)
            elseif spellName == "Arcane Shot" and target then
                -- Handle Arcane Shot animation
                local posX, posY
                if target.position then
                    -- Target is either a minion or tower with a position
                    posX, posY = target.position.x, target.position.y
                    self:playAnimation("Arcane Shot", posX, posY)
                end
            end
        end,
        "AnimationManager-SpellCast"
    ))
    
    -- Listen for minion attack events
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.MINION_ATTACKED,
        function(attacker, target)
            -- Will implement attack animations later
        end,
        "AnimationManager-MinionAttack"
    ))
    
    -- Listen for tower damaged events
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.TOWER_DAMAGED,
        function(tower, source, damage)
            -- Will implement tower damage animations later
        end,
        "AnimationManager-TowerDamage"
    ))
    
    -- For future animations based on different events
    -- Add more event subscriptions here
end

--------------------------------------------------
-- loadResources(): Load all animation resources
--------------------------------------------------
function AnimationManager:loadResources()
    -- Guard against missing anim8
    if not hasAnim8 then
        Debug.error("Cannot load animation resources - anim8 library is missing")
        return false
    end
    
    -- We'll track if all resources loaded correctly
    local allResourcesLoaded = true
    
    -- Try loading the explosion image safely
    local explosionPath = "assets/images/explosion.png"
    if love.filesystem.getInfo(explosionPath) then
        Debug.info("Loading explosion image from " .. explosionPath)
        
        -- Use pcall to catch any loading errors
        local success, result = pcall(function()
            return love.graphics.newImage(explosionPath)
        end)
        
        if success then
            self.resources.images.explosion = result
            Debug.info("Explosion image loaded successfully")
        else
            Debug.error("Failed to load explosion image: " .. tostring(result))
            allResourcesLoaded = false
        end
    else
        Debug.error("Explosion image file not found at " .. explosionPath)
        allResourcesLoaded = false
    end
    
    -- If we failed to load the image, don't try to create animations from it
    if not self.resources.images.explosion then
        return false
    end
    
    -- Try creating animation grid
    local success, result = pcall(function()
        -- Create grid for the explosion (9 frames horizontally, each 192x192 pixels)
        return anim8.newGrid(192, 192, 1728, 192)
    end)
    
    if success then
        self.resources.grids.explosion = result
        Debug.info("Explosion grid created successfully")
    else
        Debug.error("Failed to create explosion grid: " .. tostring(result))
        allResourcesLoaded = false
    end
    
    -- Try creating the animation
    success, result = pcall(function()
        -- Create explosion animation (9 frames, once)
        return anim8.newAnimation(
            self.resources.grids.explosion('1-9', 1),
            0.1, -- 0.1 seconds per frame
            function(anim) -- onLoop callback
                anim:pauseAtEnd() -- Stop on the last frame
                EventBus.publish(EventBus.Events.ANIMATION_COMPLETED, "Fireball")
            end
        )
    end)
    
    if success then
        self.resources.animations.explosion = result
        Debug.info("Explosion animation created successfully")
    else
        Debug.error("Failed to create explosion animation: " .. tostring(result))
        allResourcesLoaded = false
    end
    
    -- Load sound effects for animations (if applicable)
    -- Example: self.sounds.fireball = love.audio.newSource("assets/sounds/fireball.ogg", "static")
    
    Debug.info(allResourcesLoaded and "All animation resources loaded successfully" or 
                              "Some animation resources could not be loaded")
    
    return allResourcesLoaded
end

--------------------------------------------------
-- playAnimation(): Play an animation at a position
--------------------------------------------------
function AnimationManager:playAnimation(animationType, gridX, gridY)
    -- If animations are disabled, just fire the completion event immediately
    if self.disableAnimations then
        EventBus.publish(EventBus.Events.ANIMATION_COMPLETED, animationType, gridX, gridY)
        return nil
    end
    
    -- Get the animation configuration
    local config = self.animationRegistry[animationType]
    if not config then
        Debug.warn("Animation not configured: " .. animationType)
        EventBus.publish(EventBus.Events.ANIMATION_COMPLETED, animationType, gridX, gridY)
        return nil
    end
    
    -- Check if we have the resources
    if not self.resources.animations[config.spritesheet] then
        Debug.warn("Animation resources not loaded for: " .. animationType)
        EventBus.publish(EventBus.Events.ANIMATION_COMPLETED, animationType, gridX, gridY)
        return nil
    end
    
    -- Get board coordinates
    local boardX, boardY = BoardRenderer.getBoardPosition()
    local tileSize = BoardRenderer.getTileSize()
    
    -- Calculate animation position (center of the tile)
    local x = boardX + (gridX - 1) * tileSize + tileSize / 2
    local y = boardY + (gridY - 1) * tileSize + tileSize / 2
    
    -- Calculate scale (if auto)
    local scale = 1
    if config.scale == "auto" then
        scale = tileSize / 192 -- For explosion, adapt to tile size
    else
        scale = config.scale
    end
    
    -- Clone the animation for this instance
    local anim = self.resources.animations[config.spritesheet]:clone()
    
    -- Add to active animations
    local animInstance = {
        type = animationType,
        animation = anim,
        image = self.resources.images[config.spritesheet],
        x = x + (config.offset.x or 0),
        y = y + (config.offset.y or 0),
        scale = scale,
        done = false,
        gridX = gridX,
        gridY = gridY,
        startTime = love.timer.getTime()
    }
    
    -- Add callback to mark as done when it completes
    if not config.loop then
        animInstance.animation.onLoop = function(anim)
            anim:pauseAtEnd()
            animInstance.done = true
        end
    end
    
    table.insert(self.activeAnimations, animInstance)
    
    -- Play sound effect if configured
    if config.soundEffect then
        -- Add sound playback when sound effects are implemented
    end
    
    -- Publish animation started event
    EventBus.publish(EventBus.Events.ANIMATION_STARTED, animationType, gridX, gridY)
    
    Debug.info(string.format("Playing animation '%s' at grid position %d,%d", 
                           animationType, gridX, gridY))
    
    return animInstance
end

--------------------------------------------------
-- update(dt): Update all active animations
--------------------------------------------------
function AnimationManager:update(dt)
    -- Skip if animations are disabled
    if self.disableAnimations then
        return
    end
    
    -- Update all animations
    for i = #self.activeAnimations, 1, -1 do
        local anim = self.activeAnimations[i]
        
        -- Use pcall to catch any update errors
        local success, err = pcall(function()
            anim.animation:update(dt)
        end)
        
        if not success then
            Debug.error("Error updating animation: " .. tostring(err))
            -- Mark as done to remove it
            anim.done = true
        end
        
        -- Remove finished animations
        if anim.done then
            -- Publish animation completed event if not already done
            EventBus.publish(EventBus.Events.ANIMATION_COMPLETED, 
                           anim.type, anim.gridX, anim.gridY)
            
            table.remove(self.activeAnimations, i)
        end
    end
end

--------------------------------------------------
-- draw(): Draw all active animations
--------------------------------------------------
function AnimationManager:draw()
    -- Skip if animations are disabled
    if self.disableAnimations then
        return
    end
    
    for _, anim in ipairs(self.activeAnimations) do
        love.graphics.setColor(1, 1, 1, 1)
        
        -- Use pcall to catch any drawing errors
        local success, err = pcall(function()
            -- Draw the animation
            anim.animation:draw(
                anim.image,
                anim.x,
                anim.y,
                0, -- rotation
                anim.scale, -- scale x
                anim.scale, -- scale y
                192/2, -- origin x (center of frame)
                192/2  -- origin y (center of frame)
            )
        end)
        
        if not success then
            Debug.error("Error drawing animation: " .. tostring(err))
            -- Mark as done to remove it next update
            anim.done = true
        end
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

--------------------------------------------------
-- hasActiveAnimations(): Check if animations are playing
--------------------------------------------------
function AnimationManager:hasActiveAnimations()
    -- If animations are disabled, pretend there are none
    if self.disableAnimations then
        return false
    end
    
    return #self.activeAnimations > 0
end

--------------------------------------------------
-- destroy(): Clean up resources
--------------------------------------------------
function AnimationManager:destroy()
    self:clearEventSubscriptions()
    self.activeAnimations = {}
    Debug.info("Animation Manager destroyed")
end

--------------------------------------------------
-- Create a singleton instance
--------------------------------------------------
local function createInstance()
    Debug.addToCallTrace("AnimationManager:createInstance")
    local instance = setmetatable({}, AnimationManager)
    
    -- Use pcall to catch any initialization errors
    local success, err = pcall(function()
        instance:init()
    end)
    
    if not success then
        Debug.error("Failed to initialize AnimationManager: " .. tostring(err))
        -- Create a minimal functional instance that won't crash
        instance.initialized = false
        instance.disableAnimations = true
        instance.activeAnimations = {}
        instance.update = function() end
        instance.draw = function() end
        instance.hasActiveAnimations = function() return false end
        instance.playAnimation = function(self, type, x, y)
            EventBus.publish(EventBus.Events.ANIMATION_COMPLETED, type, x, y)
            return nil
        end
    end
    
    return instance
end

local instance = createInstance()
return instance