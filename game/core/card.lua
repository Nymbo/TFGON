-- game/core/card.lua
-- Base definition for a card. 
-- We'll just store the data for now (we’ll handle behavior later).

local Card = {}
Card.__index = Card

function Card:new(cardData)
    local self = setmetatable({}, Card)
    self.name = cardData.name or "Unnamed Card"
    self.cardType = cardData.cardType or "Minion"  -- "Minion", "Spell", "Weapon"
    self.cost = cardData.cost or 0
    self.attack = cardData.attack or 0  -- for Minions/Weapons
    self.health = cardData.health or 0  -- for Minions
    -- Spells can have an effect function we call on use
    return self
end

return Card
