﻿-----------------------------------------------------------
-- EmbedEvent-1.0.lua
-----------------------------------------------------------
-- Embeds frame events into an arbitrary object.
--
-- Abin (2012-3-23)

-----------------------------------------------------------
-- API Documentation:
-----------------------------------------------------------

-- object = EmbedEventObject([object]) -- Embed events to given object
-- object = EmbedEventObject("name", object) -- Embed events to the addon object presents in the global "..."

-- object:RegisterEvent("event" [, func])
-- object:RegisterEvent("event" [, "method"])
-- object:UnregisterEvent("event")
-- object:RegisterAllEvents()
-- object:UnregisterAllEvents()

-- object:RegisterTick(interval) -- object:OnTick() will be called automatically
-- object:UnregisterTick()
-- object:SetInterval(interval)
-- object:IsTicking()

-- object:BroadcastEvent("event" [, ...])
-- object:RegisterEventCallback("event", func [, arg1])
-- object:BroadcastOptionEvent(option [, ...])
-- object:RegisterOptionCallback("option", func [, arg1])

-----------------------------------------------------------

local type = type
local CreateFrame = CreateFrame
local tinsert = tinsert
local GetAddOnMetadata = GetAddOnMetadata
local tonumber = tonumber
local tostring = tostring
local select = select
local _G = _G

local MAJOR_VERSION = 1
local MINOR_VERSION = 7
local LIB_NAME = "EmbedEvent-1.0"

-- To prevent older libraries from over-riding newer ones...
if type(EmbedEventObject_IsNewerVersion) == "function" and not EmbedEventObject_IsNewerVersion(MAJOR_VERSION, MINOR_VERSION) then return end

local PLAYER_CLASS = select(2, UnitClass("player"))
local PLAYER_RACE = select(2, UnitRace("player"))

local function Object_RegisterEvent(self, event, method)
	if type(method) ~= "function" and type(method) ~= "string" then
		method = nil
	end

	local frame = self[LIB_NAME].frame
	if not frame:IsEventRegistered(event) then
		frame:RegisterEvent(event)
	end
	frame.events[event] = method
end

local function Object_UnregisterEvent(self, event)
	local frame = self[LIB_NAME].frame
	frame.events[event] = nil
	if frame:IsEventRegistered(event) then
		frame:UnregisterEvent(event)
	end
end

local function Object_IsEventRegistered(self, event)
	return self[LIB_NAME].frame:IsEventRegistered(event)
end

local function Object_RegisterAllEvents(self)
	return self[LIB_NAME].frame:RegisterAllEvents()
end

local function Object_UnregisterAllEvents(self)
	return self[LIB_NAME].frame:UnregisterAllEvents()
end

local function Object_SetInterval(self, interval)
	if type(interval) ~= "number" or interval < 0.2 then
		interval = 0.2
	end

	local frame = self[LIB_NAME].frame
	frame.elapsed = 0
	frame.tickSeconds = interval
end

local function Object_RegisterTick(self, interval)
	Object_SetInterval(self, interval)
	local frame = self[LIB_NAME].frame
	frame:Show()
end

local function Object_UnregisterTick(self)
	local frame = self[LIB_NAME].frame
	frame:Hide()
	frame.tickSeconds = nil
end

local function Object_IsTicking(self)
	local frame = self[LIB_NAME].frame
	return frame:IsShown()
end

local function Frame_OnEvent(self, event, ...)
	local object = self.parentObject
	if type(object.OnEvent) == "function" then
		object:OnEvent(event, ...)
	else
		local func = self.events[event]
		if not func then
			func = object[event]
		elseif type(func) ~= "function" then -- string, number, etc
			func = object[func]
		end

		if type(func) == "function" then
			func(object, ...)
		end
	end
end

local function Frame_OnUpdate(self, elapsed)
	local tickSeconds = self.tickSeconds
	if not tickSeconds then
		self:Hide()
		return
	end

	local updateElapsed = (self.elapsed or 0) + elapsed
	if updateElapsed >= tickSeconds then
		local object = self.parentObject
		if object.OnTick then
			object:OnTick(updateElapsed)
		end
		updateElapsed = 0
	end
	self.elapsed = updateElapsed
end

local function Object_BroadcastEvent(self, event, ...)
	local callbacks = self[LIB_NAME].eventCallbacks[event]
	if not callbacks then
		return
	end

	local i
	for i = 1, #callbacks do
		local arg1 = callbacks[i].arg1
		if arg1 then
			callbacks[i].func(arg1, ...)
		else
			callbacks[i].func(...)
		end
	end
end

local function Object_RegisterEventCallback(self, event, func, arg1)
	if type(event) ~= "string" or type(func) ~= "function" then
		return
	end

	local callbacks = self[LIB_NAME].eventCallbacks[event]
	if not callbacks then
		callbacks = {}
		self[LIB_NAME].eventCallbacks[event] = callbacks
	end

	tinsert(callbacks, { func = func, arg1 = arg1 })
end

local OPTION_EVENT_PREFX = "OnOptionChanged_" -- Option event name prefix

local function Object_BroadcastOptionEvent(self, option, ...)
	if type(option) == "string" then
		Object_BroadcastEvent(self, OPTION_EVENT_PREFX..option, ...)
	end
end

local function Object_RegisterOptionCallback(self, option, func, arg1)
	if type(option) == "string" then
		Object_RegisterEventCallback(self, OPTION_EVENT_PREFX..option, func, arg1)
	end
end

local function Object_Print(self, msg, r, g, b)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffff78"..self.name..":|r "..tostring(msg), r or 0.5, g or 0.75, b or 1)
end

local function Object_PlayerClass(self, ...)
	local COUNT = select("#", ...)
	if COUNT == 0 then
		return PLAYER_CLASS
	end

	local i
	for i = 1, COUNT do
		if select(i, ...) == PLAYER_CLASS then
			return PLAYER_CLASS
		end
	end
end

local function Object_PlayerRace(self, ...)
	local COUNT = select("#", ...)
	if COUNT == 0 then
		return PLAYER_RACE
	end

	local i
	for i = 1, COUNT do
		if select(i, ...) == PLAYER_RACE then
			return PLAYER_RACE
		end
	end
end

function EmbedEventObject(arg1, arg2)
	local name, object
	if type(arg1) == "string" and type(arg2) == "table" then
		name, object = arg1, arg2
	elseif type(arg1) == "table" then
		object = arg1
	else
		object = {}
	end

	if object[LIB_NAME] then
		return object
	end

	if name then
		_G[name] = object
		object.version = GetAddOnMetadata(name, "Version") or "1.0"
		object.numericVersion = tonumber(object.version) or 1.0
		object.name = name
		object.Print = Object_Print
	end

	local frame = CreateFrame("Frame")
	object[LIB_NAME] = { frame = frame, eventCallbacks = {} }
	frame.parentObject = object
	frame.events = {}
	frame:Hide()
	frame:SetScript("OnEvent", Frame_OnEvent)
	frame:SetScript("OnUpdate", Frame_OnUpdate)
	object.RegisterEvent = Object_RegisterEvent
	object.UnregisterEvent = Object_UnregisterEvent
	object.IsEventRegistered = Object_IsEventRegistered
	object.RegisterAllEvents = Object_RegisterAllEvents
	object.UnregisterAllEvents = Object_UnregisterAllEvents
	object.RegisterTick = Object_RegisterTick
	object.UnregisterTick = Object_UnregisterTick
	object.SetInterval = Object_SetInterval
	object.IsTicking = Object_IsTicking
	object.BroadcastEvent = Object_BroadcastEvent
	object.RegisterEventCallback = Object_RegisterEventCallback
	object.BroadcastOptionEvent = Object_BroadcastOptionEvent
	object.RegisterOptionCallback = Object_RegisterOptionCallback
	object.PlayerClass = Object_PlayerClass
	object.PlayerRace = Object_PlayerRace

	return object
end

-- Provides version check
function EmbedEventObject_IsNewerVersion(major, minor)
	if type(major) ~= "number" or type(minor) ~= "number" then
		return false
	end

	if major > MAJOR_VERSION then
		return true
	elseif major < MAJOR_VERSION then
		return false
	else -- major equal, check minor
		return minor > MINOR_VERSION
	end
end
