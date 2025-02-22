-- game/managers/aimanager.lua
-- Manages the AI opponent's decision-making and turn actions

local AIManager = {}
AIManager.__index = AIManager

-- Load required modules
local Combat = require("game.scenes.gameplay.combat")

-- Constructor
function AIManager:new(gameManager)
    local self = setmetatable({}, AIManager)
    self.gameManager = gameManager
    
    -- AI difficulty settings
    self.difficulty = "normal" -- Can be "easy", "normal", or "hard"
    
    -- Strategy weights (will be adjusted based on difficulty)
    self.weights = {
        attack_tower = 1.0,      -- Preference for attacking the tower
        clear_minions = 0.8,     -- Preference for removing enemy minions
        protect_minions = 0.7,   -- Preference for keeping own minions alive
        play_high_value = 0.9,   -- Preference for playing high-value cards
        mana_efficiency = 0.6    -- Preference for using all available mana
    }
    
    -- Update strategy weights based on difficulty
    self:setDifficulty(self.difficulty)
    
    return self
end

-- Set AI difficulty and adjust strategy weights
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

-- Main function to take AI turn
function AIManager:takeTurn()
    local gm = self.gameManager
    local aiPlayer = gm.player2 -- AI always controls player 2
    
    -- Simple delay to simulate "thinking" and make the game feel more natural
    love.timer.sleep(0.5)
    
    -- 1. Play minions and spells
    self:playCards(aiPlayer)
    
    -- 2. Move minions
    self:moveMinions(aiPlayer)
    
    -- 3. Attack with minions
    self:attackWithMinions(aiPlayer)
    
    -- 4. End turn
    gm:endTurn()
end

-- Function to decide which cards to play
function AIManager:playCards(aiPlayer)
    local gm = self.gameManager
    local board = gm.board
    
    -- Sort cards by "value" (a heuristic based on cost, stats, etc.)
    local sortedHand = {}
    for i, card in ipairs(aiPlayer.hand) do
        table.insert(sortedHand, {card = card, index = i, value = self:evaluateCardValue(card)})
    end
    
    table.sort(sortedHand, function(a, b) return a.value > b.value end)
    
    -- Try to play cards in order of their value
    for _, cardInfo in ipairs(sortedHand) do
        local card = cardInfo.card
        local cardIndex = cardInfo.index
        
        -- Skip if not enough mana
        if card.cost > aiPlayer.manaCrystals then
            goto continue
        end
        
        if card.cardType == "Minion" then
            -- Find best spot to place minion
            local bestSpot = self:findBestMinionPlacement(card)
            if bestSpot then
                local success = gm:summonMinion(aiPlayer, card, cardIndex, bestSpot.x, bestSpot.y)
                if success then
                    -- Adjust for the changed card indices after summoning
                    for j, info in ipairs(sortedHand) do
                        if info.index > cardIndex then
                            info.index = info.index - 1
                        end
                    end
                end
            end
        elseif card.cardType == "Spell" or card.cardType == "Weapon" then
            -- For now, just play spells and weapons automatically if we can afford them
            gm:playCardFromHand(aiPlayer, cardIndex)
            
            -- Adjust indices for remaining cards
            for j, info in ipairs(sortedHand) do
                if info.index > cardIndex then
                    info.index = info.index - 1
                end
            end
        end
        
        ::continue::
    end
end

-- Evaluate the value of a card based on its stats and the current game state
function AIManager:evaluateCardValue(card)
    local value = 0
    
    if card.cardType == "Minion" then
        -- Basic evaluation: add attack and health
        value = card.attack + card.health
        
        -- Bonus for good attack/health ratio
        if card.attack > card.health then
            value = value + 1
        end
        
        -- Bonus for movement
        value = value + (card.movement or 1) * 0.5
        
        -- Bonus for range
        if card.archetype == "Ranged" then
            value = value + 2
        elseif card.archetype == "Magic" then
            value = value + 1
        end
        
        -- Consider mana efficiency
        value = value / math.max(1, card.cost) * 1.5
        
        -- Special abilities bonus
        if card.battlecry or card.deathrattle then
            value = value + 2
        end
    elseif card.cardType == "Spell" then
        -- Simple valuation for spells
        value = card.cost * 1.2  -- Assume spells are worth slightly more than their cost
    elseif card.cardType == "Weapon" then
        -- Evaluate weapons based on damage potential
        value = (card.attack or 0) * (card.durability or 0) * 0.8
    end
    
    return value
end

-- Find the best place to put a minion on the board
function AIManager:findBestMinionPlacement(card)
    local gm = self.gameManager
    local board = gm.board
    local player = gm.player2 -- AI is always player 2
    
    -- AI spawn row is always the top row (row 1)
    local spawnRow = 1
    local availableColumns = {}
    
    -- Find all available columns in the spawn row
    for x = 1, board.cols do
        if board:isEmpty(x, spawnRow) and not gm:isTileOccupiedByTower(x, spawnRow) then
            table.insert(availableColumns, x)
        end
    end
    
    if #availableColumns == 0 then
        return nil -- No available placement spots
    end
    
    -- Score each position based on strategic considerations
    local bestX = nil
    local bestScore = -999
    
    for _, x in ipairs(availableColumns) do
        local score = 0
        
        -- Prefer central positions for control
        local centerDistance = math.abs(x - math.ceil(board.cols/2))
        score = score - centerDistance * 0.5
        
        -- Check if placing here would block enemy tower attacks
        if self:wouldBlockTowerAttack(x, spawnRow) then
            score = score + 3
        end
        
        -- Check if this position is good for this minion type
        if card.archetype == "Ranged" or card.archetype == "Magic" then
            -- Ranged and Magic units prefer positions away from the frontline
            score = score + 1
        elseif card.archetype == "Melee" then
            -- Melee units prefer positions that can reach important targets
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
        -- If no good position found, just pick a random available column
        local randomIndex = math.random(1, #availableColumns)
        return {x = availableColumns[randomIndex], y = spawnRow}
    end
end

-- Check if a position would block attacks on the tower
function AIManager:wouldBlockTowerAttack(x, y)
    local gm = self.gameManager
    local player2Tower = gm.player2.tower
    
    if not player2Tower then
        return false
    end
    
    -- Check if this position is in front of the tower
    return (math.abs(x - player2Tower.position.x) <= 1)
end

-- Check if a minion at this position could reach important targets in a few moves
function AIManager:canReachImportantTarget(x, y, movement)
    local gm = self.gameManager
    local board = gm.board
    local player1 = gm.player1
    
    -- Consider enemy tower as an important target
    if player1.tower then
        local towerPos = player1.tower.position
        local distance = math.max(math.abs(x - towerPos.x), math.abs(y - towerPos.y))
        
        -- Could reach the tower in a reasonable number of turns
        if distance <= movement * 3 then
            return true
        end
    end
    
    -- Also consider if enemy minions are reachable
    local foundReachableMinion = false
    board:forEachMinion(function(minion, minX, minY)
        if minion.owner == player1 then
            local distance = math.max(math.abs(x - minX), math.abs(y - minY))
            if distance <= movement * 2 then
                foundReachableMinion = true
            end
        end
    end)
    
    return foundReachableMinion
end

-- Function to move minions strategically
function AIManager:moveMinions(aiPlayer)
    local gm = self.gameManager
    local board = gm.board
    
    -- Find all minions controlled by the AI
    local aiMinions = {}
    board:forEachMinion(function(minion, x, y)
        if minion.owner == aiPlayer and not minion.hasMoved and not minion.summoningSickness then
            table.insert(aiMinions, {minion = minion, x = x, y = y})
        end
    end)
    
    -- Process each minion
    for _, minionInfo in ipairs(aiMinions) do
        local minion = minionInfo.minion
        local x = minionInfo.x
        local y = minionInfo.y
        
        -- Get the best move for this minion
        local bestMove = self:findBestMinionMove(minion, x, y)
        
        -- Execute the move if one was found
        if bestMove then
            board:moveMinion(x, y, bestMove.x, bestMove.y)
            minion.hasMoved = true
        end
    end
end

-- Find the best move for a minion
function AIManager:findBestMinionMove(minion, x, y)
    local gm = self.gameManager
    local board = gm.board
    local moveRange = minion.movement or 1
    
    -- Catalog all possible moves
    local possibleMoves = {}
    
    for dy = -moveRange, moveRange do
        for dx = -moveRange, moveRange do
            local newX = x + dx
            local newY = y + dy
            
            -- Skip if outside board bounds
            if newX < 1 or newX > board.cols or newY < 1 or newY > board.rows then
                goto continue
            end
            
            -- Skip if not a valid move distance
            if math.max(math.abs(dx), math.abs(dy)) > moveRange then
                goto continue
            end
            
            -- Skip if not empty
            if not board:isEmpty(newX, newY) or gm:isTileOccupiedByTower(newX, newY) then
                goto continue
            end
            
            -- Calculate move score
            local score = self:evaluateMovePosition(minion, newX, newY)
            
            -- Add to possible moves
            table.insert(possibleMoves, {x = newX, y = newY, score = score})
            
            ::continue::
        end
    end
    
    -- If no moves available, return nil
    if #possibleMoves == 0 then
        return nil
    end
    
    -- Sort moves by score (highest first)
    table.sort(possibleMoves, function(a, b) return a.score > b.score end)
    
    -- Return the best move
    return possibleMoves[1]
end

-- Evaluate how good a position is for a given minion
function AIManager:evaluateMovePosition(minion, x, y)
    local gm = self.gameManager
    local board = gm.board
    local player1 = gm.player1
    local score = 0
    
    -- Prioritize advancing toward enemy tower
    if player1.tower then
        local towerPos = player1.tower.position
        local currentDistance = math.max(math.abs(minion.position.x - towerPos.x), math.abs(minion.position.y - towerPos.y))
        local newDistance = math.max(math.abs(x - towerPos.x), math.abs(y - towerPos.y))
        
        -- Reward getting closer to the tower
        score = score + (currentDistance - newDistance) * 2 * self.weights.attack_tower
    end
    
    -- Different archetype strategies
    if minion.archetype == "Melee" then
        -- Melee units want to be close to targets
        score = score + self:scorePositionForMelee(minion, x, y)
    elseif minion.archetype == "Ranged" or minion.archetype == "Magic" then
        -- Ranged and Magic units want to attack from a safe distance
        score = score + self:scorePositionForRanged(minion, x, y)
    end
    
    -- Avoid moving next to enemy minions that could attack
    local dangerScore = self:evaluatePositionDanger(x, y)
    score = score - dangerScore * self.weights.protect_minions
    
    return score
end

-- Score position for melee minions
function AIManager:scorePositionForMelee(minion, x, y)
    local gm = self.gameManager
    local board = gm.board
    local player1 = gm.player1
    local score = 0
    
    -- For melee, we want to check if moving here would put us in attack range
    -- of enemy minions or the tower
    
    -- Check for enemy minions in attack range
    board:forEachMinion(function(enemyMinion, enemyX, enemyY)
        if enemyMinion.owner == player1 then
            local distance = math.max(math.abs(x - enemyX), math.abs(y - enemyY))
            if distance <= 1 then
                -- Prioritize attacking weaker minions
                local strengthDiff = minion.attack - enemyMinion.currentHealth
                score = score + 2 + (strengthDiff > 0 and 1 or 0)
            end
        end
    end)
    
    -- Check for tower in attack range
    if player1.tower then
        local towerPos = player1.tower.position
        local distance = math.max(math.abs(x - towerPos.x), math.abs(y - towerPos.y))
        if distance <= 1 then
            score = score + 4  -- High priority to be in position to attack tower
        end
    end
    
    return score
end

-- Score position for ranged minions
function AIManager:scorePositionForRanged(minion, x, y)
    local gm = self.gameManager
    local board = gm.board
    local player1 = gm.player1
    local score = 0
    
    -- For ranged, we want positions where we can attack but are hard to reach
    
    local reach = minion.archetype == "Ranged" and 3 or 2  -- Magic has range 2
    
    -- Count targets in range
    local targetsInRange = 0
    
    -- Check for enemy minions in attack range
    board:forEachMinion(function(enemyMinion, enemyX, enemyY)
        if enemyMinion.owner == player1 then
            local distance = math.max(math.abs(x - enemyX), math.abs(y - enemyY))
            if distance <= reach and distance > 1 then
                targetsInRange = targetsInRange + 1
                score = score + 2  -- Good to be in range of multiple targets
            end
        end
    end)
    
    -- Check for tower in attack range
    if player1.tower then
        local towerPos = player1.tower.position
        local distance = math.max(math.abs(x - towerPos.x), math.abs(y - towerPos.y))
        if distance <= reach and distance > 1 then
            score = score + 4  -- High priority to be in position to attack tower
            targetsInRange = targetsInRange + 1
        end
    end
    
    -- Bonus for being at ideal attack range (far enough to avoid counterattack)
    if targetsInRange > 0 then
        score = score + 1
    end
    
    return score
end

-- Evaluate how dangerous a position is
function AIManager:evaluatePositionDanger(x, y)
    local gm = self.gameManager
    local board = gm.board
    local player1 = gm.player1
    local dangerScore = 0
    
    -- Check for enemy minions that could attack this position
    board:forEachMinion(function(enemyMinion, enemyX, enemyY)
        if enemyMinion.owner == player1 then
            local distance = math.max(math.abs(x - enemyX), math.abs(y - enemyY))
            local enemyReach = 1
            
            if enemyMinion.archetype == "Ranged" then
                enemyReach = 3
            elseif enemyMinion.archetype == "Magic" then
                enemyReach = 2
            end
            
            if distance <= enemyReach then
                dangerScore = dangerScore + enemyMinion.attack
            end
        end
    end)
    
    return dangerScore
end

-- Function to make attacks with minions
function AIManager:attackWithMinions(aiPlayer)
    local gm = self.gameManager
    local board = gm.board
    
    -- Find all minions that can attack
    local attackingMinions = {}
    board:forEachMinion(function(minion, x, y)
        if minion.owner == aiPlayer and minion.canAttack and not minion.summoningSickness then
            table.insert(attackingMinions, {minion = minion, x = x, y = y})
        end
    end)
    
    -- Process each attacking minion
    for _, attackerInfo in ipairs(attackingMinions) do
        local minion = attackerInfo.minion
        local x = attackerInfo.x
        local y = attackerInfo.y
        
        -- Find the best attack for this minion
        local bestAttack = self:findBestAttackTarget(minion, x, y)
        
        -- Execute the attack if a target was found
        if bestAttack then
            if bestAttack.type == "minion" then
                Combat.resolveAttack(gm, {type = "minion", minion = minion}, {type = "minion", minion = bestAttack.target})
            elseif bestAttack.type == "tower" then
                Combat.resolveAttack(gm, {type = "minion", minion = minion}, {type = "tower", tower = bestAttack.target})
            end
        end
    end
end

-- Find the best attack target for a minion
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
    
    -- Check if player1's tower is in range
    if player1.tower then
        local towerPos = player1.tower.position
        local distance = math.max(math.abs(x - towerPos.x), math.abs(y - towerPos.y))
        
        if distance <= reach then
            -- Tower is almost always the best target if in range
            return {type = "tower", target = player1.tower, score = 100}
        end
    end
    
    -- Find all enemy minions in attack range
    local possibleTargets = {}
    
    board:forEachMinion(function(enemyMinion, enemyX, enemyY)
        if enemyMinion.owner == player1 then
            local distance = math.max(math.abs(x - enemyX), math.abs(y - enemyY))
            
            if distance <= reach then
                -- Calculate a score for this target
                local score = self:evaluateAttackTarget(minion, enemyMinion, distance)
                table.insert(possibleTargets, {type = "minion", target = enemyMinion, score = score})
            end
        end
    end)
    
    -- Sort targets by score (highest first)
    table.sort(possibleTargets, function(a, b) return a.score > b.score end)
    
    -- Return the best target, or nil if none found
    if #possibleTargets > 0 then
        return possibleTargets[1]
    else
        return nil
    end
end

-- Evaluate how good an attack target is
function AIManager:evaluateAttackTarget(attacker, defender, distance)
    local score = 0
    
    -- Base score is the damage we do
    score = score + attacker.attack
    
    -- Bonus for killing the target
    if attacker.attack >= defender.currentHealth then
        score = score + 5
    end
    
    -- Adjust based on whether we'll take counterattack damage
    local willTakeCounterDamage = false
    
    if attacker.archetype == "Melee" then
        -- Melee always takes counter damage
        willTakeCounterDamage = true
    elseif attacker.archetype == "Ranged" or attacker.archetype == "Magic" then
        -- Ranged/Magic take counter damage only if within defender's reach
        local defenderReach = 1
        if defender.archetype == "Ranged" then
            defenderReach = 3
        elseif defender.archetype == "Magic" then
            defenderReach = 2
        end
        
        willTakeCounterDamage = (distance <= defenderReach)
    end
    
    if willTakeCounterDamage then
        -- Reduce score based on potential damage taken
        score = score - defender.attack
        
        -- Heavy penalty if we would die
        if defender.attack >= attacker.currentHealth then
            score = score - 10
            
            -- But if both would die, and the defender is valuable, it might be worth it
            if attacker.attack >= defender.currentHealth then
                local attackerValue = attacker.attack + attacker.currentHealth
                local defenderValue = defender.attack + defender.currentHealth
                
                if defenderValue > attackerValue then
                    score = score + 5
                end
            end
        end
    end
    
    -- Bonus for targeting dangerous enemies
    score = score + defender.attack * 0.5
    
    -- Prioritize targeting enemies that can attack our tower
    if self:canAttackTower(defender) then
        score = score + 3
    end
    
    return score
end

-- Check if a minion can attack our tower
function AIManager:canAttackTower(minion)
    local gm = self.gameManager
    local player2 = gm.player2
    
    if player2.tower and minion.position then
        local towerPos = player2.tower.position
        local distance = math.max(math.abs(minion.position.x - towerPos.x), math.abs(minion.position.y - towerPos.y))
        
        local reach = 1
        if minion.archetype == "Ranged" then
            reach = 3
        elseif minion.archetype == "Magic" then
            reach = 2
        end
        
        return distance <= reach + minion.movement
    end
    
    return false
end

return AIManager