-- conf.lua
-- Configures LÖVE settings (window size, title, etc.)
function love.conf(t)
    t.window.title = "The Fine Game of Nil"
    t.window.width = 1280
    t.window.height = 720
    t.console = true  -- Set to true if you want to see print statements in a console (Windows only).
end
