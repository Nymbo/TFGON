-- game/managers/deckmanager.lua
-- Manages multiple deck slots for deck building.
-- Each deck is represented as a table with a name and a list of cards.
-- Now includes functions to save and load decks using love.filesystem.

local DeckManager = {}

-- Table to hold all deck slots
DeckManager.decks = {}

-- Require cards data for lookups when loading decks.
local cardsData = require("data.cards")

--------------------------------------------------
-- Helper function: getCardByName
-- Looks up a card from cardsData by its name.
--------------------------------------------------
local function getCardByName(cardName)
    for _, card in ipairs(cardsData) do
        if card.name == cardName then
            return card
        end
    end
    return nil
end

--------------------------------------------------
-- init():
-- Initializes deck slots if they haven't been created.
-- Here we create 5 deck slots as an example.
-- Also attempts to load saved decks from file.
--------------------------------------------------
function DeckManager:init()
    if love.filesystem.getInfo("saved_decks.lua") then
        self:loadDecks()
    else
        -- No saved decks found, create new ones.
        for i = 1, 5 do
            DeckManager.decks[i] = { name = "Deck " .. i, cards = {} }
        end
    end
end

--------------------------------------------------
-- getDeck(index):
-- Returns the deck at the specified index.
--------------------------------------------------
function DeckManager:getDeck(index)
    return DeckManager.decks[index]
end

--------------------------------------------------
-- addCardToDeck(deckIndex, card):
-- Attempts to add a card to the specified deck.
-- Ensures that no more than 2 copies of a card are added
-- and that the deck does not exceed 20 cards.
--------------------------------------------------
function DeckManager:addCardToDeck(deckIndex, card)
    local deck = DeckManager.decks[deckIndex]
    if deck then
        -- Count copies of this card in the deck
        local count = 0
        for _, c in ipairs(deck.cards) do
            if c.name == card.name then count = count + 1 end
        end
        if count < 2 and #deck.cards < 20 then
            table.insert(deck.cards, card)
            return true
        else
            return false
        end
    end
    return false
end

--------------------------------------------------
-- removeCardFromDeck(deckIndex, cardIndex):
-- Removes the card at the given index from the deck.
--------------------------------------------------
function DeckManager:removeCardFromDeck(deckIndex, cardIndex)
    local deck = DeckManager.decks[deckIndex]
    if deck and deck.cards[cardIndex] then
        table.remove(deck.cards, cardIndex)
        return true
    end
    return false
end

--------------------------------------------------
-- validateDeck(deckIndex):
-- Checks if the deck has exactly 20 cards and that
-- no card appears more than twice.
--------------------------------------------------
function DeckManager:validateDeck(deckIndex)
    local deck = DeckManager.decks[deckIndex]
    if deck then
        if #deck.cards ~= 20 then
            return false, "Deck must have exactly 20 cards."
        end
        local counts = {}
        for _, card in ipairs(deck.cards) do
            counts[card.name] = (counts[card.name] or 0) + 1
            if counts[card.name] > 2 then
                return false, "Card " .. card.name .. " appears more than 2 times."
            end
        end
        return true, "Deck is valid."
    end
    return false, "Deck not found."
end

--------------------------------------------------
-- serializeDecks(decks):
-- Serializes the decks table into a Lua literal string.
-- Only saves the deck name and card names.
--------------------------------------------------
local function serializeDecks(decks)
    local result = "return {\n"
    for i, deck in ipairs(decks) do
        result = result .. string.format("  { name = %q, cards = {", deck.name)
        for j, card in ipairs(deck.cards) do
            result = result .. string.format("%q,", card.name)
        end
        result = result .. " } },\n"
    end
    result = result .. "}"
    return result
end

--------------------------------------------------
-- saveDecks():
-- Saves the current decks to a file using love.filesystem.
--------------------------------------------------
function DeckManager:saveDecks()
    local serialized = serializeDecks(DeckManager.decks)
    local success, message = love.filesystem.write("saved_decks.lua", serialized)
    if not success then
        print("Error saving decks: " .. tostring(message))
    else
        print("Decks saved successfully.")
    end
end

--------------------------------------------------
-- loadDecks():
-- Loads decks from the saved file and updates DeckManager.decks.
-- Looks up each card by name from cardsData.
--------------------------------------------------
function DeckManager:loadDecks()
    if love.filesystem.getInfo("saved_decks.lua") then
        local chunk, err = love.filesystem.load("saved_decks.lua")
        if not chunk then
            print("Error loading decks: " .. tostring(err))
            return
        end
        local savedDecks = chunk()
        -- Convert saved decks into full card tables.
        local loadedDecks = {}
        for i, savedDeck in ipairs(savedDecks) do
            local deck = { name = savedDeck.name, cards = {} }
            for j, cardName in ipairs(savedDeck.cards) do
                local card = getCardByName(cardName)
                if card then
                    table.insert(deck.cards, card)
                else
                    print("Warning: Card not found for name: " .. cardName)
                end
            end
            loadedDecks[i] = deck
        end
        DeckManager.decks = loadedDecks
        print("Decks loaded successfully.")
    else
        print("No saved decks found. Initializing new decks.")
        for i = 1, 5 do
            DeckManager.decks[i] = { name = "Deck " .. i, cards = {} }
        end
    end
end

return DeckManager
