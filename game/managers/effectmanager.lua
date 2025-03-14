-- game/managers/effectmanager.lua
-- Centralizes card effect logic for spells/weapons (via effectKey),
-- plus functions to trigger Battlecry and Deathrattle on minions.
-- Now with support for targeted effects and minion weapons!
-- Refactored to reduce duplicate code in weapon effects
-- Now integrated with EventBus for decoupled architecture
-- Fixed Fireball effect to use proper event parameters

local EffectManager = {}
local EventBus = require("game.eventbus")  -- Import the EventBus

--------------------------------------------------
-- Helper: createWeaponEffect
-- Factory function to create weapon effect definitions 
-- with consistent behavior but different archetype requirements.
--------------------------------------------------
local function createWeaponEffect(archetypeRequirement)
    return {
        requiresTarget = true,
        targetType = "FriendlyMinion",
        validationFn = function(minion, card)
            -- Check if this minion can equip this weapon (matches archetype)
            return minion.archetype == card.archetypeRequirement
        end,
        effectFn = function(gameManager, player, target, card)
            -- Apply weapon to the minion
            if target and target.archetype == card.archetypeRequirement then
                local baseAttack
                
                -- Check if minion already has a weapon equipped
                if target.weapon then
                    -- If replacing a weapon, use the stored baseAttack
                    baseAttack = target.weapon.baseAttack
                    
                    -- Remove the old weapon's attack bonus
                    target.attack = baseAttack
                    
                    -- Publish weapon removed event
                    EventBus.publish(EventBus.Events.WEAPON_BROKEN, target, target.weapon)
                    
                    print(target.name .. " discarded " .. target.weapon.name .. "!")
                else
                    -- No previous weapon, current attack is base attack
                    baseAttack = target.attack
                end
                
                -- Create the weapon object for the minion
                target.weapon = {
                    name = card.name,
                    attack = card.attack,
                    durability = card.durability,
                    baseAttack = baseAttack  -- Store original attack without weapon bonuses
                }
                
                -- Boost the minion's attack
                target.attack = baseAttack + card.attack
                
                -- Publish weapon equipped event
                EventBus.publish(EventBus.Events.WEAPON_EQUIPPED, target, target.weapon)
                
                print(target.name .. " equipped " .. card.name .. "!")
                return true
            else
                print("Warning: Weapon cannot be equipped by this minion")
                
                -- Publish failed weapon equip event
                EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "WeaponEquipFailed", target, card)
                
                return false
            end
        end
    }
end

--------------------------------------------------
-- effectRegistry:
--   A lookup table that maps an 'effectKey' string
--   to an effect definition containing:
--   - requiresTarget: boolean indicating if user must select a target
--   - targetType: what kind of target is valid ("EnemyTower", "AnyTower", "Minion", etc.)
--   - validationFn: optional function to further validate targets
--   - effectFn: function that applies the effect with the selected target
--------------------------------------------------
local effectRegistry = {
    FireballEffect = {
        requiresTarget = true,
        targetType = "EnemyTower",
        effectFn = function(gameManager, player, target)
            if target and target.hp then
                -- Store old health for event
                local oldHealth = target.hp
                
                -- Calculate new health
                local damage = 6  -- Fireball damage
                local newHealth = oldHealth - damage
                
                -- IMPORTANT: Directly update the tower's health for fallback
                target.hp = newHealth
                
                -- Publish tower damaged event with proper parameters
                EventBus.publish(EventBus.Events.TOWER_DAMAGED, 
                    target,      -- The tower being damaged
                    nil,         -- No attacker (spell damage)
                    damage,      -- Amount of damage (6)
                    oldHealth,   -- Health before damage
                    newHealth    -- Health after damage
                )
                
                print("Fireball dealt 6 damage to a tower!")
                
                -- Publish spell cast success event
                EventBus.publish(EventBus.Events.SPELL_CAST, player, "Fireball", target)
                
                return true
            else
                print("Warning: Fireball effect called without valid target")
                
                -- Publish spell cast failed event
                EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "SpellCastFailed", player, "Fireball")
                
                return false
            end
        end
    },

    -- New effect: Rapid Resupply
    RapidResupplyEffect = {
        requiresTarget = false,  -- This spell does not require a target
        effectFn = function(gameManager, player, target, card)
            -- Draw 2 cards for the player
            player:drawCard(2)
            print(player.name .. " used Rapid Resupply and drew 2 cards!")
            -- Publish spell cast event for logging/other listeners
            EventBus.publish(EventBus.Events.SPELL_CAST, player, "RapidResupply", target)
            return true
        end
    },

    -- Using the factory function to create weapon effects
    FieryWarAxeEffect = createWeaponEffect("Melee"),
    LongbowEffect = createWeaponEffect("Ranged"),
    StaffOfFireEffect = createWeaponEffect("Magic")
}

-- Store event subscriptions
EffectManager.eventSubscriptions = {}

--------------------------------------------------
-- initEventSubscriptions():
-- Set up event listeners for effect-related events
--------------------------------------------------
function EffectManager.initEventSubscriptions()
    -- Clear any existing subscriptions
    EffectManager.clearEventSubscriptions()
    
    -- Add new subscriptions
    table.insert(EffectManager.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.BATTLECRY_TRIGGERED,
        function(minion, player, gameManager)
            EffectManager.triggerBattlecry(minion, gameManager, player)
        end,
        "EffectManager.battlecryHandler"
    ))
    
    table.insert(EffectManager.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.DEATHRATTLE_TRIGGERED,
        function(minion, player, gameManager)
            EffectManager.triggerDeathrattle(minion, gameManager, player)
        end,
        "EffectManager.deathrattleHandler"
    ))
    
    table.insert(EffectManager.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.MINION_ATTACKED,
        function(attacker, target)
            if attacker.weapon then
                EffectManager.reduceWeaponDurability(attacker)
            end
        end,
        "EffectManager.weaponDurabilityHandler"
    ))
    
    table.insert(EffectManager.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.SPELL_CAST,
        function(player, spellName, target)
            -- Additional logic could be added here for spell interactions
            -- This event is mainly for other systems to react to spells
        end,
        "EffectManager.spellCastHandler"
    ))
end

--------------------------------------------------
-- clearEventSubscriptions():
-- Clean up event subscriptions to prevent memory leaks
--------------------------------------------------
function EffectManager.clearEventSubscriptions()
    for _, sub in ipairs(EffectManager.eventSubscriptions) do
        EventBus.unsubscribe(sub)
    end
    EffectManager.eventSubscriptions = {}
end

--------------------------------------------------
-- destroy():
-- Clean up resources when EffectManager is no longer needed
--------------------------------------------------
function EffectManager.destroy()
    EffectManager.clearEventSubscriptions()
end

--------------------------------------------------
-- Helper function: reduceWeaponDurability
-- Used when a minion with a weapon attacks.
-- Reduces the weapon's durability and, when it breaks,
-- restores the minion's original attack value.
--------------------------------------------------
function EffectManager.reduceWeaponDurability(minion)
    if minion.weapon then
        -- Save old values for event data
        local oldDurability = minion.weapon.durability
        local weaponName = minion.weapon.name
        
        -- Reduce durability
        minion.weapon.durability = minion.weapon.durability - 1
        
        -- Publish weapon durability changed event
        EventBus.publish(EventBus.Events.WEAPON_EQUIPPED, minion, minion.weapon, oldDurability, minion.weapon.durability)
        
        if minion.weapon.durability <= 0 then
            -- Weapon breaks
            print(minion.name .. "'s " .. minion.weapon.name .. " broke!")
            
            -- Restore original attack
            minion.attack = minion.weapon.baseAttack
            
            -- Publish weapon broken event
            EventBus.publish(EventBus.Events.WEAPON_BROKEN, minion, weaponName)
            
            minion.weapon = nil
        end
    end
end

--------------------------------------------------
-- requiresTarget(effectKey):
--   Returns true if the effect requires a target to be selected.
--------------------------------------------------
function EffectManager.requiresTarget(effectKey)
    local effect = effectRegistry[effectKey]
    return effect and effect.requiresTarget or false
end

--------------------------------------------------
-- getTargetType(effectKey):
--   Returns the type of target required for this effect.
--------------------------------------------------
function EffectManager.getTargetType(effectKey)
    local effect = effectRegistry[effectKey]
    return effect and effect.targetType or nil
end

--------------------------------------------------
-- validateTarget(effectKey, target, card):
--   Returns true if the target is valid for this effect.
--------------------------------------------------
function EffectManager.validateTarget(effectKey, target, card)
    local effect = effectRegistry[effectKey]
    if not effect then return false end
    
    if effect.validationFn then
        return effect.validationFn(target, card)
    end
    
    return true  -- No validation function means any target is valid
end

--------------------------------------------------
-- applyEffectKey(effectKey, gameManager, player, optionalTarget, card):
--   Look up the function in 'effectRegistry' and call it.
--   If the effect requires a target but none is provided, return false.
--   Returns true if the effect was successfully applied.
--   Now passes the full card data for weapons.
--------------------------------------------------
function EffectManager.applyEffectKey(effectKey, gameManager, player, optionalTarget, card)
    local effect = effectRegistry[effectKey]
    if effect then
        if effect.requiresTarget and not optionalTarget then
            print("Warning: Effect requires target but none provided:", effectKey)
            
            -- Publish effect failed event
            EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "EffectFailedNoTarget", player, effectKey)
            
            return false
        end
        
        -- Before applying, publish effect triggered event
        EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, effectKey, player, optionalTarget)
        
        return effect.effectFn(gameManager, player, optionalTarget, card)
    else
        print("Warning: No effect function found for key:", effectKey)
        
        -- Publish unknown effect event
        EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "UnknownEffect", player, effectKey)
        
        return false
    end
end

--------------------------------------------------
-- triggerBattlecry(card, gameManager, player):
--   If a minion has a 'battlecry' function in its data,
--   call it here. This is triggered right after the minion
--   is placed on the board.
--------------------------------------------------
function EffectManager.triggerBattlecry(card, gameManager, player)
    if card and card.battlecry and type(card.battlecry) == "function" then
        -- Publish battlecry triggering event before execution
        EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "BattlecryTriggering", player, card)
        
        -- Execute the battlecry
        card.battlecry(gameManager, player)
        
        -- Publish battlecry complete event
        EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "BattlecryComplete", player, card)
    end
end

--------------------------------------------------
-- triggerDeathrattle(card, gameManager, player):
--   If a minion has a 'deathrattle' function in its data,
--   call it here. This is triggered when the minion dies.
--------------------------------------------------
function EffectManager.triggerDeathrattle(card, gameManager, player)
    if card and card.deathrattle and type(card.deathrattle) == "function" then
        -- Publish deathrattle triggering event before execution
        EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "DeathrattleTriggering", player, card)
        
        -- Execute the deathrattle
        card.deathrattle(gameManager, player)
        
        -- Publish deathrattle complete event
        EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "DeathrattleComplete", player, card)
    end
end

--------------------------------------------------
-- Initialize the EffectManager event subscriptions
--------------------------------------------------
EffectManager.initEventSubscriptions()

return EffectManager
