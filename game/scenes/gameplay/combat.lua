-- game/scenes/gameplay/combat.lua
-- Handles the logic for resolving attacks between
-- minions or between a minion/hero and a hero.

local CombatSystem = {}

--------------------------------------------------
-- resolveAttack:
-- Called by gameplay:resolveAttack(), with:
--   attacker = { type="minion"/"hero", minion=?, index=?, player=? }
--   target   = { type="minion"/"hero", minion=?, index=? }
--------------------------------------------------
function CombatSystem.resolveAttack(gameplay, attacker, target)
    local gm = gameplay.gameManager
    local currentPlayer = gm:getCurrentPlayer()

    -- If attacker is a minion
    if attacker.type == "minion" then
        local minion = attacker.minion

        if target.type == "hero" then
            -- Deal damage to the enemy hero
            local enemy = gm:getEnemyPlayer(currentPlayer)
            enemy.health = enemy.health - minion.attack
            -- Minion can only attack once per turn
            minion.canAttack = false

        elseif target.type == "minion" then
            -- Each minion deals damage to the other
            local targetMinion = target.minion
            targetMinion.currentHealth = targetMinion.currentHealth - minion.attack
            minion.currentHealth = minion.currentHealth - targetMinion.attack

            -- Remove target minion if it dies
            if targetMinion.currentHealth <= 0 then
                local enemyMinions = (gm:getEnemyPlayer(currentPlayer) == gm.player1)
                                     and gm.board.player1Minions
                                     or gm.board.player2Minions
                table.remove(enemyMinions, target.index)
            end

            -- Remove the attacking minion if it dies
            if minion.currentHealth <= 0 then
                local myMinions = (attacker.player == gm.player1)
                                    and gm.board.player1Minions
                                    or gm.board.player2Minions
                table.remove(myMinions, attacker.index)
            end

            -- Attacking minion can only attack once
            minion.canAttack = false
        end

    -- If the attacker is the hero with a weapon
    elseif attacker.type == "hero" and currentPlayer.weapon then
        currentPlayer.heroAttacked = true  -- Hero has used its attack
        local enemy = gm:getEnemyPlayer(currentPlayer)

        -- If we clicked an enemy hero, reduce its HP
        if target.type == "hero" then
            enemy.health = enemy.health - currentPlayer.weapon.attack
        else
            -- Attacking an enemy minion (not implemented in the original code).
            -- If you want hero to be able to hit minions, you could add logic here.
            local targetMinion = target.minion
            targetMinion.currentHealth = targetMinion.currentHealth - currentPlayer.weapon.attack
            -- Hero might also take damage from the minion, if we wanted that effect.
            -- For now, we skip that part unless you want "hero trades with minion" logic.
        end

        -- Reduce weapon durability
        currentPlayer.weapon.durability = currentPlayer.weapon.durability - 1

        -- If the weapon breaks, remove it
        if currentPlayer.weapon.durability <= 0 then
            currentPlayer.weapon = nil
        end
    end

    -- Check if game ended
    if gm.player1.health <= 0 or gm.player2.health <= 0 then
        gm:endGame()
    end
end

return CombatSystem
