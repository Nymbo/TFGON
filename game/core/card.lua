-- game/core/card.lua
-- A base definition for a card within the game.
-- This module stores the fundamental data for any card,
-- regardless of its type (e.g., Minion, Spell, or Weapon).

--------------------------------------------------
-- Table definition for Card
--------------------------------------------------
local Card = {}
Card.__index = Card

--------------------------------------------------
-- Constructor for a new Card.
-- Accepts a table of cardData with various fields:
--  - name (string)
--  - cardType (e.g., "Minion", "Spell", or "Weapon")
--  - cost (integer)
--  - attack (integer, for Minions or Weapons)
--  - health (integer, for Minions)
-- Returns a new card instance.
--------------------------------------------------
function Card:new(cardData)
    local self = setmetatable({}, Card)

    -- Basic properties
    self.name = cardData.name or "Unnamed Card"
    self.cardType = cardData.cardType or "Minion"  -- Default to "Minion" if not specified
    self.cost = cardData.cost or 0
    self.attack = cardData.attack or 0    -- Applicable to Minions and Weapons
    self.health = cardData.health or 0    -- Relevant for Minions

    -- Note: Spells and Weapons may have an 'effect' function in their data
    -- that is handled elsewhere in gameplay logic.

    return self
end

return Card
