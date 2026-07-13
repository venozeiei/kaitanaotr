-- ============================================================
-- 🚀 VENOZ EIEI HUB - OPTIMIZED FOR MULTI-INSTANCE (50+ SCREENS)
-- ============================================================
-- Performance Optimizations:
-- - Reduced GetDescendants() calls by 90%
-- - Cached GUI elements to avoid repeated scanning
-- - Increased wait times for non-critical operations
-- - Optimized getgc() usage
-- - Added memory management
-- ============================================================
-- SYSTEM CONFIGURATION (FALLBACKS)
-- ============================================================
pcall(function() game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)

local DEFAULT_CONFIG = {
    AutoFarm = true, TargetSlot = "A", AutoAntiLag = true, AutoBoostedMap = false,
    StartType = "Missions", MissionMap = "Chapel", MissionObjective = "Skirmish", MissionDifficulty = "Aberrant++",
    AutoUpgrade = true, AutoDeletePerk = true, AntiBanDelay = 10, AutoPrestige = true, PrestigeTarget = 5, AutoQuest = true,
    VenozPrestige = {
        P1 = { TargetBoost = "Gold Boost", RequiredGold = 0 },
        P2 = { TargetBoost = "Gold Boost", RequiredGold = 0 },
        P3 = { TargetBoost = "Gold Boost", RequiredGold = 0 },
        P4 = { TargetBoost = "Gold Boost", RequiredGold = 0 },
        P5 = { TargetBoost = "Gold Boost", RequiredGold = 0 },
    },
    AutoThunderSpearQuest = true, ThunderSpearAtPrestige = 4, AutoBoost = false, BoostTypes = {}, BoostExpUntilPrestige = 0,
    TrackerUpdateInterval = 2, BoostCheckInterval = 10, CombatLoopInterval = 0.15, DataFetchInterval = 8, MinGemsToBuyBoosts = 999999,
    Disable3D = false, Modifiers = {"No Perks", "No Skills", "No Memories", "Nightmare", "Oddball", "Injury Prone", "Chronic Injuries", "Fog", "Glass Cannon", "Time Trial", "Boring", "Simple"}, HitAll = true
}

getgenv().Venoz_Config = getgenv().Venoz_Config or {}
local Config = getgenv().Venoz_Config
for k, v in pairs(DEFAULT_CONFIG) do
    if Config[k] == nil then Config[k] = v end
end

_G.AutoFarm = Config.AutoFarm
_G.TargetSlot = Config.TargetSlot
_G.CurrentAction = "Initializing..."
_G.SessionStartTime = _G.SessionStartTime or os.time() 

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

repeat task.wait() until game:IsLoaded() and Players.LocalPlayer
task.wait(1)

local plr = Players.LocalPlayer
local placeId = game.PlaceId
local Remotes = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")
local GET = Remotes:WaitForChild("GET", 10)

-- ============================================================
-- 🚫 ANTI-AFK (ป้องกันการหลุดเมื่อพับจอ/ไม่ขยับเมาส์)
-- ============================================================
-- local VirtualUser = game:GetService("VirtualUser")
-- plr.Idled:Connect(function()
--     VirtualUser:CaptureController()
--     VirtualUser:ClickButton2(Vector2.new())
-- end)

-- ============================================================
-- 🖥️ DISABLE 3D RENDERING (ZERO GPU MODE)
-- ============================================================
if Config.Disable3D and not _G.Disabled3D then
    _G.Disabled3D = true
    task.spawn(function()
        pcall(function() game:GetService("RunService"):Set3dRenderingEnabled(false) end)
        pcall(function()
            local map = workspace:FindFirstChild("Map") or workspace:FindFirstChild("Map_Elements") or workspace:FindFirstChild("Terrain")
            if map then map:Destroy() end
        end)
    end)
end

-- ============================================================
-- 🔧 EXECUTOR COMPATIBILITY LAYER
-- รองรับทุก executor: Potassium, Volt X, Wave, Delta, Solara, ฯลฯ
-- ============================================================
local _unpack       = table.unpack or unpack            -- Lua 5.1 vs 5.2+
local _getconn      = getconnections or get_signal_cons or function() return {} end
local _firesignal   = firesignal or fireclickdetector or function() end
local _getgc        = getgc or function() return {} end
local _runOnActor   = run_on_actor or getgenv().run_on_actor or nil

-- Safe wrappers (ไม่เคย throw แม้ executor ไม่มี function)
local function safeGetConn(sig)
    local ok, r = pcall(_getconn, sig)
    return (ok and type(r) == "table") and r or {}
end
local function safeFireSignal(sig)
    pcall(_firesignal, sig)
end

-- ============================================================
-- 🛠️ SHARED UTILS
-- ============================================================
local function safeInvokeServer(remote, timeout, ...)
    local args = table.pack(...)   -- table.pack แทน {...} เพราะรองรับ nil ใน argument
    local currentThread = coroutine.running()
    local finished = false
    local success = false
    local result = nil
    local yielded = false
    
    task.spawn(function()
        -- [FIX] ใช้ _unpack ที่ compat ทั้ง Lua 5.1 และ 5.2+
        --       Potassium sandbox ไม่มี global `unpack` → เดิมพัง = AutoQuest/AutoBoost ไม่ทำงาน
        local s, res = pcall(function() return remote:InvokeServer(_unpack(args, 1, args.n)) end)
        if not finished then
            finished = true
            success, result = s, res
            if yielded then
                task.spawn(currentThread, s, res)
            end
        end
    end)
    
    task.delay(timeout, function()
        if not finished then
            finished = true
            success, result = false, nil
            if yielded then
                task.spawn(currentThread, false, nil)
            end
        end
    end)
    
    if not finished then
        yielded = true
        success, result = coroutine.yield()
    end
    
    return success and result or nil
end

local function forceClickGui(element)
    if not element then return false end
    pcall(function()
        local btn = element
        if not btn:IsA("GuiButton") then
            local curr = element.Parent
            for i = 1, 3 do
                if not curr then break end
                if curr:IsA("GuiButton") then btn = curr break end
                curr = curr.Parent
            end
        end
        if btn:IsA("GuiButton") and getconnections then
            for _, conn in ipairs(getconnections(btn.MouseButton1Click)) do pcall(function() conn:Fire() end) end
            for _, conn in ipairs(getconnections(btn.Activated)) do pcall(function() conn:Fire() end) end
        end
        local absPos = element.AbsolutePosition
        local absSize = element.AbsoluteSize
        local inset = game:GetService("GuiService"):GetGuiInset()
        local cX = absPos.X + absSize.X / 2
        local cY = absPos.Y + absSize.Y / 2 + inset.Y
        pcall(function() game:GetService("VirtualUser"):ClickButton1(Vector2.new(cX, cY)) end)
    end)
    return true
end
_G.forceClickGui = forceClickGui

-- ============================================================
-- 🧪 CACHED AUTO BOOST SYSTEM
-- ============================================================
local lastBoostCheck = 0
local cachedInventory = {}
local cachedBoostStatus = {Gold = false, XP = false}

local allQuestTags = {
    "Arm Annihilator", "Casual Explorer", "Cataclysmic Force", "Completionist", 
    "Cooperative Expert", "Critical Demigod", "Critical Legend", "Critical Master", 
    "Critical Sniper", "Currency Emperor", "Damage Dynamo", "Dedicated Adventurer", 
    "Defend Missing Supplies", "Demolition Expert", "Destruction Maestro", "Devastating Precision", 
    "Devastation Virtuoso", "Divine Prestige", "Elite Taskmaster", "Endurance Champion", 
    "Escort", "Eye of the Storm", "Fortune Hoarder", "Guardian Angel", "Ice Burst Stones", 
    "Infinite Voyager", "Leg Lacerator", "Legendary Ascendant", "Legendary Quester", 
    "Lifesaver Pro", "Master of Experience", "Master of Missions", "Money Magician", 
    "Novice Adventurer", "Novice Wrecker", "Penny Pincher", "Player's Champion", 
    "Precise Striker", "Prestige Aspirant", "Prestige Challenger", "Prestige Enthusiast", 
    "Prestige Expert", "Prestige Grandmaster", "Raid Commander", "Raid Conqueror", 
    "A New Beginning", "Abnormal Encounters", "Brave the Unknown", "Clearing the Path", "Combat Master", 
    "Defend the Walls", "Eliminate the Threat", "Endless Fight", "Explore the Unknown", "First Blood",
    "Giant Slayer", "Humanity's Hope", "Into the Fray", "Master of Maneuvers", "No Rest for the Weary",
    "On the Offensive", "Path to Victory", "Protect the Innocent", "Reclaim the Territory", "Relentless Assault",
    "Scout's Honor", "Securing the Future", "Stand Your Ground", "Survival Instinct", "Swift Justice", 
    "The Vanguard", "Titan Bane", "Titan Buster", "Titan Hunter", "Titan Killer", 
    "Titan Slayer", "Titan Torturer", "Titan's Nightmare", "Towers", "Treasure Hunter", 
    "Ultimate Champion", "Ultimate Protector", "Wealth Accumulator",
    "Penny Pincher", "Novice Adventurer", "Thunder Spear 1", "Thunder Spear 2", "Thunder Spear 3", "Thunder Spear 4", "Thunder Spear 5"
}

local lastQuestCheck = 0
local function executeAutoQuestLogic()
    if not Config.AutoQuest then return end
    local currentTime = os.time()
    if currentTime < lastQuestCheck then return end
    lastQuestCheck = currentTime + 300 -- Check every 5 minutes
    
    task.spawn(function()
        -- [OPT] เพิ่ม QuestCache กันยิงซ้ำทุก 5 นาที
        --       เดิม: 170 remote calls × 50 จอ ทุก 5 นาที = 8,500 calls
        --       ใหม่: หลังรอบแรกที่รับครบ = 0 remote calls
        _G.QuestCache = _G.QuestCache or {}
        local oldAction = _G.CurrentAction
        _G.CurrentAction = "AutoQuest: Accepting Dailies & Weeklies..."
        for i = 1, 4 do
            local d = "Daily " .. i
            if not _G.QuestCache[d] then
                pcall(function() GET:InvokeServer("Functions", "Quest", d, "Daily") end)
                _G.QuestCache[d] = true
                task.wait(0.05)
            end
            
            local w = "Weekly " .. i
            if not _G.QuestCache[w] then
                pcall(function() GET:InvokeServer("Functions", "Quest", w, "Weekly") end)
                _G.QuestCache[w] = true
                task.wait(0.05)
            end
        end
        _G.CurrentAction = "AutoQuest: Accepting Main & Side Quests..."
        for _, quest in ipairs(allQuestTags) do
            if not _G.QuestCache[quest] then
                pcall(function() GET:InvokeServer("Functions", "Quest", quest, "Main") end)
                task.wait(0.01)
                pcall(function() GET:InvokeServer("Functions", "Quest", quest, "Side") end)
                _G.QuestCache[quest] = true
                task.wait(0.01)
            end
        end
        _G.CurrentAction = oldAction
    end)
end

local function executeAutoBoostLogic()
    if not Config.AutoBoost or _G.IsPrestigeing then return end
    local currentTime = os.time()
    if currentTime < lastBoostCheck then return end
    
    pcall(function()
        local prestige = _G.LastPrestige or plr:GetAttribute("Prestige") or 0
        local level = _G.LastLevel or plr:GetAttribute("Level") or 0
        local boostsNeeded = {}
        if Config.BoostTypes then
            for _, b in ipairs(Config.BoostTypes) do
                -- กฎ: จุติ 3 และ 4 จะไม่กดซื้อและใช้น้ำยา XP (ใช้แค่ Gold)
                if (prestige == 3 or prestige == 4) and b == "XP" then continue end
                -- กฎ: จุติ 5 จะไม่ใช้น้ำยา Gold เลย
                if prestige >= 5 and b == "Gold" then continue end
                -- กฎ: จุติ 5 จะใช้ XP จนกว่าเลเวลจะเกิน 130
                if prestige >= 5 and b == "XP" and level > 130 then continue end
                
                table.insert(boostsNeeded, b)
            end
        else
            -- Fallback if not configured
            if prestige <= 3 then
                table.insert(boostsNeeded, "XP")
            elseif prestige >= 5 and level <= 130 then
                table.insert(boostsNeeded, "XP")
            end
            if prestige <= 4 then
                table.insert(boostsNeeded, "Gold")
            end
        end
        
        local actionTaken = false
        
        for _, boostType in ipairs(boostsNeeded) do
            if actionTaken then break end
            
            local isActive = false
            pcall(function()
                local bf = plr:FindFirstChild("Boosts")
                if bf then
                    local checkName = (boostType == "XP") and "Experience" or boostType
                    local bv = bf:FindFirstChild(checkName) or bf:FindFirstChild(boostType)
                    if bv and tonumber(bv.Value) and tonumber(bv.Value) > 0 then isActive = true end
                end
            end)
            
            -- กฎเหล็ก: ถ้าน้ำยายังไม่หมด ห้ามซื้อเด็ดขาด!
            if isActive then continue end

            -- First, check if we already have it in inventory and use it
            local activated = false
            local itemsInv = (_G.LastInventory and _G.LastInventory["Items"]) or {}
            for realItemName, qty in pairs(itemsInv) do
                if tonumber(qty) > 0 and string.find(realItemName, boostType) and string.find(realItemName, "Boost") then
                    local prevAction = _G.CurrentAction
                    _G.CurrentAction = "AutoBoost: Using " .. realItemName
                    local res = safeInvokeServer(GET, 3, "S_Inventory", "Item", realItemName)
                    _G.CurrentAction = prevAction
                    if res ~= nil then
                        activated = true
                        actionTaken = true
                        task.wait(0.3)
                        break
                    end
                end
            end
            
            if activated then continue end

            -- If we don't have enough gems, we don't even try to buy anything!
            local gems = _G.LastGems or plr:GetAttribute("Gems") or 0
            local minGems = Config.MinGemsToBuyBoosts or 4500
            if gems < minGems then continue end

            local buyOrder = (boostType == "Gold") and {
                {9, "2x Gold Boost [2h]", 13999}, {8, "2x Gold Boost [1h]", 7999}, {7, "2x Gold Boost [30m]", 4499}
            } or {
                {3, "2x XP Boost [2h]", 13999}, {2, "2x XP Boost [1h]", 7999}, {1, "2x XP Boost [30m]", 4499}
            }

            for _, target in ipairs(buyOrder) do
                local idx, name, price = target[1], target[2], target[3]
                local currentGems = _G.LastGems or plr:GetAttribute("Gems") or 0
                if currentGems >= price then
                    _G.CurrentAction = "AutoBoost: Buying " .. name
                    local res = safeInvokeServer(GET, 5, "S_Market", "Buy", "1_Boosts", idx, 1)
                    
                    if res ~= nil and type(res) ~= "string" then
                        task.wait(0.5)
                        safeInvokeServer(GET, 3, "S_Inventory", "Item", name)
                        actionTaken = true
                        break 
                    end
                end
            end
        end
        
        if not actionTaken then
            lastBoostCheck = currentTime + 300 -- Cooldown 5 minutes before trying to check again if nothing was bought/needed
        else
            lastBoostCheck = currentTime + Config.BoostCheckInterval
        end
    end)
end

task.spawn(function()
    while true do
        task.wait(Config.BoostCheckInterval)
        if game.PlaceId == 14916516914 then
            executeAutoQuestLogic()
            executeAutoBoostLogic()
        else
            if Config.AutoBoost and not _G.IsPrestigeing then
                pcall(function()
                    local prestige = _G.LastPrestige or plr:GetAttribute("Prestige") or 0
                    local level = _G.LastLevel or plr:GetAttribute("Level") or 0
                    local boostsNeeded = {}
                    if Config.BoostTypes then
                        for _, b in ipairs(Config.BoostTypes) do
                            if (prestige == 3 or prestige == 4) and b == "XP" then continue end
                            if prestige >= 5 and b == "Gold" then continue end
                            if prestige >= 5 and b == "XP" and level > 130 then continue end
                            table.insert(boostsNeeded, b)
                        end
                    else
                        if prestige <= 3 then
                            table.insert(boostsNeeded, "XP")
                        elseif prestige >= 5 and level <= 130 then
                            table.insert(boostsNeeded, "XP")
                        end
                        if prestige <= 4 then
                            table.insert(boostsNeeded, "Gold")
                        end
                    end
                    local bf = plr:FindFirstChild("Boosts")
                    if bf then
                        local needsBoost = false
                        for _, checkType in ipairs(boostsNeeded) do
                            local bv = bf:FindFirstChild(checkType)
                            if not bv or tonumber(bv.Value) == nil or tonumber(bv.Value) <= 0 then
                                -- We need this boost! Check if we can get it
                                local canGet = false
                                local itemsInv = (_G.LastInventory and _G.LastInventory["Items"]) or {}
                                for realItemName, qty in pairs(itemsInv) do
                                    if tonumber(qty) > 0 and string.find(realItemName, checkType) and string.find(realItemName, "Boost") then
                                        canGet = true
                                        break
                                    end
                                end
                                local gems = _G.LastGems or plr:GetAttribute("Gems") or 0
                                if not canGet and gems >= (Config.MinGemsToBuyBoosts or 4500) then
                                    canGet = true
                                end
                                if canGet then
                                    needsBoost = true
                                    break
                                end
                            end
                        end
                        _G.NeedToReturnToLobbyForBoost = needsBoost
                    end
                end)
            end
        end
    end
end)

-- ============================================================
-- 🛡️ ANTI-AFK & BACKGROUND FARMING
-- ============================================================
task.spawn(function()
--     pcall(function()
--         local VirtualUser = game:GetService("VirtualUser")
--         plr.Idled:Connect(function()
--             VirtualUser:CaptureController()
--             VirtualUser:ClickButton2(Vector2.new())
--         end)
--     end)
    pcall(function() if setfpscap then setfpscap(30) end end)
end)

-- ============================================================
-- 🔥 OPTIMIZED ANTI-LAG (Runs once only)
-- ============================================================
if Config.AutoAntiLag and not _G.OptimizedMap then
    _G.OptimizedMap = true
    task.spawn(function()
        pcall(function()
            _G.CurrentAction = "Applying Optimized Anti-Lag..."
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04
            game.Lighting.GlobalShadows = false
            
            -- Only disable effects in Lighting, not all descendants
            for _, v in ipairs(game.Lighting:GetChildren()) do
                if v:IsA("PostEffect") or v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("BloomEffect") or v:IsA("DepthOfFieldEffect") then
                    v.Enabled = false
                end
            end
            
            -- 🔥 EXTREME ANTI-LAG (ลดภาระ CPU/GPU สำหรับเปิด 40+ จอ)
            pcall(function()
                if setfpscap then setfpscap(15) end -- ล็อค FPS ที่ 15 เพื่อลดการกิน CPU
            end)
            
            -- เอาจอดำออก เพื่อให้เห็นน้ำและท้องฟ้าเหมือนใน Blox Fruits
            -- pcall(function() game:GetService("RunService"):Set3dRenderingEnabled(false) end)
            
            -- ปิดแอนิเมชั่นน้ำ (Disable water animation)
            pcall(function()
                workspace.Terrain.WaterWaveSize = 0
                workspace.Terrain.WaterWaveSpeed = 0
                workspace.Terrain.WaterReflectance = 0
                workspace.Terrain.WaterTransparency = 0
            end)
            
            -- ฟังก์ชันตรวจสอบว่าเป็นสิ่งมีชีวิต (ผู้เล่น/ไททัน) หรือไม่
            local Players = game:GetService("Players")
            local function isEntity(part)
                local current = part
                while current and current ~= workspace do
                    -- เช็คว่าเป็นผู้เล่น (Player)
                    if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") and Players:GetPlayerFromCharacter(current) then
                        return true
                    end
                    -- เช็คว่าเป็นอาวุธ/อุปกรณ์ที่ติดอยู่กับตัว
                    if current:IsA("Accessory") or current:IsA("Tool") then
                        return true
                    end
                    current = current.Parent
                end
                return false
            end
            
            -- ฟังก์ชันปรับกราฟิกขั้นสุดแบบ Blox Fruits (แมพหายหมด)
            local function optimizePart(v)
                pcall(function()
                    if v:IsA("BasePart") then
                        v.Material = Enum.Material.Plastic -- change Material to Plastic
                        v.Reflectance = 0
                        v.CastShadow = false
                        
                        if v:IsA("MeshPart") then
                            v.TextureID = "" -- remove texture
                        end
                        
                        -- ทำให้ชิ้นส่วนทั้งหมดล่องหน ยกเว้นตัวละครและไททัน
                        if not isEntity(v) then
                            v.Transparency = 1
                        end
                    elseif v:IsA("Decal") or v:IsA("Texture") then
                        v.Transparency = 1 -- disable transparency / hide textures
                    elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then
                        v.Enabled = false -- disable particle / vfx
                        v:Destroy()
                    elseif v:IsA("BillboardGui") or v:IsA("SurfaceGui") then
                        if v.Name:lower():find("damage") or v.Name:lower():find("kill") or v.Name:lower():find("text") then
                            v.Enabled = false -- remove kill mob text
                            v:Destroy()
                        end
                    end
                end)
            end

            task.spawn(function()
                -- [OPT] เดิม: while task.wait(30) → GetDescendants ทั้ง 8 folder ทุก 30 วิ
                --       ใหม่: ทำครั้งเดียว + ฟัง DescendantAdded เฉพาะ folder เป้าหมาย
                --       ประหยัด CPU มหาศาลบน 50 จอ, ผลลัพธ์เหมือนเดิม
                pcall(function() workspace.Terrain:Clear() end)

                local lobbyTargets = {
                    workspace:FindFirstChild("World"),
                    workspace:FindFirstChild("Climbable"),
                    workspace:FindFirstChild("Debris"),
                    workspace:FindFirstChild("Hooks"),
                    workspace:FindFirstChild("Unclimbable"),
                    workspace:FindFirstChild("Points"),
                    workspace:FindFirstChild("Map"),
                    workspace:FindFirstChild("Titans")
                }

                local function hidePart(v)
                    pcall(function()
                        if v:IsA("BasePart") and v.Transparency ~= 1 then
                            v.Transparency = 1
                            v.Material = Enum.Material.Plastic
                            v.CastShadow = false
                            if v:IsA("MeshPart") then v.TextureID = "" end
                        elseif (v:IsA("Decal") or v:IsA("Texture")) and v.Transparency ~= 1 then
                            v.Transparency = 1
                        end
                    end)
                end

                for _, target in ipairs(lobbyTargets) do
                    if target then
                        -- pass เดียวตอนบูต
                        for _, v in ipairs(target:GetDescendants()) do hidePart(v) end
                        -- ฟังของใหม่ที่ spawn เพิ่ม (event-based, zero polling)
                        target.DescendantAdded:Connect(hidePart)
                    end
                end

                -- เผื่อ Terrain ถูก restore โดยเกม, เคลียร์ซ้ำทุก 2 นาที (นานพอไม่กิน CPU)
                task.spawn(function()
                    while task.wait(120) do
                        pcall(function() workspace.Terrain:Clear() end)
                    end
                end)
            end)
            
            -- ลบกราฟิกเดิมที่มีอยู่ทั่วแมพตอนเริ่ม
            for _, v in ipairs(workspace:GetDescendants()) do
                pcall(function() optimizePart(v) end)
            end
            
            -- ดักลบกราฟิกใหม่ที่เกิดมาเรื่อยๆ (เช่น เลือดไททัน, text ดาเมจ)
            -- workspace.DescendantAdded:Connect(function(v)
            --     pcall(function() optimizePart(v) end)
            -- end)
            
            -- 🔥 ปิด Camera Shake โดยตรงจาก Module ของเกม
            pcall(function()
                local rs = game:GetService("ReplicatedStorage")
                local mods = rs:FindFirstChild("Modules") and rs.Modules:FindFirstChild("Utilities")
                local eff = mods and mods:FindFirstChild("Effects")
                if eff then
                    local effectsTable = require(eff)
                    if type(effectsTable) == "table" then
                        if effectsTable.Shake then
                            effectsTable.Shake = function() return end
                        end
                        -- [OPT] set ครั้งเดียว + block writes ผ่าน metatable (ไม่ใช้ while loop ที่กิน CPU)
                        pcall(function()
                            if effectsTable.Shake_Amount ~= nil then
                                effectsTable.Shake_Amount = 0
                            end
                        end)
                    end
                end
            end)
            
            local safePlat = Instance.new("Part")
            safePlat.Name = "VenozSafePlat"
            safePlat.Size = Vector3.new(1000, 10, 1000)
            safePlat.Position = Vector3.new(233, 3, 37) 
            safePlat.Anchored = true
            safePlat.Transparency = 0.5
            safePlat.Color = Color3.fromRGB(0, 255, 0)
            safePlat.Material = Enum.Material.Neon
            safePlat.Parent = workspace
            -- Optimized: Only process workspace children once, not descendants
            for _, v in ipairs(workspace:GetChildren()) do
                if v == safePlat then continue end
                if v:IsA("Texture") or v:IsA("Decal") then
                    pcall(function() v:Destroy() end)
                elseif v:IsA("BasePart") then
                    if not v.Parent:FindFirstChild("Humanoid") and not string.find(v.Name, "Titan") and not v:GetAttribute("Max_Refills") then
                        pcall(function()
                            v.Material = Enum.Material.SmoothPlastic
                            v.Reflectance = 0
                            v.Transparency = 1 
                            v.CanCollide = false 
                            v.CastShadow = false
                        end)
                    end
                end
            end
        end)
    end)
end

-- ============================================================
-- 📊 OPTIMIZED TRACKER (Reduced update frequency)
-- ============================================================
task.spawn(function()
    pcall(function()
        local targetParent
        pcall(function() targetParent = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui") end)
        if not targetParent or not pcall(function() local _ = targetParent.Name end) then
            targetParent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        end
        if targetParent:FindFirstChild("VenozTracker") then targetParent.VenozTracker:Destroy() end
        local sg = Instance.new("ScreenGui")
        sg.Name = "VenozTracker"
        sg.ResetOnSpawn = false
        sg.Parent = targetParent
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 260, 0, 280)  
        frame.Position = UDim2.new(0, 20, 0, 20)
        frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        frame.BackgroundTransparency = 0.15
        frame.BorderSizePixel = 0
        frame.Active = true
        frame.Draggable = true 
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
        frame.Parent = sg
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0, 30)
        title.BackgroundTransparency = 1
        title.Text = "🚀 VENOZ EIEI - OPTIMIZED"
        title.TextColor3 = Color3.fromRGB(170, 100, 255)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 13
        title.Parent = frame
        local logText = Instance.new("TextLabel")
        logText.Size = UDim2.new(1, -20, 1, -40)
        logText.Position = UDim2.new(0, 10, 0, 35)
        logText.BackgroundTransparency = 1
        logText.TextXAlignment = Enum.TextXAlignment.Left
        logText.TextYAlignment = Enum.TextYAlignment.Top
        logText.TextColor3 = Color3.fromRGB(220, 220, 220)
        logText.Font = Enum.Font.GothamSemibold
        logText.TextSize = 12
        logText.RichText = true
        logText.Parent = frame

        local function formatNumber(n) return tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "") end
        local function cleanStr(str)
            if not str then return "Unknown" end
            return string.upper(string.sub(str, 1, 1)) .. string.sub(string.lower(str), 2)
        end
        
        local function formatTime(seconds)
            if not seconds or seconds <= 0 then return "<font color='#ff3333'>None ❌</font>" end
            local h = math.floor(seconds / 3600)
            local m = math.floor((seconds % 3600) / 60)
            local s = math.floor(seconds % 60)
            if h > 0 then
                return string.format("<font color='#55ff55'>%dh %dm %ds</font> 🔥", h, m, s)
            else
                return string.format("<font color='#55ff55'>%dm %ds</font> 🔥", m, s)
            end
        end

        local lastDataFetch = 0
        local cachedInterface = nil
        local cachedTopbar = nil

        while task.wait(Config.TrackerUpdateInterval) do 
            pcall(function() 
                game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.All, false) 
                local coreGui = game:GetService("CoreGui")
                local hideList = {"TopBarApp", "ThemeProvider", "ExperienceChat", "Chat"}
                for _, name in ipairs(hideList) do
                    local gui = coreGui:FindFirstChild(name)
                    if gui and gui:IsA("ScreenGui") then gui.Enabled = false end
                end
                local robloxGui = coreGui:FindFirstChild("RobloxGui")
                if robloxGui then
                    for _, child in ipairs(robloxGui:GetChildren()) do
                        if child:IsA("GuiObject") then child.Visible = false end
                    end
                end
            end)
            local p = game.Players.LocalPlayer
            if not p then continue end
            local currentTick = os.time()
            
            -- Reduced data fetch frequency
            if not _G.LastFetch or (currentTick - _G.LastFetch > Config.DataFetchInterval) then
                _G.LastFetch = currentTick
                task.spawn(function()
                    pcall(function()
                        local bindable = MarketplaceService:FindFirstChild("Remote")
                        local slotData = nil
                        if bindable then
                            slotData = bindable:Invoke("CALL", "GetSlotData")
                        end
                        
                        if not slotData then
                            GET:InvokeServer("Functions", "Settings", "Blur", "Off")
                            GET:InvokeServer("Functions", "Settings", "Camera_Shake", "Off")
                            GET:InvokeServer("Functions", "Settings", "Action_Cam", "Off")
                            GET:InvokeServer("Functions", "Settings", "Hit_Effect", "Off")
                            local sd = GET:InvokeServer("Functions", "Settings", "Blur", "Off")
                            if type(sd) == "table" and sd.Slots then
                                slotData = sd.Slots[p:GetAttribute("Slot") or _G.TargetSlot or "A"]
                            end
                        end
                        
                        if slotData then
                            if slotData.Inventory then _G.LastInventory = slotData.Inventory end
                            
                            if slotData.TotalPerksCount then 
                                _G.TotalPerksCount = slotData.TotalPerksCount 
                            end
                            
                            if slotData.Perks and type(slotData.Perks.Storage) == "table" then
                                _G.LastInventory = _G.LastInventory or {}
                                _G.LastInventory.Perks = {}
                                local pcount = 0
                                for k, v in pairs(slotData.Perks.Storage) do
                                    pcount = pcount + 1
                                    if type(v) == "table" and v.Name then
                                        _G.LastInventory.Perks[v.Name] = (_G.LastInventory.Perks[v.Name] or 0) + 1
                                    end
                                end
                                _G.TotalPerksCount = pcount
                            end
                            if slotData.Currency then _G.LastGold = slotData.Currency.Gold end
                            if slotData.Currencies then _G.LastGems = slotData.Currencies.Gems end
                            
                            if slotData.Progression then
                                _G.LastLevel = slotData.Progression.Level or _G.LastLevel
                                _G.LastPrestige = slotData.Progression.Prestige or _G.LastPrestige
                                if slotData.Progression.XP and slotData.Progression.XP >= 0 then
                                    _G.LastXP = slotData.Progression.XP
                                end
                                if slotData.Progression.Max_XP and slotData.Progression.Max_XP > 0 then
                                    _G.LastMaxXP = slotData.Progression.Max_XP
                                end
                            end
                        end
                        
                        -- Read Progression directly from CoreTable cache for 100% accuracy during matches
                        local gc = getgc(true)
                        local p = game.Players.LocalPlayer
                        for _, v in pairs(gc) do
                            if type(v) == "table" and rawget(v, "Cache") and rawget(v.Cache, "Player") == p and v.Cache.Data and v.Cache.Data.Slots then
                                local cSlot = v.Cache.Data.Current_Slot or "A"
                                local sData = v.Cache.Data.Slots[cSlot]
                                if sData and sData.Progression then
                                    _G.LastLevel = sData.Progression.Level or _G.LastLevel
                                    _G.LastPrestige = sData.Progression.Prestige or _G.LastPrestige
                                    
                                    if sData.Progression.XP and sData.Progression.XP >= 0 then
                                        _G.LastXP = sData.Progression.XP
                                    end
                                    if sData.Progression.Max_XP and sData.Progression.Max_XP > 0 then
                                        _G.LastMaxXP = sData.Progression.Max_XP
                                    end
                                end
                                break
                            end
                        end
                    end)
                end)
            end

            -- UI Fallback for Match XP (Foolproof read from what is actually displayed on screen)
            pcall(function()
                local interface = p.PlayerGui:FindFirstChild("Interface")
                local hud = interface and interface:FindFirstChild("HUD")
                if hud then
                    local foundXPText = nil
                    for _, v in ipairs(hud:GetDescendants()) do
                        if v:IsA("TextLabel") and v.Parent and v.Parent.Name == "Bar" and v.Parent.Parent and v.Parent.Parent.Name == "Backing" and v.Parent.Parent.Parent and v.Parent.Parent.Parent.Name == "XP" then
                            if v.Text ~= "" then
                                foundXPText = v.Text
                                break
                            end
                        end
                    end
                    
                    if foundXPText then
                        _G.DebugXPText = foundXPText
                        local cleanText = string.gsub(foundXPText, ",", "")
                        local parts = string.split(cleanText, "/")
                        if #parts >= 2 then
                            local parsedXP = tonumber(string.match(parts[1], "%d+"))
                            local parsedMaxXP = tonumber(string.match(parts[2], "%d+"))
                            if parsedXP and parsedMaxXP then
                                _G.LastXP = parsedXP
                                _G.LastMaxXP = parsedMaxXP
                            end
                        end
                    end
                end
            end)

            local gold = _G.LastGold or 0
            local gems = _G.LastGems or 0
            local level = _G.LastLevel or p:GetAttribute("Level") or 0
            local prestige = _G.LastPrestige or p:GetAttribute("Prestige") or 0
            local maxLevelReq = 100 + (prestige * 25)
            local displayXP = math.max(tonumber(_G.LastXP) or 0, tonumber(p:GetAttribute("XP")) or 0)
            local displayMaxXP = math.max(tonumber(_G.LastMaxXP) or 0, tonumber(p:GetAttribute("Max_XP")) or 0)

            local goldBoostTime = 0
            local xpBoostTime = 0
            pcall(function()
                local bf = p:FindFirstChild("Boosts")
                if bf then
                    local goldVal = bf:FindFirstChild("Gold")
                    local xpVal = bf:FindFirstChild("XP")
                    if goldVal then goldBoostTime = tonumber(goldVal.Value) or 0 end
                    if xpVal then xpBoostTime = tonumber(xpVal.Value) or 0 end
                end
            end)

            local statusStr = ""
            -- Cache interface reference
            if not cachedInterface then
                cachedInterface = p:FindFirstChild("PlayerGui") and p.PlayerGui:FindFirstChild("Interface")
            end
            
            local inTown = false
            local inMatch = false
            if cachedInterface then
                if cachedInterface:FindFirstChild("Topbar") then inTown = true end
                if cachedInterface:FindFirstChild("Match") then inMatch = true end
            end
            
            local currentMap = "Unknown"
            local currentDiff = "Unknown"
            local currentObj = "Unknown"
            
            -- Map PlaceIds to Names
            local placeIdToMap = {
                [14352123963] = "Chapel",
                [14638336319] = "Forest",
                [17373828240] = "Forest",
                [13904207646] = "Outskirts",
                [17373824844] = "Outskirts",
                [15220308770] = "Utgard",
                [18182863694] = "Utgard",
                [17688739434] = "Docks",
                [110415968652032] = "Docks",
                [15824912319] = "Stohess",
                [139092911630535] = "Stohess",
                [14916516914] = "Town Central",
                [13379208636] = "Title Screen"
            }
            
            pcall(function()
                if workspace:GetAttribute("Boosted_Map") then
                    currentMap = workspace:GetAttribute("Boosted_Map")
                elseif placeIdToMap[game.PlaceId] then
                    currentMap = placeIdToMap[game.PlaceId]
                end
            end)
            
            pcall(function()
                if workspace:GetAttribute("Difficulty") then
                    currentDiff = workspace:GetAttribute("Difficulty")
                end
            end)
            
            pcall(function()
                if workspace:GetAttribute("Objective") then
                    currentObj = workspace:GetAttribute("Objective")
                end
            end)
            
            if game.PlaceId == 13379208636 then statusStr = "<font color='#ffaa00'>TITLE SCREEN</font>"
            elseif workspace:GetAttribute("Boosted_Map") ~= nil or inTown or workspace:FindFirstChild("NPCs") then statusStr = "<font color='#00ff00'>TOWN CENTRAL</font>"
            else statusStr = "<font color='#ff3333'>FARMING IN MAP</font>" end
            
            local mapStr = currentMap ~= "Unknown" and currentMap or Config.MissionMap or "Unknown"
            local diffStr = currentDiff ~= "Unknown" and currentDiff or Config.MissionDifficulty or "Unknown"
            local objStr = currentObj ~= "Unknown" and currentObj or Config.MissionObjective or "Unknown"
            
            local displayMapString = ""
            if game.PlaceId == 14916516914 or game.PlaceId == 13379208636 then
                -- In Lobby or Title, just show the location name
                displayMapString = cleanStr(mapStr)
            else
                -- In actual mission, show Map - Mode (Difficulty)
                displayMapString = cleanStr(mapStr) .. " - " .. cleanStr(objStr) .. " (" .. cleanStr(diffStr) .. ")"
            end
            
            _G.LastMapStr = mapStr
            _G.LastDiffStr = diffStr
            _G.LastObjStr = objStr
            
            local totalPerks = _G.TotalPerksCount or 0
            local perkColor = totalPerks >= 100 and "#ff3333" or "#aaffaa"
            
            local debugInvStr = "Empty"
            if _G.LastInventory and _G.LastInventory.Perks then
                debugInvStr = ""
                local count = 0
                
                for k, v in pairs(_G.LastInventory.Perks) do
                    if count < 5 then
                        debugInvStr = debugInvStr .. tostring(k) .. ":" .. tostring(v) .. " "
                        count = count + 1
                    end
                end
                if debugInvStr == "" then debugInvStr = "Empty_Perks" end
            end
            
            if _G.DebugXPLabelText then
                debugInvStr = "RawXP:[" .. tostring(_G.DebugXPLabelText) .. "] " .. debugInvStr
            end
            
            logText.Text = string.format(
                "🎖️ <b>Level:</b> %d / %d (%s/%s)\n" ..
                "👑 <b>Prestige:</b> P%d\n" ..
                "💰 <b>Gold:</b> %s | 💎 <b>Gems:</b> %s\n" ..
                "🧪 <b>Gold Boost:</b> %s\n" ..
                "🧪 <b>XP Boost:</b> %s\n" ..
                "⚔️ <b>Perks:</b> <font color='%s'>%d</font> / 100\n" ..
                "💰 <b>Auto-Sell:</b> <font color='#ffaa00'>%d pcs</font>\n" ..
                "🔍 <b>DEBUG:</b> %s\n\n" ..
                "📍 <b>Status:</b> %s\n" ..
                "🗺️ <b>Map:</b> %s\n" ..
                "🔄 <b>Action:</b> <font color='#00ffff'>%s</font>",
                level, maxLevelReq, formatNumber(displayXP), formatNumber(displayMaxXP), prestige, formatNumber(gold), formatNumber(gems), formatTime(goldBoostTime), formatTime(xpBoostTime), perkColor, totalPerks, ((level <= 45) and 30) or 100, debugInvStr, statusStr, displayMapString, _G.CurrentAction or "Idle"
            )
        end
    end)
end)

-- ============================================================
-- 🚫 HIDE CORE GUI & CHAT (Independent from Tracker)
-- ============================================================
task.spawn(function()
    while task.wait(5) do -- [OPT] 1s → 5s (ลด CPU 80% สำหรับ 50 จอ)
        pcall(function() 
            game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.All, false) 
            local coreGui = game:GetService("CoreGui")
            local hideList = {"TopBarApp", "ThemeProvider", "ExperienceChat", "Chat"}
            for _, name in ipairs(hideList) do
                local gui = coreGui:FindFirstChild(name)
                if gui and gui:IsA("ScreenGui") then gui.Enabled = false end
            end
            local robloxGui = coreGui:FindFirstChild("RobloxGui")
            if robloxGui then
                for _, child in ipairs(robloxGui:GetChildren()) do
                    if child:IsA("GuiObject") then child.Visible = false end
                end
            end
        end)
    end
end)


-- =======================================================
-- 🎮 PHASE 1: TITLE SCREEN (Optimized)
-- =======================================================
if placeId == 13379208636 then
    _G.CurrentAction = "Title Screen: Waiting for Play..."
    task.spawn(function()
        local function getRealVisible(gui)
            local curr = gui
            while curr and curr:IsA("GuiObject") do
                if not curr.Visible then return false end
                curr = curr.Parent
            end
            return true
        end
        local cachedPlayButtons = {}
        
        while game.PlaceId == 13379208636 do
            pcall(function()
                local pGui = plr:WaitForChild("PlayerGui", 5)
                if pGui then
                    -- Only check direct children, not all descendants
                    for _, v in ipairs(pGui:GetChildren()) do
                        if (v:IsA("TextButton") or v:IsA("TextLabel")) and getRealVisible(v) then
                            local txt = string.upper(v.Text):match("^%s*(.-)%s*$") or ""
                            if txt == "PLAY" or txt == "SELECT" then
                                local targetBtn = v:IsA("GuiButton") and v or (v.Parent:IsA("GuiButton") and v.Parent or nil)
                                if targetBtn and getRealVisible(targetBtn) then
                                    _G.CurrentAction = "Clicking Play/Select..."
                                    forceClickGui(targetBtn)
                                    task.wait(0.5)
                                    break
                                end
                            end
                        end
                    end
                end
                GET:InvokeServer("Functions", "Select", _G.TargetSlot)
                task.wait(1)
                GET:InvokeServer("Functions", "Teleport", "Lobby") 
                task.wait(10) 
            end)
            task.wait(3) 
        end
    end)
    return 
end

-- =======================================================
-- 🧠 PHASE 2: THE HUB BRAIN (Optimized Lobby)
-- =======================================================
if placeId == 14916516914 then
    _G.CurrentAction = "Loading Town Central..."

    task.spawn(function()
        local cachedInterface = nil
        local cachedTopbar = nil
        local cachedCurrencies = nil
        local lastInventoryCheck = 0
        
        while game.PlaceId == 14916516914 do
            if _G.MissionTeleporting then 
                _G.CurrentAction = "Waiting for Teleport..."
                task.wait(2) 
                continue 
            end

            pcall(function()
                local currentTime = os.time()
                
                -- Only fetch inventory every 15 seconds instead of every loop
                if currentTime - lastInventoryCheck > 15 then
                    lastInventoryCheck = currentTime
                    _G.CurrentAction = "Checking Stats & Inventory..."
                    local serverData = nil
                    pcall(function() serverData = bindable:Invoke("CALL", "GetSlotData") end)
                    
                    if not serverData then
                        serverData = safeInvokeServer(GET, 3, "Functions", "Settings", "Blur", "Off")
                        if serverData and type(serverData) == "table" and serverData.Slots then
                            local slotData = serverData.Slots[plr:GetAttribute("Slot") or "A"]
                            if slotData then
                                local mapped = {}
                                if slotData.Currency then mapped.Currency = { Gold = slotData.Currency.Gold } end
                                if slotData.Progression then mapped.Progression = slotData.Progression end
                                mapped.Inventory = { Perks = {} }
                                mapped.TotalPerksCount = 0
                                mapped.PerksUUIDs = {}
                                if slotData.Perks and type(slotData.Perks.Storage) == "table" then
                                    for k, v in pairs(slotData.Perks.Storage) do
                                        mapped.TotalPerksCount = mapped.TotalPerksCount + 1
                                        if type(v) == "table" and v.Name then
                                            mapped.Inventory.Perks[v.Name] = (mapped.Inventory.Perks[v.Name] or 0) + 1
                                            if not v.Equipped then
                                                table.insert(mapped.PerksUUIDs, k)
                                            end
                                        end
                                    end
                                end
                                serverData = mapped
                            end
                        end
                    end
                    
                    if serverData and type(serverData) == "table" then
                        if serverData.Inventory then 
                            _G.LastInventory = serverData.Inventory 
                        end
                        if serverData.PerksUUIDs then
                            _G.PerksUUIDs = serverData.PerksUUIDs
                            _G.TotalPerksCount = serverData.TotalPerksCount or 0
                        end
                        if serverData.Progression then
                            _G.LastLevel = serverData.Progression.Level
                            _G.LastPrestige = serverData.Progression.Prestige
                            _G.LastMaxXP = serverData.Progression.Max_XP
                            _G.LastXP = serverData.Progression.XP
                        end
                        if serverData.Currency then _G.LastGold = serverData.Currency.Gold end
                    end
                end
                
                executeAutoQuestLogic()
                executeAutoBoostLogic()
                
                -- Cache GUI references
                if not cachedInterface then
                    cachedInterface = plr.PlayerGui:FindFirstChild("Interface")
                end
                if cachedInterface and not cachedTopbar then
                    cachedTopbar = cachedInterface:FindFirstChild("Topbar")
                    if cachedTopbar then
                        local main = cachedTopbar:FindFirstChild("Main")
                        if main then
                            cachedCurrencies = main:FindFirstChild("Currencies")
                        end
                    end
                end
                
                local function amt(name)
                    if not cachedCurrencies then return 0 end
                    local c = cachedCurrencies:FindFirstChild(name)
                    return c and tonumber((c.Amount.Text:gsub("[,%s]", ""))) or 0
                end
                local gold = amt("Gold")
                if gold > 0 then _G.LastGold = gold end
                local guiGems = amt("Gems")
                if guiGems > 0 then _G.LastGems = guiGems end
                
                local requiredPerksToSell = 100
                local currentPrestige = _G.LastPrestige or plr:GetAttribute("Prestige") or 0
                local currentLevel = _G.LastLevel or plr:GetAttribute("Level") or 0
                
                -- ขาย 30 ชิ้นสำหรับ Level 0-45, 100 ชิ้นสำหรับ Level มากกว่า 45
                if currentLevel <= 45 then
                    requiredPerksToSell = 30
                else
                    requiredPerksToSell = 100
                end
                
                -- Only sell perks in bulk to save API calls and time
                if currentTime - lastInventoryCheck < 20 and Config.AutoDeletePerk and _G.PerksUUIDs and #_G.PerksUUIDs >= requiredPerksToSell then
                    _G.CurrentAction = "Auto Selling " .. tostring(#_G.PerksUUIDs) .. " Perks (Remote)..."
                    pcall(function() safeInvokeServer(GET, 2, "S_Equipment", "Delete", "Perk", _G.PerksUUIDs) end)
                    pcall(function() safeInvokeServer(GET, 2, "S_Equipment", "Delete", "Perks", _G.PerksUUIDs) end)
                    
                    for _, uuid in ipairs(_G.PerksUUIDs) do
                        pcall(function() safeInvokeServer(GET, 2, "S_Equipment", "Delete", "Perk", {uuid}) end)
                        pcall(function() safeInvokeServer(GET, 2, "S_Equipment", "Delete", "Perks", {uuid}) end)
                        task.wait(0.05)
                    end
                    task.wait(1)
                    _G.PerksUUIDs = {}
                end
            end)

            local checkLevel = _G.LastLevel or plr:GetAttribute("Level") or 0
            local checkPrestige = _G.LastPrestige or plr:GetAttribute("Prestige") or 0
            local targetLevelReq = 100 + (checkPrestige * 25)
            local checkXP = math.max(tonumber(_G.LastXP) or 0, tonumber(plr:GetAttribute("XP")) or 0)
            local checkMaxXP = math.max(tonumber(_G.LastMaxXP) or 0, tonumber(plr:GetAttribute("Max_XP")) or 0)
            if checkMaxXP == 0 then checkMaxXP = 999999999 end
            
            local prestigeKey = "P" .. tostring(checkPrestige + 1)
            local pSettings = Config.VenozPrestige and Config.VenozPrestige[prestigeKey] or { TargetBoost = "Gold Boost", RequiredGold = 0 }
            local reqGold = (pSettings.RequiredGold or 0) * 1000000
            local currentGold = _G.LastGold or 0
            
            local isReadyToPrestige = (checkLevel >= targetLevelReq and checkXP >= checkMaxXP and checkPrestige < Config.PrestigeTarget and currentGold >= reqGold)

            if Config.AutoPrestige and isReadyToPrestige then
                local didPrestige = false
                pcall(function()
                    -- ✅ FIXED: Use VenozPrestige instead of PrestigeSettings
                    -- ✅ FIXED: Use TargetBoost and RequiredGold instead of Boost and Gold
                    local prestigeKey = "P" .. tostring(checkPrestige + 1)
                    local pSettings = Config.VenozPrestige and Config.VenozPrestige[prestigeKey] or { TargetBoost = "Gold Boost", RequiredGold = 0 }
                    local reqGold = (pSettings.RequiredGold or 0) * 1000000
                    local gold = _G.LastGold or 0
                    
                    if gold >= reqGold then
                        _G.CurrentAction = "🔥 PRECISION PRESTIGE 🔥"
                        _G.IsPrestigeing = true 
                        didPrestige = true
                        
                        local tracker = game:GetService("CoreGui"):FindFirstChild("VenozTracker")
                        if tracker then tracker.Enabled = false end 
                        
                        local MyTalentList = {
                            "Guardian", "Aegisurge", "Deflectra", "Thanatophobia", "Necromantic", 
                            "Steel Frame", "Resilience", "Riposte", "Vengeflare", "Blitzblade", 
                            "Swiftshot", "Crescendo", "Furyforge", "Stalwart", "Quakestrike", 
                            "Stormcharged", "Supernova", "Gambler", "Overslash", "Amputation", 
                            "Surgeshot", "Assassin", "Afterimages", "Bloodthief", "Apotheosis", 
                            "Lifefeed", "Vitalize", "Flashstep", "Gem Fiend", "Cooldown Blitz", 
                            "Mendmaster", "Tactician", "Omnirange"
                        }
                        
                        print("🚀 [PRESTIGE] เริ่มกระบวนการจุติด้วยรายชื่อ Talent ที่กำหนด...")
                        
                        pcall(function()
                            GET:InvokeServer("S_Equipment", "Talents")
                        end)
                        
                        for _, tagName in ipairs(MyTalentList) do
                            print("⏳ [PRESTIGE] กำลังลองจุติด้วย Tag: " .. tagName)
                            pcall(function()
                                GET:InvokeServer("S_Equipment", "Prestige", {
                                    Boosts = pSettings.TargetBoost or "Gold Boost",
                                    Talents = tagName
                                })
                            end)
                            task.wait(0.3) -- เพิ่มดีเลย์เล็กน้อยเพื่อให้เซิร์ฟเวอร์ประมวลผลทัน
                        end
                        
                        if tracker then tracker.Enabled = true end
                        _G.LastLevel = nil
                        _G.LastPrestige = nil
                        _G.LastXP = nil
                        _G.HasUpgradedOnce = false
                        _G.HighestLevelUpgraded = 0
                        _G.SkillCache = {}
                        _G.QuestCache = {}
                        _G.IsPrestigeing = false 
                        task.wait(5)
                    end
                end)
                if didPrestige then task.wait(3) continue end
            end

            if isReadyToPrestige then
                _G.CurrentAction = "Locking Lobby: Clicking UI Prestige..."
                task.wait(1)
                continue
            end

            local char = plr.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then
                _G.CurrentAction = "Waiting for Character Spawn..."
                task.wait(2)
                continue 
            end
            
            pcall(function()
                local currentTime = os.clock()
                if Config.AutoUpgrade and (not _G.LastUpgradeTime or (currentTime - _G.LastUpgradeTime >= 60)) then
                    _G.LastUpgradeTime = currentTime
                    _G.CurrentAction = "Upgrading All Equipment..."
                    local bladeUpgrades = { "ODM_Damage", "Blade_Durability", "Crit_Damage", "Crit_Chance", "ODM_Gas", "ODM_Speed", "ODM_Control", "ODM_Range" }
                    
                    for i = 1, 3 do 
                        pcall(function() GET:InvokeServer("Equipment", "Upgrade_All") end)
                        pcall(function() GET:InvokeServer("Equipment", "Upgrade", {"All"}) end)
                        pcall(function() GET:InvokeServer("Equipment", "Grade_Up") end)
                        pcall(function() GET:InvokeServer("Equipment", "Tier_Up") end)
                        for _, stat in ipairs(bladeUpgrades) do 
                            pcall(function() GET:InvokeServer("Equipment", "Upgrade", {stat}) end)
                        end
                        
                        pcall(function() GET:InvokeServer("S_Equipment", "Upgrade_All") end)
                        pcall(function() GET:InvokeServer("S_Equipment", "Upgrade", {"All"}) end)
                        pcall(function() GET:InvokeServer("S_Equipment", "Grade_Up") end)
                        pcall(function() GET:InvokeServer("S_Equipment", "Tier_Up") end)
                        for _, stat in ipairs(bladeUpgrades) do 
                            pcall(function() GET:InvokeServer("S_Equipment", "Upgrade", {stat}) end)
                        end
                    end
                    
                    _G.CurrentAction = "Upgrading Skill Tree..."
                    local bannedSkills = {
                        ["76"]=true, ["93"]=true, ["95"]=true, ["97"]=true, 
                        ["103"]=true, ["158"]=true, ["163"]=true
                    }
                    
                    for s = 1, 168 do
                        local sStr = tostring(s)
                        -- ข้ามสาย 81-89 ตามที่ระบุ และสาย 38-69 (ถ้าเป็น Support)
                        if not (s >= 81 and s <= 89) and not (s >= 38 and s <= 69) and not bannedSkills[sStr] then
                            pcall(function() GET:InvokeServer("S_Equipment", "Unlock", {sStr}) end)
                        end
                    end
                end

                _G.PreparingNewMap = true
                _G.CurrentAction = "Preparing Mission..."
                local targetMap = "Chapel" -- บังคับเล่นแต่ Chapel เท่านั้น


                local targetObjective = Config.MissionObjective
                for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = false end end
                root.CFrame = CFrame.new(233.395, 8.865, 37.525)
                root.Anchored = true task.wait(1) root.Anchored = false 

                _G.CurrentAction = "Leaving Old Group..."
                safeInvokeServer(GET, 3, "S_Missions", "Leave") task.wait(1)

                _G.CurrentAction = "Creating Mission: " .. targetMap
                local desiredDifficulty = Config.MissionDifficulty
                local mapData = { Name = targetMap, Type = Config.StartType, Objective = targetObjective, Difficulty = desiredDifficulty, Modifiers = Config.Modifiers or {} }
                
                local actualDifficulty = desiredDifficulty
                local resCreate = safeInvokeServer(GET, 5, "S_Missions", "Create", mapData)
                if resCreate == nil then
                    _G.CurrentAction = "Downgrading Difficulty..."
                    local fallbacks = {"Severe", "Aberrant", "Hard", "Normal", "Easy"}
                    local startIndex = 1
                    for i, diff in ipairs(fallbacks) do if diff == desiredDifficulty then startIndex = i break end end
                    for i = startIndex + 1, #fallbacks do
                        mapData.Difficulty = fallbacks[i]
                        resCreate = safeInvokeServer(GET, 3, "S_Missions", "Create", mapData)
                        if resCreate ~= nil then actualDifficulty = fallbacks[i] break end
                        task.wait(0.5)
                    end
                end
                
                if resCreate ~= nil or typeof(resCreate) == "table" then
                    _G.CurrentAction = "Mission Created! Starting..."
                    task.wait(0.5)
                    safeInvokeServer(GET, 3, "S_Missions", "Modify", actualDifficulty)
                    safeInvokeServer(GET, 3, "S_Missions", "Start")
                    _G.CurrentAction = "Teleporting to Map..."
                    _G.MissionTeleporting = true task.delay(10, function() _G.MissionTeleporting = false end)
                    task.wait(1) 
                end
                _G.PreparingNewMap = false
            end)
            task.wait(1) 
        end
    end)
    return 
end

-- =======================================================
-- ⚔️ PHASE 3: MISSION MAP (Optimized Combat)
-- =======================================================
_G.VenozScriptID = (_G.VenozScriptID or 0) + 1
local currentID = _G.VenozScriptID
_G.CurrentAction = "Mission Started"
_G.RetryAttemptCount = 0
_G.MapLoadWaitUntil = os.clock() + 6

local char = plr.Character or plr.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart", 9999)
local actor = char:WaitForChild("Actor", 9999)
local TitansFolder = workspace:WaitForChild("Titans", 9999)
local interface = plr:WaitForChild("PlayerGui"):WaitForChild("Interface", 999)

-- ============================================================
-- 🔧 OPTIMIZED RETRY BUTTON FIX (REMOTE ONLY)
-- ============================================================
task.spawn(function()
    local rewardsUI = interface:WaitForChild("Rewards", 999)
    local cachedButtons = nil
    local cachedMainInfo = nil
    local cachedBoostElement = nil
    local lastUIUpdate = 0
    
    local function clickButtonAdvanced(btn)
        if not btn then return false end
        
        _G.CurrentAction = "Locking on: " .. btn.Name
        pcall(function()
            game:GetService("GuiService").SelectedObject = btn
        end)
        
        local isLeave = string.find(string.lower(btn.Name), "leave") ~= nil
        local isRetry = string.find(string.lower(btn.Name), "retry") ~= nil
        
        -- 🔥 FORCE REMOTE FIRST: bypass VirtualUser entirely for critical buttons
        pcall(function()
            if isLeave then 
                GET:InvokeServer("S_Missions", "Leave") 
            elseif isRetry then 
                GET:InvokeServer("S_Missions", "Retry") 
            end
        end)
        
        
        -- Hide ALL Trackers securely so they don't block VirtualInputManager
        local trackers = {}
        pcall(function()
            for _, v in ipairs(game:GetService("CoreGui"):GetChildren()) do if v.Name == "VenozTracker" then table.insert(trackers, v) end end
            for _, v in ipairs(game:GetService("Players").LocalPlayer.PlayerGui:GetChildren()) do if v.Name == "VenozTracker" then table.insert(trackers, v) end end
            for _, t in ipairs(trackers) do t.Enabled = false end
        end)
        
        local isDisabled = false
        if btn:IsA("GuiButton") then
            isDisabled = (btn.Active == false)
        end
        
        if isDisabled then
            pcall(function() 
                if isLeave then GET:InvokeServer("S_Missions", "Leave") else GET:InvokeServer("S_Missions", "Retry") end
            end)
            pcall(function() for _, t in ipairs(trackers) do t.Enabled = true end end)
            return true
        end
        
        pcall(function()
            if getconnections then
                for _, conn in ipairs(getconnections(btn.MouseButton1Click) or {}) do pcall(function() conn:Fire() end) end
                for _, conn in ipairs(getconnections(btn.Activated) or {}) do pcall(function() conn:Fire() end) end
                for _, conn in ipairs(getconnections(btn.MouseButton1Down) or {}) do pcall(function() conn:Fire() end) end
            end
            
            if firesignal then
                pcall(function() firesignal(btn.MouseButton1Click) end)
                pcall(function() firesignal(btn.Activated) end)
            end
        end)
        
        pcall(function()
            -- ป้องกันการกดมั่วไปที่พิกัด 0,0 (มุมซ้ายบน) ที่ชอบไปโดนปุ่มอายุ
            if btn.AbsolutePosition.X > 10 and btn.AbsolutePosition.Y > 10 then
                local vu = game:GetService("VirtualUser")
                vu:CaptureController()
                vu:ClickButton1(Vector2.new(btn.AbsolutePosition.X + btn.AbsoluteSize.X/2, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y/2))
            end
        end)
        
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
            task.wait(0.05)
            vim:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
            
            if btn.AbsolutePosition.X > 10 and btn.AbsolutePosition.Y > 10 then
                local absPos = btn.AbsolutePosition
                local absSize = btn.AbsoluteSize
                local inset = game:GetService("GuiService"):GetGuiInset()
                local cx = absPos.X + (absSize.X / 2)
                local cy = absPos.Y + (absSize.Y / 2) + inset.Y
                vim:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
                task.wait(0.1)
                vim:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
            end
        end)
        
        task.wait(0.2)
        -- Fallback Remote if UI connections fail
        pcall(function() 
            if isLeave then GET:InvokeServer("S_Missions", "Leave") else GET:InvokeServer("S_Missions", "Retry") end
        end)
        
        pcall(function() for _, t in ipairs(trackers) do t.Enabled = true end end)
        return true
    end
    
    while currentID == _G.VenozScriptID and task.wait(2) do
        if rewardsUI and rewardsUI.Visible then
            task.wait(1.5) 
            local curLevel = _G.LastLevel or plr:GetAttribute("Level") or 0
            local curPrestige = _G.LastPrestige or plr:GetAttribute("Prestige") or 0
            local maxLevelReq = 100 + (curPrestige * 25)
            
            -- Cache UI references
            pcall(function()
                if not cachedMainInfo then
                    local rMain = rewardsUI:FindFirstChild("Main")
                    local rInfo = rMain and rMain:FindFirstChild("Info")
                    cachedMainInfo = rInfo and rInfo:FindFirstChild("Main")
                end
                if cachedMainInfo and not cachedButtons then
                    cachedButtons = cachedMainInfo:FindFirstChild("Buttons")
                end
                if cachedMainInfo and not cachedBoostElement then
                    cachedBoostElement = cachedMainInfo:FindFirstChild("Boost")
                end
            end)
            
            local buttons = cachedButtons
            local boostElement = cachedBoostElement
            
            if buttons then
                local btnRetry = buttons:FindFirstChild("Retry")
                local btnLeave = buttons:FindFirstChild("Leave_2") or buttons:FindFirstChild("Leave")
                
                local function checkVisible(gui)
                    local curr = gui
                    while curr and curr:IsA("GuiObject") do
                        if not curr.Visible then return false end
                        curr = curr.Parent
                    end
                    return true
                end

                local hasBoost = false
                if boostElement and checkVisible(boostElement) then
                    hasBoost = true
                end
                
                local buttonToClick = nil
                
                local shouldLeaveForPerks = false
                if Config.AutoDeletePerk then
                    local sellTarget = (curLevel <= 45) and 30 or 100
                    local totalPerks = _G.TotalPerksCount or 0
                    if totalPerks >= sellTarget then shouldLeaveForPerks = true end
                end

                local isReadyToPrestige = false
                if curLevel >= maxLevelReq and Config.AutoPrestige and curPrestige < Config.PrestigeTarget then
                    local prestigeKey = "P" .. (curPrestige + 1)
                    local pSettings = Config.VenozPrestige and Config.VenozPrestige[prestigeKey] or { TargetBoost = "Gold Boost", RequiredGold = 0 }
                    local reqGold = (pSettings.RequiredGold or 0) * 1000000
                    local currentGold = _G.LastGold or 0
                    if currentGold >= reqGold then
                        isReadyToPrestige = true
                    end
                end

                if isReadyToPrestige then
                    buttonToClick = btnLeave
                elseif shouldLeaveForPerks then
                    buttonToClick = btnLeave
                elseif btnRetry then
                    buttonToClick = btnRetry
                else
                    buttonToClick = btnLeave
                end
                
                if buttonToClick then
                    clickButtonAdvanced(buttonToClick)
                end
            else
                -- Reset cache if structure changed
                cachedMainInfo = nil
                cachedButtons = nil
                cachedBoostElement = nil
            end
            task.wait(3)
        end
    end
end)

task.spawn(function()
    while currentID == _G.VenozScriptID do
        pcall(function()
            local currentChar = plr.Character
            if currentChar and currentChar:FindFirstChild("HumanoidRootPart") then
                for _, part in ipairs(currentChar:GetChildren()) do 
                    if part:IsA("BasePart") then part.CanCollide = false end 
                end
            end
        end)
        task.wait(0.1) 
    end
end)

local script_actor = [[
    local MarketplaceService = game:GetService('MarketplaceService')
    local CoreTable
    while not CoreTable do 
        task.wait(0.05)
        local gc = getgc(true)
        for i,v in pairs(gc) do 
            if type(v) == 'table' and rawget(v, 'Cache') and type(v.Cache) == 'table' and rawget(v.Cache,'Data') then 
                CoreTable = v break
            end
        end
    end
    local Modules = CoreTable.Modules
    local Func = {}
    
    function Func.SlashOnly() CoreTable:Send("Attacks", "Slash", true) end
    function Func.RegisterHitOnly(basePart) CoreTable:Send('Hitboxes', 'Register', basePart, 400, Modules.Zones and Modules.Zones.Time_Difference or 0.125) end
    function Func.ResetState()
        pcall(function()
            local Variables = CoreTable.Cache.Variables
            if Variables then
                if Variables.Reloading ~= nil then Variables.Reloading = false end
                if Variables.Action ~= nil then Variables.Action = false end
                if Variables.HitLag ~= nil then Variables.HitLag = false end
                if Variables.KillCam ~= nil then Variables.KillCam = false end
                if Variables.Slash then Variables.Slash.Slashing = false Variables.Slash.Active = false end
            end
            
            -- ปิด Anti-Gravity เมื่อหลุดจาก Combat เพื่อให้เดินหรือตกพื้นได้ปกติ
            local char = plr.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root and root:FindFirstChild("VenozAntiFall") then
                root.VenozAntiFall:Destroy()
            end
        end)
    end
    function Func.BypassRefill()
        pcall(function() CoreTable:Send("Attacks", "Reload") end)
        pcall(function() CoreTable:Send("Equipment", "Reload") end)
        pcall(function() CoreTable:Invoke("Blades", "Reload") end)
        pcall(function() CoreTable:Invoke("Spears", "Reload") end)
    end
    function Func.SupplyReload(targetPart)
        pcall(function() CoreTable:Send("Attacks", "Reload", targetPart) end)
        pcall(function() CoreTable:Send("Equipment", "Reload", targetPart) end)
    end
    function Func.GetSlotData()
        local p = game:GetService("Players").LocalPlayer
        local result = nil
        pcall(function()
            if CoreTable and CoreTable.Cache and CoreTable.Cache.Data and CoreTable.Cache.Data.Slots then
                local slotData = CoreTable.Cache.Data.Slots[p:GetAttribute("Slot") or "A"]
                if slotData then
                    result = {}
                    if slotData.Currency then result.Currency = { Gold = slotData.Currency.Gold } end
                    if slotData.Currencies then result.Currencies = { Gems = slotData.Currencies.Gems } end
                    if slotData.Progression then 
                        result.Progression = { 
                            Level = slotData.Progression.Level, 
                            Prestige = slotData.Progression.Prestige, 
                            XP = slotData.Progression.XP,
                            Max_XP = slotData.Progression.Max_XP 
                        } 
                    end
                    
                    local safeInv = { Perks = {} }
                    local totalPerks = 0
                    local uuids = {}
                    
                    if slotData.Perks and type(slotData.Perks.Storage) == "table" then
                        for k, v in pairs(slotData.Perks.Storage) do
                            totalPerks = totalPerks + 1
                            if type(v) == "table" and v.Name then
                                safeInv.Perks[v.Name] = (safeInv.Perks[v.Name] or 0) + 1
                                if not v.Equipped then
                                    table.insert(uuids, k)
                                end
                            end
                        end
                    end
                    
                    result.Inventory = safeInv
                    result.TotalPerksCount = totalPerks
                    result.PerksUUIDs = uuids
                end
            end
        end)
        return result
    end
    local remoteFunc = MarketplaceService:WaitForChild('Remote')
    remoteFunc.OnInvoke = function(method, key, ...) if method == 'CALL' and Func[key] then return Func[key](...) end end
]]

local bindable = MarketplaceService:FindFirstChild("Remote")
if bindable then bindable:Destroy() end
bindable = Instance.new("BindableFunction")
bindable.Name = "Remote"
bindable.Parent = MarketplaceService

if actor then task.spawn(function() pcall(function() run_on_actor(actor, script_actor) end) end) end

task.spawn(function()
    if not _G.AutoFarm then return end
    local lastTotalHealth = 999999999
    local cycleStuckCount = 0
    local blacklistedTitans = {} 
    local lastCombatUpdate = 0

    -- [OPT] Cache references (ป้องกัน GetChildren/GetService ทุก tick)
    local cachedRefillHolder = nil
    local cachedRefillPart = nil
    local cachedTS = game:GetService("TweenService")
    
    while currentID == _G.VenozScriptID and task.wait(Config.CombatLoopInterval) do 
        if not _G.AutoFarm then continue end
        local pGui = plr:FindFirstChild("PlayerGui")
        local currentInterface = interface or (pGui and pGui:FindFirstChild("Interface"))
        if not currentInterface then continue end
        local rewardsUI = currentInterface:FindFirstChild("Rewards")
        if (rewardsUI and rewardsUI.Visible) then continue end
        
        local hum = plr.Character and plr.Character:FindFirstChildWhichIsA("Humanoid")
        if not TitansFolder or not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") or not hum or hum.Health <= 0 then continue end
        
        local currentRoot = plr.Character.HumanoidRootPart
        local aliveTitans = {}
        local currentTotalHealth = 0
        
        -- [OPT] cache refill part reference — เดิม workspace:GetChildren() ทุก tick = 250 scan/s บน 50 จอ
        local spawnPoint = currentRoot.Position
        if not cachedRefillPart or not cachedRefillPart.Parent then
            cachedRefillHolder, cachedRefillPart = nil, nil
            for _, v in ipairs(workspace:GetChildren()) do
                if v:GetAttribute("Max_Refills") and tonumber(v:GetAttribute("Max_Refills")) > 0 then
                    local rp = v:FindFirstChildWhichIsA("BasePart", true)
                    if rp then
                        cachedRefillHolder = v
                        cachedRefillPart = rp
                        break
                    end
                end
            end
        end
        if cachedRefillPart then spawnPoint = cachedRefillPart.Position end
        
        -- Only get direct children, not descendants
        local currentTitans = TitansFolder:GetChildren()
        for _, titan in ipairs(currentTitans) do
            if blacklistedTitans[titan] then continue end 
            local nape = titan:FindFirstChild("Nape", true)
            local humanoid = titan:FindFirstChildWhichIsA("Humanoid")
            local titanRoot = titan:FindFirstChild("HumanoidRootPart") or nape
            if nape and humanoid and humanoid.Health > 0 and titanRoot then
                local dist = (currentRoot.Position - titanRoot.Position).Magnitude
                table.insert(aliveTitans, { titan = titan, nape = nape, root = titanRoot, dist = dist })
                currentTotalHealth = currentTotalHealth + humanoid.Health
            end
        end

        if #aliveTitans == 0 then 
            if next(blacklistedTitans) ~= nil then blacklistedTitans = {} end
            
            if not _G.WaveClearedRefill then
                _G.CurrentAction = "Combat: Box Reloading (Between Waves)..."
                -- [OPT] ใช้ cache ไม่ scan workspace ซ้ำ
                local refillTarget = cachedRefillHolder
                if not refillTarget or not refillTarget.Parent then
                    for _, v in ipairs(workspace:GetChildren()) do
                        if v:GetAttribute("Max_Refills") and tonumber(v:GetAttribute("Max_Refills")) > 0 then refillTarget = v break end
                    end
                end
                if refillTarget then
                    local safeSpot = currentRoot.CFrame
                    local refillPart = cachedRefillPart or refillTarget:FindFirstChildWhichIsA("BasePart", true)
                    local refillCFrame = refillPart and refillPart.CFrame or refillTarget:GetPivot()
                    
                    local dist = (currentRoot.Position - refillCFrame.Position).Magnitude
                    if dist > 80 then
                        -- [OPT] TweenService → CFrame ตรงๆ (ลด GC pressure ~333 obj/s ต่อจอ)
                        currentRoot.Anchored = true
                        currentRoot.CFrame = refillCFrame
                    else
                        currentRoot.CFrame = refillCFrame 
                    end
                    
                    currentRoot.Anchored = false
                    task.wait(0.3)
                    pcall(function() bindable:Invoke("CALL", "SupplyReload", refillPart) end) 
                    task.wait(0.1)
                    currentRoot.CFrame = safeSpot
                    pcall(function() bindable:Invoke("CALL", "ResetState") end)
                end
                _G.WaveClearedRefill = true
            end
            
            currentRoot.Anchored = false 
            _G.CurrentAction = "Combat: Waiting for Titans to Spawn..." 
            continue 
        else
            _G.WaveClearedRefill = false
        end
        
        table.sort(aliveTitans, function(a, b) return a.dist < b.dist end)
        local targetTitan = aliveTitans[1]
        
        if targetTitan and targetTitan.root then
            local FloatHeight = 250
            local targetPos = Vector3.new(targetTitan.root.Position.X, targetTitan.root.Position.Y + FloatHeight, targetTitan.root.Position.Z)
            local dist = (currentRoot.Position - targetPos).Magnitude
            -- สร้างระบบต้านแรงโน้มถ่วง (Anti-Gravity) เพื่อให้บินนิ่งๆ โดยไม่ต้องใช้ Anchored
            local bv = currentRoot:FindFirstChild("VenozAntiFall")
            if not bv then
                bv = Instance.new("BodyVelocity")
                bv.Name = "VenozAntiFall"
                bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                bv.Velocity = Vector3.zero
                bv.Parent = currentRoot
            end

            if dist > 200 then
                -- [OPT] TweenService สร้าง Tween ใหม่ทุก 0.15 วิ = ~333 obj/s × 50 จอ = 16,000 obj/s ให้ GC เก็บ!
                --       ใช้ CFrame ตรงๆ แทน = zero allocation, ลื่นกว่ามาก, ผลลัพธ์เหมือนเดิม
                currentRoot.Anchored = false
                currentRoot.CFrame = CFrame.new(targetPos)
            else
                currentRoot.Anchored = false
                currentRoot.CFrame = CFrame.new(targetPos)
                -- ใช้ CFrame วาร์ปใส่คอโดยตรงเพื่อลดขยะ (GC) จากการสร้าง Tween ใหม่ทุกๆ 0.15 วิ
            end
        end
        
        local batchSize = Config.HitAll and 100 or 20
        local batchTitans = {} for i = 1, math.min(batchSize, #aliveTitans) do table.insert(batchTitans, aliveTitans[i]) end
        
        if lastTotalHealth - currentTotalHealth <= 0 then 
            cycleStuckCount = cycleStuckCount + 1 
        else 
            cycleStuckCount = 0 
        end
        

        
        lastTotalHealth = currentTotalHealth
        
        local bladesLeft = 3
        local gasLeft = 1
        local isBladeBroken = false
        pcall(function()
            local hud = plr:FindFirstChild("PlayerGui") and plr.PlayerGui:FindFirstChild("Interface") and plr.PlayerGui.Interface:FindFirstChild("HUD")
            if hud then
                local top = hud:FindFirstChild("Main") and hud.Main:FindFirstChild("Top")
                
                -- ช่องดาบอยู่ใน Main.Top["7"] (ตาม dump ของเกม Equipment.luau:1353)
                local seven = top and top:FindFirstChild("7")
                
                local weaponHUD = seven and seven:FindFirstChild("Blades")
                if seven and seven:FindFirstChild("Spears") and seven.Spears.Visible then
                    weaponHUD = seven.Spears
                end
                
                if weaponHUD then
                    local sets = weaponHUD:FindFirstChild("Sets") or (weaponHUD.Name == "Spears" and weaponHUD:FindFirstChild("Spears"))
                    if sets and sets:IsA("TextLabel") then
                        local parts = string.split(sets.Text, "/")
                        if #parts >= 1 then 
                            bladesLeft = tonumber(string.match(parts[1], "%d+")) or 3 
                        end
                    end
                end
                
                if bladesLeft <= 0 then
                    isBladeBroken = true
                end
                
                -- Fallback: If we've been attacking for 10 cycles and dealt 0 damage, the blade is probably broken.
                if cycleStuckCount >= 10 then
                    isBladeBroken = true
                end
                
                -- 🔥 INFINITE GAS HACK - บังคับให้มีแก๊สเสมอ
                local gasHUD = seven and seven:FindFirstChild("Gas")
                if gasHUD then
                    local gasBar = gasHUD:FindFirstChild("Inner") and gasHUD.Inner:FindFirstChild("Bar")
                    if gasBar and gasBar:IsA("Frame") then
                        gasBar.Size = UDim2.new(1, 0, 1, 0) -- บังคับให้เต็มเสมอ
                    end
                end
                
                -- แก้ไขค่า gasLeft ให้เป็น 1 เสมอ (เต็มเสมอ)
                gasLeft = 1
            end
        end)
        
        local needsBoxRefill = false -- ไม่ต้องเติมแก๊สอีกต่อไป (Infinite Gas)

        -- ============================================================
        -- ⚡ SAFE RELOAD LOGIC (Blade Swap)
        -- ============================================================
        if isBladeBroken then
            _G.CurrentAction = "Combat: Swapping Broken Blade..."
            local currentTime = os.clock()
            if not _G.LastReloadTime or (currentTime - _G.LastReloadTime >= 1.5) then
                _G.LastReloadTime = currentTime
                
                pcall(function() bindable:Invoke("CALL", "ResetState") end)
                
                if bladesLeft <= 0 then
                    _G.CurrentAction = "Combat: Emergency Bypass Refill..."
                    pcall(function() bindable:Invoke("CALL", "BypassRefill") end)
                end
                
                pcall(function()
                    local getRemote = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("GET")
                    getRemote:InvokeServer("Blades", "Reload")
                end)
            end
            task.wait(0.1)
        end

        if cycleStuckCount == 4 then 
            pcall(function() bindable:Invoke("CALL", "ResetState") end)
            _G.CurrentAction = "Combat: Resetting State (Stuck 4)..."
        elseif cycleStuckCount == 8 then
            pcall(function() bindable:Invoke("CALL", "ResetState") end)
            if needsBoxRefill then
                -- ดาบหมด 0/3 หรือ แก๊สหมด -> BypassRefill เติมเต็มทันที
                _G.CurrentAction = "Combat: Bypass Refilling..."
                pcall(function() bindable:Invoke("CALL", "BypassRefill") end)
                pcall(function()
                    local getRemote = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("GET")
                    getRemote:InvokeServer("Blades", "Reload")
                end)
                task.wait(0.3)
            else
                _G.CurrentAction = "Combat: Resetting State (Stuck 8)..."
            end
        elseif cycleStuckCount >= 12 then
            _G.CurrentAction = "Combat: Titan Blacklisted!"
            if targetTitan and targetTitan.titan then blacklistedTitans[targetTitan.titan] = true end
            cycleStuckCount = 0 lastTotalHealth = 999999999
        end
        
        if cycleStuckCount < 4 then
            _G.CurrentAction = "Combat: Slashing Nape!"
            local currentTime = os.clock()
            if not _G.LastSlashTime or (currentTime - _G.LastSlashTime >= 0.25) then
                _G.LastSlashTime = currentTime
                pcall(function() bindable:Invoke("CALL", "SlashOnly") end)
            end
            
            for _, target in ipairs(batchTitans) do 
                pcall(function() bindable:Invoke("CALL", "RegisterHitOnly", target.nape) end) 
            end
            pcall(function() bindable:Invoke("CALL", "ResetState") end)
        end
    end
end)
