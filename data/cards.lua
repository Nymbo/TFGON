-- data/cards.lua
-- This file returns a table of card definitions used to populate decks.
-- Each entry represents a different card, with properties like:
-- name, cardType, cost, attack, health, and possibly an effect function
-- (for spells or weapons).

return {
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
    {
        name = "Fiery War Axe",
        cardType = "Weapon",
        cost = 2,
        attack = 3,
        durability = 2,
        effect = function(gameManager, player)
            player.weapon = {
                attack = 3,
                durability = 2
            }
        end
    },
    {
        name = "Fireball",
        cardType = "Spell",
        cost = 4,
        effect = function(gameManager, player)
            local enemy = gameManager:getEnemyPlayer(player)
            enemy.health = enemy.health - 6
        end
    }
}