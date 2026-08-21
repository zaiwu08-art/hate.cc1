--[[
    hate.CC 加载器（KeyAuth 直连版）
    ⚠ 此源码含你的 Secret，测试完成后必须混淆才能公开！
--]]

---------------------------------------------------------------- 配置区（必改）
local APP_NAME    = "hate.CC"
local OWNER_ID    = "在这里填你的OwnerID"
local APP_SECRET  = "在这里填你的Secret"
local APP_VERSION = "1.0"
local PAYLOAD_URL = "https://raw.githubusercontent.com/你的用户名/你的仓库/main/HateCC.lua"
----------------------------------------------------------------

-- 防重复加载（调试需反复重跑就先注释这两行）
if (getgenv and getgenv() or _G).HateCC then return end
(getgenv and getgenv() or _G).HateCC = true

local HS = game:GetService("HttpService")

---------------------------------------------------------------- 通用下载
local function fetch(url)
    if type(game) == "table" and type(game.HttpGet) == "function" then
        local ok, r = pcall(function() return game:HttpGet(url) end)
        if ok and type(r) == "string" and #r > 0 then return r end
    end
    local req = (type(request) == "function" and request)
        or (type(http_request) == "function" and http_request)
        or (type(syn) == "table" and syn.request)
        or (type(http) == "table" and http.request)
    if type(req) == "function" then
        local ok, r = pcall(req, { Url = url, Method = "GET" })
        if ok and r and type(r.Body) == "string" and #r.Body > 0 then return r.Body end
    end
    return nil
end

---------------------------------------------------------------- 设备标识
local HWID = ""
pcall(function()
    if type(gethwid) == "function" then HWID = tostring(gethwid())
    elseif type(identifyexecutor) == "function" then HWID = tostring(identifyexecutor()) end
end)
if HWID == "" then HWID = "user-" .. tostring(game:GetService("Players").LocalPlayer.UserId) end

---------------------------------------------------------------- KeyAuth 直连客户端
local auth = { success = false, message = "", sessionid = nil }

local function api(params)
    params.ownerid = OWNER_ID
    params.name    = APP_NAME
    params.ver     = APP_VERSION
    params.secret  = APP_SECRET
    params.hwid    = HWID
    if auth.sessionid then params.sessionid = auth.sessionid end
    local qs = {}
    for k, v in pairs(params) do
        qs[#qs + 1] = k .. "=" .. HS:UrlEncode(tostring(v))
    end
    local body = fetch("https://keyauth.win/api/1.2/?" .. table.concat(qs, "&"))
    if not body then
        return { success = false, message = "网络失败，无法访问 keyauth.win" }
    end
    local ok, json = pcall(function() return HS:JSONDecode(body) end)
    if not ok or type(json) ~= "table" then
        return { success = false, message = "响应非JSON（后台若开了加密请关闭）: " .. tostring(body):sub(1, 60) }
    end
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
    return self.success
end
function auth:register(u, p, k)
    local r = api({ type = "register", username = u, pass = p, key = k })
    self.success, self.message = (r.success == true), tostring(r.message or "")
    return self.success
end
function auth:license(k)
    local r = api({ type = "license", key = k })
    self.success, self.message = (r.success == true), tostring(r.message or "")
    return self.success
end

local function ok()  return auth.success end
local function msg() return auth.message end
-- ===== 第1段 结尾标记 =====
---------------------------------------------------------------- 界面
local Players = game:GetService("Players")
local UIS     = game:GetService("UserInputService")

local gui = Instance.new("ScreenGui")
gui.Name = "HateCCUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end

local function make(cls, props, parent)
    local o = Instance.new(cls)
    for k, v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end
local function trim(s) return s:match("^%s*(.-)%s*$") end

local main = make("Frame", {
    Size = UDim2.fromOffset(340, 270),
    Position = UDim2.fromScale(0.5, 0.5),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Color3.fromRGB(25, 25, 30),
    BorderSizePixel = 0,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 10) }, main)
make("UIStroke", { Color = Color3.fromRGB(60, 60, 70) }, main)

local title = make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 36),
    BackgroundColor3 = Color3.fromRGB(35, 35, 42),
    BorderSizePixel = 0,
    Text = "hate.CC | 加载器",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold, TextSize = 15,
}, main)
make("UICorner", { CornerRadius = UDim.new(0, 10) }, title)

local status = make("TextLabel", {
    Size = UDim2.new(1, -20, 0, 20),
    Position = UDim2.new(0, 10, 0, 40),
    BackgroundTransparency = 1,
    Text = "状态：初始化中…",
    TextColor3 = Color3.fromRGB(160, 160, 160),
    Font = Enum.Font.Gotham, TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
}, main)

local function makeBox(ph, isPass, y)
    local b = make("TextBox", {
        Size = UDim2.new(1, -20, 0, 34),
        Position = UDim2.new(0, 10, 0, y),
        BackgroundColor3 = Color3.fromRGB(40, 40, 48),
        BorderSizePixel = 0,
        PlaceholderText = ph,
        PlaceholderColor3 = Color3.fromRGB(120, 120, 120),
        Text = "", TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.Gotham, TextSize = 14,
        ClearTextOnFocus = false,
    }, main)
    b.Password = isPass
    make("UICorner", { CornerRadius = UDim.new(0, 8) }, b)
    make("UIPadding", { PaddingLeft = UDim.new(0, 10) }, b)
    return b
end

local userBox = makeBox("用户名", false, 66)
local passBox = makeBox("密码", true, 106)
local keyBox  = makeBox("卡密（注册必填）", false, 146)

local mode = "login"
local modeBtn = make("TextButton", {
    Size = UDim2.new(1, -20, 0, 26),
    Position = UDim2.new(0, 10, 0, 186),
    BackgroundColor3 = Color3.fromRGB(40, 40, 48),
    BorderSizePixel = 0,
    Text = "当前模式：登录（点击切换为注册）",
    TextColor3 = Color3.fromRGB(180, 180, 180),
    Font = Enum.Font.Gotham, TextSize = 12,
}, main)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, modeBtn)

local confirmBtn = make("TextButton", {
    Size = UDim2.new(0.5, -15, 0, 36),
    Position = UDim2.new(0, 10, 0, 220),
    BackgroundColor3 = Color3.fromRGB(0, 122, 255),
    BorderSizePixel = 0,
    Text = "确 定", TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold, TextSize = 15,
}, main)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, confirmBtn)

local cancelBtn = make("TextButton", {
    Size = UDim2.new(0.5, -15, 0, 36),
    Position = UDim2.new(0.5, 5, 0, 220),
    BackgroundColor3 = Color3.fromRGB(70, 70, 80),
    BorderSizePixel = 0,
    Text = "取 消", TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold, TextSize = 15,
}, main)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, cancelBtn)
-- ===== 第2段 结尾标记 =====
---------------------------------------------------------------- 逻辑
local function setStatus(t, c)
    status.Text = "状态：" .. t
    status.TextColor3 = c or Color3.fromRGB(160, 160, 160)
end

-- 窗口拖动
local dragging, dragStart, startPos = false, nil, nil
title.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging, dragStart, startPos = true, i.Position, main.Position
    end
end)
title.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
UIS.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - dragStart
        main.Position = startPos + UDim2.fromOffset(d.X, d.Y)
    end
end)

modeBtn.MouseButton1Click:Connect(function()
    if mode == "login" then
        mode = "register"
        modeBtn.Text = "当前模式：注册（点击切换为登录）"
    else
        mode = "login"
        modeBtn.Text = "当前模式：登录（点击切换为注册）"
    end
end)

cancelBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

-- 初始化 KeyAuth
task.spawn(function()
    if auth:init() then
        setStatus("初始化成功，请登录 / 注册", Color3.fromRGB(120, 220, 120))
    else
        setStatus("初始化失败：" .. msg(), Color3.fromRGB(255, 120, 120))
    end
end)

local busy = false
confirmBtn.MouseButton1Click:Connect(function()
    if busy then return end
    busy = true
    local u, p, k = trim(userBox.Text), passBox.Text, trim(keyBox.Text)

    task.spawn(function()
        if u == "" and p == "" and k ~= "" then
            auth:license(k)
        elseif mode == "register" then
            if u == "" or p == "" or k == "" then
                setStatus("注册需 用户名+密码+卡密", Color3.fromRGB(255,120,120))
                busy = false return
            end
            auth:register(u, p, k)
        else
            if u == "" or p == "" then
                setStatus("登录需 用户名+密码", Color3.fromRGB(255,120,120))
                busy = false return
            end
            auth:login(u, p)
        end

        if ok() then
            setStatus("验证成功，正在加载…", Color3.fromRGB(120, 220, 120))
            task.wait(0.3)
            gui:Destroy()
            local src = fetch(PAYLOAD_URL)
            if type(src) == "string" and #src > 0 then
                local fn, err = loadstring(src)
                if type(fn) == "function" then
                    fn()
                else
                    warn("[hate.CC] 本体编译失败: " .. tostring(err))
                end
            else
                warn("[hate.CC] 本体下载失败: " .. PAYLOAD_URL)
            end
        else
            setStatus(msg(), Color3.fromRGB(255, 120, 120))
            busy = false
        end
    end)
end)
