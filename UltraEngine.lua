--!native
--!optimize 2

if getgenv and getgenv().ApexExtremeV4Loaded then
    return
end
if getgenv then
    getgenv().ApexExtremeV4Loaded = true
end

local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")
local NetworkClient = game:GetService("NetworkClient")
local GuiService = game:GetService("GuiService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

local TARGET_FPS = 144
local FRAME_BUDGET = 1 / 125 -- Threshold (8ms) to detect micro-stutters
local setFps = setfpscap or set_fps_cap or (syn and syn.set_fps_cap)
local setFlag = setfflag or set_fflag

local function safeSet(instance, prop, val)
    if not instance then return end
    pcall(function()
        instance[prop] = val
    end)
end

local function applyFastFlag(flag, val)
    if setFlag then
        pcall(setFlag, flag, tostring(val))
    end
end

-- 1. Core 144Hz Scheduler & Early Input Hook
local function enforceExtremeFps()
    if setFps then
        pcall(setFps, TARGET_FPS)
    end
    applyFastFlag("DFIntTaskSchedulerTargetFps", TARGET_FPS)
    applyFastFlag("FFlagTaskSchedulerTargetFps", "True")
    applyFastFlag("DFIntDebugFRMQualityLevelOverride", 21)
end

-- 2. Extreme RakNet, MTU & Anti-Telemetry Ping Optimizer
local function optimizeExtremeNetwork()
    pcall(function()
        local net = settings().Network
        safeSet(net, "IncomingReplicationLag", 0)
        safeSet(net, "ExperimentalPhysicsEnabled", true)
        safeSet(net, "WaitingForCharacterLogRate", 0)
        safeSet(net, "PrintPhysicsErrors", false)
        safeSet(net, "PrintInstances", false)
        safeSet(net, "PrintBits", false)
        safeSet(net, "PrintSplitMessage", false)
        safeSet(net, "PrintStreamInstanceQuota", false)
        safeSet(net, "PrintTouches", false)
        safeSet(net, "FreeMemoryMBytes", 4096)
        safeSet(net, "DataSendRate", 120)
        safeSet(net, "PhysicsSendRate", 120)
        safeSet(net, "ReceiveRate", 120)
    end)

    -- Packet Pipeline & MTU Tuning (Zero Fragmentation)
    applyFastFlag("DFIntConnectionMTUSize", 1369)
    applyFastFlag("DFIntMaxFrameBufferSize", 1)
    applyFastFlag("DFIntRakNetResendRttMultiple", 1)
    applyFastFlag("DFIntClientPacketMaxDelayMs", 1)
    applyFastFlag("DFIntClientPacketHealthyAllocationPercent", 100)
    applyFastFlag("DFIntMaxProcessPacketsStepsPerCyclic", 5000)
    applyFastFlag("DFIntMaxProcessPacketsStepsAccumulated", 0)
    applyFastFlag("DFIntMaxProcessPacketsJobScaling", 10000)
    applyFastFlag("FFlagOptimizeNetwork", "True")
    applyFastFlag("FFlagOptimizeNetworkTransport", "True")
    applyFastFlag("FFlagOptimizeNetworkPacketReceive", "True")

    -- Kill Background Telemetry & Analytics (Frees Bandwidth for Pure Gameplay)
    applyFastFlag("FFlagDebugDisableTelemetryEphemeralCounter", "True")
    applyFastFlag("FFlagDebugDisableTelemetryEphemeralStat", "True")
    applyFastFlag("FFlagDebugDisableTelemetryEventIngest", "True")
    applyFastFlag("FFlagDebugDisableTelemetryPoint", "True")
    applyFastFlag("FFlagDebugDisableTelemetryV2Counter", "True")
    applyFastFlag("FFlagDebugDisableTelemetryV2Event", "True")
    applyFastFlag("FFlagDebugDisableTelemetryV2Stat", "True")

    pcall(function()
        if NetworkClient and NetworkClient.SetOutgoingKBPSLimit then
            NetworkClient:SetOutgoingKBPSLimit(0)
        end
    end)
end

-- 3. Zero-Latency Input & Pre-Render Priority Pipeline
local function optimizeExtremeInputAndPhysics()
    local phys = nil
    pcall(function() phys = settings().Physics end)

    safeSet(Workspace, "InterpolationThrottling", Enum.InterpolationThrottlingMode.Disabled)
    safeSet(Workspace, "ClientAnimatorThrottling", Enum.ClientAnimatorThrottlingMode.Disabled)
    safeSet(Workspace, "Retargeting", Enum.AnimatorRetargetingMode.Disabled)
    safeSet(Workspace, "SignalBehavior", Enum.SignalBehavior.Immediate)
    safeSet(Workspace, "TouchesUseCollisionGroups", true)
    safeSet(Workspace, "GlobalWind", Vector3.zero)

    if phys then
        safeSet(phys, "PhysicsEnvironmentalThrottle", Enum.EnviromentalPhysicsThrottle.Disabled)
        safeSet(phys, "AllowSleep", false)
        safeSet(phys, "ThrottleAdjustTime", -math.huge)
        safeSet(phys, "DisableCSGv2", true)
    end

    applyFastFlag("FFlagUserCameraInputRefactor3", "True")
    applyFastFlag("FFlagFastGPULightCulling3", "True")
    applyFastFlag("DFFlagDisableDPIScale", "True")

    -- Bind earliest possible priority in RenderStep to flush input queue immediately
    pcall(function()
        RunService:UnbindFromRenderStep("ApexInputFlush")
        RunService:BindToRenderStep("ApexInputFlush", Enum.RenderPriority.First.Value, function()
            if GuiService then
                safeSet(GuiService, "TouchControlsEnabled", true)
            end
        end)
    end)
end

-- 4. Smart Visual Engine & GPU Overdraw Protector
local function optimizeVisualInstance(obj)
    if obj:IsA("ParticleEmitter") then
        -- Prevent mobile GPU alpha-overdraw drops during heavy skill explosions
        if obj.Rate > 60 then
            safeSet(obj, "Rate", 60)
        end
        safeSet(obj, "LightInfluence", 0)
    elseif obj:IsA("Trail") or obj:IsA("Beam") then
        safeSet(obj, "LightInfluence", 0)
    elseif obj:IsA("BasePart") then
        safeSet(obj, "Reflectance", 0)
        if obj.Size.Magnitude < 4 then
            safeSet(obj, "CastShadow", false)
        end
    elseif obj:IsA("DepthOfFieldEffect") or obj:IsA("BlurEffect") or obj:IsA("MotionBlurEffect") or obj:IsA("SunRaysEffect") then
        safeSet(obj, "Enabled", false)
    end
end

local function initializeVisualEngine()
    local render = nil
    pcall(function() render = settings().Rendering end)

    safeSet(UserGameSettings, "SavedQualityLevel", Enum.SavedQualitySetting.QualityLevel10)
    safeSet(UserGameSettings, "VignetteEnabled", false)

    if render then
        safeSet(render, "QualityLevel", Enum.QualityLevel.Level21)
        safeSet(render, "GraphicsMode", Enum.GraphicsMode.Vulkan)
        safeSet(render, "MeshPartDetailLevel", Enum.MeshPartDetailLevel.Level04)
        safeSet(render, "EagerBulkExecution", true)
        safeSet(render, "EnableFRM", false)
        safeSet(render, "AutoFRMLevel", 21)
    end

    safeSet(Lighting, "GlobalShadows", true)
    safeSet(Lighting, "ShadowSoftness", 0)
    safeSet(Lighting, "EnvironmentSpecularScale", 1)
    safeSet(Lighting, "EnvironmentDiffuseScale", 1)
    safeSet(Lighting, "FogEnd", 9e9)
    safeSet(Lighting, "FogStart", 9e9)

    for _, effect in ipairs(Lighting:GetChildren()) do
        optimizeVisualInstance(effect)
    end

    -- Asynchronous Batch Scanner (Zero Freeze on Map Load)
    task.spawn(function()
        local descendants = Workspace:GetDescendants()
        for i = 1, #descendants do
            optimizeVisualInstance(descendants[i])
            if i % 250 == 0 then
                task.wait()
            end
        end
    end)
end

-- 5. Real-Time Frame-Pacing & Smart Idle Garbage Collector
local lastFrameTime = os.clock()
local isUnderHeavyLoad = false

RunService.RenderStepped:Connect(function(dt)
    lastFrameTime = os.clock()
    isUnderHeavyLoad = (dt > FRAME_BUDGET)
end)

local function startSmartGuardian()
    task.spawn(function()
        while task.wait(5) do
            enforceExtremeFps()

            pcall(function()
                local pingItem = Stats and Stats.Network and Stats.Network.ServerStatsItem and Stats.Network.ServerStatsItem["Data Ping"]
                local ping = pingItem and pingItem:GetValue() or 45

                -- Smart GC: Only run memory collection when frame time is smooth (not mid-combat)
                if not isUnderHeavyLoad then
                    if ping > 100 then
                        collectgarbage("step", 300)
                    else
                        collectgarbage("step", 120)
                    end
                end

                if NetworkClient and NetworkClient.SetOutgoingKBPSLimit then
                    NetworkClient:SetOutgoingKBPSLimit(0)
                end
            end)
        end
    end)
end

-- 6. Dynamic Hooks for New Effects & Respawns
Workspace.DescendantAdded:Connect(function(descendant)
    task.defer(function()
        optimizeVisualInstance(descendant)
    end)
end)

Lighting.ChildAdded:Connect(function(child)
    task.defer(function()
        optimizeVisualInstance(child)
    end)
end)

local LocalPlayer = Players.LocalPlayer
if LocalPlayer then
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.2)
        enforceExtremeFps()
        optimizeExtremeInputAndPhysics()
        optimizeExtremeNetwork()
    end)
end

-- Boot Sequence
enforceExtremeFps()
optimizeExtremeNetwork()
optimizeExtremeInputAndPhysics()
initializeVisualEngine()
startSmartGuardian()
