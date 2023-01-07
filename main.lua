local love = require("love")

local MAIN_MENU = 0
local GAME_RUNNING = 1
local GAME_PAUSED = 2
local GAME_OVER = 3
local STATE = MAIN_MENU

Time = 0

function love.keypressed(key, scancode, isrepeat)
    --print(key)
    --print(scancode)
    --print(isrepeat)
    --print()
    if key == "escape" or key == "p" then
        if STATE == GAME_RUNNING then
            STATE = GAME_PAUSED
        elseif STATE == GAME_PAUSED then
            STATE = GAME_RUNNING
        end
    end

    if key == "unknown" then
        love.event.quit()
    end
end

local function newMenuButton(text, fn)
    return {
        text = text,
        fn = fn,
        pressed = false
    }
end

local main_menu = {}
local pause_menu = {}

local function initGameWorld()
    World = love.physics.newWorld(0, 981, true)
    Objects = {}
    Objects.ground = {}
    local window_width = love.graphics.getWidth()
    local window_height = love.graphics.getHeight()

    Objects.ground.body = love.physics.newBody(World, window_width / 2, 520)
    Objects.ground.shape = love.physics.newRectangleShape(window_width, 40)
    Objects.ground.fixture = love.physics.newFixture(Objects.ground.body, Objects.ground.shape)
end

local function destroyWorld()
    Objects = {}
    World = {}
end

function love.load()
    Font = love.graphics.newFont(16)
    love.physics.setMeter(100)

    table.insert(
        main_menu,
        newMenuButton(
            "Start Game",
            function()
                initGameWorld()
                STATE = GAME_RUNNING
            end
        )
    )
    table.insert(
        main_menu,
        newMenuButton(
            "Exit",
            function()
                love.event.quit()
            end
        )
    )

    table.insert(
        pause_menu,
        newMenuButton(
            "Exit Game",
            function()
                destroyWorld()
                STATE = MAIN_MENU
            end
        )
    )

    table.insert(
        pause_menu,
        newMenuButton(
            "Unpause Game",
            function()
                STATE = GAME_RUNNING
            end
        )
    )
    print("Loaded")
end

function love.update(dt)
    if STATE ~= GAME_RUNNING then
        return
    end
    Time = Time + dt
    if Time > 1 then
        print(Objects.ground.body:getX(), Objects.ground.body:getY())
        Time = Time - 1
    end

    World:update(dt)

    if love.keyboard.isDown("up") then
        Objects.ground.body:setY(Objects.ground.body:getY() - dt * 100)
    end

    if love.keyboard.isDown("down") then
        Objects.ground.body:setY(Objects.ground.body:getY() + dt * 100)
    end

    if love.keyboard.isDown("left") then
        Objects.ground.body:setX(Objects.ground.body:getX() - dt * 100)
    end

    if love.keyboard.isDown("right") then
        Objects.ground.body:setX(Objects.ground.body:getX() + dt * 100)
    end
end

local function drawMenu(menu)
    local window_width = love.graphics.getWidth()
    local window_height = love.graphics.getHeight()
    local menu_width = window_width / 3
    local button_height = 55
    local button_height_with_spacing = button_height + 30
    local total_height = button_height_with_spacing * #menu
    for i, button in ipairs(menu) do
        local x = window_width / 2 - menu_width / 2
        local y = (window_height / 2) - (total_height / 2) + ((i - 1) * button_height_with_spacing)

        local mouseX, mouseY = love.mouse.getPosition()
        local highlighted = mouseX >= x and mouseX <= (x + menu_width) and mouseY >= y and mouseY <= (y + button_height)

        if highlighted then
            love.graphics.setColor(0.4, 0.4, 0.9)
        else
            love.graphics.setColor(0.5, 0.5, 0.9)
        end
        love.graphics.rectangle("fill", x, y, menu_width, button_height)

        if highlighted and not button.pressed and love.mouse.isDown(1) then
            button.fn()
        end
        button.pressed = love.mouse.isDown(1)

        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.printf(button.text, Font, math.floor(x), math.floor(y + (button_height / 2)), x, "center")
    end
end

function love.draw(dt)
    if STATE == MAIN_MENU then
        drawMenu(main_menu)
    else
        love.graphics.setColor(0.5, 0.7, 0.9)
        love.graphics.polygon("fill", Objects.ground.body:getWorldPoints(Objects.ground.shape:getPoints()))
        if STATE == GAME_PAUSED then
            drawMenu(pause_menu)
        end
        if STATE == GAME_OVER then
        -- TODO
        end
    end
end
