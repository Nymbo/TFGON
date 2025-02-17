-- game/scenes/gameplay/combat.lua
-- This module now handles grid-based combat between minions and includes tower attacks.

local CombatSystem = {}
local EffectManager = require("game.managers.effectmanager")

-- Helper: Chebyshev distance between two positions
local function chebyshevDistance(pos1, pos2)
    return math.max(math.abs(pos1.x - pos2.x), math.abs(pos1.y - pos2.y))
end

-- Helper: Get reach based on archetype
local function getReach(archetype)
    if archetype == "Melee" then
        return 1
    elseif archetype == "Magic" then
        return 2
    elseif archetype == "Ranged" then
        return 3
    else
        return 1 -- default reach
    end
end

function CombatSystem.resolveAttack(gameplay, attackerInfo, targetInfo)
    local gm = gameplay.gameManager
    local currentPlayer = gm:getCurrentPlayer()

    if attackerInfo.type == "minion" then
        local attacker = attackerInfo.minion
        if targetInfo.type == "hero" then
            -- For hero attacks, we assume the click was valid
            local enemy = gm:getEnemyPlayer(currentPlayer)
            enemy.health = enemy.health - attacker.attack
            -- Attacker can only attack once, so we set canAttack to false
            attacker.canAttack = false

        elseif targetInfo.type == "minion" then
            local target = targetInfo.minion
            local reach = getReach(attacker.archetype)
            local distance = chebyshevDistance(attacker.position, target.position)
            if distance <= reach then
                -- Simultaneous combat damage
                target.currentHealth = target.currentHealth - attacker.attack
                attacker.currentHealth = attacker.currentHealth - target.attack

                -- Remove target if dead
                if target.currentHealth <= 0 then
                    local tx, ty = target.position.x, target.position.y
                    EffectManager.triggerDeathrattle(target, gm, gm:getEnemyPlayer(currentPlayer))
                    gm.board:removeMinion(tx, ty)
                end

                -- Remove attacker if dead
                if attacker.currentHealth <= 0 then
                    local ax, ay = attacker.position.x, attacker.position.y
                    EffectManager.triggerDeathrattle(attacker, gm, currentPlayer)
                    gm.board:removeMinion(ax, ay)
                end

                -- Attacker can only attack once
                attacker.canAttack = false
            else
                print("Target is out of reach!")
            end

        elseif targetInfo.type == "tower" then
            local enemy = gm:getEnemyPlayer(currentPlayer)
            local towerPos = enemy.tower.position
            local distance = chebyshevDistance(attacker.position, towerPos)
            local reach = getReach(attacker.archetype)
            if distance <= reach then
                enemy.tower.hp = enemy.tower.hp - attacker.attack
                print(attacker.name .. " attacked the tower for " .. attacker.attack .. " damage!")
                -- Attacker can only attack once
                attacker.canAttack = false
            else
                print("Tower is out of attack range!")
            end
        end

    elseif attackerInfo.type == "hero" then
        local weapon = currentPlayer.weapon
        if weapon then
            currentPlayer.heroAttacked = true
            local enemy = gm:getEnemyPlayer(currentPlayer)

            if targetInfo.type == "hero" then
                enemy.health = enemy.health - weapon.attack
            elseif targetInfo.type == "minion" then
                local target = targetInfo.minion
                target.currentHealth = target.currentHealth - weapon.attack
                if target.currentHealth <= 0 then
                    local tx, ty = target.position.x, target.position.y
                    EffectManager.triggerDeathrattle(target, gm, enemy)
                    gm.board:removeMinion(tx, ty)
                end
            elseif targetInfo.type == "tower" then
                enemy.tower.hp = enemy.tower.hp - weapon.attack
                print("Hero attacked the tower for " .. weapon.attack .. " damage!")
            end

            weapon.durability = weapon.durability - 1
            if weapon.durability <= 0 then
                currentPlayer.weapon = nil
            end
        end
    end

    local enemy = gm:getEnemyPlayer(currentPlayer)
    if enemy.tower.hp <= 0 then
        gm:endGame()
    end
end

return CombatSystem
