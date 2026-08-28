--[[
	SkeetwareUI.lua
	A single-file Roblox UI library in the "skeetware" style:
	dark background, orange accent, left tab rail, right-side groupboxes,
	compact controls (toggle / slider / dropdown / multi-dropdown / keybind / colorpicker).

	USAGE:
		local Library = loadstring(game:HttpGet("PATH_TO_THIS_FILE"))()
		-- or require it as a ModuleScript

		local Window = Library:CreateWindow({ Title = "Skeetware", SubTitle = "v1.0" })
		local Tab = Window:AddTab("Main")
		local Left = Tab:AddLeftGroupbox("Combat")
		local Right = Tab:AddRightGroupbox("Visuals")

		Left:AddToggle("MyToggle", { Text = "Enable Thing", Default = false, Callback = function(v) end })
		Left:AddSlider("MySlider", { Text = "Speed", Min = 0, Max = 100, Default = 16, Rounding = 0, Callback = function(v) end })
		Right:AddDropdown("MyDropdown", { Text = "Mode", Values = {"A","B","C"}, Default = "A", Callback = function(v) end })
		Right:AddDropdown("MyMulti", { Text = "Targets", Values = {"A","B","C"}, Multi = true, Default = {}, Callback = function(v) end })
		Right:AddKeyPicker("MyBind", { Text = "Toggle Key", Default = "RightShift", Callback = function(v) end })
		Right:AddColorPicker("MyColor", { Text = "ESP Color", Default = Color3.fromRGB(255,140,0), Callback = function(v) end })

		Library.Flags["MyToggle"] -- read current values anywhere via Flags
]]

local UserInputService = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui    = LocalPlayer:WaitForChild("PlayerGui")

--=========================================================
-- THEME
--=========================================================
local Theme = {
	Background = Color3.fromRGB(20, 20, 20),
	Secondary  = Color3.fromRGB(27, 27, 27),
	Tertiary   = Color3.fromRGB(34, 34, 34),
	Stroke     = Color3.fromRGB(48, 48, 48),
	Accent     = Color3.fromRGB(255, 140, 0),
	AccentDim  = Color3.fromRGB(120, 70, 10),
	Text       = Color3.fromRGB(235, 235, 235),
	SubText    = Color3.fromRGB(145, 145, 145),
	Font       = Enum.Font.GothamMedium,
	FontBold   = Enum.Font.GothamBold,
}

--=========================================================
-- UTIL
--=========================================================
local function create(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	return inst
end

local function corner(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 6) })
end

local function stroke(color, thickness)
	return create("UIStroke", {
		Color = color or Theme.Stroke,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function pad(l, t, r, b)
	return create("UIPadding", {
		PaddingLeft = UDim.new(0, l or 0),
		PaddingTop = UDim.new(0, t or 0),
		PaddingRight = UDim.new(0, r or 0),
		PaddingBottom = UDim.new(0, b or 0),
	})
end

local function tween(obj, props, time, style, dir)
	local t = TweenService:Create(
		obj,
		TweenInfo.new(time or 0.18, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function makeDraggable(frame, handle)
	handle = handle or frame
	local dragging, dragStart, startPos

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
			local conn
			conn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					conn:Disconnect()
				end
			end)
		end
	end)

	handle.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
end

local function hueToColor(h)
	return Color3.fromHSV(h, 1, 1)
end

--=========================================================
-- LIBRARY
--=========================================================
local Library = {}
Library.__index = Library
Library.Flags = {}
Library.Open = true
Library.ToggleKeybind = Enum.KeyCode.RightShift

function Library:CreateWindow(config)
	config = config or {}
	local Title = config.Title or "Skeetware"
	local SubTitle = config.SubTitle or "v1.0"

	-- destroy previous instance if re-run
	local existing = PlayerGui:FindFirstChild("SkeetwareUI")
	if existing then existing:Destroy() end

	local ScreenGui = create("ScreenGui", {
		Name = "SkeetwareUI",
		Parent = PlayerGui,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	local Main = create("Frame", {
		Name = "Main",
		Parent = ScreenGui,
		BackgroundColor3 = Theme.Background,
		Position = UDim2.new(0.5, -290, 0.5, -180),
		Size = UDim2.new(0, 580, 0, 360),
		ClipsDescendants = true,
	}, { corner(8), stroke(Theme.Stroke, 1) })

	-- Top bar
	local TopBar = create("Frame", {
		Name = "TopBar",
		Parent = Main,
		BackgroundColor3 = Theme.Secondary,
		Size = UDim2.new(1, 0, 0, 34),
	}, { corner(8) })
	create("Frame", { -- squares off bottom corners of topbar
		Parent = TopBar, BackgroundColor3 = Theme.Secondary,
		Position = UDim2.new(0, 0, 1, -8), Size = UDim2.new(1, 0, 0, 8), BorderSizePixel = 0,
	})

	create("Frame", { Parent = TopBar, BackgroundColor3 = Theme.Accent, Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0 })

	create("TextLabel", {
		Parent = TopBar,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 14, 0, 0),
		Size = UDim2.new(0, 300, 1, 0),
		Font = Theme.FontBold,
		Text = Title,
		TextColor3 = Theme.Text,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	create("TextLabel", {
		Parent = TopBar,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 14 + 6, 0, 0),
		Size = UDim2.new(0, 200, 1, 0),
		Font = Theme.Font,
		Text = "",
		TextColor3 = Theme.SubText,
		TextSize = 12,
		Visible = false,
	})

	local SubLabel = create("TextLabel", {
		Parent = TopBar,
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -110, 0, 0),
		Size = UDim2.new(0, 96, 1, 0),
		Font = Theme.Font,
		Text = SubTitle,
		TextColor3 = Theme.SubText,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	makeDraggable(Main, TopBar)

	-- Tab rail (left)
	local TabRail = create("Frame", {
		Name = "TabRail",
		Parent = Main,
		BackgroundColor3 = Theme.Secondary,
		Position = UDim2.new(0, 0, 0, 34),
		Size = UDim2.new(0, 130, 1, -34),
	})
	local TabRailList = create("UIListLayout", {
		Parent = TabRail, Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	pad(6, 8, 6, 6).Parent = TabRail

	-- Content area (right)
	local ContentArea = create("Frame", {
		Name = "ContentArea",
		Parent = Main,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 130, 0, 34),
		Size = UDim2.new(1, -130, 1, -34),
	})

	-- toggle visibility with keybind
	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == Library.ToggleKeybind then
			Library.Open = not Library.Open
			Main.Visible = Library.Open
		end
	end)

	local Window = setmetatable({}, { __index = self })
	Window.ScreenGui = ScreenGui
	Window.Main = Main
	Window.TabRail = TabRail
	Window.ContentArea = ContentArea
	Window.Tabs = {}
	Window._firstTab = true

	--=====================================================
	-- TAB
	--=====================================================
	function Window:AddTab(name)
		local TabButton = create("TextButton", {
			Parent = TabRail,
			BackgroundColor3 = Theme.Tertiary,
			Size = UDim2.new(1, 0, 0, 30),
			Font = Theme.Font,
			Text = name,
			TextColor3 = Theme.SubText,
			TextSize = 13,
			AutoButtonColor = false,
		}, { corner(5) })

		local Page = create("ScrollingFrame", {
			Parent = ContentArea,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Theme.Accent,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Visible = false,
		}, { pad(8, 8, 8, 8) })

		local Columns = create("Frame", {
			Parent = Page, BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		})
		create("UIListLayout", {
			Parent = Columns, FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		})

		local LeftCol = create("Frame", {
			Parent = Columns, BackgroundTransparency = 1,
			Size = UDim2.new(0.5, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		})
		create("UIListLayout", { Parent = LeftCol, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })

		local RightCol = create("Frame", {
			Parent = Columns, BackgroundTransparency = 1,
			Size = UDim2.new(0.5, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		})
		create("UIListLayout", { Parent = RightCol, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })

		local Tab = {}
		Tab.Button = TabButton
		Tab.Page = Page

		local function selectTab()
			for _, t in pairs(Window.Tabs) do
				t.Page.Visible = false
				t.Button.BackgroundColor3 = Theme.Tertiary
				t.Button.TextColor3 = Theme.SubText
			end
			Page.Visible = true
			TabButton.BackgroundColor3 = Theme.Accent
			TabButton.TextColor3 = Color3.fromRGB(20, 20, 20)
		end
		TabButton.MouseButton1Click:Connect(selectTab)

		if Window._firstTab then
			Window._firstTab = false
			task.defer(selectTab)
		end

		--=================================================
		-- GROUPBOX (shared factory for left/right)
		--=================================================
		local function buildGroupbox(parentCol, title)
			local Box = create("Frame", {
				Parent = parentCol,
				BackgroundColor3 = Theme.Secondary,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
			}, { corner(6), stroke(Theme.Stroke, 1) })

			create("TextLabel", {
				Parent = Box,
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 10, 0, 6),
				Size = UDim2.new(1, -20, 0, 18),
				Font = Theme.FontBold,
				Text = title,
				TextColor3 = Theme.Accent,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
			})

			local Holder = create("Frame", {
				Parent = Box,
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 8, 0, 28),
				Size = UDim2.new(1, -16, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
			})
			create("UIListLayout", { Parent = Holder, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
			create("UIPadding", { Parent = Box, PaddingBottom = UDim.new(0, 10) })

			local Groupbox = {}

			--------------------------------------------------
			-- LABEL
			--------------------------------------------------
			function Groupbox:AddLabel(text)
				local Lbl = create("TextLabel", {
					Parent = Holder,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 16),
					Font = Theme.Font,
					Text = text,
					TextColor3 = Theme.SubText,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
				return Lbl
			end

			--------------------------------------------------
			-- DIVIDER
			--------------------------------------------------
			function Groupbox:AddDivider()
				create("Frame", {
					Parent = Holder, BackgroundColor3 = Theme.Stroke,
					Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0,
				})
			end

			--------------------------------------------------
			-- BUTTON
			--------------------------------------------------
			function Groupbox:AddButton(config)
				config = config or {}
				local Btn = create("TextButton", {
					Parent = Holder,
					BackgroundColor3 = Theme.Tertiary,
					Size = UDim2.new(1, 0, 0, 28),
					Font = Theme.Font,
					Text = config.Text or "Button",
					TextColor3 = Theme.Text,
					TextSize = 13,
					AutoButtonColor = false,
				}, { corner(5), stroke(Theme.Stroke, 1) })

				Btn.MouseEnter:Connect(function() tween(Btn, { BackgroundColor3 = Theme.AccentDim }) end)
				Btn.MouseLeave:Connect(function() tween(Btn, { BackgroundColor3 = Theme.Tertiary }) end)
				Btn.MouseButton1Click:Connect(function()
					if config.Callback then config.Callback() end
				end)
				return Btn
			end

			--------------------------------------------------
			-- TOGGLE
			--------------------------------------------------
			function Groupbox:AddToggle(flag, config)
				config = config or {}
				local state = config.Default or false
				Library.Flags[flag] = state

				local Row = create("Frame", {
					Parent = Holder, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20),
				})
				create("TextLabel", {
					Parent = Row, BackgroundTransparency = 1,
					Size = UDim2.new(1, -40, 1, 0),
					Font = Theme.Font, Text = config.Text or flag,
					TextColor3 = Theme.Text, TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
				})

				local Switch = create("Frame", {
					Parent = Row,
					BackgroundColor3 = state and Theme.Accent or Theme.Tertiary,
					Position = UDim2.new(1, -34, 0.5, -9),
					Size = UDim2.new(0, 34, 0, 18),
				}, { corner(9), stroke(Theme.Stroke, 1) })

				local Knob = create("Frame", {
					Parent = Switch,
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
					Size = UDim2.new(0, 14, 0, 14),
				}, { corner(7) })

				local Click = create("TextButton", {
					Parent = Row, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = "",
				})

				local function set(v, fromInit)
					state = v
					Library.Flags[flag] = v
					tween(Switch, { BackgroundColor3 = v and Theme.Accent or Theme.Tertiary }, 0.15)
					tween(Knob, { Position = v and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7) }, 0.15)
					if config.Callback and not fromInit then config.Callback(v) end
				end

				Click.MouseButton1Click:Connect(function() set(not state) end)
				if config.Callback then config.Callback(state) end

				local Toggle = {}
				function Toggle:Set(v) set(v) end
				function Toggle:Get() return state end
				return Toggle
			end

			--------------------------------------------------
			-- SLIDER
			--------------------------------------------------
			function Groupbox:AddSlider(flag, config)
				config = config or {}
				local min = config.Min or 0
				local max = config.Max or 100
				local rounding = config.Rounding or 0
				local value = config.Default or min
				Library.Flags[flag] = value

				local Row = create("Frame", {
					Parent = Holder, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34),
				})
				create("TextLabel", {
					Parent = Row, BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 14),
					Font = Theme.Font, Text = config.Text or flag,
					TextColor3 = Theme.Text, TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
				})

				local Bar = create("Frame", {
					Parent = Row,
					BackgroundColor3 = Theme.Tertiary,
					Position = UDim2.new(0, 0, 0, 20),
					Size = UDim2.new(1, 0, 0, 12),
				}, { corner(6), stroke(Theme.Stroke, 1) })

				local Fill = create("Frame", {
					Parent = Bar,
					BackgroundColor3 = Theme.Accent,
					Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
				}, { corner(6) })

				local ValueLabel = create("TextLabel", {
					Parent = Bar,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 1, 0),
					Font = Theme.Font, Text = tostring(value),
					TextColor3 = Theme.Text, TextSize = 10,
				})

				local dragging = false
				local function updateFromInput(x)
					local rel = math.clamp((x - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
					local raw = min + (max - min) * rel
					local stepped = rounding > 0 and (math.floor(raw / rounding + 0.5) * rounding) or math.floor(raw + 0.5)
					stepped = math.clamp(stepped, min, max)
					if stepped ~= value then
						value = stepped
						Library.Flags[flag] = value
						Fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
						ValueLabel.Text = tostring(value)
						if config.Callback then config.Callback(value) end
					end
				end

				Bar.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						dragging = true
						updateFromInput(input.Position.X)
					end
				end)
				UserInputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						dragging = false
					end
				end)
				UserInputService.InputChanged:Connect(function(input)
					if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
						updateFromInput(input.Position.X)
					end
				end)

				if config.Callback then config.Callback(value) end

				local Slider = {}
				function Slider:Set(v)
					value = math.clamp(v, min, max)
					Library.Flags[flag] = value
					Fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
					ValueLabel.Text = tostring(value)
				end
				function Slider:Get() return value end
				return Slider
			end

			--------------------------------------------------
			-- DROPDOWN (single or Multi = true)
			--------------------------------------------------
			function Groupbox:AddDropdown(flag, config)
				config = config or {}
				local values = config.Values or {}
				local multi = config.Multi or false
				local selected

				if multi then
					selected = {}
					if config.Default then
						for _, v in ipairs(config.Default) do selected[v] = true end
					end
				else
					selected = config.Default or values[1]
				end
				Library.Flags[flag] = selected

				local Row = create("Frame", {
					Parent = Holder, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), ZIndex = 2,
				})
				create("TextLabel", {
					Parent = Row, BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 14),
					Font = Theme.Font, Text = config.Text or flag,
					TextColor3 = Theme.Text, TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
				})

				local function labelText()
					if multi then
						local names = {}
						for _, v in ipairs(values) do
							if selected[v] then table.insert(names, v) end
						end
						return #names > 0 and table.concat(names, ", ") or "None"
					else
						return tostring(selected or "None")
					end
				end

				local Box = create("TextButton", {
					Parent = Row,
					BackgroundColor3 = Theme.Tertiary,
					Position = UDim2.new(0, 0, 0, 18),
					Size = UDim2.new(1, 0, 0, 22),
					Font = Theme.Font,
					Text = "  " .. labelText(),
					TextColor3 = Theme.Text,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
					AutoButtonColor = false,
					ZIndex = 2,
				}, { corner(5), stroke(Theme.Stroke, 1) })

				local List = create("Frame", {
					Parent = Row,
					BackgroundColor3 = Theme.Tertiary,
					Position = UDim2.new(0, 0, 0, 42),
					Size = UDim2.new(1, 0, 0, 0),
					ClipsDescendants = true,
					Visible = false,
					ZIndex = 5,
				}, { corner(5), stroke(Theme.Stroke, 1) })
				local ListLayout = create("UIListLayout", { Parent = List, SortOrder = Enum.SortOrder.LayoutOrder })

				local open = false
				local function refreshLabel()
					Box.Text = "  " .. labelText()
				end

				local optionButtons = {}
				local function refreshHighlights()
					for val, btn in pairs(optionButtons) do
						local isSel = multi and selected[val] or (selected == val)
						btn.TextColor3 = isSel and Theme.Accent or Theme.Text
					end
				end

				for _, val in ipairs(values) do
					local OptBtn = create("TextButton", {
						Parent = List,
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 22),
						Font = Theme.Font,
						Text = "  " .. tostring(val),
						TextColor3 = Theme.Text,
						TextSize = 12,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 6,
					})
					optionButtons[val] = OptBtn
					OptBtn.MouseButton1Click:Connect(function()
						if multi then
							selected[val] = not selected[val]
							Library.Flags[flag] = selected
						else
							selected = val
							Library.Flags[flag] = selected
							open = false
							List.Visible = false
							List.Size = UDim2.new(1, 0, 0, 0)
						end
						refreshLabel()
						refreshHighlights()
						if config.Callback then config.Callback(selected) end
					end)
				end
				refreshHighlights()

				Box.MouseButton1Click:Connect(function()
					open = not open
					List.Visible = open
					local target = open and math.min(#values * 22, 132) or 0
					tween(List, { Size = UDim2.new(1, 0, 0, target) }, 0.15)
				end)

				if config.Callback then config.Callback(selected) end

				local Dropdown = {}
				function Dropdown:Get() return selected end
				function Dropdown:Set(v)
					if multi then
						selected = {}
						for _, val in ipairs(v) do selected[val] = true end
					else
						selected = v
					end
					Library.Flags[flag] = selected
					refreshLabel()
					refreshHighlights()
				end
				return Dropdown
			end

			--------------------------------------------------
			-- KEYBIND PICKER
			--------------------------------------------------
			function Groupbox:AddKeyPicker(flag, config)
				config = config or {}
				local currentKey = config.Default and Enum.KeyCode[config.Default] or nil
				Library.Flags[flag] = currentKey and currentKey.Name or "None"

				local Row = create("Frame", {
					Parent = Holder, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20),
				})
				create("TextLabel", {
					Parent = Row, BackgroundTransparency = 1,
					Size = UDim2.new(1, -80, 1, 0),
					Font = Theme.Font, Text = config.Text or flag,
					TextColor3 = Theme.Text, TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
				})

				local KeyBtn = create("TextButton", {
					Parent = Row,
					BackgroundColor3 = Theme.Tertiary,
					Position = UDim2.new(1, -74, 0.5, -11),
					Size = UDim2.new(0, 74, 0, 22),
					Font = Theme.Font,
					Text = currentKey and currentKey.Name or "None",
					TextColor3 = Theme.Text,
					TextSize = 12,
					AutoButtonColor = false,
				}, { corner(5), stroke(Theme.Stroke, 1) })

				local listening = false
				KeyBtn.MouseButton1Click:Connect(function()
					listening = true
					KeyBtn.Text = "..."
					KeyBtn.TextColor3 = Theme.Accent
				end)

				UserInputService.InputBegan:Connect(function(input, gpe)
					if listening and input.UserInputType == Enum.UserInputType.Keyboard then
						currentKey = input.KeyCode
						KeyBtn.Text = currentKey.Name
						KeyBtn.TextColor3 = Theme.Text
						listening = false
						Library.Flags[flag] = currentKey.Name
						if config.Callback then config.Callback(currentKey) end
					elseif not listening and not gpe and config.Mode ~= "Hold" and input.KeyCode == currentKey then
						if config.Toggled then config.Toggled() end
					end
				end)

				local KeyPicker = {}
				function KeyPicker:Get() return currentKey end
				return KeyPicker
			end

			--------------------------------------------------
			-- COLOR PICKER
			--------------------------------------------------
			function Groupbox:AddColorPicker(flag, config)
				config = config or {}
				local color = config.Default or Color3.fromRGB(255, 140, 0)
				Library.Flags[flag] = color
				local hue, sat, val = 0, 1, 1
				local h0, s0, v0 = Color3.toHSV(color)
				hue, sat, val = h0, s0, v0

				local Row = create("Frame", {
					Parent = Holder, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), ZIndex = 2,
				})
				create("TextLabel", {
					Parent = Row, BackgroundTransparency = 1,
					Size = UDim2.new(1, -34, 1, 0),
					Font = Theme.Font, Text = config.Text or flag,
					TextColor3 = Theme.Text, TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
				})

				local Swatch = create("TextButton", {
					Parent = Row,
					BackgroundColor3 = color,
					Position = UDim2.new(1, -28, 0.5, -10),
					Size = UDim2.new(0, 28, 0, 20),
					Text = "",
					AutoButtonColor = false,
					ZIndex = 2,
				}, { corner(5), stroke(Theme.Stroke, 1) })

				local Popup = create("Frame", {
					Parent = Row,
					BackgroundColor3 = Theme.Tertiary,
					Position = UDim2.new(1, -160, 1, 6),
					Size = UDim2.new(0, 160, 0, 150),
					Visible = false,
					ZIndex = 10,
				}, { corner(6), stroke(Theme.Stroke, 1), pad(8, 8, 8, 8) })

				local SVBox = create("Frame", {
					Parent = Popup,
					BackgroundColor3 = hueToColor(hue),
					Size = UDim2.new(1, 0, 0, 90),
					ZIndex = 11,
				}, { corner(4) })
				create("UIGradient", {
					Parent = SVBox, Color = ColorSequence.new(Color3.new(1,1,1), hueToColor(hue)),
				})
				local SVBlack = create("Frame", {
					Parent = SVBox, BackgroundTransparency = 0, BackgroundColor3 = Color3.new(0,0,0),
					Size = UDim2.new(1,0,1,0), ZIndex = 11,
				}, { corner(4) })
				create("UIGradient", {
					Parent = SVBlack, Rotation = 90,
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(1, 0),
					}),
				})
				local SVCursor = create("Frame", {
					Parent = SVBox,
					BackgroundColor3 = Color3.new(1,1,1),
					Size = UDim2.new(0, 6, 0, 6),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(sat, 0, 1 - val, 0),
					ZIndex = 12,
				}, { corner(3), stroke(Color3.new(0,0,0), 1) })

				local HueBar = create("Frame", {
					Parent = Popup,
					Position = UDim2.new(0, 0, 0, 98),
					Size = UDim2.new(1, 0, 0, 14),
					ZIndex = 11,
				}, { corner(4) })
				do
					local seq = {}
					for i = 0, 10 do
						table.insert(seq, ColorSequenceKeypoint.new(i / 10, hueToColor(i / 10)))
					end
					create("UIGradient", { Parent = HueBar, Color = ColorSequence.new(seq) })
				end
				local HueCursor = create("Frame", {
					Parent = HueBar,
					BackgroundColor3 = Color3.new(1,1,1),
					Size = UDim2.new(0, 3, 1, 4),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(hue, 0, 0.5, 0),
					ZIndex = 12,
				})

				local function updateColor(fromCallback)
					color = Color3.fromHSV(hue, sat, val)
					Swatch.BackgroundColor3 = color
					SVBox.BackgroundColor3 = hueToColor(hue)
					Library.Flags[flag] = color
					if config.Callback and fromCallback ~= false then config.Callback(color) end
				end

				local draggingSV, draggingHue = false, false
				SVBox.InputBegan:Connect(function(i)
					if i.UserInputType == Enum.UserInputType.MouseButton1 then draggingSV = true end
				end)
				HueBar.InputBegan:Connect(function(i)
					if i.UserInputType == Enum.UserInputType.MouseButton1 then draggingHue = true end
				end)
				UserInputService.InputEnded:Connect(function(i)
					if i.UserInputType == Enum.UserInputType.MouseButton1 then draggingSV, draggingHue = false, false end
				end)
				UserInputService.InputChanged:Connect(function(i)
					if i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
					if draggingSV then
						local rx = math.clamp((i.Position.X - SVBox.AbsolutePosition.X) / SVBox.AbsoluteSize.X, 0, 1)
						local ry = math.clamp((i.Position.Y - SVBox.AbsolutePosition.Y) / SVBox.AbsoluteSize.Y, 0, 1)
						sat, val = rx, 1 - ry
						SVCursor.Position = UDim2.new(sat, 0, 1 - val, 0)
						updateColor()
					elseif draggingHue then
						local rx = math.clamp((i.Position.X - HueBar.AbsolutePosition.X) / HueBar.AbsoluteSize.X, 0, 1)
						hue = rx
						HueCursor.Position = UDim2.new(hue, 0, 0.5, 0)
						updateColor()
					end
				end)

				Swatch.MouseButton1Click:Connect(function()
					Popup.Visible = not Popup.Visible
				end)

				local ColorPicker = {}
				function ColorPicker:Get() return color end
				function ColorPicker:Set(c)
					hue, sat, val = Color3.toHSV(c)
					SVCursor.Position = UDim2.new(sat, 0, 1 - val, 0)
					HueCursor.Position = UDim2.new(hue, 0, 0.5, 0)
					updateColor()
				end
				return ColorPicker
			end

			return Groupbox
		end

		function Tab:AddLeftGroupbox(title)
			return buildGroupbox(LeftCol, title)
		end

		function Tab:AddRightGroupbox(title)
			return buildGroupbox(RightCol, title)
		end

		table.insert(Window.Tabs, Tab)
		return Tab
	end

	return Window
end

return Library
