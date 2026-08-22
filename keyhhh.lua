--[[
hate.CC 加载器（KeyAuth 直连版 · v6.5 稳定加速版）
★ init 单飞：杜绝重复 init 导致的限流/会话冲突（根治"重注入才能登录"）
★ 失败冷却 2 秒防连点限流
★ API 主/镜像双通道 + 重试间隔缩短，初始化更快
★ login/register 携带 Session ID
★ 加强版 HWID（机器唯一）+ 用户名/密码/卡密长度校验
★ 主菜单下载成功后才关闭登录窗
--]]
---------------------------------------------------------------- 反调试 & 环境检测
local function anti_debug()
    if type(isdebugger) == "function" and pcall(isdebugger) and isdebugger() then
        pcall(function() game:Shutdown() end)
        return false
    end
    if not hookfunction or not getrawmetatable then
        warn("[hate.CC] 执行器环境异常或缺失核心API，拒绝运行！")
        pcall(function() game:Shutdown() end)
        return false
    end
    return true
end
if not anti_debug() then return end

local exec_name = ""
if type(identifyexecutor) == "function" then exec_name = identifyexecutor() end
if not writefile or not readfile then
    warn("[hate.CC] 当前执行器(" .. exec_name .. ")不支持文件读写，自动登录/配置保存将失效！")
end
---------------------------------------------------------------- 配置区
local APP_NAME    = "hate.CC"
local OWNER_ID    = "RXOyhCyuBv"
local APP_SECRET  = "8623874dafddb49f0915f6d709f5f2a3e84093c88b1ca9f03a56a9abe4b6a5fa"
local APP_VERSION = "1.0"
local PAYLOAD_URL = "https://raw.githubusercontent.com/zaiwu08-art/hate.cc1/refs/heads/main/yeahhhh"
local PAYLOAD_MIRROR = "https://ghproxy.net/" .. PAYLOAD_URL
local API_MAIN = "https://keyauth.win/api/1.2/"
local API_MIRROR = "https://ghproxy.net/https://keyauth.win/api/1.2/"

local USER_MIN, USER_MAX = 3, 20
local PASS_MIN, PASS_MAX = 6, 32
local KEY_MAX = 64

local HS = game:GetService("HttpService")
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
---------------------------------------------------------------- 凭证加密 (XOR 偏移)
local CRED_FILE = "hate_cc_cred.dat"
local CRED_KEY = "h4t3_cc_s3cr3t_2026"
local function encode(s)
    local r = {}
    for i = 1, #s do
        local c = s:byte(i)
        local k = CRED_KEY:byte((i - 1) % #CRED_KEY + 1)
        r[i] = string.char((c + k) % 256)
    end
    return table.concat(r)
end
local function decode(s)
    local r = {}
    for i = 1, #s do
        local c = s:byte(i)
        local k = CRED_KEY:byte((i - 1) % #CRED_KEY + 1)
        r[i] = string.char((c - k + 256) % 256)
    end
    return table.concat(r)
end
local function saveCred(u, p)
    if not writefile then return end
    pcall(function() writefile(CRED_FILE, encode(u .. "|" .. p)) end)
end
local function loadCred()
    if not readfile then return nil, nil end
    local ok, data = pcall(function() return readfile(CRED_FILE) end)
    if ok and data and #data > 0 then
        local dec = decode(data)
        local u, p = dec:match("^(.-)|(.*)$")
        return u, p
    end
    return nil, nil
end
---------------------------------------------------------------- 清理旧界面
local function killOld()
    local parents = {}
    pcall(function() if type(gethui) == "function" and gethui() then parents[#parents + 1] = gethui() end end)
    pcall(function() parents[#parents + 1] = game:GetService("CoreGui") end)
    pcall(function() parents[#parents + 1] = Players.LocalPlayer:WaitForChild("PlayerGui") end)
    for _, p in ipairs(parents) do
        pcall(function()
            local old = p:FindFirstChild("HateCCUI")
            if old then old:Destroy() end
        end)
    end
end
killOld()
---------------------------------------------------------------- 通用下载（重试间隔 0.8s，更快）
local function fetch(url, retries)
    retries = retries or 2
    local req = (type(request) == "function" and request)
        or (type(http_request) == "function" and http_request)
        or (type(syn) == "table" and syn.request)
        or (type(http) == "table" and http.request)
    if type(req) == "function" then
        for i = 1, retries do
            local ok, r = pcall(req, { Url = url, Method = "GET" })
            if ok and r and type(r.Body) == "string" and #r.Body > 0 then return r.Body end
            if i < retries then task.wait(0.8) end
        end
    end
    if type(game) == "table" and type(game.HttpGet) == "function" then
        for i = 1, retries do
            local ok, r = pcall(function() return game:HttpGet(url) end)
            if ok and type(r) == "string" and #r > 0 then return r end
            if i < retries then task.wait(0.8) end
        end
    end
    return nil
end
---------------------------------------------------------------- HWID（加强版 + LocalPlayer 保护）
local function getHWID()
    if type(gethwid) == "function" then
        local ok, id = pcall(gethwid)
        if ok and type(id) == "string" and id ~= "" then return id end
    end
    if type(readfile) == "function" and type(writefile) == "function" then
        local file = "hate_cc_hwid.dat"
        local ok, saved = pcall(function() return readfile(file) end)
        if ok and type(saved) == "string" and #saved >= 16 then return saved end
        math.randomseed(os.time() + os.clock() * 1e6)
        local rnd = {}
        for i = 1, 32 do rnd[i] = string.format("%x", math.random(0, 15)) end
        local id = "fs-" .. table.concat(rnd)
        pcall(function() writefile(file, id) end)
        return id
    end
    local exec = (type(identifyexecutor) == "function" and identifyexecutor()) or "unknown"
    local lp = Players.LocalPlayer
    local uid = (lp and lp.UserId) or 0
    return "fb-" .. tostring(exec) .. "-" .. tostring(uid)
end
local HWID = getHWID()
---------------------------------------------------------------- KeyAuth（Session ID 修复 + 双通道）
local auth = { success = false, message = "", sessionid = nil }
local function api(params)
    params.ownerid = OWNER_ID
    params.name = APP_NAME
    params.ver = APP_VERSION
    params.secret = APP_SECRET
    params.hwid = HWID
    if auth.sessionid and params.type ~= "init" then
        params.sessionid = auth.sessionid
    end
    local qs = {}
    for k, v in pairs(params) do qs[#qs + 1] = k .. "=" .. HS:UrlEncode(tostring(v)) end
    local query = table.concat(qs, "&")
    local body = fetch(API_MAIN .. query, 1)
    if not body then body = fetch(API_MIRROR .. query, 1) end
    if not body then return { success = false, message = "网络失败，无法访问 keyauth.win" } end
    local ok, json = pcall(function() return HS:JSONDecode(body) end)
    if not ok or type(json) ~= "table" then return { success = false, message = "响应非JSON: " .. tostring(body):sub(1, 60) } end
    return json
end
function auth:init()
    local r = api({ type = "init" })
    self.success, self.message = (r.success == true), tostring(r.message or "")
    if self.success and r.sessionid then self.sessionid = r.sessionid end
    return self.success
end
function auth:login(u, p)
    local r = api({ type = "login", username = u, pass = p })
    self.success, self.message = (r.success == true), tostring(r.message or "")
    if self.success and r.sessionid then self.sessionid = r.sessionid end
    return self.success
end
function auth:register(u, p, k)
    local r = api({ type = "register", username = u, pass = p, key = k })
    self.success, self.message = (r.success == true), tostring(r.message or "")
    if self.success and r.sessionid then self.sessionid = r.sessionid end
    return self.success
end
-- ★ 单飞 init：进行中时只等待，不再发第二个 init（根治限流/会话冲突）
local initRunning = false
local function ensureInit(timeout)
    if auth.sessionid then return true end
    if initRunning then
        local t0 = tick()
        timeout = timeout or 12
        while initRunning and (tick() - t0) < timeout do task.wait(0.1) end
        return auth.sessionid ~= nil
    end
    initRunning = true
    auth:init()
    initRunning = false
    return auth.sessionid ~= nil
end
local function msg() return auth.message end
---------------------------------------------------------------- 界面 + 逻辑
local statusRef = nil
local function Run()
    local gui = Instance.new("ScreenGui")
    gui.Name = "HateCCUI"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 100
    pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
    if not gui.Parent then gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end

    local function make(cls, props, parent) local o = Instance.new(cls); for k, v in pairs(props) do o[k] = v end; o.Parent = parent; return o end
    local function trim(s) return s:match("^%s*(.-)%s*$") end
    local function chlen(s) if utf8 and utf8.len then return utf8.len(s) or #s end; return #s end

    local function validUser(u)
        local n = chlen(u)
        if n < USER_MIN or n > USER_MAX then return false, ("用户名长度需 %d-%d 位"):format(USER_MIN, USER_MAX) end
        if not u:match("^[%w_]+$") then return false, "用户名仅限 字母/数字/下划线" end
        return true
    end
    local function validPass(p)
        local n = chlen(p)
        if n < PASS_MIN or n > PASS_MAX then return false, ("密码长度需 %d-%d 位"):format(PASS_MIN, PASS_MAX) end
        return true
    end

    local main = make("Frame", { Size = UDim2.fromOffset(340, 224), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(25, 25, 30), BorderSizePixel = 0 }, gui)
    make("UICorner", { CornerRadius = UDim.new(0, 10) }, main)
    make("UIStroke", { Color = Color3.fromRGB(60, 60, 70) }, main)
    local title = make("TextLabel", { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Color3.fromRGB(35, 35, 42), BorderSizePixel = 0, Text = "hate.CC | 加载器", TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.GothamBold, TextSize = 15 }, main)
    make("UICorner", { CornerRadius = UDim.new(0, 10) }, title)
    local status = make("TextLabel", { Size = UDim2.new(1, -20, 0, 20), Position = UDim2.new(0, 10, 0, 40), BackgroundTransparency = 1, Text = "状态：初始化中…", TextColor3 = Color3.fromRGB(160, 160, 160), Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left }, main)
    statusRef = status
    local function setStatus(t, c) status.Text = "状态：" .. t; status.TextColor3 = c or Color3.fromRGB(160, 160, 160) end
    local GREEN = Color3.fromRGB(120, 220, 120)
    local RED = Color3.fromRGB(255, 120, 120)
    local YELLOW = Color3.fromRGB(255, 200, 0)

    -- ★ 尽早启动 init（单飞），用户点登录时大概率已完成
    task.spawn(function()
        if ensureInit() then setStatus("初始化成功，请登录 / 注册", GREEN)
        else setStatus("初始化失败：" .. msg(), RED) end
    end)

    local function makeBox(ph, isPass, y)
        local b = make("TextBox", { Size = UDim2.new(1, -20, 0, 34), Position = UDim2.new(0, 10, 0, y), BackgroundColor3 = Color3.fromRGB(40, 40, 48), BorderSizePixel = 0, PlaceholderText = ph, PlaceholderColor3 = Color3.fromRGB(120, 120, 120), Text = "", TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.Gotham, TextSize = 14, ClearTextOnFocus = false }, main)
        make("UICorner", { CornerRadius = UDim.new(0, 8) }, b)
        make("UIPadding", { PaddingLeft = UDim.new(0, 10) }, b)
        local get, set
        if isPass then
            local real, lock = "", false
            b:GetPropertyChangedSignal("Text"):Connect(function()
                if lock then return end
                local t = b.Text
                local masked = string.rep("•", #real)
                if t == masked then return end
                local tl = chlen(t)
                if tl > #real then real = real .. t:sub(#masked + 1) else real = real:sub(1, math.max(tl, 0)) end
                lock = true
                b.Text = string.rep("•", #real)
                lock = false
            end)
            get = function() return real end
            set = function(val) real = val; lock = true; b.Text = string.rep("•", #real); lock = false end
        else
            get = function() return b.Text end
            set = function(val) b.Text = val end
        end
        return b, get, set
    end

    local userBox, getUser, setUser = makeBox("用户名", false, 66)
    local passBox, getPass, setPass = makeBox("密码", true, 106)
    local keyBox, getKey, _ = makeBox("卡密（后台购买/生成）", false, 146)

    local u_saved, p_saved = loadCred()
    if u_saved then setUser(u_saved) end
    if p_saved then setPass(p_saved) end

    local mode = "login"
    local modeBtn = make("TextButton", { Size = UDim2.new(1, -20, 0, 26), Position = UDim2.new(0, 10, 0, 146), BackgroundColor3 = Color3.fromRGB(40, 40, 48), BorderSizePixel = 0, Text = "当前模式：登录（点击切换为注册）", TextColor3 = Color3.fromRGB(180, 180, 180), Font = Enum.Font.Gotham, TextSize = 12 }, main)
    make("UICorner", { CornerRadius = UDim.new(0, 8) }, modeBtn)
    local confirmBtn = make("TextButton", { Size = UDim2.new(0.5, -15, 0, 36), Position = UDim2.new(0, 10, 0, 178), BackgroundColor3 = Color3.fromRGB(0, 122, 255), BorderSizePixel = 0, Text = "确 定", TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.GothamBold, TextSize = 15 }, main)
    make("UICorner", { CornerRadius = UDim.new(0, 8) }, confirmBtn)
    local exitBtn = make("TextButton", { Size = UDim2.new(0.5, -15, 0, 36), Position = UDim2.new(0.5, 5, 0, 178), BackgroundColor3 = Color3.fromRGB(70, 70, 80), BorderSizePixel = 0, Text = "退 出", TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.GothamBold, TextSize = 15 }, main)
    make("UICorner", { CornerRadius = UDim.new(0, 8) }, exitBtn)

    local function layout()
        if mode == "login" then
            keyBox.Visible = false
            modeBtn.Position = UDim2.new(0, 10, 0, 146)
            confirmBtn.Position = UDim2.new(0, 10, 0, 178)
            exitBtn.Position = UDim2.new(0.5, 5, 0, 178)
            main.Size = UDim2.fromOffset(340, 224)
        else
            keyBox.Visible = true
            modeBtn.Position = UDim2.new(0, 10, 0, 186)
            confirmBtn.Position = UDim2.new(0, 10, 0, 220)
            exitBtn.Position = UDim2.new(0.5, 5, 0, 220)
            main.Size = UDim2.fromOffset(340, 270)
        end
    end
    layout()

    local dragging, dragStart, startPos = false, nil, nil
    title.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, i.Position, main.Position
        end
    end)
    title.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            local newPos = startPos + UDim2.fromOffset(d.X, d.Y)
            local vp = Camera.ViewportSize
            local maxX = vp.X - main.AbsoluteSize.X
            local maxY = vp.Y - main.AbsoluteSize.Y
            newPos = UDim2.new(0, math.clamp(newPos.X.Offset, 0, math.max(0, maxX)), 0, math.clamp(newPos.Y.Offset, 0, math.max(0, maxY)))
            main.Position = newPos
        end
    end)

    modeBtn.MouseButton1Click:Connect(function()
        mode = (mode == "login") and "register" or "login"
        modeBtn.Text = (mode == "login") and "当前模式：登录（点击切换为注册）" or "当前模式：注册（点击切换为登录）"
        layout()
    end)
    exitBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

    local busy = false
    local lastFail = 0
    local function failCool()
        local w = tick() - lastFail
        if w < 2 then setStatus(("操作太频繁，%.1f 秒后可重试"):format(2 - w), YELLOW) return false end
        return true
    end

    local function enterMain()
        setStatus("验证成功，正在加载主菜单…", GREEN)
        local src = fetch(PAYLOAD_URL)
        if not src then
            setStatus("主地址失败，正在尝试镜像下载…", YELLOW)
            src = fetch(PAYLOAD_MIRROR)
        end
        if type(src) == "string" and #src > 0 then
            gui:Destroy()
            local tempPath = "hatecc_temp.lua"
            pcall(function() writefile(tempPath, src) end)
            local fn, err
            if type(loadfile) == "function" then fn, err = loadfile(tempPath) else fn, err = loadstring(src) end
            if type(fn) == "function" then
                local env = (type(getgenv) == "function" and getgenv()) or _G
                pcall(function() setfenv(fn, env) end)
                local okRun, runErr = pcall(fn)
                if not okRun then warn("[hate.CC] 本体运行出错: " .. tostring(runErr)) end
            else
                warn("[hate.CC] 本体编译失败: " .. tostring(err))
            end
            pcall(function() if delfile then delfile(tempPath) end end)
        else
            setStatus("主菜单下载失败，请检查网络 / GitHub 仓库是否公开", RED)
            lastFail = tick()
            busy = false
        end
    end

    confirmBtn.MouseButton1Click:Connect(function()
        if busy then return end
        if not failCool() then return end
        local u, p, k = trim(getUser()), getPass(), trim(getKey())
        if mode == "register" then
            local okU, errU = validUser(u)
            if not okU then setStatus(errU, RED) return end
            local okP, errP = validPass(p)
            if not okP then setStatus(errP, RED) return end
            if k == "" then setStatus("注册需填写卡密", RED) return end
            if chlen(k) > KEY_MAX then setStatus("卡密过长（最多" .. KEY_MAX .. "位）", RED) return end
            busy = true
            setStatus("注册中…", nil)
            task.spawn(function()
                if not ensureInit() then setStatus("初始化失败：" .. msg(), RED) lastFail = tick() busy = false return end
                if auth:register(u, p, k) then saveCred(u, p) enterMain()
                else setStatus("注册失败：" .. msg(), RED) lastFail = tick() busy = false end
            end)
        else
            if u == "" or p == "" then setStatus("登录需 用户名+密码", RED) return end
            if chlen(u) > USER_MAX or chlen(p) > PASS_MAX then setStatus("用户名或密码超出长度上限", RED) return end
            busy = true
            setStatus("登录中…", nil)
            task.spawn(function()
                if not ensureInit() then setStatus("初始化失败：" .. msg(), RED) lastFail = tick() busy = false return end
                if auth:login(u, p) then saveCred(u, p) enterMain()
                else setStatus("登录失败：" .. msg(), RED) lastFail = tick() busy = false end
            end)
        end
    end)
end
---------------------------------------------------------------- 全局崩溃日志捕获
local okRun, err = xpcall(Run, function(e)
    local tb = debug.traceback(e)
    pcall(function()
        if writefile then writefile("hate_crash_" .. os.time() .. ".log", tb) end
    end)
    warn("[hate.CC] 发生致命错误，日志已保存至工作目录！")
    return e
end)
if not okRun then
    warn("[hate.CC] 加载器运行出错: " .. tostring(err))
    pcall(function()
        if statusRef then statusRef.Text = "状态：出错 → " .. tostring(err); statusRef.TextColor3 = Color3.fromRGB(255, 120, 120) end
    end)
end
