-- CREDIT TO https://github.com/Upbolt/Hydroxide/ FOR INSPIRATION AND A FEW FORKED TOSTRING FUNCTIONS

--[[ TO DO:
    * Add tuple support for return value in recieving pseudocode
    * Make main window remote list use popups (depends on OnRightClick)
    * Make arg list use right click (depends on defcon)
    * Currently, deepClone sets unclonable objects to be userdatas with custom __tostring metamethods, but if the call is repeated, the userdatas get thrown away (for being in the args of the new call), making them not appear in the second call.  One solution is to somehow pass a key to the userdata that will verify it is from Synapse, another is to check the caller whenever allowing userdatas, but neither of these solutions seem perfectly clean to me.  Once a good solution is found, it will be implemented. Best solution is likely to set one of the metamethods to a function stored in the remotespy, so that it can be compared later.  It'd be impossible for the game to get the value because of how the arg gets filtered out by roblox.

    * Need to rewrite remotespy to break it down into multiple files
        - One file for frontend, one for backend, one for pseudocode generation, one for initiation.
            - Backend stores the data safely and calls the frontend's functions to tell it when to render.
            - Frontend renders the calls
            - Frontend renders buttons that call pseudcode generation functions with data from the backend.
]]

local mt = getrawmetatable(game)
if islclosure(mt.__namecall) or islclosure(mt.__index) or islclosure(mt.__newindex) then
    error("script incompatibility detected, one of your scripts has set the game's metamethods to a luaclosure, please run the remotespy prior to that script")
end

local execType, build = identifyexecutor()

if execType == nil or build == nil then
    error("THIS EXECUTOR IS NOT SUPPORTED")
    return
end

if execType ~= "Synapse X" then
    error("THIS EXECUTOR IS NOT SUPPORTED")
    return
end

if string.split(build, "/")[1] ~= "v3" then
    error("THIS EXECUTOR IS NOT SUPPORTED")
    return
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
        if not game:IsLoaded() then game.Loaded:Wait() end
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

local isHookThread, getCallStack, getOriginalThread, getDebugId, getThreadIdentity, setThreadIdentity, getn, ceil, floor, colorHSV, colorRGB, tableInsert, tableClear, tableRemove, deferFunc, spawnFunc, gsub, rep, sub, split, strformat, lower, match = syn.oth.is_hook_thread, debug.getcallstack, syn.oth.get_original_thread, game.GetDebugId, syn.get_thread_identity, syn.set_thread_identity, table.getn, math.ceil, math.floor, Color3.fromHSV, Color3.fromRGB, table.insert, table.clear, table.remove, task.defer, task.spawn, string.gsub, string.rep, string.sub, string.split, string.format, string.lower, string.match

local IsDescendantOf = game.IsDescendantOf

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

    for _,v in getweakdescendants(game) do
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

local instanceTrackerFunctionString = [[local function GetInstanceFromDebugId(id: string): Instance
    for _,v in getnilinstances() do
        if v:GetDebugId() == id then
            return v
        end
    end

    for _,v in getweakdescendants(game) do
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

local function resizeText(original: string, newWidth: number, proceedingChars: string, font: RenderFont)  -- my fix using this and purifyString is pretty garbage as it brute forces the string size, but before that it makes a really rough guess on the maximum length of the string, allowing for general optimization for speed, but it isn't perfect.  The current system is **enough**, taking approx 370 microseconds, but could be improved greatly.  Fundamentally, this fix is also flawed because of how hard coded it is, and how unnecessarily it passes args through getArgString.
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

local function newHookMetamethod(toHook, mtmethod: string, hookFunction, filter: FilterBase)
    local oldFunction

    local func = getfilter(filter, function(...) 
        return oldFunction(...)
    end, hookFunction)

    restorefunction(getrawmetatable(toHook)[mtmethod]) -- restores any old hooks
    oldFunction = othHook(getrawmetatable(toHook)[mtmethod], func) -- hookmetamethod(toHook, mtmethod, func) 
    return oldFunction
end

local function filteredOth(toHook, hookFunction, filter: FilterBase)
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

local function outputData(source: string, destination: number, destinationTitle: string, successMessage: string)
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

local specialTypes = {
    RBXScriptConnection = "Connection",
    RBXScriptSignal = "EventInstance",
    BrickColor = "int",
    Rect = "Rect2D",
    EnumItem = "token",
    Enums = "void",
    Enum = "void",
    OverlapParams = "void",
    userdata = "void",
    RotationCurveKey = "void",
    ["function"] = "Function",
    table = "Table"
}

local axis = Enum.Axis
local normalId = Enum.NormalId

local bindableUserdataClone = {
    Axes = function(original: Axes): Axes
        local args = {}
        if original.X and not original.Left and not original.Right then
            tableInsert(args, axis.X)
        elseif original.Left then
            tableInsert(args, normalId.Left)
        end
        if original.Right then
            tableInsert(args, normalId.Right)
        end

        if original.Y and not original.Top and not original.Bottom then
            tableInsert(args, axis.Y)
        elseif original.Top then
            tableInsert(args, normalId.Top)
        end
        if original.Bottom then
            tableInsert(args, normalId.Bottom)
        end

        if original.Z and not original.Front and not original.Back then
            tableInsert(args, axis.Z)
        elseif original.Front then
            tableInsert(args, normalId.Front)
        end
        if original.Back then
            tableInsert(args, normalId.Back)
        end

        return Axes.new(unpack(args))
    end,
    BrickColor = function(original: BrickColor): BrickColor
        return BrickColor.new(original.Number)
    end,
    CatalogSearchParams = function(original: CatalogSearchParams): CatalogSearchParams
        local clone: CatalogSearchParams = CatalogSearchParams.new()
        clone.AssetTypes = original.AssetTypes
        clone.BundleTypes = original.BundleTypes
        clone.CategoryFilter = original.CategoryFilter
        clone.MaxPrice = original.MaxPrice
        clone.MinPrice = original.MinPrice
        clone.SearchKeyword = original.SearchKeyword
        clone.SortType = original.SortType

        return clone
    end,
    CFrame = function(original: CFrame): CFrame
        return CFrame.fromMatrix(original.Position, original.XVector, original.YVector, original.ZVector)
    end,
    Color3 = function(original: Color3): Color3
        return colorRGB(original.R, original.G, original.B)
    end,
    ColorSequence = function(original: ColorSequence): ColorSequence
        return ColorSequence.new(original.Keypoints)
    end,
    ColorSequenceKeypoint = function(original: ColorSequenceKeypoint): ColorSequenceKeypoint
        return ColorSequenceKeypoint.new(original.Time, original.Value)
    end,
    DateTime = function(original: DateTime): DateTime
        return DateTime.fromUnixTimestamp(original.UnixTimestamp)
    end,
    DockWidgetPluginGuiInfo = function(original: DockWidgetPluginGuiInfo): DockWidgetPluginGuiInfo
        local arguments = split(tostring(original), " ")
        local dockState: string = sub(arguments[1], 18, -1)
        local initialEnabled: boolean = tonumber(sub(arguments[2], 16, -1)) ~= 0
        local initialShouldOverride: boolean = tonumber(sub(arguments[3], 38, -1)) ~= 0
        local floatX: number = tonumber(sub(arguments[4], 15, -1)) 
        local floatY: number = tonumber(sub(arguments[5], 15, -1))
        local minWidth: number = tonumber(sub(arguments[6], 10, -1))
        local minHeight: number = tonumber(sub(arguments[7], 11, -1))
        -- can't read the properties so i have to tostring first :(

        return DockWidgetPluginGuiInfo.new(Enum.InitialDockState[dockState], initialEnabled, initialShouldOverride, floatX, floatY, minWidth, minHeight)
    end,
    Enum = function(original: Enum): Enum
        --return original -- enums don't gc
        return false -- doesn't get sent
    end,
    EnumItem = function(original: EnumItem): EnumItem
        return original -- enums don't gc
    end,
    Enums = function(original: Enums): Enums
        --return original -- enums don't gc
        return false -- doesn't get sent
    end,
    Faces = function(original: Faces): Faces
        local args = {}
        if original.Top then
            tableInsert(args, normalId.Top)
        end
        if original.Bottom then
            tableInsert(args, normalId.Bottom)
        end
        if original.Left then
            tableInsert(args, normalId.Left)
        end
        if original.Right then
            tableInsert(args, normalId.Right)
        end
        if original.Back then
            tableInsert(args, normalId.Back)
        end
        if original.Front then
            tableInsert(args, normalId.Front)
        end

        return Faces.new(unpack(args))
    end,
    FloatCurveKey = function(original: FloatCurveKey): FloatCurveKey
        return FloatCurveKey.new(original.Time, original.Value, original.Interpolation)
    end,
    Font = function(original: Font): Font
        local clone: Font = Font.new(original.Family, original.Weight, original.Style)
        clone.Bold = original.Bold

        return clone
    end,
    Instance = function(original: Instance): Instance
        return cloneref(original)
    end,
    NumberRange = function(original: NumberRange): NumberRange
        return NumberRange.new(original.Min, original.Max)
    end,
    NumberSequence = function(original: NumberSequence): NumberSequence
        return NumberSequence.new(original.Keypoints)
    end,
    NumberSequenceKeypoint = function(original: NumberSequenceKeypoint): NumberSequenceKeypoint
        return NumberSequenceKeypoint.new(original.Time, original.Value, original.Envelope)
    end,
    OverlapParams = function(original: OverlapParams): OverlapParams
        --[[local clone: OverlapParams = OverlapParams.new()
        clone.CollisionGroup = original.CollisionGroup
        clone.FilterDescendantsInstances = original.FilterDescendantsInstances
        clone.FilterType = original.FilterType
        clone.MaxParts = original.MaxParts

        return clone]]
        return false -- doesn't get sent
    end,
    PathWaypoint = function(original: PathWaypoint): PathWaypoint
        return PathWaypoint.new(original.Position, original.Action)
    end,
    PhysicalProperties = function(original: PhysicalProperties): PhysicalProperties
        return PhysicalProperties.new(original.Density, original.Friction, original.Elasticity, original.FrictionWeight, original.ElasticityWeight)
    end,
    Random = function(original: Random): Random
        --return original:Clone()
        return false -- doesn't get sent
    end,
    Ray = function(original: Ray): Ray
        return Ray.new(original.Origin, original.Direction)
    end,
    RaycastParams = function(original: RaycastParams): RaycastParams
        local clone: RaycastParams = RaycastParams.new()
        clone.CollisionGroup = original.CollisionGroup
        clone.FilterDescendantsInstances = original.FilterDescendantsInstances
        clone.FilterType = original.FilterType
        clone.IgnoreWater = original.IgnoreWater

        return clone
    end,
    RaycastResult = function(original: RaycastResult): RaycastResult
        local params: RaycastParams = RaycastParams.new()
        params.IgnoreWater = original.Material.Name ~= "Water"
        params.FilterType = Enum.RaycastFilterType.Whitelist
        params.FilterDescendantsInstances = { original.Instance }

	    local startPos: Vector3 = original.Position+(original.Distance*original.Normal)

        return workspace:Raycast(startPos, CFrame.lookAt(startPos, original.Position).LookVector*math.ceil(original.Distance), params)
    end,
    RBXScriptConnection = function(original: RBXScriptConnection): RBXScriptConnection
        return nil -- can't be sent, unsupported, another option is to send the original, but that's detectable
    end,
    RBXScriptSignal = function(original: RBXScriptSignal): RBXScriptSignal
        return nil -- can't be sent, unsupported
    end,
    Rect = function(original: Rect): Rect
        return Rect.new(original.Min, original.Max)
    end,
    Region3 = function(original: Region3): Region3
        local center = original.CFrame.Position

        return Region3.new(center-original.Size/2, center+original.Size/2)
    end,
    Region3int16 = function(original: Region3int16): Region3int16
        return Region3int16.new(original.Min, original.Max)
    end,
    RotationCurveKey = function(original: RotationCurveKey): RotationCurveKey
        --return RotationCurveKey.new(original.Time, original.Value, original.Interpolation)
        return false -- doesn't get sent
    end,
    TweenInfo = function(original: TweenInfo): TweenInfo
        return TweenInfo.new(original.Time, original.EasingStyle, original.EasingDirection, original.RepeatCount, original.Reverses, original.DelayTime)
    end,
    UDim = function(original: UDim): UDim
        return UDim.new(original.Scale, original.Offset)
    end,
    UDim2 = function(original: UDim2): UDim2
        -- I've tested it and confirmed that even though they share identical X and Y userdata properties, they do not reference the same thing, and so gcing will not detect this.
        return UDim2.new(original.X, original.Y)
    end,
    userdata = function(original) -- no typechecking for userdatas like this (newproxy)
        return false -- doesn't get sent
    end,
    Vector2 = function(original: Vector2): Vector2
        return Vector2.new(original.X, original.Y)
    end,
    Vector2int16 = function(original: Vector2int16): Vector2int16
        return Vector2int16.new(original.X, original.Y)
    end,
    Vector3 = function(original: Vector3): Vector3
        return Vector3.new(original.X, original.Y, original.Z)
    end,
    Vector3int16 = function(original: Vector3int16): Vector3int16
        return Vector3int16.new(original.X, original.Y, original.Z)
    end
}

local remoteUserdataClone = {
    Axes = function(original: Axes): Axes
        local args = {}
        if original.X and not original.Left and not original.Right then
            tableInsert(args, axis.X)
        elseif original.Left then
            tableInsert(args, normalId.Left)
        end
        if original.Right then
            tableInsert(args, normalId.Right)
        end

        if original.Y and not original.Top and not original.Bottom then
            tableInsert(args, axis.Y)
        elseif original.Top then
            tableInsert(args, normalId.Top)
        end
        if original.Bottom then
            tableInsert(args, normalId.Bottom)
        end

        if original.Z and not original.Front and not original.Back then
            tableInsert(args, axis.Z)
        elseif original.Front then
            tableInsert(args, normalId.Front)
        end
        if original.Back then
            tableInsert(args, normalId.Back)
        end

        return Axes.new(unpack(args))
    end,
    BrickColor = function(original: BrickColor): BrickColor
        return BrickColor.new(original.Number)
    end,
    CatalogSearchParams = function(original: CatalogSearchParams): CatalogSearchParams
        --[[local clone: CatalogSearchParams = CatalogSearchParams.new()
        clone.AssetTypes = original.AssetTypes
        clone.BundleTypes = original.BundleTypes
        clone.CategoryFilter = original.CategoryFilter
        clone.MaxPrice = original.MaxPrice
        clone.MinPrice = original.MinPrice
        clone.SearchKeyword = original.SearchKeyword
        clone.SortType = original.SortType

        return clone]]
        return false -- doesn't get sent
    end,
    CFrame = function(original: CFrame): CFrame
        return CFrame.fromMatrix(original.Position, original.XVector, original.YVector, original.ZVector)
    end,
    Color3 = function(original: Color3): Color3
        return colorRGB(original.R, original.G, original.B)
    end,
    ColorSequence = function(original: ColorSequence): ColorSequence
        return ColorSequence.new(original.Keypoints)
    end,
    ColorSequenceKeypoint = function(original: ColorSequenceKeypoint): ColorSequenceKeypoint
        return ColorSequenceKeypoint.new(original.Time, original.Value)
    end,
    DateTime = function(original: DateTime): DateTime
        return DateTime.fromUnixTimestamp(original.UnixTimestamp)
    end,
    DockWidgetPluginGuiInfo = function(original: DockWidgetPluginGuiInfo): DockWidgetPluginGuiInfo
        --[[local arguments = split(tostring(original), " ")
        local dockState: string = sub(arguments[1], 18, -1)
        local initialEnabled: boolean = tonumber(sub(arguments[2], 16, -1)) ~= 0
        local initialShouldOverride: boolean = tonumber(sub(arguments[3], 38, -1)) ~= 0
        local floatX: number = tonumber(sub(arguments[4], 15, -1)) 
        local floatY: number = tonumber(sub(arguments[5], 15, -1))
        local minWidth: number = tonumber(sub(arguments[6], 10, -1))
        local minHeight: number = tonumber(sub(arguments[7], 11, -1))
        -- can't read the properties so i have to tostring first :(
            
        return DockWidgetPluginGuiInfo.new(Enum.InitialDockState[dockState], initialEnabled, initialShouldOverride, floatX, floatY, minWidth, minHeight)]]
        return false -- doesn't get sent
    end,
    Enum = function(original: Enum): Enum
        --return original -- enums don't gc
        return false -- doesn't get sent
    end,
    EnumItem = function(original: EnumItem): EnumItem
        return original -- enums don't gc
    end,
    Enums = function(original: Enums): Enums
        --return original -- enums don't gc
        return false -- doesn't get sent
    end,
    Faces = function(original: Faces): Faces
        local args = {}
        if original.Top then
            tableInsert(args, normalId.Top)
        end
        if original.Bottom then
            tableInsert(args, normalId.Bottom)
        end
        if original.Left then
            tableInsert(args, normalId.Left)
        end
        if original.Right then
            tableInsert(args, normalId.Right)
        end
        if original.Back then
            tableInsert(args, normalId.Back)
        end
        if original.Front then
            tableInsert(args, normalId.Front)
        end

        return Faces.new(unpack(args))
    end,
    FloatCurveKey = function(original: FloatCurveKey): FloatCurveKey
        --return FloatCurveKey.new(original.Time, original.Value, original.Interpolation)
        return false -- doesn't get sent
    end,
    Font = function(original: Font): Font
        local clone: Font = Font.new(original.Family, original.Weight, original.Style)
        clone.Bold = original.Bold

        return clone
    end,
    Instance = function(original: Instance): Instance
        return cloneref(original)
    end,
    NumberRange = function(original: NumberRange): NumberRange
        return NumberRange.new(original.Min, original.Max)
    end,
    NumberSequence = function(original: NumberSequence): NumberSequence
        return NumberSequence.new(original.Keypoints)
    end,
    NumberSequenceKeypoint = function(original: NumberSequenceKeypoint): NumberSequenceKeypoint
        return NumberSequenceKeypoint.new(original.Time, original.Value, original.Envelope)
    end,
    OverlapParams = function(original: OverlapParams): OverlapParams
        --[[local clone: OverlapParams = OverlapParams.new()
        clone.CollisionGroup = original.CollisionGroup
        clone.FilterDescendantsInstances = original.FilterDescendantsInstances
        clone.FilterType = original.FilterType
        clone.MaxParts = original.MaxParts

        return clone]]
        return false -- doesn't get sent
    end,
    PathWaypoint = function(original: PathWaypoint): PathWaypoint
        return PathWaypoint.new(original.Position, original.Action)
    end,
    PhysicalProperties = function(original: PhysicalProperties): PhysicalProperties
        return PhysicalProperties.new(original.Density, original.Friction, original.Elasticity, original.FrictionWeight, original.ElasticityWeight)
    end,
    Random = function(original: Random): Random
        --return original:Clone()
        return false -- doesn't get sent
    end,
    Ray = function(original: Ray): Ray
        return Ray.new(original.Origin, original.Direction)
    end,
    RaycastParams = function(original: RaycastParams): RaycastParams
        --[[local clone: RaycastParams = RaycastParams.new()
        clone.CollisionGroup = original.CollisionGroup
        clone.FilterDescendantsInstances = original.FilterDescendantsInstances
        clone.FilterType = original.FilterType
        clone.IgnoreWater = original.IgnoreWater

        return clone]]
        return false -- doesn't get sent
    end,
    RaycastResult = function(original: RaycastResult): RaycastResult
        --[[local params: RaycastParams = RaycastParams.new()
        params.IgnoreWater = original.Material.Name ~= "Water"
        params.FilterType = Enum.RaycastFilterType.Whitelist
        params.FilterDescendantsInstances = { original.Instance }

	    local startPos: Vector3 = original.Position+(original.Distance*original.Normal)

        return workspace:Raycast(startPos, CFrame.lookAt(startPos, original.Position).LookVector*math.ceil(original.Distance), params)]]
        return false -- doesn't get sent
    end,
    RBXScriptConnection = function(original: RBXScriptConnection): RBXScriptConnection
        return false -- doesn't get sent
    end,
    RBXScriptSignal = function(original: RBXScriptSignal): RBXScriptSignal
        return false -- doesn't get sent
    end,
    Rect = function(original: Rect): Rect
        return Rect.new(original.Min, original.Max)
    end,
    Region3 = function(original: Region3): Region3
        local center = original.CFrame.Position

        return Region3.new(center-original.Size/2, center+original.Size/2)
    end,
    Region3int16 = function(original: Region3int16): Region3int16
        return Region3int16.new(original.Min, original.Max)
    end,
    RotationCurveKey = function(original: RotationCurveKey): RotationCurveKey
        --return RotationCurveKey.new(original.Time, original.Value, original.Interpolation)
        return false -- doesn't get sent
    end,
    TweenInfo = function(original: TweenInfo): TweenInfo
        --return TweenInfo.new(original.Time, original.EasingStyle, original.EasingDirection, original.RepeatCount, original.Reverses, original.DelayTime)
        return false -- doesn't get sent
    end,
    UDim = function(original: UDim): UDim
        return UDim.new(original.Scale, original.Offset)
    end,
    UDim2 = function(original: UDim2): UDim2
        -- I've tested it and confirmed that even though they share identical X and Y userdata properties, they do not reference the same thing, and so gcing will not detect this.
        return UDim2.new(original.X, original.Y)
    end,
    userdata = function(original) -- no typechecking for userdatas like this (newproxy)
        return false -- doesn't get sent
    end,
    Vector2 = function(original: Vector2): Vector2
        return Vector2.new(original.X, original.Y)
    end,
    Vector2int16 = function(original: Vector2int16): Vector2int16
        return Vector2int16.new(original.X, original.Y)
    end,
    Vector3 = function(original: Vector3): Vector3
        return Vector3.new(original.X, original.Y, original.Z)
    end,
    Vector3int16 = function(original: Vector3int16): Vector3int16
        return Vector3int16.new(original.X, original.Y, original.Z)
    end
}

local function cloneUserdata(userdata: any, remoteType: string): any
    local cloneTable = (remoteType == "BindableEvent" or remoteType == "BindableFunction") and bindableUserdataClone or remoteUserdataClone
    local userdataType = typeof(userdata)
    local func = cloneTable[userdataType]
    if not func then -- func was false
        pushError("Unknown Userdata: \"" .. userdataType .. ",\" please report to GameGuy#5286")
        local clone = newproxy(true)
        getmetatable(clone).__tostring = function()
            return userdataType
        end
        return clone -- userdata that I have never seen before
    else
        local clone = func(userdata)
        if clone == nil then
            clone = newproxy(true)
            getmetatable(clone).__tostring = function()
                return userdataType -- be careful here, if I were to put typeof(userdata) in, it would pass userdata as an upvalue, which would cause it to never gc, leading to a detection.
            end
            return clone -- userdatas are reserved for unclonable types because they can never be sent to the server
        elseif not clone then
            return -- userdata isn't sent to the server
        else
            return clone -- good userdata
        end
    end
end

local function getSpecialKey(index: any): string
    local prefix = specialTypes[typeof(index)] or typeof(index)

    local oldMt = getrawmetatable(index)
    local returnStr = ""
    if oldMt then
        local wasReadOnly = isreadonly(oldMt)
        if wasReadOnly then setreadonly(oldMt, false) end
        local oldToString = rawget(oldMt, "__tostring")
        
        rawset(oldMt, "__tostring", nil)
        returnStr = "<" .. prefix .. ">" .. " (" .. tostring(index) .. ")"
        rawset(oldMt, "__tostring", oldToString)
        if wasReadOnly then setreadonly(oldMt, true) end
    else
        returnStr = "<" .. prefix .. ">" .. " (" .. tostring(index) .. ")"
    end

    return returnStr
end

local function cloneData(data: any, callType: string)
    local primType: string = type(data)
    if primType == "userdata" or primType == "vector" then
        if typeof(data) == "Instance" and not IsDescendantOf(data, game) then
            return cloneUserdata(data, callType), true
        end

        return cloneUserdata(data, callType)
    elseif primType == "thread" then
        return -- can't be sent
    elseif primType == "function" and (callType == "RemoteEvent" or callType == "RemoteFunction") then
        return -- can't be sent
    else
        return data -- any non cloneables (numbers, strings, etc)
    end
end

local function createIndex(index: any) -- from my testing, calltype doesn't affect indexes
    local primType = type(index)
    if primType == "userdata" or primType == "vector" or primType == "function" or primType == "table" then
        return getSpecialKey(index)
    else
        return index -- threads and nils are unhandled in this function because neither can be indexed by
    end
end

-- this function should only be used on deepClone({...}), and only on the first table, where we can be sure that it should be all number indices, this is unsafe to use on any other tables.  The first table from deepClone may not be in order (due to nils being weird), so we need a comparison of indices.
local function getLastIndex(tbl): number
    local final: number = 0
    for i in tbl do
        if i > final then
            final = i
        end
    end

    return final
end

local function deepClone(myTable, callType: string, stack: number?) -- cyclic check built in
    stack = stack or 0 -- you can offset stack by setting the starting parameter to a number
    local newTable = {}
    local hasTable = false
    local hasNilParentedInstance = false
    local started = false
    local originalDepth = stack
    local consecutiveIndices = getn(myTable)
    local isConsecutive = (consecutiveIndices ~= 0) and (stack ~= -1) -- consecutives don't count when it's the original data (nils break stuff)

    if stack == 300 then -- this stack overflow check doesn't really matter as a stack overflow check, it's just here to make sure there are no cyclic tables.  While I could just check for cyclics directly, this is faster.
        return false, stack
    end
    for i,v in next, myTable do
        if not isConsecutive or (type(i) == "number" and i <= consecutiveIndices) then
            if not started then started = true; stack += 1 end
            local index = createIndex(i)
            if index then
                local value = nil
                if type(v) == "table" then
                    hasTable = true
                    local newTab, maxStack, _, subHasNilParentedInstance = deepClone(v, callType, originalDepth+1)
                    hasNilParentedInstance = hasNilParentedInstance or subHasNilParentedInstance
                    if maxStack > stack then
                        stack = maxStack
                    end
                    
                    if newTab then
                        value = newTab
                    else
                        return false, stack -- stack overflow
                    end
                else
                    local nilParented
                    value, nilParented = cloneData(v, callType)
                    hasNilParentedInstance = hasNilParentedInstance or nilParented
                end
                newTable[index] = value
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
    ["\""] = "\\\"",
    ["\\"] = "\\\\",
    ["\a"] = "\\a",
    ["\b"] = "\\b",
    ["\t"] = "\\t",
    ["\n"] = "\\n",
    ["\v"] = "\\v",
    ["\f"] = "\\f",
    ["\r"] = "\\r"
}

for Index = 0, 255 do
    if (Index < 32 or Index > 126) then -- only non printable ascii characters
        local character = string.char(Index)
        if not asciiFilteredCharacters[character] then
            asciiFilteredCharacters[character] = "\\" .. Index
        end
    end
end

local function purifyString(str: string, quotes: boolean, maxLength: number)
    if type(maxLength) == "number" then
        str = sub(str, 1, maxLength)
    end
    str = gsub(str, "[\"\\\0-\31\127-\255]", asciiFilteredCharacters)
    if type(maxLength) == "number" then
        str = sub(str, 1, maxLength)
    end
    --[[
        This gsub can be broken down into multiple steps.
        It filters quotations (\") and backslashes "\\" to be replaced,
        Then it filters characters 0-31, and 127-255, replacing them all with their escape sequences
    ]]
    if quotes then
        return "\"" .. str .. "\""
    else
        return str
    end
end

local gameId, workspaceId = getDebugId(game), getDebugId(workspace)

local function instanceParentedToNil(instance: Instance) -- too cursed to use (insanely slow in certain games)
    local instanceId = getDebugId(instance)
    for _,v in getnilinstances() do
        if getDebugId(v) == instanceId then
            return true
        end
    end
end

local function isRemoteEventReplicated(remote: RemoteEvent)
    local _, err = pcall(replicatesignal, remote.OnServerEvent)

    if err == "invalid argument #1 to 'replicatesignal' (this event cannot be replicated)" then
        return false
    end

    return true
end

local function getInstancePath(instance: Instance) -- FORKED FROM HYDROXIDE
    if not instance then return "NIL INSTANCE" end -- probably is impossible, cant be bothered to confirm
    local s = tick()
    setThreadIdentity(8)
    local id = getDebugId(instance)

    local name = instance.Name
    local head = (#name > 0 and '.' .. name) or "['']"
    
    if not instance.Parent and id ~= gameId then
        return "(nil)" .. head .. " --[[ INSTANCE DELETED/PARENTED TO NIL ]]", false
        --if not instanceParentedToNil(instance) then
            --return "(nil)" .. head .. " --[[ INSTANCE DELETED FROM GAME ]]", false
        --else
            --return "(nil)" .. head .. " --[[ PARENTED TO NIL ]]", false
        --end
    end
    
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
local makeUserdataConstructor = {
    Axes = function(original: Axes): Axes
        local constructor: string = "Axes.new("
        if original.X and not original.Left and not original.Right then
            constructor ..= "Enum.Axis.X, "
        elseif original.Left then
            constructor ..= "Enum.NormalId.Left, "
        end
        if original.Right then
            constructor ..= "Enum.NormalId.Right, "
        end

        if original.Y and not original.Top and not original.Bottom then
            constructor ..= "Enum.Axis.Y, "
        elseif original.Top then
            constructor ..= "Enum.NormalId.Top, "
        end
        if original.Bottom then
            constructor ..= "Enum.NormalId.Bottom, "
        end

        if original.Z and not original.Front and not original.Back then
            constructor ..= "Enum.Axis.Z, "
        elseif original.Front then
            constructor ..= "Enum.NormalId.Front, "
        end
        if original.Back then
            constructor ..= "Enum.NormalId.Back, "
        end

        return (constructor ~= "Axes.new(" and sub(constructor, 0, -3) or constructor) .. ")"
    end,
    BrickColor = function(original: BrickColor): string
        return "BrickColor.new(\"" .. original.Name .. "\")"
    end,
    CatalogSearchParams = function(original: CatalogSearchParams): string
        return strformat("(function() local clone: CatalogSearchParams = CatalogSearchParams.new(); clone.AssetTypes = %s; clone.BundleTimes = %s; clone.CategoryFilter = %s; clone.MaxPrice = %s; clone.MinPrice = %s; clone.SearchKeyword = %s; clone.SortType = %s; return clone end)()", tostring(original.AssetTypes), tostring(original.BundleTypes), tostring(original.CategoryFilter), original.MaxPrice, original.MinPrice, original.SearchKeyword, tostring(original.SortType))
    end,
    CFrame = function(original: CFrame): string
        return "CFrame.new(" .. tostring(original) .. ")"
    end,
    Color3 = function(original: Color3): string
        return "Color3.new(" .. tostring(original) .. ")"
    end,
    ColorSequence = function(original: ColorSequence): string
        return "ColorSequence.new(" .. tableToString(original.Keypoints, false) ..")"
    end,
    ColorSequenceKeypoint = function(original: ColorSequenceKeypoint): string
        return "ColorSequenceKeypoint.new(" .. original.Time .. ", Color3.new(" .. tostring(original.Value) .. "))"
    end,
    DateTime = function(original: DateTime): string
        return "DateTime.fromUnixTimestamp(" .. tostring(original.UnixTimestamp) .. ")"
    end,
    DockWidgetPluginGuiInfo = function(original: DockWidgetPluginGuiInfo): string
        local arguments = split(tostring(original), " ")
        local dockState: string = sub(arguments[1], 18, -1)
        local initialEnabled: boolean = tonumber(sub(arguments[2], 16, -1)) ~= 0
        local initialShouldOverride: boolean = tonumber(sub(arguments[3], 38, -1)) ~= 0
        local floatX: number = tonumber(sub(arguments[4], 15, -1)) 
        local floatY: number = tonumber(sub(arguments[5], 15, -1))
        local minWidth: number = tonumber(sub(arguments[6], 10, -1))
        local minHeight: number = tonumber(sub(arguments[7], 11, -1))
        -- can't read the properties so i have to tostring first :(
            
        return strformat("DockWidgetPluginGuiInfo.new(%s, %s, %s, %s, %s, %s, %s)", "Enum.InitialDockState." .. dockState, tostring(initialEnabled), tostring(initialShouldOverride), tostring(floatX), tostring(floatY), tostring(minWidth), tostring(minHeight))
    end,
    Enum = function(original: Enum): string
        return "Enum." .. tostring(original)
    end,
    EnumItem = function(original: EnumItem): string
        return tostring(original)
    end,
    Enums = function(original: Enums): string
        return "Enum"
    end,
    Faces = function(original: Faces): string
        local constructor = "Faces.new("
        if original.Top then
            constructor ..= "Enum.NormalId.Top"
        end
        if original.Bottom then
            constructor ..= "Enum.NormalId.Bottom"
        end
        if original.Left then
            constructor ..= "Enum.NormalId.Left"
        end
        if original.Right then
            constructor ..= "Enum.NormalId.Right"
        end
        if original.Back then
            constructor ..= "Enum.NormalId.Back"
        end
        if original.Front then
            constructor ..= "Enum.NormalId.Front"
        end

        return (constructor ~= "Faces.new(" and sub(constructor, 0, -3) or constructor) .. ")"
    end,
    FloatCurveKey = function(original: FloatCurveKey): string
        return "FloatCurveKey.new(" .. tostring(original.Time) .. ", " .. tostring(original.Value) .. ", "  .. tostring(original.Interpolation) .. ")"
    end,
    Font = function(original: Font): string
        return strformat("(function() local clone: Font = Font.new(%s, %s, %s); clone.Bold = %s; return clone end)()", '"' .. original.Family .. '"', tostring(original.Weight), tostring(original.Style), tostring(original.Bold))
    end,
    Instance = function(original: Instance): string
        return getInstancePath(original)
    end,
    NumberRange = function(original: NumberRange): string
        return "NumberRange.new(" .. tostring(original.Min) .. ", " .. tostring(original.Max) .. ")"
    end,
    NumberSequence = function(original: NumberSequence): string
        return "NumberSequence.new(" .. tableToString(original.Keypoints, false) .. ")"
    end,
    NumberSequenceKeypoint = function(original: NumberSequenceKeypoint): string
        return "NumberSequenceKeypoint.new(" .. tostring(original.Time) .. ", " .. tostring(original.Value) .. ", " .. tostring(original.Envelope) .. ")"
    end,
    OverlapParams = function(original: OverlapParams): OverlapParams
        return strformat("(function(): OverlapParams local clone: OverlapParams = OverlapParams.new(); clone.CollisionGroup = %s; clone.FilterDescendantInstances = %s; clone.FilterType = %s; clone.MaxParts = %s; return clone end)()", original.CollisionGroup, tableToString(original.FilterDescendantsInstances, false, Settings.InstanceTrackerMode), tostring(original.FilterType), tostring(original.MaxParts))
    end,
    PathWaypoint = function(original: PathWaypoint): string
        return "PathWaypoint.new(Vector3.new(" .. tostring(original.Position) .. "), " .. tostring(original.Action) .. ")"
    end,
    PhysicalProperties = function(original: PhysicalProperties): string
        return "PhysicalProperties.new(" .. tostring(original) .. ")"
    end,
    Random = function(original: Random): string
        return "Random.new()" -- detectable cause of seed change
    end,
    Ray = function(original: Ray): string
        return "Ray.new(Vector3.new(" .. tostring(original.Origin) .. "), Vector3.new(" .. tostring(original.Direction) .. "))"
    end,
    RaycastParams = function(original: RaycastParams): string
        return strformat("(function(): RaycastParams local clone: RaycastParams = RaycastParams.new(); clone.CollisionGroup = %s; clone.FilterDescendantsInstances = %s; clone.FilterType = %s; clone.FilterWater = %s; return clone end)()", original.CollisionGroup, tableToString(original.FilterDescendantsInstances, false, Settings.InstanceTrackerMode), tostring(original.FilterType), tostring(original.IgnoreWater))
    end,
    RaycastResult = function(original: RaycastResult): string
        return strformat("(function(): RaycastParams local params: RaycastParams = RaycastParams.new(); params.IgnoreWater = %s; params.FilterType = %s; params.FilterDescendantsInstances = %s; local startPos: Vector3 = %s; return workspace:Raycast(startPos, CFrame.lookAt(startPos, %s).LookVector*math.ceil(%s), params) end)()", tostring(original.Material.Name ~= "Water"), tostring(Enum.RaycastFilterType.Whitelist), tableToString(original.Instance, false, Settings.InstanceTrackerMode), "Vector3.new(" .. original.Position+(original.Distance*original.Normal) .. ")", "Vector3.new(" .. original.Position .. ")", "Vector3.new(" .. original.Distance .. ")")
    end,
    RBXScriptConnection = function(original: RBXScriptConnection): string
        return "nil --[[ RBXScriptConnection is Unsupported ]]"
    end,
    RBXScriptSignal = function(original: RBXScriptSignal): string
        return "nil --[[ RBXScriptSignal is Unsupported ]]"
    end,
    Rect = function(original: Rect): string
        return "Rect.new(Vector2.new(" .. tostring(original.Min) .. "), Vector2.new(" .. tostring(original.Max) .. "))"
    end,
    Region3 = function(original: Region3): string
        local center = original.CFrame.Position

        return "Region3.new(Vector3.new(" .. tostring(center-original.Size/2) .. "), Vector3.new(" .. tostring(center+original.Size/2) .. "))"
    end,
    Region3int16 = function(original: Region3int16): string
        return "Region3int16.new(Vector3int16.new(" .. tostring(original.Min) .. "), Vector3int16.new(" .. tostring(original.Max) .. "))"
    end,
    RotationCurveKey = function(original: RotationCurveKey): RotationCurveKey
        return "RotationCurveKey.new(" .. tostring(original.Time) .. ", CFrame.new(" .. tostring(original.Value) .. "), " .. tostring(original.Interpolation) .. ")"
    end,
    TweenInfo = function(original: TweenInfo): string
        return "TweenInfo.new(" .. tostring(original.Time) .. ", " .. tostring(original.EasingStyle) .. ", " .. tostring(original.EasingDirection) .. ", " .. tostring(original.RepeatCount) .. ", " .. tostring(original.Reverses) .. ", " .. tostring(original.DelayTime) .. ")"
    end,
    UDim = function(original: UDim): string
        return "UDim.new(" .. tostring(original) .. ")"
    end,
    UDim2 = function(original: UDim2): string
        return "UDim2.new(" .. tostring(original) .. ")"
    end,
    userdata = function(original): string -- no typechecking for userdatas like this (newproxy)
        return "nil --[[ " .. tostring(original) .. " is Unsupported ]]" -- newproxies can never be sent, and as such are reserved by the remotespy to be used when a type that could not be deepCloned was sent.  The tostring metamethod should've been modified to refelct the original type.
    end,
    Vector2 = function(original: Vector2): string
        return "Vector2.new(" .. tostring(original) .. ")"
    end,
    Vector2int16 = function(original: Vector2int16): string
        return "Vector2int16.new(" .. tostring(original) .. ")"
    end,
    Vector3 = function(original: Vector3): string
        return "Vector3.new(" .. tostring(original) .. ")"
    end,
    Vector3int16 = function(original: Vector3int16): string
        return "Vector3int16.new(" .. tostring(original) .. ")"
    end
}

local function getUserdataConstructor(userdata: any): string
    local userdataType = typeof(userdata)
    local constructorCreator = makeUserdataConstructor[userdataType]

    if constructorCreator then
        return constructorCreator(userdata)
    else
        return "nil --[[ " .. userdataType .. " is Unsupported ]]"
    end
end

-- localized elsewhere

tableToString = function(data: any, format: boolean, debugMode: boolean, root: any, indents: number) -- FORKED FROM HYDROXIDE
    local dataType = type(data)

    format = format == nil and true or format

    if dataType == "userdata" or dataType == "vector" then
        if typeof(data) == "Instance" then
            local str, parented, bypasses = getInstancePath(data)
            if (debugMode == 3 or (debugMode == 2 and parented)) and not bypasses then
                return ("GetInstanceFromDebugId(\"" .. getDebugId(data) .."\")") .. (" --[[ Original Path: " .. str..(parented and " ]]" or ""))
            else
                return str    
            end
        else
            return getUserdataConstructor(data)
        end
    elseif dataType == "string" then
        local success, result = pcall(purifyString, data, true)
        return (success and result) or tostring(data)
    elseif dataType == "table" then
        indents = indents or 1
        root = root or data

        local head = format and '{\n' or '{ '
        local indent = rep('\t', indents)
        local consecutiveIndices = (#data ~= 0)
        local elementCount = 0
        -- moved checkCyclic check to hook
        if format then
            if consecutiveIndices then
                for i,v in data do
                    elementCount += 1
                    if type(i) ~= "number" then continue end

                    if i ~= elementCount then
                        for _ = 1, (i-elementCount) do
                            head ..= (indent .. "nil,\n")
                        end
                        elementCount = i
                    end
                    head ..= strformat("%s%s,\n", indent, tableToString(v, true, debugMode, root, indents + 1))
                end
            else
                for i,v in data do
                    head ..= strformat("%s[%s] = %s,\n", indent, tableToString(i, true, debugMode, root, indents + 1), tableToString(v, true, debugMode, root, indents + 1))
                end
            end
        else
            if consecutiveIndices then
                for i,v in data do
                    elementCount += 1
                    if type(i) ~= "number" then continue end

                    if i ~= elementCount then
                        for _ = 1, (i-elementCount) do
                            head ..= "nil, "
                        end
                        elementCount = i
                    end
                    head ..= (tableToString(v, false, debugMode, root, indents + 1) .. ", ")
                end
            else
                for i,v in data do
                    head ..= strformat("[%s] = %s, ", tableToString(i, false, debugMode, root, indents + 1), tableToString(v, false, debugMode, root, indents + 1))
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

local function getArgString(arg: any, maxLength: number)
    local t = type(arg)

    if types[t] and t ~= "userdata" then
        local st = types[t]
        return st[2](arg, maxLength), st[1]
    elseif t == "userdata" or t == "vector" then
        local st = getUserdataConstructor(arg)
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

local function genSendPseudo(rem: Instance, call, spyFunc)
    local watermark = Settings.PseudocodeWatermark and watermarkString or ""

    local debugMode = Settings.InstanceTrackerMode

    if debugMode == 3 or (debugMode == 2 and call.HasInstance) then
        watermark ..= (--[[Settings.OptimizedInstanceTracker and optimizedInstanceTrackerFunctionString or]] instanceTrackerFunctionString) .. "\n\n"
    else
        watermark ..= "\n"
    end

    local pathStr, parented = getInstancePath(rem)
    local remPath = ((debugMode == 3 or ((debugMode == 2) and not parented)) and ("GetInstanceFromDebugId(\"" .. getDebugId(rem) .."\")" .. " -- Original Path: " .. pathStr)) or pathStr

    if call.NonNilArgCount == 0 and call.NilCount == 0 then
        if spyFunc.Type == "Call" then
            return watermark .. (Settings.PseudocodeInlineRemote and ("local remote" .. (Settings.PseudocodeLuaUTypes and (": " .. spyFunc.Object) or "").." = " .. remPath .. "\n\n" .. (spyFunc.ReturnsValue and ("local returnValue = ") or "") .. "remote:") or (remPath .. ":")) .. spyFunc.Method .."()"
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

        for i = 1, call.NonNilArgCount do
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
            if primTyp ~= "function" and primTyp ~= "table" and Settings.PseudocodeLuaUTypes then
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
                    varConstructor = getUserdataConstructor(arg)
                end
            elseif primTyp == "table" then
                varConstructor = tableToString(arg, Settings.PseudocodeFormatTables, debugMode)
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
                varConstructor = getUserdataConstructor(arg)
            elseif primTyp == "table" then
                varConstructor = tableToString(arg, Settings.PseudocodeFormatTables, 1)
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

local function genRecvPseudo(rem: Instance, call, spyFunc, watermark: string)
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
        for i = 1,call.NonNilArgCount do
            pseudocode ..= "p" .. tostring(i) .. ", "
        end
        pseudocode = (sub(pseudocode, 1, -3) .. ")")

        pseudocode ..= "\n\tprint("
        for i = 1,call.NonNilArgCount do
            pseudocode ..= "p"..tostring(i) .. ", "
        end
        pseudocode = (sub(pseudocode, 1, -3) .. ")")

        pseudocode ..= "\nend)"
        return watermark .. pseudocode
    elseif spyFunc.Type == "Callback" then
        local pseudocode = ""

        pseudocode ..= Settings.PseudocodeInlineRemote and ("local remote" .. (Settings.PseudocodeLuaUTypes and (": " .. spyFunc.Object) or "").." = " .. remPath .. "\nremote." .. spyFunc.Callback .. " = function(") or (remPath .. "." .. spyFunc.Callback .. " = function(")
        for i = 1,call.NonNilArgCount do
            pseudocode ..= "p"..tostring(i) .. ", "
        end
        pseudocode = (sub(pseudocode, 1, -3) .. ")")

        pseudocode ..= "\n\tprint("
        for i = 1,call.NonNilArgCount do
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
local remoteBlacklistCache = setmetatable({}, {__mode="kv"}) -- used to store remotes that aren't replicated to the server
-- remoteBlacklistCache[remote] = nil or 1 or 2, 1 = allowed, 2 = blacklisted, nil = not initialized

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
    checkBox4.Label = "Cache Unselected Types' Calls"
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
    creditsTab:Label("Written by GameGuy")
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

local function createCSButton(window: RenderWindow, call, spyFunc)
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

local function createCSDecompileButton(window: RenderWindow, call, spyFunc)
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

local function repeatCall(call, remote: Instance, remoteId: string, spyFunc, repeatCount: number)
    if spyFunc.Type == "Call" then
        local func = spyFunc.Function
        
        local success, result = pcall(function()
            if spyFunc.ReturnsValue then
                for _ = 1,repeatCount do
                    originalCallerCache[remoteId] = {nil, true}
                    spawnFunc(func, remote, unpack(call.Args, 1, call.NonNilArgCount + call.NilCount))
                end
            else
                for _ = 1,repeatCount do
                    spawnFunc(func, remote, unpack(call.Args, 1, call.NonNilArgCount + call.NilCount)) -- shouldn't be task.spawned but needs to be because of oth.hook being weird
                end
            end
        end)
        if not success then
            pushError("Failed to Repeat Call", result)
        end
    elseif spyFunc.Type == "Callback" then
        local success, result = pcall(function()
            for _ = 1,repeatCount do
                spawnFunc(call.CallbackLog.CurrentFunction, unpack(call.Args, 1, call.NonNilArgCount + call.NilCount)) -- always spawned to make callstack look legit
            end
        end)
        if not success then
            pushError("Failed to Repeat Callback Call", result)
        end
    elseif spyFunc.Type == "Connection" then
        local success, result = pcall(function()
            for _ = 1,repeatCount do
                originalCallerCache[remoteId] = {nil, true}
                cfiresignal(call.Signal, unpack(call.Args, 1, call.NonNilArgCount + call.NilCount))
            end
        end)
        if not success then
            pushError("Failed to Repeat Connection", result)
        end
    end
end

local function createRepeatCallButton(window: RenderWindow, call, remote: Instance, remoteId, spyFunc, amt) -- NEEDS TO BE REDONE FOR CONS AND CALLBACKS
    local button = window:Selectable()
    button.Label = amt and ("Repeat Call x" .. tostring(amt)) or "Repeat Call"
    button.Visible = true

    amt = amt or 1

    button.OnUpdated:Connect(function() repeatCall(call, remote, remoteId, spyFunc, amt) end)
end

local function createGenSendPCButton(window: RenderWindow, call, remote: Instance, spyFunc)
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

local function createGenRecvPCButton(window: RenderWindow, call, remote: Instance, spyFunc)
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
        callStackString ..= strformat("\n\t[%s] = {\n\t\tScript = %s,\n\t\tLine = %s,\n\t\tType = %s\n\t},", tostring(i), v.Script and getInstancePath(v.Script) or "\"nil\"", tostring(v.LineNumber), "\"" .. v.Type.. "\"")
    end
    
    return (sub(callStackString, 1, -2) .. "\n}")
end

local function createGetCallStackButton(window: RenderWindow, call, spyFunc)
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

local function createGetConnectionScriptsButton(window: RenderWindow, call, spyFunc)
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

local function createGetRetValButton(window: RenderWindow, call, spyFunc)
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
                    pushError("Failed to Get Return Value (may have never returned)")
                end
            end)
            if not suc then
                pushError("Failed to Get Return Value", res)
            end
        end)
    end
end

local function createCBButton(window: RenderWindow, call, spyFunc)
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

local function createCBDecompileButton(window: RenderWindow, call, spyFunc)
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

local function makeRemoteViewerLog(call: Instance, remote: Instance, remoteId: string)
    local totalArgCount = call.NonNilArgCount + call.NilCount
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
        elseif call.NonNilArgCount == 1 then
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
        for i = 1, call.NonNilArgCount do
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
        local argAmt = call.NonNilArgCount
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

local function loadRemote(remote: Instance, remoteId: string, data)
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

local function makeCopyPathButton(sameLine: RenderSameLine, remote: Instance)
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

local function makeClearLogsButton(sameLine: RenderSameLine, remoteId: string, method)
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

local function makeIgnoreButton(sameLine: RenderSameLine, remoteId: string, method)
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

local function makeBlockButton(sameLine: RenderSameLine, remoteId: string, method)
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

local function renderNewLog(remote: Instance, remoteId: string, data)
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

local function sendLog(remote: Instance, remoteId: string, data)
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

local function processReturnValue(callType: string, refTable, ...)
    spawnFunc(function(...)
        local args = deepClone({...}, callType, -1)
        if args then
            local lastIdx = getLastIndex(args)
            refTable.Args = args
            refTable.NonNilArgCount = lastIdx
            refTable.NilCount = (select("#", ...) - lastIdx)
        else
            refTable.Args = false
            pushError("Impossible error 1 has occurred, please report to GameGuy#5920")
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

local function addCall(remote: Instance, remoteId: string, returnValue, spyFunc, caller: boolean, cs: Instance, callStack, ...)
    if not remoteBlacklistCache[remote] and spyFunc.Object == "RemoteEvent" then
        if isRemoteEventReplicated(remote) then
            remoteBlacklistCache[remote] = 1
        else
            remoteBlacklistCache[remote] = 2
            return
        end
    end

    if not callLogs[remoteId] then
        callLogs[remoteId] = {
            Blocked = false,
            Ignored = false,
            Calls = {}
        }
    end
    if not callLogs[remoteId].Ignored and (Settings.LogHiddenRemotesCalls or spyFunc.Enabled) then
        local args, tableDepth, _, hasInstance = deepClone({...}, remote.ClassName, -1) -- 1 deeper total
        local argCount = select("#", ...)

        if not args or argCount > 7995 or (tableDepth > 0 and ((argCount + tableDepth) > 298)) then
            return
        end
        
        local V2Script = callStack[#callStack-1] and rawget(getfenv(callStack[#callStack-1].func), "script")
        if typeof(V2Script) ~= "Instance" then V2Script = nil end

        local lastIdx = getLastIndex(args)

        local data = {
            HasInstance = hasInstance or (not remote:IsAncestorOf(game)),
            TypeIndex = idxs[spyFunc.Name],
            Script = cs,
            Args = args, -- 2 deeper total
            NonNilArgCount = lastIdx,
            ReturnValue = returnValue,
            NilCount = (argCount - lastIdx),
            FromSynapse = caller,
            ScriptV2 = V2Script,
            CallStack = Settings.StoreCallStack and createCallStack(callStack)
        }
        sendLog(remote, remoteId, data)
    end
end

local function addCallback(remote: Instance, method: string, func)
    local oldIdentity = getThreadIdentity()
    setThreadIdentity(8)
    if remoteBlacklistCache[remote] ~= 2 then
        local remoteId = getDebugId(remote)
        local remoteType = remote.ClassName--isHookThread() and oldIndex(remote, "ClassName") or remote.ClassName

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
                        local args, _, _, hasInstance = deepClone({...}, remoteType, -1)
                        if not args then
                            pushError("Impossible error 2 has occurred, please report to GameGuy#5920")
                            return oldfunc(...)
                        end
                        local argCount = select("#", ...)

                        local callingScript = originalCallerCache[remoteId] or {nil, checkcaller()}

                        originalCallerCache[remoteId] = nil
                        
                        local scr = getcallingscript()
                        if scr then scr = cloneref(scr) end

                        local lastIdx = getLastIndex(args)

                        local data = {
                            HasInstance = hasInstance or (not remote:IsAncestorOf(game)),
                            TypeIndex = idxs[method],
                            CallbackScript = scr,
                            Script = callingScript[1],
                            Args = args, -- 2 deeper total
                            NonNilArgCount = lastIdx,
                            CallbackLog = otherLogs[remoteId],
                            NilCount = (argCount - lastIdx),
                            FromSynapse = callingScript[2]
                        }

                        if spyFunc.ReturnsValue and not otherLogs[remoteId].Blocked then
                            local returnValue = {}
                            spawnFunc(function()
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
    end
    setThreadIdentity(oldIdentity)
end

local function addConnection(remote: Instance, signalType: string, signal: RBXScriptSignal)
    local oldIdentity = getThreadIdentity()
    setThreadIdentity(8)
    if remoteBlacklistCache[remote] ~= 2 then
        local remoteId = getDebugId(remote)
        local remoteType = remote.ClassName--isHookThread() and oldIndex(remote, "ClassName") or remote.ClassName

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
                    spawnFunc(function(...)
                        local original = getThreadIdentity()
                        setThreadIdentity(8) -- not sure why hooksignal threads aren't level 8, but I restore this later anyways, just to be safe
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
                                local args, _, _, hasInstance = deepClone({...}, remoteType, -1)
                                if not args then
                                    pushError("Impossible error 3 has occurred, please report to GameGuy#5920")
                                    return true, ...
                                end
                                local argCount = select("#", ...)
                                local lastIdx = getLastIndex(args)
                                local data = {
                                    HasInstance = hasInstance or (not remote:IsAncestorOf(game)),
                                    TypeIndex = idxs[signalType],
                                    Script = callingScript[1],
                                    Scripts = scriptCache,
                                    Connections = connectionCache,
                                    Signal = signal,
                                    Args = args, -- 2 deeper total
                                    NonNilArgCount = lastIdx,
                                    NilCount = (argCount - lastIdx),
                                    FromSynapse = callingScript[2]
                                }

                                sendLog(remote, remoteId, data)
                            end
                        end
                        setThreadIdentity(original)
                    end, ...)
                end

                if otherLogs[remoteId].Blocked then 
                    return false
                end
                return true, ...
            end)
            tableInsert(_G.remoteSpySignalHooks, signal)
        end
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
-- need to pass an arg telling addCallback/addConnection that the call came from a hook thread, which will use oldIndex, as opposed to being called from the getweakdescendants iteration, where oldIndex will throw an error
oldNewIndex = newHookMetamethod(game, "__newindex", function(remote, idx, newidx)
    spawnFunc(addCallback, cloneref(remote), idx, newidx)

    return oldNewIndex(remote, idx, newidx)
end, AnyFilter.new(newIndexFilters))
_G.remoteSpyHooks.NewIndex = oldNewIndex

oldIndex = newHookMetamethod(game, "__index", function(remote, idx)
    local newSignal = oldIndex(remote, idx)
    spawnFunc(addConnection, cloneref(remote), idx, newSignal)

    return newSignal
end, AnyFilter.new(indexFilters))
_G.remoteSpyHooks.Index = oldIndex

local oldNewInstance
oldNewInstance = filteredOth(Instance.new, function(instanceType: string, ...)
    local newInstance = oldNewInstance(instanceType, ...)
    remoteBlacklistCache[newInstance] = 2
    
    return newInstance
end, AllFilter.new({
    AnyFilter.new({
        ArgumentFilter.new(1, "RemoteEvent"),
        ArgumentFilter.new(1, "RemoteFunction")
    }),
    AnyFilter.new({
        TypeFilter.new(2, "Instance"),
        ArgCountFilter.new(1)
    })
}))

local oldClone
oldClone = filteredOth(Instance.new, function(original: Instance, ...)
    local newInstance = oldClone(original, ...)
    remoteBlacklistCache[newInstance] = 2
    
    return newInstance
end, AllFilter.new({
    AnyFilter.new({
        InstanceTypeFilter.new(1, "RemoteEvent"),
        InstanceTypeFilter.new(1, "RemoteFunction")
    })
}))

table.insert(namecallFilters, AllFilter.new({ -- setup :Clone filter
    AnyFilter.new({
        NamecallFilter.new("Clone"),
        NamecallFilter.new("clone")
    }),
    AnyFilter.new({
        InstanceTypeFilter.new(1, "RemoteEvent"),
        InstanceTypeFilter.new(1, "RemoteFunction")
    })
}))

local initInfo = {
    RemoteFunction = { "Callback", "OnClientInvoke" },
    BindableFunction = { "Callback", "OnInvoke" },
    RemoteEvent = { "Connection", "OnClientEvent" },
    BindableEvent = { "Connection", "Event" }
}

do -- init OnClientInvoke and signal index
    for _,v in getweakdescendants(game) do
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

        local nmcMethod = getnamecallmethod()
        if nmcMethod == "Clone" or nmcMethod == "clone" then -- faster than string.lower
            local newInstance = oldNamecall(remote, ...)
            remoteBlacklistCache[newInstance] = 2

            return newInstance
        end

        if remoteBlacklistCache[remote] ~= 2 then
            local remoteId = getDebugId(remote)
            if not Settings.Paused and select("#", ...) < 7996 then
                local scr = getcallingscript()
                if scr then scr = cloneref(scr) end

                local spyFunc = spyFunctions[idxs[nmcMethod]]
                if spyFunc.Type == "Call" and spyFunc.FiresLocally then
                    local caller = checkcaller()
                    originalCallerCache[remoteId] = originalCallerCache[remoteId] or {(not caller and scr), caller}
                end
                -- it will either return true at checkcaller because called from synapse (non remspy), or have already been set by remspy

                if spyFunc.ReturnsValue and (not callLogs[remoteId] or not callLogs[remoteId].Blocked) then
                    local returnValue = {}
                    spawnFunc(addCall, cloneref(remote), remoteId, returnValue, spyFunc, checkcaller(), scr, getCallStack(getOriginalThread()), ...)

                    return processReturnValue(spyFunc.Object, returnValue, oldNamecall(remote, ...)) -- getproperties(remote).ClassName is not performant at all, but using oldIndex breaks stuff
                end
                spawnFunc(addCall, cloneref(remote), remoteId, nil, spyFunc, checkcaller(), scr, getCallStack(getOriginalThread()), ...)
            end
        
            if callLogs[remoteId] and callLogs[remoteId].Blocked then return end
        end

        return oldNamecall(remote, ...)
    end), AnyFilter.new(namecallFilters))
    _G.remoteSpyHooks.Namecall = oldNamecall

    for _,v in spyFunctions do
        if v.Type == "Call" then
            local oldFunc
            local newfunction = function(remote, ...)
                setThreadIdentity(8) -- oth isn't stock at 8 for some reason
                if remoteBlacklistCache[remote] ~= 2 then
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
                            spawnFunc(addCall, cloneref(remote), remoteId, returnValue, v, checkcaller(), scr, getCallStack(getOriginalThread()), ...)

                            return processReturnValue(v.Object, returnValue, oldFunc(remote, ...))
                        end
                        spawnFunc(addCall, cloneref(remote), remoteId, nil, v, checkcaller(), scr, getCallStack(getOriginalThread()), ...)
                    end
                
                    if callLogs[remoteId] and callLogs[remoteId].Blocked then return end
                end

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
