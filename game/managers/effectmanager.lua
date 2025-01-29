-- game/managers/effectmanager.lua
-- Centralizes card effect logic for spells/weapons (via effectKey),
-- plus functions to trigger Battlecry and Deathrattle on minions.

local EffectManager = {}

--------------------------------------------------
-- effectRegistry:
--   A lookup table that maps an 'effectKey' string
--   to a function that applies that effect.
--
--   For example, "FireballEffect" deals 6 damage to
--   the enemy hero; "FieryWarAxeEffect" equips a 3/2
--   weapon, etc.
--------------------------------------------------
local effectRegistry = {
    FireballEffect = function(gameManager, player)
        local enemy = gameManager:getEnemyPlayer(player)
        enemy.health = enemy.health - 6
    end,

    FieryWarAxeEffect = function(gameManager, player)
        player.weapon = {
            attack = 3,
            durability = 2
        }
    end
}

--------------------------------------------------
-- applyEffectKey(effectKey, gameManager, player, optionalTarget):
--   Look up the function in 'effectRegistry' and call it.
--   If the effect doesn't exist, do nothing (or log an error).
--------------------------------------------------
function EffectManager.applyEffectKey(effectKey, gameManager, player, optionalTarget)
    local effectFn = effectRegistry[effectKey]
    if effectFn then
        effectFn(gameManager, player, optionalTarget)
    else
        print("Warning: No effect function found for key:", effectKey)
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
