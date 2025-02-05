-- data/cards.lua
-- Updated to remove inline effect functions for spells/weapons
-- and reference a string key like "FireballEffect" or "FieryWarAxeEffect"
-- that is implemented in effectmanager.lua.
--
-- We also add two placeholder minions with Battlecry and Deathrattle.

return {
    --------------------------------------------------
    -- Basic Minions
    --------------------------------------------------
    {
        name = "Wisp",
        cardType = "Minion",
        cost = 0,
        attack = 1,
        health = 1
    },
    {
        name = "River Crocolisk",
        cardType = "Minion",
        cost = 2,
        attack = 2,
        health = 3
    },
    {
        name = "Magma Rager",
        cardType = "Minion",
        cost = 3,
        attack = 5,
        health = 1
    },
    {
        name = "Chillwind Yeti",
        cardType = "Minion",
        cost = 4,
        attack = 4,
        health = 5
    },
    {
        name = "Boulderfist Ogre",
        cardType = "Minion",
        cost = 6,
        attack = 6,
        health = 7
    },
    {
        name = "War Golem",
        cardType = "Minion",
        cost = 7,
        attack = 7,
        health = 7
    },

    --------------------------------------------------
    -- Weapon (refactored to use effectKey)
    --------------------------------------------------
    {
        name = "Fiery War Axe",
        cardType = "Weapon",
        cost = 2,
        attack = 3,       -- purely informational
        durability = 2,   -- purely informational
        effectKey = "FieryWarAxeEffect"
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
        name = "Novice Engineer",
        cardType = "Minion",
        cost = 2,
        attack = 1,
        health = 1,
        battlecry = function(gameManager, player)
            -- Example: draw 1 card
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
        deathrattle = function(gameManager, player)
            -- Example: Draw 1 card
            player:drawCard(1)
        end
    },
    {
        name = "Haunted Minion",
        cardType = "Minion",
        cost = 2,
        attack = 1,
        health = 2,
        deathrattle = function(gameManager, player)
            -- Example: deal 2 damage to enemy hero
            local enemy = gameManager:getEnemyPlayer(player)
            enemy.health = enemy.health - 2
        end
    }
}
