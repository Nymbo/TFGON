-- conf.lua
-- Configures LÖVE settings such as window size, title, etc.
-- Enabling high-DPI mode can fix cursor alignment issues on scaled displays.
function love.conf(t)
    t.window.title = "The Fine Game of Nil"
    t.window.width = 1920
    t.window.height = 1080
    t.window.highdpi = false
    t.console = true
end
