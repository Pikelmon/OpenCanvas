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

    delay(function()
        local canvas_bar_size = fake_canvas.size.height - 5 -- -5 is for the border
        fake_canvas:hide()

        trace.log(canvas_bar_size)
    
        local canvas = gurt.create("canvas", {
            id = "canvas",
            style = "w-[" .. canvas_bar_size .. "px] h-[" .. canvas_bar_size .. "px]"
        })

        canvas:withContext('shader'):source([[
            shader_type canvas_item;

            uniform float pixel_size : hint_range(4.0, 64.0) = 31.0;
            uniform float corruption_speed : hint_range(0.1, 10.0) = 1.0;
            uniform vec3 heart_color : source_color = vec3(1.0, 0.2, 0.4); // pink-red heart

            float rand(vec2 co) {
                return fract(sin(dot(co, vec2(12.9898,78.233))) * 43758.5453);
            }

            float heart_shape(vec2 p) {
                p = (p - vec2(0.4825, 0.55)) * 2.5; 
                p.y *= -1.0; // flip so it points up
                float a = p.x * p.x + p.y * p.y - 1.0;
                return a * a * a - p.x * p.x * p.y * p.y * p.y;
            }

            void fragment() {
                vec2 pixel_uv = floor(UV * pixel_size) / pixel_size;

                float in_heart = step(0.0, -heart_shape(pixel_uv));

                float t = TIME * corruption_speed;

                float corruption_phase = floor(t + rand(pixel_uv) * 1000.0);

                vec3 random_col = vec3(
                    rand(pixel_uv + vec2(corruption_phase, 1.0)),
                    rand(pixel_uv + vec2(corruption_phase, 2.0)),
                    rand(pixel_uv + vec2(corruption_phase, 3.0))
                );

                float heal = fract(t + rand(pixel_uv) * 10.0); // cycles 0→1
                vec3 color = mix(random_col, heart_color, heal);

                color *= in_heart;

                COLOR = vec4(color, in_heart);
            }

        ]])

        canvas_container:append(canvas)

        end, 1)


end

init()