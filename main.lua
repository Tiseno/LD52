local love = require("love")

local RED = {1, 0, 0}
local GREEN = {0, 1, 0}
local BLUE = {0, 0, 1}

local MAIN_MENU = "MAIN_MENU"
local GAME_INIT = "GAME_INIT"
local GAME_RUNNING = "GAME_RUNNING"
local GAME_PAUSED = "GAME_PAUSED"
local GAME_OVER = "GAME_OVER"

local STATE = GAME_INIT

CyclicTime = 0
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

-- SkyVaultGames: https://www.youtube.com/watch?v=vMSjVuJ6wDs
local function newMenuButton(text, fn)
    return {
        text = text,
        fn = fn,
        pressed = false
    }
end

local main_menu = {}
local pause_menu = {}

local function newBone(x, y, width, height, angle, color, children)
    return {
        x = x,
        y = y,
        width = width,
        height = height,
        angle = angle,
        color = color,
        children = children
    }
end

local function newWheat(x, y)
    local color = {200 / 255, 150 / 255, 100 / 255}

    -- 16 total, 7 on left, 8 on right, 1 at the top
    local seeds = {}
    for i = 0, 7, 1 do
        table.insert(seeds, newBone(0, i * 6, 3, 10, 0.4, color, {}))
    end
    for i = 0, 8, 1 do
        table.insert(seeds, newBone(0, i * 6 - 3, 3, 10, -0.4, color, {}))
    end
    table.insert(seeds, newBone(0, 8 * 6, 3, 10, 0, color, {}))

    local seed = math.random() * math.pi
    local bend = -0.09 + math.random() * 0.18
    local random_height = math.random() * 50
    local stalk3 = newBone(0, 0, 2, 30 + random_height, bend, color, seeds)
    local stalk2 = newBone(0, 0, 2, 30 + random_height, bend, color, {stalk3})
    local stalk1 = newBone(0, 0, 2, 30 + random_height, bend + math.pi * 1 + math.random() * 0.08, color, {stalk2})

    return {x = x, y = y, skeleton = stalk1, bend = bend, seed = seed}
end

local wheats = {}
-- https://love2d.org/wiki/Tutorial:Physics
local function initGameWorld()
    World = love.physics.newWorld(0, 981, true)
    Objects = {}
    Objects.ground = {}
    local window_width = love.graphics.getWidth()
    local window_height = love.graphics.getHeight()

    Objects.ground.body = love.physics.newBody(World, window_width / 2, 520)
    Objects.ground.shape = love.physics.newRectangleShape(window_width, 40)
    Objects.ground.fixture = love.physics.newFixture(Objects.ground.body, Objects.ground.shape)

    for i = 0, 200, 1 do
        table.insert(wheats, newWheat(0 + i * 5 + math.random()*3, 500))
    end
end

local function destroyWorld()
    Objects = {}
    World = {}
    wheats = {}
end

function love.load()
    Font = love.graphics.newFont(16)
    love.physics.setMeter(100)

    table.insert(
        main_menu,
        newMenuButton(
            "Start Game",
            function()
                print("Changed state to init")
                STATE = GAME_INIT
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

function updateWheat(wheat)

end

function love.update(dt)
    if STATE == GAME_INIT then
        initGameWorld()
        STATE = GAME_RUNNING
    end

    if STATE ~= GAME_RUNNING then
        return
    end

    CyclicTime = CyclicTime + dt
    if CyclicTime > math.pi then
        CyclicTime = CyclicTime - math.pi
    end

    Time = Time + dt
    if Time > math.pi then
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

    for i, wheat in ipairs(wheats) do
        updateWheat(wheat)
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

-- https://love2d.org/wiki/love.graphics.rectangle
local function drawRotatedRectangle(x, y, width, height, angle, color)
    -- We cannot rotate the rectangle directly, but we
    -- can move and rotate the coordinate system.
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(angle)
    -- love.graphics.rectangle(mode, 0, 0, width, height) -- origin in the top left corner
    love.graphics.setColor(unpack(color))
    love.graphics.rectangle("fill", -width / 2, -height / 2, width, height) -- origin in the middle
    love.graphics.pop()
end

local function drawBone(bone)
    love.graphics.push()
    love.graphics.translate(bone.x, bone.y)
    love.graphics.rotate(bone.angle)
    love.graphics.setColor(unpack(bone.color))
    love.graphics.rectangle("fill", -bone.width / 2, 0, bone.width, bone.height) -- origin in the middle bottom
    -- love.graphics.rectangle("fill", 0, 0, bone.width, bone.height) -- origin in the top left corner
    -- love.graphics.rectangle("fill", -bone.width / 2, -bone.height / 2, bone.width, bone.height) -- origin in the middle
    love.graphics.translate(0, bone.height)
    for i, childBone in ipairs(bone.children) do
        drawBone(childBone)
    end
    love.graphics.pop()
end

local function drawSkeleton(x, y, skeleton)
    love.graphics.push()
    love.graphics.translate(x, y)
    drawBone(skeleton)
    love.graphics.pop()
end


local function drawWheat(w)
    drawSkeleton(w.x, w.y, w.skeleton)
end

local function drawPoint(x, y, size, color)
    love.graphics.setColor(unpack(color))
    love.graphics.rectangle("fill", x - (size / 2), y - (size / 2), size, size)
end

local function drawWorld()
    love.graphics.setColor(0.5, 0.7, 0.9)
    love.graphics.polygon("fill", Objects.ground.body:getWorldPoints(Objects.ground.shape:getPoints()))

    for i, wheat in ipairs(wheats) do
        drawWheat(wheat)
    end
end

function love.draw(dt)
    print(STATE)

    if STATE == MAIN_MENU then
        drawMenu(main_menu)
    end

    if STATE == GAME_RUNNING then
        drawWorld()
    end

    if STATE == GAME_PAUSED then
        drawWorld()
        -- TODO draw shadow
        drawMenu(pause_menu)
    end

    if STATE == GAME_OVER then
        drawWorld()
    -- TODO
    end
end
