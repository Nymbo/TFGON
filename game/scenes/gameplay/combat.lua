-- game/scenes/gameplay/combat.lua
-- Refactored to use board methods for state changes
-- Now fully integrated with EventBus for decoupled architecture
-- Fixed implementation of Glancing Blows effect

local CombatSystem = {}
local EffectManager = require("game.managers.effectmanager")
local EventBus = require("game.eventbus")  -- Added EventBus import

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
    local board = gm.board

    if attackerInfo.type == "minion" then
        local attacker = attackerInfo.minion

        if targetInfo.type == "minion" then
            local target = targetInfo.minion
            local distance = chebyshevDistance(attacker.position, target.position)
            local attackerReach = getReach(attacker.archetype)
            local targetReach = getReach(target.archetype)
            
            -- Check if target is in reach
            if distance > attackerReach then
                print("Target is out of reach!")
                EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "AttackFailed", "OutOfRange")
                return
            end
            
            -- Publish attack event before damage is applied
            EventBus.publish(EventBus.Events.MINION_ATTACKED, attacker, target)
            
            -- Apply damage to target using board method
            board:applyDamageToMinion(target, attacker.attack, attacker)
            
            print(attacker.name .. " attacked " .. target.name .. " for " .. attacker.attack .. " damage!")

            -- Check if attacker has Glancing Blows before applying counter damage
            if attacker.glancingBlows then
                -- Attacker has Glancing Blows, so no counter damage is taken
                print(attacker.name .. " avoided counter-damage with Glancing Blows!")
                EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "GlancingBlows", attacker, target)
            else
                -- Handle normal counterattacks based on archetype
                if attacker.archetype == "Melee" then
                    board:applyDamageToMinion(attacker, target.attack, target)
                    print(target.name .. " counterattacked " .. attacker.name .. " for " .. target.attack .. " damage!")
                else
                    -- Ranged/Magic only take counter if within target's reach
                    if distance <= targetReach then
                        board:applyDamageToMinion(attacker, target.attack, target)
                        print(target.name .. " counterattacked " .. attacker.name .. " for " .. target.attack .. " damage!")
                    else
                        print(attacker.name .. " safely attacked from distance!")
                        EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "SafeAttack")
                    end
                end
            end

            -- If the attacker has a weapon, reduce its durability
            if attacker.weapon then
                EffectManager.reduceWeaponDurability(attacker)
            end

            -- Check for target death
            if target.currentHealth <= 0 then
                local tx, ty = target.position.x, target.position.y
                
                -- Trigger deathrattle effect before death event
                if target.deathrattle then
                    EventBus.publish(EventBus.Events.DEATHRATTLE_TRIGGERED, target, gm:getEnemyPlayer(attacker.owner), gm)
                end
                
                -- Remove minion from board - the board's removeMinion now publishes MINION_REMOVED event
                board:removeMinion(tx, ty)
                print(target.name .. " has been defeated!")
            end

            -- Check for attacker death
            if attacker.currentHealth <= 0 then
                local ax, ay = attacker.position.x, attacker.position.y
                
                -- Trigger deathrattle effect before death event
                if attacker.deathrattle then
                    EventBus.publish(EventBus.Events.DEATHRATTLE_TRIGGERED, attacker, attacker.owner, gm)
                end
                
                -- Remove minion from board - the board's removeMinion now publishes MINION_REMOVED event
                board:removeMinion(ax, ay)
                print(attacker.name .. " has been defeated!")
            end

            attacker.canAttack = false

        elseif targetInfo.type == "tower" then
            local tower = targetInfo.tower
            local distance = chebyshevDistance(attacker.position, tower.position)
            local attackerReach = getReach(attacker.archetype)
            
            if distance <= attackerReach then
                -- Store old tower health for events
                local oldHealth = tower.hp
                
                -- Publish tower attacked event
                EventBus.publish(EventBus.Events.MINION_ATTACKED, attacker, {type = "tower", tower = tower})
                
                -- Apply damage to tower
                tower.hp = tower.hp - attacker.attack
                
                -- Publish tower damaged event
                EventBus.publish(EventBus.Events.TOWER_DAMAGED, tower, attacker, attacker.attack, oldHealth, tower.hp)
                
                print(attacker.name .. " attacked a tower for " .. attacker.attack .. " damage!")
                
                -- If the attacker has a weapon, reduce its durability
                if attacker.weapon then
                    EffectManager.reduceWeaponDurability(attacker)
                end
                
                -- Check if tower is destroyed
                if tower.hp <= 0 then
                    -- Tower destruction is now handled by GameManager:update()
                    -- But we'll still publish the event here for immediate effects
                    EventBus.publish(EventBus.Events.TOWER_DESTROYED, tower, attacker)
                end
                
                attacker.canAttack = false
            else
                print("Tower is out of attack range!")
                EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "AttackFailed", "TowerOutOfRange")
            end
        end
    end

    -- Publish combat resolved event
    EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "CombatResolved", attackerInfo, targetInfo)
end

-- Apply a healing effect to a minion
function CombatSystem.healMinion(gameplayOrManager, minion, amount, source)
    local gm
    if gameplayOrManager.gameManager then
        gm = gameplayOrManager.gameManager
    else
        gm = gameplayOrManager
    end
    
    -- Use the board's heal method
    return gm.board:healMinion(minion, amount, source)
end

-- Apply a buff to a minion
function CombatSystem.buffMinion(gameplayOrManager, minion, attackBuff, healthBuff, source)
    local gm
    if gameplayOrManager.gameManager then
        gm = gameplayOrManager.gameManager
    else
        gm = gameplayOrManager
    end
    
    -- Use the board's buff method
    return gm.board:buffMinion(minion, attackBuff, healthBuff, source)
end

-- Apply a temporary effect to a minion
function CombatSystem.applyEffect(gameplayOrManager, minion, effectType, duration, source)
    local gm
    if gameplayOrManager.gameManager then
        gm = gameplayOrManager.gameManager
    else
        gm = gameplayOrManager
    end
    
    -- Use the board's effect method
    return gm.board:addMinionEffect(minion, effectType, duration, source)
end

return CombatSystem