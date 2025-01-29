-- game/scenes/gameplay/combat.lua
-- Handles the logic for attacks between minions/heroes.
-- Now updated to trigger Deathrattle before removing a dead minion.

local CombatSystem = {}

local EffectManager = require("game.managers.effectmanager")

function CombatSystem.resolveAttack(gameplay, attacker, target)
    local gm = gameplay.gameManager
    local currentPlayer = gm:getCurrentPlayer()

    if attacker.type == "minion" then
        local minion = attacker.minion

        if target.type == "hero" then
            local enemy = gm:getEnemyPlayer(currentPlayer)
            enemy.health = enemy.health - minion.attack
            minion.canAttack = false

        elseif target.type == "minion" then
            local targetMinion = target.minion
            targetMinion.currentHealth = targetMinion.currentHealth - minion.attack
            minion.currentHealth = minion.currentHealth - targetMinion.attack

            -- Did the target minion die?
            if targetMinion.currentHealth <= 0 then
                local enemyMinions = (gm:getEnemyPlayer(currentPlayer) == gm.player1)
                    and gm.board.player1Minions
                    or gm.board.player2Minions

                -- Trigger deathrattle before removing
                EffectManager.triggerDeathrattle(targetMinion, gm, gm:getEnemyPlayer(currentPlayer))
                table.remove(enemyMinions, target.index)
            end

            -- Did the attacking minion die?
            if minion.currentHealth <= 0 then
                local myMinions = (attacker.player == gm.player1)
                    and gm.board.player1Minions
                    or gm.board.player2Minions

                EffectManager.triggerDeathrattle(minion, gm, attacker.player)
                table.remove(myMinions, attacker.index)
            end

            minion.canAttack = false
        end

    elseif attacker.type == "hero" then
        -- The hero must have a weapon to attack
        local weapon = currentPlayer.weapon
        if weapon then
            currentPlayer.heroAttacked = true

            if target.type == "hero" then
                local enemy = gm:getEnemyPlayer(currentPlayer)
                enemy.health = enemy.health - weapon.attack
            elseif target.type == "minion" then
                -- If you want hero vs. minion combat to be 2-way, you can add logic here
                local targetMinion = target.minion
                targetMinion.currentHealth = targetMinion.currentHealth - weapon.attack

                -- If that kills the minion, trigger deathrattle and remove it
                if targetMinion.currentHealth <= 0 then
                    local enemyMinions = (gm:getEnemyPlayer(currentPlayer) == gm.player1)
                        and gm.board.player1Minions
                        or gm.board.player2Minions

                    EffectManager.triggerDeathrattle(targetMinion, gm, gm:getEnemyPlayer(currentPlayer))
                    table.remove(enemyMinions, target.index)
                end

                -- Optionally, you could also deal damage to the hero if you want minion retaliation
                -- e.g. currentPlayer.health = currentPlayer.health - targetMinion.attack
            end

            -- Reduce weapon durability
            weapon.durability = weapon.durability - 1
            if weapon.durability <= 0 then
                currentPlayer.weapon = nil
            end
        end
    end

    -- Check if either hero is dead
    if gm.player1.health <= 0 or gm.player2.health <= 0 then
        gm:endGame()
    end
end

return CombatSystem
