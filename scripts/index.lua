-- Website made by pikelmon (contact me on Discord)
-- Don't read this code unless you want suicidal thoughts

--// Constants
local SUPABASE_URL = "mjzuravlkjuqqcoeches.supabase.co"
local SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1qenVyYXZsa2p1cXFjb2VjaGVzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYyMDE2MzUsImV4cCI6MjA3MTc3NzYzNX0.7lknV_umUvciEYbP0jPGN8Qw9vPf1EdwmdumXyZTXJo"

local BACKEND_URL = "https://open-canvas-backend.vercel.app/"
local CANVAS_SIZE = 80

--// Variables
local ws = WebSocket.new("wss://" .. SUPABASE_URL .. "/realtime/v1?apikey=" .. SUPABASE_KEY)
local canvas_display_size = 0
local pixel_balance = 0

--// Elements
local fake_canvas = gurt.select("#fake-canvas")
local color_input = gurt.select("#color-input")
local main_container = gurt.select("#content-container")
local balance_indicator = gurt.select("#balance")
local balance_timer = gurt.select("#balance-timer")
local seconds_until_next_pixel = 60
local balance_interval_id
local canvas_display

--// Functions
function create_canvas()
    canvas_display_size = (fake_canvas.size.width < fake_canvas.size.height)
        and fake_canvas.size.width
        or fake_canvas.size.height

    canvas_display = gurt.create("canvas", {
        id    = "canvas",
        style = "w-" .. canvas_display_size / 4 / 4 ..
                " h-" .. canvas_display_size / 4 / 4
    })

    canvas_display:on('click', on_canvas_display_click)

    local ctx = canvas_display:withContext("2d")
    ctx:fillRect(0, 0, canvas_display_size * 4 * 4, canvas_display_size, "#ffffff")

    main_container:append(canvas_display)
end

function set_local_balance(balance)
    pixel_balance = balance
    balance_indicator.text = tostring(balance):gsub("%.0$", "").."/30"
end

function render_pixel(x, y, color)
    local pixel_size = canvas_display_size / CANVAS_SIZE
    local ctx        = canvas_display:withContext("2d")

    ctx:fillRect(pixel_size * x, pixel_size * y, pixel_size, pixel_size, color)
end

function update_pixel(x, y, color)
    render_pixel(x, y, color)

    set_local_balance(pixel_balance-1)

    local response = fetch(BACKEND_URL .. "api/canvas", {
        method  = "PUT",
        headers = {
            ["Content-Type"] = "application/json",
        },
        body    = JSON.stringify({
            token = gurt.crumbs.get("token"),
            x     = x,
            y     = y,
            color = color
        })
    })

    local json = response:json()

    seconds_until_next_pixel = json.seconds_until_next_pixel

    local new_pixel_balance = json.pixel_balance
    if pixel_balance ~= new_pixel_balance then
        set_local_balance(new_pixel_balance)
    end

    return response:ok()
end

function fetch_canvas()
    local response = fetch("https://" .. SUPABASE_URL .. "/rest/v1/canvas", {
        headers = {
            apikey        = SUPABASE_KEY,
            Authorization = "Bearer " .. SUPABASE_KEY,
            ["Content-Type"] = "application/json",
            Accept          = "application/json"
        }
    })
    return response:json()
end

function fetch_balance()
    local response = fetch(BACKEND_URL .. "api/balance", {
        method  = "POST",
        headers = {
            ["Content-Type"] = "application/json",
        },
        body    = JSON.stringify({
            token = gurt.crumbs.get("token")
        })
    })

    return response:json()
end

function render_canvas(canvas)
    for _, pixel in ipairs(canvas) do
        render_pixel(pixel.x, pixel.y, pixel.color)
    end
end

function ws_join_channel()
    local join_msg = {
        topic   = "realtime:public:canvas",
        event   = "phx_join",
        payload = {},
        ref     = "1"
    }
    ws:send(JSON.stringify(join_msg))
    trace.log("sent join_msg")
end

function start_balance_interval()
    balance_timer.text = "("..tostring(math.floor(seconds_until_next_pixel))..")"
    if balance_interval_id then clearInterval(balance_interval_id) end

    balance_interval_id = setInterval(function()
        seconds_until_next_pixel = seconds_until_next_pixel - 1
        if seconds_until_next_pixel < 0 then
            if pixel_balance < 30 then
                set_local_balance(pixel_balance + 1)
            end
            seconds_until_next_pixel = seconds_until_next_pixel + 60
        end
        balance_timer.text = "("..tostring(math.floor(seconds_until_next_pixel))..")"
    end, 1000)
end

function is_valid_hex_color(str)
    local pattern = Regex.new("^#?([0-9a-f]{6}|[0-9a-f]{3})$")
    return pattern:test(str)
end

--// Event Listeners
ws:on("close", function(code, reason)
    trace.log("WebSocket closed: " .. code .. " - " .. reason)
end)

ws:on("error", function(error)
    trace.log("WebSocket error: " .. error)
end)

ws:on("message", function(data)
    trace.log("Received: " .. data)
end)

function on_canvas_display_click(mouse_pos)
    if pixel_balance < 1 then return end 
    if not is_valid_hex_color(color_input.value) then return end

    local pixel_size = canvas_display_size / CANVAS_SIZE
    local pixel_x = math.floor(mouse_pos.x / pixel_size)
    local pixel_y = math.floor(mouse_pos.y / pixel_size)

    render_pixel(pixel_x, pixel_y, color_input.value)
    update_pixel(pixel_x, pixel_y, color_input.value)
end



--// Init
function init()
    -- Redirect if not logged in
    local token = gurt.crumbs.get("token")
    if not token then
        gurt.location.goto("opencanvas.io/auth")
        return
    end

    fake_canvas:hide()
    create_canvas()

    color_input.value = "#ff0000"

    render_canvas(fetch_canvas())
    local balance_result = fetch_balance()
    set_local_balance(balance_result.pixel_balance)

    seconds_until_next_pixel = balance_result.seconds_until_next_pixel
    start_balance_interval()

    --
end

init()