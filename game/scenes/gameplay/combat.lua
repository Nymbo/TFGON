-- game/scenes/gameplay/combat.lua
-- Minor changes to handle tower arrays. We rely on the actual tower object
-- passed in {type="tower", tower=<some tower>}.
-- Now with support for minion weapons - reduces durability after attack.

local CombatSystem = {}
local EffectManager = require("game.managers.effectmanager")

local function chebyshevDistance(pos1, pos2)
    return math.max(math.abs(pos1.x - pos2.x), math.abs(pos1.y - pos2.y))
end

local function getReach(archetype)
    if archetype == "Melee" then
        return 1
    elseif archetype == "Magic" then
        return 2
    elseif archetype == "Ranged" then
        return 3
    end
    return 1
end

function CombatSystem.resolveAttack(gameplayOrManager, attackerInfo, targetInfo)
    local gm
    if gameplayOrManager.gameManager then
        gm = gameplayOrManager.gameManager
    else
        gm = gameplayOrManager
    end

    local currentPlayer = gm:getCurrentPlayer()

    if attackerInfo.type == "minion" then
        local attacker = attackerInfo.minion

        if targetInfo.type == "minion" then
            local target = targetInfo.minion
            local distance = chebyshevDistance(attacker.position, target.position)
            local attackerReach = getReach(attacker.archetype)
            local targetReach = getReach(target.archetype)
            if distance > attackerReach then
                print("Target is out of reach!")
                return
            end
            target.currentHealth = target.currentHealth - attacker.attack
            print(attacker.name .. " attacked " .. target.name .. " for " .. attacker.attack .. " damage!")

            if attacker.archetype == "Melee" then
                attacker.currentHealth = attacker.currentHealth - target.attack
                print(target.name .. " counterattacked " .. attacker.name .. " for " .. target.attack .. " damage!")
            else
                -- Ranged/Magic only take counter if within target's reach
                if distance <= targetReach then
                    attacker.currentHealth = attacker.currentHealth - target.attack
                    print(target.name .. " counterattacked " .. attacker.name .. " for " .. target.attack .. " damage!")
                else
                    print(attacker.name .. " safely attacked from distance!")
                end
            end

            -- If the attacker has a weapon, reduce its durability
            if attacker.weapon then
                EffectManager.reduceWeaponDurability(attacker)
            end

            if target.currentHealth <= 0 then
                local tx, ty = target.position.x, target.position.y
                EffectManager.triggerDeathrattle(target, gm, gm:getEnemyPlayer(attacker.owner))
                gm.board:removeMinion(tx, ty)
                print(target.name .. " has been defeated!")
            end

            if attacker.currentHealth <= 0 then
                local ax, ay = attacker.position.x, attacker.position.y
                EffectManager.triggerDeathrattle(attacker, gm, attacker.owner)
                gm.board:removeMinion(ax, ay)
                print(attacker.name .. " has been defeated!")
            end

            attacker.canAttack = false

        elseif targetInfo.type == "tower" then
            local tower = targetInfo.tower
            local distance = chebyshevDistance(attacker.position, tower.position)
            local attackerReach = getReach(attacker.archetype)
            if distance <= attackerReach then
                tower.hp = tower.hp - attacker.attack
                print(attacker.name .. " attacked a tower for " .. attacker.attack .. " damage!")
                
                -- If the attacker has a weapon, reduce its durability
                if attacker.weapon then
                    EffectManager.reduceWeaponDurability(attacker)
                end
                
                attacker.canAttack = false
            else
                print("Tower is out of attack range!")
            end
        end
    end

    local enemy = gm:getEnemyPlayer(currentPlayer)
    -- If that player has no towers left, endGame will trigger in gm:update() or can be forced here
    -- We'll rely on gm:update() for the official check
end

return CombatSystem