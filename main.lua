local love = require("love")

local MAIN_MENU = "MAIN_MENU"
local GAME_INIT = "GAME_INIT"
local GAME_RUNNING = "GAME_RUNNING"
local GAME_PAUSED = "GAME_PAUSED"
local GAME_OVER = "GAME_OVER"

local STATE = GAME_INIT

--https://colorpicker.me
local function rgb(r, g, b)
    return {r / 255, g / 255, b / 255}
end

local function darken_color(color)
    return {
        math.max(math.min(color[1] * 0.4, 1), 0),
        math.max(math.min(color[2] * 0.4, 1), 0),
        math.max(math.min(color[3] * 0.4, 1), 0)
    }
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
local ORANGE = rgb(255, 128, 61)
local BROWN_GRAY = rgb(78, 79, 49)

local WHITE = {1, 1, 1}
local BLACK = {0, 0, 0}
local DARK_GRAY = {0.2, 0.2, 0.2}
local RED = {1, 0, 0}
local GREEN = {0, 1, 0}
local BLUE = {0, 0, 1}

CyclicTime = 0
TimeAlive = 0
KernelTimer = 0
KERNEL_TIMER_COOLDOWN = 0.2 -- 2 -- TODO

local DEFAULT_MAX_STALK_BEND = 0.05
local DEFAULT_STALK_BEND_SPEED = 1
local max_stalk_bend = DEFAULT_MAX_STALK_BEND
local stalk_bend_speed = DEFAULT_STALK_BEND_SPEED

local World = {}
local Objects = {}
local Score = {collected = 0, time = 0, score = 0, death_reason = nil}
local BackgroundProps = {}
local Props = {}

local STARVED_TO_DEATH = 0
local EATEN_BY_FROG = 1
local MANGLED_BY_TRACTOR = 2
local FELL_FROM_HIGH_PLACE = 3

local KERNEL_CALORIE_WORTH = 15

local CATEGORY_DEFAULT = 1
local CATEGORY_STATIC = 2
local CATEGORY_BIRD = 3
local CATEGORY_KERNEL = 4

local DEFAULT_BIRD_MASS = 0.03
local DEFAULT_BIRD_INERTIA = 1000000000000000
local DEFAULT_KERNEL_MASS = 0.001

local DEFAULT_FRICTION = 0.7

local function random_frog_verb()
    local reasons = {
        "assassinated",
        "consumed",
        "devoured",
        "eaten",
        "killed",
        "sent to the shadow realm",
        "smacked",
        "wasted",
        "whipped"
    }
    return reasons[1 + math.floor(math.random() * #reasons)]
end

local function random_tractor_verb()
    local reasons = {
        "crushed",
        "destroyed",
        "flattened",
        "killed",
        "mangled",
        "minced",
        "ran over",
        "stomped"
    }
    return reasons[1 + math.floor(math.random() * #reasons)]
end

local function random_falling_terms()
    local reasons = {
        "fell from a high place and died",
        "apparently forgot how to fly",
        "failed the bird exam",
        "malfunctioned mid air",
        "got a wing cramp"
    }
    return reasons[1 + math.floor(math.random() * #reasons)]
end

local function random_starving_terms()
    local reasons = {
        "starved to death",
        "got too hungry"
    }
    return reasons[1 + math.floor(math.random() * #reasons)]
end

local function format_death_reason(death_reason)
    if death_reason == STARVED_TO_DEATH then
        return random_starving_terms()
    elseif death_reason == FELL_FROM_HIGH_PLACE then
        return random_falling_terms()
    elseif death_reason == EATEN_BY_FROG then
        return string.format("got %s by a frog", random_frog_verb())
    elseif death_reason == MANGLED_BY_TRACTOR then
        return string.format("got %s by a tractor", random_tractor_verb())
    else
        return "died"
    end
end

local function format_death_reason_hint(death_reason)
    if death_reason == STARVED_TO_DEATH then
        return string.format("FYI: You eat one wheat (%ical) every return to the nest.", KERNEL_CALORIE_WORTH)
    elseif death_reason == FELL_FROM_HIGH_PLACE then
        return ""
    elseif death_reason == EATEN_BY_FROG then
        return ""
    elseif death_reason == MANGLED_BY_TRACTOR then
        return ""
    else
        return ""
    end
end

local function setScore(source)
    Score.score = Score.collected * 13 + math.floor(Score.time * 1.13)
end

local function setDeathReason(source)
    Score.death_reason = format_death_reason(source)
    Score.hint = format_death_reason_hint(source)
end

local function killBird(source)
    Objects.bird.state.dead = true
    setDeathReason(source)
    Score.time = TimeAlive
    setScore()
end

function love.keypressed(key, scancode, isrepeat)
    if key == "escape" or key == "p" or key == "pause" or key == "f10" then
        if STATE == GAME_RUNNING then
            STATE = GAME_PAUSED
        elseif STATE == GAME_PAUSED then
            STATE = GAME_RUNNING
        end
    end

    -- TODO remove all these
    if key == "5" then
        killBird(MANGLED_BY_TRACTOR)
    end

    if key == "6" then
        killBird(STARVED_TO_DEATH)
    end

    if key == "7" then
        killBird(FELL_FROM_HIGH_PLACE)
    end

    if key == "8" then
        killBird(EATEN_BY_FROG)
    end

    if key == "9" then
        max_stalk_bend = max_stalk_bend * 1.1
        stalk_bend_speed = stalk_bend_speed * 1.1
    end

    if key == "0" then
        max_stalk_bend = DEFAULT_MAX_STALK_BEND
        stalk_bend_speed = DEFAULT_STALK_BEND_SPEED
    end

    if key == "unknown" then
        love.event.quit()
    end
end

local function newMenuText(text, font, textColor, updateFn)
    return {
        type = "text",
        text = text,
        font = font,
        textColor = textColor,
        updateFn = updateFn
    }
end

-- SkyVaultGames: https://www.youtube.com/watch?v=vMSjVuJ6wDs
local function newMenuButton(text, font, textColor, updateFn, buttonColor, fn)
    return {
        type = "button",
        text = text,
        font = font,
        textColor = textColor,
        updateFn = updateFn,
        buttonColor = buttonColor,
        fn = fn,
        pressed = false
    }
end

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
        s.angle = max_stalk_bend * math.sin(wheat.seed + CyclicTime * stalk_bend_speed)
        if #s.children > 1 then
            break
        end
        s = s.children[1]
    end
    return wheat
end

local function newWheat(x, y, baseColor, mutation)
    local seeds = {}
    local color = mutate_color(baseColor, mutation)
    local lr = math.random() > 0.5
    for i = 0, 7, 1 do
        local offset1 = lr and 3 or 1
        local offset2 = lr and 1 or 3
        table.insert(
            seeds,
            newBone(0, i * 6 - offset1, 3, 10, 0.3 + math.random() * 0.2, mutate_color(color, mutation), {})
        )
        table.insert(
            seeds,
            newBone(0, i * 6 - offset2, 3, 10, -0.3 - math.random() * 0.2, mutate_color(color, mutation), {})
        )
    end
    table.insert(seeds, newBone(0, 7 * 6 + 3, 3, 10, 0, mutate_color(color, mutation), {}))

    local bend = math.pi * 1 - 0.1 + math.random() * 0.2
    local random_height = math.random() * 30
    local stalk3 = newBone(0, 0, 2, 30 + random_height, 0, color, seeds)
    local stalk2 = newBone(0, 0, 2, 30 + random_height, 0, color, {stalk3})
    local stalk1 = newBone(0, 0, 2, 30 + random_height, 0, color, {stalk2})

    local seed = math.random() * math.pi
    local wheat = {type = "wheat", x = x, y = y, skeleton = stalk1, bend = bend, seed = seed}
    return updateWheat(wheat)
end

local function addWheat(list, color, mut)
    local n = 274
    local spacing = 5
    for i = 0, n, 1 do
        table.insert(list, newWheat(-(spacing * n / 2) + (i * spacing) - 2 + math.random() * 4, 0, color, mut))
    end
end

local function destroyWorld()
    max_stalk_bend = DEFAULT_MAX_STALK_BEND
    stalk_bend_speed = DEFAULT_STALK_BEND_SPEED
    World = {}
    Objects = {}
    Score = {collected = 0, time = 0, score = 0, death_reason = nil}
    BackgroundProps = {}
    Props = {}
end

local function createKernel()
    local object = {}
    local create_area_width = 1366
    local x = (-create_area_width / 2) + create_area_width * math.random()
    local y = -130
    -- object.body = love.physics.newBody(World, 50, -400, "dynamic")
    object.body = love.physics.newBody(World, x, y, "dynamic")
    object.shape = love.physics.newRectangleShape(3, 8)
    object.fixture = love.physics.newFixture(object.body, object.shape)
    object.fixture:setCategory(CATEGORY_KERNEL)
    object.color = mutate_color(WHEAT_COLOR, 0.2)
    object.body:setMass(DEFAULT_KERNEL_MASS)
    object.body:applyAngularImpulse(300)
    return object
end

local function createStatic(x, y, width, height, secondCat)
    local object = {}
    object.body = love.physics.newBody(World, x, y)
    object.shape = love.physics.newRectangleShape(width, height)
    object.fixture = love.physics.newFixture(object.body, object.shape)
    object.fixture:setFriction(DEFAULT_FRICTION)
    object.fixture:setCategory(CATEGORY_STATIC)
    return object
end

local function createNest(x, y)
    Objects.nest_surface = createStatic(x, y - 4, 38, 2)
    Objects.nest = createStatic(x, y + 2, 50, 10)
    Objects.nest_basement = createStatic(x, y + 8, 30, 4)
end

local function createWorldBounds()
    Objects.ground = createStatic(0, 20, 5000, 40)
    Objects.left_wall = createStatic(-(1920 / 2) - 100, 0, 40, 5000)
    Objects.left_wall = createStatic((1920 / 2) + 100, 0, 40, 5000)
end

local function createBird()
    local bird_size = 10
    Objects.bird = {}
    Objects.bird.body = love.physics.newBody(World, -275, -516, "dynamic")
    Objects.bird.shape = love.physics.newCircleShape(bird_size)
    Objects.bird.fixture = love.physics.newFixture(Objects.bird.body, Objects.bird.shape)
    Objects.bird.fixture:setFriction(DEFAULT_FRICTION)
    Objects.bird.fixture:setCategory(CATEGORY_BIRD)
    Objects.bird.body:setMassData(0, 0, DEFAULT_BIRD_MASS, DEFAULT_BIRD_INERTIA)
    Objects.bird.state = {
        facing_left = false,
        flapping = false,
        on_ground = false,
        dead = false,
        controls = {up = false, down = false, left = false, right = false, rise = false},
        carrying = 0,
        calories = 60,
        expended_calories = 0
    }
end

local function leaveKernelsInNest()
    if Objects.bird.state.carrying > 0 then
        Objects.bird.state.calories = Objects.bird.state.calories + KERNEL_CALORIE_WORTH
        Score.collected = Score.collected + Objects.bird.state.carrying - 1
        Objects.bird.state.carrying = 0
        -- XXX This is ugly, but I don't know really how to do this correctly
        -- as we are not allowed to modify physics while in world callbacks
        -- Should we emit some event instead? Is there built in utilities for that? No idea
        Objects.bird.should_reset_mass = true
    end
end

local function pickingUpKernel(kernel)
    local kernelMass = kernel.body:getMass()
    local birdMass = Objects.bird.body:getMass()
    Objects.bird.state.carrying = Objects.bird.state.carrying + 1

    -- XXX this is ugly but must work for now
    if Objects.bird.extra_mass == nil then
        Objects.bird.extra_mass = {}
    end
    table.insert(Objects.bird.extra_mass, kernelMass)
end

-- https://love2d.org/wiki/Tutorial:Physics
local function initGameWorld()
    destroyWorld()
    TimeAlive = 0
    KernelTimer = 0

    World = love.physics.newWorld(0, 981, true)

    createNest(-270, -500)
    createWorldBounds()
    createBird()

    local function beginContact(a, b, coll)
        local aCat = a:getCategory()
        local bCat = b:getCategory()
        if aCat == CATEGORY_STATIC and bCat == CATEGORY_BIRD then
            print("Bird on ground!")
            Objects.bird.state.on_ground = true
            local vx, vy = Objects.bird.body:getLinearVelocity()
            if math.abs(vy) > 850 then
                killBird(FELL_FROM_HIGH_PLACE)
            end
        end
        if bCat == CATEGORY_BIRD and a == Objects.nest_surface.fixture then
            print("Landed on nest surface")
            leaveKernelsInNest()
        end

        if aCat == CATEGORY_KERNEL and bCat == CATEGORY_BIRD then
            print("Picking up a kernel")

            local picked_kernel_index = nil
            local picked_kernel = nil
            for i, kernel in ipairs(Objects.kernels) do
                if kernel.fixture == a then
                    picked_kernel_index = i
                    picked_kernel = kernel
                end
            end
            if picked_kernel then
                pickingUpKernel(picked_kernel)
                picked_kernel.body:destroy()
                picked_kernel.fixture:destroy()
                table.remove(Objects.kernels, picked_kernel_index)
            end
        end
    end

    local function endContact(a, b, coll)
        local aCat = a:getCategory()
        local bCat = b:getCategory()
        if aCat == CATEGORY_STATIC and bCat == CATEGORY_BIRD then
            print("Bird take off!")
            Objects.bird.state.on_ground = false
        end
    end

    World:setCallbacks(beginContact, endContact)

    addWheat(BackgroundProps, darken_color(WHEAT_COLOR), 0)
    addWheat(Props, WHEAT_COLOR, 0.1)
end

local MainMenuProps = {}
local main_menu = {}
local pause_menu = {}
local game_over_menu = {}

function love.load()
    addWheat(MainMenuProps, darken_color(WHEAT_COLOR), 0)
    addWheat(MainMenuProps, WHEAT_COLOR, 0.1)

    FontMini = love.graphics.newFont(12)
    FontSmall = love.graphics.newFont(24)
    FontLarge = love.graphics.newFont(32)
    love.physics.setMeter(100)

    table.insert(main_menu, newMenuText("Wheat", FontLarge, WHITE, nil))
    table.insert(main_menu, newMenuText("A game about collecting wheat", FontSmall, WHITE, nil))
    table.insert(
        main_menu,
        newMenuButton(
            "Play",
            FontSmall,
            WHITE,
            nil,
            BROWN_GRAY,
            function()
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
            nil,
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
            nil,
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
            nil,
            BROWN_GRAY,
            function()
                STATE = GAME_RUNNING
            end
        )
    )

    table.insert(game_over_menu, newMenuText("Game Over", FontLarge, WHITE, nil))
    local deathReason = newMenuText("You died", FontSmall, WHITE, nil)
    deathReason.updateFn = function()
        deathReason.text = string.format("You %s", Score.death_reason)
    end
    table.insert(game_over_menu, deathReason)

    local collectedScore = newMenuText("Collected: -", FontSmall, WHITE, nil)
    collectedScore.updateFn = function()
        collectedScore.text = string.format("Collected: %i", Score.collected)
    end
    table.insert(game_over_menu, collectedScore)
    local survivedScore = newMenuText("Survived: - s", FontSmall, WHITE, nil)
    survivedScore.updateFn = function()
        survivedScore.text = string.format("Survived: %i s", math.floor(Score.time))
    end
    table.insert(game_over_menu, survivedScore)
    local totalScore = newMenuText("Score: -", FontSmall, WHITE, nil)
    totalScore.updateFn = function()
        totalScore.text = string.format("Score: %i", math.floor(Score.score))
    end
    table.insert(game_over_menu, totalScore)
    local shareScoreButton = newMenuButton("Copy to clipboard", FontSmall, WHITE, nil, BROWN_GRAY)
    shareScoreButton.fn = function()
        love.system.setClipboardText(
            string.format(
                "I collected %i wheat, survived for %i seconds, and then I %s, for a total score of %i!",
                math.floor(Score.collected),
                math.floor(Score.time),
                Score.death_reason,
                math.floor(Score.score)
            )
        )
        shareScoreButton.text = "Copied to clipboard!"
    end
    table.insert(game_over_menu, shareScoreButton)

    local deathReasonHint = newMenuText("", FontSmall, WHITE, nil)
    deathReasonHint.updateFn = function()
        deathReasonHint.text = Score.hint
    end
    table.insert(game_over_menu, deathReasonHint)
    table.insert(
        game_over_menu,
        newMenuButton(
            "Main Menu",
            FontSmall,
            WHITE,
            nil,
            BROWN_GRAY,
            function()
                STATE = MAIN_MENU
            end
        )
    )
    print("Loaded")
end

local function updateProp(prop, dt)
    if prop.type == "wheat" then
        updateWheat(prop)
    end
end

local function updateMain(dt)
    for _, prop in ipairs(MainMenuProps) do
        updateProp(prop, dt)
    end
end

local function updateBird(bird, dt)
    if bird.should_reset_mass then
        bird.body:setMass(DEFAULT_BIRD_MASS)
        bird.should_reset_mass = false
    end
    if bird.extra_mass ~= nil and #bird.extra_mass > 0 then
        local sum = 0
        for _, v in ipairs(bird.extra_mass) do
            sum = sum + v
        end
        bird.body:setMass(bird.body:getMass() + sum)
        bird.extra_mass = {}
    end

    local up = bird.state.controls.up
    local down = bird.state.controls.down
    local left = bird.state.controls.left
    local right = bird.state.controls.right
    local rise = bird.state.controls.rise

    local FLY_Y_FORCE = 5400
    local FLY_X_FORCE = 2100

    local FLY_X_INERTIA = 600

    local JUMP_Y_IMPULSE = 8
    local JUMP_X_IMPULSE = 2

    local xv, yv = bird.body:getLinearVelocity()
    if up then
        bird.state.flapping = true
        if rise then
            if yv > -300 then
                bird.body:applyForce(0, -FLY_Y_FORCE * dt)
            end
        elseif bird.state.on_ground then
            -- do nothing, we be perching
        elseif down then
            if yv > 200 then
                bird.body:applyForce(0, -FLY_Y_FORCE * dt)
            end
        elseif yv > 0 then
            bird.body:applyForce(0, -FLY_Y_FORCE * dt)
        end
    else
        bird.state.flapping = false
    end

    if right then
        if bird.state.flapping and xv < 300 then
            bird.body:applyForce(FLY_X_FORCE * dt, 0)
        end
        bird.state.facing_left = false
    else
        if bird.state.flapping and xv < -10 then
            bird.body:applyForce(FLY_X_INERTIA * dt, 0)
        end
    end

    if left then
        if bird.state.flapping and xv > -300 then
            bird.body:applyForce(-FLY_X_FORCE * dt, 0)
        end
        bird.state.facing_left = true
    else
        if bird.state.flapping and xv > 10 then
            bird.body:applyForce(-FLY_X_INERTIA * dt, 0)
        end
    end

    if bird.state.on_ground and rise then
        if bird.state.flapping then
            bird.body:applyLinearImpulse(0, -JUMP_Y_IMPULSE)
        elseif bird.state.facing_left then
            bird.body:applyLinearImpulse(-JUMP_X_IMPULSE, -JUMP_Y_IMPULSE)
        else
            bird.body:applyLinearImpulse(JUMP_X_IMPULSE, -JUMP_Y_IMPULSE)
        end
        bird.state.expended_calories = bird.state.expended_calories - 0.1
        bird.state.on_ground = false
    end

    if not bird.state.dead then
        if bird.state.controls.up then
            if bird.state.controls.rise then
                bird.state.expended_calories = bird.state.expended_calories - (dt * 2)
            elseif bird.state.controls.down then
                bird.state.expended_calories = bird.state.expended_calories - (dt / 2)
            else
                bird.state.expended_calories = bird.state.expended_calories - dt
            end
        end

        bird.state.expended_calories = bird.state.expended_calories - dt
        if (bird.state.calories + bird.state.expended_calories) < 0 then
            killBird(STARVED_TO_DEATH)
        end
    end
end

local function updateBirdControlsFromPlayerInput(bird)
    if bird.state.dead then
        bird.state.controls.up = false
        bird.state.controls.left = false
        bird.state.controls.down = false
        bird.state.controls.right = false
        bird.state.controls.rise = false
    else
        -- bird.state.controls.up = love.keyboard.isDown("space") or love.keyboard.isDown("lshift")
        -- bird.state.controls.rise = love.keyboard.isDown("w") or love.keyboard.isDown("k")
        bird.state.controls.left = love.keyboard.isDown("a") or love.keyboard.isDown("h")
        bird.state.controls.down =
            love.keyboard.isDown("s") or love.keyboard.isDown("j") or love.keyboard.isDown("lctrl") or
            love.keyboard.isDown("rctrl")
        bird.state.controls.right = love.keyboard.isDown("d") or love.keyboard.isDown("l")

        bird.state.controls.up = love.keyboard.isDown("w") or love.keyboard.isDown("k")
        bird.state.controls.rise = love.keyboard.isDown("space") or love.keyboard.isDown("lshift")
    end
end

local function updateMenu(menu)
    for _, item in ipairs(menu) do
        if item.updateFn then
            item.updateFn()
        end
    end
end

local function updateGame(dt)
    World:update(dt)

    if Objects.kernels == nil then
        Objects.kernels = {}
    end
    if KernelTimer > KERNEL_TIMER_COOLDOWN then
        KernelTimer = KernelTimer - KERNEL_TIMER_COOLDOWN
        if #Objects.kernels < 20 then
            table.insert(Objects.kernels, createKernel())
        end
    end

    updateBirdControlsFromPlayerInput(Objects.bird)
    updateBird(Objects.bird, dt)

    for _, prop in ipairs(BackgroundProps) do
        updateProp(prop, dt)
    end

    for _, prop in ipairs(Props) do
        updateProp(prop, dt)
    end

    if STATE == GAME_RUNNING and Objects.bird.state.dead then
        STATE = GAME_OVER
        updateMenu(game_over_menu)
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

    TimeAlive = TimeAlive + dt
    KernelTimer = KernelTimer + dt

    if STATE == GAME_RUNNING or STATE == GAME_OVER then
        updateGame(dt)
    end

    if STATE == MAIN_MENU then
        updateMain(dt)
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
    local button_width = 300
    local text_width = 600
    for i, menu_item in ipairs(menu) do
        local x = (window_width / 2) - (button_width / 2)
        local y = (window_height / 2) - (menu_height / 2) + ((i - 1) * item_height_with_spacing)

        if menu_item.type == "button" then
            local mouseX, mouseY = love.mouse.getPosition()
            local highlighted =
                mouseX >= x and mouseX <= (x + button_width) and mouseY >= y and mouseY <= (y + item_height)

            if highlighted then
                love.graphics.setColor(unpack(highlight_color(menu_item.buttonColor)))
            else
                love.graphics.setColor(unpack(menu_item.buttonColor))
            end
            love.graphics.rectangle("fill", x, y, button_width, item_height)

            if highlighted and not menu_item.pressed and love.mouse.isDown(1) then
                menu_item.fn()
            end
            menu_item.pressed = love.mouse.isDown(1)
        end

        love.graphics.setColor(unpack(menu_item.textColor))
        local text_height = menu_item.font:getHeight(menu_item.text)
        local text_x = (window_width / 2) - (text_width / 2)
        love.graphics.printf(
            menu_item.text,
            menu_item.font,
            math.floor(text_x),
            math.floor(y + (item_height / 2) - (text_height / 2)),
            text_width,
            "center"
        )
    end
end

-- https://love2d.org/wiki/love.graphics.rectangle
local function drawBone(bone)
    love.graphics.push()
    love.graphics.translate(bone.x, bone.y)
    love.graphics.rotate(bone.angle)
    love.graphics.setColor(unpack(bone.color))
    love.graphics.rectangle("fill", -bone.width / 2, 0, bone.width, bone.height) -- origin in the middle bottom
    -- love.graphics.rectangle("fill", 0, 0, bone.width, bone.height) -- origin in the top left corner
    -- love.graphics.rectangle("fill", -bone.width / 2, -bone.height / 2, bone.width, bone.height) -- origin in the middle
    love.graphics.translate(0, bone.height)
    for _, childBone in ipairs(bone.children) do
        drawBone(childBone)
    end
    love.graphics.pop()
end

local function drawBird(bird, x, y)
    love.graphics.push()
    love.graphics.translate(x, y)

    if not bird.dead and bird.carrying > 0 then
        love.graphics.setColor(unpack(WHEAT_COLOR))
        love.graphics.printf(tostring(bird.carrying), FontMini, -25, -25, 50, "center")
    end

    if bird.facing_left then
        love.graphics.scale(-1, 1)
    end

    love.graphics.setColor(unpack(LIGHT_BLUE))
    love.graphics.rectangle("fill", -10, -10, 20, 20)

    love.graphics.setColor(unpack(LIGHT_BLUE))
    love.graphics.rectangle("fill", -15, 0, 9, 8)

    love.graphics.setColor(unpack(ORANGE))
    love.graphics.rectangle("fill", 4, 0, 9, 5)

    if bird.dead then
        -- love.graphics.rectangle("fill", 3, -6, 3, 3)
        -- love.graphics.rectangle("fill", -1, -2, 3, 3)
        -- love.graphics.rectangle("fill", 1, -4, 3, 3)
        -- love.graphics.rectangle("fill", 3, -2, 3, 3)
        -- love.graphics.rectangle("fill", -1, -6, 3, 3)
        love.graphics.setColor(unpack(RED))
    else
        love.graphics.setColor(unpack(BLACK))
    end
    love.graphics.rectangle("fill", 1, -4, 3, 3)

    love.graphics.setColor(unpack(DARK_GRAY))
    love.graphics.rectangle("fill", -4, 9, 3, 3)
    love.graphics.rectangle("fill", 0, 9, 3, 3)

    local flipper = math.sin(CyclicTime * 100)

    love.graphics.setColor(unpack(highlight_color(LIGHT_BLUE)))
    if bird.flapping and flipper > 0 then
        love.graphics.rectangle("fill", -8, 5, 8, 8)
    else
        love.graphics.rectangle("fill", -8, 0, 8, 8)
    end

    love.graphics.pop()
end

local function drawWheat(w)
    love.graphics.push()
    love.graphics.translate(w.x, w.y)
    love.graphics.rotate(w.bend)
    drawBone(w.skeleton)
    love.graphics.pop()
end

local function drawProps(props)
    local window_width = love.graphics.getWidth()
    local window_height = love.graphics.getHeight()
    love.graphics.push()
    love.graphics.translate(window_width / 2, window_height)

    for _, prop in ipairs(props) do
        if prop.type == "wheat" then
            drawWheat(prop)
        end
    end
    love.graphics.pop()
end

local function drawMainMenuWorld()
    drawProps(MainMenuProps)
end

local function drawNest()
    love.graphics.setColor(unpack(highlight_color(BROWN_GRAY)))
    love.graphics.polygon("fill", Objects.nest_surface.body:getWorldPoints(Objects.nest_surface.shape:getPoints()))
    love.graphics.setColor(unpack(BROWN_GRAY))
    love.graphics.polygon("fill", Objects.nest.body:getWorldPoints(Objects.nest.shape:getPoints()))
    love.graphics.setColor(unpack(BROWN_GRAY))
    love.graphics.polygon("fill", Objects.nest_basement.body:getWorldPoints(Objects.nest_basement.shape:getPoints()))

    local x1, y1 = Objects.nest_surface.body:getPosition()
    if Score.collected > 0 then
        love.graphics.setColor(unpack(WHEAT_COLOR))
        love.graphics.printf(tostring(Score.collected), FontMini, x1 - 100 - 30, y1 - 5, 100, "right")
    end

    local caloriesInSystem = Objects.bird.state.calories + Objects.bird.state.expended_calories
    if not Objects.bird.state.dead and caloriesInSystem < 30 then
        love.graphics.setColor(unpack(RED))
        love.graphics.printf(
            string.format("You have %s calories left", math.floor(caloriesInSystem + 1)),
            FontMini,
            x1 - 100 + 50,
            y1 + 20,
            100,
            "center"
        )
    end
end

local function drawObjects()
    local window_width = love.graphics.getWidth()
    local window_height = love.graphics.getHeight()
    love.graphics.push()
    love.graphics.translate(window_width / 2, window_height)

    drawNest()

    love.graphics.setColor(unpack(BROWN_GRAY))
    love.graphics.polygon("fill", Objects.ground.body:getWorldPoints(Objects.ground.shape:getPoints()))

    -- love.graphics.setColor(unpack(BROWN_GRAY))
    -- love.graphics.polygon("fill", Objects.left_wall.body:getWorldPoints(Objects.left_wall.shape:getPoints()))

    -- love.graphics.setColor(unpack(BROWN_GRAY))
    -- love.graphics.polygon("fill", Objects.right_wall.body:getWorldPoints(Objects.right_wall.shape:getPoints()))

    drawBird(Objects.bird.state, Objects.bird.body:getPosition())

    if Objects.kernels then
        for _, kernel in ipairs(Objects.kernels) do
            love.graphics.setColor(unpack(kernel.color))
            love.graphics.polygon("fill", kernel.body:getWorldPoints(kernel.shape:getPoints()))
        end
    end

    love.graphics.pop()
end

local function drawGameWorld()
    drawProps(BackgroundProps)
    drawObjects()
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
        drawWindowTint()
        drawMenu(game_over_menu)
    end
end
