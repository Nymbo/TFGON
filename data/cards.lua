-- data/cards.lua
-- Card data now includes "movement" and "archetype" for minions.
-- Weapons now have archetypeRequirement to indicate which minions can equip them.
return {
    --------------------------------------------------
    -- Basic Minions (with movement and archetype)
    --------------------------------------------------
    {
        name = "Wisp",
        cardType = "Minion",
        cost = 0,
        attack = 1,
        health = 1,
        movement = 2,
        archetype = "Melee"
    },
    {
        name = "River Crocolisk",
        cardType = "Minion",
        cost = 2,
        attack = 2,
        health = 3,
        movement = 2,
        archetype = "Melee"
    },
    {
        name = "Magma Rager",
        cardType = "Minion",
        cost = 3,
        attack = 5,
        health = 1,
        movement = 1,
        archetype = "Magic"
    },
    {
        name = "Chillwind Yeti",
        cardType = "Minion",
        cost = 4,
        attack = 4,
        health = 5,
        movement = 2,
        archetype = "Melee"
    },
    {
        name = "Boulderfist Ogre",
        cardType = "Minion",
        cost = 6,
        attack = 6,
        health = 7,
        movement = 1,
        archetype = "Melee"
    },
    {
        name = "War Golem",
        cardType = "Minion",
        cost = 7,
        attack = 7,
        health = 7,
        movement = 1,
        archetype = "Melee"
    },
    {
        name = "Ardent Defender",
        cardType = "Minion",
        cost = 3,
        attack = 2,
        health = 6,
        movement = 1,
        archetype = "Melee"
    },
    {
        name = "Eager Recruit",
        cardType = "Minion",
        cost = 2,
        attack = 3,
        health = 2,
        movement = 2,
        archetype = "Melee"
    },
    {
        name = "Rifleman",
        cardType = "Minion",
        cost = 2,
        attack = 4,
        health = 2,
        movement = 1,
        archetype = "Ranged"
    },
    {
        name = "Quickfoot McGee",
        cardType = "Minion",
        cost = 1,
        attack = 1,
        health = 2,
        movement = 3,
        archetype = "Melee"
    },
    {
        name = "Hair-trigger Bandit",
        cardType = "Minion",
        cost = 3,
        attack = 4,
        health = 3,
        movement = 2,
        archetype = "Ranged"
    },

    --------------------------------------------------
    -- Weapons (with archetypeRequirement)
    --------------------------------------------------
    {
        name = "Fiery War Axe",
        cardType = "Weapon",
        cost = 2,
        attack = 3,
        durability = 2,
        archetypeRequirement = "Melee", -- Only Melee minions can equip this
        effectKey = "FieryWarAxeEffect"
    },
    {
        name = "Longbow",
        cardType = "Weapon",
        cost = 3,
        attack = 2,
        durability = 3,
        archetypeRequirement = "Ranged", -- Only Ranged minions can equip this
        effectKey = "LongbowEffect"
    },
    {
        name = "Staff of Fire",
        cardType = "Weapon",
        cost = 4,
        attack = 4,
        durability = 2,
        archetypeRequirement = "Magic", -- Only Magic minions can equip this
        effectKey = "StaffOfFireEffect"
    },

    --------------------------------------------------
    -- Spell (refactored to use effectKey)
    --------------------------------------------------
    {
        name = "Fireball",
        cardType = "Spell",
        cost = 4,
        effectKey = "FireballEffect"
    },

    --------------------------------------------------
    -- Placeholder Minion with BATTLECRY
    --------------------------------------------------
    {
        name = "Scholar",
        cardType = "Minion",
        cost = 2,
        attack = 1,
        health = 1,
        movement = 2,
        archetype = "Magic",
        battlecry = function(gameManager, player)
            -- TEXT: draw 1 card
            player:drawCard(1)
        end
    },

    --------------------------------------------------
    -- Placeholder Minion with DEATHRATTLE
    --------------------------------------------------
    {
        name = "Loot Hoarder",
        cardType = "Minion",
        cost = 2,
        attack = 2,
        health = 1,
        movement = 2,
        archetype = "Melee",
        deathrattle = function(gameManager, player)
            -- TEXT: Draw 1 card
            player:drawCard(1)
        end
    },
    {
        name = "Haunted Minion",
        cardType = "Minion",
        cost = 2,
        attack = 1,
        health = 2,
        movement = 2,
        archetype = "Ranged",
        deathrattle = function(gameManager, player)
            -- TEXT: deal 2 damage to enemy hero
            local enemy = gameManager:getEnemyPlayer(player)
            -- Update to deal damage to a tower instead
            if #enemy.towers > 0 then
                enemy.towers[1].hp = enemy.towers[1].hp - 2
            end
        end
    }
}