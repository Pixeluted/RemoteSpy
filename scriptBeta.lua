-- CREDIT TO https://github.com/Upbolt/Hydroxide/ FOR INSPIRATION AND A FEW FORKED TOSTRING FUNCTIONS

-- TO DO:
    -- Make main window remote list use popups (depends on OnRightClick)
    -- Make arg list use right click (depends on defcon)

local mt = getrawmetatable(game)
if islclosure(mt.__namecall) or islclosure(mt.__index) or islclosure(mt.__newindex) then
    error("script incompatibility detected, one of your scripts has set the game's metamethods to a luaclosure, please run the remotespy prior to that script")
end

if not RenderWindow then
    error("EXPLOIT NOT SUPPORTED - GET SYNAPSE V3")
end

local function cleanUpSpy()
    for _,v in _G.remoteSpyCallbackHooks do
        restorefunction(v)
    end

    for _,v in _G.remoteSpySignalHooks do
        if issignalhooked(v) then
            restoresignal(v)
        end
    end
    
    _G.remoteSpyMainWindow:Clear()
    _G.remoteSpySettingsWindow:Clear()
    _G.remoteSpyMainWindow = nil
    _G.remoteSpySettingsWindow = nil 
    
    local oldHooks = _G.remoteSpyHooks

    local unHook = syn.oth.unhook
    unHook(Instance.new("RemoteEvent").FireServer, oldHooks.FireServer)
    unHook(Instance.new("RemoteFunction").InvokeServer, oldHooks.InvokeServer)
    unHook(Instance.new("BindableEvent").Fire, oldHooks.Fire)
    unHook(Instance.new("BindableFunction").Invoke, oldHooks.Invoke)

    unHook(mt.__namecall, oldHooks.Namecall)
    unHook(mt.__index, oldHooks.Index)
    unHook(mt.__newindex, oldHooks.NewIndex)
end

if _G.remoteSpyMainWindow or _G.remoteSpySettingsWindow then
    cleanUpSpy()
end

local HttpService = cloneref(game:GetService("HttpService"))
local Players = cloneref(game:GetService("Players"))

local client, clientid
if not client then -- autoexec moment
    task.spawn(function()
        repeat task.wait(); until Players.LocalPlayer
        client = cloneref(Players.LocalPlayer)
        clientid = client:GetDebugId()
    end)
end

local Settings = {
    FireServer = true,
    InvokeServer = true,
    Fire = false,
    Invoke = false,
    
    OnClientEvent = false,
    OnClientInvoke = false,
    OnEvent = false,
    OnInvoke = false,

    Paused = false,
    AlwaysOnTop = true,

    CallbackButtons = false,
    LogHiddenRemotesCalls = false,
    MoreRepeatCallOptions = false,
    CacheLimit = true,
    MaxCallAmount = 1000,
    ArgLimit = 25,
    StoreCallStack = false,
    GetCallingScriptV2 = false,

    DecompilerOutput = 1,
    ConnectionsOutput = 1,
    PseudocodeOutput = 1,
    CallStackOutput = 1,

    PseudocodeLuaUTypes = false,
    PseudocodeWatermark = true,
    PseudocodeInliningMode = 2,
    PseudocodeInlineRemote = true,
    PseudocodeInlineHiddenNils = true,
    PseudocodeFormatTables = true,
    InstanceTrackerMode = 1,
    OptimizedInstanceTracker = false
}

local function saveConfig()
    if not isfolder("Remote Spy Settings") then
        makefolder("Remote Spy Settings")
    end
    writefileasync("Remote Spy Settings/Settings.json", HttpService:JSONEncode(Settings))
end

if not isfile("Remote Spy Settings/Settings.json") then
    saveConfig()
else
    local tempSettings = HttpService:JSONDecode(readfile("Remote Spy Settings/Settings.json"))
    for i,v in tempSettings do -- this is in case I add new settings
        if Settings[i] ~= nil and type(Settings[i]) == type(v) then
            Settings[i] = v
        end
    end
end

if isfile("Remote Spy Settings/Icons.ttf") then
    delfile("Remote Spy Settings/Icons.ttf") -- no longer caching stuff, i'll do that later once i have a good system to cache the script and the icons
end

local fontData = syn.request({ Url = "https://raw.githubusercontent.com/GameGuyThrowaway/RemoteSpy/main/Icons.ttf" }).Body

Drawing:WaitForRenderer()

local RemoteIconFont = DrawFont.Register(fontData, {
    Scale = false,
    Bold = false,
    UseStb = false,
    PixelSize = 18,
    Glyphs = {
        {0xE000, 0xE007}
    }
})

local CallerIconFont = DrawFont.Register(fontData, {
    Scale = false,
    Bold = false,
    UseStb = false,
    PixelSize = 27,
    Glyphs = {
        {0xE008, 0xE009}
    }
})

local fontSize = 18
local DefaultTextFont = DrawFont.RegisterDefault("NotoSans_Regular", {
    Scale = false,
    Bold = false,
    UseStb = true,
    PixelSize = fontSize
})

local getCallStack, getOriginalThread, getDebugId, getThreadIdentity, setThreadIdentity, getn, ceil, floor, colorHSV, colorRGB, tableInsert, tableClear, tableRemove, deferFunc, spawnFunc, gsub, rep, sub, split, strformat, lower, match, pack = debug.getcallstack, syn.oth.get_original_thread, game.GetDebugId, syn.get_thread_identity, syn.set_thread_identity, table.getn, math.ceil, math.floor, Color3.fromHSV, Color3.fromRGB, table.insert, table.clear, table.remove, task.defer, task.spawn, string.gsub, string.rep, string.sub, string.split, string.format, string.lower, string.match, table.pack


local oldIndex; -- this is for signal indexing
local oldNewIndex; -- this is for OnClientInvoke hooks

local watermarkString = "--Pseudocode Generated by GameGuy's Remote Spy\n"

local inf, neginf = (1/0), (-1/0)

local othHook = syn.oth.hook

local optimizedInstanceTrackerFunctionString = [[local function GetInstancesFromDebugIds(...)
    local ids = {...}
    local instances = {}
    local idCount = #ids -- micro optimizations
    local find = table.find

    for _,v in getnilinstances() do
        local discovery = find(ids, v:GetDebugId())
        if discovery then
            instances[discovery] = v
            if #instances == idCount then 
                return unpack(instances)
            end
        end
    end

    for _,v in game:GetDescendants() do
        local discovery = find(ids, v:GetDebugId())
        if discovery then
            instances[discovery] = v
            if #instances == idCount then 
                return unpack(instances)
            end
        end
    end

    return unpack(instances)
end]]

local instanceTrackerFunctionString = [[local function GetInstanceFromDebugId(id: string)
    for _,v in getnilinstances() do
        if v:GetDebugId() == id then
            return v
        end
    end

    for _,v in game:GetDescendants() do
        if v:GetDebugId() == id then
            return v
        end
    end
end]]

local red = colorRGB(255, 0, 0)
local green = colorRGB(0, 255, 0)
local white = colorRGB(255, 255, 255)
local grey = colorRGB(144, 144, 144)
local black = colorRGB()

local styleOptions = {
    WindowRounding = 5,
    WindowTitleAlign = Vector2.new(0.5, 0.5),
    WindowBorderSize = 1,
    FrameRounding = 3,
    ButtonTextAlign = Vector2.new(0, 0.5),
    PopupRounding = 5,
    PopupBorderSize = 1
}

local colorOptions = {
    Border = {black, 1},
    TitleBgActive = {colorRGB(35, 35, 38), 1},
    TitleBg = {colorRGB(35, 35, 38), 1},
    TitleBgCollapsed = {colorRGB(35, 35, 38), 1},
    WindowBg = {colorRGB(50, 50, 53), 1},
    PopupBg = {colorRGB(20, 20, 23), 0.95},
    Button = {colorRGB(75, 75, 78), 1},
    ButtonHovered = {colorRGB(85, 85, 88), 1},
    ButtonActive = {colorRGB(115, 115, 118), 1},
    Text = {white, 1},
    ResizeGrip = {colorRGB(65, 65, 68), 1},
    ResizeGripActive = {colorRGB(115, 115, 118), 1},
    ResizeGripHovered = {colorRGB(85, 85, 88), 1},
    CheckMark = {white, 1},
    FrameBg = {colorRGB(20, 20, 23), 1},
    FrameBgHovered = {colorRGB(22, 22, 25), 1},
    FrameBgActive = {colorRGB(30, 30, 35), 1},
    Tab = {colorRGB(33, 36, 38), 1},
    TabActive = {colorRGB(20, 20, 23), 1},
    TabHovered = {colorRGB(119, 119, 119), 1},
    TabUnfocused = {colorRGB(60, 60, 60), 1},
    TabUnfocusedActive = {colorRGB(20, 20, 23), 1},
    HeaderHovered = {colorRGB(55, 55, 55), 1},
    HeaderActive = {colorRGB(75, 75, 75), 1},
}

local function resizeText(original, newWidth, proceedingChars, font)  -- my fix using this and purifyString is pretty garbage as it brute forces the string size, but before that it makes a really rough guess on the maximum length of the string, allowing for general optimization for speed, but it isn't perfect.  The current system is **enough**, taking approx 370 microseconds, but could be improved greatly.  Fundamentally, this fix is also flawed because of how hard coded it is, and how unnecessarily it passes args through getArgString.
    if type(original) ~= "string" then warn("non string text passed to resizeText"); return original end

    local charSize = font:GetTextBounds(fontSize, original).X
    if charSize < newWidth then return original end

    local newCharCount = floor(newWidth/(charSize/#original))
    local bestText = sub(original, 1, newCharCount)
    
    if proceedingChars == "...   " and fontSize == 18 then
        newWidth -= 18
    else
        newWidth -= font:GetTextBounds(fontSize, proceedingChars).X
    end

    local steps = 0

    local newSize = font:GetTextBounds(fontSize, bestText).X
    if newSize <= newWidth then
        local res = ceil((newWidth - newSize)/fontSize)
        local oldText = ""
        while true do
            steps += 1
            local newText = sub(original, 1, newCharCount+res)
            local newerSize = font:GetTextBounds(fontSize, newText).X

            if newerSize > newWidth then
                if res == 1 then
                    return oldText .. proceedingChars
                else
                    res = ceil(res/2)
                end
            else
                newCharCount = #newText
                oldText = newText
            end
        end
    else
        local res = ceil((newSize - newWidth)/fontSize)
        while true do
            steps += 1
            local newText = sub(original, 1, newCharCount-res)
            local newerSize = font:GetTextBounds(fontSize, newText).X

            if newerSize < newWidth then
                if res == 1 then
                    return newText .. proceedingChars
                else
                    res = floor(res/2)
                end
            else
                newCharCount = #newText
            end
        end
    end
end

local function newHookMetamethod(toHook, mtmethod, hookFunction, filter)
    local oldFunction

    local func = getfilter(filter, function(...) 
        return oldFunction(...)
    end, hookFunction)

    restorefunction(getrawmetatable(toHook)[mtmethod]) -- restores any old hooks
    oldFunction = othHook(getrawmetatable(toHook)[mtmethod], func) -- hookmetamethod(toHook, mtmethod, func) 
    return oldFunction
end

local function filteredOth(toHook, hookFunction, filter)
    local oldFunction

    local func = getfilter(filter, function(...) 
        return oldFunction(...)
    end, hookFunction)

    restorefunction(toHook)
    oldFunction = othHook(toHook, func)
    return oldFunction
end

local function pushError(title: string, message: string)
    syn.toast_notification({
        Type = ToastType.Error,
        Duration = 5,
        Title = message and title or "RemoteSpy",
        Content = message or title
    })
end

local function pushSuccess(message: string)
    syn.toast_notification({
        Type = ToastType.Success,
        Duration = 5,
        Title = "Remote Spy",
        Content = message
    })
end

local function outputData(source, destination, destinationTitle, successMessage)
    if destination == 1 then
        setclipboard(source)
        pushSuccess(successMessage .. " to Clipboard")
    elseif destination == 2 then
        createuitab(destinationTitle, source)
        pushSuccess(successMessage .. " to External UI")
    elseif destination == 3 then
        pushError("Internal UI Output Not Yet Supported")
    end
end

--[[
    * I need to make ShallowClone actually convert indexes correctly, as opposed to taking them at face value.
        If the game passes an instance as an index to a sub table, it'll store it as a strong reference.

    * I need to make ShallowClone properly clone userdatas as opposed to just storing them directly.
        Many userdatas gc, and they can tell that I'm storing them directly.
        I can make unsupported gcs show up as unsupported and not store.
]]

local function shallowClone(myTable: table, callType: string, first: boolean, stack: number?) -- cyclic check built in
    stack = stack or 0 -- you can offset stack by setting the starting parameter to a number
    local newTable = {}
    local hasTable = false
    local hasNilParentedInstance = false
    local started = false
    local originalDepth = stack

    if stack == 300 then -- this stack overflow check doesn't really matter as a stack overflow check, it's just here to make sure there are no cyclic tables.  While I could just check for cyclics directly, this is faster.
        return false, stack
    end
    for i,v in next, myTable do
        if not started then started = true; stack += 1 end
        local primType = type(v)
        if primType == "table" then
            hasTable = true
            local newTab, maxStack, _, subHasNilParentedInstance = shallowClone(v, callType, false, originalDepth)
            hasNilParentedInstance = hasNilParentedInstance or subHasNilParentedInstance
            if maxStack > stack then
                stack = maxStack
            end
            
            if newTab then
                newTable[i] = newTab
            else
                return false, stack -- stack overflow
            end
        elseif primType == "userdata" then
            local mainType = typeof(v)
            if mainType == "Instance" then
                if not hasNilParentedInstance and not v.IsDescendantOf(v, game) then
                    hasNilParentedInstance = true
                end
                newTable[i] = cloneref(v)
            elseif mainType == "userdata" then -- newproxy()
                newTable[i] = nil
            else
                newTable[i] = v
            end
        elseif primType == "thread" then
            newTable[i] = nil
        elseif primType == "function" and (callType == "RemoteEvent" or callType == "RemoteFUnction") then
            newTable[i] = nil
        else
            newTable[i] = v
        end
    end

    if first then -- set any nils in the middle so the table size is correct (make it a consecutive index array)
        for i = 1, #myTable do -- # is safe here because it's calling my own table, but getn could be used too
            if newTable[i] == nil then
                newTable[i] = nil
            end
        end
    end

    return newTable, stack, hasTable, hasNilParentedInstance
end

local function pushTheme(window: RenderChildBase)
    for i,v in styleOptions do
        window:SetStyle(RenderStyleOption[i], v)
    end

    for i,v in colorOptions do
        window:SetColor(RenderColorOption[i], v[1], v[2])
    end
end

local function addSpacer(window, amt: number)
    local bufferMain = window:Dummy()
    bufferMain:SetColor(RenderColorOption.Button, black, 0)
    bufferMain:SetColor(RenderColorOption.ButtonActive, black, 0)
    bufferMain:SetColor(RenderColorOption.ButtonHovered, black, 0)
    local buffer = bufferMain:Button()
    buffer.Size = Vector2.new(10, amt)
    return bufferMain
end

local asciiFilteredCharacters = {
    -- before 0x20 is control characters
    [" "] = "\\x20",
    ["!"] = "\\x21",
    ["\\\""] = "\\x22",
    ["#"] = "\\x23",
    ["$"] = "\\x24",
    ["%%"] = "\\x25",
    ["&"] = "\\x26",
    ["\\\'"] = "\\x27",
    ["("] = "\\x28",
    [")"] = "\\x29",
    ["*"] = "\\x2A",
    ["+"] = "\\x2B",
    [","] = "\\x2C",
    ["-"] = "\\x2D",
    ["."] = "\\x2E",
    ["/"] = "\\x2F",
    -- 0x30 ~ 0x39 is nums
    [":"] = "\\x3A",
    [";"] = "\\x3B",
    ["<"] = "\\x3C",
    ["="] = "\\x3D",
    [">"] = "\\x3E",
    ["?"] = "\\x3F",
    ["@"] = "\\x40",
    -- 0x41 ~ 0x5A is uppercase alphas
    ["["] = "\\x5B",
    ["\\\\"] = "\\x5C",
    ["]"] = "\\x5D",
    ["^"] = "\\x5E",
    ["_"] = "\\x5F",
    ["`"] = "\\x60",
    -- 0x61 ~ 0x7A  is lowercase alphas
    ["{"] = "\\x7B",
    ["|"] = "\\x7C",
    ["}"] = "\\x7D",
    ["~"] = "\\x7E"
}

local synEncode = syn.crypt.url.encode

local function purifyString(str: string, quotes: boolean, maxLength: number) -- my fix using this and resizeText is pretty garbage as it brute forces the string size, but before that it makes a really rough guess on the maximum length of the string, allowing for general optimization for speed, but it isn't perfect.  The current system is **enough**, taking approx 370 microseconds, but could be improved greatly.  Fundamentally, this fix is also flawed because of how hard coded it is, and how unnecessarily it passes args through getArgString.
    if type(maxLength) == "number" then
        str = sub(str, 1, maxLength)
    end
    str = gsub(synEncode(str), "%%", "\\x")
    if type(maxLength) == "number" then
        str = sub(str, 1, maxLength)
    end

    for i,v in asciiFilteredCharacters do
        str = gsub(str, v, i)
    end

    if quotes then
        return '"' .. str .. '"'
    else
        return str
    end
end

local gameId, workspaceId = getDebugId(game), getDebugId(workspace)

local function instanceParentedToNil(instance)
    local instanceId = instance:GetDebugId()
    for _,v in getnilinstances() do
        if v:GetDebugId() == instanceId then
            return true
        end
    end
end

local function getInstancePath(instance) -- FORKED FROM HYDROXIDE
    if not instance then return "NIL INSTANCE" end
    local name = instance.Name
    local head = (#name > 0 and '.' .. name) or "['']"
    
    if not instance.Parent and instance ~= game then
        if not instanceParentedToNil(instance) then
            return head .. " --[[ INSTANCE DELETED FROM GAME ]]", false
        else
            return head .. " --[[ PARENTED TO NIL ]]", false
        end
    end
    setThreadIdentity(8)
    local id = getDebugId(instance)
    
    if id == gameId then
        return "game", true, true
    elseif id == workspaceId then
        return "workspace", true, true
    else
        local plr = Players:GetPlayerFromCharacter(instance)
        if plr then
            if getDebugId(plr) == clientid then
                return 'game:GetService("Players").LocalPlayer.Character', true, true
            else
                if tonumber(sub(plr.Name, 1, 1)) then
                    return 'game:GetService("Players")["'..plr.Name..'"]".Character', true, true
                else
                    return 'game:GetService("Players").'..plr.Name..'.Character', true, true
                end
            end
        end
        local _success, result = pcall(game.GetService, game, instance.ClassName)
        
        if _success and result then
            return 'game:GetService("' .. instance.ClassName .. '")', true, true
        elseif id == clientid then -- cloneref moment
            return 'game:GetService("Players").LocalPlayer', true, true
        else
            local nonAlphaNum = gsub(name, '[%w_]', '')
            local noPunct = gsub(nonAlphaNum, '[%s%p]', '')
            
            if tonumber(sub(name, 1, 1)) or (#nonAlphaNum ~= 0 and #noPunct == 0) then
                head = '[' .. purifyString(name, true) .. ']'
            elseif #nonAlphaNum ~= 0 and #noPunct > 0 then
                head = '[' .. purifyString(name, true) .. ']'
            end
        end
    end
    
    return (getInstancePath(instance.Parent) .. head), true
end

local tableToString;

local userdataValue = function(data: any) -- FORKED FROM HYDROXIDE
    local dataType = typeof(data)

    if dataType == "userdata" then
        return "nil"
    elseif dataType == "Instance" then
        return tostring(getInstancePath(data))
    elseif dataType == "BrickColor" then
        return dataType .. ".new(\"" .. tostring(data) .. "\")"
    elseif
        dataType == "TweenInfo" or
        dataType == "Vector3" or
        dataType == "Vector2" or
        dataType == "CFrame" or
        dataType == "Color3" or
        dataType == "Random" or
        dataType == "Faces" or
        dataType == "UDim2" or
        dataType == "UDim" or
        dataType == "Rect" or
        dataType == "Axes" or
        dataType == "NumberRange" or
        dataType == "RaycastParams" or
        dataType == "PhysicalProperties"
    then
        return dataType .. ".new(" .. tostring(data) .. ")"
    elseif dataType == "DateTime" then
        return dataType .. ".now()"
    elseif dataType == "PathWaypoint" then
        local splitstr = split(tostring(data), '}, ')
        local vector = gsub(splitstr[1], '{', "Vector3.new(")
        return dataType .. ".new(" .. vector .. "), " .. splitstr[2] .. ')'
    elseif dataType == "Ray" then
        local splitstr = split(tostring(data), '}, ')
        local vprimary = gsub(splitstr[1], '{', "Vector3.new(")
        local vsecondary = gsub(gsub(splitstr[2], '{', "Vector3.new("), '}', ')')
        return "Ray.new(" .. vprimary .. "), " .. vsecondary .. ')'
    elseif dataType == "Region3" then
        local size = data.Size
        local position = data.CFrame.Position

        local startVec = "Vector3.new(" .. tostring(position.X - size.X/2) .. ", " .. tostring(position.Y - size.Y/2) .. ", " .. tostring(position.Z - size.Z/2) .. ")"
        local endVec = "Vector3.new(" .. tostring(position.X + size.X/2) .. ", " .. tostring(position.Y + size.Y/2) .. ", " .. tostring(position.Z + size.Z/2) .. ")"
        return "Region3.new(" .. startVec .. ", " .. endVec .. ")"
    elseif dataType == "ColorSequence" or dataType == "NumberSequence" then 
        return dataType .. ".new(" .. tableToString(data.Keypoints) .. ')'
    elseif dataType == "ColorSequenceKeypoint" then
        return "ColorSequenceKeypoint.new(" .. data.Time .. ", Color3.new(" .. tostring(data.Value) .. "))"
    elseif dataType == "NumberSequenceKeypoint" then
        local envelope = data.Envelope and data.Value .. ", " .. data.Envelope or data.Value
        return "NumberSequenceKeypoint.new(" .. data.Time .. ", " .. envelope .. ")"
    end

    return tostring(data) -- unsupported userdata
end

-- localized elsewhere

tableToString = function(data, format, call, debugMode, root, indents) -- FORKED FROM HYDROXIDE
    local dataType = type(data)

    format = format == nil and true or format

    if dataType == "userdata" or dataType == "vector" then
        if typeof(data) == "Instance" then
            local str, parented, bypasses = getInstancePath(data)
            if (debugMode == 3 or (debugMode == 2 and parented)) and not bypasses then
                return ("GetInstanceFromDebugId(\"" .. getDebugId(data) .."\")") .. (" -- Original Path: " .. str)
            else
                return str    
            end
        else
            return userdataValue(data)
        end
    elseif dataType == "string" then
        local success, result = pcall(purifyString, data, true)
        return (success and result) or tostring(data)
    elseif dataType == "table" then
        indents = indents or 1
        root = root or data

        local head = format and '{\n' or '{ '
        local indent = rep('\t', indents)
        local orderedNumbers = (#pack(ipairs(data))[2] ~= 0)
        local elements = 0
        -- moved checkCyclic check to hook
        if format then
            if orderedNumbers then
                for i,v in data do
                    if type(i) == "string" then continue end

                    if i ~= (elements + 1) then
                        head ..= strformat("%s[%s] = %s,\n", indent, tostring(i), tableToString(v, true, call, debugMode, root, indents + 1))
                    else
                        head ..= strformat("%s%s,\n", indent, tableToString(v, true, call, debugMode, root, indents + 1))
                    end
                    elements += 1
                end
            else
                for i,v in data do
                    head ..= strformat("%s[%s] = %s,\n", indent, tableToString(i, true, call, debugMode, root, indents + 1), tableToString(v, true, call, debugMode, root, indents + 1))
                end
            end
        else
            if orderedNumbers then
                for i,v in data do
                    if type(i) == "string" then continue end

                    if i ~= (elements + 1) then
                        head ..= strformat("%s[%s] = %s,\n", indent, tostring(i), tableToString(v, false, call, debugMode, root, indents + 1))
                    else
                        head ..= strformat("%s, ", tableToString(v, false, call, debugMode, root, indents + 1))
                    end
                    elements += 1
                end
            else
                for i,v in data do
                    head ..= strformat("[%s] = %s, ", tableToString(i, false, call, debugMode, root, indents + 1), tableToString(v, false, call, debugMode, root, indents + 1))
                end
            end
        end
        
        if format then
            return #head > 2 and strformat("%s\n%s", sub(head, 1, -3), rep('\t', indents - 1) .. '}') or "{}"
        else
            return #head > 2 and (sub(head, 1, -3) .. ' }') or "{}"
        end
    elseif dataType == "function" then -- functions are only receivable through bindables, not remotes
        return 'nil --[[ ' .. tostring(data) .. " ]]" -- just in case
    elseif dataType == "number" then
        local dataStr = tostring(data)
        if not match(dataStr, "%d") then
            if data == inf then
                return "(1/0)"
            elseif data == neginf then
                return "(-1/0)"
            elseif dataStr == "nan" then
                return "(0/0)"
            else
                return ("tonumber(\"" .. dataStr .. "\")")
            end
        else
            return dataStr
        end
    else
        return tostring(data)
    end
end

local types = {
    ["string"] = { colorHSV(29/360, 0.8, 1), function(obj, maxLength)
        return purifyString(obj, true, maxLength)
    end },
    ["number"] = { colorHSV(120/360, 0.8, 1), function(obj)
        return tostring(obj)
    end },
    ["boolean"] = { colorHSV(211/360, 0.8, 1), function(obj)
        return tostring(obj)
    end },
    ["table"] = { white, function(obj)
        return tostring(obj)
    end },

    --[[["userdata"] = { colorHSV(258/360, 0.8, 1), function(obj)
        return "Unprocessed Userdata: " .. typeof(obj) .. ": " .. tostring(obj)
    end },
    ["Instance"] = { colorHSV(57/360, 0.8, 1), function(obj)
        return tostring(obj)
    end },]]

    ["function"] = { white, function(obj)
        -- functions can't be received by Remotes, but can be received by Bindables
        return tostring(obj)
    end },
    ["nil"] = { colorHSV(360/360, 0.8, 1), function(obj)
        return "nil"
    end }
}

local function getArgString(arg, maxLength)
    local t = type(arg)

    if types[t] and t ~= "userdata" then
        local st = types[t]
        return st[2](arg, maxLength), st[1]
    elseif t == "userdata" or t == "vector" then
        local st = userdataValue(arg)
        return st, (typeof(arg) == "Instance" and colorHSV(57/360, 0.8, 1)) or colorHSV(314/360, 0.8, 1)
    else
        return ("Unprocessed Lua Type: " .. tostring(t)), colorRGB(1, 1, 1)
    end
end

local spaces = "                 "
local spaces2 = "        " -- 8 spaces

local idxs = {
    FireServer = 1,
    InvokeServer = 2,
    Fire = 3,
    Invoke = 4,

    fireServer = 1,
    invokeServer = 2,
    fire = 3,
    invoke = 4,
    
    OnClientEvent = 5,
    OnClientInvoke = 6,
    Event = 7,
    OnInvoke = 8,
}

local spyFunctions = {
    {
        Name = "FireServer",
        Object = "RemoteEvent",
        Type = "Call",
        Method = "FireServer",
        DeprecatedMethod = "fireServer",
        Enabled = Settings.FireServer,
        Icon = "\xee\x80\x80  ",
        Indent = 0
    },
    {
        Name = "InvokeServer",
        Object = "RemoteFunction",
        Type = "Call",
        ReturnsValue = true,
        Method = "InvokeServer",
        DeprecatedMethod = "invokeServer",
        Enabled = Settings.InvokeServer,
        Icon = "\xee\x80\x81  ",
        Indent = 153
    },
    {
        Name = "Fire",
        Object = "BindableEvent",
        Type = "Call",
        FiresLocally = true,
        Method = "Fire",
        DeprecatedMethod = "fire",
        Enabled = Settings.Fire,
        Icon = "\xee\x80\x82  ",
        Indent = 319
    },
    {
        Name = "Invoke",
        Object = "BindableFunction",
        Type = "Call",
        ReturnsValue = true,
        FiresLocally = true,
        Method = "Invoke",
        DeprecatedMethod = "invoke",
        Enabled = Settings.Invoke,
        Icon = "\xee\x80\x83  ",
        Indent = 434
    },

    {
        Name = "OnClientEvent",
        Object = "RemoteEvent",
        HasNoCaller = true,
        Type = "Connection",
        Connection = "OnClientEvent",
        DeprecatedConnection = "onClientEvent",
        Enabled = Settings.OnClientEvent,
        Icon = "\xee\x80\x84  ",
        Indent = 0
    },
    {
        Name = "OnClientInvoke",
        Object = "RemoteFunction",
        ReturnsValue = true,
        HasNoCaller = true,
        Type = "Callback",
        Callback = "OnClientInvoke",
        DeprecatedCallback = "onClientInvoke",
        Enabled = Settings.OnClientInvoke,
        Icon = "\xee\x80\x85  ",
        Indent = 153
    },
    {
        Name = "OnEvent",
        Object = "BindableEvent",
        Type = "Connection",
        Connection = "Event", -- not OnEvent cause roblox naming is wacky
        DeprecatedConnection = "event",
        Enabled = Settings.OnEvent,
        Icon = "\xee\x80\x86  ",
        Indent = 319
    },
    {
        Name = "OnInvoke",
        Object = "BindableFunction",
        ReturnsValue = true,
        Type = "Callback",
        Callback = "OnInvoke",
        DeprecatedCallback = "onInvoke",
        Enabled = Settings.OnInvoke,
        Icon = "\xee\x80\x87  ",
        Indent = 434
    }
}

local repeatCallSteps = {
    1,
    10,
    100,
    1000
}

local function repeatStringWithIndex(prefix: string, suffix: string, count: number)
    local retVal = ""
    for i = 1, count do
        retVal ..= (prefix .. tostring(i) .. suffix)
    end

    return retVal
end

local function genSendPseudo(rem, call, spyFunc)
    local watermark = Settings.PseudocodeWatermark and watermarkString or ""

    local debugMode = Settings.InstanceTrackerMode

    if debugMode == 3 or (debugMode == 2 and call.HasInstance) then
        watermark ..= (--[[Settings.OptimizedInstanceTracker and optimizedInstanceTrackerFunctionString or]] instanceTrackerFunctionString) .. "\n\n"
    else
        watermark ..= "\n"
    end

    local pathStr, parented = getInstancePath(rem)
    local remPath = ((debugMode == 3 or ((debugMode == 2) and not parented)) and ("GetInstanceFromDebugId(\"" .. getDebugId(rem) .."\")" .. " -- Original Path: " .. pathStr)) or pathStr

    if #call.Args == 0 and call.NilCount == 0 then
        if spyFunc.Type == "Call" then
            return watermark .. (Settings.PseudocodeInlineRemote and ("local remote" .. (Settings.PseudocodeLuaUTypes and (": " .. spyFunc.Object) or "").." = " .. remPath .. "\n\n" .. (spyFunc.ReturnsValue and ("local "..sub(repeatStringWithIndex("returnValue", ", ", #call.ReturnValue.Args), 1, -3).." = ") or "") .. "remote:") or (remPath .. ":")) .. spyFunc.Method .."()"
        elseif spyFunc.Type == "Connection" then
            return watermark .. (Settings.PseudocodeInlineRemote and ("local remote" .. (Settings.PseudocodeLuaUTypes and (": " .. spyFunc.Object) or "").." = " .. remPath .. "\n\nfiresignal(remote.") or ("firesignal(" .. remPath ".")) .. spyFunc.Connection ..")"
        elseif spyFunc.Type == "Callback" then
            return watermark .. (Settings.PseudocodeInlineRemote and ("local remote" .. (Settings.PseudocodeLuaUTypes and (": " .. spyFunc.Object) or "").." = " .. remPath .. "\n\ngetcallbackmember(remote, \"") or ("getcallbackmember(" .. remPath .. ", \"")) .. spyFunc.Callback .."\")()"
        end
    else
        local argCalls = {}
        local argCallCount = {}

        local pseudocode = ""
        local addedArg = false

        for i = 1, #call.Args do
            local arg = call.Args[i]
            local primTyp = type(arg)
            local tempTyp = typeof(arg)
            local typ = (gsub(tempTyp, "^%u", lower))

            argCallCount[typ] = argCallCount[typ] and argCallCount[typ] + 1 or 1

            local varName = typ .. tostring(argCallCount[typ])

            if primTyp == "nil" then
                tableInsert(argCalls, { typ, primTyp, "", "" })
                continue
            end
            
            local varPrefix = ""
            if primTyp ~= "function" and Settings.PseudocodeLuaUTypes then
                varPrefix = "local " .. varName .. ": ".. tempTyp .." = "
            else
                varPrefix = "local " .. varName .." = "
            end
            local varConstructor = ""

            if primTyp == "userdata" or primTyp == "vector" then -- roblox should just get rid of vector already
                if typeof(arg) == "Instance" then
                    local str, parented, bypasses = getInstancePath(arg)
                    if (debugMode == 3 or (debugMode == 2 and not parented)) and not bypasses then
                        varConstructor = ("GetInstanceFromDebugId(\"" .. getDebugId(arg) .."\")") .. (" -- Original Path: " .. str)
                    else
                        varConstructor = str
                    end
                else
                    varConstructor = userdataValue(arg)
                end
            elseif primTyp == "table" then
                varConstructor = tableToString(arg, Settings.PseudocodeFormatTables, call, debugMode)
            elseif primTyp == "string" then
                varConstructor = purifyString(arg, true)
            elseif primTyp == "function" then
                varConstructor = 'nil -- [[ ' .. tostring(arg) .. ' ]]' -- functions can be sent by bindables, but I can't exactly generate pseudocode for them
            elseif primTyp == "number" then
                local dataStr = tostring(arg)
                if not match(dataStr, "%d") then
                    if arg == inf then
                        varConstructor = "(1/0)"
                    elseif arg == neginf then
                        varConstructor = "(-1/0)"
                    elseif dataStr == "nan" then
                        varConstructor = "(0/0)"
                    else
                        varConstructor = ("tonumber(\"" .. dataStr .. "\")")
                    end
                else
                    varConstructor = dataStr
                end
            else
                varConstructor = tostring(arg)
            end

            tableInsert(argCalls, { typ, primTyp, varConstructor, varName })

            if Settings.PseudocodeInliningMode == 3 and primTyp == "table" then
                pseudocode ..= (varPrefix .. (varConstructor .. "\n"))
                addedArg = true
            elseif Settings.PseudocodeInliningMode == 2 and (primTyp == "table" or primTyp == "userdata") then
                pseudocode ..= (varPrefix .. (varConstructor .. "\n"))
                addedArg = true
            elseif Settings.PseudocodeInliningMode == 1 then
                pseudocode ..= (varPrefix .. (varConstructor .. "\n"))
                addedArg = true
            end
        end

        if Settings.PseudocodeInlineHiddenNils then 
            for i = 1, call.NilCount do
                pseudocode ..= "local hiddenNil" .. tostring(i) .. " = nil -- games can detect if this is missing, but likely won't.\n"
                addedArg = true
            end
        end
        if spyFunc.Type == "Call" then
            pseudocode ..= Settings.PseudocodeInlineRemote and ((addedArg and "\n" or "") .. "local remote" .. (Settings.PseudocodeLuaUTypes and (": " .. spyFunc.Object) or "").." = " .. remPath .. "\n" .. (spyFunc.ReturnsValue and "local returnValue = " or "") .. "remote:" .. spyFunc.Method .. "(") or (remPath .. ":" .. spyFunc.Method .. "(")
        elseif spyFunc.Type == "Connection" then
            pseudocode ..= Settings.PseudocodeInlineRemote and ((addedArg and "\n" or "") .. "local remote" .. (Settings.PseudocodeLuaUTypes and (": " .. spyFunc.Object) or "").." = " .. remPath .. "\n" .. (spyFunc.ReturnsValue--[[yes i know this is redundant]] and "local returnValue = " or "") .. "firesignal(remote." .. spyFunc.Connection .. ", ") or ("firesignal(" .. remPath .. "." .. spyFunc.Connection .. ", ")
        elseif spyFunc.Type == "Callback" then
            pseudocode ..= Settings.PseudocodeInlineRemote and ((addedArg and "\n" or "") .. "local remote" .. (Settings.PseudocodeLuaUTypes and (": " .. spyFunc.Object) or "").." = " .. remPath .. "\n" .. (spyFunc.ReturnsValue and "local returnValue = " or "") .. "getcallbackmember(remote, \"" .. spyFunc.Callback .. "\")(") or ("getcallbackmember(" .. remPath .. ", \"" .. spyFunc.Callback .. "\")(")
        end

        if Settings.PseudocodeInliningMode == 4 then
            for _,v in argCalls do
                if v[1] == "nil" then
                    pseudocode ..= "nil, "
                else
                    pseudocode ..= (v[3] .. ", ")
                end
            end
        elseif Settings.PseudocodeInliningMode == 3 then
            for _,v in argCalls do
                if v[1] == "nil" then
                    pseudocode ..= "nil, "
                elseif (v[2] == "table") then
                    pseudocode ..= ( v[4] .. ", " )
                else
                    pseudocode ..= ( v[3] .. ", " )
                end
            end
        elseif Settings.PseudocodeInliningMode == 2 then
            for _,v in argCalls do
                if v[1] == "nil" then
                    pseudocode ..= "nil, "
                elseif (v[2] == "table" or v[2] == "userdata") then
                    pseudocode ..= ( v[4] .. ", " )
                else
                    pseudocode ..= ( v[3] .. ", " )
                end
            end
        else
            for _,v in argCalls do
                if v[1] == "nil" then
                    pseudocode ..= "nil, "
                else
                    pseudocode ..= ( v[4] .. ", " )
                end
            end
        end

        if Settings.PseudocodeInlineHiddenNils then
            for i = 1, call.NilCount do
                pseudocode ..= ("hiddenNil" .. tostring(i) .. ", ")
            end
        else
            for _ = 1, call.NilCount do
                pseudocode ..= "nil, "
            end
        end

        return watermark .. (sub(pseudocode, -2, -2) == "," and sub(pseudocode, 1, -3) or pseudocode) .. ")" -- sub gets rid of the last ", "
    end
end

local function genReturnValuePseudo(returnTable, spyFunc)
    local watermark = Settings.PseudocodeWatermark and watermarkString .. "\n" or ""

    if #returnTable.Args == 0 and returnTable.NilCount == 0 then
        return watermark .. "return"
    else
        local argCalls = {}
        local argCallCount = {}

        local pseudocode = ""
        local addedArg = false

        for i = 1, #returnTable.Args do
            local arg = returnTable.Args[i]
            local primTyp = type(arg)
            local tempTyp = typeof(arg)
            local typ = (gsub(tempTyp, "^%u", lower))

            argCallCount[typ] = argCallCount[typ] and argCallCount[typ] + 1 or 1

            local varName = typ .. tostring(argCallCount[typ])

            if primTyp == "nil" then
                continue
            end

            local varPrefix = ""
            if primTyp ~= "function" and Settings.PseudocodeLuaUTypes then
                varPrefix = "local " .. varName .. ": ".. tempTyp .." = "
            else
                varPrefix = "local " .. varName .." = "
            end
            local varConstructor = ""

            if primTyp == "userdata" or primTyp == "vector" then -- roblox should just get rid of vector already
                varConstructor = userdataValue(arg)
            elseif primTyp == "table" then
                varConstructor = tableToString(arg, Settings.PseudocodeFormatTables, returnTable, 1)
            elseif primTyp == "string" then
                varConstructor = purifyString(arg, true)
            elseif primTyp == "function" then
                varConstructor = 'nil --[[ ' .. tostring(arg) .. ' ]]'
            elseif primTyp == "number" then
                local dataStr = tostring(arg)
                if not match(tostring(arg), "%d") then
                    if arg == inf then
                        varConstructor = "(1/0)"
                    elseif arg == neginf then
                        varConstructor = "(-1/0)"
                    elseif dataStr == "nan" then
                        varConstructor = "(0/0)"
                    else
                        varConstructor = ("tonumber(\"" .. dataStr .. "\")")
                    end
                else
                    varConstructor = dataStr
                end
            else
                varConstructor = tostring(arg)
            end

            tableInsert(argCalls, { typ, primTyp, varConstructor, varName })

            if Settings.PseudocodeInliningMode == 3 and primTyp == "table" then
                pseudocode ..= (varPrefix .. (varConstructor .. "\n"))
                addedArg = true
            elseif Settings.PseudocodeInliningMode == 2 and (primTyp == "table" or primTyp == "userdata") then
                pseudocode ..= (varPrefix .. (varConstructor .. "\n"))
                addedArg = true
            elseif Settings.PseudocodeInliningMode == 1 then
                pseudocode ..= (varPrefix .. (varConstructor .. "\n"))
                addedArg = true
            end
        end

        if Settings.PseudocodeInlineHiddenNils then 
            for i = 1, returnTable.NilCount do
                pseudocode ..= "local hiddenNil" .. tostring(i) .. " = nil -- games can detect if this is missing, but likely won't.\n"
                addedArg = true
            end
        end
        pseudocode ..= (addedArg and "\n" or "") .. "return "

        if Settings.PseudocodeInliningMode == 4 then
            for _,v in argCalls do
                if v[1] == "nil" then
                    pseudocode ..= "nil, "
                else
                    pseudocode ..= (v[3] .. ", ")
                end
            end
        elseif Settings.PseudocodeInliningMode == 3 then
            for _,v in argCalls do
                if v[1] == "nil" then
                    pseudocode ..= "nil, "
                elseif (v[2] == "table") then
                    pseudocode ..= ( v[4] .. ", " )
                else
                    pseudocode ..= ( v[3] .. ", " )
                end
            end
        elseif Settings.PseudocodeInliningMode == 2 then
            for _,v in argCalls do
                if v[1] == "nil" then
                    pseudocode ..= "nil, "
                elseif (v[2] == "table" or v[2] == "userdata") then
                    pseudocode ..= ( v[4] .. ", " )
                else
                    pseudocode ..= ( v[3] .. ", " )
                end
            end
        else
            for _,v in argCalls do
                if v[1] == "nil" then
                    pseudocode ..= "nil, "
                else
                    pseudocode ..= ( v[4] .. ", " )
                end
            end
        end

        if Settings.PseudocodeInlineHiddenNils then
            for i = 1, returnTable.NilCount do
                pseudocode ..= ("hiddenNil" .. tostring(i) .. ", ")
            end
        else
            for _ = 1, returnTable.NilCount do
                pseudocode ..= "nil, "
            end
        end

        return watermark .. sub(pseudocode, 1, -3) -- gets rid of last ", "
    end
end

local function genRecvPseudo(rem, call, spyFunc, watermark)
    local watermark = watermark and watermarkString or ""

    local debugMode = Settings.InstanceTrackerMode

    if debugMode == 3 or (debugMode == 2 and call.HasInstance) then
        watermark ..= (--[[Settings.OptimizedInstanceTracker and optimizedInstanceTrackerFunctionString or]] instanceTrackerFunctionString) .. "\n\n"
    else
        watermark ..= "\n"
    end

    local pathStr = getInstancePath(rem)
    local remPath = ((debugMode == 3 or ((debugMode == 2) and (sub(pathStr, -2, -1) == "]]"))) and ("GetInstanceFromDebugId(\"" .. getDebugId(rem) .."\")" .. " -- Original Path: " .. pathStr)) or pathStr

    if spyFunc.Type == "Connection" then
        local pseudocode = ""
        
        pseudocode ..= Settings.PseudocodeInlineRemote and ("local remote" .. (Settings.PseudocodeLuaUTypes and (": " .. spyFunc.Object) or "") .." = " .. remPath .. "\nremote." .. spyFunc.Connection .. ":Connect(function(") or (remPath .. "." .. spyFunc.Connection .. ":Connect(function(")
        for i = 1,#call.Args do
            pseudocode ..= "p" .. tostring(i) .. ", "
        end
        pseudocode = (sub(pseudocode, 1, -3) .. ")")

        pseudocode ..= "\n\tprint("
        for i = 1,#call.Args do
            pseudocode ..= "p"..tostring(i) .. ", "
        end
        pseudocode = (sub(pseudocode, 1, -3) .. ")")

        pseudocode ..= "\nend)"
        return watermark .. pseudocode
    elseif spyFunc.Type == "Callback" then
        local pseudocode = ""

        pseudocode ..= Settings.PseudocodeInlineRemote and ("local remote" .. (Settings.PseudocodeLuaUTypes and (": " .. spyFunc.Object) or "").." = " .. remPath .. "\nremote." .. spyFunc.Callback .. " = function(") or (remPath .. "." .. spyFunc.Callback .. " = function(")
        for i = 1,#call.Args do
            pseudocode ..= "p"..tostring(i) .. ", "
        end
        pseudocode = (sub(pseudocode, 1, -3) .. ")")

        pseudocode ..= "\n\tprint("
        for i = 1,#call.Args do
            pseudocode ..= "p"..tostring(i) .. ", "
        end
        pseudocode = (sub(pseudocode, 1, -3) .. ")")

        pseudocode ..= "\nend"
        return watermark .. pseudocode
    end
end

local otherLines = {}
local otherLogs = {}
local otherFuncs = {}
local callLines = {}
local callLogs = {}
local callFuncs = {}

local originalCallerCache = {}
local remoteNameCache = {}

local argLines = {}
local callbackButtonline

local searchBar -- declared later
local function clearFilter()
    for i,v in callLines do
        for _,x in spyFunctions do
            if v[1] == x.Name and (v[3].Label ~= "0" or callLogs[i].Ignored) and x.Enabled then
                v[2].Visible = true
                v[4].Visible = true
                break
            end
        end
    end
    for i,v in otherLines do
        for _,x in spyFunctions do
            if v[1] == x.Name and (v[3].Label ~= "0" or otherLogs[i].Ignored) and x.Enabled then
                v[2].Visible = true
                v[4].Visible = true
                break
            end
        end
    end
end

local function filterLines(name: string)
    if name == "" then 
        return clearFilter() 
    end

    for i,v in callLines do
        if not match(lower(tostring(i)), lower(name)) then -- check for if the remote actually had a log made
            v[2].Visible = false
            v[4].Visible = false
        elseif spyFunctions[idxs[v[1]]].Enabled then
            v[2].Visible = true
            v[4].Visible = true
        end
    end
    for i,v in otherLines do
        if not match(lower(tostring(i)), lower(name)) then -- check for if the remote actually had a log made
            v[2].Visible = false
            v[4].Visible = false
        elseif spyFunctions[idxs[v[1]]].Enabled then
            v[2].Visible = true
            v[4].Visible = true
        end
    end
end
    
local function updateLines(name: string, enabled: boolean)
    for i,v in callLines do
        if v[1] == name then
            if v[2].Visible ~= enabled then
                if (enabled and (v[3].Label ~= "0" or callLogs[i].Ignored)) or not enabled then
                    v[2].Visible = enabled
                    v[4].Visible = enabled
                end
            end
        end
    end
    for i,v in otherLines do
        if v[1] == name then
            if v[2].Visible ~= enabled then
                if (enabled and (v[3].Label ~= "0" or otherLogs[i].Ignored)) or not enabled then
                    v[2].Visible = enabled
                    v[4].Visible = enabled
                end
            end
        end
    end
    filterLines(searchBar.Value)
end

repeat task.wait() until pcall(function()
    _G.remoteSpyMainWindow = RenderWindow.new("Remote Spy")
end)
_G.remoteSpySettingsWindow = RenderWindow.new("Remote Spy Settings")
_G.remoteSpyCallbackHooks = {}
_G.remoteSpySignalHooks = {}
_G.remoteSpyHooks = {}

local mainWindow = _G.remoteSpyMainWindow
local mainWindowWeakReference = setmetatable({mainWindow}, {__mode="v"})
local settingsWindow = _G.remoteSpySettingsWindow
local settingsWindowWeakReference = setmetatable({settingsWindow}, {__mode="v"})
pushTheme(mainWindow)
pushTheme(settingsWindow)

-- settings page init
local settingsWidth = 310
local settingsHeight = 312
settingsWindow.DefaultSize = Vector2.new(settingsWidth, settingsHeight)
settingsWindow.CanResize = false
settingsWindow.VisibilityOverride = Settings.AlwaysOnTop
settingsWindow.Visible = false
settingsWindow:SetColor(RenderColorOption.ResizeGrip, black, 0)
settingsWindow:SetColor(RenderColorOption.ResizeGripActive, black, 0)
settingsWindow:SetColor(RenderColorOption.ResizeGripHovered, black, 0)
settingsWindow:SetStyle(RenderStyleOption.WindowPadding, Vector2.new(8, 4))
settingsWindow:SetStyle(RenderStyleOption.ButtonTextAlign, Vector2.new(0.5, 0.5))

-- main page init
local width = 562
mainWindow.DefaultSize = Vector2.new(width, 350)
mainWindow.MinSize = Vector2.new(width, 356)
mainWindow.MaxSize = Vector2.new(width, 5000)
mainWindow.VisibilityOverride = Settings.AlwaysOnTop

local frontPage = mainWindow:Dummy()
local remotePage = mainWindow:Dummy()

-- Below this is rendering Settings page

local topBar = settingsWindow:SameLine()
local exitButtonFrame = topBar:SameLine()
exitButtonFrame:SetColor(RenderColorOption.Button, black, 0)
--exitButtonFrame:SetColor(RenderColorOption.ButtonHovered, black, 0)
--exitButtonFrame:SetColor(RenderColorOption.ButtonActive, black, 0)

local exitButton = exitButtonFrame:Indent(settingsWidth-40):Button()
exitButton.Label = "\xef\x80\x8d"
exitButton.Size = Vector2.new(24, 24)
exitButton.OnUpdated:Connect(function()
    settingsWindowWeakReference[1].Visible = false
end)

local tabFrame = topBar:SameLine()
local settingsTabs = tabFrame:Indent(-1):Indent(1):TabMenu()
local generalTab = settingsTabs:Add("General")
local pseudocodeTab = settingsTabs:Add("Pseudocode")
local outputTab = settingsTabs:Add("Output")
local creditsTab = settingsTabs:Add("Credits")
do  -- general Settings
    local checkBox = generalTab:CheckBox()
    checkBox.Label = "Display Callbacks And Connections"
    checkBox.Value = Settings.CallbackButtons
    checkBox.OnUpdated:Connect(function(value)
        Settings.CallbackButtons = value
        callbackButtonline.Visible = value
        if not value then
            for i = 5,8 do
                local spyFunc = spyFunctions[i]
                spyFunc.Button.Value = false
                spyFunc.Enabled = false
                Settings[spyFunc.Name] = false
                updateLines(spyFunc.Name, false)
            end
        end
        saveConfig()
    end)

    local checkBox4 = generalTab:CheckBox()
    checkBox4.Label = "Cache Unselected Remotes' Calls"
    checkBox4.Value = Settings.LogHiddenRemotesCalls
    checkBox4.OnUpdated:Connect(function(value)
        Settings.LogHiddenRemotesCalls = value
        saveConfig()
    end)

    local checkBox6 = generalTab:CheckBox()
    checkBox6.Label = "Call Cache Amount Limiter (Per Remote)"
    checkBox6.Value = Settings.CacheLimit
    checkBox6.OnUpdated:Connect(function(value)
        Settings.CacheLimit = value
        saveConfig()
    end)

    local slider1 = generalTab:IntSlider()
    slider1.Label = "Max Calls"
    slider1.Min = 100
    slider1.Max = 10000 -- if you need to cache more than 10k calls, just disable caching
    slider1.Value = Settings.MaxCallAmount
    slider1.Clamped = true
    slider1.OnUpdated:Connect(function(value)
        if value >= 100 and value <= 10000 then -- incase they're mid way through typing it
            Settings.MaxCallAmount = value
            saveConfig()
        end
    end)

    local slider2 = generalTab:IntSlider()
    slider2.Label = "Max Args"
    slider2.Min = 10
    slider2.Max = 100
    slider2.Value = Settings.ArgLimit
    slider2.Clamped = true
    slider2.OnUpdated:Connect(function(value)
        if value >= 10 and value <= 100 then -- incase they're mid way through typing it
            Settings.ArgLimit = value
            saveConfig()
        end
    end)

    local checkBox7 = generalTab:CheckBox()
    checkBox7.Label = "Enable Get Calling Script V2"
    checkBox7.Value = Settings.GetCallingScriptV2
    checkBox7.OnUpdated:Connect(function(value)
        Settings.GetCallingScriptV2 = value
        saveConfig()
    end)

    local checkBox8 = generalTab:CheckBox()
    checkBox8.Label = "Enable Get Call Stack"
    checkBox8.Value = Settings.StoreCallStack
    checkBox8.OnUpdated:Connect(function(value)
        Settings.StoreCallStack = value
        saveConfig()
    end)

    local checkBox5 = generalTab:CheckBox()
    checkBox5.Label = "Extra Repeat Call Amounts"
    checkBox5.Value = Settings.MoreRepeatCallOptions
    checkBox5.OnUpdated:Connect(function(value)
        Settings.MoreRepeatCallOptions = value
        saveConfig()
    end)

    local checkBox6 = generalTab:CheckBox()
    checkBox6.Label = "Always On Top"
    checkBox6.Value = Settings.AlwaysOnTop
    checkBox6.OnUpdated:Connect(function(value)
        Settings.AlwaysOnTop = value
        mainWindowWeakReference[1].VisibilityOverride = value
        settingsWindowWeakReference[1].VisibilityOverride = value
        saveConfig()
    end)
end -- general settings

do -- pseudocode settings

    local checkBox1 = pseudocodeTab:CheckBox()
    checkBox1.Label = "Pseudocode Watermark"
    checkBox1.Value = Settings.PseudocodeWatermark
    checkBox1.OnUpdated:Connect(function(value)
        Settings.PseudocodeWatermark = value
        saveConfig()
    end)

    local checkBox2 = pseudocodeTab:CheckBox()
    checkBox2.Label = "Use LuaU Type Declarations"
    checkBox2.Value = Settings.PseudocodeLuaUTypes
    checkBox2.OnUpdated:Connect(function(value)
        Settings.PseudocodeLuaUTypes = value
        saveConfig()
    end)

    local checkBox5 = pseudocodeTab:CheckBox()
    checkBox5.Label = "Format Tables"
    checkBox5.Value = Settings.PseudocodeFormatTables
    checkBox5.OnUpdated:Connect(function(value)
        Settings.PseudocodeFormatTables = value
        saveConfig()
    end)

    local checkBox3 = pseudocodeTab:CheckBox()
    checkBox3.Label = "Inline Remote"
    checkBox3.Value = Settings.PseudocodeInlineRemote
    checkBox3.OnUpdated:Connect(function(value)
        Settings.PseudocodeInlineRemote = value
        saveConfig()
    end)

    local checkBox4 = pseudocodeTab:CheckBox()
    checkBox4.Label = "Inline Hidden Nils"
    checkBox4.Value = Settings.PseudocodeInlineHiddenNils
    checkBox4.OnUpdated:Connect(function(value)
        Settings.PseudocodeInlineHiddenNils = value
        saveConfig()
    end)

    pseudocodeTab:Label("Pseudocode Inlining Mode")
    local combo2 = pseudocodeTab:Combo()
    combo2.Items = { "Everything", "Tables And Userdatas", "Tables Only", "Nothing" }
    combo2.SelectedItem = Settings.PseudocodeInliningMode
    combo2.OnUpdated:Connect(function(selection)
        Settings.PseudocodeInliningMode = selection
        saveConfig()
    end)

    pseudocodeTab:Label("Instance Tracker")
    local combo3 = pseudocodeTab:Combo()
    combo3.Items = { "Off", "Nil Parented Only", "All Instances" }
    combo3.SelectedItem = Settings.InstanceTrackerMode
    combo3.OnUpdated:Connect(function(selection)
        Settings.InstanceTrackerMode = selection
        saveConfig()
    end)

    --[[local checkBox5 = pseudocodeTab:CheckBox()
    checkBox5.Label = "Optimized Instance Tracker"
    checkBox5.Value = Settings.OptimizedInstanceTracker
    checkBox5.OnUpdated:Connect(function(value)
        Settings.OptimizedInstanceTracker = value
        saveConfig()
    end)]]
end -- pseudocode settings

do -- output settings
    outputTab:Label("Pseudocode Output")
    local combo1 = outputTab:Combo()
    combo1.Items = { "Clipboard", "External UI", "Internal UI (Not Implemented)" }
    combo1.SelectedItem = Settings.PseudocodeOutput
    combo1.OnUpdated:Connect(function(selection)
        Settings.PseudocodeOutput = selection
        saveConfig()
    end)

    outputTab:Label("Decompiled Script Output")
    local combo2 = outputTab:Combo()
    combo2.Items = { "Clipboard", "External UI", "Internal UI (Not Implemented)" }
    combo2.SelectedItem = Settings.DecompilerOutput
    combo2.OnUpdated:Connect(function(selection)
        Settings.DecompilerOutput = selection
        saveConfig()
    end)

    outputTab:Label("Connections List Output")
    local combo3 = outputTab:Combo()
    combo3.Items = { "Clipboard", "External UI", "Internal UI (Not Implemented)" }
    combo3.SelectedItem = Settings.ConnectionsOutput
    combo3.OnUpdated:Connect(function(selection)
        Settings.ConnectionsOutput = selection
        saveConfig()
    end)

    outputTab:Label("Call Stack Output")
    local combo4 = outputTab:Combo()
    combo4.Items = { "Clipboard", "External UI", "Internal UI (Not Implemented)" }
    combo4.SelectedItem = Settings.CallStackOutput
    combo4.OnUpdated:Connect(function(selection)
        Settings.CallStackOutput = selection
        saveConfig()
    end)
end -- theme settings

do -- credits
    creditsTab:Label("Written primarily by GameGuy")
    creditsTab:Label("With Inspriation from Hydroxide")
    creditsTab:Separator()

    creditsTab:Label("Discord: GameGuy#5286 | 515708480661749770")
    local setDiscordToClipboard = creditsTab:Button()
    setDiscordToClipboard.Label = "Set Discord ID To Clipboard"
    setDiscordToClipboard.OnUpdated:Connect(function()
        setclipboard("515708480661749770")
    end)
    
    creditsTab:Separator()
    creditsTab:Label("Thank you to all of the Contributors on Github")
end -- credits

-- Below this is rendering Remote Page

remotePage.Visible = false

local currentSelectedRemote, currentSelectedRemoteInstance, currentSelectedType

local remotePageObjects = {
    Name = nil,
    Icon = nil,
    IconFrame = nil,
    IgnoreButton = nil,
    IgnoreButtonFrame = nil,
    BlockButton = nil,
    BlockButtonFrame = nil
}

local remoteViewerMainWindow = nil

local function unloadRemote()
    frontPage.Visible = true
    remotePage.Visible = false
    currentSelectedRemote = nil
    currentSelectedRemoteInstance = nil
    currentSelectedType = ""
    for _,v in argLines do
        v[2]:Clear()
    end
    tableClear(argLines)
    remoteViewerMainWindow:Clear()
end

local topBar = remotePage:SameLine()

local pauseSpyButton -- declared later, referenced here
local pauseSpyButton2

do -- topbar code

    local buttonsFrame = topBar:Dummy():SameLine()
    buttonsFrame:SetColor(RenderColorOption.Button, black, 0)
    buttonsFrame:SetStyle(RenderStyleOption.ButtonTextAlign, Vector2.new(0.5, 0.5))
    
    pauseSpyButton2 = buttonsFrame:Indent(width-68):Button()
    pauseSpyButton2.Size = Vector2.new(24, 24)
    pauseSpyButton2.Label = Settings.Paused and "\xef\x80\x9d" or "\xef\x8a\x8c"
    pauseSpyButton2.OnUpdated:Connect(function()
        if Settings.Paused then
            Settings.Paused = false
            pauseSpyButton.Label = "\xef\x8a\x8c"
            pauseSpyButton2.Label = "\xef\x8a\x8c"
        else
            Settings.Paused = true
            pauseSpyButton.Label = "\xef\x80\x9d"
            pauseSpyButton2.Label = "\xef\x80\x9d"
        end
    end)

    local exitButton = buttonsFrame:Indent(width-40):Button()
    exitButton.Size = Vector2.new(24, 24)
    exitButton.Label = "\xef\x80\x8d"
    exitButton.OnUpdated:Connect(unloadRemote)

    local remoteNameFrame = topBar:Dummy()
    remoteNameFrame:SetStyle(RenderStyleOption.ButtonTextAlign, Vector2.new(0, 0.5))
    remoteNameFrame:SetColor(RenderColorOption.Button, black, 0)
    remoteNameFrame:SetColor(RenderColorOption.ButtonActive, black, 0)
    remoteNameFrame:SetColor(RenderColorOption.ButtonHovered, black, 0)
    local remoteName = remoteNameFrame:Indent(26):Button()
    remoteName.Size = Vector2.new(300, 24)
    remoteName.Label = "RemoteEvent"

    local remoteIconFrame = topBar:Dummy():WithFont(RemoteIconFont)
    remoteIconFrame:SetStyle(RenderStyleOption.ButtonTextAlign, Vector2.new(1, 0.5))
    remoteIconFrame:SetColor(RenderColorOption.Button, black, 0)
    remoteIconFrame:SetColor(RenderColorOption.ButtonActive, black, 0)
    remoteIconFrame:SetColor(RenderColorOption.ButtonHovered, black, 0)
    remoteIconFrame:SetColor(RenderColorOption.Text, black, 1) -- temporarily black, gets set later
    local remoteIcon = remoteIconFrame:Indent(4):Button()
    remoteIcon.Size = Vector2.new(20, 24)
    remoteIcon.Label = "\xee\x80\x80" -- default

    remotePageObjects.Name = remoteName
    remotePageObjects.Icon = remoteIcon
    remotePageObjects.IconFrame = remoteIconFrame
end

local buttonBarFrame = remotePage:SameLine()

do -- button bar code
    local buttonBar = buttonBarFrame:Indent(125):SameLine()

    local ignoreButtonFrame = buttonBar:Dummy()
    ignoreButtonFrame:SetColor(RenderColorOption.Text, red, 1)
    local ignoreButton = ignoreButtonFrame:Button()
    ignoreButton.Label = "Ignore"
    
    ignoreButton.OnUpdated:Connect(function()
        if currentSelectedRemote then
            local funcList = (currentSelectedType == "Call") and callFuncs or otherFuncs
            local logs = (currentSelectedType == "Call") and callLogs or otherLogs 

            if logs[currentSelectedRemote].Ignored then
                logs[currentSelectedRemote].Ignored = false
                ignoreButtonFrame:SetColor(RenderColorOption.Text, red, 1)
                ignoreButton.Label = "Ignore"
            else
                logs[currentSelectedRemote].Ignored = true
                ignoreButtonFrame:SetColor(RenderColorOption.Text, green, 1)
                ignoreButton.Label = "Unignore"
            end
            funcList[currentSelectedRemote].UpdateIgnores()
        end
    end)
    --[[buttonBar = buttonBar:SameLine()
    buttonBar:SetColor(RenderColorOption.Button, colorRGB(25, 25, 28), 1)
    buttonBar:SetColor(RenderColorOption.ButtonHovered, colorRGB(55, 55, 58), 1)
    buttonBar:SetColor(RenderColorOption.ButtonActive, colorRGB(75, 75, 78), 1)]]

    local blockButtonFrame = buttonBar:Dummy()
    blockButtonFrame:SetColor(RenderColorOption.Text, red, 1)
    local blockButton = blockButtonFrame:Button()
    blockButton.Label = "Block"
    blockButton.OnUpdated:Connect(function()
        local logs = (currentSelectedType == "Call") and callLogs or otherLogs
        local funcList = (currentSelectedType == "Call") and callFuncs or otherFuncs

        if currentSelectedRemote then
            if logs[currentSelectedRemote].Blocked then
                logs[currentSelectedRemote].Blocked = false
                blockButtonFrame:SetColor(RenderColorOption.Text, red, 1)
                blockButton.Label = "Block"
            else
                logs[currentSelectedRemote].Blocked = true
                blockButtonFrame:SetColor(RenderColorOption.Text, green, 1)
                blockButton.Label = "Unblock"
            end
            funcList[currentSelectedRemote].UpdateBlocks()
        end
    end)
    local clearLogsButton = buttonBar:Button()
    clearLogsButton.Label = "Clear Logs"
    clearLogsButton.OnUpdated:Connect(function()
        local logs = (currentSelectedType == "Call") and callLogs or otherLogs
        local lines = (currentSelectedType == "Call") and callLines or otherLines
        if currentSelectedRemote then
            do -- updates front menu
                tableClear(logs[currentSelectedRemote].Calls)
                lines[currentSelectedRemote][3].Label = "0"
                if not logs[currentSelectedRemote].Ignored then
                    lines[currentSelectedRemote][2].Visible = false
                    lines[currentSelectedRemote][4].Visible = false
                end
            end

            do -- updates remote menu
                for _,v in argLines do
                    v[2]:Clear()
                end
                tableClear(argLines)
                remoteViewerMainWindow:Clear()
                addSpacer(remoteViewerMainWindow, 8)
            end
        end
    end)

    local copyPathButton = buttonBar:Button()
    copyPathButton.Label = "Copy Path"
    copyPathButton.OnUpdated:Connect(function()
        if currentSelectedRemote then
            local str = getInstancePath(currentSelectedRemoteInstance)
            if type(str) == "string" then
                outputData(str, 1, "", "Copied Path")
            else
                pushError("Failed to Copy Path")
            end
        end
    end)

    remotePageObjects.IgnoreButton = ignoreButton
    remotePageObjects.IgnoreButtonFrame = ignoreButtonFrame
    remotePageObjects.BlockButton = blockButton
    remotePageObjects.BlockButtonFrame = blockButtonFrame
end

local remoteArgFrame = remotePage:SameLine()

do -- arg frame code
    remoteArgFrame:SetColor(RenderColorOption.ChildBg, colorOptions.TitleBg[1], 1)
    remoteArgFrame:SetStyle(RenderStyleOption.ChildRounding, 5)
    remoteViewerMainWindow = remoteArgFrame:Child()
    remoteViewerMainWindow:SetStyle(RenderStyleOption.ItemSpacing, Vector2.new(4, 0))
    remoteViewerMainWindow:SetStyle(RenderStyleOption.ItemSpacing, Vector2.new(0, 0))
end

local function createCSButton(window, call, spyFunc)
    local frame = window:Dummy()
    if spyFunc.HasNoCaller or call.FromSynapse then
        frame:SetColor(RenderColorOption.Text, grey, 1)
        frame:SetColor(RenderColorOption.HeaderHovered, black, 0)
        frame:SetColor(RenderColorOption.HeaderActive, black, 0)
    end
    local button = frame:Selectable()
    button.Label = "Get Calling Script"
    if not (spyFunc.HasNoCaller or call.FromSynapse) then
        button.OnUpdated:Connect(function()
            local scr = Settings.GetCallingScriptV2 and call.ScriptV2 or call.Script
            local str = scr and getInstancePath(scr) -- not sure if getcallingscript can return a ModuleScript, I assume it can't, but adding this just in case
            if type(str) == "string" then
                outputData(str, 1, "", "Copied Calling Script")
            else
                pushError("Failed to get Calling Script")
            end
        end)
    end
end

local function createCSDecompileButton(window, call, spyFunc)
    local frame = window:Dummy()
    if spyFunc.HasNoCaller or call.FromSynapse then
        frame:SetColor(RenderColorOption.Text, grey, 1)
        frame:SetColor(RenderColorOption.HeaderHovered, black, 0)
        frame:SetColor(RenderColorOption.HeaderActive, black, 0)
    end
    local button = frame:Selectable()
    button.Label = "Decompile Calling Script"
    if not (spyFunc.HasNoCaller or call.FromSynapse) then
        button.OnUpdated:Connect(function()
            local suc, res = pcall(function()
                local scr = Settings.GetCallingScriptV2 and call.ScriptV2 or call.Script
                local str = decompile(scr)
                local scriptName = scr and getInstancePath(scr)
                if type(str) == "string" then
                    outputData(str, Settings.DecompilerOutput, scriptName, "Decompiled Calling Script")
                else
                    pushError("Failed to Decompile Calling Script2")
                end
            end)
            if not suc then
                pushError("Failed to Decompile Calling Script", res)
            end
        end)
    end
end

local function repeatCall(call, remote, remoteId, spyFunc, repeatCount)
    if spyFunc.Type == "Call" then
        local func = spyFunc.Function
        
        local success, result = pcall(function()
            if spyFunc.ReturnsValue then
                for _ = 1,repeatCount do
                    originalCallerCache[remoteId] = {nil, true}
                    spawnFunc(func, remote, unpack(call.Args, 1, #call.Args + call.NilCount))
                end
            else
                for _ = 1,repeatCount do
                    spawnFunc(func, remote, unpack(call.Args, 1, #call.Args + call.NilCount)) -- shouldn't be task.spawned but needs to be because of oth.hook being weird
                end
            end
        end)
        if not success then
            pushError("Failed to Repeat Call", result)
        end
    elseif spyFunc.Type == "Callback" then
        local success, result = pcall(function()
            for _ = 1,repeatCount do
                spawnFunc(call.CallbackLog.CurrentFunction, unpack(call.Args, 1, #call.Args + call.NilCount)) -- always spawned to make callstack look legit
            end
        end)
        if not success then
            pushError("Failed to Repeat Callback Call", result)
        end
    elseif spyFunc.Type == "Connection" then
        local success, result = pcall(function()
            for _ = 1,repeatCount do
                originalCallerCache[remoteId] = {nil, true}
                cfiresignal(call.Signal, unpack(call.Args, 1, #call.Args + call.NilCount))
            end
        end)
        if not success then
            pushError("Failed to Repeat Connection", result)
        end
    end
end

local function createRepeatCallButton(window, call, remote, remoteId, spyFunc, amt) -- NEEDS TO BE REDONE FOR CONS AND CALLBACKS
    local button = window:Selectable()
    button.Label = amt and ("Repeat Call x" .. tostring(amt)) or "Repeat Call"
    button.Visible = true

    amt = amt or 1

    button.OnUpdated:Connect(function() repeatCall(call, remote, remoteId, spyFunc, amt) end)
end

local function createGenSendPCButton(window, call, remote, spyFunc)
    local button = window:Selectable()
    button.Label = "Generate Calling Pseudocode"
    button.OnUpdated:Connect(function()
        local suc, ret = pcall(function()
            outputData(genSendPseudo(remote, call, spyFunc), Settings.PseudocodeOutput, "RS Pseudocode", "Generated Pseudocode")
        end)
        if not suc then
            pushError("Failed to Generate Pseudocode", ret)
        end
    end)
end

local function createGenRecvPCButton(window, call, remote, spyFunc)
    local frame = window:Dummy()
    if spyFunc.Type == "Call" then
        frame:SetColor(RenderColorOption.Text, grey, 1)
        frame:SetColor(RenderColorOption.HeaderHovered, black, 0)
        frame:SetColor(RenderColorOption.HeaderActive, black, 0)
    end
    local button = frame:Selectable()
    button.Label = "Generate Receiving Pseudocode"
    if spyFunc.Type ~= "Call" then
        button.OnUpdated:Connect(function()
            local suc, res = pcall(function()
                outputData(genRecvPseudo(remote, call, spyFunc, Settings.PseudocodeWatermark), Settings.PseudocodeOutput, "RS Pseudocode", "Generated Pseudocode")
            end)
            if not suc then
                pushError("Failed to Generate Pseudocode", res)
            end
        end)
    end
end

local function genCallStackString(callStack)
    local callStackString = ""
    if Settings.PseudocodeWatermark then
        callStackString ..= watermarkString
    end

    callStackString ..= "\nlocal CallStack = {"

    for i,v in callStack do
        callStackString ..= strformat("\n\t[%s] = {\n\t\tScript = %s,\n\t\tLine = %s,\n\t\tType = %s\n\t},", tostring(i), v.Script and getInstancePath(v.Script), tostring(v.LineNumber), "\"" .. v.Type.. "\"")
    end
    
    return (sub(callStackString, 1, -2) .. "\n}")
end

local function createGetCallStackButton(window, call, spyFunc)
    local frame = window:Dummy()
    if spyFunc.Type ~= "Call" or call.FromSynapse then
        frame:SetColor(RenderColorOption.Text, grey, 1)
        frame:SetColor(RenderColorOption.HeaderHovered, black, 0)
        frame:SetColor(RenderColorOption.HeaderActive, black, 0)
    end
    local button = frame:Selectable()
    button.Label = "Get Call Stack"
    if spyFunc.Type == "Call" and not call.FromSynapse then
        button.OnUpdated:Connect(function()
            local suc, res = pcall(function()
                outputData(genCallStackString(call.CallStack), Settings.CallStackOutput, "Call Stack", "Output Call Stack")
            end)
            if not suc then
                pushError("Failed to Output Call Stack", res)
            end
        end)
    end
end

local function createGetConnectionScriptsButton(window, call, spyFunc)
    local frame = window:Dummy()
    if spyFunc.Type ~= "Connection" then
        frame:SetColor(RenderColorOption.Text, grey, 1)
        frame:SetColor(RenderColorOption.HeaderHovered, black, 0)
        frame:SetColor(RenderColorOption.HeaderActive, black, 0)
    end
    local button = frame:Selectable()
    button.Label = "Get Connections' Creator-Scripts"
    if spyFunc.Type == "Connection" then
        button.OnUpdated:Connect(function()
            local suc, res = pcall(function()
                local str = Settings.PseudocodeWatermark and watermarkString or ""
                str ..= "\nlocal Connections = {"
                local count = 0
                for i,v in call.Scripts do
                    count += 1
                    str ..= strformat("\n\t[%s] = {\n\t\tInstance = %s,\n\t\tAmount = %s\n\t},", tostring(count), typeof(i) == "Instance" and getInstancePath(i) or "nil, -- Created by "..tostring(i), tostring(v))
                end
                str = sub(str, 1, -2)
                str ..= "\n}"
                outputData(str, Settings.ConnectionsOutput, "Connection Scripts", "Output Connections' Creator-Scripts List")
            end)
            if not suc then
                pushError("Failed to Get Connection Scripts", res)
            end
        end)
    end
end

local function createGetRetValButton(window, call, spyFunc)
    local frame = window:Dummy()
    if not spyFunc.ReturnsValue then
        frame:SetColor(RenderColorOption.Text, grey, 1)
        frame:SetColor(RenderColorOption.HeaderHovered, black, 0)
        frame:SetColor(RenderColorOption.HeaderActive, black, 0)
    end
    local button = frame:Selectable()
    button.Label = "Get Return Value"
    if spyFunc.ReturnsValue then
        button.OnUpdated:Connect(function()
            local suc, res = pcall(function()
                local ret = call.ReturnValue
                if ret.Args then
                    outputData(genReturnValuePseudo(ret, spyFunc), Settings.PseudocodeOutput, "RS Return Value", "Generated Return Value")
                else
                    pushError("Failed to Get Return Value")
                end
            end)
            if not suc then
                pushError("Failed to Get Return Value", res)
            end
        end)
    end
end

local function createCBButton(window, call, spyFunc)
    local frame = window:Dummy()
    if spyFunc.Type ~= "Callback" or call.FromSynapse then
        frame:SetColor(RenderColorOption.Text, grey, 1)
        frame:SetColor(RenderColorOption.HeaderHovered, black, 0)
        frame:SetColor(RenderColorOption.HeaderActive, black, 0)
    end
    local button = frame:Selectable()
    button.Label = "Get Callback Creator-Script"
    if spyFunc.Type == "Callback" and not call.FromSynapse then
        button.OnUpdated:Connect(function()
            local str = call.CallbackScript and getInstancePath(call.CallbackScript) -- not sure if getcallingscript can return a ModuleScript, I assume it can't, but adding this just in case
            if type(str) == "string" then
                outputData(str, 1, "", "Set Callback Script")
            else
                pushError("Failed to get Callback Script")
            end
        end)
    end
end

local function createCBDecompileButton(window, call, spyFunc)
    local frame = window:Dummy()
    if spyFunc.Type ~= "Callback" or call.FromSynapse then
        frame:SetColor(RenderColorOption.Text, grey, 1)
        frame:SetColor(RenderColorOption.HeaderHovered, black, 0)
        frame:SetColor(RenderColorOption.HeaderActive, black, 0)
    end
    local button = frame:Selectable()
    button.Label = "Decompile Callback Creator-Script"
    if spyFunc.Type == "Callback" and not call.FromSynapse then
        button.OnUpdated:Connect(function()
            local suc, res = pcall(function()
                local str = decompile(call.CallbackScript)
                local scriptName = call.CallbackScript and getInstancePath(call.CallbackScript)
                if type(str) == "string" then
                    outputData(str, Settings.DecompileScriptsToExternal, scriptName, "Set Callback Script")
                else
                    pushError("Failed to Decompile Callback Script2")
                end
            end)
            if not suc then
                pushError("Failed to Decompile Callback Script", res)
            end
        end)
    end
end

local function makeRemoteViewerLog(call, remote, remoteId)
    local totalArgCount = #call.Args + call.NilCount
    local spyFunc = spyFunctions[call.TypeIndex]
    local tempMainDummy = remoteViewerMainWindow:Dummy()
    local tempMain = tempMainDummy:SameLine()
    tempMain:SetColor(RenderColorOption.ChildBg, colorRGB(25, 25, 28), 1)
    
    local childWindow = tempMain:Indent(8):Child()

    if totalArgCount < 2 then
        childWindow.Size = Vector2.new(width-46, 24 + 16) -- 2 lines (top line = 24) + 2x (8px) spacers  | -46 because 16 padding on each side, plus 14 wide scrollbar
    elseif totalArgCount <= 10 then
        childWindow.Size = Vector2.new(width-46, (totalArgCount * 28) - 4 + 16) -- 24px per line, 4px spacer, 16px header and footer  | -46 because 16 padding on each side, plus 14 wide scrollbar
    else -- 28 pixels per line (24 for arg, 4 for spacer), but -4 because no spacer at end, then +24 because button line, and +24 for top, bottom, and middle spacer
        childWindow.Size = Vector2.new(width-46, (10 * 28) - 4 + 16)
    end

    local pop = mainWindowWeakReference[1]:Popup()

    createGetRetValButton(pop, call, spyFunc)
    if Settings.CallbackButtons then
        createGetConnectionScriptsButton(pop, call, spyFunc)
        createCBButton(pop, call, spyFunc)
        createCBDecompileButton(pop, call, spyFunc)
    end

    pop:Separator()
    createCSButton(pop, call, spyFunc)
    createCSDecompileButton(pop, call, spyFunc)
    if Settings.StoreCallStack then
        createGetCallStackButton(pop, call, spyFunc)
    end
    if Settings.CallbackButtons then
        createGenRecvPCButton(pop, call, remote, spyFunc)
    end
    createGenSendPCButton(pop, call, remote, spyFunc)
    if Settings.MoreRepeatCallOptions then
        pop:Separator()
        for _,v in repeatCallSteps do
            createRepeatCallButton(pop, call, remote, remoteId, spyFunc, v)
        end
    else
        createRepeatCallButton(pop, call, remote, remoteId, spyFunc)
    end

    local textFrame = childWindow:Dummy()

    addSpacer(textFrame, 6)

    local indentFrame = textFrame:Indent(4):SameLine()
    
    local temp = indentFrame:Indent(-2):WithFont(CallerIconFont) -- center it
    temp:SetStyle(RenderStyleOption.FramePadding, Vector2.new(2, 0))
    temp:SetColor(RenderColorOption.Button, black, 0)
    temp:SetColor(RenderColorOption.ButtonActive, black, 0)
    temp:SetColor(RenderColorOption.ButtonHovered, black, 0)
    local btn = temp:Button()
    
    if call.FromSynapse then
        btn.Label = "\xee\x80\x89"
    else
        btn.Label = "\xee\x80\x88"
    end
    btn.Size = Vector2.new(24, 30)

    local firstArgFrame = indentFrame:Indent(28):Child() -- 1 extra cause -1 later, and using child so I can make the icon line up
    firstArgFrame.Size = Vector2.new(width-24-38-23, 30)
    addSpacer(firstArgFrame, 2)
    firstArgFrame = firstArgFrame:SameLine()

    if totalArgCount == 0 or totalArgCount == 1 then
        local argFrame = firstArgFrame:SameLine()

        local topLine = argFrame:SameLine():Indent(8)
        topLine:SetColor(RenderColorOption.Button, black, 0)
        topLine:SetColor(RenderColorOption.ButtonActive, white, 0)
        topLine:SetColor(RenderColorOption.ButtonHovered, white, 0)
        local mainButton = topLine:Button()
        mainButton.OnUpdated:Connect(function()
            pop:Show()
        end)

        local temp2 = argFrame:SameLine()
        temp2:SetColor(RenderColorOption.ButtonActive, colorOptions.FrameBg[1], 1)
        temp2:SetColor(RenderColorOption.ButtonHovered, colorOptions.FrameBg[1], 1)
        temp2:SetColor(RenderColorOption.Button, colorOptions.FrameBg[1], 1)
        temp2:SetStyle(RenderStyleOption.ButtonTextAlign, Vector2.new(0, 0.5))

        local lineContents = temp2:Indent(-1):Indent(1):Button()
        lineContents.Size = Vector2.new(width-24-38-23, 24) -- 24 = left padding, 38 = right padding, and no scrollbar
        if totalArgCount == 0 then
            argFrame:SetColor(RenderColorOption.Text, colorRGB(156, 0, 0), 1)
            lineContents.Label = spaces2 .. "nil"
        elseif #call.Args == 1 then
            local text, color = getArgString(call.Args[1], lineContents.Size.X)
            local str = resizeText(spaces2 .. text, lineContents.Size.X, "...   ", DefaultTextFont)
            lineContents.Label = str
            argFrame:SetColor(RenderColorOption.Text, color, 1)
        else
            lineContents.Label = spaces2 .. "HIDDEN NIL"
            argFrame:SetColor(RenderColorOption.Text, colorHSV(258/360, 0.8, 1), 1)
        end
        mainButton.Size = Vector2.new(lineContents.Size.X, lineContents.Size.Y+4)

        local temp = argFrame:SameLine()
        argFrame:SetColor(RenderColorOption.ButtonActive, black, 0)
        argFrame:SetColor(RenderColorOption.ButtonHovered, black, 0)
        argFrame:SetColor(RenderColorOption.Button, black, 0)
        temp:SetStyle(RenderStyleOption.ButtonTextAlign, Vector2.new(1, 0.5))
        temp:SetColor(RenderColorOption.Text, colorHSV(179/360, 0.8, 1), 1)

        local lineNum = temp:Indent(-7):Button()
        lineNum.Label = "1"
        lineNum.Size = Vector2.new(32, 24)
    else
        local normalSize = Vector2.new(width-24-38, 24)-- 24 = left padding + indent, 38 = right padding (no scrollbar) 
        local normalFirstSize = Vector2.new(width-24-38-23, 24)
        local scrollSize = Vector2.new(width-24-38-14, 24) -- 14 = scrollbar width, plus read above
        local scrollFirstSize = Vector2.new(width-24-38-14-23, 24)
        for i = 1, #call.Args do
            if i > Settings.ArgLimit then break end

            local x = call.Args[i]

            local firstLine = (i == 1)
            local argFrame = ((firstLine and firstArgFrame) or childWindow):SameLine()

            local topLine = firstLine and argFrame:SameLine():Indent(-1):Indent(1) or argFrame:SameLine():Indent(8)
            topLine:SetColor(RenderColorOption.Button, black, 0)
            topLine:SetColor(RenderColorOption.ButtonActive, white, 0)
            topLine:SetColor(RenderColorOption.ButtonHovered, white, 0)
            local mainButton = topLine:Button()
            mainButton.OnUpdated:Connect(function()
                pop:Show()
            end)

            local temp2 = argFrame:SameLine():Indent(-1):Indent(1)
            temp2:SetColor(RenderColorOption.ButtonActive, colorOptions.FrameBg[1], 1)
            temp2:SetColor(RenderColorOption.ButtonHovered, colorOptions.FrameBg[1], 1)
            temp2:SetColor(RenderColorOption.Button, colorOptions.FrameBg[1], 1)
            temp2:SetStyle(RenderStyleOption.ButtonTextAlign, Vector2.new(0, 0.5))
            
            local lineContents = firstLine and temp2:Indent(-1):Indent(1):Button() or temp2:Indent(8):Button()
            if totalArgCount < 10 then
                lineContents.Size = firstLine and normalFirstSize or normalSize 
            else
                lineContents.Size = firstLine and scrollFirstSize or scrollSize
            end
            if i ~= Settings.ArgLimit then
                local text, color
                text, color = getArgString(x, lineContents.Size.X)
                lineContents.Label = resizeText(spaces2 .. text, lineContents.Size.X, "...   ", DefaultTextFont)
                argFrame:SetColor(RenderColorOption.Text, color, 1)
            else
                lineContents.Label = spaces2 .. "ARG LIMIT REACHED"
                argFrame:SetColor(RenderColorOption.Text, Color3.new(1, 0, 0), 1)
            end
            mainButton.Size = Vector2.new(lineContents.Size.X, lineContents.Size.Y+4) -- +4 to add spacer

            local temp = argFrame:SameLine()
            argFrame:SetColor(RenderColorOption.ButtonActive, black, 0)
            argFrame:SetColor(RenderColorOption.ButtonHovered, black, 0)
            argFrame:SetColor(RenderColorOption.Button, black, 0)
            temp:SetStyle(RenderStyleOption.ButtonTextAlign, Vector2.new(1, 0.5))
            temp:SetColor(RenderColorOption.Text, colorHSV(179/360, 0.8, 1), 1)

            local lineNum = firstLine and temp:Indent(-7):Button() or temp:Indent(1):Button()
            lineNum.Label = tostring(i)
            lineNum.Size = Vector2.new(32, 24)
            --addSpacer(childWindow, 4)
        end
        local argAmt = #call.Args
        for i = 1, call.NilCount do
            if (i + argAmt) > Settings.ArgLimit then break end

            local firstLine = (i == 1 and argAmt == 0)
            local argFrame = (firstLine and firstArgFrame:SameLine()) or childWindow:SameLine()

            local topLine = argFrame:Dummy():Indent(8)
            topLine:SetColor(RenderColorOption.Button, black, 0)
            topLine:SetColor(RenderColorOption.ButtonActive, white, 0)
            topLine:SetColor(RenderColorOption.ButtonHovered, white, 0)
            local mainButton = topLine:Button()
            mainButton.OnUpdated:Connect(function()
                pop:Show()
            end)

            local temp2 = argFrame:SameLine()
            temp2:SetColor(RenderColorOption.ButtonActive, colorOptions.FrameBg[1], 1)
            temp2:SetColor(RenderColorOption.ButtonHovered, colorOptions.FrameBg[1], 1)
            temp2:SetColor(RenderColorOption.Button, colorOptions.FrameBg[1], 1)
            temp2:SetStyle(RenderStyleOption.ButtonTextAlign, Vector2.new(0, 0.5))

            local lineContents = firstLine and temp2:Indent(-1):Indent(1):Button() or temp2:Indent(8):Button()
            if (i + argAmt) == Settings.ArgLimit then
                lineContents.Label = spaces2 .. "ARG LIMIT REACHED"
                argFrame:SetColor(RenderColorOption.Text, Color3.new(1, 0, 0), 1)
            else
                lineContents.Label = spaces2 .. "HIDDEN NIL"
                argFrame:SetColor(RenderColorOption.Text, colorHSV(258/360, 0.8, 1), 1)
            end
            if totalArgCount < 10 then
                lineContents.Size = firstLine and normalFirstSize or normalSize
            else
                lineContents.Size = firstLine and scrollFirstSize or scrollSize
            end
            if firstLine then
                mainButton.Size = Vector2.new(lineContents.Size.X, lineContents.Size.Y) -- +2 cause type icon adds 2 for some reason
            else
                mainButton.Size = Vector2.new(lineContents.Size.X, lineContents.Size.Y+4) -- +4 to add spacer
            end

            local temp = argFrame:SameLine()
            argFrame:SetColor(RenderColorOption.ButtonActive, black, 0)
            argFrame:SetColor(RenderColorOption.ButtonHovered, black, 0)
            argFrame:SetColor(RenderColorOption.Button, black, 0)
            temp:SetStyle(RenderStyleOption.ButtonTextAlign, Vector2.new(1, 0.5))
            temp:SetColor(RenderColorOption.Text, colorHSV(179/360, 0.8, 1), 1)

            local lineNum = firstLine and temp:Indent(-7):Button() or temp:Indent(1):Button()
            lineNum.Label = tostring(i + argAmt)
            lineNum.Size = Vector2.new(32, 24)
            --addSpacer(childWindow, 4)
        end
        addSpacer(childWindow, 4) -- account for the space at the end of the arg list so when you scroll all the way down the padding looks good
    end

    addSpacer(tempMainDummy, 4)
    tableInsert(argLines, { tempMainDummy, pop })
end

local function loadRemote(remote, remoteId, data)
    local funcInfo = spyFunctions[data.TypeIndex]
    local logs = funcInfo.Type == "Call" and callLogs or otherLogs
    frontPage.Visible = false
    remotePage.Visible = true
    currentSelectedRemote = remoteId
    currentSelectedRemoteInstance = remote
    currentSelectedType = funcInfo.Type
    remotePageObjects.Name.Label = remote and resizeText(purifyString(remoteNameCache[remoteId] or remote.Name, false, remotePageObjects.Name.Size.X), remotePageObjects.Name.Size.X, "...   ", DefaultTextFont) or "NIL REMOTE"
    remotePageObjects.Icon.Label = funcInfo.Icon .. "   "
    remotePageObjects.IgnoreButton.Label = (logs[remoteId].Ignored and "Unignore") or "Ignore"
    remotePageObjects.IgnoreButtonFrame:SetColor(RenderColorOption.Text, (logs[remoteId].Ignored and green) or red, 1)
    remotePageObjects.BlockButton.Label = (logs[remoteId].Blocked and "Unblock") or "Block"
    remotePageObjects.BlockButtonFrame:SetColor(RenderColorOption.Text, (logs[remoteId].Blocked and green) or red, 1)

    addSpacer(remoteViewerMainWindow, 8)

    for _,v in logs[remoteId].Calls do
        makeRemoteViewerLog(v, remote, remoteId)
    end
end

-- Below this is rendering Front Page
local topBar = frontPage:SameLine()
local frameWidth = width-150
local searchBarFrame = topBar:Indent(-0.35*frameWidth):Child()
searchBarFrame.Size = Vector2.new(frameWidth, 24)
searchBarFrame:SetColor(RenderColorOption.ChildBg, black, 0)
searchBar = searchBarFrame:Indent(0.35*frameWidth):TextBox() -- localized earlier
searchBar.OnUpdated:Connect(filterLines)

local searchButton = topBar:Button()
searchButton.Label = "Search"
searchButton.OnUpdated:Connect(function()
    filterLines(searchBar.Value) -- redundant because i did it above but /shrug
end)

local childWindow

local clearAllLogsButton = topBar:Button()
clearAllLogsButton.Label = "Clear All Logs"
clearAllLogsButton.OnUpdated:Connect(function()
    tableClear(callLines)
    tableClear(otherLines)
    for _,v in callLogs do
        tableClear(v.Calls)
    end

    for _,v in otherLogs do
        tableClear(v.Calls)
    end
    childWindow:Clear()
    addSpacer(childWindow, 8)
end)

local topRightBar = topBar:Indent(width-96):SameLine() -- -8 for right padding, -8 for previous left indent, -28 per button +4 for left side padding
topRightBar:SetColor(RenderColorOption.Button, black, 0)
topRightBar:SetStyle(RenderStyleOption.ButtonTextAlign, Vector2.new(0.5, 0.5))
topRightBar:SetStyle(RenderStyleOption.ItemSpacing, Vector2.new(0, 0))


local settingsButton = topRightBar:Button()
settingsButton.Label = "\xef\x80\x93"
settingsButton.Size = Vector2.new(24, 24)
settingsButton.OnUpdated:Connect(function()
    settingsWindowWeakReference[1].Visible = not settingsWindowWeakReference[1].Visible
end)

pauseSpyButton = topRightBar:Indent(28):Button()
pauseSpyButton.Label = Settings.Paused and "\xef\x80\x9d" or "\xef\x8a\x8c"
pauseSpyButton.Size = Vector2.new(24, 24)
pauseSpyButton.OnUpdated:Connect(function()
    if Settings.Paused then
            Settings.Paused = false
            pauseSpyButton.Label = "\xef\x8a\x8c"
            pauseSpyButton2.Label = "\xef\x8a\x8c"
        else
            Settings.Paused = true
            pauseSpyButton.Label = "\xef\x80\x9d"
            pauseSpyButton2.Label = "\xef\x80\x9d"
        end
end)

local exitButton = topRightBar:Indent(56):Button()
exitButton.Label = "\xef\x80\x91"
exitButton.Size = Vector2.new(24, 24)
exitButton.OnUpdated:Connect(function()
    if messagebox("Are you sure you want to Close/Disconnect the RemoteSpy?  You can reexecute later.", "Warning", 4) == 6 then
        cleanUpSpy()
    end
end)

addSpacer(frontPage, 4)

local sameLine = frontPage:SameLine()

local splitAmt = (floor(#spyFunctions/2)+1)
for i,v in spyFunctions do
    
    if i == splitAmt then
        sameLine = frontPage:SameLine()
        sameLine.Visible = Settings.CallbackButtons
        callbackButtonline = sameLine
    end
    
    local tempLine = v.Indent == 0 and sameLine:Dummy() or sameLine:Indent(v.Indent):Dummy()
    
    local btn = tempLine:WithFont(RemoteIconFont):CheckBox()
    btn.Label = v.Icon
    btn.Value = v.Enabled
    v.Button = btn
    btn.OnUpdated:Connect(function(enabled)
        v.Enabled = enabled
        Settings[v.Name] = enabled
        updateLines(v.Name, enabled)

        saveConfig()
    end)

    sameLine:Label(v.Name)
end

frontPage:SetColor(RenderColorOption.ChildBg, colorOptions.TitleBg[1], 1)
frontPage:SetStyle(RenderStyleOption.ChildRounding, 5)

childWindow = frontPage:Child()
childWindow:SetStyle(RenderStyleOption.ItemSpacing, Vector2.new(4, 0))
childWindow:SetStyle(RenderStyleOption.FrameRounding, 3)
addSpacer(childWindow, 8)

local function makeCopyPathButton(sameLine, remote)
    local copyPathButton = sameLine:Button()
    copyPathButton.Label = "Copy Path"

    copyPathButton.OnUpdated:Connect(function()
        local str = getInstancePath(remote)
        if type(str) == "string" then
            outputData(str, 1, "", "Copied Path")
        else
            pushError("Failed to Copy Path")
        end
    end)
end

local function makeClearLogsButton(sameLine, remoteId, method)
    local clearLogsButton = sameLine:Button()
    clearLogsButton.Label = "Clear Logs"

    local lines = (method == "Call") and callLines or otherLines
    local logs = (method == "Call") and callLogs or otherLogs

    clearLogsButton.OnUpdated:Connect(function()
        tableClear(logs[remoteId].Calls)
        lines[remoteId][3].Label = "0"
        if not logs[remoteId].Ignored then
            lines[remoteId][2].Visible = false
            lines[remoteId][4].Visible = false
        end
    end)
end

local function makeIgnoreButton(sameLine, remoteId, method)
    local spoofLine = sameLine:SameLine()
    spoofLine:SetColor(RenderColorOption.Text, red, 1)
    local ignoreButton = spoofLine:Button()
    ignoreButton.Label = "Ignore"

    local logs = (method == "Call") and callLogs or otherLogs
    local funcList = (method == "Call") and callFuncs or otherFuncs

    funcList[remoteId].UpdateIgnores = function()
        if logs[remoteId].Ignored then
            ignoreButton.Label = "Unignore"
            spoofLine:SetColor(RenderColorOption.Text, green, 1)
        else
            ignoreButton.Label = "Ignore"
            spoofLine:SetColor(RenderColorOption.Text, red, 1)
        end
    end

    ignoreButton.OnUpdated:Connect(function()
        if logs[remoteId].Ignored then
            logs[remoteId].Ignored = false
            ignoreButton.Label = "Ignore"
            spoofLine:SetColor(RenderColorOption.Text, red, 1)
        else
            logs[remoteId].Ignored = true
            ignoreButton.Label = "Unignore"
            spoofLine:SetColor(RenderColorOption.Text, green, 1)
        end
    end)
end

local function makeBlockButton(sameLine, remoteId, method)
    local spoofLine = sameLine:SameLine()
    spoofLine:SetColor(RenderColorOption.Text, red, 1)
    local blockButton = spoofLine:Button()
    blockButton.Label = "Block"

    local logs = (method == "Call") and callLogs or otherLogs
    local funcList = (method == "Call") and callFuncs or otherFuncs

    funcList[remoteId].UpdateBlocks = function()
        if logs[remoteId].Blocked then
            spoofLine:SetColor(RenderColorOption.Text, green, 1)
            blockButton.Label = "Unblock"
        else
            spoofLine:SetColor(RenderColorOption.Text, red, 1)
            blockButton.Label = "Block"
        end
    end

    blockButton.OnUpdated:Connect(function()
        if logs[remoteId].Blocked then
            logs[remoteId].Blocked = false
            spoofLine:SetColor(RenderColorOption.Text, red, 1)
            blockButton.Label = "Block"
        else
            logs[remoteId].Blocked = true
            spoofLine:SetColor(RenderColorOption.Text, green, 1)
            blockButton.Label = "Unblock"
        end
    end)
end

local function renderNewLog(remote, remoteId, data)
    local spyFunc = spyFunctions[data.TypeIndex]
    local method = spyFunc.Type
    local lines, log, funcList
    if method == "Call" then
        lines = callLines
        log = callLogs[remoteId]
        funcList = callFuncs
    else
        lines = otherLines
        log = otherLogs[remoteId]
        funcList = otherFuncs
    end
    funcList[remoteId] = {}

    local temp = childWindow:Dummy():Indent(8)
    temp:SetStyle(RenderStyleOption.ItemSpacing, Vector2.new(4, 0))
    temp:SetColor(RenderColorOption.ChildBg, colorRGB(25, 25, 28), 1)
    temp:SetStyle(RenderStyleOption.SelectableTextAlign, Vector2.new(0, 0.5))

    local line = {}
    line[1] = spyFunc.Name
    line[2] = temp:Child()
    sameButtonLine = line[2]
    sameButtonLine.Visible = spyFunc.Enabled
    sameButtonLine.Size = Vector2.new(width-32-14, 32) -- minus 32 because 4x 8px spacers, minus 14 because scrollbar
    addSpacer(sameButtonLine, 4)
    sameButtonLine = sameButtonLine:SameLine()

    local remoteButton = sameButtonLine:Indent(6):Selectable()
    remoteButton.Size = Vector2.new(width-327-4-14, 24)
    remoteButton.Label = spaces .. (remote and resizeText(purifyString(remoteNameCache[remoteId] or remote.Name, false, remoteButton.Size.X), remoteButton.Size.X, "...   ", DefaultTextFont) or "NIL REMOTE")
    remoteButton.OnUpdated:Connect(function()
        loadRemote(remote, remoteId, data)
    end)

    addSpacer(sameButtonLine, 3)

    local cloneLine = sameButtonLine:WithFont(RemoteIconFont):Indent(6)
    
    cloneLine:Label(spyFunc.Icon .. "   ")
    
    local cloneLine2 = sameButtonLine:SameLine()
    cloneLine2:SetColor(RenderColorOption.Text, colorHSV(179/360, 0.8, 1), 1)

    local callAmt = #log.Calls
    local callStr = (callAmt < 1000 and tostring(callAmt)) or "999+"
    line[3] = cloneLine2:Indent(27):Label(callStr)

    local ind = sameButtonLine:Indent(width-333)
    
    makeCopyPathButton(ind, remote)
    makeClearLogsButton(sameButtonLine, remoteId, method)
    makeIgnoreButton(sameButtonLine, remoteId, method)
    makeBlockButton(sameButtonLine, remoteId, method)

    line[4] = addSpacer(childWindow, 4)
    line[4].Visible = spyFunc.Enabled
    line[5] = remoteButton

    lines[remoteId] = line
    filterLines(searchBar.Value)
end

_G.ChangeRemoteSpyRemoteDisplayName = function(remote: Instance, newName: string)
    local remoteId = remote:GetDebugId()
    remoteNameCache[remoteId] = newName

    local line = callLines[remoteId]
    local line2 = otherLines[remoteId]
    if line then
        line[5].Label = spaces .. resizeText(purifyString(newName, false, line[5].Size.X), line[5].Size.X, "...   ", DefaultTextFont)
    end
    if line2 then
        line2[5].Label = spaces .. resizeText(purifyString(newName, false, line2[5].Size.X), line2[5].Size.X, "...   ", DefaultTextFont)
    end
end

local function sendLog(remote, remoteId, data)
    local spyFunc = spyFunctions[data.TypeIndex]
    local method = spyFunc.Type
    local check = (currentSelectedRemote == remoteId and currentSelectedType == method) and true
    
    local line, log
    if method == "Call" then
        line = callLines[remoteId]
        log = callLogs[remoteId]
    else
        line = otherLines[remoteId]
        log = otherLogs[remoteId]
    end
    
    tableInsert(log.Calls, data)

    if Settings.CacheLimit then
        local callCount = (#log.Calls-Settings.MaxCallAmount)
        if callCount > 0 then
            for _ = 1,callCount do
                if check then
                    argLines[1][2]:Clear()
                    argLines[1][1]:Clear()
                    argLines[1][1].Visible = false
                    tableRemove(argLines, 1)
                end
                tableRemove(log.Calls, 1)
            end
        end
    end

    if line then
        local callAmt = #log.Calls
        if callAmt > 0 and spyFunc.Enabled then
            line[2].Visible = true
            line[4].Visible = true
        end
        local callStr = (callAmt < 1000 and tostring(callAmt)) or "999+"
        line[3].Label = callStr
    else
        renderNewLog(remote, remoteId, data)
    end

    if check then
        makeRemoteViewerLog(data, remote, remoteId)
    end
end

local function processReturnValue(callType, refTable, ...)
    deferFunc(function(...)
        local args = shallowClone({...}, callType, true, -1)
        if args then
            refTable.Args = args
            refTable.NilCount = (select("#", ...) - #args)
        else
            refTable.Args = false
            pushError("Impossible error has occurred, please report to GameGuy#5920")
        end
    end, ...)

    return ...
end

local function createCallStack(callStack)
    local newCallStack = {}
    local callStackLength = #callStack

    for i,v in callStack do -- last index in call stack is the remotespy hook
        if i ~= callStackLength then
            local tempScript = rawget(getfenv(v.func), "script")
            local funcInfo = getinfo(v.func)
            newCallStack[i] = {
                Script = typeof(tempScript) == "Instance" and cloneref(tempScript),
                LineNumber = funcInfo.currentline,
                Type = funcInfo.what
            }
        end
    end

    return newCallStack
end

local function addCall(remote, remoteId, returnValue, spyFunc, caller, cs, callStack, ...)
    if not callLogs[remoteId] then
        callLogs[remoteId] = {
            Blocked = false,
            Ignored = false,
            Calls = {}
        }
    end
    if not callLogs[remoteId].Ignored and (Settings.LogHiddenRemotesCalls or spyFunc.Enabled) then
        local args, tableDepth, _, hasInstance = shallowClone({...}, remote.ClassName, true, -1) -- 1 deeper total
        local argCount = select("#", ...)

        if not args or argCount > 7995 or (tableDepth > 0 and ((argCount + tableDepth) > 298)) then
            return
        end
        
        local V2Script = callStack[#callStack-1] and rawget(getfenv(callStack[#callStack-1].func), "script")
        if typeof(V2Script) ~= "Instance" then V2Script = nil end

        local data = {
            HasInstance = hasInstance or (not remote:IsAncestorOf(game)),
            TypeIndex = idxs[spyFunc.Name],
            Script = cs,
            Args = args, -- 2 deeper total
            ReturnValue = returnValue,
            NilCount = (argCount - #args),
            FromSynapse = caller,
            ScriptV2 = V2Script,
            CallStack = Settings.StoreCallStack and createCallStack(callStack)
        }
        sendLog(remote, remoteId, data)
    end
end

local function addCallback(remote, method, func)
    local oldIdentity = getThreadIdentity()
    setThreadIdentity(8)
    local remoteId = getDebugId(remote)
    local remoteType = remote.ClassName

    if not otherLogs[remoteId] then
        otherLogs[remoteId] = {
            Type = "Callback",
            CurrentFunction = func,
            Ignored = false,
            Blocked = false,
            Calls = {}
        }
    elseif otherLogs[remoteId].CurrentFunction then
        local curFunc = otherLogs[remoteId].CurrentFunction
        for i,v in _G.remoteSpyCallbackHooks do
            if v == curFunc then
                tableRemove(_G.remoteSpyCallbackHooks, i)
                break
            end
        end
        restorefunction(curFunc)
        otherLogs[remoteId].CurrentFunction = func
    end

    if func then
        local oldfunc
        oldfunc = hookfunction(func, function(...) -- lclosure, so oth.hook not applicable
            if #getCallStack() == 2 then -- check that the function is actually being called by a cclosure
                local oldLevel = getThreadIdentity()
                setThreadIdentity(8) -- fix for people passing coregui as an arg, also it's here because I'm too lazy to implement at the start of every hook.  Shouldn't be too dangerous because I restore it afterwards

                if not Settings.Paused then
                    local spyFunc = spyFunctions[idxs[method]]
                    local args, _, _, hasInstance = shallowClone({...}, remoteType, true, -1)
                    if not args then
                        pushError("Impossible error has occurred, please report to GameGuy#5920")
                        return oldfunc(...)
                    end
                    local argCount = select("#", ...)

                    local callingScript = originalCallerCache[remoteId] or {nil, checkcaller()}

                    originalCallerCache[remoteId] = nil

                    
                    local scr = getcallingscript()
                    if scr then scr = cloneref(scr) end

                    local data = {
                        HasInstance = hasInstance or (not remote:IsAncestorOf(game)),
                        TypeIndex = idxs[method],
                        CallbackScript = scr,
                        Script = callingScript[1],
                        Args = args, -- 2 deeper total
                        CallbackLog = otherLogs[remoteId],
                        NilCount = (argCount - #args),
                        FromSynapse = callingScript[2]
                    }

                    if spyFunc.ReturnsValue and not otherLogs[remoteId].Blocked then
                        local returnValue = {}
                        deferFunc(function()
                            if not otherLogs[remoteId].Ignored and (Settings.LogHiddenRemotesCalls or spyFunc.Enabled) then
                                data.ReturnValue = returnValue
                                sendLog(remote, remoteId, data)
                            end
                        end)

                        setThreadIdentity(oldLevel)
                        return processReturnValue(remoteType, returnValue, oldfunc(...))
                    end
                

                    if not otherLogs[remoteId].Ignored and (Settings.LogHiddenRemotesCalls or spyFunc.Enabled) then
                        sendLog(remote, remoteId, data)
                    end
                end

                setThreadIdentity(oldLevel)
                if otherLogs[remoteId] and otherLogs[remoteId].Blocked then 
                    return
                end
            end

            return oldfunc(...)
        end)
        tableInsert(_G.remoteSpyCallbackHooks, func)
    end
    setThreadIdentity(oldIdentity)
end

local function addConnection(remote, signalType, signal)
    local oldIdentity = getThreadIdentity()
    setThreadIdentity(8)
    local remoteId = getDebugId(remote)
    local remoteType = oldIndex(remote, "ClassName")

    if not otherLogs[remoteId] then
        otherLogs[remoteId] = {
            Type = "Connection",
            Ignored = false,
            Blocked = false,
            Calls = {}
        }
        
        local scriptCache = setmetatable({}, {__mode = "k"})
        local connectionCache = {} -- unused (for now)
        hooksignal(signal, function(info, ...)
            if not Settings.Paused then
                deferFunc(function(...)
                    setThreadIdentity(8) -- coregui stupidity.  this is safe because the original thread will never see this activity
                    local spyFunc = spyFunctions[idxs[signalType]]
                    if not otherLogs[remoteId].Ignored and (Settings.LogHiddenRemotesCalls or spyFunc.Enabled) then
                        if info.Index == 0 then
                            tableClear(connectionCache)
                            tableClear(scriptCache)
                        end

                        tableInsert(connectionCache, info.Connection)
                        local CS = issynapsethread(coroutine.running()) and "Synapse" or getcallingscript()
                        if CS then
                            if scriptCache[CS] then
                                scriptCache[CS] += 1
                            else
                                scriptCache[CS] = 1
                            end
                        end

                        local callingScript = originalCallerCache[remoteId] or {nil, false}

                        originalCallerCache[remoteId] = nil
                        
                        if info.Index == (#getconnections(signal)-1) then -- -1 because base 0 for info.Index
                            local args, _, _, hasInstance = shallowClone({...}, remoteType, true, -1)
                            if not args then
                                pushError("Impossible error has occurred, please report to GameGuy#5920")
                                return true, ...
                            end
                            local argCount = select("#", ...)
                            local data = {
                                HasInstance = hasInstance or (not remote:IsAncestorOf(game)),
                                TypeIndex = idxs[signalType],
                                Script = callingScript[1],
                                Scripts = scriptCache,
                                Connections = connectionCache,
                                Signal = signal,
                                Args = args, -- 2 deeper total
                                NilCount = (argCount - #args),
                                FromSynapse = callingScript[2]
                            }

                            sendLog(remote, remoteId, data)
                        end
                    end
                end, ...)
            end

            if otherLogs[remoteId].Blocked then 
                return false
            end
            return true, ...
        end)
        tableInsert(_G.remoteSpySignalHooks, signal)
    end
    setThreadIdentity(oldIdentity)
end

local namecallFilters = {}
local newIndexFilters = {}
local indexFilters = {}

do -- filter setup
    for _,v in spyFunctions do
        if v.Type == "Callback" then
            tableInsert(newIndexFilters, AllFilter.new({
                InstanceTypeFilter.new(1, v.Object),
                AnyFilter.new({
                    ArgumentFilter.new(2, v.Callback),
                    ArgumentFilter.new(2, v.DeprecatedCallback)
                }),
                TypeFilter.new(3, "function")
            }))
        elseif v.Type == "Call" then
            tableInsert(namecallFilters, AllFilter.new({
                InstanceTypeFilter.new(1, v.Object),
                AnyFilter.new({
                    NamecallFilter.new(v.Method),
                    NamecallFilter.new(v.DeprecatedMethod)
                })
            }))
        elseif v.Type == "Connection" then
            tableInsert(indexFilters, AllFilter.new({
                InstanceTypeFilter.new(1, v.Object),
                AnyFilter.new({
                    ArgumentFilter.new(2, v.Connection),
                    ArgumentFilter.new(2, v.DeprecatedConnection)
                })
            }))
        end
    end
end

oldNewIndex = newHookMetamethod(game, "__newindex", function(remote, idx, newidx)
    addCallback(cloneref(remote), idx, newidx)

    return oldNewIndex(remote, idx, newidx)
end, AnyFilter.new(newIndexFilters))
_G.remoteSpyHooks.NewIndex = oldNewIndex

oldIndex = newHookMetamethod(game, "__index", function(remote, idx)
    local newSignal = oldIndex(remote, idx)
    addConnection(cloneref(remote), idx, newSignal)

    return newSignal
end, AnyFilter.new(indexFilters))
_G.remoteSpyHooks.Index = oldIndex

local initInfo = {
    RemoteFunction = { "Callback", "OnClientInvoke" },
    BindableFunction = { "Callback", "OnInvoke" },
    RemoteEvent = { "Connection", "OnClientEvent" },
    BindableEvent = { "Connection", "Event" }
}

do -- init OnClientInvoke and signal index
    for _,v in game:GetDescendants() do
        local data = initInfo[v.ClassName]
        if data then
            if data[1] == "Connection" then
                local _ = v[data[2]] -- calls the OTH of __index which adds the connection
            elseif data[1] == "Callback" then
                local func = getcallbackmember(v, data[2])
                if func then
                    addCallback(cloneref(v), data[2], func)
                end
            end
        end
    end

    for _,v in getnilinstances() do
        local data = initInfo[v.ClassName]
        if data then
            if data[1] == "Connection" then
                local _ = v[data[2]] -- calls the OTH of __index which adds the connection
            elseif data[1] == "Callback" then
                local func = getcallbackmember(v, data[2])
                if func then
                    addCallback(cloneref(v), data[2], func)
                end
            end
        end
    end
end

do -- namecall and function hooks
    local oldNamecall
    oldNamecall = newHookMetamethod(game, "__namecall", newcclosure(function(remote, ...)
        setThreadIdentity(8) -- oth isn't stock at 8 for some reason
        local remoteId = getDebugId(remote)

        if not Settings.Paused and select("#", ...) < 7996 then
            local scr = getcallingscript()
            if scr then scr = cloneref(scr) end

            local spyFunc = spyFunctions[idxs[getnamecallmethod()]]
            if spyFunc.Type == "Call" and spyFunc.FiresLocally then
                local caller = checkcaller()
                originalCallerCache[remoteId] = originalCallerCache[remoteId] or {(not caller and scr), caller}
            end
            -- it will either return true at checkcaller because called from synapse (non remspy), or have already been set by remspy

            if spyFunc.ReturnsValue and (not callLogs[remoteId] or not callLogs[remoteId].Blocked) then
                local returnValue = {}
                deferFunc(addCall, cloneref(remote), remoteId, returnValue, spyFunc, checkcaller(), scr, getCallStack(getOriginalThread()), ...)
                
                return processReturnValue(getproperties(remote).ClassName, returnValue, oldNamecall(remote, ...)) -- getproperties(remote).ClassName is not performant at all, but using oldIndex breaks stuff
            end
            deferFunc(addCall, cloneref(remote), remoteId, nil, spyFunc, checkcaller(), scr, getCallStack(getOriginalThread()), ...)
        end
    
        if callLogs[remoteId] and callLogs[remoteId].Blocked then return end

        return oldNamecall(remote, ...)
    end), AnyFilter.new(namecallFilters))

    for _,v in spyFunctions do
        if v.Type == "Call" then
            local oldFunc
            local newfunction = function(remote, ...)
                setThreadIdentity(8) -- oth isn't stock at 8 for some reason
                local remoteId = getDebugId(remote)

                if not Settings.Paused and select("#", ...) < 7996 then
                    local scr = getcallingscript()
                    if scr then scr = cloneref(scr) end

                    if v.Type == "Call" and v.FiresLocally then
                        local caller = checkcaller()
                        originalCallerCache[remoteId] = originalCallerCache[remoteId] or {(not caller and scr), caller}
                    end

                    if v.ReturnsValue and (not callLogs[remoteId] or not callLogs[remoteId].Blocked) then
                        local returnValue = {}
                        deferFunc(addCall, cloneref(remote), remoteId, returnValue, v, checkcaller(), scr, getCallStack(getOriginalThread()), ...)

                        return processReturnValue(getproperties(remote).ClassName, returnValue, oldFunc(remote, ...))
                    end
                    deferFunc(addCall, cloneref(remote), remoteId, nil, v, checkcaller(), scr, getCallStack(getOriginalThread()), ...)
                end
            
                if callLogs[remoteId] and callLogs[remoteId].Blocked then return end

                return oldFunc(remote, ...)
            end

            local originalFunc = Instance.new(v.Object)[v.Method]
            oldFunc = filteredOth(originalFunc, newcclosure(newfunction), InstanceTypeFilter.new(1, v.Object)) 
            
            v.Function = originalFunc
            _G.remoteSpyHooks[v.Method] = oldFunc
        end
    end
end

-- CREDIT TO https://github.com/Upbolt/Hydroxide/ FOR INSPIRATION AND A FEW FORKED TOSTRING FUNCTIONS
