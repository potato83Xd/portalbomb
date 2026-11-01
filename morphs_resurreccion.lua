--[[
  MORPHS DE RESURRECCION  (Lua Executor, cliente, R15)
  4 morphs originales: Avispon Ambar, Oso Zurcido, Langostino Abisal, Fenix Cinerea

  - Cada pieza va soldada (Weld) a una extremidad R15, asi que sigue
    animaciones, saltos, emotes y movimiento sin romperse.
  - Al morir y reaparecer, cambias al SIGUIENTE morph (ciclo) o a uno al azar.
  - Panel arrastrable: < > cambia morph, Modo ciclo/azar, Probar muerte, Quitar/Poner.
  - Solo lo ves tu (es del lado del cliente).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local lp = Players.LocalPlayer

-- si ya habia una copia corriendo, la limpio
if _G.__MorphRes and _G.__MorphRes.destroy then pcall(_G.__MorphRes.destroy) end

local S = {
  conns = {}, charConns = {}, idx = 1, deaths = 0, random = false,
  pending = false, on = true, alive = true, anims = {}, note = nil,
  hidden = setmetatable({}, { __mode = "k" }),
}
_G.__MorphRes = S

-- ============================================================
--  HELPERS
-- ============================================================
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local MAT = Enum.Material
local V3, CF, A = Vector3.new, CFrame.new, CFrame.Angles
local sin, abs, pi = math.sin, math.abs, math.pi

local LIMB = {
  H = "Head", UT = "UpperTorso", LT = "LowerTorso",
  LUA = "LeftUpperArm", LLA = "LeftLowerArm", LH = "LeftHand",
  RUA = "RightUpperArm", RLA = "RightLowerArm", RH = "RightHand",
  LUL = "LeftUpperLeg", LLL = "LeftLowerLeg", LF = "LeftFoot",
  RUL = "RightUpperLeg", RLL = "RightLowerLeg", RF = "RightFoot",
}

-- pieza generica: limb, forma, tamano, offset (o bisagra), color, material, extras
local function mk(k, shape, size, cf, col, mat, ex)
  local t = { k = k, shape = shape, size = size, cf = cf or CF(), col = col, mat = mat or MAT.SmoothPlastic }
  if ex then for a, b in pairs(ex) do t[a] = b end end
  return t
end
local function blk(k, size, cf, col, mat, ex) return mk(k, "Block", size, cf, col, mat, ex) end
local function ball(k, size, cf, col, mat, ex) return mk(k, "Ball", size, cf, col, mat, ex) end
-- cubre una extremidad completa (tamano relativo al tamano real del limb)
local function cov(k, mult, col, mat, shape)
  return mk(k, shape or "Block", mult, CF(), col, mat, { rel = true })
end
-- ejecuta f para lado izquierdo (s=-1) y derecho (s=1)
local function both(f) f("L", -1); f("R", 1) end

-- ============================================================
--  MORPH 1: AVISPON AMBAR
-- ============================================================
local function buildAvispon()
  local t = {}
  local function add(x) t[#t + 1] = x end
  local P = MAT.SmoothPlastic
  local BLK, AMB, STG = rgb(20, 20, 24), rgb(255, 176, 20), rgb(70, 36, 12)

  -- torso
  add(cov("UT", V3(1.03, 1.02, 1.06), AMB, P))
  add(blk("UT", V3(2.1, 0.2, 1.12), CF(0, 0.4, 0), BLK, P))
  add(blk("UT", V3(2.1, 0.2, 1.12), CF(0, -0.15, 0), BLK, P))
  add(cov("LT", V3(1.04, 1.1, 1.06), BLK, P))

  -- abdomen segmentado con aguijon
  local hinge = CF(0, 0, 0.5)
  local sway = function(tm) return A(sin(tm * 3) * 0.08, 0, 0) end
  local sizes = { 1.5, 1.4, 1.15, 0.85 }
  local zEnd, yEnd = 0, 0
  for i = 1, 4 do
    local z, y = 0.4 + i * 0.62, -0.15 - i * 0.17
    local d = sizes[i]
    add(ball("LT", V3(d * 0.95, d, d * 1.25), hinge, (i % 2 == 1) and AMB or BLK, P,
      { pivot = CF(0, y, z - 0.5), anim = sway }))
    zEnd, yEnd = z, y
  end
  add(ball("LT", V3(0.16, 0.16, 1.0), hinge, STG, P,
    { pivot = CF(0, yEnd - 0.15, zEnd + 0.93 - 0.5) * A(0.35, 0, 0), anim = sway }))

  -- alas (aleteo rapido)
  both(function(p, s)
    local function flap(ph, rest)
      return function(tm) return A(0, 0, -s * (rest + sin(tm * 38 + ph) * 0.33)) end
    end
    add(ball("UT", V3(0.06, 2.9, 1.15), CF(s * 0.35, 0.55, 0.55), rgb(200, 235, 255), MAT.Glass,
      { tr = 0.5, pivot = CF(0, 1.45, 0.1), anim = flap(0, 0.5) }))
    add(ball("UT", V3(0.05, 1.9, 0.8), CF(s * 0.35, 0.3, 0.65), rgb(190, 225, 250), MAT.Glass,
      { tr = 0.55, pivot = CF(0, 0.95, 0.15), anim = flap(0.6, 0.95) }))
  end)

  -- cabeza
  add(ball("H", V3(1.55, 1.4, 1.4), CF(0, -0.05, 0), AMB, P))
  both(function(p, s)
    add(ball("H", V3(0.62, 0.9, 0.55), CF(s * 0.5, 0.1, -0.42), rgb(10, 10, 14), P, { refl = 0.25 }))
    add(ball("H", V3(0.16, 0.16, 0.1), CF(s * 0.42, 0.32, -0.68), rgb(255, 255, 255), P))
    add(ball("H", V3(0.14, 0.14, 0.6), CF(s * 0.2, -0.5, -0.62) * A(0, -s * 0.45, 0), STG, P))
    local hg = CF(s * 0.3, 0.6, -0.3)
    local an = function(tm) return A(0.7 + sin(tm * 4 + s) * 0.12, -s * 0.3, 0) end
    add(ball("H", V3(0.08, 0.08, 1.2), hg, BLK, P, { pivot = CF(0, 0, -0.6), anim = an }))
    add(ball("H", V3(0.18, 0.18, 0.18), hg, AMB, P, { pivot = CF(0, 0, -1.2), anim = an }))
  end)

  -- brazos y piernas
  both(function(p, s)
    add(cov(p .. "UA", V3(1.06, 1.02, 1.06), BLK, P))
    add(cov(p .. "LA", V3(1.04, 1.02, 1.04), AMB, P))
    add(cov(p .. "H", V3(1.04, 1.1, 1.04), BLK, P))
    add(ball(p .. "H", V3(0.16, 0.8, 0.16), CF(0, -0.45, -0.1), STG, P))
    add(cov(p .. "UL", V3(1.04, 1.02, 1.04), AMB, P))
    add(cov(p .. "LL", V3(1.04, 1.02, 1.04), BLK, P))
    add(cov(p .. "F", V3(1.04, 1.1, 1.04), BLK, P))
    add(ball(p .. "F", V3(0.2, 0.2, 0.6), CF(0, -0.02, -0.55), STG, P))
  end)
  return t
end

-- ============================================================
--  MORPH 2: OSO ZURCIDO (peluche remendado)
-- ============================================================
local function buildOso()
  local t = {}
  local function add(x) t[#t + 1] = x end
  local F, P = MAT.Fabric, MAT.SmoothPlastic
  local FUR, FUR2 = rgb(176, 128, 82), rgb(138, 96, 58)
  local CRM, NOSE, RED, STI = rgb(240, 222, 190), rgb(28, 20, 20), rgb(196, 56, 56), rgb(40, 28, 22)
  local WHT = rgb(250, 250, 250)

  -- cabeza
  add(ball("H", V3(1.95, 1.75, 1.75), CF(0, -0.02, 0), FUR, F))
  add(ball("H", V3(0.95, 0.72, 0.62), CF(0, -0.32, -0.78), CRM, F))
  add(ball("H", V3(0.3, 0.22, 0.2), CF(0, -0.08, -1.05), NOSE, P))
  add(blk("H", V3(0.05, 0.22, 0.04), CF(0, -0.36, -1.1), STI, F))
  add(blk("H", V3(0.26, 0.05, 0.04), CF(-0.1, -0.5, -1.06) * A(0, 0, -0.4), STI, F))
  add(blk("H", V3(0.26, 0.05, 0.04), CF(0.1, -0.5, -1.06) * A(0, 0, 0.4), STI, F))
  -- ojo izquierdo: boton / ojo derecho: cruz cosida
  add(ball("H", V3(0.5, 0.5, 0.12), CF(-0.45, 0.2, -0.72), WHT, F))
  add(ball("H", V3(0.32, 0.32, 0.14), CF(-0.45, 0.2, -0.79), rgb(15, 15, 15), MAT.Glass))
  add(blk("H", V3(0.5, 0.07, 0.05), CF(0.45, 0.2, -0.78) * A(0, 0, pi / 4), STI, F))
  add(blk("H", V3(0.5, 0.07, 0.05), CF(0.45, 0.2, -0.78) * A(0, 0, -pi / 4), STI, F))
  -- costura en la frente
  add(blk("H", V3(0.06, 0.5, 0.05), CF(0.3, 0.55, -0.62), STI, F))
  add(blk("H", V3(0.22, 0.05, 0.05), CF(0.3, 0.45, -0.62), STI, F))
  add(blk("H", V3(0.22, 0.05, 0.05), CF(0.3, 0.65, -0.62), STI, F))
  -- orejas
  both(function(p, s)
    add(ball("H", V3(0.75, 0.75, 0.4), CF(s * 0.78, 0.72, 0.02), FUR, F))
    add(ball("H", V3(0.46, 0.46, 0.22), CF(s * 0.78, 0.72, -0.12), CRM, F))
  end)

  -- torso
  add(cov("UT", V3(1.04, 1.02, 1.12), FUR, F))
  add(ball("UT", V3(1.5, 1.3, 0.35), CF(0, -0.12, -0.45), CRM, F))
  add(blk("UT", V3(0.05, 1.0, 0.04), CF(0, -0.1, -0.64), STI, F))
  for _, y in ipairs({ 0.25, -0.1, -0.45 }) do
    add(blk("UT", V3(0.3, 0.05, 0.04), CF(0, y, -0.64), STI, F))
  end
  add(blk("UT", V3(0.42, 0.42, 0.05), CF(-0.5, 0.2, -0.58) * A(0, 0, pi / 4), RED, F))
  -- mono
  add(ball("UT", V3(0.55, 0.4, 0.25), CF(-0.32, 0.72, -0.55) * A(0, 0, 0.3), RED, F))
  add(ball("UT", V3(0.55, 0.4, 0.25), CF(0.32, 0.72, -0.55) * A(0, 0, -0.3), RED, F))
  add(ball("UT", V3(0.22, 0.22, 0.22), CF(0, 0.72, -0.55), rgb(150, 30, 30), F))

  -- cadera, colita y relleno que se sale
  add(cov("LT", V3(1.04, 1.2, 1.06), FUR2, F))
  add(ball("LT", V3(0.75, 0.75, 0.75), CF(0, 0.05, 0.65), FUR, F))
  add(ball("LT", V3(0.35, 0.35, 0.35), CF(0.3, 0.0, 0.95), WHT, F))
  add(ball("LT", V3(0.25, 0.25, 0.25), CF(0.5, -0.1, 0.85), WHT, F))

  -- brazos y piernas (rellenitos)
  both(function(p, s)
    add(cov(p .. "UA", V3(1.1, 1.25, 1.1), FUR, F, "Ball"))
    add(cov(p .. "LA", V3(1.1, 1.25, 1.1), FUR, F, "Ball"))
    add(ball(p .. "H", V3(1.1, 0.9, 1.1), CF(0, -0.05, 0), CRM, F))
    add(cov(p .. "UL", V3(1.1, 1.25, 1.1), FUR, F, "Ball"))
    add(cov(p .. "LL", V3(1.1, 1.25, 1.1), FUR, F, "Ball"))
    add(ball(p .. "F", V3(1.15, 0.8, 1.5), CF(0, 0.05, -0.1), CRM, F))
    if s == -1 then
      add(blk("LLA", V3(0.55, 0.5, 0.06), CF(0, 0, -0.54), rgb(222, 182, 64), F))
      add(blk("LLA", V3(0.62, 0.04, 0.05), CF(0, 0.27, -0.54), STI, F))
      add(blk("LLA", V3(0.62, 0.04, 0.05), CF(0, -0.27, -0.54), STI, F))
    end
  end)
  return t
end

-- ============================================================
--  MORPH 3: LANGOSTINO ABISAL
-- ============================================================
local function buildLangostino()
  local t = {}
  local function add(x) t[#t + 1] = x end
  local P, N = MAT.SmoothPlastic, MAT.Neon
  local PK, PK2, CO = rgb(255, 140, 152), rgb(255, 196, 200), rgb(222, 88, 112)
  local DP, BL, GL = rgb(150, 38, 70), rgb(255, 230, 230), rgb(110, 255, 230)

  -- cabeza
  add(ball("H", V3(1.75, 1.5, 1.8), CF(0, -0.05, 0), PK, P))
  add(ball("H", V3(0.16, 0.16, 1.2), CF(0, 0.35, -1.1) * A(0.3, 0, 0), CO, P))
  add(ball("H", V3(0.5, 0.25, 0.3), CF(0, -0.5, -0.8), DP, P))
  both(function(p, s)
    -- ojos en tallo
    add(ball("H", V3(0.16, 0.55, 0.16), CF(s * 0.5, 0.55, -0.55), PK2, P))
    add(ball("H", V3(0.5, 0.5, 0.5), CF(s * 0.52, 0.9, -0.6), rgb(15, 10, 20), MAT.Glass, { refl = 0.2 }))
    add(ball("H", V3(0.18, 0.18, 0.1), CF(s * 0.54, 0.92, -0.84), GL, N))
    -- antenas largas con punta luminosa
    local hg = CF(s * 0.4, 0.5, -0.2)
    local an = function(tm) return A(0.5 + sin(tm * 2.2 + s) * 0.1, 0, -s * 0.3 + sin(tm * 1.7) * 0.1) end
    add(ball("H", V3(0.07, 2.4, 0.07), hg, CO, P, { pivot = CF(0, 1.2, 0), anim = an }))
    add(ball("H", V3(0.16, 0.16, 0.16), hg, GL, N, { pivot = CF(0, 2.4, 0), anim = an }))
  end)

  -- torso con placas y puntos bioluminiscentes
  add(cov("UT", V3(1.04, 1.02, 1.06), PK, P))
  add(blk("UT", V3(1.4, 1.2, 0.06), CF(0, 0, -0.52), BL, P))
  for _, y in ipairs({ 0.5, 0.1, -0.3 }) do
    add(blk("UT", V3(2.08, 0.12, 1.08), CF(0, y, 0), CO, P))
  end
  for _, q in ipairs({ { -0.55, 0.35 }, { 0.55, 0.35 }, { -0.3, -0.2 }, { 0.3, -0.2 }, { 0, 0.05 } }) do
    add(ball("UT", V3(0.16, 0.16, 0.1), CF(q[1], q[2], -0.57), GL, N))
  end
  add(cov("LT", V3(1.04, 1.1, 1.08), CO, P))

  -- cola segmentada con abanico (se mueve de lado a lado)
  local hinge = CF(0, -0.05, 0.4)
  local swish = function(tm) return A(0, sin(tm * 2.4) * 0.18, 0) end
  local yE, zE = 0, 0
  for i = 1, 5 do
    local z, y = 0.5 + i * 0.55, -0.1 - i * 0.2
    add(ball("LT", V3(1.5 - i * 0.18, 0.9 - i * 0.08, 0.8), hinge, (i % 2 == 1) and PK or CO, P,
      { pivot = CF(0, y, z - 0.4), anim = swish }))
    yE, zE = y, z
  end
  local fanCols = { DP, CO, DP }
  for k, yaw in ipairs({ -0.5, 0, 0.5 }) do
    add(ball("LT", V3(0.55, 0.07, 1.1), hinge, fanCols[k], P,
      { pivot = CF(0, yE, zE + 0.3 - 0.4) * A(0, yaw, 0) * CF(0, 0, 0.55), anim = swish }))
  end

  -- patitas extra en la espalda
  both(function(p, s)
    for j = 1, 2 do
      add(ball("UT", V3(0.14, 1.2, 0.14), CF(s * (0.4 + j * 0.25), -0.5, 0.75) * A(0.5, 0, -s * (0.35 + j * 0.15)), PK2, P))
    end
  end)

  -- brazos con pinzas y piernas
  both(function(p, s)
    add(cov(p .. "UA", V3(1.06, 1.02, 1.06), PK, P))
    add(cov(p .. "LA", V3(1.04, 1.02, 1.04), PK2, P))
    add(ball(p .. "H", V3(0.95, 0.7, 1.1), CF(0, -0.1, 0), DP, P))
    add(ball(p .. "H", V3(0.16, 0.85, 0.16), CF(-0.2, -0.55, -0.1) * A(0, 0, 0.15), CO, P))
    add(ball(p .. "H", V3(0.16, 0.85, 0.16), CF(0.2, -0.55, -0.1) * A(0, 0, -0.15), CO, P))
    add(cov(p .. "UL", V3(1.04, 1.02, 1.04), PK, P))
    add(cov(p .. "LL", V3(1.04, 1.02, 1.04), PK2, P))
    add(ball(p .. "F", V3(1.05, 0.5, 1.4), CF(0, 0.05, -0.15), DP, P))
  end)
  return t
end

-- ============================================================
--  MORPH 4: FENIX CINEREA
-- ============================================================
local function buildFenix()
  local t = {}
  local function add(x) t[#t + 1] = x end
  local P, N, SL = MAT.SmoothPlastic, MAT.Neon, MAT.Slate
  local ASH, ASH2 = rgb(52, 42, 48), rgb(36, 28, 32)
  local EMB, GLD, RDD, DRK = rgb(255, 110, 30), rgb(255, 200, 60), rgb(210, 40, 22), rgb(110, 24, 12)

  -- torso agrietado con nucleo brillante
  add(cov("UT", V3(1.04, 1.02, 1.08), ASH, SL))
  add(blk("UT", V3(0.9, 0.07, 0.05), CF(-0.25, 0.4, -0.55) * A(0, 0, 0.25), EMB, N))
  add(blk("UT", V3(0.7, 0.07, 0.05), CF(0.35, 0.1, -0.55) * A(0, 0, -0.35), EMB, N))
  add(blk("UT", V3(0.8, 0.07, 0.05), CF(-0.3, -0.35, -0.55) * A(0, 0, -0.2), EMB, N))
  add(ball("UT", V3(0.5, 0.5, 0.25), CF(0, 0.05, -0.55), GLD, N))
  add(cov("LT", V3(1.04, 1.1, 1.06), ASH2, SL))

  -- cabeza con pico y cresta de fuego
  add(ball("H", V3(1.5, 1.5, 1.5), CF(0, -0.02, 0), ASH, SL))
  add(ball("H", V3(0.34, 0.26, 0.85), CF(0, -0.12, -0.85), GLD, P))
  add(ball("H", V3(0.3, 0.16, 0.6), CF(0, -0.28, -0.78), rgb(230, 160, 30), P))
  both(function(p, s)
    add(ball("H", V3(0.34, 0.14, 0.1), CF(s * 0.38, 0.2, -0.7) * A(0, 0, s * 0.3), EMB, N))
  end)
  for k = 1, 5 do
    local ang = (k - 3) * 0.3
    local len = 0.9 + (3 - abs(k - 3)) * 0.25
    add(ball("H", V3(0.2, len, 0.2), CF(0, 0.62, 0), (k % 2 == 1) and EMB or GLD, N, {
      pivot = CF(0, len / 2, 0),
      anim = function(tm) return A(sin(tm * 7 + k) * 0.08, 0, ang + sin(tm * 6 + k * 1.3) * 0.06) end,
    }))
  end

  -- alas de plumas (4 por lado, aleteo lento)
  local lens = { 3.4, 3.1, 2.7, 2.2 }
  local cols = { GLD, EMB, RDD, DRK }
  local mats = { N, N, P, P }
  both(function(p, s)
    for k = 1, 4 do
      local rest = 0.25 + (k - 1) * 0.3
      add(ball("UT", V3(0.07, lens[k], 0.75), CF(s * 0.4, 0.35, 0.55), cols[k], mats[k], {
        pivot = CF(0, lens[k] / 2, 0),
        anim = function(tm) return A(0, 0, -s * (rest + sin(tm * 2.2 - k * 0.25) * 0.14)) end,
      }))
    end
  end)

  -- cola de llamas
  local tailCols = { EMB, GLD, RDD }
  for k = 1, 3 do
    local len = 2.4 - (k % 2) * 0.5
    add(ball("LT", V3(0.3, 0.3, len), CF(0, 0, 0.45), tailCols[k], N, {
      pivot = CF(0, -0.1, len / 2),
      anim = function(tm) return A(0.2 + sin(tm * 5 + k) * 0.08, (k - 2) * 0.35 + sin(tm * 4 + k) * 0.1, 0) end,
    }))
  end

  -- brazos con plumas, garras y piernas
  both(function(p, s)
    add(cov(p .. "UA", V3(1.06, 1.02, 1.06), ASH, SL))
    add(cov(p .. "LA", V3(1.04, 1.02, 1.04), ASH2, SL))
    for j = 1, 3 do
      add(ball(p .. "LA", V3(0.08, 1.3, 0.45), CF(s * 0.55, -0.2, (j - 2) * 0.3) * A(0, 0, s * (0.1 + j * 0.08)), (j == 2) and GLD or EMB, N))
    end
    add(cov(p .. "H", V3(1.04, 1.2, 1.04), GLD, P))
    for i = -1, 1 do
      add(ball(p .. "H", V3(0.12, 0.5, 0.12), CF(i * 0.25, -0.35, -0.15), DRK, P))
    end
    add(cov(p .. "UL", V3(1.04, 1.02, 1.04), ASH, SL))
    add(cov(p .. "LL", V3(1.04, 1.02, 1.04), rgb(90, 50, 30), SL))
    add(cov(p .. "F", V3(1.04, 1.1, 1.04), GLD, P))
    for i = -1, 1 do
      add(ball(p .. "F", V3(0.12, 0.12, 0.55), CF(i * 0.27, -0.02, -0.55), DRK, P))
    end
  end)
  return t
end

-- particulas de brasas para el fenix
local function fxFenix(char)
  local ut = char:FindFirstChild("UpperTorso")
  if not ut then return end
  local pe = Instance.new("ParticleEmitter")
  pe.Name = "MorphFX"
  pe.Color = ColorSequence.new(rgb(255, 200, 60), rgb(255, 60, 20))
  pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
  pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
  pe.Lifetime = NumberRange.new(0.5, 1)
  pe.Rate = 30
  pe.Speed = NumberRange.new(1, 3)
  pe.SpreadAngle = Vector2.new(30, 30)
  pe.LightEmission = 1
  pe.Acceleration = V3(0, 4, 0)
  pe.Parent = ut
end

local MORPHS = {
  { name = "Avispon Ambar",     accent = rgb(255, 176, 20),  build = buildAvispon },
  { name = "Oso Zurcido",       accent = rgb(222, 182, 64),  build = buildOso },
  { name = "Langostino Abisal", accent = rgb(110, 255, 230), build = buildLangostino },
  { name = "Fenix Cinerea",     accent = rgb(255, 110, 30),  build = buildFenix, fx = fxFenix },
}

-- ============================================================
--  NUCLEO: aplicar / quitar morph
-- ============================================================
local refreshUI -- se define mas abajo

local function scaleCF(cf, sc)
  if sc == 1 then return cf end
  return CF(cf.Position * sc) * (cf - cf.Position)
end

local function hideInst(d)
  if S.hidden[d] == nil then S.hidden[d] = d.Transparency end
  d.Transparency = 1
end

local function hideOriginal(char)
  for _, d in ipairs(char:GetChildren()) do
    if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
      hideInst(d)
    elseif d:IsA("Accessory") then
      local h = d:FindFirstChild("Handle")
      if h and h:IsA("BasePart") then hideInst(h) end
    end
  end
  local head = char:FindFirstChild("Head")
  if head then
    for _, d in ipairs(head:GetChildren()) do
      if d:IsA("Decal") then hideInst(d) end
    end
  end
end

local function clearMorph(char)
  S.anims = {}
  if char then
    local f = char:FindFirstChild("MorphRes")
    if f then f:Destroy() end
    for _, d in ipairs(char:GetDescendants()) do
      if d.Name == "MorphFX" then d:Destroy() end
    end
  end
  for inst, tr in pairs(S.hidden) do
    if inst and inst.Parent then pcall(function() inst.Transparency = tr end) end
    S.hidden[inst] = nil
  end
end

local function applyMorph(char, i)
  clearMorph(char)
  if not char then return end
  local hum = char:FindFirstChildOfClass("Humanoid")
  if not hum then return end
  if hum.RigType ~= Enum.HumanoidRigType.R15 then
    S.note = "Necesita R15"
    return
  end
  S.note = nil
  local M = MORPHS[i]
  local sc = 1
  pcall(function() sc = char:GetScale() end)

  hideOriginal(char)
  local folder = Instance.new("Folder")
  folder.Name = "MorphRes"
  folder.Parent = char

  for _, sp in ipairs(M.build()) do
    local ok, err = pcall(function()
      local limb = char:FindFirstChild(LIMB[sp.k])
      if not limb then return end
      local p = Instance.new("Part")
      p.Name = "M_" .. sp.k
      if sp.shape == "Ball" then
        local m = Instance.new("SpecialMesh")
        m.MeshType = Enum.MeshType.Sphere
        m.Parent = p
      end
      p.Size = sp.rel and (limb.Size * sp.size) or (sp.size * sc)
      p.Color = sp.col
      p.Material = sp.mat
      p.Transparency = sp.tr or 0
      p.Reflectance = sp.refl or 0
      p.Anchored = false
      p.CanCollide = false
      p.CanTouch = false
      p.CanQuery = false
      p.Massless = true
      p.CastShadow = false
      p.TopSurface = Enum.SurfaceType.Smooth
      p.BottomSurface = Enum.SurfaceType.Smooth

      local cf = scaleCF(sp.cf, sc)
      local pv = sp.pivot or CF()
      if typeof(pv) == "Vector3" then pv = CF(pv) end
      pv = scaleCF(pv, sc)

      local w = Instance.new("Weld")
      w.Part0 = limb
      w.Part1 = p
      w.C0 = cf * pv
      w.Parent = p
      p.Parent = folder

      if sp.anim then
        S.anims[#S.anims + 1] = { w = w, cf = cf, pv = pv, fn = sp.anim }
      end
    end)
    if not ok then warn("[MorphRes] pieza fallida:", err) end
  end

  if M.fx then pcall(M.fx, char) end
end

-- efectos de muerte / renacimiento
local function burst(char, col)
  local root = char:FindFirstChild("HumanoidRootPart")
  if not root then return end
  local a = Instance.new("Part")
  a.Anchored = true; a.CanCollide = false; a.CanQuery = false; a.CanTouch = false
  a.Transparency = 1
  a.Size = V3(1, 1, 1)
  a.CFrame = root.CFrame
  a.Parent = workspace
  local pe = Instance.new("ParticleEmitter")
  pe.Color = ColorSequence.new(col, rgb(255, 255, 255))
  pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
  pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
  pe.Lifetime = NumberRange.new(0.8, 1.6)
  pe.Speed = NumberRange.new(10, 22)
  pe.SpreadAngle = Vector2.new(180, 180)
  pe.LightEmission = 1
  pe.Rate = 0
  pe.Parent = a
  pe:Emit(60)
  Debris:AddItem(a, 3)
end

local function flash(root, col)
  local b = Instance.new("Part")
  b.Shape = Enum.PartType.Ball
  b.Anchored = true; b.CanCollide = false; b.CanQuery = false; b.CanTouch = false
  b.Material = MAT.Neon
  b.Color = col
  b.Transparency = 0.35
  b.Size = V3(2, 2, 2)
  b.CFrame = root.CFrame
  b.Parent = workspace
  TweenService:Create(b, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    { Size = V3(16, 16, 16), Transparency = 1 }):Play()
  Debris:AddItem(b, 1)
end

-- ============================================================
--  SISTEMA DE RESURRECCION
-- ============================================================
local function pickNext()
  if S.random and #MORPHS > 1 then
    local n
    repeat n = math.random(#MORPHS) until n ~= S.idx
    return n
  end
  return S.idx % #MORPHS + 1
end

local function onChar(char)
  for _, c in ipairs(S.charConns) do pcall(function() c:Disconnect() end) end
  S.charConns = {}

  local hum = char:WaitForChild("Humanoid", 10)
  if not hum or not S.alive then return end
  char:WaitForChild("RightFoot", 10)
  char:WaitForChild("HumanoidRootPart", 10)
  task.wait(0.25)
  if not S.alive or not char.Parent then return end

  if S.pending then
    S.idx = pickNext()
    S.pending = false
  end

  if S.on then
    applyMorph(char, S.idx)
    local root = char:FindFirstChild("HumanoidRootPart")
    if root and S.deaths > 0 then flash(root, MORPHS[S.idx].accent) end
  end

  S.charConns[#S.charConns + 1] = hum.Died:Connect(function()
    S.deaths = S.deaths + 1
    S.pending = true
    pcall(function()
      for _, d in ipairs(char:GetDescendants()) do
        if d.Name == "MorphFX" then d.Enabled = false end
      end
    end)
    burst(char, MORPHS[S.idx].accent)
    if refreshUI then refreshUI() end
  end)

  -- accesorios que cargan tarde
  S.charConns[#S.charConns + 1] = char.ChildAdded:Connect(function(c)
    if S.on and c:IsA("Accessory") then
      local h = c:WaitForChild("Handle", 5)
      if h and h:IsA("BasePart") and char:FindFirstChild("MorphRes") then hideInst(h) end
    end
  end)

  if refreshUI then refreshUI() end
end

local function setMorph(i)
  S.idx = ((i - 1) % #MORPHS) + 1
  S.on = true
  if lp.Character then applyMorph(lp.Character, S.idx) end
  if refreshUI then refreshUI() end
end

-- ============================================================
--  PANEL
-- ============================================================
local function corner(o, r)
  local c = Instance.new("UICorner")
  c.CornerRadius = UDim.new(0, r)
  c.Parent = o
end

local function label(parent, txt, x, y, w, h, ts)
  local l = Instance.new("TextLabel")
  l.BackgroundTransparency = 1
  l.Position = UDim2.fromOffset(x, y)
  l.Size = UDim2.fromOffset(w, h)
  l.Font = Enum.Font.GothamBold
  l.TextSize = ts
  l.Text = txt
  l.TextColor3 = rgb(235, 235, 240)
  l.TextXAlignment = Enum.TextXAlignment.Left
  l.Parent = parent
  return l
end

local function button(parent, txt, x, y, w, cb)
  local b = Instance.new("TextButton")
  b.Position = UDim2.fromOffset(x, y)
  b.Size = UDim2.fromOffset(w, 28)
  b.BackgroundColor3 = rgb(40, 40, 52)
  b.TextColor3 = rgb(235, 235, 240)
  b.Font = Enum.Font.GothamMedium
  b.TextSize = 13
  b.Text = txt
  b.BorderSizePixel = 0
  b.Parent = parent
  corner(b, 6)
  b.MouseButton1Click:Connect(cb)
  return b
end

local function buildUI()
  local gui = Instance.new("ScreenGui")
  gui.Name = "MorphResUI"
  gui.ResetOnSpawn = false
  gui.DisplayOrder = 50
  local ok = false
  if gethui then ok = pcall(function() gui.Parent = gethui() end) end
  if not ok then ok = pcall(function() gui.Parent = game:GetService("CoreGui") end) end
  if not ok then gui.Parent = lp:WaitForChild("PlayerGui") end

  local f = Instance.new("Frame")
  f.Size = UDim2.fromOffset(230, 128)
  f.Position = UDim2.new(0, 14, 0.4, 0)
  f.BackgroundColor3 = rgb(18, 18, 24)
  f.BorderSizePixel = 0
  f.Active = true
  f.Draggable = true
  f.Parent = gui
  corner(f, 10)

  local ui = { gui = gui }
  ui.title = label(f, "", 10, 6, 210, 24, 15)
  ui.sub = label(f, "", 10, 32, 210, 20, 12)
  ui.sub.Font = Enum.Font.Gotham
  ui.sub.TextColor3 = rgb(170, 170, 185)

  button(f, "<", 8, 58, 40, function() setMorph(S.idx - 1) end)
  button(f, ">", 52, 58, 40, function() setMorph(S.idx + 1) end)
  ui.mode = button(f, "", 96, 58, 126, function()
    S.random = not S.random
    refreshUI()
  end)
  button(f, "Probar muerte", 8, 92, 104, function()
    local h = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
    if h then h.Health = 0 end
  end)
  ui.toggle = button(f, "", 118, 92, 104, function()
    S.on = not S.on
    if S.on then
      if lp.Character then applyMorph(lp.Character, S.idx) end
    else
      clearMorph(lp.Character)
    end
    refreshUI()
  end)
  S.ui = ui
  S.gui = gui
end

refreshUI = function()
  local ui = S.ui
  if not ui then return end
  local m = MORPHS[S.idx]
  ui.title.Text = S.idx .. "/" .. #MORPHS .. "  " .. m.name
  ui.title.TextColor3 = m.accent
  ui.sub.Text = S.note or ("Muertes: " .. S.deaths .. "  |  " .. (S.random and "Aleatorio" or "Ciclo"))
  ui.mode.Text = S.random and "Modo: Azar" or "Modo: Ciclo"
  ui.toggle.Text = S.on and "Quitar" or "Poner"
end

-- ============================================================
--  ARRANQUE
-- ============================================================
S.destroy = function()
  S.alive = false
  for _, c in ipairs(S.conns) do pcall(function() c:Disconnect() end) end
  for _, c in ipairs(S.charConns) do pcall(function() c:Disconnect() end) end
  clearMorph(lp.Character)
  if S.gui then S.gui:Destroy() end
  if _G.__MorphRes == S then _G.__MorphRes = nil end
end

buildUI()
refreshUI()

-- animaciones propias de cada morph (alas, cola, antenas, llamas)
S.conns[#S.conns + 1] = RunService.Heartbeat:Connect(function()
  local tm = os.clock()
  local list = S.anims
  for i = #list, 1, -1 do
    local a = list[i]
    if a.w.Parent then
      a.w.C0 = a.cf * a.fn(tm) * a.pv
    else
      table.remove(list, i)
    end
  end
end)

S.conns[#S.conns + 1] = lp.CharacterAdded:Connect(function(c) task.spawn(onChar, c) end)
if lp.Character then task.spawn(onChar, lp.Character) end
