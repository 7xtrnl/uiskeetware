--[[
	SkeetwareUI v1.1 — Premium dark UI library for Roblox executors
	Style: CS2 / Skeetware inspired — gradient glass panels, neon accents,
	sidebar navigation with icons, segmented tabboxes and consistent spacing.

	Loadstring ready:
		local Library = loadstring(game:HttpGet("<your-raw-url>/SkeetwareUI.lua"))()

	Quick start:
		local Window = Library:CreateWindow({ Title = "skeetware.cc", Size = UDim2.fromOffset(760, 540) })
		local Tab    = Window:AddTab("Legit", Library.Icons.Target)
		local Group  = Tab:AddGroupbox({ Title = "Aimbot", Icon = Library.Icons.Target })
		Group:AddToggle({ Text = "Enabled", Default = true, Callback = print })
		Library:CreateSettingsTab(Window)   -- theme manager + config manager + menu keybind

	Public API (all elements return objects with :Set/:Get/:Destroy):
		Library:CreateWindow, Library:CreateSettingsTab, Library:Notify,
		Library:SaveConfig, Library:LoadConfig, Library:DeleteConfig,
		Library:ListConfigs, Library:Unload, Library:SetAccent
		Window:AddTab, Window:Minimize, Window:Maximize, Window:Toggle,
		Window:SetScale, Window:SetOpacity, Window:Destroy
		Tab:AddGroupbox, Tab:AddTabbox, Tab:AddScrollingFrame
		Groupbox/Tabbox-Tab:AddToggle, AddButton (Icon/Risky), AddSlider (Suffix/Ticks),
			AddMinMaxSlider, AddDropdown, AddMultiDropdown, AddColorpicker, AddKeybind,
			AddTextlabel, AddSearchbar, AddGroupbox (nested), AddScrollingFrame

	Theme spacing tokens live in Library.Theme (PadOuter/PadInner/GapRow/GapBox).
	Library.Icons holds ready-made asset ids; swap any of them for your own.
--]]

--============================================================================--
-- SERVICES
--============================================================================--
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")
local HttpService      = game:GetService("HttpService")
local CoreGui          = game:GetService("CoreGui")
local TextService      = game:GetService("TextService")

local LocalPlayer = Players.LocalPlayer
local Mouse       = LocalPlayer and LocalPlayer:GetMouse()

--============================================================================--
-- LIBRARY ROOT
--============================================================================--
local Library = {
	Version      = "1.0.0",
	Name         = "SkeetwareUI",
	Unloaded     = false,
	ToggleKey    = Enum.KeyCode.RightShift,
	Flags        = {},          -- flag -> value
	Registry     = {},          -- flag -> element object
	Connections  = {},
	Objects      = {},          -- {inst, prop, themeKey} for live accent recolor
	Notifications= {},
	ConfigFolder = "SkeetwareUI",
	NotificationsEnabled = true,
	Theme = {
		Accent       = Color3.fromRGB(122, 106, 214),
		AccentDark   = Color3.fromRGB(84, 72, 152),
		Background   = Color3.fromRGB(18, 18, 18),
		BackgroundAlt= Color3.fromRGB(22, 22, 22),
		Gradient1    = Color3.fromRGB(36, 36, 38),
		Gradient2    = Color3.fromRGB(18, 18, 19),
		Panel        = Color3.fromRGB(26, 26, 26),
		Element      = Color3.fromRGB(33, 33, 33),
		ElementHover = Color3.fromRGB(41, 41, 41),
		Border       = Color3.fromRGB(10, 10, 10),
		Text         = Color3.fromRGB(202, 202, 202),
		TextDim      = Color3.fromRGB(122, 122, 122),
		Risky        = Color3.fromRGB(196, 76, 76),
		Good         = Color3.fromRGB(120, 176, 96),
		Font         = Enum.Font.Arial,
		FontBold     = Enum.Font.ArialBold,
		TextSize     = 12,
		-- Spacing scale (used across every container for consistent padding).
		PadOuter     = 8,
		PadInner     = 6,
		GapRow       = 4,
		GapBox       = 6,
	},
	-- Built-in icon set (Roblox asset ids) so tabs/groupboxes/buttons can use
	-- icons without hunting for asset ids: Library.Icons.Target etc.
	Icons = {
		Target    = "rbxassetid://10734977012",
		Crosshair = "rbxassetid://10709818534",
		Eye       = "rbxassetid://10723346959",
		Users     = "rbxassetid://10747373426",
		User      = "rbxassetid://10747373176",
		Globe     = "rbxassetid://10723404337",
		Shield    = "rbxassetid://10734951847",
		Sliders   = "rbxassetid://10734963400",
		Settings  = "rbxassetid://10734950309",
		Palette   = "rbxassetid://10734910430",
		Save      = "rbxassetid://10734941499",
		Download  = "rbxassetid://10723344270",
		Trash     = "rbxassetid://10747362241",
		Refresh   = "rbxassetid://10734933222",
		Power     = "rbxassetid://10734930466",
		Zap       = "rbxassetid://10723376114",
		Search    = "rbxassetid://10734943674",
		Folder    = "rbxassetid://10723387563",
		Skull     = "rbxassetid://10734962068",
		Swords    = "rbxassetid://10734975692",
		Monitor   = "rbxassetid://10734896881",
		Wrench    = "rbxassetid://10747383470",
		Cursor    = "rbxassetid://10734898476",
	},
}
Library.__index = Library

--============================================================================--
-- SAFE ENVIRONMENT SHIMS (executor differences)
--============================================================================--
local function safe(fn, ...)
	local ok, res = pcall(fn, ...)
	if ok then return res end
	return nil
end

local gethui       = (typeof(gethui) == "function") and gethui or nil
local protectgui   = (syn and syn.protect_gui) or (typeof(protect_gui) == "function" and protect_gui) or nil
local setclipboard = setclipboard or (toclipboard) or (Clipboard and Clipboard.set) or function() end
local writefile_   = writefile
local readfile_    = readfile
local isfile_      = isfile
local listfiles_   = listfiles
local makefolder_  = makefolder
local isfolder_    = isfolder
local delfile_     = delfile

local FS_AVAILABLE = (typeof(writefile_) == "function" and typeof(readfile_) == "function" and typeof(isfile_) == "function")

--============================================================================--
-- UTILITIES
--============================================================================--
local Util = {}

function Util.Create(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then inst[k] = v end
	end
	for _, child in ipairs(children or {}) do child.Parent = inst end
	if props and props.Parent then inst.Parent = props.Parent end
	return inst
end
local New = Util.Create

-- Skeetware is 100% square: every corner is hard, no exceptions.
function Util.Corner(radius, parent)
	return New("UICorner", { CornerRadius = UDim.new(0, 0), Parent = parent })
end

function Util.Stroke(parent, color, thickness, transparency)
	return New("UIStroke", {
		Color = color or Library.Theme.Border,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Util.Padding(parent, t, r, b, l)
	return New("UIPadding", {
		PaddingTop    = UDim.new(0, t or 0),
		PaddingRight  = UDim.new(0, r or t or 0),
		PaddingBottom = UDim.new(0, b or t or 0),
		PaddingLeft   = UDim.new(0, l or r or t or 0),
		Parent = parent,
	})
end

function Util.List(parent, pad, dir)
	return New("UIListLayout", {
		Padding = UDim.new(0, pad or 6),
		FillDirection = dir or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

-- Flat fill (no frosted-glass gradient; real cheat UIs are opaque and flat).
function Util.Glass(inst, alpha)
	inst.BackgroundTransparency = 1
	return inst
end

-- Premium drop shadow (uses the classic 9-slice shadow asset).
function Util.Shadow(parent, size, transparency)
	local s = New("ImageLabel", {
		BackgroundTransparency = 1,
		Image = "rbxassetid://6014261993",
		ImageColor3 = Color3.fromRGB(0, 0, 0),
		ImageTransparency = 0.75,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(49, 49, 450, 450),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 10, 1, 10),
		ZIndex = 0,
		Parent = parent,
	})
	return s
end

-- Neon glow disabled: kept as a stub so call sites stay valid.
function Util.Glow(parent, color, transparency)
	return New("ImageLabel", {
		Name = "Glow",
		BackgroundTransparency = 1,
		ImageTransparency = 1,
		Visible = false,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Parent = parent,
	})
end

function Util.Gradient(parent, c1, c2, rotation)
	local g = New("UIGradient", {
		Rotation = rotation or 90,
		Color = ColorSequence.new(c1 or Library.Theme.Gradient1, c2 or Library.Theme.Gradient2),
		Parent = parent,
	})
	return g
end

-- Vertical top-light -> bottom-dark sheen, the signature skeet panel fill.
function Util.Sheen(parent, strength)
	local k = strength or 0.10
	return New("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(225, 225, 225)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 150)),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1 - k),
			NumberSequenceKeypoint.new(1, 1 - k * 0.4),
		}),
		Parent = parent,
	})
end


local TW_FAST   = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TW_NORMAL = TweenInfo.new(0.20, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local TW_SLOW   = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

function Util.Tween(inst, props, info)
	if not inst or not inst.Parent then return end
	local t = TweenService:Create(inst, info or TW_NORMAL, props)
	t:Play()
	return t
end

function Util.Round(n, step)
	if not step or step <= 0 then return n end
	return math.floor((n / step) + 0.5) * step
end

function Util.Clamp(n, a, b) return math.clamp(n, a, b) end

function Util.Decimals(step)
	if not step or step >= 1 then return 0 end
	local s = tostring(step)
	local dot = s:find("%.")
	if not dot then return 0 end
	return #s - dot
end

function Util.FormatNumber(n, step)
	local d = Util.Decimals(step)
	if d == 0 then return tostring(math.floor(n + (n >= 0 and 0.5 or -0.5))) end
	return string.format("%." .. d .. "f", n)
end

function Util.ToHex(color)
	return string.format("#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5))
end

function Util.FromHex(hex)
	hex = tostring(hex):gsub("#", ""):gsub("%s", "")
	if #hex == 3 then hex = hex:gsub("(.)", "%1%1") end
	if #hex ~= 6 then return nil end
	local r = tonumber(hex:sub(1, 2), 16)
	local g = tonumber(hex:sub(3, 4), 16)
	local b = tonumber(hex:sub(5, 6), 16)
	if not (r and g and b) then return nil end
	return Color3.fromRGB(r, g, b)
end

function Util.KeyName(input)
	if not input then return "None" end
	if typeof(input) == "EnumItem" then
		local n = input.Name
		local map = {
			LeftShift = "LSHIFT", RightShift = "RSHIFT",
			LeftControl = "LCTRL", RightControl = "RCTRL",
			LeftAlt = "LALT", RightAlt = "RALT",
			MouseButton1 = "MOUSE1", MouseButton2 = "MOUSE2", MouseButton3 = "MOUSE3",
			Backspace = "BACK", Return = "ENTER", Escape = "ESC", Space = "SPACE",
		}
		return map[n] or n:upper()
	end
	return tostring(input)
end

function Library:RegisterThemed(inst, prop, key)
	table.insert(self.Objects, { Instance = inst, Property = prop, Key = key })
end

function Library:Connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(self.Connections, c)
	return c
end

function Library:SetAccent(color)
	self.Theme.Accent = color
	self.Theme.AccentDark = Color3.fromRGB(color.R * 160, color.G * 160, color.B * 160)
	for _, o in ipairs(self.Objects) do
		if o.Instance and o.Instance.Parent and (o.Key == "Accent") then
			pcall(function() o.Instance[o.Property] = color end)
		end
	end
end

--============================================================================--
-- ROOT SCREENGUI
--============================================================================--
local function buildScreenGui()
	local gui = New("ScreenGui", {
		Name = "\0SkeetwareUI_" .. tostring(math.random(1e5, 1e6)),
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		DisplayOrder = 9999,
	})
	local parented = false
	if gethui then parented = pcall(function() gui.Parent = gethui() end) end
	if not parented and protectgui then
		parented = pcall(function() protectgui(gui); gui.Parent = CoreGui end)
	end
	if not parented then
		local ok = pcall(function() gui.Parent = CoreGui end)
		if not ok then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
	end
	return gui
end

Library.ScreenGui = buildScreenGui()

--============================================================================--
-- NOTIFICATION SYSTEM
--============================================================================--
local NotifHolder = New("Frame", {
	Name = "Notifications",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -18, 1, -18),
	Size = UDim2.fromOffset(300, 600),
	BackgroundTransparency = 1,
	Parent = Library.ScreenGui,
})
New("UIListLayout", {
	Padding = UDim.new(0, 8),
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = NotifHolder,
})

--- Library:Notify({ Title, Text, Duration, Type = "info"|"success"|"error" })
function Library:Notify(opts)
	if self.Unloaded then return end
	if self.NotificationsEnabled == false then return end
	if typeof(opts) == "string" then opts = { Text = opts } end
	opts = opts or {}
	local T = self.Theme
	local kind = (opts.Type or "info"):lower()
	local accent = kind == "success" and T.Good or kind == "error" and T.Risky or T.Accent

	local card = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.06,
		Parent = NotifHolder,
		ClipsDescendants = false,
	})
	Util.Corner(8, card)
	Util.Stroke(card, T.Border, 1, 0.2)
	Util.Shadow(card, 34, 0.55)
	Util.Gradient(card, T.Gradient1, T.Gradient2, 30)
	Util.Sheen(card, 0.06)

	local bar = New("Frame", {
		Size = UDim2.new(0, 3, 1, -12),
		Position = UDim2.fromOffset(8, 6),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Parent = card,
	})
	Util.Corner(2, bar)

	local title = New("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 9),
		Size = UDim2.new(1, -30, 0, 15),
		Font = T.FontBold,
		Text = opts.Title or self.Name,
		TextColor3 = accent,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})

	local body = New("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 26),
		Size = UDim2.new(1, -30, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = T.Font,
		Text = opts.Text or "",
		TextColor3 = T.Text,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	Util.Padding(card, 0, 0, 12, 0)

	card.BackgroundTransparency = 1
	title.TextTransparency, body.TextTransparency = 1, 1
	card.Position = UDim2.fromOffset(40, 0)
	Util.Tween(card, { BackgroundTransparency = 0.06 }, TW_NORMAL)
	Util.Tween(title, { TextTransparency = 0 }, TW_NORMAL)
	Util.Tween(body, { TextTransparency = 0 }, TW_NORMAL)

	local duration = opts.Duration or 4
	task.delay(duration, function()
		if not card.Parent then return end
		Util.Tween(card, { BackgroundTransparency = 1 }, TW_NORMAL)
		Util.Tween(title, { TextTransparency = 1 }, TW_NORMAL)
		Util.Tween(body, { TextTransparency = 1 }, TW_NORMAL)
		task.delay(0.25, function() if card then card:Destroy() end end)
	end)
	return card
end

--============================================================================--
-- ELEMENT BASE HELPERS
--============================================================================--
local function registerFlag(element, flag, default)
	if not flag then return end
	Library.Flags[flag] = default
	Library.Registry[flag] = element
end

local function elementRow(parent, height)
	local row = New("Frame", {
		Size = UDim2.new(1, 0, 0, height or 26),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	return row
end

local function baseLabel(parent, text, width)
	return New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(width or 1, width and 0 or -10, 1, 0),
		Font = Library.Theme.Font,
		Text = text or "",
		TextColor3 = Library.Theme.Text,
		TextSize = Library.Theme.TextSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent,
	})
end

-- Ripple effect used by buttons.
local function ripple(button, x, y)
	local rip = New("Frame", {
		BackgroundColor3 = Library.Theme.Accent,
		BackgroundTransparency = 0.65,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(0, 0),
		ZIndex = 5,
		Parent = button,
	})
	Util.Corner(999, rip)
	local target = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y) * 2
	Util.Tween(rip, { Size = UDim2.fromOffset(target, target), BackgroundTransparency = 1 }, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	task.delay(0.5, function() rip:Destroy() end)
end

--============================================================================--
-- CONTAINER: mixin that provides every AddX() method
--============================================================================--
local Container = {}
Container.__index = Container

function Container.new(holder, window)
	return setmetatable({ Holder = holder, Window = window, Elements = {}, Disabled = false }, Container)
end

function Container:_track(obj)
	table.insert(self.Elements, obj)
	return obj
end

--------------------------------------------------------------------- TEXTLABEL
function Container:AddTextlabel(opts)
	opts = opts or {}
	local T = Library.Theme
	local holder = New("Frame", {
		Size = UDim2.new(1, 0, 0, opts.Height or 20),
		AutomaticSize = opts.Wrap and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
		BackgroundColor3 = T.Element,
		BackgroundTransparency = opts.Background and 0.25 or 1,
		Parent = self.Holder,
	})
	if opts.Background then
		Util.Corner(6, holder)
		if opts.Outline ~= false then Util.Stroke(holder, T.Border, 1, 0.35) end
		Util.Padding(holder, 4, 8, 4, 8)
	end

	local scroller
	local label = New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		AutomaticSize = opts.Wrap and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
		Font = opts.Font or T.Font,
		RichText = opts.RichText ~= false,
		Text = opts.Text or "",
		TextColor3 = opts.Color or T.Text,
		TextSize = opts.TextSize or T.TextSize,
		TextWrapped = opts.Wrap or false,
		TextXAlignment = opts.Center and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
		Parent = holder,
	})

	-- Marquee scrolling for long single-line content.
	if opts.Scrolling then
		holder.ClipsDescendants = true
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.new(0, 0, 1, 0)
		scroller = RunService.RenderStepped:Connect(function(dt)
			local overflow = label.AbsoluteSize.X - holder.AbsoluteSize.X
			if overflow > 0 then
				local x = label.Position.X.Offset - dt * 30
				if x < -overflow - 40 then x = holder.AbsoluteSize.X end
				label.Position = UDim2.new(0, x, 0, 0)
			else
				label.Position = UDim2.fromOffset(0, 0)
			end
		end)
		table.insert(Library.Connections, scroller)
	end

	local obj = {}
	function obj:Set(text) label.Text = tostring(text) end
	function obj:SetColor(c) label.TextColor3 = c end
	function obj:Get() return label.Text end
	function obj:Copy() pcall(setclipboard, label.ContentText or label.Text) end
	function obj:Destroy() if scroller then scroller:Disconnect() end holder:Destroy() end
	obj.Instance = holder

	if opts.Copyable then
		local btn = New("TextButton", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = "", Parent = holder, ZIndex = 3 })
		btn.MouseButton1Click:Connect(function()
			obj:Copy()
			Library:Notify({ Title = "Copied", Text = "Text copied to clipboard.", Type = "success", Duration = 2 })
		end)
	end
	return self:_track(obj)
end

------------------------------------------------------------------------ BUTTON
function Container:AddButton(opts)
	opts = opts or {}
	local T = Library.Theme
	local self_ = self

	local btn = New("TextButton", {
		Size = UDim2.new(1, 0, 0, opts.Height or 30),
		BackgroundColor3 = T.Element,
		BackgroundTransparency = 0.1,
		AutoButtonColor = false,
		Text = "",
		ClipsDescendants = true,
		Parent = self.Holder,
	})
	Util.Corner(6, btn)
	local stroke = Util.Stroke(btn, T.Border, 1, 0.25)
	local glow = Util.Glow(btn, T.Accent, 1)
	Util.Gradient(btn, T.Gradient1, T.Gradient2, 20)
	Util.Sheen(btn, 0.06)

	local iconLeft, iconRight
	if opts.Icon then
		iconLeft = New("ImageLabel", {
			BackgroundTransparency = 1,
			Image = opts.Icon,
			ImageColor3 = T.Accent,
			Size = UDim2.fromOffset(16, 16),
			Position = UDim2.new(0, 10, 0.5, -8),
			Parent = btn,
		})
		Library:RegisterThemed(iconLeft, "ImageColor3", "Accent")
	end
	if opts.IconRight then
		iconRight = New("ImageLabel", {
			BackgroundTransparency = 1,
			Image = opts.IconRight,
			ImageColor3 = T.Accent,
			Size = UDim2.fromOffset(16, 16),
			Position = UDim2.new(1, -26, 0.5, -8),
			Parent = btn,
		})
		Library:RegisterThemed(iconRight, "ImageColor3", "Accent")
	end

	local label = New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Font = T.FontBold,
		Text = opts.Text or "Button",
		TextColor3 = T.Text,
		TextSize = T.TextSize,
		Parent = btn,
	})

	local spinner = New("ImageLabel", {
		BackgroundTransparency = 1,
		Image = "rbxassetid://4965945816",
		ImageColor3 = T.Accent,
		Size = UDim2.fromOffset(16, 16),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Visible = false,
		Parent = btn,
	})
	Library:RegisterThemed(spinner, "ImageColor3", "Accent")

	local obj = { Loading = false, Disabled = opts.Disabled or false }
	obj.Instance = btn

	local baseText = opts.Risky and T.Risky or T.Text
	if opts.Risky then
		label.TextColor3 = T.Risky
		if iconLeft then iconLeft.ImageColor3 = T.Risky end
	end

	local function refresh()
		if obj.Disabled then
			btn.BackgroundTransparency = 0.55
			label.TextColor3 = T.TextDim
			stroke.Transparency = 0.7
		else
			btn.BackgroundTransparency = 0.1
			label.TextColor3 = baseText
			stroke.Transparency = 0.25
		end
	end

	local spinConn
	function obj:SetLoading(state)
		self.Loading = state and true or false
		spinner.Visible = self.Loading
		label.Visible = not self.Loading
		if spinConn then spinConn:Disconnect() spinConn = nil end
		if self.Loading then
			spinConn = RunService.RenderStepped:Connect(function(dt)
				spinner.Rotation = (spinner.Rotation + dt * 360) % 360
			end)
		end
	end
	function obj:SetDisabled(state) self.Disabled = state and true or false refresh() end
	function obj:SetText(t) label.Text = t end
	function obj:Destroy() if spinConn then spinConn:Disconnect() end btn:Destroy() end

	local function fire(x, y)
		if obj.Disabled or obj.Loading or self_.Disabled then return end
		ripple(btn, x or btn.AbsoluteSize.X / 2, y or btn.AbsoluteSize.Y / 2)
		task.spawn(function()
			local ok, err = pcall(opts.Callback or function() end, obj)
			if not ok then
				Library:Notify({ Title = "Button error", Text = tostring(err), Type = "error" })
			end
		end)
	end
	obj.Fire = function() fire() end

	btn.MouseButton1Click:Connect(function()
		local pos = UserInputService:GetMouseLocation()
		fire(pos.X - btn.AbsolutePosition.X, pos.Y - btn.AbsolutePosition.Y - 36)
	end)
	btn.MouseEnter:Connect(function()
		if obj.Disabled then return end
		Util.Tween(btn, { BackgroundColor3 = T.ElementHover }, TW_FAST)
		Util.Tween(glow, { ImageTransparency = 0.72 }, TW_FAST)
		Util.Tween(stroke, { Color = T.Accent, Transparency = 0.1 }, TW_FAST)
	end)
	btn.MouseLeave:Connect(function()
		Util.Tween(btn, { BackgroundColor3 = T.Element }, TW_FAST)
		Util.Tween(glow, { ImageTransparency = 1 }, TW_FAST)
		Util.Tween(stroke, { Color = T.Border, Transparency = 0.25 }, TW_FAST)
	end)
	-- Keyboard activation while hovered.
	btn.Selectable = true
	btn.Activated:Connect(function() end)

	refresh()
	if opts.Flag then registerFlag(obj, opts.Flag, nil) end
	return self:_track(obj)
end

------------------------------------------------------------------------ TOGGLE
function Container:AddToggle(opts)
	opts = opts or {}
	local T = Library.Theme
	local row = elementRow(self.Holder, 26)
	local label = baseLabel(row, opts.Text or "Toggle", 0.7)

	local track = New("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(38, 18),
		BackgroundColor3 = T.Element,
		AutoButtonColor = false,
		Text = "",
		Parent = row,
	})
	Util.Corner(999, track)
	local stroke = Util.Stroke(track, T.Border, 1, 0.2)
	local glow = Util.Glow(track, T.Accent, 1)

	local knob = New("Frame", {
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.fromOffset(2, 2),
		BackgroundColor3 = T.TextDim,
		BorderSizePixel = 0,
		Parent = track,
	})
	Util.Corner(999, knob)

	local statusLight = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -46, 0.5, 0),
		Size = UDim2.fromOffset(6, 6),
		BackgroundColor3 = T.TextDim,
		BorderSizePixel = 0,
		Parent = row,
	})
	Util.Corner(999, statusLight)

	local stateText = New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -58, 0.5, 0),
		Size = UDim2.fromOffset(28, 14),
		BackgroundTransparency = 1,
		Font = T.Font,
		Text = "OFF",
		TextColor3 = T.TextDim,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = opts.ShowLabels ~= false,
		Parent = row,
	})

	local obj = { Value = opts.Default and true or false, Children = {} }
	obj.Instance = row

	local function render(animate)
		local on = obj.Value
		local info = animate and TW_NORMAL or TweenInfo.new(0)
		Util.Tween(knob, { Position = UDim2.fromOffset(on and 22 or 2, 2), BackgroundColor3 = on and Color3.new(1,1,1) or T.TextDim }, info)
		Util.Tween(track, { BackgroundColor3 = on and T.AccentDark or T.Element }, info)
		Util.Tween(stroke, { Color = on and T.Accent or T.Border }, info)
		Util.Tween(glow, { ImageTransparency = on and 0.6 or 1 }, info)
		Util.Tween(statusLight, { BackgroundColor3 = on and T.Accent or T.TextDim }, info)
		stateText.Text = on and "ON" or "OFF"
		stateText.TextColor3 = on and T.Accent or T.TextDim
		label.TextColor3 = on and T.Text or T.TextDim
		-- Enable/disable child elements bound to this toggle.
		for _, child in ipairs(obj.Children) do
			if child.SetDisabled then child:SetDisabled(not on) end
		end
	end

	function obj:Set(v, skipCallback)
		self.Value = v and true or false
		if opts.Flag then Library.Flags[opts.Flag] = self.Value end
		render(true)
		if not skipCallback then
			task.spawn(function()
				local ok, err = pcall(opts.Callback or function() end, self.Value)
				if not ok then Library:Notify({ Title = "Toggle error", Text = tostring(err), Type = "error" }) end
			end)
		end
	end
	function obj:Get() return self.Value end
	function obj:Toggle() self:Set(not self.Value) end
	function obj:AddChild(el) table.insert(self.Children, el) if el.SetDisabled then el:SetDisabled(not self.Value) end end
	function obj:Destroy() row:Destroy() end

	track.MouseButton1Click:Connect(function() obj:Toggle() end)
	local hit = New("TextButton", { BackgroundTransparency = 1, Size = UDim2.new(0.7, 0, 1, 0), Text = "", Parent = row })
	hit.MouseButton1Click:Connect(function() obj:Toggle() end)

	registerFlag(obj, opts.Flag, obj.Value)
	render(false)

	-- Inline keybind support: Toggle:AddKeybind wires a hotkey to this toggle.
	function obj:AddKeybind(kopts)
		kopts = kopts or {}
		kopts.Target = obj
		return self_ and nil
	end

	if opts.Keybind then
		Library:Connect(UserInputService.InputBegan, function(input, gpe)
			if gpe then return end
			if input.KeyCode == opts.Keybind then obj:Toggle() end
		end)
	end
	return self:_track(obj)
end

------------------------------------------------------------------------ SLIDER
function Container:AddSlider(opts)
	opts = opts or {}
	local T = Library.Theme
	local min, max = opts.Min or 0, opts.Max or 100
	local step = opts.Step or 1

	local holder = New("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = self.Holder })
	local label = New("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, -80, 0, 16),
		Font = T.Font, Text = opts.Text or "Slider", TextColor3 = T.Text, TextSize = T.TextSize,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = holder,
	})
	local pct = New("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -46, 0, 0),
		Size = UDim2.fromOffset(40, 16), Font = T.Font, Text = "0%", TextColor3 = T.TextDim, TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right, Parent = holder,
	})
	local box = New("TextBox", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, -1),
		Size = UDim2.fromOffset(44, 18), BackgroundColor3 = T.Element, BackgroundTransparency = 0.15,
		Font = T.Font, Text = "0", TextColor3 = T.Accent, TextSize = 11, ClearTextOnFocus = false, Parent = holder,
	})
	Util.Corner(4, box)
	Util.Stroke(box, T.Border, 1, 0.4)
	Library:RegisterThemed(box, "TextColor3", "Accent")

	local bar = New("Frame", {
		Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = T.Element, BorderSizePixel = 0, Parent = holder,
	})
	Util.Corner(999, bar)
	Util.Stroke(bar, T.Border, 1, 0.5)

	local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = bar })
	Util.Corner(999, fill)
	Library:RegisterThemed(fill, "BackgroundColor3", "Accent")
	New("UIGradient", { Color = ColorSequence.new(T.AccentDark, T.Accent), Parent = fill })

	-- Ticks / divisions
	if opts.Ticks and opts.Ticks > 1 then
		for i = 0, opts.Ticks do
			local t = New("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(i / opts.Ticks, 0, 1, 3),
				Size = UDim2.fromOffset(1, 4),
				BackgroundColor3 = T.Border, BorderSizePixel = 0, Parent = bar,
			})
		end
	end

	local thumb = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = bar,
	})
	Util.Corner(999, thumb)
	Util.Glow(thumb, T.Accent, 0.35)

	local obj = { Value = opts.Default or min, Disabled = false }
	obj.Instance = holder

	local function render(animate)
		local alpha = (max - min) == 0 and 0 or (obj.Value - min) / (max - min)
		local info = animate and TW_FAST or TweenInfo.new(0)
		Util.Tween(fill, { Size = UDim2.fromScale(alpha, 1) }, info)
		Util.Tween(thumb, { Position = UDim2.new(alpha, 0, 0.5, 0) }, info)
		pct.Text = math.floor(alpha * 100 + 0.5) .. "%"
		local suffix = opts.Suffix or ""
		box.Text = Util.FormatNumber(obj.Value, step) .. suffix
	end

	function obj:Set(v, skipCallback)
		if typeof(v) ~= "number" then v = tonumber(v) or min end
		v = Util.Clamp(Util.Round(v, step), min, max)
		self.Value = v
		if opts.Flag then Library.Flags[opts.Flag] = v end
		render(true)
		if not skipCallback then
			task.spawn(function() pcall(opts.Callback or function() end, v) end)
		end
	end
	function obj:Get() return self.Value end
	function obj:SetDisabled(s) self.Disabled = s and true or false
		label.TextColor3 = self.Disabled and T.TextDim or T.Text
		bar.BackgroundTransparency = self.Disabled and 0.6 or 0
	end
	function obj:Destroy() holder:Destroy() end

	local dragging = false
	local function updateFromMouse()
		local x = UserInputService:GetMouseLocation().X
		local alpha = Util.Clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
		obj:Set(min + alpha * (max - min))
	end

	bar.InputBegan:Connect(function(input)
		if obj.Disabled then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			Util.Tween(thumb, { Size = UDim2.fromOffset(16, 16) }, TW_FAST)
			updateFromMouse()
		end
	end)
	Library:Connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragging then
				dragging = false
				Util.Tween(thumb, { Size = UDim2.fromOffset(12, 12) }, TW_FAST)
			end
		end
	end)
	Library:Connect(RunService.RenderStepped, function()
		if dragging then updateFromMouse() end
	end)

	box.FocusLost:Connect(function()
		local n = tonumber((box.Text:gsub("[^%-%d%.]", "")))
		if n then obj:Set(n) else render(false) end
	end)

	registerFlag(obj, opts.Flag, obj.Value)
	obj:Set(obj.Value, true)
	return self:_track(obj)
end

---------------------------------------------------------------- MINMAX SLIDER
function Container:AddMinMaxSlider(opts)
	opts = opts or {}
	local T = Library.Theme
	local min, max = opts.Min or 0, opts.Max or 100
	local step = opts.Step or 1

	local holder = New("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Parent = self.Holder })
	New("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, -120, 0, 16),
		Font = T.Font, Text = opts.Text or "Range", TextColor3 = T.Text, TextSize = T.TextSize,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = holder,
	})

	local function makeBox(anchorX)
		local b = New("TextBox", {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, anchorX, 0, -1),
			Size = UDim2.fromOffset(44, 18), BackgroundColor3 = T.Element, BackgroundTransparency = 0.15,
			Font = T.Font, Text = "0", TextColor3 = T.Accent, TextSize = 11, ClearTextOnFocus = false, Parent = holder,
		})
		Util.Corner(4, b); Util.Stroke(b, T.Border, 1, 0.4)
		Library:RegisterThemed(b, "TextColor3", "Accent")
		return b
	end
	local minBox = makeBox(-50)
	local maxBox = makeBox(0)

	local bar = New("Frame", {
		Position = UDim2.new(0, 0, 0, 28), Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = T.Element, BorderSizePixel = 0, Parent = holder,
	})
	Util.Corner(999, bar); Util.Stroke(bar, T.Border, 1, 0.5)

	local range = New("Frame", { BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = bar })
	Util.Corner(999, range)
	Library:RegisterThemed(range, "BackgroundColor3", "Accent")

	local function makeThumb()
		local t = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = bar,
		})
		Util.Corner(999, t); Util.Glow(t, T.Accent, 0.35)
		return t
	end
	local thumbMin, thumbMax = makeThumb(), makeThumb()

	local obj = { Min = opts.DefaultMin or min, Max = opts.DefaultMax or max, Disabled = false }
	obj.Instance = holder

	local function alphaOf(v) return (max - min) == 0 and 0 or (v - min) / (max - min) end

	local function render()
		local a1, a2 = alphaOf(obj.Min), alphaOf(obj.Max)
		range.Position = UDim2.fromScale(a1, 0)
		range.Size = UDim2.fromScale(a2 - a1, 1)
		thumbMin.Position = UDim2.new(a1, 0, 0.5, 0)
		thumbMax.Position = UDim2.new(a2, 0, 0.5, 0)
		minBox.Text = Util.FormatNumber(obj.Min, step)
		maxBox.Text = Util.FormatNumber(obj.Max, step)
	end

	function obj:Set(lo, hi, skipCallback)
		lo = Util.Clamp(Util.Round(tonumber(lo) or self.Min, step), min, max)
		hi = Util.Clamp(Util.Round(tonumber(hi) or self.Max, step), min, max)
		if lo > hi then lo, hi = hi, lo end
		local gap = opts.MinGap or 0
		if hi - lo < gap then hi = Util.Clamp(lo + gap, min, max); lo = Util.Clamp(hi - gap, min, max) end
		self.Min, self.Max = lo, hi
		if opts.Flag then Library.Flags[opts.Flag] = { Min = lo, Max = hi } end
		render()
		if not skipCallback then task.spawn(function() pcall(opts.Callback or function() end, lo, hi) end) end
	end
	function obj:Get() return self.Min, self.Max end
	function obj:SetDisabled(s) self.Disabled = s and true or false end
	function obj:Destroy() holder:Destroy() end

	local dragTarget = nil
	local function mouseAlpha()
		local x = UserInputService:GetMouseLocation().X
		return Util.Clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
	end

	bar.InputBegan:Connect(function(input)
		if obj.Disabled then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local a = mouseAlpha()
		local v = min + a * (max - min)
		dragTarget = (math.abs(v - obj.Min) <= math.abs(v - obj.Max)) and "min" or "max"
	end)
	Library:Connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragTarget = nil
		end
	end)
	Library:Connect(RunService.RenderStepped, function()
		if not dragTarget then return end
		local v = min + mouseAlpha() * (max - min)
		if dragTarget == "min" then obj:Set(math.min(v, obj.Max), obj.Max)
		else obj:Set(obj.Min, math.max(v, obj.Min)) end
	end)

	minBox.FocusLost:Connect(function() obj:Set(tonumber(minBox.Text), obj.Max) end)
	maxBox.FocusLost:Connect(function() obj:Set(obj.Min, tonumber(maxBox.Text)) end)

	registerFlag(obj, opts.Flag, { Min = obj.Min, Max = obj.Max })
	obj:Set(obj.Min, obj.Max, true)
	return self:_track(obj)
end

---------------------------------------------------------------------- DROPDOWN
-- Shared implementation powering AddDropdown and AddMultiDropdown.
local function buildDropdown(self, opts, multi)
	opts = opts or {}
	local T = Library.Theme
	local values = opts.Options or opts.Values or {}
	local icons = opts.Icons or {}

	local holder = New("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, ClipsDescendants = false, Parent = self.Holder })
	New("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14),
		Font = T.Font, Text = opts.Text or "Dropdown", TextColor3 = T.TextDim, TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = holder,
	})

	local button = New("TextButton", {
		Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 24),
		BackgroundColor3 = T.Element, BackgroundTransparency = 0.1, AutoButtonColor = false, Text = "",
		Parent = holder,
	})
	Util.Corner(6, button)
	local stroke = Util.Stroke(button, T.Border, 1, 0.25)
	Util.Gradient(button, T.Gradient1, T.Gradient2, 20)
	Util.Sheen(button, 0.06)

	local display = New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -30, 1, 0),
		Font = T.Font, Text = opts.Placeholder or "Select...", TextColor3 = T.TextDim, TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = button,
	})
	local arrow = New("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(12, 12), Font = T.FontBold, Text = "v", TextColor3 = T.Accent, TextSize = 11, Parent = button,
	})
	Library:RegisterThemed(arrow, "TextColor3", "Accent")

	-- Popup list rendered at ScreenGui level so it floats above everything.
	local popup = New("Frame", {
		Visible = false, BackgroundColor3 = T.Panel, BackgroundTransparency = 0.04,
		Size = UDim2.fromOffset(200, 0), ZIndex = 500, ClipsDescendants = true, Parent = Library.ScreenGui,
	})
	Util.Corner(6, popup); Util.Stroke(popup, T.Accent, 1, 0.55); Util.Shadow(popup, 40, 0.5)
	Util.Gradient(popup, T.Gradient1, T.Gradient2, 30)
	Util.Sheen(popup, 0.06)

	local searchBox
	local listTop = 4
	if opts.Search ~= false then
		searchBox = New("TextBox", {
			Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 22),
			BackgroundColor3 = T.Element, BackgroundTransparency = 0.1, Font = T.Font,
			PlaceholderText = "Search...", Text = "", TextColor3 = T.Text, TextSize = 12,
			ClearTextOnFocus = false, ZIndex = 502, Parent = popup,
		})
		Util.Corner(4, searchBox); Util.Stroke(searchBox, T.Border, 1, 0.4); Util.Padding(searchBox, 0, 6, 0, 6)
		listTop = 32
	end

	local toolbar
if multi and opts.SelectAll ~= false then
	toolbar = New("Frame", {
		Position = UDim2.fromOffset(6, listTop),
		Size = UDim2.new(1, -12, 0, 20),
		BackgroundTransparency = 1,
		ZIndex = 502,
		Parent = popup,
	})
	local function mini(text, x, cb)
		local b = New("TextButton", {
			Position = UDim2.new(x, 0, 0, 0),
			Size = UDim2.new(0.5, -3, 1, 0),
			BackgroundColor3 = T.Element,
			BackgroundTransparency = 0.15,
			AutoButtonColor = false,
			Font = T.Font,
			Text = text,
			TextColor3 = T.Accent,
			TextSize = 11,
			ZIndex = 503,
			Parent = toolbar,
		})
		Util.Corner(4, b)
		Util.Stroke(b, T.Border, 1, 0.4)
		Library:RegisterThemed(b, "TextColor3", "Accent")
		b.MouseButton1Click:Connect(cb)
		return b
	end
	listTop = listTop + 26
	toolbar.MiniFactory = mini
end

	local scroll = New("ScrollingFrame", {
		Position = UDim2.fromOffset(4, listTop), Size = UDim2.new(1, -8, 1, -listTop - 4),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
		ScrollBarImageColor3 = T.Accent, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 502, Parent = popup,
	})
	Library:RegisterThemed(scroll, "ScrollBarImageColor3", "Accent")
	Util.List(scroll, 2)

	local obj = {
		Value = multi and {} or (opts.Default or nil),
		Options = values,
		Open = false,
		Disabled = false,
		Rows = {},
	}
	obj.Instance = holder

	local function isSelected(v)
		if multi then return obj.Value[v] == true end
		return obj.Value == v
	end

	local function displayText()
		if multi then
			local list = {}
			for _, v in ipairs(obj.Options) do if obj.Value[v] then table.insert(list, tostring(v)) end end
			if #list == 0 then return opts.Placeholder or "None", T.TextDim end
			if #list > 2 then return ("%d selected"):format(#list), T.Text end
			return table.concat(list, ", "), T.Text
		end
		if obj.Value == nil then return opts.Placeholder or "Select...", T.TextDim end
		return tostring(obj.Value), T.Text
	end

	local tagHolder
	if multi and opts.Tags then
		tagHolder = New("Frame", { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = holder })
		New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), Wraps = true, SortOrder = Enum.SortOrder.LayoutOrder, Parent = tagHolder })
	end

	local function renderTags()
		if not tagHolder then return end
		for _, c in ipairs(tagHolder:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
		local count = 0
		for _, v in ipairs(obj.Options) do
			if obj.Value[v] then
				count += 1
				local tag = New("Frame", { Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = T.Element, BackgroundTransparency = 0.1, Parent = tagHolder })
				Util.Corner(999, tag); Util.Stroke(tag, T.Accent, 1, 0.6); Util.Padding(tag, 0, 8, 0, 8)
				New("TextLabel", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 18), Font = T.Font, Text = tostring(v), TextColor3 = T.Accent, TextSize = 11, Parent = tag })
			end
		end
		holder.Size = UDim2.new(1, 0, 0, count > 0 and 68 or 42)
	end

	local function refreshDisplay()
		local txt, col = displayText()
		display.Text = txt
		display.TextColor3 = col
		renderTags()
	end

	local function fire()
		if opts.Flag then
			Library.Flags[opts.Flag] = multi and table.clone(obj.Value) or obj.Value
		end
		task.spawn(function()
			pcall(opts.Callback or function() end, multi and obj:GetSelected() or obj.Value)
		end)
	end

	function obj:GetSelected()
		if not multi then return self.Value end
		local out = {}
		for _, v in ipairs(self.Options) do if self.Value[v] then table.insert(out, v) end end
		return out
	end

	local buildRows

	function obj:Set(v, skipCallback)
		if multi then
			local map = {}
			if typeof(v) == "table" then
				for k, val in pairs(v) do
					if typeof(k) == "number" then map[val] = true else map[k] = val and true or nil end
				end
			end
			self.Value = map
		else
			self.Value = v
		end
		refreshDisplay(); buildRows(searchBox and searchBox.Text or "")
		if not skipCallback then fire() end
	end
	function obj:Get() return multi and self:GetSelected() or self.Value end
	function obj:SetOptions(list)
		self.Options = list or {}
		if not multi and self.Value ~= nil and not table.find(self.Options, self.Value) then self.Value = nil end
		refreshDisplay(); buildRows(searchBox and searchBox.Text or "")
	end
	function obj:SelectAll()
		if not multi then return end
		for _, v in ipairs(self.Options) do self.Value[v] = true end
		refreshDisplay(); buildRows(searchBox and searchBox.Text or ""); fire()
	end
	function obj:ClearAll()
		if multi then self.Value = {} else self.Value = nil end
		refreshDisplay(); buildRows(searchBox and searchBox.Text or ""); fire()
	end
	function obj:SetDisabled(s) self.Disabled = s and true or false
		button.BackgroundTransparency = self.Disabled and 0.5 or 0.1
		display.TextColor3 = self.Disabled and T.TextDim or select(2, displayText())
	end

	-- Now that obj exists, populate the multi toolbar buttons.
	if toolbar and toolbar.MiniFactory then
		toolbar.MiniFactory("Select all", 0, function() obj:SelectAll() end)
		toolbar.MiniFactory("Clear", 0.5, function() obj:ClearAll() end)
		toolbar.MiniFactory = nil
	end

	buildRows = function(filter)
		filter = tostring(filter or ""):lower()
		for _, r in ipairs(scroll:GetChildren()) do if r:IsA("TextButton") then r:Destroy() end end
		for i, v in ipairs(obj.Options) do
			local text = tostring(v)
			if filter == "" or text:lower():find(filter, 1, true) then
				local selected = isSelected(v)
				local row = New("TextButton", {
					Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = selected and T.AccentDark or T.Element,
					BackgroundTransparency = selected and 0.35 or 0.5, AutoButtonColor = false, Text = "",
					LayoutOrder = i, ZIndex = 503, Parent = scroll,
				})
				Util.Corner(4, row)
				if selected then Util.Stroke(row, T.Accent, 1, 0.4) end

				local x = 8
				if multi then
					local cb = New("Frame", {
						Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(12, 12),
						BackgroundColor3 = selected and T.Accent or T.Element, BorderSizePixel = 0, ZIndex = 504, Parent = row,
					})
					Util.Corner(3, cb); Util.Stroke(cb, selected and T.Accent or T.Border, 1, 0.2)
					if selected then
						New("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1,1), Font = T.FontBold, Text = "*", TextColor3 = Color3.new(0,0,0), TextSize = 12, ZIndex = 505, Parent = cb })
					end
					x = 24
				end
				if icons[v] then
					New("ImageLabel", { BackgroundTransparency = 1, Image = icons[v], Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(x, 5), ZIndex = 504, Parent = row })
					x = x + 20
				end
				New("TextLabel", {
					BackgroundTransparency = 1, Position = UDim2.fromOffset(x, 0), Size = UDim2.new(1, -x - 6, 1, 0),
					Font = T.Font, Text = text, TextColor3 = selected and T.Accent or T.Text, TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 504, Parent = row,
				})

				row.MouseButton1Click:Connect(function()
					if multi then
						obj.Value[v] = (not obj.Value[v]) or nil
						refreshDisplay(); buildRows(searchBox and searchBox.Text or ""); fire()
					else
						obj.Value = v
						refreshDisplay(); buildRows(searchBox and searchBox.Text or ""); fire()
						obj:Close()
					end
				end)
			end
		end
	end

	local function popupHeight()
		local rows = #scroll:GetChildren() - 1
		local h = listTop + math.min(math.max(rows, 1), opts.MaxVisible or 6) * 26 + 6
		return math.min(h, 260)
	end

	function obj:Open_()
		if self.Disabled then return end
		self.Open = true
		buildRows(searchBox and searchBox.Text or "")
		popup.Visible = true
		popup.Position = UDim2.fromOffset(button.AbsolutePosition.X, button.AbsolutePosition.Y + button.AbsoluteSize.Y + 4)
		popup.Size = UDim2.fromOffset(button.AbsoluteSize.X, 0)
		Util.Tween(popup, { Size = UDim2.fromOffset(button.AbsoluteSize.X, popupHeight()) }, TW_NORMAL)
		Util.Tween(arrow, { Rotation = 180 }, TW_NORMAL)
		Util.Tween(stroke, { Color = T.Accent, Transparency = 0.1 }, TW_FAST)
	end
	function obj:Close()
		self.Open = false
		Util.Tween(popup, { Size = UDim2.fromOffset(popup.AbsoluteSize.X, 0) }, TW_FAST)
		Util.Tween(arrow, { Rotation = 0 }, TW_NORMAL)
		Util.Tween(stroke, { Color = T.Border, Transparency = 0.25 }, TW_FAST)
		task.delay(0.15, function() if not self.Open then popup.Visible = false end end)
	end
	function obj:Toggle() if self.Open then self:Close() else self:Open_() end end
	function obj:Destroy() popup:Destroy() holder:Destroy() end

	button.MouseButton1Click:Connect(function() obj:Toggle() end)
	if searchBox then
		searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			buildRows(searchBox.Text)
			if obj.Open then Util.Tween(popup, { Size = UDim2.fromOffset(popup.AbsoluteSize.X, popupHeight()) }, TW_FAST) end
		end)
	end
	-- Close on outside click.
	Library:Connect(UserInputService.InputBegan, function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if not obj.Open then return end
		local m = UserInputService:GetMouseLocation()
		local p, s = popup.AbsolutePosition, popup.AbsoluteSize
		local bp, bs = button.AbsolutePosition, button.AbsoluteSize
		local inPopup = m.X >= p.X and m.X <= p.X + s.X and (m.Y - 36) >= p.Y and (m.Y - 36) <= p.Y + s.Y
		local inButton = m.X >= bp.X and m.X <= bp.X + bs.X and (m.Y - 36) >= bp.Y and (m.Y - 36) <= bp.Y + bs.Y
		if not inPopup and not inButton then obj:Close() end
	end)

	registerFlag(obj, opts.Flag, multi and {} or opts.Default)
	if opts.Default ~= nil then obj:Set(opts.Default, true) else refreshDisplay() end
	return self:_track(obj)
end

function Container:AddDropdown(opts) return buildDropdown(self, opts, false) end
function Container:AddMultiDropdown(opts) return buildDropdown(self, opts, true) end

--------------------------------------------------------------------- SEARCHBAR
function Container:AddSearchbar(opts)
	opts = opts or {}
	local T = Library.Theme
	local holder = New("Frame", {
		Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = T.Element, BackgroundTransparency = 0.1, Parent = self.Holder,
	})
	Util.Corner(6, holder)
	local stroke = Util.Stroke(holder, T.Border, 1, 0.25)

	local searchIcon = New("ImageLabel", {
		BackgroundTransparency = 1, Image = Library.Icons.Search, ImageColor3 = T.Accent,
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 9, 0.5, 0), Size = UDim2.fromOffset(13, 13), Parent = holder,
	})
	Library:RegisterThemed(searchIcon, "ImageColor3", "Accent")

	local box = New("TextBox", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -56, 1, 0),
		Font = T.Font, PlaceholderText = opts.Placeholder or "Search...", PlaceholderColor3 = T.TextDim,
		Text = opts.Default or "", TextColor3 = T.Text, TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Parent = holder,
	})

	local clear = New("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(16, 16),
		BackgroundTransparency = 1, Font = T.FontBold, Text = "x", TextColor3 = T.TextDim, TextSize = 13,
		Visible = false, Parent = holder,
	})

	local obj = { Value = box.Text }
	obj.Instance = holder
	local debounceToken = 0

	local function emit()
		debounceToken += 1
		local token = debounceToken
		local delay = opts.Instant and 0 or (opts.Debounce or 0.15)
		task.delay(delay, function()
			if token ~= debounceToken then return end
			if opts.Flag then Library.Flags[opts.Flag] = obj.Value end
			pcall(opts.Callback or function() end, obj.Value)
		end)
	end

	box:GetPropertyChangedSignal("Text"):Connect(function()
		obj.Value = box.Text
		clear.Visible = #box.Text > 0
		emit()
	end)
	clear.MouseButton1Click:Connect(function() box.Text = "" end)
	box.Focused:Connect(function() Util.Tween(stroke, { Color = T.Accent, Transparency = 0.1 }, TW_FAST) end)
	box.FocusLost:Connect(function() Util.Tween(stroke, { Color = T.Border, Transparency = 0.25 }, TW_FAST) end)
	if opts.AutoFocus then task.defer(function() box:CaptureFocus() end) end

	function obj:Set(v, skip) box.Text = tostring(v or "") if skip then debounceToken += 1 end end
	function obj:Get() return obj.Value end
	function obj:Destroy() holder:Destroy() end
	registerFlag(obj, opts.Flag, obj.Value)
	return self:_track(obj)
end

----------------------------------------------------------------------- KEYBIND
local ActiveKeybinds = {}

function Container:AddKeybind(opts)
	opts = opts or {}
	local T = Library.Theme
	local row = elementRow(self.Holder, 26)
	baseLabel(row, opts.Text or "Keybind", 0.6)

	local btn = New("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(74, 20),
		BackgroundColor3 = T.Element, BackgroundTransparency = 0.1, AutoButtonColor = false,
		Font = T.Font, Text = "NONE", TextColor3 = T.Accent, TextSize = 11, Parent = row,
	})
	Util.Corner(5, btn)
	local stroke = Util.Stroke(btn, T.Border, 1, 0.25)
	Library:RegisterThemed(btn, "TextColor3", "Accent")

	local modeBtn = New("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -80, 0.5, 0), Size = UDim2.fromOffset(50, 20),
		BackgroundColor3 = T.Element, BackgroundTransparency = 0.2, AutoButtonColor = false,
		Font = T.Font, Text = "Toggle", TextColor3 = T.TextDim, TextSize = 10,
		Visible = opts.ShowMode ~= false, Parent = row,
	})
	Util.Corner(5, modeBtn); Util.Stroke(modeBtn, T.Border, 1, 0.45)

	local resetBtn = New("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -136, 0.5, 0), Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1, Font = T.FontBold, Text = "<", TextColor3 = T.TextDim, TextSize = 12,
		Visible = opts.ShowReset ~= false, Parent = row,
	})

	local MODES = { "Toggle", "Hold", "Always" }
	local obj = {
		Key = opts.Default,
		Mode = opts.Mode or "Toggle",
		Active = false,
		Listening = false,
		Default = opts.Default,
	}
	obj.Instance = row
	ActiveKeybinds[obj] = true

	local function render()
		btn.Text = obj.Listening and "..." or Util.KeyName(obj.Key)
		modeBtn.Text = obj.Mode
		stroke.Color = obj.Listening and T.Accent or T.Border
	end

	local function setState(v)
		if obj.Active == v then return end
		obj.Active = v
		if opts.Flag then Library.Flags[opts.Flag] = { Key = obj.Key and obj.Key.Name or nil, Mode = obj.Mode } end
		task.spawn(function() pcall(opts.Callback or function() end, v, obj.Key, obj.Mode) end)
	end

	function obj:Set(key, mode, skip)
		if typeof(key) == "string" then
			key = Enum.KeyCode[key] or Enum.UserInputType[key] or nil
		end
		-- Key conflict detection
		if key then
			for other in pairs(ActiveKeybinds) do
				if other ~= obj and other.Key == key then
					Library:Notify({ Title = "Key conflict", Text = Util.KeyName(key) .. " is already bound elsewhere.", Type = "error", Duration = 3 })
					break
				end
			end
		end
		self.Key, self.Mode = key, mode or self.Mode
		if opts.Flag then Library.Flags[opts.Flag] = { Key = key and key.Name or nil, Mode = self.Mode } end
		render()
		if not skip then task.spawn(function() pcall(opts.OnBind or function() end, key, self.Mode) end) end
	end
	function obj:Get() return self.Key, self.Mode end
	function obj:GetState() return self.Mode == "Always" or self.Active end
	function obj:Reset() self:Set(self.Default, opts.Mode or "Toggle") end
	function obj:Destroy() ActiveKeybinds[obj] = nil row:Destroy() end

	btn.MouseButton1Click:Connect(function()
		obj.Listening = true
		render()
	end)
	modeBtn.MouseButton1Click:Connect(function()
		local i = table.find(MODES, obj.Mode) or 1
		obj.Mode = MODES[(i % #MODES) + 1]
		if obj.Mode ~= "Hold" then setState(false) end
		render()
	end)
	resetBtn.MouseButton1Click:Connect(function() obj:Reset() end)

	Library:Connect(UserInputService.InputBegan, function(input, gpe)
		if obj.Listening then
			local key
			if input.UserInputType == Enum.UserInputType.Keyboard then key = input.KeyCode
			elseif input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.MouseButton2
				or input.UserInputType == Enum.UserInputType.MouseButton3 then key = input.UserInputType end
			if key then
				obj.Listening = false
				if key == Enum.KeyCode.Backspace or key == Enum.KeyCode.Escape then obj:Set(nil) else obj:Set(key) end
			end
			return
		end
		if gpe or not obj.Key then return end
		local matched = (input.KeyCode == obj.Key) or (input.UserInputType == obj.Key)
		if not matched then return end
		if obj.Mode == "Hold" then setState(true)
		elseif obj.Mode == "Toggle" then setState(not obj.Active) end
	end)
	Library:Connect(UserInputService.InputEnded, function(input)
		if not obj.Key or obj.Mode ~= "Hold" then return end
		if (input.KeyCode == obj.Key) or (input.UserInputType == obj.Key) then setState(false) end
	end)

	registerFlag(obj, opts.Flag, { Key = obj.Key and obj.Key.Name or nil, Mode = obj.Mode })
	render()
	return self:_track(obj)
end

------------------------------------------------------------------- COLORPICKER
function Container:AddColorpicker(opts)
	opts = opts or {}
	local T = Library.Theme
	local row = elementRow(self.Holder, 26)
	baseLabel(row, opts.Text or "Color", 0.7)

	local preview = New("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(34, 18),
		BackgroundColor3 = opts.Default or T.Accent, AutoButtonColor = false, Text = "", Parent = row,
	})
	Util.Corner(5, preview); Util.Stroke(preview, T.Border, 1, 0.2); Util.Glow(preview, T.Accent, 0.8)

	local panel = New("Frame", {
		Visible = false, Size = UDim2.fromOffset(220, 250), BackgroundColor3 = T.Panel, BackgroundTransparency = 0.04,
		ZIndex = 600, Parent = Library.ScreenGui,
	})
	Util.Corner(8, panel); Util.Stroke(panel, T.Accent, 1, 0.55); Util.Shadow(panel, 44, 0.5)
	Util.Gradient(panel, T.Gradient1, T.Gradient2, 30)
	Util.Sheen(panel, 0.06)

	-- Saturation / Value square
	local sv = New("ImageLabel", {
		Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(160, 140),
		BackgroundColor3 = Color3.fromHSV(0, 1, 1), Image = "rbxassetid://4155801252",
		ZIndex = 601, Parent = panel,
	})
	Util.Corner(6, sv)
	local svCursor = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(8, 8), BackgroundTransparency = 1,
		ZIndex = 603, Parent = sv,
	})
	Util.Corner(999, svCursor); Util.Stroke(svCursor, Color3.new(1, 1, 1), 2, 0)

	-- Hue slider
	local hue = New("Frame", {
		Position = UDim2.fromOffset(178, 10), Size = UDim2.fromOffset(14, 140), BorderSizePixel = 0, ZIndex = 601, Parent = panel,
	})
	Util.Corner(6, hue)
	New("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
			ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
			ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
			ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
		}),
		Parent = hue,
	})
	local hueCursor = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(1, 6, 0, 3),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 603, Parent = hue,
	})
	Util.Corner(2, hueCursor)

	local bigPreview = New("Frame", {
		Position = UDim2.fromOffset(10, 158), Size = UDim2.fromOffset(46, 30), BackgroundColor3 = T.Accent, BorderSizePixel = 0, ZIndex = 601, Parent = panel,
	})
	Util.Corner(6, bigPreview); Util.Stroke(bigPreview, T.Border, 1, 0.3)

	local function inputBox(x, y, w, placeholder)
		local b = New("TextBox", {
			Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, 22),
			BackgroundColor3 = T.Element, BackgroundTransparency = 0.1, Font = T.Font,
			PlaceholderText = placeholder, Text = "", TextColor3 = T.Text, TextSize = 11,
			ClearTextOnFocus = false, ZIndex = 602, Parent = panel,
		})
		Util.Corner(4, b); Util.Stroke(b, T.Border, 1, 0.4)
		return b
	end
	local rBox = inputBox(64, 158, 40, "R")
	local gBox = inputBox(108, 158, 40, "G")
	local bBox = inputBox(152, 158, 40, "B")
	local hexBox = inputBox(10, 190, 120, "#RRGGBB")

	local copyBtn = New("TextButton", {
		Position = UDim2.fromOffset(136, 190), Size = UDim2.fromOffset(74, 22),
		BackgroundColor3 = T.Element, BackgroundTransparency = 0.1, AutoButtonColor = false,
		Font = T.Font, Text = "Copy hex", TextColor3 = T.Accent, TextSize = 11, ZIndex = 602, Parent = panel,
	})
	Util.Corner(4, copyBtn); Util.Stroke(copyBtn, T.Border, 1, 0.4)
	Library:RegisterThemed(copyBtn, "TextColor3", "Accent")

	local hsvLabel = New("TextLabel", {
		Position = UDim2.fromOffset(10, 218), Size = UDim2.new(1, -20, 0, 18), BackgroundTransparency = 1,
		Font = T.Font, Text = "HSV 0, 0, 0", TextColor3 = T.TextDim, TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 602, Parent = panel,
	})

	local def = opts.Default or T.Accent
	local h, s, v = Color3.toHSV(def)
	local obj = { Value = def, H = h, S = s, V = v, Open = false }
	obj.Instance = row

	local updating = false
	local function render(skipBoxes)
		local col = Color3.fromHSV(obj.H, obj.S, obj.V)
		obj.Value = col
		preview.BackgroundColor3 = col
		bigPreview.BackgroundColor3 = col
		sv.BackgroundColor3 = Color3.fromHSV(obj.H, 1, 1)
		svCursor.Position = UDim2.fromScale(obj.S, 1 - obj.V)
		hueCursor.Position = UDim2.fromScale(0.5, obj.H)
		hsvLabel.Text = ("HSV  %d, %d%%, %d%%"):format(obj.H * 360, obj.S * 100, obj.V * 100)
		if not skipBoxes then
			updating = true
			rBox.Text = tostring(math.floor(col.R * 255 + 0.5))
			gBox.Text = tostring(math.floor(col.G * 255 + 0.5))
			bBox.Text = tostring(math.floor(col.B * 255 + 0.5))
			hexBox.Text = Util.ToHex(col)
			updating = false
		end
	end

	local function fire()
		if opts.Flag then Library.Flags[opts.Flag] = obj.Value end
		task.spawn(function() pcall(opts.Callback or function() end, obj.Value) end)
	end

	function obj:Set(color, skipCallback)
		if typeof(color) == "string" then color = Util.FromHex(color) end
		if typeof(color) ~= "Color3" then return end
		self.H, self.S, self.V = Color3.toHSV(color)
		render(); if not skipCallback then fire() end
	end
	function obj:Get() return self.Value end
	function obj:GetHex() return Util.ToHex(self.Value) end
	function obj:Destroy() panel:Destroy() row:Destroy() end

	local function openPanel()
		obj.Open = true
		panel.Visible = true
		panel.Position = UDim2.fromOffset(
			math.min(preview.AbsolutePosition.X - 186, Library.ScreenGui.AbsoluteSize.X - 230),
			preview.AbsolutePosition.Y + 24)
		panel.Size = UDim2.fromOffset(220, 0)
		Util.Tween(panel, { Size = UDim2.fromOffset(220, 250) }, TW_NORMAL)
	end
	local function closePanel()
		obj.Open = false
		Util.Tween(panel, { Size = UDim2.fromOffset(220, 0) }, TW_FAST)
		task.delay(0.16, function() if not obj.Open then panel.Visible = false end end)
	end
	preview.MouseButton1Click:Connect(function() if obj.Open then closePanel() else openPanel() end end)

	local dragSV, dragHue = false, false
	sv.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragSV = true end end)
	hue.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragHue = true end end)
	Library:Connect(UserInputService.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			if dragSV or dragHue then dragSV, dragHue = false, false; fire() end
		end
	end)
	Library:Connect(RunService.RenderStepped, function()
		if not (dragSV or dragHue) then return end
		local m = UserInputService:GetMouseLocation()
		local my = m.Y - 36
		if dragSV then
			obj.S = Util.Clamp((m.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
			obj.V = 1 - Util.Clamp((my - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
		else
			obj.H = Util.Clamp((my - hue.AbsolutePosition.Y) / hue.AbsoluteSize.Y, 0, 1)
		end
		render()
	end)

	local function rgbChanged()
		if updating then return end
		local r = Util.Clamp(tonumber(rBox.Text) or 0, 0, 255)
		local g = Util.Clamp(tonumber(gBox.Text) or 0, 0, 255)
		local b = Util.Clamp(tonumber(bBox.Text) or 0, 0, 255)
		obj:Set(Color3.fromRGB(r, g, b))
	end
	rBox.FocusLost:Connect(rgbChanged)
	gBox.FocusLost:Connect(rgbChanged)
	bBox.FocusLost:Connect(rgbChanged)
	hexBox.FocusLost:Connect(function()
		local c = Util.FromHex(hexBox.Text)
		if c then obj:Set(c) else render() end
	end)
	copyBtn.MouseButton1Click:Connect(function()
		pcall(setclipboard, Util.ToHex(obj.Value))
		Library:Notify({ Title = "Copied", Text = Util.ToHex(obj.Value), Type = "success", Duration = 2 })
	end)

	registerFlag(obj, opts.Flag, obj.Value)
	render()
	return self:_track(obj)
end

--------------------------------------------------------------- SCROLLING FRAME
function Container:AddScrollingFrame(opts)
	opts = opts or {}
	local T = Library.Theme
	local horizontal = (opts.Direction or "Vertical") == "Horizontal"

	local frame = New("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, opts.Height or 140),
		BackgroundColor3 = T.BackgroundAlt,
		BackgroundTransparency = opts.Transparent and 1 or 0.35,
		BorderSizePixel = 0,
		ScrollBarThickness = opts.ScrollBarThickness or 4,
		ScrollBarImageColor3 = opts.ScrollBarColor or T.Accent,
		ScrollBarImageTransparency = 0.2,
		ScrollingDirection = horizontal and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = horizontal and Enum.AutomaticSize.X or Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		ScrollingEnabled = true,
		Parent = self.Holder,
	})
	Util.Corner(6, frame)
	if not opts.Transparent then Util.Stroke(frame, T.Border, 1, 0.5) end
	Util.Padding(frame, opts.Padding or 6)
	Util.List(frame, opts.Gap or 6, horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical)
	Library:RegisterThemed(frame, "ScrollBarImageColor3", "Accent")

	local sub = Container.new(frame, self.Window)
	sub.Instance = frame
	function sub:ScrollToTop() frame.CanvasPosition = Vector2.new(0, 0) end
	function sub:ScrollToBottom() frame.CanvasPosition = Vector2.new(0, frame.AbsoluteCanvasSize.Y) end
	function sub:Destroy() frame:Destroy() end
	return self:_track(sub)
end

------------------------------------------------------------------- GROUPBOX
function Container:AddGroupbox(titleOrOpts, maybeOpts)
	local opts = typeof(titleOrOpts) == "table" and titleOrOpts or (maybeOpts or {})
	if typeof(titleOrOpts) == "string" then opts.Title = titleOrOpts end
	local T = Library.Theme

	local box = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.Panel, BackgroundTransparency = 0.15, Parent = self.Holder,
	})
	Util.Corner(8, box)
	local stroke = Util.Stroke(box, T.Border, 1, 0.25)
	Util.Gradient(box, T.Gradient1, T.Gradient2, 35)
	Util.Sheen(box, 0.06)

	local header = New("TextButton", {
		Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, AutoButtonColor = false, Text = "", Parent = box,
	})
	local accentBar = New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(3, 13),
		BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = header,
	})
	Util.Corner(2, accentBar)
	Library:RegisterThemed(accentBar, "BackgroundColor3", "Accent")

	local titleX = 23
	if opts.Icon then
		local ic = New("ImageLabel", {
			BackgroundTransparency = 1, Image = opts.Icon, ImageColor3 = T.Accent, Size = UDim2.fromOffset(14, 14),
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 23, 0.5, 0), Parent = header,
		})
		Library:RegisterThemed(ic, "ImageColor3", "Accent")
		titleX = 44
	end
	New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(titleX, 0), Size = UDim2.new(1, -titleX - 32, 1, 0),
		Font = T.FontBold, Text = opts.Title or "Group", TextColor3 = T.Text, TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = header,
	})
	local chevron = New("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(14, 14), Font = T.FontBold, Text = "⌄", TextColor3 = T.TextDim, TextSize = 12,
		Visible = opts.Collapsible ~= false, Parent = header,
	})
	local headerDivider = New("Frame", {
		Position = UDim2.new(0, 12, 1, 0), Size = UDim2.new(1, -24, 0, 1),
		BackgroundColor3 = T.Border, BackgroundTransparency = 0.55, BorderSizePixel = 0, Parent = header,
	})

	local body = New("Frame", {
		Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ClipsDescendants = false, Parent = box,
	})
	Util.Padding(body, 12, 12, 12, 12)
	Util.List(body, 8)

	header.MouseEnter:Connect(function() Util.Tween(chevron, { TextColor3 = T.Accent }, TW_FAST) end)
	header.MouseLeave:Connect(function() Util.Tween(chevron, { TextColor3 = T.TextDim }, TW_FAST) end)

	local sub = Container.new(body, self.Window)
	sub.Instance = box
	sub.Collapsed = false

	function sub:SetCollapsed(state)
		self.Collapsed = state and true or false
		body.Visible = not self.Collapsed
		box.AutomaticSize = Enum.AutomaticSize.Y
		if self.Collapsed then
			box.AutomaticSize = Enum.AutomaticSize.None
			box.Size = UDim2.new(1, 0, 0, 36)
		end
		Util.Tween(chevron, { Rotation = self.Collapsed and -90 or 0 }, TW_NORMAL)
	end
	function sub:SetDisabled(state)
		self.Disabled = state and true or false
		body.Visible = not self.Disabled and not self.Collapsed
		stroke.Transparency = self.Disabled and 0.7 or 0.25
		for _, el in ipairs(self.Elements) do if el.SetDisabled then el:SetDisabled(state) end end
	end
	function sub:Destroy() box:Destroy() end

	if opts.Collapsible ~= false then
		header.MouseButton1Click:Connect(function() sub:SetCollapsed(not sub.Collapsed) end)
	end
	if opts.Collapsed then sub:SetCollapsed(true) end

	table.insert(self.Elements, sub)
	return sub
end

--------------------------------------------------------------------- TABBOX
function Container:AddTabbox(opts)
	opts = opts or {}
	local T = Library.Theme

	local box = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.Panel, BackgroundTransparency = 0.15, Parent = self.Holder,
	})
	Util.Corner(8, box); Util.Stroke(box, T.Border, 1, 0.25)
	Util.Gradient(box, T.Gradient1, T.Gradient2, 35)
	Util.Sheen(box, 0.06)

	-- Segmented pill strip (skeet-style) instead of a bare underline row.
	local stripHolder = New("Frame", {
		Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 12),
		BackgroundColor3 = T.BackgroundAlt, BackgroundTransparency = 0.25, Parent = box,
	})
	Util.Corner(8, stripHolder)
	Util.Stroke(stripHolder, T.Border, 1, 0.45)

	local strip = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = stripHolder })
	Util.Padding(strip, 4, 4, 4, 4)
	Util.List(strip, 4, Enum.FillDirection.Horizontal)

	local bodies = New("Frame", {
		Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = box,
	})

	local tabbox = { Tabs = {}, Current = nil, Instance = box }

	function tabbox:AddTab(name, tabOpts)
		tabOpts = tabOpts or {}
		local btn = New("TextButton", {
			Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = T.Element, BackgroundTransparency = 1, AutoButtonColor = false, Text = "", Parent = strip,
		})
		Util.Corner(6, btn)
		Util.Padding(btn, 0, 12, 0, 12)
		local label = New("TextLabel", {
			BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22),
			Font = T.FontBold, Text = name, TextColor3 = T.TextDim, TextSize = 12, Parent = btn,
		})
		local badge
		local close
		local body = New("Frame", {
			Visible = false, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1, Parent = bodies,
		})
		Util.Padding(body, 4, 12, 12, 12)
		Util.List(body, 8)

		local sub = Container.new(body, self.Window)
		sub.Instance = body
		sub.Button = btn

		function sub:Select()
			local T = Library.Theme
			for _, t in ipairs(tabbox.Tabs) do
				t.Body.Visible = false
				t.Label.TextColor3 = T.TextDim
				Util.Tween(t.Button, { BackgroundTransparency = 1 }, TW_FAST)
				if t.IconImage then Util.Tween(t.IconImage, { ImageColor3 = T.TextDim }, TW_FAST) end
			end
			body.Visible = true
			label.TextColor3 = T.Text
			Util.Tween(btn, { BackgroundTransparency = 0.15 }, TW_FAST)
			if sub.IconImage then Util.Tween(sub.IconImage, { ImageColor3 = T.Accent }, TW_FAST) end
			tabbox.Current = sub
		end
		function sub:SetBadge(n)
			if not badge then
				badge = New("TextLabel", {
					AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, 2, 0.5, 0), Size = UDim2.fromOffset(16, 14),
					BackgroundColor3 = T.Accent, Font = T.FontBold, Text = "0", TextColor3 = Color3.new(0, 0, 0), TextSize = 10, Parent = btn,
				})
				Util.Corner(999, badge)
				Library:RegisterThemed(badge, "BackgroundColor3", "Accent")
			end
			badge.Visible = (tonumber(n) or 0) > 0
			badge.Text = tostring(n)
		end
		function sub:Destroy() btn:Destroy() body:Destroy() end

		if tabOpts.Closeable then
			close = New("TextButton", {
				AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, 2, 0.5, 0), Size = UDim2.fromOffset(14, 14),
				BackgroundTransparency = 1, Font = T.FontBold, Text = "x", TextColor3 = T.TextDim, TextSize = 11, Parent = btn,
			})
			close.MouseButton1Click:Connect(function()
				local idx = table.find(tabbox.Tabs, sub)
				if idx then table.remove(tabbox.Tabs, idx) end
				sub:Destroy()
				if tabbox.Tabs[1] then tabbox.Tabs[1]:Select() end
			end)
		end
		if tabOpts.Icon then
			label.Position = UDim2.fromOffset(17, 0)
			sub.IconImage = New("ImageLabel", {
				BackgroundTransparency = 1, Image = tabOpts.Icon, ImageColor3 = T.TextDim,
				Size = UDim2.fromOffset(13, 13), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Parent = btn,
			})
		end
		if tabOpts.Badge then sub:SetBadge(tabOpts.Badge) end

		sub.Body, sub.Label = body, label
		btn.MouseButton1Click:Connect(function() sub:Select() end)
		table.insert(tabbox.Tabs, sub)
		if #tabbox.Tabs == 1 then task.defer(function() sub:Select() end) end
		return sub
	end

	table.insert(self.Elements, tabbox)
	return tabbox
end

--============================================================================--
-- WINDOW
--============================================================================--
function Library:CreateWindow(opts)
	opts = opts or {}
	local T = self.Theme
	local size = opts.Size or UDim2.fromOffset(700, 500)

	local main = New("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = opts.Position or UDim2.fromScale(0.5, 0.5),
		Size = size,
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0,
		ClipsDescendants = false,
		Parent = self.ScreenGui,
	})
	Util.Corner(10, main)
	Util.Stroke(main, Color3.fromRGB(8, 8, 8), 1, 0)
	-- inner light bevel line, the classic skeet double border
	local bevel = New("Frame", {
		Name = "Bevel", Size = UDim2.new(1, -2, 1, -2), Position = UDim2.fromOffset(1, 1),
		BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 10, Parent = main,
	})
	Util.Stroke(bevel, Color3.fromRGB(58, 58, 58), 1, 0.35)
	Util.Shadow(main, 60, 0.4)
	Util.Gradient(main, T.Gradient1, T.Gradient2, 35)
	Util.Sheen(main, 0.06)
	Util.Glass(New("Frame", {
		Name = "GlassOverlay", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, Parent = main,
	}), 0.94)
	local glassOverlay = main:FindFirstChild("GlassOverlay")
if glassOverlay then
	Util.Corner(10, glassOverlay)
end

	-- Header
	local header = New("Frame", {
		Name = "Header", Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = T.Panel, BackgroundTransparency = 0, Parent = main,
	})
	Util.Corner(10, header)
	Util.Gradient(header, T.Gradient2, T.Gradient1, 0)
	Util.Sheen(header, 0.06)
	New("Frame", { Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = T.Panel, BackgroundTransparency = 0, BorderSizePixel = 0, Parent = header })

	local accentLine = New("Frame", {
		Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = header,
	})
	Library:RegisterThemed(accentLine, "BackgroundColor3", "Accent")
	New("UIGradient", {
		Color = ColorSequence.new(T.Accent),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = accentLine,
	})

	local logo = New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(6, 6),
		BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = header,
	})
	Util.Corner(2, logo)
	Util.Glow(logo, T.Accent, 0.35)
	Library:RegisterThemed(logo, "BackgroundColor3", "Accent")

	local titleLabel = New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -170, 1, 0),
		Font = T.FontBold, Text = opts.Title or "SkeetwareUI", TextColor3 = T.Text, TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = header,
	})
	local subLabel = New("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -104, 0.5, 0),
		Size = UDim2.fromOffset(200, 14), Font = T.Font, Text = opts.Subtitle or ("v" .. self.Version),
		TextColor3 = T.TextDim, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right, Parent = header,
	})

	local function headerButton(x, glyph, cb, danger)
		local b = New("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, x, 0.5, 0), Size = UDim2.fromOffset(24, 24),
			BackgroundColor3 = T.Element, BackgroundTransparency = 0.25, AutoButtonColor = false,
			Font = T.FontBold, Text = glyph, TextColor3 = T.TextDim, TextSize = 13, Parent = header,
		})
		Util.Corner(7, b); Util.Stroke(b, T.Border, 1, 0.4)
		local hoverColor = danger and T.Risky or T.Accent
		b.MouseEnter:Connect(function() Util.Tween(b, { BackgroundTransparency = 0.05 }, TW_FAST); b.TextColor3 = hoverColor end)
		b.MouseLeave:Connect(function() Util.Tween(b, { BackgroundTransparency = 0.25 }, TW_FAST); b.TextColor3 = T.TextDim end)
		b.MouseButton1Click:Connect(cb)
		return b
	end


	local window = { Tabs = {}, Current = nil, Minimized = false, Maximized = false, Instance = main }

	-- Clipped body so nothing can spill outside the rounded window frame.
	local body = New("Frame", {
		Name = "Body", Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44),
		BackgroundTransparency = 1, ClipsDescendants = true, Parent = main,
	})

	-- Sidebar tab navigation
	local sidebar = New("Frame", {
		Name = "Sidebar", Size = UDim2.new(0, 168, 1, 0),
		BackgroundColor3 = T.BackgroundAlt, BackgroundTransparency = 0.25,
		ClipsDescendants = true, Parent = body,
	})
	New("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = T.Border, BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 3, Parent = sidebar })

	local navList = New("Frame", {
		Name = "Nav", Size = UDim2.new(1, 0, 1, -34), BackgroundTransparency = 1, Parent = sidebar,
	})
	Util.Padding(navList, 14, 12, 12, 12)
	Util.List(navList, 6)

	New("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -12),
		Size = UDim2.new(1, -28, 0, 14), Font = T.Font,
		Text = (opts.Footer or "skeetware.cc") .. "  •  " .. Util.KeyName(opts.ToggleKey or self.ToggleKey),
		TextColor3 = T.TextDim, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
		TextTransparency = 0.25, Parent = sidebar,
	})

	local pageHolder = New("Frame", {
		Position = UDim2.fromOffset(168, 0), Size = UDim2.new(1, -168, 1, 0),
		BackgroundTransparency = 1, ClipsDescendants = true, Parent = body,
	})

	--- Window:AddTab(name, icon)
	function window:AddTab(name, icon)
		local T = Library.Theme
		local btn = New("TextButton", {
			Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = T.Element, BackgroundTransparency = 1,
			AutoButtonColor = false, Text = "", Parent = navList,
		})
		Util.Corner(7, btn)
		local marker = New("Frame", {
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(3, 16),
			BackgroundColor3 = T.Accent, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = btn,
		})
		Util.Corner(2, marker)
		Library:RegisterThemed(marker, "BackgroundColor3", "Accent")

		local x = 14
		local iconImg
		if icon then
			iconImg = New("ImageLabel", {
				BackgroundTransparency = 1, Image = icon, ImageColor3 = T.TextDim,
				Size = UDim2.fromOffset(15, 15), AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 14, 0.5, 0), Parent = btn,
			})
			x = 39
		end
		local label = New("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(x, 0), Size = UDim2.new(1, -x - 10, 1, 0),
			Font = T.FontBold, Text = name, TextColor3 = T.TextDim, TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left, Parent = btn,
		})

		-- Page: two responsive columns of groupboxes.
		local page = New("ScrollingFrame", {
			Visible = false, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
			ScrollBarThickness = 4, ScrollBarImageColor3 = T.Accent, CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = pageHolder,
		})
		Library:RegisterThemed(page, "ScrollBarImageColor3", "Accent")
		Util.Padding(page, 16, 14, 16, 16)
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder, Parent = page,
		})

		local function makeColumn()
			local col = New("Frame", { Size = UDim2.new(0.5, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = page })
			Util.List(col, 12)
			return col
		end
		local left, right = makeColumn(), makeColumn()

		local tab = Container.new(left, window)
		tab.Left, tab.Right = Container.new(left, window), Container.new(right, window)
		tab.Instance = page
		tab.Button = btn
		tab.Name = name

		-- Alternate sides automatically for AddGroupbox/AddTabbox on the tab itself.
		local sideFlip = false
		local rawGroup, rawTabbox = Container.AddGroupbox, Container.AddTabbox
		function tab:AddGroupbox(a, b)
			sideFlip = not sideFlip
			return rawGroup(sideFlip and self.Left or self.Right, a, b)
		end
		function tab:AddTabbox(o)
			sideFlip = not sideFlip
			return rawTabbox(sideFlip and self.Left or self.Right, o)
		end

		function tab:Select()
			local T = Library.Theme
			for _, t in ipairs(window.Tabs) do
				t.Page.Visible = false
				Util.Tween(t.Button, { BackgroundTransparency = 1 }, TW_FAST)
				Util.Tween(t.Marker, { BackgroundTransparency = 1 }, TW_FAST)
				t.Label.TextColor3 = T.TextDim
				if t.Icon then Util.Tween(t.Icon, { ImageColor3 = T.TextDim }, TW_FAST) end
			end
			page.Visible = true
			page.Position = UDim2.fromOffset(0, 8)
			Util.Tween(page, { Position = UDim2.fromOffset(0, 0) }, TW_SLOW)
			Util.Tween(btn, { BackgroundTransparency = 0.72 }, TW_FAST)
			Util.Tween(marker, { BackgroundTransparency = 0 }, TW_FAST)
			label.TextColor3 = T.Text
			if iconImg then Util.Tween(iconImg, { ImageColor3 = T.Accent }, TW_FAST) end
			window.Current = tab
		end
		function tab:Destroy() btn:Destroy() page:Destroy() end

		tab.Page, tab.Marker, tab.Label, tab.Icon = page, marker, label, iconImg
		btn.MouseButton1Click:Connect(function() tab:Select() end)
		btn.MouseEnter:Connect(function() if window.Current ~= tab then Util.Tween(btn, { BackgroundTransparency = 0.88 }, TW_FAST) end end)
		btn.MouseLeave:Connect(function() if window.Current ~= tab then Util.Tween(btn, { BackgroundTransparency = 1 }, TW_FAST) end end)

		table.insert(window.Tabs, tab)
		if #window.Tabs == 1 then task.defer(function() tab:Select() end) end
		return tab
	end

	-- Minimize / Maximize / Close
	local originalSize, originalPos = size, main.Position
	local minBtn = headerButton(-74, "–", function() window:Minimize() end)
	local maxBtn = headerButton(-45, "□", function() window:Maximize() end)
	local closeBtn = headerButton(-16, "✕", function() Library:Unload() end, true)

	function window:Minimize()
		self.Minimized = not self.Minimized
		if self.Minimized then
			Util.Tween(main, { Size = UDim2.fromOffset(main.AbsoluteSize.X, 44) }, TW_NORMAL)
			body.Visible = false
		else
			body.Visible = true
			Util.Tween(main, { Size = self.Maximized and UDim2.fromScale(0.96, 0.94) or originalSize }, TW_NORMAL)
		end
	end
	function window:Maximize()
		self.Maximized = not self.Maximized
		if self.Maximized then
			originalPos = main.Position
			Util.Tween(main, { Size = UDim2.fromScale(0.96, 0.94), Position = UDim2.fromScale(0.5, 0.5) }, TW_NORMAL)
		else
			Util.Tween(main, { Size = originalSize, Position = originalPos }, TW_NORMAL)
		end
	end
	function window:Toggle(state)
		if state == nil then state = not main.Visible end
		main.Visible = state
	end
	--- window:SetScale(number) — global UI scale (0.75 – 1.35 recommended).
	function window:SetScale(n)
		local scale = main:FindFirstChildOfClass("UIScale") or New("UIScale", { Parent = main })
		scale.Scale = math.clamp(tonumber(n) or 1, 0.5, 2)
	end
	--- window:SetOpacity(number) — 1 = solid, lower = more see-through.
	function window:SetOpacity(n)
		local a = 1 - math.clamp(tonumber(n) or 1, 0.2, 1)
		main.BackgroundTransparency = 0.05 + a
		header.BackgroundTransparency = 0.15 + a * 0.6
		sidebar.BackgroundTransparency = 0.25 + a * 0.6
	end
	function window:Destroy() main:Destroy() end

	-- Dragging (mouse + touch)
	do
		local dragging, dragStart, startPos = false, nil, nil
		header.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = input.Position
				startPos = main.Position
			end
		end)
		Library:Connect(UserInputService.InputChanged, function(input)
			if not dragging then return end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
			local delta = input.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end)
		Library:Connect(UserInputService.InputEnded, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
		end)
	end

	-- Responsive clamp: keep the window on screen.
	Library:Connect(Library.ScreenGui:GetPropertyChangedSignal("AbsoluteSize"), function()
		local vp = Library.ScreenGui.AbsoluteSize
		if main.AbsoluteSize.X > vp.X - 20 then main.Size = UDim2.fromOffset(vp.X - 20, main.AbsoluteSize.Y) end
		if main.AbsoluteSize.Y > vp.Y - 20 then main.Size = UDim2.fromOffset(main.AbsoluteSize.X, vp.Y - 20) end
	end)

	-- UI toggle hotkey
	Library:Connect(UserInputService.InputBegan, function(input, gpe)
		if gpe then return end
		if input.KeyCode == (opts.ToggleKey or Library.ToggleKey) then window:Toggle() end
	end)

	-- Entrance animation
	main.Size = UDim2.fromOffset(size.X.Offset * 0.9, size.Y.Offset * 0.9)
	main.BackgroundTransparency = 1
	Util.Tween(main, { Size = size, BackgroundTransparency = 0.05 }, TW_SLOW)

	Library.Window = window
	return window
end

--============================================================================--
-- CONFIGURATION SYSTEM
--============================================================================--
local function serializeValue(v)
	if typeof(v) == "Color3" then return { __t = "Color3", R = v.R, G = v.G, B = v.B } end
	if typeof(v) == "EnumItem" then return { __t = "Enum", Name = v.Name } end
	if typeof(v) == "table" then
		local out = {}
		for k, val in pairs(v) do out[tostring(k)] = serializeValue(val) end
		return out
	end
	return v
end

local function deserializeValue(v)
	if typeof(v) == "table" then
		if v.__t == "Color3" then return Color3.new(v.R, v.G, v.B) end
		if v.__t == "Enum" then return v.Name end
		local out = {}
		for k, val in pairs(v) do out[k] = deserializeValue(val) end
		return out
	end
	return v
end

function Library:_ensureFolder()
	if not FS_AVAILABLE then return false end
	if isfolder_ and makefolder_ and not isfolder_(self.ConfigFolder) then
		pcall(makefolder_, self.ConfigFolder)
	end
	return true
end

function Library:GetConfigTable()
	local data = {}
	for flag, value in pairs(self.Flags) do
		data[flag] = serializeValue(value)
	end
	return data
end

function Library:LoadConfigTable(data)
	for flag, raw in pairs(data or {}) do
		local element = self.Registry[flag]
		local value = deserializeValue(raw)
		if element then
			pcall(function()
				if typeof(value) == "table" and value.Min ~= nil and value.Max ~= nil and element.Set then
					element:Set(value.Min, value.Max)
				elseif typeof(value) == "table" and value.Key ~= nil and element.Set then
					element:Set(value.Key, value.Mode)
				elseif element.Set then
					element:Set(value)
				end
			end)
		else
			self.Flags[flag] = value
		end
	end
end

function Library:SaveConfig(name)
	name = tostring(name or "default")
	if not self:_ensureFolder() then
		self:Notify({ Title = "Config", Text = "Filesystem not supported by this executor.", Type = "error" })
		return false
	end
	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, self:GetConfigTable())
	if not ok then
		self:Notify({ Title = "Config", Text = "Failed to encode config.", Type = "error" })
		return false
	end
	local ok2 = pcall(writefile_, self.ConfigFolder .. "/" .. name .. ".json", encoded)
	if ok2 then self:Notify({ Title = "Config saved", Text = name, Type = "success" }) end
	return ok2
end

function Library:LoadConfig(name)
	name = tostring(name or "default")
	if not FS_AVAILABLE then return false end
	local path = self.ConfigFolder .. "/" .. name .. ".json"
	if not isfile_(path) then
		self:Notify({ Title = "Config", Text = "Config '" .. name .. "' not found.", Type = "error" })
		return false
	end
	local ok, decoded = pcall(function() return HttpService:JSONDecode(readfile_(path)) end)
	if not ok then
		self:Notify({ Title = "Config", Text = "Config file is corrupt.", Type = "error" })
		return false
	end
	self:LoadConfigTable(decoded)
	self:Notify({ Title = "Config loaded", Text = name, Type = "success" })
	return true
end

function Library:DeleteConfig(name)
	if not FS_AVAILABLE or not delfile_ then return false end
	local path = self.ConfigFolder .. "/" .. tostring(name) .. ".json"
	if isfile_(path) then pcall(delfile_, path) return true end
	return false
end

function Library:ListConfigs()
	local out = {}
	if not FS_AVAILABLE or not listfiles_ then return out end
	self:_ensureFolder()
	local ok, files = pcall(listfiles_, self.ConfigFolder)
	if not ok then return out end
	for _, f in ipairs(files) do
		local n = tostring(f):match("([^/\\]+)%.json$")
		if n then table.insert(out, n) end
	end
	return out
end

--============================================================================--
-- DESTROY / UNLOAD
--============================================================================--
function Library:Unload()
	if self.Unloaded then return end
	self.Unloaded = true
	for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
	table.clear(self.Connections)
	table.clear(self.Objects)
	table.clear(self.Registry)
	if self.OnUnload then pcall(self.OnUnload) end
	if self.ScreenGui then pcall(function() self.ScreenGui:Destroy() end) end
end
Library.Destroy = Library.Unload

--============================================================================--
-- BUILT-IN SETTINGS TAB (theme manager + config manager + menu keybinds)
--============================================================================--
--- Library:CreateSettingsTab(window, opts) -> tab
--- Adds a fully wired "Settings" tab: accent/theme manager, UI scale &
--- transparency, menu keybind picker and a complete config manager.
function Library:CreateSettingsTab(window, opts)
	opts = opts or {}
	local tab = window:AddTab(opts.Name or "Settings", Library.Icons.Settings)

	------------------------------------------------------------------ THEME
	local theme = tab:AddGroupbox({ Title = "Theme manager", Icon = Library.Icons.Palette })

	local presets = {
		["Skeetware Cyan"] = Color3.fromRGB(0, 240, 255),
		["Neon Purple"]    = Color3.fromRGB(170, 110, 255),
		["Toxic Green"]     = Color3.fromRGB(80, 240, 140),
		["Sunset Orange"]  = Color3.fromRGB(255, 140, 60),
		["Hot Pink"]       = Color3.fromRGB(255, 70, 150),
		["Ice White"]      = Color3.fromRGB(225, 235, 250),
	}
	local presetNames = {}
	for name in pairs(presets) do table.insert(presetNames, name) end
	table.sort(presetNames)

	local accentPicker
	theme:AddDropdown({
		Text = "Accent preset", Flag = "ui_accent_preset", Options = presetNames,
		Default = "Skeetware Cyan",
		Callback = function(name)
			local c = presets[name]
			if c then
				Library:SetAccent(c)
				if accentPicker then accentPicker:Set(c, true) end
			end
		end,
	})
	accentPicker = theme:AddColorpicker({
		Text = "Custom accent", Flag = "ui_accent", Default = Library.Theme.Accent,
		Callback = function(c) Library:SetAccent(c) end,
	})
	theme:AddSlider({
		Text = "UI scale", Flag = "ui_scale", Min = 0.75, Max = 1.35, Step = 0.05, Default = 1,
		Suffix = "x", Callback = function(v) window:SetScale(v) end,
	})
	theme:AddSlider({
		Text = "Background opacity", Flag = "ui_opacity", Min = 0.35, Max = 1, Step = 0.05, Default = 0.95,
		Callback = function(v) window:SetOpacity(v) end,
	})

	------------------------------------------------------------------- MENU
	local menu = tab:AddGroupbox({ Title = "Menu", Icon = Library.Icons.Sliders })
	menu:AddKeybind({
		Text = "Toggle menu", Flag = "ui_toggle_key", Default = Library.ToggleKey, Mode = "Always",
		Callback = function() end,
		OnBind = function(key) if key then Library.ToggleKey = key end end,
	})
	menu:AddToggle({
		Text = "Notifications", Flag = "ui_notifications", Default = true,
		Callback = function(v) Library.NotificationsEnabled = v end,
	})
	menu:AddButton({ Text = "Rejoin-safe unload", Icon = Library.Icons.Power, Risky = true,
		Callback = function() Library:Unload() end })

	----------------------------------------------------------------- CONFIG
	local cfgBox = tab:AddGroupbox({ Title = "Config manager", Icon = Library.Icons.Save })
	local nameBox = cfgBox:AddSearchbar({ Placeholder = "Config name…", Instant = true })
	local listDrop = cfgBox:AddDropdown({ Text = "Saved configs", Options = Library:ListConfigs() })

	local function refresh()
		local list = Library:ListConfigs()
		listDrop:SetOptions(list)
		return list
	end
	local function selected()
		local n = nameBox:Get()
		if n and n ~= "" then return n end
		return listDrop:Get()
	end

	cfgBox:AddButton({ Text = "Save", Icon = Library.Icons.Save, Callback = function()
		local n = selected()
		if not n or n == "" then
			Library:Notify({ Title = "Config", Text = "Enter a config name first.", Type = "error" })
			return
		end
		Library:SaveConfig(n); refresh()
	end })
	cfgBox:AddButton({ Text = "Load", Icon = Library.Icons.Download, Callback = function()
		local n = selected()
		if n and n ~= "" then Library:LoadConfig(n) end
	end })
	cfgBox:AddButton({ Text = "Delete", Icon = Library.Icons.Trash, Risky = true, Callback = function()
		local n = selected()
		if n and n ~= "" and Library:DeleteConfig(n) then
			Library:Notify({ Title = "Config deleted", Text = n, Type = "success" })
			refresh()
		end
	end })
	cfgBox:AddButton({ Text = "Refresh list", Icon = Library.Icons.Refresh, Callback = function()
		Library:Notify({ Title = "Config", Text = #refresh() .. " config(s) found.", Type = "info" })
	end })
	cfgBox:AddTextlabel({ Text = "Folder: <b>" .. Library.ConfigFolder .. "</b>", RichText = true, Copyable = true })

	return tab
end

--============================================================================--
-- EXAMPLE USAGE (delete or keep — runs only when EXAMPLE is true)
--============================================================================--
local EXAMPLE = false
if EXAMPLE then
	local Window = Library:CreateWindow({ Title = "skeetware.cc", Subtitle = "premium build", Size = UDim2.fromOffset(760, 540) })

	local Legit = Window:AddTab("Legit", Library.Icons.Target)
	local Rage = Window:AddTab("Rage", Library.Icons.Crosshair)
	local Visuals = Window:AddTab("Visuals", Library.Icons.Eye)
	local Misc = Window:AddTab("Misc", Library.Icons.Sliders)

	local aim = Legit:AddGroupbox({ Title = "Aimbot", Icon = Library.Icons.Target })
	local enabled = aim:AddToggle({ Text = "Enabled", Flag = "aim_enabled", Default = true })
	local fov = aim:AddSlider({ Text = "FOV", Flag = "aim_fov", Min = 0, Max = 360, Step = 1, Default = 90, Ticks = 6 })
	enabled:AddChild(fov)
	aim:AddSlider({ Text = "Smoothing", Flag = "aim_smooth", Min = 0, Max = 1, Step = 0.05, Default = 0.35 })
	aim:AddMinMaxSlider({ Text = "Distance range", Flag = "aim_range", Min = 0, Max = 500, DefaultMin = 50, DefaultMax = 300 })
	aim:AddKeybind({ Text = "Aim key", Flag = "aim_key", Default = Enum.UserInputType.MouseButton2, Mode = "Hold" })
	aim:AddDropdown({ Text = "Hitbox", Flag = "aim_hitbox", Options = { "Head", "Torso", "Nearest" }, Default = "Head" })
	aim:AddMultiDropdown({ Text = "Targets", Flag = "aim_targets", Options = { "Players", "NPCs", "Pets", "Turrets" }, Tags = true })

	local checks = Legit:AddGroupbox({ Title = "Target checks", Icon = Library.Icons.Shield })
	checks:AddToggle({ Text = "Visible check", Default = true })
	checks:AddToggle({ Text = "Wall check", Default = true })
	checks:AddToggle({ Text = "Team check" })

	local rage = Rage:AddGroupbox({ Title = "Silent aim", Icon = Library.Icons.Crosshair })
	rage:AddToggle({ Text = "Enabled", Flag = "rage_enabled" })
	rage:AddSlider({ Text = "Hit chance", Flag = "rage_hc", Min = 0, Max = 100, Step = 1, Default = 100, Suffix = "%" })

	local espBox = Visuals:AddTabbox()
	local players = espBox:AddTab("Players", { Icon = Library.Icons.Users })
	players:AddToggle({ Text = "Boxes", Flag = "esp_box", Default = true })
	players:AddColorpicker({ Text = "Box color", Flag = "esp_box_color", Default = Color3.fromRGB(0, 240, 255) })
	players:AddToggle({ Text = "Names", Default = true })
	players:AddDropdown({ Text = "Box style", Options = { "Corner", "Full", "2D" }, Default = "Corner" })
	local world = espBox:AddTab("World", { Icon = Library.Icons.Globe, Badge = 3 })
	world:AddToggle({ Text = "Chams" })
	world:AddSearchbar({ Placeholder = "Filter entities" })
	local sf = world:AddScrollingFrame({ Height = 130 })
	for i = 1, 12 do sf:AddToggle({ Text = "Entity " .. i }) end

	local misc = Misc:AddGroupbox({ Title = "Movement", Icon = Library.Icons.Zap })
	misc:AddToggle({ Text = "Bunny hop" })
	misc:AddSlider({ Text = "Walk speed", Min = 16, Max = 120, Step = 1, Default = 16 })
	misc:AddKeybind({ Text = "Speed key", Default = Enum.KeyCode.LeftShift, Mode = "Hold" })

	Library:CreateSettingsTab(Window)
	Library:Notify({ Title = "Loaded", Text = "SkeetwareUI v" .. Library.Version, Type = "success" })
end

return Library
