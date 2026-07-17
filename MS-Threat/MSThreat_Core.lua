-- MSThreat_Core.lua
-- Standalone current-target threat display for the World of Warcraft 1.12.1 client.
-- Exact native/server threat is always preferred. During ordinary solo combat,
-- when no exact numeric source is available, MS Threat can display a clearly
-- marked LOCAL EST value calculated only from this client's combat messages.
-- No peer addon is required for either path.

MSThreat = MSThreat or {}
OctoThreat = MSThreat -- Temporary runtime compatibility alias.
local OT = MSThreat

OT.name = "MSThreat"
OT.displayName = "MS Threat"
OT.publisher = "MoobStack"
OT.version = "1.0.7"
OT.interfaceVersion = 11200
OT.coreLoaded = true
OT.loadStage = "core file executing"
OT.loadError = nil

local floor = math.floor
local abs = math.abs
local min = math.min
local max = math.max
local tinsert = table.insert
local tremove = table.remove
local tsort = table.sort
local tconcat = table.concat
local strfind = string.find
local strsub = string.sub
local strlower = string.lower
local strlen = string.len
local tonumber = tonumber
local tostring = tostring
local type = type
local pairs = pairs
local pcall = pcall

local function Print(message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff55c8ffMS Threat:|r " .. tostring(message or ""))
    end
end

OT.Print = Print

local function CopyValue(value)
    local copy
    local k
    local v
    if type(value) ~= "table" then
        return value
    end
    copy = {}
    for k, v in pairs(value) do
        copy[k] = CopyValue(v)
    end
    return copy
end

local function ApplyDefaults(target, defaults)
    local k
    local v
    for k, v in pairs(defaults) do
        if target[k] == nil then
            target[k] = CopyValue(v)
        elseif type(v) == "table" and type(target[k]) == "table" then
            ApplyDefaults(target[k], v)
        end
    end
end

local function Round(value, decimals)
    local mult = 10 ^ (decimals or 0)
    return floor((value or 0) * mult + 0.5) / mult
end

local function Trim(text)
    text = tostring(text or "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function SplitPlain(text, delimiter)
    local result = {}
    local startAt = 1
    local foundAt
    local delimiterLength = strlen(delimiter)

    if not text or text == "" then
        return result
    end

    while true do
        foundAt = strfind(text, delimiter, startAt, 1)
        if not foundAt then
            tinsert(result, strsub(text, startAt))
            break
        end
        tinsert(result, strsub(text, startAt, foundAt - 1))
        startAt = foundAt + delimiterLength
    end

    return result
end

local function FormatNumber(value, abbreviate)
    local n = tonumber(value) or 0
    local sign = ""
    if n < 0 then
        sign = "-"
        n = abs(n)
    end

    if abbreviate then
        if n >= 1000000 then
            return sign .. string.format("%.2fm", n / 1000000)
        elseif n >= 10000 then
            return sign .. string.format("%.1fk", n / 1000)
        elseif n >= 1000 then
            return sign .. string.format("%.2fk", n / 1000)
        end
    end

    return sign .. tostring(floor(n + 0.5))
end

OT.FormatNumber = FormatNumber
OT.Round = Round

OT.defaults = {
    enabled = true,
    locked = false,
    hideOutOfCombat = true,
    hideWithoutTarget = true,
    showPets = true,
    alwaysShowPlayer = true,
    keepLastFight = true,
    soloFallback = true,
    autoRecover = true,
    recoveryDelay = 4.0,
    colorMode = "CLASS",
    showThreat = true,
    showPercent = true,
    showTPS = true,
    abbreviate = true,
    warningEnabled = true,
    warningSound = true,
    warningThreshold = 90,
    width = 300,
    headerHeight = 22,
    rowHeight = 18,
    rowSpacing = 1,
    maxRows = 20,
    scale = 1.0,
    alpha = 1.0,
    updateInterval = 0.20,
    serverInterval = 0.50,
    staleSeconds = 2.0,
    tpsWindow = 5.0,
    providerMode = "AUTO",
    firstRun = true,
    position = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 250,
        y = 120,
    },
}

OT.classColors = {
    WARRIOR = { 0.78, 0.61, 0.43 },
    MAGE = { 0.41, 0.80, 0.94 },
    ROGUE = { 1.00, 0.96, 0.41 },
    DRUID = { 1.00, 0.49, 0.04 },
    HUNTER = { 0.67, 0.83, 0.45 },
    SHAMAN = { 0.14, 0.35, 1.00 },
    PRIEST = { 1.00, 1.00, 1.00 },
    WARLOCK = { 0.58, 0.51, 0.79 },
    PALADIN = { 0.96, 0.55, 0.73 },
    PET = { 0.65, 0.65, 0.65 },
    UNKNOWN = { 0.70, 0.70, 0.70 },
}

OT.eventFrame = CreateFrame("Frame", "MSThreatEventFrame")
OT.rosterByName = {}
OT.rosterByNormalizedName = {}
OT.rosterUnits = {}
OT.nativeRows = {}
OT.serverRows = {}
OT.displayRows = {}
OT.history = {}
OT.fightPeaks = {}
OT.fightMaxTPS = {}
OT.fightWasEstimated = false
OT.fightProvider = nil
OT.currentTargetKey = nil
OT.currentTargetName = nil
OT.currentFightTarget = nil
OT.currentFightStarted = nil
OT.currentProvider = "NONE"
OT.currentProviderExact = false
OT.currentProviderAbsolute = false
OT.currentProviderEstimated = false
OT.lastProviderLabel = "NONE"
OT.nativeAvailable = false
OT.nativePercentAvailable = false
OT.nativeStatusAvailable = false
OT.nativeLastData = 0
OT.nativeHadAbsolute = false
OT.serverLastQuery = 0
OT.serverLastResponse = 0
OT.serverEverResponded = false
OT.serverResponseTargetKey = nil
OT.targetChangedAt = 0
OT.lastPoll = 0
OT.lastDisplayUpdate = 0
OT.initialized = false
OT.inCombat = false
OT.warningLatched = false
OT.warningFlashUntil = 0
OT.testUntil = 0
OT.lastError = nil
OT.lastProviderScan = 0
OT.groupSignature = nil
OT.pendingGroupRefreshAt = 0
OT.pendingGroupRefreshReason = nil
OT.lastGroupSignatureCheck = 0
OT.lastDataRefreshAt = 0
OT.lastDataRefreshReason = "startup"
OT.dataRefreshNoticeUntil = 0
OT.autoRecoveryCount = 0
OT.autoRecoveryArmed = true
OT.noDataSince = 0
OT.refreshingData = false
OT.pendingGroupForceRefresh = false
OT.lastCombatEvidenceAt = 0
OT.combatGraceSeconds = 2.50
OT.playerRegenEnabledAt = 0
OT.regenState = "UNKNOWN"
OT.lastRegenEventAt = 0
OT.lastCombatEvidenceReason = "none"
OT.serverQueryTargetName = nil
OT.serverPacketAccepted = 0
OT.serverPacketRejected = 0
OT.serverLastRejectReason = nil
OT.serverLastPacketAt = 0
OT.profileSchemaVersion = 1
OT.accountDB = nil
OT.profileKey = nil
OT.profileName = nil
OT.profileRealm = nil
OT.profileClass = nil
OT.profileCreatedAtLoad = false
OT.profileMigratedAtLoad = false
OT.legacyBridgeLoaded = false
OT.legacyImportedAtLoad = false
OT.legacyMigrationSourceVersion = "1.0.6"

-- WoW 1.12 embeds Lua 5.0. Lua 5.0 does not support forwarding
-- varargs with the Lua 5.1-style expression pcall(fn, ...). Keep this helper
-- fixed-arity so the complete core can compile before commands are registered.
local function SafeStringCall(fn, argument, hasArgument)
    local ok
    local value
    if type(fn) ~= "function" then
        return nil
    end
    if hasArgument then
        ok, value = pcall(fn, argument)
    else
        ok, value = pcall(fn)
    end
    if not ok or type(value) ~= "string" then
        return nil
    end
    value = Trim(value)
    if value == "" then
        return nil
    end
    return value
end

local function SafeTimestamp()
    local ok
    local value
    if type(time) ~= "function" then
        return 0
    end
    ok, value = pcall(time)
    if ok and tonumber(value) then
        return tonumber(value)
    end
    return 0
end


local function HasTableData(value, ignoredKey)
    local key
    if type(value) ~= "table" then
        return false
    end
    for key in pairs(value) do
        if key ~= ignoredKey then
            return true
        end
    end
    return false
end

local function CopyMissingKeys(target, source)
    local key
    local value
    if type(target) ~= "table" or type(source) ~= "table" then
        return
    end
    for key, value in pairs(source) do
        if target[key] == nil then
            target[key] = CopyValue(value)
        elseif type(target[key]) == "table" and type(value) == "table" then
            CopyMissingKeys(target[key], value)
        end
    end
end

function OT:MigrateLegacySavedVariables()
    local bridge = MSThreatLegacyMigration
    local legacy = type(OctoThreatDB) == "table" and OctoThreatDB or nil
    local marker

    if type(legacy) ~= "table" and type(bridge) == "table"
        and type(bridge.account) == "table" then
        legacy = bridge.account
    end

    if type(MSThreatDB) ~= "table" then
        MSThreatDB = {}
    end

    marker = MSThreatDB._moobStackMigration
    if type(marker) ~= "table" then
        marker = {}
    end

    if marker.octoThreat106 ~= 1 and type(legacy) == "table" then
        if not HasTableData(MSThreatDB, "_moobStackMigration") then
            MSThreatDB = CopyValue(legacy)
            if type(MSThreatDB) ~= "table" then
                MSThreatDB = {}
            end
        else
            CopyMissingKeys(MSThreatDB, legacy)
        end

        if type(MSThreatDB._moobStackMigration) ~= "table" then
            MSThreatDB._moobStackMigration = marker
        end
        MSThreatDB._moobStackMigration.octoThreat106 = 1
        MSThreatDB._moobStackMigration.completedBy = "MS Threat 1.0.7"
        MSThreatDB._moobStackMigration.sourceVersion = self.legacyMigrationSourceVersion
        MSThreatDB._moobStackMigration.completedAt = SafeTimestamp()
        self.legacyImportedAtLoad = true
    elseif type(MSThreatDB._moobStackMigration) ~= "table" then
        MSThreatDB._moobStackMigration = marker
    end

    self.legacyBridgeLoaded = type(bridge) == "table" and bridge.loaded == 1 and true or false
end

function OT:GetMigrationStatusText()
    local marker = type(MSThreatDB) == "table" and MSThreatDB._moobStackMigration or nil
    if self.legacyImportedAtLoad then
        return "legacy settings imported this session"
    end
    if type(marker) == "table" and marker.octoThreat106 == 1 then
        return "legacy migration complete"
    end
    if self.legacyBridgeLoaded then
        return "legacy bridge loaded; no legacy data required import"
    end
    return "native MoobStack profile"
end

function OT:GetCharacterProfileIdentity()
    local name = SafeStringCall(UnitName, "player", true)
    local realm
    local classToken
    local ok
    local localizedClass

    if not name then
        return nil
    end

    realm = SafeStringCall(GetRealmName, nil, false)
    if not realm then
        realm = SafeStringCall(GetCVar, "realmName", true)
    end
    if not realm then
        realm = "Unknown Realm"
    end

    if type(UnitClass) == "function" then
        ok, localizedClass, classToken = pcall(UnitClass, "player")
        if not ok then
            classToken = nil
        end
    end

    return realm .. "::" .. name, name, realm, classToken or localizedClass or "UNKNOWN"
end

function OT:BuildLegacyProfile(source)
    local profile = {}
    local key
    local found = false

    if type(source) ~= "table" then
        return nil
    end

    for key in pairs(self.defaults) do
        if source[key] ~= nil then
            profile[key] = CopyValue(source[key])
            found = true
        end
    end

    if not found then
        return nil
    end

    -- Last-fight history from the former shared database cannot be assigned to
    -- a character safely, so it is intentionally not activated in a profile.
    -- Provider selection is also character-sensitive. Normalize the migrated
    -- profile to Auto so a server-only choice made on one character cannot
    -- strand the first migrated character in WAIT while solo.
    ApplyDefaults(profile, self.defaults)
    profile.providerMode = "AUTO"
    profile.soloFallback = true
    profile.autoRecover = true
    return profile
end

function OT:EnsureAccountDatabase(currentKey)
    local existing
    local root
    local legacyProfile
    local migrationMarker
    local migrated = false

    self:MigrateLegacySavedVariables()
    existing = MSThreatDB
    migrationMarker = type(existing) == "table" and existing._moobStackMigration or nil

    if type(existing) == "table" and type(existing.profiles) == "table" then
        root = existing
    else
        root = {
            schemaVersion = self.profileSchemaVersion,
            profiles = {},
            profileInfo = {},
        }
        legacyProfile = self:BuildLegacyProfile(existing)
        if legacyProfile and currentKey then
            root.profiles[currentKey] = legacyProfile
            root.migratedFromSharedDB = true
            root.migratedAt = SafeTimestamp()
            migrated = true
        end
        if type(migrationMarker) == "table" then
            root._moobStackMigration = migrationMarker
        end
        MSThreatDB = root
    end

    if type(root.profiles) ~= "table" then
        root.profiles = {}
    end
    if type(root.profileInfo) ~= "table" then
        root.profileInfo = {}
    end
    root.schemaVersion = self.profileSchemaVersion
    self.accountDB = root
    return root, migrated
end

function OT:UpdateProfileMetadata()
    local info
    if not self.accountDB or not self.profileKey then
        return
    end
    if type(self.accountDB.profileInfo) ~= "table" then
        self.accountDB.profileInfo = {}
    end
    info = self.accountDB.profileInfo[self.profileKey]
    if type(info) ~= "table" then
        info = {}
        self.accountDB.profileInfo[self.profileKey] = info
    end
    info.name = self.profileName
    info.realm = self.profileRealm
    info.class = self.profileClass
    info.lastSeen = SafeTimestamp()
end

function OT:ActivateCurrentCharacterProfile()
    local key
    local name
    local realm
    local classToken
    local root
    local profile
    local created = false
    local migrated = false

    key, name, realm, classToken = self:GetCharacterProfileIdentity()
    if not key then
        return false, false, false
    end

    root, migrated = self:EnsureAccountDatabase(key)
    profile = root.profiles[key]
    if type(profile) ~= "table" then
        profile = CopyValue(self.defaults)
        root.profiles[key] = profile
        created = true
    else
        ApplyDefaults(profile, self.defaults)
    end

    self.profileKey = key
    self.profileName = name
    self.profileRealm = realm
    self.profileClass = classToken
    self.db = profile
    self.lastFight = profile.lastFight
    self:UpdateProfileMetadata()

    return true, created, migrated
end

function OT:GetProfileCount()
    local count = 0
    local key
    if self.accountDB and type(self.accountDB.profiles) == "table" then
        for key in pairs(self.accountDB.profiles) do
            count = count + 1
        end
    end
    return count
end

function OT:GetProfileLabel()
    if self.profileName and self.profileRealm then
        return self.profileName .. " @ " .. self.profileRealm
    end
    return self.profileName or self.profileKey or "unavailable"
end

function OT:PrintProfiles()
    local keys = {}
    local key
    local i
    local info
    local label

    if not self.accountDB or type(self.accountDB.profiles) ~= "table" then
        Print("No character profiles are available.")
        return
    end

    for key in pairs(self.accountDB.profiles) do
        tinsert(keys, key)
    end
    tsort(keys)
    Print("Active profile: " .. self:GetProfileLabel()
        .. " | saved profiles: " .. tostring(table.getn(keys)))
    for i = 1, table.getn(keys) do
        key = keys[i]
        info = self.accountDB.profileInfo and self.accountDB.profileInfo[key]
        if info and info.name then
            label = tostring(info.name) .. " @ " .. tostring(info.realm or "Unknown Realm")
        else
            label = tostring(key)
        end
        Print((key == self.profileKey and "* " or "  ") .. label)
    end
end

function OT:ResetProfileSessionState()
    self.rosterByName = {}
    self.rosterByNormalizedName = {}
    self.rosterUnits = {}
    self.nativeRows = {}
    self.serverRows = {}
    self.displayRows = {}
    self.history = {}
    self.fightPeaks = {}
    self.fightMaxTPS = {}
    self.fightWasEstimated = false
    self.fightProvider = nil
    self.currentTargetKey = nil
    self.currentTargetName = nil
    self.currentFightTarget = nil
    self.currentFightStarted = nil
    self.currentProvider = "NONE"
    self.currentProviderExact = false
    self.currentProviderAbsolute = false
    self.currentProviderEstimated = false
    self.lastProviderLabel = "NONE"
    self.nativeLastData = 0
    self.nativeHadAbsolute = false
    self.serverLastQuery = 0
    self.serverLastResponse = 0
    self.serverEverResponded = false
    self.serverResponseTargetKey = nil
    self.serverQueryTargetKey = nil
    self.serverQueryTargetName = nil
    self.targetChangedAt = 0
    self.lastPoll = 0
    self.lastDisplayUpdate = 0
    self.warningLatched = false
    self.warningFlashUntil = 0
    self.testUntil = 0
    self.lastError = nil
    self.lastProviderScan = 0
    self.groupSignature = nil
    self.pendingGroupRefreshAt = 0
    self.pendingGroupRefreshReason = nil
    self.pendingGroupForceRefresh = false
    self.lastGroupSignatureCheck = 0
    self.lastDataRefreshAt = 0
    self.lastDataRefreshReason = "character profile activated"
    self.dataRefreshNoticeUntil = 0
    self.autoRecoveryCount = 0
    self.autoRecoveryArmed = true
    self.noDataSince = 0
    self.refreshingData = false
    self.lastCombatEvidenceAt = 0
    self.playerRegenEnabledAt = 0
    self.regenState = "UNKNOWN"
    self.lastRegenEventAt = 0
    self.lastCombatEvidenceReason = "none"
    self.serverPacketAccepted = 0
    self.serverPacketRejected = 0
    self.serverLastRejectReason = nil
    self.serverLastPacketAt = 0
    self.lastFight = self.db and self.db.lastFight or nil

    if self.Local and self.Local.ResetSession then
        self.Local:ResetSession()
    elseif self.Local then
        self.Local.active = false
        self.Local.entries = {}
        self.Local.targetKey = nil
        self.Local.targetName = nil
        self.Local.lastData = 0
        self.Local.eventCount = 0
    end
end

function OT:EnsureActiveCharacterProfile()
    local key = self:GetCharacterProfileIdentity()
    local oldKey = self.profileKey
    local ok
    local created
    local migrated

    if not key then
        return false, false
    end
    if oldKey == key and self.db then
        self:UpdateProfileMetadata()
        return true, false
    end

    if self.initialized and oldKey then
        self:FinalizeFight("character changed")
    end

    ok, created, migrated = self:ActivateCurrentCharacterProfile()
    if not ok then
        return false, false
    end

    if self.initialized then
        self:ResetProfileSessionState()
        self:RefreshThreatData("character profile activated", false, false, false, true)
        if self.UI and self.UI.RestorePosition then
            self.UI:RestorePosition()
        end
        if self.UI and self.UI.ApplyAllSettings then
            self.UI:ApplyAllSettings()
        end
        Print("Activated character profile " .. self:GetProfileLabel() .. ". Threat providers were restarted.")
    end

    return true, true, created, migrated
end

local function NormalizeClassToken(classToken)
    local token = classToken
    if not token or token == "" then
        return "UNKNOWN"
    end
    token = string.upper(token)
    if OT.classColors[token] then
        return token
    end
    return "UNKNOWN"
end

function OT:GetClassColor(classToken)
    return self.classColors[NormalizeClassToken(classToken)] or self.classColors.UNKNOWN
end

local function NormalizeRosterName(name)
    local normalized = strlower(Trim(name or ""))
    local dashAt
    if normalized == "" then
        return nil
    end
    -- Some extended clients append a realm suffix to server-returned names.
    -- World of Warcraft normally uses one realm, but stripping the suffix makes roster
    -- matching resilient during character and group transitions.
    dashAt = strfind(normalized, "-", 1, 1)
    if dashAt and dashAt > 1 then
        normalized = strsub(normalized, 1, dashAt - 1)
    end
    return normalized
end

local function AddRosterUnit(unitToken, isPet, ownerName)
    local name
    local localizedClass
    local classToken
    local entry
    local normalizedName

    if not UnitExists(unitToken) then
        return
    end

    name = UnitName(unitToken)
    if not name or name == "" then
        return
    end

    -- Raid unit lists include the player. Since "player" is already added,
    -- avoid querying and displaying the same character twice.
    if not isPet and OT.rosterByName[name] and not OT.rosterByName[name].isPet then
        return
    end

    if isPet then
        classToken = "PET"
    else
        localizedClass, classToken = UnitClass(unitToken)
        classToken = NormalizeClassToken(classToken or localizedClass)
    end

    entry = {
        name = name,
        unit = unitToken,
        class = classToken,
        isPet = isPet and true or false,
        owner = ownerName,
    }

    tinsert(OT.rosterUnits, entry)
    if not OT.rosterByName[name] or not isPet then
        OT.rosterByName[name] = entry
    end
    normalizedName = NormalizeRosterName(name)
    if normalizedName and (not OT.rosterByNormalizedName[normalizedName] or not isPet) then
        OT.rosterByNormalizedName[normalizedName] = entry
    end
end

function OT:RebuildRoster()
    local i
    local ownerName

    -- Build fresh containers rather than reusing an array that may have a
    -- stale length boundary after party, raid, or pet roster changes.
    self.rosterByName = {}
    self.rosterByNormalizedName = {}
    self.rosterUnits = {}

    AddRosterUnit("player", false, nil)
    if self.db and self.db.showPets then
        AddRosterUnit("pet", true, UnitName("player"))
    end

    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            AddRosterUnit("raid" .. i, false, nil)
            if self.db and self.db.showPets then
                ownerName = UnitName("raid" .. i)
                AddRosterUnit("raidpet" .. i, true, ownerName)
            end
        end
    elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then
        for i = 1, GetNumPartyMembers() do
            AddRosterUnit("party" .. i, false, nil)
            if self.db and self.db.showPets then
                ownerName = UnitName("party" .. i)
                AddRosterUnit("partypet" .. i, true, ownerName)
            end
        end
    end
end

function OT:GetGroupSize()
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
        return GetNumRaidMembers()
    end
    if GetNumPartyMembers then
        return GetNumPartyMembers()
    end
    return 0
end

function OT:GetDistribution()
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
        return "RAID"
    end
    if GetNumPartyMembers and GetNumPartyMembers() > 0 then
        return "PARTY"
    end
    return nil
end

function OT:GetGroupSignature()
    local members = {}
    local distribution = "SOLO"
    local total = 1
    local count
    local i
    local name

    name = UnitName("player")
    if name and name ~= "" then
        tinsert(members, "P:" .. name)
    end
    if self.db and self.db.showPets and UnitExists("pet") then
        name = UnitName("pet")
        if name and name ~= "" then
            tinsert(members, "PET:" .. name)
        end
    end

    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
        distribution = "RAID"
        count = GetNumRaidMembers()
        total = count
        for i = 1, count do
            name = UnitName("raid" .. i)
            if name and name ~= "" then
                tinsert(members, "R:" .. name)
            end
        end
    elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then
        distribution = "PARTY"
        count = GetNumPartyMembers()
        total = count + 1
        for i = 1, count do
            name = UnitName("party" .. i)
            if name and name ~= "" then
                tinsert(members, "G:" .. name)
            end
        end
    end

    tsort(members)
    return distribution .. ":" .. tostring(total) .. ":" .. tconcat(members, ",")
end

function OT:ScheduleGroupRefresh(reason, forceRefresh, delay)
    self.pendingGroupRefreshAt = GetTime() + (tonumber(delay) or 0.35)
    self.pendingGroupRefreshReason = reason or "group roster changed"
    if forceRefresh then
        self.pendingGroupForceRefresh = true
    end
end

function OT:IsValidTarget()
    if not UnitExists("target") then
        return false
    end
    if UnitIsPlayer("target") then
        return false
    end
    if UnitIsDead("target") then
        return false
    end
    if UnitCanAttack and not UnitCanAttack("player", "target") then
        return false
    end
    return UnitName("target") ~= nil
end

function OT:GetTargetKey()
    local name
    local level
    local classification
    local guid
    local ok

    if not self:IsValidTarget() then
        return nil
    end

    name = UnitName("target") or "Unknown"

    if type(UnitGUID) == "function" then
        ok, guid = pcall(UnitGUID, "target")
        if ok and guid and guid ~= "" then
            return tostring(guid)
        end
    end

    level = UnitLevel("target") or -1
    classification = UnitClassification("target") or "normal"
    return name .. "#" .. tostring(level) .. "#" .. tostring(classification)
end

function OT:HasLiveCombatEvidence()
    local i
    local rosterEntry
    local unit

    if UnitAffectingCombat("player") then
        return true
    end
    if UnitExists("target") and UnitAffectingCombat("target") then
        return true
    end

    for i = 1, table.getn(self.rosterUnits) do
        rosterEntry = self.rosterUnits[i]
        if rosterEntry then
            unit = rosterEntry.unit
            if unit and UnitExists(unit) and UnitAffectingCombat(unit) then
                return true
            end
        end
    end

    return false
end

function OT:NoteCombatEvidence(reason)
    self.lastCombatEvidenceAt = GetTime()
    self.lastCombatEvidenceReason = reason or "combat evidence"
    if self.regenState ~= "COMBAT" then
        self.regenState = "EVIDENCE"
    end
end

function OT:IsGroupInCombat()
    local now = GetTime()
    if self:HasLiveCombatEvidence() then
        self.lastCombatEvidenceAt = now
        self.lastCombatEvidenceReason = "unit combat flag"
        return true
    end

    -- PLAYER_REGEN_DISABLED is the old client's authoritative combat-start
    -- event. Keep the fight active until PLAYER_REGEN_ENABLED instead of
    -- allowing a momentary false UnitAffectingCombat result (common around
    -- stealth, stance, target, and roster transitions) to tear providers down.
    if self.regenState == "COMBAT" then
        return true
    end

    -- A local combat message can arrive before PLAYER_REGEN_DISABLED. Latch it
    -- long enough for the client state to catch up and for fast rogue openers or
    -- killing blows to be recorded.
    if (self.inCombat or self.regenState == "EVIDENCE")
        and self.lastCombatEvidenceAt > 0
        and now - self.lastCombatEvidenceAt <= (self.combatGraceSeconds or 2.50) then
        return true
    end

    return false
end

function OT:GetNativeHoldSeconds()
    return max(2.50, (tonumber(self.db and self.db.updateInterval) or 0.20) * 8)
end

function OT:GetServerHoldSeconds()
    return max(4.00, tonumber(self.db and self.db.staleSeconds) or 2.00)
end

function OT:DetectProviders()
    self.nativeAvailable = type(UnitDetailedThreatSituation) == "function"
    self.nativePercentAvailable = type(GetThreatPercent) == "function"
    self.nativeStatusAvailable = type(UnitThreatSituation) == "function"
end

local function SafeDetailedThreat(unitToken)
    local ok
    local isTanking
    local status
    local scaledPercent
    local rawPercent
    local threatValue

    if type(UnitDetailedThreatSituation) ~= "function" then
        return nil, nil, nil, nil, nil
    end

    ok, isTanking, status, scaledPercent, rawPercent, threatValue =
        pcall(UnitDetailedThreatSituation, unitToken, "target")

    if not ok then
        OT.lastError = tostring(isTanking)
        return nil, nil, nil, nil, nil
    end

    return isTanking, status, scaledPercent, rawPercent, threatValue
end

local function SafeThreatPercent(unitToken)
    local ok
    local result

    if type(GetThreatPercent) ~= "function" then
        return nil
    end

    ok, result = pcall(GetThreatPercent, unitToken, "target")
    if not ok then
        OT.lastError = tostring(result)
        return nil
    end
    return tonumber(result)
end

local function SafeThreatStatus(unitToken)
    local ok
    local result

    if type(UnitThreatSituation) ~= "function" then
        return nil
    end

    ok, result = pcall(UnitThreatSituation, unitToken, "target")
    if not ok then
        OT.lastError = tostring(result)
        return nil
    end
    return tonumber(result)
end

function OT:GetNativeThreatStatus(unitToken)
    return SafeThreatStatus(unitToken)
end

function OT:PollNative()
    local i
    local rosterEntry
    local isTanking
    local status
    local scaledPercent
    local rawPercent
    local threatValue
    local numericThreat
    local score
    local row
    local found = false
    local absoluteCount = 0
    local now = GetTime()
    local newRows = {}

    if not self:IsValidTarget() then
        self.nativeRows = {}
        self.nativeHadAbsolute = false
        return false
    end

    if not self.nativeAvailable and not self.nativePercentAvailable then
        self.nativeRows = {}
        self.nativeHadAbsolute = false
        return false
    end

    for i = 1, table.getn(self.rosterUnits) do
        rosterEntry = self.rosterUnits[i]
        if rosterEntry and rosterEntry.unit then
            isTanking, status, scaledPercent, rawPercent, threatValue = SafeDetailedThreat(rosterEntry.unit)
            if status == nil and self.nativeStatusAvailable then
                status = SafeThreatStatus(rosterEntry.unit)
            end

            numericThreat = tonumber(threatValue)
            rawPercent = tonumber(rawPercent)
            scaledPercent = tonumber(scaledPercent)

            if numericThreat and numericThreat > 0 then
                score = numericThreat
                absoluteCount = absoluteCount + 1
            elseif rawPercent and rawPercent > 0 then
                score = rawPercent
            elseif scaledPercent and scaledPercent > 0 then
                score = scaledPercent
            else
                score = nil
            end

            if not score and self.nativePercentAvailable then
                scaledPercent = SafeThreatPercent(rosterEntry.unit)
                if scaledPercent and scaledPercent > 0 then
                    score = scaledPercent
                end
            end

            if score then
                row = {
                    name = rosterEntry.name,
                    unit = rosterEntry.unit,
                    class = rosterEntry.class,
                    isPet = rosterEntry.isPet,
                    owner = rosterEntry.owner,
                    tank = (isTanking and true) or ((tonumber(status) or 0) >= 2),
                    status = tonumber(status) or 0,
                    threat = score,
                    absoluteThreat = numericThreat,
                    rawPercent = rawPercent,
                    pullPercent = scaledPercent,
                    melee = nil,
                    source = "NATIVE",
                    exact = numericThreat ~= nil,
                }
                tinsert(newRows, row)
                found = true
            end
        end
    end

    if found then
        self.nativeRows = newRows
        self.nativeLastData = now
        self.nativeHadAbsolute = absoluteCount == table.getn(newRows)

        -- Never mix absolute threat values and percentage values in one sort.
        -- If the provider returned incomplete absolute data, consistently use
        -- raw/relative percentages for every row until a complete sample arrives.
        if not self.nativeHadAbsolute then
            for i = 1, table.getn(self.nativeRows) do
                row = self.nativeRows[i]
                row.absoluteThreat = nil
                row.threat = row.rawPercent or row.pullPercent or row.threat or 0
                row.exact = false
            end
        end
    elseif now - (self.nativeLastData or 0) > self:GetNativeHoldSeconds() then
        -- Some extended 1.12 clients return nil for one or two frames while a
        -- rogue changes stealth state or while the roster is settling. Retain
        -- the last valid sample briefly rather than flashing IDLE/WAIT.
        self.nativeRows = {}
        self.nativeHadAbsolute = false
    end

    return found
end

function OT:CanQueryServer()
    local classification

    if not self:IsValidTarget() then
        return false
    end
    if self:GetGroupSize() <= 0 then
        return false
    end
    if not self:GetDistribution() then
        return false
    end

    -- The exact TWT v4 server query is intended for grouped combat
    -- against elite creatures and bosses. Native client threat APIs, when
    -- available, remain usable outside these server-protocol restrictions.
    classification = UnitClassification("target") or "normal"
    if classification ~= "elite" and classification ~= "worldboss" then
        return false
    end
    -- Query from the latched combat state rather than requiring the target's
    -- combat flag to be true on this exact frame. The server remains the final
    -- authority and simply ignores requests made outside an eligible fight.
    if not self:IsGroupInCombat() then
        return false
    end

    return true
end

function OT:QueryServerThreat()
    local distribution
    local limit
    local ok
    local err
    local now = GetTime()

    if not self:CanQueryServer() then
        return false
    end

    if now - self.targetChangedAt < 0.18 then
        return false
    end

    distribution = self:GetDistribution()
    limit = max(1, min(40, tonumber(self.db.maxRows) or 20))

    ok, err = pcall(SendAddonMessage, "TWT_UDTSv4", "limit=" .. tostring(limit), distribution)
    self.serverLastQuery = now
    self.serverQueryTargetKey = self.currentTargetKey
    self.serverQueryTargetName = self.currentTargetName

    if not ok then
        self.lastError = tostring(err)
        return false
    end

    return true
end

local function ResolveServerClass(name)
    local rosterEntry = OT.rosterByName[name]
    local normalizedName
    if not rosterEntry then
        normalizedName = NormalizeRosterName(name)
        if normalizedName then
            rosterEntry = OT.rosterByNormalizedName[normalizedName]
        end
    end
    if rosterEntry then
        return rosterEntry.class, rosterEntry.isPet, rosterEntry.owner, rosterEntry.unit
    end

    -- Never assume an unresolved server row is a pet. During login or a group
    -- transition the roster may be incomplete for a few frames; treating an
    -- unknown player as a pet could discard every row when pet display is off.
    return "UNKNOWN", false, nil, nil
end

function OT:RejectServerPacket(reason)
    self.serverPacketRejected = (self.serverPacketRejected or 0) + 1
    self.serverLastRejectReason = reason or "unknown"
    self.serverLastPacketAt = GetTime()
    return false
end

function OT:HandleServerPacket(message)
    local markerStart
    local dataStart
    local dataEnd
    local packetData
    local hashAt
    local entries
    local fields
    local i
    local name
    local classToken
    local isPet
    local owner
    local unitToken
    local threat
    local row
    local newRows = {}
    local now = GetTime()
    local queryMatches

    if not message then
        return self:RejectServerPacket("empty packet")
    end

    markerStart = strfind(message, "TWTv4=", 1, 1)
    if not markerStart then
        return false
    end
    self.serverLastPacketAt = now

    if not self.currentTargetKey then
        return self:RejectServerPacket("no current target")
    end

    queryMatches = self.serverQueryTargetKey == self.currentTargetKey
    if not queryMatches and self.serverQueryTargetName and self.currentTargetName then
        queryMatches = NormalizeRosterName(self.serverQueryTargetName)
            == NormalizeRosterName(self.currentTargetName)
    end
    if not queryMatches then
        return self:RejectServerPacket("target changed after query")
    end
    if self.serverLastQuery <= 0 or now - self.serverLastQuery > 4.0 then
        return self:RejectServerPacket("response arrived after query window")
    end

    dataStart = markerStart + strlen("TWTv4=")
    packetData = strsub(message, dataStart)
    hashAt = strfind(packetData, "#", 1, 1)
    if hashAt then
        dataEnd = hashAt - 1
        packetData = strsub(packetData, 1, dataEnd)
    end

    entries = SplitPlain(packetData, ";")

    for i = 1, table.getn(entries) do
        if entries[i] and entries[i] ~= "" then
            fields = SplitPlain(entries[i], ":")
            name = fields[1]
            threat = tonumber(fields[3])

            if name and name ~= "" and threat and threat >= 0 then
                classToken, isPet, owner, unitToken = ResolveServerClass(name)
                if self.db.showPets or not isPet then
                    row = {
                        name = name,
                        unit = unitToken,
                        class = classToken,
                        isPet = isPet,
                        owner = owner,
                        tank = fields[2] == "1",
                        status = fields[2] == "1" and 3 or 0,
                        threat = threat,
                        absoluteThreat = threat,
                        rawPercent = tonumber(fields[4]),
                        pullPercent = nil,
                        melee = fields[5] == "1",
                        source = "SERVER",
                        exact = true,
                    }
                    tinsert(newRows, row)
                end
            end
        end
    end

    -- An empty packet can occur while a roster is settling. Keep the last
    -- valid sample until its normal stale timeout instead of blanking the UI.
    if table.getn(newRows) == 0 then
        return self:RejectServerPacket("packet contained no usable rows")
    end

    self.serverRows = newRows
    self.serverLastResponse = now
    self.serverEverResponded = true
    self.serverResponseTargetKey = self.currentTargetKey
    self.serverPacketAccepted = (self.serverPacketAccepted or 0) + 1
    self.serverLastRejectReason = nil
    return true
end

local function RowsAllHaveAbsoluteThreat(rows)
    local i
    if not rows or table.getn(rows) == 0 then
        return false
    end
    for i = 1, table.getn(rows) do
        if not rows[i] or rows[i].absoluteThreat == nil then
            return false
        end
    end
    return true
end

function OT:SelectProviderRows()
    local mode = self.db.providerMode or "AUTO"
    local now = GetTime()
    local nativeFresh = table.getn(self.nativeRows) > 0
        and (now - self.nativeLastData <= self:GetNativeHoldSeconds())
    local serverFresh = table.getn(self.serverRows) > 0
        and self.serverResponseTargetKey == self.currentTargetKey
        and (now - self.serverLastResponse <= self:GetServerHoldSeconds())
    local nativeAbsolute = nativeFresh and RowsAllHaveAbsoluteThreat(self.nativeRows)
    local localRows = nil
    local localFresh = false

    if self.Local and self.Local.GetRows and self.db.soloFallback then
        localRows = self.Local:GetRows()
        localFresh = localRows and table.getn(localRows) > 0
    end

    if mode == "NATIVE" then
        if nativeFresh then
            return self.nativeRows, nativeAbsolute and "NATIVE" or "NATIVE %",
                true, nativeAbsolute, false
        end
        return nil, "NONE", false, false, false
    elseif mode == "SERVER" then
        if serverFresh then
            return self.serverRows, "SERVER", true, true, false
        end
        return nil, "NONE", false, false, false
    elseif mode == "LOCAL" then
        if localFresh and self:GetGroupSize() == 0 then
            return localRows, "LOCAL EST", false, true, true
        end
        return nil, "NONE", false, false, false
    end

    if nativeAbsolute then
        return self.nativeRows, "NATIVE", true, true, false
    end
    if serverFresh then
        return self.serverRows, "SERVER", true, true, false
    end

    -- While solo, prefer a numeric local estimate over a percentage-only
    -- native sample. The native threat status is still used to mark aggro.
    if localFresh and self:GetGroupSize() == 0 then
        return localRows, "LOCAL EST", false, true, true
    end
    if nativeFresh then
        return self.nativeRows, "NATIVE %", true, false, false
    end
    if localFresh then
        return localRows, "LOCAL EST", false, true, true
    end

    return nil, "NONE", false, false, false
end

function OT:ResetThreatHistory()
    self.history = {}
    self.fightPeaks = {}
    self.fightMaxTPS = {}
    self.fightWasEstimated = false
    self.fightProvider = nil
    self.currentFightTarget = self.currentTargetName
    if self.currentTargetName and (self.inCombat or self:IsGroupInCombat()) then
        self.currentFightStarted = GetTime()
    else
        self.currentFightStarted = nil
    end
end

function OT:CalculateTPS(name, threat)
    local now = GetTime()
    local window = max(1.0, tonumber(self.db.tpsWindow) or 5.0)
    local samples = self.history[name]
    local lastSample
    local firstSample
    local deltaTime
    local deltaThreat

    if not samples then
        samples = {}
        self.history[name] = samples
    end

    lastSample = samples[table.getn(samples)]
    if lastSample and threat < lastSample.value then
        samples = {}
        self.history[name] = samples
        lastSample = nil
    end

    if not lastSample or now - lastSample.time >= 0.18 or threat ~= lastSample.value then
        tinsert(samples, { time = now, value = threat })
    end

    while table.getn(samples) > 2 and now - samples[1].time > window do
        tremove(samples, 1)
    end

    firstSample = samples[1]
    lastSample = samples[table.getn(samples)]

    if not firstSample or not lastSample then
        return 0
    end

    deltaTime = lastSample.time - firstSample.time
    deltaThreat = lastSample.value - firstSample.value
    if deltaTime <= 0 or deltaThreat <= 0 then
        return 0
    end

    return deltaThreat / deltaTime
end

local function SortRows(a, b)
    if (a.threat or 0) == (b.threat or 0) then
        return tostring(a.name or "") < tostring(b.name or "")
    end
    return (a.threat or 0) > (b.threat or 0)
end

function OT:BuildDisplayRows(sourceRows, provider, exact, absoluteThreat, estimated)
    local i
    local source
    local row
    local topThreat = 0
    local tankThreat = 0
    local tankName = nil
    local playerName = UnitName("player")
    local maxRows = max(1, min(40, tonumber(self.db.maxRows) or 20))

    self.displayRows = {}

    if not sourceRows then
        self.currentProvider = "NONE"
        self.currentProviderExact = false
        self.currentProviderAbsolute = false
        self.currentProviderEstimated = false
        return self.displayRows
    end

    for i = 1, table.getn(sourceRows) do
        source = sourceRows[i]
        if type(source) == "table" then
            row = {}
            local k
            local v
            for k, v in pairs(source) do
                row[k] = v
            end
            tinsert(self.displayRows, row)
            if (row.threat or 0) > topThreat then
                topThreat = row.threat or 0
            end
            if row.tank and (row.threat or 0) >= tankThreat then
                tankThreat = row.threat or 0
                tankName = row.name
            end
        end
    end

    if tankThreat <= 0 then
        tankThreat = topThreat
    end

    tsort(self.displayRows, SortRows)

    for i = 1, table.getn(self.displayRows) do
        self.displayRows[i].rank = i
    end

    if table.getn(self.displayRows) > maxRows and self.db.alwaysShowPlayer then
        local playerIndex = nil
        local playerRow = nil
        for i = maxRows + 1, table.getn(self.displayRows) do
            if self.displayRows[i].name == playerName then
                playerIndex = i
                playerRow = self.displayRows[i]
                break
            end
        end
        while table.getn(self.displayRows) > maxRows do
            tremove(self.displayRows)
        end
        if playerIndex and playerRow and maxRows > 0 then
            self.displayRows[maxRows] = playerRow
        end
    else
        while table.getn(self.displayRows) > maxRows do
            tremove(self.displayRows)
        end
    end

    for i = 1, table.getn(self.displayRows) do
        row = self.displayRows[i]
        if topThreat > 0 then
            row.relativePercent = (row.threat or 0) / topThreat * 100
        else
            row.relativePercent = 0
        end

        if not row.pullPercent then
            if row.tank then
                row.pullPercent = 100
            elseif tankThreat > 0 then
                if row.melee then
                    row.pullPercent = (row.threat or 0) / (tankThreat * 1.10) * 100
                else
                    row.pullPercent = (row.threat or 0) / (tankThreat * 1.30) * 100
                end
            else
                row.pullPercent = row.relativePercent
            end
        end

        if self.inCombat and absoluteThreat then
            row.tps = self:CalculateTPS(row.name, row.threat or 0)
        else
            row.tps = 0
        end
        row.isPlayer = row.name == playerName
        row.tankName = tankName

        if self.inCombat and absoluteThreat then
            -- A reload or unusual client event order can put the player in
            -- combat before PLAYER_REGEN_DISABLED reaches this addon. Start a
            -- report as soon as a numeric sample exists so solo kills are not
            -- silently lost.
            if not self.currentFightStarted and self.currentTargetName then
                self.currentFightStarted = GetTime()
                self.currentFightTarget = self.currentTargetName
            end
            self.fightProvider = provider or self.fightProvider or "UNKNOWN"
            if not self.fightPeaks[row.name] or (row.threat or 0) > self.fightPeaks[row.name] then
                self.fightPeaks[row.name] = row.threat or 0
            end
            if not self.fightMaxTPS[row.name] or (row.tps or 0) > self.fightMaxTPS[row.name] then
                self.fightMaxTPS[row.name] = row.tps or 0
            end
            if estimated or row.estimated then
                self.fightWasEstimated = true
            end
        end
    end

    self.currentProvider = provider or "NONE"
    self.currentProviderExact = exact and true or false
    self.currentProviderAbsolute = absoluteThreat and true or false
    self.currentProviderEstimated = estimated and true or false
    self.lastProviderLabel = self.currentProvider

    return self.displayRows
end

function OT:FinalizeFight(reason)
    local summary
    local rows
    local name
    local peak
    local rosterEntry
    local maxTPS
    local averageTPS
    local duration

    if not self.currentFightStarted or not self.currentFightTarget then
        return
    end

    duration = max(0, GetTime() - self.currentFightStarted)
    if not next(self.fightPeaks) then
        self.currentFightStarted = nil
        self.currentFightTarget = nil
        self.fightProvider = nil
        self.fightWasEstimated = false
        return
    end

    rows = {}
    for name, peak in pairs(self.fightPeaks) do
        rosterEntry = self.rosterByName[name]
        maxTPS = self.fightMaxTPS[name] or 0
        if duration > 0 then
            averageTPS = (tonumber(peak) or 0) / duration
            if averageTPS > maxTPS then
                maxTPS = averageTPS
            end
        end
        tinsert(rows, {
            name = name,
            class = rosterEntry and rosterEntry.class or "UNKNOWN",
            peak = peak,
            maxTPS = maxTPS,
        })
    end

    tsort(rows, function(a, b)
        if a.peak == b.peak then
            return a.name < b.name
        end
        return a.peak > b.peak
    end)

    summary = {
        target = self.currentFightTarget,
        ended = time(),
        duration = duration,
        provider = self.fightProvider or self.currentProvider,
        estimated = self.fightWasEstimated and true or false,
        reason = reason or "ended",
        rows = rows,
    }

    self.lastFight = summary
    if self.db.keepLastFight then
        self.db.lastFight = summary
    end

    self.currentFightStarted = nil
    self.currentFightTarget = nil
    self.fightProvider = nil
    self.fightWasEstimated = false
end

function OT:GetLastFight()
    return self.lastFight or (self.db and self.db.lastFight)
end

function OT:PrintLastFight()
    local fight = self:GetLastFight()
    local i
    local row

    if not fight or not fight.rows or table.getn(fight.rows) == 0 then
        Print("No recorded fight is available yet.")
        return
    end

    Print("Last fight: " .. tostring(fight.target or "Unknown")
        .. " | duration " .. tostring(floor((fight.duration or 0) + 0.5)) .. "s"
        .. " | provider " .. tostring(fight.provider or "unknown")
        .. (fight.estimated and " (estimated)" or ""))

    for i = 1, min(10, table.getn(fight.rows)) do
        row = fight.rows[i]
        Print(tostring(i) .. ". " .. tostring(row.name)
            .. "  peak " .. (fight.estimated and "~" or "") .. FormatNumber(row.peak, true)
            .. "  max TPS " .. (fight.estimated and "~" or "") .. FormatNumber(row.maxTPS, true))
    end
end

function OT:HandleTargetChanged(force)
    local newKey = self:GetTargetKey()
    local newName = newKey and UnitName("target") or nil

    if not force and newKey == self.currentTargetKey then
        return false
    end

    if self.currentTargetKey then
        self:FinalizeFight("target changed")
    end

    self.currentTargetKey = newKey
    self.currentTargetName = newName
    self.targetChangedAt = GetTime()
    self.serverResponseTargetKey = nil
    self.serverQueryTargetKey = nil
    self.serverQueryTargetName = nil
    self.serverLastResponse = 0
    self.serverEverResponded = false
    self.nativeLastData = 0
    self.nativeRows = {}
    self.serverRows = {}
    self.displayRows = {}
    self.warningLatched = false
    self.currentProviderEstimated = false
    self.noDataSince = 0
    self.autoRecoveryArmed = true

    if self.Local and self.Local.ResetTarget then
        self.Local:ResetTarget(newKey, newName)
    end

    if newKey then
        self:ResetThreatHistory()
    else
        self.history = {}
        self.fightPeaks = {}
        self.fightMaxTPS = {}
        self.fightWasEstimated = false
        self.currentFightTarget = nil
        self.currentFightStarted = nil
        self.fightProvider = nil
        self.fightWasEstimated = false
    end

    return true
end

function OT:RefreshThreatData(reason, announce, automatic, watchdogAttempt, skipFinalize)
    local now
    local refreshReason
    local liveTargetKey
    local liveTargetName

    if not self.initialized or self.refreshingData then
        return false
    end

    self.refreshingData = true
    now = GetTime()
    refreshReason = reason or "manual data refresh"

    -- Preserve any useful sample already collected by ending the current
    -- segment before provider arrays are discarded. The new segment begins
    -- immediately if combat is still active.
    if not skipFinalize then
        self:FinalizeFight(refreshReason)
    end

    liveTargetKey = self:GetTargetKey()
    liveTargetName = liveTargetKey and UnitName("target") or nil
    self.currentTargetKey = liveTargetKey
    self.currentTargetName = liveTargetName

    self.nativeRows = {}
    self.serverRows = {}
    self.displayRows = {}
    self.history = {}
    self.fightPeaks = {}
    self.fightMaxTPS = {}
    self.fightWasEstimated = false
    self.fightProvider = nil
    self.nativeLastData = 0
    self.nativeHadAbsolute = false
    self.serverLastQuery = 0
    self.serverLastResponse = 0
    self.serverEverResponded = false
    self.serverResponseTargetKey = nil
    self.serverQueryTargetKey = nil
    self.serverQueryTargetName = nil
    self.currentProvider = "NONE"
    self.currentProviderExact = false
    self.currentProviderAbsolute = false
    self.currentProviderEstimated = false
    self.lastProviderLabel = "NONE"
    self.warningLatched = false
    self.warningFlashUntil = 0
    self.lastError = nil
    self.lastPoll = 0
    self.lastProviderScan = now
    self.noDataSince = 0
    self.targetChangedAt = now - 1.0
    self.pendingGroupRefreshAt = 0
    self.pendingGroupRefreshReason = nil
    self.pendingGroupForceRefresh = false

    self.loadStage = "detecting providers"
    self:DetectProviders()
    self.loadStage = "building roster"
    self:RebuildRoster()
    self.groupSignature = self:GetGroupSignature()
    self.inCombat = self:IsGroupInCombat() and true or false

    if self.Local then
        if self.Local.EndCombat then
            self.Local:EndCombat()
        end
        if self.Local.ResetTarget then
            self.Local:ResetTarget(self.currentTargetKey, self.currentTargetName)
        end
        if self.inCombat and self:GetGroupSize() == 0 and self.db.soloFallback
            and self.Local.StartCombat then
            self.Local:StartCombat()
        end
    end

    if self.currentTargetKey then
        self:ResetThreatHistory()
    else
        self.currentFightTarget = nil
        self.currentFightStarted = nil
    end

    self.lastDataRefreshAt = now
    self.lastDataRefreshReason = refreshReason
    self.dataRefreshNoticeUntil = now + 1.25
    if automatic then
        self.autoRecoveryCount = (self.autoRecoveryCount or 0) + 1
    end
    if watchdogAttempt then
        self.autoRecoveryArmed = false
    else
        self.autoRecoveryArmed = true
    end
    self.refreshingData = false

    -- Reacquire every available source immediately instead of waiting for the
    -- next periodic tick. The normal poll loop continues from this fresh state.
    self:PollNative()
    if self.Local and self.Local.Poll then
        self.Local:Poll()
    end
    if self.db.providerMode ~= "NATIVE" and self.db.providerMode ~= "LOCAL" then
        self:QueryServerThreat()
    end
    self:RefreshDisplay(true)

    if announce then
        Print("Threat data refreshed. Roster and providers restarted; settings were preserved.")
    end
    return true
end

function OT:CheckAutoRecovery(now)
    local delay
    local canExpectData

    if not self.db.autoRecover then
        self.noDataSince = 0
        self.autoRecoveryArmed = true
        return false
    end

    if self.refreshingData or self.testUntil > now then
        self.noDataSince = 0
        return false
    end

    if not self.inCombat or not self:IsValidTarget() then
        self.noDataSince = 0
        self.autoRecoveryArmed = true
        return false
    end

    if table.getn(self.displayRows) > 0 then
        self.noDataSince = 0
        self.autoRecoveryArmed = true
        return false
    end

    canExpectData = self.nativeAvailable or self.nativePercentAvailable
        or self:CanQueryServer()
        or (self.db.soloFallback and self:GetGroupSize() == 0)
    if not canExpectData then
        self.noDataSince = 0
        return false
    end

    if self.noDataSince <= 0 then
        self.noDataSince = now
        return false
    end

    delay = max(3.0, tonumber(self.db.recoveryDelay) or 4.0)
    if self.autoRecoveryArmed
        and now - self.noDataSince >= delay
        and now - self.lastDataRefreshAt >= delay then
        return self:RefreshThreatData("automatic stale-data recovery", false, true, true)
    end

    return false
end

function OT:GetPlayerRow()
    local playerName = UnitName("player")
    local i
    for i = 1, table.getn(self.displayRows) do
        if self.displayRows[i] and self.displayRows[i].name == playerName then
            return self.displayRows[i]
        end
    end
    return nil
end

function OT:CheckAggroWarning()
    local row
    local threshold

    if not self.db.warningEnabled then
        self.warningLatched = false
        return
    end

    row = self:GetPlayerRow()
    if not row or row.tank or row.estimated then
        self.warningLatched = false
        return
    end

    threshold = tonumber(self.db.warningThreshold) or 90
    if (row.pullPercent or 0) >= threshold then
        if not self.warningLatched then
            self.warningLatched = true
            self.warningFlashUntil = GetTime() + 0.8
            if self.db.warningSound and PlaySoundFile then
                pcall(PlaySoundFile, "Sound\\Interface\\RaidWarning.wav")
            elseif self.db.warningSound and PlaySound then
                pcall(PlaySound, "RaidWarning")
            end
            if self.UI and self.UI.FlashWarning then
                self.UI:FlashWarning()
            end
        end
    elseif (row.pullPercent or 0) < threshold - 5 then
        self.warningLatched = false
    end
end

function OT:GetStatusText()
    local now = GetTime()
    local classification

    if self.testUntil > now then
        return "Preview data", "PREVIEW"
    end

    if not self:IsValidTarget() then
        if not self.inCombat then
            return "Out of combat - target a hostile NPC", "IDLE"
        end
        return "Target a hostile NPC", "NO TARGET"
    end

    if table.getn(self.displayRows) == 0 and self.dataRefreshNoticeUntil > now then
        return "Refreshing roster and threat providers", "REFRESH"
    end

    if table.getn(self.displayRows) > 0 then
        if self.currentProviderEstimated then
            return "Estimated solo threat from local combat messages", "LOCAL EST"
        elseif self.currentProviderAbsolute then
            return "Exact threat", self.currentProvider
        end
        return "Exact ordering; percentages only", self.currentProvider
    end

    if not self.inCombat then
        return "Out of combat", "IDLE"
    end

    if self.db.providerMode == "NATIVE" and not self.nativeAvailable and not self.nativePercentAvailable then
        return "Native threat API is unavailable", "NO API"
    end

    if self.db.providerMode == "LOCAL" then
        if not self.db.soloFallback then
            return "Local solo estimation is disabled", "OFF"
        elseif self:GetGroupSize() > 0 then
            return "Local estimation is solo-only", "NO DATA"
        end
        return "Waiting for local solo combat data", "WAIT"
    end

    if self.db.providerMode == "SERVER" and not self:CanQueryServer() then
        classification = UnitClassification("target") or "normal"
        if self:GetGroupSize() <= 0 then
            return "Server threat requires a party or raid", "NO GROUP"
        elseif classification ~= "elite" and classification ~= "worldboss" then
            return "Server threat supports elite targets and bosses", "NO DATA"
        elseif not UnitAffectingCombat("target") then
            return "Waiting for the target to enter combat", "WAIT"
        end
        return "Waiting for group combat", "WAIT"
    end

    classification = UnitClassification("target") or "normal"
    if self:GetGroupSize() == 0 and self.db.providerMode == "AUTO" and not self.db.soloFallback then
        return "Solo local estimate is disabled in settings", "NO DATA"
    end
    if not self.nativeAvailable and not self.nativePercentAvailable and self:GetGroupSize() == 0 then
        if self.db.soloFallback then
            return "Waiting for local combat events", "WAIT"
        end
        return "Exact group threat requires a party or raid", "NO GROUP"
    end

    if self.serverEverResponded and now - self.serverLastResponse > self:GetServerHoldSeconds() then
        return "Waiting for refreshed threat data", "WAIT"
    end

    if not self.nativeAvailable and not self.nativePercentAvailable
        and classification ~= "elite" and classification ~= "worldboss" then
        return "Server threat may require an elite or boss", "WAIT"
    end

    if self:CanQueryServer() and now - self.targetChangedAt > 4 and not self.serverEverResponded
        and not self.nativeAvailable and not self.nativePercentAvailable then
        return "No exact threat response; use /msthreat status", "NO DATA"
    end

    return "Waiting for exact threat data", "WAIT"
end

function OT:GetTestRows()
    local samples = {
        { name = UnitName("player") or "You", class = "WARRIOR", threat = 18420, tank = false, pullPercent = 86, tps = 612, exact = true },
        { name = "Shieldwall", class = "WARRIOR", threat = 17650, tank = true, pullPercent = 100, tps = 488, exact = true },
        { name = "Moonflare", class = "MAGE", threat = 14390, tank = false, pullPercent = 63, tps = 734, exact = true },
        { name = "Nightstep", class = "ROGUE", threat = 10920, tank = false, pullPercent = 48, tps = 521, exact = true },
        { name = "Wildbloom", class = "DRUID", threat = 6210, tank = false, pullPercent = 27, tps = 245, exact = true },
    }
    local _, playerClass = UnitClass("player")
    samples[1].class = NormalizeClassToken(playerClass)
    samples[1].isPlayer = true
    return samples
end

function OT:StartTest(seconds)
    self.testUntil = GetTime() + (seconds or 15)
    if self.UI and self.UI.Refresh then
        self.UI:Refresh(true)
    end
end

function OT:StopTest()
    self.testUntil = 0
    if self.UI and self.UI.Refresh then
        self.UI:Refresh(true)
    end
end

function OT:ShouldShowMeter()
    if not self.db or not self.db.enabled then
        return false
    end
    if self.testUntil > GetTime() then
        return true
    end
    if self.UI and self.UI.options and self.UI.options:IsVisible() then
        return true
    end

    -- "Hide while out of combat" is the master out-of-combat visibility
    -- switch. When it is disabled, keep the header visible even with no target;
    -- the separate target filter applies only while combat is active.
    if not self.inCombat then
        return not self.db.hideOutOfCombat
    end
    if self.db.hideWithoutTarget and not self:IsValidTarget() then
        return false
    end
    return true
end

function OT:RefreshDisplay(force)
    local sourceRows
    local provider
    local exact
    local absoluteThreat
    local estimated
    local displayRows

    if not self.initialized then
        return
    end

    if self.testUntil > GetTime() then
        displayRows = self:GetTestRows()
        self.currentProvider = "PREVIEW"
        self.currentProviderExact = true
        self.currentProviderAbsolute = true
        self.currentProviderEstimated = false
    else
        sourceRows, provider, exact, absoluteThreat, estimated = self:SelectProviderRows()
        displayRows = self:BuildDisplayRows(sourceRows, provider, exact, absoluteThreat, estimated)
        self:CheckAggroWarning()
    end

    if self.UI and self.UI.Update then
        self.UI:Update(displayRows, force)
    end
end

function OT:BeginCombatTracking()
    self.inCombat = true
    self:NoteCombatEvidence("combat began")
    if self.currentTargetKey and not self.currentFightStarted then
        self:ResetThreatHistory()
    end
    if self.Local and self.Local.StartCombat and not self.Local.active then
        self.Local:StartCombat()
    end
end

function OT:EndCombatTracking(reason)
    -- Keep combat marked active for one last provider sample, then save the
    -- report before the solo estimator is cleared.
    if self.Local and self.Local.Poll then
        self.Local:Poll()
    end
    self:RefreshDisplay(true)
    self.inCombat = false
    self.regenState = "IDLE"
    self:FinalizeFight(reason or "combat ended")
    if self.Local and self.Local.EndCombat then
        self.Local:EndCombat()
    end
    self:RefreshDisplay(true)
end

function OT:Poll()
    local now = GetTime()
    local interval = max(0.10, tonumber(self.db.updateInterval) or 0.20)
    local serverInterval = max(0.25, tonumber(self.db.serverInterval) or 0.50)
    local detectedCombat
    local wasInCombat
    local signature
    local refreshReason

    if self.pendingGroupRefreshAt > 0 and now >= self.pendingGroupRefreshAt then
        local forceGroupRefresh = self.pendingGroupForceRefresh and true or false
        refreshReason = self.pendingGroupRefreshReason or "group roster changed"
        self.pendingGroupRefreshAt = 0
        self.pendingGroupRefreshReason = nil
        self.pendingGroupForceRefresh = false
        signature = self:GetGroupSignature()
        if not self.groupSignature then
            self.groupSignature = signature
            self:RebuildRoster()
        elseif forceGroupRefresh or signature ~= self.groupSignature then
            self.groupSignature = signature
            self:RefreshThreatData(refreshReason, false, true, false)
            return
        else
            -- Roster events can fire even when the membership fingerprint is
            -- unchanged. A compact rebuild is sufficient in that case.
            self:RebuildRoster()
        end
    end

    -- Old clients can occasionally omit or coalesce a roster event. A cheap
    -- one-second fingerprint check supplies the same self-healing path.
    if now - self.lastGroupSignatureCheck >= 1.0 then
        self.lastGroupSignatureCheck = now
        signature = self:GetGroupSignature()
        if self.groupSignature and signature ~= self.groupSignature then
            self:ScheduleGroupRefresh("group state changed")
        elseif not self.groupSignature then
            self.groupSignature = signature
        end
    end

    self:HandleTargetChanged(false)
    wasInCombat = self.inCombat and true or false
    detectedCombat = self:IsGroupInCombat() and true or false
    if detectedCombat and not wasInCombat then
        self:BeginCombatTracking()
    elseif not detectedCombat and wasInCombat then
        self:EndCombatTracking("combat ended")
    else
        self.inCombat = detectedCombat
    end

    if now - self.lastProviderScan >= 5 then
        self.lastProviderScan = now
        self:DetectProviders()
    end

    if now - self.lastPoll >= interval then
        self.lastPoll = now
        self:RebuildRoster()
        self:PollNative()
        if self.Local and self.Local.Poll then
            self.Local:Poll()
        end

        if self.db.providerMode ~= "NATIVE" and self.db.providerMode ~= "LOCAL"
            and now - self.serverLastQuery >= serverInterval then
            self:QueryServerThreat()
        end

        self:RefreshDisplay(false)
        if self:CheckAutoRecovery(now) then
            return
        end
    end
end

function OT:TryInitialize(reason)
    local ok
    local result

    if self.initialized then
        return true
    end

    self.loadStage = "initializing: " .. tostring(reason or "unknown")
    ok, result = pcall(self.Initialize, self)
    if not ok then
        self.initialized = false
        self.loadError = tostring(result or "unknown initialization error")
        self.loadStage = "initialization failed"
        Print("Initialization failed: " .. self.loadError)
        Print("Slash commands remain available for diagnostics.")
        return false
    end

    if result == false or not self.initialized then
        self.loadStage = "waiting for character identity"
        return false
    end

    self.loadError = nil
    self.loadStage = "ready"
    return true
end

function OT:Initialize()
    local profileReady
    local profileCreated
    local profileMigrated

    if self.initialized then
        return true
    end

    self.loadStage = "activating character profile"
    profileReady, profileCreated, profileMigrated = self:ActivateCurrentCharacterProfile()
    if not profileReady then
        self.loadStage = "waiting for character identity"
        return false
    end
    self.profileCreatedAtLoad = profileCreated and true or false
    self.profileMigratedAtLoad = profileMigrated and true or false

    self:DetectProviders()
    self:RebuildRoster()
    self.groupSignature = self:GetGroupSignature()
    self.currentTargetKey = self:GetTargetKey()
    self.currentTargetName = self.currentTargetKey and UnitName("target") or nil
    self.targetChangedAt = GetTime()
    if self.Local and self.Local.Initialize then
        self.Local:Initialize()
        self.Local:ResetTarget(self.currentTargetKey, self.currentTargetName)
    end
    self.inCombat = self:HasLiveCombatEvidence() and true or false
    self.regenState = self.inCombat and "COMBAT" or "IDLE"
    self.lastRegenEventAt = GetTime()
    if self.inCombat then
        self:NoteCombatEvidence("startup combat")
    end
    self.lastDataRefreshAt = GetTime()
    self.lastDataRefreshReason = "startup"

    if self.UI and self.UI.Initialize then
        self.loadStage = "creating user interface"
        self.UI:Initialize()
    end

    self.initialized = true

    if self.db.firstRun then
        self.db.firstRun = false
        self.db.locked = false
        self:StartTest(30)
        if self.UI and self.UI.OpenOptions then
            self.UI:OpenOptions()
        end
        Print(self.displayName .. " v" .. self.version .. " loaded for " .. self:GetProfileLabel()
            .. ". Move the header, configure it, then lock it.")
    else
        Print(self.displayName .. " v" .. self.version .. " loaded for " .. self:GetProfileLabel()
            .. ". Type /msthreat for settings.")
    end
    if self.profileMigratedAtLoad then
        Print("The former shared settings were migrated into this character profile. Last-fight history was not copied between characters.")
    end
    if self.legacyImportedAtLoad then
        Print("Legacy OctoThreat profiles and settings were copied into MSThreatDB. The legacy data was not erased.")
    end
    self.loadStage = "ready"
    self.loadError = nil
    return true
end

function OT:ResetSettings(keepPosition)
    local oldPosition
    if keepPosition and self.db and self.db.position then
        oldPosition = CopyValue(self.db.position)
    end

    if not self.accountDB or not self.profileKey then
        if not self:ActivateCurrentCharacterProfile() then
            Print("The current character profile is not available yet.")
            return
        end
    end

    self.accountDB.profiles[self.profileKey] = CopyValue(self.defaults)
    self.db = self.accountDB.profiles[self.profileKey]
    self.db.firstRun = false
    self.lastFight = nil

    if oldPosition then
        self.db.position = oldPosition
    end
    self:UpdateProfileMetadata()

    self:RefreshThreatData("settings reset", false, false, false)
    if self.UI and self.UI.ApplyAllSettings then
        self.UI:ApplyAllSettings()
    end
    self:StartTest(15)
end

function OT:PrintStatus()
    local statusText
    local badge
    local serverAge
    local refreshAge
    local distribution
    local target = self.currentTargetName or "none"

    statusText, badge = self:GetStatusText()
    if self.serverLastResponse > 0 then
        serverAge = string.format("%.1fs", GetTime() - self.serverLastResponse)
    else
        serverAge = "never"
    end
    if self.lastDataRefreshAt > 0 then
        refreshAge = string.format("%.1fs", GetTime() - self.lastDataRefreshAt)
    else
        refreshAge = "never"
    end
    distribution = self:GetDistribution() or "SOLO"

    Print("Version " .. self.version .. " | load stage: " .. tostring(self.loadStage or "unknown")
        .. " | initialized: " .. (self.initialized and "yes" or "no"))
    if self.loadError then
        Print("Load error: " .. tostring(self.loadError))
    end
    Print("Target: " .. target)
    Print("Profile: " .. self:GetProfileLabel() .. " | saved character profiles: " .. tostring(self:GetProfileCount()))
    Print("Saved data: " .. self:GetMigrationStatusText())
    Print("Group: " .. distribution .. " | roster entries: " .. tostring(table.getn(self.rosterUnits)))
    Print("Provider mode: " .. tostring(self.db.providerMode)
        .. " | active: " .. tostring(self.currentProvider)
        .. " | rows: " .. tostring(table.getn(self.displayRows)))
    Print("Combat: " .. (self.inCombat and "yes" or "no")
        .. " | latch: " .. tostring(self.regenState or "UNKNOWN")
        .. " | last evidence: " .. ((self.lastCombatEvidenceAt or 0) > 0
            and string.format("%.1fs", GetTime() - self.lastCombatEvidenceAt) or "never")
        .. " (" .. tostring(self.lastCombatEvidenceReason or "none") .. ")")
    Print("Native detailed API: " .. (self.nativeAvailable and "yes" or "no")
        .. " | native percent API: " .. (self.nativePercentAvailable and "yes" or "no")
        .. " | native status API: " .. (self.nativeStatusAvailable and "yes" or "no"))
    if self.Local and self.Local.GetDiagnostics then
        Print("Local: " .. self.Local:GetDiagnostics())
    end
    Print("Server query eligible: " .. (self:CanQueryServer() and "yes" or "no")
        .. " | server response age: " .. serverAge
        .. " | packets accepted/rejected: " .. tostring(self.serverPacketAccepted or 0)
        .. "/" .. tostring(self.serverPacketRejected or 0))
    if self.serverLastRejectReason then
        Print("Last server packet rejection: " .. tostring(self.serverLastRejectReason))
    end
    Print("Recovery: " .. (self.db.autoRecover and "on" or "off")
        .. " | automatic refreshes: " .. tostring(self.autoRecoveryCount or 0)
        .. " | last: " .. refreshAge .. " ago (" .. tostring(self.lastDataRefreshReason or "unknown") .. ")")
    Print("State: " .. tostring(statusText) .. " [" .. tostring(badge) .. "]")
    if self.lastError then
        Print("Last provider error: " .. tostring(self.lastError))
    end
end

function OT:PrintHelp()
    Print("Commands (legacy aliases: /othreat and /octothreat):")
    Print("/msthreat - open or close settings")
    Print("/msthreat show | hide | toggle")
    Print("/msthreat lock | unlock | center")
    Print("/msthreat test | status | report | refresh")
    Print("/msthreat profile | profiles - show the active character profile or list saved profiles")
    Print("/msthreat provider auto|native|server|local")
    Print("/msthreat refresh | recover | resetdata - restart threat data without changing settings")
    Print("/msthreat reset - restore defaults for the active character profile")
end

function OT:HandleSlash(message)
    local text = Trim(message)
    local lower = strlower(text)
    local provider

    if lower == "" or lower == "config" or lower == "options" then
        if self.UI and self.UI.ToggleOptions then
            self.UI:ToggleOptions()
        end
        return
    end

    if lower == "show" then
        self.db.enabled = true
        if self.UI and self.UI.meter then
            self.UI.meter:Show()
        end
        self:RefreshDisplay(true)
    elseif lower == "hide" then
        self.db.enabled = false
        if self.UI and self.UI.meter then
            self.UI.meter:Hide()
        end
    elseif lower == "toggle" then
        self.db.enabled = not self.db.enabled
        self:RefreshDisplay(true)
    elseif lower == "lock" then
        self.db.locked = true
        if self.UI and self.UI.ApplyAllSettings then
            self.UI:ApplyAllSettings()
        end
        Print("Meter locked.")
    elseif lower == "unlock" then
        self.db.locked = false
        self:StartTest(30)
        if self.UI and self.UI.ApplyAllSettings then
            self.UI:ApplyAllSettings()
        end
        Print("Meter unlocked. Drag the header with the left mouse button.")
    elseif lower == "center" then
        if self.UI and self.UI.CenterMeter then
            self.UI:CenterMeter()
        end
    elseif lower == "test" then
        self:StartTest(15)
    elseif lower == "status" then
        self:PrintStatus()
    elseif lower == "report" then
        self:PrintLastFight()
    elseif lower == "profile" or lower == "profile status" then
        Print("Active character profile: " .. self:GetProfileLabel()
            .. " | saved profiles: " .. tostring(self:GetProfileCount()))
    elseif lower == "profiles" or lower == "profile list" then
        self:PrintProfiles()
    elseif lower == "refresh" or lower == "recover" or lower == "resetdata" then
        self:StopTest()
        self:RefreshThreatData("manual data refresh", true, false, false)
    elseif lower == "reset" then
        self:ResetSettings(false)
        Print("Settings reset.")
    elseif strsub(lower, 1, 9) == "provider " then
        provider = string.upper(Trim(strsub(lower, 10)))
        if provider == "AUTO" or provider == "NATIVE" or provider == "SERVER" or provider == "LOCAL" then
            self.db.providerMode = provider
            self.serverRows = {}
            self.nativeRows = {}
            self.serverLastResponse = 0
            self.nativeLastData = 0
            if self.Local and self.Local.ResetTarget then
                self.Local:ResetTarget(self.currentTargetKey, self.currentTargetName)
            end
            Print("Provider mode set to " .. provider .. ".")
            self:RefreshThreatData("provider mode changed", false, false, false)
            if self.UI and self.UI.ApplyAllSettings then
                self.UI:ApplyAllSettings()
            end
        else
            Print("Use: /msthreat provider auto|native|server|local")
        end
    elseif lower == "help" then
        self:PrintHelp()
    else
        self:PrintHelp()
    end
end

-- MSThreat_Bootstrap.lua normally registers these aliases before the core
-- is parsed. Keep a fallback for manual source installations that omit it.
if not SlashCmdList["MSTHREAT"] then
    SLASH_MSTHREAT1 = "/msthreat"
    SLASH_MSTHREAT2 = "/mst"
    SLASH_MSTHREAT3 = "/msthreatmeter"
    SLASH_MSTHREAT4 = "/othreat"
    SLASH_MSTHREAT5 = "/octothreat"
    SlashCmdList["MSTHREAT"] = function(message)
        if MSThreat and MSThreat.HandleSlash then
            if not MSThreat.initialized and MSThreat.TryInitialize then
                MSThreat:TryInitialize("slash command")
            end
            if MSThreat.initialized then
                MSThreat:HandleSlash(message)
            end
        end
    end
end
SlashCmdList["OCTOTHREAT"] = SlashCmdList["MSTHREAT"]
MSThreat_CommandDispatch = SlashCmdList["MSTHREAT"]
OctoThreat_CommandDispatch = SlashCmdList["MSTHREAT"]

OT.eventFrame:RegisterEvent("ADDON_LOADED")
OT.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
OT.eventFrame:RegisterEvent("PLAYER_LOGIN")
OT.eventFrame:RegisterEvent("PLAYER_LOGOUT")
OT.eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
OT.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
OT.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
OT.eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
OT.eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
OT.eventFrame:RegisterEvent("UNIT_PET")
OT.eventFrame:RegisterEvent("CHAT_MSG_ADDON")
OT.eventFrame:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
OT.eventFrame:RegisterEvent("CHAT_MSG_COMBAT_SELF_MISSES")
OT.eventFrame:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS")
OT.eventFrame:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES")
OT.eventFrame:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE")
OT.eventFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
OT.eventFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE")
OT.eventFrame:RegisterEvent("CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF")
OT.eventFrame:RegisterEvent("CHAT_MSG_SPELL_DAMAGESHIELDS_ON_OTHERS")
OT.eventFrame:RegisterEvent("CHAT_MSG_COMBAT_PET_HITS")
OT.eventFrame:RegisterEvent("CHAT_MSG_SPELL_PET_DAMAGE")
OT.eventFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")
OT.eventFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS")
OT.eventFrame:RegisterEvent("CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF")
OT.eventFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS")
OT.eventFrame:RegisterEvent("PLAYER_DEAD")
OT.eventFrame:RegisterEvent("PLAYER_ALIVE")

OT.eventFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "MSThreat" then
        OT:TryInitialize("ADDON_LOADED")
        return
    end

    if (event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD") and not OT.initialized then
        OT:TryInitialize(event)
    end

    if not OT.initialized then
        return
    end

    if event == "PLAYER_LOGOUT" then
        OT:FinalizeFight("logout")
        OT:UpdateProfileMetadata()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        OT:EnsureActiveCharacterProfile()
        OT:DetectProviders()
        OT:RebuildRoster()
        OT.groupSignature = OT:GetGroupSignature()
        OT.pendingGroupRefreshAt = 0
        OT.pendingGroupRefreshReason = nil
        OT.pendingGroupForceRefresh = false
        OT:HandleTargetChanged(true)
        OT.inCombat = OT:HasLiveCombatEvidence() and true or false
        OT.regenState = OT.inCombat and "COMBAT" or "IDLE"
        OT.lastRegenEventAt = GetTime()
        if OT.inCombat then
            OT:NoteCombatEvidence("entered world in combat")
        end
        -- Group and addon-message channels can settle after PLAYER_ENTERING_WORLD,
        -- especially after changing characters. Force one delayed provider
        -- resynchronization even when the first roster fingerprint looks equal.
        OT:ScheduleGroupRefresh("entering world provider sync", true, 0.80)
        if OT.Local and OT.Local.ResetTarget then
            OT.Local:ResetTarget(OT.currentTargetKey, OT.currentTargetName)
        end
        OT:RefreshDisplay(true)
    elseif event == "PLAYER_TARGET_CHANGED" then
        OT:HandleTargetChanged(true)
        OT:RefreshDisplay(true)
    elseif event == "PLAYER_REGEN_DISABLED" then
        OT.regenState = "COMBAT"
        OT.lastRegenEventAt = GetTime()
        OT:BeginCombatTracking()
        OT:RefreshDisplay(true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Do not tear down providers on the same frame. Delayed combat-log
        -- messages and transient old-client state changes still need one final
        -- sample. Poll() ends the fight after the combat-evidence grace period.
        OT.regenState = "IDLE"
        OT.lastRegenEventAt = GetTime()
        OT.playerRegenEnabledAt = OT.lastRegenEventAt
        OT.lastCombatEvidenceAt = OT.lastRegenEventAt
        OT.lastCombatEvidenceReason = "PLAYER_REGEN_ENABLED grace"
        OT:RefreshDisplay(true)
    elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        OT:ScheduleGroupRefresh("group roster changed")
    elseif event == "UNIT_PET" then
        OT:ScheduleGroupRefresh("pet roster changed")
    elseif event == "CHAT_MSG_ADDON" then
        if arg2 and strfind(arg2, "TWTv4=", 1, 1) then
            OT:HandleServerPacket(arg2)
            OT:RefreshDisplay(true)
        end
    elseif event == "CHAT_MSG_COMBAT_SELF_HITS"
        or event == "CHAT_MSG_COMBAT_SELF_MISSES"
        or event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS"
        or event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES"
        or event == "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE"
        or event == "CHAT_MSG_SPELL_SELF_DAMAGE"
        or event == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE"
        or event == "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF"
        or event == "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_OTHERS"
        or event == "CHAT_MSG_COMBAT_PET_HITS"
        or event == "CHAT_MSG_SPELL_PET_DAMAGE"
        or event == "CHAT_MSG_SPELL_SELF_BUFF"
        or event == "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS"
        or event == "CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF"
        or event == "CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS" then
        local combatEvidence = event == "CHAT_MSG_COMBAT_SELF_HITS"
            or event == "CHAT_MSG_COMBAT_SELF_MISSES"
                    or event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS"
            or event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES"
            or event == "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE"
            or event == "CHAT_MSG_SPELL_SELF_DAMAGE"
            or event == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE"
            or event == "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF"
            or event == "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_OTHERS"
            or event == "CHAT_MSG_COMBAT_PET_HITS"
            or event == "CHAT_MSG_SPELL_PET_DAMAGE"

        if combatEvidence then
            OT:NoteCombatEvidence("combat message: " .. tostring(event))
            if not OT.inCombat and OT.currentTargetKey then
                OT:BeginCombatTracking()
            end
        end
        if OT.Local and OT.Local.HandleEvent and OT.Local:HandleEvent(event, arg1, combatEvidence) then
            OT:RefreshDisplay(true)
        end
    elseif event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" then
        if event == "PLAYER_ALIVE" and OT:HasLiveCombatEvidence() then
            OT.regenState = "COMBAT"
            OT:NoteCombatEvidence("player alive in combat")
        end
        OT.inCombat = OT:IsGroupInCombat()
        OT:RefreshDisplay(true)
    end
end)

OT.eventFrame:SetScript("OnUpdate", function()
    if OT.initialized then
        OT:Poll()
    end
end)
