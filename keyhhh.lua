--[[
    hate.CC 加载器（KeyAuth 版）
    ⚠ 此源码含你的 Secret，测试完后必须混淆才能公开！
--]]

---------------------------------------------------------------- 配置区（必改）
local KEYAUTH_API = "https://keyauth.win/api/1.2/"   -- 若官方更新版本以文档为准
local APP_NAME    = "hate.CC"
local OWNER_ID    = "RXOyhCyuBv"
local APP_SECRET  = "8623874dafddb49f0915f6d709f5f2a3e84093c88b1ca9f03a56a9abe4b6a5fa"
local APP_VERSION = "1.0"
-- 混淆后的本体地址（上一轮你搭好的 GitHub raw 链接）
local PAYLOAD_URL = "https://github.com/zaiwu08-art/hate.cc1/blob/main/yeahhhh"
----------------------------------------------------------------

-- 防重复加载（测试时若想重跑，重新执行整个脚本前注意此标记）
if (getgenv and getgenv() or _G).MoonLoader then return end
(getgenv and getgenv() or _G).MoonLoader = true

-- 载入 KeyAuth
local KeyAuth = loadstring(game:HttpGet(KEYAUTH_API))()
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
gui.Name = "MoonLoaderUI"
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
    Text = "MoonGui | 加载器",
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
local passBox = makeBox("密码",   true,  106)
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
    Text = "确 定", TextColor3 = Color3.fromRGB(255,255,255),
    Font = Enum.Font.GothamBold, TextSize = 15,
}, main)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, confirmBtn)

local cancelBtn = make("TextButton", {
    Size = UDim2.new(0.5, -15, 0, 36),
    Position = UDim2.new(0.5, 5, 0, 220),
    BackgroundColor3 = Color3.fromRGB(70, 70, 80),
    BorderSizePixel = 0,
    Text = "取 消", TextColor3 = Color3.fromRGB(255,255,255),
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
        -- 只填卡密 → 纯卡密登录；否则按模式 注册/登录
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
            -- 拉取并执行本体
            local got, src = pcall(function() return game:HttpGet(PAYLOAD_URL) end)
            if got and type(src) == "string" and #src > 0 then
                local fn = loadstring(src)
                if fn then fn() end
            end
        else
            setStatus(msg(), Color3.fromRGB(255, 120, 120))
            busy = false
        end
    end)
end)