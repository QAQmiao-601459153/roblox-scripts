-- ============================================================
-- NARAMO 终极版
-- 修复 1: 关闭残留 —— 连接登记 + 线程取消 + 原值还原（参考 xk 的 OnUnload/RemoveAll）
-- 修复 2: 配置回填 —— 控件注册表 SetControl，UI 与 State 同步（参考 SaveManager 的 SetValue）
-- 新增 3: 无限子弹改为真锁 —— 元表 __index 恒 9999 / __newindex 丢弃写入，锁不上才逐帧写回
-- 新增 4: 打僵尸分区 —— NPC 绘制 + NPC 自瞄，两个独立开关，附「扫描诊断」自查工具
-- 改动 5: 新增「即时互动」(移植自 xk 新版通用)；移除「推进方向反转」
-- 改动 6: 「PM秒维修」—— 维修小游戏一弹出就直接发 Repair 跳过小游戏，多次维修之间间隔为 0
-- 改动 7: 新增「PM 靠近自动维修」—— 靠近带 RepairObject 标签的设备就自动补满耐久，不用等小游戏
-- 改动 8: 新增「简介」分区（放在最上面）：脚本信息 / 免责声明 / 一键复制 QQ 群号
-- 改动 9: 新增「踏空行走」(移植自 xk 主页面)：脚下铺隐形平台，可在空中站立/行走
-- 改动 10: 新增「PM全场自动维修」：自动开穿墙/自动维修/移速50，定高滑行巡回全场维修点
-- 修复 11: UI 打不开 —— 顶层局部变量超过 Lua 的 200 个上限导致编译失败，已收束到 187 个
-- 修复 12: 巡回被椅子吸住 —— 每帧强制起身（Sit=false / Jump / 拆 SeatWeld），2 秒脱不掉就弹一下
-- 修复 13: 持续掉耐久的设备 —— 耐久高于阈值不修 + 修过后进入冷却，不再一圈圈来回跑
-- 修复 14: 高耐久设备修不满 —— 到点后停在旁边反复补，修满或超时才走（单台最多停留可调）
-- 新增 15: 巡回时标记当前目标 —— 橙色高亮 + 头顶置顶圆点，随时看得到下一台要修哪
-- ============================================================

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- 版本号：启动日志里会带上，方便确认跑的是哪一版
local SCRIPT_VERSION = "2026-11-01 r42 · 目标高亮标记 / 停留修满"

-- ============================ 全局状态 ============================
local State = {
    InfJump = false, Noclip = false, FullBright = false, UnlockChat = false, UnlockFPS = false,
    -- 踏空行走（移植自 xk）：脚下铺隐形锚定平台，可以在空中站立与行走
    SkyWalk = false,
    -- 即时互动（移植自 xk）：提示按住时长归零 / 点击距离放大
    InstantInteract = false,
    -- PM 秒维修：检测到维修小游戏界面就直接发 Repair，跳过小游戏
    -- WrenchAutoRepair：靠近可修设备（WrenchAutoDist 内）就自动补满耐久
    WrenchRepair = false, WrenchAutoRepair = false, WrenchAutoDist = 20,
    -- 全场自动维修：逐个巡回全场可修设备；WrenchTourPoints 是可选的预设坐标兜底
    WrenchTour = false, WrenchTourSpeed = 50, WrenchTourArrive = 12, WrenchTourPoints = {}, WrenchTourHold = 8,
    -- 巡回时标记当前目标（高亮 + 头顶圆点）
    WrenchTourMark = true,
    -- 重复维修冷却（秒）与“耐久高于多少就不修”的阈值（%）：对付持续掉耐久的设备
    WrenchTourCooldown = 180, WrenchSkipAbove = 95,
    InfiniteAmmo = false, AmmoFields = "", AmmoPollOnly = false,
    ESPEnabled = false, ESPBox = true, ESPName = true, ESPDistance = true, ESPHealth = true, ESPTracer = true, ESPHighlight = false, ESPColorIdx = 1,
    ESPMaxDist = 1000,
    ESPTeammates = false,
    -- 队伍检测（管理 / 高价值目标）
    -- 这游戏的小队伍在玩家属性 Unit / SubUnit 里，不在 Teams 服务
    TeamHighlightEnabled = true, TeamNotifyEnabled = true,
    AdminTeamKeywords = "联邦,government,federal,admin,moderator,staff",
    HVTeamKeywords = "plantdirector,总监",
    AimbotEnabled = false, AimbotFOV = 120, ShowFOV = true, TargetPart = "Head", AimbotPredict = true, AimbotSpeed = 1000,
    AimMaxDist = 1000,
    AimMobileActive = false, NpcAimMobileActive = false,
    -- 打僵尸 / NPC（活动功能，绘制与自瞄各自独立）
    NPCESPEnabled = false, NPCESPBox = true, NPCESPName = true, NPCESPHealth = true, NPCESPDistance = true,
    NPCESPLimit = 60, NPCESPMaxDist = 800, NPCNameFilter = "", NPCHitboxMode = true,
    NPCAimEnabled = false, NPCAimFOV = 200,
    -- 车辆调校
    VehiclePushEnabled = false, VehiclePushSpeed = 120,
    VehiclePushBrake = true, VehiclePushAutoCal = true,
    VehicleTurnEnabled = false, VehicleTurnRate = 180, VehiclePushSmooth = 12,
    -- 车辆低空悬浮（只贴地托起，不做自由升降；服务器会检测高度，飞高扣车血）
    VehicleHoverEnabled = false, VehicleHoverHeight = 8, VehicleHoverGain = 8,
    UserList = {},
    AutoCheck = false, CheckInterval = 5, AutoExit = false, DisableOnAdmin = false,
    WalkSpeedEnabled = false, WalkSpeedValue = 16,
}

local Colors = {
    Color3.fromRGB(255, 50, 50), Color3.fromRGB(255, 255, 50),
    Color3.fromRGB(50, 255, 50), Color3.fromRGB(200, 50, 255),
    Color3.fromRGB(255, 255, 255)
}
local TEAMMATE_COLOR = Color3.fromRGB(80, 230, 120)   -- 队友专用色

local ESPObjects = {}
local AutoCheckThread = nil
local AmmoTables = {}
local AmmoBackup = {}
local CONFIG_FOLDER = "NARAMO_Configs"

-- ============ 生命周期管理（参考 xk: OnUnload / ih:RemoveAll 的做法） ============
-- 所有 Connect 都登记到 Connections，所有常驻循环登记到 Threads，
-- 关闭时统一 Disconnect / task.cancel，避免"关掉面板但后台还在跑"。
local IsClosing = false
local Connections = {}
local Threads = {}
local UIControls = {}      -- State 字段名 -> UI 控件回填函数
local ClearAllESP          -- 前向声明，ESP 段内赋值
local ClearAllNPCESP       -- 前向声明，NPC 段内赋值
local GetVehicleBasePart   -- 前向声明，车辆段内赋值
local GetPlayerTeamText    -- 前向声明，ESP 段内赋值
local GetPlayerTag         -- 前向声明，ESP 段内赋值
local MatchKeywords        -- 前向声明，ESP 段内赋值
local ESPFolder            -- 前向声明，ESP 段内赋值

local function Track(conn)
    table.insert(Connections, conn)
    return conn
end

local function TrackThread(co)
    table.insert(Threads, co)
    return co
end

-- 配置回填时用它把 UI 和 State 一起更新（等价于 xk 里的 控件:SetValue）
local function SetControl(key, value)
    local setter = UIControls[key]
    if setter then
        local ok, err = pcall(setter, value)
        if not ok then warn("[NARAMO] 控件刷新失败: " .. tostring(key) .. " -> " .. tostring(err)) end
        return ok
    end
    State[key] = value
    return false
end

local function DeepCopy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = DeepCopy(v) end
    return out
end

local DefaultState = DeepCopy(State)

-- 记录进服时的原始光照，关闭时按原值还原（不再硬编码 Brightness=1/FogEnd=1000）
local LightingBackup = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    GlobalShadows = Lighting.GlobalShadows,
    FogStart = Lighting.FogStart,
    FogEnd = Lighting.FogEnd,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
}

local function RestoreLighting()
    pcall(function()
        Lighting.Brightness = LightingBackup.Brightness
        Lighting.ClockTime = LightingBackup.ClockTime
        Lighting.GlobalShadows = LightingBackup.GlobalShadows
        Lighting.FogStart = LightingBackup.FogStart
        Lighting.FogEnd = LightingBackup.FogEnd
        Lighting.Ambient = LightingBackup.Ambient
        Lighting.OutdoorAmbient = LightingBackup.OutdoorAmbient
    end)
end

local function ResetState()
    for k, v in pairs(DefaultState) do
        State[k] = DeepCopy(v)
    end
end

-- 聊天框原始状态（"解锁聊天框"关闭时按原样还原，而不是强行改成 false）
local ChatBackup = true
pcall(function() ChatBackup = game:GetService("TextChatService").ChatWindowConfiguration.Enabled end)

-- Drawing 能力探测：不支持 Drawing 的执行器不会整段报错
local HasDrawing = false
local FOVCircle = nil
local LockText = nil          -- 准心右下角的红色"锁定中"提示
pcall(function()
    local probe = Drawing.new("Square")
    probe.Visible = false
    probe:Remove()
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Thickness = 1.5
    FOVCircle.NumSides = 64
    FOVCircle.Color = Color3.fromRGB(0, 255, 150)
    LockText = Drawing.new("Text")
    LockText.Size = 15
    LockText.Center = false
    LockText.Outline = true
    LockText.Color = Color3.fromRGB(255, 45, 45)
    LockText.Visible = false
    HasDrawing = true
end)
if not HasDrawing then
    print("[NARAMO] 当前执行器不支持 Drawing，绘制/ESP/FOV 圈已禁用，其余功能正常")
end

pcall(function()
    if not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end
end)

-- ============================ 无限子弹：扫描 + 锁定 ============================
local AMMO_VALUE = 9999

-- 默认字段名。不是你游的字段就在「弹药字段名」里补真实字段（逗号分隔）
local BASE_AMMO_FIELDS = { "MagCapacity", "ReservedAmmo", "currentclip", "clip" }
local AmmoKeyList = {}    -- 数组：当前生效的全部字段名
local AmmoKeySet = {}     -- 集合：给 __index / __newindex 闭包用
local AmmoLocks = {}      -- tbl -> { mt = 新元表, prevMT = 原元表 }
local AmmoLocked = {}     -- tbl -> true，供 __index / __newindex 闭包判断
local AmmoNextScan = 0    -- 下一次自动重扫的时间（os.clock）
local AmmoDeepScan = true -- 下一次扫描是否做"按名字宽松"的深扫（重）
local AmmoInstances = {}  -- 实例型弹药（TAmmo / LocalTAmmo 这类 Folder 里的数值）
local AmmoInstanceScanAt = 0
local AmmoInstanceWriteAt = 0
local RefreshAmmoInstances   -- 前向声明，下面赋值
local IsConstrainedValue     -- 前向声明，下面赋值

-- 默认字段一个都找不到时的兜底：按名字宽松匹配
-- 只放弹药专用词，刻意不含 round / mag（会误伤 RoundCount、Magnitude 之类的字段）
local AMMO_PATTERNS = { "ammo", "clip", "bullet", "magazine", "reserve" }
local function IsAmmoName(name)
    if type(name) ~= "string" then return false end
    local lk = string.lower(name)
    for _, w in ipairs(AMMO_PATTERNS) do
        if string.find(lk, w, 1, true) then return true end
    end
    return false
end

-- 这两个表必须原地改：锁的 __index / __newindex 闭包持有的是它们的引用
local function RebuildAmmoKeys()
    for k in pairs(AmmoKeySet) do AmmoKeySet[k] = nil end
    local merged = {}
    for _, name in ipairs(BASE_AMMO_FIELDS) do
        if not AmmoKeySet[name] then AmmoKeySet[name] = true; table.insert(merged, name) end
    end
    local extra = State.AmmoFields
    if type(extra) == "string" and extra ~= "" then
        for name in string.gmatch(extra, "[^,%s]+") do
            if not AmmoKeySet[name] then
                AmmoKeySet[name] = true
                table.insert(merged, name)
            end
        end
    end
    for i = #AmmoKeyList, 1, -1 do AmmoKeyList[i] = nil end
    for _, name in ipairs(merged) do table.insert(AmmoKeyList, name) end
end
RebuildAmmoKeys()

local function HasAmmoField(tbl)
    for _, name in ipairs(AmmoKeyList) do
        if type(rawget(tbl, name)) == "number" then return true end   -- 只认数字，避免误伤文本/配置字段
    end
    return false
end

local function BackupAmmoFields(tbl)
    local backup, any = {}, false
    for _, name in ipairs(AmmoKeyList) do
        local v = rawget(tbl, name)
        if type(v) == "number" then backup[name] = v; any = true end
    end
    if not any then return nil end
    return backup
end

local function GetRawMetatableSafe(t)
    local ok, mt = pcall(getrawmetatable, t)
    if ok then return mt end
    return getmetatable(t)
end

local function UpdateAmmoTable(deep)
    if not State.InfiniteAmmo then return end
    RebuildAmmoKeys()
    local seen, list = {}, {}
    -- 已锁住的表要保留：它们原始字段被摘掉了，重新扫描是扫不到的
    for _, tbl in ipairs(AmmoTables) do
        if AmmoLocked[tbl] and not seen[tbl] then
            seen[tbl] = true
            table.insert(list, tbl)
        end
    end
    local fixedFound = 0
    for _, obj in pairs(getgc(true)) do
        if type(obj) == "table" and not seen[obj] then
            if HasAmmoField(obj) then
                seen[obj] = true
                table.insert(list, obj)
                -- 先记下原值，关闭无限子弹时才能还原（同 xk 的 fg[gx] 存原尺寸）
                if not AmmoBackup[obj] then AmmoBackup[obj] = BackupAmmoFields(obj) end
                fixedFound = fixedFound + 1
            end
        end
    end

    -- 默认字段一个都没命中 → 按名字宽松再扫一遍（不少游戏的字段叫 Ammo / Clip / Magazine）
    -- 这个扫法要把每个表的键都过一遍，比较重，只在"深扫"时做（开开关 / 重生 / 手动按钮）
    if deep and fixedFound == 0 then
        for _, obj in pairs(getgc(true)) do
            if type(obj) == "table" and not seen[obj] then
                local fields = nil
                for k, v in pairs(obj) do
                    if type(v) == "number" and IsAmmoName(k) then
                        fields = fields or {}
                        fields[k] = v
                    end
                end
                if fields then
                    seen[obj] = true
                    table.insert(list, obj)
                    AmmoBackup[obj] = fields
                    if #list >= 30 then break end    -- 兜底模式最多锁 30 个表，避免误伤
                end
            end
        end
    end

    AmmoTables = list
end

-- 给单个表上锁：把弹药字段从原始表里摘掉，让读写都走元表
--   读 -> __index 恒返回 9999
--   写 -> __newindex 直接丢弃（游戏想改成别的值也改不进去）
local function LockAmmoTable(tbl)
    if State.AmmoPollOnly then return false end   -- 兼容模式：只轮询写回，不动元表
    if AmmoLocked[tbl] then return true end
    local backup = AmmoBackup[tbl]
    if not backup then return false end
    local frozen = false
    pcall(function() frozen = table.isfrozen(tbl) end)
    if frozen then return false end

    -- 用"这张表实际找到的字段"来锁，而不是全局字段表
    local keys = {}
    for k in pairs(backup) do keys[k] = true end
    if next(keys) == nil then return false end

    local prevMT = GetRawMetatableSafe(tbl)
    local prevIndex = prevMT and rawget(prevMT, "__index") or nil
    local prevNewIndex = prevMT and rawget(prevMT, "__newindex") or nil

    -- 复制一份元表再改，不碰原元表（原元表可能被别的对象共用）
    local newMT = {}
    if prevMT then
        pcall(function() for k, v in pairs(prevMT) do newMT[k] = v end end)
    end
    newMT.__index = function(t, k)
        if keys[k] and AmmoLocked[t] then return AMMO_VALUE end
        if type(prevIndex) == "function" then return prevIndex(t, k) end
        if type(prevIndex) == "table" then return prevIndex[k] end
        return nil
    end
    newMT.__newindex = function(t, k, v)
        if keys[k] and AmmoLocked[t] then return end   -- 锁死：丢弃写入
        if type(prevNewIndex) == "function" then prevNewIndex(t, k, v) else rawset(t, k, v) end
    end

    if not pcall(setmetatable, tbl, newMT) then return false end   -- 受保护元表会失败
    AmmoLocked[tbl] = true
    for k in pairs(keys) do
        if rawget(tbl, k) ~= nil then pcall(rawset, tbl, k, nil) end
    end
    AmmoLocks[tbl] = { mt = newMT, prevMT = prevMT }
    return true
end

local function UnlockAmmoTable(tbl)
    local lock = AmmoLocks[tbl]
    if not lock then return end
    AmmoLocked[tbl] = nil
    AmmoLocks[tbl] = nil
    pcall(setmetatable, tbl, lock.prevMT)
    local backup = AmmoBackup[tbl]
    if backup then
        for k, v in pairs(backup) do
            if v ~= nil then pcall(rawset, tbl, k, v) end
        end
    end
end

local function LockAllAmmo()
    for _, tbl in ipairs(AmmoTables) do LockAmmoTable(tbl) end
end

local function RestoreAmmoTable()
    local list = {}
    for tbl in pairs(AmmoBackup) do table.insert(list, tbl) end
    for _, tbl in ipairs(list) do
        if AmmoLocks[tbl] then
            UnlockAmmoTable(tbl)        -- 还原元表 + 原值
        else
            local backup = AmmoBackup[tbl]
            if backup then
                for k, v in pairs(backup) do
                    if v ~= nil then pcall(rawset, tbl, k, v) end
                end
            end
        end
    end
    AmmoBackup = {}
    AmmoTables = {}
    AmmoLocks = {}
    AmmoLocked = {}
end

-- 逐帧：定时重扫（游戏重置/换枪后会有新的弹药表）+ 写回 + 元表健康检查
Track(RunService.Heartbeat:Connect(function()
    if IsClosing or not State.InfiniteAmmo then return end

    -- 每 10 秒重扫一次：重置/换枪/重生后新的弹药对象才能被锁上
    local now = os.clock()
    if now >= AmmoNextScan then
        AmmoNextScan = now + 10
        UpdateAmmoTable(AmmoDeepScan)
        AmmoDeepScan = false
        LockAllAmmo()
    end

    -- 实例型弹药（TAmmo / LocalTAmmo）：每 2 秒重收，每 0.1 秒写一次（同别人脚本的轮询手感）
    if now >= AmmoInstanceScanAt then
        AmmoInstanceScanAt = now + 2
        RefreshAmmoInstances()
    end
    if now >= AmmoInstanceWriteAt then
        AmmoInstanceWriteAt = now + 0.1
        for _, v in ipairs(AmmoInstances) do
            if v.Parent then
                pcall(function()
                    -- 带上下限的类（DoubleConstrainedValue）要先把上限抬高，否则 9999 会被夹回原值
                    if IsConstrainedValue(v) then
                        pcall(function() v.MaxValue = 1e9 end)
                    end
                    local cur = v.Value
                    if type(cur) == "number" and cur ~= AMMO_VALUE then v.Value = AMMO_VALUE end
                end)
            end
        end
    end

    for _, tbl in ipairs(AmmoTables) do
        if AmmoLocked[tbl] then
            local lock = AmmoLocks[tbl]
            if lock and GetRawMetatableSafe(tbl) ~= lock.mt then
                UnlockAmmoTable(tbl)
                LockAmmoTable(tbl)
            end
        else
            -- 锁不上的表：按这张表实际找到的字段逐帧写回
            local backup = AmmoBackup[tbl]
            if backup then
                for k in pairs(backup) do
                    if type(rawget(tbl, k)) == "number" then pcall(rawset, tbl, k, AMMO_VALUE) end
                end
            end
        end
    end
end))

-- 换枪 / 拿到新工具时立刻安排一次重扫，不用等 10 秒
pcall(function()
    local function watchBackpack(bp)
        if not bp then return end
        Track(bp.ChildAdded:Connect(function() AmmoNextScan = 0; AmmoDeepScan = true end))
    end
    watchBackpack(LocalPlayer:FindFirstChildOfClass("Backpack"))
    Track(LocalPlayer.ChildAdded:Connect(function(child)
        if child:IsA("Backpack") then watchBackpack(child) end
    end))
end)

local function AmmoStatusText()
    local locked, names = 0, {}
    for _ in pairs(AmmoLocked) do locked = locked + 1 end
    for _, backup in pairs(AmmoBackup) do
        for k in pairs(backup) do names[k] = true end
    end
    local list = {}
    for k in pairs(names) do table.insert(list, k) end
    table.sort(list)
    return string.format("弹药表 %d 个，已锁定 %d 个，实际字段 [%s]，实例弹药 %d 个",
        #AmmoTables, locked, table.concat(list, ","), #AmmoInstances)
end

-- 实例型弹药：TAmmo / LocalTAmmo 这类 Folder 里的数值对象
-- 注意：这游戏用的是 DoubleConstrainedValue（旧式带上下限的数值类），不是 IntValue
local function IsAmmoValueObject(obj)
    return obj:IsA("IntValue") or obj:IsA("NumberValue")
        or obj:IsA("DoubleConstrainedValue") or obj:IsA("IntConstrainedValue")
end

IsConstrainedValue = function(obj)
    return obj:IsA("DoubleConstrainedValue") or obj:IsA("IntConstrainedValue")
end

-- 这条路不需要 getgc，专门对付"getgc 只返回 Instance"的执行器
RefreshAmmoInstances = function()
    local list, seen = {}, {}

    -- 往上找 6 层，只要祖先里有个名字带 ammo 的文件夹（TAmmo / LocalTAmmo）就算弹药
    local function InAmmoContainer(obj)
        local node = obj
        for _ = 1, 6 do
            node = node.Parent
            if not node then return false end
            if node:IsA("Tool") then return false end
            if string.find(string.lower(node.Name), "ammo", 1, true) then return true end
        end
        return false
    end

    local function addFrom(root)
        pcall(function()
            for _, obj in ipairs(root:GetDescendants()) do
                if IsAmmoValueObject(obj) and not seen[obj] then
                    local name = string.lower(obj.Name)
                    if string.find(name, "ammo", 1, true) or InAmmoContainer(obj) then
                        seen[obj] = true
                        table.insert(list, obj)
                    end
                end
            end
        end)
    end
    local char = LocalPlayer.Character
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") then addFrom(tool) end
        end
    end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") then addFrom(tool) end
        end
    end
    AmmoInstances = list
end

-- ============================ 车辆：强制推进 / 强制转向 ============================
-- 整段包进 do ... end：段内十几个局部变量用完即释放，不占顶层 200 个名额；
-- 外面（车辆页的「重新校准车头方向」按钮）要用的三个先声明在这里。
local VehicleForward, ForwardWarned, ForwardCalib
do
local function GetCurrentVehicleSeat()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local seat = hum and hum.SeatPart
    if seat and seat:IsA("VehicleSeat") then return seat end
    return nil
end

-- 找车体上用来加力的部件
GetVehicleBasePart = function(seat)
    local model = seat
    while model.Parent and model.Parent:IsA("Model") do model = model.Parent end
    local core = model:FindFirstChild("Core", true)
        or model.PrimaryPart
        or model:FindFirstChildWhichIsA("BasePart", true)
    return core, model
end

-- 油门状态：1 前进 / -1 倒车 / 0 松开
-- 键盘优先（W / S）；没有键盘输入时退回座位自己的 Throttle（手机摇杆、手柄）
local function GetThrottleState(seat)
    local w = UserInputService:IsKeyDown(Enum.KeyCode.W)
    local s = UserInputService:IsKeyDown(Enum.KeyCode.S)
    if w and not s then return 1 end
    if s and not w then return -1 end
    if w and s then return 0 end
    local ok, th = pcall(function() return seat.Throttle end)
    if ok and type(th) == "number" then
        if th > 0.05 then return 1 end
        if th < -0.05 then return -1 end
    end
    return 0
end

-- 车头方向：不再猜，改成实测。
-- 各种车的模型轴向完全不一样（朝后、朝侧、斜 45° 都有），靠 LookVector 永远猜不准；
-- 所以这里让游戏自己把车开起来，采集「速度在变大时」的世界方向，
-- 转成车体局部坐标存起来——之后不管模型怎么建、车身怎么转，换回世界方向都是对的。
VehicleForward = {}          -- [模型名] = 车体局部空间里的车头单位向量
ForwardCalib = { acc = nil, hits = 0, lastSpeed = 0 }
ForwardWarned = {}

-- 学到的方向存进 getgenv：脚本重载后不用重新学一遍（同一辆车、同一场对局内）
pcall(function()
    if type(getgenv) == "function" then
        local g = getgenv()
        if type(g.NARAMO_VEHICLE_FORWARD) == "table" then
            VehicleForward = g.NARAMO_VEHICLE_FORWARD
        else
            g.NARAMO_VEHICLE_FORWARD = VehicleForward
        end
    end
end)

-- 采样。返回 true 表示「本帧正在采样，不要推进也不要刹车」，让游戏按它自己的方向加速
local function UpdateForwardCalibration(base, model, throttle, speed, horizontal)
    local name = (model and model.Name) or "?"
    if VehicleForward[name] then return false end            -- 已经校准过
    if not State.VehiclePushAutoCal then return false end     -- 用户关掉了自动校准
    if State.VehicleHoverEnabled then return false end        -- 悬浮时轮胎离地，游戏推不动，采不到有效样本

    -- 只在「踩 W + 正在加速」时取样：减速阶段（比如刚倒完车）方向会反，不能要
    local sampling = (throttle == 1 and speed > 8 and speed > ForwardCalib.lastSpeed + 0.005)
    ForwardCalib.lastSpeed = speed

    if not sampling then
        ForwardCalib.acc, ForwardCalib.hits = nil, 0
        return false
    end

    local dir = horizontal.Unit
    if not ForwardCalib.acc or ForwardCalib.acc:Dot(dir) < 0.9 then
        ForwardCalib.acc, ForwardCalib.hits = dir, 1          -- 方向不稳（正在转弯），重新开始
    else
        ForwardCalib.acc = ForwardCalib.acc + dir
        ForwardCalib.hits = ForwardCalib.hits + 1
    end

    if ForwardCalib.hits >= 6 and ForwardCalib.acc.Magnitude > 0.1 then
        VehicleForward[name] = base.CFrame:VectorToObjectSpace(ForwardCalib.acc.Unit)
        ForwardCalib.acc, ForwardCalib.hits = nil, 0
        print("[NARAMO] 车头方向已校准: " .. name)
        return false                                          -- 校准完成，本帧开始推进
    end
    return true
end

-- 车头朝向（压平）：优先用实测结果；还没实测过就先拿座位朝向兜底并提示一次
local function GetVehicleForward(base, seat, model)
    local name = model and model.Name
    local dir = nil
    local localDir = name and VehicleForward[name]
    if localDir then
        dir = base.CFrame:VectorToWorldSpace(localDir)
    else
        dir = (seat or base).CFrame.LookVector
        if name and not ForwardWarned[name] then
            ForwardWarned[name] = true
            print("[NARAMO] " .. name .. " 还没校准车头方向，先用座位朝向兜底；在地上按住 W 开一下会自动校准")
        end
    end
    local flat = Vector3.new(dir.X, 0, dir.Z)
    if flat.Magnitude < 0.05 then
        local fb = base.CFrame.LookVector
        flat = Vector3.new(fb.X, 0, fb.Z)
        if flat.Magnitude < 0.05 then return nil end
    end
    flat = flat.Unit
    return flat
end

-- 速度强制推进（逐帧平滑版）
--   1) 方向来自「实测」：见上面的 UpdateForwardCalibration。不再用模型 LookVector
--      （各种车轴向乱飞），也不再沿当前速度加速（以前那点反向速度会被一路放大成
--      "按 W 反而往车屁股方向冲"）；
--   2) 松油门（W / S 都没按）→ 水平速度直接清零，立即刹停；按住 S 倒车时不介入；
--   3) 只改水平速度，保留竖直分量，避免上下坡和悬浮高度被抹平。
local function ApplyVehiclePush(dt)
    local seat = GetCurrentVehicleSeat()
    if not seat then return end
    local base, model = GetVehicleBasePart(seat)
    if not base or not base:IsA("BasePart") then return end

    local v = base.AssemblyLinearVelocity
    local horizontal = Vector3.new(v.X, 0, v.Z)
    local speed = horizontal.Magnitude
    local target = State.VehiclePushSpeed
    local throttle = GetThrottleState(seat)

    -- 方向采样中：本帧不推也不刹，让游戏自己把车开起来，我们只负责记方向
    if UpdateForwardCalibration(base, model, throttle, speed, horizontal) then return end

    local forward = GetVehicleForward(base, seat, model)
    if not forward then return end

    if throttle <= 0 then
        if throttle == 0 and State.VehiclePushBrake then
            -- 松开油门：立刻停。悬浮/低摩擦地面上没有任何阻力，不主动刹会一直滑。
            -- 真在空中（没开悬浮、竖直速度很大）就不硬刹：停半空不自然，速度突变也容易被判异常
            local airborne = (not State.VehicleHoverEnabled) and math.abs(v.Y) > 40
            if not airborne then
                pcall(function()
                    base.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0)
                end)
            end
        end
        return                             -- 倒车（-1）交给游戏原来的倒挡，这里不碰
    end

    -- 还没校准、又在地面上：这一帧先别推，让游戏自己把车加速起来，好让采样拿到真实方向。
    -- 校准完成后（约 0.1 秒）会自动切到实测车头，之后就不会再有这个空窗。
    local calibrated = model and VehicleForward[model.Name] ~= nil
    if State.VehiclePushAutoCal and not calibrated and not State.VehicleHoverEnabled then
        return
    end

    -- 沿车头方向的「有符号」速度：正 = 朝前，负 = 正在往后溜
    local signed = horizontal:Dot(forward)

    if math.abs(signed) <= 3 then           -- 还没起步
        -- 地面上本来靠游戏自己的引擎起步；悬浮时引擎推不动，这里补一脚起步推力
        if State.VehicleHoverEnabled then
            local startSpeed = math.min(target, 40)
            pcall(function()
                base.AssemblyLinearVelocity = Vector3.new(forward.X * startSpeed, v.Y, forward.Z * startSpeed)
            end)
        end
        return
    end

    if signed >= target then return end

    local k = math.clamp((State.VehiclePushSmooth or 12) * dt, 0, 1)
    local newSpeed = signed + (target - signed) * k
    pcall(function()
        base.AssemblyLinearVelocity = Vector3.new(forward.X * newSpeed, v.Y, forward.Z * newSpeed)
    end)
end

-- 强制转向：按住 A / D 逐帧旋转车体（绕竖轴，原地也能掉头）
local function ApplyVehicleTurn(dt)
    local seat = GetCurrentVehicleSeat()
    if not seat then return end
    local base = GetVehicleBasePart(seat)
    if not base or not base:IsA("BasePart") then return end

    local turn = 0
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then turn = turn + 1 end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then turn = turn - 1 end
    if turn == 0 then return end

    local delta = math.rad(State.VehicleTurnRate) * turn * math.clamp(dt or 0.016, 0.001, 0.05)
    pcall(function()
        local cf = base.CFrame
        base.CFrame = CFrame.new(cf.Position) * CFrame.Angles(0, delta, 0) * (cf - cf.Position)
    end)
end

-- 车辆固定高度悬浮：位置和姿态全部由我们接管，车头不会翘，高速也不会在空中翻转。
-- 之前只写「竖直速度」，俯仰/横滚仍归物理管：加速时轮子的反作用力会把车头抬起来，
-- 高速再被地形顶一下就在空中翻过去。现在每帧直接摆正车体：
--   1) 高度钉在「地面 + height」上（每帧位移有上限，不做瞬移），且硬夹在 HOVER_MAX 以内；
--   2) 姿态只保留朝向 yaw，俯仰/横滚一律归零 → 整车永远是平的；
--   3) 角速度清零，避免残余旋转继续把车带翻；
--   4) 测不到地面（悬空 / 虚空 / 掉崖）就放手，让车正常下落，绝不在天上悬停。
local HOVER_MAX = 20            -- 离地硬上限（studs），再高就可能被服务器判"飞天"
local HoverRayParams = RaycastParams.new()
pcall(function() HoverRayParams.FilterType = Enum.RaycastFilterType.Blacklist end)

local function ApplyVehicleHover(dt)
    local seat = GetCurrentVehicleSeat()
    if not seat then return end
    local base, model = GetVehicleBasePart(seat)
    if not base or not base:IsA("BasePart") then return end

    -- 射线要排除车体本身和角色，否则打到自己的底盘/轮子上
    local ignore = { base }
    if model then table.insert(ignore, model) end
    if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
    HoverRayParams.FilterDescendantsInstances = ignore

    local cf = base.CFrame
    local pos = cf.Position
    local look = cf.LookVector
    local yaw = math.atan2(-look.X, -look.Z)     -- 只留朝向，丢掉俯仰和横滚

    -- 车头 / 车身 / 车尾各探一条射线，取脚下最高的地面：
    -- 只探车身中心的话，上坡时车头会先顶进坡里，被物理顶得翘起来
    local forward = Vector3.new(look.X, 0, look.Z)
    if forward.Magnitude > 0.05 then forward = forward.Unit else forward = Vector3.zero end
    local groundY = nil
    for _, off in ipairs({ Vector3.zero, forward * 4, forward * -4 }) do
        local okRay, hit = pcall(function()
            return workspace:Raycast(pos + off, Vector3.new(0, -1500, 0), HoverRayParams)
        end)
        if okRay and hit and (not groundY or hit.Position.Y > groundY) then
            groundY = hit.Position.Y
        end
    end
    if not groundY then return end                 -- 脚下没地面：放手，让车正常下落

    local height = math.clamp(State.VehicleHoverHeight or 8, 1, HOVER_MAX)
    local targetY = groundY + height

    -- 高度回正：每帧最多挪 liftSpeed*dt，够快但不像瞬移
    local liftSpeed = 30 * (State.VehicleHoverGain or 8)
    local step = math.max(liftSpeed * math.clamp(dt or 0.016, 0.001, 0.05), 0.5)
    local newY = pos.Y + math.clamp(targetY - pos.Y, -step, step)

    local v = base.AssemblyLinearVelocity
    pcall(function()
        base.CFrame = CFrame.new(pos.X, newY, pos.Z) * CFrame.Angles(0, yaw, 0)
        base.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
        base.AssemblyAngularVelocity = Vector3.zero
    end)
end

Track(RunService.Heartbeat:Connect(function(dt)
    if IsClosing then return end
    if State.VehicleHoverEnabled then ApplyVehicleHover(dt) end
    if State.VehiclePushEnabled then ApplyVehiclePush(dt) end
    if State.VehicleTurnEnabled then ApplyVehicleTurn(dt) end
end))

Track(LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1.5)
    if IsClosing then return end
    if State.InfiniteAmmo then
        AmmoNextScan = os.clock() + 10
        UpdateAmmoTable(true)
        LockAllAmmo()
        print("[NARAMO] 重生后重扫: " .. AmmoStatusText())
    end
    if State.WalkSpeedEnabled and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = State.WalkSpeedValue end
    end
end))
end   -- 车辆段结束

local function DisableAllFeatures()
    for _, key in ipairs({ "InfJump", "Noclip", "FullBright", "ESPEnabled", "AimbotEnabled",
                           "NPCESPEnabled", "NPCAimEnabled", "WalkSpeedEnabled", "InfiniteAmmo",
                           "InstantInteract", "WrenchRepair", "WrenchAutoRepair", "SkyWalk",
                           "VehiclePushEnabled", "VehicleTurnEnabled", "VehicleHoverEnabled", "WrenchTour" }) do
        SetControl(key, false)   -- 走控件回填，开关显示也会一起复位
    end
    print("触发了安全机制：已关闭所有功能")
end

-- ============================ 即时互动（移植自 xk 新版通用） ============================
-- xk 的做法：把全地图 ProximityPrompt 的 HoldDuration 改成 0（碰到即触发），
-- 把 ClickDetector 的点击距离放大到 500。
-- 这里沿用 NARAMO 的「原值还原」规范：先把原始值记下来，关闭时按原样还回去，
-- 而不是像 xk 那样硬写成 1 / 32（会改掉游戏原本的设计值）。
local INTERACT_CLICK_DIST = 500        -- 点击距离放大到多少 studs（同 xk）
local InteractBackup = {}              -- 交互对象 -> { hold = 原按住时长 } 或 { dist = 原点击距离 }

local function IsInteractObject(obj)
    return obj:IsA("ProximityPrompt") or obj:IsA("ClickDetector")
end

local function ApplyInstantInteract(obj)
    if IsClosing or not State.InstantInteract then return end
    if not IsInteractObject(obj) then return end
    -- 只在第一次碰到时记原值：反复写 0 不会把备份覆盖成 0
    if not InteractBackup[obj] then
        if obj:IsA("ProximityPrompt") then
            InteractBackup[obj] = { hold = obj.HoldDuration }
        else
            InteractBackup[obj] = { dist = obj.MaxActivationDistance }
        end
    end
    pcall(function()
        if obj:IsA("ProximityPrompt") then
            if obj.HoldDuration ~= 0 then obj.HoldDuration = 0 end
        elseif obj.MaxActivationDistance < INTERACT_CLICK_DIST then
            obj.MaxActivationDistance = INTERACT_CLICK_DIST
        end
    end)
end

local function ScanInstantInteract()
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if IsInteractObject(obj) then ApplyInstantInteract(obj) end
        end
    end)
end

-- 返回还原了多少个（关闭时用来打日志，也顺手清空备份）
local function RestoreInstantInteract()
    local n = 0
    for obj, backup in pairs(InteractBackup) do
        n = n + 1
        pcall(function()
            if obj.Parent == nil then return end     -- 已经被游戏销毁的交互点不用管
            if backup.hold ~= nil and obj:IsA("ProximityPrompt") then
                obj.HoldDuration = backup.hold
            elseif backup.dist ~= nil and obj:IsA("ClickDetector") then
                obj.MaxActivationDistance = backup.dist
            end
        end)
    end
    table.clear(InteractBackup)
    return n
end

-- 新刷出来的提示 / 检测器也要吃上（同 xk 的 DescendantAdded 处理）
Track(workspace.DescendantAdded:Connect(function(obj)
    if IsClosing or not State.InstantInteract then return end
    ApplyInstantInteract(obj)
end))

-- ============================ 踏空行走（移植自 xk 主页面） ============================
-- xk 的做法：在脚下落一块 10000×1×10000 的隐形锚定平台，站上去就能在空中行走。
-- 这里沿用 NARAMO 的规范：只在本机生成（不复制到服务器），关开关 / 死亡 / 卸载脚本时销毁。
-- 整段收进 SkyWalk 表：Lua 每个函数最多 200 个局部变量，占满就编译不过。
local SkyWalk = { part = nil, dieConn = nil }

function SkyWalk.Remove()
    if SkyWalk.dieConn then
        pcall(function() SkyWalk.dieConn:Disconnect() end)
        SkyWalk.dieConn = nil
    end
    if SkyWalk.part then
        pcall(function() SkyWalk.part:Destroy() end)
        SkyWalk.part = nil
    end
end

function SkyWalk.Create()
    SkyWalk.Remove()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not hrp:IsA("BasePart") then return false end

    local p = Instance.new("Part")
    p.Name = "NARAMO_SkyWalk"
    p.Size = Vector3.new(10000, 1, 10000)
    p.Position = hrp.Position - Vector3.new(0, 3, 0)   -- 同 xk：落在脚底板下面
    p.Anchored = true
    p.CanCollide = true
    p.CanQuery = false        -- 别让 ESP / 车辆悬浮的射线打到它
    p.CanTouch = false
    p.CastShadow = false
    p.Material = Enum.Material.SmoothPlastic
    p.Transparency = 1
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = workspace
    SkyWalk.part = p

    -- 死了就把平台拆掉，重生后由 CharacterAdded 按新位置重新铺
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then SkyWalk.dieConn = hum.Died:Connect(SkyWalk.Remove) end
    return true
end

function SkyWalk.Set(on)
    State.SkyWalk = on
    if not on then
        local had = SkyWalk.part ~= nil
        SkyWalk.Remove()
        if had then print("[NARAMO] 踏空行走: 已关闭，平台已移除") end   -- 初始化时的静默关闭不打日志
        return
    end
    if SkyWalk.Create() then
        print("[NARAMO] 踏空行走: 平台已铺在脚下（想在空中走：跳起来 / 掉落中再打开这个开关）")
    else
        State.SkyWalk = false
        SetControl("SkyWalk", false)          -- 角色没就绪，界面上的开关也退回关
        print("[NARAMO] 踏空行走: 角色未就绪，先别开")
    end
end

Track(LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1.5)
    if IsClosing or not State.SkyWalk then return end
    SkyWalk.Create()
end))

-- ============================ PM 秒维修 ============================
-- 四个维修小游戏（接线 WireUI / 进度条 Repair / 管道 Weld / 变压器 TransformerIsolationGame）
-- 都是纯客户端判定，成功时只调用一次：
--   ReplicatedStorage.Remotes.RepairSystem.Repair:FireServer(工具, RepairObject.BasePart, "Durability")
-- 所以监听这几个界面，一出现就直接发调用，再连发补满耐久，最后卸下/重装扳手复位。
-- 需要多次维修的东西：两次 Repair 之间不留空档（WrenchTune.gap = 0），逐帧连发到耐久满。
-- 「靠近自动维修」完全不依赖小游戏：身边有没修满的 RepairObject 就直接补满。
local WrenchRS = game:GetService("ReplicatedStorage")
local WrenchCS = game:GetService("CollectionService")

local WrenchGuis = {
    WireUI = true,
    Repair = true,
    Weld = true,
    TransformerIsolationGame = true,
}

local WrenchBusy = false
local WrenchHandledUI = nil
local WrenchThread = nil
local WrenchLast = 0

-- 维修节奏参数（收进 WrenchTune 表，不占顶层局部变量名额）
local WrenchTune = {
    gap = 0,             -- 两次 Repair 之间的间隔（秒）。0 = 中间不留空档，每帧补一次，直到耐久满
    maxFires = 900,      -- 有耐久读数时最多连发多少次（约 15 秒 @60fps）
    stallFires = 120,    -- 耐久连续这么多次没涨就停手（约 2 秒，服务端冷却时别空打）
    unknownFires = 12,   -- 读不到耐久上限（没有 Values/Durability）时的固定连发次数
    autoCooldown = 1.0,  -- 同一台设备两次自动维修之间的最小间隔（秒）
}

local function WrenchRemotes()
    local remotes = WrenchRS:FindFirstChild("Remotes")
    local sys = remotes and remotes:FindFirstChild("RepairSystem")
    if not sys then return nil, nil end
    return sys:FindFirstChild("Repair"), sys:FindFirstChild("RequestRepair")
end

local function WrenchTool()
    local char = LocalPlayer.Character
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    local fallback = nil
    local function isWrench(t)
        local n = string.lower(t.Name)
        return string.find(n, "wrench", 1, true) ~= nil or string.find(n, "repair", 1, true) ~= nil
    end
    if char then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") then
                if isWrench(t) then return t end
                fallback = fallback or t
            end
        end
    end
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") then
                if isWrench(t) then return t end
                fallback = fallback or t
            end
        end
    end
    return fallback
end

-- 自动维修专用：只认扳手本身，绝不拿别的工具（枪/钥匙）去发 Repair
local function WrenchOnly()
    local function isWrench(t)
        local n = string.lower(t.Name)
        return string.find(n, "wrench", 1, true) ~= nil or string.find(n, "repair", 1, true) ~= nil
    end
    local function scan(root)
        if not root then return nil end
        for _, t in ipairs(root:GetChildren()) do
            if t:IsA("Tool") and isWrench(t) then return t end
        end
        return nil
    end
    return scan(LocalPlayer.Character) or scan(LocalPlayer:FindFirstChildOfClass("Backpack"))
end

local function WrenchPos()
    local char = LocalPlayer.Character
    local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head"))
    return hrp and hrp.Position
end

-- 到「部件表面最近点」的距离：大机器中心很远，但表面就在手边
local function WrenchSurfaceDistance(part, pos)
    local ok, cp = pcall(function() return part:GetClosestPointOnSurface(pos) end)
    if ok and typeof(cp) == "Vector3" then return (cp - pos).Magnitude end
    return (part.Position - pos).Magnitude
end

local function WrenchFindTarget(maxDist)
    local pos = WrenchPos()
    if not pos then return nil end
    maxDist = maxDist or 15.5
    local best, bestD = nil, nil
    local ok, tagged = pcall(function() return WrenchCS:GetTagged("RepairObject") end)
    if ok and type(tagged) == "table" then
        for _, part in ipairs(tagged) do
            if part:IsA("BasePart") and part:IsDescendantOf(workspace) then
                local d = WrenchSurfaceDistance(part, pos)
                if d <= maxDist and (bestD == nil or d < bestD) then best, bestD = part, d end
            end
        end
    end
    return best, bestD
end

local function WrenchDurability(part)
    local vals = part:FindFirstChild("Values")
    local attr = vals and vals:FindFirstChild("Durability")
    if not attr then return nil, nil end
    local v, mx
    pcall(function() v = attr.Value end)
    pcall(function() mx = attr.MaxValue end)
    if v == nil then pcall(function() v = attr:GetAttribute("Value") end) end
    if mx == nil then pcall(function() mx = attr:GetAttribute("MaxValue") end) end
    return v, mx
end

local function WrenchFire(repair, request, tool, part)
    if request then pcall(function() request:FireServer(tool, part, "Durability") end) end
    pcall(function() repair:FireServer(tool, part, "Durability") end)
end

-- 修完弹一个通知（只报这次修的设备，不做任何计数）
local function WrenchNotify(text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "PM秒维修",
            Text = text,
            Duration = 3,
        })
    end)
end

local function WrenchResetTool()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    pcall(function() hum:UnequipTools() end)
    task.wait(0.35)
    local t = WrenchTool()
    if t then pcall(function() hum:EquipTool(t) end) end
end

-- 秒维修 / 自动维修 只要还有一个开着，连发就继续
local function WrenchStillOn()
    return not IsClosing and (State.WrenchRepair or State.WrenchAutoRepair)
end

-- 连发补耐久：两次 Repair 之间不留间隔（WrenchTune.gap = 0 时每帧发一次），
-- 直到耐久补满 / 目标消失 / 连续一段时间没有进展。
-- 返回最后读到的耐久值（读不到时是 nil）。
local function WrenchRepairUntilFull(repair, request, tool, part)
    if not part or not part:IsDescendantOf(workspace) then return nil end
    local cur, mx = WrenchDurability(part)
    if cur ~= nil and mx ~= nil and cur >= mx - 0.01 then return cur end   -- 本来就是满的

    local maxFires = (mx ~= nil) and WrenchTune.maxFires or WrenchTune.unknownFires
    local stall = 0

    for _ = 1, maxFires do
        if not WrenchStillOn() then break end
        if not part:IsDescendantOf(workspace) then break end

        WrenchFire(repair, request, tool, part)
        -- 间隔 0 也至少要让出一帧：卡在死循环里客户端会直接冻住
        if WrenchTune.gap > 0 then
            task.wait(WrenchTune.gap)
        else
            RunService.Heartbeat:Wait()
        end

        local nv, nmx = WrenchDurability(part)
        if nv == nil then break end                            -- 耐久对象没了（设备销毁/换模型）
        if nmx ~= nil then mx = nmx end
        if mx ~= nil and nv >= mx - 0.01 then return nv end     -- 补满了

        if cur ~= nil and nv > cur + 0.05 then
            stall = 0                                          -- 还在涨：继续连发
        else
            stall = stall + 1
            if mx ~= nil and stall >= WrenchTune.stallFires then break end   -- 服务端在冷却，别空打
        end
        cur = nv
    end
    return cur
end

local function WrenchHandle()
    if IsClosing or WrenchBusy or not State.WrenchRepair then return end
    if os.clock() - WrenchLast < 0.3 then return end

    local ui, name = nil, nil
    for n in pairs(WrenchGuis) do
        local g = PlayerGui:FindFirstChild(n)
        if g and g:IsA("ScreenGui") then ui, name = g, n; break end
    end
    if not ui or ui == WrenchHandledUI then return end

    WrenchHandledUI = ui
    WrenchBusy = true

    -- 同步立即开火：不等、不 spawn
    local repair, request = WrenchRemotes()
    local tool = WrenchTool()
    local part = nil
    if tool and repair then
        part = WrenchFindTarget(15.5)
        if not part then part = WrenchFindTarget(25) end
        if part then WrenchFire(repair, request, tool, part) end
    end

    task.spawn(function()
        if repair and tool and part then
            pcall(WrenchRepairUntilFull, repair, request, tool, part)
        end
        if not IsClosing then pcall(WrenchResetTool) end
        for n in pairs(WrenchGuis) do
            local g = PlayerGui:FindFirstChild(n)
            if g then pcall(function() g:Destroy() end) end
        end
        -- 每次维修完成后弹一个通知（报设备和耐久，不做计数）
        if not IsClosing and tool and part then
            local v = WrenchDurability(part)
            local txt = "?"
            if tonumber(v) then txt = tostring(math.floor(tonumber(v))) end
            WrenchNotify("已修好：" .. tostring(part.Name) .. "（耐久 " .. txt .. "）")
        end
        WrenchLast = os.clock()
        WrenchBusy = false
    end)
end

-- 靠近自动维修：不依赖小游戏弹出。身边（WrenchAutoDist 内）有带 RepairObject 标签、
-- 耐久还没满的设备，就拿扳手直接补满；同一台设备 1 秒内不会重复触发。
local WrenchAutoSeen = {}

local function WrenchAutoTick()
    if IsClosing or WrenchBusy or not State.WrenchAutoRepair then return end
    local now = os.clock()

    -- 顺手清掉已经销毁的设备，别让这张表越攒越大
    for part in pairs(WrenchAutoSeen) do
        if part.Parent == nil then WrenchAutoSeen[part] = nil end
    end

    local repair, request = WrenchRemotes()
    if not repair then return end
    local tool = WrenchOnly()               -- 没有扳手就不动，绝不拿别的工具发
    if not tool then return end

    local part = WrenchFindTarget(State.WrenchAutoDist or 20)
    if not part then return end

    local cur, mx = WrenchDurability(part)
    -- 高于阈值就不修：专治「刚修好就掉到 99%」这种持续扣血的设备
    if cur ~= nil and mx ~= nil then
        local pct = math.clamp(State.WrenchSkipAbove or 95, 0, 100) / 100
        if cur >= mx * pct then return end
    end

    -- 读不到耐久 / 没有上限的读数，都判断不了满没满：给个长冷却，别一直空打
    local waitFor = (cur == nil or mx == nil) and 30 or WrenchTune.autoCooldown
    if (WrenchAutoSeen[part] or 0) > now then return end
    WrenchAutoSeen[part] = now + waitFor

    WrenchBusy = true
    task.spawn(function()
        pcall(function()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and tool.Parent ~= char then
                hum:EquipTool(tool)             -- 扳手在背包里：先装备再发，服务端才认
                task.wait(0.1)
            end
            if request then pcall(function() request:FireServer(tool, part, "Durability") end) end
            local after = WrenchRepairUntilFull(repair, request, tool, part)
            local txt = "?"
            if tonumber(after) then txt = tostring(math.floor(tonumber(after))) end
            print(string.format("[PM秒维修] 自动维修 %s → 耐久 %s", tostring(part.Name), txt))
        end)
        WrenchBusy = false
    end)
end

local function WrenchStartLoop()
    if WrenchThread then return end
    WrenchThread = task.spawn(function()
        while not IsClosing and (State.WrenchRepair or State.WrenchAutoRepair) do
            task.wait(0.1)
            if not WrenchBusy then
                -- 界面上已经没有小游戏了就清掉「已处理」标记，等下一次弹出
                local any = false
                for n in pairs(WrenchGuis) do
                    if PlayerGui:FindFirstChild(n) then any = true; break end
                end
                if not any then WrenchHandledUI = nil end
                if State.WrenchRepair then pcall(WrenchHandle) end
            end
            if not WrenchBusy and State.WrenchAutoRepair then pcall(WrenchAutoTick) end
        end
        WrenchThread = nil
    end)
end

-- 界面一挂上来就处理（轮询只是兜底）
Track(PlayerGui.ChildAdded:Connect(function(obj)
    if IsClosing or not State.WrenchRepair then return end
    if obj and WrenchGuis[obj.Name] then pcall(WrenchHandle) end
end))

-- ============================ PM 全场自动维修 ============================
-- 开启后：自动打开「穿墙 / PM 靠近自动维修 / 移速 50」→ 扫描全场 RepairObject 标签
-- → 按「最近优先」逐个滑行过去（高度由脚本每帧接管，墙体和虚空都直接穿过去）
-- → 到点让维修逻辑补满，短暂停留就直奔下一个 → 一圈跑完重新扫描，循环往复。
-- 为什么不用「踏空行走」：穿墙会把角色所有部件 CanCollide=false，隐形平台根本站不上去，
-- 角色会直接穿过去往下掉；这里改成每帧写位置 + 锁定高度，效果一样而且更稳。
-- 整段收进 Tour 表：Lua 每个函数最多 200 个局部变量，顶层变量太多会直接编译失败
local Tour = {
    thread = nil, halt = false, holdY = nil, target = nil, char = nil, dwell = 0,
    visited = {}, badUntil = {}, doneUntil = {}, cache = {}, cacheAt = 0,
    prev = {}, setTo = {}, cleaned = true,
    legKey = nil, legDist = math.huge, legAt = 0, errAt = 0, seatT = 0,
    holdPart = nil, holdKey = nil, holdStart = 0, holdUntil = 0,
}

function Tour.Key(t)
    if t.part then return t.part end
    return string.format("%s|%.0f|%.0f|%.0f", tostring(t.name), t.pos.X, t.pos.Y, t.pos.Z)
end

-- 预设坐标兜底：配置文件里写 WrenchTourPoints = {{x=..,y=..,z=..}, ...}（也接受 {x,y,z} 数组）
function Tour.PresetPoints()
    local out = {}
    local pts = State.WrenchTourPoints
    if type(pts) ~= "table" then return out end
    for _, e in ipairs(pts) do
        local x, y, z
        if type(e) == "table" then
            x = tonumber(e.x or e[1]); y = tonumber(e.y or e[2]); z = tonumber(e.z or e[3])
        end
        if x and y and z then
            table.insert(out, { pos = Vector3.new(x, y, z), name = "预设点" })
        end
    end
    return out
end

function Tour.Scan()
    local out = {}
    local ok, tagged = pcall(function() return WrenchCS:GetTagged("RepairObject") end)
    if ok and type(tagged) == "table" then
        for _, part in ipairs(tagged) do
            if part:IsA("BasePart") and part:IsDescendantOf(workspace) then
                table.insert(out, { part = part, pos = part.Position, name = part.Name })
            end
        end
    end
    for _, p in ipairs(Tour.PresetPoints()) do table.insert(out, p) end
    Tour.cache = out
    Tour.cacheAt = os.clock()
    return out
end

function Tour.PickNext()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    if os.clock() - Tour.cacheAt > 5 or #Tour.cache == 0 then Tour.Scan() end

    local myPos = hrp.Position
    local now = os.clock()
    local pct = math.clamp(State.WrenchSkipAbove or 95, 0, 100) / 100
    local best, bestD = nil, math.huge
    for _, t in ipairs(Tour.cache) do
        local key = Tour.Key(t)
        local alive = (t.part == nil) or (t.part.Parent ~= nil and t.part:IsDescendantOf(workspace))
        if alive and not Tour.visited[key] and (Tour.badUntil[key] or 0) <= now
            and (Tour.doneUntil[key] or 0) <= now then
            local full = false
            if t.part then
                local cur, mx = WrenchDurability(t.part)
                full = (cur ~= nil and mx ~= nil and cur >= mx * pct)   -- 高于阈值 = 不需要跑这趟
            end
            if not full then
                local d = (t.pos - myPos).Magnitude
                if d < bestD then best, bestD = t, d end
            end
        end
    end
    return best, bestD
end

function Tour.ApplyPose(hrp, x, y, z)
    pcall(function()
        hrp.CFrame = CFrame.new(x, y, z) * (hrp.CFrame - hrp.CFrame.Position)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
end

-- 标记「当前目标」：一块橙色高亮 + 头顶一个始终置顶的圆点，隔着墙也能看到下一台要修哪里
function Tour.MarkCurrent()
    if not State.WrenchTourMark then
        if Tour.mark then
            Tour.mark.hl.Enabled = false
            Tour.mark.gui.Enabled = false
        end
        return
    end

    local part = Tour.holdPart or (Tour.target and Tour.target.part)

    if not Tour.mark then
        local ok, holder = pcall(function()
            local root = Instance.new("Folder")
            root.Name = "NARAMO_TourMark"
            root.Parent = ESPFolder or PlayerGui

            local hl = Instance.new("Highlight")
            hl.Name = "TourTargetHL"
            hl.FillColor = Color3.fromRGB(255, 190, 40)
            hl.OutlineColor = Color3.fromRGB(255, 240, 160)
            hl.FillTransparency = 0.5
            hl.OutlineTransparency = 0
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Enabled = false
            hl.Parent = root

            local gui = Instance.new("BillboardGui")
            gui.Name = "TourTargetDot"
            gui.Size = UDim2.fromOffset(16, 16)
            gui.StudsOffset = Vector3.new(0, 2.5, 0)
            gui.AlwaysOnTop = true
            gui.LightInfluence = 0
            gui.MaxDistance = 3000
            gui.Enabled = false
            gui.Parent = root

            local dot = Instance.new("Frame")
            dot.Size = UDim2.fromScale(1, 1)
            dot.BackgroundColor3 = Color3.fromRGB(255, 190, 40)
            dot.BorderSizePixel = 0
            dot.Parent = gui
            Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

            return { root = root, hl = hl, gui = gui }
        end)
        if not ok or type(holder) ~= "table" then return end
        Tour.mark = holder
    end

    local m = Tour.mark
    if part and part:IsDescendantOf(workspace) then
        if m.hl.Adornee ~= part then m.hl.Adornee = part end
        if m.gui.Adornee ~= part then m.gui.Adornee = part end
        m.hl.Enabled = true
        m.gui.Enabled = true
    else
        m.hl.Enabled = false
        m.gui.Enabled = false
    end
end

function Tour.ClearMark()
    if not Tour.mark then return end
    pcall(function() Tour.mark.root:Destroy() end)
    Tour.mark = nil
end

-- 到点：直接把这一台交给补耐久逻辑（不依赖自动维修的半径设置）
-- force = true 时忽略“高于阈值不修”的限制（正在修的设备必须修满才走）
function Tour.RepairHere(part, force)
    if not part or WrenchBusy then return end
    local repair, request = WrenchRemotes()
    local tool = WrenchOnly()
    if not repair or not tool then return end
    local cur, mx = WrenchDurability(part)
    if not force and cur ~= nil and mx ~= nil then
        local pct = math.clamp(State.WrenchSkipAbove or 95, 0, 100) / 100
        if cur >= mx * pct then return end
    end
    WrenchBusy = true
    task.spawn(function()
        pcall(WrenchRepairUntilFull, repair, request, tool, part)
        WrenchBusy = false
    end)
end

function Tour.Step(dt)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then Tour.holdY = nil; return end
    if hum.Health <= 0 then return end                           -- 死了先待着，重生后自动接着跑

    -- 被椅子 / 座椅吸住：每帧强制站起来，不然巡回会永远卡在这
    if hum.Sit or hum.SeatPart then
        pcall(function() hum.Sit = false end)
        local seat = hum.SeatPart
        if seat then
            pcall(function() hum.Jump = true end)                    -- 载具座要跳一下才下得来
            local weld = seat:FindFirstChild("SeatWeld")
            if weld then pcall(function() weld:Destroy() end) end    -- 兜底：拆掉座椅焊点
            Tour.seatT = (Tour.seatT or 0) + dt
            if Tour.seatT > 2 then                                   -- 2 秒还没脱离：往上弹一下
                Tour.seatT = 0
                pcall(function() hrp.CFrame = hrp.CFrame + Vector3.new(0, 5, 0) end)
            end
            return                                                     -- 这一帧先别硬拽位置
        end
        Tour.seatT = 0
    end

    -- 换角色（重生）后重新取高度，别把新角色拽到旧高度
    if Tour.char ~= char then
        Tour.char, Tour.holdY, Tour.target = char, hrp.Position.Y, nil
        Tour.holdPart, Tour.holdKey = nil, nil
    end
    if not Tour.holdY then Tour.holdY = hrp.Position.Y end

    -- 正在修一台设备：停在旁边，一轮连发没满就再补一轮，直到修满或超时
    if Tour.holdPart then
        local part = Tour.holdPart
        local gone = (part.Parent == nil) or (not part:IsDescendantOf(workspace))
        local cur, mx = WrenchDurability(part)
        local known = (cur ~= nil and mx ~= nil)
        local full = known and (cur >= mx - 0.01)
        local now = os.clock()
        local timeout = now > Tour.holdUntil

        if known and not full and not gone and not timeout and not WrenchBusy then
            Tour.RepairHere(part, true)          -- 上一轮连发停了还没满：接着补
        end
        Tour.ApplyPose(hrp, hrp.Position.X, Tour.holdY, hrp.Position.Z)

        -- 读不到耐久的设备不知道该修到什么时候：等这一轮连发跑完就走
        local unknownDone = (not known) and (not WrenchBusy) and (now > Tour.holdStart + 0.5)
        if gone or full or timeout or unknownDone then
            local key = Tour.holdKey
            if key then
                Tour.doneUntil[key] = now + math.clamp(State.WrenchTourCooldown or 180, 0, 3600)
            end
            local spent = now - (Tour.holdStart or now)
            if timeout and not full and not gone then
                print("[NARAMO] 全场自动维修: " .. tostring(part.Name) .. " 没修满（可能被服务端限制），先跳过")
            elseif full and spent > 1.5 then
                print("[NARAMO] 全场自动维修: " .. tostring(part.Name) .. " 修满（停留 " .. string.format("%.1f", spent) .. " 秒）")
            end
            Tour.holdPart, Tour.holdKey = nil, nil
        end
        return
    end

    -- 到点后的短暂停留：让补耐久先开火
    if Tour.dwell > 0 then
        Tour.dwell = Tour.dwell - dt
        Tour.ApplyPose(hrp, hrp.Position.X, Tour.holdY, hrp.Position.Z)
        if Tour.dwell <= 0 then Tour.target = nil end
        return
    end

    if not Tour.target then
        Tour.target = Tour.PickNext()
        if not Tour.target then
            -- 一圈跑完 / 全场都修满了：清标记、重扫，等两秒再来
            Tour.visited = {}
            Tour.Scan()
            Tour.target = Tour.PickNext()
            if not Tour.target then
                Tour.ApplyPose(hrp, hrp.Position.X, Tour.holdY, hrp.Position.Z)
                task.wait(2)
                return
            end
        end
        Tour.legKey, Tour.legDist, Tour.legAt = nil, math.huge, os.clock()
    end

    local t = Tour.target
    if t.part and (t.part.Parent == nil or not t.part:IsDescendantOf(workspace)) then
        Tour.target = nil
        return
    end

    local pos = hrp.Position
    local dx, dz = t.pos.X - pos.X, t.pos.Z - pos.Z
    local dy = t.pos.Y - Tour.holdY
    local hDist = math.sqrt(dx * dx + dz * dz)
    local arrive = math.clamp(State.WrenchTourArrive or 12, 4, 40)
    local speed = math.clamp(State.WrenchTourSpeed or 50, 10, 300)

    if hDist <= arrive and math.abs(dy) <= 10 then
        local key = Tour.Key(t)
        Tour.visited[key] = true
        Tour.target = nil
        if t.part then
            -- 停在旁边修满再走：高耐久的设备一次修不满，走开就只能修到一半
            Tour.holdPart = t.part
            Tour.holdKey = key
            Tour.holdStart = os.clock()
            Tour.holdUntil = Tour.holdStart + math.clamp(State.WrenchTourHold or 8, 2, 30)
            Tour.RepairHere(t.part)
        else
            Tour.doneUntil[key] = os.clock() + math.clamp(State.WrenchTourCooldown or 180, 0, 3600)
            Tour.dwell = 0.25
        end
        Tour.ApplyPose(hrp, pos.X, Tour.holdY, pos.Z)
        return
    end

    local key = Tour.Key(t)
    if Tour.legKey ~= key then
        Tour.legKey, Tour.legDist, Tour.legAt = key, hDist, os.clock()
    elseif hDist < Tour.legDist - 1 then
        Tour.legDist, Tour.legAt = hDist, os.clock()
    elseif os.clock() - Tour.legAt > 6 then
        Tour.badUntil[key] = os.clock() + 60
        print("[NARAMO] 全场自动维修: 到不了 " .. tostring(t.name) .. "，先跳过 60 秒")
        Tour.target = nil
        return
    end

    local step = speed * dt
    local nx, nz = pos.X, pos.Z
    if hDist > 6 then
        local s = math.min(step, hDist)
        nx = pos.X + (dx / hDist) * s
        nz = pos.Z + (dz / hDist) * s
        -- 高度跟着目标缓慢靠拢（限速，避免像电梯直上直下）
        Tour.holdY = Tour.holdY + math.clamp(dy, -step * 0.5, step * 0.5)
    else
        -- 已经在正上方/正下方：垂直贴近
        Tour.holdY = Tour.holdY + math.clamp(dy, -step, step)
    end

    Tour.ApplyPose(hrp, nx, Tour.holdY, nz)
end

function Tour.Restore()
    if Tour.cleaned then return end
    Tour.cleaned = true
    if IsClosing then return end          -- 关面板/卸载时不还原，免得把已经关掉的东西又打开
    for key, old in pairs(Tour.prev) do
        if State[key] == Tour.setTo[key] and old ~= nil and old ~= Tour.setTo[key] then
            SetControl(key, old)
        end
    end
    Tour.prev, Tour.setTo = {}, {}
end

function Tour.Enable(key, value)
    Tour.prev[key] = State[key]
    Tour.setTo[key] = value
    if State[key] ~= value then SetControl(key, value) end
end

function Tour.Start()
    if Tour.thread then return true end
    if not WrenchRemotes() then
        print("[NARAMO] 全场自动维修: 没找到 RepairSystem 远程，可能跑错游戏了")
        return false
    end
    if not WrenchOnly() then
        print("[NARAMO] 全场自动维修: 手上和背包里都没有扳手，先拿一把再开")
        return false
    end

    Tour.cleaned = false
    Tour.prev, Tour.setTo = {}, {}
    Tour.Enable("Noclip", true)               -- 方便走直线
    Tour.Enable("WrenchAutoRepair", true)     -- 路过就修
    Tour.Enable("WalkSpeedEnabled", true)     -- 移速（面板上也看得见）
    Tour.Enable("WalkSpeedValue", 50)         -- 50 是这游戏能稳住的最高速度

    Tour.visited, Tour.badUntil, Tour.doneUntil = {}, {}, {}
    Tour.holdY, Tour.target, Tour.char, Tour.dwell = nil, nil, nil, 0
    Tour.holdPart, Tour.holdKey = nil, nil
    Tour.legKey, Tour.legDist, Tour.legAt = nil, math.huge, 0
    Tour.Scan()
    State.WrenchTour = true
    Tour.halt = false

    Tour.thread = task.spawn(function()
        local last = os.clock()
        while not IsClosing and State.WrenchTour and not Tour.halt do
            local now = os.clock()
            local dt = math.clamp(now - last, 0.001, 0.05)
            last = now
            local ok, err = pcall(Tour.Step, dt)
            if not ok and now - Tour.errAt > 3 then
                Tour.errAt = now
                print("[NARAMO] 全场自动维修: 出错 " .. tostring(err))
            end
            pcall(Tour.MarkCurrent)          -- 把高亮/圆点跟到当前目标上
            RunService.Heartbeat:Wait()
        end
        Tour.thread = nil
        SetControl("WrenchTour", false)      -- 同步 UI，并走一遍还原
        if not IsClosing then print("[NARAMO] 全场自动维修: 已停止") end
    end)

    print("[NARAMO] 全场自动维修: 已开启（" .. tostring(#Tour.cache) .. " 个目标，巡航速度 " .. tostring(State.WrenchTourSpeed) .. "）")
    return true
end

function Tour.Stop()
    State.WrenchTour = false
    Tour.halt = true
    if Tour.thread then pcall(task.cancel, Tour.thread); Tour.thread = nil end
    Tour.target, Tour.holdY = nil, nil
    Tour.holdPart, Tour.holdKey = nil, nil
    Tour.ClearMark()
    Tour.Restore()
end

-- ============================ UI 构建 ============================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NARAMO_UI"; ScreenGui.ResetOnSpawn = false; ScreenGui.Parent = PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 600, 0, 400); MainFrame.Position = UDim2.new(0.5, -300, 0.5, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30); MainFrame.BorderSizePixel = 0; MainFrame.Active = true; MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 36); TitleBar.BackgroundColor3 = Color3.fromRGB(18, 18, 22); TitleBar.BorderSizePixel = 0; TitleBar.Parent = MainFrame
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 8)

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1, -80, 1, 0); TitleText.Position = UDim2.new(0, 12, 0, 0); TitleText.BackgroundTransparency = 1
TitleText.Text = "NARAMO 终极版"; TitleText.TextColor3 = Color3.fromRGB(230, 230, 240); TitleText.Font = Enum.Font.GothamBold; TitleText.TextSize = 16
TitleText.TextXAlignment = Enum.TextXAlignment.Left; TitleText.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28); CloseBtn.Position = UDim2.new(1, -34, 0, 4); CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50); CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "×"; CloseBtn.TextColor3 = Color3.new(1, 1, 1); CloseBtn.Font = Enum.Font.GothamBold; CloseBtn.TextSize = 18; CloseBtn.Parent = TitleBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

local MiniBtn = Instance.new("TextButton")
MiniBtn.Size = UDim2.new(0, 28, 0, 28); MiniBtn.Position = UDim2.new(1, -66, 0, 4); MiniBtn.BackgroundColor3 = Color3.fromRGB(70, 90, 120); MiniBtn.BorderSizePixel = 0
MiniBtn.Text = "－"; MiniBtn.TextColor3 = Color3.new(1, 1, 1); MiniBtn.Font = Enum.Font.GothamBold; MiniBtn.TextSize = 16; MiniBtn.Parent = TitleBar
Instance.new("UICorner", MiniBtn).CornerRadius = UDim.new(0, 6)

local function CleanupAndClose()
    if IsClosing then return end
    IsClosing = true

    -- 1) 所有开关回到默认（走控件回填，界面同步）
    for _, key in ipairs({ "InfJump", "Noclip", "FullBright", "UnlockChat", "UnlockFPS",
                          "ESPEnabled", "AimbotEnabled", "NPCESPEnabled", "NPCAimEnabled",
                          "WalkSpeedEnabled", "InfiniteAmmo",
                          "InstantInteract", "WrenchRepair", "WrenchAutoRepair", "SkyWalk",
                          "VehiclePushEnabled", "VehicleTurnEnabled", "VehicleHoverEnabled", "WrenchTour" }) do
        SetControl(key, false)
    end
    SetControl("AutoCheck", false)
    if AutoCheckThread then pcall(task.cancel, AutoCheckThread); AutoCheckThread = nil end

    -- 2) 恢复角色上被写过的属性
    pcall(function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 16; hum.JumpPower = 50 end
        if char then                        -- 穿墙会关掉 CanCollide，这里还原
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
        end
    end)

    -- 3) 还原被改写的原始值（子弹 / 光照）
    RestoreAmmoTable()
    RestoreLighting()

    -- 4) 清理 ESP 与 Drawing
    if ClearAllESP then ClearAllESP() end
    if ClearAllNPCESP then ClearAllNPCESP() end
    if FOVCircle then pcall(function() FOVCircle:Remove() end) end
    if LockText then pcall(function() LockText:Remove() end) end

    -- 5) 断开全部连接（这是之前漏掉的部分）
    for i = #Connections, 1, -1 do
        pcall(function() Connections[i]:Disconnect() end)
    end
    table.clear(Connections)

    -- 6) 取消全部常驻线程
    for i = #Threads, 1, -1 do
        pcall(function() task.cancel(Threads[i]) end)
    end
    table.clear(Threads)

    -- 7) 状态复位并销毁界面
    ResetState()
    pcall(function() ESPFolder:Destroy() end)
    ScreenGui:Destroy()
    print("[NARAMO] 已卸载：连接 / 线程 / Drawing 已全部清理")
end
CloseBtn.MouseButton1Click:Connect(CleanupAndClose)

-- ============================ 缩小后的悬浮窗 ============================
local MiniFrame = Instance.new("Frame")
MiniFrame.Size = UDim2.new(0, 118, 0, 32); MiniFrame.Position = UDim2.new(0.5, -59, 0, 24)
MiniFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40); MiniFrame.BorderSizePixel = 0
MiniFrame.Active = true; MiniFrame.Visible = false; MiniFrame.Parent = ScreenGui
Instance.new("UICorner", MiniFrame).CornerRadius = UDim.new(0, 16)

local MiniLabel = Instance.new("TextLabel")
MiniLabel.Size = UDim2.new(1, 0, 1, 0); MiniLabel.BackgroundTransparency = 1
MiniLabel.Text = "NARAMO"; MiniLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
MiniLabel.Font = Enum.Font.GothamBold; MiniLabel.TextSize = 13; MiniLabel.Parent = MiniFrame

local miniDragging, miniMoved, miniStartPos, miniStartInput = false, false, nil, nil
MiniFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        miniDragging = true; miniMoved = false
        miniStartPos = MiniFrame.Position
        miniStartInput = input.Position
    end
end)
MiniFrame.InputChanged:Connect(function(input)
    if miniDragging and miniStartInput and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - miniStartInput
        if delta.Magnitude > 4 then miniMoved = true end
        MiniFrame.Position = UDim2.new(miniStartPos.X.Scale, miniStartPos.X.Offset + delta.X,
                                       miniStartPos.Y.Scale, miniStartPos.Y.Offset + delta.Y)
    end
end)
MiniFrame.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        miniDragging = false
        if not miniMoved then          -- 没拖动 = 点击 → 展开
            MiniFrame.Visible = false
            MainFrame.Visible = true
        end
    end
end)

MiniBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    MiniFrame.Visible = true
end)

-- ============================ 移动端自瞄悬浮按钮 ============================
local function MakeMobileAimButton(label, yPos, stateKey)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 120, 0, 44)
    btn.Position = UDim2.new(1, -132, 0.5, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    btn.BackgroundTransparency = 0.1
    btn.BorderSizePixel = 0
    btn.Text = label .. ": 关"
    btn.TextColor3 = Color3.fromRGB(225, 225, 235)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.Visible = false
    btn.Parent = ScreenGui
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
    btn.MouseButton1Click:Connect(function()
        State[stateKey] = not State[stateKey]
        btn.Text = label .. (State[stateKey] and ": 开" or ": 关")
        btn.BackgroundColor3 = State[stateKey] and Color3.fromRGB(180, 60, 60) or Color3.fromRGB(45, 45, 55)
    end)
    return btn
end

local MobileAimBtn = MakeMobileAimButton("自瞄", 40, "AimMobileActive")
local MobileNpcAimBtn = MakeMobileAimButton("僵尸自瞄", 94, "NpcAimMobileActive")

local dragging, dragStart, startPos
local dragConn = nil
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = MainFrame.Position
        if dragConn then dragConn:Disconnect(); dragConn = nil end
        dragConn = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                if dragConn then dragConn:Disconnect(); dragConn = nil end
            end
        end)
    end
end)
TitleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        if dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end
end)

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 120, 1, -36); Sidebar.Position = UDim2.new(0, 0, 0, 36); Sidebar.BackgroundColor3 = Color3.fromRGB(20, 20, 26); Sidebar.BorderSizePixel = 0; Sidebar.Parent = MainFrame
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 8)
Instance.new("UIListLayout", Sidebar).Padding = UDim.new(0, 4)   -- 9 个分支，间距 4 才放得下
Instance.new("UIPadding", Sidebar).PaddingTop = UDim.new(0, 10)

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -130, 1, -46); ContentArea.Position = UDim2.new(0, 125, 0, 41); ContentArea.BackgroundColor3 = Color3.fromRGB(30, 30, 38); ContentArea.BorderSizePixel = 0; ContentArea.Parent = MainFrame
Instance.new("UICorner", ContentArea).CornerRadius = UDim.new(0, 8)

local currentPage = nil
local function CreatePage(name)
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0); page.BackgroundTransparency = 1; page.BorderSizePixel = 0
    page.ScrollBarThickness = 4; page.Visible = false; page.Parent = ContentArea
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y   -- 控件一多要能滚动，不然下面的开关点不到
    Instance.new("UIListLayout", page).Padding = UDim.new(0, 8)
    local pad = Instance.new("UIPadding", page); pad.PaddingTop = UDim.new(0, 10); pad.PaddingLeft = UDim.new(0, 10); pad.PaddingRight = UDim.new(0, 10)
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 35); btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50); btn.BorderSizePixel = 0
    btn.Text = name; btn.TextColor3 = Color3.fromRGB(200, 200, 200); btn.Font = Enum.Font.GothamBold; btn.TextSize = 14
    btn.Parent = Sidebar; Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    
    btn.MouseButton1Click:Connect(function()
        for _, child in ipairs(ContentArea:GetChildren()) do if child:IsA("ScrollingFrame") then child.Visible = false end end
        for _, child in ipairs(Sidebar:GetChildren()) do if child:IsA("TextButton") then child.BackgroundColor3 = Color3.fromRGB(40, 40, 50) end end
        page.Visible = true; btn.BackgroundColor3 = Color3.fromRGB(60, 90, 160)
    end)
    if not currentPage then currentPage = page; btn.BackgroundColor3 = Color3.fromRGB(60, 90, 160); page.Visible = true end
    return page
end

local function CreateToggle(parent, text, key, default, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 34); btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50); btn.BorderSizePixel = 0
    btn.Text = "  " .. text; btn.TextColor3 = Color3.fromRGB(220, 220, 220); btn.Font = Enum.Font.Gotham; btn.TextSize = 13
    btn.TextXAlignment = Enum.TextXAlignment.Left; btn.Parent = parent; Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    local state = default and true or false
    local function refresh(fireCallback)
        btn.BackgroundColor3 = state and Color3.fromRGB(60, 90, 160) or Color3.fromRGB(40, 40, 50)
        if fireCallback and callback then callback(state) end
    end
    btn.MouseButton1Click:Connect(function()
        if IsClosing then return end
        state = not state
        refresh(true)
    end)
    -- 注册回填函数：配置加载 / 安全机制复位时，界面和 State 一起来（同 xk 的 SetValue）
    if key then UIControls[key] = function(v) state = v and true or false; refresh(true) end end
    refresh(true)
    return btn
end

local function CreateButton(parent, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 34); btn.BackgroundColor3 = Color3.fromRGB(50, 110, 70); btn.BorderSizePixel = 0
    btn.Text = text; btn.TextColor3 = Color3.new(1, 1, 1); btn.Font = Enum.Font.GothamBold; btn.TextSize = 13
    btn.Parent = parent; Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local function CreateInput(parent, placeholder, callback)
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 0, 34); box.BackgroundColor3 = Color3.fromRGB(20, 20, 25); box.BorderSizePixel = 0
    box.PlaceholderText = placeholder; box.Text = ""; box.TextColor3 = Color3.new(1,1,1); box.Font = Enum.Font.Gotham; box.TextSize = 13
    box.Parent = parent; Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)
    box.FocusLost:Connect(function() if callback then callback(box.Text) end end)
    return box
end

local function CreateSlider(parent, text, key, min, max, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 45); frame.BackgroundColor3 = Color3.fromRGB(35, 35, 45); frame.BorderSizePixel = 0
    frame.Parent = parent; Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
    local label = Instance.new("TextLabel"); label.Size = UDim2.new(1, -20, 0, 20); label.Position = UDim2.new(0, 10, 0, 5)
    label.BackgroundTransparency = 1; label.Text = text .. ": " .. tostring(default); label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.Font = Enum.Font.Gotham; label.TextSize = 13; label.TextXAlignment = Enum.TextXAlignment.Left; label.Parent = frame
    local bar = Instance.new("Frame"); bar.Size = UDim2.new(1, -20, 0, 6); bar.Position = UDim2.new(0, 10, 0, 30)
    bar.BackgroundColor3 = Color3.fromRGB(20, 20, 25); bar.BorderSizePixel = 0; bar.Parent = frame
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 3)
    local fill = Instance.new("Frame"); fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(60, 90, 160); fill.BorderSizePixel = 0; fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 3)
    local sliderBtn = Instance.new("TextButton"); sliderBtn.Size = UDim2.new(1, 0, 1, 0); sliderBtn.BackgroundTransparency = 1; sliderBtn.Text = ""; sliderBtn.Parent = bar
    local val = default
    -- 统一入口：拖动和配置回填都走这里，保证 数值/填充条/文字/State 四者同步
    local function setValue(v, fireCallback)
        v = math.clamp(tonumber(v) or val, min, max)
        val = math.floor(v + 0.5)
        local percent = (max > min) and math.clamp((val - min) / (max - min), 0, 1) or 0
        fill.Size = UDim2.new(percent, 0, 1, 0)
        label.Text = text .. ": " .. tostring(val)
        if fireCallback and callback then callback(val) end
    end
    sliderBtn.MouseButton1Down:Connect(function()
        if IsClosing then return end
        local draggingSlider = true
        local function updateSlider(input)
            local percent = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            setValue(min + (max - min) * percent, true)
        end
        local conn, conn2
        conn = UserInputService.InputChanged:Connect(function(input) if draggingSlider then updateSlider(input) end end)
        conn2 = UserInputService.InputEnded:Connect(function()
            draggingSlider = false
            if conn then conn:Disconnect() end
            if conn2 then conn2:Disconnect() end
        end)
    end)
    if key then
        UIControls[key] = function(v)
            if type(v) ~= "number" then v = tonumber(v) end
            if type(v) ~= "number" then return end
            setValue(v, true)
        end
    end
    return frame
end

-- ============================ 页面内容 ============================
-- 每个控件第三个参数是它在 State 里的字段名，用于配置回填时同步 UI

-- ---------------------- 简介（放在所有分支的最上面） ----------------------
do    -- 包成 do ... end：段内局部变量用完即释放，不占顶层 200 个名额
local IntroPage = CreatePage("简介")

-- 往当前页塞一段自动换行的说明文字
local function CreateIntroLabel(parent, text, color, bold)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 0)
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.BackgroundTransparency = 1
    lbl.TextWrapped = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Top
    lbl.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextColor3 = color
    lbl.Text = text
    lbl.Parent = parent
    return lbl
end

CreateIntroLabel(IntroPage, "NARAMO 终极版", Color3.fromRGB(235, 235, 245), true)
CreateIntroLabel(IntroPage, "版本：" .. SCRIPT_VERSION, Color3.fromRGB(150, 150, 165), false)
CreateIntroLabel(IntroPage,
    "本脚本仅供学习交流，请勿在任何公共服务器使用，这会影响到其他人的体验。",
    Color3.fromRGB(255, 120, 110), true)
CreateIntroLabel(IntroPage,
    "功能都在左边其它分支里；开关式的按钮点一下切换开/关，点按式的按钮点一下只执行一次。",
    Color3.fromRGB(170, 170, 185), false)

-- 剪贴板 API 各家执行器名字不统一，挨个试；一个都没有就把群号直接显示在按钮上
local function CopyText(text)
    local fns = {}
    if type(setclipboard) == "function" then table.insert(fns, setclipboard) end
    if type(toclipboard) == "function" then table.insert(fns, toclipboard) end
    if type(set_clipboard) == "function" then table.insert(fns, set_clipboard) end
    local okG, g = pcall(function() return _G end)
    if okG and type(g) == "table" then
        for _, name in ipairs({ "setclipboard", "toclipboard", "set_clipboard", "copy_to_clipboard" }) do
            local okF, fn = pcall(function() return g[name] end)
            if okF and type(fn) == "function" then table.insert(fns, fn) end
        end
    end
    for _, fn in ipairs(fns) do
        if pcall(fn, text) then return true end
    end
    return false
end

local QQ_GROUP = "313217509"
CreateIntroLabel(IntroPage, "QQ 交流群：" .. QQ_GROUP, Color3.fromRGB(200, 200, 215), false)

-- 点按式按钮（不是开关）：点一下复制群号，2 秒后恢复文字
local copyBtn
copyBtn = CreateButton(IntroPage, "点击复制QQ交流群群号", function()
    if CopyText(QQ_GROUP) then
        copyBtn.Text = "已复制：" .. QQ_GROUP
        print("[NARAMO] QQ 交流群群号已复制: " .. QQ_GROUP)
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "QQ 交流群",
                Text = "群号 " .. QQ_GROUP .. " 已复制到剪贴板",
                Duration = 3,
            })
        end)
    else
        copyBtn.Text = "执行器不支持剪贴板，群号：" .. QQ_GROUP
        print("[NARAMO] 当前执行器没有剪贴板 API，群号: " .. QQ_GROUP)
    end
    task.delay(2, function()
        if copyBtn and copyBtn.Parent then copyBtn.Text = "点击复制QQ交流群群号" end
    end)
end)
end   -- 简介段结束

local MainPage = CreatePage("主要")
CreateToggle(MainPage, "无限跳", "InfJump", State.InfJump, function(v) State.InfJump = v end)
CreateToggle(MainPage, "穿墙", "Noclip", State.Noclip, function(v)
    local prev = State.Noclip
    State.Noclip = v
    -- 关闭时把碰撞体还回去（同 xk 的 NoClip 关掉后 CanCollide = true）
    if not v and prev and LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then pcall(function() part.CanCollide = true end) end
        end
    end
end)
-- 踏空行走：在脚下铺隐形平台，站在上面可以在空中行走（移植自 xk 主页面）
CreateToggle(MainPage, "踏空行走 (空中铺隐形平台)", "SkyWalk", State.SkyWalk, function(v) SkyWalk.Set(v) end)
-- 即时互动：按住提示不用等（HoldDuration=0），点击检测器距离放大到 500（同 xk 的 InstantInteract）
CreateToggle(MainPage, "即时互动 (提示秒触发 / 点击距离 500)", "InstantInteract", State.InstantInteract, function(v)
    State.InstantInteract = v
    if v then
        ScanInstantInteract()
        local n = 0
        for _ in pairs(InteractBackup) do n = n + 1 end
        print("[NARAMO] 即时互动: 已开启，接管 " .. tostring(n) .. " 个交互点")
    else
        local n = RestoreInstantInteract()
        if n > 0 then print("[NARAMO] 即时互动: 已关闭，还原 " .. tostring(n) .. " 个交互点") end
    end
end)
-- PM秒维修：维修小游戏一弹出就直接发 Repair，跳过小游戏（四种小游戏通用），多次维修间隔为 0
CreateToggle(MainPage, "PM秒维修", "WrenchRepair", State.WrenchRepair, function(v)
    State.WrenchRepair = v
    if v then WrenchStartLoop() end
end)
-- PM 靠近自动维修：靠近带 RepairObject 标签的设备就自动补满，不用等小游戏弹出
CreateToggle(MainPage, "PM 靠近自动维修", "WrenchAutoRepair", State.WrenchAutoRepair, function(v)
    State.WrenchAutoRepair = v
    if v then WrenchStartLoop() end
end)
CreateSlider(MainPage, "自动维修距离 (studs)", "WrenchAutoDist", 5, 60, State.WrenchAutoDist, function(v)
    State.WrenchAutoDist = v
end)
-- PM 全场自动维修：自动跑遍全场可修设备（定高滑行，穿墙走直线，不吃虚空）
CreateToggle(MainPage, "PM全场自动维修", "WrenchTour", State.WrenchTour, function(v)
    if v then
        if not Tour.Start() then SetControl("WrenchTour", false) end
    else
        Tour.Stop()
    end
end)
CreateSlider(MainPage, "全场巡回速度 (studs/s)", "WrenchTourSpeed", 20, 150, State.WrenchTourSpeed, function(v)
    State.WrenchTourSpeed = v
end)
CreateSlider(MainPage, "到点判定距离 (studs)", "WrenchTourArrive", 6, 40, State.WrenchTourArrive, function(v)
    State.WrenchTourArrive = v
end)
-- 对付「刚修好就掉到 99%」的设备：高于阈值不修，修过之后一段时间不再去
CreateSlider(MainPage, "重复维修冷却 (秒)", "WrenchTourCooldown", 30, 600, State.WrenchTourCooldown, function(v)
    State.WrenchTourCooldown = v
end)
CreateSlider(MainPage, "耐久高于此值不修 (%)", "WrenchSkipAbove", 50, 100, State.WrenchSkipAbove, function(v)
    State.WrenchSkipAbove = v
end)
-- 高耐久设备要连修好几次：到点后最多在旁边停留多久
CreateSlider(MainPage, "单台最多停留 (秒)", "WrenchTourHold", 2, 30, State.WrenchTourHold, function(v)
    State.WrenchTourHold = v
end)
-- 在下一个维修目标上画高亮 + 圆点
CreateToggle(MainPage, "标记当前维修目标 (高亮+圆点)", "WrenchTourMark", State.WrenchTourMark, function(v)
    State.WrenchTourMark = v
end)
CreateToggle(MainPage, "全亮", "FullBright", State.FullBright, function(v)
    State.FullBright = v
    if v then
        Lighting.Brightness = 2; Lighting.ClockTime = 14; Lighting.GlobalShadows = false
        Lighting.FogEnd = 1e6; Lighting.Ambient = Color3.new(1,1,1)
    else
        RestoreLighting()   -- 还原进服时的原始光照，而不是硬编码值
    end
end)
CreateToggle(MainPage, "解锁聊天框", "UnlockChat", State.UnlockChat, function(v)
    local want = v or ChatBackup
    pcall(function()
        game:GetService("TextChatService").ChatWindowConfiguration.Enabled = want
        game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Chat, want)
    end)
end)
CreateToggle(MainPage, "解锁 FPS", "UnlockFPS", State.UnlockFPS, function(v) if setfpscap then pcall(setfpscap, v and 9999 or 60) end end)

CreateToggle(MainPage, "开启移速修改", "WalkSpeedEnabled", State.WalkSpeedEnabled, function(v)
    local prev = State.WalkSpeedEnabled
    State.WalkSpeedEnabled = v
    -- 关闭时回到默认速度，避免角色卡在 150 速度上（同 xk 的 dn()）
    if not v and prev and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 16 end
    end
end)
CreateSlider(MainPage, "移动速度 (建议<50)", "WalkSpeedValue", 16, 150, State.WalkSpeedValue, function(v) 
    State.WalkSpeedValue = v 
    if State.WalkSpeedEnabled and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = v end
    end
end)

CreateToggle(MainPage, "无限子弹 (开启/重生时生效)", "InfiniteAmmo", State.InfiniteAmmo, function(v)
    State.InfiniteAmmo = v
    if v then
        UpdateAmmoTable(true)
        LockAllAmmo()      -- 扫描完立刻上锁：读恒 9999，写被丢弃
        RefreshAmmoInstances()
        AmmoNextScan = os.clock() + 10
        print("[NARAMO] 无限子弹: " .. AmmoStatusText())
    else
        RestoreAmmoTable()
        print("[NARAMO] 无限子弹: 已关闭并还原原值")
    end
end)
CreateToggle(MainPage, "弹药兼容模式(只轮询,不动元表)", "AmmoPollOnly", State.AmmoPollOnly, function(v)
    State.AmmoPollOnly = v
    if State.InfiniteAmmo then
        RestoreAmmoTable()          -- 先把已锁的解开、原值还原
        UpdateAmmoTable(true)
        LockAllAmmo()
        AmmoNextScan = os.clock() + 10
        print("[NARAMO] 弹药模式: " .. (v and "轮询写回" or "元表锁定") .. " | " .. AmmoStatusText())
    end
end)

-- 绘制页面
local DrawPage = CreatePage("绘制")
CreateToggle(DrawPage, "开启绘制", "ESPEnabled", State.ESPEnabled, function(v) State.ESPEnabled = v end)
CreateToggle(DrawPage, "高亮透视", "ESPHighlight", State.ESPHighlight, function(v) State.ESPHighlight = v end)
CreateToggle(DrawPage, "方框", "ESPBox", State.ESPBox, function(v) State.ESPBox = v end)
CreateToggle(DrawPage, "名字", "ESPName", State.ESPName, function(v) State.ESPName = v end)
CreateToggle(DrawPage, "血量", "ESPHealth", State.ESPHealth, function(v) State.ESPHealth = v end)
CreateToggle(DrawPage, "距离", "ESPDistance", State.ESPDistance, function(v) State.ESPDistance = v end)
CreateToggle(DrawPage, "天线", "ESPTracer", State.ESPTracer, function(v) State.ESPTracer = v end)
CreateToggle(DrawPage, "绘制队友", "ESPTeammates", State.ESPTeammates, function(v) State.ESPTeammates = v end)
CreateSlider(DrawPage, "最远绘制距离 (studs)", "ESPMaxDist", 100, 5000, State.ESPMaxDist, function(v) State.ESPMaxDist = v end)
CreateButton(DrawPage, "切换颜色", function() State.ESPColorIdx = (State.ESPColorIdx % #Colors) + 1 end)

-- 自瞄页面
local AimbotPage = CreatePage("自瞄")
CreateToggle(AimbotPage, "开启自瞄 (按住右键 / 移动端悬浮按钮)", "AimbotEnabled", State.AimbotEnabled, function(v)
    State.AimbotEnabled = v
    if not v then
        State.AimMobileActive = false
        MobileAimBtn.Text = "自瞄: 关"
        MobileAimBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    end
end)
CreateToggle(AimbotPage, "显示 FOV 圈", "ShowFOV", State.ShowFOV, function(v) State.ShowFOV = v end)
CreateSlider(AimbotPage, "FOV 范围", "AimbotFOV", 20, 500, State.AimbotFOV, function(v) State.AimbotFOV = v end)
CreateSlider(AimbotPage, "最远自瞄距离 (studs)", "AimMaxDist", 50, 5000, State.AimMaxDist, function(v) State.AimMaxDist = v end)
CreateToggle(AimbotPage, "移动预判", "AimbotPredict", State.AimbotPredict, function(v) State.AimbotPredict = v end)
CreateSlider(AimbotPage, "子弹速度", "AimbotSpeed", 100, 5000, State.AimbotSpeed, function(v) State.AimbotSpeed = v end)

-- 打僵尸 / NPC 页面（活动期间用；绘制与自瞄是两个独立开关，互不依赖）
local NpcPage = CreatePage("打僵尸")
CreateToggle(NpcPage, "绘制 NPC (独立开关)", "NPCESPEnabled", State.NPCESPEnabled, function(v) State.NPCESPEnabled = v end)
CreateToggle(NpcPage, "NPC 方框", "NPCESPBox", State.NPCESPBox, function(v) State.NPCESPBox = v end)
CreateToggle(NpcPage, "NPC 名字", "NPCESPName", State.NPCESPName, function(v) State.NPCESPName = v end)
CreateToggle(NpcPage, "NPC 血量", "NPCESPHealth", State.NPCESPHealth, function(v) State.NPCESPHealth = v end)
CreateToggle(NpcPage, "NPC 距离", "NPCESPDistance", State.NPCESPDistance, function(v) State.NPCESPDistance = v end)
CreateSlider(NpcPage, "NPC 最远显示距离", "NPCESPMaxDist", 50, 3000, State.NPCESPMaxDist, function(v) State.NPCESPMaxDist = v end)
CreateSlider(NpcPage, "NPC 最多显示数量", "NPCESPLimit", 1, 200, State.NPCESPLimit, function(v) State.NPCESPLimit = v end)
CreateInput(NpcPage, "只看名字包含…(留空=全部，回车生效)", function(text)
    State.NPCNameFilter = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end)
CreateToggle(NpcPage, "无 Humanoid 的僵尸也画 (Hitbox)", "NPCHitboxMode", State.NPCHitboxMode, function(v) State.NPCHitboxMode = v end)
CreateToggle(NpcPage, "自瞄 NPC (按住右键 / 移动端悬浮按钮)", "NPCAimEnabled", State.NPCAimEnabled, function(v)
    State.NPCAimEnabled = v
    if not v then
        State.NpcAimMobileActive = false
        MobileNpcAimBtn.Text = "僵尸自瞄: 关"
        MobileNpcAimBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    end
end)
CreateSlider(NpcPage, "NPC 自瞄范围", "NPCAimFOV", 20, 800, State.NPCAimFOV, function(v) State.NPCAimFOV = v end)

-- 车辆页面
local VehiclePage = CreatePage("车辆")
CreateToggle(VehiclePage, "速度强制推进 (按住 W 才生效)", "VehiclePushEnabled", State.VehiclePushEnabled, function(v) State.VehiclePushEnabled = v end)
CreateSlider(VehiclePage, "推进目标速度", "VehiclePushSpeed", 20, 500, State.VehiclePushSpeed, function(v) State.VehiclePushSpeed = v end)
CreateSlider(VehiclePage, "推进平滑度 (越大加速越猛)", "VehiclePushSmooth", 1, 40, State.VehiclePushSmooth, function(v) State.VehiclePushSmooth = v end)
CreateToggle(VehiclePage, "松开 W 立即刹停", "VehiclePushBrake", State.VehiclePushBrake, function(v) State.VehiclePushBrake = v end)
CreateToggle(VehiclePage, "自动校准车头方向 (实测, 不靠模型轴向)", "VehiclePushAutoCal", State.VehiclePushAutoCal, function(v) State.VehiclePushAutoCal = v end)
CreateButton(VehiclePage, "重新校准车头方向", function()
    for k in pairs(VehicleForward) do VehicleForward[k] = nil end
    for k in pairs(ForwardWarned) do ForwardWarned[k] = nil end
    ForwardCalib.acc, ForwardCalib.hits, ForwardCalib.lastSpeed = nil, 0, 0
    print("[NARAMO] 车头方向已清空：关掉悬浮，在地上按住 W 开一下就会自动重新学习")
end)
CreateToggle(VehiclePage, "强制转向 (按 A/D 原地掉头)", "VehicleTurnEnabled", State.VehicleTurnEnabled, function(v) State.VehicleTurnEnabled = v end)
CreateSlider(VehiclePage, "原地转向速度 (度/秒)", "VehicleTurnRate", 30, 720, State.VehicleTurnRate, function(v) State.VehicleTurnRate = v end)

-- 整车悬浮：固定高度 + 姿态锁平（车头不翘、高速不会翻转），高度上限硬夹在 20 studs。
CreateToggle(VehiclePage, "整车悬浮 (锁平不翘头, 离地≤20)", "VehicleHoverEnabled", State.VehicleHoverEnabled, function(v)
    State.VehicleHoverEnabled = v
    if v then
        print("[NARAMO] 整车悬浮: 已开启，离地 " .. tostring(math.clamp(State.VehicleHoverHeight or 8, 1, 20)) .. " studs，姿态已锁平")
    end
end)
CreateSlider(VehiclePage, "悬浮高度 (越高越容易被检测)", "VehicleHoverHeight", 1, 20, State.VehicleHoverHeight, function(v)
    State.VehicleHoverHeight = v
end)
CreateSlider(VehiclePage, "悬浮跟随速度 (越大贴地越紧)", "VehicleHoverGain", 2, 20, State.VehicleHoverGain, function(v) State.VehicleHoverGain = v end)

-- 队伍页面（管理 / 高价值目标）
local TeamPage = CreatePage("队伍")
CreateToggle(TeamPage, "重点目标高亮 (管理/高价值)", "TeamHighlightEnabled", State.TeamHighlightEnabled, function(v) State.TeamHighlightEnabled = v end)
CreateToggle(TeamPage, "发现时打印提示", "TeamNotifyEnabled", State.TeamNotifyEnabled, function(v) State.TeamNotifyEnabled = v end)
local adminKwBox = CreateInput(TeamPage, "管理员队伍关键词(逗号分隔)", function(text)
    State.AdminTeamKeywords = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end)
adminKwBox.Text = State.AdminTeamKeywords
local hvKwBox = CreateInput(TeamPage, "高价值队伍关键词(逗号分隔)", function(text)
    State.HVTeamKeywords = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end)
hvKwBox.Text = State.HVTeamKeywords

-- 反管理页面
local AdminPage = CreatePage("反管理")

-- 判断某玩家是不是管理员：名字在名单里，或者 Unit/队伍命中管理员关键词（比如"联邦政府"）
local function IsAdminPlayer(player)
    for _, target in ipairs(State.UserList) do
        if string.lower(player.Name) == string.lower(target) then
            return true, "名单"
        end
    end
    -- 队伍判定函数在脚本后半段才赋值，配置自动加载时可能还没就绪，这里做个保护
    if type(GetPlayerTeamText) == "function" and type(MatchKeywords) == "function" then
        local ok, text = pcall(GetPlayerTeamText, player)
        if ok and type(text) == "string" and MatchKeywords(text, State.AdminTeamKeywords) then
            return true, "队伍"
        end
    end
    return false, nil
end

CreateToggle(AdminPage, "自动检测管理员", "AutoCheck", State.AutoCheck, function(v)
    State.AutoCheck = v
    if AutoCheckThread then pcall(task.cancel, AutoCheckThread); AutoCheckThread = nil end
    if v then
        AutoCheckThread = task.spawn(function()
            while State.AutoCheck and not IsClosing do
                local foundName, foundWhy = nil, nil
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer then
                        local okCall, isAdmin, why = pcall(IsAdminPlayer, p)
                        if okCall and isAdmin then foundName, foundWhy = p.Name, why; break end
                    end
                end

                if foundName then
                    print(string.format("[NARAMO] 检测到管理员: %s（来源: %s）", foundName, tostring(foundWhy)))
                    if State.DisableOnAdmin then DisableAllFeatures() end
                    if State.AutoExit then LocalPlayer:Kick("Admin Detected") end
                end
                task.wait(State.CheckInterval)
            end
            AutoCheckThread = nil
        end)
    end
end)
CreateToggle(AdminPage, "发现管理时关闭所有功能", "DisableOnAdmin", State.DisableOnAdmin, function(v) State.DisableOnAdmin = v end)
CreateToggle(AdminPage, "发现管理时自动退服", "AutoExit", State.AutoExit, function(v) State.AutoExit = v end)
CreateSlider(AdminPage, "检测间隔 (秒)", "CheckInterval", 1, 60, State.CheckInterval, function(v) State.CheckInterval = v end)

-- 手动管理员名单（点击名字可移除）
local AdminListFrame = Instance.new("ScrollingFrame")
AdminListFrame.Size = UDim2.new(1, 0, 0, 140)
AdminListFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
AdminListFrame.BorderSizePixel = 0
AdminListFrame.ScrollBarThickness = 4
AdminListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
AdminListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
AdminListFrame.Parent = AdminPage
Instance.new("UICorner", AdminListFrame).CornerRadius = UDim.new(0, 6)
local adminListLayout = Instance.new("UIListLayout", AdminListFrame)
adminListLayout.Padding = UDim.new(0, 4)
local adminListPad = Instance.new("UIPadding", AdminListFrame)
adminListPad.PaddingTop = UDim.new(0, 6)
adminListPad.PaddingLeft = UDim.new(0, 6)
adminListPad.PaddingRight = UDim.new(0, 6)

local function RefreshAdminList()
    for _, child in ipairs(AdminListFrame:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then child:Destroy() end
    end

    if #State.UserList == 0 then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -12, 0, 24)
        lbl.BackgroundTransparency = 1
        lbl.Text = "（名单为空：输入名字后回车添加）"
        lbl.TextColor3 = Color3.fromRGB(150, 150, 160)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = AdminListFrame
        return
    end

    for i, name in ipairs(State.UserList) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -12, 0, 28)
        btn.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
        btn.BorderSizePixel = 0
        btn.Text = "  " .. name .. "   (点击移除)"
        btn.TextColor3 = Color3.fromRGB(230, 210, 210)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 12
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Parent = AdminListFrame
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        btn.MouseButton1Click:Connect(function()
            local target = State.UserList[i]
            if target then
                print("[NARAMO] 已移除管理员: " .. target)
                table.remove(State.UserList, i)
                RefreshAdminList()
            end
        end)
    end
end

CreateInput(AdminPage, "输入管理员名字，回车添加", function(text)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return end
    for _, n in ipairs(State.UserList) do
        if string.lower(n) == string.lower(text) then
            print("[NARAMO] 这个名字已经在名单里了")
            return
        end
    end
    table.insert(State.UserList, text)
    RefreshAdminList()
    print("[NARAMO] 已添加管理员: " .. text)
end)
CreateButton(AdminPage, "清空管理员名单", function()
    State.UserList = {}
    RefreshAdminList()
    print("[NARAMO] 管理员名单已清空")
end)

RefreshAdminList()

-- 配置页面
local ConfigPage = CreatePage("配置")
local configName = "default"

-- 配置回填：有对应控件就走控件（界面 + State 一起变），没有的直接写 State
-- 对应 xk 里 SaveManager:LoadAutoloadConfig() + 控件:SetValue() 的做法
local function ApplyConfig(data)
    if type(data) ~= "table" then return 0, 0 end
    local uiCount, rawCount = 0, 0
    for k, v in pairs(data) do
        if UIControls[k] then
            if SetControl(k, v) then
                uiCount = uiCount + 1
            else
                State[k] = v; rawCount = rawCount + 1   -- 控件出错时兜底，至少状态是对的
            end
        else
            State[k] = v
            rawCount = rawCount + 1
        end
    end
    -- 兼容手改过的配置：颜色索引越界会直接报错，这里夹一下
    State.ESPColorIdx = math.clamp(tonumber(State.ESPColorIdx) or 1, 1, #Colors)
    if type(State.UserList) ~= "table" then State.UserList = DeepCopy(DefaultState.UserList) end
    if type(RefreshAdminList) == "function" then RefreshAdminList() end
    return uiCount, rawCount
end

local function LoadConfigByName(name)
    local path = CONFIG_FOLDER .. "/" .. name .. ".json"
    if not (isfile and isfile(path)) then return false, "文件不存在" end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok or type(data) ~= "table" then return false, "解析失败" end
    local ui, raw = ApplyConfig(data)
    return true, string.format("界面同步 %d 项 / 直接写入 %d 项", ui, raw)
end

local configNameBox = CreateInput(ConfigPage, "输入配置文件名...", function(text) if text ~= "" then configName = text end end)

-- 已有配置文件列表（自动读取 CONFIG_FOLDER，点一下直接加载）
local ConfigListFrame = Instance.new("ScrollingFrame")
ConfigListFrame.Size = UDim2.new(1, 0, 0, 170)
ConfigListFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
ConfigListFrame.BorderSizePixel = 0
ConfigListFrame.ScrollBarThickness = 4
ConfigListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ConfigListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
ConfigListFrame.Parent = ConfigPage
Instance.new("UICorner", ConfigListFrame).CornerRadius = UDim.new(0, 6)
local cfgListLayout = Instance.new("UIListLayout", ConfigListFrame)
cfgListLayout.Padding = UDim.new(0, 4)
local cfgListPad = Instance.new("UIPadding", ConfigListFrame)
cfgListPad.PaddingTop = UDim.new(0, 6)
cfgListPad.PaddingLeft = UDim.new(0, 6)
cfgListPad.PaddingRight = UDim.new(0, 6)

local function RefreshConfigList()
    for _, child in ipairs(ConfigListFrame:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then child:Destroy() end
    end

    local names = {}
    local ok, files = pcall(function() return listfiles(CONFIG_FOLDER) end)
    if ok and type(files) == "table" then
        for _, path in ipairs(files) do
            local name = tostring(path):match("([^/\\]+)%.json$")
            if name then table.insert(names, name) end
        end
    end
    table.sort(names)

    if #names == 0 then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -12, 0, 24)
        lbl.BackgroundTransparency = 1
        lbl.Text = ok and "（还没有已保存的配置）" or "（当前执行器不支持 listfiles）"
        lbl.TextColor3 = Color3.fromRGB(150, 150, 160)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = ConfigListFrame
        return 0
    end

    for _, name in ipairs(names) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -12, 0, 28)
        btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        btn.BorderSizePixel = 0
        btn.Text = "  " .. name
        btn.TextColor3 = Color3.fromRGB(220, 220, 225)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 12
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Parent = ConfigListFrame
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        btn.MouseButton1Click:Connect(function()
            configName = name
            if configNameBox then configNameBox.Text = name end
            local okLoad, msg = LoadConfigByName(name)
            print(okLoad and ("配置已加载: " .. name .. " (" .. msg .. ")")
                or ("配置加载失败: " .. name .. " - " .. msg))
        end)
    end
    return #names
end

CreateButton(ConfigPage, "刷新配置列表", function()
    local n = RefreshConfigList()
    print("[NARAMO] 配置列表已刷新，共 " .. tostring(n) .. " 个")
end)

CreateButton(ConfigPage, "保存当前配置", function()
    local path = CONFIG_FOLDER .. "/" .. configName .. ".json"
    if writefile then
        local ok, err = pcall(function() writefile(path, HttpService:JSONEncode(State)) end)
        print(ok and ("配置已保存: " .. path) or ("配置保存失败: " .. tostring(err)))
        if ok then RefreshConfigList() end
    end
end)
CreateButton(ConfigPage, "加载当前配置", function()
    local ok, msg = LoadConfigByName(configName)
    print(ok and ("配置已加载: " .. configName .. " (" .. msg .. ")") or ("配置加载失败: " .. configName .. " - " .. msg))
end)
CreateButton(ConfigPage, "删除当前配置", function()
    local path = CONFIG_FOLDER .. "/" .. configName .. ".json"
    if isfile and isfile(path) then
        pcall(function() delfile(path) end)
        print("配置已删除: " .. configName)
        RefreshConfigList()
    end
end)
CreateButton(ConfigPage, "设为自动加载", function()
    local path = CONFIG_FOLDER .. "/" .. configName .. ".json"
    if isfile and isfile(path) then
        pcall(function() writefile(CONFIG_FOLDER .. "/_auto.txt", configName) end)
        print("已设为自动加载: " .. configName)
    end
end)

-- 自动加载放在所有控件创建之后：此时 UIControls 已齐全，勾选状态也能同步
if isfile and isfile(CONFIG_FOLDER .. "/_auto.txt") then
    local okRead, autoName = pcall(readfile, CONFIG_FOLDER .. "/_auto.txt")
    if okRead and autoName then
        autoName = autoName:gsub("^%s+", ""):gsub("%s+$", "")   -- 去掉文件尾换行
        local ok, msg = LoadConfigByName(autoName)
        print(ok and ("已自动加载配置: " .. autoName .. " (" .. msg .. ")") or ("自动加载失败: " .. autoName .. " - " .. msg))
    end
end

RefreshConfigList()

-- ============================ 后台执行逻辑 ============================
Track(UserInputService.JumpRequest:Connect(function()
    if State.InfJump and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

Track(RunService.Stepped:Connect(function()
    if IsClosing then return end
    if State.Noclip and LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end))

Track(RunService.Heartbeat:Connect(function()
    if IsClosing then return end
    if State.WalkSpeedEnabled and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.WalkSpeed ~= State.WalkSpeedValue then hum.WalkSpeed = State.WalkSpeedValue end
    end
end))

-- ESP 容器：优先 gethui()，退回 CoreGui / PlayerGui（同 xk 的 bm() 做法）
local function GetESPContainer()
    local ok, hui = pcall(function() return gethui() end)
    if ok and hui then return hui end
    local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and cg then return cg end
    return PlayerGui
end

ESPFolder = Instance.new("Folder")
ESPFolder.Name = "NARAMO_ESP"
pcall(function() ESPFolder.Parent = GetESPContainer() end)

local function HideESP(esp)
    if esp.Box then esp.Box.Visible = false end
    if esp.Name then esp.Name.Visible = false end
    if esp.Distance then esp.Distance.Visible = false end
    if esp.Health then esp.Health.Visible = false end
    if esp.Tracer then esp.Tracer.Visible = false end
    if esp.Highlight then esp.Highlight.Enabled = false end
end

local function RemoveESP(player)
    local esp = ESPObjects[player]
    if not esp then return end
    ESPObjects[player] = nil
    for _, key in ipairs({ "Box", "Name", "Distance", "Health", "Tracer" }) do
        local obj = esp[key]
        if obj then pcall(function() obj:Remove() end) end
    end
    if esp.Highlight then pcall(function() esp.Highlight:Destroy() end) end
end

ClearAllESP = function()
    local list = {}
    for player in pairs(ESPObjects) do table.insert(list, player) end
    for _, player in ipairs(list) do RemoveESP(player) end
end

local function CreateESP(player)
    if player == LocalPlayer then return end
    if ESPObjects[player] then RemoveESP(player) end
    if not HasDrawing then return end
    local esp = {}
    pcall(function()
        local Box = Drawing.new("Square"); Box.Thickness = 1.5; Box.Filled = false; Box.Visible = false
        local NameText = Drawing.new("Text"); NameText.Size = 14; NameText.Center = true; NameText.Outline = true; NameText.Visible = false
        local DistanceText = Drawing.new("Text"); DistanceText.Size = 12; DistanceText.Center = true; DistanceText.Outline = true; DistanceText.Visible = false
        local HealthText = Drawing.new("Text"); HealthText.Size = 12; HealthText.Center = true; HealthText.Outline = true; HealthText.Visible = false
        local Tracer = Drawing.new("Line"); Tracer.Thickness = 1; Tracer.Transparency = 0.7; Tracer.Visible = false
        esp.Box = Box; esp.Name = NameText; esp.Distance = DistanceText; esp.Health = HealthText; esp.Tracer = Tracer
    end)
    pcall(function()
        local Highlight = Instance.new("Highlight")
        Highlight.Name = "NARAMO_HL"; Highlight.FillTransparency = 0.5; Highlight.OutlineTransparency = 0
        Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; Highlight.Enabled = false
        Highlight.Parent = ESPFolder
        esp.Highlight = Highlight
    end)
    ESPObjects[player] = esp
end

Track(Players.PlayerAdded:Connect(CreateESP))
Track(Players.PlayerRemoving:Connect(RemoveESP))
for _, p in ipairs(Players:GetPlayers()) do CreateESP(p) end

TrackThread(task.spawn(function()
    while not IsClosing do
        task.wait(0.2)
        if IsClosing then break end
        if State.ESPEnabled and State.ESPDistance and LocalPlayer.Character then
            local lhrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if lhrp then
                for player, esp in pairs(ESPObjects) do
                    local char = player.Character
                    local prp = char and char:FindFirstChild("HumanoidRootPart")
                    if prp and esp.Distance then
                        esp.Distance.Text = math.floor((lhrp.Position - prp.Position).Magnitude) .. "m"
                    end
                end
            end
        end
    end
end))

-- ============================ 队伍识别（管理 / 高价值目标） ============================
-- Roblox 原生的 player.Team + 玩家/角色身上的 Attribute 都可能是队伍信息
local TeamTextCache = {}

GetPlayerTeamText = function(player)
    local now = os.clock()
    local cached = TeamTextCache[player]
    if cached and (now - cached.at) < 2 then return cached.text end

    local parts = {}
    pcall(function()
        if player.Team then table.insert(parts, player.Team.Name) end
    end)
    pcall(function()
        for k, v in pairs(player:GetAttributes()) do
            table.insert(parts, tostring(k))
            if type(v) == "string" then table.insert(parts, v) end
        end
    end)
    local char = player.Character
    if char then
        pcall(function()
            for k, v in pairs(char:GetAttributes()) do
                table.insert(parts, tostring(k))
                if type(v) == "string" then table.insert(parts, v) end
            end
            for _, c in ipairs(char:GetChildren()) do
                if c:IsA("ValueBase") then table.insert(parts, c.Name) end
            end
        end)
    end

    local text = string.lower(table.concat(parts, " "))
    TeamTextCache[player] = { text = text, at = now }
    return text
end

MatchKeywords = function(text, keywords)
    if type(keywords) ~= "string" or keywords == "" then return false end
    for word in string.gmatch(string.lower(keywords), "[^,%s]+") do
        if string.find(text, word, 1, true) then return true end
    end
    return false
end

-- 返回 标签, 特殊颜色
local ADMIN_COLOR = Color3.fromRGB(255, 60, 60)
local HV_COLOR = Color3.fromRGB(255, 200, 40)
local TaggedSeen = {}

GetPlayerTag = function(player)
    if not State.TeamHighlightEnabled then return "", nil end
    local text = GetPlayerTeamText(player)

    local tag, color, kind
    if MatchKeywords(text, State.AdminTeamKeywords) then
        tag, color, kind = " [管理]", ADMIN_COLOR, "管理"
    elseif MatchKeywords(text, State.HVTeamKeywords) then
        tag, color, kind = " [高价值]", HV_COLOR, "高价值"
    else
        return "", nil
    end

    if State.TeamNotifyEnabled and not TaggedSeen[player] then
        TaggedSeen[player] = true
        print(string.format("[NARAMO] 发现%s: %s", kind, player.Name))
    end
    return tag, color
end

Track(RunService.RenderStepped:Connect(function()
    if IsClosing then return end
    -- 总开关关闭时把残留全部隐藏（不再每帧报错）
    if not State.ESPEnabled then
        for _, esp in pairs(ESPObjects) do HideESP(esp) end
        return
    end

    local cam = workspace.CurrentCamera
    if not cam then return end
    local currentColor = Colors[State.ESPColorIdx] or Colors[1]

    -- 距离限制：超出「最远绘制距离」的人不画
    local maxDist = State.ESPMaxDist or 1000
    local myChar = LocalPlayer.Character
    local myPart = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myPos = myPart and myPart.Position or cam.CFrame.Position

    for player, esp in pairs(ESPObjects) do
        local isTeammate = LocalPlayer.Team and player.Team and (LocalPlayer.Team == player.Team)
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        -- 管理 / 高价值目标：特殊颜色 + 名称后缀，且即使同队也画
        local tag, specialColor = GetPlayerTag(player)

        local tooFar = false
        if char then
            local okPivot, pivot = pcall(function() return char:GetPivot() end)
            if okPivot and pivot then
                tooFar = (pivot.Position - myPos).Magnitude > maxDist
            end
        end

        -- 队友默认不画；开了「绘制队友」才画，并用绿色区分
        local drawTeammate = isTeammate and State.ESPTeammates
        if (isTeammate and not State.ESPTeammates and not specialColor)
            or tooFar or not char or not hum or hum.Health <= 0 then
            HideESP(esp)
        else
            local rowColor = specialColor or (drawTeammate and TEAMMATE_COLOR or currentColor)
            pcall(function()
                if State.ESPHighlight and esp.Highlight then
                    if esp.Highlight.Adornee ~= char then esp.Highlight.Adornee = char end
                    esp.Highlight.FillColor = rowColor; esp.Highlight.OutlineColor = rowColor; esp.Highlight.Enabled = true
                elseif esp.Highlight then
                    esp.Highlight.Enabled = false
                end
                if not esp.Box then return end

                local cf, sz = char:GetBoundingBox()
                local corners = {
                    cf * CFrame.new(-sz.X/2, -sz.Y/2, -sz.Z/2), cf * CFrame.new( sz.X/2, -sz.Y/2, -sz.Z/2),
                    cf * CFrame.new( sz.X/2,  sz.Y/2, -sz.Z/2), cf * CFrame.new(-sz.X/2,  sz.Y/2, -sz.Z/2),
                    cf * CFrame.new(-sz.X/2, -sz.Y/2,  sz.Z/2), cf * CFrame.new( sz.X/2, -sz.Y/2,  sz.Z/2),
                    cf * CFrame.new( sz.X/2,  sz.Y/2,  sz.Z/2), cf * CFrame.new(-sz.X/2,  sz.Y/2,  sz.Z/2)
                }

                local minX, minY, maxX, maxY, onScreen = math.huge, math.huge, -math.huge, -math.huge, false

                for _, corner in ipairs(corners) do
                    local pos, onScr = cam:WorldToViewportPoint(corner.Position)
                    if onScr then
                        onScreen = true
                        minX = math.min(minX, pos.X); minY = math.min(minY, pos.Y)
                        maxX = math.max(maxX, pos.X); maxY = math.max(maxY, pos.Y)
                    end
                end

                if onScreen then
                    esp.Box.Color = rowColor; esp.Box.Size = Vector2.new(maxX - minX, maxY - minY); esp.Box.Position = Vector2.new(minX, minY); esp.Box.Visible = State.ESPBox
                    esp.Name.Text = player.Name .. (drawTeammate and " [队友]" or "") .. tag
                    esp.Name.Color = rowColor; esp.Name.Position = Vector2.new((minX + maxX)/2, minY - 20); esp.Name.Visible = State.ESPName
                    esp.Health.Text = "HP: " .. math.floor(hum.Health) .. " / " .. math.floor(hum.MaxHealth); esp.Health.Color = rowColor; esp.Health.Position = Vector2.new((minX + maxX)/2, minY - 36); esp.Health.Visible = State.ESPHealth
                    esp.Distance.Color = rowColor; esp.Distance.Position = Vector2.new((minX + maxX)/2, maxY + 5); esp.Distance.Visible = State.ESPDistance

                    if State.ESPTracer then
                        esp.Tracer.From = Vector2.new(cam.ViewportSize.X / 2, 0); esp.Tracer.To = Vector2.new((minX + maxX)/2, minY); esp.Tracer.Color = rowColor; esp.Tracer.Visible = true
                    else
                        esp.Tracer.Visible = false
                    end
                else
                    HideESP(esp)
                end
            end)
        end
    end
end))

-- ============================ NPC / 僵尸：缓存 + 绘制 ============================
-- 缓存只记"哪些 Model 算 NPC"，绘制对象按需创建。
-- NPC 绘制与 NPC 自瞄共用这份缓存，但两个开关彼此独立。
local NPCCache = {}          -- model -> true
local NPCESPObjects = {}     -- model -> { Box, Name, Health, Distance }
local NPCLastScan = 0
local NPC_COLOR = Color3.fromRGB(255, 120, 40)

local function NPCNeeded()
    return State.NPCESPEnabled or State.NPCAimEnabled
end

-- 兼容两种结构：Humanoid 是模型的直接子对象（最常见），或埋得更深
local function GetHumanoid(model)
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum then return hum end
    return model:FindFirstChildWhichIsA("Humanoid", true)
end

-- 取一个可定位的部件：普通 NPC 用 Head/HRP；只有 Hitbox 的活动怪就用那个 Hitbox
local function GetNPCPart(model)
    return model:FindFirstChild("Hitbox")
        or model:FindFirstChild("Head")
        or model:FindFirstChild("HumanoidRootPart")
        or model.PrimaryPart
        or model:FindFirstChildWhichIsA("BasePart", true)
end

-- 名字过滤：匹配模型名，或它直接父级的名字（填 Zombie / EventNPCs 都能筛）
-- 刻意不用 GetFullName：一次扫描要过一万多个模型，逐层拼路径会明显卡顿
local function NPCMatchesFilter(model)
    local f = State.NPCNameFilter
    if f == nil or f == "" then return true end
    f = string.lower(f)
    if string.find(string.lower(model.Name), f, 1, true) then return true end
    local parent = model.Parent
    if parent then
        return string.find(string.lower(parent.Name), f, 1, true) ~= nil
    end
    return false
end

-- 自动识别"只剩 Hitbox"的活动怪：没有 Humanoid，但名字/路径带这些词
local HITBOX_KEYWORDS = { "zombie", "僵尸", "丧尸", "hostile", "undead", "infected" }
local function MatchesAnyKeyword(model, words)
    local name = string.lower(model.Name)
    for _, w in ipairs(words) do
        if string.find(name, w, 1, true) then return true end
    end
    return false
end

local function IsHitboxTarget(model)
    if not State.NPCHitboxMode then return false end
    if GetNPCPart(model) == nil then return false end
    return MatchesAnyKeyword(model, HITBOX_KEYWORDS)
end

-- 统一判活：NaN 血量也算死（有些展示骨架 Health 是 NaN，肉眼看是 -9e18）
local function IsNPCAlive(model)
    local hum = GetHumanoid(model)
    if hum then return hum.Health > 0 end
    if State.NPCNameFilter ~= "" then
        return GetNPCPart(model) ~= nil and NPCMatchesFilter(model)
    end
    return IsHitboxTarget(model)
end

local function IsNPCModel(model)
    if not model:IsA("Model") then return false end
    if model == LocalPlayer.Character then return false end
    if Players:GetPlayerFromCharacter(model) then return false end   -- 排除真人玩家角色
    return IsNPCAlive(model)
end

local function HideNPCESP(esp)
    if esp.Box then esp.Box.Visible = false end
    if esp.Name then esp.Name.Visible = false end
    if esp.Health then esp.Health.Visible = false end
    if esp.Distance then esp.Distance.Visible = false end
end

local function RemoveNPCESP(model)
    local esp = NPCESPObjects[model]
    if not esp then return end
    NPCESPObjects[model] = nil
    for _, key in ipairs({ "Box", "Name", "Health", "Distance" }) do
        local obj = esp[key]
        if obj then pcall(function() obj:Remove() end) end
    end
end

ClearAllNPCESP = function()
    local list = {}
    for model in pairs(NPCESPObjects) do table.insert(list, model) end
    for _, model in ipairs(list) do RemoveNPCESP(model) end
    NPCCache = {}
end

local function CreateNPCESP(model)
    if not HasDrawing then return nil end
    local esp = {}
    local ok = pcall(function()
        esp.Box = Drawing.new("Square"); esp.Box.Thickness = 1.5; esp.Box.Filled = false; esp.Box.Visible = false
        esp.Name = Drawing.new("Text"); esp.Name.Size = 13; esp.Name.Center = true; esp.Name.Outline = true; esp.Name.Visible = false
        esp.Health = Drawing.new("Text"); esp.Health.Size = 11; esp.Health.Center = true; esp.Health.Outline = true; esp.Health.Visible = false
        esp.Distance = Drawing.new("Text"); esp.Distance.Size = 11; esp.Distance.Center = true; esp.Distance.Outline = true; esp.Distance.Visible = false
    end)
    if not ok then return nil end
    NPCESPObjects[model] = esp
    return esp
end

local function NPCScan()
    local ok = pcall(function()
        local all = workspace:GetDescendants()
        -- 顺着 Humanoid 往上找它所属的 Model：一次遍历就能覆盖"Humanoid 埋深"的情况
        local owners = {}
        for _, obj in ipairs(all) do
            if obj:IsA("Humanoid") then
                local m = obj.Parent
                while m and not m:IsA("Model") do m = m.Parent end
                if m and m ~= LocalPlayer.Character and not Players:GetPlayerFromCharacter(m) then
                    owners[m] = true
                end
            end
        end
        for model in pairs(owners) do
            if model.Parent then NPCCache[model] = true end
        end
        -- 填了名字过滤时，把"没有 Humanoid 但符合过滤、且有部件"的模型也收进来；
        -- 没填过滤但开着 Hitbox 模式时，按关键词抓"只剩 Hitbox 的活动怪"
        if State.NPCNameFilter ~= "" or State.NPCHitboxMode then
            for _, obj in ipairs(all) do
                if obj:IsA("Model") and not owners[obj] then
                    local match = false
                    if State.NPCNameFilter ~= "" then
                        match = NPCMatchesFilter(obj)
                    else
                        match = MatchesAnyKeyword(obj, HITBOX_KEYWORDS)
                    end
                    if match and not Players:GetPlayerFromCharacter(obj) and GetNPCPart(obj) ~= nil then
                        owners[obj] = true
                    end
                end
            end
        end
    end)
end

local function NPCPrune()
    for model in pairs(NPCCache) do
        -- 必须还在 workspace 里：被挪到 ReplicatedStorage/垃圾回收区的模型会在原地留下"空气框"
        if not model:IsDescendantOf(workspace) or not IsNPCAlive(model) then
            NPCCache[model] = nil
            RemoveNPCESP(model)
        end
    end
end

-- 1 秒一次：剔除死亡/消失的；每 10 秒补一次全量扫描（新刷出来的靠 DescendantAdded 即时接住）
TrackThread(task.spawn(function()
    while not IsClosing do
        task.wait(1)
        if IsClosing then break end
        if NPCNeeded() then
            NPCPrune()
            local now = os.clock()
            if now - NPCLastScan > 10 then
                NPCLastScan = now
                NPCScan()
            end
        elseif next(NPCCache) ~= nil then
            ClearAllNPCESP()
        end
    end
end))

Track(workspace.DescendantAdded:Connect(function(obj)
    if IsClosing or not NPCNeeded() then return end
    if obj:IsA("Model") then
        if IsNPCModel(obj) then NPCCache[obj] = true end
    elseif obj:IsA("Humanoid") then
        -- 有时候模型先存在、Humanoid 后挂上去，这种也要接住
        local m = obj.Parent
        while m and not m:IsA("Model") do m = m.Parent end
        if m and IsNPCModel(m) then NPCCache[m] = true end
    end
end))

-- 绘制：只跟「绘制 NPC」开关走，与玩家 ESP 完全独立
Track(RunService.RenderStepped:Connect(function()
    if IsClosing then return end
    if not State.NPCESPEnabled or not HasDrawing then
        for _, esp in pairs(NPCESPObjects) do HideNPCESP(esp) end
        return
    end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local limit = State.NPCESPLimit
    local maxDist = State.NPCESPMaxDist
    local tracked = 0
    -- 只把"当前过滤匹配"的算进配额，避免被过滤掉的 NPC 白占名额
    for m in pairs(NPCESPObjects) do
        if NPCMatchesFilter(m) then tracked = tracked + 1 end
    end

    for model in pairs(NPCCache) do
        local nameOk = NPCMatchesFilter(model)
        local esp = NPCESPObjects[model]
        -- 数量上限只限制"建多少个"，不按帧挑着画，避免超过上限后每帧换一批导致闪烁
        if not esp and nameOk and tracked < limit then
            esp = CreateNPCESP(model)
            if esp then tracked = tracked + 1 end
        end
        if esp then
            local hum = model.Parent and GetHumanoid(model)
            if not nameOk or not model:IsDescendantOf(workspace) or not IsNPCAlive(model) then
                HideNPCESP(esp)
            else
                pcall(function()
                    local cf, sz = model:GetBoundingBox()
                    local dist = (cf.Position - cam.CFrame.Position).Magnitude
                    if dist > maxDist then
                        HideNPCESP(esp)
                        return
                    end

                    local corners = {
                        cf * CFrame.new(-sz.X/2, -sz.Y/2, -sz.Z/2), cf * CFrame.new( sz.X/2, -sz.Y/2, -sz.Z/2),
                        cf * CFrame.new( sz.X/2,  sz.Y/2, -sz.Z/2), cf * CFrame.new(-sz.X/2,  sz.Y/2, -sz.Z/2),
                        cf * CFrame.new(-sz.X/2, -sz.Y/2,  sz.Z/2), cf * CFrame.new( sz.X/2, -sz.Y/2,  sz.Z/2),
                        cf * CFrame.new( sz.X/2,  sz.Y/2,  sz.Z/2), cf * CFrame.new(-sz.X/2,  sz.Y/2,  sz.Z/2)
                    }

                    local minX, minY, maxX, maxY, onScreen = math.huge, math.huge, -math.huge, -math.huge, false
                    for _, corner in ipairs(corners) do
                        local pos, onScr = cam:WorldToViewportPoint(corner.Position)
                        if onScr then
                            onScreen = true
                            minX = math.min(minX, pos.X); minY = math.min(minY, pos.Y)
                            maxX = math.max(maxX, pos.X); maxY = math.max(maxY, pos.Y)
                        end
                    end

                    if onScreen then
                        esp.Box.Color = NPC_COLOR; esp.Box.Size = Vector2.new(maxX - minX, maxY - minY)
                        esp.Box.Position = Vector2.new(minX, minY); esp.Box.Visible = State.NPCESPBox
                        esp.Name.Text = model.Name; esp.Name.Color = NPC_COLOR
                        esp.Name.Position = Vector2.new((minX + maxX)/2, minY - 18); esp.Name.Visible = State.NPCESPName
                        if hum then
                            esp.Health.Text = "HP: " .. math.floor(hum.Health) .. " / " .. math.floor(hum.MaxHealth)
                            esp.Health.Color = NPC_COLOR
                            esp.Health.Position = Vector2.new((minX + maxX)/2, minY - 34)
                            esp.Health.Visible = State.NPCESPHealth
                        else
                            esp.Health.Visible = false      -- 只有 Hitbox 的目标没有血量
                        end
                        esp.Distance.Text = math.floor(dist) .. "m"; esp.Distance.Color = NPC_COLOR
                        esp.Distance.Position = Vector2.new((minX + maxX)/2, maxY + 4); esp.Distance.Visible = State.NPCESPDistance
                    else
                        HideNPCESP(esp)
                    end
                end)
            end
        end
    end
end))

local function GetPredictPosition(part)
    if not State.AimbotPredict then return part.Position end
    local distance = (part.Position - workspace.CurrentCamera.CFrame.Position).Magnitude
    local travelTime = distance / State.AimbotSpeed
    local vel = part.AssemblyLinearVelocity or Vector3.new(0,0,0)
    return part.Position + (vel * travelTime)
end

local function GetClosestTarget()
    local closest, closestDist = nil, State.AimbotFOV
    local cam = workspace.CurrentCamera
    local screenCenter = cam.ViewportSize / 2
    local myChar = LocalPlayer.Character
    local myPart = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myPos = myPart and myPart.Position or cam.CFrame.Position
    local maxDist = State.AimMaxDist or 1000

    for _, p in ipairs(Players:GetPlayers()) do
        local isTeammate = LocalPlayer.Team and p.Team and (LocalPlayer.Team == p.Team)
        if p ~= LocalPlayer and not isTeammate and p.Character then
            local part = p.Character:FindFirstChild(State.TargetPart) or p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if part and hum and hum.Health > 0 then
                -- 世界距离限制：超出「最远自瞄距离」不锁
                if (part.Position - myPos).Magnitude <= maxDist then
                    local predPos = GetPredictPosition(part)
                    local screenPos, onScreen = cam:WorldToViewportPoint(predPos)
                    if onScreen then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                        if dist < closestDist then closestDist = dist; closest = part end
                    end
                end
            end
        end
    end
    return closest, closestDist
end

-- NPC 自瞄的目标选取：走同一份 NPCCache，并按自己的 FOV 半径判定
local function GetClosestNPCTarget()
    local cam = workspace.CurrentCamera
    if not cam then return nil, math.huge end
    local center = cam.ViewportSize / 2
    local myChar = LocalPlayer.Character
    local myPart = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myPos = myPart and myPart.Position or cam.CFrame.Position
    local maxDist = State.AimMaxDist or 1000
    local best, bestDist = nil, State.NPCAimFOV
    for model in pairs(NPCCache) do
        local nameOk = NPCMatchesFilter(model)
        local hum = nameOk and model.Parent and GetHumanoid(model)
        local part = nameOk and model.Parent and GetNPCPart(model)
        if part and part.Parent and (hum == nil or hum.Health > 0)
            and (part.Position - myPos).Magnitude <= maxDist then
            local screenPos, onScreen = cam:WorldToViewportPoint(GetPredictPosition(part))
            if onScreen then
                local d = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                if d < bestDist then bestDist = d; best = part end
            end
        end
    end
    return best, bestDist
end

-- ============ 自瞄锁定：按住右键只锁一个人（粘性锁） ============
-- 旧逻辑每帧都重新挑“离准心最近”的目标：旁边有人经过、或者对手贴近时，
-- 准心会在几个人之间来回跳。现在改成：
--   按下的那一帧选一次目标 → 整个按住期间只跟它，不再重新挑选；
--   只有目标死亡/消失，或者松开按键 / 关掉开关，才会换人。
local AimLockPart = nil
local AimLockIsNPC = false
local AimLockHeld = false

-- 顺着部件往上找它所属的 Model（玩家角色；NPC 的 Hitbox 可能埋在模型里）
local function GetAimTargetModel(part)
    local node = part
    while node and not node:IsA("Model") do node = node.Parent end
    return node
end

-- 锁住的目标还能不能继续瞄：活着、还在 workspace、类型没变
local function IsAimLockValid(part, isNPC)
    if not part or not part:IsDescendantOf(workspace) then return false end
    local model = GetAimTargetModel(part)
    if not model then return false end
    if isNPC then
        if Players:GetPlayerFromCharacter(model) then return false end   -- 这个模型变成玩家角色了
    elseif not Players:GetPlayerFromCharacter(model) then
        return false
    end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum then return hum.Health > 0 end
    return isNPC                     -- 只剩 Hitbox 的活动怪没有 Humanoid，有部件就继续锁
end

-- 只在“需要选人”的时候调用：两个自瞄都开时，取屏幕上离准心更近的那个
local function PickAimTarget(playerActive, npcActive)
    local target, targetIsNPC, bestDist = nil, false, math.huge
    if playerActive then
        local part, d = GetClosestTarget()
        if part and d < bestDist then target, targetIsNPC, bestDist = part, false, d end
    end
    if npcActive then
        local part, d = GetClosestNPCTarget()
        if part and d < bestDist then target, targetIsNPC, bestDist = part, true, d end
    end
    return target, targetIsNPC
end

Track(RunService.RenderStepped:Connect(function()
    if IsClosing then return end
    if FOVCircle then
        FOVCircle.Position = workspace.CurrentCamera.ViewportSize / 2
        FOVCircle.Radius = State.AimbotFOV
        FOVCircle.Visible = State.ShowFOV
        FOVCircle.Thickness = 1.5
        FOVCircle.Color = Color3.fromRGB(0, 255, 150)
    end
    -- 移动端悬浮按钮：只在对应自瞄开启时出现
    if MobileAimBtn then MobileAimBtn.Visible = State.AimbotEnabled end
    if MobileNpcAimBtn then MobileNpcAimBtn.Visible = State.NPCAimEnabled end

    local rmb = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    local playerActive = State.AimbotEnabled and (rmb or State.AimMobileActive)
    local npcActive = State.NPCAimEnabled and (rmb or State.NpcAimMobileActive)

    -- 松开右键 / 关掉开关：立刻解除锁定，下次按下重新选人
    if not (playerActive or npcActive) then
        AimLockPart = nil
        AimLockIsNPC = false
        AimLockHeld = false
        if LockText then LockText.Visible = false end
        return
    end

    -- 按下的第一帧：只在这里选一次目标
    if not AimLockHeld then
        AimLockHeld = true
        AimLockPart, AimLockIsNPC = PickAimTarget(playerActive, npcActive)
    end

    -- 目标还活着就继续锁：哪怕他已经走出 FOV、哪怕别人离得更近，都不换人
    local lockActive = (AimLockIsNPC and npcActive) or ((not AimLockIsNPC) and playerActive)
    if not (lockActive and IsAimLockValid(AimLockPart, AimLockIsNPC)) then
        -- 只有目标死亡 / 离开 / 对应开关被关时才会走到这里
        AimLockPart, AimLockIsNPC = PickAimTarget(playerActive, npcActive)
    end

    local target = AimLockPart
    if target then
        local cam = workspace.CurrentCamera
        cam.CFrame = CFrame.new(cam.CFrame.Position, GetPredictPosition(target))
        if LockText then
            local vp = cam.ViewportSize
            local model = GetAimTargetModel(target)
            LockText.Text = "锁定: " .. (model and model.Name or "?")
            LockText.Position = Vector2.new(vp.X / 2 + 26, vp.Y / 2 + 20)
            LockText.Visible = true
        end
    elseif LockText then
        LockText.Visible = false
    end
end))

Track(UserInputService.InputBegan:Connect(function(input, gpe)
    if IsClosing then return end
    if not gpe and input.KeyCode == Enum.KeyCode.RightShift then
        if MiniFrame.Visible then          -- 缩小时按快捷键先展开
            MiniFrame.Visible = false
            MainFrame.Visible = true
        else
            MainFrame.Visible = not MainFrame.Visible
        end
    end
end))

print("[NARAMO] 已加载 " .. SCRIPT_VERSION)