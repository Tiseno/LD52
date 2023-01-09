local love = require("love")

local MAIN_MENU = "MAIN_MENU"
local GAME_INIT = "GAME_INIT"
local GAME_RUNNING = "GAME_RUNNING"
local GAME_PAUSED = "GAME_PAUSED"
local GAME_OVER = "GAME_OVER"

local STATE = MAIN_MENU

-- https://colorpicker.me
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

local function mutate_color_additive(color, factor)
    return {
        math.min(color[1] + math.random() * factor, 1),
        math.min(color[2] + math.random() * factor, 1),
        math.min(color[3] + math.random() * factor, 1)
    }
end

local function rand(min, max)
    return min + math.random() * (max - min)
end

local function mutate_color_range(color, min, max)
    return {
        math.min(color[1] + rand(min, max), 1),
        math.min(color[2] + rand(min, max), 1),
        math.min(color[3] + rand(min, max), 1)
    }
end

local function merge_max_color(color1, color2)
    return {
        math.max(color1[1], color2[1]),
        math.max(color1[2], color2[2]),
        math.max(color1[3], color2[3])
    }
end

-- The color used by the US National Association of Wheat Growers: https://wheatworld.org/wheat-101/wheat-facts/
local WHEAT_COLOR = rgb(179, 136, 7)

local WHEAT_WILT_COLOR = rgb(179 * 3 / 4, 136 * 3 / 4, 7 * 3 / 4)
local WHEAT_WILT_COLOR_BACKGROUND = rgb(179 / 3, 136 / 3, 7 / 3)

local LIGHT_BLUE = {0.5, 0.7, 0.9}
local ORANGE = rgb(255, 128, 61)
local BROWN_GRAY = rgb(78, 79, 49)

local WHITE = {1, 1, 1}
local BLACK = {0, 0, 0}
local DARK_GRAY = {0.2, 0.2, 0.2}
local RED = {1, 0, 0}
local GREEN = {0, 1, 0}
local BLUE = {0, 0, 1}

Time = 0
CyclicTime = 0
TimeAlive = 0
TimeSpentInNest = 0
KernelTimer = 0
KERNEL_TIMER_COOLDOWN = 0.1

local DEFAULT_MAX_STALK_BEND = 0.05
local DEFAULT_STALK_BEND_SPEED = 1
local max_stalk_bend = DEFAULT_MAX_STALK_BEND
local stalk_bend_speed = DEFAULT_STALK_BEND_SPEED

local World = {}
local Objects = {}
local CreatedFrogs = 0
local Score = {collected = 0, time = 0, score = 0, death_reason = nil}
local BackgroundProps = {}
local Props = {}
local ToggleProps = true

local STARVED_TO_DEATH = 0
local EATEN_BY_FROG = 1
local MANGLED_BY_TRACTOR = 2
local FELL_FROM_HIGH_PLACE = 3

local KERNEL_CALORIE_WORTH = 15

local CATEGORY_DEFAULT = 1
local CATEGORY_STATIC = 2
local CATEGORY_BIRD = 3
local CATEGORY_KERNEL = 4
local CATEGORY_FROG = 5
local CATEGORY_TONGUE = 6

local NEST_X = -270
local NEST_Y = -516

local DEFAULT_BIRD_MASS = 0.03
local DEFAULT_INERTIA = 1000000000000000
local DEFAULT_KERNEL_MASS = 0.001

local BIRD_CARRY_PENALTY_START = 40
local BIRD_CARRY_PENALTY_MAX = 50

local BIRD_CARRY_PENALTY_DOUBLE_START = 50
local BIRD_CARRY_PENALTY_DOUBLE_MAX = 60

local SHOW_CALORIES_THRESHHOLD = 50
local SHOW_CALORIES_WARNING_THRESHHOLD = 40
local SHOW_CALORIES_CRITICAL_THRESHHOLD = 20

local DEFAULT_FRICTION = 0.9

local FROG_ATTACK_INTERVAL = 5
local FROG_ATTACK_COOLDOWN = 4

local FROG_INSANE_ATTACK_INTERVAL = 3
local FROG_INSANE_ATTACK_COOLDOWN = 2

local FROG_ATTACK_ANIMATION_TIME = 0.5

local function random_frog_verb()
    local reasons = {
        -- "smacked",
        --"assassinated",
        -- "whipped",
        "consumed",
        "crushed",
        "destroyed",
        "devoured",
        "eaten",
        "killed",
        "licked",
        "mangled",
        "owned",
        "sent to the shadow realm",
        "wasted"
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
        "apparently forgot how to fly",
        "failed the bird exam",
        "fell from a high place and died",
        "got a wing cramp",
        "hit the ground too hard",
        "malfunctioned mid air"
    }
    return reasons[1 + math.floor(math.random() * #reasons)]
end

local function random_starving_terms()
    local reasons = {
        "starved to death"
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
        return string.format(
            "Every time a bird returns to its nest, it eats some of its new harvest.",
            KERNEL_CALORIE_WORTH
        )
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

local sounds = {}

local function killBird(source)
    sounds.collision:play()
    Objects.bird.state.dead = true
    setDeathReason(source)
    Score.time = TimeAlive - TimeSpentInNest
    setScore()
end

local function turnAllFrogsEvil()
    for _, frog in ipairs(Objects.frogs) do
        if not frog.evil then
            frog.evil = true
            frog.croak()
        end
    end
end

local function turnAllFrogsInsane()
    for _, frog in ipairs(Objects.frogs) do
        if not frog.insane then
            frog.insane = true
        end
    end
end

local function activateAllFrogs()
    for _, frog in ipairs(Objects.frogs) do
        if not frog.active then
            frog.active = true
        end
    end
end

local function createTongueSegment(x, y, size)
    local object = {}
    object.body = love.physics.newBody(World, x, y, "dynamic")
    object.shape = love.physics.newCircleShape(size)
    object.fixture = love.physics.newFixture(object.body, object.shape)
    object.body:setMass(size * 0.0003)
    object.fixture:setFriction(1) -- tongues are sticky
    object.fixture:setCategory(CATEGORY_TONGUE)
    object.fixture:setMask(CATEGORY_FROG, CATEGORY_TONGUE)
    object.radius = size
    return object
end

local function createTongue(x, y, dx, dy, size, n)
    if Objects.tongues == nil then
        Objects.tongues = {}
    end

    local first = createTongueSegment(x, y, size)
    table.insert(Objects.tongues, first)

    local c = first
    local cx, cy = x, y
    for i = 1, n, 1 do
        local nx, ny = cx + dx, cy + dy
        local n = createTongueSegment(nx, ny, size)
        c.next = n
        table.insert(Objects.tongues, n)
        love.physics.newRopeJoint(c.body, n.body, cx, cy, nx, ny, size, false)
        c = n
        cx, cy = nx, ny
    end

    return first
end

function love.keypressed(key, scancode, isrepeat)
    if key == "escape" or key == "p" or key == "pause" or key == "f10" then
        if STATE == GAME_RUNNING then
            STATE = GAME_PAUSED
        elseif STATE == GAME_PAUSED then
            STATE = GAME_RUNNING
        end
    end

    if key == "9" then
        max_stalk_bend = max_stalk_bend * 1.1
        stalk_bend_speed = stalk_bend_speed * 1.1
    end

    if key == "0" then
        max_stalk_bend = DEFAULT_MAX_STALK_BEND
        stalk_bend_speed = DEFAULT_STALK_BEND_SPEED
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

local function updateWheat(wheat, disco)
    local s = wheat.skeleton
    while true do
        s.angle = max_stalk_bend * math.sin(wheat.seed + CyclicTime * stalk_bend_speed)
        local MUTATION_MIN = -0.01
        local MUTATION_MAX = 0.01
        if disco then
            s.color = mutate_color_range(s.color, MUTATION_MIN, MUTATION_MAX)
        end
        if #s.children > 1 then
            if disco then
                for _, kernel in ipairs(s.children) do
                    kernel.color = mutate_color_range(kernel.color, MUTATION_MIN, MUTATION_MAX)
                end
            end
            break
        end
        s = s.children[1]
    end

    return wheat
end

local function newWheat(x, y, baseColor, mutation)
    local seeds = {}
    local color = mutate_color_additive(baseColor, mutation)
    local lr = math.random() > 0.5
    for i = 0, 7, 1 do
        local offset1 = lr and 3 or 1
        local offset2 = lr and 1 or 3
        table.insert(
            seeds,
            newBone(0, i * 6 - offset1, 3, 10, 0.3 + math.random() * 0.2, mutate_color_additive(color, mutation), {})
        )
        table.insert(
            seeds,
            newBone(0, i * 6 - offset2, 3, 10, -0.3 - math.random() * 0.2, mutate_color_additive(color, mutation), {})
        )
    end
    table.insert(seeds, newBone(0, 7 * 6 + 3, 3, 10, 0, mutate_color_additive(color, mutation), {}))

    local bend = math.pi * 1 - 0.1 + math.random() * 0.2
    local random_height = math.random() * 30
    local stalk3 = newBone(0, 0, 2, 30 + random_height, 0, color, seeds)
    local stalk2 = newBone(0, 0, 2, 30 + random_height, 0, color, {stalk3})
    local stalk1 = newBone(0, 0, 2, 30 + random_height, 0, color, {stalk2})

    local seed = math.random() * math.pi
    local wheat = {type = "wheat", x = x, y = y, skeleton = stalk1, bend = bend, seed = seed}
    return updateWheat(wheat, false)
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
    ToggleProps = true
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
    object.color = mutate_color_additive(WHEAT_COLOR, 0.2)
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

local function createBird(x, y)
    local bird_size = 10
    Objects.bird = {}
    Objects.bird.body = love.physics.newBody(World, x, y - (bird_size / 2), "dynamic")
    Objects.bird.shape = love.physics.newCircleShape(bird_size)
    Objects.bird.fixture = love.physics.newFixture(Objects.bird.body, Objects.bird.shape)
    Objects.bird.fixture:setFriction(0.2)
    Objects.bird.fixture:setCategory(CATEGORY_BIRD)
    Objects.bird.body:setMassData(0, 0, DEFAULT_BIRD_MASS, DEFAULT_INERTIA)
    Objects.bird.state = {
        facing_left = false,
        flapping = false,
        on_ground = false,
        in_nest = false,
        dead = false,
        controls = {up = false, down = false, left = false, right = false, rise = false},
        carrying = 0,
        calories = 55,
        expended_calories = 0,
        sticky_stuff = {},
        is_stuck = false,
        stuck_timer = 0
    }
end

local function createFrog(x, y, scale)
    if scale == nil then
        scale = 1
    end
    local object = {}
    object.base_width = (40) * scale + (60) * scale * math.random()
    object.base_height = (10) * scale + math.random() * (20) * scale

    object.body_width = math.min((30) * scale + (30) * scale * math.random(), object.base_width - (10) * scale)
    object.body_height = (5) * scale + math.random() * (20) * scale

    object.eye_spacing = (20) * scale + math.random() * (object.body_width - (10)) * scale

    object.stalk_width = (5) * scale + math.random() * (5) * scale
    object.stalk_height = (30) * scale * math.random()

    object.eye_socket_width = (object.stalk_width * (3)) + (5) * scale * math.random()
    object.eye_socket_height = object.eye_socket_width

    object.eye_ball_width = object.eye_socket_width - (5) * scale
    object.eye_ball_height = object.eye_socket_height - (5) * scale

    -- object.width = math.max(object.eye_spacing + (object.eye_socket_width / 2), object.base_width, object.body_width)
    -- object.height = object.base_height + object.stalk_height + object.eye_socket_height
    -- object.strength = object.width + object.height

    object.pitch = math.max(1 - (scale) / 2 + math.random() * 0.3, 0.5)
    object.croak = function()
        sounds.croak:setPitch(object.pitch)
        sounds.croak:play()
    end

    object.evil = false
    object.timer = math.random()
    object.attack_cooldown = math.random() * FROG_ATTACK_COOLDOWN
    object.attacking = false
    object.attacking_timer = 0

    object.body = love.physics.newBody(World, x, y, "dynamic")

    -- object.shape = love.physics.newRectangleShape(object.width, object.height)
    -- local hw = object.width / 2
    -- local hh = object.height / 2
    object.shape =
        love.physics.newPolygonShape(
        -object.base_width / 2,
        0,
        -object.base_width / 2,
        -object.base_height,
        0,
        -object.base_height - object.body_height,
        object.base_width / 2,
        -object.base_height,
        object.base_width / 2,
        0
    )

    object.fixture = love.physics.newFixture(object.body, object.shape)
    object.fixture:setFriction(0.2)
    object.fixture:setCategory(CATEGORY_FROG)

    local calculatedMass = object.body:getMass()
    object.body:setMassData(0, 0, calculatedMass, DEFAULT_INERTIA)

    object.tongue = createTongue(x, y - object.base_height, 0, 0, (8) * scale, 8 + math.floor(math.random() * 20))
    love.physics.newWeldJoint(object.body, object.tongue.body, x, y - object.base_height, false)

    return object
end

local function leaveKernelsInNest()
    if Objects.bird.state.carrying > 0 then
        sounds.tick:play()
        Objects.bird.state.calories = Objects.bird.state.calories + KERNEL_CALORIE_WORTH
        Score.collected = Score.collected + Objects.bird.state.carrying
        Objects.bird.state.carrying = 0
        -- XXX This is ugly, but I don't know really how to do this correctly
        -- as we are not allowed to modify physics while in world callbacks
        -- Should we emit some event instead? Is there built in utilities for that? No idea
        Objects.bird.should_reset_mass = true
    end
end

local function pickingUpKernel(kernel)
    sounds.tick:play()
    local kernelMass = kernel.body:getMass()
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
    Time = 0
    TimeAlive = 0
    TimeSpentInNest = 0
    KernelTimer = 0

    World = love.physics.newWorld(0, 981, true)

    createNest(NEST_X, NEST_Y)
    createBird(NEST_X, NEST_Y - 10)

    createWorldBounds()

    Objects.frogs = {}

    local function beginContact(a, b, coll)
        local aCat = a:getCategory()
        local bCat = b:getCategory()
        if (aCat == CATEGORY_STATIC or aCat == CATEGORY_FROG) and bCat == CATEGORY_BIRD then
            Objects.bird.state.on_ground = true
            local vx, vy = Objects.bird.body:getLinearVelocity()
            if math.abs(vy) > 850 then
                killBird(FELL_FROM_HIGH_PLACE)
            end
        end

        if (aCat == CATEGORY_STATIC or aCat == CATEGORY_KERNEL or aCat == CATEGORY_FROG) and bCat == CATEGORY_FROG then
            for _, frog in ipairs(Objects.frogs) do
                if b == frog.fixture then
                    frog.on_ground = true
                end
            end
        end

        if bCat == CATEGORY_BIRD and a == Objects.nest_surface.fixture then
            Objects.bird.state.in_nest = true
            leaveKernelsInNest()
        end

        if aCat == CATEGORY_KERNEL and bCat == CATEGORY_BIRD then
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

        if aCat == CATEGORY_BIRD and bCat == CATEGORY_TONGUE then
            for i, tongueSegment in ipairs(Objects.tongues) do
                if tongueSegment.fixture == b then
                    table.insert(Objects.bird.state.sticky_stuff, tongueSegment)
                end
            end
        end
    end

    local function endContact(a, b, coll)
        local aCat = a:getCategory()
        local bCat = b:getCategory()
        if aCat == CATEGORY_STATIC and bCat == CATEGORY_BIRD then
            Objects.bird.state.on_ground = false
        end

        if bCat == CATEGORY_BIRD and a == Objects.nest_surface.fixture then
            Objects.bird.state.in_nest = false
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
    math.randomseed(os.time())

    sounds.croak = love.audio.newSource("croak.wav", "static")
    sounds.croak:setVolume(0.2)

    sounds.tick = love.audio.newSource("tick.wav", "static")
    sounds.tick:setVolume(5)

    sounds.small_swosh = love.audio.newSource("small_swosh.wav", "static")
    sounds.small_swosh:setVolume(0.15)
    sounds.smaller_swosh = love.audio.newSource("small_swosh.wav", "static")
    sounds.smaller_swosh:setVolume(0.10)

    sounds.collision = love.audio.newSource("collision.wav", "static")
    sounds.collision:setVolume(6)

    addWheat(MainMenuProps, darken_color(WHEAT_COLOR), 0)
    addWheat(MainMenuProps, WHEAT_COLOR, 0.1)

    FontMiniP = love.graphics.newFont(13)
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
end

local function updateMain(dt)
    for _, prop in ipairs(MainMenuProps) do
        if prop.type == "wheat" then
            updateWheat(prop, false)
        end
    end
end

local function updateBird(bird, dt)
    if bird.state.is_stuck then
        bird.state.stuck_timer = bird.state.stuck_timer + dt
    end
    if not bird.state.dead and bird.state.stuck_timer > 2 then
        killBird(EATEN_BY_FROG)
    end

    local bx, by = bird.body:getPosition()
    for _, tongue in ipairs(bird.state.sticky_stuff) do
        bird.state.is_stuck = true
        local tx, ty = tongue.body:getPosition()
        local dist = math.sqrt((tx - bx) * (tx - bx) - (ty - by) * (ty - by))
        love.physics.newRopeJoint(tongue.body, bird.body, tx, ty, bx, by, dist, false)
    end
    bird.state.sticky_stuff = {}

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

    local JUMP_Y_IMPULSE = 10
    local JUMP_X_IMPULSE = 4

    local RUN_Y_IMPULSE = 4
    local RUN_X_IMPULSE = 2

    local xv, yv = bird.body:getLinearVelocity()
    if up then
        bird.state.flapping = true
        sounds.smaller_swosh:play()
        if rise then
            if yv > -300 then
                bird.body:applyForce(0, -FLY_Y_FORCE * dt)
            end
        elseif bird.state.on_ground then
            -- do nothing, we be perching
        elseif down then
            if yv > 300 then
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
        elseif bird.state.on_ground then
            sounds.small_swosh:play()
            bird.body:applyLinearImpulse(RUN_X_IMPULSE, -RUN_Y_IMPULSE)
            bird.state.expended_calories = bird.state.expended_calories - 0.01
            bird.state.on_ground = false
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
        elseif bird.state.on_ground then
            sounds.small_swosh:play()
            bird.body:applyLinearImpulse(-RUN_X_IMPULSE, -RUN_Y_IMPULSE)
            bird.state.expended_calories = bird.state.expended_calories - ((RUN_X_IMPULSE + RUN_Y_IMPULSE) / 100)
            bird.state.on_ground = false
        end

        bird.state.facing_left = true
    else
        if bird.state.flapping and xv > 10 then
            bird.body:applyForce(-FLY_X_INERTIA * dt, 0)
        end
    end

    if bird.state.on_ground and rise then
        sounds.small_swosh:play()
        if bird.state.flapping then
            bird.body:applyLinearImpulse(0, -JUMP_Y_IMPULSE)
            bird.state.expended_calories = bird.state.expended_calories - (JUMP_Y_IMPULSE / 100)
        elseif bird.state.facing_left then
            bird.body:applyLinearImpulse(-JUMP_X_IMPULSE, -JUMP_Y_IMPULSE)
            bird.state.expended_calories = bird.state.expended_calories - ((JUMP_Y_IMPULSE + JUMP_X_IMPULSE) / 100)
        else
            bird.body:applyLinearImpulse(JUMP_X_IMPULSE, -JUMP_Y_IMPULSE)
            bird.state.expended_calories = bird.state.expended_calories - ((JUMP_Y_IMPULSE + JUMP_X_IMPULSE) / 100)
        end
        bird.state.on_ground = false
    end

    if not bird.state.dead then
        if up then
            local carryPenalty =
                math.max(0, bird.state.carrying - BIRD_CARRY_PENALTY_START) /
                (BIRD_CARRY_PENALTY_MAX - BIRD_CARRY_PENALTY_START)

            local doubleCarryPenalty =
                math.max(0, bird.state.carrying - BIRD_CARRY_PENALTY_DOUBLE_START) /
                (BIRD_CARRY_PENALTY_DOUBLE_MAX - BIRD_CARRY_PENALTY_DOUBLE_START)

            bird.state.expended_calories = bird.state.expended_calories - dt * carryPenalty - dt * doubleCarryPenalty
            if bird.state.controls.rise then
                bird.state.expended_calories = bird.state.expended_calories - (dt * 2)
            elseif bird.state.controls.down then
                bird.state.expended_calories = bird.state.expended_calories - (dt / 2)
            else
                bird.state.expended_calories = bird.state.expended_calories - dt
            end
        end

        if bird.state.in_nest then
            bird.state.expended_calories = bird.state.expended_calories - (dt / 10)
        else
            bird.state.expended_calories = bird.state.expended_calories - (dt / 2)
        end

        if (bird.state.calories + bird.state.expended_calories) < 0 then
            killBird(STARVED_TO_DEATH)
        end
    end
end

local function updateBirdControlsFromPlayerInput(bird)
    if bird.state.dead then
        bird.state.controls.left = false
        bird.state.controls.down = false
        bird.state.controls.right = false

        bird.state.controls.up = false
        bird.state.controls.rise = false
    else
        bird.state.controls.left = love.keyboard.isDown("a") or love.keyboard.isDown("h")
        bird.state.controls.down =
            love.keyboard.isDown("s") or love.keyboard.isDown("j") or love.keyboard.isDown("lctrl") or
            love.keyboard.isDown("rctrl")
        bird.state.controls.right = love.keyboard.isDown("d") or love.keyboard.isDown("l")

        bird.state.controls.up = love.keyboard.isDown("space") or love.keyboard.isDown("lshift")
        bird.state.controls.rise = love.keyboard.isDown("w") or love.keyboard.isDown("k")
    end
end

local function updateMenu(menu)
    for _, item in ipairs(menu) do
        if item.updateFn then
            item.updateFn()
        end
    end
end

local function frogAttackAndCooldown(frog, dt, cd, interval)
    if not frog.attacking and frog.attack_cooldown > cd and math.random() * interval < frog.attack_cooldown then
        local bx, by = Objects.bird.body:getPosition()
        local c = frog.tongue
        while c ~= nil do
            local cx, cy = c.body:getPosition()
            local distance = math.sqrt((bx - cx) * (bx - cx) + (by - cy) * (by - cy))
            local directionx = (bx - cx) / distance
            local directiony = (by - cy) / distance
            c.body:applyLinearImpulse(c.body:getMass() * 1000 * directionx, c.body:getMass() * 1000 * directiony)
            c = c.next
        end

        frog.attacking = true
        frog.attacking_timer = 0
        frog.attack_cooldown = 0
    elseif not frog.attacking then
        local c = frog.tongue
        while c ~= nil do
            local cx, cy = c.body:getPosition()
            local fx, fy = frog.body:getPosition()
            local squareDistance = (fx - cx) * (fx - cx) + (fy - cy) * (fy - cy)
            local cOutsideBody = squareDistance > (frog.base_width * frog.base_width / 2)

            if cOutsideBody then
                local distance = math.sqrt(squareDistance)
                local directionx = (fx - cx) / distance
                local directiony = (fy - cy) / distance
                c.body:applyForce(
                    c.body:getMass() * 10000 * directionx * dt,
                    c.body:getMass() * 10000 * directiony * dt
                )
            end
            c = c.next
        end
        frog.attack_cooldown = frog.attack_cooldown + dt
    else
        frog.attack_cooldown = frog.attack_cooldown + dt
    end
end

local function updateFrog(frog, dt)
    frog.timer = frog.timer + dt

    local mod = math.random() > 0.5 and 1 or -1

    local JUMP_X_FACTOR = 100 * mod
    local JUMP_Y_FACTOR = -400

    if frog.on_ground then
        if frog.time_on_ground == nil then
            frog.time_on_ground = 0
        end
        frog.time_on_ground = frog.time_on_ground + dt
    else
        frog.time_on_ground = 0
    end

    if frog.attacking then
        frog.attacking_timer = frog.attacking_timer + dt
        if frog.attacking_timer > FROG_ATTACK_ANIMATION_TIME then
            frog.attacking = false
        end
    end

    if frog.active then
        if frog.on_ground and frog.time_on_ground > 1 and math.random() < 0.01 then
            frog.croak()
            local mass = frog.body:getMass()
            frog.body:applyLinearImpulse(mass * JUMP_X_FACTOR, mass * JUMP_Y_FACTOR)
            frog.time_on_ground = 0
        end
        if frog.insane then
            frogAttackAndCooldown(frog, dt, FROG_INSANE_ATTACK_COOLDOWN, FROG_INSANE_ATTACK_INTERVAL)
        elseif frog.evil and not Objects.bird.state.dead then
            local birdx, birdy = Objects.bird.body:getPosition()
            local frogx, frogy = frog.body:getPosition()
            local squareDistance = (birdx - frogx) * (birdx - frogx) + (birdy - frogy) * (birdy - frogy)
            local birdInRange = squareDistance < (frog.base_width * frog.base_width)

            if birdInRange and not Objects.bird.dead then
                frogAttackAndCooldown(frog, dt, FROG_ATTACK_COOLDOWN, FROG_ATTACK_INTERVAL)
            end
        end
    end
end

local function createFrogAtGround(x)
    return createFrog(x, 10, 1 + 0.2 * math.random())
end

local function createFrogInAir(size)
    local left = -900
    local right = 900
    local SAFE_AREA_WIDTH = 220
    local left_side = left - (NEST_X - SAFE_AREA_WIDTH)
    local right_side = right - (NEST_X + SAFE_AREA_WIDTH)

    local r = rand(left_side, right_side)

    local x = 0
    if r < 0 then
        x = NEST_X - SAFE_AREA_WIDTH + r
    else
        x = NEST_X + SAFE_AREA_WIDTH + r
    end

    -- local x = -500 + math.random() * 1000
    local y = -1000
    local frog = createFrog(x, y, size)
    frog.evil = true
    frog.insane = true
    frog.active = true
    return frog
end

local function createSmallFrogInAir()
    return createFrogInAir(0.4 + 0.2 * math.random())
end

local function createBigFrogInAir()
    return createFrogInAir(1.5 + 0.2 * math.random())
end

local function updateGame(dt)
    World:update(dt)

    local EVENT_INTERVAL = 50

    if Score.collected >= EVENT_INTERVAL and #Objects.frogs <= 0 then
        table.insert(Objects.frogs, createFrogAtGround(450 + math.random() * 100))
    end

    if Score.collected >= EVENT_INTERVAL * 2 and #Objects.frogs <= 1 then
        table.insert(Objects.frogs, createFrogAtGround(-450 - math.random() * 100))
    end

    if Score.collected >= EVENT_INTERVAL * 3 and #Objects.frogs <= 2 then
        table.insert(Objects.frogs, createFrogAtGround(-50 + math.random() * 100))
    end

    if Score.collected >= EVENT_INTERVAL * 3.5 then
        activateAllFrogs()
        turnAllFrogsEvil()
        turnAllFrogsInsane()
    end

    local WHEAT_DISCO_START = EVENT_INTERVAL * 4.5

    if Score.collected >= EVENT_INTERVAL * 4.5 and #Objects.frogs <= 8 then
        table.insert(Objects.frogs, createSmallFrogInAir())
    end

    if Score.collected >= EVENT_INTERVAL * 5 and #Objects.frogs <= 9 then
        table.insert(Objects.frogs, createBigFrogInAir())
    end

    if Score.collected >= EVENT_INTERVAL * 5.5 and #Objects.frogs <= 16 then
        table.insert(Objects.frogs, createSmallFrogInAir())
    end

    if Score.collected >= EVENT_INTERVAL * 6 and #Objects.frogs <= 17 then
        table.insert(Objects.frogs, createBigFrogInAir())
    end

    if Score.collected >= EVENT_INTERVAL * 6.5 and #Objects.frogs <= 20 then
        table.insert(Objects.frogs, createSmallFrogInAir())
    end

    if Score.collected >= EVENT_INTERVAL * 7 and #Objects.frogs <= 25 then
        table.insert(Objects.frogs, createSmallFrogInAir())
    end

    if Objects.kernels == nil then
        Objects.kernels = {}
    end
    if KernelTimer > KERNEL_TIMER_COOLDOWN then
        KernelTimer = KernelTimer - KERNEL_TIMER_COOLDOWN
        if #Objects.kernels < 200 then
            table.insert(Objects.kernels, createKernel())
        end
    end

    updateBirdControlsFromPlayerInput(Objects.bird)
    updateBird(Objects.bird, dt)

    for _, frog in ipairs(Objects.frogs) do
        updateFrog(frog, dt)
    end

    for _, prop in ipairs(BackgroundProps) do
        if prop.type == "wheat" then
            updateWheat(prop, Score.collected >= WHEAT_DISCO_START)
        end
    end

    for _, prop in ipairs(Props) do
        if prop.type == "wheat" then
            updateWheat(prop, Score.collected >= WHEAT_DISCO_START)
        end
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
    -- if CyclicTime > (2 * math.pi) then
    --     CyclicTime = CyclicTime - (2 * math.pi)
    -- end

    Time = Time + dt
    TimeAlive = TimeAlive + dt
    if Objects.bird and Objects.bird.state.in_nest then
        TimeSpentInNest = TimeSpentInNest + dt
    end

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

local function drawRectMiddleMiddle(x, y, width, height)
    -- love.graphics.rectangle("fill", x - (width / 2), y, width, height) -- origin in the middle bottom
    love.graphics.rectangle("fill", x - (width / 2), y, -(height / 2), width, height) -- origin in the middle
end

local function drawRectMiddleBottom(x, y, width, height)
    love.graphics.rectangle("fill", x - (width / 2), y - height, width, height)
end

local function drawTongue(tongue)
    local x, y = tongue.body:getPosition()
    love.graphics.setColor(unpack(RED))
    love.graphics.circle("fill", x, y, tongue.radius)
end

local function drawFrog(frog) --x, y, w, h)
    local x, y = frog.body:getPosition()
    local FROG_DARK_GREEN = rgb(20, 72, 20)
    local FROG_DARKER_GREEN = rgb(14, 52, 14)
    local FROG_PURPLE = rgb(52, 14, 52)

    local FROG_PURPLE = rgb(120, 33, 120)
    local FROG_BRIGHT_PURPLE = rgb(160, 44, 160)

    love.graphics.push()
    love.graphics.translate(x, y) -- + (frog.height / 2))

    love.graphics.setColor(unpack(FROG_DARKER_GREEN))
    drawRectMiddleBottom(0, 0, frog.base_width, frog.base_height)
    drawRectMiddleBottom(0, -frog.base_height, frog.body_width, frog.body_height)
    -- stalks
    drawRectMiddleBottom(0 + (frog.eye_spacing / 2), -frog.base_height, frog.stalk_width, frog.stalk_height)
    drawRectMiddleBottom(0 - (frog.eye_spacing / 2), -frog.base_height, frog.stalk_width, frog.stalk_height)
    -- eye sockets
    drawRectMiddleBottom(
        0 + (frog.eye_spacing / 2) + (frog.eye_socket_width / 2) - frog.stalk_width,
        -frog.base_height - frog.stalk_height,
        frog.eye_socket_width,
        frog.eye_socket_height
    )
    drawRectMiddleBottom(
        0 - (frog.eye_spacing / 2) - (frog.eye_socket_width / 2) + frog.stalk_width,
        -frog.base_height - frog.stalk_height,
        frog.eye_socket_width,
        frog.eye_socket_height
    )

    -- eyes
    love.graphics.setColor(unpack(FROG_PURPLE))
    drawRectMiddleBottom(
        0 + (frog.eye_spacing / 2) + (frog.eye_socket_width / 2) - frog.stalk_width +
            (frog.eye_socket_width - frog.eye_ball_width) / 2,
        -frog.base_height - frog.stalk_height,
        frog.eye_ball_width,
        frog.eye_ball_height
    )
    drawRectMiddleBottom(
        0 - (frog.eye_spacing / 2) - (frog.eye_socket_width / 2) + frog.stalk_width -
            (frog.eye_socket_width - frog.eye_ball_width) / 2,
        -frog.base_height - frog.stalk_height,
        frog.eye_ball_width,
        frog.eye_ball_height
    )

    -- pupils
    if frog.insane then
        local flipper = math.sin(CyclicTime * 100)
        if flipper > 0 then
            love.graphics.setColor(unpack(FROG_BRIGHT_PURPLE))
        else
            love.graphics.setColor(unpack(RED))
        end
    elseif frog.evil then
        love.graphics.setColor(unpack(RED))
    else
        love.graphics.setColor(unpack(FROG_BRIGHT_PURPLE))
    end

    drawRectMiddleBottom(
        0 + (frog.eye_spacing / 2) + (frog.eye_socket_width / 2) - frog.stalk_width +
            (frog.eye_socket_width - frog.eye_ball_width) / 2,
        -frog.base_height - frog.stalk_height - (frog.eye_ball_height / 3),
        frog.eye_ball_width,
        frog.eye_ball_height / 3
    )
    drawRectMiddleBottom(
        0 - (frog.eye_spacing / 2) - (frog.eye_socket_width / 2) + frog.stalk_width -
            (frog.eye_socket_width - frog.eye_ball_width) / 2,
        -frog.base_height - frog.stalk_height - (frog.eye_ball_height / 3),
        frog.eye_ball_width,
        frog.eye_ball_height / 3
    )

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
    if not Objects.bird.state.dead and caloriesInSystem < SHOW_CALORIES_THRESHHOLD then
        if caloriesInSystem < SHOW_CALORIES_CRITICAL_THRESHHOLD then
            love.graphics.setColor(unpack(RED))
        elseif caloriesInSystem < SHOW_CALORIES_WARNING_THRESHHOLD then
            love.graphics.setColor(unpack(ORANGE))
        else
            love.graphics.setColor(unpack(WHITE))
        end
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

    if Objects.kernels then
        for _, kernel in ipairs(Objects.kernels) do
            love.graphics.setColor(unpack(kernel.color))
            love.graphics.polygon("fill", kernel.body:getWorldPoints(kernel.shape:getPoints()))
        end
    end

    drawBird(Objects.bird.state, Objects.bird.body:getPosition())

    if Objects.tongues then
        for _, tongue in ipairs(Objects.tongues) do
            drawTongue(tongue)
        end
    end

    if Objects.frogs then
        for _, frog in ipairs(Objects.frogs) do
            drawFrog(frog)
        end
    end

    love.graphics.pop()
end

local function drawBirdCarryText()
    local window_width = love.graphics.getWidth()
    local window_height = love.graphics.getHeight()
    local x, y = Objects.bird.body:getPosition()
    local bird = Objects.bird.state

    love.graphics.push()
    love.graphics.translate(math.floor(window_width / 2), window_height)
    love.graphics.translate(math.floor(x), math.floor(y))

    if not bird.dead and bird.carrying > 0 then
        love.graphics.setColor(unpack(BLACK))
        love.graphics.printf(string.format("%i", bird.carrying), FontMiniP, -25, -25, 50, "center")
        if bird.carrying > BIRD_CARRY_PENALTY_MAX then
            love.graphics.setColor(unpack(RED))
        elseif bird.carrying > BIRD_CARRY_PENALTY_START then
            love.graphics.setColor(unpack(ORANGE))
        else
            love.graphics.setColor(unpack(WHEAT_COLOR))
        end
        love.graphics.printf(string.format("%i", bird.carrying), FontMini, -25, -25, 50, "center")
    end
    love.graphics.pop()
end

local function drawGameWorld()
    drawProps(BackgroundProps)
    drawObjects()
    drawProps(Props)
    drawBirdCarryText()
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
