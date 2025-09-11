--// Constants

local BACKEND_URL = 'https://open-canvas-backend.vercel.app/'

--// Elements

local username_input = gurt.select('#username-input')
local password_input = gurt.select('#password-input')

local login_btn = gurt.select('#login-btn')
local register_btn = gurt.select('#register-btn')

local auth_error_display = gurt.select('#auth-error')

local gradient_bar = gurt.select("#gradient-bar")
local fake_canvas = gurt.select("#fake-canvas")
local canvas_container = gurt.select("#canvas-container")

--// Functions

function login(username, password)
    local response = fetch(BACKEND_URL .. 'api/auth/login', {
        method = 'POST',
        headers = {
            ['Content-Type'] = 'application/json',
        },
        body = JSON.stringify({
            username = username,
            password = password
        })
    })

    if response:ok() then
        local data = response:json()
        gurt.crumbs.set({name='token', value=data.token})
        gurt.crumbs.set({name='userId', value=data.userId})
        auth_error_display.text = ''
        return true
    else
        if response.status == 401 then
            auth_error_display.text = 'Invalid credentials!'
        end
        return false
    end
end

function register(username, password)
    local response = fetch(BACKEND_URL .. 'api/auth/register', {
        method = 'POST',
        headers = {
            ['Content-Type'] = 'application/json',
        },
        body = JSON.stringify({
            username = username,
            password = password
        })
    })

    if response:ok() then
        local data = response:json()
        gurt.crumbs.set({name='token', value=data.token})
        gurt.crumbs.set({name='userId', value=data.userId})
        auth_error_display.text = ''
        return true
    else
        if response.status == 409 then
            auth_error_display.text = 'Username taken!'
        end
        if response.status == 400 then
            auth_error_display.text = 'Invalid credentials; Minimum username length is 3, minimum password length is 6'
        end
        return false
    end
end

local function delay(callback, ms)
    local interval_id
    interval_id = setInterval(function()
        clearInterval(interval_id)
        callback()
    end, ms)
end

--// Event Listeners

login_btn:on('click', function()
    local success = login(username_input.value, password_input.value)
    if success then
        gurt.location.goto("/")
    end
end)

register_btn:on('click', function()
    local success = register(username_input.value, password_input.value)
    if success then
        gurt.location.goto("/")
    end
end)

-- Initialization
local function init()
    gradient_bar:withContext('shader'):source([[
        shader_type canvas_item;

        void fragment() {
            float x = UV.x;

            float dist = abs(x - 0.5) * 2.0; // 0 at center, 1 at edges

            vec3 dark = vec3(0.0, 0.0, 0.4);   // dark blue
            vec3 light = vec3(0.3, 0.6, 1.0);  // lighter blue

            vec3 color = mix(light, dark, dist);

            COLOR = vec4(color, 1.0);
        }
    ]])
end

init()