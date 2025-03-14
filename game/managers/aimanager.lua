-- game/managers/aimanager.lua
-- Updated to handle multiple towers. AI will pick "the first tower"
-- in the array for any tower-related logic, or skip if none.
-- A more advanced approach would pick the "closest tower" or "lowest HP tower," etc.
-- Now using EventBus architecture for better integration with the game.
-- UPDATED: Removed legacy callbacks in favor of event-based handling
-- FIXED: Tower damage events now use Combat.resolveAttack properly

local AIManager = {}
AIManager.__index = AIManager

local Combat = require("game.scenes.gameplay.combat")
local EventBus = require("game.eventbus")

--------------------------------------------------
-- Helper: getFirstTower
--------------------------------------------------
local function getFirstTower(towers)
    if towers and #towers > 0 then
        return towers[1]
    end
    return nil
end

--------------------------------------------------
-- Helper: getClosestTower (OPTIONAL)
-- If you want a more advanced approach, uncomment and use
-- in place of getFirstTower logic. 
--[[
local function chebyshevDist(x1, y1, x2, y2)
    return math.max(math.abs(x1 - x2), math.abs(y1 - y2))
end
local function getClosestTower(towers, fromX, fromY)
    local best = nil
    local bestDist = 99999
    for _, t in ipairs(towers) do
        local dist = chebyshevDist(fromX, fromY, t.position.x, t.position.y)
        if dist < bestDist then
            bestDist = dist
            best = t
        end
    end
    return best
end
]]
--------------------------------------------------

function AIManager:new(gameManager)
    local self = setmetatable({}, AIManager)
    self.gameManager = gameManager
    self.difficulty = "normal"
    self.weights = {
        attack_tower = 1.0,
        clear_minions = 0.8,
        protect_minions = 0.7,
        play_high_value = 0.9,
        mana_efficiency = 0.6
    }
    self:setDifficulty(self.difficulty)
    
    -- Initialize event subscriptions
    self:initEventSubscriptions()
    
    return self
end

--------------------------------------------------
-- initEventSubscriptions():
-- Set up all the event listeners for the AI.
--------------------------------------------------
function AIManager:initEventSubscriptions()
    self.eventSubscriptions = {}
    
    -- Subscribe to AI turn start event
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.AI_TURN_STARTED,
        function(player)
            self:executeTurn(player)
        end,
        "AIManager"
    ))
    
    -- Subscribe to AI action events
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.AI_ACTION_PERFORMED,
        function(actionType, player)
            if actionType == "playCards" then
                self:playCards(player)
            elseif actionType == "moveMinions" then
                self:moveMinions(player)
            elseif actionType == "attackWithMinions" then
                self:attackWithMinions(player)
            end
        end,
        "AIActionHandler"
    ))
    
    -- Subscribe to AI turn end event
    table.insert(self.eventSubscriptions, EventBus.subscribe(
        EventBus.Events.AI_TURN_ENDED,
        function(player)
            -- Make sure we only end the turn if it's still the AI's turn
            if self.gameManager.currentPlayer == 2 then
                self.gameManager:endTurn()
            end
        end,
        "AITurnEndHandler"
    ))
end

--------------------------------------------------
-- destroy():
-- Clean up event subscriptions when AI is no longer needed.
--------------------------------------------------
function AIManager:destroy()
    -- Clean up subscriptions to prevent memory leaks
    for _, sub in ipairs(self.eventSubscriptions) do
        EventBus.unsubscribe(sub)
    end
    self.eventSubscriptions = {}
end

function AIManager:setDifficulty(difficulty)
    self.difficulty = difficulty
    if difficulty == "easy" then
        self.weights = {
            attack_tower = 0.5,
            clear_minions = 0.6,
            protect_minions = 0.4,
            play_high_value = 0.7,
            mana_efficiency = 0.3
        }
    elseif difficulty == "normal" then
        -- Keep default weights
    elseif difficulty == "hard" then
        self.weights = {
            attack_tower = 1.2,
            clear_minions = 1.0,
            protect_minions = 0.9,
            play_high_value = 1.1,
            mana_efficiency = 0.8
        }
    end
end

--------------------------------------------------
-- executeTurn(player):
-- Main function for the AI's entire turn, now event-based.
--------------------------------------------------
function AIManager:executeTurn(player)
    -- Ensure the player parameter is the AI player
    if player ~= self.gameManager.player2 then
        Debug.error("AIManager:executeTurn called with wrong player")
        EventBus.publishDelayed(EventBus.Events.AI_TURN_ENDED, 0.1, player)
        return
    end
    
    -- Introduce delay between actions for more natural pacing
    EventBus.publishDelayed(EventBus.Events.AI_ACTION_PERFORMED, 0.3, "playCards", player)
    EventBus.publishDelayed(EventBus.Events.AI_ACTION_PERFORMED, 1.0, "moveMinions", player)
    EventBus.publishDelayed(EventBus.Events.AI_ACTION_PERFORMED, 1.8, "attackWithMinions", player)
    
    -- Ensure the turn ends even if there was a problem with animations or events
    -- Use a longer delay to ensure all actions have time to complete
    EventBus.publishDelayed(EventBus.Events.AI_TURN_ENDED, 3.0, player)
    
    -- Optionally publish event when AI starts thinking for UI feedback
    EventBus.publish(EventBus.Events.EFFECT_TRIGGERED, "AIThinking")
end

function AIManager:playCards(aiPlayer)
    local gm = self.gameManager
    local board = gm.board

    local sortedHand = {}
    for i, card in ipairs(aiPlayer.hand) do
        table.insert(sortedHand, {card = card, index = i, value = self:evaluateCardValue(card)})
    end

    table.sort(sortedHand, function(a, b) return a.value > b.value end)

    for _, cardInfo in ipairs(sortedHand) do
        local card = cardInfo.card
        local cardIndex = cardInfo.index

        -- Skip cards that cost too much mana
        if card.cost > aiPlayer.manaCrystals then
            -- Fixed: changed goto continue to just "continue" via the loop
            -- The goto statement would require a label, which wasn't defined
            -- We'll use the simpler approach of skipping to the next iteration
            -- This is what the `goto continue` was trying to do anyway
        else
            if card.cardType == "Minion" then
                local bestSpot = self:findBestMinionPlacement(card)
                if bestSpot then
                    local success = gm:summonMinion(aiPlayer, card, cardIndex, bestSpot.x, bestSpot.y)
                    if success then
                        -- Publish an event for minion summoned
                        EventBus.publish(EventBus.Events.MINION_SUMMONED, aiPlayer, card, bestSpot.x, bestSpot.y)
                        
                        -- Adjust indices in sortedHand
                        for j, info in ipairs(sortedHand) do
                            if info.index > cardIndex then
                                info.index = info.index - 1
                            end
                        end
                    end
                end
            elseif card.cardType == "Spell" or card.cardType == "Weapon" then
                local success = gm:playCardFromHand(aiPlayer, cardIndex)
                if success then
                    -- Publish card played event
                    EventBus.publish(EventBus.Events.CARD_PLAYED, aiPlayer, card)
                    
                    for j, info in ipairs(sortedHand) do
                        if info.index > cardIndex then
                            info.index = info.index - 1
                        end
                    end
                end
            end
        end
    end
end

function AIManager:evaluateCardValue(card)
    local value = 0
    if card.cardType == "Minion" then
        value = card.attack + card.health
        if card.attack > card.health then
            value = value + 1
        end
        value = value + (card.movement or 1) * 0.5
        if card.archetype == "Ranged" then
            value = value + 2
        elseif card.archetype == "Magic" then
            value = value + 1
        end
        value = value / math.max(1, card.cost) * 1.5
        if card.battlecry or card.deathrattle then
            value = value + 2
        end
    elseif card.cardType == "Spell" then
        value = card.cost * 1.2
    elseif card.cardType == "Weapon" then
        value = (card.attack or 0) * (card.durability or 0) * 0.8
    end
    return value
end

function AIManager:findBestMinionPlacement(card)
    local gm = self.gameManager
    local board = gm.board
    local aiPlayer = gm.player2

    local spawnRow = 1
    local availableColumns = {}
    for x = 1, board.cols do
        if board:isEmpty(x, spawnRow) and (not gm:isTileOccupiedByTower(x, spawnRow)) then
            table.insert(availableColumns, x)
        end
    end
    if #availableColumns == 0 then
        return nil
    end

    local bestX = nil
    local bestScore = -999
    for _, x in ipairs(availableColumns) do
        local score = 0
        local centerDistance = math.abs(x - math.ceil(board.cols/2))
        score = score - centerDistance * 0.5
        if self:wouldBlockTowerAttack(x, spawnRow) then
            score = score + 3
        end
        if card.archetype == "Ranged" or card.archetype == "Magic" then
            score = score + 1
        elseif card.archetype == "Melee" then
            if self:canReachImportantTarget(x, spawnRow, card.movement or 1) then
                score = score + 2
            end
        end

        if score > bestScore then
            bestScore = score
            bestX = x
        end
    end

    if bestX then
        return {x = bestX, y = spawnRow}
    else
        local randomIndex = math.random(1, #availableColumns)
        return {x = availableColumns[randomIndex], y = spawnRow}
    end
end

--------------------------------------------------
-- For AI's own tower, we pick the first tower in player2.towers
--------------------------------------------------
function AIManager:wouldBlockTowerAttack(x, y)
    local gm = self.gameManager
    local tower = getFirstTower(gm.player2.towers)
    if not tower then
        return false
    end
    return (math.abs(x - tower.position.x) <= 1)
end

function AIManager:canReachImportantTarget(x, y, movement)
    local gm = self.gameManager
    local board = gm.board
    local player1 = gm.player1
    local tower = getFirstTower(player1.towers)
    if tower then
        local dist = math.max(math.abs(x - tower.position.x), math.abs(y - tower.position.y))
        if dist <= movement * 3 then
            return true
        end
    end

    local foundReachableMinion = false
    board:forEachMinion(function(minion, minX, minY)
        if minion.owner == player1 then
            local dist = math.max(math.abs(x - minX), math.abs(y - minY))
            if dist <= movement * 2 then
                foundReachableMinion = true
            end
        end
    end)
    return foundReachableMinion
end

function AIManager:moveMinions(aiPlayer)
    local gm = self.gameManager
    local board = gm.board
    local aiMinions = {}

    board:forEachMinion(function(minion, x, y)
        if minion.owner == aiPlayer and not minion.hasMoved and not minion.summoningSickness then
            table.insert(aiMinions, {minion = minion, x = x, y = y})
        end
    end)

    for _, mInfo in ipairs(aiMinions) do
        local minion = mInfo.minion
        local fromX, fromY = mInfo.x, mInfo.y
        local bestMove = self:findBestMinionMove(minion, fromX, fromY)
        if bestMove then
            local success = board:moveMinion(fromX, fromY, bestMove.x, bestMove.y)
            if success then
                minion.hasMoved = true
                
                -- Publish minion moved event
                EventBus.publish(EventBus.Events.MINION_MOVED, minion, fromX, fromY, bestMove.x, bestMove.y)
            end
        end
    end
end

function AIManager:findBestMinionMove(minion, x, y)
    local gm = self.gameManager
    local board = gm.board
    local moveRange = minion.movement or 1

    local possibleMoves = {}
    for dy = -moveRange, moveRange do
        for dx = -moveRange, moveRange do
            local nx = x + dx
            local ny = y + dy
            if nx >= 1 and nx <= board.cols and ny >= 1 and ny <= board.rows then
                if math.max(math.abs(dx), math.abs(dy)) <= moveRange then
                    if board:isEmpty(nx, ny) and (not gm:isTileOccupiedByTower(nx, ny)) then
                        local score = self:evaluateMovePosition(minion, nx, ny)
                        table.insert(possibleMoves, {x = nx, y = ny, score = score})
                    end
                end
            end
        end
    end
    if #possibleMoves == 0 then
        return nil
    end
    table.sort(possibleMoves, function(a, b) return a.score > b.score end)
    return possibleMoves[1]
end

function AIManager:evaluateMovePosition(minion, x, y)
    local gm = self.gameManager
    local player1 = gm.player1
    local score = 0

    local tower = getFirstTower(player1.towers)
    if tower then
        local towerPos = tower.position
        local currentDistance = math.max(math.abs(minion.position.x - towerPos.x), math.abs(minion.position.y - towerPos.y))
        local newDistance = math.max(math.abs(x - towerPos.x), math.abs(y - towerPos.y))
        score = score + (currentDistance - newDistance) * 2 * self.weights.attack_tower
    end

    if minion.archetype == "Melee" then
        score = score + self:scorePositionForMelee(minion, x, y)
    elseif minion.archetype == "Ranged" or minion.archetype == "Magic" then
        score = score + self:scorePositionForRanged(minion, x, y)
    end

    local dangerScore = self:evaluatePositionDanger(x, y)
    score = score - dangerScore * self.weights.protect_minions
    return score
end

function AIManager:scorePositionForMelee(minion, x, y)
    local gm = self.gameManager
    local board = gm.board
    local player1 = gm.player1
    local score = 0

    board:forEachMinion(function(enemyMinion, ex, ey)
        if enemyMinion.owner == player1 then
            local dist = math.max(math.abs(x - ex), math.abs(y - ey))
            if dist <= 1 then
                local strengthDiff = minion.attack - enemyMinion.currentHealth
                score = score + 2 + (strengthDiff > 0 and 1 or 0)
            end
        end
    end)

    local tower = getFirstTower(player1.towers)
    if tower then
        local dist = math.max(math.abs(x - tower.position.x), math.abs(y - tower.position.y))
        if dist <= 1 then
            score = score + 4
        end
    end

    return score
end

function AIManager:scorePositionForRanged(minion, x, y)
    local gm = self.gameManager
    local board = gm.board
    local player1 = gm.player1
    local score = 0
    local reach = (minion.archetype == "Ranged") and 3 or 2

    local targetsInRange = 0
    board:forEachMinion(function(enemyMinion, ex, ey)
        if enemyMinion.owner == player1 then
            local dist = math.max(math.abs(x - ex), math.abs(y - ey))
            if dist <= reach and dist > 1 then
                targetsInRange = targetsInRange + 1
                score = score + 2
            end
        end
    end)
    local tower = getFirstTower(player1.towers)
    if tower then
        local dist = math.max(math.abs(x - tower.position.x), math.abs(y - tower.position.y))
        if dist <= reach and dist > 1 then
            score = score + 4
            targetsInRange = targetsInRange + 1
        end
    end
    if targetsInRange > 0 then
        score = score + 1
    end

    return score
end

function AIManager:evaluatePositionDanger(x, y)
    local gm = self.gameManager
    local board = gm.board
    local player1 = gm.player1
    local dangerScore = 0

    board:forEachMinion(function(enemyMinion, ex, ey)
        if enemyMinion.owner == player1 then
            local dist = math.max(math.abs(x - ex), math.abs(y - ey))
            local enemyReach = 1
            if enemyMinion.archetype == "Ranged" then
                enemyReach = 3
            elseif enemyMinion.archetype == "Magic" then
                enemyReach = 2
            end
            if dist <= enemyReach then
                dangerScore = dangerScore + enemyMinion.attack
            end
        end
    end)

    return dangerScore
end

function AIManager:attackWithMinions(aiPlayer)
    local gm = self.gameManager
    local board = gm.board
    local attackingMinions = {}

    board:forEachMinion(function(minion, x, y)
        if minion.owner == aiPlayer and minion.canAttack and not minion.summoningSickness then
            table.insert(attackingMinions, {minion = minion, x = x, y = y})
        end
    end)

    for _, attackerInfo in ipairs(attackingMinions) do
        local attacker = attackerInfo.minion
        local x = attackerInfo.x
        local y = attackerInfo.y
        local bestAttack = self:findBestAttackTarget(attacker, x, y)
        if bestAttack then
            if bestAttack.type == "minion" then
                -- Use Combat.resolveAttack for minion attacks
                local result = Combat.resolveAttack(gm, {type = "minion", minion = attacker}, {type = "minion", minion = bestAttack.target})
                
                -- The resolveAttack function already publishes the appropriate events
            elseif bestAttack.type == "tower" then
                -- FIXED: Use Combat.resolveAttack for tower attacks too
                -- Let the combat system handle the tower damage event publishing
                local result = Combat.resolveAttack(gm, {type = "minion", minion = attacker}, {type = "tower", tower = bestAttack.target})
                
                -- REMOVED: Don't manually publish TOWER_DAMAGED event here!
                -- That causes duplicate/incomplete events
            end
        end
    end
end

function AIManager:findBestAttackTarget(minion, x, y)
    local gm = self.gameManager
    local board = gm.board
    local player1 = gm.player1

    local reach = 1
    if minion.archetype == "Ranged" then
        reach = 3
    elseif minion.archetype == "Magic" then
        reach = 2
    end

    --------------------------------------------------
    -- If there's a tower, consider it
    --------------------------------------------------
    local tower = getFirstTower(player1.towers)
    if tower then
        local dist = math.max(math.abs(x - tower.position.x), math.abs(y - tower.position.y))
        if dist <= reach then
            return {type = "tower", target = tower, score = 100}
        end
    end

    local possibleTargets = {}
    board:forEachMinion(function(enemyMinion, ex, ey)
        if enemyMinion.owner == player1 then
            local dist = math.max(math.abs(x - ex), math.abs(y - ey))
            if dist <= reach then
                local score = self:evaluateAttackTarget(minion, enemyMinion, dist)
                table.insert(possibleTargets, {type = "minion", target = enemyMinion, score = score})
            end
        end
    end)

    table.sort(possibleTargets, function(a, b) return a.score > b.score end)
    if #possibleTargets > 0 then
        return possibleTargets[1]
    else
        return nil
    end
end

function AIManager:evaluateAttackTarget(attacker, defender, distance)
    local score = 0
    score = score + attacker.attack
    if attacker.attack >= defender.currentHealth then
        score = score + 5
    end

    local willTakeCounterDamage = false
    if attacker.archetype == "Melee" then
        willTakeCounterDamage = true
    elseif attacker.archetype == "Ranged" or attacker.archetype == "Magic" then
        local defenderReach = 1
        if defender.archetype == "Ranged" then
            defenderReach = 3
        elseif defender.archetype == "Magic" then
            defenderReach = 2
        end
        willTakeCounterDamage = (distance <= defenderReach)
    end
    if willTakeCounterDamage then
        score = score - defender.attack
        if defender.attack >= attacker.currentHealth then
            score = score - 10
            if attacker.attack >= defender.currentHealth then
                local attVal = attacker.attack + attacker.currentHealth
                local defVal = defender.attack + defender.currentHealth
                if defVal > attVal then
                    score = score + 5
                end
            end
        end
    end

    score = score + defender.attack * 0.5

    if self:canAttackTower(defender) then
        score = score + 3
    end

    return score
end

function AIManager:canAttackTower(minion)
    local gm = self.gameManager
    local player2 = gm.player2
    if #player2.towers == 0 or (not minion.position) then
        return false
    end

    local tower = getFirstTower(player2.towers)
    if not tower then
        return false
    end
    local dist = math.max(math.abs(minion.position.x - tower.position.x), math.abs(minion.position.y - tower.position.y))
    local reach = 1
    if minion.archetype == "Ranged" then
        reach = 3
    elseif minion.archetype == "Magic" then
        reach = 2
    end

    return dist <= (reach + minion.movement)
end

return AIManager