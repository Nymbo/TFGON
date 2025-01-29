-- game/core/deck.lua
-- Manages a deck of cards, including creation, shuffling, and drawing.

--------------------------------------------------
-- Require the global card data from data/cards.lua
--------------------------------------------------
local cardsData = require("data.cards")

--------------------------------------------------
-- Table definition for Deck
--------------------------------------------------
local Deck = {}
Deck.__index = Deck

--------------------------------------------------
-- Constructor for a new Deck.
-- 1. Copies card data from 'cardsData' so each deck
--    maintains its own independent list.
-- 2. Shuffles the new deck upon creation.
--------------------------------------------------
function Deck:new()
    local self = setmetatable({}, Deck)

    -- Create a shallow copy of the global card data
    -- so that modifying this deck won't affect others.
    self.cards = {}
    for i, cardInfo in ipairs(cardsData) do
        table.insert(self.cards, cardInfo)
    end

    -- Shuffle the deck right after creation
    self:shuffle()
    return self
end

--------------------------------------------------
-- shuffle():
-- Implements a Fisher-Yates shuffle algorithm.
-- This randomly rearranges all cards in the deck.
--------------------------------------------------
function Deck:shuffle()
    -- Loop backwards through the list of cards,
    -- swapping each card with a random one before it.
    for i = #self.cards, 2, -1 do
        -- Pick a random position from 1 to i
        local j = math.random(1, i)
        -- Swap the cards at indices i and j
        self.cards[i], self.cards[j] = self.cards[j], self.cards[i]
    end
end

--------------------------------------------------
-- draw():
-- Removes the top card (index 1) from the deck and returns it.
-- If the deck is empty, returns nil.
--------------------------------------------------
function Deck:draw()
    if #self.cards == 0 then
        return nil  -- No cards left
    end
    -- table.remove(..., 1) removes and returns the first item
    return table.remove(self.cards, 1)
end

return Deck
