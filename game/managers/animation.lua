-- game/managers/animation.lua
-- A simple custom tweening/animation module for smooth property transitions.
-- Usage:
--   Animation.tween(obj, { x = newX, y = newY }, duration, easingFunction, callback)
--   Call Animation.update(dt) in your update loop to progress animations.
--   Available easing functions: Animation.easing.linear, Animation.easing.easeInQuad, Animation.easing.easeOutQuad

local Animation = {}

-- Table to hold active tweens
Animation.tweens = {}

-- Easing functions for smooth animations.
Animation.easing = {
    -- Linear easing: no acceleration.
    linear = function(t)
        return t
    end,
    -- EaseInQuad: acceleration from zero velocity.
    easeInQuad = function(t)
        return t * t
    end,
    -- EaseOutQuad: deceleration to zero velocity.
    easeOutQuad = function(t)
        return -t * (t - 2)
    end,
    -- (Additional easing functions can be added here)
}

--[[
    tween(obj, target, duration, easing, callback)
    @obj: The table containing properties to animate.
    @target: A table of target values for the properties (e.g. { x = 100, y = 200 }).
    @duration: Duration of the animation in seconds.
    @easing: (Optional) An easing function that takes a normalized time (0 to 1) and returns progress.
             Defaults to linear easing if not provided.
    @callback: (Optional) A function to be called once the tween completes.
]]
function Animation.tween(obj, target, duration, easing, callback)
    local tween = {
        obj = obj,
        target = target,
        duration = duration,
        elapsed = 0,
        easing = easing or Animation.easing.linear,
        callback = callback,
        start = {}
    }
    -- Record starting values for each property to be animated
    for k, v in pairs(target) do
        tween.start[k] = obj[k]
    end
    table.insert(Animation.tweens, tween)
end

-- Update all active tweens. Call this function in your main update(dt) loop.
function Animation.update(dt)
    for i = #Animation.tweens, 1, -1 do
        local tween = Animation.tweens[i]
        tween.elapsed = tween.elapsed + dt
        local t = tween.elapsed / tween.duration
        if t > 1 then t = 1 end
        local progress = tween.easing(t)
        -- Update each property based on progress
        for k, targetVal in pairs(tween.target) do
            local startVal = tween.start[k]
            tween.obj[k] = startVal + (targetVal - startVal) * progress
        end
        -- If animation is complete, call the callback and remove the tween.
        if t >= 1 then
            if tween.callback then tween.callback() end
            table.remove(Animation.tweens, i)
        end
    end
end

-- Clears all active tweens (if needed)
function Animation.clear()
    Animation.tweens = {}
end

return Animation
