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

local WHITE = {1, 1, 1}
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

local function newMenuText(text, font, textColor, fn)
    return {
        type = "text",
        text = text,
        font = font,
        textColor = textColor
    }
end

-- SkyVaultGames: https://www.youtube.com/watch?v=vMSjVuJ6wDs
local function newMenuButton(text, font, textColor, buttonColor, fn)
    return {
        type = "button",
        text = text,
        font = font,
        textColor = textColor,
        buttonColor = buttonColor,
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

local World = {}
local Objects = {}
local Props = {}

local function addWheat(list)
    local n = 380
    local spacing = 5
    for i = 0, n, 1 do
        table.insert(list, newWheat(-(n * spacing * 0.5) + (i * spacing) - 2 + math.random() * 4, 0))
    end
end

-- https://love2d.org/wiki/Tutorial:Physics
local function initGameWorld()
    World = love.physics.newWorld(0, 981, true)
    Objects.ground = {}
    local window_width = love.graphics.getWidth()
    local window_height = love.graphics.getHeight()

    Objects.ground.body = love.physics.newBody(World, window_width / 2, 0)
    Objects.ground.shape = love.physics.newRectangleShape(window_width, 40)
    Objects.ground.fixture = love.physics.newFixture(Objects.ground.body, Objects.ground.shape)

    addWheat(Props)
end

local function destroyWorld()
    World = {}
    Objects = {}
    Props = {}
end

local MainMenuProps = {}

function love.load()
    addWheat(MainMenuProps)

    FontSmall = love.graphics.newFont(24)
    FontLarge = love.graphics.newFont(32)
    love.physics.setMeter(100)

    table.insert(main_menu, newMenuText("Wheat", FontLarge, WHITE))
    table.insert(
        main_menu,
        newMenuButton(
            "New Game",
            FontSmall,
            WHITE,
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
            FontSmall,
            WHITE,
            BROWN_GRAY,
            function()
                love.event.quit()
            end
        )
    )

    table.insert(pause_menu, newMenuText("Paused", FontLarge, WHITE))
    table.insert(
        pause_menu,
        newMenuButton(
            "Exit Game",
            FontSmall,
            WHITE,
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
            "Resume",
            FontSmall,
            WHITE,
            BROWN_GRAY,
            function()
                STATE = GAME_RUNNING
            end
        )
    )
    print("Loaded")
end

function updateProp(prop, dt)
    if prop.type == "wheat" then
        updateWheat(prop)
    end
end

function main_update(dt)
    for i, prop in ipairs(MainMenuProps) do
        updateProp(prop, dt)
    end
end

function game_update(dt)
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

    for i, prop in ipairs(Props) do
        updateProp(prop, dt)
    end
end

function love.update(dt)
    if STATE == GAME_INIT then
        initGameWorld()
        STATE = GAME_RUNNING
    end

    if STATE == GAME_PAUSED then
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

    if STATE == GAME_RUNNING then
        game_update(dt)
    end

    if STATE == MAIN_MENU then
        main_update(dt)
    end
end

local function drawPoint(x, y, size, color)
    love.graphics.setColor(unpack(color))
    love.graphics.rectangle("fill", x - (size / 2), y - (size / 2), size, size)
end

local function drawMenu(menu)
    local window_width = love.graphics.getWidth()
    local window_height = love.graphics.getHeight()
    local item_height = 55
    local item_height_with_spacing = item_height + 30
    local menu_height = item_height_with_spacing * #menu
    local menu_width = 300
    for i, menu_item in ipairs(menu) do
        local x = (window_width / 2) - (menu_width / 2)
        local y = (window_height / 3) - (menu_height / 2) + ((i - 1) * item_height_with_spacing)

        if menu_item.type == "button" then
            local mouseX, mouseY = love.mouse.getPosition()
            local highlighted =
                mouseX >= x and mouseX <= (x + menu_width) and mouseY >= y and mouseY <= (y + item_height)

            if highlighted then
                love.graphics.setColor(unpack(highlight_color(menu_item.buttonColor)))
            else
                love.graphics.setColor(unpack(menu_item.buttonColor))
            end
            love.graphics.rectangle("fill", x, y, menu_width, item_height)

            if highlighted and not menu_item.pressed and love.mouse.isDown(1) then
                menu_item.fn()
            end
            menu_item.pressed = love.mouse.isDown(1)
        end

        love.graphics.setColor(unpack(menu_item.textColor))
        local textHeight = menu_item.font:getHeight(menu_item.text)
        love.graphics.printf(
            menu_item.text,
            menu_item.font,
            math.floor(x),
            math.floor(y + (item_height / 2) - (textHeight / 2)),
            menu_width,
            "center"
        )
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

local function drawProps(props)
    local window_width = love.graphics.getWidth()
    local window_height = love.graphics.getHeight()
    love.graphics.push()
    love.graphics.translate(math.floor(window_width / 2), window_height)
    for i, prop in ipairs(props) do
        if prop.type == "wheat" then
            drawWheat(prop)
        end
    end
    love.graphics.pop()
end

local function drawMainMenuWorld()
    drawProps(MainMenuProps)
end

local function drawGameWorld()
    -- local window_height = love.graphics.getHeight()
    -- love.graphics.push()
    -- love.graphics.translate(0, window_height)
    --
    -- love.graphics.setColor(unpack(BROWN_GRAY))
    -- love.graphics.polygon("fill", Objects.ground.body:getWorldPoints(Objects.ground.shape:getPoints()))
    -- love.graphics.pop()

    drawProps(Props)
end

local function drawWindowTint()
    local window_width = love.graphics.getWidth()
    local window_height = love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", 0, 0, window_width, window_height)
end

function love.draw(dt)
    if STATE == MAIN_MENU then
        drawMainMenuWorld()
        drawMenu(main_menu)
    end

    if STATE == GAME_RUNNING then
        drawGameWorld()
    end

    if STATE == GAME_PAUSED then
        drawGameWorld()
        drawWindowTint()
        drawMenu(pause_menu)
    end

    if STATE == GAME_OVER then
        drawGameWorld()
    -- TODO
    end
end
