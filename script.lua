-- CREDIT TO https://github.com/Upbolt/Hydroxide/ FOR INSPIRATION AND A FEW COPIED TOSTRING FUNCTIONS

if not RenderWindow then
    error("EXPLOIT NOT SUPPORTED - GET SYNAPSE V3")
end

if not _G.remoteSpyMainWindow and not _G.remoteSpySettingsWindow then

    local HttpService = game:GetService("HttpService")

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

        SendPseudocodeToExternal = false,
        DecompileCallingScriptToExternal = false,
        PseudocodeWatermark = 2,
        LogHiddenRemotesCalls = false,
        CacheLimit = true,
        MaxCallAmount = 1000
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

    local red = Color3.fromRGB(255, 0, 0)
    local green = Color3.fromRGB(0, 255, 0)
    local white = Color3.fromRGB(255, 255, 255)
    local black = Color3.fromRGB()

    local styleOptions = {
        WindowRounding = 5,
        WindowTitleAlign = Vector2.new(0.5, 0.5),
        WindowBorderSize = 1,
        FrameRounding = 3,
        ButtonTextAlign = Vector2.new(0, 0.5),
    }

    local colorOptions = {
        Border = {black, 1},
        TitleBgActive = {Color3.fromRGB(35, 35, 38), 1},
        TitleBg = {Color3.fromRGB(35, 35, 38), 1},
        TitleBgCollapsed = {Color3.fromRGB(35, 35, 38), 0.8},
        WindowBg = {Color3.fromRGB(50, 50, 53), 1},
        Button = {Color3.fromRGB(75, 75, 78), 1},
        ButtonHovered = {Color3.fromRGB(85, 85, 88), 1},
        ButtonActive = {Color3.fromRGB(115, 115, 118), 1},
        Text = {white, 1},
        ResizeGrip = {black, 0},
        ResizeGripActive = {Color3.fromRGB(115, 115, 118), 1},
        ResizeGripHovered = {Color3.fromRGB(85, 85, 88), 1},
        CheckMark = {white, 1},
        FrameBg = {Color3.fromRGB(20, 20, 23), 1},
        FrameBgHovered = {Color3.fromRGB(22, 22, 25), 1},
        FrameBgActive = {Color3.fromRGB(30, 30, 35), 1},
        Tab = {Color3.fromRGB(33, 36, 38), 1},
        TabActive = {Color3.fromRGB(20, 20, 23), 1},
        TabHovered = {Color3.fromRGB(119, 119, 119), 1},
        TabUnfocused = {Color3.fromRGB(60, 60, 60), 1},
        TabUnfocusedActive = {Color3.fromRGB(20, 20, 23), 1},
        HeaderHovered = {Color3.fromRGB(55, 55, 55), 1},
        HeaderActive = {Color3.fromRGB(75, 75, 75), 1},
    }

    local function pushError(message: string)
        syn.toast_notification({
            Type = ToastType.Error,
            Duration = 5,
            Title = "Remote Spy",
            Content = message
        })
    end

    local safeMt = getrawmetatable({})

    local function shallowClone(myTable: table, originalTable: table, stack: number) -- cyclic check built in
        stack = stack or 0 -- you can offset stack by setting the starting parameter to a number
        local newTable = {}

        if stack == 300 then -- this stack overflow check doesn't really matter, it's just to optimize the function.  The actual stack size check is later because it's based on the type of call, and how many args are passed.
            return false, stack
        end

        for i,v in next, myTable do
            if type(v) == "table" then
                if rawequal(v, originalTable) or rawequal(v, myTable) then
                    return false, stack
                end

                local newTab, maxStack = shallowClone(v, myTable, stack+1)
                stack = maxStack
                
                if newTab then
                    newTable[i] = newTab
                else
                    return false, stack -- stack overflow
                end
            else
                newTable[i] = v
            end
        end

        return newTable, stack
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

    local function purifyString(str: string, quotes: boolean)
        str = string.gsub(HttpService:UrlEncode(string.gsub(str, "\\", "\\\\")), "%%", "\\x")
        for i,v in asciiFilteredCharacters do
            str = string.gsub(str, v, i)
        end

        if quotes then
            return '"' .. str .. '"'
        else
            return str
        end
    end
    
    local function getInstancePath(instance) -- COPIED FROM HYDROXIDE
        local name = instance.Name
        local head = (#name > 0 and '.' .. name) or "['']"
        
        if not instance.Parent and instance ~= game then
            return head .. " --[[ PARENTED TO NIL OR DESTROYED ]]"
        end
        
        if instance == game then
            return "game"
        elseif instance == workspace then
            return "workspace"
        else
            local _success, result = pcall(game.GetService, game, instance.ClassName)
            
            if result then
                head = ':GetService("' .. instance.ClassName .. '")'
            elseif instance == client then
                head = '.LocalPlayer' 
            else
                local nonAlphaNum = string.gsub(name, '[%w_]', '')
                local noPunct = string.gsub(nonAlphaNum, '[%s%p]', '')
                
                if tonumber(string.sub(name, 1, 1)) or (#nonAlphaNum ~= 0 and #noPunct == 0) then
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

    local function userdataValue(data) -- COPIED FROM HYDROXIDE
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
            local split = string.split(tostring(data), '}, ')
            local vector = string.gsub(split[1], '{', "Vector3.new(")
            return dataType .. ".new(" .. vector .. "), " .. split[2] .. ')'
        elseif dataType == "Ray" or dataType == "Region3" then
            local split = string.split(tostring(data), '}, ')
            local vprimary = string.gsub(split[1], '{', "Vector3.new(")
            local vsecondary = string.gsub(string.gsub(split[2], '{', "Vector3.new("), '}', ')')
            return dataType .. ".new(" .. vprimary .. "), " .. vsecondary .. ')'
        elseif dataType == "ColorSequence" or dataType == "NumberSequence" then 
            return dataType .. ".new(" .. tableToString(nil, data.Keypoints) .. ')'
        elseif dataType == "ColorSequenceKeypoint" then
            return "ColorSequenceKeypoint.new(" .. data.Time .. ", Color3.new(" .. tostring(data.Value) .. "))"
        elseif dataType == "NumberSequenceKeypoint" then
            local envelope = data.Envelope and data.Value .. ", " .. data.Envelope or data.Value
            return "NumberSequenceKeypoint.new(" .. data.Time .. ", " .. envelope .. ")"
        end

        return tostring(data)
    end

    local function tableToString(call, data, root, indents) -- COPIED FROM HYDROXIDE
        local dataType = type(data)

        if dataType == "userdata" then
            return (typeof(data) == "Instance" and getInstancePath(data)) or userdataValue(data)
        elseif dataType == "string" then
            if #(string.gsub(string.gsub(string.gsub(data, '%w', ''), '%s', ''), '%p', '')) > 0 then
                local success, result = pcall(purifyString, data, false)
                return (success and result) or toString(data)
            else
                return ('"' .. string.gsub(data, '"', '\\"') .. '"')
            end
        elseif dataType == "table" then
            indents = indents or 1
            root = root or data

            local head = '{\n'
            local elements = 0
            local indent = string.rep('\t', indents)
            -- moved checkCyclic check to hook
            for i,v in data do
                elements += 1

                if type(i) == "number" and elements == i then -- table will either use all numbers, or mixed between non numbers
                    head ..= string.format("%s%s,\n", indent, tableToString(call, v, root, indents + 1))
                else
                    head ..= string.format("%s[%s] = %s,\n", indent, tableToString(call, i, root, indents + 1), tableToString(call, v, root, indents + 1))
                end
            end
            
            return elements > 0 and string.format("%s\n%s", string.sub(head, 1, -3), string.rep('\t', indents - 1) .. '}') or "{}"
        elseif primTyp == "function" and (call.Type == "BindableEvent" or call.Type == "BindableFunction") then -- functions are only recieveable through bindables, not remotes
            varConstructor = 'nil -- "' .. tostring(arg) .. '"  FUNCTIONS CANT BE MADE INTO PSEUDOCODE' -- just in case
        elseif primTyp == "thread" and false then -- dont bother listing threads because they can never be sent
            varConstructor = 'nil -- "' .. tostring(arg) .. '"  THREADS CANT BE MADE INTO PSEUDOCODE' -- just in case
        elseif primTyp == "thread" or primTyp == "function" then
            varConstructor = "nil"
        else
            return tostring(data)
        end
    end

    local types = {
        ["string"] = { Color3.fromHSV(29/360, 0.8, 1), function(obj)
            return purifyString(obj, true)
        end },
        ["number"] = { Color3.fromHSV(120/360, 0.8, 1), function(obj)
            return tostring(obj)
        end },
        ["boolean"] = { Color3.fromHSV(211/360, 0.8, 1), function(obj)
            return tostring(obj)
        end },
        ["table"] = { white, function(obj)
            return tostring(obj)
        end },

        --[[["userdata"] = { Color3.fromHSV(258/360, 0.8, 1), function(obj)
            return "Unprocessed Userdata: " .. typeof(obj) .. ": " .. tostring(obj)
        end },
        ["Instance"] = { Color3.fromHSV(57/360, 0.8, 1), function(obj)
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
        ["nil"] = { Color3.fromHSV(360/360, 0.8, 1), function(obj)
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
            return st, (typeof(arg) == "Instance" and Color3.fromHSV(57/360, 0.8, 1)) or white
        else
            return ("Unprocessed Lua Type: " .. tostring(t)), Color3.new(1, 1, 1)
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
        OnClientEvent = 5,
        OnClientInvoke = 6,
        OnEvent = 7,
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
            Color = Color3.fromRGB(254, 254, 0),
            Indent = 0
        },
        {
            Name = "InvokeServer",
            Object = "RemoteFunction",
            Type = "Call",
            Method = "InvokeServer",
            DeprecatedMethod = "invokeServer",
            Enabled = Settings.InvokeServer,
            Icon = "\xef\x81\xa4",
            Color = Color3.fromRGB(250, 152, 251),
            Indent = 153
        },
        {
            Name = "Fire",
            Object = "BindableEvent",
            Type = "Call",
            Method = "Fire",
            DeprecatedMethod = "fire",
            Enabled = Settings.Fire,
            Icon = "\xef\x83\xa7",
            Color = Color3.fromRGB(200, 100, 0),
            Indent = 319
        },
        {
            Name = "Invoke",
            Object = "BindableFunction",
            Type = "Call",
            Method = "Invoke",
            DeprecatedMethod = "invoke",
            Enabled = Settings.Invoke,
            Icon = "\xef\x81\xa4",
            Color = Color3.fromRGB(163, 51, 189),
            Indent = 434
        },

        {
            Name = "OnClientEvent",
            Object = "RemoteEvent",
            Type = "Connection",
            Connection = "OnClientEvent",
            Enabled = Settings.OnClientEvent,
            Icon = "\xef\x83\xa7",
            Color = Color3.fromRGB(254, 254, 0),
            Indent = 0,
        },
        {
            Name = "OnClientInvoke",
            Object = "RemoteFunction",
            Type = "Callback",
            Callback = "OnClientInvoke",
            Enabled = Settings.OnClientInvoke,
            Icon = "\xef\x81\xa4",
            Color = Color3.fromRGB(250, 152, 251),
            Indent = 153,
        },
        {
            Name = "OnEvent",
            Object = "BindableEvent",
            Type = "Connection",
            Connection = "Event", -- not OnEvent cause roblox naming is wacky
            Enabled = Settings.OnEvent,
            Icon = "\xef\x83\xa7",
            Color = Color3.fromRGB(200, 100, 0),
            Indent = 319
        },
        {
            Name = "OnInvoke",
            Object = "BindableFunction",
            Type = "Callback",
            Callback = "OnInvoke",
            Enabled = Settings.OnInvoke,
            Icon = "\xef\x81\xa4",
            Color = Color3.fromRGB(163, 51, 189),
            Indent = 434
        }
    }

    local function getCountFromTable(tab: table, target)
        local count = 0
        for _,v in tab do
            if v == target then
                count += 1
            end
        end
        return count
    end

    local function genPseudo(rem, call, watermark)
        local watermark = watermark and "--Pseudocode Generated by GameGuy's Remote Spy\n" or ""
        if #call.Args == 0 and call.NilCount == 0 then
            return watermark .. "local remote = " .. getInstancePath(rem) .. "\n\nremote:" .. spyFunctions[idxs[call.Type]].Method .."()"
        else
            local argCalls = {}
            local argCallCount = {}

            local pseudocode = ""

            for i = 1, #call.Args do
                local arg = call.Args[i]
                local primTyp = type(arg)
                local tempTyp = typeof(arg)
                local typ = (string.gsub(tempTyp, "^%u", string.lower))

                if primTyp == "thread" or (primTyp == "function" and (call.Type == "RemoteEvent" or call.Type == "RemoteFunction")) then
                    typ = "nil" -- functions are only recieveable through bindables, not remotes
                    primTyp = "nil"
                end -- dont bother listing threads because they can never be sent

                local amt = getCountFromTable(argCalls, typ) + 1
                table.insert(argCalls, typ)
                table.insert(argCallCount, amt)

                if primTyp == "nil" then
                    continue
                end

                local varPrefix = ""
                if primTyp ~= "function" then
                    varPrefix = "local " .. typ .. tostring(amt) .. ": ".. tempTyp .." = "
                else
                    varPrefix = "local " .. typ .. tostring(amt) .." = "
                end
                local varConstructor = ""

                if primTyp == "userdata" or primTyp == "vector" then -- roblox should just get rid of vector already
                    varConstructor = (typ == "Instance" and getInstancePath(arg)) or userdataValue(arg)
                elseif primTyp == "table" then
                    varConstructor = tableToString(call, arg)
                elseif primTyp == "string" then
                    varConstructor = purifyString(arg, true)
                elseif primTyp == "function" then
                    varConstructor = 'nil -- "' .. tostring(arg) .. '"  FUNCTIONS CANT BE MADE INTO PSEUDOCODE' -- just in case
                elseif primTyp == "thread" then
                    varConstructor = 'nil -- "' .. tostring(arg) .. '"  THREADS CANT BE MADE INTO PSEUDOCODE' -- just in case
                elseif primTyp == "thread" or primTyp == "function" then
                    varConstructor = "nil"
                else
                    varConstructor = tostring(arg)
                end

                pseudocode ..= (varPrefix .. (varConstructor .. "\n"))
            end

            for i = 1, call.NilCount do
                pseudocode ..= "local hiddenNil" .. tostring(i) .. " = nil -- games can detect if this is missing, but likely won't.\n"
            end
            pseudocode ..= ("\nlocal remote = " .. getInstancePath(rem) .. "\n") .. ("remote:" .. spyFunctions[idxs[call.Type]].Method .. "(")
            
            for i,v in argCalls do
                if v == "nil" then
                    pseudocode ..= "nil, "
                else
                    pseudocode ..= ( v .. argCallCount[i] .. ", " )
                end
            end

            for i = 1, call.NilCount do
                pseudocode ..= ("hiddenNil" .. tostring(i) .. ", ")
            end

            return watermark .. (string.sub(pseudocode, 1, -3) .. ")") -- sub gets rid of the last ", "
        end
    end

    local lines = {}
    local argLines = {}
    local logs = {}
    local callbackButtonline
    --local invokeLogs = {}
    local remFuncs = {}

    local searchBar -- declared later
    local function clearFilter()
        for _,v in lines do
            for _,x in spyFunctions do
                if v[1] == x.Name and v[3].Label ~= "0" and x.Enabled then
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

        for i,v in lines do
            if not string.match(string.lower(tostring(i)), string.lower(name)) then -- check for if the remote actually had a log made
                v[2].Visible = false
                v[4].Visible = false
            elseif spyFunctions[idxs[v[1]]].Enabled then
                v[2].Visible = true
                v[4].Visible = true
            end
        end
    end
     
    local function updateLines(name: string, enabled: bool)
        for _,v in lines do
            if v[1] == name then
                if v[2].Visible ~= enabled then
                    if (enabled and v[3].Label ~= "0") or not enabled then
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
    _G.remoteSpyConnections = {}

    local mainWindow = _G.remoteSpyMainWindow
    local settingsWindow = _G.remoteSpySettingsWindow
    pushTheme(mainWindow)
    pushTheme(settingsWindow)

    -- settings page init
    local settingsWidth = 310
    local settingsHeight = 200
    settingsWindow.DefaultSize = Vector2.new(settingsWidth, settingsHeight)
    settingsWindow.CanResize = false
    settingsWindow.VisibilityOverride = true
    settingsWindow.Visible = false
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
    table.insert(_G.remoteSpyConnections, exitButton.OnUpdated:Connect(function()
        settingsWindow.Visible = false
    end))
    
    local tabFrame = topBar:SameLine()
    local settingsTabs = tabFrame:Indent(-1):TabMenu()
    local generalTab = settingsTabs:Add("General")
    local pseudocodeTab = settingsTabs:Add("Pseudocode")
    local themeTab = settingsTabs:Add("Theme")
    local creditsTab = settingsTabs:Add("Credits")

    do  -- general Settings
        local checkBox = generalTab:SameLine():CheckBox()
        checkBox.Label = "Display Callbacks/Connections (TBA)"
        checkBox.Value = Settings.CallbackButtons
        table.insert(_G.remoteSpyConnections, checkBox.OnUpdated:Connect(function(value)
            Settings.CallbackButtons = value
            callbackButtonline.Visible = value
            if not value then
                for i = 5,8 do
                    local spyFunc = spyFunctions[i]
                    spyFunc.Button.Value = false
                    spyFunc.Enabled = false
                    Settings[spyFunc.Name] = false
                end
            end
            updateLines(searchBar.Value)
            saveConfig()
        end))

        local checkBox2 = generalTab:CheckBox()
        checkBox2.Label = "Decompile Calling Script to External UI"
        checkBox2.Value = Settings.DecompileCallingScriptToExternal
        table.insert(_G.remoteSpyConnections, checkBox2.OnUpdated:Connect(function(value)
            Settings.DecompileCallingScriptToExternal = value
            saveConfig()
        end))

        local checkBox4 = generalTab:CheckBox()
        checkBox4.Label = "Cache Unselected Remotes' Calls"
        checkBox4.Value = Settings.LogHiddenRemotesCalls
        table.insert(_G.remoteSpyConnections, checkBox4.OnUpdated:Connect(function(value)
            Settings.LogHiddenRemotesCalls = value
            saveConfig()
        end))

        local checkBox5 = generalTab:CheckBox()
        checkBox5.Label = "Call Cache Amount Limiter (Per Remote)"
        checkBox5.Value = Settings.CacheLimit
        table.insert(_G.remoteSpyConnections, checkBox5.OnUpdated:Connect(function(value)
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
    end -- general settings

    do -- pseudocode settings
        local checkBox = pseudocodeTab:SameLine():CheckBox()
        checkBox.Label = "Send Pseudocode To External UI"
        checkBox.Value = Settings.SendPseudocodeToExternal
        table.insert(_G.remoteSpyConnections, checkBox.OnUpdated:Connect(function(value)
            Settings.SendPseudocodeToExternal = value
            saveConfig()
        end))

        pseudocodeTab:Label("Pseudocode Watermark")
        local combo1 = pseudocodeTab:Combo()
        combo1.Items = { "Off", "External UI Only", "Always On" }
        combo1.SelectedItem = Settings.PseudocodeWatermark
        table.insert(_G.remoteSpyConnections, combo1.OnUpdated:Connect(function(selection)
            Settings.PseudocodeWatermark = selection
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

    local remotePageObjects = {
        Name = nil,
        Icon = nil,
        IconFrame = nil,
        IgnoreButton = nil,
        IgnoreButtonFrame = nil,
        BlockButton = nil,
        BlockButtonFrame = nil,
        MainWindow = nil
    }

    local function unloadRemote()
        frontPage.Visible = true
        remotePage.Visible = false
        currentSelectedRemote = nil
        remotePageObjects.MainWindow:Clear()
        table.clear(argLines)
    end

    local topBar = remotePage:SameLine()

    do -- topbar code

        local exitButtonFrame = topBar:Dummy()
        exitButtonFrame:SetColor(RenderColorOption.Button, black, 0)
        exitButtonFrame:SetStyle(RenderStyleOption.ButtonTextAlign, Vector2.new(0.5, 0.5))
        local exitButton = exitButtonFrame:Indent(width-41):Button()
        exitButton.Size = Vector2.new(24, 24)
        exitButton.Label = "\xef\x80\x8d"
        table.insert(_G.remoteSpyConnections, exitButton.OnUpdated:Connect(unloadRemote))

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
        table.insert(_G.remoteSpyConnections, ignoreButton.OnUpdated:Connect(function()
            if currentSelectedRemote then
                if logs[currentSelectedRemote].Ignored then
                    logs[currentSelectedRemote].Ignored = false
                    ignoreButtonFrame:SetColor(RenderColorOption.Text, red, 1)
                    ignoreButton.Label = "Ignore"
                else
                    logs[currentSelectedRemote].Ignored = true
                    ignoreButtonFrame:SetColor(RenderColorOption.Text, green, 1)
                    ignoreButton.Label = "Unignore"
                end
                remFuncs[currentSelectedRemote].UpdateIgnores()
            end
        end))

        local blockButtonFrame = buttonBar:Dummy()
        blockButtonFrame:SetColor(RenderColorOption.Text, red, 1)
        local blockButton = blockButtonFrame:Button()
        blockButton.Label = "Block"
        table.insert(_G.remoteSpyConnections, blockButton.OnUpdated:Connect(function()
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
                remFuncs[currentSelectedRemote].UpdateBlocks()
            end
        end))

        local clearLogsButton = buttonBar:Button()
        clearLogsButton.Label = "Clear Logs"
        table.insert(_G.remoteSpyConnections, clearLogsButton.OnUpdated:Connect(function()
            if currentSelectedRemote then
                do -- updates front menu
                    table.clear(logs[currentSelectedRemote].Calls)
                    lines[currentSelectedRemote][3].Label = "0"
                    if not logs[currentSelectedRemote].Ignored then
                        lines[currentSelectedRemote][2].Visible = false
                        lines[currentSelectedRemote][4].Visible = false
                    end
                end

                do -- updates remote menu
                    remotePageObjects.MainWindow:Clear()
                    table.clear(argLines)
                    addSpacer(remotePageObjects.MainWindow, 8)
                end
            end
        end))

        local copyPathButton = buttonBar:Button()
        copyPathButton.Label = "Copy Path"
        table.insert(_G.remoteSpyConnections, copyPathButton.OnUpdated:Connect(function()
            if currentSelectedRemote then
                local str = getInstancePath(currentSelectedRemote)
                if type(str) == "string" then
                    setclipboard(str)
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
        local mainWindow = remoteArgFrame:Child()
        remotePageObjects.MainWindow = mainWindow
    end

    local function createCSButton(window, call)
        local button = window:Button()
        button.Label = "Get Calling Script"
        table.insert(_G.remoteSpyConnections, button.OnUpdated:Connect(function()
            local str = call.Script and getInstancePath(call.Script) -- not sure if getcallingscript can return a ModuleScript, I assume it can't, but adding this just in case
            if type(str) == "string" then
                setclipboard(str)
            else
                pushError("Failed to get Calling Script")
            end
        end))
    end

    local function createCSDecompileButton(window, call)
        local button = window:Button()
        button.Label = "Decompile CS"
        table.insert(_G.remoteSpyConnections, button.OnUpdated:Connect(function()
            if call.FromSynapse then
                pushError("Synapse Created Scripts Cannot be Decompiled")
                return
            end

            if not pcall(function()
                local str = decompile(call.Script)
                local scriptName = call.Script and getInstancePath(call.Script)
                if type(str) == "string" then
                    if Settings.DecompileCallingScriptToExternal then
                        createuitab(scriptName or "Script Not Found", str)
                    else
                        setclipboard(str)
                    end
                else
                    pushError("Failed to Decompile Calling Script2")
                end
            end) then
                pushError("Failed to Decompile Calling Script")
            end
        end))
    end

    local function createRepeatCallButton(window, call, self)
        local button = window:Button()
        button.Label = "Repeat Call"
        table.insert(_G.remoteSpyConnections, button.OnUpdated:Connect(function()
            if call.NilCount == 0 then
                if not pcall(spyFunctions[idxs[call.Type]].Function, self, unpack(call.Args)) then
                    pushError("Failed to Repeat Call")
                end
            else
                if not pcall(loadstring(genPseudo(self, call))) then
                    pushError("Failed to Repeat Call (Variant 2)")
                end
            end
        end))
    end

    local function createGenPCButton(window, call, self)
        local button = window:Button()
        button.Label = "Generate Pseudocode"
        table.insert(_G.remoteSpyConnections, button.OnUpdated:Connect(function()
            if not pcall(function()
                local pseudo = genPseudo(self, call)
                if Settings.SendPseudocodeToExternal then
                    createuitab("RS Pseudocode", genPseudo(self, call, Settings.PseudocodeWatermark == 2)) -- no pseudocode watermark when setting to clipboard
                else
                    setclipboard(genPseudo(self, call, Settings.PseudocodeWatermark == 3))
                end
            end) then
                pushError("Failed to Generate Pseudocode")
            end
        end))
    end

    local function makeRemoteViewerLog(window, call, remote)
        local totalArgCount = #call.Args + call.NilCount
        local tempMain = window:Dummy()
        table.insert(argLines, tempMain)
        tempMain:SetColor(RenderColorOption.ChildBg, Color3.fromRGB(25, 25, 28), 1)

        local childWindow = tempMain:Indent(8):Child()
        addSpacer(childWindow, 8)

        if #call.Args == 1 or #call.Args == 0 then
            childWindow.Size = Vector2.new(width-46, 24 + 24 + 24) -- 2 lines (top line = 24, arg line = 20) + 3x (8px) spacers  | -46 because 16 padding on each side, plus 14 wide scrollbar
        elseif totalArgCount < 10 then
            childWindow.Size = Vector2.new(width-46, (totalArgCount * 28) - 4 + 24 + 24) -- 3 lines (1 line = 24) + 3x (8px) spacers  | -46 because 16 padding on each side, plus 14 wide scrollbar
        else -- 28 pixels per line (24 for arg, 4 for spacer), but -4 because no spacer at end, then +24 because button line, and +24 for top, bottom, and middle spacer
            childWindow.Size = Vector2.new(width-46, (9 * 28) - 4 + 24 + 24)
        end

        local textFrame = childWindow:SameLine()

        if call.FromSynapse then
            local temp = textFrame:Dummy():Indent(9)
            temp:SetColor(RenderColorOption.Text, Color3.fromRGB(252, 86, 3), 1)
            temp:SetColor(RenderColorOption.Button, black, 0)
            temp:SetColor(RenderColorOption.ButtonActive, black, 0)
            temp:SetColor(RenderColorOption.ButtonHovered, black, 0)
            local fakeBtn = temp:Button()
            fakeBtn.Label = "\xef\x87\x89"
        end

        local buttonFrame = textFrame:Indent(8 + 23):SameLine()

        createCSButton(buttonFrame, call)
        createCSDecompileButton(buttonFrame, call)
        createRepeatCallButton(buttonFrame, call, remote)
        createGenPCButton(buttonFrame, call, remote)

        addSpacer(childWindow, 8)

        if totalArgCount == 0 or totalArgCount == 1 then
            local argFrame = childWindow:SameLine()

            local temp2 = argFrame:SameLine()
            temp2:SetColor(RenderColorOption.ButtonActive, colorOptions.FrameBg[1], 1)
            temp2:SetColor(RenderColorOption.ButtonHovered, colorOptions.FrameBg[1], 1)
            temp2:SetColor(RenderColorOption.Button, colorOptions.FrameBg[1], 1)
            temp2:SetStyle(RenderStyleOption.ButtonTextAlign, Vector2.new(0, 0.5))

            local lineContents = temp2:Indent(8):Button()
            if totalArgCount == 0 then
                argFrame:SetColor(RenderColorOption.Text, Color3.fromRGB(156, 0, 0), 1)
                lineContents.Label = spaces2 .. "nil"
            elseif #call.Args == 1 then
                local text, color = getArgString(call.Args[1], call.Type)
                lineContents.Label = spaces2 .. text
                argFrame:SetColor(RenderColorOption.Text, color, 1)
            else
                lineContents.Label = spaces2 .. "HIDDEN NIL"
                argFrame:SetColor(RenderColorOption.Text, Color3.fromHSV(258/360, 0.8, 1), 1)
            end
            lineContents.Size = Vector2.new(width-24-38, 24) -- 24 = left padding, 38 = right padding, and no scrollbar

            local temp = argFrame:SameLine()
            argFrame:SetColor(RenderColorOption.ButtonActive, black, 0)
            argFrame:SetColor(RenderColorOption.ButtonHovered, black, 0)
            argFrame:SetColor(RenderColorOption.Button, black, 0)
            temp:SetStyle(RenderStyleOption.ButtonTextAlign, Vector2.new(1, 0.5))
            temp:SetColor(RenderColorOption.Text, Color3.fromHSV(179/360, 0.8, 1), 1)

            local lineNum = temp:Indent(1):Button()
            lineNum.Label = "1"
            lineNum.Size = Vector2.new(32, 20)
        else
            local curCount = 0
            for i = 1, #call.Args do
                local x = call.Args[i]

                local argFrame = childWindow:SameLine()

                local temp2 = argFrame:SameLine()
                temp2:SetColor(RenderColorOption.ButtonActive, colorOptions.FrameBg[1], 1)
                temp2:SetColor(RenderColorOption.ButtonHovered, colorOptions.FrameBg[1], 1)
                temp2:SetColor(RenderColorOption.Button, colorOptions.FrameBg[1], 1)
                temp2:SetStyle(RenderStyleOption.ButtonTextAlign, Vector2.new(0, 0.5))

                local lineContents = temp2:Indent(8):Button()
                local text, color = getArgString(x, call.Type)
                lineContents.Label = spaces2 .. text
                argFrame:SetColor(RenderColorOption.Text, color, 1)
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
                temp:SetColor(RenderColorOption.Text, Color3.fromHSV(179/360, 0.8, 1), 1)

                local lineNum = temp:Indent(1):Button()
                lineNum.Label = tostring(i)
                lineNum.Size = Vector2.new(32, 24)

                addSpacer(childWindow, 4)
            end
            for i = 1, call.NilCount do
                local argFrame = childWindow:SameLine()

                local temp2 = argFrame:SameLine()
                temp2:SetColor(RenderColorOption.ButtonActive, colorOptions.FrameBg[1], 1)
                temp2:SetColor(RenderColorOption.ButtonHovered, colorOptions.FrameBg[1], 1)
                temp2:SetColor(RenderColorOption.Button, colorOptions.FrameBg[1], 1)
                temp2:SetStyle(RenderStyleOption.ButtonTextAlign, Vector2.new(0, 0.5))

                local lineContents = temp2:Indent(8):Button()
                lineContents.Label = spaces2 .. "HIDDEN NIL"
                argFrame:SetColor(RenderColorOption.Text, Color3.fromHSV(258/360, 0.8, 1), 1)
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
                temp:SetColor(RenderColorOption.Text, Color3.fromHSV(179/360, 0.8, 1), 1)

                local lineNum = temp:Indent(1):Button()
                lineNum.Label = tostring(i + #call.Args)
                lineNum.Size = Vector2.new(32, 24)

                addSpacer(childWindow, 4)
            end
        end
        addSpacer(tempMain, 8)
    end

    local function loadRemote(self, data)
        local funcInfo = spyFunctions[idxs[data.Type]]
        frontPage.Visible = false
        remotePage.Visible = true
        currentSelectedRemote = self
        remotePageObjects.Name.Label = purifyString(self.Name)
        remotePageObjects.Icon.Label = funcInfo.Icon
        remotePageObjects.IconFrame:SetColor(RenderColorOption.Text, funcInfo.Color, 1)
        remotePageObjects.IgnoreButton.Label = (logs[self].Ignored and "Unignore") or "Ignore"
        remotePageObjects.IgnoreButtonFrame:SetColor(RenderColorOption.Text, (logs[self].Ignored and green) or red, 1)
        remotePageObjects.BlockButton.Label = (logs[self].Blocked and "Unblock") or "Block"
        remotePageObjects.BlockButtonFrame:SetColor(RenderColorOption.Text, (logs[self].Blocked and green) or red, 1)

        local mainWindow = remotePageObjects.MainWindow
        mainWindow:SetStyle(RenderStyleOption.ItemSpacing, Vector2.new(4, 0))
        addSpacer(mainWindow, 8)

        for _,v in logs[self].Calls do
            makeRemoteViewerLog(mainWindow, v, self)
        end
    end

    -- Below this is rendering Front Page
    local topBar = frontPage:SameLine()
    local frameWidth = width-130
    local searchBarFrame = topBar:Indent(-0.35*frameWidth):Child()
    searchBarFrame.Size = Vector2.new(frameWidth, 24)
    searchBarFrame:SetColor(RenderColorOption.ChildBg, black, 0)
    searchBar = searchBarFrame:Indent(0.35*frameWidth):TextBox() -- localized earlier
    table.insert(_G.remoteSpyConnections, searchBar.OnUpdated:Connect(filterLines))
    
    local searchButton = topBar:Button()
    searchButton.Label = "Search"
    table.insert(_G.remoteSpyConnections, searchButton.OnUpdated:Connect(function()
        filterLines(searchBar.Value) -- redundant because i did it above but /shrug
    end))

    local clearButton = topBar:Button()
    clearButton.Label = "Reset"
    table.insert(_G.remoteSpyConnections, clearButton.OnUpdated:Connect(function()
        searchBar.Value = ""
        clearFilter()
    end))

    local clearAllLogsButton = topBar:Button()
    clearAllLogsButton.Label = "Clear All Logs"
    table.insert(_G.remoteSpyConnections, clearAllLogsButton.OnUpdated:Connect(function()
        for i,v in logs do
            table.clear(v.Calls)
            if lines[i] then
                lines[i][3].Label = "0"
                if not v.Ignored then -- im keeping the ignored remotes shown.  Either I clear all remotes and unignore any ignored ones, or I clear all remotes except ignoted ones.
                    lines[i][2].Visible = false -- any remotes cleared when ignored wont show any new logs, and therefore will obviously be later untraceable
                    lines[i][4].Visible = false
                end
            end
        end
    end))

    local topRightBar = topBar:Indent(width-40):SameLine()
    topRightBar:SetColor(RenderColorOption.Button, black, 0)
    topRightBar:SetStyle(RenderStyleOption.ButtonTextAlign, Vector2.new(0.5, 0.5))

    local settingsButton = topRightBar:Button()
    settingsButton.Label = "\xef\x80\x93"
    settingsButton.Size = Vector2.new(24, 24)
    table.insert(_G.remoteSpyConnections, settingsButton.OnUpdated:Connect(function()
        settingsWindow.Visible = not settingsWindow.Visible
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
        table.insert(_G.remoteSpyConnections, btn.OnUpdated:Connect(function(enabled)
            v.Enabled = enabled
            Settings[v.Name] = enabled
            updateLines(v.Name, enabled)

            saveConfig()
        end))

        sameLine:Label(v.Name)
    end
    
    frontPage:SetColor(RenderColorOption.ChildBg, colorOptions.TitleBg[1], 1)
    frontPage:SetStyle(RenderStyleOption.ChildRounding, 5)

    local childWindow = frontPage:Child()
    childWindow:SetStyle(RenderStyleOption.ItemSpacing, Vector2.new(4, 0))
    childWindow:SetStyle(RenderStyleOption.FrameRounding, 3)
    addSpacer(childWindow, 8)

    local function makeCopyPathButton(sameLine, self)
        local copyPathButton = sameLine:Button()
        copyPathButton.Label = "Copy Path"

        table.insert(_G.remoteSpyConnections, copyPathButton.OnUpdated:Connect(function()
            local str = getInstancePath(self)
            if type(str) == "string" then
                setclipboard(str)
            else
                pushError("Failed to Copy Path")
            end
        end))
    end

    local function makeClearLogsButton(sameLine, self)
        local clearLogsButton = sameLine:Button()
        clearLogsButton.Label = "Clear Logs"

        table.insert(_G.remoteSpyConnections, clearLogsButton.OnUpdated:Connect(function()
            table.clear(logs[self].Calls)
            lines[self][3].Label = "0"
            if not logs[self].Ignored then
                lines[self][2].Visible = false
                lines[self][4].Visible = false
            end
        end))
    end

    local function makeIgnoreButton(sameLine, self)
        local spoofLine = sameLine:SameLine()
        spoofLine:SetColor(RenderColorOption.Text, red, 1)
        local ignoreButton = spoofLine:Button()
        ignoreButton.Label = "Ignore"

        remFuncs[self].UpdateIgnores = function()
            if logs[self].Ignored then
                ignoreButton.Label = "Unignore"
                spoofLine:SetColor(RenderColorOption.Text, green, 1)
            else
                ignoreButton.Label = "Ignore"
                spoofLine:SetColor(RenderColorOption.Text, red, 1)
            end
        end

        table.insert(_G.remoteSpyConnections, ignoreButton.OnUpdated:Connect(function()
            if logs[self].Ignored then
                logs[self].Ignored = false
                ignoreButton.Label = "Ignore"
                spoofLine:SetColor(RenderColorOption.Text, red, 1)
            else
                logs[self].Ignored = true
                ignoreButton.Label = "Unignore"
                spoofLine:SetColor(RenderColorOption.Text, green, 1)
            end
        end))
    end

    local function makeBlockButton(sameLine, self)
        local spoofLine = sameLine:SameLine()
        spoofLine:SetColor(RenderColorOption.Text, red, 1)
        local blockButton = spoofLine:Button()
        blockButton.Label = "Block"

        remFuncs[self].UpdateBlocks = function()
            if logs[self].Blocked then
                spoofLine:SetColor(RenderColorOption.Text, green, 1)
                blockButton.Label = "Unblock"
            else
                spoofLine:SetColor(RenderColorOption.Text, red, 1)
                blockButton.Label = "Block"
            end
        end

        table.insert(_G.remoteSpyConnections, blockButton.OnUpdated:Connect(function()
            if logs[self].Blocked then
                logs[self].Blocked = false
                spoofLine:SetColor(RenderColorOption.Text, red, 1)
                blockButton.Label = "Block"
            else
                logs[self].Blocked = true
                spoofLine:SetColor(RenderColorOption.Text, green, 1)
                blockButton.Label = "Unblock"
            end
        end))
    end

    local function renderNewLog(self, data)
        remFuncs[self] = {}

        local functionInfo = spyFunctions[idxs[data.Type]]

        local temp = childWindow:Dummy():Indent(8)
        temp:SetStyle(RenderStyleOption.ItemSpacing, Vector2.new(4, 0))
        temp:SetColor(RenderColorOption.ChildBg, Color3.fromRGB(25, 25, 28), 1)
        temp:SetStyle(RenderStyleOption.SelectableTextAlign, Vector2.new(0, 0.5))

        local line = {}
        line[1] = functionInfo.Name
        line[2] = temp:Child()
        sameButtonLine = line[2]
        sameButtonLine.Visible = spyFunctions[idxs[data.Type]].Enabled
        sameButtonLine.Size = Vector2.new(width-32-14, 32) -- minus 32 because 4x 8px spacers, minus 14 because scrollbar
        addSpacer(sameButtonLine, 4)
        sameButtonLine = sameButtonLine:SameLine()

        local remoteButton = sameButtonLine:Indent(6):Selectable()
        remoteButton.Label = spaces .. purifyString(self.Name, false) 
        remoteButton.Size = Vector2.new(width-327-4-14, 24)
        table.insert(_G.remoteSpyConnections, remoteButton.OnUpdated:Connect(function()
            loadRemote(self, data)
        end))

        addSpacer(sameButtonLine, 3)

        local cloneLine = sameButtonLine:SameLine():Indent(6)
        cloneLine:SetColor(RenderColorOption.Text, functionInfo.Color, 1)
        
        cloneLine:Label(functionInfo.Icon)
        
        local cloneLine2 = sameButtonLine:SameLine()
        cloneLine2:SetColor(RenderColorOption.Text, Color3.fromHSV(179/360, 0.8, 1), 1)

        local callAmt = #logs[self].Calls
        local callStr = (callAmt < 1000 and tostring(callAmt)) or "999+"
        line[3] = cloneLine2:Indent(27):Label(callStr)

        local ind = sameButtonLine:Indent(width-333)
        
        makeCopyPathButton(ind, self)
        makeClearLogsButton(sameButtonLine, self)
        makeIgnoreButton(sameButtonLine, self)
        makeBlockButton(sameButtonLine, self)

        line[4] = addSpacer(childWindow, 4)
        line[4].Visible = spyFunctions[idxs[data.Type]].Enabled

        lines[self] = line
        filterLines(searchBar.Value)
    end

    local synapseUpdateLogsThread

    local function updateLogs(self, data)
        synapseUpdateLogsThread = coroutine.create(updateLogs)
        table.insert(logs[self].Calls, data)

        if Settings.CacheLimit then
            local callNum = #logs[self].Calls
            local check = currentSelectedRemote == self
            local callCount = (callNum-Settings.MaxCallAmount)
            if callCount > 0 then
                for i = 1,callCount do
                    if check then
                        argLines[i]:Clear()
                        argLines[i].Visible = false
                        table.remove(argLines, i)
                    end
                    table.remove(logs[self].Calls, i)
                end
            end
        end
        
        if lines[self] then
            local callAmt = #logs[self].Calls
            if callAmt > 0 and spyFunctions[idxs[data.Type]].Enabled then
                lines[self][2].Visible = true
                lines[self][4].Visible = true
            end
            local callStr = (callAmt < 1000 and tostring(callAmt)) or "999+"
            lines[self][3].Label = callStr
        else
            renderNewLog(self, data)
        end

        if currentSelectedRemote == self then
            makeRemoteViewerLog(remotePageObjects.MainWindow, data, self)
        end
    end

    synapseUpdateLogsThread = coroutine.create(updateLogs)
    local defer = task.defer
    local spawnFunc = task.spawn

    local function sendLog(self, method, func, ...)
            
        if not logs[self] then
            logs[self] = {
                Blocked = false,
                Ignored = false,
                Calls = {}
            }
        end

        if not logs[self].Ignored and (Settings.LogHiddenRemotesCalls or spyFunctions[idxs[method]].Enabled) then
            local args, tableDepth = shallowClone({...}, nil, -1) -- 1 deeper total
            local argCount = select("#", ...)
            if not args or #args > 7995 or (argCount-1 + tableDepth) >= 299 then
                return
            end

            local data = {
                Type = method,
                Script = getcallingscript(),
                Args = args, -- 2 deeper total
                NilCount = (argCount - #args),
                FromSynapse = checkcaller(),
                InvokeFunction = func
            }

            spawnFunc(synapseUpdateLogsThread, self, data)
        end
    end

    local namecallFilters = {}
    --local indexFilters = {}

    -- line 515 needs to be uncommented when I later decide to add in the callback stuff

    for _,v in spyFunctions do
        --[[if v.isCallback then
            table.insert(indexFilters, AllFilter.new({
                InstanceTypeFilter.new(1, v.Object),
                ArgumentFilter.new(2, v.Name),
                TypeFilter.new(3, "function")
            }))
        else]]
        if v.Type == "Call" then
            table.insert(namecallFilters, AllFilter.new({
                InstanceTypeFilter.new(1, v.Object),
                AnyFilter.new({
                    NamecallFilter.new(v.Method),
                    NamecallFilter.new(v.DeprecatedMethod)
                })
            }))
        end
        --end
    end

    --[[local function addInvoke(remote: RemoteFunction, func)
        if not invokeLogs[remote] then
            invokeLogs[remote] = {
                CurrentFunction = nil,
                Ignored = false,
                Blocked = false,
                Calls = {}
            }
        elseif invokeLogs[remote].CurrentFunction then
            restorefunction(invokeLogs[remote].CurrentFunction)
        end

        invokeLogs[remote].CurrentFunction = func

        local oldfunc
        oldfunc = hookfunction(func, function(...)
            local retVal = oldfunc(...)
            defer(sendLog, self, func, retVal)

            return retVal
        end)
    end]]

    local function newHookMetamethod(toHook, mtmethod, hookFunction, filter)
        local oldFunction

        local func = getfilter(filter, function(...) 
            return oldFunction(...)
        end, hookFunction)

        oldFunction = hookmetamethod(toHook, mtmethod, func)
        return oldFunction
    end

    --[[local oldNewIndex -- this is for OnClientInvoke hooks
    oldNewIndex = newHookMetamethod(game, "__index", function(self, idx, newidx)
        addInvoke(self, newidx)
        return oldNewIndex(self, idx, newidx)
    end, AnyFilter.new(indexFilters))

    do -- init OnClientInvoke
        for _,v in getnilinstances() do
            if v.ClassName == "RemoteFunction" then
                local func = getcallbackmember(v, "OnClientInvoke")
                if func then
                    addInvoke(v, func)
                end
            end
            for _,x in v:GetDescendants() do
                if x.ClassName == "RemoteFunction" then
                    local func = getcallbackmember(x, "OnClientInvoke")
                    if func then
                        addInvoke(x, func)
                    end
                end
            end
        end

        for _,v in game:GetDescendants() do
            if v.ClassName == "RemoteFunction" then
                local func = getcallbackmember(v, "OnClientInvoke")
                if func then
                    addInvoke(v, func)
                end
            end
        end
    end]]

    local oldNamecall
    oldNamecall = newHookMetamethod(game, "__namecall", newcclosure(function(self, ...)

        defer(sendLog, self, getnamecallmethod(), nil, ...)
        
        if logs[self] and logs[self].Blocked then return end

        return oldNamecall(self, ...)
    end), AnyFilter.new(namecallFilters))

    for i,v in spyFunctions do
        if v.Type == "Call" then

            local oldfunc
            local newfunction = function(self, ...)

                defer(sendLog, self, v.Name, nil, ...)

                if not logs[self] or not logs[self].Blocked then
                    return oldfunc(self, ...)
                end
            end

            oldfunc = hookfunction(Instance.new(v.Object)[v.Method], newcclosure(newfunction), InstanceTypeFilter.new(1, v.Object))

            v.Function = newfunction
        end
    end
else

    for _,v in _G.remoteSpyConnections do
        v:Disconnect()
    end

    _G.remoteSpyConnections = nil
    _G.remoteSpyMainWindow = nil
    _G.remoteSpySettingsWindow = nil
    
    restorefunction(Instance.new("RemoteEvent").FireServer)
    restorefunction(Instance.new("RemoteFunction").InvokeServer)
    restorefunction(Instance.new("BindableEvent").Fire)
    restorefunction(Instance.new("BindableFunction").Invoke)
    restorefunction(getrawmetatable(game).__namecall)
end

-- CREDIT TO https://github.com/Upbolt/Hydroxide/ FOR INSPIRATION AND A FEW COPIED TOSTRING FUNCTIONS
