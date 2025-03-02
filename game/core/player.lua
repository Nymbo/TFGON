-- game/core/player.lua
-- Defines a Player. Now accepts an optional custom deck.
-- Integrated with EventBus for a more decoupled architecture
local Deck = require("game/core/deck")
local EventBus = require("game/eventbus")  -- Added EventBus import
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
    
    -- Initialize towers array (multiple towers per player)
    self.towers = {}
    
    return self
end

--------------------------------------------------
-- drawCard: Draws 'count' cards from the deck.
-- Now publishes events for card drawing and deck emptying.
--------------------------------------------------
function Player:drawCard(count)
    for i = 1, count do
        local card = self.deck:draw()
        if card then
            -- First modify the state
            table.insert(self.hand, card)
            
            -- Then publish the event
            EventBus.publish(EventBus.Events.CARD_DRAWN, self, card)
        else
            -- Could publish a deck empty event
            EventBus.publish(EventBus.Events.DECK_EMPTY, self)
        end
    end
end

--------------------------------------------------
-- spendMana: Spend mana and publish an event.
--------------------------------------------------
function Player:spendMana(amount)
    if amount <= 0 then return false end
    if amount > self.manaCrystals then return false end
    
    -- Store old value for the event
    local oldValue = self.manaCrystals
    
    -- Update mana
    self.manaCrystals = self.manaCrystals - amount
    
    -- Publish event
    EventBus.publish(EventBus.Events.PLAYER_MANA_CHANGED, self, oldValue, self.manaCrystals)
    
    return true
end

--------------------------------------------------
-- gainMana: Gain mana and publish an event.
--------------------------------------------------
function Player:gainMana(amount)
    if amount <= 0 then return false end
    
    -- Store old value for the event
    local oldValue = self.manaCrystals
    
    -- Update mana (capped at maxManaCrystals)
    self.manaCrystals = math.min(self.maxManaCrystals, self.manaCrystals + amount)
    
    -- Only publish if there was actually a change
    if self.manaCrystals ~= oldValue then
        EventBus.publish(EventBus.Events.PLAYER_MANA_CHANGED, self, oldValue, self.manaCrystals)
        return true
    end
    
    return false
end

--------------------------------------------------
-- setMaxMana: Set max mana and publish an event.
--------------------------------------------------
function Player:setMaxMana(amount)
    if amount < 0 or amount > 10 then return false end
    
    -- Store old values
    local oldMax = self.maxManaCrystals
    local oldCurrent = self.manaCrystals
    
    -- Update max mana
    self.maxManaCrystals = amount
    
    -- Update current mana if needed
    if self.manaCrystals > self.maxManaCrystals then
        self.manaCrystals = self.maxManaCrystals
    end
    
    -- Publish max mana changed event
    EventBus.publish(EventBus.Events.PLAYER_MAX_MANA_CHANGED, self, oldMax, self.maxManaCrystals)
    
    -- If current mana also changed, publish that event
    if self.manaCrystals ~= oldCurrent then
        EventBus.publish(EventBus.Events.PLAYER_MANA_CHANGED, self, oldCurrent, self.manaCrystals)
    end
    
    return true
end

--------------------------------------------------
-- gainMaxMana: Increase max mana and publish events
--------------------------------------------------
function Player:gainMaxMana(amount)
    if amount <= 0 then return false end
    
    -- Cap max mana at 10
    local newMax = math.min(10, self.maxManaCrystals + amount)
    return self:setMaxMana(newMax)
end

--------------------------------------------------
-- startTurn: Prepare player for their turn
--------------------------------------------------
function Player:startTurn()
    -- Gain a mana crystal (max 10)
    if self.maxManaCrystals < 10 then
        self:gainMaxMana(1)
    end
    
    -- Refill mana
    local oldMana = self.manaCrystals
    self.manaCrystals = self.maxManaCrystals
    
    -- Publish mana changed event
    if oldMana ~= self.manaCrystals then
        EventBus.publish(EventBus.Events.PLAYER_MANA_CHANGED, self, oldMana, self.manaCrystals)
    end
    
    -- Reset hero attacked flag
    self.heroAttacked = false
    
    -- Publish turn started event
    EventBus.publish(EventBus.Events.PLAYER_TURN_STARTED, self)
    
    -- Draw a card
    self:drawCard(1)
end

--------------------------------------------------
-- endTurn: Clean up at end of turn
--------------------------------------------------
function Player:endTurn()
    -- Publish turn ended event
    EventBus.publish(EventBus.Events.PLAYER_TURN_ENDED, self)
end

return Player