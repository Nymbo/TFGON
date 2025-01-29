-- conf.lua
-- Configures LÖVE settings such as window size, title, etc.

--------------------------------------------------
-- The love.conf function is called before everything else,
-- allowing you to configure your LÖVE application.
--------------------------------------------------
function love.conf(t)
    -- The window title appears in the title bar of the window
    t.window.title = "The Fine Game of Nil"
    
    -- Set the default window width and height
    t.window.width = 1280
    t.window.height = 720
    
    -- Enable the console window for debugging/logging (on Windows)
    -- If set to false, no separate console window is shown.
    t.console = true
end
