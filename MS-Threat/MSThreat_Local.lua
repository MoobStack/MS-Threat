-- MSThreat_Local.lua
-- Solo-only combat-log threat estimator for WoW 1.12.
--
-- Exact native and server APIs remain preferred. This module is used only in Auto
-- mode, while solo, when no exact numeric provider is returning data. Values
-- are deliberately marked as estimated because Vanilla chat combat events do
-- not expose every spell's hidden flat threat, every talent modifier, or an
-- unambiguous GUID when several enemies share a name.

local OT = MSThreat
OT.Local = OT.Local or {}
local Local = OT.Local

local floor = math.floor
local max = math.max
local min = math.min
local tonumber = tonumber
local tostring = tostring
local type = type
local pcall = pcall
local tinsert = table.insert
local tsort = table.sort
local strfind = string.find
local strsub = string.sub
local strlen = string.len
local strlower = string.lower
local gsub = string.gsub

Local.initialized = false
Local.targetKey = nil
Local.targetName = nil
Local.active = false
Local.entries = {}
Local.lastData = 0
Local.eventCount = 0
Local.parseCount = 0
Local.unmatchedCount = 0
Local.lastMessage = nil
Local.selfDamageRules = {}
Local.petDamageRules = {}
Local.healRules = {}

local PATTERN_MAGIC = {
    ["^"] = true, ["$"] = true, ["("] = true, [")"] = true,
    ["%"] = true, ["."] = true, ["["] = true, ["]"] = true,
    ["*"] = true, ["+"] = true, ["-"] = true, ["?"] = true,
}

local function EscapeLiteralChar(ch)
    if PATTERN_MAGIC[ch] then
        return "%" .. ch
    end
    return ch
end

-- Converts a localized Blizzard printf format into a Lua pattern and retains
-- the relationship between capture order and the original printf arguments.
-- Both %s/%d and positional forms such as %2$s/%3$d are supported.
local function CompileFormat(formatText)
    local pattern = "^"
    local captureMap = {}
    local captureCount = 0
    local autoArg = 1
    local i = 1
    local length
    local ch
    local nextCh
    local rest
    local s
    local e
    local position
    local kind
    local argIndex

    if type(formatText) ~= "string" or formatText == "" then
        return nil, nil, 0
    end

    length = strlen(formatText)
    while i <= length do
        ch = strsub(formatText, i, i)
        if ch == "%" then
            nextCh = strsub(formatText, i + 1, i + 1)
            if nextCh == "%" then
                pattern = pattern .. "%%"
                i = i + 2
            else
                rest = strsub(formatText, i)
                s, e, position, kind = strfind(rest, "^%%(%d+)%$([sd])")
                if s then
                    argIndex = tonumber(position)
                    i = i + e
                elseif nextCh == "s" or nextCh == "d" then
                    kind = nextCh
                    argIndex = autoArg
                    autoArg = autoArg + 1
                    i = i + 2
                else
                    pattern = pattern .. "%%"
                    i = i + 1
                end

                if kind == "s" or kind == "d" then
                    captureCount = captureCount + 1
                    captureMap[captureCount] = argIndex
                    if kind == "s" then
                        pattern = pattern .. "(.+)"
                    else
                        -- Damage values are integers, but localized clients may
                        -- insert punctuation as a thousands separator.
                        pattern = pattern .. "([%d%.,]+)"
                    end
                    kind = nil
                end
            end
        else
            pattern = pattern .. EscapeLiteralChar(ch)
            i = i + 1
        end
    end

    return pattern, captureMap, captureCount
end

local function GetGlobalText(name)
    if type(getglobal) == "function" then
        return getglobal(name)
    end
    return nil
end

local function AddRule(bucket, globalName, targetArg, amountArg, sourceArg, spellArg)
    local formatText = GetGlobalText(globalName)
    local pattern
    local captureMap
    local captureCount

    if type(formatText) ~= "string" or formatText == "" then
        return
    end

    pattern, captureMap, captureCount = CompileFormat(formatText)
    if not pattern or captureCount <= 0 then
        return
    end

    tinsert(bucket, {
        name = globalName,
        pattern = pattern,
        captureMap = captureMap,
        captureCount = captureCount,
        targetArg = targetArg,
        amountArg = amountArg,
        sourceArg = sourceArg,
        spellArg = spellArg,
    })
end

local function ParseNumber(text)
    local digits
    if text == nil then
        return nil
    end
    digits = gsub(tostring(text), "[^%d]", "")
    if digits == "" then
        return nil
    end
    return tonumber(digits)
end

local function ParseRule(rule, message)
    local s
    local e
    local c1
    local c2
    local c3
    local c4
    local c5
    local captures
    local args = {}
    local i

    s, e, c1, c2, c3, c4, c5 = strfind(message, rule.pattern)
    if not s then
        return nil, nil, nil, nil
    end

    captures = { c1, c2, c3, c4, c5 }
    for i = 1, rule.captureCount do
        args[rule.captureMap[i]] = captures[i]
    end

    return args[rule.targetArg], ParseNumber(args[rule.amountArg]),
        rule.sourceArg and args[rule.sourceArg] or nil,
        rule.spellArg and args[rule.spellArg] or nil
end

local function ParseRules(rules, message)
    local i
    local targetName
    local amount
    local sourceName
    local spellName

    for i = 1, table.getn(rules) do
        targetName, amount, sourceName, spellName = ParseRule(rules[i], message)
        if amount and amount > 0 then
            return targetName, amount, sourceName, spellName
        end
    end
    return nil, nil, nil, nil
end

local function EscapeNamePattern(name)
    local result = ""
    local i
    local ch
    name = tostring(name or "")
    for i = 1, strlen(name) do
        ch = strsub(name, i, i)
        result = result .. EscapeLiteralChar(ch)
    end
    return result
end

local function ParseEnglishSelfDamage(message)
    local s
    local e
    local targetName
    local amount

    s, e, targetName, amount = strfind(message, "^You hit (.+) for ([%d,%.]+)")
    if not s then
        s, e, targetName, amount = strfind(message, "^You crit (.+) for ([%d,%.]+)")
    end
    if not s then
        s, e, targetName, amount = strfind(message, "^Your .+ hits (.+) for ([%d,%.]+)")
    end
    if not s then
        s, e, targetName, amount = strfind(message, "^Your .+ crits (.+) for ([%d,%.]+)")
    end
    if not s then
        s, e, targetName, amount = strfind(message, "^(.+) suffers ([%d,%.]+) .- damage from your .+")
    end

    if s then
        return targetName, ParseNumber(amount)
    end
    return nil, nil
end

local function ParseEnglishPetDamage(message, petName)
    local escaped = EscapeNamePattern(petName)
    local s
    local e
    local targetName
    local amount

    if escaped == "" then
        return nil, nil
    end

    s, e, targetName, amount = strfind(message, "^" .. escaped .. " hits (.+) for ([%d,%.]+)")
    if not s then
        s, e, targetName, amount = strfind(message, "^" .. escaped .. " crits (.+) for ([%d,%.]+)")
    end
    if not s then
        s, e, targetName, amount = strfind(message, "^" .. escaped .. "'s .+ hits (.+) for ([%d,%.]+)")
    end
    if not s then
        s, e, targetName, amount = strfind(message, "^" .. escaped .. "'s .+ crits (.+) for ([%d,%.]+)")
    end

    if s then
        return targetName, ParseNumber(amount)
    end
    return nil, nil
end

local function ParseEnglishHeal(message)
    local s
    local e
    local amount

    s, e, amount = strfind(message, "^Your .+ heals .- for ([%d,%.]+)")
    if not s then
        s, e, amount = strfind(message, "^You gain ([%d,%.]+) health from .+")
    end
    if s then
        return ParseNumber(amount)
    end
    return nil
end

local function NamesEqual(a, b)
    if not a or not b then
        return false
    end
    return tostring(a) == tostring(b)
end

local function GetPlayerClass()
    local localized
    local classToken
    if type(UnitClass) ~= "function" then
        return "UNKNOWN"
    end
    localized, classToken = UnitClass("player")
    if classToken and classToken ~= "" then
        return string.upper(classToken)
    end
    if localized and localized ~= "" then
        return string.upper(localized)
    end
    return "UNKNOWN"
end

local function GetActiveFormTexture()
    local count
    local i
    local texture
    local name
    local active

    if type(GetNumShapeshiftForms) ~= "function" or type(GetShapeshiftFormInfo) ~= "function" then
        return nil, nil
    end

    count = GetNumShapeshiftForms() or 0
    for i = 1, count do
        texture, name, active = GetShapeshiftFormInfo(i)
        if active then
            return texture, name
        end
    end
    return nil, nil
end

-- Conservative visible-state modifiers. Hidden flat spell threat and many
-- talent/buff modifiers are intentionally not guessed; this is why the result
-- is displayed as an estimate rather than exact server threat.
function Local:GetPlayerThreatModifier()
    local classToken = GetPlayerClass()
    local texture
    local formName
    local formText

    if classToken == "ROGUE" then
        return 0.71
    end

    if classToken == "WARRIOR" or classToken == "DRUID" then
        texture, formName = GetActiveFormTexture()
        formText = strlower(tostring(texture or "") .. " " .. tostring(formName or ""))

        if classToken == "WARRIOR" then
            if strfind(formText, "defensive", 1, 1) then
                return 1.30
            end
            return 0.80
        end

        if strfind(formText, "bear", 1, 1) then
            return 1.30
        elseif strfind(formText, "cat", 1, 1) then
            return 0.71
        end
    end

    return 1.00
end

function Local:BuildRules()
    self.selfDamageRules = {}
    self.petDamageRules = {}
    self.healRules = {}

    AddRule(self.selfDamageRules, "COMBATHITSELFOTHER", 1, 2, nil, nil)
    AddRule(self.selfDamageRules, "COMBATHITSCHOOLSELFOTHER", 1, 2, nil, nil)
    AddRule(self.selfDamageRules, "COMBATHITCRITSELFOTHER", 1, 2, nil, nil)
    AddRule(self.selfDamageRules, "COMBATHITCRITSCHOOLSELFOTHER", 1, 2, nil, nil)
    AddRule(self.selfDamageRules, "SPELLLOGSELFOTHER", 2, 3, nil, 1)
    AddRule(self.selfDamageRules, "SPELLLOGSCHOOLSELFOTHER", 2, 3, nil, 1)
    AddRule(self.selfDamageRules, "SPELLLOGCRITSELFOTHER", 2, 3, nil, 1)
    AddRule(self.selfDamageRules, "SPELLLOGCRITSCHOOLSELFOTHER", 2, 3, nil, 1)
    AddRule(self.selfDamageRules, "PERIODICAURADAMAGESELFOTHER", 1, 2, nil, 4)
    AddRule(self.selfDamageRules, "DAMAGESHIELDSELFOTHER", 3, 1, nil, nil)

    -- Spell messages ("Pet's Bite hits ...") must be checked before the
    -- generic melee format, whose first %s would otherwise greedily consume
    -- "Pet's Bite" as though it were the source name.
    AddRule(self.petDamageRules, "SPELLLOGOTHEROTHER", 3, 4, 1, 2)
    AddRule(self.petDamageRules, "SPELLLOGSCHOOLOTHEROTHER", 3, 4, 1, 2)
    AddRule(self.petDamageRules, "SPELLLOGCRITOTHEROTHER", 3, 4, 1, 2)
    AddRule(self.petDamageRules, "SPELLLOGCRITSCHOOLOTHEROTHER", 3, 4, 1, 2)
    AddRule(self.petDamageRules, "COMBATHITOTHEROTHER", 2, 3, 1, nil)
    AddRule(self.petDamageRules, "COMBATHITSCHOOLOTHEROTHER", 2, 3, 1, nil)
    AddRule(self.petDamageRules, "COMBATHITCRITOTHEROTHER", 2, 3, 1, nil)
    AddRule(self.petDamageRules, "COMBATHITCRITSCHOOLOTHEROTHER", 2, 3, 1, nil)
    AddRule(self.petDamageRules, "PERIODICAURADAMAGEOTHEROTHER", 1, 2, 4, 5)

    AddRule(self.healRules, "HEALEDSELFSELF", nil, 2, nil, 1)
    AddRule(self.healRules, "HEALEDCRITSELFSELF", nil, 2, nil, 1)
    AddRule(self.healRules, "HEALEDSELFOTHER", 2, 3, nil, 1)
    AddRule(self.healRules, "HEALEDCRITSELFOTHER", 2, 3, nil, 1)
    AddRule(self.healRules, "PERIODICAURAHEALSELFSELF", nil, 1, nil, 2)
    AddRule(self.healRules, "PERIODICAURAHEALSELFOTHER", 1, 2, nil, 3)
end

function Local:Initialize()
    if self.initialized then
        return
    end
    self:BuildRules()
    self.targetKey = OT.currentTargetKey
    self.targetName = OT.currentTargetName
    self.initialized = true
end

function Local:ResetSession()
    self.targetKey = nil
    self.targetName = nil
    self.active = false
    self.entries = {}
    self.lastData = 0
    self.eventCount = 0
    self.parseCount = 0
    self.unmatchedCount = 0
    self.lastMessage = nil
end

function Local:ResetTarget(targetKey, targetName)
    self.targetKey = targetKey
    self.targetName = targetName
    self.entries = {}
    self.lastData = 0
    self.eventCount = 0
    if self.active and targetKey and targetName then
        self:EnsureEntries()
    end
end

function Local:StartCombat()
    self.active = true
    self.targetKey = OT.currentTargetKey
    self.targetName = OT.currentTargetName
    self.entries = {}
    self.lastData = GetTime()
    self.eventCount = 0
    self:EnsureEntries()
end

function Local:EndCombat()
    self.active = false
    self.entries = {}
    self.lastData = 0
    self.eventCount = 0
end

function Local:CanActivate()
    if not OT.db or not OT.db.soloFallback then
        return false
    end
    if OT:GetGroupSize() > 0 or not OT.inCombat then
        return false
    end

    -- Keep the stored fight target usable through the killing blow. A 1.12
    -- client can mark the selected unit dead before the final combat message is
    -- dispatched, even though currentTargetKey/currentTargetName still belong
    -- to the fight that is about to be finalized.
    return OT.currentTargetKey ~= nil and OT.currentTargetName ~= nil
end

function Local:EnsureCombatTracking(fromCombatEvent)
    if not OT.db or not OT.db.soloFallback or OT:GetGroupSize() > 0 then
        return false
    end

    -- A combat-log message is itself authoritative evidence that a fight has
    -- begun. This matters for fast melee openers and stealth transitions where
    -- UnitAffectingCombat can lag behind the first rogue attack on old clients.
    if fromCombatEvent and not OT.inCombat and OT.currentTargetKey and OT.currentTargetName then
        if OT.NoteCombatEvidence then
            OT:NoteCombatEvidence("local combat message")
        end
        if OT.BeginCombatTracking then
            OT:BeginCombatTracking()
        else
            OT.inCombat = true
        end
    elseif not OT.inCombat and OT.IsGroupInCombat and OT:IsGroupInCombat() then
        if OT.BeginCombatTracking then
            OT:BeginCombatTracking()
        else
            OT.inCombat = true
        end
    end

    if OT.inCombat and not self.active then
        self:StartCombat()
    end

    return self:CanActivate() and self.active
end

function Local:IsUsable()
    if not self:CanActivate() or not self.active then
        return false
    end
    return self.targetKey == OT.currentTargetKey and self.targetName == OT.currentTargetName
end

function Local:EnsureEntry(name, classToken, isPet, owner)
    local entry
    if not name or name == "" then
        return nil
    end
    entry = self.entries[name]
    if not entry then
        entry = {
            name = name,
            class = classToken or "UNKNOWN",
            isPet = isPet and true or false,
            owner = owner,
            threat = 0,
            events = 0,
        }
        self.entries[name] = entry
    end
    return entry
end

function Local:EnsureEntries()
    local playerName = UnitName("player")
    local petName
    self:EnsureEntry(playerName, GetPlayerClass(), false, nil)
    if OT.db and OT.db.showPets and UnitExists("pet") then
        petName = UnitName("pet")
        self:EnsureEntry(petName, "PET", true, playerName)
    end
end

function Local:AddPlayerDamage(amount)
    local playerName
    local entry
    local modifier

    if not self:IsUsable() or not amount or amount <= 0 then
        return false
    end

    playerName = UnitName("player")
    entry = self:EnsureEntry(playerName, GetPlayerClass(), false, nil)
    if not entry then
        return false
    end

    modifier = self:GetPlayerThreatModifier()
    entry.threat = (entry.threat or 0) + amount * modifier
    entry.events = (entry.events or 0) + 1
    self.lastData = GetTime()
    self.eventCount = self.eventCount + 1
    return true
end

function Local:AddPlayerHealing(amount)
    local playerName
    local entry
    local modifier

    if not self:IsUsable() or not amount or amount <= 0 then
        return false
    end

    playerName = UnitName("player")
    entry = self:EnsureEntry(playerName, GetPlayerClass(), false, nil)
    if not entry then
        return false
    end

    modifier = self:GetPlayerThreatModifier()
    entry.threat = (entry.threat or 0) + amount * 0.50 * modifier
    entry.events = (entry.events or 0) + 1
    self.lastData = GetTime()
    self.eventCount = self.eventCount + 1
    return true
end

function Local:AddPetDamage(amount)
    local playerName
    local petName
    local entry

    if not self:IsUsable() or not OT.db.showPets or not amount or amount <= 0 then
        return false
    end
    if not UnitExists("pet") then
        return false
    end

    playerName = UnitName("player")
    petName = UnitName("pet")
    entry = self:EnsureEntry(petName, "PET", true, playerName)
    if not entry then
        return false
    end

    entry.threat = (entry.threat or 0) + amount
    entry.events = (entry.events or 0) + 1
    self.lastData = GetTime()
    self.eventCount = self.eventCount + 1
    return true
end

function Local:HandleEvent(eventName, message, combatEvidence)
    local targetName
    local amount
    local sourceName
    local spellName
    local petName

    if type(message) ~= "string" or message == "" then
        return false
    end
    if not self:EnsureCombatTracking(combatEvidence and true or false) or not self:IsUsable() then
        return false
    end

    self.lastMessage = message

    if eventName == "CHAT_MSG_COMBAT_SELF_HITS"
        or eventName == "CHAT_MSG_SPELL_SELF_DAMAGE"
        or eventName == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE"
        or eventName == "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF"
        or eventName == "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_OTHERS" then
        targetName, amount, sourceName, spellName = ParseRules(self.selfDamageRules, message)
        if not amount then
            targetName, amount = ParseEnglishSelfDamage(message)
        end
        if amount and NamesEqual(targetName, self.targetName) then
            self.parseCount = self.parseCount + 1
            return self:AddPlayerDamage(amount)
        end
    end

    if eventName == "CHAT_MSG_COMBAT_PET_HITS"
        or eventName == "CHAT_MSG_SPELL_PET_DAMAGE"
        or eventName == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE" then
        petName = UnitExists("pet") and UnitName("pet") or nil
        targetName, amount, sourceName, spellName = ParseRules(self.petDamageRules, message)
        if not amount then
            targetName, amount = ParseEnglishPetDamage(message, petName)
            sourceName = petName
        end
        if amount and NamesEqual(targetName, self.targetName)
            and (not sourceName or NamesEqual(sourceName, petName)) then
            self.parseCount = self.parseCount + 1
            return self:AddPetDamage(amount)
        end
    end

    if eventName == "CHAT_MSG_SPELL_SELF_BUFF"
        or eventName == "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS"
        or eventName == "CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF"
        or eventName == "CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS" then
        targetName, amount, sourceName, spellName = ParseRules(self.healRules, message)
        if not amount then
            amount = ParseEnglishHeal(message)
        end
        if amount then
            self.parseCount = self.parseCount + 1
            return self:AddPlayerHealing(amount)
        end
    end

    self.unmatchedCount = (self.unmatchedCount or 0) + 1
    return false
end

function Local:Poll()
    self:EnsureCombatTracking(false)
    if not self.active and self:CanActivate() then
        self:StartCombat()
    elseif self.active and self:CanActivate()
        and (self.targetKey ~= OT.currentTargetKey or self.targetName ~= OT.currentTargetName) then
        self:ResetTarget(OT.currentTargetKey, OT.currentTargetName)
    end

    if self:IsUsable() then
        self:EnsureEntries()
        if self.lastData <= 0 then
            self.lastData = GetTime()
        end
        return true
    end
    return false
end

local function LocalSort(a, b)
    if (a.threat or 0) == (b.threat or 0) then
        return tostring(a.name or "") < tostring(b.name or "")
    end
    return (a.threat or 0) > (b.threat or 0)
end

function Local:GetRows()
    local rows = {}
    local playerName
    local targetTargetName
    local name
    local entry
    local row
    local status

    if not self:IsUsable() then
        return rows
    end

    self:EnsureEntries()
    playerName = UnitName("player")
    if UnitExists("targettarget") then
        targetTargetName = UnitName("targettarget")
    end

    for name, entry in pairs(self.entries) do
        if entry and (not entry.isPet or OT.db.showPets) then
            status = nil
            if OT.GetNativeThreatStatus and entry.isPet and UnitExists("pet") and name == UnitName("pet") then
                status = OT:GetNativeThreatStatus("pet")
            elseif OT.GetNativeThreatStatus and not entry.isPet and name == playerName then
                status = OT:GetNativeThreatStatus("player")
            end

            row = {
                name = name,
                unit = entry.isPet and "pet" or "player",
                class = entry.class,
                isPet = entry.isPet,
                owner = entry.owner,
                tank = NamesEqual(name, targetTargetName) or ((tonumber(status) or 0) >= 2),
                status = tonumber(status) or 0,
                threat = entry.threat or 0,
                absoluteThreat = entry.threat or 0,
                rawPercent = nil,
                pullPercent = nil,
                melee = nil,
                source = "LOCAL",
                exact = false,
                estimated = true,
                localEvents = entry.events or 0,
            }
            tinsert(rows, row)
        end
    end

    tsort(rows, LocalSort)
    return rows
end

function Local:GetDiagnostics()
    local age
    if self.lastData and self.lastData > 0 then
        age = string.format("%.1fs", GetTime() - self.lastData)
    else
        age = "none"
    end
    return "fallback " .. ((OT.db and OT.db.soloFallback) and "on" or "off")
        .. ", patterns " .. tostring(table.getn(self.selfDamageRules)
            + table.getn(self.petDamageRules) + table.getn(self.healRules))
        .. ", fight events " .. tostring(self.eventCount or 0)
        .. ", matched " .. tostring(self.parseCount or 0)
        .. ", unmatched " .. tostring(self.unmatchedCount or 0)
        .. ", last " .. age
end

if MSThreat then
    MSThreat.localProviderLoaded = true
    MSThreat.loadStage = "local provider loaded"
end
