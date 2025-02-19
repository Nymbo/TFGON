-- game/core/tower.lua
-- Defines a Tower object that can be placed anywhere on any board.

local Tower = {}
Tower.__index = Tower

--------------------------------------------------
-- Tower:new(params)
-- Constructor for a new Tower.
-- Expects a table 'params' with:
--   - owner: the owner of the tower (player object)
--   - position: table with x and y (grid coordinates)
--   - hp: hit points for the tower
--   - imagePath: file path to the tower's image
--------------------------------------------------
function Tower:new(params)
    local self = setmetatable({}, Tower)
    self.owner = params.owner
    self.position = params.position or { x = 0, y = 0 }
    self.hp = params.hp or 30
    self.imagePath = params.imagePath or "assets/images/default_tower.png"
    self.image = love.graphics.newImage(self.imagePath)  -- Load the tower image
    return self
end

return Tower
