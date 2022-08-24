-- CREDIT TO https://github.com/Upbolt/Hydroxide/ FOR INSPIRATION AND A FEW COPIED TOSTRING FUNCTIONS

if not RenderWindow then
    error("EXPLOIT NOT SUPPORTED - GET SYNAPSE V3")
end

if not _G.mainWindow then
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
        ResizeGripActive = {black, 0},
        ResizeGripHovered = {black, 0},
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

    local function checkCyclic(newTable: table, originalTable: table, stack: number) -- prevents lots of detection methods, automatically checks for stack overflows, cyclic tables, and strips metamethods silently (no more table.freeze or table.__metamethod)
        stack = stack or 1

        for _,v in next, newTable do -- next because __iter is detected :(, also we don't want to replace metatables because of the risk of time delay before original metatable is replaced
            if type(v) == "table" then
                if rawequal(v, newTable) or rawequal(v, originalTable) then
                    return true
                end
                
                if stack == 19997 then
                    return true -- STACK OVERFLOW ATTEMPT
                end

                local retVal = checkCyclic(v, newTable, stack+1);
                
                return retVal
            end
        end
        return false
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

    local function purifyString(str: string, quotes: boolean) -- COPIED FROM HYDROXIDE
        str = string.gsub(str, "\\", "\\\\")
        if quotes then
            return '"' .. string.gsub(game:GetService("HttpService"):UrlEncode(str), "%%", "\\x") .. '"'
        else
            return string.gsub(game:GetService("HttpService"):UrlEncode(str), "%%", "\\x")
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

    local function toString(value) -- COPIED FROM HYDROXIDE
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
                if type(i) == "number" then -- table will either use all numbers, or mixed between non numbers
                    head ..= string.format("%s%s,\n", indent, tableToString(call, v, root, indents + 1))
                else
                    head ..= string.format("%s[%s] = %s,\n", indent, tableToString(call, i, root, indents + 1), tableToString(call, v, root, indents + 1))
                end
                
                elements += 1
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

        --[[["Vector2"] = { white, function(obj)
            return "Vector2.new(" .. tostring(obj.X) .. ", " .. tostring(obj.Y) .. ")"
        end },
        ["Vector3"] = { white, function(obj)
            return "Vector3.new(" .. tostring(obj.X) .. ", " .. tostring(obj.Y) .. ", " .. tostring(obj.Z) .. ")"
        end }]]
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
        RemoteEvent = 1,
        RemoteFunction = 2,
        BindableEvent = 3,
        BindableFunction = 4
    }

    local spyFunctions = {
        {
            Name = "RemoteEvent",
            Method = "FireServer",
            DeprecatedMethod = "fireServer",
            Enabled = true,
            Icon = "\xef\x83\xa7",
            Color = Color3.fromRGB(254, 254, 0),
            oldFunction = nil
        },
        {
            Name = "RemoteFunction",
            Method = "InvokeServer",
            DeprecatedMethod = "invokeServer",
            Enabled = true,
            Icon = "\xef\x81\xa4",
            Color = Color3.fromRGB(250, 152, 251),
            oldFunction = nil
        },
        {
            Name = "BindableEvent",
            Method = "Fire",
            DeprecatedMethod = "fire",
            Enabled = false,
            Icon = "\xef\x83\xa7",
            Color = Color3.fromRGB(200, 100, 0),
            oldFunction = nil
        },
        {
            Name = "BindableFunction",
            Method = "Invoke",
            DeprecatedMethod = "invoke",
            Enabled = false,
            Icon = "\xef\x81\xa4",
            Color = Color3.fromRGB(163, 51, 189),
            oldFunction = nil
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

    local function genPseudo(rem, call)
        if #call.Args == 0 and call.NilCount == 0 then
            return "local remote = " .. getInstancePath(rem) .. "\n\nremote:" .. spyFunctions[idxs[call.Type]].Method .."()"
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
                pseudocode ..= "local nil" .. tostring(i) .. " = nil -- HIDDEN NIL SENT BY THE GAME, THE GAME CAN TELL IF THIS IS NOT SENT, CONTACT GameGuy#5920 FOR MORE INFO\n"
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
                pseudocode ..= ("nil" .. tostring(i) .. ", ")
            end

            return (string.sub(pseudocode, 1, -3) .. ")") -- sub gets rid of the last ", "
        end
    end

    local lines = {}
    local argLines = {}
    local logs = {}
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
            if not string.match(tostring(i), name) and spyFunctions[idxs[v[1]]].Enabled then -- check for if the remote actually had a log made
                v[2].Visible = false
                v[4].Visible = false
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
    
    _G.mainWindow = RenderWindow.new("Remote Spy")

    local mainWindow = _G.mainWindow
    pushTheme(mainWindow)

    local width = 536
    mainWindow.DefaultSize = Vector2.new(width, 350)
    mainWindow.MinSize = Vector2.new(width, 350)
    mainWindow.MaxSize = Vector2.new(width, 5000)
    mainWindow.VisibilityOverride = true

    local frontPage = mainWindow:Dummy()
    local remotePage = mainWindow:Dummy()

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
    end

    local topBar = remotePage:SameLine()

    do -- topbar code

        local exitButtonFrame = topBar:Dummy()
        exitButtonFrame:SetColor(RenderColorOption.Button, black, 0)
        local exitButton = exitButtonFrame:Indent(width-39):Button()
        exitButton.Label = "\xef\x80\x8d"
        exitButton.OnUpdated:Connect(unloadRemote)

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
        remoteIconFrame:SetColor(RenderColorOption.Text, Color3.fromRGB(254, 254, 0), 1)
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
        ignoreButton.OnUpdated:Connect(function()
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
        end)

        local blockButtonFrame = buttonBar:Dummy()
        blockButtonFrame:SetColor(RenderColorOption.Text, red, 1)
        local blockButton = blockButtonFrame:Button()
        blockButton.Label = "Block"
        blockButton.OnUpdated:Connect(function()
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
        end)

        local clearLogsButton = buttonBar:Button()
        clearLogsButton.Label = "Clear Logs"
        clearLogsButton.OnUpdated:Connect(function()
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
                    addSpacer(remotePageObjects.MainWindow, 8)
                end
            end
        end)

        local copyPathButton = buttonBar:Button()
        copyPathButton.Label = "Copy Path"
        copyPathButton.OnUpdated:Connect(function()
            if currentSelectedRemote then
                local str = getInstancePath(currentSelectedRemote)
                if type(str) == "string" then
                    setclipboard(str)
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
        local mainWindow = remoteArgFrame:Child()
        remotePageObjects.MainWindow = mainWindow
    end

    local function createCSButton(window, call)
        local button = window:Button()
        button.Label = "Get Calling Script"
        button.OnUpdated:Connect(function()
            local localType = (typeof(call.Script) == "Instance") and call.Script.ClassName
            local str = (localType == "LocalScript" or localType == "ModuleScript") and getInstancePath(call.Script) -- not sure if getcallingscript can return a ModuleScript, I assume it can't, but adding this just in case
            if type(str) == "string" then
                setclipboard(str)
            else
                pushError("Failed to get Calling Script")
            end
        end)
    end

    local function createRepeatCallButton(window, call, self)
        local button = window:Button()
        button.Label = "Repeat Call"
        button.OnUpdated:Connect(function()
            if call.NilCount == 0 then
                if not pcall(spyFunctions[idxs[call.Type]].Function, self, unpack(call.Args)) then
                    pushError("Failed to Repeat Call")
                end
            else
                if not pcall(loadstring(genPseudo(self, call))) then
                    pushError("Failed to Repeat Call (Variant 2)")
                end
            end
        end)
    end

    local function createGenPCButton(window, call, self)
        local button = window:Button()
        button.Label = "Generate Pseudocode"
        button.OnUpdated:Connect(function()
            setclipboard(genPseudo(self, call))
        end)
    end

    local function makeRemoteViewerLog(window, call, remote)
        local totalArgCount = #call.Args + call.NilCount
        local tempMain = window:Dummy()
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
    searchBar = topBar:TextBox()
    searchBar.Size = Vector2.new(width-188, 24)
    searchBar.OnUpdated:Connect(filterLines)
    
    local searchButton = topBar:Button()
    searchButton.Label = "Search"
    searchButton.OnUpdated:Connect(function()
        filterLines(searchBar.Value) -- redundant because i did it above but /shrug
    end)

    local clearButton = topBar:Button()
    clearButton.Label = "Reset"
    clearButton.OnUpdated:Connect(function()
        searchBar.Value = ""
        clearFilter()
    end)

    local sameLine = frontPage:SameLine()

    for i,v in spyFunctions do
        if i == 3 then
            sameLine = frontPage:SameLine()
        end
        local tempLine = sameLine:Dummy()
        tempLine:SetColor(RenderColorOption.Text, v.Color, 1)
        
        local btn = tempLine:CheckBox()
        btn.Label = v.Icon
        btn.Value = v.Enabled

        sameLine:Label(v.Name)
        
        btn.OnUpdated:Connect(function(enabled)
            spyFunctions[i].Enabled = enabled
            updateLines(v.Name, enabled)
        end)
    end

    -- below the above loop so that it gets placed on the bottom row of options
    local clearAllLogsFrame = sameLine:Indent(width-108) -- 100 because button is 92 wide, plus 8 px padding on right edge, plus 8px because left edge is over intended by 8
    local clearAllLogsButton = clearAllLogsFrame:Button()
    clearAllLogsButton.Label = "Clear All Logs"
    clearAllLogsButton.OnUpdated:Connect(function()
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
    end)

    frontPage:Separator()

    
    frontPage:SetColor(RenderColorOption.ChildBg, colorOptions.TitleBg[1], 1)
    frontPage:SetStyle(RenderStyleOption.ChildRounding, 5)

    local childWindow = frontPage:Child()
    childWindow:SetStyle(RenderStyleOption.ItemSpacing, Vector2.new(4, 0))
    childWindow:SetStyle(RenderStyleOption.FrameRounding, 3)
    addSpacer(childWindow, 8)

    local function makeCopyPathButton(sameLine, self)
        local copyPathButton = sameLine:Button()
        copyPathButton.Label = "Copy Path"

        copyPathButton.OnUpdated:Connect(function()
            local str = getInstancePath(self)
            if type(str) == "string" then
                setclipboard(str)
            else
                pushError("Failed to Copy Path")
            end
        end)
    end

    local function makeClearLogsButton(sameLine, self)
        local clearLogsButton = sameLine:Button()
        clearLogsButton.Label = "Clear Logs"

        clearLogsButton.OnUpdated:Connect(function()
            table.clear(logs[self].Calls)
            lines[self][3].Label = "0"
            if not logs[self].Ignored then
                lines[self][2].Visible = false
                lines[self][4].Visible = false
            end
        end)
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

        ignoreButton.OnUpdated:Connect(function()
            if logs[self].Ignored then
                logs[self].Ignored = false
                ignoreButton.Label = "Ignore"
                spoofLine:SetColor(RenderColorOption.Text, red, 1)
            else
                logs[self].Ignored = true
                ignoreButton.Label = "Unignore"
                spoofLine:SetColor(RenderColorOption.Text, green, 1)
            end
        end)
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

        blockButton.OnUpdated:Connect(function()
            if logs[self].Blocked then
                logs[self].Blocked = false
                spoofLine:SetColor(RenderColorOption.Text, red, 1)
                blockButton.Label = "Block"
            else
                logs[self].Blocked = true
                spoofLine:SetColor(RenderColorOption.Text, green, 1)
                blockButton.Label = "Unblock"
            end
        end)
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
        sameButtonLine.Size = Vector2.new(width-32-14, 32) -- minus 32 because 4x 8px spacers, minus 14 because scrollbar
        addSpacer(sameButtonLine, 4)
        sameButtonLine = sameButtonLine:SameLine()

        local remoteButton = sameButtonLine:Indent(6):Selectable()
        remoteButton.Label = spaces .. purifyString(self.Name, false) 
        remoteButton.Size = Vector2.new(width-327-4-14, 24)
        remoteButton.OnUpdated:Connect(function()
            loadRemote(self, data)
        end)

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

        lines[self] = line
        filterLines(searchBar.Value)
    end

    local function updateLogs(self, data)
        table.insert(logs[self].Calls, data)
        if (spyFunctions[idxs[data.Type]].Enabled) then -- probably should've made spyFunctions a dict
            if lines[self] then
                local callAmt = #logs[self].Calls
                if callAmt == 1 then
                    lines[self][2].Visible = true
                    lines[self][4].Visible = true
                end
                local callStr = (callAmt < 1000 and tostring(callAmt)) or "999+"
                lines[self][3].Label = callStr
            else
                renderNewLog(self, data)
            end
        end

        if currentSelectedRemote == self then
            makeRemoteViewerLog(remotePageObjects.MainWindow, data, self)
        end
    end

    _G.remSpyComms = Instance.new("BindableEvent")
    local comms = _G.remSpyComms
    comms.Event:Connect(updateLogs)
    local commsFunc = comms.Fire

    local filters = {}
    for _,v in spyFunctions do
        table.insert(filters, AllFilter.new({
            InstanceFilter.new(1, v.Name),
            AnyFilter.new({
                NamecallFilter.new(v.Method),
                NamecallFilter.new(v.DeprecatedMethod)
            })
        }))
    end

    local function newHookMetamethod(toHook, mtmethod, hookFunction, filter)
        local oldFunction

        local func = getfilter(filter, function(...) 
            return oldFunction(...)
        end, hookFunction)

        oldFunction = hookmetamethod(toHook, mtmethod, func)
        return oldFunction
    end

    local oldNamecall
    oldNamecall = newHookMetamethod(game, "__namecall", function(self, ...)
        if self == comms then return oldNamecall(self, ...) end

        task.defer(function(...)
            if not logs[self] then
                logs[self] = {
                    Blocked = false,
                    Ignored = false,
                    Calls = {}
                }
            end

            if not logs[self].Ignored then
                local args = {...}
                local argCount = select("#", ...)
                if #args > 7995 or checkCyclic(args) then
                    return
                end
                local data = {
                    Type = self.ClassName,
                    Script = getcallingscript(),
                    Args = args,
                    NilCount = (argCount - #args),
                    FromSynapse = checkcaller()
                }
                commsFunc(comms, self, data)
            end
        end, ...)
        
        if logs[self] and logs[self].Blocked then return end

        return oldNamecall(self, ...)
    end, AnyFilter.new(filters))

    for i,v in spyFunctions do

        local oldfunc
        local newfunction = function(self, ...)
            if self == comms then return oldfunc(self, ...) end

            task.defer(function(...)
                if not logs[self] then
                    logs[self] = {
                        Blocked = false,
                        Ignored = false,
                        Calls = {}
                    }
                end

                if not logs[self].Ignored then
                    local args = {...}
                    local argCount = select("#", ...)
                    if argCount > 7995 or checkCyclic(args) then
                        return
                    end

                    local data = {
                        Type = v.Name,
                        Script = getcallingscript(),
                        Args = args,
                        NilCount = (argCount - #args), -- vuln patch
                        FromSynapse = checkcaller()
                    }
                    commsFunc(comms, self, data)
                end
            end, ...)

            if not logs[self] or not logs[self].Blocked then
                return oldfunc(self, ...)
            end
        end

        oldfunc = hookfunction(Instance.new(v.Name)[v.Method], newcclosure(newfunction), InstanceFilter.new(1, v.Name))

        spyFunctions[i].Function = newfunction
    end
else
    _G.mainWindow = nil
    if _G.remSpyComms then
        _G.remSpyComms:Destroy()
    end
    restorefunction(Instance.new("RemoteEvent").FireServer)
    restorefunction(Instance.new("RemoteFunction").InvokeServer)
    restorefunction(Instance.new("BindableEvent").Fire)
    restorefunction(Instance.new("BindableFunction").Invoke)
    restorefunction(getrawmetatable(game).__namecall)
end

-- CREDIT TO https://github.com/Upbolt/Hydroxide/ FOR INSPIRATION AND A FEW COPIED TOSTRING FUNCTIONS
