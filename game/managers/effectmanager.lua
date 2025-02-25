-- game/managers/effectmanager.lua
-- Centralizes card effect logic for spells/weapons (via effectKey),
-- plus functions to trigger Battlecry and Deathrattle on minions.
-- Now with support for targeted effects!

local EffectManager = {}

--------------------------------------------------
-- effectRegistry:
--   A lookup table that maps an 'effectKey' string
--   to an effect definition containing:
--   - requiresTarget: boolean indicating if user must select a target
--   - targetType: what kind of target is valid ("EnemyTower", "AnyTower", "Minion", etc.)
--   - effectFn: function that applies the effect with the selected target
--------------------------------------------------
local effectRegistry = {
    FireballEffect = {
        requiresTarget = true,
        targetType = "EnemyTower",
        effectFn = function(gameManager, player, target)
            if target and target.hp then
                -- Deal 6 damage to the selected tower
                target.hp = target.hp - 8
                print("Fireball dealt 8 damage to a tower!")
            else
                print("Warning: Fireball effect called without valid target")
                return false
            end
            return true
        end
    },

    FieryWarAxeEffect = {
        requiresTarget = false,
        targetType = nil,
        effectFn = function(gameManager, player)
            player.weapon = {
                attack = 3,
                durability = 2
            }
            return true
        end
    }
}

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
-- applyEffectKey(effectKey, gameManager, player, optionalTarget):
--   Look up the function in 'effectRegistry' and call it.
--   If the effect requires a target but none is provided, return false.
--   Returns true if the effect was successfully applied.
--------------------------------------------------
function EffectManager.applyEffectKey(effectKey, gameManager, player, optionalTarget)
    local effect = effectRegistry[effectKey]
    if effect then
        if effect.requiresTarget and not optionalTarget then
            print("Warning: Effect requires target but none provided:", effectKey)
            return false
        end
        return effect.effectFn(gameManager, player, optionalTarget)
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