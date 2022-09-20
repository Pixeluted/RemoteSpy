-- CREDIT TO https://github.com/Upbolt/Hydroxide/ FOR INSPIRATION AND A FEW FORKED TOSTRING FUNCTIONS

-- TO DO:
    -- Can't scroll args when hovering over arg button cause of focus loss (Need to rework the entire way clicking args works)
    -- Make main window remote list use popups (depends on OnRightClick)
    -- Make arg list use right click (depends on defcon)

if not RenderWindow then
    error("EXPLOIT NOT SUPPORTED - GET SYNAPSE V3")
end

local function cleanUpSpy()
    for _,v in _G.remoteSpyGuiConnections do
        v:Disconnect()
    end

    for _,v in _G.remoteSpyCallbackHooks do
        restorefunction(v)
    end

    for _,v in _G.remoteSpySignalHooks do
        unhooksignal(v)
    end

    _G.remoteSpyGuiConnections = nil
    _G.remoteSpyMainWindow = nil
    _G.remoteSpySettingsWindow = nil
    
    restorefunction(Instance.new("RemoteEvent").FireServer)
    restorefunction(Instance.new("RemoteFunction").InvokeServer)
    restorefunction(Instance.new("BindableEvent").Fire)
    restorefunction(Instance.new("BindableFunction").Invoke)
    restorefunction(getrawmetatable(game).__namecall)
    restorefunction(getrawmetatable(game).__index)
    restorefunction(getrawmetatable(game).__newindex)
end

if not _G.remoteSpyMainWindow and not _G.remoteSpySettingsWindow then

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

        CallbackButtons = false,
        DecompileScriptsToExternal = false,
        ListConnectionScriptsToExternal = false,
        LogHiddenRemotesCalls = false,
        MoreRepeatCallOptions = false,
        CacheLimit = true,
        MaxCallAmount = 1000,

        SendPseudocodeToExternal = false,
        PseudocodeLuaUTypes = false,
        PseudocodeWatermark = 2,
        PseudocodeInliningMode = 2,
        PseudocodeInlineRemote = true,
        PseudocodeInlineHiddenNils = true,
        PseudocodeFormatTables = true
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

    local colorHSV, colorRGB, tableInsert, tableClear, tableRemove, taskWait, deferFunc, spawnFunc, gsub, rep, sub, split, strformat, lower, match = Color3.fromHSV, Color3.fromRGB, table.insert, table.clear, table.remove, task.wait, task.defer, task.spawn, string.gsub, string.rep, string.sub, string.split, string.format, string.lower, string.match

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

    local function pushError(message: string)
        syn.toast_notification({
            Type = ToastType.Error,
            Duration = 5,
            Title = "Remote Spy",
            Content = message
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

    local function shallowClone(myTable: table, stack: number) -- cyclic check built in
        stack = stack or 0 -- you can offset stack by setting the starting parameter to a number
        local newTable = {}
        local hasTable = false

        if #myTable > 0 then stack += 1 end -- replacing the old method because stack doesnt increase unless args are added

        if stack == 300 then -- this stack overflow check doesn't really matter as a stack overflow check, it's just here to make sure there are no cyclic tables.  While I could just check for cyclics directly, this is faster.
            return false, stack
        end

        for i,v in next, myTable do
            if type(v) == "table" then
                hasTable = true

                local newTab, maxStack = shallowClone(v, stack)
                stack = maxStack
                
                if newTab then
                    newTable[i] = newTab
                else
                    return false, stack -- stack overflow
                end
            else
                if typeof(v) == "Instance" then
                    newTable[i] = cloneref(v)
                else
                    newTable[i] = v
                end
            end
        end

        if stack == -1 then -- set any nils in the middle so the table size is correct
            for i = 1, #myTable do
                if not newTable[i] then
                    newTable[i] = nil
                end
            end
        end
        
        return newTable, stack, hasTable
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

    local function purifyString(str: string, quotes: boolean)
        str = gsub(synEncode(gsub(str, "\\", "\\\\")), "%%", "\\x")
        for i,v in asciiFilteredCharacters do
            str = gsub(str, v, i)
        end

        if quotes then
            return '"' .. str .. '"'
        else
            return str
        end
    end

    local gameId, workspaceId = game:GetDebugId(), workspace:GetDebugId()
    
    local function getInstancePath(instance) -- FORKED FROM HYDROXIDE
        if not instance then return "NIL INSTANCE" end
        local name = instance.Name
        local head = (#name > 0 and '.' .. name) or "['']"
        
        if not instance.Parent and instance ~= game then
            return head .. " --[[ PARENTED TO NIL OR DESTROYED ]]"
        end
        local old = syn.get_thread_identity()
        local id
        if old < 3 then
            syn.set_thread_identity(3)
            id = instance:GetDebugId()
            syn.set_thread_identity(old)
        else
            id = instance:GetDebugId()
        end
        
        if id == gameId then
            return "game"
        elseif id == workspaceId then
            return "workspace"
        else
            local plr = Players:GetPlayerFromCharacter(instance)
            if plr then
                if plr == client then
                    return 'game:GetService("Players").LocalPlayer.Character'
                else
                    if tonumber(sub(plr.Name, 1, 1)) then
                        return 'game:GetService("Players")["'..plr.Name..'"]".Character'
                    else
                        return 'game:GetService("Players").'..plr.Name..'.Character'
                    end
                end
            end
            local _success, result = pcall(game.GetService, game, instance.ClassName)
            
            if _success and result then
                head = ':GetService("' .. instance.ClassName .. '")'
            elseif id == clientid then -- cloneref moment
                head = '.LocalPlayer' 
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
        
        return getInstancePath(instance.Parent) .. head
    end

    local function toString(value)
        return type(value) == "userdata" and userdataValue(value) or tostring(value)
    end

    local function userdataValue(data) -- FORKED FROM HYDROXIDE
        local dataType = typeof(data)

        if dataType == "userdata" then
            return "aux.placeholderUserdataConstant"
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
            local split = split(tostring(data), '}, ')
            local vector = gsub(split[1], '{', "Vector3.new(")
            return dataType .. ".new(" .. vector .. "), " .. split[2] .. ')'
        elseif dataType == "Ray" or dataType == "Region3" then
            local split = split(tostring(data), '}, ')
            local vprimary = gsub(split[1], '{', "Vector3.new(")
            local vsecondary = gsub(gsub(split[2], '{', "Vector3.new("), '}', ')')
            return dataType .. ".new(" .. vprimary .. "), " .. vsecondary .. ')'
        elseif dataType == "ColorSequence" or dataType == "NumberSequence" then 
            return dataType .. ".new(" .. tableToString(data.Keypoints) .. ')'
        elseif dataType == "ColorSequenceKeypoint" then
            return "ColorSequenceKeypoint.new(" .. data.Time .. ", Color3.new(" .. tostring(data.Value) .. "))"
        elseif dataType == "NumberSequenceKeypoint" then
            local envelope = data.Envelope and data.Value .. ", " .. data.Envelope or data.Value
            return "NumberSequenceKeypoint.new(" .. data.Time .. ", " .. envelope .. ")"
        end

        return tostring(data)
    end

    local function tableToString(data, format, root, indents) -- FORKED FROM HYDROXIDE
        local dataType = type(data)

        format = (format==true) or (format==nil) or ((format==false) and false)

        if dataType == "userdata" or dataType == "vector" then
            return (typeof(data) == "Instance" and getInstancePath(data)) or userdataValue(data)
        elseif dataType == "string" then
            local success, result = pcall(purifyString, data, true)
            return (success and result) or toString(data)
        elseif dataType == "table" then
            indents = indents or 1
            root = root or data

            local head = format and '{\n' or '{ '
            local elements = 0
            local indent = rep('\t', indents)
            -- moved checkCyclic check to hook
            if format then
                for i,v in data do
                    elements += 1

                    if type(i) == "number" and elements == i then -- table will either use all numbers, or mixed between non numbers
                        head ..= strformat("%s%s,\n", indent, tableToString(v, true, root, indents + 1))
                    else
                        head ..= strformat("%s[%s] = %s,\n", indent, tableToString(i, true, root, indents + 1), tableToString(v, true, root, indents + 1))
                    end
                end
            else
                for i,v in data do
                    elements += 1

                    if type(i) == "number" and elements == i then -- table will either use all numbers, or mixed between non numbers
                        head ..= strformat("%s, ", tableToString(v, false, root, indents + 1))
                    else
                        head ..= strformat("[%s] = %s, ", tableToString(i, false, root, indents + 1), tableToString(v, false, root, indents + 1))
                    end
                end
            end
            
            if format then
                return elements > 0 and strformat("%s\n%s", sub(head, 1, -3), rep('\t', indents - 1) .. '}') or "{}"
            else
                return elements > 0 and (sub(head, 1, -3) .. ' }') or "{}"
            end
        elseif dataType == "function" and (call.Type == "BindableEvent" or call.Type == "BindableFunction") then -- functions are only receivable through bindables, not remotes
            varConstructor = 'nil -- "' .. tostring(data) .. '"  FUNCTIONS CANT BE MADE INTO PSEUDOCODE' -- just in case
        elseif dataType == "thread" and false then -- dont bother listing threads because they can never be sent
            varConstructor = 'nil -- "' .. tostring(data) .. '"  THREADS CANT BE MADE INTO PSEUDOCODE' -- just in case
        elseif dataType == "thread" or dataType == "function" then
            varConstructor = "nil"
        elseif dataType == "number" then
            if not match(tostring(data), "%d") then
                return ("tonumber(\"" .. tostring(data) .. "\")")
            else
                return tostring(data)
            end
        else
            return tostring(data)
        end
    end

    local types = {
        ["string"] = { colorHSV(29/360, 0.8, 1), function(obj)
            return purifyString(obj, true)
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
        ["thread"] = { white, function(obj)
            -- threads can't be received by Remotes or Bindables
            return tostring(obj) -- threads dont get sent by bindables, which I use to communicate with the remotespy, so if your logs are showing nil when you want them to show a thread, that's why.
        end },
        ["nil"] = { colorHSV(360/360, 0.8, 1), function(obj)
            return "nil"
        end }
    }

    local function getArgString(arg, remType)
        local t = type(arg)
        if (t == "thread") or (t == "function" and (remType == "RemoteFunction" or remType == "RemoteEvent")) then
            return "nil", types["nil"][1]
        end -- edge case

        if types[t] and t ~= "userdata" then
            local st = types[t]
            return st[2](arg), st[1]
        elseif t == "userdata" or t == "vector" then
            local st = userdataValue(arg)
            return st, (typeof(arg) == "Instance" and colorHSV(57/360, 0.8, 1)) or colorHSV(314/360, 0.8, 1)
        else
            return ("Unprocessed Lua Type: " .. tostring(t)), colorRGB(1, 1, 1)
        end
    end
    
    local spaces = "                 "
    local spaces2 = "        " -- 8 spaces
    local curPage = 1

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
            Icon = "\xef\x83\xa7",
            Color = colorRGB(253, 206, 0),
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
            Icon = "\xef\x81\xa4",
            Color = colorRGB(250, 152, 251),
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
            Icon = "\xef\x83\xa7",
            Color = colorRGB(200, 100, 0),
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
            Icon = "\xef\x81\xa4",
            Color = colorRGB(163, 51, 189),
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
            Icon = "\xef\x83\xa8",
            Color = colorRGB(253, 206, 0),
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
            Icon = "\xef\x84\xa2",
            Color = colorRGB(250, 152, 251),
            Indent = 153
        },
        {
            Name = "OnEvent",
            Object = "BindableEvent",
            Type = "Connection",
            Connection = "Event", -- not OnEvent cause roblox naming is wacky
            DeprecatedConnection = "event",
            Enabled = Settings.OnEvent,
            Icon = "\xef\x83\xa8",
            Color = colorRGB(200, 100, 0),
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
            Icon = "\xef\x84\xa2",
            Color = colorRGB(163, 51, 189),
            Indent = 434
        }
    }

    local repeatCallSteps = {
        1,
        10,
        100,
        1000
    }

    local function getCountFromTable(tab: table, target)
        local count = 0
        for _,v in tab do
            if v[1] == target then
                count += 1
            end
        end
        return count
    end

    local function genSendPseudo(rem, call, spyFunc, watermark)
        local watermark = watermark and "--Pseudocode Generated by GameGuy's Remote Spy\n\n" or ""

        if #call.Args == 0 and call.NilCount == 0 then
            if spyFunc.Type == "Call" then
                return watermark .. (Settings.PseudocodeInlineRemote and ("local remote" .. (Settings.PseudocodeLuaUTypes and (": " .. spyFunc.Object) or "").." = " .. getInstancePath(rem) .. "\n\n" .. (spyFunc.ReturnsValue and "local returnValue = " or "") .. "remote:") or (getInstancePath(rem) .. ":")) .. spyFunc.Method .."()"
            elseif spyFunc.Type == "Connection" then
                return watermark .. (Settings.PseudocodeInlineRemote and ("local remote" .. (Settings.PseudocodeLuaUTypes and (": " .. spyFunc.Object) or "").." = " .. getInstancePath(rem) .. "\n\nfiresignal(remote.") or ("firesignal(" .. getInstancePath(rem) ".")) .. spyFunc.Connection ..")"
            elseif spyFunc.Type == "Callback" then
                return watermark .. (Settings.PseudocodeInlineRemote and ("local remote" .. (Settings.PseudocodeLuaUTypes and (": " .. spyFunc.Object) or "").." = " .. getInstancePath(rem) .. "\n\ngetcallbackmember(remote, ") or ("getcallbackmember(" .. getInstancePath(rem) .. ", ")) .. spyFunc.Callback ..")()"
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

                if primTyp == "thread" or (primTyp == "function" and (call.Type == "RemoteEvent" or call.Type == "RemoteFunction")) then
                    typ = "nil" -- functions are only receivable through bindables, not remotes
                    primTyp = "nil"
                end -- dont bother listing threads because they can never be sent

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
                    varConstructor = (typ == "Instance" and getInstancePath(arg)) or userdataValue(arg)
                elseif primTyp == "table" then
                    varConstructor = tableToString(arg, Settings.PseudocodeFormatTables)
                elseif primTyp == "string" then
                    varConstructor = purifyString(arg, true)
                elseif primTyp == "function" then
                    varConstructor = 'nil -- "' .. tostring(arg) .. '"  FUNCTIONS CANT BE MADE INTO PSEUDOCODE' -- just in case
                elseif primTyp == "thread" then
                    varConstructor = 'nil -- "' .. tostring(arg) .. '"  THREADS CANT BE MADE INTO PSEUDOCODE' -- just in case
                elseif primTyp == "thread" or primTyp == "function" then
                    varConstructor = "nil"
                elseif primTyp == "number" then
                    if not match(tostring(arg), "%d") then
                        varConstructor = ("tonumber(\"" .. tostring(arg) .. "\")")
                    else
                        varConstructor = tostring(arg)
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
                pseudocode ..= Settings.PseudocodeInlineRemote and ((addedArg and "\n" or "") .. "local remote" .. (Settings.PseudocodeLuaUTypes and (": " .. spyFunc.Object) or "").." = " .. getInstancePath(rem) .. "\n" .. (spyFunc.ReturnsValue and "local returnValue = " or "") .. "remote:" .. spyFunc.Method .. "(") or (getInstancePath(rem) .. ":" .. spyFunc.Method .. "(")
            elseif spyFunc.Type == "Connection" then
                pseudocode ..= Settings.PseudocodeInlineRemote and ((addedArg and "\n" or "") .. "local remote" .. (Settings.PseudocodeLuaUTypes and (": " .. spyFunc.Object) or "").." = " .. getInstancePath(rem) .. "\n" .. (spyFunc.ReturnsValue--[[yes i know this is redundant]] and "local returnValue = " or "") .. "firesignal(remote." .. spyFunc.Connection .. ", ") or ("firesignal(" .. getInstancePath(rem) .. "." .. spyFunc.Connection .. ", ")
            elseif spyFunc.Type == "Callback" then
                pseudocode ..= Settings.PseudocodeInlineRemote and ((addedArg and "\n" or "") .. "local remote" .. (Settings.PseudocodeLuaUTypes and (": " .. spyFunc.Object) or "").." = " .. getInstancePath(rem) .. "\n" .. (spyFunc.ReturnsValue and "local returnValue = " or "") .. "getcallbackmember(remote." .. spyFunc.Callback .. ")(") or ("getcallbackmember(" .. getInstancePath(rem) .. ", " .. spyFunc.Callback .. ")(")
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

    local function genReturnValuePseudo(returnTable, spyFunc, watermark)
        local watermark = watermark and "--Pseudocode Generated by GameGuy's Remote Spy\n\n" or ""

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

                if primTyp == "thread" or (primTyp == "function" and spyFunc.Object == "BindableFunction") then
                    typ = "nil" -- functions are only receivable through bindables, not remotes
                    primTyp = "nil"
                end -- dont bother listing threads because they can never be sent

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
                    varConstructor = (typ == "Instance" and getInstancePath(arg)) or userdataValue(arg)
                elseif primTyp == "table" then
                    varConstructor = tableToString(arg, Settings.PseudocodeFormatTables)
                elseif primTyp == "string" then
                    varConstructor = purifyString(arg, true)
                elseif primTyp == "function" then
                    varConstructor = 'nil -- "' .. tostring(arg) .. '"  FUNCTIONS CANT BE MADE INTO PSEUDOCODE' -- just in case
                elseif primTyp == "thread" then
                    varConstructor = 'nil -- "' .. tostring(arg) .. '"  THREADS CANT BE MADE INTO PSEUDOCODE' -- just in case
                elseif primTyp == "thread" or primTyp == "function" then
                    varConstructor = "nil"
                elseif primTyp == "number" then
                    if not match(tostring(arg), "%d") then
                        varConstructor = ("tonumber(\"" .. tostring(arg) .. "\")")
                    else
                        varConstructor = tostring(arg)
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
        local watermark = watermark and "--Pseudocode Generated by GameGuy's Remote Spy\n\n" or ""

        if spyFunc.Type == "Connection" then
            local pseudocode = ""
            
            pseudocode ..= Settings.PseudocodeInlineRemote and ("local remote" .. (Settings.PseudocodeLuaUTypes and (": " .. spyFunc.Object) or "") .." = " .. getInstancePath(rem) .. "\nremote." .. spyFunc.Connection .. ":Connect(function(") or (getInstancePath(rem) .. "." .. spyFunc.Connection .. ":Connect(function(")
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

            pseudocode ..= Settings.PseudocodeInlineRemote and ("local remote" .. (Settings.PseudocodeLuaUTypes and (": " .. spyFunc.Object) or "").." = " .. getInstancePath(rem) .. "\nremote." .. spyFunc.Callback .. " = function(") or (getInstancePath(rem) .. "." .. spyFunc.Callback .. " = function(")
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
    local otherCheckCaller = {}
    local callLines = {}
    local callLogs = {}
    local callFuncs = {}
    local callCheckCaller = {}

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
     
    local function updateLines(name: string, enabled: bool)
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
    
    _G.remoteSpyMainWindow = RenderWindow.new("Remote Spy")
    _G.remoteSpySettingsWindow = RenderWindow.new("Remote Spy Settings")
    _G.remoteSpyGuiConnections = {}
    _G.remoteSpyCallbackHooks = {}
    _G.remoteSpySignalHooks = {}

    local mainWindow = _G.remoteSpyMainWindow
    local settingsWindow = _G.remoteSpySettingsWindow
    pushTheme(mainWindow)
    pushTheme(settingsWindow)

    -- settings page init
    local settingsWidth = 310
    local settingsHeight = 301
    settingsWindow.DefaultSize = Vector2.new(settingsWidth, settingsHeight)
    settingsWindow.CanResize = false
    settingsWindow.VisibilityOverride = true
    settingsWindow.Visible = false
    settingsWindow:SetColor(RenderColorOption.ResizeGrip, black, 0)
    settingsWindow:SetColor(RenderColorOption.ResizeGripActive, black, 0)
    settingsWindow:SetColor(RenderColorOption.ResizeGripHovered, black, 0)
    settingsWindow:SetStyle(RenderStyleOption.WindowPadding, Vector2.new(8, 4))
    settingsWindow:SetStyle(RenderStyleOption.ButtonTextAlign, Vector2.new(0.5, 0.5))

    -- main page init
    local width = 562
    mainWindow.DefaultSize = Vector2.new(width, 350)
    mainWindow.MinSize = Vector2.new(width, 350)
    mainWindow.MaxSize = Vector2.new(width, 5000)
    mainWindow.VisibilityOverride = true

    local frontPage = mainWindow:Dummy()
    local remotePage = mainWindow:Dummy()

    -- Below this is rendering Settings page

    local topBar = settingsWindow:SameLine()
    local exitButtonFrame = topBar:SameLine()
    exitButtonFrame:SetColor(RenderColorOption.Button, black, 0)
    exitButtonFrame:SetColor(RenderColorOption.ButtonHovered, black, 0)
    exitButtonFrame:SetColor(RenderColorOption.ButtonActive, black, 0)

    local exitButton = exitButtonFrame:Indent(settingsWidth-40):Button()
    exitButton.Label = "\xef\x80\x8d"
    exitButton.Size = Vector2.new(25, 25)
    tableInsert(_G.remoteSpyGuiConnections, exitButton.OnUpdated:Connect(function()
        settingsWindow.Visible = false
    end))
    
    local tabFrame = topBar:SameLine()
    local settingsTabs = tabFrame:Indent(-1):TabMenu()
    local generalTab = settingsTabs:Add("General")
    local pseudocodeTab = settingsTabs:Add("Pseudocode")
    local themeTab = settingsTabs:Add("Theme")
    local creditsTab = settingsTabs:Add("Credits")
    do  -- general Settings
        local checkBox = generalTab:CheckBox()
        checkBox.Label = "Display Callbacks And Connections"
        checkBox.Value = Settings.CallbackButtons
        tableInsert(_G.remoteSpyGuiConnections, checkBox.OnUpdated:Connect(function(value)
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
        end))

        local checkBox2 = generalTab:CheckBox()
        checkBox2.Label = "Decompile Scripts to External UI"
        checkBox2.Value = Settings.DecompileScriptsToExternal
        tableInsert(_G.remoteSpyGuiConnections, checkBox2.OnUpdated:Connect(function(value)
            Settings.DecompileScriptsToExternal = value
            saveConfig()
        end))

        local checkBox3 = generalTab:CheckBox()
        checkBox3.Label = "List Connection Scripts to External UI"
        checkBox3.Value = Settings.ListConnectionScriptsToExternal
        tableInsert(_G.remoteSpyGuiConnections, checkBox3.OnUpdated:Connect(function(value)
            Settings.ListConnectionScriptsToExternal = value
            saveConfig()
        end))

        local checkBox4 = generalTab:CheckBox()
        checkBox4.Label = "Cache Unselected Remotes' Calls"
        checkBox4.Value = Settings.LogHiddenRemotesCalls
        tableInsert(_G.remoteSpyGuiConnections, checkBox4.OnUpdated:Connect(function(value)
            Settings.LogHiddenRemotesCalls = value
            saveConfig()
        end))

        local checkBox6 = generalTab:CheckBox()
        checkBox6.Label = "Call Cache Amount Limiter (Per Remote)"
        checkBox6.Value = Settings.CacheLimit
        tableInsert(_G.remoteSpyGuiConnections, checkBox6.OnUpdated:Connect(function(value)
            Settings.CacheLimit = value
            saveConfig()
        end))

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

        local checkBox5 = generalTab:CheckBox()
        checkBox5.Label = "Extra Repeat Call Amounts"
        checkBox5.Value = Settings.MoreRepeatCallOptions
        tableInsert(_G.remoteSpyGuiConnections, checkBox5.OnUpdated:Connect(function(value)
            Settings.MoreRepeatCallOptions = value
            saveConfig()
        end))
    end -- general settings

    do -- pseudocode settings
        local checkBox = pseudocodeTab:CheckBox()
        checkBox.Label = "Send Pseudocode To External UI"
        checkBox.Value = Settings.SendPseudocodeToExternal
        tableInsert(_G.remoteSpyGuiConnections, checkBox.OnUpdated:Connect(function(value)
            Settings.SendPseudocodeToExternal = value
            saveConfig()
        end))

        local checkBox2 = pseudocodeTab:CheckBox()
        checkBox2.Label = "Use LuaU Type Declaration in Pseudocode"
        checkBox2.Value = Settings.PseudocodeLuaUTypes
        tableInsert(_G.remoteSpyGuiConnections, checkBox2.OnUpdated:Connect(function(value)
            Settings.PseudocodeLuaUTypes = value
            saveConfig()
        end))

        pseudocodeTab:Label("Pseudocode Watermark")
        local combo1 = pseudocodeTab:Combo()
        combo1.Items = { "Off", "External UI Only", "Always On" }
        combo1.SelectedItem = Settings.PseudocodeWatermark
        tableInsert(_G.remoteSpyGuiConnections, combo1.OnUpdated:Connect(function(selection)
            Settings.PseudocodeWatermark = selection
            saveConfig()
        end))

        pseudocodeTab:Label("Pseudocode Inlining Mode")
        local combo2 = pseudocodeTab:Combo()
        combo2.Items = { "Everything", "Tables And Userdatas", "Tables Only", "Nothing" }
        combo2.SelectedItem = Settings.PseudocodeInliningMode
        tableInsert(_G.remoteSpyGuiConnections, combo2.OnUpdated:Connect(function(selection)
            Settings.PseudocodeInliningMode = selection
            saveConfig()
        end))

        local checkBox3 = pseudocodeTab:CheckBox()
        checkBox3.Label = "Inline Remote"
        checkBox3.Value = Settings.PseudocodeInlineRemote
        tableInsert(_G.remoteSpyGuiConnections, checkBox3.OnUpdated:Connect(function(value)
            Settings.PseudocodeInlineRemote = value
            saveConfig()
        end))

        local checkBox4 = pseudocodeTab:CheckBox()
        checkBox4.Label = "Inline Hidden Nils"
        checkBox4.Value = Settings.PseudocodeInlineHiddenNils
        tableInsert(_G.remoteSpyGuiConnections, checkBox4.OnUpdated:Connect(function(value)
            Settings.PseudocodeInlineHiddenNils = value
            saveConfig()
        end))

        local checkBox5 = pseudocodeTab:CheckBox()
        checkBox5.Label = "Format Tables"
        checkBox5.Value = Settings.PseudocodeFormatTables
        tableInsert(_G.remoteSpyGuiConnections, checkBox5.OnUpdated:Connect(function(value)
            Settings.PseudocodeFormatTables = value
            saveConfig()
        end))
    end -- pseudocode settings

    do -- theme settings
        themeTab:Label("Hah No.")
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

    local currentSelectedRemote = nil
    local currentSelectedType = nil

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
        currentSelectedType = ""
        for _,v in argLines do
            v[2]:Clear()
        end
        tableClear(argLines)
        remoteViewerMainWindow:Clear()
    end

    local topBar = remotePage:SameLine()

    do -- topbar code

        local exitButtonFrame = topBar:Dummy()
        exitButtonFrame:SetColor(RenderColorOption.Button, black, 0)
        exitButtonFrame:SetStyle(RenderStyleOption.ButtonTextAlign, Vector2.new(0.5, 0.5))
        local exitButton = exitButtonFrame:Indent(width-41):Button()
        exitButton.Size = Vector2.new(24, 24)
        exitButton.Label = "\xef\x80\x8d"
        tableInsert(_G.remoteSpyGuiConnections, exitButton.OnUpdated:Connect(unloadRemote))

        local remoteNameFrame = topBar:Dummy()
        remoteNameFrame:SetStyle(RenderStyleOption.ButtonTextAlign, Vector2.new(0, 0.5))
        remoteNameFrame:SetColor(RenderColorOption.Button, black, 0)
        remoteNameFrame:SetColor(RenderColorOption.ButtonActive, black, 0)
        remoteNameFrame:SetColor(RenderColorOption.ButtonHovered, black, 0)
        local remoteName = remoteNameFrame:Indent(26):Button()
        remoteName.Size = Vector2.new(150, 24)
        remoteName.Label = "RemoteEvent"

        local remoteIconFrame = topBar:Dummy()
        remoteIconFrame:SetStyle(RenderStyleOption.ButtonTextAlign, Vector2.new(1, 0.5))
        remoteIconFrame:SetColor(RenderColorOption.Button, black, 0)
        remoteIconFrame:SetColor(RenderColorOption.ButtonActive, black, 0)
        remoteIconFrame:SetColor(RenderColorOption.ButtonHovered, black, 0)
        remoteIconFrame:SetColor(RenderColorOption.Text, black, 1) -- temporarily black, gets set later
        local remoteIcon = remoteIconFrame:Indent(4):Button()
        remoteIcon.Size = Vector2.new(20, 24)
        remoteIcon.Label = "\xef\x83\xa7"

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
        
        tableInsert(_G.remoteSpyGuiConnections, ignoreButton.OnUpdated:Connect(function()
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
        end))

        local blockButtonFrame = buttonBar:Dummy()
        blockButtonFrame:SetColor(RenderColorOption.Text, red, 1)
        local blockButton = blockButtonFrame:Button()
        blockButton.Label = "Block"
        tableInsert(_G.remoteSpyGuiConnections, blockButton.OnUpdated:Connect(function()
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
        end))
        local clearLogsButton = buttonBar:Button()
        clearLogsButton.Label = "Clear Logs"
        tableInsert(_G.remoteSpyGuiConnections, clearLogsButton.OnUpdated:Connect(function()
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
        end))

        local copyPathButton = buttonBar:Button()
        copyPathButton.Label = "Copy Path"
        tableInsert(_G.remoteSpyGuiConnections, copyPathButton.OnUpdated:Connect(function()
            if currentSelectedRemote then
                local str = getInstancePath(currentSelectedRemote)
                if type(str) == "string" then
                    setclipboard(str)
                    pushSuccess("Copied Path to Clipboard")
                else
                    pushError("Failed to Copy Path")
                end
            end
        end))

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
        local con = nil
        if not (spyFunc.HasNoCaller or call.FromSynapse) then
            con = button.OnUpdated:Connect(function()
                local str = call.Script and getInstancePath(call.Script) -- not sure if getcallingscript can return a ModuleScript, I assume it can't, but adding this just in case
                if type(str) == "string" then
                    setclipboard(str)
                    pushSuccess("Copied Calling Script to Clipboard")
                else
                    pushError("Failed to get Calling Script")
                end
            end)
            tableInsert(_G.remoteSpyGuiConnections, con)
        end
        return con
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
        local con = nil
        if not (spyFunc.HasNoCaller or call.FromSynapse) then
            con = button.OnUpdated:Connect(function()
                if not pcall(function()
                    local str = decompile(call.Script)
                    local scriptName = call.Script and getInstancePath(call.Script)
                    if type(str) == "string" then
                        if Settings.DecompileScriptsToExternal then
                            createuitab(scriptName or "Script Not Found", str)
                            pushSuccess("Decompiled Calling Script to External UI")
                        else
                            pushSuccess("Decompiled Calling Script to Clipboard")
                            setclipboard(str)
                        end
                    else
                        pushError("Failed to Decompile Calling Script2")
                    end
                end) then
                    pushError("Failed to Decompile Calling Script")
                end
            end)
            tableInsert(_G.remoteSpyGuiConnections, con)
        end
        return con
    end

    local function repeatCall(call, remote, spyFunc, repeatCount)
        local callerIndex = spyFunc.Type == "Call" and callCheckCaller or otherCheckCaller

        callerIndex[remote] = {nil, true}
        if spyFunc.Type == "Call" then
            if call.NilCount == 0 then
                local func = spyFunc.Function
                
                local success, result = pcall(function()
                    if spyFunc.ReturnsValue then
                        for _ = 1,repeatCount do
                            spawnFunc(func, remote, unpack(call.Args))
                        end
                    else
                        for _ = 1,repeatCount do
                            func(remote, unpack(call.Args))
                        end
                    end
                end)
                if not success then
                    callerIndex[remote] = nil
                    pushError("Failed to Repeat Call: " .. tostring(result))
                end
            else
                local success, result = pcall(function()
                    local call = loadstring(genSendPseudo(remote, call, spyFunc))
                    if spyFunc.ReturnsValue then
                        for _ = 1,repeatCount do
                            spawnFunc(call)
                        end
                    else
                        for _= 1,repeatCount do
                            call()
                        end
                    end
                end)
                if not success then
                    callerIndex[remote] = nil
                    pushError("Failed to Repeat Call (Variant 2): " .. tostring(result))
                end
            end
        elseif spyFunc.Type == "Callback" then
            local success, result = pcall(function()
                for _ = 1,repeatCount do
                    spawnFunc(call.CallbackLog.CurrentFunction, unpack(call.Args))
                end
            end)
            if not success then
                callerIndex[remote] = nil
                pushError("Failed to Repeat Callback Call")
            end
        elseif spyFunc.Type == "Connection" then
            local success, result = pcall(function()
                for _ = 1,repeatCount do
                    cfiresignal(call.Signal, unpack(call.Args))
                end
            end)
            if not success then
                callerIndex[remote] = nil
                pushError("Failed to Repeat Connection")
            end
        end
    end

    local function createRepeatCallButton(window, call, remote, spyFunc, amt) -- NEEDS TO BE REDONE FOR CONS AND CALLBACKS
        local button = window:Selectable()
        button.Label = amt and ("Repeat Call x" .. tostring(amt)) or "Repeat Call"
        button.Visible = true

        amt = amt or 1

        local con = button.OnUpdated:Connect(function() repeatCall(call, remote, spyFunc, amt) end)
        tableInsert(_G.remoteSpyGuiConnections, con)
        return con
    end

    local function createGenSendPCButton(window, call, remote, spyFunc)
        local button = window:Selectable()
        button.Label = "Generate Calling Pseudocode"
        local con = button.OnUpdated:Connect(function()
            if not pcall(function()
                if Settings.SendPseudocodeToExternal then
                    createuitab("RS Pseudocode", genSendPseudo(remote, call, spyFunc, Settings.PseudocodeWatermark == 2))
                    pushSuccess("Generated Pseudocode to External UI")
                else
                    setclipboard(genSendPseudo(remote, call, spyFunc, Settings.PseudocodeWatermark == 3)) -- no pseudocode watermark when setting to clipboard
                    pushSuccess("Generated Pseudocode to Clipboard")
                end
            end) then
                pushError("Failed to Generate Pseudocode")
            end
        end)
        tableInsert(_G.remoteSpyGuiConnections, con)
        return con
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
        local con 
        if spyFunc.Type ~= "Call" then
            con = button.OnUpdated:Connect(function()
                if not pcall(function()
                    if Settings.SendPseudocodeToExternal then
                        createuitab("RS Pseudocode", genRecvPseudo(remote, call, spyFunc, Settings.PseudocodeWatermark == 2))
                        pushSuccess("Generated Pseudocode to External UI")
                    else
                        setclipboard(genRecvPseudo(remote, call, spyFunc, Settings.PseudocodeWatermark == 3)) -- no pseudocode watermark when setting to clipboard
                        pushSuccess("Generated Pseudocode to Clipboard")
                    end
                end) then
                    pushError("Failed to Generate Pseudocode")
                end
            end)
            tableInsert(_G.remoteSpyGuiConnections, con)
        end
        return con
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
        local con
        if spyFunc.Type == "Connection" then
            con = button.OnUpdated:Connect(function()
                if not pcall(function()
                    local str = "WARNING, THESE VALUES MAY HAVE BEEN TAMPERED WITH\n\n"
                    for i,v in call.Scripts do
                        str ..=  "[x" .. tostring(v) .. "]: " .. getInstancePath(i) .. "\n"
                    end
                    if Settings.ListConnectionScriptsToExternal then
                        createuitab("Connection Scripts", str)
                        pushSuccess("Listed Connections' Creator-Scripts in External UI")
                    else
                        setclipboard(str)
                        pushSuccess("Set Connections' Creator-Scripts List to Clipboard")
                    end
                end) then
                    pushError("Failed to Get Connection Scripts")
                end
            end)
            tableInsert(_G.remoteSpyGuiConnections, con)
        end
        return con
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
        local con = nil
        if spyFunc.ReturnsValue then
            con = button.OnUpdated:Connect(function()
                if not pcall(function()
                    local ret = call.ReturnValue
                    if ret.Args then
                        if Settings.SendPseudocodeToExternal then
                            createuitab("RS Return Value", genReturnValuePseudo(ret, spyFunc, Settings.PseudocodeWatermark == 2))
                            pushSuccess("Generated Return Value to External UI")
                        else
                            setclipboard(genReturnValuePseudo(ret, spyFunc, Settings.PseudocodeWatermark == 3)) -- no pseudocode watermark when setting to clipboard
                            pushSuccess("Generated Return Value to Clipboard")
                        end
                    else
                        pushError("Failed to Get Return Value")
                    end
                end) then
                    pushError("Failed to Get Return Value")
                end
            end)
            tableInsert(_G.remoteSpyGuiConnections, con)
        end
        return con
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
        local con = nil
        if spyFunc.Type == "Callback" and not call.FromSynapse then
            con = button.OnUpdated:Connect(function()
                local str = call.CallbackScript and getInstancePath(call.CallbackScript) -- not sure if getcallingscript can return a ModuleScript, I assume it can't, but adding this just in case
                if type(str) == "string" then
                    setclipboard(str)
                    pushSuccess("Set Callback Script to Clipboard")
                else
                    pushError("Failed to get Callback Script")
                end
            end)
            tableInsert(_G.remoteSpyGuiConnections, con)
        end
        return con
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
        local con = nil
        if spyFunc.Type == "Callback" and not call.FromSynapse then
            local con = button.OnUpdated:Connect(function()
                if not pcall(function()
                    local str = decompile(call.CallbackScript)
                    local scriptName = call.CallbackScript and getInstancePath(call.CallbackScript)
                    if type(str) == "string" then
                        if Settings.DecompileScriptsToExternal then
                            createuitab(scriptName or "Script Not Found", str)
                            pushSuccess("Decompiled Callback Script to External UI")
                        else
                            setclipboard(str)
                            pushSuccess("Decompiled Callback Script to Clipboard")
                        end
                    else
                        pushError("Failed to Decompile Callback Script2")
                    end
                end) then
                    pushError("Failed to Decompile Callback Script")
                end
            end)
            tableInsert(_G.remoteSpyGuiConnections, con)
        end
        return con
    end

    local function makeRemoteViewerLog(call, remote)
        local totalArgCount = #call.Args + call.NilCount
        local spyFunc = spyFunctions[call.TypeIndex]
        local tempMain = remoteViewerMainWindow:Dummy()
        local tempMain2 = tempMain:SameLine()
        local dummyMain = tempMain2:Dummy()
        local dummyMain2 = tempMain2:Dummy()
        dummyMain:SetColor(RenderColorOption.ChildBg, colorRGB(25, 25, 28), 1)
        dummyMain2:SetColor(RenderColorOption.ChildBg, black, 0)
        
        local childWindow = dummyMain:Indent(8):Child()
        local secondChild = dummyMain2:Indent(8):Child()
        secondChild:SetColor(RenderColorOption.Button, black, 0)
        secondChild:SetColor(RenderColorOption.ButtonActive, white, 0)
        secondChild:SetColor(RenderColorOption.ButtonHovered, white, 0)

        if totalArgCount < 2 then
            childWindow.Size = Vector2.new(width-46, 24 + 16) -- 2 lines (top line = 24) + 2x (8px) spacers  | -46 because 16 padding on each side, plus 14 wide scrollbar
        elseif totalArgCount <= 10 then
            childWindow.Size = Vector2.new(width-46, (totalArgCount * 28) - 4 + 16) -- 24px per line, 4px spacer, 16px header and footer  | -46 because 16 padding on each side, plus 14 wide scrollbar
        else -- 28 pixels per line (24 for arg, 4 for spacer), but -4 because no spacer at end, then +24 because button line, and +24 for top, bottom, and middle spacer
            childWindow.Size = Vector2.new(width-46, (10 * 28) - 4 + 16)
        end

        local mainButton = secondChild:Button()
        local pop = mainWindow:Popup()

        createGetRetValButton(pop, call, spyFunc)
        if Settings.CallbackButtons then
            createGetConnectionScriptsButton(pop, call, spyFunc)
            createCBButton(pop, call, spyFunc)
            createCBDecompileButton(pop, call, spyFunc)
        end

        pop:Separator()
        createCSButton(pop, call, spyFunc)
        createCSDecompileButton(pop, call, spyFunc)
        if Settings.CallbackButtons then
            createGenRecvPCButton(pop, call, remote, spyFunc)
        end
        createGenSendPCButton(pop, call, remote, spyFunc)
        if Settings.MoreRepeatCallOptions then
            pop:Separator()
            for _,v in repeatCallSteps do
                createRepeatCallButton(pop, call, remote, spyFunc, v)
            end
        else
            createRepeatCallButton(pop, call, remote, spyFunc)
        end

        local con = mainButton.OnUpdated:Connect(function()
            pop:Show()
        end)
        mainButton.Size = Vector2.new(childWindow.Size.X - 18, childWindow.Size.Y)
        secondChild.Size = Vector2.new(childWindow.Size.X - 18, childWindow.Size.Y)

        local textFrame = childWindow:Dummy()

        addSpacer(textFrame, 8)

        local indentFrame = textFrame:Indent(4):SameLine()
        
        local temp = indentFrame:Dummy()
        temp:SetColor(RenderColorOption.Button, black, 0)
        temp:SetColor(RenderColorOption.ButtonActive, black, 0)
        temp:SetColor(RenderColorOption.ButtonHovered, black, 0)
        
        if call.FromSynapse then
            temp:SetColor(RenderColorOption.Text, colorRGB(252, 86, 3), 1)
        else
            temp:SetColor(RenderColorOption.Text, colorRGB(51, 136, 255), 1)
        end

        local fakeBtn = temp:Button()
        fakeBtn.Label = "\xef\x87\x89"

        local firstArgFrame = indentFrame:Indent(27)

        if totalArgCount == 0 or totalArgCount == 1 then
            local argFrame = firstArgFrame:SameLine()

            local temp2 = argFrame:SameLine()
            temp2:SetColor(RenderColorOption.ButtonActive, colorOptions.FrameBg[1], 1)
            temp2:SetColor(RenderColorOption.ButtonHovered, colorOptions.FrameBg[1], 1)
            temp2:SetColor(RenderColorOption.Button, colorOptions.FrameBg[1], 1)
            temp2:SetStyle(RenderStyleOption.ButtonTextAlign, Vector2.new(0, 0.5))

            local lineContents = temp2:Button()
            if totalArgCount == 0 then
                argFrame:SetColor(RenderColorOption.Text, colorRGB(156, 0, 0), 1)
                lineContents.Label = spaces2 .. "nil"
            elseif #call.Args == 1 then
                local text, color = getArgString(call.Args[1], call.Type)
                lineContents.Label = spaces2 .. text
                argFrame:SetColor(RenderColorOption.Text, color, 1)
            else
                lineContents.Label = spaces2 .. "HIDDEN NIL"
                argFrame:SetColor(RenderColorOption.Text, colorHSV(258/360, 0.8, 1), 1)
            end
            lineContents.Size = Vector2.new(width-24-38-23, 24) -- 24 = left padding, 38 = right padding, and no scrollbar

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
            for i = 1, #call.Args do
                local x = call.Args[i]

                local firstLine = (i == 1)
                local argFrame = (firstLine and firstArgFrame:SameLine()) or childWindow:SameLine()

                local temp2 = argFrame:SameLine()
                temp2:SetColor(RenderColorOption.ButtonActive, colorOptions.FrameBg[1], 1)
                temp2:SetColor(RenderColorOption.ButtonHovered, colorOptions.FrameBg[1], 1)
                temp2:SetColor(RenderColorOption.Button, colorOptions.FrameBg[1], 1)
                temp2:SetStyle(RenderStyleOption.ButtonTextAlign, Vector2.new(0, 0.5))
                
                local lineContents = firstLine and temp2:Button() or temp2:Indent(8):Button()
                local text, color
                text, color = getArgString(x, call.Type)
                lineContents.Label = spaces2 .. text
                argFrame:SetColor(RenderColorOption.Text, color, 1)
                if totalArgCount < 10 then
                    lineContents.Size = firstLine and Vector2.new(width-24-38-23, 24) or Vector2.new(width-24-38, 24) -- 24 = left padding + indent, 38 = right padding (no scrollbar) 
                else
                    lineContents.Size = firstLine and Vector2.new(width-24-38-14-23, 24) or Vector2.new(width-24-38-14, 24) -- 14 = scrollbar width, plus read above
                end

                local temp = argFrame:SameLine()
                argFrame:SetColor(RenderColorOption.ButtonActive, black, 0)
                argFrame:SetColor(RenderColorOption.ButtonHovered, black, 0)
                argFrame:SetColor(RenderColorOption.Button, black, 0)
                temp:SetStyle(RenderStyleOption.ButtonTextAlign, Vector2.new(1, 0.5))
                temp:SetColor(RenderColorOption.Text, colorHSV(179/360, 0.8, 1), 1)

                local lineNum = firstLine and temp:Indent(-7):Button() or temp:Indent(1):Button()
                lineNum.Label = tostring(i)
                lineNum.Size = Vector2.new(32, 24)

                addSpacer(childWindow, 4)
            end
            for i = 1, call.NilCount do
                local argFrame = ((i ~= 1 or #call.Args > 0) and childWindow:SameLine()) or firstArgFrame:SameLine()

                local temp2 = argFrame:SameLine()
                temp2:SetColor(RenderColorOption.ButtonActive, colorOptions.FrameBg[1], 1)
                temp2:SetColor(RenderColorOption.ButtonHovered, colorOptions.FrameBg[1], 1)
                temp2:SetColor(RenderColorOption.Button, colorOptions.FrameBg[1], 1)
                temp2:SetStyle(RenderStyleOption.ButtonTextAlign, Vector2.new(0, 0.5))

                local lineContents = temp2:Indent(8):Button()
                lineContents.Label = spaces2 .. "HIDDEN NIL"
                argFrame:SetColor(RenderColorOption.Text, colorHSV(258/360, 0.8, 1), 1)
                if totalArgCount < 10 then
                    lineContents.Size = Vector2.new(width-24-38, 24) -- 24 = left padding + indent, 38 = right padding (no scrollbar) 
                else
                    lineContents.Size = Vector2.new(width-24-38-14, 24) -- 14 = scrollbar width, plus read above
                end

                local temp = argFrame:SameLine()
                argFrame:SetColor(RenderColorOption.ButtonActive, black, 0)
                argFrame:SetColor(RenderColorOption.ButtonHovered, black, 0)
                argFrame:SetColor(RenderColorOption.Button, black, 0)
                temp:SetStyle(RenderStyleOption.ButtonTextAlign, Vector2.new(1, 0.5))
                temp:SetColor(RenderColorOption.Text, colorHSV(179/360, 0.8, 1), 1)

                local lineNum = temp:Indent(1):Button()
                lineNum.Label = tostring(i + #call.Args)
                lineNum.Size = Vector2.new(32, 24)

                addSpacer(childWindow, 4)
            end
        end

        addSpacer(tempMain, 4)
        tableInsert(argLines, { tempMain, pop })
    end

    local function loadRemote(remote, data)
        local funcInfo = spyFunctions[data.TypeIndex]
        local logs = funcInfo.Type == "Call" and callLogs or otherLogs
        frontPage.Visible = false
        remotePage.Visible = true
        currentSelectedRemote = remote
        currentSelectedType = funcInfo.Type
        remotePageObjects.Name.Label = remote and purifyString(remote.Name) or "NIL REMOTE"
        remotePageObjects.Icon.Label = funcInfo.Icon
        remotePageObjects.IconFrame:SetColor(RenderColorOption.Text, funcInfo.Color, 1)
        remotePageObjects.IgnoreButton.Label = (logs[remote].Ignored and "Unignore") or "Ignore"
        remotePageObjects.IgnoreButtonFrame:SetColor(RenderColorOption.Text, (logs[remote].Ignored and green) or red, 1)
        remotePageObjects.BlockButton.Label = (logs[remote].Blocked and "Unblock") or "Block"
        remotePageObjects.BlockButtonFrame:SetColor(RenderColorOption.Text, (logs[remote].Blocked and green) or red, 1)

        addSpacer(remoteViewerMainWindow, 8)

        for _,v in logs[remote].Calls do
            makeRemoteViewerLog(v, remote)
        end
    end

    -- Below this is rendering Front Page
    local topBar = frontPage:SameLine()
    local frameWidth = width-130
    local searchBarFrame = topBar:Indent(-0.35*frameWidth):Child()
    searchBarFrame.Size = Vector2.new(frameWidth, 24)
    searchBarFrame:SetColor(RenderColorOption.ChildBg, black, 0)
    searchBar = searchBarFrame:Indent(0.35*frameWidth):TextBox() -- localized earlier
    tableInsert(_G.remoteSpyGuiConnections, searchBar.OnUpdated:Connect(filterLines))
    
    local searchButton = topBar:Button()
    searchButton.Label = "Search"
    tableInsert(_G.remoteSpyGuiConnections, searchButton.OnUpdated:Connect(function()
        filterLines(searchBar.Value) -- redundant because i did it above but /shrug
    end))

    local clearButton = topBar:Button()
    clearButton.Label = "Reset"
    tableInsert(_G.remoteSpyGuiConnections, clearButton.OnUpdated:Connect(function()
        searchBar.Value = ""
        clearFilter()
    end))

    local childWindow

    local clearAllLogsButton = topBar:Button()
    clearAllLogsButton.Label = "Clear All Logs"
    tableInsert(_G.remoteSpyGuiConnections, clearAllLogsButton.OnUpdated:Connect(function()
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
    end))

    local topRightBar = topBar:Indent(width-64):SameLine() -- -8 for right padding, -8 for previous left indent, -4 for middle padding, -24 per button
    topRightBar:SetColor(RenderColorOption.Button, black, 0)
    topRightBar:SetColor(RenderColorOption.ButtonHovered, black, 0)
    topRightBar:SetColor(RenderColorOption.ButtonActive, black, 0)
    topRightBar:SetStyle(RenderStyleOption.ButtonTextAlign, Vector2.new(0.5, 0.5))
    topRightBar:SetStyle(RenderStyleOption.ItemSpacing, Vector2.new(0, 0))

    local settingsButton = topRightBar:Button()
    settingsButton.Label = "\xef\x80\x93"
    settingsButton.Size = Vector2.new(24, 24)
    tableInsert(_G.remoteSpyGuiConnections, settingsButton.OnUpdated:Connect(function()
        settingsWindow.Visible = not settingsWindow.Visible
    end))

    local exitButton = topRightBar:Button()
    exitButton.Label = "\xef\x80\x91"
    exitButton.Size = Vector2.new(24, 24)
    tableInsert(_G.remoteSpyGuiConnections, exitButton.OnUpdated:Connect(function()
        if messagebox("Are you sure you want to Close/Disconnect the RemoteSpy?  You can reexecute later.", "Warning", 4) == 6 then
            cleanUpSpy()
        end
    end))
    
    addSpacer(frontPage, 4)

    local sameLine = frontPage:SameLine()

    local splitAmt = (math.floor(#spyFunctions/2)+1)
    for i,v in spyFunctions do
        
        if i == splitAmt then
            sameLine = frontPage:SameLine()
            sameLine.Visible = Settings.CallbackButtons
            callbackButtonline = sameLine
        end
        
        local tempLine = v.Indent == 0 and sameLine:Dummy() or sameLine:Indent(v.Indent):Dummy()
        tempLine:SetColor(RenderColorOption.Text, v.Color, 1)
        
        local btn = tempLine:CheckBox()
        btn.Label = v.Icon
        btn.Value = v.Enabled
        v.Button = btn
        tableInsert(_G.remoteSpyGuiConnections, btn.OnUpdated:Connect(function(enabled)
            v.Enabled = enabled
            Settings[v.Name] = enabled
            updateLines(v.Name, enabled)

            saveConfig()
        end))

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

        local con = copyPathButton.OnUpdated:Connect(function()
            local str = getInstancePath(remote)
            if type(str) == "string" then
                setclipboard(str)
                pushSuccess("Copied Path to Clipboard")
            else
                pushError("Failed to Copy Path")
            end
        end)
        tableInsert(_G.remoteSpyGuiConnections, con)
        return con
    end

    local function makeClearLogsButton(sameLine, remote, method)
        local clearLogsButton = sameLine:Button()
        clearLogsButton.Label = "Clear Logs"

        local lines = (method == "Call") and callLines or otherLines
        local logs = (method == "Call") and callLogs or otherLogs

        local con = clearLogsButton.OnUpdated:Connect(function()
            tableClear(logs[remote].Calls)
            lines[remote][3].Label = "0"
            if not logs[remote].Ignored then
                lines[remote][2].Visible = false
                lines[remote][4].Visible = false
            end
        end)
        tableInsert(_G.remoteSpyGuiConnections, con)
        return con
    end

    local function makeIgnoreButton(sameLine, remote, method)
        local spoofLine = sameLine:SameLine()
        spoofLine:SetColor(RenderColorOption.Text, red, 1)
        local ignoreButton = spoofLine:Button()
        ignoreButton.Label = "Ignore"

        local logs = (method == "Call") and callLogs or otherLogs
        local funcList = (method == "Call") and callFuncs or otherFuncs

        funcList[remote].UpdateIgnores = function()
            if logs[remote].Ignored then
                ignoreButton.Label = "Unignore"
                spoofLine:SetColor(RenderColorOption.Text, green, 1)
            else
                ignoreButton.Label = "Ignore"
                spoofLine:SetColor(RenderColorOption.Text, red, 1)
            end
        end

        local con = ignoreButton.OnUpdated:Connect(function()
            if logs[remote].Ignored then
                logs[remote].Ignored = false
                ignoreButton.Label = "Ignore"
                spoofLine:SetColor(RenderColorOption.Text, red, 1)
            else
                logs[remote].Ignored = true
                ignoreButton.Label = "Unignore"
                spoofLine:SetColor(RenderColorOption.Text, green, 1)
            end
        end)
        tableInsert(_G.remoteSpyGuiConnections, con)
        return con
    end

    local function makeBlockButton(sameLine, remote, method)
        local spoofLine = sameLine:SameLine()
        spoofLine:SetColor(RenderColorOption.Text, red, 1)
        local blockButton = spoofLine:Button()
        blockButton.Label = "Block"

        local logs = (method == "Call") and callLogs or otherLogs
        local funcList = (method == "Call") and callFuncs or otherFuncs

        funcList[remote].UpdateBlocks = function()
            if logs[remote].Blocked then
                spoofLine:SetColor(RenderColorOption.Text, green, 1)
                blockButton.Label = "Unblock"
            else
                spoofLine:SetColor(RenderColorOption.Text, red, 1)
                blockButton.Label = "Block"
            end
        end

        local con = blockButton.OnUpdated:Connect(function()
            if logs[remote].Blocked then
                logs[remote].Blocked = false
                spoofLine:SetColor(RenderColorOption.Text, red, 1)
                blockButton.Label = "Block"
            else
                logs[remote].Blocked = true
                spoofLine:SetColor(RenderColorOption.Text, green, 1)
                blockButton.Label = "Unblock"
            end
        end)
        tableInsert(_G.remoteSpyGuiConnections, con)
        return con
    end

    local function renderNewLog(remote, data)
        local spyFunc = spyFunctions[data.TypeIndex]
        local method = spyFunc.Type
        local lines, log, funcList
        if method == "Call" then
            lines = callLines
            log = callLogs[remote]
            funcList = callFuncs
        else
            lines = otherLines
            log = otherLogs[remote]
            funcList = otherFuncs
        end
        funcList[remote] = {}

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
        remoteButton.Label = spaces .. (remote and purifyString(remote.Name, false) or "NIL REMOTE")
        remoteButton.Size = Vector2.new(width-327-4-14, 24)
        local con = remoteButton.OnUpdated:Connect(function()
            loadRemote(remote, data)
        end)
        tableInsert(_G.remoteSpyGuiConnections, con)
        line[5] = { con }

        addSpacer(sameButtonLine, 3)

        local cloneLine = sameButtonLine:SameLine():Indent(6)
        cloneLine:SetColor(RenderColorOption.Text, spyFunc.Color, 1)
        
        cloneLine:Label(spyFunc.Icon)
        
        local cloneLine2 = sameButtonLine:SameLine()
        cloneLine2:SetColor(RenderColorOption.Text, colorHSV(179/360, 0.8, 1), 1)

        local callAmt = #log.Calls
        local callStr = (callAmt < 1000 and tostring(callAmt)) or "999+"
        line[3] = cloneLine2:Indent(27):Label(callStr)

        local ind = sameButtonLine:Indent(width-333)
        
        tableInsert(line[5], makeCopyPathButton(ind, remote))
        tableInsert(line[5], makeClearLogsButton(sameButtonLine, remote, method))
        tableInsert(line[5], makeIgnoreButton(sameButtonLine, remote, method))
        tableInsert(line[5], makeBlockButton(sameButtonLine, remote, method))

        line[4] = addSpacer(childWindow, 4)
        line[4].Visible = spyFunc.Enabled

        lines[remote] = line
        filterLines(searchBar.Value)
    end

    local function sendLog(remote, data)
        local spyFunc = spyFunctions[data.TypeIndex]
        local method = spyFunc.Type
        local check = (currentSelectedRemote == remote and currentSelectedType == method) and true
        
        local line, log
        if method == "Call" then
            line = callLines[remote]
            log = callLogs[remote]
        else
            line = otherLines[remote]
            log = otherLogs[remote]
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
            renderNewLog(remote, data)
        end

        if check then
            makeRemoteViewerLog(data, remote)
        end
    end

    local function processReturnValue(refTable, ...)
        local args = shallowClone({...}, nil, -1)
        if args then
            refTable.Args = args
            refTable.NilCount = (select("#", args) - #args)
        else
            refTable.Args = false
            pushError("Return Value Shallow Clone Returned False")
        end

        return ...
    end

    local function addCall(remote, returnValue, spyFunc, ...)
        if not callLogs[remote] then
            callLogs[remote] = {
                Blocked = false,
                Ignored = false,
                Calls = {}
            }
        end

        if not callLogs[remote].Ignored and (Settings.LogHiddenRemotesCalls or spyFunc.Enabled) then

            local args, tableDepth, hasTable = shallowClone({...}, nil, -1) -- 1 deeper total
            local argCount = select("#", ...)

            if not args or (hasTable and argCount > 7995 or argCount > 7996) or (tableDepth > 0 and ((argCount + tableDepth) > 298)) then
                return
            end

            local caller = checkcaller()
            local callingScript = callCheckCaller[remote] or {(not caller and getcallingscript()), caller}

            callCheckCaller[remote] = nil

            local data = {
                TypeIndex = idxs[spyFunc.Name],
                Script = callingScript[1],
                Args = args, -- 2 deeper total
                ReturnValue = returnValue,
                NilCount = (argCount - #args),
                FromSynapse = callingScript[2]
            }
            
            sendLog(remote, data)
        end
    end

    local function addCallback(remote, method, func)
        if not otherLogs[remote] then
            otherLogs[remote] = {
                Type = "Callback",
                CurrentFunction = func,
                Ignored = false,
                Blocked = false,
                Calls = {}
            }
        elseif otherLogs[remote].CurrentFunction then
            local curFunc = otherLogs[remote].CurrentFunction
            for i,v in _G.remoteSpyCallbackHooks do
                if v == curFunc then
                    tableRemove(_G.remoteSpyCallbackHooks, i)
                    break
                end
            end
            restorefunction(curFunc)
            otherLogs[remote].CurrentFunction = func
        end

        if func then
            local oldfunc
            oldfunc = hookfunction(func, function(...)
                local spyFunc = spyFunctions[idxs[method]]
                local args = shallowClone({...}, nil, -1)
                local argCount = select("#", ...)

                local callingScript = otherCheckCaller[remote] or {nil, checkcaller()}

                otherCheckCaller[remote] = nil

                local data = {
                    TypeIndex = idxs[method],
                    CallbackScript = getcallingscript(),
                    Script = callingScript[1],
                    Args = args, -- 2 deeper total
                    CallbackLog = otherLogs[remote],
                    NilCount = (argCount - #args),
                    FromSynapse = callingScript[2]
                }

                if spyFunc.ReturnsValue and not otherLogs[remote].Blocked then 
                    local returnValue = {}
                    deferFunc(function()
                        if not otherLogs[remote].Ignored and (Settings.LogHiddenRemotesCalls or spyFunc.Enabled) then
                            data.ReturnValue = returnValue

                            sendLog(remote, data)
                        end
                    end)

                    return processReturnValue(returnValue, oldfunc(...))
                end
            
                if otherLogs[remote] and otherLogs[remote].Blocked then return end

                deferFunc(function(...)
                    if not otherLogs[remote].Ignored and (Settings.LogHiddenRemotesCalls or spyFunc.Enabled) then
                        sendLog(remote, data)
                    end
                end, ...)

                return oldfunc(...)
            end)
            tableInsert(_G.remoteSpyCallbackHooks, func)
        end
    end

    local function addConnection(remote, signalType, signal)
        if not otherLogs[remote] then
            otherLogs[remote] = {
                Type = "Connection",
                Ignored = false,
                Blocked = false,
                Calls = {}
            }
            
            local scriptCache = {}
            local connectionCache = {} -- unused (for now)
            hooksignal(signal, function(info, ...)
                deferFunc(function(...)
                    local spyFunc = spyFunctions[idxs[signalType]]
                    if not otherLogs[remote].Ignored and (Settings.LogHiddenRemotesCalls or spyFunc.Enabled) then
                        if info.Index == 0 then
                            tableClear(connectionCache)
                            tableClear(scriptCache)
                        end

                        tableInsert(connectionCache, info.Connection)
                        local CS = getcallingscript()
                        if CS then
                            if scriptCache[CS] then
                                scriptCache[CS] += 1
                            else
                                scriptCache[CS] = 1
                            end
                        end

                        local callingScript = otherCheckCaller[remote] or {nil, false}

                        otherCheckCaller[remote] = nil
                        
                        if info.Index == (#getconnections(signal)-1) then -- -1 because base 0 for info.Index
                            local args = shallowClone({...}, nil, -1)
                            local argCount = select("#", ...)
                            local data = {
                                TypeIndex = idxs[signalType],
                                Script = callingScript[1],
                                Scripts = scriptCache,
                                Connections = connectionCache,
                                Signal = signal,
                                Args = args, -- 2 deeper total
                                NilCount = (argCount - #args),
                                FromSynapse = callingScript[2]
                            }

                            sendLog(remote, data)
                        end
                    end
                end, ...)

                if otherLogs[remote].Blocked then 
                    return false
                end

                return true, ...
            end)
            tableInsert(_G.remoteSpySignalHooks, signal)
        end
    end

    local namecallFilters = {}
    local newIndexFilters = {}
    local indexFilters = {}

    do -- filter setup

        for _,v in spyFunctions do
            if v.Type == "Callback" then
                tableInsert(newIndexFilters, AllFilter.new({
                    AnyFilter.new({
                        InstanceTypeFilter.new(1, v.Object),
                        ArgumentFilter.new(1, nil)
                    }),
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

    local function newHookMetamethod(toHook, mtmethod, hookFunction, filter)
        local oldFunction

        local func = getfilter(filter, function(...) 
            return oldFunction(...)
        end, hookFunction)

        oldFunction = hookmetamethod(toHook, mtmethod, func)
        return oldFunction
    end

    local oldNewIndex -- this is for OnClientInvoke hooks
    oldNewIndex = newHookMetamethod(game, "__newindex", function(remote, idx, newidx)
        addCallback(remote, idx, newidx)

        return oldNewIndex(remote, idx, newidx)
    end, AnyFilter.new(newIndexFilters))

    local oldIndex -- this is for signal indexing
    oldIndex = newHookMetamethod(game, "__index", function(remote, idx)
        local newSignal = oldIndex(remote, idx)
        addConnection(remote, idx, newSignal)

        return newSignal
    end, AnyFilter.new(indexFilters))

    local initInfo = {
        RemoteFunction = { "Callback", "OnClientInvoke" },
        BindableFunction = { "Callback", "OnInvoke" },
        RemoteEvent = { "Connection", "OnClientEvent" },
        BindableEvent = { "Connection", "Event" }
    }

    do -- init OnClientInvoke and signal index
        for _,v in getnilinstances() do
            local data = initInfo[v.ClassName]
            if data then
                if data[1] == "Connection" then
                    addConnection(v, data[2], v[data[2]])
                elseif data[1] == "Callback" then
                    local func = getcallbackmember(v, data[2])
                    if func then
                        addCallback(v, data[2], func)
                    end
                end
            end
            for _,x in v:GetDescendants() do
                local data = initInfo[x.ClassName]
                if data then
                    if data[1] == "Connection" then
                        addConnection(x, data[2], x[data[2]])
                    elseif data[1] == "Callback" then
                        local func = getcallbackmember(x, data[2])
                        if func then
                            addCallback(x, data[2], func)
                        end
                    end
                end
            end
        end

        for _,v in game:GetDescendants() do
            local data = initInfo[v.ClassName]
            if data then
                if data[1] == "Connection" then
                    addConnection(v, data[2], v[data[2]])
                elseif data[1] == "Callback" then
                    local func = getcallbackmember(v, data[2])
                    if func then
                        addCallback(v, data[2], func)
                    end
                end
            end
        end
    end
    do -- namecall and function hooks
        local oldNamecall
        oldNamecall = newHookMetamethod(game, "__namecall", newcclosure(function(remote, ...)
            local spyFunc = spyFunctions[idxs[getnamecallmethod()]]

            if spyFunc.Type == "Call" and spyFunc.FiresLocally then
                local caller = checkcaller()
                otherCheckCaller[remote] = otherCheckCaller[remote] or {(not caller and getcallingscript()), caller}
            end
            -- it will either return true at checkcaller because called from synapse (non remspy), or have already been set by remspy

            if spyFunc.ReturnsValue and (not callLogs[remote] or not callLogs[remote].Blocked) then 
                local returnValue = {}
                deferFunc(function(...)
                    --repeat taskWait() until returnValue.Args

                    addCall(remote, returnValue, spyFunc, ...)
                end, ...) -- I could rewrite the entire system to not need a second thread, but the issue is that then I would need to encorporate all data collection into that function, and essentially make the entire function run on what is currently a new thread, rather than having a new thread running separately from the entire function.
                return processReturnValue(returnValue, oldNamecall(remote, ...))
            end

            deferFunc(addCall, remote, nil, spyFunc, ...)
            --addCall(remote, nil, spyFunc, ...)
        
            if callLogs[remote] and callLogs[remote].Blocked then return end

            return oldNamecall(remote, ...)
        end), AnyFilter.new(namecallFilters))

        for _,v in spyFunctions do
            if v.Type == "Call" then

                local oldFunc
                local newfunction = function(remote, ...)
                    local spyFunc = v
                    if spyFunc.Type == "Call" and spyFunc.FiresLocally then
                        local caller = checkcaller()
                        otherCheckCaller[remote] = otherCheckCaller[remote] or {(not caller and getcallingscript()), caller}
                    end

                    if spyFunc.ReturnsValue and (not callLogs[remote] or not callLogs[remote].Blocked) then 
                        local returnValue = {}
                        deferFunc(function(...)
                            
                            addCall(remote, returnValue, spyFunc, ...)
                        end, ...)
                        return processReturnValue(returnValue, oldNamecall(remote, ...))
                    end

                    deferFunc(addCall, remote, nil, spyFunc, ...)
                    --addCall(remote, nil, spyFunc, ...)
                
                    if callLogs[remote] and callLogs[remote].Blocked then return end

                    return oldFunc(remote, ...)
                end

                oldFunc = hookfunction(Instance.new(v.Object)[v.Method], newcclosure(newfunction), InstanceTypeFilter.new(1, v.Object))

                v.Function = newfunction
            end
        end
    end
else
    cleanUpSpy()
end

-- CREDIT TO https://github.com/Upbolt/Hydroxide/ FOR INSPIRATION AND A FEW FORKED TOSTRING FUNCTIONS
