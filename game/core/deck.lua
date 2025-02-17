-- game/core/deck.lua
-- Manages a deck of cards, including creation, shuffling, and drawing.
local cardsData = require("data.cards")
local Deck = {}
Deck.__index = Deck

--------------------------------------------------
-- Constructor for a new Deck (default: all cards from cardsData).
--------------------------------------------------
function Deck:new()
    local self = setmetatable({}, Deck)
    self.cards = {}
    for i, cardInfo in ipairs(cardsData) do
        table.insert(self.cards, cardInfo)
    end
    self:shuffle()
    return self
end

--------------------------------------------------
-- createFromList: Creates a deck from a given list of cards.
--------------------------------------------------
function Deck:createFromList(cardList)
    local self = setmetatable({}, Deck)
    self.cards = {}
    for i, card in ipairs(cardList) do
        table.insert(self.cards, card)
    end
    self:shuffle()
    return self
end

--------------------------------------------------
-- shuffle: Fisher-Yates shuffle algorithm.
--------------------------------------------------
function Deck:shuffle()
    for i = #self.cards, 2, -1 do
        local j = math.random(1, i)
        self.cards[i], self.cards[j] = self.cards[j], self.cards[i]
    end
end

--------------------------------------------------
-- draw: Removes and returns the top card.
--------------------------------------------------
function Deck:draw()
    if #self.cards == 0 then return nil end
    return table.remove(self.cards, 1)
end

return Deck
