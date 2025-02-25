-- game/managers/effectmanager.lua
-- Centralizes card effect logic for spells/weapons (via effectKey),
-- plus functions to trigger Battlecry and Deathrattle on minions.
-- Now with support for targeted effects and minion weapons!
-- Refactored to reduce duplicate code in weapon effects

local EffectManager = {}

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
                print(target.name .. " equipped " .. card.name .. "!")
                return true
            else
                print("Warning: Weapon cannot be equipped by this minion")
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
                -- Deal 6 damage to the selected tower
                target.hp = target.hp - 6
                print("Fireball dealt 6 damage to a tower!")
            else
                print("Warning: Fireball effect called without valid target")
                return false
            end
            return true
        end
    },

    -- Using the factory function to create weapon effects
    -- This reduces duplicate code while keeping each effect distinct
    FieryWarAxeEffect = createWeaponEffect("Melee"),
    LongbowEffect = createWeaponEffect("Ranged"),
    StaffOfFireEffect = createWeaponEffect("Magic")
}

--------------------------------------------------
-- Helper function: reduceWeaponDurability
-- Used when a minion with a weapon attacks.
-- Reduces the weapon's durability and, when it breaks,
-- restores the minion's original attack value.
--------------------------------------------------
function EffectManager.reduceWeaponDurability(minion)
    if minion.weapon then
        minion.weapon.durability = minion.weapon.durability - 1
        
        if minion.weapon.durability <= 0 then
            -- Weapon breaks
            print(minion.name .. "'s " .. minion.weapon.name .. " broke!")
            -- Restore original attack
            minion.attack = minion.weapon.baseAttack
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
            return false
        end
        return effect.effectFn(gameManager, player, optionalTarget, card)
    else
        print("Warning: No effect function found for key:", effectKey)
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
        card.battlecry(gameManager, player)
    end
end

--------------------------------------------------
-- triggerDeathrattle(minion, gameManager, owningPlayer):
--   If a minion has a 'deathrattle' function in its data,
--   call it right before the minion is removed from the board.
--------------------------------------------------
function EffectManager.triggerDeathrattle(minion, gameManager, owningPlayer)
    -- For minion-based card data, you might store 'deathrattle'
    -- in the same table as 'attack', 'health', etc.
    --
    -- Check if that data is attached:
    if minion.deathrattle and type(minion.deathrattle) == "function" then
        minion.deathrattle(gameManager, owningPlayer)
    end
end

return EffectManager