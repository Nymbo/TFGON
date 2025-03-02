-- game/core/board.lua
-- This module now creates boards based on provided configuration.
-- Integrated with EventBus for movement events.
local Board = {}
Board.__index = Board

local EventBus = require("game/eventbus")  -- Added EventBus import

function Board:new(config)
    local self = setmetatable({}, Board)
    
    -- Use config or default to 9x9
    config = config or {}
    self.cols = config.cols or 9
    self.rows = config.rows or 9
    
    -- Initialize a 2D array for tiles: tiles[y][x]
    self.tiles = {}
    for y = 1, self.rows do
        self.tiles[y] = {}
        for x = 1, self.cols do
            self.tiles[y][x] = nil
        end
    end
    
    -- Store the tower positions if any
    self.towerPositions = config.towerPositions
    
    return self
end

function Board:isEmpty(x, y)
    return self.tiles[y] and self.tiles[y][x] == nil
end

function Board:placeMinion(minion, x, y)
    if self:isEmpty(x, y) then
        self.tiles[y][x] = minion
        minion.position = { x = x, y = y }
        
        -- Use MINION_SUMMONED instead of MINION_PLACED (which doesn't exist)
        EventBus.publish(EventBus.Events.MINION_SUMMONED, minion.owner, minion, x, y)
        
        return true
    else
        return false
    end
end

function Board:moveMinion(fromX, fromY, toX, toY)
    if self.tiles[fromY] and self.tiles[fromY][fromX] and self:isEmpty(toX, toY) then
        local minion = self.tiles[fromY][fromX]
        
        -- Store old position for event
        local oldPosition = { x = fromX, y = fromY }
        
        -- Update board state
        self.tiles[fromY][fromX] = nil
        self.tiles[toY][toX] = minion
        minion.position = { x = toX, y = toY }
        
        -- Publish movement event with before/after positions
        EventBus.publish(EventBus.Events.MINION_MOVED, minion, oldPosition, minion.position)
        return true
    end
    return false
end

function Board:getMinionAt(x, y)
    if self.tiles[y] then
        return self.tiles[y][x]
    end
    return nil
end

function Board:removeMinion(x, y)
    if self.tiles[y] and self.tiles[y][x] then
        local minion = self.tiles[y][x]
        
        -- No direct "REMOVED" event, so use EFFECT_TRIGGERED
        EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "MinionRemoved", minion, x, y)
        
        -- Remove the minion
        self.tiles[y][x] = nil
        
        return minion
    end
    return nil
end

-- Helper to iterate over all minions on the board
function Board:forEachMinion(callback)
    for y = 1, self.rows do
        for x = 1, self.cols do
            local minion = self.tiles[y][x]
            if minion then
                callback(minion, x, y)
            end
        end
    end
end

--------------------------------------------------
-- applyDamageToMinion: Apply damage to a minion
-- Publishes MINION_DAMAGED event
--------------------------------------------------
function Board:applyDamageToMinion(minion, damage, source)
    if not minion or damage <= 0 then return false end
    
    -- Store old health for event
    local oldHealth = minion.currentHealth
    
    -- Apply damage
    minion.currentHealth = minion.currentHealth - damage
    
    -- Publish minion damaged event
    EventBus.publish(EventBus.Events.MINION_DAMAGED, 
        minion,   -- The minion that was damaged
        source,   -- The source of the damage (can be nil)
        damage,   -- Amount of damage
        oldHealth, -- Health before damage
        minion.currentHealth -- Health after damage
    )
    
    -- Check if minion died
    if minion.currentHealth <= 0 then
        -- We let the combat system or game manager handle minion death
        -- But we can publish a minion died event
        EventBus.publish(EventBus.Events.MINION_DIED, minion, source)
    end
    
    return true
end

--------------------------------------------------
-- healMinion: Heal a minion and publish event
--------------------------------------------------
function Board:healMinion(minion, amount, source)
    if not minion or amount <= 0 then return false end
    
    -- Store old health for event
    local oldHealth = minion.currentHealth
    
    -- Apply healing (capped at maxHealth)
    minion.currentHealth = math.min(minion.maxHealth, minion.currentHealth + amount)
    
    -- Only publish event if healing actually happened
    if minion.currentHealth > oldHealth then
        EventBus.publish(EventBus.Events.MINION_HEALED, 
            minion,   -- The minion that was healed
            source,   -- The source of the healing (can be nil)
            amount,   -- Amount of healing attempted
            oldHealth, -- Health before healing
            minion.currentHealth -- Health after healing
        )
        return true
    end
    
    return false
end

--------------------------------------------------
-- buffMinion: Apply stat buffs to a minion
--------------------------------------------------
function Board:buffMinion(minion, attackBuff, healthBuff, source)
    if not minion then return false end
    
    local changed = false
    local oldAttack = minion.attack
    local oldMaxHealth = minion.maxHealth
    local oldCurrentHealth = minion.currentHealth
    
    -- Apply attack buff
    if attackBuff and attackBuff ~= 0 then
        minion.attack = math.max(0, minion.attack + attackBuff)
        changed = true
    end
    
    -- Apply health buff
    if healthBuff and healthBuff ~= 0 then
        minion.maxHealth = math.max(1, minion.maxHealth + healthBuff)
        
        -- If it's a positive health buff, also increase current health
        if healthBuff > 0 then
            minion.currentHealth = minion.currentHealth + healthBuff
        else
            -- If it's a negative health buff, ensure current health doesn't exceed max
            minion.currentHealth = math.min(minion.currentHealth, minion.maxHealth)
        end
        
        changed = true
    end
    
    -- If anything changed, publish event (using EFFECT_TRIGGERED instead of MINION_BUFFED)
    if changed then
        EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "MinionBuffed", 
            minion,    -- The minion that was buffed
            source,    -- The source of the buff (can be nil)
            attackBuff, -- Attack buff amount
            healthBuff, -- Health buff amount
            { -- Old stats
                attack = oldAttack,
                maxHealth = oldMaxHealth,
                currentHealth = oldCurrentHealth
            },
            { -- New stats
                attack = minion.attack,
                maxHealth = minion.maxHealth,
                currentHealth = minion.currentHealth
            }
        )
        return true
    end
    
    return false
end

--------------------------------------------------
-- addMinionEffect: Add a temporary effect to a minion
--------------------------------------------------
function Board:addMinionEffect(minion, effectType, duration, source)
    if not minion then return false end
    
    -- Initialize effects table if not exists
    minion.effects = minion.effects or {}
    
    -- Add the effect
    table.insert(minion.effects, {
        type = effectType,
        duration = duration,
        source = source
    })
    
    -- Publish effect added event using EFFECT_TRIGGERED instead of MINION_EFFECT_ADDED
    EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "MinionEffectAdded", 
        minion,
        effectType,
        duration,
        source
    )
    
    return true
end

--------------------------------------------------
-- updateMinionEffects: Update duration of temporary effects
--------------------------------------------------
function Board:updateMinionEffects()
    self:forEachMinion(function(minion, x, y)
        if minion.effects then
            for i = #minion.effects, 1, -1 do
                local effect = minion.effects[i]
                
                -- Decrease duration
                if effect.duration > 0 then
                    effect.duration = effect.duration - 1
                end
                
                -- Remove expired effects
                if effect.duration <= 0 then
                    EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "MinionEffectRemoved", 
                        minion,
                        effect.type,
                        effect.source
                    )
                    table.remove(minion.effects, i)
                end
            end
        end
    end)
end

return Board