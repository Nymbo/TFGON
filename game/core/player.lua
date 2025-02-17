-- game/core/player.lua
-- Defines a Player. Now accepts an optional custom deck.
local Deck = require("game/core/deck")
local Player = {}
Player.__index = Player

--------------------------------------------------
-- Constructor for a new Player.
-- If 'customDeck' is provided, it will be used to create the player's deck.
--------------------------------------------------
function Player:new(name, customDeck)
    local self = setmetatable({}, Player)
    self.name = name or "Unnamed"
    self.health = 30
    if customDeck then
        -- Create a deck from the custom deck list using Deck:createFromList
        self.deck = Deck:createFromList(customDeck.cards)
    else
        self.deck = Deck:new()
    end
    self.hand = {}
    self.maxManaCrystals = 0
    self.manaCrystals = 0
    self.weapon = nil
    self.heroAttacked = false
    return self
end

--------------------------------------------------
-- drawCard: Draws 'count' cards from the deck.
--------------------------------------------------
function Player:drawCard(count)
    for i = 1, count do
        local card = self.deck:draw()
        if card then
            table.insert(self.hand, card)
        else
            -- Handle fatigue here if desired
        end
    end
end

return Player
