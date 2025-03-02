-- game/scenes/gameplay/combat.lua
-- Minor changes to handle tower arrays. We rely on the actual tower object
-- passed in {type="tower", tower=<some tower>}.
-- Now with support for minion weapons - reduces durability after attack.
-- Now integrated with EventBus for decoupled architecture

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
                -- Publish attack failed event
                EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "AttackFailed", "OutOfRange")
                return
            end
            
            -- Publish attack event before damage is applied
            EventBus.publish(EventBus.Events.MINION_ATTACKED, attacker, target)
            
            -- Store original health values for events
            local targetOldHealth = target.currentHealth
            local attackerOldHealth = attacker.currentHealth
            
            -- Apply damage to target
            target.currentHealth = target.currentHealth - attacker.attack
            
            -- Publish minion damaged event with before/after health
            EventBus.publish(EventBus.Events.MINION_DAMAGED, 
                             target, attacker.attack, targetOldHealth, target.currentHealth)
            
            print(attacker.name .. " attacked " .. target.name .. " for " .. attacker.attack .. " damage!")

            -- Handle counterattacks based on archetype
            if attacker.archetype == "Melee" then
                attacker.currentHealth = attacker.currentHealth - target.attack
                
                -- Publish counterattack event
                EventBus.publish(EventBus.Events.MINION_ATTACKED, target, attacker)
                EventBus.publish(EventBus.Events.MINION_DAMAGED, 
                               attacker, target.attack, attackerOldHealth, attacker.currentHealth)
                
                print(target.name .. " counterattacked " .. attacker.name .. " for " .. target.attack .. " damage!")
            else
                -- Ranged/Magic only take counter if within target's reach
                if distance <= targetReach then
                    attacker.currentHealth = attacker.currentHealth - target.attack
                    
                    -- Publish counterattack event
                    EventBus.publish(EventBus.Events.MINION_ATTACKED, target, attacker)
                    EventBus.publish(EventBus.Events.MINION_DAMAGED, 
                                   attacker, target.attack, attackerOldHealth, attacker.currentHealth)
                    
                    print(target.name .. " counterattacked " .. attacker.name .. " for " .. target.attack .. " damage!")
                else
                    print(attacker.name .. " safely attacked from distance!")
                    EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "SafeAttack")
                end
            end

            -- If the attacker has a weapon, reduce its durability
            if attacker.weapon then
                local oldDurability = attacker.weapon.durability
                EffectManager.reduceWeaponDurability(attacker)
                
                -- If weapon still exists but durability reduced, publish event
                if attacker.weapon then
                    EventBus.publish(EventBus.Events.WEAPON_EQUIPPED, 
                                   attacker, attacker.weapon, oldDurability, attacker.weapon.durability)
                else
                    -- Weapon broke
                    EventBus.publish(EventBus.Events.WEAPON_BROKEN, attacker, oldDurability)
                end
            end

            -- Check for target death
            if target.currentHealth <= 0 then
                local tx, ty = target.position.x, target.position.y
                
                -- Trigger deathrattle effect before death event
                EventBus.publish(EventBus.Events.DEATHRATTLE_TRIGGERED, target, gm:getEnemyPlayer(attacker.owner), gm)
                
                -- Publish minion died event
                EventBus.publish(EventBus.Events.MINION_DIED, target, attacker)
                
                -- Still handle the direct board modification (could be moved to an event handler later)
                gm.board:removeMinion(tx, ty)
                print(target.name .. " has been defeated!")
            end

            -- Check for attacker death
            if attacker.currentHealth <= 0 then
                local ax, ay = attacker.position.x, attacker.position.y
                
                -- Trigger deathrattle effect before death event
                EventBus.publish(EventBus.Events.DEATHRATTLE_TRIGGERED, attacker, attacker.owner, gm)
                
                -- Publish minion died event
                EventBus.publish(EventBus.Events.MINION_DIED, attacker, target)
                
                -- Still handle the direct board modification (could be moved to an event handler later)
                gm.board:removeMinion(ax, ay)
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
                    local oldDurability = attacker.weapon.durability
                    EffectManager.reduceWeaponDurability(attacker)
                    
                    -- If weapon still exists but durability reduced, publish event
                    if attacker.weapon then
                        EventBus.publish(EventBus.Events.WEAPON_EQUIPPED, 
                                       attacker, attacker.weapon, oldDurability, attacker.weapon.durability)
                    else
                        -- Weapon broke
                        EventBus.publish(EventBus.Events.WEAPON_BROKEN, attacker, oldDurability)
                    end
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

    -- Additional combat-related events could be published here
    -- For example, we might want to track combat statistics or trigger effects
    EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "CombatResolved", attackerInfo, targetInfo)
end

return CombatSystem