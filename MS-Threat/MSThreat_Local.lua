-- MSThreat_Local.lua
-- Local combat-log threat estimator for World of Warcraft 1.12.1.
--
-- Exact native and server APIs remain preferred. When those sources are not
-- available, this module can estimate solo or grouped current-target threat from
-- combat messages visible to this client. Values are deliberately marked as
-- estimated because the 1.12.1 combat log does not expose every hidden flat
-- threat value, talent modifier, threat reset, or unambiguous unit GUID.

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
Local.groupDamageRules = {}
Local.healRules = {}
Local.groupHealRules = {}
Local.groupParseCount = 0
Local.groupRejectedCount = 0
Local.lastScope = "none"

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

local function NormalizeName(name)
    local normalized
    local dashAt
    if not name then
        return nil
    end
    normalized = strlower(tostring(name))
    normalized = gsub(normalized, "^%s+", "")
    normalized = gsub(normalized, "%s+$", "")
    dashAt = strfind(normalized, "-", 1, 1)
    if dashAt and dashAt > 1 then
        normalized = strsub(normalized, 1, dashAt - 1)
    end
    if normalized == "" then
        return nil
    end
    return normalized
end

local function NamesEqual(a, b)
    local first = NormalizeName(a)
    local second = NormalizeName(b)
    return first ~= nil and second ~= nil and first == second
end

local function ParseEnglishGroupDamage(message)
    local s
    local sourceName
    local targetName
    local amount

    s, _, sourceName, targetName, amount = strfind(message, "^(.+) hits (.+) for ([%d,%.]+)")
    if not s then
        s, _, sourceName, targetName, amount = strfind(message, "^(.+) crits (.+) for ([%d,%.]+)")
    end
    if not s then
        s, _, sourceName, targetName, amount = strfind(message, "^(.+)'s .+ hits (.+) for ([%d,%.]+)")
    end
    if not s then
        s, _, sourceName, targetName, amount = strfind(message, "^(.+)'s .+ crits (.+) for ([%d,%.]+)")
    end
    if s then
        return targetName, ParseNumber(amount), sourceName
    end
    return nil, nil, nil
end

local function ParseEnglishGroupHeal(message)
    local s
    local sourceName
    local targetName
    local amount

    s, _, sourceName, targetName, amount = strfind(message, "^(.+)'s .+ heals (.+) for ([%d,%.]+)")
    if not s then
        s, _, sourceName, targetName, amount = strfind(message, "^(.+)'s .+ critically heals (.+) for ([%d,%.]+)")
    end
    if not s then
        s, _, targetName, amount, sourceName = strfind(message, "^(.+) gains ([%d,%.]+) health from (.+)'s .+")
    end
    if s then
        return targetName, ParseNumber(amount), sourceName
    end
    return nil, nil, nil
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
    self.groupDamageRules = {}
    self.healRules = {}
    self.groupHealRules = {}

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

    -- Other-to-other formats carry both source and target. They are used for
    -- the player's pet and for visible party/raid member combat messages.
    AddRule(self.groupDamageRules, "SPELLLOGOTHEROTHER", 3, 4, 1, 2)
    AddRule(self.groupDamageRules, "SPELLLOGSCHOOLOTHEROTHER", 3, 4, 1, 2)
    AddRule(self.groupDamageRules, "SPELLLOGCRITOTHEROTHER", 3, 4, 1, 2)
    AddRule(self.groupDamageRules, "SPELLLOGCRITSCHOOLOTHEROTHER", 3, 4, 1, 2)
    AddRule(self.groupDamageRules, "COMBATHITOTHEROTHER", 2, 3, 1, nil)
    AddRule(self.groupDamageRules, "COMBATHITSCHOOLOTHEROTHER", 2, 3, 1, nil)
    AddRule(self.groupDamageRules, "COMBATHITCRITOTHEROTHER", 2, 3, 1, nil)
    AddRule(self.groupDamageRules, "COMBATHITCRITSCHOOLOTHEROTHER", 2, 3, 1, nil)
    AddRule(self.groupDamageRules, "PERIODICAURADAMAGEOTHEROTHER", 1, 2, 4, 5)

    -- Keep a separate pet bucket for backwards-compatible diagnostics and for
    -- clients that route pet messages through the same localized formats.
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

    AddRule(self.groupHealRules, "HEALEDOTHERSELF", nil, 3, 1, 2)
    AddRule(self.groupHealRules, "HEALEDCRITOTHERSELF", nil, 3, 1, 2)
    AddRule(self.groupHealRules, "HEALEDOTHEROTHER", 3, 4, 1, 2)
    AddRule(self.groupHealRules, "HEALEDCRITOTHEROTHER", 3, 4, 1, 2)
    AddRule(self.groupHealRules, "PERIODICAURAHEALOTHERSELF", nil, 2, 3, 4)
    AddRule(self.groupHealRules, "PERIODICAURAHEALOTHEROTHER", 1, 2, 3, 4)
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
    self.groupParseCount = 0
    self.groupRejectedCount = 0
    self.lastScope = "none"
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

function Local:IsScopeEnabled()
    if not OT.db then
        return false
    end
    if OT:GetGroupSize() > 0 then
        return OT.db.groupFallback and true or false
    end
    return OT.db.soloFallback and true or false
end

function Local:CanActivate()
    if not self:IsScopeEnabled() or not OT.inCombat then
        return false
    end

    -- Keep the stored fight target usable through the killing blow. A 1.12.1
    -- client can mark the selected unit dead before the final combat message.
    return OT.currentTargetKey ~= nil and OT.currentTargetName ~= nil
end

function Local:EnsureCombatTracking(fromCombatEvent)
    if not self:IsScopeEnabled() then
        return false
    end

    -- A current-target combat message is authoritative evidence that the fight
    -- has begun. This covers fast rogue openers and group attacks that arrive
    -- before UnitAffectingCombat settles on an old client.
    if fromCombatEvent and not OT.inCombat and OT.currentTargetKey and OT.currentTargetName then
        if OT.NoteCombatEvidence then
            OT:NoteCombatEvidence("current-target combat message")
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

function Local:EnsureEntry(name, classToken, isPet, owner, unitToken)
    local entry
    if not name or name == "" then
        return nil
    end
    entry = self.entries[name]
    if not entry then
        entry = {
            name = name,
            unit = unitToken,
            class = classToken or "UNKNOWN",
            isPet = isPet and true or false,
            owner = owner,
            threat = 0,
            events = 0,
        }
        self.entries[name] = entry
    else
        if unitToken then
            entry.unit = unitToken
        end
        if classToken and classToken ~= "UNKNOWN" then
            entry.class = classToken
        end
        if owner then
            entry.owner = owner
        end
        if isPet then
            entry.isPet = true
        end
    end
    return entry
end

function Local:EnsureEntries()
    local i
    local rosterEntry
    local playerName = UnitName("player")

    if OT.GetGroupSize and OT:GetGroupSize() > 0 and OT.rosterUnits then
        for i = 1, table.getn(OT.rosterUnits) do
            rosterEntry = OT.rosterUnits[i]
            if rosterEntry and (not rosterEntry.isPet or (OT.db and OT.db.showPets)) then
                self:EnsureEntry(rosterEntry.name, rosterEntry.class, rosterEntry.isPet,
                    rosterEntry.owner, rosterEntry.unit)
            end
        end
    else
        self:EnsureEntry(playerName, GetPlayerClass(), false, nil, "player")
        if OT.db and OT.db.showPets and UnitExists("pet") then
            self:EnsureEntry(UnitName("pet"), "PET", true, playerName, "pet")
        end
    end
end

function Local:ResolveRosterSource(sourceName)
    local rosterEntry
    if not sourceName then
        return nil
    end
    if OT.ResolveRosterEntry then
        rosterEntry = OT:ResolveRosterEntry(sourceName)
    end
    if not rosterEntry then
        return nil
    end
    if rosterEntry.isPet and OT.db and not OT.db.showPets then
        return nil
    end
    return rosterEntry
end

function Local:GetEntryThreatModifier(entry)
    if entry and entry.unit == "player" then
        return self:GetPlayerThreatModifier()
    end
    -- Other players' stance, talents, buffs, and hidden spell threat are not
    -- fully visible. Keep their baseline at 1.0 and mark the provider estimated.
    return 1.00
end

function Local:AddSourceDamage(sourceName, amount, sourceEntry)
    local rosterEntry = sourceEntry or self:ResolveRosterSource(sourceName)
    local entry
    local modifier

    if not self:IsUsable() or not amount or amount <= 0 then
        return false
    end
    if not rosterEntry then
        self.groupRejectedCount = (self.groupRejectedCount or 0) + 1
        return false
    end

    entry = self:EnsureEntry(rosterEntry.name, rosterEntry.class, rosterEntry.isPet,
        rosterEntry.owner, rosterEntry.unit)
    if not entry then
        return false
    end

    modifier = self:GetEntryThreatModifier(entry)
    entry.threat = (entry.threat or 0) + amount * modifier
    entry.events = (entry.events or 0) + 1
    self.lastData = GetTime()
    self.eventCount = self.eventCount + 1
    return true
end

function Local:AddSourceHealing(sourceName, amount, sourceEntry)
    local rosterEntry = sourceEntry or self:ResolveRosterSource(sourceName)
    local entry
    local modifier

    if not self:IsUsable() or not amount or amount <= 0 then
        return false
    end
    if not rosterEntry then
        self.groupRejectedCount = (self.groupRejectedCount or 0) + 1
        return false
    end

    entry = self:EnsureEntry(rosterEntry.name, rosterEntry.class, rosterEntry.isPet,
        rosterEntry.owner, rosterEntry.unit)
    if not entry then
        return false
    end

    modifier = self:GetEntryThreatModifier(entry)
    entry.threat = (entry.threat or 0) + amount * 0.50 * modifier
    entry.events = (entry.events or 0) + 1
    self.lastData = GetTime()
    self.eventCount = self.eventCount + 1
    return true
end

function Local:AddPlayerDamage(amount)
    local playerName = UnitName("player")
    local rosterEntry = OT.ResolveRosterEntry and OT:ResolveRosterEntry(playerName) or nil
    if not rosterEntry then
        rosterEntry = { name = playerName, unit = "player", class = GetPlayerClass(), isPet = false }
    end
    return self:AddSourceDamage(playerName, amount, rosterEntry)
end

function Local:AddPlayerHealing(amount)
    local playerName = UnitName("player")
    local rosterEntry = OT.ResolveRosterEntry and OT:ResolveRosterEntry(playerName) or nil
    if not rosterEntry then
        rosterEntry = { name = playerName, unit = "player", class = GetPlayerClass(), isPet = false }
    end
    return self:AddSourceHealing(playerName, amount, rosterEntry)
end

function Local:AddPetDamage(amount)
    local playerName
    local petName
    local rosterEntry

    if not OT.db or not OT.db.showPets or not UnitExists("pet") then
        return false
    end
    playerName = UnitName("player")
    petName = UnitName("pet")
    rosterEntry = OT.ResolveRosterEntry and OT:ResolveRosterEntry(petName) or nil
    if not rosterEntry then
        rosterEntry = { name = petName, unit = "pet", class = "PET", isPet = true, owner = playerName }
    end
    return self:AddSourceDamage(petName, amount, rosterEntry)
end

function Local:HandleEvent(eventName, message, combatEvidence)
    local targetName
    local amount
    local sourceName
    local spellName
    local petName
    local rosterEntry
    local playerName
    local isGroupDamage
    local isGroupHeal
    local preParsedGroupDamage = false

    if type(message) ~= "string" or message == "" then
        return false
    end
    playerName = UnitName("player")
    isGroupDamage = eventName == "CHAT_MSG_COMBAT_PARTY_HITS"
        or eventName == "CHAT_MSG_COMBAT_FRIENDLYPLAYER_HITS"
        or eventName == "CHAT_MSG_SPELL_PARTY_DAMAGE"
        or eventName == "CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE"
        or eventName == "CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE"
        or eventName == "CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE"

    -- Group combat events can arrive before the local player or target combat
    -- flags settle. Parse the source and target first, and only latch combat when
    -- the message actually belongs to the selected target.
    if isGroupDamage and not OT.inCombat and OT:GetGroupSize() > 0
        and OT.db and OT.db.groupFallback then
        targetName, amount, sourceName, spellName = ParseRules(self.groupDamageRules, message)
        if not amount then
            targetName, amount, sourceName = ParseEnglishGroupDamage(message)
        end
        rosterEntry = self:ResolveRosterSource(sourceName)
        if amount and rosterEntry and rosterEntry.unit ~= "player"
            and NamesEqual(targetName, OT.currentTargetName) then
            preParsedGroupDamage = true
            if OT.NoteCombatEvidence then
                OT:NoteCombatEvidence("current-target group combat message")
            end
            if OT.BeginCombatTracking then
                OT:BeginCombatTracking()
            else
                OT.inCombat = true
            end
        end
    end

    if not self:EnsureCombatTracking(combatEvidence and true or preParsedGroupDamage) or not self:IsUsable() then
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
            self.lastScope = "self damage"
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
            self.lastScope = "pet damage"
            return self:AddPetDamage(amount)
        end
    end

    if isGroupDamage and OT:GetGroupSize() > 0 and OT.db and OT.db.groupFallback then
        if not preParsedGroupDamage then
            targetName, amount, sourceName, spellName = ParseRules(self.groupDamageRules, message)
            if not amount then
                targetName, amount, sourceName = ParseEnglishGroupDamage(message)
            end
            rosterEntry = self:ResolveRosterSource(sourceName)
        end
        -- Own damage is handled by SELF events; do not count a duplicated OTHER
        -- representation if a modified client emits both channels.
        if amount and rosterEntry and rosterEntry.unit ~= "player"
            and NamesEqual(targetName, self.targetName) then
            self.parseCount = self.parseCount + 1
            self.groupParseCount = self.groupParseCount + 1
            self.lastScope = "group damage"
            return self:AddSourceDamage(sourceName, amount, rosterEntry)
        end
    end

    if eventName == "CHAT_MSG_SPELL_SELF_BUFF"
        or eventName == "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS" then
        targetName, amount, sourceName, spellName = ParseRules(self.healRules, message)
        if not amount then
            amount = ParseEnglishHeal(message)
        end
        if amount then
            self.parseCount = self.parseCount + 1
            self.lastScope = "self healing"
            return self:AddPlayerHealing(amount)
        end
    end

    isGroupHeal = eventName == "CHAT_MSG_SPELL_PARTY_BUFF"
        or eventName == "CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF"
        or eventName == "CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS"
        or eventName == "CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS"

    if isGroupHeal and OT:GetGroupSize() > 0 and OT.db and OT.db.groupFallback then
        targetName, amount, sourceName, spellName = ParseRules(self.groupHealRules, message)
        if not amount then
            targetName, amount, sourceName = ParseEnglishGroupHeal(message)
        end
        rosterEntry = self:ResolveRosterSource(sourceName)
        if amount and rosterEntry and not NamesEqual(rosterEntry.name, playerName) then
            self.parseCount = self.parseCount + 1
            self.groupParseCount = self.groupParseCount + 1
            self.lastScope = "group healing"
            return self:AddSourceHealing(sourceName, amount, rosterEntry)
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
                unit = entry.unit,
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
    local grouped = OT.GetGroupSize and OT:GetGroupSize() > 0
    local enabled
    if self.lastData and self.lastData > 0 then
        age = string.format("%.1fs", GetTime() - self.lastData)
    else
        age = "none"
    end
    if grouped then
        enabled = OT.db and OT.db.groupFallback
    else
        enabled = OT.db and OT.db.soloFallback
    end
    return "scope " .. (grouped and "group" or "solo")
        .. ", fallback " .. (enabled and "on" or "off")
        .. ", patterns " .. tostring(table.getn(self.selfDamageRules)
            + table.getn(self.petDamageRules) + table.getn(self.groupDamageRules)
            + table.getn(self.healRules) + table.getn(self.groupHealRules))
        .. ", fight events " .. tostring(self.eventCount or 0)
        .. ", group matched " .. tostring(self.groupParseCount or 0)
        .. ", rejected sources " .. tostring(self.groupRejectedCount or 0)
        .. ", matched " .. tostring(self.parseCount or 0)
        .. ", unmatched " .. tostring(self.unmatchedCount or 0)
        .. ", last " .. age .. " (" .. tostring(self.lastScope or "none") .. ")"
end

if MSThreat then
    MSThreat.localProviderLoaded = true
    MSThreat.loadStage = "local provider loaded"
end
