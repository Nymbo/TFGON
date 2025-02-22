-- game/scenes/gameplay/combat.lua
-- The CombatSystem module now modified to better handle attacks from the AI manager
-- It has been updated to support the new combat rules where ranged/magic minions
-- only take counter damage if they are within the target's attack range.

local CombatSystem = {}
local EffectManager = require("game.managers.effectmanager")

--------------------------------------------------
-- Helper: Chebyshev distance between two positions
-- This calculates the maximum difference in x or y coordinates.
--------------------------------------------------
local function chebyshevDistance(pos1, pos2)
    return math.max(math.abs(pos1.x - pos2.x), math.abs(pos1.y - pos2.y))
end

--------------------------------------------------
-- Helper: Get reach based on archetype
-- Determines how far a minion can attack.
--------------------------------------------------
local function getReach(archetype)
    if archetype == "Melee" then
        return 1  -- Melee minions can only attack adjacent cells.
    elseif archetype == "Magic" then
        return 2  -- Magic minions have moderate range.
    elseif archetype == "Ranged" then
        return 3  -- Ranged minions can attack from further away.
    else
        return 1 -- default reach
    end
end

--------------------------------------------------
-- CombatSystem.resolveAttack:
-- Resolves an attack initiated by a minion or hero.
-- Now supports direct gameManager parameter for AI usage.
--------------------------------------------------
function CombatSystem.resolveAttack(gameplayOrManager, attackerInfo, targetInfo)
    -- Support both gameplay scene or direct game manager
    local gm
    if gameplayOrManager.gameManager then
        -- It's a gameplay scene
        gm = gameplayOrManager.gameManager
    else
        -- It's already a game manager
        gm = gameplayOrManager
    end
    
    local currentPlayer = gm:getCurrentPlayer()

    if attackerInfo.type == "minion" then
        local attacker = attackerInfo.minion
        
        if targetInfo.type == "hero" then
            -- For hero attacks, apply damage to the enemy hero.
            local enemy = gm:getEnemyPlayer(currentPlayer)
            enemy.health = enemy.health - attacker.attack
            attacker.canAttack = false

        elseif targetInfo.type == "minion" then
            local target = targetInfo.minion
            
            -- Calculate distance and reach for both attacker and target.
            local distance = chebyshevDistance(attacker.position, target.position)
            local attackerReach = getReach(attacker.archetype)
            local targetReach = getReach(target.archetype)
            
            -- Ensure the target is within the attacker's range.
            if distance > attackerReach then
                print("Target is out of reach!")
                return
            end

            -- Attacker deals damage to the target.
            target.currentHealth = target.currentHealth - attacker.attack
            print(attacker.name .. " attacked " .. target.name .. " for " .. attacker.attack .. " damage!")
            
            -- Determine counter damage based on attacker type.
            if attacker.archetype == "Melee" then
                -- Melee minions always take counter damage.
                attacker.currentHealth = attacker.currentHealth - target.attack
                print(target.name .. " counterattacked " .. attacker.name .. " for " .. target.attack .. " damage!")
            elseif attacker.archetype == "Ranged" or attacker.archetype == "Magic" then
                -- Ranged/Magic minions take counter damage only if within target's reach.
                if distance <= targetReach then
                    attacker.currentHealth = attacker.currentHealth - target.attack
                    print(target.name .. " counterattacked " .. attacker.name .. " for " .. target.attack .. " damage!")
                else
                    print(attacker.name .. " safely attacked " .. target.name .. " from a distance!")
                end
            end

            -- Check if target is defeated.
            if target.currentHealth <= 0 then
                local tx, ty = target.position.x, target.position.y
                EffectManager.triggerDeathrattle(target, gm, gm:getEnemyPlayer(currentPlayer))
                gm.board:removeMinion(tx, ty)
                print(target.name .. " has been defeated!")
            end

            -- Check if attacker is defeated.
            if attacker.currentHealth <= 0 then
                local ax, ay = attacker.position.x, attacker.position.y
                EffectManager.triggerDeathrattle(attacker, gm, currentPlayer)
                gm.board:removeMinion(ax, ay)
                print(attacker.name .. " has been defeated!")
            end

            -- Mark the attacker as having attacked this turn.
            attacker.canAttack = false

        elseif targetInfo.type == "tower" then
            local enemy = gm:getEnemyPlayer(currentPlayer)
            local towerPos = enemy.tower.position
            local distance = chebyshevDistance(attacker.position, towerPos)
            local attackerReach = getReach(attacker.archetype)
            if distance <= attackerReach then
                enemy.tower.hp = enemy.tower.hp - attacker.attack
                print(attacker.name .. " attacked the tower for " .. attacker.attack .. " damage!")
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

    -- End the game if the enemy tower's health drops to zero or below.
    local enemy = gm:getEnemyPlayer(currentPlayer)
    if enemy.tower and enemy.tower.hp <= 0 then
        gm:endGame()
    end
end

return CombatSystem