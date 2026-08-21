--[[
    hate.CC 加载器（KeyAuth 版 · 修复版）
    ⚠ 此源码含你的 Secret，测试完成后必须混淆才能公开！
--]]

---------------------------------------------------------------- 配置区（必改）
local APP_NAME    = "hate.CC"
local OWNER_ID    = "在这里填你的OwnerID"
local APP_SECRET  = "在这里填你的Secret"
local APP_VERSION = "1.0"
-- 混淆后的本体地址（GitHub raw 链接）
local PAYLOAD_URL = "https://raw.githubusercontent.com/你的用户名/你的仓库/main/HateCC.lua"
----------------------------------------------------------------

-- 防重复加载（调试期间如需反复重跑，先注释掉这两行）
if (getgenv and getgenv() or _G).HateCC then return end
(getgenv and getgenv() or _G).HateCC = true

---------------------------------------------------------------- 通用下载（自动兼容各种执行器）
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
    local okHS, hs = pcall(function() return game:GetService("HttpService") end)
    if okHS and hs then
        local ok, r = pcall(function() return hs:GetAsync(url) end)
        if ok and type(r) == "string" and #r > 0 then return r end
    end
    return nil
end

---------------------------------------------------------------- 载入 KeyAuth（带诊断）
if type(loadstring) ~= "function" then
    error("[hate.CC] 当前执行器没有 loadstring，请换支持 loadstring 的执行器")
end

local KeyAuth
for _, api in ipairs({
    "https://keyauth.win/api/1.2/",
    "https://keyauth.win/api/1.3/",
}) do
    local src = fetch(api)
    if not src then
        warn("[hate.CC] 下载失败: " .. api)
    else
        local fn, err = loadstring(src)
        if type(fn) == "function" then
            KeyAuth = fn()
            break
        else
            warn("[hate.CC] 编译失败 " .. api .. ": " .. tostring(err))
            warn("[hate.CC] 内容前80字符: " .. src:sub(1, 80))
        end
    end
end
if not KeyAuth then
    error("[hate.CC] KeyAuth 载入失败，请看上方 warn 输出的具体原因")
end

local auth = KeyAuth:new({
    name = APP_NAME, ownerid = OWNER_ID,
    secret = APP_SECRET, version = APP_VERSION,
})
local function ok()  return auth.success or KeyAuth.success end
local function msg() return tostring(auth.message or KeyAuth.message or "未知错误") end

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
    local okInit = pcall(function() auth:init() end)
    if okInit and ok() then
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
        local callOk, callErr = pcall(function()
            if u == "" and p == "" and k ~= "" then
                auth:license(k)                      -- 只填卡密 → 纯卡密登录
            elseif mode == "register" then
                if u == "" or p == "" or k == "" then
                    setStatus("注册需 用户名+密码+卡密", Color3.fromRGB(255,120,120))
                    busy = false return
                end
                auth:register(u, p, k)               -- 注册
            else
                if u == "" or p == "" then
                    setStatus("登录需 用户名+密码", Color3.fromRGB(255,120,120))
                    busy = false return
                end
                auth:login(u, p)                     -- 登录
            end
        end)

        if not callOk then
            setStatus("调用失败：" .. tostring(callErr), Color3.fromRGB(255, 120, 120))
            busy = false
            return
        end

        if ok() then
            setStatus("验证成功，正在加载…", Color3.fromRGB(120, 220, 120))
            task.wait(0.3)
            gui:Destroy()
            -- 拉取并执行本体
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
