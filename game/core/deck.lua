-- game/core/deck.lua
-- Represents a deck of cards and handles drawing, shuffling, etc.

local cardsData = require("data.cards")

local Deck = {}
Deck.__index = Deck

function Deck:new()
    local self = setmetatable({}, Deck)

    -- Create a shallow copy of card data so each deck can have its own
    self.cards = {}
    for i, cardInfo in ipairs(cardsData) do
        table.insert(self.cards, cardInfo)
    end

    self:shuffle()
    return self
end

function Deck:shuffle()
    -- Simple Fisher-Yates shuffle
    for i = #self.cards, 2, -1 do
        local j = math.random(1, i)
        self.cards[i], self.cards[j] = self.cards[j], self.cards[i]
    end
end

function Deck:draw()
    if #self.cards == 0 then
        return nil
    end
    return table.remove(self.cards, 1)
end

return Deck
