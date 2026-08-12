



-- ═══════════════════════════════════════════════════════════════
-- 🛡️ VENOZ NO-SB  ·  BUILD v4.0   (ต่อยอดจาก titan_noshadowban ตัวที่รอด)
-- ═══════════════════════════════════════════════════════════════
--  แก้จากตัวเดิม 3 อย่าง:
--   1️⃣ RETRY  : 15 ครั้ง/1.5 วิ  →  "กดครั้งเดียว" หลังรอนิ่ง 3 วิ
--   2️⃣ SPEED  : ตัด task.wait(8) + waits ยิบย่อย → เข้าด่านปุ๊บฟาร์มเลย
--   3️⃣ SLIM   : ตัดโค้ดที่ไม่ได้ใช้ทิ้ง 2,749 บรรทัด (Trade/Spin/Family/Webhook)
--   4️⃣ ⬛ANTI-LAG : ปิด render 3D ทุกที่ + กราฟิกต่ำสุด + ปิด particle/เสียง
--   5️⃣ 🔇CHAT  : ปิดช่องแชทถาวร (CoreGui + TextChatService + ScreenGui เก่า)
--   6️⃣ ⏳LOAD  : ไม่ปิด render ตอนหน้า LOADING ยังอยู่ + ค้างเกิน 30 วิซ่อนทิ้ง
--   7️⃣ ⚙️UPGRADE: _VZChoreWait ค้างข้าม teleport → brain ไม่รองาน lobby
--                 = ดาบไม่เคยถูกอัพตั้งแต่รอบ 2 (ฟาร์มช้าเพราะดาบพังบ่อย)
--  ถ้าไม่เห็น 4 บรรทัดนี้ใน F9 = ยังรันโค้ดตัวเก่าอยู่ ให้ paste ไฟล์ใหม่ทับ
-- ═══════════════════════════════════════════════════════════════
print("═══════════════════════════════════════════════")
print("🛡️ VENOZ NO-SB — BUILD v4.3")
print("   🔁 RETRY กดครั้งเดียว (รอนิ่ง 3 วิก่อนกด)")
print("   ⚡ เข้าด่าน = ฟาร์มทันที ไม่รอโหลดอะไรทั้งนั้น")
print("   ⬛ จอว่างทุกที่ (Main Menu + Lobby + ในด่าน) + ปิดแชทถาวร")
print("   ⏳ แก้ค้างจอ LOADING ตอนกดออกจากด่าน")
print("   ⚙️ แก้บั๊ก: อัพเกรดดาบไม่ทำงานตั้งแต่รอบที่ 2 เป็นต้นไป")
print("   🗑️ ตัดโค้ดไม่ใช้ทิ้ง 2,749 บรรทัด")
print("═══════════════════════════════════════════════")
getgenv().VenozBuild = "v4.3-nosb"

-- ระบบเช็คสถานะ GUI และ Auto Teleport เมื่อผิดปกติ
task.spawn(function()
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    if not player then return end

    local placeId = game.PlaceId
    if placeId ~= 14916516914 then return end 

    local playerGui = player:WaitForChild("PlayerGui", 10)
    if not playerGui then return end


    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local remote = ReplicatedStorage:FindFirstChild("Assets") 
        and ReplicatedStorage.Assets:FindFirstChild("Remotes") 
        and ReplicatedStorage.Assets.Remotes:FindFirstChild("POST")
    
    if not remote then

        -- [FIX] บั๊กของ UI2: เรียก checkAnyVisible() ก่อนที่ฟังก์ชันจะถูกประกาศ → error
        --   ครอบ pcall + เช็คว่ามีจริงก่อนเรียก
        local TeleportService = game:GetService("TeleportService")
        pcall(function()
            local fn = rawget(getfenv(), "checkAnyVisible")
            if type(fn) ~= "function" then return end
            if not fn() then
                task.wait(10)
                if not fn() then
                    pcall(function() TeleportService:Teleport(13379208636, player) end)
                end
            end
        end)
        return
    end

    local function IsActuallyVisible(gui)
        if not gui or not gui:IsA("GuiObject") then return false end
        if not gui.Visible then return false end
        local current = gui.Parent
        while current do
            if current:IsA("GuiObject") and not current.Visible then return false end
            if current:IsA("ScreenGui") and not current.Enabled then return false end
            current = current.Parent
        end
        return true
    end

    local function GetGuiByPath(root, pathSegments)
        local current = root
        for _, segment in ipairs(pathSegments) do
            if current then
                current = current:FindFirstChild(segment)
            else
                break
            end
        end
        return current
    end

    local targets = {
        { path = {"Interface", "Gear_Up", "Lobby", "Backing"} },
        { path = {"Interface", "Topbar", "Main", "Categories", "Inventory"} }
    }

    local function checkAnyVisible()
        for _, target in ipairs(targets) do
            local gui = GetGuiByPath(playerGui, target.path)
            if gui and IsActuallyVisible(gui) then
                return true
            end
        end
        return false
    end
    if not checkAnyVisible() then
        task.wait(10)
        if not checkAnyVisible() then

            pcall(function()
                remote:FireServer("Functions", "Teleport", "Menu", nil)
            end)
        end
    end
end)


-- ⚡ [SPEED] รอเท่าที่ "จำเป็นจริงๆ" เท่านั้น — ตัด task.wait(1) ท้ายบล็อกทิ้ง
--    (1 วินาทีนั้นคือเวลาที่ไททันเดินมาถึงตัวเราพอดี)
repeat task.wait() until game:IsLoaded()
repeat task.wait() until game:GetService("Players").LocalPlayer
repeat task.wait() until game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
repeat task.wait() until game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Interface")

-- ระบบ AFK 
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local VirtualUser = game:GetService("VirtualUser")

local currentCamera = game.Workspace.CurrentCamera

player.Idled:Connect(function()
	VirtualUser:Button2Down(Vector2.zero, currentCamera.CFrame)
	task.wait(1)
	VirtualUser:Button2Up(Vector2.zero, currentCamera.CFrame)
end)
----------------------------------------------------------------------

-- ═══════════════════════════════════════════════════════════════
-- 🚫 HEADLESS UI SHIM — ไม่มีหน้าต่าง ไม่โหลด library จากเน็ต
-- ═══════════════════════════════════════════════════════════════
--   แทน LinoriaLib ด้วยของปลอมที่เก็บค่า + เรียก Callback เหมือนกันเป๊ะ
--   → logic ทุกอย่างของสคริปเดิมทำงานครบ แต่ไม่สร้าง GUI ให้เปลืองแรม/ไม่มีปุ่มให้กด
--   → auto-pilot สั่ง SetValue() = เหมือนคนกดปุ่มจริง
-- ═══════════════════════════════════════════════════════════════
local Library, ThemeManager, SaveManager
do
    local noop = function() end
    local anyMethod = { __index = function() return noop end }

    getgenv().Toggles = {}
    getgenv().Options = {}
    local Toggles, Options = getgenv().Toggles, getgenv().Options

    local function fire(cb, v)
        if type(cb) == "function" then
            local ok, err = pcall(cb, v)
            if not ok then warn("[UI-SHIM] callback error: " .. tostring(err)) end
        end
    end

    local function makeElement(name, opts, store)
        local e = setmetatable({}, anyMethod)
        opts = opts or {}
        e.Value   = opts.Default
        e.Values  = opts.Values
        e.Text    = opts.Text
        e.Type    = opts.Type
        e.Visible = true
        function e:SetValue(v)
            self.Value = v
            fire(opts.Callback, v)
            return self
        end
        function e:SetValues(list) self.Values = list return self end
        function e:SetText(t) self.Text = t return self end
        function e:OnChanged(f) opts.Callback = f return self end
        function e:AddKeyPicker() return setmetatable({}, anyMethod) end
        if name and store then store[name] = e end
        return e
    end

    local Groupbox = {}
    Groupbox.__index = function(t, k)
        return rawget(Groupbox, k) or noop
    end
    function Groupbox.new()
        return setmetatable({}, Groupbox)
    end
    function Groupbox:AddToggle(n, o)   o = o or {}; o.Type = "Toggle";   return makeElement(n, o, getgenv().Toggles) end
    function Groupbox:AddSlider(n, o)   o = o or {}; o.Type = "Slider";   return makeElement(n, o, getgenv().Options) end
    function Groupbox:AddDropdown(n, o) o = o or {}; o.Type = "Dropdown"; return makeElement(n, o, getgenv().Options) end
    function Groupbox:AddInput(n, o)    o = o or {}; o.Type = "Input";    return makeElement(n, o, getgenv().Options) end
    function Groupbox:AddButton(a, b)
        local e = setmetatable({}, anyMethod)
        e.Func = (type(a) == "function") and a or b
        function e:DoClick() fire(self.Func) end
        return e
    end
    function Groupbox:AddLabel(txt) local e = setmetatable({}, anyMethod); e.Text = txt
        function e:SetText(t) self.Text = t return self end
        return e end
    function Groupbox:AddDivider() return setmetatable({}, anyMethod) end

    local Tabbox = {}
    Tabbox.__index = Tabbox
    function Tabbox:AddTab() return Groupbox.new() end

    local Tab = {}
    Tab.__index = Tab
    function Tab:AddLeftGroupbox()  return Groupbox.new() end
    function Tab:AddRightGroupbox() return Groupbox.new() end
    function Tab:AddLeftTabbox()    return setmetatable({}, Tabbox) end
    function Tab:AddRightTabbox()   return setmetatable({}, Tabbox) end

    Library = setmetatable({
        Toggled = true,
        ToggleKeybind = nil,
        -- Holder.Visible = true เสมอ (โค้ดเขามีลูปรอค่านี้ ถ้า false จะค้าง)
        Holder = { Visible = true, Enabled = true,
                   Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(0, 400, 0, 500) },
    }, anyMethod)
    function Library:CreateWindow()
        local w = setmetatable({ Holder = self.Holder }, anyMethod)
        function w:AddTab() return setmetatable({}, Tab) end
        return w
    end
    function Library:Notify(msg)
        local c = getgenv().VenozChicken
        if not (c and c.SilentNotify) then print("[UI2] " .. tostring(msg)) end
    end
    function Library:Toggle() end
    function Library:Unload() end

    ThemeManager = setmetatable({}, anyMethod)
    SaveManager  = setmetatable({}, anyMethod)
end

-- ═══════════════════════════════════════════════════════════════
-- 🚦 ธง "สคริปโหลดครบแล้ว" (แทน task.wait(8) แบบเดาสุ่ม)
-- ═══════════════════════════════════════════════════════════════
--   ทำไมต้องมี: ปุ่ม AutoFarmBlade เรียก CreateFarmLoop() ซึ่งเป็นตัวแปร global
--   ที่ถูกประกาศ "ท้ายไฟล์" ถ้าเปิดฟาร์มก่อนถึงบรรทัดนั้น = CreateFarmLoop เป็น nil
--   = ตัวยืนนิ่งไม่ฟาร์ม (บั๊กที่เคยเจอ) → เลยต้องรอ "โหลดครบ" จริงๆ ไม่ใช่รอ 8 วิ
--   ⚠️ ต้องเซ็ต false ทุกครั้งที่รัน เพราะ getgenv ค้างข้ามการ teleport
getgenv().VenozScriptReady = false
getgenv().VenozPressing    = 0   -- ⚠️ ต้องรีเซ็ตด้วย ไม่งั้นค้างข้าม teleport = ปิดจอไม่ลง
-- 🐛 [FIX] ตัวนับ "รองาน lobby" ก็ค้างข้าม teleport เหมือนกัน
--    เดิมไม่มีใครรีเซ็ต → เข้า lobby รอบที่ 2 ค่านี้เต็ม (>12) อยู่แล้ว
--    → brain เลยข้ามการรอทันที = อัพดาบ/สกิล ยังไม่ทันเริ่มก็โดนลากเข้าด่านแล้ว
--    = ดาบไม่เคยถูกอัพเลยตั้งแต่รอบที่ 2 เป็นต้นไป (ฟาร์มช้าเพราะดาบพังบ่อย)
getgenv()._VZChoreWait     = 0

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local VIM = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

pcall(function()
    UserInputService.MouseIconEnabled = true
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end)
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local Assets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")
local POST = Assets:WaitForChild("POST")
local GET = Assets:WaitForChild("GET")

local function SafeInvoke(remote, ...)
    local args = {...}
    local maxRetries = 3
    local attempt = 0
    while attempt < maxRetries do
        attempt = attempt + 1
        local success, result = pcall(function()
            return remote:InvokeServer(unpack(args))
        end)
        if success then
            return true, result
        end
        if attempt < maxRetries then
            local delay = 0.3 * (2 ^ (attempt - 1))
            task.wait(delay)
        end
    end
    return false, nil
end

local function SafeFire(remote, ...)
    local args = {...}
    local success = pcall(function()
        remote:FireServer(unpack(args))
    end)
    return success
end

getgenv().SafeInvoke = SafeInvoke
getgenv().SafeFire = SafeFire

-- ═══════════════════════════════════════════════════════════════
-- 🐔 CHICKEN MODE — ทำระบบตีของสคริปนี้ให้ "เนียน" (กัน shadow ban)
-- ═══════════════════════════════════════════════════════════════
--   ของเดิม: Register(nape, 99999, 0) ทุก 0.05 วิ × หลายตัวพร้อมกัน
--            = ความเร็วเป็นไปไม่ได้จริง + ค่าคงที่เป๊ะ + rate สูง → โดนจับ
--   โหมดไก่: ความเร็วสุ่มสมจริง 126-384 + Time_Difference สุ่ม + ตีห่างขึ้น + จำกัดจำนวนตัว
--   ปิดโหมดไก่ (กลับเป็นของเดิมเป๊ะ): getgenv().VenozChicken.Enabled = false
-- ═══════════════════════════════════════════════════════════════
getgenv().VenozChicken = getgenv().VenozChicken or {}
local VZC = getgenv().VenozChicken
if VZC.Enabled == nil then VZC.Enabled = true end
VZC.AttackInterval = tonumber(VZC.AttackInterval) or 1
VZC.HitCap         = tonumber(VZC.HitCap)         or 3
VZC.SpearInterval  = tonumber(VZC.SpearInterval)  or 2
VZC.HitRange       = tonumber(VZC.HitRange)       or 200   -- ระยะสูงสุดที่ยอมให้ register (studs)
VZC.ArriveRadius   = tonumber(VZC.ArriveRadius)   or 45    -- ⭐ เข้าใกล้จุดเหนือหัวไททันไม่เกินนี้ = "ถึงแล้ว"
VZC.SettleTime     = tonumber(VZC.SettleTime)     or 1     -- ⭐ ถึงแล้วต้องนิ่งกี่วิก่อนเริ่มฟัน
if VZC.DiveImpulse == nil then VZC.DiveImpulse = true end   -- 💨 พุ่งเข้าหาคอก่อนฟัน (ให้มีความเร็วจริง)
VZC.DiveSpeed      = tonumber(VZC.DiveSpeed)      or 320
-- 💥 ONE-SHOT บังคับเสมอ — ห้ามฟันติดธรรมดาเด็ดขาด
--    เลข velocity ที่ส่ง = ตัวคูณดาเมจ → ต้องสูงพอตัดคอตายทีเดียวทุกครั้ง
--    ส่งเป็น "ช่วงสุ่ม" ไม่ใช่ค่าคงที่ 99999 → ผลเหมือนกันแต่ไม่มีเลขซ้ำให้จับ pattern
--    + ถ้าเจอตัวที่ไม่ตายในทีเดียว จะเพิ่มแรงให้อัตโนมัติจนตัดคอได้
VZC.KillVelMin     = tonumber(VZC.KillVelMin)     or 99999
VZC.KillVelMax     = tonumber(VZC.KillVelMax)     or 99999
VZC.VelBoost       = tonumber(VZC.VelBoost)       or 1

-- 💥 ตัดคอทีเดียวตายเท่านั้น (ไม่มีโหมดฟันธรรมดาแล้ว)
function VZC.Vel()
    if not VZC.Enabled then return 99999 end
    local boost = math.clamp(tonumber(VZC.VelBoost) or 1, 1, 40)
    local lo = (VZC.KillVelMin or 99999) * boost
    local hi = (VZC.KillVelMax or 99999) * boost
    return lo + math.random() * (hi - lo)
end
-- เจอตัวที่ฟันแล้วไม่ตาย → เพิ่มแรงอัตโนมัติจนกว่าจะตัดคอได้ทีเดียว
function VZC.Escalate()
    local old = tonumber(VZC.VelBoost) or 1
    VZC.VelBoost = math.min(old * 1.8, 40)
    if VZC.VelBoost > old then
        warn(string.format("[CHICKEN] ⚠️ ฟันแล้วไม่ตาย → เพิ่มแรงเป็น x%.1f (%.0f-%.0f)",
            VZC.VelBoost, (VZC.KillVelMin or 99999) * VZC.VelBoost, (VZC.KillVelMax or 99999) * VZC.VelBoost))
    end
end
-- ⏱️ Time_Difference — ต้องส่ง 0 เป๊ะเหมือน UI2
--   ถ้าส่งค่าอื่น server จะคำนวณความเร็วใหม่จาก td แล้วหั่นดาเมจ (ได้ 359/1032 แทนที่จะตัดคอ)
function VZC.TD()
    return tonumber(VZC.HitTD) or 0
end
function VZC.Gap(base)
    base = base or VZC.AttackInterval
    if not VZC.Enabled then return 0.05 end
    return base * (0.85 + math.random() * 0.3)
end
function VZC.Cap(n)
    if not VZC.Enabled then return n or 9 end
    return math.min(n or 1, VZC.HitCap)
end

local ErrorLog = {}
local MaxLogEntries = 50
local function LogError(category, message)
end
getgenv().PrintErrorLog = function()
end
getgenv().LogError = LogError

local LastServerResponse = tick()
task.spawn(function()
    while task.wait(15) do
        pcall(function() if Player and Player.Parent == Players then LastServerResponse = tick() end end)
    end
end)

task.spawn(function()
    pcall(function()
        Player.Idled:Connect(function()
            pcall(function()
                VIM:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                task.wait(1)
                VIM:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
            end)
        end)
    end)
end)

task.spawn(function()
    while task.wait(300) do
        pcall(function()
            local ok, memBefore = pcall(gcinfo)
            collectgarbage("collect")
            local ok2, memAfter = pcall(gcinfo)
        end)
    end
end)

local LastGlobalHeartbeat = tick()
task.spawn(function()
    local watchConn = RunService.Heartbeat:Connect(function() LastGlobalHeartbeat = tick() end)
    while task.wait(10) do
        pcall(function()
            local elapsed = tick() - LastGlobalHeartbeat
            if elapsed > 15 then
                if watchConn then pcall(function() watchConn:Disconnect() end) end
                watchConn = RunService.Heartbeat:Connect(function() LastGlobalHeartbeat = tick() end)
            end
        end)
    end
end)

local PlaceId = game.PlaceId
local MAIN_MENU_ID = 13379208636
local LOBBY_ID = 14916516914
local TRADE_LOBBY_ID = 14932214603

local function IsMainmenuLobby() return PlaceId == MAIN_MENU_ID end
local function IsLobbyLobby() return PlaceId == LOBBY_ID or PlaceId == TRADE_LOBBY_ID end
local function IsIngameLobby() return not IsMainmenuLobby() and not IsLobbyLobby() end

-- ═══════════════════════════════════════════════════════════════
-- 🖱️ VENOZ PRESS — กดปุ่ม GUI แบบ "คลิกเมาส์จริง"
-- ═══════════════════════════════════════════════════════════════
--   🐛 ของ UI2 ใช้ GuiService.SelectedObject + ส่งปุ่ม Enter
--      → ปุ่ม RETRY ของเกม "ไม่รับ" วิธีนี้เลย ค้างที่ (0/1) ตลอด
--      → ลองยิง getconnections(MouseButton1Click):Fire() ก็ไม่ติดเหมือนกัน
--   ✅ ที่ทดสอบกับเกมจริงแล้วติด: VirtualInputManager ส่ง "เมาส์ move + คลิก"
--      ที่พิกัดจริงของปุ่ม และต้องบวก GuiInset.Y ด้วย ไม่งั้นคลิกพลาดตำแหน่ง
--      ผลทดสอบ: "RETRY (0/1)" → "STARTING (4s)" ทันที
-- ═══════════════════════════════════════════════════════════════
local function VenozVisible(gui)
    if not (gui and gui.Parent) then return false end
    local o = gui
    while o and o ~= game do
        if o:IsA("GuiObject") and not o.Visible then return false end
        if o:IsA("ScreenGui") and not o.Enabled then return false end
        o = o.Parent
    end
    return true
end

-- ⬛ สลับ render 3D (ใช้ร่วมกันทั้งสคริป)
local function Venoz3D(on)
    pcall(function() game:GetService("RunService"):Set3dRenderingEnabled(on and true or false) end)
end
local function Venoz3DIsOn()
    local ok, v = pcall(function()
        local RS = game:GetService("RunService")
        if RS.Is3dRenderingEnabled then return RS:Is3dRenderingEnabled() end
        return true
    end)
    return (not ok) or v
end
getgenv().Venoz3D = Venoz3D

local function VenozPress(btn)
    if not (btn and btn.Parent and btn:IsA("GuiObject")) then return false end
    if not VenozVisible(btn) then return false end

    -- ⬛ ตอนปิด render 3D อยู่ เกมจะไม่คิด hit-test ของ GUI → คลิกไม่โดน
    --    เลยต้อง "เปิดคืนชั่วคราว" เฉพาะตอนกด แล้วปิดกลับทันทีที่เสร็จ
    --    + ซ่อนป้ายสถานะของเราไว้ก่อน กันมันบังปุ่ม
    -- 🔒 บอกลูป anti-lag ว่า "กำลังกดปุ่มอยู่ อย่าเพิ่งปิด render"
    --    ไม่งั้นลูป 10 วิอาจปิด 3D กลางคันพอดี → คลิกพลาด
    getgenv().VenozPressing = (tonumber(getgenv().VenozPressing) or 0) + 1
    local re3d = false
    if not Venoz3DIsOn() then Venoz3D(true) re3d = true end
    local hidden = {}
    pcall(function()
        local roots = {}
        local okc, cg = pcall(function() return game:GetService("CoreGui") end)
        if okc and cg then table.insert(roots, cg) end
        local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
        if pg then table.insert(roots, pg) end
        if typeof(gethui) == "function" then table.insert(roots, gethui()) end
        for _, root in ipairs(roots) do
            for _, v in ipairs(root:GetChildren()) do
                if v:IsA("ScreenGui") and v.Enabled
                    and (v.Name == "VenozChickenStatus" or v.Name == "VenozTracker"
                         or v.Name == "TownShipPlayerStats") then
                    v.Enabled = false
                    table.insert(hidden, v)
                end
            end
        end
    end)
    local function restore()
        for _, v in ipairs(hidden) do pcall(function() v.Enabled = true end) end
        if re3d then Venoz3D(false) end
        getgenv().VenozPressing = math.max(0, (tonumber(getgenv().VenozPressing) or 1) - 1)
    end

    local ok = pcall(function()
        local VIM = game:GetService("VirtualInputManager")
        local inset = game:GetService("GuiService"):GetGuiInset()
        task.wait(0.05)                      -- ให้ layout อัปเดตหลังซ่อน GUI
        local p, s = btn.AbsolutePosition, btn.AbsoluteSize
        if s.X <= 0 or s.Y <= 0 then error("ปุ่มขนาด 0") end
        local x = p.X + s.X / 2
        local y = p.Y + s.Y / 2 + inset.Y
        VIM:SendMouseMoveEvent(x, y, game)
        task.wait(0.12)
        VIM:SendMouseButtonEvent(x, y, 0, true, game, false)
        task.wait(0.06)
        VIM:SendMouseButtonEvent(x, y, 0, false, game, false)
    end)
    restore()
    if ok then return true end
    -- สำรอง 1: ยิง handler ของปุ่มตรงๆ
    if type(getconnections) == "function" then
        pcall(function()
            for _, c in ipairs(getconnections(btn.MouseButton1Click)) do
                pcall(function() c:Fire() end)
            end
        end)
    end
    -- สำรอง 2: วิธีเดิมของ UI2 (เผื่อบางปุ่มรับ)
    pcall(function()
        local GS, VIM = game:GetService("GuiService"), game:GetService("VirtualInputManager")
        GS.SelectedObject = btn
        task.wait(0.05)
        VIM:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        task.wait(0.05)
        VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
        GS.SelectedObject = nil
    end)
    return false
end
getgenv().VenozPress = VenozPress

-- อ่านข้อความบนปุ่ม (ปุ่มบางอันเก็บ text ไว้ที่ TextLabel ลูก)
local function VenozBtnText(btn)
    local t = ""
    pcall(function()
        local tl = btn:FindFirstChildWhichIsA("TextLabel", true)
        t = string.upper(tostring((tl and tl.Text) or (btn:IsA("TextButton") and btn.Text) or ""))
    end)
    return t
end
getgenv().VenozBtnText = VenozBtnText

-- ═══════════════════════════════════════════════════════════════
-- 🔇 ปิดช่องแชทถาวร
-- ═══════════════════════════════════════════════════════════════
--   ปิดครบทั้ง 3 ระบบ (เกมอาจใช้อันไหนก็ได้ แล้วแต่เวอร์ชัน):
--     1) CoreGui Chat        — ระบบแชทมาตรฐาน
--     2) TextChatService     — แชทตัวใหม่ (หน้าต่าง + ช่องพิมพ์ + bubble)
--     3) ScreenGui ชื่อ Chat — แชทแบบเก่าใน PlayerGui/CoreGui
--   เฝ้าซ้ำทุก 5 วิ เผื่อเกมเปิดคืนเองตอนเปลี่ยนแมพ
--   ปิดระบบนี้: getgenv().VenozChicken.DisableChat = false
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    if (getgenv().VenozChicken or {}).DisableChat == false then return end

    local function killChat()
        pcall(function()
            game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
        end)
        pcall(function()
            local TCS = game:GetService("TextChatService")
            if TCS.ChatWindowConfiguration   then TCS.ChatWindowConfiguration.Enabled   = false end
            if TCS.ChatInputBarConfiguration then TCS.ChatInputBarConfiguration.Enabled = false end
            if TCS.BubbleChatConfiguration   then TCS.BubbleChatConfiguration.Enabled   = false end
        end)
        pcall(function()
            local plrC = game:GetService("Players").LocalPlayer
            local roots = { plrC:FindFirstChild("PlayerGui") }
            local okc, cg = pcall(function() return game:GetService("CoreGui") end)
            if okc and cg then table.insert(roots, cg) end
            for _, root in ipairs(roots) do
                if root then
                    for _, v in ipairs(root:GetChildren()) do
                        if v:IsA("ScreenGui") and v.Name:lower():find("chat") and v.Enabled then
                            v.Enabled = false
                        end
                    end
                end
            end
        end)
    end

    killChat()
    print("[CHAT] 🔇 ปิดช่องแชทแล้ว (กันคลิก/คีย์หลุดไปโดนแชทหรือ popup ยืนยัน)")
    while true do
        task.wait(5)
        killChat()
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- ⬛ VENOZ ANTI-LAG — จอขาว/ว่างทุกที่ (Main Menu + Lobby + ในด่าน)
-- ═══════════════════════════════════════════════════════════════
--   ⭐ Set3dRenderingEnabled(false) = "ไม่วาดภาพ 3D" เฉยๆ
--      ของในเกมยังอยู่ครบทุกชิ้น → ฟาร์ม/ตี/จบด่าน ทำงานปกติ 100%
--      ประหยัด CPU/GPU แรงที่สุด และปลอดภัยกว่า "ลบแมพ" มาก
--   🖱️ ตอนกดปุ่ม VenozPress จะเปิด render คืนให้เองชั่วคราว แล้วปิดกลับ
--      (RETRY / LEAVE / ปุ่มใน lobby ยังกดติดปกติ)
--   🔁 ย้ำซ้ำทุก 10 วิ เผื่อเกมเปิด render คืนตอนเปลี่ยนแมพ/เกิดใหม่
--   ปิด: getgenv().VenozChicken.AntiLag = false
--   อยากเห็นภาพเกมตอนดีบัก: getgenv().VenozChicken.Disable3D = false
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    local VZa = getgenv().VenozChicken or {}
    if VZa.AntiLag == false then return end

    local Lighting = game:GetService("Lighting")

    -- ── กราฟิกต่ำสุด (ทำได้ทุกที่ ไม่มีผลกับ logic) ──
    local function lowGfx()
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            Lighting.GlobalShadows = false
            Lighting.Brightness    = 0
            Lighting.FogEnd        = 9e9
            Lighting.EnvironmentDiffuseScale  = 0
            Lighting.EnvironmentSpecularScale = 0
            for _, v in ipairs(Lighting:GetChildren()) do
                if v:IsA("PostEffect") then v.Enabled = false end
            end
        end)
    end

    -- ── ✂️ ปิด particle / trail / เสียง (ตัวกิน CPU ที่ spawn มาเรื่อยๆ) ──
    local function killFx()
        local n = 0
        pcall(function()
            for _, v in ipairs(workspace:GetDescendants()) do
                if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam")
                    or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                    if v.Enabled then v.Enabled = false n = n + 1 end
                elseif v:IsA("Sound") and v.Playing then
                    v.Playing = false
                    n = n + 1
                end
            end
        end)
        return n
    end

    -- ══════════════════════════════════════════════════════════
    -- ⏳ ตัวจัดการหน้า "LOADING" ของเกม
    -- ══════════════════════════════════════════════════════════
    --  🐛 อาการ: กด LEAVE ออกจากด่าน → ค้างจอ LOADING ไม่หายสักที
    --  💡 สาเหตุ: หน้า LOADING ของเกม fade ออกด้วย RenderStepped/Tween
    --     ซึ่ง "ไม่เดิน" ตอนปิด render 3D → มันเลยค้างคาจออยู่อย่างนั้น
    --     (สคริปข้างล่างยังทำงานปกตินะ แค่มีแผ่น LOADING บังอยู่)
    --  ✅ วิธีแก้ 2 ชั้น:
    --     ชั้น 1 = รอให้หน้า LOADING หายไปเองก่อน ค่อยปิด render (แก้ที่ต้นเหตุ)
    --     ชั้น 2 = ถ้ามันค้างเกิน LoadTimeout วิ → ซ่อนทิ้งเอง (กันเหนียว)
    --  🔁 ตอนเปลี่ยนแมพก็เช็คซ้ำให้ ผ่านลูป 10 วิข้างล่าง
    -- ══════════════════════════════════════════════════════════
    local LOAD_TIMEOUT = tonumber(VZa.LoadTimeout) or 30

    -- หา GUI หน้า LOADING (สแกนลึกครั้งเดียวตอนเริ่ม — ตอนนั้นมันโชว์อยู่พอดี)
    local function findLoadingUI(deep)
        local hit = nil
        pcall(function()
            local roots = {}
            local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
            if pg then table.insert(roots, pg) end
            local okc, cg = pcall(function() return game:GetService("CoreGui") end)
            if okc and cg then table.insert(roots, cg) end   -- เผื่อหน้า loading ของ teleport

            -- 1) หาแบบถูกๆ ก่อน: ดูแค่ลูกชั้นแรก แล้วเดาจากชื่อ
            for _, root in ipairs(roots) do
                for _, sg in ipairs(root:GetChildren()) do
                    local nm = tostring(sg.Name):lower()
                    if (sg:IsA("ScreenGui") or sg:IsA("GuiObject"))
                        and (nm:find("load") or nm:find("splash") or nm:find("intro")) then
                        hit = sg
                        return
                    end
                end
            end
            if not deep then return end

            -- 2) ยังไม่เจอ → สแกนลึกหา TextLabel ที่เขียนว่า LOADING (ทำครั้งเดียวตอนเริ่ม)
            for _, root in ipairs(roots) do
                for _, d in ipairs(root:GetDescendants()) do
                    if d:IsA("TextLabel") or d:IsA("TextButton") then
                        local ok, txt = pcall(function() return tostring(d.Text or ""):upper() end)
                        if ok and txt:find("LOADING") then
                            -- ไต่ขึ้นไปหา ScreenGui ที่ครอบอยู่
                            local o = d
                            while o and o.Parent and not o:IsA("ScreenGui") do o = o.Parent end
                            -- ⚠️ ห้ามซ่อน "Interface" เด็ดขาด — บอทต้องใช้หา Rewards/ปุ่ม
                            if o and o:IsA("ScreenGui") and o.Name ~= "Interface" then
                                hit = o
                            else
                                hit = d.Parent      -- ซ่อนแค่กรอบที่ครอบตัวหนังสือพอ
                            end
                            return
                        end
                    end
                end
            end
        end)
        return hit
    end

    local function loadingShowing(g)
        if not (g and g.Parent) then return false end
        local ok, vis = pcall(function() return VenozVisible(g) end)
        return ok and vis
    end

    local function hideLoading(g)
        pcall(function()
            if g:IsA("ScreenGui") then g.Enabled = false else g.Visible = false end
        end)
    end

    -- 🕐 รอหน้า LOADING หายก่อน (คืนค่า true = เคลียร์แล้ว พร้อมปิดจอ)
    local loadUI = findLoadingUI(true)
    local function waitLoadingGone(why)
        if not loadingShowing(loadUI) then return end
        print("[LAG] ⏳ " .. why .. " → รอหน้า LOADING หายก่อนค่อยปิดจอ")
        local t0 = tick()
        while loadingShowing(loadUI) and (tick() - t0) < LOAD_TIMEOUT do
            task.wait(0.25)
        end
        if loadingShowing(loadUI) then
            hideLoading(loadUI)
            warn(string.format("[LAG] ⛔ หน้า LOADING ค้างเกิน %d วิ → ซ่อนทิ้งเองแล้ว", LOAD_TIMEOUT))
        else
            print(string.format("[LAG] ✅ โหลดจบใน %.1f วิ → ปิดจอได้", tick() - t0))
        end
    end

    lowGfx()
    local want3DOff = (VZa.Disable3D ~= false)
    if want3DOff then
        waitLoadingGone("เพิ่งเข้าแมพ")     -- ⭐ อย่าปิด render ตอนหน้า loading ยังอยู่
        Venoz3D(false)
        print("[LAG] ⬛ ปิด render 3D แล้ว — จอว่างทุกที่ (ป้ายสถานะ + F9 ยังเห็นปกติ)")
    end

    local f = killFx()
    if f > 0 then print(string.format("[LAG] ✂️ ปิด effect/เสียง %d ชิ้น", f)) end

    -- ── 🔁 ย้ำซ้ำ กันเกมเปิดคืนตอนเปลี่ยนแมพ / ตัวละครเกิดใหม่ ──
    local round = 0
    while true do
        task.wait(10)

        -- 🔎 อ้างอิงเดิมโดนลบไปแล้ว (เปลี่ยนแมพ) → หาใหม่แบบถูกๆ ไม่สแกนลึก
        if not (loadUI and loadUI.Parent) then loadUI = findLoadingUI(false) end

        -- ⏳ หน้า LOADING โผล่อีก → เปิด render คืนให้มัน fade จบ แล้วค่อยปิด
        --    (ทำงานแม้ตั้ง Disable3D = false ด้วย จะได้ไม่มีทางค้างจอ)
        if loadingShowing(loadUI) then
            if want3DOff then Venoz3D(true) end
            waitLoadingGone("หน้า LOADING โผล่อีก")
            if want3DOff then Venoz3D(false) end
        end

        -- ⏸️ ถ้ากำลังกดปุ่มอยู่ → ข้ามรอบนี้ (ห้ามปิด render กลางคัน)
        if (tonumber(getgenv().VenozPressing) or 0) == 0 then
            if want3DOff and Venoz3DIsOn() then
                Venoz3D(false)      -- เกมเปิด render คืน → ปิดกลับ
            end
        end
        round = round + 1
        if round >= 6 then          -- ทุก ~60 วิ (killFx สแกนทั้ง workspace = แพง)
            round = 0
            lowGfx()
            killFx()
        end
    end
end)

task.spawn(function()
    local start = tick()
    repeat
        if PlayerGui:FindFirstChild("Interface") then break end
        task.wait()
    until tick() - start > 3
end)

local Window = Library:CreateWindow({Title="#Town Ship", Center=true, AutoShow=true})

local function isUIHiddenGlobal()
    local ok, hidden = pcall(function()
        return Window and Window.Holder and not Window.Holder.Visible
    end)
    return ok and hidden
end

local function hideUIGlobal()
    pcall(function()
        if Window and Window.Holder and Window.Holder.Visible then
            if Library and Library.Toggle then
                Library:Toggle()
            end
        end
    end)
end

local function showUIGlobal()
    pcall(function()
        if Window and Window.Holder and not Window.Holder.Visible then
            if Library and Library.Toggle then
                Library:Toggle()
            end
        end
    end)
end

getgenv().isUIHidden = isUIHiddenGlobal
getgenv().hideUI = hideUIGlobal
getgenv().showUI = showUIGlobal

local TownShipFolder = "TownShip"
if not isfolder(TownShipFolder) then makefolder(TownShipFolder) end

local activeFolder
if IsMainmenuLobby() then activeFolder = TownShipFolder.."/Mainmenu"
elseif IsLobbyLobby() then activeFolder = TownShipFolder.."/Lobby"
elseif IsIngameLobby() then activeFolder = TownShipFolder.."/Ingame"
else activeFolder = TownShipFolder.."/Default" end
if not isfolder(activeFolder) then makefolder(activeFolder) end

pcall(function()
    if game.Workspace:FindFirstChild("LinoriaLibSettings") then game.Workspace.LinoriaLibSettings:Destroy() end
    if isfolder("LinoriaLibSettings") then delfolder("LinoriaLibSettings") end
end)


local oldBuildFolderTree = SaveManager.BuildFolderTree
SaveManager.BuildFolderTree = function(...) if oldBuildFolderTree then return oldBuildFolderTree(...) end end
SaveManager:SetLibrary(Library)
SaveManager:SetFolder(activeFolder)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({"MenuKeybind"})
ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder(TownShipFolder)
pcall(function() SaveManager:BuildFolderTree() end)

local Tabs = {}
if IsMainmenuLobby() then Tabs.MainMenu = Window:AddTab("Main Menu") end
if IsLobbyLobby() then
    Tabs.Lobby = Window:AddTab("Lobby")
    Tabs.Session = Window:AddTab("Equipment")
    Tabs.Trade = Window:AddTab("Trade")
end
if IsIngameLobby() then
    Tabs.AutoFarm = Window:AddTab("Auto Farm")
    Tabs.Webhook = Window:AddTab("Webhook")
end
-- 🗑️ [ตัดออก] 🎰 Auto Spin / Family (Main Menu) — ไม่ได้ใช้  (เดิม 676 บรรทัด)

-- 🗑️ [ตัดออก] 👨‍👩‍👧 Show Family popup GUI — ไม่ได้ใช้  (เดิม 373 บรรทัด)







-- 🗑️ [ตัดออก] 🤝 Trade: saved players — ไม่ได้ใช้  (เดิม 278 บรรทัด)


-- 🗑️ [ตัดออก] 🤝 Trade: settings — ไม่ได้ใช้  (เดิม 40 บรรทัด)


-- 🗑️ [ตัดออก] 🤝 Auto Trade Manual — ไม่ได้ใช้  (เดิม 543 บรรทัด)


-- 🗑️ [ตัดออก] 🗑️ บล็อกที่ถูก comment ทิ้งไว้อยู่แล้ว  (เดิม 190 บรรทัด)
getgenv().scalemobile = false

local CONFIG_PRESETS = {
    mobile = { OFFSET_X = 500, OFFSET_Y = 250 },
    pc = { OFFSET_X = 1000, OFFSET_Y = 500 }
}

local isMobile = getgenv().scalemobile or false
local selectedConfig = isMobile and CONFIG_PRESETS.mobile or CONFIG_PRESETS.pc

local OFFSET_X = selectedConfig.OFFSET_X
local OFFSET_Y = selectedConfig.OFFSET_Y

local UISettingsTab = Window:AddTab("Settings")
local MenuGroup = UISettingsTab:AddLeftGroupbox("Menu")

local function IsUIVisible()
    return Window and Window.Holder and Window.Holder.Visible
end

local function HideUI()
    pcall(function()
        if IsUIVisible() then
            Library:Toggle()
        end
    end)
end

MenuGroup:AddToggle("HideUIToggle", {
    Text = "Auto Hide UI",
    Default = false,
    Callback = function(v)
    end
})

MenuGroup:AddToggle("EnableMobileUI", {
    Text = "Enable UI for Mobile",
    Default = getgenv().scalemobile or false,
    Callback = function(v)
        getgenv().scalemobile = v
        local isMobile = getgenv().scalemobile or false
        local selectedConfig = isMobile and CONFIG_PRESETS.mobile or CONFIG_PRESETS.pc
        OFFSET_X = selectedConfig.OFFSET_X
        OFFSET_Y = selectedConfig.OFFSET_Y
        
        if Window and Window.Holder then
            local holder = Window.Holder
            local basePos = holder.Position
            local baseX = basePos.X.Offset
            local baseY = basePos.Y.Offset
            local newX = baseX
            local newY = baseY
            
            if isMobile then
                newX = CONFIG_PRESETS.mobile.OFFSET_X
                newY = CONFIG_PRESETS.mobile.OFFSET_Y
            else
                newX = CONFIG_PRESETS.pc.OFFSET_X
                newY = CONFIG_PRESETS.pc.OFFSET_Y
            end
            
            holder.Position = UDim2.new(0, newX, 0, newY)
        end
    end
})

MenuGroup:AddButton("Unload", function()
    Library:Unload()
end)

MenuGroup:AddLabel("Menu Bind"):AddKeyPicker(
    "MenuKeybind",
    {
        Default = "End",
        NoUI = true,
        Text = "Menu Keybind",
        Callback = function(key)
            if Library and Options.MenuKeybind then
                Library.ToggleKeybind = Options.MenuKeybind
            end
        end
    }
)

task.defer(function()
    pcall(function()
        if Options and Options.MenuKeybind and Library then
            Library.ToggleKeybind = Options.MenuKeybind
        end
    end)
end)

local oldBuildConfigSection = SaveManager.BuildConfigSection
function SaveManager:BuildConfigSection(tab)
    if oldBuildConfigSection then
        oldBuildConfigSection(self, tab)
    end

    local section = tab:AddRightGroupbox("Configuration")
    section:AddButton("Delete config", function()
        if not Options or not Options.SaveManager_ConfigList then return end
        local name = Options.SaveManager_ConfigList.Value
        if not name then return end

        local filePath = self.Folder .. "/settings/" .. name .. ".json"
        if isfile(filePath) then
            delfile(filePath)
            Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
            Options.SaveManager_ConfigList:SetValue(nil)
        end
    end)
    
    section:AddButton("Reset Autoload", function()
        local autoloadPath = self.Folder .. "/settings/autoload.txt"
        if isfile(autoloadPath) then
            delfile(autoloadPath)
            if SaveManager.AutoloadLabel then
                SaveManager.AutoloadLabel:SetText("Current autoload config: none")
            end
            if Options and Options.SaveManager_ConfigList then
                Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
            end
            Library:Notify("Autoload config has been reset to none")
        else
            if SaveManager.AutoloadLabel then
                SaveManager.AutoloadLabel:SetText("Current autoload config: none")
            end
            Library:Notify("No autoload config found, reset to none")
        end
    end)
end

SaveManager:BuildConfigSection(UISettingsTab)

pcall(function()
    if ThemeManager and ThemeManager.BuiltInThemes and ThemeManager.BuiltInThemes["Jester"] then
        ThemeManager:ApplyTheme("Jester")
        ThemeManager:SaveDefault("Jester")
    elseif ThemeManager and ThemeManager.ApplyTheme then
        ThemeManager:ApplyTheme("Default")
    end
end)

task.spawn(function()
    local maxWait = 5
    local start = tick()
    while tick() - start < maxWait do
        if Window and Window.Holder then
            break
        end
        task.wait(0.1)
    end

    if Window and Window.Holder then
        local holder = Window.Holder
        local basePos = holder.Position
        local baseX = basePos.X.Offset
        local baseY = basePos.Y.Offset
        holder.Position = UDim2.new(0, baseX + OFFSET_X, 0, baseY + OFFSET_Y)
    end
end)

task.spawn(function()
    task.wait(0.25)
    pcall(function()
        SaveManager:LoadAutoloadConfig()
    end)

    for i = 1, 40 do
        if Window and Window.Holder then break end
        task.wait(0.05)
    end
    task.wait(0.15)

    if Toggles["HideUIToggle"] and Toggles["HideUIToggle"].Value and IsUIVisible() then
        HideUI()
    end
end)


if IsMainmenuLobby() then
    local g = Tabs.MainMenu:AddRightGroupbox("Start GaMe")

    local d, s, a = 1, false, "A"

    local Players = game:GetService("Players")
    local VIM = game:GetService("VirtualInputManager")
    local GS = game:GetService("GuiService")

    local p = Players.LocalPlayer
    local PlayerGui = p.PlayerGui

    local function GetSlots()
        local i = PlayerGui:FindFirstChild("Interface")
        if not i then return nil end
        local t = i:FindFirstChild("Title_Screen")
        if not t then return nil end
        return t:FindFirstChild("Slots")
    end

    local function GetLogo()
        local i = PlayerGui:FindFirstChild("Interface")
        if not i then return nil end
        local t = i:FindFirstChild("Title_Screen")
        if not t then return nil end
        return t:FindFirstChild("Logo")
    end

    local function IsVisible(obj)
        if not obj then return false end
        if obj:IsA("ScreenGui") then return obj.Enabled end
        if obj:IsA("GuiObject") then
            return obj.Visible and obj.AbsoluteSize.X > 1 and obj.AbsoluteSize.Y > 1
        end
        return false
    end

    local function IsLogoActuallyVisible(obj)
        if not obj then return false end
        if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
            if obj.ImageTransparency < 0.95 and obj.AbsoluteSize.X > 5 and obj.AbsoluteSize.Y > 5 then
                return true
            end
        end
        for _, v in ipairs(obj:GetDescendants()) do
            if v:IsA("ImageLabel") or v:IsA("ImageButton") then
                if v.Visible and v.ImageTransparency < 0.95 and v.AbsoluteSize.X > 5 and v.AbsoluteSize.Y > 5 then
                    return true
                end
            end
            if v:IsA("TextLabel") or v:IsA("TextButton") then
                if v.Visible and v.TextTransparency < 0.95 and v.AbsoluteSize.X > 5 and v.AbsoluteSize.Y > 5 then
                    return true
                end
            end
        end
        return false
    end

    local function clickButton(target)
        if not target or not target.Visible then return false end
        
        local obj = target
        while obj and obj ~= p.PlayerGui do
            if obj:IsA("GuiObject") and not obj.Visible then return false end
            if obj:IsA("ScreenGui") and not obj.Enabled then return false end
            obj = obj.Parent
        end
        
        if target.AbsoluteSize.X <= 0 or target.AbsoluteSize.Y <= 0 then return false end
        
        GS.SelectedObject = target
        task.wait(0.05)
        VIM:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        task.wait(0.05)
        VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
        task.wait(0.1)
        GS.SelectedObject = nil
        
        return true
    end

    local function SelectSlot()
        if not s then return false end
        local map = {A = "Select_A", B = "Select_B", C = "Select_C"}
        local Slots = GetSlots()
        if not Slots then return false end
        local slot = Slots:FindFirstChild(a)
        if not slot then return false end
        local button = slot:FindFirstChild(map[a])
        if not button then return false end
        return clickButton(button)
    end

    g:AddDropdown("SlotSelectionDropdown", {
        Values = {"A","B","C"}, Default = "A", Multi = false,
        Text = "Select Slot", Callback = function(x) a = x end
    })
    g:AddDivider()
    g:AddSlider("SelectDelaySlider", {
        Text = "Delay", Default = d, Min = 0.1, Max = 10, Rounding = 1,
        Callback = function(x) d = x end
    })
    g:AddDivider()
    g:AddToggle("AutoClickSelectToggle", {
        Text = "Auto Slot [ SELECT ]", Default = false,
        Callback = function(x)
            s = x
            if not x then return end
            task.spawn(function()
                while s do
                    task.wait(0.3)
                    local Slots = GetSlots()
                    if IsLogoActuallyVisible(GetLogo()) then continue end
                    if not IsVisible(Slots) then continue end
                    SelectSlot()
                    task.wait(d)
                end
            end)
        end
    })

    
    local C = Tabs.MainMenu:AddRightGroupbox("Join Community")

    local autoJoinEnabled = false
    local autoNotNowEnabled = false

    -- ใช้ Path ใหม่ตามที่กำหนด
    local function IsJoinCommunityDialogVisible()
        local success, dialog = pcall(function()
            return game:GetService("CoreGui").RobloxGui.FocusNavigationCoreScriptsWrapper.Main.DialogContentWrapper.Folder.Dialog
        end)
        if not success or not dialog then return false end
        return dialog.Visible == true
    end

    local function getDialogButtons()
        local success, actionsContainer = pcall(function()
            return game:GetService("CoreGui").RobloxGui
                .FocusNavigationCoreScriptsWrapper.Main.DialogContentWrapper.Folder.Dialog.DialogInner.DialogBody.DialogActions.ActionsContainer
        end)
        if not success or not actionsContainer then return {} end
        
        local buttons = {}
        for _, child in ipairs(actionsContainer:GetChildren()) do
            if child:IsA("GuiButton") and child.Visible and child.AbsoluteSize.X > 0 and child.AbsoluteSize.Y > 0 then
                table.insert(buttons, child)
            end
        end
        return buttons
    end

    local function clickJoinButton()
        local buttons = getDialogButtons()
        if #buttons >= 1 then
            return clickButton(buttons[1])
        end
        return false
    end

    local function clickNotNowButton()
        local buttons = getDialogButtons()
        if #buttons >= 2 then
            return clickButton(buttons[2])
        end
        return false
    end

    C:AddToggle("AutoDialogClickerToggle", {
        Text = "Auto Click 'Join Community'", Default = false,
        Callback = function(v)
            autoJoinEnabled = v
        end
    })

    C:AddToggle("AutoNotNowClickerToggle", {
        Text = "Not Click 'Join Community'", Default = false,
        Callback = function(v)
            autoNotNowEnabled = v
        end
    })

    task.spawn(function()
        while true do
            task.wait(0.3)
            pcall(function()
                if IsJoinCommunityDialogVisible() then
                    if autoJoinEnabled then
                        clickJoinButton()
                    elseif autoNotNowEnabled then
                        clickNotNowButton()
                    end
                end
            end)
        end
    end)
end

if IsMainmenuLobby() then
    local J = Tabs.MainMenu:AddRightGroupbox("Auto Join")

    local D2 = 0
    local Dst = "Lobby"
    local E = false
    local R = false
    local Lf = 0

    local Players = game:GetService("Players")
    local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

    local function IsFollowFrameOpen()
        local ok, follow = pcall(function()
            return PlayerGui.Interface.Title_Screen.Follow
        end)
        if not ok or not follow then return false end
        return follow.Visible == true
    end

    local function TeleportTo(destination)
        local args = {"Functions", "Teleport", destination}
        pcall(function()
            GET:InvokeServer(unpack(args))
        end)
    end

    J:AddDropdown("JoinDestinationDropdown", {
        Values = {"Lobby","Trade"}, Default = "Lobby", Multi = false,
        Text = "Teleport To", Callback = function(x) Dst = x end
    })
    J:AddSlider("AutoJoinDelaySlider", {
        Text = "Delay (seconds)", Default = 0, Min = 0, Max = 120, Rounding = 0,
        Callback = function(x) D2 = x end
    })
    J:AddToggle("MyToggle", {
        Text = "Auto Join", Default = false,
        Callback = function(x)
            E = x
            if not x then R = false; return end
            if R then return end
            R = true
            task.spawn(function()
                while E do
                    task.wait(0.3)
                    
                    if not IsFollowFrameOpen() then
                        continue
                    end
                    
                    if tick() - Lf < 2 then continue end
                    if D2 > 0 then task.wait(D2) end
                    Lf = tick()
                    TeleportTo(Dst)
                end
                R = false
            end)
        end
    })
end
if IsMainmenuLobby() or IsLobbyLobby() then
    local tab = Tabs.MainMenu or Tabs.Lobby
    local g = tab:AddLeftGroupbox("Teleport Now")
    local l = g:AddLabel("")
    local function DoTP(id) pcall(function() TeleportService:Teleport(id, Player) end) end
    local function AddConfirm(name, id, time)
        local c = false
        g:AddButton(name, function()
            if c then DoTP(id)
            else
                c = true; l:SetText("Are you sure?")
                task.delay(time or 3, function() c = false; l:SetText("") end)
            end
        end)
    end
    AddConfirm("Teleport to Main Menu", MAIN_MENU_ID, 1.5)
    AddConfirm("Teleport to Lobby", LOBBY_ID)
    AddConfirm("Teleport to Trading", TRADE_LOBBY_ID)
    
        g:AddDivider()
    
    local autoTeleportEnabled = false
    local autoTeleportTime = 0
    local teleportAttempts = 0
    local maxAttempts = 5
    local isTeleporting = false
    local startTime = 0
    
    g:AddSlider("AutoTeleportTimeSlider", {
        Text = "Teleport Main Menu After x Minute",
        Default = 0,
        Min = 0,
        Max = 600,
        Rounding = 0,
        Suffix = "sec",
        Callback = function(v)
            autoTeleportTime = v
        end
    })
    
    g:AddToggle("AutoTeleportToggle", {
        Text = "Enable Auto Teleport",
        Default = false,
        Callback = function(v)
            autoTeleportEnabled = v
            if not v then
                teleportAttempts = 0
                isTeleporting = false
                startTime = 0
            else
                teleportAttempts = 0
                isTeleporting = false
                startTime = tick()
            end
        end
    })
    
    task.spawn(function()
        while true do
            task.wait(1) 
            
            if autoTeleportEnabled and not isTeleporting then
                local elapsed = tick() - startTime
                if elapsed >= autoTeleportTime then
                    isTeleporting = true
                    teleportAttempts = 0
                end
            end
            
            if autoTeleportEnabled and isTeleporting then
                teleportAttempts = teleportAttempts + 1
                
                pcall(function() TeleportService:Teleport(MAIN_MENU_ID, Player) end)
                
                if teleportAttempts >= maxAttempts then
                    game:Shutdown()
                end
                
                task.wait(5) 
            end
        end
    end)
end

if IsMainmenuLobby() then
    local CodeGroup = Tabs.MainMenu:AddLeftGroupbox("Code Redeem")

    local codesFile = "TownShip/codes.txt"
    local codeList = {}
    local selectedCodes = {}  
    local autoRedeemActive = false
    local autoRedeemTask = nil

    local function saveCodes()
        writefile(codesFile, table.concat(codeList, "\n"))
    end

    local function loadCodes()
        codeList = {}
        if isfile(codesFile) then
            local content = readfile(codesFile)
            for line in string.gmatch(content, "[^\r\n]+") do
                line = line:gsub("^%s+", ""):gsub("%s+$", "")
                if line ~= "" then
                    table.insert(codeList, line)
                end
            end
        end
    end

    local function addCode(newCode)
        newCode = newCode:gsub("^%s+", ""):gsub("%s+$", "")
        if newCode == "" then return false end
        for _, existing in ipairs(codeList) do
            if existing == newCode then return false end
        end
        table.insert(codeList, newCode)
        saveCodes()
        return true
    end

    local function removeSelectedCodes()
        local removed = false
        for code, isSelected in pairs(selectedCodes) do
            if isSelected then
                for i, existing in ipairs(codeList) do
                    if existing == code then
                        table.remove(codeList, i)
                        removed = true
                        break
                    end
                end
            end
        end
        if removed then
            saveCodes()
            refreshDropdown()
        end
        return removed
    end

    loadCodes()

    local codeDropdown = CodeGroup:AddDropdown("CodeListDropdown", {
        Text = "Stored Codes",
        Values = codeList,
        Default = {},
        Multi = true,
        Callback = function(v)
            selectedCodes = v
        end
    })

    local function refreshDropdown()
        codeDropdown:SetValues(codeList)
        selectedCodes = {}
        codeDropdown:SetValue(selectedCodes)
    end

    local newCodeInput = ""
    CodeGroup:AddInput("NewCodeInput", {
        Text = "New Code",
        Placeholder = "Enter code...",
        Numeric = false,
        Finished = true,
        Callback = function(v)
            newCodeInput = v
        end
    })

    CodeGroup:AddButton("Store Code", function()
        if newCodeInput ~= "" then
            if addCode(newCodeInput) then
                Library:Notify("Code '" .. newCodeInput .. "' added successfully!", 3)
                refreshDropdown()
                newCodeInput = ""
                if Options and Options.NewCodeInput then
                    Options.NewCodeInput:SetValue("")
                end
            else
                Library:Notify("Code already exists or invalid!", 3)
            end
        else
            Library:Notify("Please enter a code first!", 3)
        end
    end)

    CodeGroup:AddButton("Remove Selected Codes", function()
        local hasSelected = false
        for _, selected in pairs(selectedCodes) do
            if selected then hasSelected = true; break end
        end
        if hasSelected then
            if removeSelectedCodes() then
                Library:Notify("Selected codes removed.", 3)
            else
                Library:Notify("Failed to remove codes.", 3)
            end
        else
            Library:Notify("No code selected.", 3)
        end
    end)

    CodeGroup:AddDivider()

    local function IsActuallyVisible(gui)
        if not gui or not gui:IsA("GuiObject") then return false end
        if not gui.Visible then return false end
        local current = gui.Parent
        while current do
            if current:IsA("GuiObject") and not current.Visible then return false end
            if current:IsA("ScreenGui") and not current.Enabled then return false end
            current = current.Parent
        end
        return true
    end

    local function isRedeemPageVisible()
        local interface = PlayerGui:FindFirstChild("Interface")
        if not interface then return false end
        local followVisible = false
        local familyVisible = false
        local titleScreen = interface:FindFirstChild("Title_Screen")
        if titleScreen then
            local follow = titleScreen:FindFirstChild("Follow")
            if follow then followVisible = IsActuallyVisible(follow) end
        end
        local customisation = interface:FindFirstChild("Customisation")
        if customisation then
            local categories = customisation:FindFirstChild("Categories")
            if categories then
                local family = categories:FindFirstChild("Family")
                if family then familyVisible = IsActuallyVisible(family) end
            end
        end
        return followVisible or familyVisible
    end

    local function redeemCode(code)
        if not code or code == "" then return false, "No code provided!" end
        local GET = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("GET")
        local success, result = pcall(function()
            return GET:InvokeServer("Functions", "Redeem", code)
        end)
        if not success then return false, tostring(result) end
        local resultStr = tostring(result)
        if resultStr:find("SUCCESSFUL") then
            return true, "✅ Redeemed successfully! (" .. code .. ")"
        elseif resultStr:find("USED") then
            return false, "⚠️ Code already used! (" .. code .. ")"
        elseif resultStr:find("EXPIRED") then
            return false, "❌ Code expired! (" .. code .. ")"
        elseif resultStr:find("INVALID") then
            return false, "❌ Invalid code! (" .. code .. ")"
        else
            return false, "Redeem result: " .. resultStr
        end
    end

    local function getSelectedCodeList()
        local list = {}
        for code, isSelected in pairs(selectedCodes) do
            if isSelected then table.insert(list, code) end
        end
        return list
    end

    local function startAutoRedeem()
        if autoRedeemTask then return end
        autoRedeemTask = task.spawn(function()
            -- รอให้หน้า redeem พร้อม (เช็คทุก 0.5 วินาที)
            local waitingNotified = false
            while autoRedeemActive and not isRedeemPageVisible() do
                if not waitingNotified then
                    Library:Notify("Waiting for redeem...", 3)
                    waitingNotified = true
                end
                task.wait(0.5)
            end
            
            if not autoRedeemActive then return end
            
            local selectedList = getSelectedCodeList()
            if #selectedList == 0 then
                Library:Notify("No codes selected to redeem.", 3)
                autoRedeemActive = false
                if Options and Options.AutoRedeemToggle then
                    Options.AutoRedeemToggle:SetValue(false)
                end
                autoRedeemTask = nil
                return
            end
            
            local successCount = 0
            local failCount = 0
            for i, code in ipairs(selectedList) do
                if not autoRedeemActive then break end
                -- ก่อน redeem แต่ละครั้ง เช็ค visibility อีกครั้ง
                while autoRedeemActive and not isRedeemPageVisible() do
                    task.wait(0.5)
                end
                if not autoRedeemActive then break end
                
                local success, message = redeemCode(code)
                print("[Code Redeemer] " .. message)
                if success then
                    successCount = successCount + 1
                else
                    failCount = failCount + 1
                end
                if i < #selectedList then task.wait(1) end
            end
            Library:Notify(string.format("Auto Redeem finished. Success: %d, Failed: %d", successCount, failCount), 5)
            
            autoRedeemActive = false
            if Options and Options.AutoRedeemToggle then
                Options.AutoRedeemToggle:SetValue(false)
            end
            autoRedeemTask = nil
        end)
    end

    CodeGroup:AddToggle("AutoRedeemToggle", {
        Text = "Auto Redeem Selected Codes",
        Default = false,
        Callback = function(v)
            if v then
                -- ✅ รอ 1 วินาทีให้ UI, Dropdown และ Config โหลดเสร็จ
                task.wait(1)
                
                -- ✅ ดึงค่าที่เลือกจาก Dropdown โดยตรง เพื่อให้แน่ใจว่าได้ค่าล่าสุด
                local dropdownValue = Options and Options.CodeListDropdown and Options.CodeListDropdown.Value or {}
                local selectedList = {}
                for code, isSelected in pairs(dropdownValue) do
                    if isSelected then
                        table.insert(selectedList, code)
                    end
                end
                
                -- ✅ ถ้าจาก dropdown ยังไม่มี ให้ใช้ selectedCodes แทน
                if #selectedList == 0 then
                    selectedList = getSelectedCodeList()
                end
                
                if #selectedList == 0 then
                    pcall(function()
                        if Options and Options.AutoRedeemToggle then
                            Options.AutoRedeemToggle:SetValue(false)
                        end
                    end)
                    Library:Notify("Please select at least one code first!", 3)
                    return
                end
                if #codeList == 0 then
                    pcall(function()
                        if Options and Options.AutoRedeemToggle then
                            Options.AutoRedeemToggle:SetValue(false)
                        end
                    end)
                    Library:Notify("No codes stored. Please add codes first!", 3)
                    return
                end
                autoRedeemActive = true
                startAutoRedeem()
            else
                autoRedeemActive = false
                if autoRedeemTask then
                    task.cancel(autoRedeemTask)
                    autoRedeemTask = nil
                end
            end
        end
    })
end



local function findMissionRemote()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local remotesFolder = ReplicatedStorage:FindFirstChild("Assets") 
        and ReplicatedStorage.Assets:FindFirstChild("Remotes")
        or ReplicatedStorage:FindFirstChild("Remotes")
        or ReplicatedStorage:FindFirstChild("Network")
        or ReplicatedStorage:FindFirstChild("RemoteEvents")
    
    if not remotesFolder then
        for _, child in ipairs(ReplicatedStorage:GetChildren()) do
            if child:IsA("Folder") and (child.Name:lower():find("remote") or child.Name:lower():find("network")) then
                remotesFolder = child
                break
            end
        end
    end
    
    local getRemote = remotesFolder and remotesFolder:FindFirstChild("GET") 
        or ReplicatedStorage:FindFirstChild("GET")
        or ReplicatedStorage:FindFirstChild("GetRemote")
        or ReplicatedStorage:FindFirstChild("RequestData")
    
    return getRemote
end

local MissionGET = findMissionRemote()

if not MissionGET then
    local waited = 0
    while not MissionGET and waited < 5 do
        task.wait(0.5)
        MissionGET = findMissionRemote()
        waited = waited + 0.5
    end
end

local function SafeMissionCall(...)
    if not MissionGET then return false, nil end
    local args = {...}
    local success, result = pcall(function()
        return MissionGET:InvokeServer(unpack(args, 1, table.getn(args)))
    end)
    return success, result
end

if Tabs.Lobby then

    local Players = game:GetService("Players")
    local player = Players.LocalPlayer

    local function IsActuallyVisible(gui)
        if not gui or not gui:IsA("GuiObject") then return false end
        if not gui.Visible then return false end
        local current = gui.Parent
        while current do
            if current:IsA("GuiObject") and not current.Visible then return false end
            if current:IsA("ScreenGui") and not current.Enabled then return false end
            current = current.Parent
        end
        return true
    end

    local function isUIActive()
        local keyGui = player.PlayerGui:FindFirstChild("Interface")
        if keyGui then
            keyGui = keyGui:FindFirstChild("Gear_Up")
            if keyGui then
                keyGui = keyGui:FindFirstChild("Lobby")
                if keyGui then
                    keyGui = keyGui:FindFirstChild("Key")
                end
            end
        end
        local keyVisible = (keyGui and IsActuallyVisible(keyGui)) or false

        local invGui = player.PlayerGui:FindFirstChild("Interface")
        if invGui then
            invGui = invGui:FindFirstChild("Topbar")
            if invGui then
                invGui = invGui:FindFirstChild("Main")
                if invGui then
                    invGui = invGui:FindFirstChild("Categories")
                    if invGui then
                        invGui = invGui:FindFirstChild("Inventory")
                    end
                end
            end
        end
        local inventoryVisible = (invGui and IsActuallyVisible(invGui)) or false

        return (keyVisible or inventoryVisible)
    end
  
    local AutoMissionTabbox = Tabs.Lobby:AddLeftTabbox("Auto Content")

    local MissionTab = AutoMissionTabbox:AddTab("Mission")

    local MissionObjectives = {
        ["Shiganshina"] = {"Skirmish","Breach","Random"},
        ["Trost"] = {"Skirmish","Protect","Random"},
        ["Outskirts"] = {"Skirmish","Escort","Random"},
        ["Forest"] = {"Skirmish","Guard","Random"},
        ["Utgard"] = {"Skirmish","Defend","Random"},
        ["Docks"] = {"Skirmish","Stall","Random"},
        ["Stohess"] = {"Skirmish","Random"}
    }

    local ModifiersList = {
        "No Perks", "No Skills", "No Memories", "Nightmare", "Oddball",
        "Injury Prone", "Chronic Injuries", "Fog", "Glass Cannon", "Time Trial", "Boring", "Simple"
    }

    local MODIFIER_ORDER = {
        "No Perks", "No Skills", "No Memories", "Nightmare", "Oddball",
        "Injury Prone", "Chronic Injuries", "Fog", "Glass Cannon", "Time Trial", "Boring", "Simple"
    }

    local State_Mission = {
        Name = "Shiganshina",
        Objective = "Skirmish",
        Difficulty = "Hardest"
    }

    local MissionDelay = 0
    local missionRunning = false
    local missionBusy = false
    local missionSessionId = 0
    local lastNotifiedMissionMods = ""

    pcall(function()
        if Options and Options.MissionDropdown and Options.MissionDropdown.Value then State_Mission.Name = Options.MissionDropdown.Value end
        if Options and Options.ObjectiveDropdown and Options.ObjectiveDropdown.Value then State_Mission.Objective = Options.ObjectiveDropdown.Value end
        if Options and Options.MissionDifficultyDropdown and Options.MissionDifficultyDropdown.Value then State_Mission.Difficulty = Options.MissionDifficultyDropdown.Value end
        if Options and Options.MissionDelaySlider and Options.MissionDelaySlider.Value then MissionDelay = tonumber(Options.MissionDelaySlider.Value) or 0 end
    end)

    local function GetPlayerLevel()
        local success, level = pcall(function()
            local player = game:GetService("Players").LocalPlayer
            local playerGui = player:FindFirstChild("PlayerGui")
            if not playerGui then return 1 end
            local interface = playerGui:FindFirstChild("Interface")
            if not interface then return 1 end
            local gearUp = interface:FindFirstChild("Gear_Up")
            if not gearUp then return 1 end
            local hud = gearUp:FindFirstChild("HUD")
            if not hud then return 1 end
            local levelFrame = hud:FindFirstChild("Level")
            if not levelFrame then return 1 end
            local title = levelFrame:FindFirstChild("Title")
            if not title then return 1 end
            local txt = tostring(title.Text)
            local num = tonumber(txt:match("%d+"))
            return num or 1
        end)
        return success and level or 1
    end

    local function GetDifficultyCycle(missionType)
        local level = GetPlayerLevel()
        if missionType == "Raids" then
            if level >= 100 then return {"Aberrant"}
            elseif level >= 60 then return {"Aberrant", "Severe", "Hard"}
            elseif level >= 40 then return {"Severe", "Hard", "Normal"}
            else return {"Hard", "Normal", "Easy"} end
        end
        if level >= 100 then return {"Aberrant"}
        elseif level >= 60 then return {"Aberrant", "Severe", "Hard", "Normal", "Easy"}
        elseif level >= 40 then return {"Severe", "Hard", "Normal", "Easy"}
        else return {"Hard", "Normal", "Easy"} end
    end

    local function formatMissionModifiers(modList)
        if not modList or #modList == 0 then return nil end
        local sorted = {}
        for _, ordered in ipairs(MODIFIER_ORDER) do
            for _, m in ipairs(modList) do
                if m == ordered then table.insert(sorted, m); break end
            end
        end
        for _, m in ipairs(modList) do
            local found = false
            for _, ordered in ipairs(MODIFIER_ORDER) do
                if m == ordered then found = true; break end
            end
            if not found then table.insert(sorted, m) end
        end
        return "Modifiers:\n" .. table.concat(sorted, "\n")
    end

     local function CreateMissionWithRetry(missionName, objective, difficulty)
        local maxRetries = 3
        for attempt = 1, maxRetries do
            if not missionRunning then return false end
            local success, _ = SafeMissionCall("S_Missions", "Create", {
                Difficulty = difficulty,
                Type = "Missions",
                Name = missionName,
                Objective = objective
            })
            if success then
                task.wait(0.15)
                return true
            end
            if attempt < maxRetries then
                Library:Notify(string.format("Mission creation failed, retry %d/%d in 3s", attempt, maxRetries), 2)
                task.wait(3)
            else
                Library:Notify("Mission creation failed after 3 attempts, stopping", 3)
                return false
            end
        end
        return false
    end

    local function CreateMission(missionName, objective, difficulty)
        return CreateMissionWithRetry(missionName, objective, difficulty)
    end

    local function ClearMissionModifiers()
        if not missionRunning then return end
        for retry = 1, 2 do
            if not missionRunning then break end
            local success = SafeMissionCall("S_Missions", "ClearModifiers")
            if success then break end
            task.wait(0.2)
        end
        task.wait(0.3)
    end

    local function ApplyModifier(mod)
        local Event = game:GetService("ReplicatedStorage").Assets.Remotes.GET
        local success, result = pcall(function()
            return Event:InvokeServer("S_Missions", "Modify", mod)
        end)
        if success and result == true then
            return true
        end
        return false
    end

    local function ApplyMissionModifiers()
        if not missionRunning then return end
        local selected = {}
        pcall(function()
            if Options and Options.MissionModifiersDropdown and Options.MissionModifiersDropdown.Value then
                local val = Options.MissionModifiersDropdown.Value
                if type(val) == "table" then
                    for mod, enabled in pairs(val) do
                        if enabled then table.insert(selected, mod) end
                    end
                end
            end
        end)
        if #selected == 0 then return end
        
        local modsString = table.concat(selected, ", ")
        if lastNotifiedMissionMods ~= modsString then
            lastNotifiedMissionMods = modsString
        end
        
        ClearMissionModifiers()
        if not missionRunning then return end
        
        for _, mod in ipairs(selected) do
            if not missionRunning then break end
            local success = false
            for retry = 1, 3 do
                if not missionRunning then break end
                success = ApplyModifier(mod)
                if success then break end
                task.wait(0.3)
            end
            task.wait(0.5)  
			end
        task.wait(0.4)
    end

    local function StartMission()
        if not missionRunning then return end
        task.wait(0.1)
        SafeMissionCall("S_Missions", "Start")
    end

    local function LeaveMission()
        SafeMissionCall("S_Missions", "Leave")
    end

    local function GetMyMission()
        local start = tick()
        while (tick() - start) < 2 do
            local missions = game:GetService("ReplicatedStorage"):FindFirstChild("Missions")
            if missions then
                for _, mission in next, missions:GetChildren() do
                    if mission:FindFirstChild("Leader") and mission.Leader.Value == game.Players.LocalPlayer.Name then
                        return mission
                    end
                end
            end
            task.wait(0.1)
        end
        return nil
    end

    local function MissionLoop(mySession)
        task.wait(1)
        if MissionDelay > 0 then task.wait(MissionDelay) end
        
        while missionRunning and missionSessionId == mySession do
            if missionBusy then task.wait(0.05); continue end
            missionBusy = true
            
            local currentMission = State_Mission.Name
            local currentObjective = State_Mission.Objective
            local currentDifficulty = State_Mission.Difficulty

            if currentDifficulty == "Hardest" then
                local cycle = GetDifficultyCycle("Missions")
                local created = false
                local targetDiff = nil
                local targetObj = nil
                
                for _, diff in ipairs(cycle) do
                    if not missionRunning or missionSessionId ~= mySession then break end
                    if State_Mission.Difficulty ~= "Hardest" then break end
                    
                    local objList = MissionObjectives[currentMission] or {"Skirmish"}
                    local obj = currentObjective
                    if obj == "Random" then
                        local filtered = {}
                        for _, v in ipairs(objList) do if v ~= "Random" then filtered[#filtered+1] = v end end
                        obj = filtered[math.random(#filtered)]
                    end
                    
                    CreateMission(currentMission, obj, diff)
                    task.wait(0.2)
                    
                    if GetMyMission() then
                        Library:Notify(string.format("Found suitable difficulty: %s", diff), 3)
                        targetDiff = diff
                        targetObj = obj
                        created = true
                        break
                    else
                        LeaveMission()
                        task.wait(0.5)
                    end
                    
                    if not missionRunning then break end
                end
                
                if not created then
                    Library:Notify("Mission creation failed, retrying later", 3)
                    missionBusy = false
                    task.wait(2)
                    continue
                end
                
               
                Library:Notify("🔄 Leaving current mission to reset state...", 3)
                LeaveMission()
                local leaveStart = tick()
                while (tick() - leaveStart) < 2 do
                    local missions = game:GetService("ReplicatedStorage"):FindFirstChild("Missions")
                    local stillExists = false
                    if missions then
                        for _, m in next, missions:GetChildren() do
                            if m:FindFirstChild("Leader") and m.Leader.Value == game.Players.LocalPlayer.Name then
                                stillExists = true
                                break
                            end
                        end
                    end
                    if not stillExists then break end
                    task.wait(0.1)
                end
                task.wait(0.3)
                
                Library:Notify(string.format("Recreating mission with exact difficulty: %s", targetDiff), 3)
                CreateMission(currentMission, targetObj, targetDiff)
                task.wait(0.2)
                
                local recreateSuccess = false
                for retry = 1, 3 do
                    if GetMyMission() then
                        recreateSuccess = true
                        break
                    end
                    task.wait(0.3)
                end
                if not recreateSuccess then
                    Library:Notify("Failed to recreate mission, restarting loop", 3)
                    LeaveMission()
                    missionBusy = false
                    task.wait(1)
                    continue
                end
                Library:Notify("Mission recreated successfully!", 3)
                
                Library:Notify("Applying modifiers...", 3)
                local selectedMods = {}
                pcall(function()
                    if Options and Options.MissionModifiersDropdown and Options.MissionModifiersDropdown.Value then
                        local val = Options.MissionModifiersDropdown.Value
                        if type(val) == "table" then
                            for mod, enabled in pairs(val) do
                                if enabled then table.insert(selectedMods, mod) end
                            end
                        end
                    end
                end)
                
                if #selectedMods > 0 then
                    for retry = 1, 2 do
                        if not missionRunning then break end
                        SafeMissionCall("S_Missions", "ClearModifiers")
                        task.wait(0.2)
                    end
                    task.wait(0.3)
                    
                    local applied = 0
                    for _, mod in ipairs(selectedMods) do
                        if not missionRunning then break end
                        local success = false
                        for retry = 1, 3 do
                            success = ApplyModifier(mod)
                            if success then break end
                            task.wait(0.3)
                        end
                        if success then
                            applied = applied + 1
                            Library:Notify(string.format("  Applied: %s (%d/%d)", mod, applied, #selectedMods), 1)
                        else
                            Library:Notify(string.format("  Failed to apply: %s", mod), 2)
                        end
                        task.wait(0.5)  
                    end
                    task.wait(0.4)
                    Library:Notify(string.format("Applied %d/%d modifiers", applied, #selectedMods), 3)
                else
                    Library:Notify("ℹ️ No modifiers selected", 2)
                end
                
                if not missionRunning then
                    missionBusy = false
                    continue
                end
                
                Library:Notify("Starting mission", 2)
                StartMission()
                local startTick = tick()
                repeat task.wait(0.05) until not missionRunning or missionSessionId ~= mySession or tick() - startTick >= 3.5
                if MissionDelay > 0 then task.wait(MissionDelay) end
                
            else
                local objList = MissionObjectives[currentMission] or {"Skirmish"}
                local obj = currentObjective
                if obj == "Random" then
                    local filtered = {}
                    for _, v in ipairs(objList) do if v ~= "Random" then filtered[#filtered+1] = v end end
                    obj = filtered[math.random(#filtered)]
                end
                
                CreateMission(currentMission, obj, currentDifficulty)
                task.wait(0.2)
                
                if not GetMyMission() then
                    Library:Notify("Mission creation failed, resetting lobby...", 2)
                    LeaveMission()
                    missionBusy = false
                    task.wait(0.5)
                    continue
                end
                
                Library:Notify("Recreating mission to ensure stability...", 3)
                LeaveMission()
                task.wait(0.3)
                CreateMission(currentMission, obj, currentDifficulty)
                task.wait(0.2)
                
                local recreateSuccess = false
                for retry = 1, 3 do
                    if GetMyMission() then
                        recreateSuccess = true
                        break
                    end
                    task.wait(0.3)
                end
                if not recreateSuccess then
                    Library:Notify("Recreate failed, restarting loop", 3)
                    LeaveMission()
                    missionBusy = false
                    task.wait(1)
                    continue
                end
                Library:Notify("Mission ready", 3)
                
                local selectedMods = {}
                pcall(function()
                    if Options and Options.MissionModifiersDropdown and Options.MissionModifiersDropdown.Value then
                        local val = Options.MissionModifiersDropdown.Value
                        if type(val) == "table" then
                            for mod, enabled in pairs(val) do
                                if enabled then table.insert(selectedMods, mod) end
                            end
                        end
                    end
                end)
                
                if #selectedMods > 0 then
                    for retry = 1, 2 do
                        if not missionRunning then break end
                        SafeMissionCall("S_Missions", "ClearModifiers")
                        task.wait(0.2)
                    end
                    task.wait(0.3)
                    local applied = 0
                    for _, mod in ipairs(selectedMods) do
                        if not missionRunning then break end
                        local success = false
                        for retry = 1, 3 do
                            success = ApplyModifier(mod)
                            if success then break end
                            task.wait(0.3)
                        end
                        if success then applied = applied + 1 end
                        task.wait(0.5)                      end
                    task.wait(0.4)
                    Library:Notify(string.format("Applied %d/%d modifiers", applied, #selectedMods), 3)
                end
                
                if not missionRunning then
                    missionBusy = false
                    continue
                end
                
                Library:Notify("Starting mission", 2)
                StartMission()
                local startTick = tick()
                repeat task.wait(0.05) until not missionRunning or missionSessionId ~= mySession or tick() - startTick >= 0.45
            end
            missionBusy = false
        end
    end

    MissionTab:AddDropdown("MissionDropdown", {
        Values = {"Shiganshina","Trost","Outskirts","Forest","Utgard","Docks","Stohess"},
        Default = State_Mission.Name,
        Text = "Mission",
        Callback = function(val)
            State_Mission.Name = val
            local newObjs = MissionObjectives[val] or {"Skirmish"}
            State_Mission.Objective = newObjs[1]
            if Options and Options.MissionObjectiveDropdown then
                Options.MissionObjectiveDropdown:SetValues(newObjs)
                Options.MissionObjectiveDropdown:SetValue(newObjs[1])
            end
        end
    })

    MissionTab:AddDropdown("MissionObjectiveDropdown", {
        Values = MissionObjectives["Shiganshina"],
        Default = State_Mission.Objective,
        Text = "Objective",
        Callback = function(val) State_Mission.Objective = val end
    })

    MissionTab:AddDropdown("MissionDifficultyDropdown", {
        Values = {"Easy","Normal","Hard","Severe","Aberrant","Hardest"},
        Default = State_Mission.Difficulty,
        Text = "Mode",
        Callback = function(val) State_Mission.Difficulty = val end
    })

    MissionTab:AddDropdown("MissionModifiersDropdown", {
        Values = ModifiersList,
        Default = {},
        Multi = true,
        Text = "Modifiers",
        Callback = function() end
    })

    MissionTab:AddSlider("MissionDelaySlider", {
        Text = "Delay",
        Default = MissionDelay,
        Min = 0, Max = 60, Rounding = 0,
        Callback = function(v) MissionDelay = v end
    })

        local activeAutoContent = nil  

        local missionPendingStart = false
    local missionStartTask = nil

    local missionToggle = MissionTab:AddToggle("AutoStartMissionToggle", {
        Text = "Start Mission",
        Default = false,
        Callback = function(v)
            if v then
                if missionRunning or missionPendingStart then return end
                if activeAutoContent ~= nil then
                    Library:Notify("Select one Toggle", 2)
                    pcall(function()
                        if Options and Options.AutoStartMissionToggle then
                            Options.AutoStartMissionToggle:SetValue(false)
                        end
                    end)
                    return
                end
                activeAutoContent = "mission"
                missionPendingStart = true
                missionStartTask = task.spawn(function()
                    while missionPendingStart do
                        if isUIActive() then
                            Library:Notify("Content Ready (Mission)", 2)
                            break
                        end
                        task.wait(0.5)
                    end
                    if missionPendingStart then
                        missionRunning = true
                        missionBusy = false
                        missionSessionId = missionSessionId + 1
                        task.spawn(MissionLoop, missionSessionId)
                    end
                    missionPendingStart = false
                end)
            else
                missionPendingStart = false
                if missionStartTask then task.cancel(missionStartTask) end
                missionRunning = false
                missionSessionId = missionSessionId + 1
                LeaveMission()
                if activeAutoContent == "mission" then activeAutoContent = nil end
            end
        end
    })

        local RaidTab = AutoMissionTabbox:AddTab("Raid")

    local RaidObjectives = {
        ["Attack Titan"] = {name = "Trost", objective = "Attack Titan", hasMinimum = false},
        ["Armored Titan"] = {name = "Shiganshina", objective = "Armored Titan", hasMinimum = false},
        ["Female Titan"] = {name = "Stohess", objective = "Female Titan", hasMinimum = false},
        ["Colossal Titan"] = {name = "Shiganshina", objective = "Colossal Titan", hasMinimum = true, minimum = 3}
    }

    local State_Raid = { Boss = "Attack Titan", Difficulty = "Hardest" }
    local RaidDelay = 0
    local raidRunning = false
    local raidBusy = false
    local raidSessionId = 0
    local lastNotifiedRaidMods = ""

    pcall(function()
        if Options and Options.RaidBossDropdown and Options.RaidBossDropdown.Value then State_Raid.Boss = Options.RaidBossDropdown.Value end
        if Options and Options.RaidDifficultyDropdown and Options.RaidDifficultyDropdown.Value then State_Raid.Difficulty = Options.RaidDifficultyDropdown.Value end
        if Options and Options.RaidDelaySlider and Options.RaidDelaySlider.Value then RaidDelay = tonumber(Options.RaidDelaySlider.Value) or 0 end
    end)

        local function CreateRaidWithRetry(bossName, difficulty)
        local maxRetries = 3
        for attempt = 1, maxRetries do
            if not raidRunning then return false end
            local data = RaidObjectives[bossName]
            if not data then return false end
            local createArgs = {
                Difficulty = difficulty,
                Type = "Raids",
                Name = data.name,
                Objective = data.objective
            }
            if data.hasMinimum then createArgs.Minimum = data.minimum end
            local success, _ = SafeMissionCall("S_Missions", "Create", createArgs)
            if success then
                task.wait(0.15)
                return true
            end
            if attempt < maxRetries then
                Library:Notify(string.format("Raid creation failed, retry %d/%d in 3s", attempt, maxRetries), 2)
                task.wait(3)
            else
                Library:Notify("Raid creation failed after 3 attempts, stopping", 3)
                return false
            end
        end
        return false
    end

        local function CreateRaid(bossName, difficulty)
        return CreateRaidWithRetry(bossName, difficulty)
    end

    local function ClearRaidModifiers()
        if not raidRunning then return end
        for retry = 1, 2 do
            if not raidRunning then break end
            local success = SafeMissionCall("S_Missions", "ClearModifiers")
            if success then break end
            task.wait(0.2)
        end
        task.wait(0.3)
    end

    local function ApplyRaidModifiers()
        if not raidRunning then return end
        local selected = {}
        pcall(function()
            if Options and Options.RaidModifiersDropdown and Options.RaidModifiersDropdown.Value then
                local val = Options.RaidModifiersDropdown.Value
                if type(val) == "table" then
                    for mod, enabled in pairs(val) do
                        if enabled then table.insert(selected, mod) end
                    end
                end
            end
        end)
        if #selected == 0 then return end
        local modsString = table.concat(selected, ", ")
        if lastNotifiedRaidMods ~= modsString then
            lastNotifiedRaidMods = modsString
        end
        ClearRaidModifiers()
        if not raidRunning then return end
        for _, mod in ipairs(selected) do
            if not raidRunning then break end
            local success = false
            for retry = 1, 3 do
                if not raidRunning then break end
                success = ApplyModifier(mod)
                if success then break end
                task.wait(0.3)
            end
            task.wait(0.5)          end
        task.wait(0.4)
    end

    local function StartRaid()
        if not raidRunning then return end
        task.wait(0.1)
        SafeMissionCall("S_Missions", "Start")
    end

    local function LeaveRaid()
        SafeMissionCall("S_Missions", "Leave")
    end

        local function RaidLoop(mySession)
        task.wait(1)
        if RaidDelay > 0 then task.wait(RaidDelay) end
        
        while raidRunning and raidSessionId == mySession do
            if raidBusy then task.wait(0.05); continue end
            raidBusy = true
            local currentBoss = State_Raid.Boss
            local currentDifficulty = State_Raid.Difficulty

            if currentDifficulty == "Hardest" then
                local cycle = GetDifficultyCycle("Raids")
                local created = false
                local targetDiff = nil
                
                for _, diff in ipairs(cycle) do
                    if not raidRunning or raidSessionId ~= mySession then break end
                    if State_Raid.Difficulty ~= "Hardest" then break end
                    
                    CreateRaid(currentBoss, diff)
                    task.wait(0.2)
                    
                    if GetMyMission() then
                        Library:Notify(string.format("Found suitable raid difficulty: %s", diff), 3)
                        targetDiff = diff
                        created = true
                        break
                    else
                        LeaveRaid()
                        task.wait(0.5)
                    end
                    
                    if not raidRunning then break end
                end
                
                if not created then
                    Library:Notify("Raid creation failed, retrying later", 3)
                    raidBusy = false
                    task.wait(2)
                    continue
                end
                
                
                Library:Notify("Leaving current raid...", 3)
                LeaveRaid()
                task.wait(0.3)
                
               
                Library:Notify(string.format("Recreating raid with difficulty: %s", targetDiff), 3)
                CreateRaid(currentBoss, targetDiff)
                task.wait(0.2)
                local ok = false
                for retry = 1, 3 do
                    if GetMyMission() then ok = true; break end
                    task.wait(0.3)
                end
                if not ok then
                    Library:Notify("Raid recreate failed, restarting", 3)
                    LeaveRaid()
                    raidBusy = false
                    task.wait(1)
                    continue
                end
                Library:Notify("Raid recreated successfully!", 3)
                
                local selectedMods = {}
                pcall(function()
                    if Options and Options.RaidModifiersDropdown and Options.RaidModifiersDropdown.Value then
                        local val = Options.RaidModifiersDropdown.Value
                        if type(val) == "table" then
                            for mod, enabled in pairs(val) do
                                if enabled then table.insert(selectedMods, mod) end
                            end
                        end
                    end
                end)
                
                if #selectedMods > 0 then
                    for retry = 1, 2 do SafeMissionCall("S_Missions", "ClearModifiers") task.wait(0.2) end
                    task.wait(0.3)
                    local applied = 0
                    for _, mod in ipairs(selectedMods) do
                        if not raidRunning then break end
                        local success = false
                        for retry = 1, 3 do
                            success = ApplyModifier(mod)
                            if success then break end
                            task.wait(0.3)
                        end
                        if success then applied = applied + 1 end
                        task.wait(0.5)                      end
                    task.wait(0.4)
                    Library:Notify(string.format("Applied %d/%d modifiers", applied, #selectedMods), 3)
                end
                
                if not raidRunning then
                    raidBusy = false
                    continue
                end
                
                Library:Notify("Starting raid", 2)
                StartRaid()
                local startTick = tick()
                repeat task.wait(0.05) until not raidRunning or raidSessionId ~= mySession or tick() - startTick >= 3.5
                if RaidDelay > 0 then task.wait(RaidDelay) end
                
            else
                CreateRaid(currentBoss, currentDifficulty)
                task.wait(0.2)
                
                if not GetMyMission() then
                    Library:Notify("Raid creation failed, resetting lobby...", 2)
                    LeaveRaid()
                    raidBusy = false
                    task.wait(0.5)
                    continue
                end
                
                Library:Notify("Recreating raid for stability...", 3)
                LeaveRaid()
                task.wait(0.3)
                CreateRaid(currentBoss, currentDifficulty)
                task.wait(0.2)
                local ok = false
                for retry = 1, 3 do
                    if GetMyMission() then ok = true; break end
                    task.wait(0.3)
                end
                if not ok then
                    Library:Notify("Recreate failed, restarting", 3)
                    LeaveRaid()
                    raidBusy = false
                    task.wait(1)
                    continue
                end
                
                local selectedMods = {}
                pcall(function()
                    if Options and Options.RaidModifiersDropdown and Options.RaidModifiersDropdown.Value then
                        local val = Options.RaidModifiersDropdown.Value
                        if type(val) == "table" then
                            for mod, enabled in pairs(val) do
                                if enabled then table.insert(selectedMods, mod) end
                            end
                        end
                    end
                end)
                
                if #selectedMods > 0 then
                    for retry = 1, 2 do SafeMissionCall("S_Missions", "ClearModifiers") task.wait(0.2) end
                    task.wait(0.3)
                    local applied = 0
                    for _, mod in ipairs(selectedMods) do
                        if not raidRunning then break end
                        local success = false
                        for retry = 1, 3 do
                            success = ApplyModifier(mod)
                            if success then break end
                            task.wait(0.3)
                        end
                        if success then applied = applied + 1 end
                        task.wait(0.5)
                    end
                    task.wait(0.4)
                    Library:Notify(string.format("Applied %d/%d modifiers", applied, #selectedMods), 3)
                end
                
                if not raidRunning then
                    raidBusy = false
                    continue
                end
                
                Library:Notify("Starting raid", 2)
                StartRaid()
                local startTick = tick()
                repeat task.wait(0.05) until not raidRunning or raidSessionId ~= mySession or tick() - startTick >= 0.45
            end
            raidBusy = false
        end
    end

    RaidTab:AddDropdown("RaidBossDropdown", {
        Values = {"Attack Titan","Armored Titan","Female Titan","Colossal Titan"},
        Default = State_Raid.Boss,
        Text = "Raid Boss",
        Callback = function(v) State_Raid.Boss = v end
    })

    RaidTab:AddDropdown("RaidDifficultyDropdown", {
        Values = {"Easy","Normal","Hard","Severe","Aberrant","Hardest"},
        Default = State_Raid.Difficulty,
        Text = "Mode",
        Callback = function(v) State_Raid.Difficulty = v end
    })

    RaidTab:AddDropdown("RaidModifiersDropdown", {
        Values = ModifiersList,
        Default = {},
        Multi = true,
        Text = "Modifiers",
        Callback = function() end
    })

    RaidTab:AddSlider("RaidDelaySlider", {
        Text = "Delay",
        Default = RaidDelay,
        Min = 0, Max = 60, Rounding = 0,
        Callback = function(v) RaidDelay = v end
    })

        local raidPendingStart = false
    local raidStartTask = nil

    local raidToggle = RaidTab:AddToggle("AutoRaidToggle", {
        Text = "Start Raid",
        Default = false,
        Callback = function(v)
            if v then
                if raidRunning or raidPendingStart then return end
                if activeAutoContent ~= nil then
                    Library:Notify("Select one Toggle", 2)
                    pcall(function()
                        if Options and Options.AutoRaidToggle then
                            Options.AutoRaidToggle:SetValue(false)
                        end
                    end)
                    return
                end
                activeAutoContent = "raid"
                raidPendingStart = true
                raidStartTask = task.spawn(function()
                    while raidPendingStart do
                        if isUIActive() then
                            Library:Notify("Content Ready (Raid)", 2)
                            break
                        end
                        task.wait(0.5)
                    end
                    if raidPendingStart then
                        raidRunning = true
                        raidBusy = false
                        raidSessionId = raidSessionId + 1
                        task.spawn(RaidLoop, raidSessionId)
                    end
                    raidPendingStart = false
                end)
            else
                raidPendingStart = false
                if raidStartTask then task.cancel(raidStartTask) end
                raidRunning = false
                raidSessionId = raidSessionId + 1
                LeaveRaid()
                if activeAutoContent == "raid" then activeAutoContent = nil end
            end
        end
    })

        local WavesTab = AutoMissionTabbox:AddTab("Waves")

    local wavesRunning = false
    local wavesBusy = false
    local wavesSessionId = 0
    local wavesDelay = 0
    local wavesCooldownUntil = 0  
        local function CreateWaveWithRetry()
        local maxRetries = 3
        for attempt = 1, maxRetries do
            if not wavesRunning then return false end
            local success, _ = SafeMissionCall("S_Missions", "Create", {
                Difficulty = "Easy",
                Type = "Waves",
                Name = "Trost",
                Objective = "Waves"
            })
            if success then
                task.wait(0.15)
                return true
            end
            if attempt < maxRetries then
                Library:Notify(string.format("Wave creation failed, retry %d/%d in 3s", attempt, maxRetries), 2)
                task.wait(3)
            else
                Library:Notify("Wave creation failed after 3 attempts, stopping", 3)
                return false
            end
        end
        return false
    end

        local function CreateWave()
        return CreateWaveWithRetry()
    end

    local function StartWave()
        if not wavesRunning then return end
        task.wait(0.1)
        SafeMissionCall("S_Missions", "Start")
    end

    local function LeaveWave()
        SafeMissionCall("S_Missions", "Leave")
    end

    local function WavesLoop(mySession)
        task.wait(1)
        
        while wavesRunning and wavesSessionId == mySession do
                        local now = tick()
            if now < wavesCooldownUntil then
                local remaining = math.ceil(wavesCooldownUntil - now)
                if remaining > 0 then
                    task.wait(remaining)
                end
                continue
            end
            
            if wavesBusy then
                task.wait(0.05)
                continue
            end
            wavesBusy = true

            CreateWave()
            task.wait(0.2)

            if not wavesRunning then 
                wavesBusy = false
                break 
            end

            Library:Notify("Creating wave", 2)
            Library:Notify("Starting wave", 2)
            StartWave()

            local startTick = tick()
            repeat
                task.wait(0.05)
                if not wavesRunning or wavesSessionId ~= mySession then break end
            until tick() - startTick >= 0.45

                        if wavesDelay > 0 then
                wavesCooldownUntil = tick() + wavesDelay
            end

            wavesBusy = false
        end
    end

        WavesTab:AddSlider("WavesDelaySlider", {
        Text = "Wave Delay",
        Default = 0,
        Min = 0,
        Max = 60,
        Rounding = 0,
        Suffix = " sec",
        Callback = function(v)
            wavesDelay = v
        end
    })

        local wavesPendingStart = false
    local wavesStartTask = nil

    local wavesToggle = WavesTab:AddToggle("AutoWavesToggle", {
        Text = "Start Waves",
        Default = false,
        Callback = function(v)
            if v then
                if wavesRunning or wavesPendingStart then return end
                if activeAutoContent ~= nil then
                    Library:Notify("Select one Toggle", 2)
                    pcall(function()
                        if Options and Options.AutoWavesToggle then
                            Options.AutoWavesToggle:SetValue(false)
                        end
                    end)
                    return
                end
                activeAutoContent = "waves"
                wavesPendingStart = true
                wavesStartTask = task.spawn(function()
                    while wavesPendingStart do
                        if isUIActive() then
                            Library:Notify("Content Ready (Waves)", 2)
                            break
                        end
                        task.wait(0.5)
                    end
                    if wavesPendingStart then
                                                if wavesDelay > 0 then
                            wavesCooldownUntil = tick() + wavesDelay
                            Library:Notify(string.format("Wave cooldown started: %d seconds", wavesDelay), 2)
                        end
                        wavesRunning = true
                        wavesBusy = false
                        wavesSessionId = wavesSessionId + 1
                        local mySession = wavesSessionId
                        task.spawn(function()
                            WavesLoop(mySession)
                        end)
                    end
                    wavesPendingStart = false
                end)
            else
                wavesPendingStart = false
                if wavesStartTask then task.cancel(wavesStartTask) end
                wavesRunning = false
                wavesBusy = false
                wavesSessionId = wavesSessionId + 1
                wavesCooldownUntil = 0                  LeaveWave()
                if activeAutoContent == "waves" then activeAutoContent = nil end
            end
        end
    })

end
if IsLobbyLobby() then
    local UpgradeTabbox = Tabs.Session:AddLeftTabbox("Auto Upgrade")

        local activeUpgradeType = nil 

        local function switchToBlades()
        local Event = game:GetService("ReplicatedStorage").Assets.Remotes.GET
        local Result = Event:InvokeServer(
            "S_Equipment",
            "Weapon",
            "Blades"
        )
                return true
    end

    local function switchToSpears()
        local Event = game:GetService("ReplicatedStorage").Assets.Remotes.GET
        local Result = Event:InvokeServer(
            "S_Equipment",
            "Weapon",
            "Spears"
        )
                return true
    end

        local function getGoldAmount()
        local player = game:GetService("Players").LocalPlayer
        local gold = 0
        pcall(function()
            local topbar = player.PlayerGui.Interface.Topbar.Main.Currencies
            if topbar then
                local goldLabel = topbar.Gold and topbar.Gold:FindFirstChild("Amount")
                if goldLabel and goldLabel.Text then
                    local goldText = goldLabel.Text:gsub("[^%d]", "")
                    gold = tonumber(goldText) or 0
                end
            end
        end)
        return gold
    end

        local function isUpgradeReady()
        local player = game:GetService("Players").LocalPlayer
        local ready = false
        pcall(function()
            local equipment = player.PlayerGui.Interface:FindFirstChild("Equipment")
            if equipment then
                local statusLabel = equipment:FindFirstChild("Status") 
                                    or equipment:FindFirstChild("ReadyLabel")
                if statusLabel and statusLabel:IsA("TextLabel") then
                    if statusLabel.Text and statusLabel.Text:find("Ready") then
                        ready = true
                    end
                else
                    ready = true
                end
            else
                ready = true
            end
        end)
        return ready
    end

        local BladeTab = UpgradeTabbox:AddTab("Blade")

    getgenv().AutoUpgradeBlade = false
    getgenv().UpgradeRunning = false
    getgenv().BladeUpgradeDelay = 0

    local ALL_BLADE_STATS = {
        "ODM_Gas", "ODM_Speed", "ODM_Range", "ODM_Control",
        "Crit_Damage", "ODM_Damage", "Crit_Chance", "Blade_Durability"
    }

    local function batchUpgradeBlade()
        if not GET then return false end
        local args = { "S_Equipment", "Upgrade", ALL_BLADE_STATS }
        local success = pcall(function()
            GET:InvokeServer(unpack(args))
        end)
        return success
    end

    BladeTab:AddSlider("BladeUpgradeDelaySlider", {
        Text = "Upgrade Delay (seconds)",
        Default = 0,
        Min = 0,
        Max = 60,
        Rounding = 0,
        Callback = function(v)
            getgenv().BladeUpgradeDelay = v
        end
    })

    BladeTab:AddToggle("AutoUpgradeBladeToggle", {
        Text = "Auto Upgrade Blade",
        Default = false,
        Callback = function(state)
            if state then
                if activeUpgradeType == "spear" then
                    Library:Notify("Cannot enable Blade upgrade because Thunder Spear upgrade is already running. Please disable Thunder Spear upgrade first.", 4)
                    pcall(function()
                        if Options and Options.AutoUpgradeBladeToggle then
                            Options.AutoUpgradeBladeToggle:SetValue(false)
                        end
                    end)
                    return
                end
                                local success = switchToBlades()
                if not success then
                    Library:Notify("Failed to switch weapon to Blades. Upgrade may not work properly.", 4)
                else
                    Library:Notify("Switched weapon to Blades. Starting auto upgrade.", 3)
                end
                activeUpgradeType = "blade"
                getgenv().AutoUpgradeBlade = true
            else
                getgenv().AutoUpgradeBlade = false
                if activeUpgradeType == "blade" then
                    activeUpgradeType = nil
                end
            end

            if state and not getgenv().UpgradeRunning then
                getgenv().UpgradeRunning = true
                task.spawn(function()
                    local _pgB, _stB = -1, 0   -- [CHICKEN]
                    local _nUp, _g0 = 0, getGoldAmount()   -- [CHICKEN] ไว้ log ให้เห็นว่าทำจริง
                    while getgenv().AutoUpgradeBlade do
                        local ready = isUpgradeReady()
                        local gold = getGoldAmount()
                        local delay = getgenv().BladeUpgradeDelay

                        if ready and gold >= 1000 then
                            batchUpgradeBlade()
                            _nUp = _nUp + 1
                            if _nUp == 1 then
                                print(string.format("[UPGRADE] ⚙️ เริ่มอัพดาบ — ทอง %d", gold))
                            end
                            -- [CHICKEN] ทองไม่ลด 5 ครั้งติด = ตัน → ปิดเอง (เดิมยิงวนฟรีตลอด)
                            if _pgB >= 0 and gold >= _pgB then
                                _stB = _stB + 1
                                if _stB >= 5 then
                                    getgenv().AutoUpgradeBlade = false
                                    pcall(function()
                                        if Options and Options.AutoUpgradeBladeToggle then Options.AutoUpgradeBladeToggle:SetValue(false) end
                                    end)
                                    break
                                end
                            else
                                _stB = 0
                            end
                            _pgB = gold
                            task.wait(delay > 0 and delay or 1.5)   -- [CHICKEN] เดิม task.wait() = ทุกเฟรม
                        else
                            task.wait(2)
                        end
                    end
                    print(string.format("[UPGRADE] ✅ อัพดาบจบ — ยิงไป %d ครั้ง | ใช้ทอง %s",
                        _nUp, tostring(math.max(0, _g0 - getGoldAmount()))))
                    getgenv().UpgradeRunning = false
                end)
            end
        end
    })

        local SpearTab = UpgradeTabbox:AddTab("Thunder Spear")

    getgenv().AutoUpgradeSpear = false
    getgenv().SpearUpgradeRunning = false
    getgenv().SpearUpgradeDelay = 0

    local ALL_SPEAR_STATS = {
        "Blast_Radius",
        "TS_Damage",
        "TS_Gas",
        "TS_Range",
        "TS_Control",
        "Crit_Chance",
        "Crit_Damage",
        "TS_Speed"
    }

    local function batchUpgradeSpear()
        if not GET then return false end
        local args = { "S_Equipment", "Upgrade", ALL_SPEAR_STATS }
        local success = pcall(function()
            GET:InvokeServer(unpack(args))
        end)
        return success
    end

    SpearTab:AddSlider("SpearUpgradeDelaySlider", {
        Text = "Upgrade Delay (seconds)",
        Default = 0,
        Min = 0,
        Max = 60,
        Rounding = 0,
        Callback = function(v)
            getgenv().SpearUpgradeDelay = v
        end
    })

    SpearTab:AddToggle("AutoUpgradeSpearToggle", {
        Text = "Auto Upgrade Thunder Spear",
        Default = false,
        Callback = function(state)
            if state then
                if activeUpgradeType == "blade" then
                    Library:Notify("Cannot enable Thunder Spear upgrade because Blade upgrade is already running. Please disable Blade upgrade first.", 4)
                    pcall(function()
                        if Options and Options.AutoUpgradeSpearToggle then
                            Options.AutoUpgradeSpearToggle:SetValue(false)
                        end
                    end)
                    return
                end
                                local success = switchToSpears()
                if not success then
                    Library:Notify("Failed to switch weapon to Thunder Spear. Upgrade may not work properly.", 4)
                else
                    Library:Notify("Switched weapon to Thunder Spear. Starting auto upgrade.", 3)
                end
                activeUpgradeType = "spear"
                getgenv().AutoUpgradeSpear = true
            else
                getgenv().AutoUpgradeSpear = false
                if activeUpgradeType == "spear" then
                    activeUpgradeType = nil
                end
            end

            if state and not getgenv().SpearUpgradeRunning then
                getgenv().SpearUpgradeRunning = true
                task.spawn(function()
                    local _pgS, _stS = -1, 0   -- [CHICKEN]
                    while getgenv().AutoUpgradeSpear do
                        local ready = isUpgradeReady()
                        local gold = getGoldAmount()
                        local delay = getgenv().SpearUpgradeDelay

                        if ready and gold >= 1000 then
                            batchUpgradeSpear()
                            -- [CHICKEN] ทองไม่ลด 5 ครั้งติด = ตัน → ปิดเอง (เดิมยิงวนฟรีตลอด)
                            if _pgS >= 0 and gold >= _pgS then
                                _stS = _stS + 1
                                if _stS >= 5 then
                                    getgenv().AutoUpgradeSpear = false
                                    pcall(function()
                                        if Options and Options.AutoUpgradeSpearToggle then Options.AutoUpgradeSpearToggle:SetValue(false) end
                                    end)
                                    break
                                end
                            else
                                _stS = 0
                            end
                            _pgS = gold
                            task.wait(delay > 0 and delay or 1.5)   -- [CHICKEN] เดิม task.wait() = ทุกเฟรม
                        else
                            task.wait(2)
                        end
                    end
                    getgenv().SpearUpgradeRunning = false
                end)
            end
        end
    })
end

if IsLobbyLobby() then
    local UnlockGroupLeft = Tabs.Session:AddLeftGroupbox("Unlock Skills")

    local branches = {
        ["Support Left"] = {
            ids = {
                "70","71","72","73","74","75","76","77","78","79",
                "80","81","82","83","84","85","86","87","88","89"
            }
        },
        ["Support Right"] = {
            ids = {
                "70","71","72","73","74","75","76","77","78","79",
                "80","90","91","92","93","94","95","96","97","98"
            }
        },
        ["Offense Left"] = {
            ids = {
                "1","2","3","4","5","6","7","8","9","10","11","12","13",
                "26","27","28","29","30","31","32","33","34","35","36","37"
            }
        },
        ["Offense Right"] = {
            ids = {
                "1","2","3","4","5","6","7","8","9","10","11","12","13",
                "14","15","16","17","18","19","20","21","22","23","24","25"
            }
        },
        ["Defense Left"] = {
            ids = {
                "38","39","40","41","42","43","44","45",
                "58","59","60","61","62","63","64","65","66","67","68","69"
            }
        },
        ["Defense Right"] = {
            ids = {
                "38","39","40","41","42","43","44","45",
                "46","47","48","49","50","51","52","53","54","55","56","57"
            }
        }
    }

    local selected = { Support = nil, Offense = nil, Defense = nil }
    local isUnlocking = false
    local unlockDelay = 0.08

    local function createDropdown(category, text)
        local dropdown = UnlockGroupLeft:AddDropdown(category .. "SideDropdown", {
            Text = text,
            Values = {"None", "Left", "Right"},
            Default = "None",
            Multi = false,
            Callback = function(v)
                if v == "None" then 
                    selected[category] = nil 
                else 
                    selected[category] = v 
                end
            end
        })
        return dropdown
    end

    local supportDropdown = createDropdown("Support", "Support Side")
    local offenseDropdown = createDropdown("Offense", "Offense Side")
    local defenseDropdown = createDropdown("Defense", "Defense Side")

    UnlockGroupLeft:AddSlider("UnlockDelaySlider", {
        Text = "Unlock Delay (sec)",
        Default = 0.08,
        Min = 0.01,
        Max = 1,
        Rounding = 2,
        Callback = function(v) unlockDelay = v end
    })

    UnlockGroupLeft:AddDivider()

    local function unlockSingleId(id, retryCount)
        retryCount = retryCount or 0
        local success, err = pcall(function()
            GET:InvokeServer("S_Equipment", "Unlock", { id })
        end)
        if not success and retryCount < 3 then
            task.wait(0.2)
            return unlockSingleId(id, retryCount + 1)
        end
        return success, err
    end

    local function unlockBranch(ids)
        for _, id in ipairs(ids) do
            unlockSingleId(id)
            task.wait(unlockDelay)
        end
    end

    local function showGoldAndWait()
        while not (Window and Window.Holder and Window.Holder.Visible) do
            task.wait(0.1)
        end
        local player = game:GetService("Players").LocalPlayer
        local goldLabel = nil
        repeat
            task.wait(0.1)
            goldLabel = player.PlayerGui:FindFirstChild("Interface") and
                        player.PlayerGui.Interface:FindFirstChild("Topbar") and
                        player.PlayerGui.Interface.Topbar:FindFirstChild("Main") and
                        player.PlayerGui.Interface.Topbar.Main:FindFirstChild("Currencies") and
                        player.PlayerGui.Interface.Topbar.Main.Currencies:FindFirstChild("Gold") and
                        player.PlayerGui.Interface.Topbar.Main.Currencies.Gold:FindFirstChild("Amount")
        until goldLabel and goldLabel.Text and goldLabel.Text:gsub("[^%d]", "") ~= ""
        local goldText = goldLabel.Text:gsub("[^%d]", "")
        local goldAmount = tonumber(goldText) or 0
        Library:Notify(string.format("💰 Gold: %s", goldAmount), 3)
        task.wait(0.2)
    end

    UnlockGroupLeft:AddToggle("UnlockSkillsToggle", {
        Text = "Start Unlock Skills Blades",
        Default = false,
        Callback = function(v)
            if not v then return end
            if isUnlocking then
                pcall(function()
                    if Options and Options.UnlockSkillsToggle then
                        Options.UnlockSkillsToggle:SetValue(false)
                    end
                end)
                return
            end

            showGoldAndWait()

            local queue = {}
            if selected.Defense then
                local side = selected.Defense
                local branchName = "Defense " .. side
                table.insert(queue, branches[branchName].ids)
            end
            if selected.Offense then
                local side = selected.Offense
                local branchName = "Offense " .. side
                table.insert(queue, branches[branchName].ids)
            end
            if selected.Support then
                local side = selected.Support
                local branchName = "Support " .. side
                table.insert(queue, branches[branchName].ids)
            end

            if #queue == 0 then
                pcall(function()
                    if Options and Options.UnlockSkillsToggle then
                        Options.UnlockSkillsToggle:SetValue(false)
                    end
                end)
                return
            end

            isUnlocking = true
            task.spawn(function()
                for i, ids in ipairs(queue) do
                    unlockBranch(ids)
                    if i < #queue then
                        task.wait(unlockDelay)
                    end
                end
                isUnlocking = false
                pcall(function()
                    if Options and Options.UnlockSkillsToggle then
                        Options.UnlockSkillsToggle:SetValue(false)
                    end
                end)
            end)
        end
    })
end

if IsLobbyLobby() then

    local BoostGroup = Tabs.Lobby:AddRightGroupbox("Boost Selection")

    local purchaseAmount = 1
    local purchaseDelay = 0
    local isReady = false
    local pendingUseAfterPurchase = false
    local autoUseActive = false
    local autoUseTask = nil

    local ALL_BOOSTS = {
        "2X XP Boost [30M]", "2X Luck [30M]", "2X Gold [30M]",
        "2X XP Boost [1H]", "2X Luck [1H]", "2X Gold [1H]",
        "2X XP Boost [2H]", "2X Luck [2H]", "2X Gold [2H]"
    }

    local PRICE_MAP = {
        ["30M"] = 4499,
        ["1H"] = 7999,
        ["2H"] = 13999,
    }

    local function getBoostPrice(boostName)
        for duration, price in pairs(PRICE_MAP) do
            if boostName:find(duration) then
                return price
            end
        end
        return 0
    end

    local function formatNumberWithComma(num)
        local formatted = tostring(num)
        local k = 0
        for i = #formatted - 2, 1, -3 do
            k = k + 1
            formatted = formatted:sub(1, i) .. "," .. formatted:sub(i + 1)
        end
        return formatted
    end

    local BOOST_MAP = {
        ["2X XP Boost [30M]"] = {type = "xp", duration = "30M", id = 1},
        ["2X XP Boost [1H]"] = {type = "xp", duration = "1H", id = 2},
        ["2X XP Boost [2H]"] = {type = "xp", duration = "2H", id = 3},
        ["2X Luck [30M]"] = {type = "luck", duration = "30M", id = 4},
        ["2X Luck [1H]"] = {type = "luck", duration = "1H", id = 5},
        ["2X Luck [2H]"] = {type = "luck", duration = "2H", id = 6},
        ["2X Gold [30M]"] = {type = "gold", duration = "30M", id = 7},
        ["2X Gold [1H]"] = {type = "gold", duration = "1H", id = 8},
        ["2X Gold [2H]"] = {type = "gold", duration = "2H", id = 9},
    }

    local GET = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("GET")

    local function waitForUIMenu()
        while not (Window and Window.Holder and Window.Holder.Visible) do
            task.wait(0.05)
        end
    end

    local function waitForTopbar()
        local player = game:GetService("Players").LocalPlayer
        local playerGui = player:WaitForChild("PlayerGui", 10)
        local interface = playerGui:WaitForChild("Interface", 10)
        local topbar = interface:WaitForChild("Topbar", 10)
        return topbar
    end

    local function checkCurrencies()
        local gemsAmount = 0
        local goldAmount = 0
        pcall(function()
            local topbar = waitForTopbar()
            local main = topbar:FindFirstChild("Main")
            if main then
                local currencies = main:FindFirstChild("Currencies")
                if currencies then
                    local gemsLabel = currencies:FindFirstChild("Gems") and currencies.Gems:FindFirstChild("Amount")
                    local goldLabel = currencies:FindFirstChild("Gold") and currencies.Gold:FindFirstChild("Amount")
                    if gemsLabel and gemsLabel.Text then
                        local gemText = gemsLabel.Text:gsub("[^%d]", "")
                        gemsAmount = tonumber(gemText) or 0
                    end
                    if goldLabel and goldLabel.Text then
                        local goldText = goldLabel.Text:gsub("[^%d]", "")
                        goldAmount = tonumber(goldText) or 0
                    end
                end
            end
        end)
        return gemsAmount, goldAmount
    end

    local function startReadyCheck()
        task.spawn(function()
            waitForUIMenu()
            waitForTopbar()
            while true do
                local gemsAmount, goldAmount = checkCurrencies()
                if gemsAmount > 1 or goldAmount > 1 then
                    isReady = true
                else
                    isReady = false
                end
                task.wait(2)
            end
        end)
    end

    startReadyCheck()

    local function purchaseBoost(boostName)
        local data = BOOST_MAP[boostName]
        if not data then return false end
        if not isReady then return false end
        local args = {"S_Market", "Buy", "1_Boosts", data.id, purchaseAmount}
        return pcall(function() GET:InvokeServer(unpack(args)) end)
    end

    local function useBoost(boostName)
        local args = {"S_Inventory", "Item", boostName}
        return pcall(function() GET:InvokeServer(unpack(args)) end)
    end

    local function IsActuallyVisible(gui)
        if not gui or not gui:IsA("GuiObject") then return false end
        if not gui.Visible then return false end
        local current = gui.Parent
        while current do
            if current:IsA("GuiObject") and not current.Visible then return false end
            if current:IsA("ScreenGui") and not current.Enabled then return false end
            current = current.Parent
        end
        return true
    end

    local function isLobbyUIVisible()
        local interface = PlayerGui:FindFirstChild("Interface")
        if not interface then return false end
        local keyVisible = false
        local categoriesVisible = false
        local gearUp = interface:FindFirstChild("Gear_Up")
        if gearUp then
            local lobby = gearUp:FindFirstChild("Lobby")
            if lobby then
                local key = lobby:FindFirstChild("Key")
                if key then keyVisible = IsActuallyVisible(key) end
            end
        end
        local topbar = interface:FindFirstChild("Topbar")
        if topbar then
            local main = topbar:FindFirstChild("Main")
            if main then
                local categories = main:FindFirstChild("Categories")
                if categories then categoriesVisible = IsActuallyVisible(categories) end
            end
        end
        return keyVisible or categoriesVisible
    end

    local function startAutoUse()
        if autoUseTask then return end
        autoUseActive = true
        autoUseTask = task.spawn(function()
            while autoUseActive do
                if not isLobbyUIVisible() then
                    task.wait(0.1)
                    continue
                end

                if pendingUseAfterPurchase then
                    pendingUseAfterPurchase = false
                    local purchaseSelection = {}
                    pcall(function()
                        if Options and Options.Boost_ListDropdown and Options.Boost_ListDropdown.Value then
                            purchaseSelection = Options.Boost_ListDropdown.Value
                        end
                    end)
                    for boostName, enabled in pairs(purchaseSelection) do
                        if enabled and not autoUseActive then break end
                        if not isReady then 
                            task.wait(0.05)
                            break
                        end
                        useBoost(boostName)
                        task.wait(0.3)
                    end
                    if not autoUseActive then break end
                end

                local durations = {"2h", "1h", "30m"}
                local roundsPerDuration = 5
                for _, dur in ipairs(durations) do
                    if not autoUseActive then break end
                    for round = 1, roundsPerDuration do
                        if not autoUseActive then break end
                        if not isReady then 
                            task.wait(0.05)
                            break
                        end
                        local goldName = "2x Gold Boost [" .. dur .. "]"
                        useBoost(goldName)
                        task.wait()
                        if not autoUseActive then break end
                        if not isReady then 
                            task.wait(0.05)
                            break
                        end
                        local luckName = "2x Luck Boost [" .. dur .. "]"
                        useBoost(luckName)
                        task.wait()
                        if not autoUseActive then break end
                        if not isReady then 
                            task.wait(0.05)
                            break
                        end
                        local xpName = "2x XP Boost [" .. dur .. "]"
                        useBoost(xpName)
                        task.wait()
                    end
                    if not autoUseActive then break end
                end
                break
            end
            autoUseActive = false
            pcall(function()
                if Options and Options.Boost_AutoUseToggle then
                    Options.Boost_AutoUseToggle:SetValue(false)
                end
            end)
            autoUseTask = nil
        end)
    end

    BoostGroup:AddDropdown("Boost_ListDropdown", {
        Text = " --- Select Boosts ---",
        Values = ALL_BOOSTS,
        Default = {},
        Multi = true,
        Callback = function() end
    })

    BoostGroup:AddSlider("Boost_AmountSlider", {
        Text = "Amount",
        Default = 1, Min = 1, Max = 50, Rounding = 0,
        Callback = function(v) purchaseAmount = v end
    })

    BoostGroup:AddSlider("Boost_DelaySlider", {
        Text = "Purchase Delay (seconds)",
        Default = 0, Min = 0, Max = 60, Rounding = 0,
        Callback = function(v) purchaseDelay = v end
    })

    BoostGroup:AddToggle("Boost_PurchaseToggle", {
        Text = "Purchase",
        Default = false,
        Callback = function(v)
            if v then
                task.wait(1)

                local purchaseSelection = {}
                pcall(function()
                    if Options and Options.Boost_ListDropdown and Options.Boost_ListDropdown.Value then
                        purchaseSelection = Options.Boost_ListDropdown.Value
                    end
                end)

                local selectedNames = {}
                for boostName, enabled in pairs(purchaseSelection) do
                    if enabled then
                        table.insert(selectedNames, boostName)
                    end
                end

                if #selectedNames == 0 then
                    pcall(function()
                        if Options and Options.Boost_PurchaseToggle then
                            Options.Boost_PurchaseToggle:SetValue(false)
                        end
                    end)
                    Library:Notify("Please select at least one boost to purchase!", 3)
                    return
                end

                if not isReady then
                    pcall(function()
                        if Options and Options.Boost_PurchaseToggle then
                            Options.Boost_PurchaseToggle:SetValue(false)
                        end
                    end)
                    Library:Notify("Currency not ready yet. Please wait.", 3)
                    return
                end

                task.spawn(function()
                    local successCount = 0
                    for boostName, enabled in pairs(purchaseSelection) do
                        if enabled then
                            if not isReady then break end
                            local ok = purchaseBoost(boostName)
                            if ok then successCount = successCount + 1 end
                            if purchaseDelay > 0 then task.wait(purchaseDelay) else task.wait(0.15) end
                        end
                    end
                    Library:Notify(string.format("Purchased %d boost(s).", successCount), 3)

                    if Options and Options.Boost_AutoUseToggle and Options.Boost_AutoUseToggle.Value then
                        pendingUseAfterPurchase = true
                        if not autoUseActive then
                            startAutoUse()
                        end
                    end

                    pcall(function()
                        if Options and Options.Boost_PurchaseToggle then
                            Options.Boost_PurchaseToggle:SetValue(false)
                        end
                    end)
                end)
            else
                
            end
        end
    })

    BoostGroup:AddToggle("Boost_AutoUseToggle", {
        Text = "Auto Use All Boosts",
        Default = false,
        Callback = function(v)
            if v then
                task.wait(1)

                if autoUseActive then 
                    return 
                end

                local purchaseEnabled = false
                pcall(function()
                    if Options and Options.Boost_PurchaseToggle then
                        purchaseEnabled = Options.Boost_PurchaseToggle.Value
                    end
                end)

                if purchaseEnabled then
                    pendingUseAfterPurchase = true
                else
                    startAutoUse()
                end
            else
                autoUseActive = false
                pendingUseAfterPurchase = false
                if autoUseTask then
                    task.cancel(autoUseTask)
                    autoUseTask = nil
                end
            end
        end
    })
end
if IsLobbyLobby() then
    local PrestigeGroup = Tabs.Session:AddRightGroupbox("Prestige")

        getgenv().PrestigeEnabled = false
    getgenv().SelectedBoost = "Gold Boost"
    getgenv().ForceGoldRequirement = false

        local DEFAULT_GOLD_REQUIREMENTS_M = {200, 400, 600, 800, 1000}
    getgenv().PrestigeGoldRequirement = {200, 400, 600, 800, 1000}
    
        local SLIDER_RANGES = {
        {min = 0,   max = 200}, 
        {min = 0,   max = 400}, 
        {min = 0,   max = 600},   
        {min = 0,   max = 800},  
        {min = 0,   max = 1000}, 
    }
    
        local function syncFromOptions()
        if Options then
            for i = 1, 5 do
                local optName = "GoldReq_"..(i-1).."to"..i
                if Options[optName] and Options[optName].Value ~= nil then
                    getgenv().PrestigeGoldRequirement[i] = Options[optName].Value
                else
                    getgenv().PrestigeGoldRequirement[i] = DEFAULT_GOLD_REQUIREMENTS_M[i]
                end
            end
            if Options.BoostDropdown and Options.BoostDropdown.Value then
                getgenv().SelectedBoost = Options.BoostDropdown.Value
            end
            if Options.ForceGoldToggle ~= nil then
                getgenv().ForceGoldRequirement = Options.ForceGoldToggle.Value or false
            end
            if Options.PrestigeToggle ~= nil then
                getgenv().PrestigeEnabled = Options.PrestigeToggle.Value or false
            end
        end
    end

    syncFromOptions()

    local MAX_LEVEL_FOR_PRESTIGE = {100, 125, 150, 175, 200}

    local AllTalents = {
        "Crescendo", "Blitzblade", "Swiftshot", "Surgeshot",
        "Stalwart", "Stormcharged",
        "Quakestrike", "Furyforge", "Assassin", "Amputation", "Marksman",
        "Overslash", "Gambler", "Afterimages",
        "Guardian", "Deflectra",
        "Aegisurge", "Riposte",
        "Resilience", "Vengeflare", "Steel Frame",
        "Necromantic", "Thanatophobia",
        "Cooldown Blitz", "Mendmaster",
        "Lifefeed", "Vitalize", "Gem Fiend",
        "Omnirange", "Flashstep", "Tactician",
        "Bloodthief", "Apotheosis"
    }

    local RemainingTalents = {}
    local function resetTalentPool()
        RemainingTalents = {}
        for _, t in ipairs(AllTalents) do table.insert(RemainingTalents, t) end
    end
    resetTalentPool()

    local function getRandomTalent()
        if #RemainingTalents == 0 then return nil end
        local idx = math.random(1, #RemainingTalents)
        local talent = RemainingTalents[idx]
        table.remove(RemainingTalents, idx)
        return talent
    end

    local PrestigeCooldown = 0.3
    local PrestigeRunning = false

        local lastGoldNotifyStep = -1
    local lastGoldNotifyStatus = nil

        local function getGold()
        local player = game:GetService("Players").LocalPlayer
        local gold = 0
        pcall(function()
            local topbar = player.PlayerGui.Interface.Topbar.Main.Currencies
            if topbar then
                local goldLabel = topbar.Gold and topbar.Gold:FindFirstChild("Amount")
                if goldLabel and goldLabel.Text then
                    local goldText = goldLabel.Text:gsub("[^%d]", "")
                    gold = tonumber(goldText) or 0
                end
            end
        end)
        return gold
    end

    local function getLevel()
        local player = game:GetService("Players").LocalPlayer
        local level = 0
        pcall(function()
            local levelLabel = player.PlayerGui.Interface.Gear_Up.HUD.Level.Title
            if levelLabel and levelLabel.Text then
                local levelText = levelLabel.Text:match("%d+")
                level = tonumber(levelText) or 0
            end
        end)
        return level
    end

    local function getXPPercent()
        local player = game:GetService("Players").LocalPlayer
        local percent = 0
        pcall(function()
            local xpLabel = player.PlayerGui.Interface.Gear_Up.XP.Percentage
            if xpLabel and xpLabel.Text then
                local xpText = xpLabel.Text:match("(%d+)%%")
                percent = tonumber(xpText) or 0
            end
        end)
        return percent
    end

    PrestigeGroup:AddSlider("GoldReq_0to1", { 
        Text = "       0 → 1  (200M)", 
        Default = getgenv().PrestigeGoldRequirement[1], 
        Min = SLIDER_RANGES[1].min, 
        Max = SLIDER_RANGES[1].max, 
        Rounding = 0, 
        Suffix = "M", 
        Callback = function(v) getgenv().PrestigeGoldRequirement[1] = math.floor(v) end 
    })
    PrestigeGroup:AddSlider("GoldReq_1to2", { 
        Text = "       1 → 2  (400M)", 
        Default = getgenv().PrestigeGoldRequirement[2], 
        Min = SLIDER_RANGES[2].min, 
        Max = SLIDER_RANGES[2].max, 
        Rounding = 0, 
        Suffix = "M", 
        Callback = function(v) getgenv().PrestigeGoldRequirement[2] = math.floor(v) end 
    })
    PrestigeGroup:AddSlider("GoldReq_2to3", { 
        Text = "       2 → 3  (600M)", 
        Default = getgenv().PrestigeGoldRequirement[3], 
        Min = SLIDER_RANGES[3].min, 
        Max = SLIDER_RANGES[3].max, 
        Rounding = 0, 
        Suffix = "M", 
        Callback = function(v) getgenv().PrestigeGoldRequirement[3] = math.floor(v) end 
    })
    PrestigeGroup:AddSlider("GoldReq_3to4", { 
        Text = "       3 → 4  (800M)", 
        Default = getgenv().PrestigeGoldRequirement[4], 
        Min = SLIDER_RANGES[4].min, 
        Max = SLIDER_RANGES[4].max, 
        Rounding = 0, 
        Suffix = "M", 
        Callback = function(v) getgenv().PrestigeGoldRequirement[4] = math.floor(v) end 
    })
    PrestigeGroup:AddSlider("GoldReq_4to5", { 
        Text = "       4 → 5  (1000M)", 
        Default = getgenv().PrestigeGoldRequirement[5], 
        Min = SLIDER_RANGES[5].min, 
        Max = SLIDER_RANGES[5].max, 
        Rounding = 0, 
        Suffix = "M", 
        Callback = function(v) getgenv().PrestigeGoldRequirement[5] = math.floor(v) end 
    })

    PrestigeGroup:AddDropdown("BoostDropdown", { 
        Values = {"Luck Boost","Exp Boost","Gold Boost"}, 
        Default = getgenv().SelectedBoost, 
        Text = "Boost", 
        Callback = function(v) getgenv().SelectedBoost = v end 
    })
    PrestigeGroup:AddSlider("PrestigeCooldownSlider", { 
        Text = "Delay", 
        Default = PrestigeCooldown, 
        Min = 0.2, 
        Max = 2, 
        Rounding = 1, 
        Suffix = "s", 
        Callback = function(v) PrestigeCooldown = v end 
    })
    PrestigeGroup:AddToggle("ForceGoldToggle", { 
        Text = "Force Gold Requirement", 
        Default = getgenv().ForceGoldRequirement, 
        Callback = function(v) 
            getgenv().ForceGoldRequirement = v
            lastGoldNotifyStep = -1
            lastGoldNotifyStatus = nil
        end 
    })
    PrestigeGroup:AddToggle("PrestigeToggle", { 
        Text = "Auto Prestige", 
        Default = getgenv().PrestigeEnabled, 
        Callback = function(v) 
            getgenv().PrestigeEnabled = v
            if not v then
                lastGoldNotifyStep = -1
                lastGoldNotifyStatus = nil
            end
        end 
    })

        local function canPrestige(currentPrestige, currentLevel, currentXP, currentGold)
        if currentPrestige >= 5 then return false, "max" end
        local requiredLevel = MAX_LEVEL_FOR_PRESTIGE[currentPrestige + 1]
        if currentLevel < requiredLevel then return false, "level" end
        if currentXP < 100 then return false, "xp" end
        
        if getgenv().ForceGoldRequirement then
            local requiredGoldM = getgenv().PrestigeGoldRequirement[currentPrestige + 1] or 0
            local requiredGold = requiredGoldM * 1000000
            if currentGold < requiredGold then
                if lastGoldNotifyStep ~= currentPrestige or lastGoldNotifyStatus ~= false then
                    lastGoldNotifyStep = currentPrestige
                    lastGoldNotifyStatus = false
                    local needM = requiredGoldM
                    local currentM = math.floor(currentGold / 1000000)
                    Library:Notify(string.format("💰 Gold not enough for Prestige %d→%d: need %dM, have %dM", currentPrestige, currentPrestige+1, needM, currentM), 3)
                end
                return false, "gold"
            else
                if lastGoldNotifyStep ~= currentPrestige or lastGoldNotifyStatus ~= true then
                    lastGoldNotifyStep = currentPrestige
                    lastGoldNotifyStatus = true
                    Library:Notify(string.format("✅ Gold requirement met for Prestige %d→%d", currentPrestige, currentPrestige+1), 3)
                end
            end
        end
        return true, "ok"
    end

    local function doPrestige()
        if not getgenv().PrestigeEnabled then return false end

        local player = game:GetService("Players").LocalPlayer
        local currentPrestige = player:GetAttribute("Prestige") or 0
        local currentLevel = getLevel()
        local currentXP = getXPPercent()
        local currentGold = getGold()

        local can, reason = canPrestige(currentPrestige, currentLevel, currentXP, currentGold)

        if not can then
            if reason == "max" then
                if getgenv().PrestigeEnabled then
                    getgenv().PrestigeEnabled = false
                    pcall(function() if Options and Options.PrestigeToggle then Options.PrestigeToggle:SetValue(false) end end)
                end
            end
            return false
        end

        local talent = getRandomTalent()
        if not talent then
            resetTalentPool()
            talent = getRandomTalent()
            if not talent then return false end
        end

        local Event = game:GetService("ReplicatedStorage").Assets.Remotes.GET
        pcall(function() Event:InvokeServer("S_Equipment", "Talents") end)
        task.wait(0.3)
        pcall(function()
            Event:InvokeServer("S_Equipment", "Prestige", {
                Boosts = getgenv().SelectedBoost,
                Talents = talent
            })
        end)
        lastGoldNotifyStep = -1
        lastGoldNotifyStatus = nil
        return true
    end

    task.spawn(function()
        while true do
                        if not getgenv().PrestigeEnabled then
                PrestigeRunning = false
                task.wait(1)                  continue
            end
            
                        if not PrestigeRunning then
                PrestigeRunning = true
                pcall(doPrestige)
                PrestigeRunning = false
            end
            
            task.wait(PrestigeCooldown)
        end
    end)
end
if IsLobbyLobby() then
    local AutoClaimGroup = Tabs.Session:AddLeftGroupbox("Auto Claims")
    
    getgenv().ClaimQuestEnabled = false
    getgenv().ClaimQuestRunning = false
    getgenv().ClaimAchievementEnabled = false
    getgenv().ClaimAchievementRunning = false
    getgenv().ClaimDelay = 0
    
    local statusLabel = AutoClaimGroup:AddLabel("Status: Checking...", true)
    
        local function getCurrencyValues()
        local player = game:GetService("Players").LocalPlayer
        local goldAmount = 0
        local gemsAmount = 0
        
        pcall(function()
            local topbar = player.PlayerGui.Interface.Topbar.Main.Currencies
            if topbar then
                local goldLabel = topbar.Gold and topbar.Gold:FindFirstChild("Amount")
                local gemsLabel = topbar.Gems and topbar.Gems:FindFirstChild("Amount")
                if goldLabel and goldLabel.Text then
                    local goldText = goldLabel.Text:gsub("[^%d]", "")
                    goldAmount = tonumber(goldText) or 0
                end
                if gemsLabel and gemsLabel.Text then
                    local gemsText = gemsLabel.Text:gsub("[^%d]", "")
                    gemsAmount = tonumber(gemsText) or 0
                end
            end
        end)
        return goldAmount, gemsAmount
    end
    
    local function isCurrenciesReady()
        local gold, gems = getCurrencyValues()
        return (gold > 0 or gems > 0)
    end
    
        task.spawn(function()
        while true do
            task.wait(1)
            pcall(function()
                local ready = isCurrenciesReady()
                if ready then
                    statusLabel:SetText("Status: Ready")
                else
                    statusLabel:SetText("Status: Not Ready (Waiting for Gold/Gems)")
                end
            end)
        end
    end)
    
    local QuestList = {
        {name="Novice Adventurer", category="Main"},{name="Seasoned Operative", category="Main"},{name="Master Of Missions", category="Main"},{name="Elite Taskmaster", category="Main"},{name="Legendary Quester", category="Main"},{name="Completionist", category="Main"},{name="Rookie Raider", category="Main"},{name="Raid Veteran", category="Main"},{name="Raid Commander", category="Main"},{name="Raid Warlord", category="Main"},{name="Raid Conqueror", category="Main"},{name="Precise Striker", category="Main"},{name="Critical Sniper", category="Main"},{name="Devastating Precision", category="Main"},{name="Critical Master", category="Main"},{name="Critical Legend", category="Main"},{name="Critical Demigod", category="Main"},{name="Novice Wrecker", category="Main"},{name="Demolition Expert", category="Main"},{name="Destruction Maestro", category="Main"},{name="Damage Dynamo", category="Main"},{name="Cataclysmic Force", category="Main"},{name="Devastation Virtuoso", category="Main"},{name="Titan Hunter", category="Main"},{name="Titan Slayer", category="Main"},{name="Titan Executioner", category="Main"},{name="Titan Butcher", category="Main"},{name="Titan Dominator", category="Main"},{name="Titan Conqueror", category="Main"},{name="Rookie Adventurer", category="Main"},{name="Seasoned Warrior", category="Main"},{name="Master Of Experience", category="Main"},{name="Legendary Ascendant", category="Main"},{name="Divine Prestige", category="Main"},{name="Ultimate Champion", category="Main"},{name="Prestige Aspirant", category="Main"},{name="Prestige Challenger", category="Main"},{name="Prestige Enthusiast", category="Main"},{name="Prestige Expert", category="Main"},
        {name="Casual Explorer", category="Side"},{name="Guardian Angel", category="Side"},{name="Penny Pincher", category="Side"},{name="Eye Of The Storm", category="Side"},{name="Shifting Apprentice", category="Side"},{name="Skill Novice", category="Side"},{name="Team Player", category="Side"},{name="Wealth Accumulator", category="Side"},{name="Rescuer Extraordinaire", category="Side"},{name="Teamwork Enthusiast", category="Side"},{name="Dedicated Adventurer", category="Side"},{name="Skill Practitioner", category="Side"},{name="Shifting Adept", category="Side"},{name="Leg Lacerator", category="Side"},{name="Treasure Hunter", category="Side"},{name="Seasoned Gamer", category="Side"},{name="Cooperative Expert", category="Side"},{name="Skill Expert", category="Side"},{name="Lifesaver Pro", category="Side"},{name="Shifting Expert", category="Side"},{name="Arm Annihilator", category="Side"},{name="Skill Master", category="Side"},{name="Titan Torturer", category="Side"},{name="Teamwork Specialist", category="Side"},{name="Fortune Hoarder", category="Side"},{name="Saving Supreme", category="Side"},{name="Endurance Champion", category="Side"},{name="Shifting Master", category="Side"},{name="Shifting Guru", category="Side"},{name="Titan Annihilator", category="Side"},{name="Teamwork Virtuoso", category="Side"},{name="Timeless Immortal", category="Side"},{name="Money Magician", category="Side"},{name="Skill Virtuoso", category="Side"},{name="Player's Champion", category="Side"},{name="Teamwork Maestro", category="Side"},{name="Skill Prodigy", category="Side"},{name="Legendary Superior", category="Side"},{name="Titan's Nightmare", category="Side"},{name="Ultimate Protector", category="Side"},{name="Ultimate Victor", category="Side"},{name="Shifting Virtuoso", category="Side"},
        {name="Daily 1", category="Daily"},{name="Daily 2", category="Daily"},{name="Daily 3", category="Daily"},
        {name="Weekly 1", category="Weekly"},{name="Weekly 2", category="Weekly"},{name="Weekly 3", category="Weekly"},{name="Weekly 4", category="Weekly"},
        {name="Towers", category="Spears"},{name="Escort", category="Spears"},{name="Ice Burst Stones", category="Spears"},{name="Retrieve Missing Supplies", category="Spears"},{name="Defend Missing Supplies", category="Spears"}
    }
    
        local function waitForCurrency()
        while not (Window and Window.Holder and Window.Holder.Visible) do
            task.wait(0.1)
        end
        
        local gold, gems = 0, 0
        repeat
            task.wait(0.1)
            gold, gems = getCurrencyValues()
        until gold > 0 or gems > 0
    end
    
    local function claimAllQuests()
        -- [CHICKEN] เดิม while วนไม่จบ = ยิงซ้ำ ~95 เควสตลอดเวลา → เหลือรอบเดียวแล้วปิดตัวเอง
        for i, quest in ipairs(QuestList) do
            if not getgenv().ClaimQuestEnabled then break end
            pcall(function() SafeInvoke(GET, "Functions", "Quest", quest.name, quest.category) end)
            task.wait(0.15 + math.random()*0.1 + getgenv().ClaimDelay)
        end
        getgenv().ClaimQuestEnabled = false
        pcall(function()
            if Options and Options.ClaimQuestToggle then Options.ClaimQuestToggle:SetValue(false) end
        end)
        getgenv().ClaimQuestRunning = false
    end
    
    local function claimAllAchievements()
                pcall(function()
            local GET = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("GET")
            GET:InvokeServer("S_Achievements", "Category", 5)
        end)
        task.wait(0.2)
        
        for id = 1, 71 do
            if not getgenv().ClaimAchievementEnabled then break end
            pcall(function() SafeInvoke(GET, "S_Achievements", "Claim", id) end)
            task.wait(0.1 + math.random()*0.03 + getgenv().ClaimDelay)
        end
        getgenv().ClaimAchievementEnabled = false
        getgenv().ClaimAchievementRunning = false
        pcall(function()
            if Options and Options.ClaimAchievementToggle then
                Options.ClaimAchievementToggle:SetValue(false)
            end
        end)
    end
    
    AutoClaimGroup:AddToggle("ClaimQuestToggle", {
        Text = "Claim Quest",
        Default = false,
        Callback = function(v)
            getgenv().ClaimQuestEnabled = v
            if v and not getgenv().ClaimQuestRunning then
                task.spawn(function()
                    task.wait(2)
                    waitForCurrency()
                    getgenv().ClaimQuestRunning = true
                    claimAllQuests()
                end)
            end
        end
    })
    
    AutoClaimGroup:AddToggle("ClaimAchievementToggle", {
        Text = "Claim Achievement",
        Default = false,
        Callback = function(v)
            getgenv().ClaimAchievementEnabled = v
            if v and not getgenv().ClaimAchievementRunning then
                task.spawn(function()
                    task.wait(2)
                    waitForCurrency()
                    getgenv().ClaimAchievementRunning = true
                    claimAllAchievements()
                end)
            end
        end
    })
    
    AutoClaimGroup:AddSlider("ClaimDelaySlider", {
        Text = "Claim Delay (sec)",
        Default = 0,
        Min = 0,
        Max = 60,
        Rounding = 1,
        Compact = false,
        Callback = function(v)
            getgenv().ClaimDelay = v
        end
    })
end
do
    local DETECTED_WEAPON = "Unknown"
    local detectionComplete = false
    
    task.spawn(function()
        while not detectionComplete do
            local success, weapon = pcall(function()
                local GET = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("GET")
                local data = GET:InvokeServer("Data", "Copy")
                local slot = data.Current_Slot or "A"
                return data.Slots[slot].Weapon or "Unknown"
            end)
            
            if success and weapon and weapon ~= "Unknown" then
                DETECTED_WEAPON = weapon
                
                local weaponLower = string.lower(tostring(weapon))
                
                if weaponLower:find("blade") or weaponLower:find("aottg") then
                    DETECTED_WEAPON = "Blade"
                elseif weaponLower:find("spear") or weaponLower:find("thunder") then
                    DETECTED_WEAPON = "Thunder Spear"
                end
                
                detectionComplete = true
            else
                task.wait(1)
            end
        end
    end)
    
    getgenv().GetDetectedWeapon = function()
        return DETECTED_WEAPON
    end
end

if IsIngameLobby() and Tabs.AutoFarm then
    local MiscGroup = Tabs.AutoFarm:AddLeftGroupbox("Misc")

        local StatsGui = nil
    local StatsEnabled = false
    local scaleFactor = 1

    local JESTER = {
        Background = Color3.fromHex("1c1c1c"),
        Accent = Color3.fromHex("db4467"),
        Font = Color3.fromHex("ffffff"),
        Outline = Color3.fromHex("373737")
    }

        getgenv().FarmTimerStarted = getgenv().FarmTimerStarted or false
    getgenv().FarmStartTime = getgenv().FarmStartTime or nil
    getgenv().FarmLastOnTime = getgenv().FarmLastOnTime or 0   
        local function IsActuallyVisible(gui)
        if not gui or not gui:IsA("GuiObject") then return false end
        if not gui.Visible then return false end
        local current = gui.Parent
        while current do
            if current:IsA("GuiObject") and not current.Visible then return false end
            if current:IsA("ScreenGui") and not current.Enabled then return false end
            current = current.Parent
        end
        return true
    end

        local function isObjectivesVisible()
        local player = game:GetService("Players").LocalPlayer
        local playerGui = player:FindFirstChild("PlayerGui")
        if not playerGui then return false end
        for _, v in ipairs(playerGui:GetDescendants()) do
            if v.Name == "Objectives" and IsActuallyVisible(v) then
                return true
            end
        end
        return false
    end

        local function waitForStableOn()
        local onCount = 0
        local startTime = tick()
        local maxDuration = 2
        local requiredCount = 10
        while tick() - startTime < maxDuration do
            if isObjectivesVisible() then
                onCount = onCount + 1
            else
                onCount = 0
            end
            if onCount >= requiredCount then
                return true
            end
            task.wait(0.05)
        end
        return false
    end

        local function startFarmTimerIfNeeded()
        if getgenv().FarmTimerStarted then return end
        if waitForStableOn() then
            getgenv().FarmTimerStarted = true
            getgenv().FarmStartTime = tick()
            getgenv().FarmLastOnTime = tick()
        end
    end

        local function getFarmElapsedTime()
        if getgenv().FarmTimerStarted and getgenv().FarmStartTime then
            return tick() - getgenv().FarmStartTime
        else
            return 0
        end
    end

        task.spawn(function()
        while true do
                        startFarmTimerIfNeeded()

                        if getgenv().FarmTimerStarted then
                if isObjectivesVisible() then
                    getgenv().FarmLastOnTime = tick()
                end
            end

            task.wait(0.5)
        end
    end)

        MiscGroup:AddSlider("UIScaleSlider", {
        Text = "UI Scale (%)",
        Default = 100,
        Min = 50,
        Max = 200,
        Rounding = 0,
        Suffix = "%",
        Callback = function(v)
            scaleFactor = v / 100
            if StatsEnabled and StatsGui then
                local scaleObj = StatsGui:FindFirstChild("UIScale")
                if scaleObj then
                    scaleObj.Scale = scaleFactor
                end
            end
        end
    })

    local function CreatePlayerStatsHUD()
        if StatsGui then
            StatsGui:Destroy()
            StatsGui = nil
        end

        local Players = game:GetService("Players")
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local LocalPlayer = Players.LocalPlayer
        local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

        local Gui = Instance.new("ScreenGui")
        Gui.Name = "TownShipPlayerStats"
        Gui.IgnoreGuiInset = true
        Gui.ResetOnSpawn = false
        Gui.Parent = PlayerGui
        StatsGui = Gui

        local uiScale = Instance.new("UIScale")
        uiScale.Scale = scaleFactor
        uiScale.Parent = Gui

        local Frame = Instance.new("Frame")
        Frame.Size = UDim2.new(0, 520, 0, 116)
        Frame.Position = UDim2.new(0.5, -260, 0, 12)
        Frame.BackgroundColor3 = JESTER.Background
        Frame.BackgroundTransparency = 0.05
        Frame.BorderSizePixel = 0
        Frame.Parent = Gui

        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 10)
        Corner.Parent = Frame

        local Gradient = Instance.new("UIGradient")
        Gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, JESTER.Background),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 22, 22))
        })
        Gradient.Rotation = 90
        Gradient.Parent = Frame

        local Stroke = Instance.new("UIStroke")
        Stroke.Color = JESTER.Accent
        Stroke.Thickness = 1.2
        Stroke.Transparency = 0.55
        Stroke.Parent = Frame

        local TimerTitle = Instance.new("TextLabel")
        TimerTitle.Size = UDim2.new(0, 170, 0, 20)
        TimerTitle.Position = UDim2.new(0, 14, 0, 10)
        TimerTitle.BackgroundTransparency = 1
        TimerTitle.Text = "FARM TIMER"
        TimerTitle.Font = Enum.Font.GothamSemibold
        TimerTitle.TextSize = 12
        TimerTitle.TextColor3 = JESTER.Font
        TimerTitle.TextXAlignment = Enum.TextXAlignment.Left
        TimerTitle.Parent = Frame

        local TimerValue = Instance.new("TextLabel")
        TimerValue.Size = UDim2.new(0, 200, 0, 42)
        TimerValue.Position = UDim2.new(0, 14, 0, 32)
        TimerValue.BackgroundTransparency = 1
        TimerValue.Text = "00:00:00"
        TimerValue.Font = Enum.Font.GothamBold
        TimerValue.TextSize = 34
        TimerValue.TextColor3 = JESTER.Font
        TimerValue.TextXAlignment = Enum.TextXAlignment.Left
        TimerValue.Parent = Frame

        local StatusTitle = Instance.new("TextLabel")
        StatusTitle.Size = UDim2.new(0, 170, 0, 16)
        StatusTitle.Position = UDim2.new(0, 14, 0, 80)
        StatusTitle.BackgroundTransparency = 1
        StatusTitle.Text = "STATUS:"
        StatusTitle.Font = Enum.Font.GothamMedium
        StatusTitle.TextSize = 10
        StatusTitle.TextColor3 = JESTER.Font
        StatusTitle.TextXAlignment = Enum.TextXAlignment.Left
        StatusTitle.Parent = Frame

        local StatusValue = Instance.new("TextLabel")
        StatusValue.Size = UDim2.new(0, 150, 0, 16)
        StatusValue.Position = UDim2.new(0, 65, 0, 80)
        StatusValue.BackgroundTransparency = 1
        StatusValue.Text = "OFF"
        StatusValue.Font = Enum.Font.GothamBold
        StatusValue.TextSize = 11
        StatusValue.TextColor3 = Color3.fromRGB(255, 100, 100)
        StatusValue.TextXAlignment = Enum.TextXAlignment.Left
        StatusValue.Parent = Frame

        local Divider = Instance.new("Frame")
        Divider.Size = UDim2.new(0, 1, 0, 90)
        Divider.Position = UDim2.new(0.5, -1, 0, 13)
        Divider.BackgroundColor3 = JESTER.Accent
        Divider.BackgroundTransparency = 0.65
        Divider.BorderSizePixel = 0
        Divider.Parent = Frame

        local StatsContainer = Instance.new("Frame")
        StatsContainer.Size = UDim2.new(0, 230, 0, 72)
        StatsContainer.Position = UDim2.new(1, -245, 0, 12)
        StatsContainer.BackgroundTransparency = 1
        StatsContainer.Parent = Frame

        local StatsTitle = Instance.new("TextLabel")
        StatsTitle.Size = UDim2.new(1, 0, 0, 20)
        StatsTitle.Position = UDim2.new(0, 0, 0, 0)
        StatsTitle.BackgroundTransparency = 1
        StatsTitle.Text = "PLAYER STATS"
        StatsTitle.Font = Enum.Font.GothamSemibold
        StatsTitle.TextSize = 12
        StatsTitle.TextColor3 = JESTER.Font
        StatsTitle.TextXAlignment = Enum.TextXAlignment.Right
        StatsTitle.Parent = StatsContainer

        local function MakeStatRow(name, xPos, yPos)
            local Holder = Instance.new("Frame")
            Holder.Size = UDim2.new(0, 105, 0, 18)
            Holder.Position = UDim2.new(0, xPos, 0, yPos)
            Holder.BackgroundTransparency = 1
            Holder.Parent = StatsContainer

            local Label = Instance.new("TextLabel")
            Label.Size = UDim2.new(0, 45, 1, 0)
            Label.Position = UDim2.new(0, 0, 0, 0)
            Label.BackgroundTransparency = 1
            Label.Text = name
            Label.Font = Enum.Font.GothamMedium
            Label.TextSize = 11
            Label.TextColor3 = JESTER.Font
            Label.TextXAlignment = Enum.TextXAlignment.Left
            Label.Parent = Holder

            local Value = Instance.new("TextLabel")
            Value.Size = UDim2.new(0, 60, 1, 0)
            Value.Position = UDim2.new(0, 45, 0, 0)
            Value.BackgroundTransparency = 1
            Value.Text = "0"
            Value.Font = Enum.Font.GothamBold
            Value.TextSize = 13
            Value.TextColor3 = JESTER.Accent
            Value.TextXAlignment = Enum.TextXAlignment.Left
            Value.Parent = Holder

            return Value
        end

        local LevelVal = MakeStatRow("Level", 0, 28)
        local GemsVal  = MakeStatRow("Gems", 120, 28)
        local GoldVal  = MakeStatRow("Gold", 0, 52)

        local function FormatTime(sec)
            return string.format("%02d:%02d:%02d",
                math.floor(sec / 3600),
                math.floor((sec % 3600) / 60),
                math.floor(sec % 60))
        end

        task.spawn(function()
            while StatsEnabled and Gui.Parent do
                task.wait(0.3)
                
                local objectivesVisible = isObjectivesVisible()
                local elapsed = getFarmElapsedTime()
                TimerValue.Text = FormatTime(elapsed)
                
                if objectivesVisible then
                    StatusValue.Text = "ON"
                    StatusValue.TextColor3 = Color3.fromRGB(0, 255, 0)
                else
                    StatusValue.Text = "OFF"
                    StatusValue.TextColor3 = Color3.fromRGB(255, 100, 100)
                end
            end
        end)

        local function FormatNumber(num)
            if num >= 1e6 then
                return string.format("%.2fM", num / 1e6)
            elseif num >= 1e3 then
                return string.format("%.1fK", num / 1e3)
            else
                return tostring(num)
            end
        end

        local function UpdateStats(data)
            pcall(function()
                if data and data.Slots then
                    local slot = data.Current_Slot or "A"
                    local slotData = data.Slots[slot]

                    if slotData then
                        if slotData.Progression and slotData.Progression.Level then
                            LevelVal.Text = tostring(slotData.Progression.Level)
                        end

                        if slotData.Currency then
                            if slotData.Currency.Gold then
                                GoldVal.Text = FormatNumber(slotData.Currency.Gold)
                            end
                            if slotData.Currency.Gems then
                                GemsVal.Text = FormatNumber(slotData.Currency.Gems)
                            end
                        end
                    end
                end
            end)
        end

        local function FetchAndUpdate()
            task.spawn(function()
                pcall(function()
                    local remoteGET = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("GET")
                    local data = remoteGET:InvokeServer("Data", "Copy", LocalPlayer.UserId)
                    if data and type(data) == "table" then
                        UpdateStats(data)
                    end
                end)
            end)
        end

        task.spawn(function()
            while StatsEnabled and Gui.Parent do
                task.wait(5)
                FetchAndUpdate()
            end
        end)

        FetchAndUpdate()
    end

    MiscGroup:AddToggle("PlayerStatsToggle", {
        Text = "Player Stats",
        Default = false,
        Callback = function(v)
            StatsEnabled = v
            if v then
                CreatePlayerStatsHUD()
            else
                if StatsGui then
                    StatsGui:Destroy()
                    StatsGui = nil
                end
            end
        end
    })

        MiscGroup:AddDropdown("RenderModeDropdown", {
        Text = "FPS Performance",
        Values = {"Low Graphic", "Delete Map", "Disable 3D Render", "Disable Text DMG"},
        Default = {},
        Multi = true,
        Callback = function(v)
                        if v["Low Graphic"] then
                pcall(function()
                    game:GetService("Lighting").Brightness = 0
                    game:GetService("Lighting").GlobalShadows = false
                    game:GetService("Lighting").FogEnd = 0
                    settings().Rendering.QualityLevel = 1
                    game:GetService("Workspace").TintColor = Color3.new(0, 0, 0)
                    if sethiddenproperty then
                        sethiddenproperty(game:GetService("Workspace"), "Terrain", nil)
                    end
                end)
            else
                pcall(function()
                    game:GetService("Lighting").Brightness = 1
                    game:GetService("Lighting").GlobalShadows = true
                    game:GetService("Lighting").FogEnd = 100000
                    settings().Rendering.QualityLevel = 21
                    game:GetService("Workspace").TintColor = Color3.new(1, 1, 1)
                end)
            end

                        if v["Delete Map"] then
                local climbable = workspace:FindFirstChild("Climbable")
                local unclimbable = workspace:FindFirstChild("Unclimbable")
                if climbable or unclimbable then
                    if climbable then
                        for _, child in ipairs(climbable:GetChildren()) do
                            pcall(function() child:Destroy() end)
                        end
                    end
                    if unclimbable then
                        local preserve = {Reloads = true, Objective = true, Cutscene = true}
                        for _, child in ipairs(unclimbable:GetChildren()) do
                            if not preserve[child.Name] then
                                pcall(function() child:Destroy() end)
                            end
                        end
                    end
                end
            end

                        if v["Disable 3D Render"] then
                pcall(function()
                    game:GetService("RunService"):Set3dRenderingEnabled(false)
                    settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
                    for _, part in ipairs(workspace:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.Material = Enum.Material.Plastic
                            part.Reflectance = 0
                        end
                    end
                end)
            else
                pcall(function()
                    game:GetService("RunService"):Set3dRenderingEnabled(true)
                    settings().Rendering.QualityLevel = Enum.QualityLevel.Level21
                end)
            end

                        if v["Disable Text DMG"] then
                for i = 1, 5 do
                    pcall(function()
                        local args = {
                            "Functions",
                            "Settings",
                            "Damage_Indicator",
                            "Off"
                        }
                        game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("GET"):InvokeServer(unpack(args))
                    end)
                    task.wait(0.1)
                end
            else
                for i = 1, 5 do
                    pcall(function()
                        local args = {
                            "Functions",
                            "Settings",
                            "Damage_Indicator",
                            "On"
                        }
                        game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("GET"):InvokeServer(unpack(args))
                    end)
                    task.wait(0.1)
                end
            end
        end
    })

        MiscGroup:AddSlider("FPSLimitSlider", {
        Text = "Set FPS",
        Default = 60,
        Min = 5,
        Max = 120,
        Rounding = 0,
        Suffix = " FPS",
        Callback = function(v)
            pcall(function()
                if setfpscap then
                    setfpscap(v)
                else
                    local fpsCap = syn and syn.set_fps_cap or (setfpscap and setfpscap)
                    if fpsCap then
                        fpsCap(v)
                    end
                end
            end)
        end
    })
end

if Tabs.AutoFarm then
    local SafetyGroup = Tabs.AutoFarm:AddRightGroupbox("Safety Settings")
    SafetyGroup:AddLabel(" -- 60s is safe! --")
    SafetyGroup:AddSlider("SafetyTimeSlider", {
        Text="--- End Missions ---", Default=60, Min=0, Max=60, Rounding=0,
        Callback=function(val)
            getgenv().SafetyTime = math.floor(val)
        end,
        Drag = true
    })
    
    getgenv().StopAtTitansLeft = getgenv().StopAtTitansLeft or 10
    
    SafetyGroup:AddSlider("StopAtTitansLeftSlider", {
        Text="Stop attacking when .. titans Left",
        Default = getgenv().StopAtTitansLeft,
        Min = 10,
        Max = 25,
        Rounding = 0,
        Callback = function(val)
            getgenv().StopAtTitansLeft = math.floor(val)
        end
    })
end
local PendingFarmStart = false
local syncingWeapon = false  
local function isObjectivesVisibleForFarm()
    local player = game:GetService("Players").LocalPlayer
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return false end
    
    local function IsActuallyVisible(gui)
        if not gui or not gui:IsA("GuiObject") then return false end
        if not gui.Visible then return false end
        local current = gui.Parent
        while current do
            if current:IsA("GuiObject") and not current.Visible then return false end
            if current:IsA("ScreenGui") and not current.Enabled then return false end
            current = current.Parent
        end
        return true
    end
    
    for _, v in ipairs(playerGui:GetDescendants()) do
        if v.Name == "Objectives" then
            if IsActuallyVisible(v) then
                return true
            end
        end
    end
    return false
end

local farmObjectivesReady = false
local lastObjectivesCheck = 0

local function updateFarmObjectivesStatus()
    if tick() - lastObjectivesCheck >= 0.5 then
        lastObjectivesCheck = tick()
        farmObjectivesReady = isObjectivesVisibleForFarm()
    end
    return farmObjectivesReady
end

---------- :farm tab: ----------
if Tabs.AutoFarm then
    local AutoFarmTabbox = Tabs.AutoFarm:AddLeftTabbox("Auto Farm")
    local G = getgenv()

    G.Farm = false
    G.AutoFarmBlade = false
    G.AutoReloadBlade = false
    G.AutoThunderSpear = false
    G.StartRejoin = false
    G.FarmMode = nil
    G.HoverSpeed = 120
    G.HoverHeight = 120
    G.SafetyTime = G.SafetyTime or 60
    G.LeaveMinimum = 1
    G.AttackInterval = 0.15
    G.KillHits = 1  

    G.ThunderSpearFarmMode = "Tween"
    G.ThunderSpearHoverSpeed = 120
    G.ThunderSpearHoverHeight = 120
    G.ThunderSpearFirePower = 8
    G.ThunderSpearExplodeRadius = 0.13

    local FarmConn = nil
    local SpearFarmConn = nil

    task.spawn(function()
        while true do
            task.wait(5)
            pcall(function()
                if G.GetDetectedWeapon then
                    local oldWeapon = G.GetDetectedWeapon()
                    G.GetDetectedWeapon()
                    local newWeapon = G.GetDetectedWeapon()
                    
                    if oldWeapon ~= newWeapon and not syncingWeapon then
                        syncingWeapon = true
                        
                        if newWeapon == "Blade" then
                            if G.AutoThunderSpear then
                                if Options and Options.AutoThunderSpearToggle then
                                    pcall(function() Options.AutoThunderSpearToggle:SetValue(false) end)
                                end
                                if Options and Options.AutoFarmBlade then
                                    pcall(function() Options.AutoFarmBlade:SetValue(true) end)
                                end
                            end
                        elseif newWeapon == "Thunder Spear" then
                            if G.AutoFarmBlade then
                                if Options and Options.AutoFarmBlade then
                                    pcall(function() Options.AutoFarmBlade:SetValue(false) end)
                                end
                                if Options and Options.AutoThunderSpearToggle then
                                    pcall(function() Options.AutoThunderSpearToggle:SetValue(true) end)
                                end
                            end
                        end
                        
                        syncingWeapon = false
                    end
                end
            end)
        end
    end)
    
    local function getCurrentWeapon()
        return G.GetDetectedWeapon and G.GetDetectedWeapon() or "Unknown"
    end
    
    local function isBlade()
        return getCurrentWeapon() == "Blade"
    end
    
    local function isThunderSpear()
        return getCurrentWeapon() == "Thunder Spear"
    end

    local function resolveConflictingToggles()
        if syncingWeapon then return end
        if G.AutoFarmBlade and G.AutoThunderSpear then
            if isBlade() then
                G.AutoThunderSpear = false
                pcall(function()
                    if Options and Options.AutoThunderSpearToggle then
                        Options.AutoThunderSpearToggle:SetValue(false)
                    end
                end)
            elseif isThunderSpear() then
                G.AutoFarmBlade = false
                G.Farm = false
                PendingFarmStart = false
                pcall(function()
                    if Options and Options.AutoFarmBlade then
                        Options.AutoFarmBlade:SetValue(false)
                    end
                end)
            else
                G.AutoFarmBlade = false
                G.AutoThunderSpear = false
                G.Farm = false
                PendingFarmStart = false
                pcall(function()
                    if Options and Options.AutoFarmBlade then
                        Options.AutoFarmBlade:SetValue(false)
                    end
                    if Options and Options.AutoThunderSpearToggle then
                        Options.AutoThunderSpearToggle:SetValue(false)
                    end
                end)
            end
        end
    end

    local function waitForUI()
        local waited = 0
        while not (Window and Window.Holder and Window.Holder.Visible) and waited < 1 do
            task.wait(0.05)
            waited = waited + 0.05
        end
    end

    local BladeTab = AutoFarmTabbox:AddTab("Blade")

    BladeTab:AddDropdown("FarmModeDropdown", {
        Values = {"Tween","Teleport"}, 
        Default = "",
        Multi = false, 
        Text = "Farm Select",
        Callback = function(val)
            if syncingWeapon then return end
            G.FarmMode = val
        end
    })

    BladeTab:AddSlider("HoverSpeedSlider", {
        Text="Hover Speed", Default=G.HoverSpeed, Min=50, Max=1000, Rounding=0,
        Callback=function(val) if not syncingWeapon then G.HoverSpeed = val end end
    })
    
    BladeTab:AddSlider("HoverHeightSlider", {
        Text="Hover Height", Default=G.HoverHeight, Min=0, Max=400, Rounding=0,
        Callback=function(val) if not syncingWeapon then G.HoverHeight = val end end
    })

    BladeTab:AddSlider("KillHitsSlider", {
        Text="Kill Hits", Default=1, Min=1, Max=9, Rounding=0,
        Callback=function(val)
            if not syncingWeapon then G.KillHits = val end
        end
    })

    BladeTab:AddToggle("AutoFarmBlade", {
        Text="Auto Farm Blade", Default=false,
        Callback=function(v)
            if syncingWeapon then return end
            if v then
                -- ⚡ [SPEED] เดิม task.wait(0.5) ตรงนี้ — ครึ่งวินาทีที่ไททันใช้วิ่งมาถึงตัวเราพอดี
                if G.AutoThunderSpear then
                    if isThunderSpear() then
                        pcall(function()
                            if Options and Options.AutoThunderSpearToggle then
                                Options.AutoThunderSpearToggle:SetValue(false)
                            end
                        end)
                        pcall(function()
                            if Options and Options.AutoFarmBlade then
                                Options.AutoFarmBlade:SetValue(false)
                            end
                        end)
                        Library:Notify("⚠️ Cannot enable Blade because Thunder Spear is active!", 3)
                        return
                    else
                        G.AutoThunderSpear = false
                        pcall(function()
                            if Options and Options.AutoThunderSpearToggle then
                                Options.AutoThunderSpearToggle:SetValue(false)
                            end
                        end)
                    end
                end
                
                if not G.FarmMode or (G.FarmMode ~= "Tween" and G.FarmMode ~= "Teleport") then
                    pcall(function()
                        if Options and Options.AutoFarmBlade then
                            Options.AutoFarmBlade:SetValue(false)
                        end
                    end)
                    Library:Notify("⚠️ Please select Farm Mode (Tween/Teleport) first!", 3)
                    return
                end
                
                G.AutoFarmBlade = true
                G.Farm = true
                G.FarmStartTime = tick()
                PendingFarmStart = false
                CurrentEntry = nil
                LastAttackTime = tick()
                
                if not FarmConn then
                    CreateFarmLoop()
                end
            else
                G.AutoFarmBlade = false
                G.Farm = false
                PendingFarmStart = false
                CurrentEntry = nil
                if FarmConn then
                    FarmConn:Disconnect()
                    FarmConn = nil
                end
                CleanupSmoothMovement()
                if CharRef then
                    for _, part in ipairs(CharParts) do
                        if part and part.Parent then
                            pcall(function()
                                part.CanCollide = true
                            end)
                        end
                    end
                    CharParts = {}
                    CharRef = nil
                end
                NapeCache = setmetatable({}, {__mode = "k"})
                LastTitanPosition = nil
                local char = Player.Character
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        pcall(function()
                            hrp.AssemblyLinearVelocity = Vector3.zero
                            hrp.AssemblyAngularVelocity = Vector3.zero
                        end)
                    end
                end
                pcall(function()
                    if Options and Options.AutoFarmBlade then
                        Options.AutoFarmBlade:SetValue(false)
                    end
                end)
            end
        end
    })

    BladeTab:AddToggle("AutoReloadBlade", {
        Text="Auto Reload Blade", Default=false,
        Callback=function(v) 
            if syncingWeapon then return end
            if v then task.wait(1) end
            G.AutoReloadBlade = v
            if not v then
                getgenv().IsReloading = false
                getgenv().IsRefilling = false
                reloadInProgress = false
                refillInProgress = false
                refillStage = 0
            end
        end
    })
    
    BladeTab:AddToggle("StartRejoin", {
        Text="Auto Retry", Default=false,
        Callback=function(v)
            if syncingWeapon then return end
            -- ⚡ [SPEED] เดิม task.wait(1) ตรงนี้ — ไม่มีเหตุผลต้องรอ แค่เซ็ตตัวแปร
            G.StartRejoin = v
        end
    })

    local SpearTab = AutoFarmTabbox:AddTab("Thunder Spear")
    
    SpearTab:AddToggle("AutoThunderSpearToggle", {
        Text = "Auto Thunder Spear",
        Default = false,
        Callback = function(v)
            if syncingWeapon then return end
            if v then
                task.wait(0.5)
                
                if G.AutoFarmBlade then
                    if isBlade() then
                        pcall(function()
                            if Options and Options.AutoFarmBlade then
                                Options.AutoFarmBlade:SetValue(false)
                            end
                        end)
                        pcall(function()
                            if Options and Options.AutoThunderSpearToggle then
                                Options.AutoThunderSpearToggle:SetValue(false)
                            end
                        end)
                        Library:Notify("⚠️ Cannot enable Thunder Spear because Blade is active!", 3)
                        return
                    else
                        G.AutoFarmBlade = false
                        G.Farm = false
                        PendingFarmStart = false
                        pcall(function()
                            if Options and Options.AutoFarmBlade then
                                Options.AutoFarmBlade:SetValue(false)
                            end
                        end)
                    end
                end
                
                G.AutoThunderSpear = true
                G.SpearFarm = true
                G.FarmStartTime = tick()
                SpearCurrentEntry = nil
                LastSpearAttackTime = tick()
                
                if not SpearFarmConn then
                    CreateSpearFarmLoop()
                end
            else
                G.AutoThunderSpear = false
                G.SpearFarm = false
                SpearCurrentEntry = nil
                if SpearFarmConn then
                    SpearFarmConn:Disconnect()
                    SpearFarmConn = nil
                end
                CleanupSmoothMovement()
                if CharRef then
                    for _, part in ipairs(CharParts) do
                        if part and part.Parent then
                            pcall(function()
                                part.CanCollide = true
                            end)
                        end
                    end
                    CharParts = {}
                    CharRef = nil
                end
                NapeCache = setmetatable({}, {__mode = "k"})
                if type(ActiveTitans) == "table" then
                    table.clear(ActiveTitans)
                else
                    ActiveTitans = {}
                end
                LastTitanPosition = nil
                local char = Player.Character
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        pcall(function()
                            hrp.AssemblyLinearVelocity = Vector3.zero
                            hrp.AssemblyAngularVelocity = Vector3.zero
                        end)
                    end
                end
                pcall(function()
                    if Options and Options.AutoThunderSpearToggle then
                        Options.AutoThunderSpearToggle:SetValue(false)
                    end
                end)
            end
        end
    })
    
    SpearTab:AddDivider()
    
    SpearTab:AddDropdown("ThunderSpear_FarmMode", {
        Values = {"Tween","Teleport"},
        Default = "Tween",
        Multi = false,
        Text = "Farm Mode",
        Callback = function(v) if not syncingWeapon then G.ThunderSpearFarmMode = v end end
    })
    
    SpearTab:AddSlider("ThunderSpear_HoverSpeed", {
        Text="Hover Speed", Default=120, Min=50, Max=1000, Rounding=0,
        Callback=function(v) if not syncingWeapon then G.ThunderSpearHoverSpeed = v end end
    })
    
    SpearTab:AddSlider("ThunderSpear_HoverHeight", {
        Text="Hover Height", Default=120, Min=0, Max=400, Rounding=0,
        Callback=function(v) if not syncingWeapon then G.ThunderSpearHoverHeight = v end end
    })

    task.spawn(function()
        while true do
            task.wait(0.1)
            pcall(function()
                local G = getgenv()
                if G.AutoFarmBlade and not G.Farm then
                    G.Farm = true
                    G.FarmStartTime = tick()
                    CurrentEntry = nil
                    LastAttackTime = tick()
                    if not FarmConn then
                        CreateFarmLoop()
                    end
                end
                if G.AutoThunderSpear and not G.SpearFarm then
                    G.SpearFarm = true
                    G.FarmStartTime = tick()
                    SpearCurrentEntry = nil
                    LastSpearAttackTime = tick()
                    if not SpearFarmConn then
                        CreateSpearFarmLoop()
                    end
                end
            end)
        end
    end)

    local TeleportGroup = Tabs.AutoFarm:AddRightGroupbox("Teleport Now")
    local tpLabel = TeleportGroup:AddLabel("")
    local function AddConfirmTP(name, id, time)
        local c = false
        TeleportGroup:AddButton(name, function()
            if c then
                pcall(function() TeleportService:Teleport(id, Player) end)
            else
                c = true
                tpLabel:SetText("Are you sure?")
                task.delay(time or 3, function() c = false; tpLabel:SetText("") end)
            end
        end)
    end
    AddConfirmTP("Teleport to Main Menu", MAIN_MENU_ID, 1.5)
    AddConfirmTP("Teleport to Lobby", LOBBY_ID)
    
    TeleportGroup:AddDivider()

    local combinedDelay = 0
    local selectedActions = {}
    local combinedEnabled = false
    local combinedTimerRunning = false
    local combinedStartTime = 0
    local actionPending = false
    local teleportAttempts = 0
    local maxAttempts = 5

    TeleportGroup:AddSlider("CombinedActionDelaySlider", {
        Text = "Set Delay (seconds)",
        Default = 0,
        Min = 0,
        Max = 1200,
        Rounding = 0,
        Suffix = " sec",
        Callback = function(v)
            combinedDelay = v
        end
    })

    TeleportGroup:AddDropdown("CombinedActionsDropdown", {
        Values = {"Teleport to Main Menu", "Teleport to Lobby", "Kill Character", "AUTO Leave Game"},
        Default = {},
        Multi = true,
        Text = "Select [ Multi ]",
        Callback = function(v)
            selectedActions = v
        end
    })

    local function performTeleportToMainMenu()
        teleportAttempts = teleportAttempts + 1
        pcall(function() TeleportService:Teleport(MAIN_MENU_ID, Player) end)
        if teleportAttempts >= maxAttempts then
            pcall(function() game:Shutdown() end)
        end
    end

    local function performTeleportToLobby()
        teleportAttempts = teleportAttempts + 1
        pcall(function() TeleportService:Teleport(LOBBY_ID, Player) end)
        if teleportAttempts >= maxAttempts then
            pcall(function() game:Shutdown() end)
        end
    end

    local function performKillCharacter()
        local player = game.Players.LocalPlayer
        if player and player.Character and player.Character:FindFirstChild("Humanoid") then
            pcall(function() player.Character.Humanoid.Health = 0 end)
        end
    end

    local function getSelectedActionsList()
        local list = {}
        if type(selectedActions) == "table" then
            for actionName, isSelected in pairs(selectedActions) do
                if isSelected then
                    table.insert(list, actionName)
                end
            end
        end
        return list
    end

    local function executeCombinedActions()
        if not actionPending then return end
        actionPending = false
        combinedTimerRunning = false
        
        local actionsToRun = getSelectedActionsList()
        for _, action in ipairs(actionsToRun) do
            if action == "Teleport to Main Menu" then
                performTeleportToMainMenu()
            elseif action == "Teleport to Lobby" then
                performTeleportToLobby()
            elseif action == "Kill Character" then
                performKillCharacter()
            elseif action == "AUTO Leave Game" then
                pcall(function() game:Shutdown() end)
            end
            task.wait(0.2)
        end
        teleportAttempts = 0
    end

    local function startCombinedTimer()
        if combinedTimerRunning then return end
        
        local actionsToRun = getSelectedActionsList()
        if #actionsToRun == 0 then
            if combinedEnabled then
                pcall(function()
                    if Options and Options.CombinedActionToggle then
                        Options.CombinedActionToggle:SetValue(false)
                    end
                end)
                combinedEnabled = false
            end
            return
        end
        
        if combinedDelay <= 0 then
            actionPending = true
            executeCombinedActions()
            return
        end
        
        combinedTimerRunning = true
        actionPending = true
        combinedStartTime = tick()
        
        task.spawn(function()
            while combinedEnabled and actionPending do
                local elapsed = tick() - combinedStartTime
                if elapsed >= combinedDelay then
                    executeCombinedActions()
                    break
                end
                task.wait(0.1)
            end
        end)
    end

    local function stopCombinedTimer()
        actionPending = false
        combinedTimerRunning = false
        teleportAttempts = 0
    end

    TeleportGroup:AddToggle("CombinedActionToggle", {
        Text = "Enable Failed Safe",
        Default = false,
        Callback = function(v)
            combinedEnabled = v
            if v then
                local actionsToRun = getSelectedActionsList()
                if #actionsToRun == 0 then
                    pcall(function()
                        if Options and Options.CombinedActionToggle then
                            Options.CombinedActionToggle:SetValue(false)
                        end
                    end)
                    return
                end
                startCombinedTimer()
            else
                stopCombinedTimer()
            end
        end
    })
end

-- ===== ส่วนของ Titans และ Farm Core (ปรับปรุงให้ยิงเร็วขึ้น) =====

local function SafeGetTitansFolder()
    local success, folder = pcall(function()
        return workspace:FindFirstChild("Titans")
    end)
    if success and folder then
        return folder
    end
    local success2, newFolder = pcall(function()
        local f = Instance.new("Folder")
        f.Name = "Titans"
        f.Parent = workspace
        return f
    end)
    if success2 then return newFolder end
    return nil
end

local TitansFolder = SafeGetTitansFolder()

local function IsInCutscene()
    local ok, result = pcall(function()
        local gui = Player:FindFirstChild("PlayerGui")
        if not gui then return false end
        local Interface = gui:FindFirstChild("Interface")
        if not Interface then return false end
        local skip = Interface:FindFirstChild("Skip")
        local skipWarning = Interface:FindFirstChild("Skip_Warning")
        return (skip and skip.Visible) or (skipWarning and skipWarning.Visible) or false
    end)
    return ok and result or false
end


-- ═══════════════════════════════════════════════════════════════
-- 🤖 VENOZ AUTO-PILOT — เปิดฟังก์ชันของสคริปนี้ให้ครบอัตโนมัติ
-- ═══════════════════════════════════════════════════════════════
--   MAIN MENU : กดเลือกสลอต + ปิด popup + redeem code
--   LOBBY     : เควส → achievement → spin → boost → อัพดาบ/หอก → สกิล
--               → จุติ → raid/waves/สร้างด่าน
--   MISSION   : skip cutscene → reload → retry → ฟาร์ม (ดาบ/หอก) → spear quest → failed safe
--   ปิดทั้งหมด: getgenv().VenozChicken.AutoPilot = false
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    local VZ = getgenv().VenozChicken
    if VZ.AutoPilot == false then return end

    -- ── ค่าเริ่มต้น ──
    local function dflt(k, v) if VZ[k] == nil then VZ[k] = v end end
    dflt("Slot", "A")            dflt("SelectDelay", 1)       dflt("AutoSelectSlot", true)
    dflt("AutoDialogClick", true) dflt("AutoNotNowClick", true)
    dflt("AutoRedeem", false)    dflt("CodeList", {})
    dflt("Mission", "Chapel")    dflt("Objective", "Skirmish") dflt("Difficulty", "Aberrant++")
    dflt("Modifiers", {"No Perks","No Skills","No Memories","Nightmare","Oddball",
                       "Injury Prone","Chronic Injuries","Fog","Glass Cannon",
                       "Time Trial","Boring","Simple"})
    dflt("MissionDelay", 0)
    dflt("FarmMode", "Teleport")    dflt("HoverHeight", 120)     dflt("HoverSpeed", 120)
    dflt("SafetyTime", 0)        dflt("StopAtTitans", 0)      dflt("FPS", 60)
    dflt("UpgradeDelay", 1.5)    dflt("ClaimDelay", 0.2)      dflt("UnlockDelay", 0.15)
    dflt("OffenseSide", "Right") dflt("DefenseSide", "Right") dflt("SupportSide", "None")
    dflt("PrestigeBoost", "Gold Boost") dflt("PrestigeCooldown", 0.3)
    dflt("ForceGold", false)     dflt("GoldReq", {0, 0, 0, 0, 0})
    dflt("AutoFarm", true)       dflt("AutoReload", true)     dflt("AutoRetry", true)
    dflt("SkipCutscene", true)   dflt("SkipForce", false)     dflt("LowGraphic", true)
    dflt("AutoMission", true)    dflt("AutoQuest", true)      dflt("AutoAchieve", true)
    dflt("AutoPrestige", true)   dflt("AutoUpgrade", true)    dflt("AutoSkills", true)
    dflt("AutoUpgradeSpear", false) dflt("SpearUpgradeDelay", 1.5)
    dflt("AutoThunderSpear", false) dflt("SpearFarmMode", "Tween")
    dflt("SpearHoverHeight", 120)   dflt("SpearHoverSpeed", 120)
    dflt("AutoSpearQuest", false)
    dflt("AutoRaid", false)      dflt("RaidBoss", nil)        dflt("RaidDifficulty", nil)
    dflt("RaidModifiers", {})    dflt("RaidDelay", 0)
    dflt("AutoWaves", false)     dflt("WavesDelay", 0)
    dflt("AutoBoost", true)      dflt("BoostTypes", {"XP", "Gold"})
    dflt("MinGemsToBuyBoosts", 4499)  dflt("BoostCheckInterval", 15)
    -- 🔧 config เก่า (ก่อน v3) ตั้ง AutoBoost=false ไว้ตอนที่ระบบ boost ยังพัง
    --    ค่านั้นไม่ใช่ความตั้งใจของผู้ใช้ → ถ้าเจอ config เก่า ให้เปิดให้อัตโนมัติ
    --    ถ้าอยากปิดจริงๆ ใส่ VenozChicken.ConfigVersion = 3 แล้วตั้ง AutoBoost = false
    if VZ.AutoBoost == false and (tonumber(VZ.ConfigVersion) or 0) < 3 then
        VZ.AutoBoost = true
        warn("[BOOST] 🔧 เจอ config เก่า (AutoBoost=false) → เปิดให้อัตโนมัติแล้ว")
    end
    dflt("AutoSpin", false)      dflt("SpinFamilies", {})     dflt("SpinDelay", 1)
    dflt("StopAtSpinLimit", true)
        dflt("FailedSafe", false)    dflt("FailedSafeDelay", 1200)
    dflt("FailedSafeActions", {"Teleport to Lobby"})
    dflt("SilentNotify", false)
    -- ⬛ จอขาว / ปิดแชท (ค่าเริ่มต้น = เปิดทั้งหมด ตั้ง false ถ้าอยากปิดระบบ)
    dflt("AntiLag", true)        dflt("Disable3D", true)      dflt("DisableChat", true)
    dflt("LoadTimeout", 30)      -- หน้า LOADING ค้างเกินกี่วิ → ซ่อนทิ้งเอง

    -- ═══ 🚪 MAIN MENU: เลือกสลอต + เข้า Lobby ด้วย remote ทันที ═══
    --     (วิธีเดิมของเรา — ไม่ต้องกดปุ่ม ไม่ต้องรอ UI)
    if IsMainmenuLobby() and VZ.AutoSelectSlot then
        task.spawn(function()
            local GETr
            pcall(function()
                GETr = game:GetService("ReplicatedStorage")
                    :WaitForChild("Assets", 15):WaitForChild("Remotes", 15):WaitForChild("GET", 15)
            end)
            if not GETr then warn("[AUTO] ⛔ ไม่พบ GET remote — เลือกสลอตไม่ได้") return end
            task.wait(2)
            local tries = 0
            while game.PlaceId == MAIN_MENU_ID and tries < 30 do
                tries = tries + 1
                pcall(function() GETr:InvokeServer("Functions", "Select", VZ.Slot) end)
                task.wait(1)
                pcall(function() GETr:InvokeServer("Functions", "Teleport", "Lobby") end)
                print(string.format("[AUTO] 🚪 Select %s + Teleport Lobby (ครั้งที่ %d)",
                    tostring(VZ.Slot), tries))
                task.wait(10)
            end
            if game.PlaceId ~= MAIN_MENU_ID then print("[AUTO] ✅ เข้า Lobby แล้ว") end
        end)
    end

    -- ⚡ [SPEED] เดิม task.wait(8) — เดาเวลาโหลดแบบมั่วๆ เสียฟรี 8 วินาที
    --    ใหม่: รอ "ธงโหลดครบ" ตัวจริง ปกติได้ภายใน ~0.1-0.5 วิ
    do
        local t0 = tick()
        while not getgenv().VenozScriptReady and (tick() - t0) < 15 do task.wait() end
        print(string.format("[AUTO] 🚦 สคริปโหลดครบใน %.2f วิ → เริ่มสั่งงานได้", tick() - t0))
    end

    -- ⚠️ LinoriaLib: Toggle อยู่ใน `Toggles` ส่วน Slider/Dropdown อยู่ใน `Options`
    --    (เดิมหาแต่ใน Options → เปิด toggle ไม่ติดเลยซักตัว)
    local function opt(n)
        local ok, o = pcall(function()
            if Toggles ~= nil and Toggles[n] ~= nil then return Toggles[n] end
            if Options ~= nil and Options[n] ~= nil then return Options[n] end
            return nil
        end)
        return ok and o or nil
    end
    -- 💾 [SPEED] จำว่าวันนี้เคลมเควส/achievement ไปแล้ว (เหมือนบอทเก่า)
    --    เดิม: เข้า lobby ทีไรเคลมใหม่ทุกครั้ง = เสียเวลา 1-2 นาทีต่อรอบ + remote เพียบ
    local DayFile = "VenozChicken_Day_" .. tostring(game:GetService("Players").LocalPlayer.UserId) .. ".json"
    local function dayCache()
        local today = os.date("%Y-%m-%d")
        if getgenv()._VZDay and getgenv()._VZDay.day == today then return getgenv()._VZDay end
        local loaded
        pcall(function()
            if isfile and readfile and isfile(DayFile) then
                local d = game:GetService("HttpService"):JSONDecode(readfile(DayFile))
                if type(d) == "table" and d.day == today then loaded = d end
            end
        end)
        getgenv()._VZDay = loaded or { day = today }
        return getgenv()._VZDay
    end
    local function daySave()
        pcall(function()
            if writefile and getgenv()._VZDay then
                writefile(DayFile, game:GetService("HttpService"):JSONEncode(getgenv()._VZDay))
            end
        end)
    end

    local function has(n) return opt(n) ~= nil end
    local function setv(n, v)
        -- ⚡ [SPEED] เดิมมี task.wait(0.2) ทุกครั้ง → เรียก 10 ครั้ง = เสียฟรี 2 วิ
        --    SetValue เป็นการเซ็ตตัวแปร + เรียก callback ตรงๆ ไม่ต้องรอ UI วาด
        local o = opt(n)
        if not o then return false end
        return (pcall(function() o:SetValue(v) end))
    end
    local function tset(list)   -- แปลง array → table สำหรับ multi-dropdown
        local t = {}
        if type(list) == "table" then for _, v in ipairs(list) do t[v] = true end end
        return t
    end
    local function waitFlag(flag, maxSec)
        local t0 = tick()
        while getgenv()[flag] and (tick() - t0) < (maxSec or 90) do task.wait(1) end
    end

    -- ═══ ตั้งค่าที่ใช้ร่วมทุกที่ ═══
    setv("FPSLimitSlider", VZ.FPS)
    if VZ.LowGraphic then setv("RenderModeDropdown", { ["Low Graphic"] = true }) end

    -- ══════════════════ 🎬 MAIN MENU ══════════════════
    if IsMainmenuLobby() then
        print("[AUTO] 🎬 Main Menu — เลือกสลอต " .. tostring(VZ.Slot))
        if VZ.AutoDialogClick then setv("AutoDialogClickerToggle", true) end
        if VZ.AutoNotNowClick then setv("AutoNotNowClickerToggle", true) end
        if VZ.AutoRedeem and has("AutoRedeemToggle") then
            if #VZ.CodeList > 0 then setv("CodeListDropdown", tset(VZ.CodeList)) end
            setv("AutoRedeemToggle", true)
        end
        -- (การเลือกสลอตยิง remote ไปแล้วด้านบน — ตรงนี้แค่ตั้งค่า UI ให้ตรงกัน)
        setv("SlotSelectionDropdown", VZ.Slot)
        setv("SelectDelaySlider", VZ.SelectDelay)

    -- ══════════════════ 🏠 LOBBY ══════════════════
    elseif IsLobbyLobby() then
        print("[AUTO] 🏠 Lobby — เริ่มลำดับงาน")
        getgenv().VenozChoresDone = false     -- brain ต้องรอจนกว่าจะเสร็จ
        getgenv()._VZChoreWait    = 0         -- 🐛 [FIX] เริ่มนับใหม่ทุกครั้งที่เข้า lobby
        setv("ClaimDelaySlider", VZ.ClaimDelay)

        local dc = dayCache()
        if VZ.AutoQuest and has("ClaimQuestToggle") and not dc.quest then
            print("[AUTO] 📜 เคลมเควส (ครั้งเดียวของวันนี้)...")
            setv("ClaimQuestToggle", true)
            task.wait(3); waitFlag("ClaimQuestRunning", 150)
            dc.quest = true; daySave()
        elseif dc.quest then
            print("[AUTO] 📜 เคลมเควสไปแล้ววันนี้ → ข้าม")
        end

        if VZ.AutoAchieve and has("ClaimAchievementToggle") and not dc.ach then
            print("[AUTO] 🏆 เคลม achievement (ครั้งเดียวของวันนี้)...")
            setv("ClaimAchievementToggle", true)
            task.wait(3); waitFlag("ClaimAchievementRunning", 150)
            dc.ach = true; daySave()
        elseif dc.ach then
            print("[AUTO] 🏆 เคลม achievement ไปแล้ววันนี้ → ข้าม")
        end

        if VZ.AutoRedeem and has("AutoRedeemToggle") then
            if #VZ.CodeList > 0 then setv("CodeListDropdown", tset(VZ.CodeList)) end
            setv("AutoRedeemToggle", true)
        end

        if VZ.AutoSpin and has("AutoSpinToggle") then
            print("[AUTO] 🎰 Family spin")
            if #VZ.SpinFamilies > 0 then setv("AutoSpinFamilies", tset(VZ.SpinFamilies)) end
            setv("AutoSpinDelaySlider", VZ.SpinDelay)
            if VZ.StopAtSpinLimit then setv("StopAtSpinLimitToggle", true) end
            setv("AutoSpinToggle", true)
        end

        -- [CHICKEN] boost ใช้ VENOZ BOOST SYSTEM (logic บอทเก่า) — ไม่ใช้ของ UI2

        if VZ.AutoUpgrade and has("AutoUpgradeBladeToggle") then
            print("[AUTO] ⚙️ อัพเกรดดาบ...")
            setv("BladeUpgradeDelaySlider", VZ.UpgradeDelay)
            setv("AutoUpgradeBladeToggle", true)
            task.wait(3); waitFlag("UpgradeRunning", 120)
        end

        if VZ.AutoUpgradeSpear and has("AutoUpgradeSpearToggle") then
            print("[AUTO] ⚙️ อัพเกรดหอก...")
            setv("SpearUpgradeDelaySlider", VZ.SpearUpgradeDelay)
            setv("AutoUpgradeSpearToggle", true)
            task.wait(3); waitFlag("SpearUpgradeRunning", 120)
        end

        local curLv = tonumber(game:GetService("Players").LocalPlayer:GetAttribute("Level")) or 0
        if VZ.AutoSkills and has("UnlockSkillsToggle") and dc.skillLv ~= curLv then
            dc.skillLv = curLv; daySave()
            print("[AUTO] 🌳 ปลดสกิล (ข้าม Support)")
            setv("UnlockDelaySlider", VZ.UnlockDelay)
            setv("OffenseSideDropdown", VZ.OffenseSide)
            setv("DefenseSideDropdown", VZ.DefenseSide)
            setv("SupportSideDropdown", VZ.SupportSide)
            setv("UnlockSkillsToggle", true)
            task.wait(20)
        elseif dc.skillLv == curLv then
            print("[AUTO] 🌳 ปลดสกิลแล้วที่ Lv นี้ → ข้าม")
        end

        if VZ.AutoPrestige and has("PrestigeToggle") then
            print("[AUTO] 👑 เปิดจุติอัตโนมัติ")
            setv("BoostDropdown", VZ.PrestigeBoost)
            setv("PrestigeCooldownSlider", VZ.PrestigeCooldown)
            local gk = {"GoldReq_0to1","GoldReq_1to2","GoldReq_2to3","GoldReq_3to4","GoldReq_4to5"}
            for i, name in ipairs(gk) do
                if VZ.GoldReq[i] then setv(name, VZ.GoldReq[i]) end
            end
            if VZ.ForceGold then setv("ForceGoldToggle", true) end
            setv("PrestigeToggle", true)
        end

        if VZ.AutoRaid and has("AutoRaidToggle") then
            print("[AUTO] 🐉 Auto Raid")
            if VZ.RaidBoss then setv("RaidBossDropdown", VZ.RaidBoss) end
            if VZ.RaidDifficulty then setv("RaidDifficultyDropdown", VZ.RaidDifficulty) end
            if #VZ.RaidModifiers > 0 then setv("RaidModifiersDropdown", tset(VZ.RaidModifiers)) end
            setv("RaidDelaySlider", VZ.RaidDelay)
            setv("AutoRaidToggle", true)

        elseif VZ.AutoWaves and has("AutoWavesToggle") then
            print("[AUTO] 🌊 Auto Waves")
            setv("WavesDelaySlider", VZ.WavesDelay)
            setv("AutoWavesToggle", true)

        elseif VZ.AutoMission and not (VZ.Brain ~= false) and has("AutoStartMissionToggle") then
            print(string.format("[AUTO] 🗺️ สร้างด่าน %s / %s / %s",
                tostring(VZ.Mission), tostring(VZ.Objective), tostring(VZ.Difficulty)))
            setv("MissionDropdown", VZ.Mission)
            task.wait(1)
            setv("MissionObjectiveDropdown", VZ.Objective)
            setv("MissionDifficultyDropdown", VZ.Difficulty)
            setv("MissionModifiersDropdown", tset(VZ.Modifiers))
            setv("MissionDelaySlider", VZ.MissionDelay)
            task.wait(1)
            setv("AutoStartMissionToggle", true)
        end
        getgenv().VenozChoresDone = true      -- ✅ brain สร้างด่านได้แล้ว
        print("[AUTO] ✅ ลำดับงาน Lobby เสร็จ → brain ทำต่อ")

    -- ══════════════════ ⚔️ MISSION ══════════════════
    else
        print("[AUTO] ⚔️ Mission — เปิดฟาร์มทันที (ไม่รออะไรทั้งนั้น)")

        -- ⚡ [SPEED] เปิดฟาร์ม "เป็นอย่างแรกสุด" ก่อนตั้งค่าอื่นทุกตัว
        --    เดิม: ตั้ง 10 ค่า (×0.2) + wait 0.5 = กว่าจะฟาร์ม ~3 วิ → ไททันวิ่งมาฆ่าก่อน
        --    ใหม่: ยิง AutoFarmBlade ทันที แล้วค่อยตั้งค่าที่เหลือระหว่างที่บินอยู่
        if not (VZ.AutoThunderSpear and has("AutoThunderSpearToggle")) and VZ.AutoFarm then
            setv("HoverHeightSlider", VZ.HoverHeight)
            setv("HoverSpeedSlider", VZ.HoverSpeed)
            setv("FarmModeDropdown", VZ.FarmMode)
            setv("AutoFarmBlade", true)
            print("[AUTO] ⚡ ฟาร์มติดแล้ว → บินหาไททันได้เลย")
        end

        if (tonumber(VZ.StopAtTitans) or 0) > 0 or (tonumber(VZ.SafetyTime) or 0) > 0 then
            warn(string.format("[AUTO] ⚠️ SafetyTime=%s / StopAtTitans=%s → บอทจะ 'หยุดตี' เมื่อไททันเหลือน้อย"
                .. " (ตั้ง 0 ทั้งคู่ถ้าอยากให้ตีตลอด)",
                tostring(VZ.SafetyTime), tostring(VZ.StopAtTitans)))
        end
        setv("KillHitsSlider", VZ.HitCap)
        setv("SafetyTimeSlider", VZ.SafetyTime)
        setv("StopAtTitansLeftSlider", VZ.StopAtTitans)

        if VZ.SkipCutscene then setv("SkipCutSceneToggle", true) end
        if VZ.SkipForce    then setv("SkipForceToggle", true) end
        setv("AutoReloadBlade", false)   -- [CHICKEN] ปิดของ UI2 (path ถังแก๊สพัง) → ใช้ VENOZ BLADE SYSTEM แทน
        if VZ.AutoRetry    then setv("StartRejoin", true) end
        if VZ.AutoSpearQuest and has("AutoSpearQuestToggle") then
            setv("AutoSpearQuestToggle", true)
        end

        if VZ.AutoThunderSpear and has("AutoThunderSpearToggle") then
            print("[AUTO] ⚡ ฟาร์มด้วย Thunder Spear")
            setv("ThunderSpear_FarmMode", VZ.SpearFarmMode)
            setv("ThunderSpear_HoverHeight", VZ.SpearHoverHeight)
            setv("ThunderSpear_HoverSpeed", VZ.SpearHoverSpeed)
            setv("AutoThunderSpearToggle", true)
        end   -- (ฟาร์มดาบถูกเปิดไปแล้วด้านบนสุด — ไม่ต้องเปิดซ้ำ)

        if VZ.FailedSafe and has("CombinedActionToggle") then
            setv("CombinedActionDelaySlider", VZ.FailedSafeDelay)
            setv("CombinedActionsDropdown", tset(VZ.FailedSafeActions))
            setv("CombinedActionToggle", true)
        end

        print(string.format("[AUTO] ✅ ฟาร์มแล้ว | โหมดไก่=%s | ตี %d ตัว ทุก ~%.1f วิ",
            tostring(VZ.Enabled), VZ.HitCap, VZ.AttackInterval))
    end
end)


-- ═══════════════════════════════════════════════════════════════
-- 🧠 VENOZ BRAIN — ยก logic บอท "ไก่ตัน" ตัวเก่ามาทั้งชุด
-- ═══════════════════════════════════════════════════════════════
--   1) หลุดเข้า Docks/Stohess/Trade → วาร์ปกลับ Lobby
--   2) Lobby: ขาย perk → จุติ (อ่าน talent ที่ server offer = 2-3 call) → สร้างด่าน Chapel เอง
--   3) Mission: กันตกแมพ + ตอนจบเลือก LEAVE (perk เต็ม/พร้อมจุติ) หรือ RETRY
--   4) เฝ้าสถานะ Shadow Ban + ป้ายสถานะกลางจอ
--   ปิด: getgenv().VenozChicken.Brain = false
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    local VZ = getgenv().VenozChicken or {}
    if VZ.Brain == false then return end
    if VZ.ForceChapel == nil then VZ.ForceChapel = true end
    if VZ.ShowStatus  == nil then VZ.ShowStatus  = true end
    VZ.PerkSellTarget = tonumber(VZ.PerkSellTarget) or 200
    VZ.PerkSellLow    = tonumber(VZ.PerkSellLow) or 30
    VZ.PrestigeTarget = tonumber(VZ.PrestigeTarget) or 5

    -- 🎯 เป้าขาย perk ตามความยากด่าน "ที่เล่นจริง"
    --    easy1 normal2 hard3 severe4 | aberrant5 aberrant+6 aberrant++7
    --    ต่ำกว่า Aberrant (Severe ลงมา) → PerkSellLow (30) ขายไวไม่ค้าง
    --    Aberrant ขึ้นไป              → PerkSellTarget (200, ฟาร์มยาว)
    local DIFF_RANK = {
        easy = 1, normal = 2, hard = 3, severe = 4,
        aberrant = 5, ["aberrant+"] = 6, ["aberrant++"] = 7,
    }
    -- ปรับได้ที่ config: PerkHighFrom = "Aberrant" (ค่าเริ่มต้น) หรือ "Severe" แบบเดิม
    local HIGH_FROM = DIFF_RANK[string.lower(tostring(VZ.PerkHighFrom or "Aberrant"))] or 5

    -- ชื่อที่เกมคืนมาอาจมีวงเล็บเกรดต่อท้าย เช่น "Severe (B- Grade)" → ตัดทิ้งก่อนเทียบ
    local function normDiff(d)
        local s = string.lower(tostring(d or ""))
        s = s:gsub("%b()", "")            -- ตัด "(B- Grade)"
        s = s:gsub("grade", ""):gsub("[%s]+", "")
        return s
    end
    local function latchDiff(d)
        if not d then return end
        local r = DIFF_RANK[normDiff(d)]
        if r then
            getgenv().VenozDiffRank = r
            getgenv().VenozDiffName = tostring(d)
        end
    end
    local function perkTarget()
        pcall(function() latchDiff(workspace:GetAttribute("Difficulty")) end)
        local rank = tonumber(getgenv().VenozDiffRank) or 0
        if rank >= HIGH_FROM then return VZ.PerkSellTarget end
        return VZ.PerkSellLow
    end
    VZ.GoldReq = VZ.GoldReq or {0, 0, 0, 0, 0}

    local RSb  = game:GetService("ReplicatedStorage")
    local plrB = game:GetService("Players").LocalPlayer
    local GETb
    pcall(function()
        GETb = RSb:WaitForChild("Assets", 20):WaitForChild("Remotes", 20):WaitForChild("GET", 20)
    end)
    if not GETb then warn("[BRAIN] ⛔ ไม่พบ GET remote") return end

    local SOCIAL_HUB = {
        [17688739434] = true, [110415968652032] = true,   -- Docks
        [15824912319] = true, [139092911630535] = true,   -- Stohess
        [14932214603] = true,                             -- Trade Lobby
    }

    -- ── slot data (cache 8 วิ) ──
    local cache, cacheT = nil, 0
    -- 🔁 [FIX] อ่าน slot data 2 ทางแบบบอทเก่า — Data/Copy บางทีไม่คืนค่าตอนอยู่ lobby
    local function fetchRaw()
        local ok, d = pcall(function() return GETb:InvokeServer("Data", "Copy") end)
        if ok and type(d) == "table" and type(d.Slots) == "table" then return d end
        -- endpoint สำรอง (ตัวที่บอทเก่าใช้มาตลอด — คืน slot data เหมือนกัน)
        ok, d = pcall(function() return GETb:InvokeServer("Functions", "Settings", "Blur", "Off") end)
        if ok and type(d) == "table" and type(d.Slots) == "table" then return d end
        return nil
    end
    local function getSlot(force)
        local now = os.clock()
        -- ยังไม่เคยอ่านได้ → ลองใหม่ถี่ๆ (2 วิ) | อ่านได้แล้ว → cache 8 วิ
        local ttl = cache and 8 or 2
        if not force and cache and (now - cacheT) < ttl then return cache end
        local d = fetchRaw()
        if d then
            local key = d.Current_Slot or plrB:GetAttribute("Slot") or VZ.Slot or "A"
            local sd = d.Slots[key]
            if not sd then   -- key ไม่ตรง → เอา slot แรกที่มี Progression
                for _, v in pairs(d.Slots) do
                    if type(v) == "table" and v.Progression then sd = v break end
                end
            end
            if sd then cache, cacheT = sd, now end
            -- 📤 แชร์ payload เต็มให้ระบบอื่นใช้ต่อ (ระบบ boost ต้องใช้ d.Boosts ที่อยู่ชั้นบนสุด)
            getgenv().VenozRaw  = d
            getgenv().VenozRawT = os.time()
        end
        return cache
    end
    local function perkInfo()
        local sd = getSlot()
        local uuids, total = {}, 0
        if sd and sd.Perks and type(sd.Perks.Storage) == "table" then
            for k, v in pairs(sd.Perks.Storage) do
                total = total + 1
                if type(v) == "table" and v.Name and not v.Equipped then table.insert(uuids, k) end
            end
        end
        return #uuids, total, uuids
    end
    -- 📊 [FIX] อ่านสถานะจากหลายแหล่ง (slot data → attribute → GUI) แบบบอทเก่า
    local function progress()
        local sd = getSlot()
        local pg = sd and sd.Progression
        local lv = tonumber(pg and pg.Level)    or tonumber(plrB:GetAttribute("Level"))    or 0
        local pr = tonumber(pg and pg.Prestige) or tonumber(plrB:GetAttribute("Prestige")) or 0
        local xp = math.max(tonumber(pg and pg.XP) or tonumber(plrB:GetAttribute("XP")) or 0, 0)
        local mx = tonumber(pg and pg.Max_XP)   or tonumber(plrB:GetAttribute("Max_XP"))   or 0
        local gold = (sd and sd.Currency and tonumber(sd.Currency.Gold))
                  or tonumber(plrB:GetAttribute("Gold")) or 0
        -- 💎 เพชร — คีย์จริงในเกมคือ sd.Currency.Gems (ยืนยันจาก client จริงแล้ว)
        local gems = (sd and sd.Currency and tonumber(sd.Currency.Gems))
                  or tonumber(plrB:GetAttribute("Gems")) or 0
        -- 🖥️ สำรองสุดท้าย: อ่านจาก GUI (path เดียวกับที่ UI2 ใช้แล้วได้ผลจริง)
        if gold <= 0 or gems <= 0 then
            pcall(function()
                local cur = plrB.PlayerGui.Interface.Topbar.Main.Currencies
                if gold <= 0 then
                    local g = tonumber((cur.Gold.Amount.Text:gsub("[^%d]", "")))
                    if g and g > 0 then gold = g end
                end
                if gems <= 0 then
                    local gm = cur:FindFirstChild("Gems")
                    local lbl = gm and gm:FindFirstChild("Amount")
                    if lbl then
                        local n = tonumber((tostring(lbl.Text):gsub("[^%d]", "")))
                        if n and n > 0 then gems = n end
                    end
                end
            end)
        end
        getgenv().VenozGems = gems
        local xpPct = 0
        if lv <= 0 then
            pcall(function()
                local t = plrB.PlayerGui.Interface.Gear_Up.HUD.Level.Title
                local n = tonumber(tostring(t.Text):match("%d+"))
                if n and n > 0 then lv = n end
            end)
        end
        pcall(function()
            local t = plrB.PlayerGui.Interface.Gear_Up.XP.Percentage
            local n = tonumber(tostring(t.Text):match("(%d+)%%"))
            if n then xpPct = n end
        end)
        return lv, pr, xp, mx, gold, xpPct, gems
    end
    local function isTan()
        local lv, pr, xp, mx, _, pct = progress()
        local full = (mx > 0 and xp >= mx) or ((pct or 0) >= 100)
        return (lv > 0 and lv >= (100 + pr * 25) and full), pr
    end
    -- 🖱️ ใช้คลิกเมาส์จริง (ปุ่มหน้าจบด่านไม่รับวิธี GuiService+Enter)
    local function clickBtn(btn)
        if not btn then return false end
        return VenozPress(btn)
    end
    local function clickBtnOld(btn)
        if not btn then return false end
        local GS, VIM = game:GetService("GuiService"), game:GetService("VirtualInputManager")
        return pcall(function()
            GS.SelectedObject = btn
            task.wait(0.05)
            VIM:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
            task.wait(0.05)
            VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
            task.wait(0.05)
            GS.SelectedObject = nil
        end)
    end

    -- ── 🛡️ SB WATCHER (ไม่ยิง remote) ──
    task.spawn(function()
        while true do
            pcall(function()
                local bl, trd = plrB:GetAttribute("Blacklisted"), plrB:GetAttribute("Trades")
                if bl ~= nil or trd ~= nil then
                    local ok = not (bl == true or trd == 0)
                    if getgenv().VenozSB ~= ok then
                        getgenv().VenozSB = ok
                        if ok then print("[SB] ✅ ปกติ")
                        else warn("[SB] 🚨 โดน Shadow Ban!") end
                    end
                end
            end)
            task.wait(10)
        end
    end)

    -- ── 📊 ป้ายสถานะกลางจอ ──
    local statusLbl
    if VZ.ShowStatus then
        pcall(function()
            local parent = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
            local old = parent:FindFirstChild("VenozChickenStatus")
            if old then old:Destroy() end
            local sg = Instance.new("ScreenGui")
            sg.Name = "VenozChickenStatus"; sg.ResetOnSpawn = false
            sg.IgnoreGuiInset = true; sg.DisplayOrder = 9999; sg.Parent = parent
            statusLbl = Instance.new("TextLabel")
            statusLbl.AnchorPoint = Vector2.new(0.5, 0)
            statusLbl.Position = UDim2.new(0.5, 0, 0, 8)
            statusLbl.Size = UDim2.new(0, 660, 0, 140)   -- 5 บรรทัด (เดิม 96 = บรรทัด 🧪 ถูกตัดหาย)
            statusLbl.BackgroundTransparency = 1
            statusLbl.TextYAlignment = Enum.TextYAlignment.Top
            statusLbl.RichText = true
            statusLbl.Font = Enum.Font.GothamBold
            statusLbl.TextSize = 15
            statusLbl.TextColor3 = Color3.fromRGB(240, 240, 240)
            statusLbl.TextStrokeTransparency = 0
            statusLbl.Text = "🐔 VENOZ"
            statusLbl.Parent = sg
        end)
    end
    local function setStatus(txt)
        getgenv().VenozAction = txt
        if not statusLbl then return end
        pcall(function()
            local lv, pr, xp, mx, gold, _, gems = progress()
            local sellable = perkInfo()
            local sb = (getgenv().VenozSB == false) and "<font color='#ff3333'>❌ โดนแบน</font>"
                    or (getgenv().VenozSB == true) and "<font color='#33ff99'>✅ ปกติ</font>"
                    or "<font color='#aaaaaa'>⏳</font>"
            -- 🧪 boost ที่ติดอยู่ตอนนี้ (อ่านจาก Data.Copy ชั้นบนสุด → .Boosts)
            local bs = getgenv().VenozBoostStr or "⏳"
            statusLbl.Text = string.format(
                "🐔 <b><font color='#b46bff'>VENOZ CHICKEN</font></b>   🛡️ %s\n" ..
                "🎖️ Lv <b>%d/%d</b>  👑 <b>P.%d</b>  📊 XP %d/%d\n" ..
                "💰 %d   💎 <b><font color='#66d9ff'>%d</font></b>   ⚔️ Perk %d/%d\n" ..
                "🧪 %s\n" ..
                "<font color='#00e5ff'>%s</font>",
                sb, lv, 100 + pr * 25, pr, xp, mx, gold, gems,
                sellable, perkTarget(), bs, tostring(txt))
        end)
    end

    -- ── 👑 จุติแบบบอทเก่า: อ่าน talent ที่ server offer → ยิงตัวเดียว ──
    local function doPrestige(pr)
        setStatus("👑 กำลังจุติ...")
        pcall(function() if Toggles and Toggles.PrestigeToggle then Toggles.PrestigeToggle:SetValue(false) end end)

        local keyToTag = {}
        pcall(function()
            for _, d in ipairs(RSb:GetDescendants()) do
                if d:IsA("ModuleScript") and d.Name == "Memories" then
                    local okM, M = pcall(require, d)
                    if okM and type(M) == "table" and type(M.Talents) == "table" then
                        for _, cat in pairs(M.Talents) do
                            if type(cat) == "table" then
                                for k, v in pairs(cat) do
                                    if type(v) == "table" and v.Tag then keyToTag[tostring(k)] = v.Tag end
                                end
                            end
                        end
                    end
                    break
                end
            end
        end)

        pcall(function() GETb:InvokeServer("S_Equipment", "Talents") end)
        task.wait(0.3)
        local sd = getSlot(true)
        local order, seen = {}, {}
        local function push(k)
            local tag = keyToTag[tostring(k)]
            if not tag and type(k) == "string" and #k > 2 then tag = k end
            if tag and not seen[tag] then seen[tag] = true; order[#order + 1] = tag end
        end
        if sd and type(sd.Next_Talents) == "table" then
            for _, k in pairs(sd.Next_Talents) do
                if type(k) == "table" then for _, k2 in pairs(k) do push(k2) end else push(k) end
            end
        end
        if #order == 0 then
            for _, t in pairs(keyToTag) do if not seen[t] then seen[t] = true; order[#order + 1] = t end end
        end

        print(string.format("[BRAIN] 👑 จุติ P%d → P%d (offer %d ตัว)", pr, pr + 1, #order))
        local before = pr
        for i, tag in ipairs(order) do
            pcall(function()
                GETb:InvokeServer("S_Equipment", "Prestige",
                    { Boosts = VZ.PrestigeBoost or "Gold Boost", Talents = tag })
            end)
            task.wait(0.3 + math.random() * 0.2)
            local _, nowP = progress()
            if nowP > before then
                print(string.format("[BRAIN] ✅ จุติสำเร็จที่ call %d (talent %s)", i, tostring(tag)))
                return true
            end
            getSlot(true)
            if i >= 12 then break end
        end
        warn("[BRAIN] ⚠️ จุติไม่ติด — รอรอบหน้า")
        return false
    end

    -- ── 🗺️ สร้างด่าน Chapel เอง (มี fallback ความยากแบบบอทเก่า) ──
    local function createMission()
        setStatus("🗺️ กำลังสร้างด่าน Chapel...")
        pcall(function()
            local ch = plrB.Character
            local root = ch and ch:FindFirstChild("HumanoidRootPart")
            if root then
                for _, prt in ipairs(ch:GetDescendants()) do
                    if prt:IsA("BasePart") then prt.CanCollide = false end
                end
                root.CFrame = CFrame.new(233.395, 8.865, 37.525)
                root.Anchored = true; task.wait(1); root.Anchored = false
            end
        end)
        pcall(function() GETb:InvokeServer("S_Missions", "Leave") end)
        task.wait(1)

        local mapData = {
            Name = "Chapel", Type = "Missions",
            Objective = VZ.Objective or "Skirmish",
            Difficulty = VZ.Difficulty or "Aberrant++",
            Modifiers = VZ.Modifiers or {},
        }
        local res
        pcall(function() res = GETb:InvokeServer("S_Missions", "Create", mapData) end)
        if res == nil then
            -- ⬇️ ไล่จากยากไปง่าย (เดิมเรียง Severe ก่อน Aberrant = ยอมเล่นด่านง่ายกว่าที่ปลดได้)
            local fallbacks = { "Aberrant+", "Aberrant", "Severe", "Hard", "Normal", "Easy" }
            for _, diff in ipairs(fallbacks) do
                mapData.Difficulty = diff
                pcall(function() res = GETb:InvokeServer("S_Missions", "Create", mapData) end)
                if res ~= nil then break end
                task.wait(0.5)
            end
        end
        if res ~= nil then
            latchDiff(mapData.Difficulty)
            pcall(function() GETb:InvokeServer("S_Missions", "Modify", mapData.Difficulty) end)
            pcall(function() GETb:InvokeServer("S_Missions", "Start") end)
            print(string.format("[BRAIN] ✅ สร้างด่าน Chapel (%s) → เป้าขาย perk = %d",
                tostring(mapData.Difficulty), perkTarget()))
            setStatus("🚀 เข้าด่าน...")
            return true
        end
        warn("[BRAIN] ⚠️ สร้างด่านไม่ได้ — รอรอบหน้า")
        return false
    end

    -- ── 🛡️ กันตกแมพ (เฉพาะในด่าน) ──
    task.spawn(function()
        while true do
            task.wait(1)
            if not IsLobbyLobby() and not IsMainmenuLobby() then
                pcall(function()
                    local ch = plrB.Character
                    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                    local hum = ch and ch:FindFirstChildWhichIsA("Humanoid")
                    if hrp and hum and hum.Health > 0 and hrp.Position.Y < -50 then
                        hrp.CFrame = CFrame.new(hrp.Position.X, 150, hrp.Position.Z)
                        hrp.AssemblyLinearVelocity = Vector3.zero
                    end
                end)
            end
        end
    end)

    -- ═══════════ MAIN LOOP ═══════════
    local lastSell, lastMission = 0, os.clock()
    print(string.format("[BRAIN] 🧠 เริ่มทำงาน | ขาย perk: ต่ำกว่า %s = %d | %s ขึ้นไป = %d",
        tostring(VZ.PerkHighFrom or "Aberrant"), VZ.PerkSellLow,
        tostring(VZ.PerkHighFrom or "Aberrant"), VZ.PerkSellTarget))

    while true do
        task.wait(8)
        pcall(function()
            -- 1) หลุดเข้า social hub → กลับ Lobby
            if SOCIAL_HUB[game.PlaceId] then
                setStatus("🚪 อยู่ hub → กลับ Lobby")
                pcall(function() GETb:InvokeServer("Functions", "Teleport", "Lobby") end)
                task.wait(10)
                return
            end

            if IsLobbyLobby() then
                local lv, pr, xp, mx, gold = progress()

                -- ⏳ [FIX] ข้อมูลยังไม่โหลด (โชว์ 0 ทุกอย่าง) → ห้ามตัดสินใจอะไรทั้งนั้น
                --    เดิม: เห็น perk=0 → ไม่ขาย, เห็น lv=0 → ไม่จุติ, แล้วสร้างด่านเลย
                if lv <= 0 and gold <= 0 and mx <= 0 then
                    setStatus("⏳ รอข้อมูลผู้เล่นโหลด...")
                    getSlot(true)
                    getgenv()._VZWait = (getgenv()._VZWait or 0) + 1
                    if getgenv()._VZWait % 4 == 1 then
                        warn(string.format("[BRAIN] ⏳ ยังอ่านข้อมูลไม่ได้ (ครั้งที่ %d) — slotData=%s attrLv=%s",
                            getgenv()._VZWait, tostring(getSlot() ~= nil),
                            tostring(plrB:GetAttribute("Level"))))
                    end
                    return
                end
                -- อ่าน slot data ไม่ได้ = นับ perk ไม่ได้ → รอก่อน (แต่ไม่รอตลอดกาล)
                if not getSlot() then
                    getgenv()._VZPerkWait = (getgenv()._VZPerkWait or 0) + 1
                    if getgenv()._VZPerkWait <= 8 then    -- รอสูงสุด ~64 วิ
                        setStatus("⏳ รอข้อมูล perk/inventory...")
                        getSlot(true)
                        return
                    end
                    warn("[BRAIN] ⚠️ อ่าน perk ไม่ได้เกิน 1 นาที → ข้ามการขาย ไปสร้างด่านต่อ")
                end

                local sellable, total, uuids = perkInfo()
                local tan = (lv >= (100 + pr * 25) and mx > 0 and xp >= mx)

                if not getgenv()._VZDataLogged then
                    getgenv()._VZDataLogged = true
                    print(string.format("[BRAIN] ✅ อ่านข้อมูลได้ — Lv %d/%d | P%d | XP %d/%d | ทอง %d | 💎 เพชร %d | Perk ขายได้ %d (ทั้งหมด %d)",
                        lv, 100 + pr * 25, pr, xp, mx, gold,
                        tonumber(getgenv().VenozGems) or 0, sellable, total))
                end

                -- 2) ล็อคด่าน Chapel
                if VZ.ForceChapel and Options and Options.MissionDropdown
                   and Options.MissionDropdown.Value ~= "Chapel" then
                    Options.MissionDropdown:SetValue("Chapel")
                end

                -- 3) ขาย perk ก่อนเสมอ
                local pTarget = perkTarget()
                if sellable >= pTarget and (os.clock() - lastSell) > 20 then
                    lastSell = os.clock()
                    setStatus(string.format("🗑️ ขาย perk %d ชิ้น", sellable))
                    print(string.format("[BRAIN] 🗑️ ขาย perk %d (ทั้งหมด %d | เป้า %d)",
                        sellable, total, pTarget))
                    pcall(function() GETb:InvokeServer("S_Equipment", "Delete", "Perk", uuids) end)
                    task.wait(1.5)
                    getSlot(true)
                    if perkInfo() >= pTarget then
                        for _, id in ipairs(uuids) do
                            pcall(function() GETb:InvokeServer("S_Equipment", "Delete", "Perk", { id }) end)
                            task.wait(0.2)
                        end
                        getSlot(true)
                    end
                    print("[BRAIN] ✅ ขาย perk เสร็จ")
                    return
                end

                -- 3.5) รอ auto-pilot เก็บงาน lobby ให้เสร็จก่อนค่อยจุติ/สร้างด่าน
                --      (ขาย perk ทำไปแล้วข้างบน — ไม่ต้องรอ เพราะสำคัญและเร็ว)
                if not getgenv().VenozChoresDone then
                    getgenv()._VZChoreWait = (getgenv()._VZChoreWait or 0) + 1
                    if getgenv()._VZChoreWait <= 20 then       -- รอสูงสุด ~160 วิ
                                                              -- (อัพดาบอย่างเดียวกินได้ถึง 120 วิ)
                        setStatus("⏳ กำลังเก็บงาน lobby (เควส/อัพเกรด/สกิล)...")
                        return
                    end
                    warn("[BRAIN] ⚠️ งาน lobby ไม่จบใน 160 วิ → ไปต่อเลย")
                    getgenv().VenozChoresDone = true
                end

                -- 4) จุติ (ตัน + ยังไม่ถึงเป้า + ทองถึงเกณฑ์)
                if tan and pr < VZ.PrestigeTarget then
                    local reqM = tonumber(VZ.GoldReq[pr + 1]) or 0
                    if gold >= reqM * 1000000 then
                        doPrestige(pr)
                        getSlot(true)
                        task.wait(3)
                        return
                    else
                        setStatus(string.format("💰 รอทองจุติ %d/%dM", math.floor(gold / 1000000), reqM))
                        return
                    end
                end

                -- 5) สร้างด่าน Chapel (บอทเราคุมเอง ไม่พึ่ง AutoStartMission)
                if (os.clock() - lastMission) > 20 then
                    lastMission = os.clock()
                    createMission()
                else
                    setStatus(string.format("🏠 Lobby | Lv%d P%d | Perk %d/%d",
                        lv, pr, sellable, pTarget))
                end

            elseif not IsMainmenuLobby() then
                -- 6) ในด่าน: ตอนจบเลือก LEAVE / RETRY
                local iface = plrB.PlayerGui:FindFirstChild("Interface")
                local rewards = iface and iface:FindFirstChild("Rewards")
                if rewards and rewards.Visible then
                    local sellable = perkInfo()
                    local tan, pr = isTan()
                    local pT = perkTarget()
                    local wantLeave = (sellable >= pT) or (tan and pr < VZ.PrestigeTarget)
                    if wantLeave then
                        getgenv().StartRejoin = false
                        local b = rewards:FindFirstChild("Main")
                        b = b and b:FindFirstChild("Info"); b = b and b:FindFirstChild("Main")
                        b = b and b:FindFirstChild("Buttons")
                        local leave = b and (b:FindFirstChild("Leave_2") or b:FindFirstChild("Leave"))
                        if leave then
                            print(string.format("[BRAIN] 🚪 LEAVE — perk=%d/%d ตัน=%s P%d",
                                sellable, pT, tostring(tan), pr))
                            setStatus("🚪 ออกจากด่าน (ไปขาย perk / จุติ)")
                            clickBtn(leave)
                            task.wait(5)
                        end
                    else
                        getgenv().StartRejoin = true
                        setStatus("🔁 RETRY ด่านเดิม")
                    end
                else
                    setStatus(getgenv().VenozAction or "⚔️ ฟาร์ม")
                end
            end
        end)
    end
end)


-- ═══════════════════════════════════════════════════════════════
-- 🗡️ VENOZ BLADE SYSTEM — ยกระบบดาบของบอทตัวเก่ามาแทนของ UI2
-- ═══════════════════════════════════════════════════════════════
--   🐛 ของ UI2 พัง: hardcode path ถังแก๊ส (Props.HQ:GetChildren()[224].Refill)
--      → แมพ Chapel ไม่มี index นั้น = หาไม่เจอ = ไม่เติมเลย ดาบพังค้าง
--   ✅ ของเรา: หา Refill แบบสแกนจริง + เช็ค Sets/Refills + กด R ก่อนแล้วค่อยยิง remote
--   ปิด: getgenv().VenozChicken.AutoReload = false
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    local VZb = getgenv().VenozChicken or {}
    if VZb.AutoReload == false then return end
    local Plrs = game:GetService("Players")
    local me = Plrs.LocalPlayer
    local RSb2 = game:GetService("ReplicatedStorage")
    local GETv, POSTv
    pcall(function()
        local rem = RSb2:WaitForChild("Assets", 20):WaitForChild("Remotes", 20)
        GETv, POSTv = rem:WaitForChild("GET", 10), rem:WaitForChild("POST", 10)
    end)
    if not (GETv and POSTv) then warn("[BLADE] ⛔ ไม่พบ remote") return end

    local BLADE = { busy = false, gui = nil, tank = nil }

    -- 🔎 cache กล่อง Blades บน HUD (ใช้อ่านจำนวนชุดดาบ)
    task.spawn(function()
        while true do
            if not (BLADE.gui and BLADE.gui.Parent) then
                pcall(function()
                    local iface = me.PlayerGui:FindFirstChild("Interface")
                    local hud = iface and iface:FindFirstChild("HUD")
                    local main = hud and hud:FindFirstChild("Main")
                    local top = main and main:FindFirstChild("Top")
                    if top then
                        for _, v in ipairs(top:GetDescendants()) do
                            if v.Name == "Blades" and v:FindFirstChild("Sets") then
                                BLADE.gui = v
                                break
                            end
                        end
                    end
                end)
            end
            task.wait(3)
        end
    end)

    local function readSets()
        local g = BLADE.gui
        if not (g and g.Parent) then return nil end
        local sv = g:FindFirstChild("Sets")
        if sv and sv:IsA("TextLabel") then return tonumber(string.match(sv.Text, "%d+")) end
        return nil
    end

    -- ⭐ ดาบพังไหม (เช็ค 2 path — ทั้งใน Character และ workspace.Characters)
    local function isBroken()
        local found = false
        pcall(function()
            local rigs = {}
            local ch = me.Character
            if ch then table.insert(rigs, ch:FindFirstChild("Rig_" .. me.Name)) end
            local wc = workspace:FindFirstChild("Characters")
            local wch = wc and wc:FindFirstChild(me.Name)
            if wch then table.insert(rigs, wch:FindFirstChild("Rig_" .. me.Name)) end
            for _, rig in ipairs(rigs) do
                if rig then
                    for _, hand in ipairs(rig:GetChildren()) do
                        if hand.Name == "RightHand" or hand.Name == "LeftHand" then
                            local b = hand:FindFirstChild("Blade_1")
                            if b then
                                local attr = b:GetAttribute("Broken")
                                if attr == true or (b:IsA("BasePart") and b.Transparency ~= 0) then
                                    found = true
                                    return
                                end
                            end
                        end
                    end
                end
            end
        end)
        return found
    end

    -- ⭐ หาถังแก๊ส: Unclimbable.Reloads.<สถานี>.Refill → สำรอง: สแกนทั้ง workspace
    local function findTank()
        if BLADE.tank and BLADE.tank.Parent then return BLADE.tank end
        BLADE.tank = nil
        pcall(function()
            local unc = workspace:FindFirstChild("Unclimbable")
            local reloads = unc and unc:FindFirstChild("Reloads")
            if reloads then
                for _, st in ipairs(reloads:GetChildren()) do
                    local r = st:FindFirstChild("Refill")
                    if r then BLADE.tank = r return end
                end
            end
        end)
        if not BLADE.tank then
            pcall(function()
                local r = workspace:FindFirstChild("Refill", true)
                if r then BLADE.tank = r end
            end)
        end
        if BLADE.tank then print("[BLADE] 📍 GasTank: " .. BLADE.tank:GetFullName()) end
        return BLADE.tank
    end

    local function ensureBlade()
        if BLADE.busy then return end
        if not isBroken() then return end
        BLADE.busy = true
        getgenv().VenozBladeBusy = true

        -- ═══ 1) Sets = 0 + ดาบพัง → เติมที่ถังแก๊ส ═══
        local guard = 0
        while isBroken() and (readSets() or 0) == 0 and guard < 8 do
            guard = guard + 1
            local refills = me:GetAttribute("Refills") or 0
            if refills <= 0 then
                if not getgenv()._BladeNoRefill then
                    getgenv()._BladeNoRefill = true
                    warn("[BLADE] 🚫 Refills หมด — เติมไม่ได้จนจบด่าน")
                end
                break
            end
            local tank = findTank()
            if not tank then warn("[BLADE] ❌ ไม่พบถังแก๊สในแมพนี้") break end
            print(string.format("[BLADE] 📦 Refill #%d (เหลือ %d) — รอ 4 วิ", guard, refills))
            getgenv().VenozAction = string.format("📦 เติมดาบ (%d)", refills)
            pcall(function() POSTv:FireServer("Attacks", "Reload", tank) end)
            task.wait(4)
        end

        -- ═══ 2) ดาบพัง + มี Sets → สลับชุด (กด R ก่อน = 0 remote) ═══
        guard = 0
        while isBroken() and (readSets() or 0) > 0 and guard < 6 do
            guard = guard + 1
            local sets = readSets() or 0
            print(string.format("[BLADE] 🔄 สลับชุด #%d (Sets %d/3)", guard, sets))
            getgenv().VenozAction = string.format("🔄 สลับดาบ (%d/3)", sets)
            pcall(function()
                local vim = game:GetService("VirtualInputManager")
                vim:SendKeyEvent(true, Enum.KeyCode.R, false, game)
                task.wait(0.03)
                vim:SendKeyEvent(false, Enum.KeyCode.R, false, game)
            end)
            task.wait(1.2)
            if not isBroken() then break end
            pcall(function() GETv:InvokeServer("Blades", "Reload") end)
            task.wait(2)
        end

        if not isBroken() then
            print(string.format("[BLADE] ✅ ดาบพร้อม (Sets %s/3)", tostring(readSets() or "?")))
            getgenv()._BladeNoRefill = nil
        end
        BLADE.busy = false
        getgenv().VenozBladeBusy = false
    end

    print("[BLADE] 🗡️ ระบบดาบตัวเก่าเริ่มทำงาน")
    while true do
        task.wait(1)
        if not IsLobbyLobby() and not IsMainmenuLobby() then
            pcall(ensureBlade)
        end
    end
end)


-- ═══════════════════════════════════════════════════════════════
-- 🧪 VENOZ BOOST SYSTEM v3 — อ้างอิงโครงสร้างข้อมูลจริงของเกม
-- ═══════════════════════════════════════════════════════════════
--   ✅ ยืนยันจาก client จริงแล้วว่า:
--        Data.Copy.Slots[slot].Currency.Gems   ← เพชร (ไม่ใช่ Currencies)
--        Data.Copy.Boosts = {XP=0, Gold=0, Luck=0}  ← boost ที่ติดอยู่
--          • อยู่ "ชั้นบนสุด" ของ payload ไม่ได้อยู่ใน slot
--          • 0 = ไม่ติด | มากกว่า 0 = ติดอยู่  → ใช้ตัวนี้ตัดสินแทนการเดา
--        Data.Copy.Slots[slot].Inventory.Items = {ชื่อไอเทม = จำนวน}
--   ลำดับ: เช็ค Boosts → ไม่ติด: กินจากกระเป๋าก่อน → ไม่มีค่อยซื้อ
--   เลือกชนิดตาม prestige/level แบบเดิม:
--     • P3-P4 → ไม่เอา XP | P5+ → ไม่เอา Gold, เอา XP เฉพาะ level <= 130
--   ซื้อไล่จากก้อนใหญ่: 2H (13999) → 1H (7999) → 30M (4499)
--   ปิด: getgenv().VenozChicken.AutoBoost = false
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    local mePl = game:GetService("Players").LocalPlayer
    local GETo
    pcall(function()
        GETo = game:GetService("ReplicatedStorage")
            :WaitForChild("Assets", 20):WaitForChild("Remotes", 20):WaitForChild("GET", 20)
    end)
    if not GETo then warn("[BOOST] ⛔ ไม่พบ GET remote") return end

    local function cfg() return getgenv().VenozChicken or {} end

    -- 🔧 กัน config เก่าค้างใน getgenv (AutoBoost=false ตั้งแต่ตอนระบบยังพัง)
    do
        local c = getgenv().VenozChicken
        if c and c.AutoBoost == false and (tonumber(c.ConfigVersion) or 0) < 3 then
            c.AutoBoost = true
        end
    end
    print(string.format("[BOOST] ⚙️ สถานะ: %s | เพชรขั้นต่ำ %s | ชนิด %s",
        (cfg().AutoBoost == true) and "เปิด ✅" or "ปิด ❌",
        tostring(cfg().MinGemsToBuyBoosts or 4499),
        table.concat(cfg().BoostTypes or { "XP", "Gold" }, ",")))

    -- { id, ชื่อไอเทมจริง, ราคาเพชร, อายุ(วินาที) } — id ตรงกับ BOOST_MAP ของ UI2
    local SHOP = {
        XP = {
            { 3, "2X XP Boost [2H]", 13999, 7200 },
            { 2, "2X XP Boost [1H]", 7999, 3600 },
            { 1, "2X XP Boost [30M]", 4499, 1800 },
        },
        Gold = {
            { 9, "2X Gold [2H]", 13999, 7200 },
            { 8, "2X Gold [1H]", 7999, 3600 },
            { 7, "2X Gold [30M]", 4499, 1800 },
        },
        Luck = {
            { 6, "2X Luck [2H]", 13999, 7200 },
            { 5, "2X Luck [1H]", 7999, 3600 },
            { 4, "2X Luck [30M]", 4499, 1800 },
        },
    }
    local KIND_WORD = { XP = "xp", Gold = "gold", Luck = "luck" }

    -- ═══ ดึง payload เต็ม (ใช้ของ BRAIN ถ้าสดพอ = ประหยัด remote) ═══
    local rawC, rawT = nil, 0
    local function fetchAll(force)
        local now = os.clock()
        if not force then
            local shared = getgenv().VenozRaw
            if type(shared) == "table" and type(shared.Slots) == "table"
                and (os.time() - (tonumber(getgenv().VenozRawT) or 0)) <= 10 then
                return shared
            end
            if rawC and (now - rawT) < 10 then return rawC end
        end
        local d
        local ok, r = pcall(function() return GETo:InvokeServer("Data", "Copy") end)
        if ok and type(r) == "table" and type(r.Slots) == "table" then d = r end
        if not d then
            ok, r = pcall(function() return GETo:InvokeServer("Functions", "Settings", "Blur", "Off") end)
            if ok and type(r) == "table" and type(r.Slots) == "table" then d = r end
        end
        if d then
            rawC, rawT = d, now
            getgenv().VenozRaw, getgenv().VenozRawT = d, os.time()
        end
        return rawC
    end

    local function slotOf(d)
        if not d then return nil end
        local sd = d.Slots[d.Current_Slot or mePl:GetAttribute("Slot") or cfg().Slot or "A"]
        if not sd then
            for _, v in pairs(d.Slots) do
                if type(v) == "table" and v.Progression then sd = v break end
            end
        end
        return sd
    end

    -- ═══ 💎 เพชร ═══
    local function readGems(d)
        local sd = slotOf(d)
        local c = sd and (sd.Currency or sd.Currencies)
        local g = c and tonumber(c.Gems)
        if g and g > 0 then return g, "slot" end
        local a = tonumber(mePl:GetAttribute("Gems"))
        if a and a > 0 then return a, "attr" end
        local gui
        pcall(function()
            local cur = mePl.PlayerGui.Interface.Topbar.Main:FindFirstChild("Currencies")
            local gm = cur and cur:FindFirstChild("Gems")
            local lbl = gm and gm:FindFirstChild("Amount")
            if lbl then gui = tonumber((tostring(lbl.Text):gsub("[^%d]", ""))) end
        end)
        if gui and gui > 0 then return gui, "gui" end
        return 0, "none"
    end

    -- ═══ 🧪 boost ที่ติดอยู่ — อ่านจาก d.Boosts ตรงๆ ═══
    local function activeOf(d, kind)
        local b = d and d.Boosts
        if type(b) ~= "table" then return nil end          -- nil = อ่านไม่ได้
        local v = b[kind]
        if v == nil and kind == "XP" then v = b.Experience end
        return (tonumber(v) or 0) > 0, tonumber(v) or 0
    end

    -- ═══ หา boost ในกระเป๋า (เอาก้อนยาวสุดก่อน) ═══
    local function findInInv(sd, kind)
        local items = (sd and sd.Inventory and sd.Inventory.Items) or {}
        local word = KIND_WORD[kind] or string.lower(kind)
        local best, bestRank, bestDur = nil, -1, 1800
        for name, qty in pairs(items) do
            local q = tonumber(qty) or 0
            local nl = string.lower(tostring(name))
            -- Gold boost ชื่อจริงคือ "2X Gold [2H]" → ไม่มีคำว่า boost ห้ามบังคับ
            if q > 0 and nl:find(word, 1, true)
                and (nl:find("boost", 1, true) or nl:find("2x", 1, true)) then
                local r, dur = 0, 1800
                if nl:find("2h", 1, true) then r, dur = 3, 7200
                elseif nl:find("1h", 1, true) then r, dur = 2, 3600
                elseif nl:find("30m", 1, true) then r, dur = 1, 1800 end
                if r > bestRank then best, bestRank, bestDur = name, r, dur end
            end
        end
        return best, bestDur
    end

    local nextCheck, lastOff = 0, 0
    print("[BOOST] 🧪 ระบบ boost v3 พร้อม (อ่าน Data.Copy.Boosts + Currency.Gems)")

    while true do
        task.wait(3)
        local VZo = cfg()
        if VZo.AutoBoost ~= true then
            if os.time() - lastOff > 300 then
                lastOff = os.time()
                print("[BOOST] 💤 ปิดอยู่ — เปิดที่ config: AutoBoost = true")
            end
        elseif IsLobbyLobby() and os.time() >= nextCheck then
            local minGems = tonumber(VZo.MinGemsToBuyBoosts) or 4499
            local acted, evaluated = false, false
            local okRun, err = pcall(function()
                local d = fetchAll()
                if not d then
                    warn("[BOOST] ⏳ ยังอ่านข้อมูลไม่ได้ → ลองใหม่ใน 8 วิ")
                    return
                end
                local sd = slotOf(d)
                local pg = (sd and sd.Progression) or {}
                local prestige = tonumber(pg.Prestige) or tonumber(mePl:GetAttribute("Prestige")) or 0
                local level = tonumber(pg.Level) or tonumber(mePl:GetAttribute("Level")) or 0
                local gems, gsrc = readGems(d)

                -- ── เลือกชนิด boost ที่ต้องการ (สูตรเดิม) ──
                local need = {}
                if VZo.IgnorePrestigeFilter == true and type(VZo.BoostTypes) == "table" then
                    -- 🔓 เอาตาม BoostTypes ตรงๆ ไม่สนเงื่อนไข prestige
                    for _, b in ipairs(VZo.BoostTypes) do table.insert(need, b) end
                elseif type(VZo.BoostTypes) == "table" and #VZo.BoostTypes > 0 then
                    for _, b in ipairs(VZo.BoostTypes) do
                        if (prestige == 3 or prestige == 4) and b == "XP" then
                        elseif prestige >= 5 and b == "Gold" then
                        elseif prestige >= 5 and b == "XP" and level > 130 then
                        else table.insert(need, b) end
                    end
                else
                    if prestige <= 3 then table.insert(need, "XP")
                    elseif prestige >= 5 and level <= 130 then table.insert(need, "XP") end
                    if prestige <= 4 then table.insert(need, "Gold") end
                end

                -- ── 📋 log สถานะทุกชนิด (ดูใน F9 ได้เลย) ──
                local parts, shown = {}, {}
                for _, k in ipairs({ "XP", "Gold", "Luck" }) do
                    local on, val = activeOf(d, k)
                    if on == nil then
                        parts[#parts + 1] = k .. "=?"
                    else
                        -- ค่าใน Boosts = วินาทีที่เหลือ → แปลงเป็นนาทีให้อ่านง่าย
                        parts[#parts + 1] = string.format("%s=%s", k,
                            on and string.format("ติด %d นาที", math.floor(val / 60)) or "ไม่ติด")
                        if on then shown[#shown + 1] = string.format("%s %dm", k, math.floor(val / 60)) end
                    end
                end
                getgenv().VenozBoostStr = (#shown > 0)
                    and ("ติดอยู่: " .. table.concat(shown, ", "))
                    or "ไม่มี boost ติด"
                print(string.format("[BOOST] 💎 เพชร %d (จาก %s) | ขั้นต่ำ %d | P%d Lv%d | อยากได้ %s | %s",
                    gems, gsrc, minGems, prestige, level,
                    (#need > 0 and table.concat(need, ",") or "-"),
                    table.concat(parts, " ")))

                if gsrc == "none" then
                    warn("[BOOST] ⚠️ อ่านเพชรไม่ได้เลย → ยังไม่ซื้อ (รอข้อมูลโหลด)")
                    return
                end
                evaluated = true   -- ✅ ตรวจครบจริง (ข้อมูลพร้อม) → ค่อยพักยาวได้

                for _, kind in ipairs(need) do
                    if acted then break end
                    if not SHOP[kind] then
                        warn("[BOOST] ⚠️ ไม่รู้จักชนิด " .. tostring(kind))
                    elseif activeOf(d, kind) == false then
                        -- 1️⃣ กินของในกระเป๋าก่อน (ฟรี)
                        local hadItem = findInInv(sd, kind)
                        local useFailed = false
                        if hadItem then
                            print(string.format("[BOOST] 🍷 กิน %s (มีในกระเป๋า)", tostring(hadItem)))
                            pcall(function() GETo:InvokeServer("S_Inventory", "Item", hadItem) end)
                            task.wait(1.2)
                            local d2 = fetchAll(true)
                            if activeOf(d2, kind) == true then
                                print("[BOOST] ✅ ใช้สำเร็จ — " .. kind .. " ติดแล้ว")
                                acted = true
                            else
                                -- ⚠️ มีของแต่ใช้ไม่ติด → "ห้ามซื้อเพิ่ม" เพราะซื้อมาก็ใช้ไม่ได้เหมือนกัน (เปลืองเพชรฟรี)
                                useFailed = true
                                warn(string.format("[BOOST] ⚠️ มี %s อยู่แล้วแต่ใช้ไม่ติด → ข้ามการซื้อรอบนี้ (กันเปลืองเพชร)",
                                    tostring(hadItem)))
                            end
                        end

                        -- 2️⃣ ไม่มีของในกระเป๋าเลย → ค่อยซื้อ
                        if not acted and not useFailed then
                            if gems < minGems then
                                print(string.format("[BOOST] 🚫 %s: เพชรไม่ถึงเกณฑ์ (%d < %d) → ข้าม",
                                    kind, gems, minGems))
                            else
                                for _, t in ipairs(SHOP[kind]) do
                                    if acted then break end
                                    local idx, nm, price = t[1], t[2], t[3]
                                    if gems >= price then
                                        print(string.format("[BOOST] 💳 ซื้อ %s (%d เพชร)", nm, price))
                                        pcall(function()
                                            GETo:InvokeServer("S_Market", "Buy", "1_Boosts", idx, 1)
                                        end)
                                        task.wait(1.2)
                                        local d2 = fetchAll(true)
                                        local after = readGems(d2)
                                        local bought = (after > 0 and after <= gems - math.floor(price * 0.9))
                                            or (findInInv(slotOf(d2), kind) ~= nil)
                                        if bought then
                                            print(string.format("[BOOST] 🛒 ซื้อผ่าน (เพชร %d → %d) → ใช้เลย", gems, after))
                                            local useName = findInInv(slotOf(d2), kind) or nm
                                            pcall(function()
                                                GETo:InvokeServer("S_Inventory", "Item", useName)
                                            end)
                                            task.wait(1.2)
                                            local d3 = fetchAll(true)
                                            if activeOf(d3, kind) == true then
                                                print("[BOOST] ✅ " .. kind .. " ติดแล้ว เรียบร้อย")
                                            else
                                                warn("[BOOST] ⚠️ ซื้อได้แต่ใช้ไม่ติด (ชื่อไอเทม: "
                                                    .. tostring(useName) .. ") → รอบหน้าลองใหม่")
                                            end
                                            gems = (after > 0) and after or gems
                                            acted = true
                                        else
                                            warn(string.format("[BOOST] ❌ ซื้อไม่ผ่าน %s (เพชร %d → %d) → ลองก้อนเล็กลง",
                                                nm, gems, after))
                                            gems = (after > 0) and after or gems
                                            task.wait(0.5)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end)
            if not okRun then warn("[BOOST] ⛔ error: " .. tostring(err)) end
            -- ทำอะไรไป → เช็คถี่ | ตรวจครบแล้วไม่ต้องทำ → พัก 5 นาที
            -- ⚠️ ข้อมูลยังไม่พร้อม → ห้ามพักยาว! (อยู่ lobby แค่ ~30 วิ พัก 5 นาที = ไม่ได้เช็คเลย)
            nextCheck = os.time() + (acted and (tonumber(VZo.BoostCheckInterval) or 15)
                or (evaluated and 300 or 8))
        end
    end
end)

if ({[MAIN_MENU_ID]=true,[LOBBY_ID]=true})[game.PlaceId] then return end

if not TitansFolder then
    TitansFolder = SafeGetTitansFolder()
end

local function safeClearTable(tbl)
    if type(tbl) == "table" then
        table.clear(tbl)
        return tbl
    end
    return {}
end

local objectivesCache = false
local objectivesCacheTime = 0
local OBJECTIVES_CACHE_DURATION = 0.05

local function isObjectivesActiveForCore()
    local now = tick()
    if now - objectivesCacheTime < OBJECTIVES_CACHE_DURATION then
        return objectivesCache
    end
    objectivesCacheTime = now
    
    local success, player = pcall(function()
        return game:GetService("Players").LocalPlayer
    end)
    if not success or not player then 
        objectivesCache = false
        return false 
    end
    
    local success2, playerGui = pcall(function()
        return player:FindFirstChild("PlayerGui")
    end)
    if not success2 or not playerGui then 
        objectivesCache = false
        return false 
    end
    
    local function IsActuallyVisible(gui)
        if not gui or not gui:IsA("GuiObject") then return false end
        if not gui.Visible then return false end
        local current = gui.Parent
        while current do
            if current:IsA("GuiObject") and not current.Visible then return false end
            if current:IsA("ScreenGui") and not current.Enabled then return false end
            current = current.Parent
        end
        return true
    end
    
    local success3, descendants = pcall(function()
        return playerGui:GetDescendants()
    end)
    if not success3 then 
        objectivesCache = false
        return false 
    end
    
    for _, v in ipairs(descendants) do
        if v.Name == "Objectives" then
            if IsActuallyVisible(v) then
                objectivesCache = true
                return true
            end
        end
    end
    objectivesCache = false
    return false
end

local slayCache = false
local slayCacheTime = 0
local SLAY_CACHE_DURATION = 0.05

local function isSlayObjectiveVisible()
    local now = tick()
    if now - slayCacheTime < SLAY_CACHE_DURATION then
        return slayCache
    end
    slayCacheTime = now
    
    local success, player = pcall(function()
        return game:GetService("Players").LocalPlayer
    end)
    if not success or not player then 
        slayCache = false
        return false 
    end
    
    local success2, targetGui = pcall(function()
        local gui = player.PlayerGui:FindFirstChild("Interface")
        if gui then
            gui = gui:FindFirstChild("HUD")
            if gui then
                gui = gui:FindFirstChild("Objectives")
                if gui then
                    gui = gui:FindFirstChild("Main")
                    if gui then
                        gui = gui:FindFirstChild("Slay")
                        return gui
                    end
                end
            end
        end
        return nil
    end)
    
    if success2 and targetGui and targetGui:IsA("TextLabel") then
        local visible = true
        local current = targetGui
        while current do
            if current:IsA("GuiObject") and not current.Visible then visible = false break end
            if current:IsA("ScreenGui") and not current.Enabled then visible = false break end
            current = current.Parent
        end
        if visible and targetGui.AbsoluteSize.X > 0 and targetGui.AbsoluteSize.Y > 0 then
            slayCache = true
            return true
        end
    end
    slayCache = false
    return false
end

local isShiganshinaBreachMission = false
local isProtectHQActive = false
local protectHQCompleted = false
local lastMissionCheck = 0
local protectHQCheckTimer = 0
local protectHQCheckInterval = 0.1

local function updateMissionInfo()
    local now = tick()
    if now - lastMissionCheck < 5 then return end
    lastMissionCheck = now
    
    pcall(function()
        local GET = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("GET")
        local data = GET:InvokeServer("Data", "Copy")
        if data and data.Map then
            local mapName = data.Map.Map or ""
            local objective = data.Map.Objective or ""
            if mapName == "Shiganshina" and objective == "Breach" then
                if not isShiganshinaBreachMission then
                    isShiganshinaBreachMission = true
                    Library:Notify("Shiganshina Breach mission detected - Slay check disabled until Protect_HQ appears", 4)
                end
            else
                if isShiganshinaBreachMission then
                    isShiganshinaBreachMission = false
                    isProtectHQActive = false
                    protectHQCompleted = false
                    Library:Notify("Not Shiganshina Breach - Returning to normal mode", 3)
                end
            end
        end
    end)
end

local function checkProtectHQ()
    if not isShiganshinaBreachMission then return end
    
    local now = tick()
    if now - protectHQCheckTimer < protectHQCheckInterval then return end
    protectHQCheckTimer = now
    
    local success, protect = pcall(function()
        local gui = Player.PlayerGui:FindFirstChild("Interface")
        if gui then
            gui = gui:FindFirstChild("HUD")
            if gui then
                gui = gui:FindFirstChild("Objectives")
                if gui then
                    gui = gui:FindFirstChild("Main")
                    if gui then
                        return gui:FindFirstChild("Protect_HQ")
                    end
                end
            end
        end
        return nil
    end)
    
    if success and protect and protect:IsA("TextLabel") and protect.Visible then
        if not isProtectHQActive then
            isProtectHQActive = true
            protectHQCompleted = false
            Library:Notify("Protect_HQ appeared - Slay check will be re-enabled after completing Protect_HQ", 3)
        end
        
        local text = protect.Text
        local current, max = text:match("(%d+)/(%d+)")
        if current and max then
            if tonumber(current) >= tonumber(max) and not protectHQCompleted then
                protectHQCompleted = true
                Library:Notify("Protect_HQ completed ("..current.."/"..max..") - Re-enabling Slay check", 3)
            end
        end
    else
        if isProtectHQActive and not protectHQCompleted then
            isProtectHQActive = false
        end
    end
end

task.spawn(function()
    while true do
        pcall(function()
            updateMissionInfo()
            checkProtectHQ()
        end)
        task.wait()
    end
end)

local BOSS_NAMES = {
    Attack_Titan = true, Armored_Titan = true, Female_Titan = true,
    Beast_Titan = true, Colossal_Titan = true, Warhammer_Titan = true,
    Jaw_Titan = true, Cart_Titan = true
}
local attackTitanSpawnTime = nil

local ActiveTitans = {}
local LastScan = 0
local SCAN_RATE = 0.03
local NapeCache = setmetatable({}, {__mode = "k"})

local LastTitanPosition = nil
local LastTitanHoverHeight = 120

local function IsTitanAlive(t)
    if not t then return false end
    local success, h = pcall(function()
        return t:FindFirstChildWhichIsA("Humanoid")
    end)
    return success and h and h.Health > 10
end

local function GetNape(t)
    if not t then return nil end
    local c = NapeCache[t]
    if c then return c end
    local success, hitboxes = pcall(function()
        return t:FindFirstChild("Hitboxes")
    end)
    if success and hitboxes then
        local success2, hit = pcall(function()
            return hitboxes:FindFirstChild("Hit")
        end)
        if success2 and hit then
            local success3, nape = pcall(function()
                return hit:FindFirstChild("Nape")
            end)
            if success3 and nape and nape:IsA("BasePart") then
                NapeCache[t] = nape
                return nape
            end
        end
    end
    return nil
end

local function ScanTitans()
    local now = tick()
    if now - LastScan < SCAN_RATE then return end
    LastScan = now
    
    local success, titansFolder = pcall(function()
        return workspace:FindFirstChild("Titans")
    end)
    if not success or not titansFolder then
        ActiveTitans = safeClearTable(ActiveTitans)
        return
    end
    
    ActiveTitans = safeClearTable(ActiveTitans)
    local attackFound = false
    
    local success2, children = pcall(function()
        return titansFolder:GetChildren()
    end)
    if not success2 then return end
    
    for i = 1, #children do
        local t = children[i]
        if t:IsA("Model") and IsTitanAlive(t) then
            local JaMe = t:FindFirstChild("JaMe")
            if JaMe then
                local collision = JaMe:FindFirstChild("Collision")
                if collision and not collision.CanCollide then              
                end
            end
            local nape = GetNape(t)
            if nape then
                local isBoss = BOSS_NAMES[t.Name] or false
                if t.Name == "Attack_Titan" then attackFound = true end
                table.insert(ActiveTitans, {titan = t, nape = nape, isBoss = isBoss, titanName = t.Name})
                LastTitanPosition = nape.Position
            end
        end
    end
    
    if attackFound then
        if not attackTitanSpawnTime then attackTitanSpawnTime = now end
    else
        attackTitanSpawnTime = nil
    end
end

local function GetBestTarget(hrpPos)
    if not hrpPos then return nil end
    if #ActiveTitans == 0 then return nil end
    
    local now = tick()
    local attackReady = true
    if attackTitanSpawnTime then
        attackReady = (now - attackTitanSpawnTime) >= 3
    end
    
    local bestBoss, bestBossDist = nil, math.huge
    local bestNormal, bestNormalDist = nil, math.huge
    
    for i = 1, #ActiveTitans do
        local entry = ActiveTitans[i]
        if entry.titanName == "Attack_Titan" and not attackReady then continue end
        local n = entry.nape
        if not n then continue end
        local dx = hrpPos.X - n.Position.X
        local dz = hrpPos.Z - n.Position.Z
        local distSq = dx*dx + dz*dz
        if entry.isBoss then
            if distSq < bestBossDist then bestBossDist = distSq; bestBoss = entry end
        else
            if distSq < bestNormalDist then bestNormalDist = distSq; bestNormal = entry end
        end
    end
    return bestBoss or bestNormal
end

local CharParts = {}
local CharRef = nil
local function NoclipOn()
    local success, char = pcall(function()
        return Player.Character
    end)
    if not success or not char then return end
    if char ~= CharRef then
        CharRef = char
        CharParts = {}
        local success2, descendants = pcall(function()
            return char:GetDescendants()
        end)
        if success2 then
            for i = 1, #descendants do
                local v = descendants[i]
                if v:IsA("BasePart") then
                    CharParts[#CharParts + 1] = v
                end
            end
        end
    end
    for i = 1, #CharParts do
        if CharParts[i] and CharParts[i].Parent then
            pcall(function()
                CharParts[i].CanCollide = false
            end)
        end
    end
end

local bodyPos = nil
local bodyGyro = nil

local function InitSmoothMovement(hrp)
    if not hrp then return end
    if not bodyPos or not bodyPos.Parent then
        if bodyPos then pcall(function() bodyPos:Destroy() end) end
        local success, newPos = pcall(function()
            local b = Instance.new("BodyPosition")
            b.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            b.P = 5000
            b.D = 1000
            b.Parent = hrp
            return b
        end)
        if success then bodyPos = newPos end
    end
    if not bodyGyro or not bodyGyro.Parent then
        if bodyGyro then pcall(function() bodyGyro:Destroy() end) end
        local success, newGyro = pcall(function()
            local g = Instance.new("BodyGyro")
            g.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
            g.P = 8000
            g.D = 1600
            g.Parent = hrp
            return g
        end)
        if success then bodyGyro = newGyro end
    end
end

CleanupSmoothMovement = function()
    if bodyPos then pcall(function() bodyPos:Destroy() end); bodyPos = nil end
    if bodyGyro then pcall(function() bodyGyro:Destroy() end); bodyGyro = nil end
end

local function MoveSmooth(hrp, targetPos, targetLookDir)
    if not hrp or not targetPos then return end
    InitSmoothMovement(hrp)
    if bodyPos then
        pcall(function() bodyPos.Position = targetPos end)
    end
    if bodyGyro then
        pcall(function()
            if targetLookDir then
                bodyGyro.CFrame = CFrame.lookAt(targetPos, targetLookDir)
            else
                bodyGyro.CFrame = CFrame.lookAt(targetPos, targetPos + Vector3.new(0, 0, -1))
            end
        end)
    end
end

local function MoveStableTeleport(hrp, targetPos)
    if not hrp or not targetPos then return end
    pcall(function()
        hrp.CFrame = CFrame.new(targetPos)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
    CleanupSmoothMovement()
end

local function HoverInPlace(hrp)
    if not hrp then return end
    NoclipOn()
    CleanupSmoothMovement()
    
    local targetY = IdleHoverY
    if LastTitanPosition then
        targetY = LastTitanPosition.Y + LastTitanHoverHeight
    end
    
    local currentY = hrp.Position.Y
    if math.abs(currentY - targetY) > 2 then
        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.new(0, (targetY - currentY) * 8, 0)
        end)
    else
        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = CFrame.new(hrp.Position.X, targetY, hrp.Position.Z)
        end)
    end
    pcall(function()
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
end

local CurrentEntry = nil
local isDead = false
local IdleHoverY = 80

local function IsRewardsUIVisible()
    local success, interface = pcall(function()
        return Player.PlayerGui:FindFirstChild("Interface")
    end)
    if success and interface then
        local success2, rewards = pcall(function()
            return interface:FindFirstChild("Rewards")
        end)
        if success2 and rewards and rewards.Visible then return true end
    end
    return false
end

local function OnDeath()
    isDead = true
    CurrentEntry = nil
    NapeCache = setmetatable({}, {__mode = "k"})
    ActiveTitans = safeClearTable(ActiveTitans)
    CharRef = nil
    CharParts = {}
    CleanupSmoothMovement()
end

local function OnSpawn(char)
    if not char then return end
    isDead = false
    CharRef = nil
    CleanupSmoothMovement()
    local success, hum = pcall(function()
        return char:FindFirstChildOfClass("Humanoid")
    end)
    if success and hum then
        pcall(function() hum.Died:Connect(OnDeath) end)
    end
end

if Player.Character then OnSpawn(Player.Character) end
Player.CharacterAdded:Connect(OnSpawn)

local FarmConn = nil
local SpearFarmConn = nil
local FARM_ATTACK_INTERVAL = VZC.Gap()   -- [CHICKEN] เดิม 0.05
local LastAttackTime = 0

local waveWaiting = false
local waveProgressCache = {current = nil, max = nil, text = nil, time = 0}
local WAVE_CACHE_DURATION = 0.05

local function getWaveProgress()
    local now = tick()
    if now - waveProgressCache.time < WAVE_CACHE_DURATION then
        return waveProgressCache.current, waveProgressCache.max, waveProgressCache.text
    end
    
    local success, player = pcall(function()
        return game:GetService("Players").LocalPlayer
    end)
    if not success or not player then return nil, nil, nil end
    
    local success2, defend = pcall(function()
        local gui = player.PlayerGui:FindFirstChild("Interface")
        if gui then
            gui = gui:FindFirstChild("HUD")
            if gui then
                gui = gui:FindFirstChild("Objectives")
                if gui then
                    gui = gui:FindFirstChild("Main")
                    if gui then
                        return gui:FindFirstChild("Defend")
                    end
                end
            end
        end
        return nil
    end)
    
    if success2 and defend and defend:IsA("TextLabel") and defend.Visible then
        local text = defend.Text
        local current, max = text:match("(%d+)/(%d+)")
        if current and max then
            waveProgressCache.current = tonumber(current)
            waveProgressCache.max = tonumber(max)
            waveProgressCache.text = text
            waveProgressCache.time = now
            return waveProgressCache.current, waveProgressCache.max, waveProgressCache.text
        end
    end
    waveProgressCache.current = nil
    waveProgressCache.max = nil
    waveProgressCache.text = nil
    waveProgressCache.time = now
    return nil, nil, nil
end

local reloadCache = false
local reloadCacheTime = 0
local RELOAD_CACHE_DURATION = 0.05

local function NeedReload()
    local now = tick()
    if now - reloadCacheTime < RELOAD_CACHE_DURATION then
        return reloadCache
    end
    reloadCacheTime = now
    
    local success, char = pcall(function()
        return workspace:FindFirstChild("Characters")
    end)
    if not success or not char then 
        reloadCache = false
        return false 
    end
    local success2, playerChar = pcall(function()
        return char:FindFirstChild(Player.Name)
    end)
    if not success2 or not playerChar then 
        reloadCache = false
        return false 
    end
    local success3, rig = pcall(function()
        return playerChar:FindFirstChild("Rig_" .. Player.Name)
    end)
    if not success3 or not rig then 
        reloadCache = false
        return false 
    end

    local success4, leftHand = pcall(function()
        return rig:FindFirstChild("LeftHand")
    end)
    local success5, rightHand = pcall(function()
        return rig:FindFirstChild("RightHand")
    end)

    if success4 and leftHand then
        local success6, blade = pcall(function()
            return leftHand:FindFirstChild("Blade_1")
        end)
        if success6 and blade and blade.Transparency == 1 then 
            reloadCache = true
            return true 
        end
    end

    if success5 and rightHand then
        local success7, blade = pcall(function()
            return rightHand:FindFirstChild("Blade_1")
        end)
        if success7 and blade and blade.Transparency == 1 then 
            reloadCache = true
            return true 
        end
    end

    reloadCache = false
    return false
end

local function GetTargets(limit)
    if #ActiveTitans == 0 then return {} end
    local success, hrp = pcall(function()
        local char = Player.Character
        if char then return char:FindFirstChild("HumanoidRootPart") end
        return nil
    end)
    if not success or not hrp then return {} end
    local pos = hrp.Position
    
    local sorted = {}
    -- [CHICKEN] ⭐ ยิงเฉพาะไททันที่ "บินถึงจริง" แล้วเท่านั้น
    --   เดิมยิงทุกตัวไม่สนระยะ → ถ้ายังบินไม่ถึง ดาเมจบัคตีไม่เข้า + เปลือง remote ฟรี
    local maxSq = VZC.Enabled and ((VZC.HitRange or 200) ^ 2) or math.huge   -- [CHICKEN] ปิดเมื่อ Enabled=false
    for i = 1, #ActiveTitans do
        local entry = ActiveTitans[i]
        local nape = entry.nape
        if nape then
            local dx = nape.Position.X - pos.X
            local dy = nape.Position.Y - pos.Y
            local dz = nape.Position.Z - pos.Z
            local distSq = dx*dx + dy*dy + dz*dz    -- ระยะ 3 มิติ (รวมความสูงที่ลอย)
            if distSq <= maxSq then
                sorted[#sorted + 1] = {entry = entry, dist = distSq}
            end
        end
    end
    table.sort(sorted, function(a,b) return a.dist < b.dist end)
    
    local result = {}
    local count = math.min(#sorted, limit or 9)
    for i = 1, count do
        result[i] = sorted[i].entry
    end
    return result
end

local function AttackAllTitans()
    if #ActiveTitans == 0 then return end
    if not isObjectivesActiveForCore() then return end
    if NeedReload() then return end

    local G = getgenv()
    local elapsed = (G.FarmStartTime and tick() - G.FarmStartTime) or 0
    local safe = elapsed >= (G.SafetyTime or 60)
    local killHits = VZC.Cap(G.KillHits or 1)   -- [CHICKEN]

    -- [CHICKEN] ยังบินไม่ถึงไททันตัวไหนเลย → ยังไม่ฟัน (เฉพาะโหมดไก่)
    if VZC.Enabled and #GetTargets(killHits) == 0 then return end
    -- [CHICKEN] กำลังเติม/สลับดาบอยู่ → หยุดฟัน (ฟันตอนดาบพัง = ดาเมจไม่เข้า + เปลือง remote)
    if getgenv().VenozBladeBusy then return end
    -- [CHICKEN] ⭐ ต้องบินถึง+นิ่งก่อนฟัน (เฉพาะโหมดไก่ — ปิดเมื่อ Enabled=false)
    if VZC.Enabled and not getgenv().VenozReady then return end

    -- [CHICKEN] 💨 DIVE IMPULSE — ให้ตัวละคร "มีความเร็วจริง" พุ่งเข้าหาคอก่อนฟัน
    --   วาร์ปแล้วล็อกนิ่ง = AssemblyLinearVelocity 0 → ถ้าเกมคิดดาเมจจากความเร็วจริงด้วย
    --   จะได้แค่ดาเมจน้อย (เช่น 359) แทนที่จะตัดคอตาย
    if VZC.Enabled and VZC.DiveImpulse ~= false then
        pcall(function()
            local ch = Player.Character
            local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
            local first = GetTargets(1)[1]
            if hrp and first and first.nape then
                local dir = first.nape.Position - hrp.Position
                if dir.Magnitude > 1 then
                    hrp.AssemblyLinearVelocity = dir.Unit * (VZC.DiveSpeed or 320)
                end
            end
        end)
    end

    if safe then
        SafeFire(POST, "Attacks", "Slash", true)
        local targets = GetTargets(killHits)
        for i = 1, #targets do
            local entry = targets[i]
            local nape = entry.nape
            if nape and nape.Parent then
                SafeFire(POST, "Hitboxes", "Register", nape, VZC.Vel(), VZC.TD())   -- [CHICKEN]
            end
        end
        return
    end

    if isShiganshinaBreachMission and not protectHQCompleted then
        SafeFire(POST, "Attacks", "Slash", true)
        local targets = GetTargets(killHits)
        for i = 1, #targets do
            local entry = targets[i]
            local nape = entry.nape
            if nape and nape.Parent then
                SafeFire(POST, "Hitboxes", "Register", nape, VZC.Vel(), VZC.TD())   -- [CHICKEN]
            end
        end
        return
    end

    local currentWave, maxWave = getWaveProgress()
    if currentWave and maxWave and currentWave < maxWave then
        local nearComplete = (currentWave >= maxWave - 2)
        if nearComplete then
            if elapsed < (G.SafetyTime or 60) then
                if not waveWaiting then waveWaiting = true end
                return
            else
                if waveWaiting then waveWaiting = false end
            end
        else
            waveWaiting = false
        end
    elseif currentWave and currentWave == maxWave then
        waveWaiting = false
    elseif not currentWave then
        waveWaiting = false
    end

    local slayVisible = isSlayObjectiveVisible()
    local stopAt = G.StopAtTitansLeft or 1
    local targets = GetTargets(killHits)

    if not slayVisible then
        SafeFire(POST, "Attacks", "Slash", true)
        for i = 1, #targets do
            local entry = targets[i]
            local nape = entry.nape
            if nape and nape.Parent then
                SafeFire(POST, "Hitboxes", "Register", nape, VZC.Vel(), VZC.TD())   -- [CHICKEN]
            end
        end
        return
    end

    if not safe and #ActiveTitans <= stopAt then return end

    SafeFire(POST, "Attacks", "Slash", true)
    for i = 1, #targets do
        local entry = targets[i]
        local nape = entry.nape
        if nape and nape.Parent then
            SafeFire(POST, "Hitboxes", "Register", nape, VZC.Vel(), VZC.TD())   -- [CHICKEN]
        end
    end
end

local function FarmUpdate()
    pcall(function()
        local G = getgenv()
        
        if not G.AutoFarmBlade then
            if G.Farm then G.Farm = false end
            return
        end
        
        if not G.Farm then return end
        
        if isDead then return end
        
        if NeedReload() then
            local char = Player.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then HoverInPlace(hrp) end
            end
            return
        end
        
        if IsRewardsUIVisible() then
            G.Farm = false
            pcall(function()
                if Options and Options.AutoFarmBlade then
                    Options.AutoFarmBlade:SetValue(false)
                end
            end)
            return
        end

        local char = Player.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then
            OnDeath()
            return
        end

        hrp.AssemblyAngularVelocity = Vector3.zero

        if hrp.Position.Y < -50 then
            hrp.CFrame = CFrame.new(hrp.Position.X, IdleHoverY, hrp.Position.Z)
            hrp.AssemblyLinearVelocity = Vector3.zero
            CleanupSmoothMovement()
            return
        end

        ScanTitans()

        local elapsed = (G.FarmStartTime and tick() - G.FarmStartTime) or 0
        if waveWaiting then
            if elapsed < (G.SafetyTime or 60) then
                HoverInPlace(hrp)
                return
            else
                waveWaiting = false
            end
        end

        if #ActiveTitans == 0 then
            CurrentEntry = nil
            HoverInPlace(hrp)
            return
        end

        LastTitanHoverHeight = G.HoverHeight or 120

        if not CurrentEntry or not IsTitanAlive(CurrentEntry.titan) then
            CurrentEntry = GetBestTarget(hrp.Position)
        end
        
        if not CurrentEntry then return end

        local nape = CurrentEntry.nape
        if not nape then
            CurrentEntry = nil
            return
        end
        
        LastTitanPosition = nape.Position

        local ty = nape.Position.Y + (G.HoverHeight or 120)
        local tp = Vector3.new(nape.Position.X, ty, nape.Position.Z)
        local lookDir = Vector3.new(nape.Position.X, ty, nape.Position.Z - 5)

        NoclipOn()

        if G.FarmMode == "Teleport" then
            MoveStableTeleport(hrp, tp)
        else
            MoveSmooth(hrp, tp, lookDir)
        end

        -- ⭐ [CHICKEN] ARRIVE + SETTLE GATE
        --   ต้องบินถึงจุดเหนือหัวไททันจริง (<= ArriveRadius) แล้วนิ่งครบ SettleTime
        --   ก่อนถึงจะเริ่มฟัน — กันเคส "ยังบินไม่ถึงแล้วตี" ที่ดาเมจไม่เข้า
        do
            local gg = getgenv()
            if not VZC.Enabled then gg.VenozReady = true end   -- [CHICKEN] ไม่ใช่โหมดไก่ = ฟันได้เลย
            local arriveR = VZC.ArriveRadius or 30
            local settleT = VZC.SettleTime or 1.5
            local dist = (hrp.Position - tp).Magnitude

            if gg._VZTarget ~= CurrentEntry then      -- เปลี่ยนเป้า → เริ่มนับใหม่
                gg._VZTarget = CurrentEntry
                gg._VZArriveAt = nil
                gg.VenozReady = false
            end

            if dist <= arriveR then
                if not gg._VZArriveAt then
                    gg._VZArriveAt = tick()
                    gg.VenozAction = "🛬 ถึงหัวไททันแล้ว — รอนิ่ง"
                end
                local held = tick() - gg._VZArriveAt
                gg.VenozReady = (held >= settleT)
                if gg.VenozReady then gg.VenozAction = "⚔️ ฟัน" end
            elseif dist > arriveR * 2 then            -- หลุดไกลจริง → รีเซ็ต
                gg._VZArriveAt = nil
                gg.VenozReady = false
                gg.VenozAction = string.format("🛫 บินไปหาไททัน (%d studs)", math.floor(dist))
            end
        end

        local now = tick()
        if now - LastAttackTime >= FARM_ATTACK_INTERVAL then
            LastAttackTime = now
            FARM_ATTACK_INTERVAL = VZC.Gap()   -- [CHICKEN] สุ่มช่องว่างรอบถัดไป

            -- [CHICKEN] 💥 บังคับ one-shot: ถ้าฟันเป้าเดิมซ้ำ = แปลว่ารอบก่อนไม่ตาย → เพิ่มแรง
            local gg2 = getgenv()
            if gg2.VenozReady and CurrentEntry then
                if gg2._VZHitTitan == CurrentEntry.titan then
                    gg2._VZHitN = (gg2._VZHitN or 1) + 1
                    if gg2._VZHitN >= 2 then
                        VZC.Escalate()
                        gg2._VZHitN = 1
                    end
                else
                    gg2._VZHitTitan = CurrentEntry.titan
                    gg2._VZHitN = 1
                end
            end

            AttackAllTitans()
        end
    end)
end

CreateFarmLoop = function()
    if FarmConn then
        pcall(function() FarmConn:Disconnect() end)
        FarmConn = nil
    end
    FarmConn = RunService.Heartbeat:Connect(FarmUpdate)
end

local SpearCurrentEntry = nil
local LastSpearAttackTime = 0
local SPEAR_ATTACK_INTERVAL = VZC.Gap(VZC.SpearInterval)   -- [CHICKEN] เดิม 0.1
local CurrentFirePower = 8
local EXPLODE_RADIUS = 0.14
getgenv().SpearFarm = getgenv().SpearFarm or false

local cachedSpearRefill = nil
local lastSpearRefillCheck = 0

local function FindRefillObject()
    local now = tick()
    if cachedSpearRefill and (now - lastSpearRefillCheck < 3) then
        if pcall(function() return cachedSpearRefill.Parent end) then
            return cachedSpearRefill
        end
    end
    lastSpearRefillCheck = now

    local paths = {
        "Climbable._Walls.Gate.GasTanks.Refill",
        "Climbable._Walls.Gate:GetChildren()[50].Refill",
        "Unclimbable.Props.HQ.GasTanks.Refill"
    }
    for _, path in ipairs(paths) do
        local success, obj = pcall(function()
            if path:find(":GetChildren") then
                local gate = workspace:FindFirstChild("Climbable") and workspace.Climbable:FindFirstChild("_Walls") and workspace.Climbable._Walls:FindFirstChild("Gate")
                if gate then
                    local children = gate:GetChildren()
                    if children[50] then return children[50]:FindFirstChild("Refill") end
                end
                return nil
            else
                local parts = {}
                for part in string.gmatch(path, "[^.]+") do table.insert(parts, part) end
                local obj = workspace
                for _, p in ipairs(parts) do obj = obj and obj:FindFirstChild(p) if not obj then break end end
                return obj
            end
        end)
        if success and obj then
            cachedSpearRefill = obj
            return obj
        end
    end
    local success, refill = pcall(function() return workspace:FindFirstChild("Refill", true) end)
    if success and refill then
        cachedSpearRefill = refill
        return refill
    end
    cachedSpearRefill = nil
    return nil
end

local function ReloadSpears()
    local refill = FindRefillObject()
    if refill then
        pcall(function() POST:FireServer("Attacks", "Reload", refill) end)
    end
    CurrentFirePower = 8
end

local function FireSpear()
    if CurrentFirePower <= 0 then
        ReloadSpears()
        task.wait(0.05)
        if CurrentFirePower == 0 then return end
    end
    pcall(function()
        GET:InvokeServer("Spears", "S_Fire", tostring(CurrentFirePower))
        CurrentFirePower = CurrentFirePower - 1
    end)
end

local function ThunderAOEAttack()
    local activeList = ActiveTitans
    local _cap = VZC.Cap(#activeList)   -- [CHICKEN] ไม่ระเบิดทุกตัวทั้งแมพ
    for i = 1, math.min(#activeList, _cap) do
        local entry = activeList[i]
        local nape = entry.nape
        if nape then
            pcall(function()
                POST:FireServer("Spears", "S_Explode", Vector3.new(nape.Position.X, nape.Position.Y, nape.Position.Z), EXPLODE_RADIUS)
            end)
        end
    end
end

local function ThunderAttackAllTitans()
    if #ActiveTitans == 0 then return end
    if not isObjectivesActiveForCore() then return end
    
    if getgenv().IsReloading or getgenv().IsRefilling then
        return
    end

    local G = getgenv()
    local elapsed = (G.FarmStartTime and tick() - G.FarmStartTime) or 0
    local safe = elapsed >= (G.SafetyTime or 60)

    if safe then
        FireSpear()
        ThunderAOEAttack()
        return
    end

    if isShiganshinaBreachMission and not protectHQCompleted then
        FireSpear()
        ThunderAOEAttack()
        return
    end

    local currentWave, maxWave = getWaveProgress()
    if currentWave and maxWave and currentWave < maxWave then
        local nearComplete = (currentWave >= maxWave - 2)
        if nearComplete then
            if elapsed < (G.SafetyTime or 60) then
                if not waveWaiting then
                    waveWaiting = true
                end
                return
            else
                if waveWaiting then
                    waveWaiting = false
                end
            end
        else
            waveWaiting = false
        end
    elseif currentWave and currentWave == maxWave then
        waveWaiting = false
    elseif not currentWave then
        waveWaiting = false
    end

    local slayVisible = isSlayObjectiveVisible()
    
    if not slayVisible then
        FireSpear()
        ThunderAOEAttack()
        return
    end
    
    local stopAt = G.StopAtTitansLeft or 1
    if not safe and #ActiveTitans <= stopAt then
        return
    end

    FireSpear()
    ThunderAOEAttack()
end

local function SpearFarmUpdate()
    pcall(function()
        local G = getgenv()
        
        if not G.AutoThunderSpear then
            if G.SpearFarm then G.SpearFarm = false end
            return
        end
        
        if not G.SpearFarm or isDead then return end
        
        if G.IsReloading or G.IsRefilling then return end
        
        if G.AutoThunderSpear and not G.SpearFarm then
            G.SpearFarm = true
            G.FarmStartTime = tick()
        end
        
        if IsRewardsUIVisible() then
            G.SpearFarm = false
            if Options and Options.AutoThunderSpearToggle then
                Options.AutoThunderSpearToggle:SetValue(false)
            end
            return
        end

        local char = Player.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then
            OnDeath()
            return
        end

        hrp.AssemblyAngularVelocity = Vector3.zero

        if hrp.Position.Y < -50 then
            hrp.CFrame = CFrame.new(hrp.Position.X, IdleHoverY, hrp.Position.Z)
            hrp.AssemblyLinearVelocity = Vector3.zero
            CleanupSmoothMovement()
            return
        end

        ScanTitans()

        if #ActiveTitans == 0 then
            SpearCurrentEntry = nil
            NoclipOn()
            CleanupSmoothMovement()
            local dy = IdleHoverY - hrp.Position.Y
            hrp.AssemblyLinearVelocity = Vector3.new(0, math.clamp(dy * 8, -80, 80), 0)
            return
        end

        if not SpearCurrentEntry or not IsTitanAlive(SpearCurrentEntry.titan) then
            SpearCurrentEntry = GetBestTarget(hrp.Position)
        end
        if not SpearCurrentEntry then return end

        local nape = SpearCurrentEntry.nape
        if not nape then
            SpearCurrentEntry = nil
            return
        end

        local hoverHeight = G.ThunderSpearHoverHeight or G.HoverHeight or 120
        local targetHeight = nape.Position.Y + hoverHeight
        local targetPos = Vector3.new(nape.Position.X, targetHeight, nape.Position.Z)
        local lookDir = Vector3.new(nape.Position.X, targetHeight, nape.Position.Z - 5)

        NoclipOn()

        local farmMode = G.ThunderSpearFarmMode or G.FarmMode or "Tween"
        if farmMode == "Teleport" then
            MoveStableTeleport(hrp, targetPos)
        else
            MoveSmooth(hrp, targetPos, lookDir)
        end

        -- ยิงเร็วขึ้น
        local now = tick()
        if now - LastSpearAttackTime >= SPEAR_ATTACK_INTERVAL then
            LastSpearAttackTime = now
            SPEAR_ATTACK_INTERVAL = VZC.Gap(VZC.SpearInterval)   -- [CHICKEN]
            ThunderAttackAllTitans()
        end
    end)
end

CreateSpearFarmLoop = function()
    if SpearFarmConn then
        pcall(function() SpearFarmConn:Disconnect() end)
        SpearFarmConn = nil
    end
    SpearFarmConn = RunService.Heartbeat:Connect(SpearFarmUpdate)
end

-- ===== สร้าง loop ตรวจสอบสถานะ (เร็วขึ้น) =====
task.spawn(function()
    while true do
        task.wait(0.03)
        local G = getgenv()
        if G.AutoFarmBlade then
            if not G.Farm then
                G.Farm = true
                G.FarmStartTime = tick()
                CurrentEntry = nil
                LastAttackTime = tick()
                if not FarmConn then
                    CreateFarmLoop()
                end
            end
        else
            if G.Farm then
                G.Farm = false
                CurrentEntry = nil
                CleanupSmoothMovement()
                if FarmConn then
                    FarmConn:Disconnect()
                    FarmConn = nil
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.03)
        local G = getgenv()
        if G.AutoThunderSpear then
            if not G.SpearFarm then
                G.SpearFarm = true
                G.FarmStartTime = tick()
                SpearCurrentEntry = nil
                LastSpearAttackTime = tick()
                if not SpearFarmConn then
                    CreateSpearFarmLoop()
                end
            end
        else
            if G.SpearFarm then
                G.SpearFarm = false
                SpearCurrentEntry = nil
                CleanupSmoothMovement()
                if SpearFarmConn then
                    SpearFarmConn:Disconnect()
                    SpearFarmConn = nil
                end
            end
        end
    end
end)

-- ===== loop เช็คและสร้างใหม่ =====
task.spawn(function()
    while task.wait(0.1) do
        local G = getgenv()
        if G.AutoFarmBlade and (not FarmConn or not FarmConn.Connected) then
            CreateFarmLoop()
        end
    end
end)

task.spawn(function()
    while task.wait(0.1) do
        local G = getgenv()
        if G.AutoThunderSpear and (not SpearFarmConn or not SpearFarmConn.Connected) then
            CreateSpearFarmLoop()
        end
    end
end)



if ({[MAIN_MENU_ID]=true,[LOBBY_ID]=true})[game.PlaceId] then return end

local SpearCurrentEntry = nil
local LastSpearAttackTime = 0
local SPEAR_ATTACK_INTERVAL = VZC.Gap(VZC.SpearInterval)   -- [CHICKEN] เดิม 0.2     local CurrentFirePower = 8
local EXPLODE_RADIUS = 0.14           
getgenv().SpearFarm = getgenv().SpearFarm or false

local cachedSpearRefill = nil
local lastSpearRefillCheck = 0

local function FindRefillObject()
    local now = tick()
    if cachedSpearRefill and (now - lastSpearRefillCheck < 3) then
        if pcall(function() return cachedSpearRefill.Parent end) then
            return cachedSpearRefill
        end
    end
    lastSpearRefillCheck = now

    local paths = {
        "Climbable._Walls.Gate.GasTanks.Refill",
        "Climbable._Walls.Gate:GetChildren()[50].Refill",
        "Unclimbable.Props.HQ.GasTanks.Refill"
    }
    for _, path in ipairs(paths) do
        local success, obj = pcall(function()
            if path:find(":GetChildren") then
                local gate = workspace:FindFirstChild("Climbable") and workspace.Climbable:FindFirstChild("_Walls") and workspace.Climbable._Walls:FindFirstChild("Gate")
                if gate then
                    local children = gate:GetChildren()
                    if children[50] then return children[50]:FindFirstChild("Refill") end
                end
                return nil
            else
                local parts = {}
                for part in string.gmatch(path, "[^.]+") do table.insert(parts, part) end
                local obj = workspace
                for _, p in ipairs(parts) do obj = obj and obj:FindFirstChild(p) if not obj then break end end
                return obj
            end
        end)
        if success and obj then
            cachedSpearRefill = obj
            return obj
        end
    end
    local success, refill = pcall(function() return workspace:FindFirstChild("Refill", true) end)
    if success and refill then
        cachedSpearRefill = refill
        return refill
    end
    cachedSpearRefill = nil
    return nil
end

local function ReloadSpears()
    local refill = FindRefillObject()
    if refill then
        pcall(function() POST:FireServer("Attacks", "Reload", refill) end)
    end
    CurrentFirePower = 8
end

local function FireSpear()
    if CurrentFirePower <= 0 then
        ReloadSpears()
        task.wait(0.15)           if CurrentFirePower == 0 then return end
    end
    pcall(function()
        GET:InvokeServer("Spears", "S_Fire", tostring(CurrentFirePower))
        CurrentFirePower = CurrentFirePower - 1
    end)
end

local function ThunderAOEAttack()
        local activeList = ActiveTitans
    local _n, _cap = 0, VZC.Cap(#activeList)   -- [CHICKEN] ไม่ระเบิดทุกตัวทั้งแมพ
    for _, entry in ipairs(activeList) do
        _n = _n + 1
        if _n > _cap then break end
        local nape = entry.nape
        if nape then
            pcall(function()
                POST:FireServer("Spears", "S_Explode", Vector3.new(nape.Position.X, nape.Position.Y, nape.Position.Z), EXPLODE_RADIUS)
            end)
        end
    end
end

local function ThunderAttackAllTitans()
    if #ActiveTitans == 0 then return end
    if not isObjectivesActiveForCore() then return end
    
    if getgenv().IsReloading or getgenv().IsRefilling then
        return
    end

    local G = getgenv()
    local elapsed = (G.FarmStartTime and tick() - G.FarmStartTime) or 0
    local safe = elapsed >= (G.SafetyTime or 60)

    if safe then
        FireSpear()
        ThunderAOEAttack()
        return
    end

    if isShiganshinaBreachMission and not protectHQCompleted then
        FireSpear()
        ThunderAOEAttack()
        return
    end

    local currentWave, maxWave = getWaveProgress()
    if currentWave and maxWave and currentWave < maxWave then
        local nearComplete = (currentWave >= maxWave - 2)
        if nearComplete then
            if elapsed < (G.SafetyTime or 60) then
                if not waveWaiting then
                    waveWaiting = true
                    Library:Notify(string.format("Wave nearly complete (%d/%d), waiting for safety timer (%.0f/%.0f sec)", currentWave, maxWave, elapsed, G.SafetyTime or 60), 3)
                end
                return
            else
                if waveWaiting then
                    waveWaiting = false
                    Library:Notify("Safety timer reached, resuming attack!", 2)
                end
            end
        else
            waveWaiting = false
        end
    elseif currentWave and currentWave == maxWave then
        waveWaiting = false
    elseif not currentWave then
        waveWaiting = false
    end

    local slayVisible = isSlayObjectiveVisible()
    
    if not slayVisible then
        FireSpear()
        ThunderAOEAttack()
        return
    end
    
    local stopAt = G.StopAtTitansLeft or 1
    if not safe and #ActiveTitans <= stopAt then
        return
    end

    FireSpear()
    ThunderAOEAttack()
end

local function SpearFarmUpdate()
    pcall(function()
        local G = getgenv()
        
        if not G.AutoThunderSpear then
            if G.SpearFarm then G.SpearFarm = false end
            return
        end
        
        if not G.SpearFarm or isDead then return end
        
        if G.IsReloading or G.IsRefilling then return end
        
        if G.AutoThunderSpear and not G.SpearFarm then
            G.SpearFarm = true
            G.FarmStartTime = tick()
        end
        
        if IsRewardsUIVisible() then
            G.SpearFarm = false
            if Options and Options.AutoThunderSpearToggle then
                Options.AutoThunderSpearToggle:SetValue(false)
            end
            return
        end

        local char = Player.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then
            OnDeath()
            return
        end

        hrp.AssemblyAngularVelocity = Vector3.zero

        if hrp.Position.Y < -50 then
            hrp.CFrame = CFrame.new(hrp.Position.X, IdleHoverY, hrp.Position.Z)
            hrp.AssemblyLinearVelocity = Vector3.zero
            CleanupSmoothMovement()
            return
        end

        ScanTitans()

        if #ActiveTitans == 0 then
            SpearCurrentEntry = nil
            NoclipOn()
            CleanupSmoothMovement()
            local dy = IdleHoverY - hrp.Position.Y
            hrp.AssemblyLinearVelocity = Vector3.new(0, math.clamp(dy * 5, -50, 50), 0)
            return
        end

        if not SpearCurrentEntry or not IsTitanAlive(SpearCurrentEntry.titan) then
            SpearCurrentEntry = GetBestTarget(hrp.Position)
        end
        if not SpearCurrentEntry then return end

        local nape = SpearCurrentEntry.nape
        if not nape then
            SpearCurrentEntry = nil
            return
        end

        local hoverHeight = G.ThunderSpearHoverHeight or G.HoverHeight or 120
        local hoverSpeed = G.ThunderSpearHoverSpeed or G.HoverSpeed or 120
        local targetHeight = nape.Position.Y + hoverHeight
        local targetPos = Vector3.new(nape.Position.X, targetHeight, nape.Position.Z)
        local lookDir = Vector3.new(nape.Position.X, targetHeight, nape.Position.Z - 5)

        NoclipOn()

        local farmMode = G.ThunderSpearFarmMode or G.FarmMode or "Tween"
        if farmMode == "Teleport" then
            MoveStableTeleport(hrp, targetPos)
        else
            MoveSmooth(hrp, targetPos, lookDir)
        end

        local now = tick()
        if now - LastSpearAttackTime >= SPEAR_ATTACK_INTERVAL then
            LastSpearAttackTime = now
            SPEAR_ATTACK_INTERVAL = VZC.Gap(VZC.SpearInterval)   -- [CHICKEN]
            ThunderAttackAllTitans()
        end
    end)
end

local SpearFarmConn = nil
local function CreateSpearFarmLoop()
    if SpearFarmConn then SpearFarmConn:Disconnect() end
    SpearFarmConn = RunService.Heartbeat:Connect(SpearFarmUpdate)
end
CreateSpearFarmLoop()

task.spawn(function()
    while true do
        task.wait(0.1)
        local G = getgenv()
        if G.AutoThunderSpear then
            if not G.SpearFarm then
                G.SpearFarm = true
                G.FarmStartTime = tick()
                SpearCurrentEntry = nil
                LastSpearAttackTime = tick()
            end
        else
            if G.SpearFarm then
                G.SpearFarm = false
                SpearCurrentEntry = nil
                CleanupSmoothMovement()
            end
        end
    end
end)

task.spawn(function()
    while task.wait(1) do           if not SpearFarmConn or not SpearFarmConn.Connected then
            CreateSpearFarmLoop()
        end
    end
end)


-- ═══════════════════════════════════════════════════════════════
-- 🔁 RETRY — กดครั้งเดียว หลังรอให้ทุกอย่างนิ่ง 3 วิ
-- ═══════════════════════════════════════════════════════════════
--  ⚠️ RETRY เป็นปุ่ม TOGGLE (บอทเก่าจดเตือนไว้แล้ว)
--     กดซ้ำเร็วเกิน = ครั้งที่ 2 ไปยกเลิกครั้งที่ 1 → "กดแล้วไม่ติด"
--     และ 15 ครั้ง/22 วิ = สัญญาณผิดธรรมชาติ → เสี่ยง shadow-ban
--  ✅ กติกาใหม่: Rewards โผล่ → รอ 3 วิ → กด 1 ครั้ง → จบ ไม่กดซ้ำอีกเลย
--     กันค้าง: ถ้ากดแล้วผ่านไป 25 วิยังค้างหน้าเดิม → กด LEAVE 1 ครั้ง
--     (LEAVE ปลอดภัยกว่า เพราะกลับ lobby แล้ว AutoMission พาเข้าด่านใหม่เอง)
-- ═══════════════════════════════════════════════════════════════
if Tabs.AutoFarm then
    task.spawn(function()
        local SETTLE = 3      -- รอกี่วิหลังหน้า Rewards โผล่ ค่อยกด
        local GIVEUP = 25     -- กดแล้วยังค้างกี่วิ → ออกจากด่านแทน

        local shownAt, pressedAt, closedAt = 0, 0, 0
        local pressed, bailed = false, false
        local LastState = nil

        local function IsActuallyVisible(gui)
            if not gui or not gui.Visible then return false end
            local current = gui.Parent
            while current and current ~= game do
                if current:IsA("GuiObject") and not current.Visible then return false end
                if current:IsA("ScreenGui") and not current.Enabled then return false end
                current = current.Parent
            end
            return true
        end

        local function reset()
            LastState = nil
            shownAt, pressedAt, closedAt = 0, 0, 0
            pressed, bailed = false, false
        end

        while true do
            task.wait(0.3)

            if not getgenv().StartRejoin then reset() continue end

            local player = game:GetService("Players").LocalPlayer
            if not player then reset() continue end

            local interface = player.PlayerGui:FindFirstChild("Interface")
            if not interface then reset() continue end

            local rewards = interface:FindFirstChild("Rewards")
            if not rewards then reset() continue end

            local ok, retry = pcall(function()
                return rewards.Main.Info.Main.Buttons.Retry
            end)
            if not ok or not retry then reset() continue end

            local isOpen = IsActuallyVisible(retry)
            local currentState = isOpen and "open" or "close"

            -- 🆕 หน้า Rewards เพิ่งโผล่ → เริ่มจับเวลา
            --    ⚠️ ถ้าปุ่มแค่ "กระพริบ" (ปิดแวบเดียวแล้วเปิดใหม่) ห้ามรีเซ็ตนาฬิกา
            --       ไม่งั้นตัวนับ 3 วิจะถูกรีตลอด = ไม่ได้กดสักที = ค้างยาว
            --       นับเป็นด่านใหม่ต่อเมื่อปิดไปแล้วเกิน 5 วิเท่านั้น
            if currentState == "open" and LastState ~= "open" then
                local freshRound = (shownAt == 0) or (closedAt > 0 and tick() - closedAt > 5)
                if freshRound then
                    shownAt   = tick()
                    pressedAt = 0
                    pressed   = false
                    bailed    = false
                    print("[RETRY] 👀 เจอหน้าจบด่าน → รอ " .. SETTLE .. " วิให้นิ่งก่อนค่อยกด")
                end
            elseif currentState == "close" and LastState == "open" then
                closedAt = tick()
            end
            LastState = currentState

            if not isOpen then continue end

            -- ✅ ติดแล้ว → เลิกยุ่ง
            local txt = VenozBtnText(retry)
            if txt:find("STARTING") or txt:find("1/1") then
                if pressed then print("[RETRY] ✅ ติดแล้ว → " .. txt) end
                pressed = true
                continue
            end

            if not pressed then
                -- ⏳ ยังไม่ครบ 3 วิ → รอ (ห้ามกดเร็ว ปุ่มมันเป็น toggle)
                if tick() - shownAt < SETTLE then continue end

                pressed   = true
                pressedAt = tick()
                VenozPress(retry)
                print("[RETRY] 🔁 กด RETRY ครั้งเดียว (" .. txt .. ")")
            else
                -- 🚪 กดไปแล้วแต่ยังค้าง → ออกจากด่านแทน (ไม่กด RETRY ซ้ำ)
                if bailed then continue end
                if pressedAt == 0 or tick() - pressedAt < GIVEUP then continue end

                bailed = true
                warn("[RETRY] ⛔ กดแล้วไม่ติดใน " .. GIVEUP .. " วิ → ออกจากด่านแทน (กันค้าง)")
                local lv = retry.Parent:FindFirstChild("Leave_2")
                    or retry.Parent:FindFirstChild("Leave")
                if lv then VenozPress(lv) end
                task.wait(5)
            end
        end
    end)
end


getgenv().AutoReloadBlade = false

task.spawn(function()
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local COOLDOWN_REFILL = 1.5
    local COOLDOWN_R_PRESS = 1
    local FORCE_RELOAD_LOOP_DELAY = 0.1
    local FORCE_RELOAD_MAX_DURATION = 5

    local lastRefillTime = 0
    local lastRPressTime = 0

    local validRefills = {}
    local lastCacheRefresh = 0
    local CACHE_REFRESH_INTERVAL = 30

    local function getRefillIfExists(pathFunc)
        local success, obj = pcall(pathFunc)
        if success and obj and obj:IsA("BasePart") then
            return obj
        end
        return nil
    end

    local refillPathFunctions = {
        function() return workspace:FindFirstChild("Unclimbable") and workspace.Unclimbable:FindFirstChild("Props") and workspace.Unclimbable.Props:FindFirstChild("HQ") and workspace.Unclimbable.Props.HQ:GetChildren()[224] and workspace.Unclimbable.Props.HQ:GetChildren()[224].Refill end,
        function() return workspace:FindFirstChild("Unclimbable") and workspace.Unclimbable:FindFirstChild("Props") and workspace.Unclimbable.Props:FindFirstChild("HQ") and workspace.Unclimbable.Props.HQ:GetChildren()[274] and workspace.Unclimbable.Props.HQ:GetChildren()[274].Refill end,
        function() return workspace:FindFirstChild("Unclimbable") and workspace.Unclimbable:FindFirstChild("Props") and workspace.Unclimbable.Props:FindFirstChild("HQ") and workspace.Unclimbable.Props.HQ:GetChildren()[276] and workspace.Unclimbable.Props.HQ:GetChildren()[276].Refill end,
        function() return workspace:FindFirstChild("Unclimbable") and workspace.Unclimbable:FindFirstChild("Props") and workspace.Unclimbable.Props:FindFirstChild("HQ") and workspace.Unclimbable.Props.HQ:GetChildren()[128] and workspace.Unclimbable.Props.HQ:GetChildren()[128].Refill end,
        function() return workspace:FindFirstChild("Unclimbable") and workspace.Unclimbable:FindFirstChild("Props") and workspace.Unclimbable.Props:FindFirstChild("HQ") and workspace.Unclimbable.Props.HQ:GetChildren()[167] and workspace.Unclimbable.Props.HQ:GetChildren()[167].Refill end,
        function() return workspace:FindFirstChild("Climbable") and workspace.Climbable:FindFirstChild("_Walls") and workspace.Climbable._Walls:FindFirstChild("Gate") and workspace.Climbable._Walls.Gate:GetChildren()[50] and workspace.Climbable._Walls.Gate:GetChildren()[50].Refill end,
        function() return workspace:FindFirstChild("Unclimbable") and workspace.Unclimbable:FindFirstChild("Camps") and workspace.Unclimbable.Camps:FindFirstChild("Camp") and workspace.Unclimbable.Camps.Camp:GetChildren()[55] and workspace.Unclimbable.Camps.Camp:GetChildren()[55].Refill end,
        function() return workspace:FindFirstChild("Unclimbable") and workspace.Unclimbable:FindFirstChild("World") and workspace.Unclimbable.World:FindFirstChild("Buildings") and workspace.Unclimbable.World.Buildings:FindFirstChild("Hanger") and workspace.Unclimbable.World.Buildings.Hanger:GetChildren()[19] and workspace.Unclimbable.World.Buildings.Hanger:GetChildren()[19].Refill end,
        function() return workspace:FindFirstChild("Unclimbable") and workspace.Unclimbable:FindFirstChild("Objective") and workspace.Unclimbable.Objective:FindFirstChild("Waves") and workspace.Unclimbable.Objective.Waves:GetChildren()[281] and workspace.Unclimbable.Objective.Waves:GetChildren()[281].Refill end,
    }

    local function refreshRefillCache()
        local newCache = {}
        for _, pathFunc in ipairs(refillPathFunctions) do
            local ref = getRefillIfExists(pathFunc)
            if ref then
                table.insert(newCache, ref)
            end
        end
        if #newCache > 0 then
            validRefills = newCache
        end
        lastCacheRefresh = tick()
    end

    refreshRefillCache()

    task.spawn(function()
        while true do
            task.wait(CACHE_REFRESH_INTERVAL)
            if getgenv().AutoReloadBlade then
                refreshRefillCache()
            end
        end
    end)

    local refillIndex = 1
    local function PerformRefill()
        local now = tick()
        if now - lastRefillTime < COOLDOWN_REFILL then
            return false
        end

        if #validRefills == 0 then
            refreshRefillCache()
            if #validRefills == 0 then
                return false
            end
        end

        lastRefillTime = now

        getgenv().IsRefilling = true

        local target = validRefills[refillIndex]
        refillIndex = (refillIndex % #validRefills) + 1

        pcall(function()
            local POST = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("POST")
            POST:FireServer("Attacks", "Reload", target)
        end)

        task.wait(1.5)
        getgenv().IsRefilling = false
        return true
    end

    local function PressR()
        local now = tick()
        if now - lastRPressTime < COOLDOWN_R_PRESS then
            return
        end
        lastRPressTime = now

        getgenv().IsReloading = true

        pcall(function()
            local VIM = game:GetService("VirtualInputManager")
            VIM:SendKeyEvent(true, Enum.KeyCode.R, false, game)
            task.wait(0.02)
            VIM:SendKeyEvent(false, Enum.KeyCode.R, false, game)
        end)

                task.wait(0.3)

                if getgenv().AutoReloadBlade and NeedReload() then
            local startLoop = tick()
            while getgenv().AutoReloadBlade and NeedReload() and (tick() - startLoop < FORCE_RELOAD_MAX_DURATION) do
                pcall(function()
                    local GET = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("GET")
                    GET:InvokeServer("Blades", "Reload")
                end)
                task.wait(FORCE_RELOAD_LOOP_DELAY)
            end
        end

        task.wait(0.2)
        getgenv().IsReloading = false
    end

    local function NeedReload()
        local char = workspace:FindFirstChild("Characters")
        if not char then return false end
        local playerChar = char:FindFirstChild(LocalPlayer.Name)
        if not playerChar then return false end
        local rig = playerChar:FindFirstChild("Rig_" .. LocalPlayer.Name)
        if not rig then return false end

        local leftHand = rig:FindFirstChild("LeftHand")
        local rightHand = rig:FindFirstChild("RightHand")

        if leftHand then
            local blade = leftHand:FindFirstChild("Blade_1")
            if blade and blade.Transparency == 1 then return true end
        end

        if rightHand then
            local blade = rightHand:FindFirstChild("Blade_1")
            if blade and blade.Transparency == 1 then return true end
        end

        return false
    end

    local function isZeroThree()
        local success, text = pcall(function()
            local sets = LocalPlayer.PlayerGui.Interface.HUD.Main.Top["7"].Blades.Sets
            if sets and sets:IsA("TextLabel") then
                return sets.Text
            end
            return ""
        end)
        if success then
            local clean = text:gsub("%s+", "")
            return clean == "0/3"
        end
        return false
    end

    while true do
        if getgenv().AutoReloadBlade then
            local needReload = NeedReload()
            local zeroThree = isZeroThree()

            if needReload and zeroThree then
                PerformRefill()
                task.wait(0.5)
            elseif needReload then
                PressR()
                task.wait(0.5)
            end
        end
        task.wait(0.1)
    end
end)
-- 🗑️ [ตัดออก] 📡 Discord Webhook — ไม่ได้ใช้ (เราใช้ Horst)  (เดิม 641 บรรทัด)
if IsIngameLobby() and Tabs.Webhook then
    local descGroup = Tabs.Webhook:AddRightGroupbox("Set Description")

        local function formatNumber(n)
        if type(n) ~= "number" then return "0" end
        return tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    end

        local function getThaiTime()
        local utcHour = tonumber(os.date("!%H"))
        local utcMin  = tonumber(os.date("!%M"))
        local thaiHour = (utcHour + 7) % 24
        return string.format("%02d:%02d", thaiHour, utcMin)
    end

        local statsFields = {
        "Level", "Prestige", "Slot", "Gold", "Gems", "Shards", "Spins", "Time"
    }
    local selectedStats = {
        ["Level"] = true,
        ["Prestige"] = true,
        ["Slot"] = true,
        ["Gold"] = true,
        ["Gems"] = true,
        ["Shards"] = true,
        ["Spins"] = true,
        ["Time"] = true,
    }

        local itemsFields = {
        "Memory Scroll", "Emperor's Key", "Female Serum", "Attack Serum", "Armored Serum"
    }
    local selectedItems = {
        ["Memory Scroll"] = true,
        ["Emperor's Key"] = true,
        ["Female Serum"] = true,
        ["Attack Serum"] = true,
        ["Armored Serum"] = true,
    }

        local cosmeticsFields = {
        "Angel's Halo", "Kitsune Ribbon", "Radiant Headband", "Blood Vial", "Kitsune Mask"
    }
    local selectedCosmetics = {
        ["Angel's Halo"] = true,
        ["Kitsune Ribbon"] = true,
        ["Radiant Headband"] = true,
        ["Blood Vial"] = true,
        ["Kitsune Mask"] = true,
    }

    descGroup:AddDropdown("DescTypeDropdown", {
        Text = "Description Type",
        Values = {"Horst"},
        Default = "Horst",
        Multi = false,
        Callback = function() end
    })

    descGroup:AddDivider()

    descGroup:AddDropdown("DescStatsDropdown", {
        Text = "Stats to include",
        Values = statsFields,
        Default = selectedStats,
        Multi = true,
        Callback = function(v) selectedStats = v end
    })

    descGroup:AddDivider()

    descGroup:AddDropdown("DescItemsDropdown", {
        Text = "Items to include",
        Values = itemsFields,
        Default = selectedItems,
        Multi = true,
        Callback = function(v) selectedItems = v end
    })

    descGroup:AddDivider()

    descGroup:AddDropdown("DescCosmeticsDropdown", {
        Text = "Cosmetics to include",
        Values = cosmeticsFields,
        Default = selectedCosmetics,
        Multi = true,
        Callback = function(v) selectedCosmetics = v end
    })

    descGroup:AddDivider()

    descGroup:AddToggle("SetDescToggle", {
        Text = "Apply Description (once, after 1s)",
        Default = false,
        Callback = function(v)
            if not v then return end

            task.spawn(function()
                task.wait(1)

                local success, data = pcall(function()
                    return GET:InvokeServer("Data", "Copy")
                end)

                if success and data and data.Slots then
                    local currentSlot = data.Current_Slot or "A"
                    local slotData = data.Slots[currentSlot]

                    if slotData then
                                                local valueMap = {}
                        
                        valueMap.Level = (slotData.Progression and slotData.Progression.Level) or 0
                        valueMap.Prestige = (slotData.Progression and slotData.Progression.Prestige) or 0
                        valueMap.Slot = currentSlot
                        valueMap.Gold = (slotData.Currency and slotData.Currency.Gold) or 0
                        valueMap.Gems = (slotData.Currency and slotData.Currency.Gems) or 0
                        valueMap.Shards = (slotData.Currency and slotData.Currency.Shards) or 0
                        valueMap.Spins = data.Spins or 0
                        valueMap.Time = getThaiTime()

                        local items = (slotData.Inventory and slotData.Inventory.Items) or {}
                        for _, field in ipairs(itemsFields) do
                            valueMap[field] = items[field] or 0
                        end

                        local cosmetics = (slotData.Inventory and slotData.Inventory.Cosmetics) or {}
                        for _, field in ipairs(cosmeticsFields) do
                            valueMap[field] = cosmetics[field] or 0
                        end

                                                local parts = {}

                                                for _, field in ipairs(statsFields) do
                            if selectedStats[field] and valueMap[field] ~= nil then
                                local val = valueMap[field]
                                if field ~= "Slot" and field ~= "Time" then
                                    val = formatNumber(val)
                                end
                                table.insert(parts, string.format("%s: %s", field, val))
                            end
                        end

                        for _, field in ipairs(itemsFields) do
                            if selectedItems[field] and valueMap[field] ~= nil and valueMap[field] > 0 then
                                local val = valueMap[field]
                                val = formatNumber(val)
                                table.insert(parts, string.format("%s: %s", field, val))
                            end
                        end

                        for _, field in ipairs(cosmeticsFields) do
                            if selectedCosmetics[field] and valueMap[field] ~= nil and valueMap[field] > 0 then
                                local val = valueMap[field]
                                val = formatNumber(val)
                                table.insert(parts, string.format("%s: %s", field, val))
                            end
                        end

                                                local description = table.concat(parts, "  ")

                        if _G and _G.Horst_SetDescription then
                            _G.Horst_SetDescription(description)
                        end
                    end
                end

                pcall(function()
                    if Options and Options.SetDescToggle then
                        Options.SetDescToggle:SetValue(false)
                    end
                end)
            end)
        end
    })
end

if Tabs.AutoFarm then
    local MiscGroup = Tabs.AutoFarm:AddRightGroupbox("Skip Cutscene")

    local skipEnabled = false
    local skipRunning = false

    local Players = game:GetService("Players")
    local GuiService = game:GetService("GuiService")
    local VirtualInputManager = game:GetService("VirtualInputManager")
    local lp = Players.LocalPlayer

    local CLICK_DELAY = 1.0

    local function clickSkipButton()
        local playerGui = lp:FindFirstChild("PlayerGui")
        if not playerGui then return false end

        local interface = playerGui:FindFirstChild("Interface")
        if not interface then return false end

        local skipFrame = interface:FindFirstChild("Skip")
        if not skipFrame or not skipFrame.Visible then return false end

        local interactBtn = skipFrame:FindFirstChild("Interact")
        if not interactBtn or not interactBtn.Visible then return false end

        if GuiService.MenuIsOpen then
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Escape, false, game)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Escape, false, game)
            task.wait(0.05)
        end

        GuiService.SelectedObject = interactBtn
        task.wait(0.02)
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        task.wait(0.02)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
        task.wait(0.02)
        GuiService.SelectedObject = nil

        return true
    end

    task.spawn(function()
        local detectedTime = 0
        local hasClicked = false

        while true do
            task.wait(0.1)

            if not skipEnabled then
                detectedTime = 0
                hasClicked = false
                continue
            end

            local interface = lp.PlayerGui:FindFirstChild("Interface")
            local skip = interface and interface:FindFirstChild("Skip")

            if skip and skip.Visible then
                local interactBtn = skip:FindFirstChild("Interact")
                if interactBtn and interactBtn.Visible then
                    if not hasClicked then
                        if detectedTime == 0 then
                            detectedTime = tick()
                        elseif tick() - detectedTime >= CLICK_DELAY then
                            clickSkipButton()
                            hasClicked = true
                            detectedTime = 0
                        end
                    end
                else
                    detectedTime = 0
                    hasClicked = false
                end
            else
                detectedTime = 0
                hasClicked = false
            end
        end
    end)

    MiscGroup:AddToggle("SkipCutSceneToggle", {
        Text = "Skip Cut Scene",
        Default = false,
        Callback = function(v)
            skipEnabled = v
            if not v then
                skipRunning = false
            end
        end
    })

    MiscGroup:AddToggle("SkipForceToggle", {
        Text = "Skip Fixed",
        Default = false,
        Callback = function(v)
            if v then
                task.spawn(function()
                    local ReplicatedStorage = game:GetService("ReplicatedStorage")
                    local GET = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("GET")
                    local POST = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("POST")

                    pcall(function()
                        GET:InvokeServer("Functions", "Loaded", "Add")
                    end)

                    local function GetNil(Name, DebugId)
                        for _, Object in getnilinstances() do
                            if Object.Name == Name and Object:GetDebugId() == DebugId then
                                return Object
                            end
                        end
                    end

                    local startObj = GetNil("Start", "1_39502")
                    if startObj then
                        pcall(function()
                            POST:FireServer("Functions", "Finished", startObj)
                        end)
                    end

                    if Options and Options.SkipForceToggle then
                        Options.SkipForceToggle:SetValue(false)
                    end
                end)
            end
        end
    })
end



if Tabs.AutoFarm then
    local SpearGroup = Tabs.AutoFarm:AddRightGroupbox("Auto Spear Quest")
    
    local spearQuestEnabled = false
    local spearQuestRunning = false
    
        local GET = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("GET")
    
        local function callSpearQuestUpdate()
        for i = 1, 6 do
            if not spearQuestEnabled then break end
            local args = {"Quests", "Update_Spear_Towers", true}
            pcall(function()
                GET:InvokeServer(unpack(args))
            end)
            task.wait(0.2)
        end
    end
    
    SpearGroup:AddToggle("AutoSpearQuestToggle", {
        Text="Auto Spear Quest",
        Default=false,
        Callback=function(v)
            spearQuestEnabled = v
            if v and not spearQuestRunning then
                spearQuestRunning = true
                task.spawn(function()
                                        callSpearQuestUpdate()
                    
                                        repeat task.wait() until game.Players.LocalPlayer.Character
                    local hrp = game.Players.LocalPlayer.Character:WaitForChild("HumanoidRootPart")
                    
                    local Unclimbable = workspace:FindFirstChild("Unclimbable")
                    if Unclimbable then
                        local baseCircle = Unclimbable:FindFirstChild("Supplies_Circle")
                        local baseHitbox = baseCircle and baseCircle:FindFirstChild("Hitbox")
                        
                        for lap = 1, 3 do
                            if not spearQuestEnabled then break end
                            
                            local supplies = {}
                            for _, obj in ipairs(Unclimbable:GetChildren()) do
                                if obj.Name:find("ThunderSpear_Supplies") then
                                    table.insert(supplies, obj)
                                end
                            end
                            
                            for _, supply in ipairs(supplies) do
                                if not spearQuestEnabled then break end
                                
                                local hitbox = supply:FindFirstChild("Hitbox")
                                if hitbox and hitbox.Parent then
                                    hrp.CFrame = hitbox.CFrame
                                    hrp.Velocity = Vector3.zero
                                    hrp.RotVelocity = Vector3.zero
                                    task.wait(0.5)
                                end
                                
                                if baseHitbox and baseHitbox.Parent then
                                    hrp.CFrame = baseHitbox.CFrame
                                    hrp.Velocity = Vector3.zero
                                    hrp.RotVelocity = Vector3.zero
                                    task.wait(0.5)
                                end
                            end
                        end
                    end
                    
                    spearQuestRunning = false
                    if spearQuestEnabled then
                        spearQuestEnabled = false
                        pcall(function()
                            SpearGroup:GetToggle("AutoSpearQuestToggle"):SetValue(false)
                        end)
                    end
                end)
            else
                spearQuestRunning = false
            end
        end
    })
end

-- ═══════════════════════════════════════════════════════════════
-- 🚦 โหลดครบแล้ว — ปลด auto-pilot ให้เริ่มสั่งงานได้
-- ═══════════════════════════════════════════════════════════════
getgenv().VenozScriptReady = true
print("[VENOZ] 🚦 โหลดสคริปครบทุกบรรทัดแล้ว → auto-pilot เริ่มทำงาน")
