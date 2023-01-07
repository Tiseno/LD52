local love = require("love")

local MAIN_MENU = "MAIN_MENU"
local GAME_INIT = "GAME_INIT"
local GAME_RUNNING = "GAME_RUNNING"
local GAME_PAUSED = "GAME_PAUSED"
local GAME_OVER = "GAME_OVER"

local STATE = MAIN_MENU

--https://colorpicker.me
local function rgb(r, g, b)
    return {r / 255, g / 255, b / 255}
end

local function highlight_color(color)
    return {
        math.min(color[1] + 0.1, 1),
        math.min(color[2] + 0.1, 1),
        math.min(color[3] + 0.1, 1)
    }
end

local function mutate_color(color, factor)
    return {
        math.min(color[1] + math.random() * factor, 1),
        math.min(color[2] + math.random() * factor, 1),
        math.min(color[3] + math.random() * factor, 1)
    }
end

-- The color used by the US National Association of Wheat Growers: https://wheatworld.org/wheat-101/wheat-facts/
local WHEAT_COLOR = rgb(179, 136, 7)

local LIGHT_BLUE = {0.5, 0.7, 0.9}
local BROWN_GRAY = rgb(78, 79, 49)

local RED = {1, 0, 0}
local GREEN = {0, 1, 0}
local BLUE = {0, 0, 1}

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
local function newMenuButton(text, color, fn)
    return {
        text = text,
        color = color,
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

local function updateWheat(wheat)
    local s = wheat.skeleton
    while true do
        s.angle = 0.05 * math.sin(wheat.seed + CyclicTime)
        if #s.children > 1 then
            break
        end
        s = s.children[1]
    end
    return wheat
end

local function newWheat(x, y)
    -- 16 total, 7 on left, 8 on right, 1 at the top
    local seeds = {}
    local color = mutate_color(WHEAT_COLOR, 0.2)
    local lr = math.random() > 0.5
    for i = 0, 7, 1 do
        local offset1 = lr and 3 or 1
        local offset2 = lr and 1 or 3
        table.insert(seeds, newBone(0, i * 6 - offset1, 3, 10, 0.4, mutate_color(color, 0.1), {}))
        table.insert(seeds, newBone(0, i * 6 - offset2, 3, 10, -0.4, mutate_color(color, 0.1), {}))
    end
    table.insert(seeds, newBone(0, 7 * 6 + 3, 3, 10, 0, mutate_color(color, 0.1), {}))

    local bend = math.pi * 1 - 0.1 + math.random() * 0.2
    local random_height = math.random() * 30
    local stalk3 = newBone(0, 0, 2, 30 + random_height, 0, color, seeds)
    local stalk2 = newBone(0, 0, 2, 30 + random_height, 0, color, {stalk3})
    local stalk1 = newBone(0, 0, 2, 30 + random_height, 0, color, {stalk2})

    local seed = math.random() * math.pi
    local wheat = {type = "wheat", x = x, y = y, skeleton = stalk1, bend = bend, seed = seed}
    return updateWheat(wheat)
end

local Props = {}

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
        table.insert(Props, newWheat(0 + i * 5 + math.random() * 3, 500))
    end
end

local function destroyWorld()
    Objects = {}
    World = {}
    Props = {}
end

function love.load()
    Font = love.graphics.newFont(16)
    love.physics.setMeter(100)

    table.insert(
        main_menu,
        newMenuButton(
            "Start Game",
            BROWN_GRAY,
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
            BROWN_GRAY,
            function()
                love.event.quit()
            end
        )
    )

    table.insert(
        pause_menu,
        newMenuButton(
            "Exit Game",
            BROWN_GRAY,
            function()
                destroyWorld()
                STATE = MAIN_MENU
            end
        )
    )

    table.insert(
        pause_menu,
        newMenuButton(
            "Unpause",
            BROWN_GRAY,
            function()
                STATE = GAME_RUNNING
            end
        )
    )
    print("Loaded")
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
    if CyclicTime > (2 * math.pi) then
        CyclicTime = CyclicTime - (2 * math.pi)
    end

    Time = Time + dt
    if Time > math.pi then
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

    for i, wheat in ipairs(Props) do
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
            love.graphics.setColor(unpack(highlight_color(button.color)))
        else
            love.graphics.setColor(unpack(button.color))
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
    drawBone(skeleton)
end

local function drawWheat(w)
    love.graphics.push()
    love.graphics.translate(w.x, w.y)
    love.graphics.rotate(w.bend)
    drawSkeleton(w.x, w.y, w.skeleton)
    love.graphics.pop()
end

local function drawPoint(x, y, size, color)
    love.graphics.setColor(unpack(color))
    love.graphics.rectangle("fill", x - (size / 2), y - (size / 2), size, size)
end

local function drawMainMenuProps()
    for i, prop in ipairs(Props) do
        if prop.type == 'wheat' then
          drawWheat(prop)
        end
    end
end

local function drawWorld()
    love.graphics.setColor(unpack(BROWN_GRAY))
    love.graphics.polygon("fill", Objects.ground.body:getWorldPoints(Objects.ground.shape:getPoints()))

    for i, prop in ipairs(Props) do
        if prop.type == 'wheat' then
          drawWheat(prop)
        end
    end
end

function love.draw(dt)
    if STATE == MAIN_MENU then
        drawMainMenuProps()
        drawMenu(main_menu)
    end

    if STATE == GAME_RUNNING then
        drawWorld()
    end

    if STATE == GAME_PAUSED then
        drawWorld()
        local window_width = love.graphics.getWidth()
        local window_height = love.graphics.getHeight()
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.rectangle("fill", 0, 0, window_width, window_height)
        drawMenu(pause_menu)
    end

    if STATE == GAME_OVER then
        drawWorld()
    -- TODO
    end
end
