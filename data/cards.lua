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
        name = "Murloc Raider",
        cardType = "Minion",
        cost = 1,
        attack = 2,
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
        name = "Boulderfist Ogre",
        cardType = "Minion",
        cost = 6,
        attack = 6,
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
        name = "Battlecry Goblin",
        cardType = "Minion",
        cost = 3,
        attack = 2,
        health = 2,
        battlecry = function(gameManager, player)
            -- Example: draw 1 card
            player:drawCard(1)
        end
    },

    --------------------------------------------------
    -- Placeholder Minion with DEATHRATTLE
    --------------------------------------------------
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
