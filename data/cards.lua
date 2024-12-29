-- data/cards.lua
-- A simple Lua table defining placeholder cards.
-- We'll keep it super basic for now.

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
        name = "Fiery War Axe",
        cardType = "Weapon",
        cost = 2,
        attack = 3,
        health = 2  -- Durability for a weapon
    },
    {
        name = "Fireball",
        cardType = "Spell",
        cost = 4
        -- Potential effect: deal 6 damage
    },
    {
        name = "Boulderfist Ogre",
        cardType = "Minion",
        cost = 6,
        attack = 6,
        health = 7
    }
}
