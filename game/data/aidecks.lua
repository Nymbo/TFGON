-- game/data/aidecks.lua
-- Contains pre-built decks for the AI opponent

local AIDeck = {}

-- Function to create a basic deck from the card pool with duplicates allowed
function AIDeck.createBasicDeck(allCards, deckName)
    local selectedCards = {}
    local deckSize = 20
    
    -- Function to find a card by name
    local function findCardByName(name)
        for _, card in ipairs(allCards) do
            if card.name == name then
                return card
            end
        end
        return nil
    end
    
    -- Create a new deck with the given name
    local deck = {
        name = deckName or "AI Deck",
        cards = {}
    }
    
    -- Add specific cards to ensure a balanced deck
    local cardList = {
        -- Basic minions for early game (2 copies each)
        {name = "Wisp", count = 2},
        {name = "Quickfoot McGee", count = 2},
        {name = "River Crocolisk", count = 2},
        {name = "Eager Recruit", count = 2},
        {name = "Rifleman", count = 2},
        {name = "Scholar", count = 2},
        {name = "Haunted Minion", count = 2},
        {name = "Loot Hoarder", count = 2},
        
        -- Mid-game minions
        {name = "Magma Rager", count = 1},
        {name = "Hair-trigger Bandit", count = 1},
        {name = "Chillwind Yeti", count = 1},
        {name = "Ardent Defender", count = 1},
        
        -- Late game threats
        {name = "Boulderfist Ogre", count = 1},
        {name = "War Golem", count = 1},
        
        -- Spells and weapons
        {name = "Fireball", count = 1},
        {name = "Fiery War Axe", count = 1},
    }
    
    -- Add cards from the list to the deck
    for _, cardEntry in ipairs(cardList) do
        local card = findCardByName(cardEntry.name)
        if card then
            for i = 1, cardEntry.count do
                table.insert(deck.cards, card)
            end
        end
    end
    
    -- Ensure the deck has exactly 20 cards
    local totalCards = #deck.cards
    if totalCards < deckSize then
        -- Fill remaining slots randomly
        local candidates = {}
        for _, card in ipairs(allCards) do
            if card.cardType == "Minion" then
                table.insert(candidates, card)
            end
        end
        
        for i = 1, (deckSize - totalCards) do
            local randomIndex = math.random(1, #candidates)
            table.insert(deck.cards, candidates[randomIndex])
        end
    elseif totalCards > deckSize then
        -- Trim the deck to 20 cards
        while #deck.cards > deckSize do
            table.remove(deck.cards)
        end
    end
    
    return deck
end

-- Predefined decks for different AI difficulty levels

-- Easy AI Deck: More basic units, fewer specials
AIDeck.easyDeck = function(allCards)
    return AIDeck.createBasicDeck(allCards, "AI Easy Deck")
end

-- Normal AI Deck: Balanced mix of units
AIDeck.normalDeck = function(allCards)
    return AIDeck.createBasicDeck(allCards, "AI Normal Deck")
end

-- Hard AI Deck: More strategic units with abilities
AIDeck.hardDeck = function(allCards)
    local deck = AIDeck.createBasicDeck(allCards, "AI Hard Deck")
    
    -- Replace some basic cards with more strategic options
    -- This would be expanded with more cards as they're added to the game
    
    return deck
end

return AIDeck