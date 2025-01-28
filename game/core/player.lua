-- game/core/player.lua
local Deck = require("game.core.deck")

local Player = {}
Player.__index = Player

function Player:new(name)
    local self = setmetatable({}, Player)
    self.name = name or "Unnamed"
    self.health = 30
    self.deck = Deck:new()            -- each player has a deck
    self.hand = {}                    -- cards in hand
    self.maxManaCrystals = 0
    self.manaCrystals = 0
    self.weapon = nil
    self.heroAttacked = false
    return self
end

-- Draw 'count' cards from the deck into hand
function Player:drawCard(count)
    for i = 1, count do
        local card = self.deck:draw()
        if card then
            table.insert(self.hand, card)
        else
            -- If the deck is empty, we could handle fatigue here
            -- but for now let's just skip
        end
    end
end

return Player