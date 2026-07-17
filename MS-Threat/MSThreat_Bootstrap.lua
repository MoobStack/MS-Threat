-- MSThreat_Bootstrap.lua
-- Loaded before the core so commands remain available if a later file fails.

MSThreat = MSThreat or {}
OctoThreat = MSThreat -- Temporary runtime compatibility alias.
local OT = MSThreat

OT.bootstrapLoaded = true
OT.bootstrapVersion = "1.0.8"
OT.loadStage = "bootstrap loaded"
OT.displayName = "MS Threat"
OT.publisher = "MoobStack"

local function BootstrapPrint(message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff55c8ffMS Threat:|r " .. tostring(message or ""))
    end
end

local function Dispatch(message)
    local ok
    local errorText
    local command = string.lower(tostring(message or ""))

    if command == "bootstrap" or command == "loadstatus" then
        BootstrapPrint("Bootstrap " .. tostring(OT.bootstrapVersion)
            .. " | stage: " .. tostring(OT.loadStage or "unknown")
            .. " | core: " .. (OT.coreLoaded and "loaded" or "not loaded")
            .. " | initialized: " .. (OT.initialized and "yes" or "no"))
        if OT.initializationError or OT.loadError then
            BootstrapPrint("Last initialization error: "
                .. tostring(OT.initializationError or OT.loadError))
        end
        return
    end

    if not OT.coreLoaded or type(OT.HandleSlash) ~= "function" then
        BootstrapPrint("The command bootstrap loaded, but the core did not finish loading.")
        BootstrapPrint("Load stage: " .. tostring(OT.loadStage or "unknown")
            .. ". Use /console scriptErrors 1 and /reload for the underlying error.")
        return
    end

    if not OT.initialized and type(OT.SafeInitialize) == "function" then
        OT:SafeInitialize("slash command")
    elseif not OT.initialized and type(OT.TryInitialize) == "function" then
        OT:TryInitialize("slash command")
    end

    if not OT.initialized then
        BootstrapPrint("The core loaded, but initialization is not complete.")
        if OT.initializationError or OT.loadError then
            BootstrapPrint("Last initialization error: "
                .. tostring(OT.initializationError or OT.loadError))
        else
            BootstrapPrint("Enter /msthreat bootstrap for load diagnostics.")
        end
        return
    end

    ok, errorText = pcall(OT.HandleSlash, OT, message)
    if not ok then
        OT.initializationError = tostring(errorText)
        BootstrapPrint("Command failed: " .. tostring(errorText))
    end
end

SlashCmdList = SlashCmdList or {}
SLASH_MSTHREAT1 = "/msthreat"
SLASH_MSTHREAT2 = "/mst"
SLASH_MSTHREAT3 = "/msthreatmeter"
SLASH_MSTHREAT4 = "/othreat"
SLASH_MSTHREAT5 = "/octothreat"
SlashCmdList["MSTHREAT"] = Dispatch

-- Compatibility for integrations that referenced the former dispatcher key.
SlashCmdList["OCTOTHREAT"] = Dispatch
MSThreat_CommandDispatch = Dispatch
OctoThreat_CommandDispatch = Dispatch
