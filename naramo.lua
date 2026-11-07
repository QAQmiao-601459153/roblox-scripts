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
-- 新增 16: 弹速自动读取 —— 换枪自动从 TREK GunConfig 读 ProjectileVelocity（含别名解包），
--          并按 GunConfig 的 ProjectileAcceleration 做下坠补偿；读不到时退回手填滑块
-- 新增 17: 69 把枪的弹速/重力/射程全部硬编码进 GunSpeed.DB（实读失败时自动兜底）；
--          内置管理员用户名名单（mod.txt 里带 @ 的那些真实用户名）作为反管理默认名单
-- 修复 18: 弹速改为"内置表优先"，实读游戏配置降级为手动开关（默认关）——
--          实测 require 游戏配置后枪会拿不上，不能让它跟着换枪自动跑
-- 新增 19: 「反管理」新增自动重置角色 —— 检测到管理员时本地重置角色
--          （断关节 / 血量归零 / Dead 状态三套兜底，上一套不生效还有下一套），
--          同一个管理员只触发一次（连开三轮回合都没再扫到才算离开，离开后再进来会重新触发）
-- 新增 20: 「反管理」检测到管理员时右下角常驻弹窗「检测到管理员: 名字」；
--          自动退服的 Kick 信息里也带上管理员名字；绘制管理员的判定同时认「管理员名单」，
--          管理员（队伍判定 + 名单判定）统一画成灰色；「高价值目标」改名为「植物总监」
-- 新增 21: 「主要」页新增反挂机 —— 固定每 19 分钟模拟一次鼠标左键点击（VirtualInputManager /
--          mouse1click / VirtualUser 三套兜底），刷新闲置计时，防止 20 分钟没输入被服务器踢；
--          另外监听 Idled 事件再补一次点击兜底
-- 新增 22: 「车辆」页新增车辆传送 —— 传送到准星位置 / 传送到输入框坐标 / 记录当前位置。
--          实测（独立测试脚本）客户端对车体有网络所有权，直接摆位置服务器接受、不回弹，
--          所以默认走一帧瞬移，滑行模式留作备用；坐标统一按「车体锚点 (model pivot)」算，
--          记录完再传回去能精确回到原地（早期版本记的是底盘零件，会整体偏一截）
-- 修复 23: 车辆传送的锚点改回「你坐着的那个 VehicleSeat 的位置」——之前用 model:GetPivot()，
--          遇到模型层级套得深 / pivot 定在不动件上的车，车都开出去一段了锚点还在原地，
--          于是记录出来的坐标不对、传送一直提示"已经在这个位置了"。座位位置 100% 跟着车走；
--          同时传送改成「只算平移量」（delta），不再依赖 pivot 的绝对值
-- 新增 24: 「仅持枪时自瞄」—— 手上 Tool 不是枪就不锁（玩家自瞄 + NPC 自瞄都管），
--          判定顺序：内置 69 把枪名表 / 名字里的枪械词 → TConfigToUse 属性对应的
--          GunConfigs.Guns 模块 → 工具里带弹药容器；三条都不命中的，就不是枪。
--          按住右键时右下角会提示「手上不是枪」，FOV 圈在手非枪时变灰，换枪时控制台会说明。
-- 新增 25: 「静默自瞄」—— 不转相机，只在开火那一瞬间把方向改成目标点（原理同 xk 的无声自瞄）。
--          但 xk 那套 __namecall 钩子 Xeno 没有，这游戏的枪也不走 RemoteEvent:FireServer，
--          所以改成替换 GunRemotes.Projectile.FireServerNew 表字段；默认关，
--          面板上带「静默自瞄自检」，能看拦截/改写次数、开火参数形状和执行器 API。
-- 新增 26: 「持枪自动开火」—— 检测到手上有枪就模拟按住鼠标左键（全自动枪一直打），
--          收枪 / 换非枪工具 / 死亡 / 聊天框聚焦 / 关脚本都会自动松开；
--          半自动枪按住只响一发，面板上可切「改用连点」并按毫秒设间隔。
-- 修复 27: 「配置」页点配置名不再直接加载 —— 点一下只是「选中」（列表高亮 + 写进输入框），
--          要应用得点「加载选中配置」；启动时自动加载的那份也会被自动选中
-- 新增 28: 自动加载按钮跟着选中项变 —— 选中的正好是自动加载项时，按钮变成
--          「取消自动加载」，再点一下就把 _auto.txt 删掉（没有 delfile 就清空内容），
--          列表里自动加载项前面有 ★；删掉配置时如果它正好是自动加载项，会一并取消
-- 新增 29: 「车辆」页新增坐标点收藏 —— 可命名保存多个地点（存
--          NARAMO_Configs/_vehicle_points.json，不跟配置走，换配置不会丢），
--          点坐标点直接传送、点「删」删除；记录坐标也不再要求坐在车上，
--          步行时用「记录脚下位置」（从角色身上向下打射线取真实地面点）
-- 新增 30: 「持枪自动开火」新增「附近有人自动暂停」—— 150 格内有真人玩家就立刻
--          松开左键，人走出 150 格后再自动恢复开火；距离可调，队友也算
--          （队友一样看得见你在乱开枪）。掉线/重生/关开关都会把暂停状态清干净
-- 新增 31: 「附近有人自动暂停」新增「不屏蔽名单」—— 名单里的人（比如自己的小号）
--          站在旁边也不会触发暂停，自动开火照常打；面板上可加/删/清空，
--          名字按「用户名或显示名」不区分大小写匹配，跟着配置一起存
-- 修复 32: 暂停后恢复自动开火，视角会偏 —— 原来点击点写死屏幕左下角，而且松开时
--          还无条件再调一次执行器的 mouse1release。两件事都等于把虚拟鼠标从准星
--          拽到别处，游戏按鼠标位置算朝向 / 角色跟着转，每暂停一次视角就歪一点。
--          现在按下、松开、连点都点在「鼠标当前所在位置」（锁定时就是屏幕正中），
--          让光标零位移；松开只用按下时的同一条通道，另一条仅在失败时兜底。
--          如果这个点正好压在我们自己的面板上，会先把 ScreenGui 关一瞬间再点
--          （同一帧内恢复，看不出闪），避免把自己的开关点掉。
-- 新增 33: 「PM 靠近自动维修」节奏可调 —— 同一台设备的冷却从写死的 1 秒降到默认 500ms
--          （面板可调 100–5000ms），主循环扫描间隔默认 100ms（可调 30–500ms）；
--          一轮之内的补耐久仍然是 0 间隔逐帧连发，不受这两个值影响
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
local SCRIPT_VERSION = "2026-11-07 r59 · 自动维修冷却/扫描间隔可调（默认 500ms / 100ms）"

-- ============================ 内置管理员名单 ============================
-- 来源：mod.txt。注意 —— 那个文件里每两行一组，只有**带 @ 的那一行**是真实用户名，
-- 上面那行是可以随便改的显示名（游戏昵称），所以这里只抄 @ 后面的用户名，全部按小写比对。
-- 面板「反管理」页里可以直接追加/移除；按「清空管理员名单」会把这一整份也清掉。
local MOD_USERNAMES = {
    "Quaza_Keidoo", "Exinatiny", "korraged", "crafty_jayden12356", "Nixxorei",
    "Joemotheris", "Danny_Will", "Ps2cho_k", "AvariciousBlake", "angwaves",
    "akaidoj", "Pink_Unoriginality", "SpukenderGeist", "Hexagge", "KamilCraft123",
    "Ihatebloxxed_hotel2", "JohnsonOsborn2", "XKatieKillzX", "NicoOfTheHell", "Johniesplaytime",
    "KDmaster2107", "That_Guy231242", "radchallenge", "cmperaino1213", "crafty_jayden123456",
    "Noobgaming565", "sugary3334", "MaskedWarrior36", "Helios458", "TimorousShadow",
    "DartImperlum", "Franioboss", "LT_Hxro", "cgmhnhgd", "redactedvk",
    "ComSera", "CelestineKavvyyyyy", "mrgumybears7", "zenith1234567", "Argenos",
    "Basically_Ren", "Marshium", "smxszk", "CelestineArcturyx", "EndrMOD",
    "IBI_Gunslinger", "polaskibb", "nypdpolice74", "ArchonFonik", "cj01113",
    "catritonixx", "nullipotent", "Zind_ex", "Vermelt", "Blaley",
    "milltary123321", "AFDGHVDV", "SolarisOrbit", "cpt_connor", "Voltronvoltage",
}

-- ============================ 全局状态 ============================
local State = {
    InfJump = false, Noclip = false, FullBright = false, UnlockChat = false, UnlockFPS = false,
    -- 踏空行走（移植自 xk）：脚下铺隐形锚定平台，可以在空中站立与行走
    SkyWalk = false,
    -- 即时互动（移植自 xk）：提示按住时长归零 / 点击距离放大
    InstantInteract = false,
    -- PM 秒维修：检测到维修小游戏界面就直接发 Repair，跳过小游戏
    -- WrenchAutoRepair：靠近可修设备（WrenchAutoDist 内）就自动补满耐久
    -- WrenchAutoCooldownMs：同一台设备两次自动维修之间的最小间隔（毫秒）
    -- WrenchAutoTickMs：主循环多久扫一次身边的可修设备（毫秒）
    WrenchRepair = false, WrenchAutoRepair = false, WrenchAutoDist = 20,
    WrenchAutoCooldownMs = 500, WrenchAutoTickMs = 100,
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
    -- 队伍检测（管理 / 植物总监）
    -- 这游戏的小队伍在玩家属性 Unit / SubUnit 里，不在 Teams 服务
    TeamHighlightEnabled = true, TeamNotifyEnabled = true,
    AdminTeamKeywords = "联邦,government,federal,admin,moderator,staff",
    HVTeamKeywords = "plantdirector,总监",
    AimbotEnabled = false, AimbotFOV = 120, ShowFOV = true, TargetPart = "Head", AimbotPredict = true, AimbotSpeed = 1000,
    -- 仅持枪时自瞄：手上 Tool 不是枪就不锁（"是不是枪"的判定见 GunSpeed.IsGunTool）
    OnlyGunAim = true,
    -- 静默自瞄：不改相机，只在开火那一刻把方向参数改成目标点（见下面的 Silent 模块）
    -- SilentDryRun = 干跑：只记录开火参数、不改写，第一次试新枪时用
    SilentAim = false, SilentRange = 300, SilentTeamCheck = true, SilentDryRun = false,
    -- 持枪自动开火：检测到手上有枪就模拟按住左键
    -- AutoFireClick = 半自动枪改用连点；AutoFireIntervalMs = 连点间隔（毫秒）
    AutoFire = false, AutoFireClick = false, AutoFireIntervalMs = 80,
    -- 附近有人自动暂停：AutoFireSafeDist 格（面板上按 m 显示）内有真人玩家就不开火，
    -- 人走远后自动继续。距离和 ESP 上的距离是同一套（这个游戏 1 stud 就显示成 1m）
    AutoFireSafe = true, AutoFireSafeDist = 150,
    -- 不屏蔽名单：名单里的人（比如自己的小号）站在附近也不会触发上面的暂停；
    -- 元素是名字字符串，比较时不区分大小写，用户名和显示名都算
    AutoFireSafeIgnore = {},
    -- 弹速自动读取（TREK GunConfig）+ 下坠补偿：读不到配置时自动退回上面的手填值
    -- AimSpeedLiveRead 默认关：实测 require 游戏配置会让枪拿不上，平时只用内置表
    AimSpeedAuto = true, AimDropComp = true, AimSpeedLiveRead = false,
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
    -- 车辆传送：坐标一律按「车体锚点 (model pivot)」，记录 / 传送 / 回填共用同一个点
    VehicleTPCooldown = 3, VehicleTPGlide = false, VehicleTPGlideStep = 25,
    -- 车辆坐标点收藏：{ {name=.., x=.., y=.., z=..}, ... }
    -- 单独存 NARAMO_Configs/_vehicle_points.json，不跟着配置走（换配置也不会丢）
    VehicleTPBookmarks = {},
    UserList = MOD_USERNAMES,
    AutoCheck = false, CheckInterval = 5, AutoExit = false, DisableOnAdmin = false,
    -- 检测到管理员时自动重置角色（本地重置：断关节 + 血量归零 + Dead 状态）
    AutoResetChar = false,
    -- 检测到管理员时，右下角常驻弹窗提示（管理员还在就一直显示）
    AdminPopup = true,
    WalkSpeedEnabled = false, WalkSpeedValue = 16,
    -- 反挂机：固定每 19 分钟模拟一次鼠标点击，防止「闲置 20 分钟被服务器踢掉」
    AntiIdle = false,
}

local Colors = {
    Color3.fromRGB(255, 50, 50), Color3.fromRGB(255, 255, 50),
    Color3.fromRGB(50, 255, 50), Color3.fromRGB(200, 50, 255),
    Color3.fromRGB(255, 255, 255)
}
local TEAMMATE_COLOR = Color3.fromRGB(80, 230, 120)   -- 队友专用色

local ESPObjects = {}
local AutoCheckThread = nil

-- 反管理：自动重置角色的记录表。
-- 顶层局部变量有 200 个硬上限，所以这里只占 1 个名字，具体函数在「反管理」页里赋值到表上。
--   done        [小写名字] = true，这一轮已经触发过重置的管理员（防止同一个人无限触发）
--   pending     正在等角色重生，8 秒内不再重复重置
--   lastAt      上一次触发重置的时间（os.clock）
--   emptyPasses 连续几轮没扫到管理员（连续 3 轮才认为管理员走了，清空 done）
local AdminGuard = { done = {}, pending = false, lastAt = 0, emptyPasses = 0 }
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

-- ============================ 车辆传送 ============================
-- 实测结论（见独立测试脚本 naramo_vehicle_tp_test.lua）：客户端对车体有网络所有权，
-- 直接把车摆到新位置，服务器会接受、不回弹，所以默认走「一帧瞬移」；滑行模式留作备用。
-- 重要约定：所有坐标 —— 记录、输入、传送、回填 —— 一律指「车座锚点」：
--   也就是玩家坐着的那个 VehicleSeat 的位置。它 100% 跟着车走。
-- 早期版本用 model:GetPivot() 当锚点，遇到 pivot 定义怪 / 模型层级套得深的车，
-- 车开出去后锚点还在原地，于是记录出来的位置是错的、传送又一直报"已经在这个位置了"。
local TPLastAt = 0
local TPRay = RaycastParams.new()
pcall(function() TPRay.FilterType = Enum.RaycastFilterType.Blacklist end)

-- 射线别打到自己的车和角色
local function TPFilter(base, model)
    local ignore = { base }
    if model then table.insert(ignore, model) end
    if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
    TPRay.FilterDescendantsInstances = ignore
end

local function TPAnchor(seat)
    local ok, pos = pcall(function() return seat.CFrame.Position end)
    if ok and pos then return pos end
    return nil
end

-- 给 UI 用：读当前车体锚点（没在车上返回 nil）
-- 用全局名而不是顶层 local：文件头的"修复 11"说过顶层局部变量有 200 个硬上限，
-- 这里一个新名额都不占（同 NARAMO_VEHICLE_FORWARD / NARAMO_GUNSPEED 的做法）
NARAMO_VehicleAnchor = function()
    local seat = GetCurrentVehicleSeat()
    if not seat then return nil end
    return TPAnchor(seat)
end

-- 给 UI 用：读「当前脚下」的地面坐标，步行 / 站任何地方都能用（不强求坐在车上）。
-- 先从 HumanoidRootPart 往下打一条射线取真正踩到的地面点（桥面、楼板也算）；
-- 打不到地面（悬空、掉出地图）就按 Humanoid 的脚底高度估一个点，保证总有返回值。
NARAMO_PlayerFeetPosition = function()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not (hrp and hrp:IsA("BasePart")) then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local params = RaycastParams.new()
    pcall(function() params.FilterType = Enum.RaycastFilterType.Blacklist end)
    params.FilterDescendantsInstances = { char }
    local ok, hit = pcall(function()
        return workspace:Raycast(hrp.Position + Vector3.new(0, 2, 0), Vector3.new(0, -500, 0), params)
    end)
    if ok and hit then return hit.Position end
    local hip = (hum and tonumber(hum.HipHeight)) or 0
    return Vector3.new(hrp.Position.X, hrp.Position.Y - hip - hrp.Size.Y * 0.5, hrp.Position.Z)
end

-- 从某点上方 300 studs 往下探地面；探不到返回 nil。
-- 注意：如果在室内/桥下，上方射线会先打中天花板，这种情况改从目标点本身往下重打一次，
-- 否则「离地高度」会算成 1 stud，车会被放到贴着地面、轮子插进地里。
local function TPGroundY(pos, base, model)
    TPFilter(base, model)
    local ok, hit = pcall(function()
        return workspace:Raycast(pos + Vector3.new(0, 300, 0), Vector3.new(0, -3000, 0), TPRay)
    end)
    if ok and hit and hit.Position.Y <= pos.Y + 1 then return hit.Position.Y end
    local ok2, hit2 = pcall(function()
        return workspace:Raycast(pos + Vector3.new(0, 0.5, 0), Vector3.new(0, -3000, 0), TPRay)
    end)
    if ok2 and hit2 then return hit2.Position.Y end
    return nil
end

-- 取「这一辆车的模型」：模型层级乱的时候 GetVehicleBasePart 可能一路爬到
-- "所有车"的容器模型上，那种大模型一旦 PivotTo 会把全场的车一起挪走。
-- 用包围盒尺寸做保险：超过 200 studs 就不当成单车，退回挪刚体根。
local function TPCarModel(model, seat)
    if not model or model == seat then return nil end
    local ok, _, size = pcall(function() return model:GetBoundingBox() end)
    if not ok or not size then return nil end
    if math.max(size.X, size.Y, size.Z) > 200 then return nil end
    return model
end

-- 只平移车体、不改朝向：给一个位移量，整辆车挪过去。
-- 注意这里刻意只算「挪多少」而不去读绝对位置 —— 即使某些车的 pivot 定义得很怪，
-- 平移量也不会错位（PivotTo 内部会按模型自己的 pivot 换算，这里只提供增量）。
local function TPShift(base, model, delta, seat)
    if model then
        local pv = model:GetPivot()
        model:PivotTo(CFrame.new(pv.Position + delta) * (pv - pv.Position))
    else
        -- 拿不到"这一辆车"的模型（层级太乱 / 挂在所有车的容器下）时，
        -- 挪座位所在的刚体根：刚体根一动整辆组装体跟着走，比挪单个零件稳
        local root = nil
        if seat then
            local ok, r = pcall(function() return seat.AssemblyRootPart end)
            if ok then root = r end
        end
        root = root or base
        local cf = root.CFrame
        root.CFrame = CFrame.new(cf.Position + delta) * (cf - cf.Position)
    end
end

-- 准星目标：屏幕中心打一条 3000 studs 的射线
local function TPCursorTarget(base, model)
    local cam = workspace.CurrentCamera
    if not cam then return nil, "拿不到相机" end
    local vp = cam.ViewportSize
    local ok, ray = pcall(function() return cam:ViewportPointToRay(vp.X * 0.5, vp.Y * 0.5) end)
    if not ok or not ray then return nil, "取不到屏幕中心射线" end
    TPFilter(base, model)
    local ok2, hit = pcall(function()
        return workspace:Raycast(ray.Origin, ray.Direction * 3000, TPRay)
    end)
    if not ok2 or not hit then return nil, "准星没打到东西（3000 studs 内）" end
    return hit.Position
end

-- 返回 ok, 说明文字。target 为 nil 或 opts.cursor 时走准星；
-- opts.exactY 为真时 Y 以调用方给的为准（记录点才能精确回传）
NARAMO_VehicleTeleport = function(target, opts)
    opts = opts or {}
    if IsClosing then return false, "脚本已关闭" end
    local seat = GetCurrentVehicleSeat()
    if not seat then return false, "没在车上（坐进 VehicleSeat 再传）" end
    local base, model = GetVehicleBasePart(seat)
    if not base or not base:IsA("BasePart") then return false, "找不到车体主部件" end
    local carModel = TPCarModel(model, seat)

    local now = os.clock()
    local cd = tonumber(State.VehicleTPCooldown) or 3
    if TPLastAt > 0 and (now - TPLastAt) < cd then
        return false, string.format("冷却中，还要 %.1f 秒", cd - (now - TPLastAt))
    end

    if opts.cursor or not target then
        local t, err = TPCursorTarget(base, carModel)
        if not t then return false, err end
        target, opts.exactY = t, nil
    end

    local from = TPAnchor(seat)
    if not from then return false, "读不到车座位置（车可能刚被拆）" end
    local gHere = TPGroundY(from, base, carModel)
    local rise = 4
    if gHere then rise = math.clamp(from.Y - gHere, 1, 20) end
    local gThere = TPGroundY(target, base, carModel)

    local goalY
    if opts.exactY then
        -- 输入 / 记录的坐标：Y 以你给的为准，只在明显埋进地面时抬回来
        goalY = target.Y
        if gThere and goalY < gThere + 1 then goalY = gThere + rise end
    else
        -- 准星点：贴地，保留原车离地高度
        goalY = (gThere or target.Y) + rise
    end
    local goal = Vector3.new(target.X, goalY, target.Z)

    -- 只算「要平移多少」，不做绝对定位：这样哪怕某辆车的 pivot 定义很怪也不会错位
    local delta = goal - from
    local dist = delta.Magnitude
    print(string.format(
        "[NARAMO] 车辆传送: 起点 (%.0f, %.0f, %.0f) → 目标 (%.0f, %.0f, %.0f)，距离 %.0f，车型 %s",
        from.X, from.Y, from.Z, goal.X, goal.Y, goal.Z, dist, tostring(carModel and carModel.Name or "?")))

    if dist > 6000 then
        return false, string.format("目标太远 %.0f studs，已拒绝", dist)
    end
    if dist < 0.5 then
        return false, string.format("已经在这个位置了（车在 %.0f, %.0f, %.0f）", from.X, from.Y, from.Z)
    end

    TPLastAt = now
    local ok, err = pcall(function()
        if State.VehicleTPGlide then
            local step = math.max(5, tonumber(State.VehicleTPGlideStep) or 25)
            local steps = math.max(1, math.ceil(dist / step))
            for i = 1, steps do
                if IsClosing then return end
                TPShift(base, carModel, delta * (i / steps), seat)
                RunService.Heartbeat:Wait()
            end
        else
            TPShift(base, carModel, delta, seat)
        end
    end)

    -- 清惯性：不清的话传完会带着旧速度继续漂
    pcall(function()
        base.AssemblyLinearVelocity = Vector3.zero
        base.AssemblyAngularVelocity = Vector3.zero
    end)

    if not ok then return false, "移动失败: " .. tostring(err) end
    return true, string.format("车辆已传送 %.0f studs（→ %.0f, %.0f, %.0f）", dist, goal.X, goal.Y, goal.Z)
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

-- ============================ 子弹速度自动读取（TREK GunConfig） ============================
-- 这游戏是 TREK + FastCast 构架：真实弹速不在枪工具上，而是在
--   ReplicatedStorage.TREK_SERVICES.GunConfigs.Guns.<枪名>[模式].ProjectileVelocity
-- 而且不少枪名只是"别名模块"（例如 BR-18 的内容其实是 require(D-23 STAR)），
-- 直接 require 别名会因为它一进门就找 shared.S 而报错，所以要先按源码把别名解开。
--
-- 整段包进 do...end：顶层局部变量有 200 个硬上限（见文件头的"修复 11"），
-- 块内局部变量用完即释放，只留 GunSpeed 一个名字给外面。
local GunSpeed
do
GunSpeed = {
    cache = {},       -- [枪名] = { speed, accel, distance, mode, module, alias }
    current = nil,    -- 当前手上这把枪的数据
    folder = nil,     -- GunConfigs.Guns
}

-- 硬编码兜底表：探针 2026-11-01 扫出来的 69 把枪。
-- 格式：["枪名"] = { 弹速 studs/s, 重力, 射程 studs }
-- 作用：执行器没有 decompile、或者游戏改了配置模块结构时，照样能读对弹速。
GunSpeed.DB = {
    ["AB9"] = {4000, 196.2, 1000},
    ["B63 LMG"] = {4000, 196.2, 5000},
    ["B9"] = {4000, 196.2, 1000},
    ["BR-10"] = {4000, 196.2, 5000},
    ["BR-10 Suppressed"] = {4000, 196.2, 5000},
    ["BR-10A1"] = {4000, 196.2, 5000},
    ["BR-177S"] = {4000, 196.2, 1500},
    ["BR-18"] = {4000, 196.2, 2500},
    ["BR-18A2"] = {4000, 196.2, 2500},
    ["BR-18C"] = {4000, 196.2, 1500},
    ["BR-7"] = {4000, 196.2, 5000},
    ["BR-PDW"] = {4000, 196.2, 1500},
    ["Bolterer Fist"] = {3750, 196.2, 2500},
    ["Bolterer Gun"] = {4000, 196.2, 2500},
    ["C-11 LMG"] = {4000, 196.2, 5000},
    ["C-16 GPMG"] = {4000, 196.2, 5000},
    ["CMP-44"] = {4000, 196.2, 1500},
    ["CMP-44E1"] = {4000, 196.2, 1500},
    ["China Lake 40mm"] = {500, 196.2, 300},
    ["D-19 STAR"] = {4000, 196.2, 5000},
    ["D-19A1 STAR"] = {4000, 196.2, 5000},
    ["D-22 STAR"] = {4000, 196.2, 5000},
    ["D-23 STAR"] = {4000, 196.2, 2500},
    ["D-23 Spectre"] = {4000, 196.2, 2500},
    ["D-23FM"] = {4000, 196.2, 2500},
    ["D-23SD"] = {4000, 196.2, 2500},
    ["DA-21"] = {4000, 196.2, 1000},
    ["DA-21 Suppressed"] = {4000, 196.2, 1000},
    ["DX-21"] = {4000, 196.2, 1000},
    ["DX-9000"] = {4000, 196.2, 1000},
    ["ED-23"] = {4000, 196.2, 6000},
    ["ED-23H"] = {4000, 196.2, 2500},
    ["Ellan L1"] = {750, 20, 5000},
    ["Falkenkreuz"] = {500, 196.2, 1000},
    ["HEAVY BOLTER"] = {4000, 196.2, 2500},
    ["HEAVY LASGUN"] = {4000, 196.2, 2500},
    ["Jerico SMG"] = {4000, 196.2, 1500},
    ["Jerico SMG-S"] = {4000, 196.2, 1500},
    ["Lasgun"] = {4500, 196.2, 2500},
    ["Lewis Gun"] = {4000, 196.2, 3000},
    ["M-16"] = {600, 196.2, 1000},
    ["M-23"] = {500, 196.2, 1000},
    ["M-24"] = {500, 196.2, 1000},
    ["M16A1"] = {4000, 196.2, 2500},
    ["M19"] = {4000, 196.2, 1000},
    ["M19 Suppressed"] = {4000, 196.2, 1000},
    ["M80 AMR"] = {3500, 0, 5000},
    ["Model 117"] = {4000, 196.2, 1000},
    ["Model 17"] = {4000, 196.2, 1000},
    ["Münzwurf"] = {500, 196.2, 1000},
    ["PAT-1"] = {500, 20, 5000},
    ["PAT-1 Test"] = {500, 20, 5000},
    ["PDW-18"] = {4000, 196.2, 1500},
    ["PSAT"] = {750, 20, 5000},
    ["Plasma Pistol"] = {4000, 196.2, 2500},
    ["Projectile Tester"] = {4000, 196.2, 1000},
    ["R72"] = {500, 20, 5000},
    ["Springton Pattern Lasgun"] = {4500, 196.2, 2500},
    ["Super Bazooka"] = {600, 10, 5000},
    ["T-29 Springbolt"] = {5000, 196.2, 4000},
    ["T-3"] = {500, 196.2, 1000},
    ["T-3 Suppressed"] = {500, 196.2, 1000},
    ["T-42 Matchbox"] = {4000, 196.2, 5000},
    ["The Sleeper Agent"] = {100, 1.96, 1000},
    ["Weston Ranger"] = {4000, 196.2, 1500},
    ["Weston SMG"] = {4000, 196.2, 1500},
    ["Weston SMG-S"] = {4000, 196.2, 1500},
    ["XD-23H"] = {4000, 196.2, 1500},
    ["XD-23M"] = {4000, 196.2, 2500},
}

function GunSpeed.Folder()
    if GunSpeed.folder and GunSpeed.folder.Parent then return GunSpeed.folder end
    local rs = game:GetService("ReplicatedStorage")
    local ts = rs:FindFirstChild("TREK_SERVICES")
    local gc = ts and ts:FindFirstChild("GunConfigs")
    GunSpeed.folder = gc and gc:FindFirstChild("Guns")
    return GunSpeed.folder
end

-- 解别名：别名模块的源码长这样
--   local v1 = shared.S.GunConfigs:FindFirstChild("Guns"):FindFirstChild("D-23 STAR", true)
--   return require(v1)
function GunSpeed.ResolveAlias(mod, depth)
    depth = depth or 0
    if depth > 3 or not mod then return mod end
    if type(decompile) ~= "function" then return mod end
    local ok, src = pcall(decompile, mod)
    if not ok or type(src) ~= "string" or #src > 4000 then return mod end

    local target = nil
    for name in string.gmatch(src, "FindFirstChild%(%s*[\"']([^\"']+)[\"']%s*,[%s]*true%s*%)") do
        target = name
    end
    if not target then return mod end

    local guns = GunSpeed.Folder()
    local nextMod = guns and guns:FindFirstChild(target)
    if not nextMod then
        local okd, desc = pcall(function() return guns and guns:GetDescendants() or {} end)
        if okd then
            for _, d in ipairs(desc) do
                if d:IsA("ModuleScript") and string.lower(d.Name) == string.lower(target) then
                    nextMod = d
                    break
                end
            end
        end
    end
    if nextMod and nextMod:IsA("ModuleScript") and nextMod ~= mod then
        return GunSpeed.ResolveAlias(nextMod, depth + 1)
    end
    return mod
end

-- 从游戏配置里实读（需要 require；别名还要 decompile）。读不到返回 nil
function GunSpeed.ReadLive(toolName)
    local guns = GunSpeed.Folder()
    if not guns or not toolName then return nil end

    local mod = guns:FindFirstChild(toolName)
    if not mod then
        -- 大小写/空格差异也认（直接列子项，不用递归 FindFirstChild）
        local okd, desc = pcall(function() return guns:GetDescendants() end)
        if okd then
            for _, d in ipairs(desc) do
                if d:IsA("ModuleScript") and string.lower(d.Name) == string.lower(toolName) then
                    mod = d
                    break
                end
            end
        end
    end
    if not mod or not mod:IsA("ModuleScript") then return nil end

    local real = GunSpeed.ResolveAlias(mod, 0)
    local ok, cfg = pcall(require, real)
    if not ok or type(cfg) ~= "table" then return nil end

    local m1 = cfg[1]
    if type(m1) ~= "table" then
        if type(cfg.ProjectileVelocity) ~= "number" then return nil end
        m1 = cfg
    end
    if type(m1.ProjectileVelocity) ~= "number" then return nil end

    local info = {
        speed = m1.ProjectileVelocity,
        distance = m1.Distance,
        mode = "1",
        module = real:GetFullName(),
        alias = (real ~= mod) and real.Name or nil,
    }
    local accel = m1.ProjectileAcceleration
    if typeof(accel) == "Vector3" then info.accel = accel.Magnitude end

    GunSpeed.cache[toolName] = info
    return info
end

-- 查硬编码表（大小写不敏感）
function GunSpeed.LookupDB(toolName)
    if not toolName then return nil end
    local v = GunSpeed.DB[toolName]
    if not v then
        local want = string.lower(toolName)
        for name, val in pairs(GunSpeed.DB) do
            if string.lower(name) == want then v = val; break end
        end
    end
    return v
end

-- 对外统一入口：**先查内置表**（不碰游戏模块，最安全）。
-- 内置表里没有（新枪/改名）才考虑实读，而且必须手动打开 State.AimSpeedLiveRead ——
-- 实测发现 require 游戏配置会让枪拿不上，所以实读默认关闭。
function GunSpeed.Read(toolName)
    local db = GunSpeed.LookupDB(toolName)
    if db then
        local info = {
            speed = db[1],
            accel = db[2],
            distance = db[3],
            mode = "1",
            source = "db",
        }
        GunSpeed.cache[toolName] = info
        return info
    end

    if State.AimSpeedLiveRead then
        local live = GunSpeed.ReadLive(toolName)
        if live then return live end
    end

    return nil
end

function GunSpeed.Refresh(toolName)
    if not toolName then
        GunSpeed.current = nil
        return
    end
    local info = GunSpeed.cache[toolName] or GunSpeed.Read(toolName)
    GunSpeed.current = info

    if info and info.speed then
        local from = (info.source == "db") and "，内置表"
            or (info.alias and ("，别名→" .. info.alias) or "")
        print(string.format("[NARAMO] 弹速自动读取: %s = %d studs/s（重力 %.1f，射程 %s）%s",
            tostring(toolName), math.floor(info.speed + 0.5), info.accel or 0,
            tostring(info.distance or "?"), from))
        -- 顺手把滑块同步成真值，面板上能直接看到（超出 100~5000 会被夹住，不影响实际计算）
        if State.AimSpeedAuto then
            pcall(SetControl, "AimbotSpeed", math.floor(info.speed + 0.5))
        end
    elseif State.AimSpeedAuto then
        print("[NARAMO] 弹速自动读取: " .. tostring(toolName)
            .. " 没读到配置，退回手填 " .. tostring(State.AimbotSpeed))
    end
end

-- 枪口位置：优先枪管，退回相机（相机在脑袋后面，近距离差得出来）
-- 注意：这里全部用非递归 FindFirstChild —— 这个执行器上递归查找不可靠
function GunSpeed.Muzzle()
    local char = LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool then
        local barrel = tool:FindFirstChild("Barrel") or tool:FindFirstChild("Main")
        if barrel and barrel:IsA("BasePart") then return barrel.Position end
        local handle = tool:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then return handle.Position end
    end
    return workspace.CurrentCamera.CFrame.Position
end

-- ============ 持枪判定（「仅持枪时自瞄」用） ============
-- 只读判断，不改任何游戏数据。判定顺序（命中一条就算枪）：
--   1) 名字在内置枪表 GunSpeed.DB（69 把枪）里，或名字里带枪械词
--      —— 不依赖游戏结构，最稳，先走这条
--   2) Tool 上的 TConfigToUse 属性，而且 GunConfigs.Guns 里真有同名模块
--      —— 游戏给枪挂的配置名，新枪 / 改过名的枪也能认
--   3) 工具里带弹药（TAmmo / LocalTAmmo 这类容器，或名字带 ammo 的数值对象）
--      —— 最后的兜底，防止认不出枪名时把自瞄全挡掉
-- 判定结果按 Tool 实例缓存：认定是枪就一直有效；认定不是的每秒重判一次
-- （TConfigToUse 属性有时比 Tool 本身晚到，不能只判一次就定死）。
GunSpeed.GUN_WORDS = { "gun", "rifle", "smg", "lmg", "pistol", "revolver", "carbine",
    "sniper", "shotgun", "launcher", "bazooka", "lasgun", "bolter", "firearm", "cannon" }
GunSpeed.verdict = setmetatable({}, { __mode = "k" })   -- 弱键：旧工具不会一直留在内存里

function GunSpeed.IsGunName(name)
    if type(name) ~= "string" or name == "" then return false end
    if GunSpeed.LookupDB(name) then return true end
    local lk = string.lower(name)
    for _, w in ipairs(GunSpeed.GUN_WORDS) do
        if string.find(lk, w, 1, true) then return true end
    end
    return false
end

-- 手上正拿着的工具（角色下装备中的 Tool 只会有一个）
function GunSpeed.CurrentTool()
    local char = LocalPlayer.Character
    if not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool and tool:IsA("Tool") then return tool end
    return nil
end

-- 工具里有没有弹药痕迹（TAmmo / LocalTAmmo 这类容器，或 AmmoXXX 数值对象）
function GunSpeed.HasAmmoEvidence(tool)
    local found = false
    pcall(function()
        for _, d in ipairs(tool:GetDescendants()) do
            local ln = string.lower(tostring(d.Name))
            if string.find(ln, "ammo", 1, true)
                and (d:IsA("Folder") or d:IsA("ValueBase") or d:IsA("Configuration")) then
                found = true
                return
            end
        end
    end)
    return found
end

-- 返回：是不是枪, 判定理由, 工具名（不是枪时理由会写清卡在哪一条，方便排查）
function GunSpeed.IsGunTool(tool)
    if not tool or not tool:IsA("Tool") then return false, "空手", nil end
    local name = tostring(tool.Name)
    local c = GunSpeed.verdict[tool]
    if c and (c.gun or (os.clock() - c.at) < 1) then return c.gun, c.why, name end

    local why = nil
    local note = nil
    if GunSpeed.IsGunName(name) then
        why = "名字命中内置枪表 / 带枪械词"
    else
        local attr = nil
        pcall(function() attr = tool:GetAttribute("TConfigToUse") end)
        if type(attr) == "string" and attr ~= "" then
            local guns = GunSpeed.Folder()
            local hit = nil
            if guns then
                local ok, child = pcall(function() return guns:FindFirstChild(attr) end)
                if ok then hit = child end
            end
            if hit then
                why = "TConfigToUse=" .. attr .. "（GunConfigs.Guns 里有同名模块）"
            elseif GunSpeed.HasAmmoEvidence(tool) then
                why = "TConfigToUse=" .. attr .. " + 工具里带弹药"
            else
                note = "（TConfigToUse=" .. attr .. "，但 Guns 里没这个模块、工具里也没弹药）"
            end
        elseif GunSpeed.HasAmmoEvidence(tool) then
            why = "工具里带弹药"
        end
    end

    local isGun = why ~= nil
    local reason = why or ("名字不认识、也没有枪械特征" .. (note or ""))
    GunSpeed.verdict[tool] = {
        gun = isGun,
        why = reason,
        at = os.clock(),
    }
    return isGun, reason, name
end

-- 自瞄统一入口：OnlyGunAim 关着就直接放行（返回 true = 可以自瞄）
function GunSpeed.AimAllowed()
    if not State.OnlyGunAim then return true, nil, nil end
    return GunSpeed.IsGunTool(GunSpeed.CurrentTool())
end

-- 换枪 / 重生都重读一次；顺便把「这把算不算枪、自瞄会不会生效」打到控制台
local function watchTool(container)
    if not container then return end
    Track(container.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            task.delay(0.35, function()
                GunSpeed.Refresh(child.Name)
                if State.OnlyGunAim and not IsClosing then
                    local isGun, why, name = GunSpeed.IsGunTool(child)
                    print(string.format("[NARAMO] 仅持枪时自瞄: 换上 %s → %s（%s）",
                        tostring(name or child.Name),
                        isGun and "是枪，自瞄可用" or "不是枪，自瞄暂停",
                        tostring(why)))
                end
            end)
        end
    end))
end

watchTool(LocalPlayer.Character)
-- 脚本加载时如果枪已经在手上（不是刚换的），先读一次弹速；
-- 不然静默自瞄的预判会退回滑块默认值（1000），远距离提前量会差很多
pcall(function()
    local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
    if tool then GunSpeed.Refresh(tool.Name) end
end)
Track(LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    if IsClosing or not char then return end
    watchTool(char)
    local tool = char:FindFirstChildOfClass("Tool")
    GunSpeed.Refresh(tool and tool.Name)
end))

-- 方便在控制台核对：getgenv().NARAMO_GUNSPEED.current 就是当前这把枪的数据
pcall(function() getgenv().NARAMO_GUNSPEED = GunSpeed end)
end   -- 弹速段结束

-- ============================ 静默自瞄（改写开火参数，不动视角） ============================
-- 原型：xk新版通用.lua 的「无声自瞄」。它的做法是钩 __namecall，把开火远端里的
-- Vector3 / CFrame 参数换成目标坐标，相机完全不转，所以屏幕上看起来没瞄准。
--
-- 但直接搬过来在这台执行器 / 这个游戏上跑不起来：
--   1) xk 依赖 getrawmetatable(game) + newcclosure + getnamecallmethod，
--      Xeno 这三样都没有（之前的探针 dump 已确认），钩子根本挂不上；
--   2) 这游戏的枪不发 RemoteEvent:FireServer，而是走
--      ReplicatedStorage.GunRemotes.Projectile.FireServerNew(self, origin, dir, velocity, behavior, mode)，
--      再由它打包成 GunPackets 发出去，所以就算钩到 __namecall 也看不到开火。
--
-- 所以这里保留「改写开火参数」这个原理，换成这个游戏真正走得通的做法：
--   替换 GunRemotes.Projectile.FireServerNew 这个表字段，在游戏发包前把方向 / 坐标
--   参数改成目标点（枪脚本是查表调用，表字段替换能生效）。如果枪脚本把函数缓存进了
--   局部变量，就会一次都拦截不到 —— 「静默自瞄自检」按钮会直接显示拦截次数。
-- 安全兜底：改写后的参数如果让游戏报错，就退回原始参数再打一次，保证还能正常开枪。
local Silent = {
    installed = false, proj = nil, orig = nil, wrap = nil,
    shots = 0, rewrites = 0, would = 0, skipped = 0, failed = 0,
    logged = 0, tries = 0, targetName = nil, targetDist = nil,
    predict = nil,          -- 延迟赋值：GetPredictPosition（文件后面才定义）
}

do
local Unpack = table.unpack or unpack

local function SilentMyPos()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then return root.Position end
    local cam = workspace.CurrentCamera
    if cam then return cam.CFrame.Position end
    return Vector3.new(0, 0, 0)
end

-- 选目标：按世界距离挑最近的，和准心 / FOV 无关（静默自瞄不看屏幕位置）
local function SilentPickTarget()
    local myPos = SilentMyPos()
    local range = tonumber(State.SilentRange) or 300
    local best, bestPart, bestDist = nil, nil, range
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local part = p.Character:FindFirstChild(State.TargetPart)
                or p.Character:FindFirstChild("HumanoidRootPart")
            if part and hum and hum.Health > 0 then
                local sameTeam = State.SilentTeamCheck
                    and LocalPlayer.Team ~= nil and p.Team ~= nil
                    and LocalPlayer.Team == p.Team
                if not sameTeam then
                    local d = (part.Position - myPos).Magnitude
                    if d < bestDist then best, bestPart, bestDist = p, part, d end
                end
            end
        end
    end
    return bestPart, bestDist, (best and best.Name) or nil
end

-- 开火参数摘要：前几次开火打到控制台，实际形状和 xk 那边不一样时一眼能看出来
local function SilentDescribeArgs(args, n)
    local out = {}
    for i = 1, math.min(n, 8) do
        local v = args[i]
        local tv = typeof(v)
        if tv == "Vector3" then
            out[i] = string.format("V3(%.1f,%.1f,%.1f)|%.2f", v.X, v.Y, v.Z, v.Magnitude)
        elseif tv == "CFrame" then
            out[i] = "CFrame"
        elseif tv == "Instance" then
            out[i] = "Inst(" .. tostring(v.Name) .. ")"
        elseif tv == "table" then
            out[i] = "table"
        else
            out[i] = tostring(v)
        end
    end
    return table.concat(out, ", ")
end

-- 参数改写：原点（FireServerNew 的第 2 个参数，枪口 / 相机位置）不动，
-- 单位向量当方向改写，远处的世界坐标当瞄点改写，CFrame 改成「看向目标」。
local function SilentRewrite(args, n, aimPos)
    local myPos = SilentMyPos()
    -- 签名是 FireServerNew(self, origin, dir, velocity, behavior, mode)：
    -- 第 2 个参数就是原点；万一不是 Vector3（换了路径），再按「离自己最近」兜底。
    local origin = nil
    if typeof(args[2]) == "Vector3" then
        origin = args[2]
    else
        for i = 2, n do
            local v = args[i]
            if typeof(v) == "Vector3" and (v - myPos).Magnitude < 20 then
                origin = v
                break
            end
        end
    end
    origin = origin or myPos

    local changed = 0
    for i = 2, n do
        local v = args[i]
        local tv = typeof(v)
        if tv == "Vector3" then
            if v ~= origin then
                if v.Magnitude <= 4 then
                    -- 单位向量 = 方向
                    local dir = aimPos - origin
                    if dir.Magnitude > 0.05 then
                        args[i] = dir.Unit
                        changed = changed + 1
                    end
                elseif (v - myPos).Magnitude > 12 then
                    -- 世界坐标 = 瞄点之类
                    args[i] = aimPos
                    changed = changed + 1
                end
            end
        elseif tv == "CFrame" then
            args[i] = CFrame.new(v.Position, aimPos)
            changed = changed + 1
        end
    end
    return changed
end

local function SilentMakeWrapper(orig)
    return function(...)
        if IsClosing or not State.SilentAim then return orig(...) end

        Silent.shots = Silent.shots + 1
        local n = select("#", ...)
        local args = { ... }

        local part, dist, tname = SilentPickTarget()
        local would, changed = 0, 0
        if part then
            local aim = part.Position
            local pred = Silent.predict
            if pred then
                local okp, pos = pcall(pred, part)
                if okp and typeof(pos) == "Vector3" then aim = pos end
            end
            local okr, c = pcall(SilentRewrite, args, n, aim)
            if okr then would = tonumber(c) or 0 end
            changed = would
            Silent.targetName, Silent.targetDist = tname, dist
        else
            Silent.targetName, Silent.targetDist = nil, nil
        end

        if would > 0 then Silent.would = Silent.would + 1 end
        if Silent.logged < 3 then
            Silent.logged = Silent.logged + 1
            print(string.format("[NARAMO][静默] 开火参数 #%d: %s | 目标: %s | 改写: %d",
                Silent.logged, SilentDescribeArgs(args, n), tostring(tname or "无"), would))
        end

        if changed <= 0 or State.SilentDryRun then
            Silent.skipped = Silent.skipped + 1
            return orig(...)
        end

        local okCall, r1, r2 = pcall(orig, Unpack(args, 1, n))
        if not okCall then
            Silent.failed = Silent.failed + 1
            return orig(...)          -- 改完的参数被游戏拒了：退回原参数，保证还能开枪
        end
        Silent.rewrites = Silent.rewrites + 1
        return r1, r2
    end
end

-- 安装 / 卸载：替换的是模块表里的字段，不需要 hookfunction（Xeno 也没有）
function Silent.Install()
    if Silent.installed and Silent.proj then return true, "已安装" end
    local rs = game:GetService("ReplicatedStorage")
    local gr = rs:FindFirstChild("GunRemotes")
    if not gr then return false, "ReplicatedStorage 里没有 GunRemotes（还没进对局？）" end
    local ok, gm = pcall(require, gr)
    if not ok or type(gm) ~= "table" then return false, "require GunRemotes 失败: " .. tostring(gm) end
    local proj = gm.Projectile
    if type(proj) ~= "table" then return false, "GunRemotes.Projectile 不存在或不是表" end
    local fn = proj.FireServerNew
    if type(fn) ~= "function" then return false, "Projectile.FireServerNew 不存在（开火路径可能改了）" end

    local wrap = SilentMakeWrapper(fn)
    pcall(function() proj.FireServerNew = wrap end)
    local now = nil
    pcall(function() now = proj.FireServerNew end)
    if now ~= wrap then
        pcall(rawset, proj, "FireServerNew", wrap)      -- 表有 __newindex 拦截时再走 rawset
        pcall(function() now = proj.FireServerNew end)
    end
    if now ~= wrap then return false, "FireServerNew 写不进去（Projectile 表被冻结 / 有元表拦截）" end

    Silent.installed, Silent.proj, Silent.orig, Silent.wrap = true, proj, fn, wrap
    return true, "已替换 FireServerNew"
end

function Silent.Uninstall()
    if not Silent.installed then return end
    pcall(function()
        if Silent.proj and Silent.proj.FireServerNew == Silent.wrap then
            Silent.proj.FireServerNew = Silent.orig
        end
    end)
    Silent.installed, Silent.proj, Silent.orig, Silent.wrap = false, nil, nil, nil
end

-- 刚进图 GunRemotes 还没复制好时安装会失败，隔 2 秒重试几次
function Silent.Retry()
    if IsClosing or not State.SilentAim or Silent.installed then return end
    Silent.tries = (Silent.tries or 0) + 1
    if Silent.tries > 5 then
        print("[NARAMO][静默] 安装重试 5 次都失败，已停止重试；点「静默自瞄自检」看具体原因")
        return
    end
    task.delay(2, function()
        if IsClosing or not State.SilentAim or Silent.installed then return end
        Silent.Install()
        if Silent.installed then
            print("[NARAMO][静默] 重试安装成功")
        else
            Silent.Retry()
        end
    end)
end

function Silent.SetEnabled(on)
    on = on and true or false
    State.SilentAim = on
    if on then
        Silent.tries = 0
        Silent.shots, Silent.rewrites, Silent.would, Silent.skipped, Silent.failed = 0, 0, 0, 0, 0
        Silent.logged = 0
        local ok, why = Silent.Install()
        print("[NARAMO][静默] " .. (ok and ("已开启：" .. tostring(why))
            or ("开启失败：" .. tostring(why) .. "（点「静默自瞄自检」看详情）")))
        if not ok then Silent.Retry() end
    elseif Silent.installed then
        Silent.Uninstall()
        print(string.format("[NARAMO][静默] 已关闭（拦截 %d / 改写 %d / 未改写 %d / 失败退回 %d）",
            Silent.shots, Silent.rewrites, Silent.skipped, Silent.failed))
    end
    return State.SilentAim
end

-- 自检：执行器 API、开火模块、安装状态、拦截统计一次看全（发反馈时直接抄这段）
function Silent.SelfCheck()
    local lines = {}
    local function Add(s) lines[#lines + 1] = s end
    Add("静默自瞄: " .. (State.SilentAim and "开" or "关")
        .. " | 干跑: " .. (State.SilentDryRun and "开" or "关")
        .. " | FireServerNew: " .. (Silent.installed and "已被替换" or "原版"))
    Add(string.format("执行器: hookfunction=%s getrawmetatable=%s newcclosure=%s getnamecallmethod=%s",
        type(hookfunction), type(getrawmetatable), type(newcclosure), type(getnamecallmethod)))

    local rs = game:GetService("ReplicatedStorage")
    local gr = rs:FindFirstChild("GunRemotes")
    Add("GunRemotes: " .. (gr and gr:GetFullName() or "没找到"))
    if gr then
        local ok, gm = pcall(require, gr)
        if ok and type(gm) == "table" then
            local proj = gm.Projectile
            if type(proj) == "table" then
                local names = {}
                for k, v in pairs(proj) do
                    if type(k) == "string" and type(v) == "function" then
                        table.insert(names, k)
                        if #names >= 24 then break end
                    end
                end
                table.sort(names)
                Add("Projectile 函数: " .. (#names > 0 and table.concat(names, ", ") or "（无）"))
            else
                Add("GunRemotes.Projectile 不是表")
            end
        else
            Add("require GunRemotes 失败: " .. tostring(gm))
        end
    end

    -- 如果 FireServerNew 被枪脚本缓存、拦截恒为 0，下一步就改这条最深的路（发包模块）
    local packetMod = nil
    pcall(function()
        for _, d in ipairs(rs:GetDescendants()) do
            if d:IsA("ModuleScript") and string.find(string.lower(d.Name), "gunpacket", 1, true) then
                packetMod = d
                break
            end
        end
    end)
    Add("GunPackets 模块: " .. (packetMod and packetMod:GetFullName() or "没找到"))

    Add(string.format("统计: 拦截 %d / 改写 %d / 本来会改写 %d / 未改写 %d / 改写失败退回 %d",
        Silent.shots, Silent.rewrites, Silent.would, Silent.skipped, Silent.failed))
    Add("最近目标: " .. tostring(Silent.targetName or "无")
        .. (Silent.targetDist and string.format("（%.0f studs）", Silent.targetDist) or ""))
    if State.SilentAim and Silent.installed and Silent.shots == 0 then
        Add("提示: 已挂上但还没拦截到开火 —— 开一枪再看；开过枪还是 0，说明枪脚本把函数缓存了")
    end
    return table.concat(lines, "\n")
end
end   -- 静默自瞄段结束

-- ============================ 持枪自动开火（模拟鼠标按住左键） ============================
-- 检测到手上是枪（判定同「仅持枪时自瞄」）就模拟按住鼠标左键：
--   全自动枪 → 一直开火；半自动枪 → 按住只响一发，打开「改用连点」才会持续打。
-- 收枪 / 换非枪工具 / 死亡 / 聊天框聚焦 / 关开关 / 关脚本 都会自动松开。
-- 点击位置固定在屏幕左下角，避开我们自己的面板和游戏 UI；
-- 执行器不支持「按住」时自动降级成连点，不会一动不动。
local AutoFire = {
    thread = nil, held = false, method = nil, lastTool = nil, forceClick = false,
    pressAt = nil, holdVerified = nil,
    -- 附近有人自动暂停的现场信息（面板「检测当前手持武器」会读它）
    safePaused = false, nearDist = nil, nearName = nil,
}

do
-- 鼠标现在是不是压在我们自己的面板上？返回 true / false，查不了返回 nil
-- （面板默认是屏幕正中 600x400，正常游玩时鼠标经常就在它上面）
local function AutoFireOverOwnGui(x, y)
    local gui = NARAMO_GuiRef
    if not gui then return nil end
    local ok, objs = pcall(function() return PlayerGui:GetGuiObjectsAtPosition(x, y) end)
    if not ok or type(objs) ~= "table" then return nil end
    for _, obj in ipairs(objs) do
        if obj:IsDescendantOf(gui) then return true end
    end
    return false
end

-- 点击点：优先点「鼠标现在所在的位置」—— 点在这里等于鼠标没有动，游戏就不会
-- 因为鼠标被挪走而把视角/角色转向别处。
-- 之前写死屏幕左下角 (10, 视口高-20)，每按下一次都等于把虚拟鼠标从准星拽到左下角，
-- 有些枪是按鼠标位置算朝向/让角色转身的 —— 暂停一次→恢复一次，视角就偏一点。
-- 鼠标被游戏锁在中间（第一人称）时直接用屏幕正中，连读鼠标位置都不用。
local function AutoFirePoint()
    local vp = Vector2.new(1920, 1080)
    pcall(function() vp = workspace.CurrentCamera.ViewportSize end)
    local centerX, centerY = math.floor(vp.X * 0.5), math.floor(vp.Y * 0.5)
    local cornerX, cornerY = 10, math.max(10, math.floor(vp.Y) - 20)

    local locked = false
    pcall(function() locked = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter end)
    if locked then
        -- 锁定状态下光标本来就在正中，点正中 = 零位移
        local over = AutoFireOverOwnGui(centerX, centerY)
        if over == nil then return cornerX, cornerY, false end
        return centerX, centerY, over
    end

    local ok, pos = pcall(function() return UserInputService:GetMouseLocation() end)
    if not (ok and typeof(pos) == "Vector2") then return centerX, centerY, false end
    local x, y = math.floor(pos.X), math.floor(pos.Y)
    if x < 0 or y < 0 or x > vp.X or y > vp.Y then return centerX, centerY, false end

    local over = AutoFireOverOwnGui(x, y)
    if over == nil then
        -- 查不了自家界面：退回老的左下角，宁可视角偏一点也不能点到自己的开关
        return cornerX, cornerY, false
    end
    return x, y, over
end

-- 发一次鼠标事件。如果这个点正压在我们自己的面板上，先把 ScreenGui 关掉一瞬间再发：
-- 面板被临时禁用 -> 这一下点不到面板（不会把开关点掉），点完立刻恢复，
-- 整个过程在同一帧内完成，画面不会闪。
local function AutoFireSend(x, y, overOwn, fn)
    local gui = NARAMO_GuiRef
    if overOwn and gui and gui.Enabled then
        gui.Enabled = false
        local ok = pcall(fn)
        gui.Enabled = true
        return ok
    end
    return pcall(fn)
end

-- 按住：优先 VirtualInputManager（引擎级输入，游戏里是「真的按住」），
-- 其次执行器的 mouse1press。返回用到的通道，松开时按同一个通道放。
local function AutoFirePress()
    local x, y, over = AutoFirePoint()
    local okVim, vim = pcall(function() return game:GetService("VirtualInputManager") end)
    if okVim and vim then
        local ok = AutoFireSend(x, y, over, function()
            vim:SendMouseButtonEvent(x, y, 0, true, game, 1)
        end)
        if ok then return "VirtualInputManager" end
    end
    local okFn, fn = pcall(function() return mouse1press end)
    if okFn and type(fn) == "function" and pcall(fn) then return "mouse1press" end
    return nil
end

-- 松开：用「按下去的那条通道」放；另一条只在第一条失败时兜底。
-- 原来是无条件两条都放 —— 执行器的 mouse1release 很多会顺手把鼠标挪到 (0,0)，
-- 于是每暂停一次就把视角往左上拽一下，人走远恢复后视角自然就不在原地了。
local function AutoFireRelease(method)
    local x, y, over = AutoFirePoint()
    local vimOk = false
    local okVim, vim = pcall(function() return game:GetService("VirtualInputManager") end)
    if okVim and vim then
        vimOk = AutoFireSend(x, y, over, function()
            vim:SendMouseButtonEvent(x, y, 0, false, game, 1)
        end)
    end
    if method ~= "VirtualInputManager" or not vimOk then
        local okFn, fn = pcall(function() return mouse1release end)
        if okFn and type(fn) == "function" then pcall(fn) end
        return
    end
    -- VIM 松完再确认一次：万一游戏没收到（事件被吞），才用执行器函数补一刀。
    -- 平时这条路不走，也就不会每次暂停都多调一次 mouse1release 把鼠标拖走。
    task.wait(0.03)
    local stillDown = false
    pcall(function() stillDown = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) end)
    if stillDown then
        local okFn, fn = pcall(function() return mouse1release end)
        if okFn and type(fn) == "function" then pcall(fn) end
    end
end

-- 点一下（连点模式 / 降级兜底）
local function AutoFireClickOnce()
    local x, y, over = AutoFirePoint()
    local okVim, vim = pcall(function() return game:GetService("VirtualInputManager") end)
    if okVim and vim then
        local ok = AutoFireSend(x, y, over, function()
            vim:SendMouseButtonEvent(x, y, 0, true, game, 1)
            vim:SendMouseButtonEvent(x, y, 0, false, game, 1)
        end)
        if ok then return true end
    end
    local okFn, fn = pcall(function() return mouse1click end)
    if okFn and type(fn) == "function" and pcall(fn) then return true end
    local okPress, press = pcall(function() return mouse1press end)
    local okRelease, release = pcall(function() return mouse1release end)
    if okPress and okRelease and type(press) == "function" and type(release) == "function" then
        if pcall(function() press(); task.wait(0.01); release() end) then return true end
    end
    return false
end

-- 给面板上的「视角自检」按钮用：返回 当前会用的点击点 x, y, 是否压在自己面板上
function AutoFire.ClickPoint()
    return AutoFirePoint()
end

-- 现在能不能开火：活着 + 手上有枪
local function AutoFireReady()
    if IsClosing then return false, nil end
    local char = LocalPlayer.Character
    if not char then return false, nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false, nil end
    local tool = GunSpeed.CurrentTool()
    if not tool then return false, nil end
    return GunSpeed.IsGunTool(tool), tool
end

-- 不屏蔽名单：名单里的人（比如自己的小号）不算「附近有人」，不会让自动开火暂停。
-- 存在 State.AutoFireSafeIgnore 里，元素是名字；比较时统一小写，
-- 用户名（p.Name）和显示名（p.DisplayName）都认，这样你按游戏里看到的名字加也行。
function AutoFire.IsIgnored(name)
    if type(name) ~= "string" or name == "" then return false end
    local list = State.AutoFireSafeIgnore
    if type(list) ~= "table" then return false end
    local lower = string.lower(name)
    for _, n in ipairs(list) do
        if type(n) == "string" and string.lower(n) == lower then return true end
    end
    return false
end

-- 加一个名字：去首尾空格、去重；返回 ok, 说明
function AutoFire.AddIgnore(name)
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return false, "名字是空的" end
    if type(State.AutoFireSafeIgnore) ~= "table" then State.AutoFireSafeIgnore = {} end
    if AutoFire.IsIgnored(name) then return false, "这个名字已经在不屏蔽名单里了" end
    table.insert(State.AutoFireSafeIgnore, name)
    return true, name
end

-- 按序号删一个名字；返回 ok, 被删掉的名字
function AutoFire.RemoveIgnore(index)
    local list = State.AutoFireSafeIgnore
    if type(list) ~= "table" or not list[index] then return false, nil end
    local name = table.remove(list, index)
    return true, name
end

-- 附近有没有别的真人玩家（队友也算）：返回 最近距离, 名字
-- 距离按「我的 HumanoidRootPart → 他的 HumanoidRootPart」算，和 ESP 上显示的 m 是同一套
-- （这个游戏 1 stud 就显示成 1m，所以阈值 150 就是面板上看到的 150m）
-- 死掉的角色不算（死亡后会在地上留一会儿）；刚重生、Humanoid 还没挂上的照算，毕竟人已经在那了
-- 「不屏蔽名单」里的人直接跳过：他们站在旁边也不算有人，自动开火照常打
local function AutoFireNearbyPlayer()
    local myChar = LocalPlayer.Character
    local myPart = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myPos = myPart and myPart.Position or nil
    if not myPos then
        local cam = workspace.CurrentCamera
        myPos = cam and cam.CFrame.Position or nil
    end
    if not myPos then return nil, nil end

    local limit = tonumber(State.AutoFireSafeDist) or 150
    local best, bestName = nil, nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local char = p.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local part = char and (char:FindFirstChild("HumanoidRootPart")
                or char:FindFirstChildWhichIsA("BasePart"))
            local ignored = AutoFire.IsIgnored(p.Name) or AutoFire.IsIgnored(p.DisplayName)
            if part and (not hum or hum.Health > 0) and not ignored then
                local d = (part.Position - myPos).Magnitude
                if d <= limit and (not best or d < best) then
                    best, bestName = d, p.Name
                end
            end
        end
    end
    return best, bestName
end

function AutoFire.Stop()
    if AutoFire.thread then pcall(task.cancel, AutoFire.thread); AutoFire.thread = nil end
    if AutoFire.held then AutoFireRelease(AutoFire.method) end
    AutoFire.held, AutoFire.method, AutoFire.lastTool = false, nil, nil
    AutoFire.forceClick = false
    AutoFire.pressAt, AutoFire.holdVerified = nil, nil
    AutoFire.safePaused, AutoFire.nearDist, AutoFire.nearName = false, nil, nil
end

function AutoFire.Start()
    AutoFire.Stop()
    AutoFire.thread = TrackThread(task.spawn(function()
        local lastClick = 0
        local warned = false
        local lastPaused = false
        while State.AutoFire and not IsClosing do
            local okG, gun, tool = pcall(AutoFireReady)
            gun = okG and gun or false
            local focused, menuOpen = false, false
            pcall(function() focused = UserInputService:GetFocusedTextBox() ~= nil end)
            pcall(function() menuOpen = game:GetService("GuiService").MenuIsOpen end)

            -- 附近有人自动暂停：只要 150 格内还有活着的玩家，这一轮就不开火（连点也不点）
            -- 人一走远，paused 变回 false，下面会重新按下去 / 继续连点，不用手动重开开关
            local nearDist, nearName = nil, nil
            if State.AutoFireSafe then
                local okNear, d, n = pcall(AutoFireNearbyPlayer)
                if okNear then nearDist, nearName = d, n end
            end
            local paused = (nearDist ~= nil)
            AutoFire.safePaused, AutoFire.nearDist, AutoFire.nearName = paused, nearDist, nearName
            if paused ~= lastPaused then
                lastPaused = paused
                if paused then
                    print(string.format(
                        "[NARAMO] 自动开火: 附近 %.0f 格有玩家 %s（阈值 %d 格），已暂停；人走远后自动继续",
                        nearDist, tostring(nearName), math.floor(tonumber(State.AutoFireSafeDist) or 150)))
                else
                    print("[NARAMO] 自动开火: 附近没人了，恢复自动开火")
                end
            end

            if gun and not focused and not menuOpen and not paused then
                -- 从「长按」切到「连点」时先把按住的那一下松开，不然会一直算按住
                if (State.AutoFireClick or AutoFire.forceClick) and AutoFire.held then
                    AutoFireRelease(AutoFire.method)
                    AutoFire.held, AutoFire.method, AutoFire.lastTool = false, nil, nil
                end
                if State.AutoFireClick or AutoFire.forceClick then
                    local gap = math.clamp((tonumber(State.AutoFireIntervalMs) or 80) / 1000, 0.02, 1)
                    local now = os.clock()
                    if now - lastClick >= gap then
                        lastClick = now
                        AutoFireClickOnce()
                    end
                else
                    -- 长按：刚拿上枪 / 换了另一把枪 → 重新按一次（旧的那次先松开）
                    if not AutoFire.held or AutoFire.lastTool ~= tool then
                        if AutoFire.held then AutoFireRelease(AutoFire.method) end
                        AutoFire.held, AutoFire.method = false, nil
                        local method = AutoFirePress()
                        if method then
                            AutoFire.held, AutoFire.method = true, method
                            AutoFire.lastTool = tool
                            AutoFire.pressAt, AutoFire.holdVerified = os.clock(), nil
                        else
                            AutoFire.forceClick = true
                            if not warned then
                                warned = true
                                print("[NARAMO] 自动开火: 这个执行器不支持模拟按住，已自动改用连点")
                            end
                        end
                    end
                end

                -- 按住 0.6 秒后回头看输入状态：如果游戏根本没收到底部按下的状态，
                -- 说明这个执行器的虚拟输入不进鼠标状态机，直接降级成连点（否则会干等着不开火）
                if AutoFire.held and not AutoFire.holdVerified and AutoFire.pressAt
                    and (os.clock() - AutoFire.pressAt) >= 0.6 then
                    local pressed = true
                    pcall(function()
                        pressed = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                    end)
                    AutoFire.holdVerified = true
                    if not pressed then
                        AutoFireRelease(AutoFire.method)
                        AutoFire.held, AutoFire.method, AutoFire.lastTool = false, nil, nil
                        AutoFire.forceClick = true
                        if not warned then
                            warned = true
                            print("[NARAMO] 自动开火: 长按没被游戏识别，已自动改用连点")
                        end
                    end
                end
            else
                if AutoFire.held then
                    AutoFireRelease(AutoFire.method)
                    AutoFire.held, AutoFire.method, AutoFire.lastTool = false, nil, nil
                end
            end

            local waitTime = (State.AutoFireClick or AutoFire.forceClick) and 0.02 or 0.12
            if paused then waitTime = math.max(waitTime, 0.1) end   -- 暂停时 10Hz 复查就够，别空转
            task.wait(waitTime)
        end
        if AutoFire.held then AutoFireRelease(AutoFire.method) end
        AutoFire.held, AutoFire.method, AutoFire.lastTool = false, nil, nil
        AutoFire.thread = nil
    end))
end

function AutoFire.SetEnabled(on)
    on = on and true or false
    State.AutoFire = on
    if on then
        AutoFire.Start()
        local safe = State.AutoFireSafe
            and string.format("，%d 格内有玩家会自动暂停", math.floor(tonumber(State.AutoFireSafeDist) or 150))
            or "，附近有人也照打（附近有人暂停已关）"
        print("[NARAMO] 自动开火: 已开启（" .. (State.AutoFireClick and "连点" or "长按")
            .. "模式，手里是枪才会开火" .. safe .. "；按下 / 松开都在鼠标原地发，不再把光标拽走）")
    else
        local was = (AutoFire.thread ~= nil) or AutoFire.held
        AutoFire.Stop()
        if was then print("[NARAMO] 自动开火: 已关闭，鼠标已松开") end
    end
    return State.AutoFire
end
end   -- 自动开火段结束

local function DisableAllFeatures()
    for _, key in ipairs({ "InfJump", "Noclip", "FullBright", "ESPEnabled", "AimbotEnabled",
                           "NPCESPEnabled", "NPCAimEnabled", "WalkSpeedEnabled", "InfiniteAmmo",
                           "InstantInteract", "WrenchRepair", "WrenchAutoRepair", "SkyWalk",
                           "VehiclePushEnabled", "VehicleTurnEnabled", "VehicleHoverEnabled", "WrenchTour",
                           "SilentAim", "AutoFire" }) do
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
    -- 「同一台设备的冷却」「主循环扫描间隔」已经挪到面板上（State.WrenchAutoCooldownMs /
    -- State.WrenchAutoTickMs），这里不再写死
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
-- 返回 最后读到的耐久值（读不到时是 nil）, 是否卡住（耐久一直不涨 = 服务端在冷却）
local function WrenchRepairUntilFull(repair, request, tool, part)
    if not part or not part:IsDescendantOf(workspace) then return nil end
    local cur, mx = WrenchDurability(part)
    if cur ~= nil and mx ~= nil and cur >= mx - 0.01 then return cur end   -- 本来就是满的

    local maxFires = (mx ~= nil) and WrenchTune.maxFires or WrenchTune.unknownFires
    local stall = 0
    local stalled = false

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
            if mx ~= nil and stall >= WrenchTune.stallFires then
                stalled = true; break                          -- 服务端在冷却，别空打
            end
        end
        cur = nv
    end
    return cur, stalled
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
    -- 冷却从「这一轮开始」算起，默认 500ms；要更快就调小（最小 100ms）
    local waitFor = (cur == nil or mx == nil) and 30
        or (math.clamp(tonumber(State.WrenchAutoCooldownMs) or 500, 100, 60000) / 1000)
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
            local after, stalled = WrenchRepairUntilFull(repair, request, tool, part)
            if stalled then
                -- 服务端在冷却：怎么打耐久都不涨，这台先放 5 秒，
                -- 免得把「同一设备冷却」调快之后一直对着它空打
                WrenchAutoSeen[part] = os.clock() + 5
            end
            local txt = "?"
            if tonumber(after) then txt = tostring(math.floor(tonumber(after))) end
            print(string.format("[PM秒维修] 自动维修 %s → 耐久 %s%s", tostring(part.Name), txt,
                stalled and "（耐久没涨，这台先放 5 秒）" or ""))
        end)
        WrenchBusy = false
    end)
end

local function WrenchStartLoop()
    if WrenchThread then return end
    WrenchThread = task.spawn(function()
        while not IsClosing and (State.WrenchRepair or State.WrenchAutoRepair) do
            -- 扫描间隔可调（默认 100ms）：调小能更快发现刚掉耐久的设备，代价是扫描更频繁
            task.wait(math.clamp((tonumber(State.WrenchAutoTickMs) or 100) / 1000, 0.03, 1))
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
-- 自动开火 / 反挂机点鼠标时要知道「这一下会不会点到自己面板」。
-- 用全局名而不是顶层 local：文件头的「修复 11」说过顶层 local 有 200 个硬上限
NARAMO_GuiRef = ScreenGui

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
                          "WalkSpeedEnabled", "InfiniteAmmo", "AntiIdle",
                          "InstantInteract", "WrenchRepair", "WrenchAutoRepair", "SkyWalk",
                          "VehiclePushEnabled", "VehicleTurnEnabled", "VehicleHoverEnabled", "WrenchTour",
                          "SilentAim", "AutoFire" }) do
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
-- 自动维修的速度由两个参数决定：
--   冷却 = 同一台设备隔多久才允许再修一轮（默认 500ms，越小事后重连越快）
--   扫描 = 主循环隔多久看一眼身边有没有掉耐久的设备（默认 100ms）
-- 一轮之内是 0 间隔逐帧连发，直到耐久满，所以这两个才是「每次维修后的间隔」
CreateSlider(MainPage, "自动维修·同一设备冷却 (毫秒)", "WrenchAutoCooldownMs", 100, 5000, State.WrenchAutoCooldownMs,
    function(v) State.WrenchAutoCooldownMs = v end)
CreateSlider(MainPage, "自动维修·扫描间隔 (毫秒)", "WrenchAutoTickMs", 30, 500, State.WrenchAutoTickMs,
    function(v) State.WrenchAutoTickMs = v end)
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

-- ============================ 反挂机 ============================
-- Roblox 的闲置踢人是「20 分钟没有任何输入」就踢，这里固定每 19 分钟模拟一次鼠标左键点击，
-- 点击走客户端的输入管线，闲置计时器会被刷新，人挂着不动也不会被踢。
-- 包成 do...end：线程句柄、点击函数都是段内局部变量，用完即释放，不占顶层 200 个名额。
do
    local AntiIdleThread = nil
    local IdleConn = nil
    local ANTI_IDLE_INTERVAL = 19     -- 固定 19 分钟（服务器 20 分钟闲置踢人）

    -- 模拟一次鼠标左键点击。不同执行器能力不一样，按可靠程度依次退：
    --   1) VirtualInputManager（引擎级输入，InputBegan 会真的触发，最通用）
    --   2) 执行器自带的 mouse1click / mouse1press+mouse1release
    --   3) VirtualUser（老式反挂机脚本的写法，CaptureController + ClickButton）
    local function ClickOnce()
        -- 点击点固定在屏幕左下角：避开我们自己的面板 / 右下角弹窗 / 右侧移动端按钮。
        -- 不用当前鼠标位置 —— 刚点完开关时鼠标正压在面板上，19 分钟后会把自己的开关点掉。
        local vp = Vector2.new(1920, 1080)
        pcall(function() vp = workspace.CurrentCamera.ViewportSize end)
        local x = 10
        local y = math.max(10, math.floor(vp.Y) - 20)

        -- 1) VirtualInputManager
        local okVim, vim = pcall(function() return game:GetService("VirtualInputManager") end)
        if okVim and vim then
            local okClick = pcall(function()
                vim:SendMouseMoveEvent(x, y, game)
                vim:SendMouseButtonEvent(x, y, 0, true, game, 1)
                task.wait(0.05)
                vim:SendMouseButtonEvent(x, y, 0, false, game, 1)
            end)
            if okClick then return true, "VirtualInputManager" end
        end

        -- 2) 执行器全局函数
        local okFn, fn = pcall(function() return mouse1click end)
        if okFn and type(fn) == "function" then
            local okClick = pcall(fn)
            if okClick then return true, "mouse1click" end
        end
        local okPress, press = pcall(function() return mouse1press end)
        local okRelease, release = pcall(function() return mouse1release end)
        if okPress and okRelease and type(press) == "function" and type(release) == "function" then
            local okClick = pcall(function()
                press()
                task.wait(0.05)
                release()
            end)
            if okClick then return true, "mouse1press/mouse1release" end
        end

        -- 3) VirtualUser：老式反挂机脚本的保底写法
        local okVu, vu = pcall(function() return game:GetService("VirtualUser") end)
        if okVu and vu then
            local okClick = pcall(function()
                vu:CaptureController()
                vu:ClickButton1(Vector2.new(x, y))
            end)
            if okClick then return true, "VirtualUser" end
        end

        return false, nil
    end

    local function StopLoop()
        if AntiIdleThread then pcall(task.cancel, AntiIdleThread); AntiIdleThread = nil end
    end

    local function StartLoop()
        StopLoop()
        AntiIdleThread = TrackThread(task.spawn(function()
            while State.AntiIdle and not IsClosing do
                task.wait(ANTI_IDLE_INTERVAL * 60)   -- 先等再点：刚开启的那一下不会误触游戏
                if not State.AntiIdle or IsClosing then break end
                local ok, how = ClickOnce()
                if ok then
                    print("[NARAMO] 反挂机: 已模拟鼠标点击（" .. tostring(how) .. "），闲置计时器已刷新")
                else
                    print("[NARAMO] 反挂机: 模拟点击失败（这个执行器不支持 VirtualInputManager / mouse1click），下一轮再试")
                end
            end
            AntiIdleThread = nil
        end))
    end

    CreateToggle(MainPage, "反挂机 (定时模拟鼠标点击)", "AntiIdle", State.AntiIdle, function(v)
        State.AntiIdle = v
        if v then
            -- 兜底：万一哪次点击没送到、真触发了 20 分钟闲置踢人，Idled 事件里再补一次
            if not IdleConn and LocalPlayer.Idled then
                IdleConn = Track(LocalPlayer.Idled:Connect(function()
                    if IsClosing or not State.AntiIdle then return end
                    ClickOnce()
                end))
            end
            StartLoop()
            print("[NARAMO] 反挂机: 已开启，每 " .. tostring(ANTI_IDLE_INTERVAL) .. " 分钟模拟一次鼠标点击")
        else
            local wasRunning = AntiIdleThread ~= nil
            StopLoop()
            if wasRunning then print("[NARAMO] 反挂机: 已关闭") end
        end
    end)
end

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
-- 仅持枪时自瞄：手上 Tool 不是枪就不锁（玩家自瞄 + NPC 自瞄都管；判定见 GunSpeed.IsGunTool）
CreateToggle(AimbotPage, "仅持枪时自瞄 (手上不是枪就不锁)", "OnlyGunAim", State.OnlyGunAim, function(v)
    State.OnlyGunAim = v
    if not State.OnlyGunAim then return end        -- 关掉时不用判定，直接放行
    local isGun, why, name = GunSpeed.IsGunTool(GunSpeed.CurrentTool())
    print(string.format("[NARAMO] 仅持枪时自瞄: 开 | 当前手上 %s → %s（%s）",
        tostring(name or "空手"), isGun and "是枪" or "不是枪", tostring(why)))
end)
-- 手动检测一次：换枪后不确定手上算不算枪就点它，控制台 + 右上角通知都会说清楚
CreateButton(AimbotPage, "检测当前手持武器 (算不算枪 / 自瞄会不会生效)", function()
    local isGun, why, name = GunSpeed.IsGunTool(GunSpeed.CurrentTool())
    local msg = string.format("手上 %s → %s（%s）", tostring(name or "空手"),
        isGun and "是枪" or "不是枪", tostring(why))
    print("[NARAMO] 持枪检测: " .. msg)
    print(string.format("[NARAMO] 自动开火: %s | %s | 连点间隔 %d ms",
        State.AutoFire and "开" or "关",
        AutoFire.held and "正在按住左键" or (State.AutoFireClick and "连点模式" or "空闲"),
        math.floor(tonumber(State.AutoFireIntervalMs) or 0)))
    if State.AutoFire then
        if AutoFire.safePaused then
            print(string.format("[NARAMO] 自动开火: 暂停中 —— 附近 %.0f 格有玩家 %s（阈值 %d 格），人走远自动继续",
                tonumber(AutoFire.nearDist) or 0, tostring(AutoFire.nearName),
                math.floor(tonumber(State.AutoFireSafeDist) or 150)))
        else
            local ignoreCount = 0
            if type(State.AutoFireSafeIgnore) == "table" then ignoreCount = #State.AutoFireSafeIgnore end
            print(string.format("[NARAMO] 自动开火: 附近 %d 格内没有需要屏蔽的玩家（不屏蔽名单 %d 人），照常开火",
                math.floor(tonumber(State.AutoFireSafeDist) or 150), ignoreCount))
        end
    end
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "NARAMO 持枪检测",
            Text = msg,
            Duration = 4,
        })
    end)
end)
-- 持枪自动开火：手上是枪就模拟按住左键（收枪 / 死亡 / 聊天框聚焦 / 关脚本会自动松开）
-- 全自动枪用长按就够了；半自动枪按住只响一发，打开「改用连点」才会持续打
CreateToggle(AimbotPage, "持枪自动开火 (检测到枪就按住左键)", "AutoFire", State.AutoFire, function(v)
    AutoFire.SetEnabled(v)
end)
CreateToggle(AimbotPage, "自动开火·改用连点 (半自动枪用)", "AutoFireClick", State.AutoFireClick, function(v) State.AutoFireClick = v end)
CreateSlider(AimbotPage, "自动开火·连点间隔 (毫秒)", "AutoFireIntervalMs", 20, 1000, State.AutoFireIntervalMs, function(v) State.AutoFireIntervalMs = v end)
-- 附近有人自动暂停：阈值内有真人玩家就松开左键，人走远后自动继续（队友也算）
CreateToggle(AimbotPage, "自动开火·附近有人就暂停 (人走远自动继续)", "AutoFireSafe", State.AutoFireSafe, function(v)
    State.AutoFireSafe = v
    AutoFire.safePaused = false          -- 关掉时把暂停现场的显示一起清掉
    print(v and string.format("[NARAMO] 附近有人暂停: 已开启（%d 格内有玩家就停，人走远自动继续）",
            math.floor(tonumber(State.AutoFireSafeDist) or 150))
        or "[NARAMO] 附近有人暂停: 已关闭（附近有人也照常开火）")
end)
CreateSlider(AimbotPage, "自动开火·暂停距离 (m, 默认 150)", "AutoFireSafeDist", 20, 1000, State.AutoFireSafeDist, function(v) State.AutoFireSafeDist = v end)

-- 不屏蔽名单：名单里的人（例如自己的小号）站在旁边也不会让自动开火暂停。
-- 下面输入名字回车添加，点名单里的名字删除；按「用户名 / 显示名」不区分大小写匹配。
-- 包成 do ... end：段内局部变量用完即释放，不占顶层 200 个名额
do
local ignoreFrame = Instance.new("ScrollingFrame")
ignoreFrame.Size = UDim2.new(1, 0, 0, 110)
ignoreFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
ignoreFrame.BorderSizePixel = 0
ignoreFrame.ScrollBarThickness = 4
ignoreFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ignoreFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
ignoreFrame.Parent = AimbotPage
Instance.new("UICorner", ignoreFrame).CornerRadius = UDim.new(0, 6)
local ignoreLayout = Instance.new("UIListLayout", ignoreFrame)
ignoreLayout.Padding = UDim.new(0, 4)
local ignorePad = Instance.new("UIPadding", ignoreFrame)
ignorePad.PaddingTop = UDim.new(0, 6)
ignorePad.PaddingLeft = UDim.new(0, 6)
ignorePad.PaddingRight = UDim.new(0, 6)

local function RefreshIgnoreList()
    for _, child in ipairs(ignoreFrame:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then child:Destroy() end
    end
    local list = State.AutoFireSafeIgnore
    if type(list) ~= "table" then
        list = {}
        State.AutoFireSafeIgnore = list
    end
    if #list == 0 then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -12, 0, 0)
        lbl.AutomaticSize = Enum.AutomaticSize.Y
        lbl.BackgroundTransparency = 1
        lbl.TextWrapped = true
        lbl.TextYAlignment = Enum.TextYAlignment.Top
        lbl.Text = "（空：附近有玩家就会暂停；把不想算进去的名字加进来，比如小号）"
        lbl.TextColor3 = Color3.fromRGB(150, 150, 160)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = ignoreFrame
        return
    end
    for i, name in ipairs(list) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -12, 0, 26)
        btn.BackgroundColor3 = Color3.fromRGB(45, 75, 55)
        btn.BorderSizePixel = 0
        btn.Text = "  " .. tostring(name) .. "   (点击移除)"
        btn.TextColor3 = Color3.fromRGB(210, 235, 215)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 12
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Parent = ignoreFrame
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        btn.MouseButton1Click:Connect(function()
            local ok, removed = AutoFire.RemoveIgnore(i)
            if ok then
                print("[NARAMO] 不屏蔽名单: 已移除 " .. tostring(removed)
                    .. "（这个人再靠近会重新暂停自动开火）")
                RefreshIgnoreList()
            end
        end)
    end
end
-- 配置加载后也要刷新这张表：用全局名，不新增顶层 local
NARAMO_RefreshAutoFireIgnore = RefreshIgnoreList

local ignoreBox
ignoreBox = CreateInput(AimbotPage, "输入不屏蔽的名字 (小号)，回车添加", function(text)
    local ok, nameOrErr = AutoFire.AddIgnore(text)
    if ok then
        if ignoreBox then ignoreBox.Text = "" end
        print("[NARAMO] 不屏蔽名单: 已添加 " .. tostring(nameOrErr)
            .. "（这个人在附近不会让自动开火暂停）")
        RefreshIgnoreList()
    else
        print("[NARAMO] 不屏蔽名单: 添加失败 —— " .. tostring(nameOrErr))
    end
end)
CreateButton(AimbotPage, "清空不屏蔽名单", function()
    State.AutoFireSafeIgnore = {}
    RefreshIgnoreList()
    print("[NARAMO] 不屏蔽名单已清空（附近有人会重新暂停自动开火）")
end)

RefreshIgnoreList()
end   -- 不屏蔽名单段结束

-- 视角自检：排查「暂停后恢复，视角跑偏」用的。开火时如果视角又偏了，点一下这个，
-- 看打印出来的鼠标状态 / 点击点，就知道是不是还在把光标拽到别处。
CreateButton(AimbotPage, "自动开火·视角自检 (鼠标状态 / 点击点 / 相机朝向)", function()
    local cam = workspace.CurrentCamera
    local cf = cam and cam.CFrame
    local yaw, pitch = 0, 0
    if cf then
        local look = cf.LookVector
        yaw = math.deg(math.atan2(-look.X, -look.Z))
        pitch = math.deg(math.asin(math.clamp(look.Y, -1, 1)))
    end
    local posText, mbText = "读不到", "?"
    pcall(function()
        local pos = UserInputService:GetMouseLocation()
        posText = string.format("(%.0f, %.0f)", pos.X, pos.Y)
    end)
    pcall(function() mbText = tostring(UserInputService.MouseBehavior) end)
    local x, y, over = AutoFire.ClickPoint()
    print(string.format(
        "[NARAMO] 自动开火自检: 相机 yaw %.1f / pitch %.1f | 鼠标位置 %s | 鼠标状态 %s | 下次点击点 (%d, %d)%s",
        yaw, pitch, posText, mbText, x, y,
        over and "（压在自己面板上，按下时会临时隐藏面板）" or ""))
end)

CreateToggle(AimbotPage, "显示 FOV 圈", "ShowFOV", State.ShowFOV, function(v) State.ShowFOV = v end)
CreateSlider(AimbotPage, "FOV 范围", "AimbotFOV", 20, 500, State.AimbotFOV, function(v) State.AimbotFOV = v end)
CreateSlider(AimbotPage, "最远自瞄距离 (studs)", "AimMaxDist", 50, 5000, State.AimMaxDist, function(v) State.AimMaxDist = v end)
CreateToggle(AimbotPage, "移动预判", "AimbotPredict", State.AimbotPredict, function(v) State.AimbotPredict = v end)
CreateSlider(AimbotPage, "子弹速度", "AimbotSpeed", 100, 5000, State.AimbotSpeed, function(v) State.AimbotSpeed = v end)
-- 自动读取 TREK GunConfig 里的 ProjectileVelocity，换枪自动更新；读不到就沿用手填的滑块
CreateToggle(AimbotPage, "自动读取弹速 (TREK GunConfig)", "AimSpeedAuto", State.AimSpeedAuto, function(v)
    State.AimSpeedAuto = v
    if v then
        local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
        GunSpeed.Refresh(tool and tool.Name)
    end
end)
-- 按 GunConfig 里的 ProjectileAcceleration（这个游戏是 -196.2）补下坠
CreateToggle(AimbotPage, "下坠补偿 (按 GunConfig 重力)", "AimDropComp", State.AimDropComp, function(v) State.AimDropComp = v end)
-- 默认只用内置表；这个开关是给"内置表里没有的新枪"用的，开了会去 require 游戏配置
CreateToggle(AimbotPage, "实读游戏配置 (仅新枪，可能影响拿枪)", "AimSpeedLiveRead", State.AimSpeedLiveRead, function(v)
    State.AimSpeedLiveRead = v
    if v then
        local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if tool then GunSpeed.cache[tool.Name] = nil end
        GunSpeed.Refresh(tool and tool.Name)
    end
end)

-- 静默自瞄：不转相机，改写开火方向（原理同 xk 的无声自瞄，落到 GunRemotes.Projectile.FireServerNew）
-- 目标按世界距离选，不受 FOV 限制；默认关，先按「静默自瞄自检」确认钩子挂上了再开。
CreateToggle(AimbotPage, "静默自瞄 (改写开火方向, 相机不动)", "SilentAim", State.SilentAim, function(v)
    Silent.SetEnabled(v)
end)
CreateSlider(AimbotPage, "静默自瞄距离 (studs, 不看 FOV)", "SilentRange", 30, 2000, State.SilentRange, function(v) State.SilentRange = v end)
CreateToggle(AimbotPage, "静默自瞄·队伍检测", "SilentTeamCheck", State.SilentTeamCheck, function(v) State.SilentTeamCheck = v end)
CreateToggle(AimbotPage, "静默自瞄·只记录不改 (干跑, 首次测试用)", "SilentDryRun", State.SilentDryRun, function(v) State.SilentDryRun = v end)
CreateButton(AimbotPage, "静默自瞄自检 (钩子 / 开火函数 / 统计)", function()
    print("[NARAMO][静默自检]\n" .. Silent.SelfCheck())
end)

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

-- 车辆传送（实测服务器接受客户端摆位置，不回弹；默认一帧瞬移）
-- 包成 do ... end：这几个局部变量用完即释放，不占顶层 200 个名额
do
    local tpBox = CreateInput(VehiclePage, "目标坐标：x, y, z（逗号或空格分隔，可直接粘贴）", nil)

    -- "123, 45, 678" / "123 45 678" / "123,45,678" 都认
    local function ParseVec3(text)
        local n = {}
        for s in tostring(text or ""):gmatch("-?%d+%.?%d*") do
            n[#n + 1] = tonumber(s)
            if #n >= 3 then break end
        end
        if #n < 3 then return nil end
        return Vector3.new(n[1], n[2], n[3])
    end

    local function VecToText(v)
        return string.format("%.0f, %.0f, %.0f", v.X, v.Y, v.Z)
    end

    -- 传送结果弹个通知，省得每次去翻控制台
    local function TPNotify(text)
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "车辆传送", Text = tostring(text), Duration = 3,
            })
        end)
    end

    -- 当前位置：坐车时取车座锚点，步行时取脚下地面点 —— 不用非得在车上
    local function GetCurrentRecordPos()
        local carPos = NARAMO_VehicleAnchor()
        if carPos then return carPos, "车座" end
        local feetPos = NARAMO_PlayerFeetPosition()
        if feetPos then return feetPos, "脚下" end
        return nil, nil
    end

    local function FillTPBox(v)
        tpBox.Text = VecToText(v)
    end

    CreateButton(VehiclePage, "传送到准星位置", function()
        if IsClosing then return end
        local ok, msg = NARAMO_VehicleTeleport(nil, { cursor = true })
        print("[NARAMO] 车辆传送: " .. tostring(msg))
        TPNotify(msg)
    end)

    CreateButton(VehiclePage, "传送到输入框坐标", function()
        if IsClosing then return end
        local v = ParseVec3(tpBox.Text)
        if not v then
            print("[NARAMO] 车辆传送: 坐标格式不对，需要三个数字，例如 123, 45, 678")
            return
        end
        local ok, msg = NARAMO_VehicleTeleport(v, { exactY = true })
        print("[NARAMO] 车辆传送: " .. tostring(msg))
        TPNotify(msg)
    end)

    CreateButton(VehiclePage, "记录车位置 → 输入框（需在车上）", function()
        if IsClosing then return end
        local p = NARAMO_VehicleAnchor()
        if not p then
            print("[NARAMO] 车辆传送: 没在车上；想记脚下的位置用下面那个「记录脚下位置」")
            return
        end
        FillTPBox(p)
        print(string.format("[NARAMO] 已记录车座位置 (%s)", VecToText(p)))
    end)

    -- 新增：不坐车也能取点 —— 站在地上就能记脚下的坐标
    CreateButton(VehiclePage, "记录脚下位置 → 输入框（步行也能用）", function()
        if IsClosing then return end
        local p = NARAMO_PlayerFeetPosition()
        if not p then
            print("[NARAMO] 车辆传送: 读不到角色位置（角色还没加载完？）")
            return
        end
        FillTPBox(p)
        print(string.format("[NARAMO] 已记录脚下位置 (%s)", VecToText(p)))
    end)

    -- ==================== 坐标点收藏（多个地点） ====================
    -- 单独存一个文件，不跟配置走：换/加载配置都不会把攒下来的点冲掉
    local BOOKMARK_FILE = CONFIG_FOLDER .. "/_vehicle_points.json"
    local BOOKMARK_LIMIT = 40
    local BookmarkFrame          -- 前向声明：刷新函数要用
    local RefreshBookmarks       -- 前向声明：保存按钮要用

    local function SaveBookmarks()
        if not writefile then return end
        pcall(function() writefile(BOOKMARK_FILE, HttpService:JSONEncode(State.VehicleTPBookmarks or {})) end)
    end

    local function LoadBookmarks()
        State.VehicleTPBookmarks = {}
        if not (isfile and isfile(BOOKMARK_FILE)) then return end
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(BOOKMARK_FILE)) end)
        if not ok or type(data) ~= "table" then return end
        for _, item in ipairs(data) do
            if type(item) == "table" then
                local x, y, z = tonumber(item.x), tonumber(item.y), tonumber(item.z)
                if x and y and z then
                    table.insert(State.VehicleTPBookmarks, {
                        name = tostring(item.name or ("点 " .. tostring(#State.VehicleTPBookmarks + 1))),
                        x = x, y = y, z = z,
                    })
                end
            end
        end
    end

    local bmNameBox = CreateInput(VehiclePage, "坐标点名称（可留空，自动编号）", nil)
    CreateButton(VehiclePage, "保存当前坐标（车上取车座 / 步行取脚下）", function()
        if IsClosing then return end
        if type(State.VehicleTPBookmarks) ~= "table" then State.VehicleTPBookmarks = {} end
        local list = State.VehicleTPBookmarks
        if #list >= BOOKMARK_LIMIT then
            print(string.format("[NARAMO] 坐标点最多存 %d 个，先删掉几个再用", BOOKMARK_LIMIT))
            return
        end
        local p, tag = GetCurrentRecordPos()
        if not p then
            print("[NARAMO] 坐标点: 读不到当前位置")
            return
        end
        local name = tostring(bmNameBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then name = "点 " .. tostring(#list + 1) end
        table.insert(list, { name = name, x = p.X, y = p.Y, z = p.Z })
        bmNameBox.Text = ""
        SaveBookmarks()
        RefreshBookmarks()
        FillTPBox(p)
        print(string.format("[NARAMO] 已保存坐标点「%s」(%s)：%s", name, tag, VecToText(p)))
    end)

    local bmTitle = Instance.new("TextLabel")
    bmTitle.Size = UDim2.new(1, 0, 0, 18)
    bmTitle.BackgroundTransparency = 1
    bmTitle.Text = "已保存的坐标点（点一下直接传送，点「删」删除）"
    bmTitle.TextColor3 = Color3.fromRGB(160, 170, 190)
    bmTitle.Font = Enum.Font.Gotham
    bmTitle.TextSize = 12
    bmTitle.TextXAlignment = Enum.TextXAlignment.Left
    bmTitle.Parent = VehiclePage

    BookmarkFrame = Instance.new("ScrollingFrame")
    BookmarkFrame.Size = UDim2.new(1, 0, 0, 150)
    BookmarkFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    BookmarkFrame.BorderSizePixel = 0
    BookmarkFrame.ScrollBarThickness = 4
    BookmarkFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    BookmarkFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    BookmarkFrame.Parent = VehiclePage
    Instance.new("UICorner", BookmarkFrame).CornerRadius = UDim.new(0, 6)
    local bmLayout = Instance.new("UIListLayout", BookmarkFrame)
    bmLayout.Padding = UDim.new(0, 4)
    local bmPad = Instance.new("UIPadding", BookmarkFrame)
    bmPad.PaddingTop = UDim.new(0, 6)
    bmPad.PaddingLeft = UDim.new(0, 6)
    bmPad.PaddingRight = UDim.new(0, 6)

    RefreshBookmarks = function()
        if not BookmarkFrame then return end
        for _, child in ipairs(BookmarkFrame:GetChildren()) do
            if child:IsA("Frame") or child:IsA("TextButton") or child:IsA("TextLabel") then child:Destroy() end
        end

        local list = State.VehicleTPBookmarks or {}
        if #list == 0 then
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -12, 0, 24)
            lbl.BackgroundTransparency = 1
            lbl.Text = "（还没有保存的坐标点）"
            lbl.TextColor3 = Color3.fromRGB(150, 150, 160)
            lbl.Font = Enum.Font.Gotham
            lbl.TextSize = 12
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = BookmarkFrame
            return
        end

        for i, item in ipairs(list) do
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, -12, 0, 30)
            row.BackgroundTransparency = 1
            row.Parent = BookmarkFrame

            -- 主按钮：点一下直接传送到这个点（不在车上会提示，不会乱动）
            local go = Instance.new("TextButton")
            go.Size = UDim2.new(1, -34, 1, 0)
            go.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
            go.BorderSizePixel = 0
            go.Text = string.format("  %d. %s  (%.0f, %.0f, %.0f)", i, tostring(item.name), item.x, item.y, item.z)
            pcall(function() go.TextTruncate = Enum.TextTruncate.AtEnd end)   -- 老执行器没有这个属性
            go.TextColor3 = Color3.fromRGB(220, 220, 225)
            go.Font = Enum.Font.Gotham
            go.TextSize = 12
            go.TextXAlignment = Enum.TextXAlignment.Left
            go.Parent = row
            Instance.new("UICorner", go).CornerRadius = UDim.new(0, 4)
            go.MouseButton1Click:Connect(function()
                if IsClosing then return end
                local v = Vector3.new(item.x, item.y, item.z)
                FillTPBox(v)
                local ok, msg = NARAMO_VehicleTeleport(v, { exactY = true })
                print("[NARAMO] 坐标点「" .. tostring(item.name) .. "」: " .. tostring(msg))
                TPNotify(msg)
            end)

            local del = Instance.new("TextButton")
            del.Size = UDim2.new(0, 30, 1, 0)
            del.Position = UDim2.new(1, -30, 0, 0)
            del.BackgroundColor3 = Color3.fromRGB(120, 45, 45)
            del.BorderSizePixel = 0
            del.Text = "删"
            del.TextColor3 = Color3.fromRGB(240, 210, 210)
            del.Font = Enum.Font.Gotham
            del.TextSize = 12
            del.Parent = row
            Instance.new("UICorner", del).CornerRadius = UDim.new(0, 4)
            del.MouseButton1Click:Connect(function()
                if IsClosing then return end
                table.remove(State.VehicleTPBookmarks, i)
                SaveBookmarks()
                RefreshBookmarks()
                print("[NARAMO] 已删除坐标点: " .. tostring(item.name))
            end)
        end
    end

    LoadBookmarks()
    RefreshBookmarks()

    CreateSlider(VehiclePage, "传送冷却 (秒)", "VehicleTPCooldown", 0, 30, State.VehicleTPCooldown, function(v)
        State.VehicleTPCooldown = v
    end)
    CreateToggle(VehiclePage, "滑行传送 (瞬移被卡时备用)", "VehicleTPGlide", State.VehicleTPGlide, function(v)
        State.VehicleTPGlide = v
    end)
    CreateSlider(VehiclePage, "滑行每帧位移 (studs)", "VehicleTPGlideStep", 5, 100, State.VehicleTPGlideStep, function(v)
        State.VehicleTPGlideStep = v
    end)
end

-- 队伍页面（管理 / 植物总监）
local TeamPage = CreatePage("队伍")
CreateToggle(TeamPage, "重点目标高亮 (管理/植物总监)", "TeamHighlightEnabled", State.TeamHighlightEnabled, function(v) State.TeamHighlightEnabled = v end)
CreateToggle(TeamPage, "发现时打印提示", "TeamNotifyEnabled", State.TeamNotifyEnabled, function(v) State.TeamNotifyEnabled = v end)
local adminKwBox = CreateInput(TeamPage, "管理员队伍关键词(逗号分隔)", function(text)
    State.AdminTeamKeywords = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end)
adminKwBox.Text = State.AdminTeamKeywords
local hvKwBox = CreateInput(TeamPage, "植物总监队伍关键词(逗号分隔)", function(text)
    State.HVTeamKeywords = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end)
hvKwBox.Text = State.HVTeamKeywords

-- 反管理页面
local AdminPage = CreatePage("反管理")

-- 判断某玩家是不是管理员：名字在名单里，或者 Unit/队伍命中管理员关键词（比如"联邦政府"）
local function IsAdminPlayer(player)
    if AdminGuard.IsListed(player.Name) then
        return true, "名单"
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

-- ============ 反管理：检测到管理员时自动重置角色 ============
-- 重置走客户端最通用的三套写法，上一套被游戏挡住时还有下一套：
--   1) Character:BreakJoints()         —— 断关节，等价于点游戏里的「重置角色」按钮
--   2) Humanoid.Health = 0             —— 关节被锁、断不开时的备选
--   3) ChangeState(Dead) / TakeDamage  —— 血量被写保护时的最后手段
-- 角色死亡后的重生由游戏服务端负责，这里只负责"把本地角色弄死"这一步。
function AdminGuard.Reset(reason)
    if IsClosing then return false end

    local now = os.clock()
    -- 正在等重生（8 秒内）就不重复重置：同一轮扫到好几个管理员也只重置一次
    if AdminGuard.pending and (now - AdminGuard.lastAt) < 8 then
        print("[NARAMO] 重置角色: 上一次重置还在等重生，跳过")
        return false
    end

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum then
        print("[NARAMO] 重置角色: 当前没有可重置的角色，跳过")
        return false
    end

    AdminGuard.pending = true
    AdminGuard.lastAt = now

    pcall(function() char:BreakJoints() end)
    pcall(function() hum.Health = 0 end)
    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Dead) end)
    pcall(function() hum:TakeDamage(math.max(hum.Health, hum.MaxHealth)) end)

    print("[NARAMO] 重置角色: 已触发（" .. tostring(reason) .. "）")

    -- 重生回调：拿到新角色才算重置成功，同时解除 pending（新角色上功能会自动恢复）
    local conn
    conn = LocalPlayer.CharacterAdded:Connect(function()
        if conn then pcall(function() conn:Disconnect() end) end
        if AdminGuard.pending then
            AdminGuard.pending = false
            print("[NARAMO] 重置角色: 已重生")
        end
    end)
    Track(conn)

    -- 兜底：8 秒内没等到重生也要放开 pending，否则以后永远不再触发重置
    task.delay(8, function()
        if conn then pcall(function() conn:Disconnect() end) end
        AdminGuard.pending = false
    end)
    return true
end

-- 管理员名单的小写索引：绘制时每帧都要判断"这个名字在不在名单里"，
-- 直接遍历 60 个名字再 string.lower 会一直产生垃圾，这里在名单变动时重建一次。
function AdminGuard.RefreshNameSet()
    local set = {}
    for _, name in ipairs(State.UserList) do
        if type(name) == "string" then set[string.lower(name)] = true end
    end
    AdminGuard.nameSet = set
    return set
end

function AdminGuard.IsListed(playerName)
    if type(playerName) ~= "string" then return false end
    local set = AdminGuard.nameSet
    if not set then                    -- 索引还没建（脚本刚起来）时退回直接扫名单
        for _, name in ipairs(State.UserList) do
            if type(name) == "string" and string.lower(name) == string.lower(playerName) then
                return true
            end
        end
        return false
    end
    return set[string.lower(playerName)] == true
end

-- ============ 右下角管理员提示框（检测到管理员时一直挂在屏幕右下角） ============
-- 包成 do...end：段内局部变量用完即释放，不占顶层 200 个名额。
do
    local frame = Instance.new("Frame")
    frame.Name = "NARAMO_AdminAlert"
    frame.AnchorPoint = Vector2.new(1, 1)
    frame.Position = UDim2.new(1, -16, 1, -16)
    frame.Size = UDim2.new(0, 320, 0, 0)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.BackgroundColor3 = Color3.fromRGB(40, 16, 16)
    frame.BackgroundTransparency = 0.08
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.ZIndex = 60
    frame.Parent = ScreenGui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(255, 90, 80)
    stroke.Thickness = 1
    stroke.Transparency = 0.3

    local layout = Instance.new("UIListLayout", frame)
    layout.Padding = UDim.new(0, 4)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    local pad = Instance.new("UIPadding", frame)
    pad.PaddingTop = UDim.new(0, 8)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)

    AdminGuard.popupFrame = frame
end

-- names 传空表/不传 = 收起弹窗。内容没变就不重建控件，避免每轮检测都闪一下。
function AdminGuard.UpdatePopup(names)
    local frame = AdminGuard.popupFrame
    if not frame then return end
    names = names or {}
    AdminGuard.lastNames = names

    if not State.AdminPopup or #names == 0 then
        frame.Visible = false
        return
    end

    local key = table.concat(names, "|")
    if AdminGuard.popupKey ~= key then
        for _, child in ipairs(frame:GetChildren()) do
            if child:IsA("TextLabel") then child:Destroy() end
        end
        for i, name in ipairs(names) do
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 0, 0)
            lbl.AutomaticSize = Enum.AutomaticSize.Y
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 14
            lbl.TextWrapped = true
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.TextYAlignment = Enum.TextYAlignment.Top
            lbl.TextColor3 = Color3.fromRGB(255, 120, 110)
            lbl.Text = "检测到管理员: " .. tostring(name)
            lbl.LayoutOrder = i
            lbl.Parent = frame
        end
        AdminGuard.popupKey = key
    end
    frame.Visible = true
end

CreateToggle(AdminPage, "自动检测管理员", "AutoCheck", State.AutoCheck, function(v)
    State.AutoCheck = v
    if AutoCheckThread then pcall(task.cancel, AutoCheckThread); AutoCheckThread = nil end
    if not v then
        table.clear(AdminGuard.done)                  -- 关掉再开，管理员可以重新触发重置
        AdminGuard.UpdatePopup({})                    -- 关掉检测就把右下角弹窗一起收起
    end
    if v then
        AutoCheckThread = task.spawn(function()
            while State.AutoCheck and not IsClosing do
                -- 本轮扫到的所有管理员（名字 + 判定来源）
                local found = {}
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer then
                        local okCall, isAdmin, why = pcall(IsAdminPlayer, p)
                        if okCall and isAdmin then table.insert(found, { name = p.Name, why = why }) end
                    end
                end

                if #found > 0 then
                    AdminGuard.emptyPasses = 0
                    local names = {}
                    for _, info in ipairs(found) do
                        table.insert(names, info.name)
                        print(string.format("[NARAMO] 检测到管理员: %s（来源: %s）", info.name, tostring(info.why)))
                    end
                    -- 右下角常驻弹窗：每个管理员一行「检测到管理员: 名字」
                    AdminGuard.UpdatePopup(names)
                    if State.DisableOnAdmin then DisableAllFeatures() end
                    -- 退服信息里也带上管理员名字（多个管理员用逗号隔开）
                    if State.AutoExit then LocalPlayer:Kick("Admin Detected: " .. table.concat(names, ", ")) end

                    -- 自动重置角色：同一个管理员只触发一次，避免站在管理员面前无限重生
                    if State.AutoResetChar then
                        local freshNames = {}
                        for _, info in ipairs(found) do
                            local key = string.lower(info.name)
                            if not AdminGuard.done[key] then
                                AdminGuard.done[key] = true
                                table.insert(freshNames, info.name)
                            end
                        end
                        if #freshNames > 0 then
                            AdminGuard.Reset("检测到管理员 " .. table.concat(freshNames, ", "))
                        end
                    end
                else
                    AdminGuard.UpdatePopup({})            -- 没有管理员：收起右下角弹窗
                    -- 连续 3 轮没扫到才认为管理员走了：刚进服时队伍信息可能还没同步好，
                    -- 单轮没扫到就清空记录会导致来回重置
                    AdminGuard.emptyPasses = AdminGuard.emptyPasses + 1
                    if AdminGuard.emptyPasses >= 3 and next(AdminGuard.done) then
                        table.clear(AdminGuard.done)
                    end
                end
                task.wait(State.CheckInterval)
            end
            AutoCheckThread = nil
        end)
    end
end)
CreateToggle(AdminPage, "发现管理时关闭所有功能", "DisableOnAdmin", State.DisableOnAdmin, function(v) State.DisableOnAdmin = v end)
CreateToggle(AdminPage, "发现管理时自动退服", "AutoExit", State.AutoExit, function(v) State.AutoExit = v end)
CreateToggle(AdminPage, "发现管理时自动重置角色", "AutoResetChar", State.AutoResetChar, function(v)
    State.AutoResetChar = v
    if not v then table.clear(AdminGuard.done) end    -- 关掉再开可以重新触发
end)
CreateToggle(AdminPage, "发现管理员时右下角弹窗", "AdminPopup", State.AdminPopup, function(v)
    State.AdminPopup = v
    AdminGuard.UpdatePopup(AdminGuard.lastNames or {})
end)
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
    AdminGuard.RefreshNameSet()   -- 名单变了，绘制用的索引也跟着重建
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
-- 包成 do ... end：页面局部变量用完即释放，不占顶层 200 个名额
do
local ConfigPage = CreatePage("配置")
local configName = "default"
local autoConfigName = nil      -- _auto.txt 里记着的自动加载配置名，没有就是 nil
local loadedName = nil          -- 当前界面状态是从哪个配置加载来的（保存时用来提醒覆盖）
local AUTO_FILE = CONFIG_FOLDER .. "/_auto.txt"

-- 页头说明：点列表只是选中，不会立刻加载
local configHint = Instance.new("TextLabel")
configHint.Size = UDim2.new(1, 0, 0, 0)
configHint.AutomaticSize = Enum.AutomaticSize.Y
configHint.BackgroundTransparency = 1
configHint.TextWrapped = true
configHint.TextXAlignment = Enum.TextXAlignment.Left
configHint.TextYAlignment = Enum.TextYAlignment.Top
configHint.Font = Enum.Font.Gotham
configHint.TextSize = 12
configHint.TextColor3 = Color3.fromRGB(150, 160, 180)
configHint.Text = "列表里点一下只是「选中」这个配置，不会马上加载；选中后再点「加载选中配置」才生效。"
    .. "如果选中的这份正好是自动加载项，下面的按钮会变成「取消自动加载」，点它就取消。"
    .. "自动加载的那份在列表名前有 ★。"
configHint.Parent = ConfigPage

-- 配置回填：有对应控件就走控件（界面 + State 一起变），没有的直接写 State
-- 对应 xk 里 SaveManager:LoadAutoloadConfig() + 控件:SetValue() 的做法
local function ApplyConfig(data)
    if type(data) ~= "table" then return 0, 0 end
    local uiCount, rawCount = 0, 0
    for k, v in pairs(data) do
        if k == "VehicleTPBookmarks" then
            -- 坐标点收藏单独存 _vehicle_points.json，加载配置时不动它
        elseif UIControls[k] then
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
    -- 不屏蔽名单同理：手改过 / 旧配置里没有这个字段都要能兜住，界面列表跟着重建
    if type(State.AutoFireSafeIgnore) ~= "table" then State.AutoFireSafeIgnore = {} end
    if type(NARAMO_RefreshAutoFireIgnore) == "function" then NARAMO_RefreshAutoFireIgnore() end
    return uiCount, rawCount
end

local function LoadConfigByName(name)
    local path = CONFIG_FOLDER .. "/" .. name .. ".json"
    if not (isfile and isfile(path)) then return false, "文件不存在" end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok or type(data) ~= "table" then return false, "解析失败" end
    local ui, raw = ApplyConfig(data)
    loadedName = name
    return true, string.format("界面同步 %d 项 / 直接写入 %d 项", ui, raw)
end

-- _auto.txt 里只有一行配置名；读写都收在这里
local function ReadAutoName()
    if not (isfile and isfile(AUTO_FILE)) then return nil end
    local ok, content = pcall(readfile, AUTO_FILE)
    if not ok or type(content) ~= "string" then return nil end
    local name = content:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return nil end
    return name
end

-- name 为 nil 表示「取消自动加载」
local function WriteAutoName(name)
    if name == nil then
        if not (isfile and isfile(AUTO_FILE)) then return true end
        local ok = false
        if type(delfile) == "function" then ok = pcall(delfile, AUTO_FILE) end
        if not ok and writefile then
            -- 没有 delfile 的执行器：把内容清空，ReadAutoName 读到空串同样当没设置
            ok = pcall(function() writefile(AUTO_FILE, "") end)
        end
        return ok and true or false
    end
    if not writefile then return false end
    return pcall(function() writefile(AUTO_FILE, name) end) and true or false
end

local autoBtn                   -- 「设为 / 取消自动加载」按钮，选中项一变就改它的字
local SelectConfig              -- 列表点一下 → 选中（在下面赋值）

-- 按「选中的配置是不是自动加载项」切换按钮文字和颜色
local function UpdateAutoButton()
    if not autoBtn then return end
    if configName ~= "" and autoConfigName == configName then
        autoBtn.Text = "取消自动加载（当前: " .. configName .. "）"
        autoBtn.BackgroundColor3 = Color3.fromRGB(150, 80, 40)
    else
        autoBtn.Text = "设为自动加载"
        autoBtn.BackgroundColor3 = Color3.fromRGB(50, 110, 70)
    end
end

local configNameBox = CreateInput(ConfigPage, "输入配置文件名...", function(text)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return end
    SelectConfig(text)   -- 手输的名字也算选中（还不存在的文件也能先起个名）
end)

-- 已有配置文件列表（自动读取 CONFIG_FOLDER，点一下只选中，不加载）
local ConfigListFrame = Instance.new("ScrollingFrame")
ConfigListFrame.Size = UDim2.new(1, 0, 0, 170)
ConfigListFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
ConfigListFrame.BorderSizePixel = 0
ConfigListFrame.ScrollBarThickness = 4
ConfigListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ConfigListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
ConfigListFrame.Parent = ConfigPage
Instance.new("UICorner", ConfigListFrame).CornerRadius = UDim.new(0, 6)
Instance.new("UIListLayout", ConfigListFrame).Padding = UDim.new(0, 4)
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
            -- 下划线开头的是内部文件（_vehicle_points.json 这种），不算配置
            if name and not name:match("^_") then table.insert(names, name) end
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
        local isSelected = (name == configName)
        local isAuto = (name == autoConfigName)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -12, 0, 28)
        btn.BackgroundColor3 = isSelected and Color3.fromRGB(60, 90, 160) or Color3.fromRGB(40, 40, 50)
        btn.BorderSizePixel = 0
        btn.Text = "  " .. (isAuto and "★ " or "") .. name
        btn.TextColor3 = isSelected and Color3.fromRGB(255, 255, 255)
            or (isAuto and Color3.fromRGB(150, 210, 160) or Color3.fromRGB(220, 220, 225))
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 12
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Parent = ConfigListFrame
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        btn.MouseButton1Click:Connect(function()
            SelectConfig(name)   -- 只选中，不加载
        end)
    end
    return #names
end

-- 选中某个配置：只改选中项 + 刷新高亮/按钮，不动 State
SelectConfig = function(name)
    configName = tostring(name or "")
    if configNameBox then configNameBox.Text = configName end
    UpdateAutoButton()
    RefreshConfigList()
    print("[NARAMO] 已选中配置: " .. configName .. "（点「加载选中配置」才会应用）")
end

CreateButton(ConfigPage, "刷新配置列表", function()
    local n = RefreshConfigList()
    print("[NARAMO] 配置列表已刷新，共 " .. tostring(n) .. " 个")
end)

CreateButton(ConfigPage, "保存当前配置", function()
    local path = CONFIG_FOLDER .. "/" .. configName .. ".json"
    if not writefile then
        print("[NARAMO] 配置保存失败：执行器不支持 writefile")
        return
    end
    if loadedName ~= configName then
        print("[NARAMO] 提醒：当前界面状态来自「" .. tostring(loadedName or "未加载")
            .. "」，保存会用它覆盖「" .. configName .. "」")
    end
    -- 坐标点收藏不写进配置（单独存 _vehicle_points.json），免得加载配置把攒的点冲掉
    local snapshot = {}
    for k, v in pairs(State) do
        if k ~= "VehicleTPBookmarks" then snapshot[k] = v end
    end
    local ok, err = pcall(function() writefile(path, HttpService:JSONEncode(snapshot)) end)
    print(ok and ("配置已保存: " .. path) or ("配置保存失败: " .. tostring(err)))
    if ok then
        loadedName = configName   -- 保存后，这份配置就和当前状态一致了
        RefreshConfigList()
    end
end)
CreateButton(ConfigPage, "加载选中配置", function()
    local ok, msg = LoadConfigByName(configName)
    print(ok and ("配置已加载: " .. configName .. " (" .. msg .. ")") or ("配置加载失败: " .. configName .. " - " .. msg))
end)
CreateButton(ConfigPage, "删除选中配置", function()
    local path = CONFIG_FOLDER .. "/" .. configName .. ".json"
    if isfile and isfile(path) then
        pcall(function() delfile(path) end)
        print("配置已删除: " .. configName)
        if loadedName == configName then loadedName = nil end
        if autoConfigName == configName then
            WriteAutoName(nil)
            autoConfigName = nil
            print("[NARAMO] 这份配置本来是自动加载项，已一并取消自动加载")
            UpdateAutoButton()
        end
        RefreshConfigList()
    end
end)

autoBtn = CreateButton(ConfigPage, "设为自动加载", function()
    if configName == "" then
        print("[NARAMO] 先在列表里选中一个配置")
        return
    end
    if autoConfigName == configName then
        -- 选中的就是自动加载项 → 这个按钮此刻是「取消自动加载」
        if WriteAutoName(nil) then
            print("[NARAMO] 已取消自动加载: " .. configName)
            autoConfigName = nil
        else
            print("[NARAMO] 取消自动加载失败：删不掉/清空不了 " .. AUTO_FILE)
        end
    else
        local path = CONFIG_FOLDER .. "/" .. configName .. ".json"
        if not (isfile and isfile(path)) then
            print("[NARAMO] 这个配置还没保存过，先点「保存当前配置」再设自动加载")
            return
        end
        if WriteAutoName(configName) then
            print("[NARAMO] 已设为自动加载: " .. configName)
            autoConfigName = configName
        else
            print("[NARAMO] 设置自动加载失败：执行器不支持 writefile")
        end
    end
    UpdateAutoButton()
    RefreshConfigList()   -- 列表上的 ★ 跟着变
end)
UpdateAutoButton()

-- 自动加载放在所有控件创建之后：此时 UIControls 已齐全，勾选状态也能同步
autoConfigName = ReadAutoName()
if autoConfigName then
    local ok, msg = LoadConfigByName(autoConfigName)
    print(ok and ("已自动加载配置: " .. autoConfigName .. " (" .. msg .. ")") or ("自动加载失败: " .. autoConfigName .. " - " .. msg))
    -- 顺手选中自动加载的那份：一进来就能看到它，也能直接点「取消自动加载」
    configName = autoConfigName
    if configNameBox then configNameBox.Text = autoConfigName end
end

UpdateAutoButton()
RefreshConfigList()
end   -- 配置页面结束

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

-- ============================ 队伍识别（管理 / 植物总监） ============================
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
-- 管理（不管是队伍判出来的，还是管理员名单里的）统一灰色；植物总监保留金色
local ADMIN_COLOR = Color3.fromRGB(160, 160, 160)
local HV_COLOR = Color3.fromRGB(255, 200, 40)
local TaggedSeen = {}

GetPlayerTag = function(player)
    if not State.TeamHighlightEnabled then return "", nil end
    local text = GetPlayerTeamText(player)

    -- 管理员有两种来源：队伍/Unit 命中管理关键词，或者名字在「反管理」的手动名单里。
    -- 名单里的管理员原来只在自动检测里用，这里也一起画出来（灰色），不然看不见人。
    local isAdmin = MatchKeywords(text, State.AdminTeamKeywords)
    if not isAdmin then isAdmin = AdminGuard.IsListed(player.Name) end

    local tag, color, kind
    if isAdmin then
        tag, color, kind = " [管理]", ADMIN_COLOR, "管理"
    elseif MatchKeywords(text, State.HVTeamKeywords) then
        tag, color, kind = " [植物总监]", HV_COLOR, "植物总监"
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

        -- 管理 / 植物总监：特殊颜色 + 名称后缀，且即使同队也画
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

-- 移动预判：从"直线领先"升级成"抛物线解算"
--   1) 速度优先用 GunConfig 读到的 ProjectileVelocity（换枪自动更新），读不到才用滑块
--   2) 起点用枪口（枪管）而不是相机，近距离差异明显
--   3) 按 ProjectileAcceleration（这游戏是 -196.2）补下坠，迭代 3 次收敛
local function GetPredictPosition(part)
    if not State.AimbotPredict then return part.Position end

    local speed = State.AimbotSpeed
    local info = GunSpeed.current
    if State.AimSpeedAuto and info and info.speed and info.speed > 0 then
        speed = info.speed
    end
    if not speed or speed <= 0 then return part.Position end

    local origin = GunSpeed.Muzzle()
    local targetPos = part.Position
    local vel = part.AssemblyLinearVelocity or Vector3.new(0, 0, 0)
    local gravity = 0
    if State.AimDropComp and info and info.accel then gravity = info.accel end

    local aim = targetPos
    for _ = 1, 3 do
        local travelTime = (aim - origin).Magnitude / speed
        aim = targetPos + vel * travelTime
        if gravity > 0 then
            aim = aim + Vector3.new(0, 0.5 * gravity * travelTime * travelTime, 0)
        end
    end
    return aim
end

-- 静默自瞄也复用这一份弹道预判（开火那一刻现算，目标点/提前量才准）
Silent.predict = GetPredictPosition

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

    -- 仅持枪时自瞄：手上 Tool 不是枪 → gunOk = false，玩家自瞄和 NPC 自瞄一起停
    -- （OnlyGunAim 关掉时 AimAllowed 恒返回 true，行为和以前完全一样）
    local gunOk, gunWhy, gunName = GunSpeed.AimAllowed()

    if FOVCircle then
        FOVCircle.Position = workspace.CurrentCamera.ViewportSize / 2
        FOVCircle.Radius = State.AimbotFOV
        FOVCircle.Visible = State.ShowFOV
        FOVCircle.Thickness = 1.5
        -- 手上有枪 = 绿色；手非枪被暂停 = 灰色，一眼看得出自瞄现在不生效
        FOVCircle.Color = gunOk and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(130, 130, 140)
    end
    -- 移动端悬浮按钮：只在对应自瞄开启时出现
    if MobileAimBtn then MobileAimBtn.Visible = State.AimbotEnabled end
    if MobileNpcAimBtn then MobileNpcAimBtn.Visible = State.NPCAimEnabled end

    local rmb = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    local playerActive = State.AimbotEnabled and (rmb or State.AimMobileActive) and gunOk
    local npcActive = State.NPCAimEnabled and (rmb or State.NpcAimMobileActive) and gunOk

    -- 松开右键 / 关掉开关 / 手上不是枪：立刻解除锁定，下次按下重新选人
    if not (playerActive or npcActive) then
        AimLockPart = nil
        AimLockIsNPC = false
        AimLockHeld = false
        if LockText then
            -- 本来想自瞄、但被「仅持枪」挡住时给一句提示，让人知道是暂停而不是脚本坏了
            local wantAim = (State.AimbotEnabled and (rmb or State.AimMobileActive))
                or (State.NPCAimEnabled and (rmb or State.NpcAimMobileActive))
            if wantAim and not gunOk then
                local vp = workspace.CurrentCamera.ViewportSize
                LockText.Text = "仅持枪时自瞄：手上不是枪"
                    .. (gunName and ("（" .. gunName .. "）") or "（空手）")
                LockText.Position = Vector2.new(vp.X / 2 + 26, vp.Y / 2 + 20)
                LockText.Visible = true
            elseif State.AutoFire and AutoFire.safePaused then
                -- 自动开火被「附近有人」暂停时也在屏幕上说一句，不用开控制台也知道原因
                local vp = workspace.CurrentCamera.ViewportSize
                LockText.Text = string.format("自动开火：附近 %.0f 格有玩家，已暂停",
                    tonumber(AutoFire.nearDist) or 0)
                LockText.Position = Vector2.new(vp.X / 2 + 26, vp.Y / 2 + 20)
                LockText.Visible = true
            else
                LockText.Visible = false
            end
        end
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