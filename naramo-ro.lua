-- ============================================================
-- NARAMO-RO  v1.0  (Reactor Operation · 反应堆操作)
-- ------------------------------------------------------------
-- 定位：只干「按开关」这一件事，UI 结构与主程序 NARAMO 一致（同配色 / 同侧栏 / 同迷你窗）。
--
-- 为什么是「瞬移过去按」而不是「远程点」：
--   2026-11-15 实测（探针 + Xeno，PlaceId 98626216952426）：
--     * 所有设施开关都是 ProximityPrompt，MaxActivationDistance 5～14，
--       fireproximityprompt 在距离外完全不生效（连客户端 Triggered 都收不到）。
--     * 服务器有传送检测，位置跳太远会被拉回。
--   所以引擎的写法是：存 CFrame → 瞬移到面板前 → 同帧触发 → 收到 Triggered 立即传回。
--   首次等待默认 0ms（越短越安全），收不到信号再按「重试」逐次加等待。
--
-- 分区（左侧顺序）：
--   说明：原理 / 状态颜色 / 边界（面板默认停在这页）
--   控制室：涡轮机 / 给水泵 / 控制棒 / 电力与启动 / 警报确认 / 泄压阀 / 冷却剂阀门
--   设施入口：冷却剂泵 Alpha·Beta / 加油锁
--   设施概况：反应堆温度、控制棒行程 + 控制室各面板的读数（镜像面板文字）
--   所有警报：各警报屏的告警条目（认 Neon 灯零件的透明度）
--   设置：传送距离、等待、重试、自动刷新
--
-- 状态显示：
--   [启用]/[禁用]  = 提示当前的 Enabled
--                    注意：这只代表属性，不代表动作有效（控制棒到顶后按钮仍在、Enabled 仍为 true）
--   [棒位 xx%]     = 控制棒实时行程，量的是 ControlRods 里零件的平均高度，自动校准
--   [上次: 开/关]  = 单键切换类开关没有本地状态，只能记「上次是从哪边切过来的」，
--                    存在 NARAMO_RO/config.json，换服务器/重开脚本都还在
--
-- 注意：反应堆运行中乱按可能把堆搞炸；本脚本不改游戏任何属性，只瞬移 + 触发 + 传回。
-- ============================================================

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LP = Players.LocalPlayer
local PG = LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui")

local GENV = _G
do
    local ok, g = pcall(function() return getgenv() end)
    if ok and type(g) == "table" then GENV = g end
end

local VERSION = "2026-11-15 r18"

-- 重复加载：先把旧面板拆掉，避免叠两个
if GENV.__NARAMO_RO_RUNNING then
    pcall(function()
        local old = PG:FindFirstChild("NARAMO_RO_UI")
        if old then old:Destroy() end
    end)
end
GENV.__NARAMO_RO_RUNNING = true

-- ============================================================
-- 配置 / 状态
-- ============================================================
local FOLDER = "NARAMO_RO"

local CFG = {
    off = 2.5,         -- 瞬移到离开关几格
    up = 1.5,          -- 抬高点，避免卡地板
    settle = 0,        -- 首次触发前等待（ms）。0 = 同帧触发，被拉回风险最低
    after = 90,        -- 触发后等信号的时间（ms）
    retries = 1,       -- 失败重试次数
    retryAdd = 60,     -- 每次重试多等多少 ms（给服务器同步位置留时间）
    clickSettle = 200, -- 点击类专用：瞬移后先等多久再点（服务器要先收到你的新位置）
    autoRefresh = true,
    verbose = false,
}

local MEM = {}         -- 单键切换开关的「上次状态」：id -> true/false
local Busy = false
local IsClosing = false

local function FileExists(p)
    if type(isfile) ~= "function" then return false end
    local ok, v = pcall(isfile, p)
    return ok and v
end

local function EnsureFolder()
    if type(isfolder) ~= "function" or type(makefolder) ~= "function" then return false end
    local ok, has = pcall(isfolder, FOLDER)
    if not ok then return false end
    if not has then
        pcall(makefolder, FOLDER)
        ok, has = pcall(isfolder, FOLDER)
    end
    return ok and has
end

local function SaveCfg()
    if not EnsureFolder() or type(writefile) ~= "function" then return end
    local data = { cfg = CFG, mem = MEM, version = VERSION }
    local ok, enc = pcall(function() return HttpService:JSONEncode(data) end)
    if ok and type(enc) == "string" then
        pcall(writefile, FOLDER .. "/config.json", enc)
    end
end

local function LoadCfg()
    if type(readfile) ~= "function" then return end
    local path = FOLDER .. "/config.json"
    if not FileExists(path) then return end
    local ok, raw = pcall(readfile, path)
    if not ok or type(raw) ~= "string" then return end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 or type(data) ~= "table" then return end
    if type(data.cfg) == "table" then
        for k, v in pairs(data.cfg) do
            if CFG[k] ~= nil and type(v) == type(CFG[k]) then CFG[k] = v end
        end
    end
    if type(data.mem) == "table" then
        for k, v in pairs(data.mem) do
            if type(k) == "string" then MEM[k] = v and true or false end
        end
    end
end

LoadCfg()

-- ============================================================
-- 基础工具
-- ============================================================
local function PathOf(inst)
    if not inst or inst == game then return "(game)" end
    local names = {}
    local cur, guard = inst, 0
    while cur and cur ~= game and guard < 9 do
        names[#names + 1] = cur.Name
        cur = cur.Parent
        guard = guard + 1
    end
    local out = {}
    for i = #names, 1, -1 do out[#out + 1] = names[i] end
    return table.concat(out, "/")
end

local function FindByPath(tree)
    local cur = workspace
    for _, n in ipairs(tree) do
        if not cur then return nil end
        cur = cur:FindFirstChild(n)
    end
    return cur
end

local function Char()
    local c = LP.Character
    if not c then return nil, nil, nil end
    return c, c:FindFirstChild("HumanoidRootPart"), c:FindFirstChildOfClass("Humanoid")
end

local function WorldPos(obj)
    local p = obj and obj.Parent
    if not p then return nil end
    local ok, pos = pcall(function()
        if p:IsA("Attachment") then return p.WorldPosition end
        if p:IsA("BasePart") then return p.Position end
        if p:IsA("Model") then return p:GetPivot().Position end
        return nil
    end)
    if ok then return pos end
    return nil
end

local function Resolve(entry)
    local obj = nil
    if entry.find then
        local ok, v = pcall(entry.find)
        if ok then obj = v end
    else
        obj = FindByPath(entry.tree)
    end
    -- 已经被游戏销毁的（Parent=nil）当作找不到，否则后面取坐标会炸
    if obj and obj.Parent == nil then return nil end
    return obj
end

local function Ms()
    return math.floor((os.clock() % 1) * 1000)
end

-- 取任意实例的位置：BasePart 有 Position，Model 只能用 GetPivot()
-- （踩过的坑：ReliefValve 是 Model，直接写 .Position 会抛错并把整个脚本打断）
local function InstPos(inst)
    if not inst then return Vector3.zero end
    local ok, p = pcall(function()
        if inst:IsA("BasePart") then return inst.Position end
        if inst:IsA("Model") then return inst:GetPivot().Position end
        return nil
    end)
    if ok and p then return p end
    return Vector3.zero
end

-- ============================================================
-- 遥测：自动发现「温度 / 压力 / 流量 / 棒位」这类可读数值
-- 这些不是写死的路径 —— 不同版本设备的数值挂法不一样，所以运行时扫一遍，
-- 名字命中关键词的属性 / ValueBase 全收进来，再在「设施概况」里显示。
-- ============================================================
local TELE = { items = {}, scanned = false }
local RODSTATE = { pct = nil, y = nil, span = nil }   -- 刷新循环里更新，行 / 概况页共用
local TELE_WORDS = {
    "temp", "heat", "thermal", "core", "pressure", "press", "flow", "rpm", "power",
    "watt", "mw", "coolant", "water", "steam", "level", "rod", "fuel", "xenon",
    "boron", "integrity", "damage", "output", "load", "volt", "amp", "rps",
    "state", "status", "running", "active", "enabled", "online",
}

local function TeleScore(name)
    local low = string.lower(tostring(name or ""))
    for i, w in ipairs(TELE_WORDS) do
        if string.find(low, w, 1, true) then
            if i <= 3 then return 3 end     -- temp / heat / thermal
            if i <= 10 then return 2 end    -- pressure / flow / rpm / power / rod ...
            return 1
        end
    end
    return 0
end

local function AddTele(inst, kind, key, score)
    TELE.items[#TELE.items + 1] = {
        inst = inst, kind = kind, key = key, score = score,
        name = key and (inst.Name .. "." .. key) or inst.Name,
        path = PathOf(inst),
    }
end

local function ScanTelemetry()
    TELE.items = {}
    local count = 0
    local function full() return count >= 200 end

    -- 1) ReplicatedStorage：整棵树的 ValueBase + 属性（树不大）
    local okRS, rs = pcall(function() return game:GetService("ReplicatedStorage") end)
    if okRS and rs then
        local okD, desc = pcall(function() return rs:GetDescendants() end)
        if okD and desc then
            for _, d in ipairs(desc) do
                if full() then break end
                if d:IsA("ValueBase") then
                    local s = TeleScore(d.Name)
                    if s > 0 then count = count + 1; AddTele(d, "value", nil, s) end
                end
                local okA, attrs = pcall(function() return d:GetAttributes() end)
                if okA and attrs then
                    for k, _ in pairs(attrs) do
                        if full() then break end
                        local s = TeleScore(k) + TeleScore(d.Name)
                        if s > 0 then count = count + 1; AddTele(d, "attr", k, s) end
                    end
                end
            end
        end
    end

    -- 2) workspace：只查 ValueBase，以及名字命中关键词的实例上的属性
    --    （全地图每个零件都 GetAttributes 太慢）
    local okW, all = pcall(function() return workspace:GetDescendants() end)
    if okW and all then
        for _, d in ipairs(all) do
            if full() then break end
            if d:IsA("ValueBase") then
                local s = TeleScore(d.Name)
                if s > 0 then count = count + 1; AddTele(d, "value", nil, s) end
            elseif TeleScore(d.Name) > 0 then
                local okA, attrs = pcall(function() return d:GetAttributes() end)
                if okA and attrs then
                    local s0 = TeleScore(d.Name)
                    for k, _ in pairs(attrs) do
                        if full() then break end
                        local s = TeleScore(k) + s0
                        if s > 0 then count = count + 1; AddTele(d, "attr", k, s) end
                    end
                end
            end
        end
    end

    table.sort(TELE.items, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.path < b.path
    end)
    TELE.scanned = true
    print("[NARAMO-RO] 遥测扫描：命中 " .. tostring(#TELE.items) .. " 个候选值")
end

local function TeleValueText(item)
    local ok, v = pcall(function()
        if item.kind == "attr" then return item.inst:GetAttribute(item.key) end
        return item.inst.Value
    end)
    if not ok then return "?" end
    if typeof(v) == "number" then
        local a = math.abs(v)
        if a >= 10000 then return string.format("%.0f", v) end
        if a >= 100 then return string.format("%.1f", v) end
        if a >= 1 then return string.format("%.2f", v) end
        return string.format("%.3f", v)
    end
    return tostring(v)
end

-- 读一个遥测项/指标的数值（属性或 ValueBase），非数字返回 nil
local function ItemNumber(it)
    if not it then return nil end
    local ok, v = pcall(function()
        if it.kind == "attr" then return it.inst:GetAttribute(it.key) end
        return it.inst.Value
    end)
    if ok and type(v) == "number" then return v end
    return nil
end

-- ============================================================
-- 反应堆指标：游戏自己在 ReplicatedStorage 下开了个 ReactorMetrics 文件夹
-- （诊断实测：ReplicatedStorage/ReactorMetrics/Temperature = 14256，游戏里显示 1425.6）
-- 这是最靠谱的数据源，直接读它，不要靠关键词猜。
-- ============================================================
local METRICS = { items = {}, folder = nil }

local function ScanMetrics()
    METRICS.items = {}
    METRICS.folder = nil
    local rs = game:GetService("ReplicatedStorage")
    local f = rs:FindFirstChild("ReactorMetrics")
    METRICS.folder = f
    if not f then return 0 end

    local ok, desc = pcall(function() return f:GetDescendants() end)
    if not ok or not desc then return 0 end

    for _, d in ipairs(desc) do
        if d:IsA("ValueBase") then
            METRICS.items[#METRICS.items + 1] = {
                inst = d, name = d.Name, path = PathOf(d), kind = "value",
            }
        end
        local okA, attrs = pcall(function() return d:GetAttributes() end)
        if okA and attrs then
            for k, _ in pairs(attrs) do
                METRICS.items[#METRICS.items + 1] = {
                    inst = d, name = d.Name .. "." .. tostring(k), key = k,
                    path = PathOf(d), kind = "attr",
                }
            end
        end
    end

    table.sort(METRICS.items, function(a, b) return a.name < b.name end)
    print("[NARAMO-RO] ReactorMetrics: " .. tostring(#METRICS.items) .. " 个指标")
    return #METRICS.items
end

-- 名字里带 rod 的零件（棒体可能不在 ControlRods 模型里，诊断实测那个模型全是静止件）
local RODPARTS = { list = {} }

local function FindRodParts()
    local out = {}
    local ok, all = pcall(function() return workspace:GetDescendants() end)
    if not ok or not all then return out end
    for _, d in ipairs(all) do
        if d:IsA("BasePart") then
            local low = string.lower(d.Name)
            if string.find(low, "rod", 1, true) then
                out[#out + 1] = d
                if #out >= 40 then break end
            end
        end
    end
    return out
end

-- ============================================================
-- 控制棒行程
-- 旧办法（整个模型所有零件的平均 Y）会被静态机架稀释，行程小到 0.5 格以下就测不出来。
-- 新办法：每 0.4 秒给 Reactor 下每个零件记「最小/最大位置」，谁的实际位移最大，
-- 就拿谁当尺子 —— 不管控制棒是被 CFrame 平移、还是被约束/动画带动，都能抓到。
-- ============================================================
local RODTRACK = { map = {}, best = nil, bestRange = 0 }

local function RodRoot()
    return FindByPath({ "FacilitySystems", "Controls", "Reactor", "ControlRods" })
        or FindByPath({ "FacilitySystems", "Controls", "Reactor" })
end

local function RodSample()
    -- 采样范围 = ControlRods 里的零件 + 全图名字带 rod 的零件
    local parts = {}
    local root = RodRoot()
    if root then
        local ok, desc = pcall(function() return root:GetDescendants() end)
        if ok and desc then
            local n = 0
            for _, d in ipairs(desc) do
                if n >= 160 then break end
                if d:IsA("BasePart") then
                    n = n + 1
                    parts[#parts + 1] = d
                end
            end
        end
    end
    for _, d in ipairs(RODPARTS.list) do
        if d.Parent then parts[#parts + 1] = d end
    end

    for _, d in ipairs(parts) do
        local p = d.Position
        local rec = RODTRACK.map[d]
        if not rec then
            rec = { part = d, min = p, max = p, path = PathOf(d) }
            RODTRACK.map[d] = rec
        else
            local mn, mx = rec.min, rec.max
            rec.min = Vector3.new(math.min(mn.X, p.X), math.min(mn.Y, p.Y), math.min(mn.Z, p.Z))
            rec.max = Vector3.new(math.max(mx.X, p.X), math.max(mx.Y, p.Y), math.max(mx.Z, p.Z))
        end
        local range = (rec.max - rec.min).Magnitude
        if range > RODTRACK.bestRange + 0.02 then
            RODTRACK.bestRange = range
            RODTRACK.best = rec
        end
    end
end

-- 返回 百分比(0~1 或 nil), 说明文字
local function RodUpdate()
    -- 名字像「棒位」的数值：rod + pos/insert/depth/height/level/withdraw
    local function IsRodPosName(low)
        if not string.find(low, "rod", 1, true) then return false end
        return string.find(low, "pos", 1, true) or string.find(low, "insert", 1, true)
            or string.find(low, "depth", 1, true) or string.find(low, "height", 1, true)
            or string.find(low, "level", 1, true) or string.find(low, "withdraw", 1, true)
    end

    local function PctOf(it)
        local ok, v = pcall(function()
            if it.kind == "attr" then return it.inst:GetAttribute(it.key) end
            return it.inst.Value
        end)
        if not ok or type(v) ~= "number" then return nil end
        local pct = v
        if pct > 1.5 then pct = pct / 100 end      -- 0~100 的写法
        return math.clamp(pct, 0, 1)
    end

    -- 0) ReactorMetrics 里带 rod 的指标最可信（游戏自己的数据）
    for _, m in ipairs(METRICS.items) do
        if IsRodPosName(string.lower(m.name)) then
            local pct = PctOf(m)
            if pct then return pct, m.name .. "（ReactorMetrics）" end
        end
    end

    -- 1) 再退一步：全场遥测里名字像棒位的数值
    for _, it in ipairs(TELE.items) do
        local low = string.lower(it.name)
        if IsRodPosName(low) then
            local pct = PctOf(it)
            if pct then return pct, it.name .. "（数值）" end
        end
    end

    -- 2) 几何法：找位移最大的零件，按它的主方向算百分比
    local rec = RODTRACK.best
    if not rec or RODTRACK.bestRange < 0.4 then
        return nil, "校准中（请升/降一次控制棒）"
    end
    local cur = rec.part.Position
    local d = rec.max - rec.min
    local axis, span
    if d.Y >= d.X and d.Y >= d.Z then
        axis, span = 1, d.Y
    elseif d.X >= d.Z then
        axis, span = 2, d.X
    else
        axis, span = 3, d.Z
    end
    if span < 0.4 then return nil, "校准中（位移太小）" end
    local v = (axis == 1) and cur.Y or ((axis == 2) and cur.X or cur.Z)
    local lo = (axis == 1) and rec.min.Y or ((axis == 2) and rec.min.X or rec.min.Z)
    local pct = math.clamp((v - lo) / span, 0, 1)
    return pct, string.format("零件位移 %.1f 格", span)
end

-- ============================================================
-- 开关登记表
--   kind = "prompt"（按 E / 提示）或 "click"（点击探测器）
--   mem  = 单键切换类，显示「上次」状态
-- ============================================================
local CTRL = { "FacilitySystems", "Controls" }
local function T(...)
    local t = { "FacilitySystems", "Controls" }
    for _, v in ipairs({ ... }) do t[#t + 1] = v end
    return t
end

local ENTRIES = {
    -- ── 控制室 · 涡轮机 ──────────────────────────────
    { g = "控制室", s = "涡轮机", name = "涡轮 A · 加速档", kind = "prompt", mem = true,
      tree = T("Turbines", "TurbAlphaAccelSwitch", "Switch", "ProximityPrompt") },
    { g = "控制室", s = "涡轮机", name = "涡轮 B · 加速档", kind = "prompt", mem = true,
      tree = T("Turbines", "TurbBetaAccelSwitch", "Switch", "ProximityPrompt") },
    { g = "控制室", s = "涡轮机", name = "涡轮 A · 流量 +", kind = "prompt",
      tree = T("Turbines", "TurbAlphaValveSwitch", "Prompt", "Increment") },
    { g = "控制室", s = "涡轮机", name = "涡轮 A · 流量 −", kind = "prompt",
      tree = T("Turbines", "TurbAlphaValveSwitch", "Prompt", "Decrement") },
    { g = "控制室", s = "涡轮机", name = "涡轮 B · 流量 +", kind = "prompt",
      tree = T("Turbines", "TurbBetaValveSwitch", "Prompt", "Increment") },
    { g = "控制室", s = "涡轮机", name = "涡轮 B · 流量 −", kind = "prompt",
      tree = T("Turbines", "TurbBetaValveSwitch", "Prompt", "Decrement") },
    { g = "控制室", s = "涡轮机", name = "涡轮 A · 同步", kind = "prompt", mem = true,
      tree = T("Turbines", "TurbineAlphaSyncSwitch", "Main", "ProximityPrompt") },
    { g = "控制室", s = "涡轮机", name = "涡轮 B · 同步", kind = "prompt", mem = true,
      tree = T("Turbines", "TurbineBetaSyncSwitch", "Main", "ProximityPrompt") },

    -- ── 控制室 · 给水泵 ──────────────────────────────
    { g = "控制室", s = "给水泵", name = "给水阀 总阀", kind = "prompt", mem = true,
      tree = T("Feedwater", "FeedwaterValves", "Main", "ProximityPrompt") },
    { g = "控制室", s = "给水泵", name = "给水泵 1 · 流量 +", kind = "prompt",
      tree = T("Feedwater", "FeedPump1Valve", "Prompt", "Increment") },
    { g = "控制室", s = "给水泵", name = "给水泵 1 · 流量 −", kind = "prompt",
      tree = T("Feedwater", "FeedPump1Valve", "Prompt", "Decrement") },
    { g = "控制室", s = "给水泵", name = "给水泵 2 · 流量 +", kind = "prompt",
      tree = T("Feedwater", "FeedPump2Valve", "Prompt", "Increment") },
    { g = "控制室", s = "给水泵", name = "给水泵 2 · 流量 −", kind = "prompt",
      tree = T("Feedwater", "FeedPump2Valve", "Prompt", "Decrement") },

    -- ── 控制室 · 控制棒 ──────────────────────────────
    { g = "控制室", s = "控制棒", name = "控制棒 · 提起 (Raise)", kind = "prompt", rod = true,
      tree = T("Reactor", "ControlRods", "Activate", "DownPrompt") },
    { g = "控制室", s = "控制棒", name = "控制棒 · 落下 (Lower)", kind = "prompt", rod = true,
      tree = T("Reactor", "ControlRods", "Activate", "UpPrompt") },
    { g = "控制室", s = "控制棒", name = "点火台 · 提棒", kind = "prompt",
      tree = T("Startup", "Ignition", "Dispense", "ProximityPrompt") },

    -- ── 控制室 · 电力与启动 ──────────────────────────
    { g = "控制室", s = "电力与启动", name = "功率指令 (Power Orders)", kind = "prompt", mem = true,
      tree = T("PowerOrders", "PowerOrders", "Main", "ProximityPrompt") },
    { g = "控制室", s = "电力与启动", name = "停堆泵 (Shutdown Pumps)", kind = "prompt", mem = true,
      tree = T("Startup", "Recirc", "Main", "ProximityPrompt") },
    { g = "控制室", s = "电力与启动", name = "点火授权 (Authorize Ignition)", kind = "prompt", mem = true,
      tree = T("Startup", "IgniteAuth", "Main", "ProximityPrompt") },
    { g = "控制室", s = "电力与启动", name = "电网并网按钮", kind = "click",
      tree = T("Grid", "GridSwitch", "FanIn", "Button", "ClickDetector") },

    -- ── 控制室 · 警报屏（确认按钮）────────────────────
    { g = "控制室", s = "警报屏", name = "警报确认 · 反应堆", kind = "click",
      tree = { "FacilitySystems", "Annunciators", "AnnunciatorPanelReactor", "AckButton", "Button", "ClickDetector" } },
    { g = "控制室", s = "警报屏", name = "警报确认 · 冷却剂", kind = "click",
      tree = { "FacilitySystems", "Annunciators", "AnnunciatorPanelCoolant", "AckButton", "Button", "ClickDetector" } },
    { g = "控制室", s = "警报屏", name = "警报确认 · 电力", kind = "click",
      tree = { "FacilitySystems", "Annunciators", "AnnunciatorPanelPower", "AckButton", "Button", "ClickDetector" } },
    { g = "控制室", s = "警报屏", name = "警报确认 · 涡轮", kind = "click",
      tree = { "FacilitySystems", "Annunciators", "AnnunciatorPanelTurbines", "AckButton", "Button", "ClickDetector" } },
    { g = "控制室", s = "警报屏", name = "警报确认 · 发电机房", kind = "click",
      tree = { "FacilitySystems", "Annunciators", "AnnunciatorPanelGeneratorRoom", "AckButton", "Button", "ClickDetector" } },
    { g = "控制室", s = "警报屏", name = "警报确认 · 计算机", kind = "click",
      tree = { "FacilitySystems", "Annunciators", "AnnunciatorPanelComputer", "AckButton", "Button", "ClickDetector" } },

    -- ── 设施入口 ────────────────────────────────────
    { g = "设施入口", s = "冷却剂", name = "冷却剂泵 Alpha", kind = "prompt", mem = true,
      tree = T("Coolant", "CoolantAlpha", "Main", "ProximityPrompt") },
    { g = "设施入口", s = "冷却剂", name = "冷却剂泵 Beta", kind = "prompt", mem = true,
      tree = T("Coolant", "CoolantBeta", "Main", "ProximityPrompt") },
    -- 冷却剂阀门在探针里离控制室只有 47 格（泵在 470 格外），所以归到控制室
    { g = "控制室", s = "冷却剂", name = "冷却剂阀门", kind = "prompt", mem = true,
      tree = T("Coolant", "CoolantValves", "Main", "ProximityPrompt") },
    { g = "设施入口", s = "加油", name = "加油锁 (REFUELER LOCK)", kind = "prompt", mem = true,
      tree = { "FacilitySystems", "RefuelerControls", "LockControl", "Main", "ProximityPrompt" } },
}

-- 泄压阀是同一个名字的多份实例，按位置编号收进来。
-- 整段必须 pcall：这里一旦抛错，加载阶段就中断，面板都建不出来（上次就是这么炸的）
do
    local okBlock, errBlock = pcall(function()
        local folder = FindByPath({ "FacilitySystems", "Controls", "ReliefValves" })
        if not folder then return end
        local valves = {}
        for _, d in ipairs(folder:GetDescendants()) do
            if d:IsA("ClickDetector") and d.Parent then
                valves[#valves + 1] = d
            end
        end
        table.sort(valves, function(a, b)
            local pa = InstPos(a.Parent)
            local pb = InstPos(b.Parent)
            if pa.X ~= pb.X then return pa.X < pb.X end
            return pa.Z < pb.Z
        end)
        for i, d in ipairs(valves) do
            ENTRIES[#ENTRIES + 1] = {
                g = "控制室", s = "泄压阀", name = "泄压阀 " .. i, kind = "click",
                find = function() return d end,
            }
        end
    end)
    if not okBlock then
        print("[NARAMO-RO] 泄压阀收集失败（不影响其它开关）: " .. tostring(errBlock))
    end
end

-- 稳定的 id（用于记住「上次」状态）
for i, e in ipairs(ENTRIES) do
    e.id = e.tree and table.concat(e.tree, "/") or ("dyn-" .. tostring(i))
end

-- ============================================================
-- 引擎：瞬移 → 同帧触发 → 收到信号立刻传回
-- ============================================================
local function FireOnce(obj, kind, cfg, settleMs)
    local char, hrp, hum = Char()
    if not hrp then error("没有角色", 0) end
    if hum and hum.Health <= 0 then error("角色已经死了", 0) end
    if hum and hum.Sit then error("正坐在载具/座位上，先按空格起身", 0) end

    local pos = WorldPos(obj)
    if not pos then error("取不到开关坐标", 0) end

    local reach = tonumber(obj.MaxActivationDistance) or 5
    local dist0 = (pos - hrp.Position).Magnitude
    local oldCF = hrp.CFrame
    local moved = false

    local function restore()
        if moved then
            pcall(function() hrp.CFrame = oldCF end)
            moved = false
        end
    end

    local okRun, resHits, resPull, resClick = pcall(function()
        -- 1) 不在交互距离内就瞬移过去（已经在的话不折腾）
        local d = (pos - hrp.Position).Magnitude
        if d > math.max(1, reach - 0.8) then
            local flat = Vector3.new(hrp.Position.X - pos.X, 0, hrp.Position.Z - pos.Z)
            if flat.Magnitude < 0.3 then flat = Vector3.new(1, 0, 0) end
            flat = flat.Unit
            local spot = pos + flat * cfg.off + Vector3.new(0, cfg.up, 0)
            hrp.CFrame = CFrame.lookAt(spot, pos)
            moved = true
        end

        -- 2) 可选等待（默认 0）：给服务器同步位置用的
        if settleMs and settleMs > 0 then
            task.wait(settleMs / 1000)
        end

        local atSpot = hrp.Position
        local hits = 0
        local conn = nil
        local clickInfo = nil

        -- 3) 触发（同步调用，越快越好）
        if kind == "prompt" then
            pcall(function()
                conn = obj.Triggered:Connect(function(plr)
                    if plr == LP then hits = hits + 1 end
                end)
            end)
            if type(fireproximityprompt) == "function" then
                pcall(fireproximityprompt, obj)
            else
                local oh, om = obj.HoldDuration, obj.MaxActivationDistance
                pcall(function()
                    if obj.HoldDuration ~= 0 then obj.HoldDuration = 0 end
                    if obj.MaxActivationDistance < 60 then obj.MaxActivationDistance = 60 end
                    obj:InputHoldBegin()
                    task.wait(0.05)
                    obj:InputHoldEnd()
                end)
                pcall(function() obj.HoldDuration, obj.MaxActivationDistance = oh, om end)
            end
        else
            -- 点击类和提示类不一样：fireclickdetector 是「发给服务器的点击」，
            -- 服务器按它自己同步到的位置验距离。瞬移完立刻点，服务器可能还认为你在原地，
            -- 所以这里先多等一会儿（clickSettle），再按「原生 → 本地连接 → 虚拟鼠标」依次尝试。
            local part = obj.Parent
            local beforeCF = nil
            pcall(function()
                if part and part:IsA("BasePart") then beforeCF = part.CFrame end
            end)

            local function partMoved()
                local changed = false
                pcall(function()
                    if beforeCF and part and part:IsA("BasePart") then
                        changed = (part.CFrame.Position - beforeCF.Position).Magnitude > 0.005
                    end
                end)
                return changed
            end

            if (cfg.clickSettle or 0) > 0 then
                task.wait(cfg.clickSettle / 1000)
            end

            local used = {}

            -- 策略 1：执行器原生
            if type(fireclickdetector) == "function" then
                pcall(fireclickdetector, obj)
                used[#used + 1] = "fireclickdetector"
                task.wait(0.12)
            end

            -- 策略 2：直接触发游戏自己的客户端连接（如果这个点击是客户端处理的）
            if not partMoved() and type(getconnections) == "function" then
                local okC, conns = pcall(getconnections, obj.MouseClick)
                if okC and type(conns) == "table" and #conns > 0 then
                    for _, c in ipairs(conns) do
                        pcall(function() c:Fire(LP) end)
                    end
                    used[#used + 1] = "本地连接x" .. tostring(#conns)
                    task.wait(0.12)
                end
            end

            -- 策略 3：真·虚拟鼠标点击（相机对准零件再点）
            if not partMoved() and part and part:IsA("BasePart") then
                local cam = workspace.CurrentCamera
                local okCam = false
                pcall(function()
                    local vp, onScreen = cam:WorldToViewportPoint(part.Position)
                    if not onScreen then
                        cam.CFrame = CFrame.lookAt(cam.CFrame.Position, part.Position)
                        task.wait(0.06)
                        vp, onScreen = cam:WorldToViewportPoint(part.Position)
                    end
                    if onScreen then
                        local vim = game:GetService("VirtualInputManager")
                        vim:SendMouseButtonEvent(math.floor(vp.X), math.floor(vp.Y), 0, true, game, 0)
                        vim:SendMouseButtonEvent(math.floor(vp.X), math.floor(vp.Y), 0, false, game, 0)
                        okCam = true
                    end
                end)
                if okCam then
                    used[#used + 1] = "虚拟鼠标"
                    task.wait(0.15)
                end
            end

            clickInfo = table.concat(used, " → ") .. (partMoved() and "（按钮有位移）" or "（按钮无位移）")
        end

        -- 4) 等信号（收到就立刻走，不等满）
        local waited = 0
        while waited < cfg.after and hits == 0 do
            task.wait(0.02)
            waited = waited + 20
        end
        if conn then pcall(function() conn:Disconnect() end) end

        -- 5) 被拉回检测：触发时人已经不在传送点附近了
        local pulled = ((hrp.Position - atSpot).Magnitude > 10)
        return hits, pulled, clickInfo
    end)

    restore()

    if not okRun then error(resHits, 0) end
    return resHits or 0, resPull or false, dist0, resClick
end

function RO_Fire(entry)
    if Busy then return false, "上一个动作还没结束" end
    local obj = Resolve(entry)
    if not obj then return false, "找不到这个开关（可能被改版/移走了）" end
    if not obj:IsA("ProximityPrompt") and not obj:IsA("ClickDetector") then
        return false, "目标类型不对（不是提示/点击器）"
    end

    Busy = true
    local t0 = os.clock()
    local attempts = 0
    local lastErr, hits, pulled, dist0 = nil, 0, false, 0
    local clickInfo = nil
    local maxAttempts = 1 + math.max(0, math.floor(CFG.retries))

    while attempts < maxAttempts do
        attempts = attempts + 1
        -- 首次用 CFG.settle；重试逐次加等待，给服务器位置同步留时间
        local settle = (attempts == 1) and CFG.settle or (CFG.settle + CFG.retryAdd * (attempts - 1))
        local ok, h, p, d, c = pcall(FireOnce, obj, entry.kind or "prompt", CFG, settle)
        if ok then
            hits, pulled, dist0, clickInfo = h, p, d or 0, c
            if hits > 0 or (entry.kind == "click") then break end
        else
            lastErr = h
            break
        end
    end

    Busy = false
    local ms = math.floor((os.clock() - t0) * 1000)

    if lastErr then
        return false, string.format("%s（%dms）", tostring(lastErr), ms)
    end

    if entry.kind == "click" then
        return true, string.format("%s · 已点击（%dms；%s）", entry.name, ms,
            tostring(clickInfo or "无反馈"))
    end

    if hits and hits > 0 then
        if entry.mem then
            MEM[entry.id] = not (MEM[entry.id] and true or false)
            SaveCfg()
        end
        local extra = pulled and " · 被拉回" or ""
        return true, string.format("%s · 成功（%dms，Triggered ×%d，距离 %.0f→%.0f%s）",
            entry.name, ms, hits, dist0, CFG.off, extra)
    end

    return false, string.format("%s · 没有回执（%dms，试了 %d 次）—— 可能被拉回/条件不满足",
        entry.name, ms, attempts)
end

-- ============================================================
-- UI（结构照主程序 NARAMO）
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NARAMO_RO_UI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PG

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 600, 0, 420)
MainFrame.Position = UDim2.new(0.5, -300, 0.5, -210)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 36)
TitleBar.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 8)

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1, -140, 1, 0)
TitleText.Position = UDim2.new(0, 12, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Text = "NARAMO-RO"
TitleText.TextColor3 = Color3.fromRGB(230, 230, 240)
TitleText.Font = Enum.Font.GothamBold
TitleText.TextSize = 16
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = TitleBar

local SubTitle = Instance.new("TextLabel")
SubTitle.Size = UDim2.new(0, 200, 1, 0)
SubTitle.Position = UDim2.new(0, 110, 0, 0)
SubTitle.BackgroundTransparency = 1
SubTitle.Text = "Reactor Operation · " .. VERSION
SubTitle.TextColor3 = Color3.fromRGB(120, 130, 150)
SubTitle.Font = Enum.Font.Code
SubTitle.TextSize = 10
SubTitle.TextXAlignment = Enum.TextXAlignment.Left
SubTitle.Parent = TitleBar

local MiniBtn = Instance.new("TextButton")
MiniBtn.Size = UDim2.new(0, 28, 0, 28)
MiniBtn.Position = UDim2.new(1, -66, 0, 4)
MiniBtn.BackgroundColor3 = Color3.fromRGB(70, 90, 120)
MiniBtn.BorderSizePixel = 0
MiniBtn.Text = "－"
MiniBtn.TextColor3 = Color3.new(1, 1, 1)
MiniBtn.Font = Enum.Font.GothamBold
MiniBtn.TextSize = 16
MiniBtn.Parent = TitleBar
Instance.new("UICorner", MiniBtn).CornerRadius = UDim.new(0, 6)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -34, 0, 4)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.new(1, 1, 1)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 18
CloseBtn.Parent = TitleBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 120, 1, -66)
Sidebar.Position = UDim2.new(0, 0, 0, 36)
Sidebar.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 8)
-- 侧栏按钮也是手算位置（见 MakePage），所以这里不要 UIListLayout / UIPadding，
-- 否则布局器会覆盖我们设的 Position

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -130, 1, -82)
ContentArea.Position = UDim2.new(0, 125, 0, 41)
ContentArea.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
ContentArea.BorderSizePixel = 0
ContentArea.Parent = MainFrame
Instance.new("UICorner", ContentArea).CornerRadius = UDim.new(0, 8)

-- 底部状态条：显示上一次操作结果
local StatusBar = Instance.new("TextLabel")
StatusBar.Size = UDim2.new(1, -130, 0, 30)
StatusBar.Position = UDim2.new(0, 125, 1, -36)
StatusBar.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
StatusBar.BorderSizePixel = 0
StatusBar.Text = "就绪 · 点任意一行 = 瞬移过去按一下再回来"
StatusBar.TextColor3 = Color3.fromRGB(160, 185, 215)
StatusBar.Font = Enum.Font.Code
StatusBar.TextSize = 10
StatusBar.TextXAlignment = Enum.TextXAlignment.Left
StatusBar.TextTruncate = Enum.TextTruncate.AtEnd
StatusBar.Parent = MainFrame
Instance.new("UICorner", StatusBar).CornerRadius = UDim.new(0, 6)
Instance.new("UIPadding", StatusBar).PaddingLeft = UDim.new(0, 8)

local function Status(text, ok)
    StatusBar.Text = tostring(text)
    if ok == true then
        StatusBar.TextColor3 = Color3.fromRGB(130, 220, 150)
    elseif ok == false then
        StatusBar.TextColor3 = Color3.fromRGB(235, 150, 140)
    else
        StatusBar.TextColor3 = Color3.fromRGB(160, 185, 215)
    end
    if CFG.verbose then
        print("[NARAMO-RO] " .. tostring(text))
    end
end

local currentPage = nil
local Pages = {}
local PAGE_BTNS = {}

-- 不再用 UIListLayout 排页面内容：位置全部手算。
-- 之前用 UIListLayout 时，分组标题会跑到最下面（排序规则不可控），手算就没有这个问题。
local PAGE_Y = {}
local ROW_GAP = 6
local PAD_TOP = 6

local function Place(parent, gui, height)
    local y = PAGE_Y[parent] or PAD_TOP
    gui.Position = UDim2.new(0, 8, 0, y)
    gui.Size = UDim2.new(1, -16, 0, height)
    gui.Parent = parent
    local nextY = y + height + ROW_GAP
    PAGE_Y[parent] = nextY
    parent.CanvasSize = UDim2.new(0, 0, 0, nextY + PAD_TOP)
    return gui
end

local function MakePage(name)
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.Visible = false
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.Parent = ContentArea
    PAGE_Y[page] = PAD_TOP

    local idx = #Pages + 1
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 35)
    btn.Position = UDim2.new(0, 5, 0, 10 + (idx - 1) * 39)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.Parent = Sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    btn.MouseButton1Click:Connect(function()
        for _, p in ipairs(Pages) do p.Visible = false end
        for _, b in ipairs(PAGE_BTNS) do b.BackgroundColor3 = Color3.fromRGB(40, 40, 50) end
        page.Visible = true
        btn.BackgroundColor3 = Color3.fromRGB(60, 90, 160)
    end)

    Pages[#Pages + 1] = page
    PAGE_BTNS[#PAGE_BTNS + 1] = btn
    if not currentPage then
        currentPage = page
        page.Visible = true
        btn.BackgroundColor3 = Color3.fromRGB(60, 90, 160)
    end
    return page
end

local function CreateSection(parent, text)
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Text = "  " .. text
    lbl.TextColor3 = Color3.fromRGB(120, 165, 225)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    Place(parent, lbl, 22)
    return lbl
end

local ROWS = {}

local function MakeRow(parent, entry)
    local frame = Instance.new("Frame")
    frame.BackgroundColor3 = Color3.fromRGB(38, 38, 48)
    frame.BorderSizePixel = 0
    Place(parent, frame, 36)
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(0, 196, 1, 0)
    nameLbl.Position = UDim2.new(0, 8, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = entry.name
    nameLbl.TextColor3 = Color3.fromRGB(225, 228, 235)
    nameLbl.Font = Enum.Font.Gotham
    nameLbl.TextSize = 12
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    nameLbl.Parent = frame

    local badge = Instance.new("TextLabel")
    badge.Size = UDim2.new(0, 54, 0, 20)
    badge.Position = UDim2.new(0, 208, 0, 8)
    badge.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    badge.BorderSizePixel = 0
    badge.Text = "…"
    badge.TextColor3 = Color3.fromRGB(180, 180, 190)
    badge.Font = Enum.Font.GothamBold
    badge.TextSize = 10
    badge.Parent = frame
    Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 4)

    local memBadge = Instance.new("TextLabel")
    memBadge.Size = UDim2.new(0, 86, 0, 20)
    memBadge.Position = UDim2.new(0, 266, 0, 8)
    memBadge.BackgroundTransparency = 1
    memBadge.Text = ""
    memBadge.TextColor3 = Color3.fromRGB(150, 170, 200)
    memBadge.Font = Enum.Font.Code
    memBadge.TextSize = 10
    memBadge.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 62, 0, 26)
    btn.Position = UDim2.new(1, -70, 0, 5)
    btn.BackgroundColor3 = Color3.fromRGB(50, 110, 70)
    btn.BorderSizePixel = 0
    btn.Text = "按"
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

    local row = { entry = entry, frame = frame }

    function row.Refresh()
        local obj = Resolve(entry)
        entry.obj = obj

        if not obj then
            badge.Text = "缺失"
            badge.TextColor3 = Color3.fromRGB(235, 160, 120)
            memBadge.Text = ""
            btn.BackgroundColor3 = Color3.fromRGB(55, 55, 62)
            btn.Text = "—"
            row.dead = true
            return
        end
        row.dead = false
        btn.Text = "按"

        if entry.rod and RODSTATE.pct then
            -- 控制棒：按真实行程显示，不再说「可用/禁用」
            local pct = RODSTATE.pct
            badge.Text = string.format("棒位 %d%%", math.floor(pct * 100 + 0.5))
            if pct >= 0.98 then
                badge.TextColor3 = Color3.fromRGB(150, 215, 170)   -- 已提到顶
            elseif pct <= 0.02 then
                badge.TextColor3 = Color3.fromRGB(200, 200, 210)   -- 已落到底
            else
                badge.TextColor3 = Color3.fromRGB(235, 200, 120)   -- 行程中
            end
            btn.BackgroundColor3 = Color3.fromRGB(50, 110, 70)
        elseif entry.kind == "click" then
            badge.Text = "可点"
            badge.TextColor3 = Color3.fromRGB(150, 215, 170)
            btn.BackgroundColor3 = Color3.fromRGB(50, 110, 70)
        else
            local enabled = false
            pcall(function() enabled = obj.Enabled end)
            if enabled then
                -- 注意：这只代表「提示是启用的」，不代表动作一定有效
                -- （控制棒到顶后按钮还在、Enabled 还是 true，按了没反应）
                badge.Text = "启用"
                badge.TextColor3 = Color3.fromRGB(160, 190, 220)
                btn.BackgroundColor3 = Color3.fromRGB(50, 110, 70)
            else
                badge.Text = "禁用"
                badge.TextColor3 = Color3.fromRGB(235, 150, 140)
                btn.BackgroundColor3 = Color3.fromRGB(90, 60, 60)
            end
        end

        if entry.mem then
            local v = MEM[entry.id]
            if v == nil then
                memBadge.Text = "上次: —"
            else
                memBadge.Text = "上次: " .. (v and "开" or "关")
            end
        else
            memBadge.Text = ""
        end
    end

    btn.MouseButton1Click:Connect(function()
        if IsClosing then return end
        if Busy then
            Status("上一个动作还没结束", false)
            return
        end
        local obj = Resolve(entry)
        if not obj then
            Status(entry.name .. " · 找不到目标（重新进游戏或改版了）", false)
            row.Refresh()
            return
        end
        entry.obj = obj
        Status(entry.name .. " · 执行中…")
        local ok, msg = RO_Fire(entry)
        Status(msg, ok)
        row.Refresh()
    end)

    ROWS[#ROWS + 1] = row
    row.Refresh()
    return row
end

-- ============================================================
-- 页面：说明（第一个分区）
-- MakePage 的调用顺序决定侧栏顺序，也决定面板打开时默认停在哪一页，
-- 所以「说明」要先建，内容后面再填（见文件末尾附近）。
-- ============================================================
local AboutPage = MakePage("说明")

-- ============================================================
-- 页面：控制室 / 设施入口
-- ============================================================
local function BuildSwitchPage(pageName, group)
    local page = MakePage(pageName)
    local lastSub = nil
    for _, e in ipairs(ENTRIES) do
        if e.g == group then
            if e.s ~= lastSub then
                CreateSection(page, e.s)
                lastSub = e.s
            end
            MakeRow(page, e)
        end
    end
    return page
end

-- 页面构建也包一层：某个开关的目标结构变了，最多是那一页少几行，不至于整个脚本挂掉
local okC, errC = pcall(BuildSwitchPage, "控制室", "控制室")
if not okC then print("[NARAMO-RO] 控制室页面构建失败: " .. tostring(errC)) end
local okF, errF = pcall(BuildSwitchPage, "设施入口", "设施入口")
if not okF then print("[NARAMO-RO] 设施入口页面构建失败: " .. tostring(errF)) end

-- ============================================================
-- 页面：设施概况（反应堆温度 / 棒位 / 自动发现的部件数值）
-- 数值位置没法写死：不同版本把温度挂在属性、ValueBase 或文件夹里都有可能，
-- 所以这里用「关键词自动发现 + 诊断打印」：找到就显示，找不到就告诉你去哪看。
-- ============================================================
local OverviewPage = MakePage("设施概况")
local PanelsPage = MakePage("所有警报")
local INFO_ROWS = {}

-- 两个页面共用 INFO_ROWS，重建某一页时只能删自己那几行，不能整表清空
local BuildPanels = nil      -- 前置声明：BuildOverview 里要调用它（定义在后面）

local function ClearPageRows(page)
    for i = #INFO_ROWS, 1, -1 do
        if INFO_ROWS[i].page == page then
            table.remove(INFO_ROWS, i)
        end
    end
end

-- ============================================================
-- 全量扫描：把游戏能读到的「数值 / 布尔状态 / 面板文字」都抓出来
-- 用途：游戏里的概览和警报是中文机翻的，脚本必须先看到内部英文名，才能做中文映射
-- ============================================================
local SCAN = { values = {}, bools = {}, texts = {} }

local function ScanEverything()
    SCAN.values, SCAN.bools, SCAN.texts = {}, {}, {}

    local rs = game:GetService("ReplicatedStorage")
    local ok, desc = pcall(function() return rs:GetDescendants() end)
    if ok and desc then
        for _, d in ipairs(desc) do
            if d:IsA("ValueBase") then
                local item = { inst = d, name = d.Name, path = PathOf(d), kind = "value" }
                SCAN.values[#SCAN.values + 1] = item
                if d:IsA("BoolValue") then
                    SCAN.bools[#SCAN.bools + 1] = item
                end
            end
        end
    end
    table.sort(SCAN.values, function(a, b) return a.path < b.path end)
    table.sort(SCAN.bools, function(a, b) return a.path < b.path end)

    -- FacilitySystems 下所有 SurfaceGui 里的文字：游戏面板上的读数就在这
    local fs = workspace:FindFirstChild("FacilitySystems")
    if fs then
        local ok2, desc2 = pcall(function() return fs:GetDescendants() end)
        if ok2 and desc2 then
            for _, d in ipairs(desc2) do
                if #SCAN.texts >= 600 then break end
                if d:IsA("TextLabel") and tostring(d.Text) ~= "" then
                    SCAN.texts[#SCAN.texts + 1] = { inst = d, path = PathOf(d) }
                end
            end
        end
    end

    print(string.format("[NARAMO-RO] 全量扫描：数值 %d / 布尔 %d / 面板文字 %d",
        #SCAN.values, #SCAN.bools, #SCAN.texts))
end

-- ============================================================
-- 设备面板镜像
-- 游戏里的概览全在 ControlPanels 下的 SurfaceGui 里：
--   标签零件  .../Text/SurfaceGui/TextLabel = "REACTOR TEMP (K)"
--   数值零件  .../Part/SurfaceGui/TextLabel = "2191.6 K"
-- 两者是面板上相邻的两个零件，所以用「三维距离最近」配对；
-- 同一块面板有多张贴面（正反面），文字会重复，配对后按标签去重。
-- ============================================================
local PANEL = { groups = {} }
local VALUE_WORDS = { "OPEN", "CLOSED", "CLOSE", "SYNCED", "EXTERNAL", "PRIMARY",
                      "ACTIVE", "ON", "OFF", "NO SIGNAL", "RUNNING", "TRIPPED", "FAULT", "N/A" }

local function LooksLikeValue(t)
    t = tostring(t or "")
    if t == "" then return false end
    if string.match(t, "^[%-%d]") then return true end
    local up = string.upper(t)
    for _, w in ipairs(VALUE_WORDS) do
        if up == w then return true end
    end
    return false
end

local function CollectPanelTexts()
    local root = FindByPath({ "FacilitySystems", "ControlPanels" })
    if not root then return {} end

    local items, seen = {}, {}
    local ok, desc = pcall(function() return root:GetDescendants() end)
    if not ok or not desc then return items end

    for _, d in ipairs(desc) do
        if d:IsA("SurfaceGui") then
            local part = d.Parent
            if part and part:IsA("BasePart") and not seen[part] then
                seen[part] = true
                for _, lbl in ipairs(d:GetChildren()) do
                    if lbl:IsA("TextLabel") and tostring(lbl.Text) ~= "" then
                        items[#items + 1] = {
                            part = part,
                            lbl = lbl,
                            text = tostring(lbl.Text),
                            model = part:FindFirstAncestorOfClass("Model") or root,
                        }
                        break
                    end
                end
            end
        end
    end
    return items
end

local function BuildPanelRows(items)
    local byModel = {}
    for _, it in ipairs(items) do
        local key = it.model
        byModel[key] = byModel[key] or {}
        table.insert(byModel[key], it)
    end

    local groups = {}
    for model, list in pairs(byModel) do
        local labels, values = {}, {}
        for _, it in ipairs(list) do
            if LooksLikeValue(it.text) then
                values[#values + 1] = it
            else
                labels[#labels + 1] = it
            end
        end

        local rows, used = {}, {}
        for _, v in ipairs(values) do
            local best, bestD = nil, math.huge
            for _, l in ipairs(labels) do
                local d = (l.part.Position - v.part.Position).Magnitude
                if d < bestD then best, bestD = l, d end
            end
            if best and bestD <= 8 and not used[best.text] then
                used[best.text] = true
                rows[#rows + 1] = {
                    label = best.text,
                    valLbl = v.lbl,
                    y = v.part.Position.Y,
                    x = v.part.Position.X,
                }
            end
        end

        if #rows > 0 then
            table.sort(rows, function(a, b)
                if math.abs(a.y - b.y) > 0.6 then return a.y > b.y end
                return a.x < b.x
            end)
            groups[#groups + 1] = { name = model.Name, rows = rows }
        end
    end

    table.sort(groups, function(a, b) return a.name < b.name end)
    return groups
end

local function ScanPanels()
    PANEL.groups = BuildPanelRows(CollectPanelTexts())
    local total = 0
    for _, g in ipairs(PANEL.groups) do total = total + #g.rows end
    print(string.format("[NARAMO-RO] 面板读数：%d 块，%d 条", #PANEL.groups, total))
end

-- ============================================================
-- 警报屏：Annunciators 下每块屏的告警文字（亮/暗靠文字颜色和透明度判断）
-- ============================================================
local ALARMS = { items = {}, snap = nil }

-- 颜色转 #RRGGBB，方便在诊断里对比
local function Hex(c)
    local ok, s = pcall(function()
        return string.format("#%02X%02X%02X",
            math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
    end)
    return ok and s or "?"
end

-- 一条警报当前的所有「可能表示状态」的属性
local function AlarmSig(item)
    local sig = {}
    local lbl = item.inst
    local function add(k, v) sig[k] = tostring(v) end

    pcall(function()
        add("text", lbl.Text)
        add("color", Hex(lbl.TextColor3))
        add("transp", string.format("%.2f", lbl.TextTransparency))
        add("visible", lbl.Visible)
        local part = lbl:FindFirstAncestorWhichIsA("BasePart")
        if part then
            add("part.color", Hex(part.Color))
            add("part.transp", string.format("%.2f", part.Transparency))
            add("part.mat", tostring(part.Material))
            local okA, attrs = pcall(function() return part:GetAttributes() end)
            if okA and attrs then
                for k, v in pairs(attrs) do add("attr." .. tostring(k), v) end
            end
        end
        for _, d in ipairs(lbl:GetDescendants()) do
            if d:IsA("Light") then add("light", d.Enabled) end
        end
    end)
    return sig
end

local function SnapshotAlarms()
    ALARMS.snap = {}
    for _, a in ipairs(ALARMS.items) do
        ALARMS.snap[a] = AlarmSig(a)
    end
    Status(string.format("已记录 %d 条警报当前状态。去触发/解除一个警报，再按「对比」", #ALARMS.items), true)
end

local function DiffAlarms()
    if not ALARMS.snap then
        Status("先按「记录警报基线」", false)
        return
    end
    local lines = {}
    for _, a in ipairs(ALARMS.items) do
        local before = ALARMS.snap[a]
        if before then
            local now = AlarmSig(a)
            for k, v in pairs(now) do
                if before[k] ~= v then
                    lines[#lines + 1] = string.format("%s · %s : %s → %s   [%s]",
                        a.panel, a.text, tostring(before[k]), tostring(v), k)
                end
            end
        end
    end

    local text = "NARAMO-RO 警报对比  " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
        .. "基线记录于本次点击「记录」时；下面是所有变化\n\n"
        .. table.concat(lines, "\n")
    if #lines == 0 then text = text .. "（没有任何变化——说明我记录的这些属性都不是状态位）" end

    if EnsureFolder() and type(writefile) == "function" then
        pcall(writefile, FOLDER .. "/alarm_diff.txt", text)
    end
    if type(setclipboard) == "function" then
        pcall(setclipboard, text)
    end
    print(text)
    Status(string.format("对比完成：%d 处变化，已写到 NARAMO_RO/alarm_diff.txt", #lines), true)
end

local function ScanAlarms()
    ALARMS.items = {}
    local root = FindByPath({ "FacilitySystems", "Annunciators" })
    if not root then return end

    local ok, desc = pcall(function() return root:GetDescendants() end)
    if not ok or not desc then return end

    -- 结构 dump 确认：同一条警报在面板上有两个零件 ——
    --   背板：Material=SmoothPlastic，永远 Tr=0，只负责显示文字
    --   灯　：Material=Neon，亮的时候 Tr=0，灭的时候 Tr=1
    -- 所以必须认 Neon 那个；认背板就会「全部都是触发」。
    local best = {}
    for _, d in ipairs(desc) do
        if d:IsA("TextLabel") and tostring(d.Text) ~= "" then
            local part = d:FindFirstAncestorWhichIsA("BasePart")
            if part then
                local anchor = part
                while anchor and anchor.Parent and anchor.Parent ~= root do
                    anchor = anchor.Parent
                end
                local isInPanel = (anchor and anchor.Parent == root)
                local panelName = isInPanel and anchor.Name or "Annunciators"
                local panelKey = isInPanel and PathOf(anchor) or "Annunciators"
                local isNeon = (part.Material == Enum.Material.Neon)
                local key = panelKey .. "|" .. string.lower(tostring(d.Text))
                local rec = best[key]
                -- 同一个 key 下优先保留 Neon 灯
                if not rec or (isNeon and not rec.isNeon) then
                    best[key] = {
                        inst = d, part = part, isNeon = isNeon,
                        text = tostring(d.Text), panel = panelName, panelKey = panelKey,
                    }
                end
            end
        end
    end

    for _, r in pairs(best) do
        ALARMS.items[#ALARMS.items + 1] = r
    end

    table.sort(ALARMS.items, function(a, b)
        if a.panel ~= b.panel then return a.panel < b.panel end
        return a.text < b.text
    end)

    local neonCount = 0
    for _, a in ipairs(ALARMS.items) do
        if a.isNeon then neonCount = neonCount + 1 end
    end
    print(string.format("[NARAMO-RO] 警报：%d 条（其中 %d 条找到霓虹灯）", #ALARMS.items, neonCount))
end

-- ============================================================
-- 面板小分区名 / 行标签 / 状态值的中文对照
-- 游戏面板上的标题都是英文，这里统一翻成中文；查不到就原样显示
-- ============================================================
local PANEL_GROUP_ZH = {
    ["TurbinePanel"] = "涡轮机面板",
    ["CoolantPumps"] = "冷却剂泵",
    ["Generators"] = "发电机",
    ["GridOps"] = "电网操作台",
    ["ReactorMainPanels"] = "反应堆主面板",
    ["EmergencySystems"] = "应急系统",
    ["ShiftManager"] = "换挡 / 班次",
    ["PumpBetaStatus"] = "冷却剂泵 Beta 状态",
    ["PumpAlphaStatus"] = "冷却剂泵 Alpha 状态",
    ["AnnunciatorPanelTurbines"] = "警报屏 · 涡轮机",
    ["AnnunciatorPanelPower"] = "警报屏 · 电源",
    ["AnnunciatorPanelCoolant"] = "警报屏 · 冷却液",
    ["AnnunciatorPanelReactor"] = "警报屏 · 反应堆",
    ["AnnunciatorPanelGeneratorRoom"] = "警报屏 · 发电机房",
    ["AnnunciatorPanelComputer"] = "警报屏 · 计算机",
}

local function NormLabel(t)
    local s = string.upper(tostring(t or ""))
    s = string.gsub(s, "%s+", " ")
    return s
end

local function PanelGroupZh(name)
    return PANEL_GROUP_ZH[tostring(name or "")] or tostring(name or "")
end

local PANEL_LABEL_ZH = {
    ["REACTOR TEMP (K)"] = "反应堆温度 (K)",
    ["REACTOR WATER LEVEL"] = "反应堆水位",
    ["FEEDWATER FLOW (㎥/S)"] = "供水流量 (m³/s)",
    ["FEEDWATER FLOW (M³/S)"] = "供水流量 (m³/s)",
    ["FEEDWATER FLOW"] = "供水流量",
    ["FEEDWATER OVERVIEW"] = "给水概览",
    ["FEEDWATER PUMP 1"] = "给水泵 1",
    ["FEEDWATER PUMP 2"] = "给水泵 2",
    ["UTILIZATION"] = "利用率",
    ["RPM"] = "转速",
    ["FLOW (㎥/S)"] = "流量 (m³/s)",
    ["FLOW (M³/S)"] = "流量 (m³/s)",
    ["FLOW"] = "流量",
    ["TURB. OUTPUT (KW)"] = "涡轮输出功率 (kW)",
    ["DEMAND (KW)"] = "需求量 (kW)",
    ["SUPPLY (KW)"] = "供应量 (kW)",
    ["SUPPLIED BY"] = "供应方",
    ["OUTPUT (KW)"] = "输出功率 (kW)",
    ["POWER PRODUCTION (KW)"] = "发电功率 (kW)",
    ["GEN. OUTPUT (KW)"] = "发电机输出 (kW)",
    ["GEN 1-3 FUEL (%)"] = "GEN 1-3 燃料 (%)",
    ["CURRENT GRID"] = "当前电网",
    ["COOLANT VALVES"] = "冷却液阀门",
    ["COOLANT OVERVIEW"] = "冷却液概览",
    ["RELIEF VALVE STATUS"] = "减压泵状态",
    ["RELIEF VALVE OVERVIEW"] = "减压泵概览",
    ["ORDERS COMPLETE"] = "订单已完成",
    ["SHIFT TIER"] = "技能等级",
    ["SHIFT OVERVIEW"] = "换挡概览",
    ["TURBINE RPM"] = "涡轮转速",
    ["VIBRATION"] = "震动",
    ["VALVES (%)"] = "阀门 (%)",
    ["FLOW RATE (M³/S)"] = "流量 (m³/s)",
    ["FLOW RATE (㎥/S)"] = "流量 (m³/s)",
    ["STATUS"] = "状态",
    ["FACILITY OVERVIEW"] = "设施概览",
    ["ROD INSERTION"] = "控制棒插入深度",
    ["GRID OVERVIEW"] = "电网概览",
    ["GRID OVERVIEW (PRIMARY)"] = "电网概览（主）",
    ["GRID OVERVIEW (AUX)"] = "电网概览（辅）",
    ["BUS OVERVIEW (PRIMARY)"] = "母线概览（主）",
    ["BUS OVERVIEW (AUX)"] = "母线概览（辅）",
    ["EXTERNAL"] = "外部",
    ["PRIMARY"] = "主",
    ["AUX"] = "辅",
}

local PANEL_VALUE_ZH = {
    ["EXTERNAL"] = "外部供电",
    ["PRIMARY"] = "主",
    ["AUX"] = "辅",
    ["SYNCED"] = "已同步",
    ["UNSYNCED"] = "未同步",
    ["OPEN"] = "打开",
    ["CLOSED"] = "关闭",
    ["NO SIGNAL"] = "无信号",
    ["ACTIVE"] = "运行中",
    ["ON"] = "开",
    ["OFF"] = "关",
}

local function PanelZh(text)
    return PANEL_LABEL_ZH[NormLabel(text)] or tostring(text)
end

local function ValueZh(text)
    return PANEL_VALUE_ZH[NormLabel(text)] or tostring(text)
end

local function AlarmIsLit(lbl)
    local ok, lit = pcall(function()
        if lbl.TextTransparency and lbl.TextTransparency > 0.55 then return false end
        local c = lbl.TextColor3
        local lum = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
        return lum > 0.45
    end)
    return ok and lit
end

-- 警报中英对照：游戏里警报名是英文，这里按「实测对比」+ 你给的清单映射成中文。
-- 带编号的用 # 占位，例如 "TURBINE # UNDERSPEED" → 涡轮机#转速过低
local ALARM_ZH = {
    -- 涡轮机
    ["TURBINE # RUNNING"] = "涡轮机#正在运行",
    ["TURBINE # SYNCED"] = "涡轮机#已同步",
    ["TURBINE # FAULT"] = "涡轮机#发生故障",
    ["TURBINE # TRIP"] = "涡轮机#跳闸",
    ["TURBINE # OVERSPEED"] = "涡轮机#超速运行",
    ["TURBINE # UNDERSPEED"] = "涡轮机#转速过低",
    ["TURBINE # HIGH VIBRATION"] = "涡轮机#振动较高",
    ["TURBINE # VIBRATION CRITICAL"] = "涡轮机#震动暴击",
    ["TURBINES UNSYNCED"] = "涡轮机不同步",
    -- 电源
    ["PRIMARY POWER LOW"] = "主电源不足",
    ["AUX POWER LOW"] = "辅助电源不足",
    ["AUXILIARY POWER LOW"] = "辅助电源不足",
    ["DC POWER LOW"] = "直流电源不足",
    ["GEN # RUNNING"] = "第#代设备运行中",
    ["GEN # FAULT"] = "第#代设备故障",
    ["GENERATOR # RUNNING"] = "第#代设备运行中",
    ["GENERATOR # FAULT"] = "第#代设备故障",
    ["GRID AWAITING HANDOVER"] = "电网正在等待交接",
    -- 冷却液
    ["COOLANT VALVE OPEN"] = "冷却液阀门打开",
    ["COOLANT VALVE CLOSED"] = "冷却液阀门已关闭",
    ["COOLANT PUMP # RUNUP"] = "冷却液泵#启动",
    ["COOLANT PUMP # RUNNING"] = "冷却液泵#正在运行",
    ["COOLANT PUMP # OFF"] = "冷却泵#关闭",
    ["FEED PUMP # CAVITATION"] = "进料泵#发生气蚀",
    ["FEED PUMP # FAULT"] = "给料泵#发生故障",
    ["FEED PUMP FLOW LOW"] = "给料泵流量过低",
    ["FEEDWATER VALVE OPEN"] = "给水阀门打开",
    ["FEEDWATER VALVE CLOSED"] = "给水阀门已关闭",
    -- 反应堆
    ["REACTOR OFFLINE"] = "反应堆已停用",
    ["REACTOR ONLINE"] = "反应堆已上线",
    ["REACTOR SCRAM"] = "反应堆紧急停堆",
    ["REACTOR TEMP LOW"] = "反应堆温度过低",
    ["REACTOR TEMP HIGH"] = "反应堆温度过高",
    ["REACTOR TEMPERATURE LOW"] = "反应堆温度过低",
    ["REACTOR TEMPERATURE HIGH"] = "反应堆温度过高",
    ["ROD INSERTION LOW"] = "控制棒插入深度较低",
    ["REACTOR PRESSURE LOW"] = "反应堆压力过低",
    ["REACTOR PRESSURE HIGH"] = "高反应堆压力",
    ["RELIEF PUMP ACTIVE"] = "减压泵已激活",
    ["WATER LEVEL LOW"] = "水位较低",
    ["FUEL EFFICIENCY LOW"] = "反应堆燃料效率低",
    ["FUEL LOW"] = "反应堆燃料不足",
}

local function AlarmZh(text)
    local up = string.upper(tostring(text or "")):gsub("%s+", " ")
    local exact = ALARM_ZH[up]
    if exact then return exact end
    local n = string.match(up, "(%d)")
    if n then
        local key = string.gsub(up, "%d", "#")
        local fmt = ALARM_ZH[key]
        if fmt then return (string.gsub(fmt, "#", n)) end
    end
    return text
end

-- 实测：警报灯 = 标签所在零件，Transparency 0 = 亮，0.83/1.0 = 暗
local function AlarmTransp(item)
    local ok, t = pcall(function()
        local part = item.part or item.inst:FindFirstAncestorWhichIsA("BasePart")
        if part then return part.Transparency end
        return nil
    end)
    return ok and t or nil
end

local function AlarmLit(item)
    local t = AlarmTransp(item)
    if not t then return false end
    return t < 0.5
end

-- 警报屏结构树：状态位靠猜不准时，看这个就知道灯到底是什么东西
local function AlarmTreeText()
    local root = FindByPath({ "FacilitySystems", "Annunciators" })
    if not root then return "（没有 Annunciators）" end

    local out, n = {}, 0
    for _, d in ipairs(root:GetDescendants()) do
        n = n + 1
        if n > 120 then break end
        local extra = ""
        pcall(function()
            if d:IsA("BasePart") then
                extra = string.format(" Color=%s Tr=%.2f Mat=%s",
                    Hex(d.Color), d.Transparency, tostring(d.Material))
            elseif d:IsA("TextLabel") then
                extra = string.format(" Text=%q Color=%s Tr=%.2f Vis=%s",
                    tostring(d.Text), Hex(d.TextColor3), d.TextTransparency, tostring(d.Visible))
            elseif d:IsA("Light") then
                extra = " Enabled=" .. tostring(d.Enabled)
            end
        end)
        out[#out + 1] = string.format("  %s <%s>%s", PathOf(d), d.ClassName, extra)
    end
    return table.concat(out, "\n")
end

local function MakeInfoRow(page, label, getter, width, colorFn)
    local frame = Instance.new("Frame")
    frame.BackgroundColor3 = Color3.fromRGB(38, 38, 48)
    frame.BorderSizePixel = 0
    Place(page, frame, 26)
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(0, width or 190, 1, 0)
    nameLbl.Position = UDim2.new(0, 8, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = label
    nameLbl.TextColor3 = Color3.fromRGB(205, 212, 225)
    nameLbl.Font = Enum.Font.Gotham
    nameLbl.TextSize = 11
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    nameLbl.Parent = frame

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(1, -((width or 190) + 20), 1, 0)
    valLbl.Position = UDim2.new(0, (width or 190) + 12, 0, 0)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = "…"
    valLbl.TextColor3 = Color3.fromRGB(150, 215, 170)
    valLbl.Font = Enum.Font.Code
    valLbl.TextSize = 11
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.TextTruncate = Enum.TextTruncate.AtEnd
    valLbl.Parent = frame

    local row = { val = valLbl, getter = getter, page = page, color = colorFn }
    INFO_ROWS[#INFO_ROWS + 1] = row
    pcall(function()
        valLbl.Text = getter()
        if colorFn then valLbl.TextColor3 = colorFn() end
    end)
    return row
end

local function OverviewButton(page, text, color, fn)
    local btn = Instance.new("TextButton")
    btn.BackgroundColor3 = color or Color3.fromRGB(46, 52, 66)
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(230, 235, 245)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    Place(page, btn, 30)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    btn.MouseButton1Click:Connect(function()
        local ok, err = pcall(fn)
        if not ok then Status("概况操作失败：" .. tostring(err), false) end
    end)
    return btn
end

-- 温度类数值：优先名字里有 temp/heat/thermal 的
local function FindTempItem()
    for _, it in ipairs(TELE.items) do
        if TeleScore(it.name) >= 3 then return it end
    end
    return nil
end

-- 诊断文本：控制台、文件、剪贴板三个地方都能拿到（控制台多数执行器复制不了）
local function BuildDiagText()
    local out = {}
    local function W(s) out[#out + 1] = tostring(s) end

    W("NARAMO-RO 遥测诊断  " .. os.date("%Y-%m-%d %H:%M:%S"))
    W("PlaceId: " .. tostring(game.PlaceId))
    W("玩家人数: " .. tostring(#game:GetService("Players"):GetPlayers()))
    W("候选数值: " .. tostring(#TELE.items))
    W("")

    for i, it in ipairs(TELE.items) do
        if i > 200 then break end
        W(string.format("[%03d] %-44s = %-20s %s",
            i, it.name, tostring(TeleValueText(it)), it.path))
    end

    W("")
    W("---- ReplicatedStorage 顶层 ----")
    local rs = game:GetService("ReplicatedStorage")
    local n = 0
    for _, c in ipairs(rs:GetChildren()) do
        n = n + 1
        if n > 80 then break end
        W(string.format("  %-30s %s", c.Name, c.ClassName))
    end

    W("")
    W("---- ReactorMetrics（" .. tostring(#METRICS.items) .. " 个）----")
    for i, m in ipairs(METRICS.items) do
        if i > 60 then break end
        W(string.format("  [%02d] %-32s = %-18s  %s",
            i, m.name, tostring(TeleValueText(m)), m.path))
    end

    W("")
    W("---- 设备面板（" .. tostring(#PANEL.groups) .. " 块）----")
    for _, g in ipairs(PANEL.groups) do
        W("  [" .. tostring(g.name) .. "]")
        for i, r in ipairs(g.rows) do
            if i > 40 then break end
            local txt = "?"
            pcall(function() txt = tostring(r.valLbl.Text) end)
            W(string.format("    %-34s = %s", r.label, txt))
        end
    end

    W("")
    W("---- 警报屏（" .. tostring(#ALARMS.items) .. " 条）----")
    for i, a in ipairs(ALARMS.items) do
        if i > 200 then break end
        local tr = AlarmTransp(a)
        local short = string.match(a.panelKey or "", "([^/]+)$") or a.panel
        W(string.format("  [%03d] %-26s %-36s %-22s mat=%-14s tr=%s %s",
            i, short, a.text, tostring(AlarmZh(a.text)),
            a.part and tostring(a.part.Material) or "?",
            tr and string.format("%.2f", tr) or "?",
            (not a.isNeon) and "（未找到灯）" or (AlarmLit(a) and "亮" or "灭")))
    end

    W("")
    W("---- 警报屏结构（前 120 个节点）----")
    W(AlarmTreeText())

    W("")
    W("---- 布尔状态（" .. tostring(#SCAN.bools) .. " 个）----")
    for i, b in ipairs(SCAN.bools) do
        if i > 80 then break end
        local ok, v = pcall(function() return b.inst.Value end)
        W(string.format("  [%02d] %-44s = %-6s %s", i, b.name, tostring(ok and v or "?"), b.path))
    end

    W("")
    W("---- 全部数值（" .. tostring(#SCAN.values) .. " 个）----")
    local vn = 0
    for _, v in ipairs(SCAN.values) do
        if vn >= 220 then break end
        if not v.inst:IsA("BoolValue") then
            vn = vn + 1
            W(string.format("  [%03d] %-44s = %-20s %s", vn, v.name, tostring(TeleValueText(v)), v.path))
        end
    end

    W("")
    W("---- 面板文字（" .. tostring(#SCAN.texts) .. " 个）----")
    for i, t in ipairs(SCAN.texts) do
        if i > 160 then break end
        local txt = "?"
        pcall(function() txt = tostring(t.inst.Text) end)
        W(string.format("  [%03d] %-58s = %s", i, t.path, txt))
    end

    W("")
    W("---- 名字带 rod 的零件（" .. tostring(#RODPARTS.list) .. " 个）----")
    for i, p in ipairs(RODPARTS.list) do
        if i > 40 then break end
        pcall(function()
            W(string.format("  [%02d] %-56s (%.1f, %.1f, %.1f)",
                i, PathOf(p), p.Position.X, p.Position.Y, p.Position.Z))
        end)
    end

    W("")
    W("---- 控制棒跟踪 ----")
    local tracked = 0
    for _ in pairs(RODTRACK.map) do tracked = tracked + 1 end
    W(string.format("  已跟踪零件 %d 个，最大位移 %.2f 格", tracked, RODTRACK.bestRange))
    if RODTRACK.best then
        W("  当前最好的尺子: " .. tostring(RODTRACK.best.path))
        W(string.format("    当前 (%.2f, %.2f, %.2f)", RODTRACK.best.part.Position.X,
            RODTRACK.best.part.Position.Y, RODTRACK.best.part.Position.Z))
        W(string.format("    min (%.2f, %.2f, %.2f)", RODTRACK.best.min.X,
            RODTRACK.best.min.Y, RODTRACK.best.min.Z))
        W(string.format("    max (%.2f, %.2f, %.2f)", RODTRACK.best.max.X,
            RODTRACK.best.max.Y, RODTRACK.best.max.Z))
    end

    -- 位移最大的前 10 个零件：棒位测不出来时，这里能看出到底哪个零件在动
    local recs = {}
    for _, rec in pairs(RODTRACK.map) do
        recs[#recs + 1] = rec
    end
    table.sort(recs, function(a, b)
        return (a.max - a.min).Magnitude > (b.max - b.min).Magnitude
    end)
    W("  位移 Top10:")
    for i = 1, math.min(#recs, 10) do
        local r = recs[i]
        W(string.format("    [%02d] %6.2f 格  %s", i, (r.max - r.min).Magnitude,
            tostring(r.path or PathOf(r.part))))
    end

    return table.concat(out, "\n")
end

local function DumpTelemetry()
    local text = BuildDiagText()
    local wrote, copied = false, false

    if EnsureFolder() and type(writefile) == "function" then
        wrote = pcall(writefile, FOLDER .. "/diag.txt", text)
        pcall(writefile, FOLDER .. "/diag_" .. os.date("%Y%m%d_%H%M%S") .. ".txt", text)
    end
    if type(setclipboard) == "function" then
        copied = pcall(setclipboard, text)
    end

    print(text)

    if wrote then
        Status("诊断已写到 " .. FOLDER .. "/diag.txt" .. (copied and "，也复制到剪贴板了" or ""), true)
    elseif copied then
        Status("诊断已复制到剪贴板（文件写入失败）", true)
    else
        Status("写文件/剪贴板都失败，控制台里有一份", false)
    end
end

local function BuildOverview()
    for _, ch in ipairs(OverviewPage:GetChildren()) do
        pcall(function() ch:Destroy() end)
    end
    ClearPageRows(OverviewPage)
    PAGE_Y[OverviewPage] = PAD_TOP
    OverviewPage.CanvasSize = UDim2.new(0, 0, 0, 0)

    CreateSection(OverviewPage, "反应堆")
    MakeInfoRow(OverviewPage, "温度", function()
        -- 1) 面板上如果有 REACTOR TEMP，直接镜像面板文字（和游戏显示的完全一致）
        for _, g in ipairs(PANEL.groups) do
            for _, r in ipairs(g.rows) do
                if string.find(string.upper(r.label), "TEMP", 1, true) then
                    local ok, t = pcall(function() return r.valLbl.Text end)
                    if ok and tostring(t) ~= "" then return tostring(t) end
                end
            end
        end
        -- 2) 否则读 ReactorMetrics/Temperature（诊断实测：内部值 = 面板显示值，单位 K）
        local raw = nil
        for _, m in ipairs(METRICS.items) do
            if string.find(string.lower(m.name), "temp", 1, true) then
                raw = ItemNumber(m)
                if raw then break end
            end
        end
        if not raw then
            local it = FindTempItem()
            if it then raw = ItemNumber(it) end
        end
        if not raw then return "未找到" end
        return string.format("%.1f K", raw)
    end, 150)
    MakeInfoRow(OverviewPage, "温度来源", function()
        for _, m in ipairs(METRICS.items) do
            if string.find(string.lower(m.name), "temp", 1, true) then
                return m.path
            end
        end
        local it = FindTempItem()
        if not it then return "（点「诊断」看候选）" end
        return it.name
    end, 150)
    MakeInfoRow(OverviewPage, "控制棒行程", function()
        if not RODSTATE.pct then return tostring(RODSTATE.note or "校准中") end
        return string.format("%d%%", math.floor(RODSTATE.pct * 100 + 0.5))
    end, 150)
    MakeInfoRow(OverviewPage, "棒位来源", function()
        return tostring(RODSTATE.note or "—")
    end, 150)

    -- 面板读数（原来在「设备面板」页，现在并进概况；警报留在「所有警报」页）
    if #PANEL.groups == 0 then
        CreateSection(OverviewPage, "面板读数")
        MakeInfoRow(OverviewPage, "（还没扫到面板）", function() return "点下面「重新扫描」" end, 220)
    else
        for _, g in ipairs(PANEL.groups) do
            CreateSection(OverviewPage, string.format("%s（%d）", PanelGroupZh(g.name), #g.rows))
            local shown = 0
            for _, r in ipairs(g.rows) do
                if shown >= 40 then break end
                shown = shown + 1
                local lbl = r.valLbl
                MakeInfoRow(OverviewPage, PanelZh(r.label), function()
                    local ok, t = pcall(function() return lbl.Text end)
                    if not ok then return "?" end
                    return ValueZh(tostring(t))
                end, 220)
            end
        end
    end

    CreateSection(OverviewPage, "工具")
    OverviewButton(OverviewPage, "重新扫描（面板 + 数值）", Color3.fromRGB(58, 88, 120), function()
        ScanMetrics()
        ScanTelemetry()
        RODPARTS.list = FindRodParts()
        ScanPanels()
        ScanAlarms()
        BuildOverview()
        BuildPanels()
        Status(string.format("已重新扫描：面板 %d 块", #PANEL.groups), true)
    end)
    OverviewButton(OverviewPage, "诊断：导出文件 / 剪贴板", Color3.fromRGB(88, 76, 60), function()
        DumpTelemetry()
    end)
    OverviewButton(OverviewPage, "重置控制棒行程校准", Color3.fromRGB(90, 62, 52), function()
        RODTRACK.map = {}
        RODTRACK.best = nil
        RODTRACK.bestRange = 0
        RODSTATE.pct, RODSTATE.note = nil, nil
        SaveCfg()
        BuildOverview()
        Status("已重置棒位跟踪，请升/降一次控制棒", true)
    end)
end

-- （原来的「全量数据」页已删除：普通玩家用不到，数据都并进「设施概况」和「所有警报」了）

-- ============================================================
-- 页面：所有警报（只保留警报；面板读数已经并进「设施概况」）
-- ============================================================
BuildPanels = function()
    for _, ch in ipairs(PanelsPage:GetChildren()) do
        pcall(function() ch:Destroy() end)
    end
    ClearPageRows(PanelsPage)
    PAGE_Y[PanelsPage] = PAD_TOP
    PanelsPage.CanvasSize = UDim2.new(0, 0, 0, 0)

    CreateSection(PanelsPage, "警报屏（" .. tostring(#ALARMS.items) .. " 条）")
    if #ALARMS.items == 0 then
        MakeInfoRow(PanelsPage, "（没扫到警报文字）", function() return "—" end, 220)
    else
        -- 按「屏」分组：同一块屏内的重复文字已经在扫描时去重；
        -- 同名但不同实例的屏（比如控制室一块、应急间一块）用 #2 / #3 区分
        local byKey, order = {}, {}
        local nameCount = {}
        for _, a in ipairs(ALARMS.items) do
            if not byKey[a.panelKey] then
                local n = (nameCount[a.panel] or 0) + 1
                nameCount[a.panel] = n
                local zh = PanelGroupZh(a.panel)
                byKey[a.panelKey] = { title = (n == 1) and zh or (zh .. " #" .. n), rows = {} }
                order[#order + 1] = a.panelKey
            end
            table.insert(byKey[a.panelKey].rows, a)
        end

        for _, key in ipairs(order) do
            local g = byKey[key]
            CreateSection(PanelsPage, string.format("%s（%d）", g.title, #g.rows))
            local n = 0
            for _, a in ipairs(g.rows) do
                if n >= 30 then break end
                n = n + 1
                local item = a
                MakeInfoRow(PanelsPage, AlarmZh(item.text), function()
                    if not item.isNeon then return "? 未找到灯" end
                    return AlarmLit(item) and "● 亮（触发）" or "○ 灭"
                end, 220, function()
                    if not item.isNeon then return Color3.fromRGB(235, 200, 120) end
                    if AlarmLit(item) then return Color3.fromRGB(235, 120, 110) end
                    return Color3.fromRGB(140, 150, 165)
                end)
            end
        end
    end

    CreateSection(PanelsPage, "工具")
    OverviewButton(PanelsPage, "记录警报基线", Color3.fromRGB(58, 88, 120), function()
        SnapshotAlarms()
    end)
    OverviewButton(PanelsPage, "对比警报变化（触发后按）", Color3.fromRGB(88, 76, 60), function()
        DiffAlarms()
    end)
    OverviewButton(PanelsPage, "重新扫描面板", Color3.fromRGB(58, 88, 120), function()
        ScanPanels()
        ScanAlarms()
        BuildPanels()
        Status("面板重扫完成", true)
    end)
end

-- ============================================================
-- 页面：设置
-- ============================================================
local function CreateSlider(parent, text, get, set, min, max, step)
    local frame = Instance.new("Frame")
    frame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    frame.BorderSizePixel = 0
    Place(parent, frame, 46)
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 18)
    label.Position = UDim2.new(0, 10, 0, 4)
    label.BackgroundTransparency = 1
    label.Text = text .. ": " .. tostring(get())
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local minus = Instance.new("TextButton")
    minus.Size = UDim2.new(0, 30, 0, 20)
    minus.Position = UDim2.new(1, -96, 0, 22)
    minus.BackgroundColor3 = Color3.fromRGB(50, 50, 62)
    minus.BorderSizePixel = 0
    minus.Text = "−"
    minus.TextColor3 = Color3.fromRGB(230, 230, 240)
    minus.Font = Enum.Font.GothamBold
    minus.TextSize = 14
    minus.Parent = frame
    Instance.new("UICorner", minus).CornerRadius = UDim.new(0, 4)

    local plus = Instance.new("TextButton")
    plus.Size = UDim2.new(0, 30, 0, 20)
    plus.Position = UDim2.new(1, -62, 0, 22)
    plus.BackgroundColor3 = Color3.fromRGB(50, 50, 62)
    plus.BorderSizePixel = 0
    plus.Text = "+"
    plus.TextColor3 = Color3.fromRGB(230, 230, 240)
    plus.Font = Enum.Font.GothamBold
    plus.TextSize = 14
    plus.Parent = frame
    Instance.new("UICorner", plus).CornerRadius = UDim.new(0, 4)

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -150, 0, 6)
    bar.Position = UDim2.new(0, 10, 0, 30)
    bar.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    bar.BorderSizePixel = 0
    bar.Parent = frame
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 3)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(60, 90, 160)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 3)

    local function sync()
        local v = get()
        label.Text = text .. ": " .. tostring(v)
        local pct = (max > min) and math.clamp((v - min) / (max - min), 0, 1) or 0
        fill.Size = UDim2.new(pct, 0, 1, 0)
    end

    local function bump(dir)
        local v = get() + dir * step
        v = math.clamp(v, min, max)
        set(v)
        sync()
        SaveCfg()
    end

    minus.MouseButton1Click:Connect(function() bump(-1) end)
    plus.MouseButton1Click:Connect(function() bump(1) end)

    sync()
    return frame, sync
end

local SettingsPage = MakePage("设置")
CreateSection(SettingsPage, "瞬移与触发")

local _, syncOff = CreateSlider(SettingsPage, "瞬移到离开关几格", function() return CFG.off end,
    function(v) CFG.off = v end, 1, 6, 0.5)
local _, syncSettle = CreateSlider(SettingsPage, "触发前等待 (ms)", function() return CFG.settle end,
    function(v) CFG.settle = math.floor(v) end, 0, 300, 20)
local _, syncAfter = CreateSlider(SettingsPage, "触发后等回执 (ms)", function() return CFG.after end,
    function(v) CFG.after = math.floor(v) end, 20, 400, 20)
local _, syncClick = CreateSlider(SettingsPage, "点击前等待 (ms，点按类专用)", function() return CFG.clickSettle end,
    function(v) CFG.clickSettle = math.floor(v) end, 0, 800, 50)
local _, syncRetry = CreateSlider(SettingsPage, "失败重试次数", function() return CFG.retries end,
    function(v) CFG.retries = math.floor(v) end, 0, 3, 1)
local _, syncRetryAdd = CreateSlider(SettingsPage, "重试时每次多等 (ms)", function() return CFG.retryAdd end,
    function(v) CFG.retryAdd = math.floor(v) end, 0, 300, 20)

CreateSection(SettingsPage, "其它")

local function MakeToggle(parent, text, get, set)
    local btn = Instance.new("TextButton")
    btn.BorderSizePixel = 0
    btn.Text = "  " .. text
    btn.TextColor3 = Color3.fromRGB(220, 220, 220)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.TextXAlignment = Enum.TextXAlignment.Left
    Place(parent, btn, 34)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local function sync()
        btn.BackgroundColor3 = get() and Color3.fromRGB(60, 90, 160) or Color3.fromRGB(40, 40, 50)
    end
    btn.MouseButton1Click:Connect(function()
        set(not get())
        sync()
        SaveCfg()
    end)
    sync()
    return btn
end

MakeToggle(SettingsPage, "自动刷新状态（每 0.4 秒）", function() return CFG.autoRefresh end,
    function(v) CFG.autoRefresh = v end)
MakeToggle(SettingsPage, "控制台输出调试日志", function() return CFG.verbose end,
    function(v) CFG.verbose = v end)

local resetBtn = Instance.new("TextButton")
resetBtn.BackgroundColor3 = Color3.fromRGB(90, 62, 52)
resetBtn.BorderSizePixel = 0
resetBtn.Text = "重置「上次」记忆"
resetBtn.TextColor3 = Color3.new(1, 1, 1)
resetBtn.Font = Enum.Font.GothamBold
resetBtn.TextSize = 12
Place(SettingsPage, resetBtn, 34)
Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0, 6)
resetBtn.MouseButton1Click:Connect(function()
    for k in pairs(MEM) do MEM[k] = nil end
    SaveCfg()
    for _, r in ipairs(ROWS) do pcall(r.Refresh) end
    Status("已清空「上次」状态记忆")
end)

-- ============================================================
-- 页面：说明（内容）
-- 页面本身在最前面就建好了（见「页面：说明（第一个分区）」），这里只往里填文字
-- ============================================================
local function C(hex, text)
    return string.format('<font color="#%s">%s</font>', hex, text)
end

local aboutText = table.concat({
    C("96BEE6", "NARAMO-RO · 反应堆操作"),
    C("9699AA", "版本 " .. VERSION .. " · 与主程序 NARAMO 分开加载，互不影响。"),
    "",
    C("EB8C86", "请注意：由于本脚本的原理是「传送到按钮旁边再按」，动作很显眼，"
        .. "容易被其他玩家发现并被举报，请小心使用。"),
    "",
    C("96BEE6", "原理"),
    "所有设施开关都是 ProximityPrompt，只有在交互距离内（5～14 格）触发才算数；"
        .. "服务器还会检测位置跳变并把人拉回。所以这里的做法是：记住当前位置 → 瞬移到面板前 → "
        .. "同一帧触发 → 收到 Triggered 立刻传回。整个过程一般 20～80ms。",
    "",
    C("96BEE6", "状态颜色"),
    C("A0BEDC", "[启用]") .. " 灰蓝：提示当前是启用的 —— 注意这只代表属性为 true，"
        .. "不代表动作一定有效（控制棒到顶后按钮还在、属性还是 true，按下去没反应）。",
    C("EB968C", "[禁用]") .. " 红色：提示当前禁用，按了不会生效。",
    C("96D7AA", "[可点]") .. " 绿色：点击探测器，没有启用开关这个概念。",
    C("EBA078", "[缺失]") .. " 橙色：按登记路径没找到，可能这个版本改了名字。",
    C("96AAC8", "[上次: 开/关]") .. " 只对单键切换类生效：这类开关不往客户端同步状态，"
        .. "只能记「上次切到哪边」，存在 NARAMO_RO/config.json 里。",
    C("EBC878", "[棒位 xx%]") .. " 控制棒的实时行程：不读按钮属性，而是跟踪 Reactor 下每个零件的"
        .. "位置，自动挑「位移最大」的那个当尺子，记下它走过的最低/最高点来算百分比。"
        .. "第一次升/降一次控制棒才校准得出来；提升/落下时如果显示「校准中」，点概况页的「诊断」看位移 Top10。",
    "",
    C("96BEE6", "设施概况 / 所有警报"),
    "「设施概况」= 反应堆温度、控制棒行程，加上控制室各面板的读数（给水、电网、冷却液、"
        .. "涡轮、发电机、母线…），按面板分小分区实时刷新，读数直接镜像面板上的文字。",
    "「所有警报」= 各警报屏的告警条目，灯亮（Neon 零件不透明）就显示「● 亮（触发）」，"
        .. "灭显示「○ 灭」。面板上的每条告警有两个零件：背板（永远不透明）+ 霓虹灯（真正的状态），"
        .. "脚本认的是霓虹灯。",
    "",
    C("96BEE6", "边界"),
    "· 反应堆运行中乱按可能把堆搞炸，按之前先确认状态。",
    "· 电网并网开关是 DragDetector（拖拽式），没法用点击触发，所以没有登记。",
    "· 如果某一行一直「没有回执」，多半是被拉回早了：到「设置」里把「触发前等待」加到 40～80ms 再试。",
    "· 所有改动只发生在本机：不动游戏属性，不写服务器，只瞬移 + 触发一次 + 传回。",
}, "\n")

local aboutLbl = Instance.new("TextLabel")
aboutLbl.RichText = true
aboutLbl.Size = UDim2.new(1, -16, 0, 0)
aboutLbl.Position = UDim2.new(0, 8, 0, PAD_TOP)
aboutLbl.AutomaticSize = Enum.AutomaticSize.Y
aboutLbl.BackgroundTransparency = 1
aboutLbl.Text = aboutText
aboutLbl.TextColor3 = Color3.fromRGB(190, 195, 205)
aboutLbl.Font = Enum.Font.Gotham
aboutLbl.TextSize = 12
aboutLbl.TextWrapped = true
aboutLbl.TextXAlignment = Enum.TextXAlignment.Left
aboutLbl.TextYAlignment = Enum.TextYAlignment.Top
aboutLbl.Parent = AboutPage
-- 说明页只有这一个自动高度的标签，画布高度让它自己撑
AboutPage.AutomaticCanvasSize = Enum.AutomaticSize.Y

-- ============================================================
-- 迷你窗（照主程序）
-- ============================================================
local MiniFrame = Instance.new("Frame")
MiniFrame.Size = UDim2.new(0, 132, 0, 32)
MiniFrame.Position = UDim2.new(0.5, -66, 0, 24)
MiniFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
MiniFrame.BorderSizePixel = 0
MiniFrame.Active = true
MiniFrame.Visible = false
MiniFrame.Parent = ScreenGui
Instance.new("UICorner", MiniFrame).CornerRadius = UDim.new(0, 16)

local MiniLabel = Instance.new("TextLabel")
MiniLabel.Size = UDim2.new(1, 0, 1, 0)
MiniLabel.BackgroundTransparency = 1
MiniLabel.Text = "NARAMO-RO"
MiniLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
MiniLabel.Font = Enum.Font.GothamBold
MiniLabel.TextSize = 12
MiniLabel.Parent = MiniFrame

local miniDragging, miniMoved, miniStartPos, miniStartInput = false, false, nil, nil
MiniFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        miniDragging = true
        miniMoved = false
        miniStartPos = MiniFrame.Position
        miniStartInput = input.Position
    end
end)
MiniFrame.InputChanged:Connect(function(input)
    if miniDragging and miniStartInput
        and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - miniStartInput
        if delta.Magnitude > 4 then miniMoved = true end
        MiniFrame.Position = UDim2.new(miniStartPos.X.Scale, miniStartPos.X.Offset + delta.X,
            miniStartPos.Y.Scale, miniStartPos.Y.Offset + delta.Y)
    end
end)
MiniFrame.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        miniDragging = false
        if not miniMoved then
            MiniFrame.Visible = false
            MainFrame.Visible = true
        end
    end
end)

MiniBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    MiniFrame.Visible = true
end)

-- ============================================================
-- 拖动
-- ============================================================
local dragging, dragStart, startPos = false, nil, nil
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)
TitleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
TitleBar.InputChanged:Connect(function(input)
    if not dragging or not dragStart then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- ============================================================
-- 关闭 / 刷新循环
-- ============================================================
local RefreshThread = nil

local function Close()
    if IsClosing then return end
    IsClosing = true
    SaveCfg()
    if RefreshThread then
        pcall(task.cancel, RefreshThread)
        RefreshThread = nil
    end
    pcall(function() ScreenGui:Destroy() end)
    GENV.__NARAMO_RO_RUNNING = false
    print("[NARAMO-RO] 已关闭")
end

CloseBtn.MouseButton1Click:Connect(Close)

RefreshThread = task.spawn(function()
    local lastSave = 0
    while not IsClosing do
        -- 控制棒行程：先采样（记每个零件的位移范围），再算百分比
        pcall(RodSample)
        local pct, note = RodUpdate()
        RODSTATE.pct, RODSTATE.note = pct, note
        if pct and (os.clock() - lastSave > 8) then
            SaveCfg()
            lastSave = os.clock()
        end

        if CFG.autoRefresh then
            for _, r in ipairs(ROWS) do
                pcall(r.Refresh)
            end
            for _, r in ipairs(INFO_ROWS) do
                pcall(function()
                    r.val.Text = r.getter()
                    if r.color then r.val.TextColor3 = r.color() end
                end)
            end
        end
        task.wait(0.4)
    end
end)

-- 设置页的滑条文字要跟着 CFG 变化重画（重试次数等由滑块自己 sync；这里只管首次）
pcall(syncOff)
pcall(syncSettle)
pcall(syncAfter)
pcall(syncClick)
pcall(syncRetry)
pcall(syncRetryAdd)

-- 概况页 / 所有警报页：先建空壳，再把扫描放进后台
pcall(BuildOverview)
pcall(BuildPanels)
task.defer(function()
    task.wait(0.8)
    pcall(ScanMetrics)
    pcall(ScanTelemetry)
    pcall(ScanEverything)
    pcall(function() RODPARTS.list = FindRodParts() end)
    pcall(ScanPanels)
    pcall(ScanAlarms)
    pcall(BuildOverview)
    pcall(BuildPanels)
end)

print("[NARAMO-RO] 已加载 " .. VERSION .. "（开关 " .. tostring(#ENTRIES) .. " 个）")
