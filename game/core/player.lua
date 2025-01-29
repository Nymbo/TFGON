-- game/core/player.lua
-- Defines a Player, who has a name, health,
-- a deck of cards, a hand, and mana resources.

--------------------------------------------------
-- Require the Deck module so each Player can have
-- their own deck of cards.
--------------------------------------------------
local Deck = require("game.core.deck")

--------------------------------------------------
-- Table definition for Player
--------------------------------------------------
local Player = {}
Player.__index = Player

--------------------------------------------------
-- Constructor for a new Player.
-- Initializes:
--  - name (string)
--  - health (default 30)
--  - deck (unique Deck instance)
--  - hand (empty table for drawn cards)
--  - manaCrystals (both max and current)
--  - weapon (nil if none equipped)
--  - heroAttacked (tracks if hero has attacked this turn)
--------------------------------------------------
function Player:new(name)
    local self = setmetatable({}, Player)
    
    self.name = name or "Unnamed"     -- Player's display name
    self.health = 30                  -- Starting health
    self.deck = Deck:new()            -- Unique deck for drawing cards
    self.hand = {}                    -- The cards the player currently holds

    self.maxManaCrystals = 0         -- Maximum mana that increases each turn
    self.manaCrystals = 0            -- Current available mana (resets each turn)
    
    self.weapon = nil                -- Holds weapon data if equipped
    self.heroAttacked = false        -- Tracks if hero has used a weapon attack this turn

    return self
end

--------------------------------------------------
-- drawCard(count):
-- Draws 'count' cards from the deck into the player's hand.
-- If the deck is empty, no cards are drawn (could handle fatigue).
--------------------------------------------------
function Player:drawCard(count)
    for i = 1, count do
        local card = self.deck:draw()
        if card then
            table.insert(self.hand, card)
        else
            -- Deck is empty; in a real game, you might apply "fatigue" damage here
        end
    end
end

return Player
