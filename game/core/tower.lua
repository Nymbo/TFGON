-- game/core/tower.lua
-- Defines a Tower object that can be placed anywhere on any board.
-- Refactored to support event-based interactions

local Tower = {}
Tower.__index = Tower
local EventBus = require("game.eventbus")

--------------------------------------------------
-- Tower:new(params)
-- Constructor for a new Tower.
-- Expects a table 'params' with:
--   - owner: the owner of the tower (player object)
--   - position: table with x and y (grid coordinates)
--   - hp: hit points for the tower
--   - imagePath: file path to the tower's image
--------------------------------------------------
function Tower:new(params)
    local self = setmetatable({}, Tower)
    self.owner = params.owner
    self.position = params.position or { x = 0, y = 0 }
    self.hp = params.hp or 30
    self.maxHp = params.hp or 30  -- Added maxHp to track original health
    self.imagePath = params.imagePath or "assets/images/default_tower.png"
    self.image = love.graphics.newImage(self.imagePath)  -- Load the tower image
    
    -- Publish tower created event
    EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "TowerInitialized", self)
    
    return self
end

--------------------------------------------------
-- takeDamage: Applies damage to the tower and publishes events
-- Returns true if the damage was applied and false otherwise
--------------------------------------------------
function Tower:takeDamage(amount, source)
    if amount <= 0 then return false end
    
    -- Store old health for event
    local oldHealth = self.hp
    
    -- Calculate new health
    local newHealth = self.hp - amount
    
    -- IMPORTANT: Apply the damage directly as a fallback
    -- This ensures damage works even if event handlers aren't properly set up
    self.hp = newHealth
    
    -- Publish tower damaged event - GameManager's handler will also update the health
    EventBus.publish(EventBus.Events.TOWER_DAMAGED, 
        self,       -- The tower
        source,     -- Damage source
        amount,     -- Damage amount
        oldHealth,  -- Old health
        newHealth   -- New health
    )
    
    return true
end

--------------------------------------------------
-- heal: Heals the tower and publishes events
-- Returns true if healing was applied, false if already at max health
--------------------------------------------------
function Tower:heal(amount, source)
    if amount <= 0 or self.hp >= self.maxHp then return false end
    
    -- Store old health for event
    local oldHealth = self.hp
    
    -- Calculate new health (capped at maxHp)
    local newHealth = math.min(self.maxHp, self.hp + amount)
    
    -- IMPORTANT: Apply the healing directly as a fallback
    -- This ensures healing works even if event handlers aren't properly set up
    self.hp = newHealth
    
    -- Publish tower healed event
    EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "TowerHealed", 
        self,       -- The tower
        source,     -- Healing source
        amount,     -- Healing amount
        oldHealth,  -- Old health
        newHealth   -- New health
    )
    
    return true
end

return Tower