local input_service = game:GetService("UserInputService");
local text_service = game:GetService("TextService");
local run_service = game:GetService("RunService");
local players = game:GetService("Players");
local teams = game:GetService("Teams");
local gui_service = game:GetService("GuiService");
local local_player = players.LocalPlayer;
local mouse = local_player:GetMouse();

local mouse_button_one = Enum.UserInputType.MouseButton1;
local mouse_button_two = Enum.UserInputType.MouseButton2;
local mouse_movement = Enum.UserInputType.MouseMovement;
local touch = Enum.UserInputType.Touch;
local keyboard = Enum.UserInputType.Keyboard;
local white = Color3.new(1, 1, 1);
local black = Color3.new(0, 0, 0);
local tap_slop = 10;
local hold_time = 0.45;
local fit_margin = 8;
local text_resolution = Vector2.new(1920, 1080);
local tooltip_offset = Vector2.new(15, 12);
local tooltip_padding = Vector2.new(8, 6);
local tooltip_delay = 0.3;
local bottom_padding = 7;
local scroll_image = "rbxasset://textures/ui/Scroll/scroll-middle.png";
local touch_only = input_service.TouchEnabled and (not input_service.KeyboardEnabled);
local topbar_found = pcall(function()
    return gui_service.TopbarInset;
end);
local accent_border = { BorderColor3 = "AccentColor"; };
local black_border = { BorderColor3 = "Black"; };
local mouse_keys = { MB1 = mouse_button_one; MB2 = mouse_button_two; };
local button_gradient = ColorSequence.new({
    ColorSequenceKeypoint.new(0, white);
    ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212));
});
local fade_rules = {
    Frame = { "BackgroundTransparency" };
    ScrollingFrame = { "BackgroundTransparency"; "ScrollBarImageTransparency" };
    TextLabel = { "TextTransparency"; "BackgroundTransparency" };
    TextBox = { "TextTransparency" };
    ImageLabel = { "ImageTransparency"; "BackgroundTransparency" };
    UIStroke = { "Transparency" };
};
local hue_points = {};

for index = 0, 10 do
    table.insert(hue_points, ColorSequenceKeypoint.new(index / 10, Color3.fromHSV(index / 10, 1, 1)));
end;

local hue_sequence = ColorSequence.new(hue_points);

local toggles = {};
local options = {};
local key_pickers = {};
local player_dropdowns = {};
local team_dropdowns = {};
local unload_callbacks = {};
local blank_frames = {};
local list_containers = {};
local trailing_blanks = {};
local trailing_boxes = {};
local addon_rows = {};
local notices = {};
local notice_stack = {};
local hovering = {};
local themed = {
    BackgroundColor3 = {};
    BorderColor3 = {};
    TextColor3 = {};
    ScrollBarImageColor3 = {};
    Color = {};
};
local watermark_text = nil;
local watermark_position = UDim2.new(0, 100, 0, -25);
local addon_functions = {};
local groupbox_functions = {};
local base_addons = { __index = addon_functions; };
local base_groupbox = { __index = groupbox_functions; };
local view = { scale = 1; holder = nil; base = nil; fitted = nil; lowered = nil; button = nil; };
local gesture = { active = nil; connections = {}; };
local popup = { current = nil; };
local tooltip = { frame = nil; label = nil; host = nil; follow = nil; reveal = nil; };
local binding = { session = nil; };
local fade = {
    running = false;
    open = false;
    dirty = true;
    watching = false;
    driver = nil;
    outer = nil;
    modal = nil;
    window_properties = nil;
    time = 0;
    elapsed = 0;
    targets = {};
    properties = {};
    bases = {};
};

local screen_gui = Instance.new("ScreenGui");
local root = Instance.new("Frame");
local root_scale = Instance.new("UIScale");

screen_gui.ZIndexBehavior = Enum.ZIndexBehavior.Global;
screen_gui.ResetOnSpawn = false;
screen_gui.Parent = gethui();

root.BackgroundTransparency = 1;
root.BorderSizePixel = 0;
root.Size = UDim2.fromScale(1, 1);
root_scale.Parent = root;
root.Parent = screen_gui;

local Library = {
    FontColor = Color3.fromRGB(255, 255, 255);
    LabelColor = Color3.fromRGB(200, 200, 200);
    MainColor = Color3.fromRGB(28, 28, 28);
    BackgroundColor = Color3.fromRGB(20, 20, 20);
    AccentColor = Color3.fromRGB(255, 255, 255);
    OutlineColor = Color3.fromRGB(50, 50, 50);
    RiskColor = Color3.fromRGB(255, 50, 50);
    Black = Color3.new(0, 0, 0);
    Theme = "Classic";
    Font = Enum.Font.Code;
    OpenedFrames = {};
    DependencyBoxes = {};
    Signals = {};
    InputBeganHandlers = {};
    InputEndedHandlers = {};
    ScreenGui = screen_gui;
};

getgenv().Toggles = toggles;
getgenv().Options = options;

local theme_value = function(key)
    if (key == "FontColorDark") then
        return Library:GetDarkerColor(Library.FontColor);
    end;

    if (key == "MainGradient") then
        return ColorSequence.new({
            ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor));
            ColorSequenceKeypoint.new(1, Library.MainColor);
        });
    end;

    return Library[key];
end;

local set_color = function(instance, property, color)
    if (type(color) == "string") then
        themed[property][instance] = color;
        instance[property] = theme_value(color);
        return;
    end;

    themed[property][instance] = nil;
    instance[property] = color;
end;

local destroy_themed = function(frame)
    for _, part in frame:GetDescendants() do
        for _, entries in themed do
            entries[part] = nil;
        end;
    end;

    frame:Destroy();
end;

local create = function(class, properties)
    local instance = class;
    local parent = properties.Parent;

    if (type(class) == "string") then
        instance = Instance.new(class);
    end;

    for property, value in properties do
        if (property == "Parent") then
            continue;
        end;

        if (themed[property]) then
            set_color(instance, property, value);
            continue;
        end;

        instance[property] = value;
    end;

    if (parent) then
        instance.Parent = parent;
    end;

    return instance;
end;

local apply_text_stroke = function(text_object)
    local stroke = Instance.new("UIStroke");

    text_object.TextStrokeTransparency = 1;

    stroke.Color = black;
    stroke.Thickness = 1;
    stroke.LineJoinMode = Enum.LineJoinMode.Miter;
    stroke.Parent = text_object;
end;

local create_label = function(properties)
    local label = Instance.new("TextLabel");

    label.BackgroundTransparency = 1;
    label.Font = Library.Font;
    label.TextSize = 16;

    set_color(label, "TextColor3", "FontColor");

    apply_text_stroke(label);

    return create(label, properties);
end;

local flat = function(position)
    return Vector2.new(position.X, position.Y);
end;

local inside = function(object, position)
    local offset = position - object.AbsolutePosition;
    local size = object.AbsoluteSize;

    return (offset.X >= 0) and (offset.Y >= 0) and (offset.X <= size.X) and (offset.Y <= size.Y);
end;

local is_blocked = function(object, position)
    local holder = view.holder;
    local in_window = (holder ~= nil) and ((object == holder) or (object:IsDescendantOf(holder)));
    local keybind = Library.KeybindFrame;
    local watermark = Library.Watermark;

    if (view.button) and (inside(view.button, position)) then
        return true;
    end;

    if (in_window) and (keybind.Visible) and (inside(keybind, position)) then
        return true;
    end;

    if (in_window) and (watermark.Visible) and (inside(watermark, position)) then
        return true;
    end;

    for frame in Library.OpenedFrames do
        if (inside(frame, position)) and (not object:IsDescendantOf(frame)) then
            return true;
        end;
    end;

    return false;
end;

local unscale = function(length)
    if (view.scale == 1) then
        return length;
    end;

    return math.round(length / view.scale);
end;

local to_root = function(position)
    return (position - root.AbsolutePosition) / view.scale;
end;

local screen_bounds = function(size, margin)
    local edge = Vector2.new(margin, margin);
    local low = screen_gui.AbsolutePosition + edge;
    local high = screen_gui.AbsolutePosition + screen_gui.AbsoluteSize - size - edge;

    return {
        low = low;
        high = high:Max(low);
    };
end;

local place_tooltip = function(corner)
    local size = tooltip.host.size + tooltip_padding;
    local screen = screen_gui.AbsoluteSize / view.scale;
    local high = (screen - size - Vector2.one):Max(Vector2.one);
    local clamped = corner:Max(Vector2.one):Min(high);

    tooltip.frame.Position = UDim2.fromOffset(clamped.X, clamped.Y);
end;

local tooltip_corner = function(pointer)
    local size = tooltip.host.size + tooltip_padding;
    local screen = screen_gui.AbsoluteSize / view.scale;
    local corner = pointer + tooltip_offset;

    if (corner.X + size.X > screen.X) then
        corner = Vector2.new(pointer.X - tooltip_offset.X - size.X, corner.Y);
    end;

    return corner;
end;

local show_tooltip = function(entry)
    local wrap_width = math.floor(screen_gui.AbsoluteSize.X / view.scale - fit_margin * 2 - tooltip_padding.X);
    local width, height = Library:GetTextBounds(entry.text, Library.Font, 14, Vector2.new(wrap_width, math.huge));

    entry.size = Vector2.new(width, height);

    if (not tooltip.frame) then
        tooltip.frame = create("Frame", {
            BackgroundColor3 = Library.Black;
            BorderColor3 = Library.Black;
            Visible = false;
            ZIndex = 300;
            Parent = root;
        });

        create("Frame", {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.fromScale(1, 1);
            ZIndex = 301;
            Parent = tooltip.frame;
        });

        tooltip.label = create_label({
            Position = UDim2.fromOffset(4, 3);
            TextSize = 14;
            TextWrapped = true;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 302;
            Parent = tooltip.frame;
        });
    end;

    tooltip.host = entry;
    tooltip.frame.Size = UDim2.fromOffset(width + tooltip_padding.X, height + tooltip_padding.Y);
    tooltip.label.Size = UDim2.fromOffset(wrap_width, height);
    tooltip.label.Text = entry.text;
end;

local reveal_tooltip = function(frame)
    tooltip.reveal = nil;
    frame.Visible = true;
end;

local hide_tooltip = function(entry)
    if (entry == nil) or (tooltip.host ~= entry) then
        return;
    end;

    tooltip.host = nil;
    tooltip.frame.Visible = false;

    if (tooltip.reveal) then
        task.cancel(tooltip.reveal);
        tooltip.reveal = nil;
    end;

    if (tooltip.follow) then
        tooltip.follow:Disconnect();
        tooltip.follow = nil;
    end;
end;

local follow_tooltip = function(input)
    if (input.UserInputType ~= mouse_movement) then
        return;
    end;

    place_tooltip(tooltip_corner(to_root(flat(input.Position))));
end;

local end_gesture = function(position, tapped)
    local current = gesture.active;

    if (not current) then
        return;
    end;

    for _, connection in gesture.connections do
        connection:Disconnect();
    end;

    table.clear(gesture.connections);
    gesture.active = nil;

    if (current.column) then
        current.column.ScrollingEnabled = true;
    end;

    if (current.tip_shown) then
        hide_tooltip(current.tip);
    end;

    if (tapped) and (current.tap) then
        current.tap(position, current);
    end;

    if (current.finish) then
        current.finish(position, current);
    end;
end;

local check_hold = function(record)
    if (gesture.active ~= record) or (record.moved) then
        return;
    end;

    if (record.hold) then
        record.held = true;
        record.hold(record.last, record);
        return;
    end;

    if (not record.tip) then
        return;
    end;

    record.held = true;
    record.tip_shown = true;

    hide_tooltip(tooltip.host);
    show_tooltip(record.tip);
    place_tooltip(to_root(record.last) - Vector2.new(record.tip.size.X / 2, record.tip.size.Y + 24));

    tooltip.frame.Visible = true;
end;

local gesture_changed = function(input)
    local current = gesture.active;
    local mouse_gesture = (current.input.UserInputType == mouse_button_one);
    local position = nil;

    if (mouse_gesture) and (input.UserInputType ~= mouse_movement) then
        return;
    end;

    if (not mouse_gesture) and (input ~= current.input) then
        return;
    end;

    position = flat(input.Position);

    if (mouse_gesture) and (not input_service:IsMouseButtonPressed(mouse_button_one)) then
        end_gesture(position, false);
        return;
    end;

    current.last = position;

    if ((position - current.origin).Magnitude > tap_slop) then
        current.moved = true;
    end;

    if (current.move) then
        current.move(position, current);
    end;
end;

local gesture_ended = function(input)
    local current = gesture.active;
    local mouse_release = (current.input.UserInputType == mouse_button_one) and (input.UserInputType == mouse_button_one);

    if (input ~= current.input) and (not mouse_release) then
        return;
    end;

    end_gesture(flat(input.Position), (not current.moved) and (not current.held));
end;

local gesture_focus = function()
    end_gesture(gesture.active.last, false);
end;

local begin_gesture = function(record)
    local current = gesture.active;
    local position = flat(record.input.Position);

    if (current) then
        if (current.input == record.input) then
            for key, value in record do
                current[key] = value;
            end;

            return current;
        end;

        if (current.input.UserInputType == touch) then
            return nil;
        end;

        end_gesture(current.last, false);
    end;

    record.origin = position;
    record.last = position;
    record.moved = false;
    record.held = false;
    gesture.active = record;

    table.insert(gesture.connections, input_service.InputChanged:Connect(gesture_changed));
    table.insert(gesture.connections, input_service.InputEnded:Connect(gesture_ended));
    table.insert(gesture.connections, input_service.WindowFocusReleased:Connect(gesture_focus));

    if (record.input.UserInputType == touch) then
        task.delay(hold_time, check_hold, record);
    end;

    return record;
end;

local lock_column = function(record, object)
    local column = object:FindFirstAncestorOfClass("ScrollingFrame");

    if (not column) then
        return;
    end;

    column.ScrollingEnabled = false;
    record.column = column;
end;

local on_press = function(object, actions)
    object.InputBegan:Connect(function(input)
        local input_type = input.UserInputType;
        local pointer = (input_type == mouse_button_one) or (input_type == mouse_button_two) or (input_type == touch);
        local position = nil;

        if (not pointer) then
            return;
        end;

        position = flat(input.Position);

        if (is_blocked(object, position)) then
            return;
        end;

        if (input_type == mouse_button_one) then
            actions.click(position);
            return;
        end;

        if (input_type == mouse_button_two) then
            if (actions.alternate) then
                actions.alternate(position);
            end;

            return;
        end;

        begin_gesture({
            input = input;
            tap = actions.click;
            hold = actions.alternate;
        });
    end);
end;

local hit_region = function(object, position, size)
    if (not touch_only) then
        return object;
    end;

    return create("Frame", {
        Active = true;
        BackgroundTransparency = 1;
        Position = position;
        Size = size;
        ZIndex = object.ZIndex;
        Parent = object;
    });
end;

local track_hover = function(object, parts, paint)
    local update = function()
        local hovered = not is_blocked(object, Vector2.new(mouse.X, mouse.Y));

        if (hovered == parts.hovered) then
            return;
        end;

        parts.hovered = hovered;
        hovering[parts] = nil;

        if (hovered) then
            hovering[parts] = paint;
        end;

        paint(parts);
    end;

    object.MouseEnter:Connect(update);
    object.MouseMoved:Connect(update);

    object.MouseLeave:Connect(function()
        parts.hovered = false;
        hovering[parts] = nil;
        paint(parts);
    end);
end;

local paint_highlight = function(parts)
    local colors = parts.defaults;

    if (parts.hovered) then
        colors = parts.properties;
    end;

    for property, color in colors do
        if (themed[property]) then
            set_color(parts.target, property, color);
            continue;
        end;

        parts.target[property] = Library[color] or color;
    end;
end;

local paint_border = function(parts)
    local color = "Black";

    if (parts.hovered) or (parts.active) or (parts.open) then
        color = "AccentColor";
    end;

    set_color(parts.outer, "BorderColor3", color);
end;

local watch_hover = function(parts)
    if (touch_only) then
        return;
    end;

    track_hover(parts.outer, parts, paint_border);
end;

local paint_tab = function(parts)
    local color = "FontColorDark";

    if (parts.hovered) or (parts.active) then
        color = "FontColor";
    end;

    set_color(parts.label, "TextColor3", color);
end;

local watch_tab_hover = function(parts)
    if (touch_only) then
        return;
    end;

    track_hover(parts.button, parts, paint_tab);
end;

local padded_height = function(container, layout)
    local children = container:GetChildren();
    local index = #children;
    local content = unscale(layout.AbsoluteContentSize.Y);

    while (index > 0) do
        local child = children[index];
        local takes_space = child:IsA("GuiObject") and child.Visible and (child.Size.Y.Offset > 0);
        local nested = nil;

        index -= 1;

        if (not takes_space) then
            continue;
        end;

        if (blank_frames[child]) then
            return content - child.Size.Y.Offset + bottom_padding;
        end;

        nested = child:FindFirstChildOfClass("Frame");

        if (not list_containers[nested]) then
            break;
        end;

        children = nested:GetChildren();
        index = #children;
    end;

    return content + bottom_padding;
end;

local add_addon = function(owner, addon)
    local row = addon_rows[owner];
    local layout = nil;

    if (not row.holder) then
        row.holder = create("Frame", {
            BackgroundTransparency = 1;
            Position = UDim2.new(1, 4, 0, 0);
            Size = UDim2.new(0, 0, 0, row.height);
        });

        layout = create("UIListLayout", {
            Padding = UDim.new(0, 4);
            FillDirection = Enum.FillDirection.Horizontal;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = row.holder;
        });

        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            local width = unscale(layout.AbsoluteContentSize.X);
            local height = row.text.Size.Y;

            row.text.Size = UDim2.new(1, row.offset - width - 4, height.Scale, height.Offset);

            if (row.region) then
                row.region.Size = UDim2.new(1, row.edge - width, 0, row.region.Size.Y.Offset);
            end;
        end);

        row.holder.Parent = row.text;
    end;

    addon.Parent = row.holder;
end;

local drag_move = function(position, record)
    local wanted = record.corner + (position - record.origin);
    local clamped = wanted:Max(record.low):Min(record.high);
    local in_bar = (record.bar_left ~= nil) and (clamped.Y < record.bar_bottom);
    local shift = nil;
    local step_x = 0;
    local step_y = 0;

    if (in_bar) and (record.bar_left > record.high.X) then
        clamped = Vector2.new(clamped.X, record.bar_bottom);
    elseif (in_bar) then
        clamped = Vector2.new(math.max(clamped.X, record.bar_left), clamped.Y);
    end;

    shift = (clamped - record.corner) / record.scale;
    step_x = math.sign(shift.X) * math.floor(math.abs(shift.X));
    step_y = math.sign(shift.Y) * math.floor(math.abs(shift.Y));
    record.frame.Position = record.start + UDim2.fromOffset(step_x, step_y);
end;

local drag_record = function(frame, input, scale)
    local corner = frame.AbsolutePosition;
    local bounds = screen_bounds(frame.AbsoluteSize, frame.BorderSizePixel);
    local inset = gui_service:GetGuiInset();
    local record = {
        input = input;
        frame = frame;
        scale = scale;
        corner = corner;
        start = frame.Position;
        low = bounds.low:Min(corner);
        high = bounds.high:Max(corner);
        move = drag_move;
    };

    if (frame ~= Library.Watermark) then
        return record;
    end;

    record.low = Vector2.new(record.low.X, bounds.low.Y - inset.Y);

    if (topbar_found) and (gui_service.TopbarInset.Height > 0) then
        record.bar_left = gui_service.TopbarInset.Min.X + 8 - inset.X;
        record.bar_bottom = bounds.low.Y;
    end;

    return record;
end;

local place_popup = function(record)
    local frame = record.frame;
    local origin = to_root(record.anchor.AbsolutePosition);
    local extent = record.anchor.AbsoluteSize / view.scale;
    local size = Vector2.new(frame.Size.X.Offset, frame.Size.Y.Offset);
    local screen = screen_gui.AbsoluteSize / view.scale;
    local high = (screen - size - Vector2.one):Max(Vector2.one);
    local below = origin.Y + extent.Y + record.gap;
    local above = origin.Y - size.Y - record.gap;
    local cramped = (below + size.Y > screen.Y) and (above < 0);
    local corner = Vector2.new(origin.X, below);

    if (record.align_right) then
        local column_left = to_root(record.column.AbsolutePosition).X;
        local column_width = record.column.AbsoluteSize.X / view.scale;

        corner = Vector2.new(origin.X + extent.X - size.X, below);

        if (column_width >= size.X) then
            corner = Vector2.new(math.max(corner.X, column_left), below);
        end;
    end;

    if (below + size.Y > screen.Y) then
        corner = Vector2.new(corner.X, above);
    end;

    if (cramped) then
        corner = Vector2.new(origin.X + extent.X + record.gap, origin.Y);
    end;

    if (cramped) and (corner.X + size.X > screen.X) then
        corner = Vector2.new(origin.X - size.X - record.gap, corner.Y);
    end;

    corner = corner:Max(Vector2.one):Min(high);
    frame.Position = UDim2.fromOffset(math.ceil(corner.X - 0.5), math.ceil(corner.Y - 0.5));
end;

local anchor_overflow = function(record)
    local anchor = record.anchor;
    local column = record.column;
    local top = column.AbsolutePosition.Y;
    local bottom = top + column.AbsoluteSize.Y;
    local anchor_top = anchor.AbsolutePosition.Y;
    local anchor_bottom = anchor_top + anchor.AbsoluteSize.Y;

    if (anchor_bottom > bottom) then
        return anchor_bottom - bottom;
    end;

    if (anchor_top < top) then
        return anchor_top - top;
    end;

    return 0;
end;

local close_popup = function(record)
    if (record == nil) or (popup.current ~= record) then
        return;
    end;

    popup.current = nil;
    record.follow:Disconnect();
    record.frame.Visible = false;
    Library.OpenedFrames[record.frame] = nil;

    if (record.close) then
        record:close();
    end;
end;

local follow_popup = function()
    local record = popup.current;

    if (anchor_overflow(record) ~= 0) then
        close_popup(record);
        return;
    end;

    place_popup(record);
end;

local open_popup = function(record)
    local overflow = 0;
    local shift = 0;

    if (not fade.open) or (Library.Unloaded) then
        return;
    end;

    close_popup(popup.current);
    hide_tooltip(tooltip.host);

    if (not record.owner) then
        record.owner = record.anchor;
    end;

    record.column = record.anchor:FindFirstAncestorOfClass("ScrollingFrame");
    overflow = anchor_overflow(record) / view.scale;
    shift = math.sign(overflow) * math.ceil(math.abs(overflow));
    record.column.CanvasPosition += Vector2.new(0, shift);
    popup.current = record;

    place_popup(record);

    record.frame.Visible = true;
    Library.OpenedFrames[record.frame] = true;
    record.follow = record.anchor:GetPropertyChangedSignal("AbsolutePosition"):Connect(follow_popup);
end;

local player_names = function(leaving)
    local names = {};

    for _, player in players:GetPlayers() do
        if (player ~= leaving) then
            table.insert(names, player.Name);
        end;
    end;

    table.sort(names);

    return names;
end;

local team_names = function(service)
    local names = {};

    for _, team in service:GetTeams() do
        table.insert(names, team.Name);
    end;

    table.sort(names);

    return names;
end;

local refresh_dropdowns = function(dropdowns, names)
    for _, dropdown in dropdowns do
        task.spawn(dropdown.SetValues, dropdown, names);
    end;
end;

local refresh_team_lists = function()
    refresh_dropdowns(team_dropdowns, team_names(teams));
end;

local mark_fade = function()
    fade.dirty = true;
end;

local step_fade = function(step)
    local targets = fade.targets;
    local properties = fade.properties;
    local bases = fade.bases;

    fade.elapsed += step;

    local progress = math.min(fade.elapsed / fade.time, 1);

    if (fade.open) then
        progress = 1 - progress;
    end;

    for index, target in targets do
        local base = bases[index];

        if (base ~= 1) then
            target[properties[index]] = base + (1 - base) * progress;
        end;
    end;
end;

local toggle_menu = function()
    local targets = fade.targets;
    local properties = fade.properties;
    local bases = fade.bases;
    local outer = fade.outer;

    if (fade.running) or (Library.Unloaded) then
        return;
    end;

    fade.running = true;
    fade.open = not fade.open;
    fade.time = fade.window_properties.MenuFadeTime;
    fade.modal.Modal = fade.open;

    if (not fade.open) then
        close_popup(popup.current);
        hide_tooltip(tooltip.host);
    end;

    if (fade.dirty) then
        table.clear(targets);
        table.clear(properties);

        for _, descendant in outer:GetDescendants() do
            local rule = fade_rules[descendant.ClassName];

            if (not rule) then
                continue;
            end;

            for _, property in rule do
                table.insert(targets, descendant);
                table.insert(properties, property);
            end;
        end;

        fade.dirty = false;
    end;

    if (not fade.watching) then
        outer.DescendantAdded:Connect(mark_fade);
        outer.DescendantRemoving:Connect(mark_fade);
        fade.watching = true;
    end;

    for index, target in targets do
        bases[index] = target[properties[index]];
    end;

    if (fade.open) then
        for index, target in targets do
            if (bases[index] ~= 1) then
                target[properties[index]] = 1;
            end;
        end;

        outer.Visible = true;
    end;

    if (fade.time > 0) then
        fade.elapsed = 0;
        fade.driver = run_service.Heartbeat:Connect(step_fade);

        task.wait(fade.time);

        if (Library.Unloaded) then
            return;
        end;

        fade.driver:Disconnect();
        fade.driver = nil;
    end;

    for index, target in targets do
        if (bases[index] ~= 1) then
            target[properties[index]] = bases[index];
        end;
    end;

    fade.running = false;

    if (not fade.open) then
        outer.Visible = false;

        for parts, paint in hovering do
            parts.hovered = false;
            paint(parts);
        end;

        table.clear(hovering);
    end;
end;

local keep_on_screen = function(frame, margin, reach)
    local corner = frame.AbsolutePosition;
    local limits = screen_bounds(frame.AbsoluteSize, 0);
    local bounds = screen_bounds(frame.AbsoluteSize, margin);
    local fitted = corner:Max(limits.low - reach):Min(limits.high);
    local scale = 1;
    local shift = nil;

    if (fitted == corner) then
        return;
    end;

    if (frame:IsDescendantOf(root)) then
        scale = view.scale;
    end;

    shift = (corner:Max(bounds.low - reach):Min(bounds.high) - corner) / scale;
    frame.Position = frame.Position + UDim2.fromOffset(math.round(shift.X), math.round(shift.Y));
end;

local fit_window = function(holder)
    local available = screen_gui.AbsoluteSize;
    local base = nil;
    local button = view.button;
    local scale = 1;
    local height = 0;
    local border = nil;
    local button_low = nil;
    local button_high = nil;
    local window_low = nil;
    local window_high = nil;
    local across = false;
    local covered = false;
    local lowered = false;
    local top = 0;
    local size = nil;
    local resized = false;
    local offset_only = false;

    if (button) then
        keep_on_screen(button, button.BorderSizePixel, Vector2.zero);
    end;

    if (holder) and (view.fitted) then
        size = holder.Size;
        resized = (size ~= view.fitted);
        offset_only = (size.X.Scale == 0) and (size.Y.Scale == 0) and (size.X.Offset > 0);
    end;

    if (resized) then
        view.base = nil;
    end;

    if (resized) and (offset_only) then
        view.base = Vector2.new(size.X.Offset, size.Y.Offset);
    end;

    base = view.base;

    if (not holder) or (not base) or (available.X <= 0) then
        return;
    end;

    scale = math.min(1, (available.X - fit_margin * 2) / base.X);
    height = math.min(base.Y, math.floor((available.Y - fit_margin * 2) / scale));

    view.scale = scale;
    root_scale.Scale = scale;
    root.Size = UDim2.fromScale(1 / scale, 1 / scale);
    holder.Size = UDim2.fromOffset(base.X, height);
    view.fitted = holder.Size;

    keep_on_screen(holder, fit_margin, Vector2.zero);

    if (not button) then
        return;
    end;

    border = Vector2.one * button.BorderSizePixel;
    button_low = button.AbsolutePosition - border;
    button_high = button.AbsolutePosition + button.AbsoluteSize + border;
    window_low = holder.AbsolutePosition;
    window_high = window_low + holder.AbsoluteSize;
    top = button_high.Y + fit_margin;
    across = (button_low.X < window_high.X) and (button_high.X > window_low.X);
    covered = (button_low.Y <= window_low.Y) and (window_low.Y < top - 0.5);
    lowered = (holder.Position == view.lowered);

    if (not across) or ((not covered) and (not lowered)) then
        return;
    end;

    height = math.min(base.Y, math.floor((screen_gui.AbsolutePosition.Y + available.Y - top - fit_margin) / scale));
    holder.Size = UDim2.fromOffset(base.X, height);
    view.fitted = holder.Size;
    holder.Position += UDim2.fromOffset(0, math.round((top - holder.AbsolutePosition.Y) / scale));
    view.lowered = holder.Position;
end;

local place_watermark = function(frame)
    if (frame.Position ~= watermark_position) then
        keep_on_screen(frame, frame.BorderSizePixel, Vector2.new(0, gui_service:GetGuiInset().Y));
        return;
    end;

    watermark_position = UDim2.new(0, 100, 0, -25);

    if (topbar_found) and (gui_service.TopbarInset.Height > 0) then
        local topbar = gui_service.TopbarInset;
        local size = Vector2.new(frame.Size.X.Offset, frame.Size.Y.Offset);
        local corner = Vector2.new(topbar.Max.X - 8 - size.X, topbar.Height * 34 / 58 - size.Y / 2) - gui_service:GetGuiInset();

        if (topbar.Min.X + 8 + size.X > topbar.Max.X - 8) then
            corner = Vector2.new(screen_gui.AbsoluteSize.X - size.X - 8, 8);
        end;

        watermark_position = UDim2.fromOffset(math.round(corner.X), math.round(corner.Y));
    end;

    frame.Position = watermark_position;
end;

local press_menu_button = function(input)
    local input_type = input.UserInputType;
    local record = nil;

    if (input_type == mouse_button_one) then
        task.spawn(Library.Toggle);
        return;
    end;

    if (input_type ~= touch) then
        return;
    end;

    record = drag_record(view.button, input, 1);
    record.tap = function()
        task.spawn(Library.Toggle);
    end;

    begin_gesture(record);
end;

local dispatch_began = function(input, processed)
    local input_type = input.UserInputType;
    local key_code = input.KeyCode;
    local session = binding.session;
    local current = popup.current;
    local pointer = (input_type == mouse_button_one) or (input_type == mouse_button_two) or (input_type == touch);
    local typing = (input_type == keyboard) and (input_service:GetFocusedTextBox() ~= nil);
    local keybind = Library.ToggleKeybind;
    local consumed = false;

    if (session) then
        consumed = session:listen(input);
    end;

    if (current) and (pointer) then
        local position = flat(input.Position);
        local outside = (not inside(current.frame, position)) and (not inside(current.owner, position));

        if (outside) then
            close_popup(current);
        end;
    end;

    if (not consumed) and (not typing) then
        for _, entry in key_pickers do
            local matched = (entry.mouse_type == input_type) or ((input_type == keyboard) and (entry.key_code == key_code));

            if (matched) then
                task.spawn(entry.press, entry);
            end;
        end;
    end;

    if (not consumed) and (not typing) and (Library.Toggle) then
        local right_control = (key_code == Enum.KeyCode.RightControl);
        local right_shift = (key_code == Enum.KeyCode.RightShift) and (not processed);

        if (type(keybind) == "table") and (keybind.Type == "KeyPicker") then
            local mouse_matched = (mouse_keys[keybind.Value] == input_type);
            local key_matched = (input_type == keyboard) and (key_code ~= Enum.KeyCode.Unknown) and (key_code.Name == keybind.Value);

            if (mouse_matched) or (key_matched) then
                task.spawn(Library.Toggle);
            end;
        elseif (right_control) or (right_shift) then
            task.spawn(Library.Toggle);
        end;
    end;

    for _, handler in Library.InputBeganHandlers do
        task.spawn(handler, input, processed);
    end;
end;

local dispatch_ended = function(input, processed)
    local input_type = input.UserInputType;
    local key_code = input.KeyCode;

    for _, entry in key_pickers do
        local matched = (entry.mouse_type == input_type) or ((input_type == keyboard) and (entry.key_code == key_code));

        if (matched) then
            task.spawn(entry.release, entry);
        end;
    end;

    for _, handler in Library.InputEndedHandlers do
        task.spawn(handler, input, processed);
    end;
end;

local register_unload = function(self, callback)
    table.insert(unload_callbacks, callback);
end;

local add_groupbox = function(tab_parts, properties)
    local groupbox = {};
    local column = tab_parts.right;
    local name = properties.Name or "";
    local title_width = Library:GetTextBounds(name, Library.Font, 13) + 8;
    local top = 10;

    if (name == "") then
        top = 4;
    end;

    local outer = create("Frame", {
        BackgroundColor3 = "MainColor";
        BorderColor3 = "OutlineColor";
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 0, 17);
        ZIndex = 2;
    });

    local inner = create("Frame", {
        BackgroundColor3 = "MainColor";
        BorderSizePixel = 0;
        Size = UDim2.new(1, -2, 1, -2);
        Position = UDim2.new(0, 1, 0, 1);
        ZIndex = 4;
        Parent = outer;
    });

    local title = create_label({
        AutomaticSize = Enum.AutomaticSize.X;
        BackgroundColor3 = "MainColor";
        BackgroundTransparency = 0;
        BorderSizePixel = 0;
        Size = UDim2.new(0, 0, 0, 16);
        Position = UDim2.new(0, 5, 0, -9);
        TextSize = 13;
        Text = name;
        TextTruncate = Enum.TextTruncate.AtEnd;
        TextXAlignment = Enum.TextXAlignment.Left;
        Visible = (name ~= "");
        ZIndex = 5;
        Parent = inner;
    });

    local container = create("Frame", {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 4, 0, top);
        Size = UDim2.new(1, -4, 1, -top);
        ZIndex = 1;
        Parent = inner;
    });

    local layout = create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = container;
    });

    create("UIPadding", {
        PaddingLeft = UDim.new(0, 4);
        PaddingRight = UDim.new(0, 4);
        Parent = title;
    });

    if (properties.Side == 1) then
        column = tab_parts.left;
    end;

    groupbox.Container = container;

    groupbox.Resize = function(self)
        outer.Size = UDim2.new(1, 0, 0, top + padded_height(container, layout) + 4);
    end;

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        groupbox:Resize();
    end);

    if (name ~= "") then
        outer:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            local room = unscale(outer.AbsoluteSize.X) - 14;

            if (title_width > room) then
                title.AutomaticSize = Enum.AutomaticSize.None;
                title.Size = UDim2.new(0, room, 0, 16);
                return;
            end;

            title.AutomaticSize = Enum.AutomaticSize.X;
            title.Size = UDim2.new(0, 0, 0, 16);
        end);
    end;

    setmetatable(groupbox, base_groupbox);
    groupbox:AddBlank(3);
    trailing_blanks[container] = nil;

    outer.Parent = column;
    tab_parts.tab.Groupboxes[name] = groupbox;

    return groupbox;
end;

local place_tab_buttons = function(tabbox_parts)
    local buttons = tabbox_parts.buttons;
    local span = unscale(tabbox_parts.button_row.AbsoluteSize.X) - 1;

    for index, button in buttons do
        local left = math.floor((index - 1) * span / #buttons);
        local right = math.floor(index * span / #buttons);

        button.Position = UDim2.fromOffset(left, 0);
        button.Size = UDim2.new(0, right - left + 1, 1, 0);
    end;
end;

local add_tabbox_tab = function(tabbox_parts, name)
    local tab = {};

    local button = create("Frame", {
        BackgroundColor3 = "BackgroundColor";
        BorderColor3 = "OutlineColor";
        BorderMode = Enum.BorderMode.Inset;
        ZIndex = 6;
    });

    local block = create("Frame", {
        BackgroundColor3 = "MainColor";
        BorderSizePixel = 0;
        Position = UDim2.new(0, 0, 1, 0);
        Size = UDim2.new(1, 0, 0, 1);
        Visible = false;
        ZIndex = 9;
    });

    local container = create("Frame", {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 4, 0, 21);
        Size = UDim2.new(1, -4, 1, -21);
        Visible = false;
        ZIndex = 1;
    });

    local layout = create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = container;
    });

    local label = create_label({
        Position = UDim2.new(0, 3, 0, 0);
        Size = UDim2.new(1, -6, 1, 0);
        TextColor3 = "FontColorDark";
        TextSize = 14;
        Text = name;
        TextTruncate = Enum.TextTruncate.AtEnd;
        TextXAlignment = Enum.TextXAlignment.Center;
        ZIndex = 7;
        Parent = button;
    });

    local button_parts = { button = button; label = label; active = false; hovered = false; };

    block.Parent = button;

    tab.Container = container;

    tab.Show = function(self)
        for _, other in tabbox_parts.tabs do
            other:Hide();
        end;

        close_popup(popup.current);
        hide_tooltip(tooltip.host);

        container.Visible = true;
        block.Visible = true;
        set_color(button, "BackgroundColor3", "MainColor");
        button_parts.active = true;
        paint_tab(button_parts);

        tab:Resize();
    end;

    tab.Hide = function(self)
        container.Visible = false;
        block.Visible = false;
        set_color(button, "BackgroundColor3", "BackgroundColor");
        button_parts.active = false;
        paint_tab(button_parts);
    end;

    tab.Resize = function(self)
        if (not container.Visible) then
            return;
        end;

        tabbox_parts.outer.Size = UDim2.new(1, 0, 0, 21 + padded_height(container, layout) + 4);
    end;

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        tab:Resize();
    end);

    watch_tab_hover(button_parts);

    on_press(button, {
        click = function()
            tab:Show();
        end;
    });

    table.insert(tabbox_parts.tabs, tab);
    table.insert(tabbox_parts.buttons, button);
    tabbox_parts.tabbox.Tabs[name] = tab;
    setmetatable(tab, base_groupbox);

    button.Parent = tabbox_parts.button_row;
    container.Parent = tabbox_parts.inner;

    place_tab_buttons(tabbox_parts);
    tab:AddBlank(3);
    trailing_blanks[container] = nil;
    tab:Resize();

    if (#tabbox_parts.tabs == 1) then
        tab:Show();
    end;

    return tab;
end;

local add_tabbox = function(tab_parts, properties)
    local tabbox = { Tabs = {}; };
    local column = tab_parts.right;

    local outer = create("Frame", {
        BackgroundColor3 = "MainColor";
        BorderColor3 = "OutlineColor";
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 0, 0);
        ZIndex = 2;
    });

    local inner = create("Frame", {
        BackgroundColor3 = "MainColor";
        BorderSizePixel = 0;
        Size = UDim2.new(1, -2, 1, -2);
        Position = UDim2.new(0, 1, 0, 1);
        ZIndex = 4;
        Parent = outer;
    });

    local button_row = create("Frame", {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, -2, 0, -2);
        Size = UDim2.new(1, 4, 0, 18);
        ZIndex = 5;
        Parent = inner;
    });

    local tabbox_parts = {
        tabbox = tabbox;
        outer = outer;
        inner = inner;
        button_row = button_row;
        tabs = {};
        buttons = {};
    };

    if (properties.Side == 1) then
        column = tab_parts.left;
    end;

    tabbox.AddTab = function(self, name)
        return add_tabbox_tab(tabbox_parts, name or "");
    end;

    button_row:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        place_tab_buttons(tabbox_parts);
    end);

    outer.Parent = column;
    tab_parts.tab.Tabboxes[properties.Name or ""] = tabbox;

    return tabbox;
end;

local add_tab = function(window_parts, name)
    local tab = { Groupboxes = {}; Tabboxes = {}; };
    local width = Library:GetTextBounds(name, Library.Font, 14);

    local button = create("Frame", {
        BackgroundTransparency = 1;
        Size = UDim2.new(0, width + 4, 1, 0);
        ZIndex = 1;
    });

    local label = create_label({
        Position = UDim2.new(0, 0, 0, 0);
        Size = UDim2.new(1, 0, 1, -2);
        Text = name;
        TextColor3 = "FontColorDark";
        TextSize = 14;
        ZIndex = 1;
        Parent = button;
    });

    local blocker = create("Frame", {
        BackgroundColor3 = "AccentColor";
        BorderSizePixel = 0;
        Position = UDim2.new(0, 0, 1, -2);
        Size = UDim2.new(1, 0, 0, 2);
        Visible = false;
        ZIndex = 3;
        Parent = button;
    });

    local page = create("Frame", {
        Name = "TabFrame";
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 0, 0, 0);
        Size = UDim2.new(1, 0, 1, 0);
        Visible = false;
        ZIndex = 2;
    });

    local left = create("ScrollingFrame", {
        BackgroundTransparency = 1;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 8, 0, 12);
        Size = UDim2.new(0.5, -8, 1, -20);
        CanvasSize = UDim2.new(0, 0, 0, 0);
        BottomImage = scroll_image;
        MidImage = scroll_image;
        TopImage = scroll_image;
        ScrollBarImageColor3 = "AccentColor";
        ScrollBarThickness = 3;
        ZIndex = 2;
        Parent = page;
    });

    local right = create("ScrollingFrame", {
        BackgroundTransparency = 1;
        BorderSizePixel = 0;
        Position = UDim2.new(0.5, 4, 0, 12);
        Size = UDim2.new(0.5, -8, 1, -20);
        CanvasSize = UDim2.new(0, 0, 0, 0);
        BottomImage = scroll_image;
        MidImage = scroll_image;
        TopImage = scroll_image;
        ScrollBarImageColor3 = "AccentColor";
        ScrollBarThickness = 3;
        ZIndex = 2;
        Parent = page;
    });

    local left_layout = create("UIListLayout", {
        Padding = UDim.new(0, 8);
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        HorizontalAlignment = Enum.HorizontalAlignment.Center;
        Parent = left;
    });

    local right_layout = create("UIListLayout", {
        Padding = UDim.new(0, 8);
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        HorizontalAlignment = Enum.HorizontalAlignment.Center;
        Parent = right;
    });

    local tab_parts = {
        tab = tab;
        left = left;
        right = right;
    };

    local button_parts = { button = button; label = label; active = false; hovered = false; };

    create("UIPadding", {
        PaddingTop = UDim.new(0, 8);
        PaddingRight = UDim.new(0, 4);
        Parent = left;
    });

    create("UIPadding", {
        PaddingTop = UDim.new(0, 8);
        PaddingRight = UDim.new(0, 4);
        Parent = right;
    });

    tab.ShowTab = function(self)
        local tab_area = window_parts.tab_area;
        local left = 0;
        local shown = 0;
        local reveal = 0;

        for _, other in window_parts.tabs do
            other:HideTab();
        end;

        close_popup(popup.current);
        hide_tooltip(tooltip.host);

        blocker.Visible = true;
        page.Visible = true;
        button_parts.active = true;
        paint_tab(button_parts);

        left = (button.AbsolutePosition.X - tab_area.AbsolutePosition.X) / view.scale + tab_area.CanvasPosition.X;
        shown = tab_area.AbsoluteWindowSize.X / view.scale;
        reveal = math.max(tab_area.CanvasPosition.X, left + button.Size.X.Offset - shown);
        reveal = math.min(reveal, left);
        tab_area.CanvasPosition = Vector2.new(math.max(reveal, 0), 0);
    end;

    tab.HideTab = function(self)
        blocker.Visible = false;
        page.Visible = false;
        button_parts.active = false;
        paint_tab(button_parts);
    end;

    tab.SetLayoutOrder = function(self, order)
        button.LayoutOrder = order;
        window_parts.tab_layout:ApplyLayout();
    end;

    tab.AddGroupbox = function(self, groupbox_properties)
        return add_groupbox(tab_parts, groupbox_properties or {});
    end;

    tab.AddLeftGroupbox = function(self, groupbox_name)
        return tab:AddGroupbox({ Side = 1; Name = groupbox_name; });
    end;

    tab.AddRightGroupbox = function(self, groupbox_name)
        return tab:AddGroupbox({ Side = 2; Name = groupbox_name; });
    end;

    tab.AddTabbox = function(self, tabbox_properties)
        return add_tabbox(tab_parts, tabbox_properties or {});
    end;

    tab.AddLeftTabbox = function(self, tabbox_name)
        return tab:AddTabbox({ Name = tabbox_name; Side = 1; });
    end;

    tab.AddRightTabbox = function(self, tabbox_name)
        return tab:AddTabbox({ Name = tabbox_name; Side = 2; });
    end;

    page:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        local width = unscale(page.AbsoluteSize.X);
        local column_width = math.floor(width / 2) - 8;

        left.Size = UDim2.new(0, column_width, 1, -20);
        right.Position = UDim2.new(0, width - column_width - 4, 0, 12);
        right.Size = UDim2.new(0, column_width, 1, -20);
    end);

    left_layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        left.CanvasSize = UDim2.fromOffset(0, unscale(left_layout.AbsoluteContentSize.Y) + 16);
        left.ScrollBarImageColor3 = Library.AccentColor;
    end);

    right_layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        right.CanvasSize = UDim2.fromOffset(0, unscale(right_layout.AbsoluteContentSize.Y) + 16);
        right.ScrollBarImageColor3 = Library.AccentColor;
    end);

    watch_tab_hover(button_parts);

    on_press(button, {
        click = function()
            tab:ShowTab();
        end;
    });

    button.Parent = window_parts.tab_area;
    page.Parent = window_parts.tab_container;

    table.insert(window_parts.tabs, tab);
    window_parts.window.Tabs[name] = tab;

    if (#window_parts.tabs == 1) then
        tab:ShowTab();
    end;

    return tab;
end;

Library.SafeCallback = function(self, callback, ...)
    local success = true;
    local fault = nil;
    local message = nil;
    local finish = nil;

    if (not callback) then
        return;
    end;

    if (not Library.NotifyOnError) then
        return callback(...);
    end;

    success, fault = pcall(callback, ...);

    if (success) then
        return;
    end;

    message = tostring(fault);
    finish = select(2, string.find(message, ":%d+: "));

    if (not finish) then
        return Library:Notify(message);
    end;

    return Library:Notify(string.sub(message, finish + 1), 3);
end;

Library.AttemptSave = function(self)
    if (Library.SaveManager) then
        Library.SaveManager:Save();
    end;
end;

Library.Create = function(self, class, properties)
    return create(class, properties);
end;

Library.ApplyTextStroke = function(self, text_object)
    apply_text_stroke(text_object);
end;

Library.CreateLabel = function(self, properties)
    return create_label(properties);
end;

Library.MakeDraggable = function(self, frame, cutoff)
    frame.Active = true;

    frame.InputBegan:Connect(function(input)
        local input_type = input.UserInputType;
        local scale = 1;
        local position = nil;

        if (input_type ~= mouse_button_one) and (input_type ~= touch) then
            return;
        end;

        if (frame:IsDescendantOf(root)) then
            scale = view.scale;
        end;

        position = flat(input.Position);

        if (is_blocked(frame, position)) then
            return;
        end;

        if ((position.Y - frame.AbsolutePosition.Y) / scale > (cutoff or 40)) then
            return;
        end;

        begin_gesture(drag_record(frame, input, scale));
    end);
end;

Library.AddToolTip = function(self, text, host)
    local entry = { text = text; size = Vector2.zero; };

    if (touch_only) then
        host.InputBegan:Connect(function(input)
            if (input.UserInputType ~= touch) or (is_blocked(host, flat(input.Position))) then
                return;
            end;

            begin_gesture({ input = input; tip = entry; });
        end);

        return;
    end;

    host.MouseEnter:Connect(function()
        if (Library:MouseIsOverOpenedFrame()) then
            return;
        end;

        if (popup.current) and (popup.current.owner == host) then
            return;
        end;

        hide_tooltip(tooltip.host);
        show_tooltip(entry);
        place_tooltip(tooltip_corner(to_root(Vector2.new(mouse.X, mouse.Y))));
        tooltip.follow = input_service.InputChanged:Connect(follow_tooltip);
        tooltip.reveal = task.delay(tooltip_delay, reveal_tooltip, tooltip.frame);
    end);

    host.MouseLeave:Connect(function()
        hide_tooltip(entry);
    end);
end;

Library.OnHighlight = function(self, hover_object, target, properties, defaults)
    local parts = {
        target = target;
        properties = properties;
        defaults = defaults;
        hovered = false;
    };

    track_hover(hover_object, parts, paint_highlight);
end;

Library.MouseIsOverOpenedFrame = function(self)
    local position = Vector2.new(mouse.X, mouse.Y);

    for frame in Library.OpenedFrames do
        if (inside(frame, position)) then
            return true;
        end;
    end;
end;

Library.IsMouseOverFrame = function(self, frame)
    if (inside(frame, Vector2.new(mouse.X, mouse.Y))) then
        return true;
    end;
end;

Library.UpdateDependencyBoxes = function(self)
    for _, dependency_box in Library.DependencyBoxes do
        dependency_box:Update();
    end;
end;

Library.MapValue = function(self, value, from_min, from_max, to_min, to_max)
    local ratio = (value - from_min) / (from_max - from_min);

    return (1 - ratio) * to_min + ratio * to_max;
end;

Library.GetTextBounds = function(self, text, font, size, resolution)
    local bounds = text_service:GetTextSize(text, size, font, resolution or text_resolution);

    return bounds.X, bounds.Y;
end;

Library.GetDarkerColor = function(self, color)
    local hue, saturation, value = Color3.toHSV(color);

    return Color3.fromHSV(hue, saturation, value / 1.5);
end;

Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor);

do
    local theme_keys = { "FontColor"; "LabelColor"; "MainColor"; "BackgroundColor"; "AccentColor"; "OutlineColor"; };
    local classic = { "Classic"; "ffffff"; "c8c8c8"; "1c1c1c"; "141414"; "ffffff"; "323232"; };
    local seasons = {
        { "Ember"; "f5e9dd"; "cdbfb2"; "1d1917"; "151210"; "ee8a4a"; "3b302a"; };
        { "Maple"; "f6e8e4"; "cfbab5"; "1e1716"; "161010"; "e8705a"; "3e2926"; };
        { "Harvest"; "f5eedd"; "cdc5b1"; "1c1a15"; "14120e"; "e9b44c"; "39342a"; };
        { "Frost"; "eef4fb"; "c5cdd8"; "181b20"; "111418"; "9ccfff"; "2d343e"; };
        { "Aurora"; "ecf7f3"; "bfcfca"; "16191d"; "0f1215"; "7de3c0"; "29313a"; };
        { "Blossom"; "f8eef3"; "d3c3cb"; "1e191c"; "161214"; "f4a6c6"; "3b2f36"; };
        { "Meadow"; "f0f6ea"; "c7d0bf"; "181c17"; "111510"; "a6dc7e"; "2f392d"; };
        { "Lagoon"; "eaf7f7"; "bdd0d0"; "151b1d"; "0e1315"; "5fd6d4"; "273438"; };
        { "Sunset"; "fbefe9"; "d5c4bd"; "1f191c"; "171214"; "ff9f7a"; "3d2e33"; };
    };

    local make_theme = function(row)
        local theme = { Name = row[1]; };

        for index, key in theme_keys do
            theme[key] = Color3.fromHex(row[index + 1]);
        end;

        return theme;
    end;

    Library.Themes = {};

    for _, season in seasons do
        table.insert(Library.Themes, make_theme(season));
    end;

    table.insert(Library.Themes, make_theme(classic));

    for _, season in seasons do
        local variant = table.clone(classic);

        variant[1] = "Classic " .. season[1];
        variant[6] = season[6];

        table.insert(Library.Themes, make_theme(variant));
    end;

    Library.SetTheme = function(self, name)
        local theme = nil;

        for _, entry in Library.Themes do
            if (entry.Name == name) then
                theme = entry;
                break;
            end;
        end;

        if (not theme) then
            return;
        end;

        for _, key in theme_keys do
            Library[key] = theme[key];
        end;

        Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor);
        Library.Theme = name;

        for property, entries in themed do
            for instance, key in entries do
                instance[property] = theme_value(key);
            end;
        end;
    end;
end;

Library.GiveSignal = function(self, connection)
    table.insert(Library.Signals, connection);
end;

Library.OnUnload = register_unload;

Library.Unload = function(self)
    local current = gesture.active;
    local signals = Library.Signals;
    local legacy_unload = Library.OnUnload;

    if (Library.Unloaded) then
        return;
    end;

    Library.Unloaded = true;
    binding.session = nil;

    if (current) then
        end_gesture(current.last, false);
    end;

    close_popup(popup.current);
    hide_tooltip(tooltip.host);

    if (fade.driver) then
        fade.driver:Disconnect();
        fade.driver = nil;
    end;

    for index = #signals, 1, -1 do
        table.remove(signals, index):Disconnect();
    end;

    for _, callback in unload_callbacks do
        task.spawn(callback);
    end;

    if (legacy_unload) and (legacy_unload ~= register_unload) then
        task.spawn(legacy_unload);
    end;

    screen_gui:Destroy();

    table.clear(unload_callbacks);
    table.clear(Library.OpenedFrames);
    table.clear(Library.DependencyBoxes);
    table.clear(Library.InputBeganHandlers);
    table.clear(Library.InputEndedHandlers);
    table.clear(key_pickers);
    table.clear(player_dropdowns);
    table.clear(team_dropdowns);
    table.clear(fade.targets);
    table.clear(fade.properties);
    table.clear(fade.bases);
    table.clear(notices);
    table.clear(notice_stack);
    table.clear(hovering);
    table.clear(blank_frames);
    table.clear(list_containers);
    table.clear(trailing_blanks);
    table.clear(trailing_boxes);
    table.clear(addon_rows);

    for _, entries in themed do
        table.clear(entries);
    end;
end;

Library.SetWatermarkVisibility = function(self, visible)
    Library.Watermark.Visible = visible;
end;

Library.SetWatermark = function(self, text)
    local width = 0;
    local height = 0;
    local size = nil;

    Library.Watermark.Visible = true;

    if (text == watermark_text) then
        return;
    end;

    width, height = Library:GetTextBounds(text, Library.Font, 14);
    size = UDim2.new(0, width + 14, 0, height * 1.5 + 3);
    watermark_text = text;
    Library.WatermarkText.Text = text;

    if (size == Library.Watermark.Size) then
        return;
    end;

    Library.Watermark.Size = size;

    place_watermark(Library.Watermark);
end;

Library.Notify = function(self, text, duration)
    local key = tostring(text);
    local seconds = tonumber(duration) or 5;
    local shown = notices[key];
    local wrap_width = 0;
    local width = 0;
    local height = 0;
    local total = 0;
    local notice = nil;

    if (Library.Unloaded) then
        return;
    end;

    if (shown) then
        shown.deadline = os.clock() + seconds;
        return;
    end;

    wrap_width = math.min(screen_gui.AbsoluteSize.X - 16, 360) - 12;
    width, height = Library:GetTextBounds(text, Library.Font, 14, Vector2.new(wrap_width, math.huge));
    height += 7;
    total = height + 4;
    notice = { key = key; height = height; frame = nil; thread = nil; deadline = os.clock() + seconds; };

    for _, other in notice_stack do
        total += other.height + 4;
    end;

    while (total > screen_gui.AbsoluteSize.Y - 48) and (#notice_stack > 0) do
        local oldest = table.remove(notice_stack, 1);

        total -= oldest.height + 4;
        task.cancel(oldest.thread);
        destroy_themed(oldest.frame);

        if (notices[oldest.key] == oldest) then
            notices[oldest.key] = nil;
        end;
    end;

    local holder = create("Frame", {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 0, height + 4);
        ZIndex = 100;
    });

    local outer = create("Frame", {
        BorderColor3 = black;
        Size = UDim2.new(0, 0, 0, height);
        ClipsDescendants = true;
        ZIndex = 120;
        Parent = holder;
    });

    local inner = create("Frame", {
        BackgroundColor3 = "MainColor";
        BorderColor3 = "OutlineColor";
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 121;
        Parent = outer;
    });

    local shade = create("Frame", {
        BackgroundColor3 = white;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 122;
        Parent = inner;
    });

    create("UIGradient", {
        Color = "MainGradient";
        Rotation = -90;
        Parent = shade;
    });

    create_label({
        Position = UDim2.new(0, 5, 0, 1);
        Size = UDim2.new(0, wrap_width, 1, -2);
        Text = text;
        TextWrapped = true;
        TextXAlignment = Enum.TextXAlignment.Left;
        TextSize = 14;
        ZIndex = 123;
        Parent = shade;
    });

    notice.frame = holder;
    notices[key] = notice;
    table.insert(notice_stack, notice);

    holder.Parent = Library.NotificationArea;
    outer:TweenSize(UDim2.new(0, width + 12, 0, height), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.4, true);

    notice.thread = task.spawn(function()
        local remaining = notice.deadline - os.clock();

        while (remaining > 0) do
            task.wait(remaining);
            remaining = notice.deadline - os.clock();
        end;

        if (Library.Unloaded) then
            return;
        end;

        notices[key] = nil;
        outer:TweenSize(UDim2.new(0, 0, 0, height), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.4, true);

        task.wait(0.4);

        if (Library.Unloaded) then
            return;
        end;

        outer.BackgroundTransparency = 1;
        holder:TweenSize(UDim2.new(1, 0, 0, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true);

        task.wait(0.2);

        if (Library.Unloaded) then
            return;
        end;

        table.remove(notice_stack, table.find(notice_stack, notice));
        destroy_themed(holder);
    end);
end;

Library.CreateWindow = function(self, ...)
    local arguments = { ... };
    local properties = { AnchorPoint = Vector2.zero; };
    local window = { Tabs = {}; };

    if (type(arguments[1]) == "table") then
        properties = arguments[1];
    else
        properties.Title = arguments[1];
        properties.AutoShow = arguments[2] or false;
    end;

    if (type(properties.Title) ~= "string") then
        properties.Title = "No title";
    end;

    if (type(properties.TabPadding) ~= "number") then
        properties.TabPadding = 14;
    end;

    if (type(properties.MenuFadeTime) ~= "number") then
        properties.MenuFadeTime = 0.2;
    end;

    if (typeof(properties.Position) ~= "UDim2") then
        properties.Position = UDim2.fromOffset(380, 50);
    end;

    if (typeof(properties.Size) ~= "UDim2") then
        properties.Size = UDim2.fromOffset(600, 540);
    end;

    if (properties.Center) then
        properties.AnchorPoint = Vector2.new(0.5, 0.5);
        properties.Position = UDim2.fromScale(0.5, 0.5);
    end;

    local fixed_size = (properties.Size.X.Scale == 0) and (properties.Size.Y.Scale == 0) and (properties.Size.X.Offset > 0);

    local outer = create("Frame", {
        AnchorPoint = properties.AnchorPoint;
        BackgroundColor3 = "OutlineColor";
        BorderSizePixel = 0;
        Position = properties.Position;
        Size = properties.Size;
        Visible = false;
        ZIndex = 1;
    });

    local inner = create("Frame", {
        BackgroundColor3 = "MainColor";
        BorderSizePixel = 0;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 1;
        Parent = outer;
    });

    local title = create_label({
        Position = UDim2.new(0, 8, 0, 0);
        Size = UDim2.new(1, -16, 0, 24);
        Text = properties.Title;
        TextTruncate = Enum.TextTruncate.AtEnd;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 1;
        Parent = inner;
    });

    local section = create("Frame", {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 0, 0, 26);
        Size = UDim2.new(1, 0, 1, -26);
        ZIndex = 1;
    });

    local tab_area = create("ScrollingFrame", {
        BackgroundTransparency = 1;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 8, 0, 6);
        Size = UDim2.new(1, -16, 0, 22);
        CanvasSize = UDim2.new(0, 0, 0, 0);
        ScrollBarThickness = 0;
        ScrollingDirection = Enum.ScrollingDirection.X;
        ZIndex = 1;
        Parent = section;
    });

    local tab_layout = create("UIListLayout", {
        Padding = UDim.new(0, properties.TabPadding);
        FillDirection = Enum.FillDirection.Horizontal;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = tab_area;
    });

    local tab_container = create("Frame", {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 0, 0, 28);
        Size = UDim2.new(1, 0, 1, -28);
        ZIndex = 2;
        Parent = section;
    });

    local modal = create("TextButton", {
        BackgroundTransparency = 1;
        Size = UDim2.new(0, 0, 0, 0);
        Visible = true;
        Text = "";
        Modal = false;
        Parent = screen_gui;
    });

    local window_parts = {
        window = window;
        tabs = {};
        tab_area = tab_area;
        tab_layout = tab_layout;
        tab_container = tab_container;
    };

    create("Frame", {
        BackgroundColor3 = "OutlineColor";
        BorderSizePixel = 0;
        Position = UDim2.new(0, 0, 0, 25);
        Size = UDim2.new(1, 0, 0, 1);
        ZIndex = 1;
        Parent = inner;
    });

    section.Parent = inner;

    window.SetWindowTitle = function(self, text)
        title.Text = text;
    end;

    window.AddTab = function(self, name)
        return add_tab(window_parts, name or "");
    end;

    window.Holder = outer;

    fade.outer = outer;
    fade.modal = modal;
    fade.window_properties = properties;
    fade.open = false;
    fade.dirty = true;
    fade.watching = false;
    Library.Toggle = toggle_menu;

    view.holder = outer;
    view.base = nil;
    view.fitted = nil;
    view.lowered = nil;

    if (fixed_size) then
        view.base = Vector2.new(properties.Size.X.Offset, properties.Size.Y.Offset);
    end;

    if (touch_only) and (not view.button) then
        local button = create("Frame", {
            Active = true;
            BackgroundColor3 = Library.Black;
            BorderColor3 = Library.Black;
            Position = UDim2.fromOffset(8, 8);
            Size = UDim2.fromOffset(64, 30);
            ZIndex = 250;
        });

        local button_inner = create("Frame", {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.fromScale(1, 1);
            ZIndex = 251;
            Parent = button;
        });

        create_label({
            Position = UDim2.fromOffset(0, 2);
            Size = UDim2.new(1, 0, 1, -2);
            Text = "Menu";
            TextSize = 14;
            ZIndex = 253;
            Parent = button_inner;
        });

        button.InputBegan:Connect(press_menu_button);
        button.Parent = screen_gui;
        view.button = button;
        Library.NotificationArea.Position = UDim2.new(0, 8, 0, 42);
    end;

    tab_layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        tab_area.CanvasSize = UDim2.fromOffset(unscale(tab_layout.AbsoluteContentSize.X), 0);
    end);

    Library:MakeDraggable(outer, 25);
    outer.Parent = root;

    fit_window(view.holder);

    if (properties.AutoShow) then
        task.spawn(Library.Toggle);
    end;

    return window;
end;

groupbox_functions.AddBlank = function(self, size)
    local blank = create("Frame", {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 0, size);
        ZIndex = 1;
        Parent = self.Container;
    });

    blank_frames[blank] = true;
    list_containers[self.Container] = true;
    trailing_blanks[self.Container] = blank;

    return blank;
end;

local box_blank = function(box)
    local inner_blank = trailing_blanks[box.container];

    if (box.holder.Visible) and (inner_blank) then
        return inner_blank;
    end;

    return box.before;
end;

local blank_above = function(container)
    local blank = trailing_blanks[container];
    local box = trailing_boxes[container];

    if (blank) or (not box) then
        return blank;
    end;

    return box_blank(box);
end;

local title_height = function(blank)
    if (not blank) then
        return 10;
    end;

    return math.max(16 - blank.Size.Y.Offset, 7);
end;

local add_title = function(groupbox, text)
    local container = groupbox.Container;
    local box = trailing_boxes[container];
    local follows_box = (box ~= nil) and (trailing_blanks[container] == nil);

    local title = create_label({
        Size = UDim2.new(1, -4, 0, title_height(blank_above(container)));
        TextColor3 = "LabelColor";
        TextSize = 14;
        Text = text;
        TextTruncate = Enum.TextTruncate.AtEnd;
        TextXAlignment = Enum.TextXAlignment.Left;
        TextYAlignment = Enum.TextYAlignment.Bottom;
        ZIndex = 5;
        Parent = container;
    });

    if (follows_box) then
        table.insert(box.titles, title);
    end;

    groupbox:AddBlank(3);

    return title;
end;

Library.NotificationArea = create("Frame", {
    BackgroundTransparency = 1;
    Position = UDim2.new(0, 8, 0, 40);
    Size = UDim2.new(0, 300, 0, 200);
    ZIndex = 100;
});

create("UIListLayout", {
    Padding = UDim.new(0, 0);
    FillDirection = Enum.FillDirection.Vertical;
    SortOrder = Enum.SortOrder.LayoutOrder;
    Parent = Library.NotificationArea;
});

Library.Watermark = create("Frame", {
    BorderColor3 = black;
    Position = watermark_position;
    Size = UDim2.new(0, 213, 0, 20);
    ZIndex = 200;
    Visible = false;
});

do
    local watermark_inner = create("Frame", {
        BackgroundColor3 = "MainColor";
        BorderColor3 = "AccentColor";
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 201;
        Parent = Library.Watermark;
    });

    local shade = create("Frame", {
        BackgroundColor3 = white;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 202;
        Parent = watermark_inner;
    });

    create("UIGradient", {
        Color = "MainGradient";
        Rotation = -90;
        Parent = shade;
    });

    Library.WatermarkText = create_label({
        Position = UDim2.new(0, 6, 0, 1);
        Size = UDim2.new(1, -6, 1, -2);
        TextSize = 14;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 203;
        Parent = shade;
    });
end;

Library.KeybindFrame = create("Frame", {
    AnchorPoint = Vector2.new(0, 0.5);
    BorderColor3 = black;
    Position = UDim2.new(0, 8, 0.5, 0);
    Size = UDim2.new(0, 210, 0, 25);
    Visible = false;
    ZIndex = 100;
});

if (touch_only) then
    Library.KeybindFrame.AnchorPoint = Vector2.new(1, 0);
    Library.KeybindFrame.Position = UDim2.new(1, -8, 0, 42);
end;

do
    local keybind_frame = Library.KeybindFrame;
    local keybind_shown = nil;

    local keybind_inner = create("Frame", {
        BackgroundColor3 = "MainColor";
        BorderColor3 = "OutlineColor";
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 101;
        Parent = keybind_frame;
    });

    create_label({
        Size = UDim2.new(1, 0, 0, 20);
        Position = UDim2.fromOffset(5, 2);
        TextXAlignment = Enum.TextXAlignment.Left;
        Text = "Keybinds";
        ZIndex = 104;
        Parent = keybind_inner;
    });

    Library.KeybindContainer = create("Frame", {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 1, -22);
        Position = UDim2.new(0, 0, 0, 22);
        ZIndex = 1;
        Parent = keybind_inner;
    });

    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = Library.KeybindContainer;
    });

    create("UIPadding", {
        PaddingLeft = UDim.new(0, 5);
        PaddingRight = UDim.new(0, 5);
        Parent = Library.KeybindContainer;
    });

    keybind_shown = keybind_frame:GetPropertyChangedSignal("Visible"):Connect(function()
        local anchor = keybind_frame.AnchorPoint;
        local position = keybind_frame.Position;
        local top = position.Y.Scale * screen_gui.AbsoluteSize.Y + position.Y.Offset - anchor.Y * keybind_frame.Size.Y.Offset;

        if (not keybind_frame.Visible) then
            return;
        end;

        keybind_shown:Disconnect();
        keybind_frame.AnchorPoint = Vector2.new(anchor.X, 0);
        keybind_frame.Position = UDim2.new(position.X.Scale, position.X.Offset, 0, math.round(top));
    end);

    keybind_frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        keep_on_screen(keybind_frame, keybind_frame.BorderSizePixel, Vector2.zero);
    end);
end;

Library:MakeDraggable(Library.Watermark);
Library:MakeDraggable(Library.KeybindFrame);

Library.NotificationArea.Parent = screen_gui;
Library.Watermark.Parent = screen_gui;
Library.KeybindFrame.Parent = screen_gui;

place_watermark(Library.Watermark);

do
    local color_panel = {
        outer = nil;
        title = nil;
        map = nil;
        cursor = nil;
        hue_bar = nil;
        hue_cursor = nil;
        hex_box = nil;
        rgb_box = nil;
        alpha_outer = nil;
        alpha_bar = nil;
        alpha_cursor = nil;
        fields = nil;
        record = nil;
    };

    local color_menu = {
        outer = nil;
        record = nil;
        rows = {};
        copied_transparency = nil;
    };

    local rgb_text = function(color)
        return math.round(color.R * 255) .. ", " .. math.round(color.G * 255) .. ", " .. math.round(color.B * 255);
    end;

    local watch_row_hover = function(row)
        if (touch_only) then
            return;
        end;

        row.MouseEnter:Connect(function()
            set_color(row, "TextColor3", "FontColor");
        end);

        row.MouseLeave:Connect(function()
            set_color(row, "TextColor3", "FontColorDark");
        end);
    end;

    local set_active = function(field, active)
        field.active = active;
        paint_border(field);
    end;

    local set_typed_color = function(picker, color)
        local hue = picker.Hue;

        picker:SetHSVFromRGB(color);

        if (picker.Sat == 0) then
            picker.Hue = hue;
        end;
    end;

    local drag_map = function(position, record)
        local picker = record.picker;
        local map = color_panel.map;
        local offset = position - map.AbsolutePosition;
        local size = map.AbsoluteSize;
        local saturation = math.clamp(offset.X / size.X, 0, 1);
        local vibrance = 1 - math.clamp(offset.Y / size.Y, 0, 1);

        if (saturation == picker.Sat) and (vibrance == picker.Vib) then
            return;
        end;

        picker.Sat = saturation;
        picker.Vib = vibrance;
        picker:Display();
    end;

    local drag_hue = function(position, record)
        local picker = record.picker;
        local bar = color_panel.hue_bar;
        local travel = bar.AbsoluteSize.Y - color_panel.hue_cursor.AbsoluteSize.Y;
        local hue = math.clamp((position.Y - bar.AbsolutePosition.Y) / travel, 0, 1);

        if (hue == picker.Hue) then
            return;
        end;

        picker.Hue = hue;
        picker:Display();
    end;

    local drag_alpha = function(position, record)
        local picker = record.picker;
        local bar = color_panel.alpha_outer;
        local travel = bar.AbsoluteSize.X - color_panel.alpha_cursor.AbsoluteSize.X;
        local transparency = 1 - math.clamp((position.X - bar.AbsolutePosition.X) / travel, 0, 1);

        if (transparency == picker.Transparency) then
            return;
        end;

        picker.Transparency = transparency;
        picker:Display();
    end;

    local finish_drag = function(position, record)
        set_active(record.field, false);
    end;

    local start_drag = function(input, move, field)
        local input_type = input.UserInputType;
        local record = nil;

        if (input_type ~= mouse_button_one) and (input_type ~= touch) then
            return;
        end;

        if (is_blocked(field.outer, flat(input.Position))) then
            return;
        end;

        record = begin_gesture({
            input = input;
            picker = color_panel.record.picker;
            move = move;
            field = field;
            finish = finish_drag;
        });

        if (not record) then
            return;
        end;

        if (input_type == touch) then
            lock_column(record, color_panel.record.anchor);
        end;

        set_active(field, true);
        move(flat(input.Position), record);
    end;

    local press_map = function(input)
        start_drag(input, drag_map, color_panel.fields.map);
    end;

    local press_hue = function(input)
        start_drag(input, drag_hue, color_panel.fields.hue);
    end;

    local press_alpha = function(input)
        start_drag(input, drag_alpha, color_panel.fields.alpha);
    end;

    local focus_hex = function()
        set_active(color_panel.fields.hex, true);
    end;

    local focus_rgb = function()
        set_active(color_panel.fields.rgb, true);
    end;

    local commit_hex = function(enter_pressed)
        local picker = color_panel.record.picker;
        local success = false;
        local color = nil;

        set_active(color_panel.fields.hex, false);

        if (enter_pressed) or (touch_only) then
            success, color = pcall(Color3.fromHex, color_panel.hex_box.Text);
        end;

        if (success) then
            set_typed_color(picker, color);
        end;

        picker:Display();
    end;

    local commit_rgb = function(enter_pressed)
        local picker = color_panel.record.picker;
        local red = nil;
        local green = nil;
        local blue = nil;

        set_active(color_panel.fields.rgb, false);

        if (enter_pressed) or (touch_only) then
            red, green, blue = string.match(color_panel.rgb_box.Text, "(%d+),%s*(%d+),%s*(%d+)");
        end;

        if (red) then
            set_typed_color(picker, Color3.fromRGB(
                math.clamp(tonumber(red), 0, 255),
                math.clamp(tonumber(green), 0, 255),
                math.clamp(tonumber(blue), 0, 255)
            ));
        end;

        picker:Display();
    end;

    local close_panel = function(record)
        local current = gesture.active;

        if (current) and (current.picker == record.picker) then
            end_gesture(current.last, false);
        end;

        for _, field in color_panel.fields do
            field.hovered = false;
            set_active(field, false);
        end;

        record.swatch.open = false;
        paint_border(record.swatch);
    end;

    local close_menu = function(record)
        record.swatch.open = false;
        paint_border(record.swatch);
    end;

    local copy_color = function()
        local picker = color_menu.record.picker;

        Library.ColorClipboard = picker.Value;
        color_menu.copied_transparency = picker.Transparency;
        Library:Notify("Copied color!", 2);
    end;

    local paste_color = function()
        local record = color_menu.record;
        local picker = record.picker;
        local color = Library.ColorClipboard;
        local transparency = nil;

        if (not color) then
            Library:Notify("You have not copied a color!", 2);
            return;
        end;

        if (record.has_alpha) then
            transparency = color_menu.copied_transparency;
        end;

        picker.Transparency = transparency or picker.Transparency;
        set_typed_color(picker, color);
        picker:Display();
    end;

    local copy_hex = function()
        pcall(setclipboard, color_menu.record.picker.Value:ToHex());
        Library:Notify("Copied hex code to clipboard!", 2);
    end;

    local copy_rgb = function()
        pcall(setclipboard, rgb_text(color_menu.record.picker.Value));
        Library:Notify("Copied RGB values to clipboard!", 2);
    end;

    local menu_options = {
        { text = "Copy color"; action = copy_color; };
        { text = "Paste color"; action = paste_color; };
        { text = "Copy HEX"; action = copy_hex; };
        { text = "Copy RGB"; action = copy_rgb; };
    };

    addon_functions.AddColorPicker = function(self, index, properties)
        assert(properties.Default, "AddColorPicker: Missing default value.");

        local has_alpha = (type(properties.Transparency) == "number");
        local panel_height = 255;
        local shown_value = nil;
        local shown_transparency = nil;

        local picker = {
            Value = properties.Default;
            Transparency = properties.Transparency or 0;
            Type = "ColorPicker";
            Title = "Color picker";
            Callback = properties.Callback or function() end;
        };

        local swatch = create("Frame", {
            BorderColor3 = black;
            Size = UDim2.new(0, 28, 1, 0);
            ZIndex = 5;
        });

        local display_frame = create("Frame", {
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = swatch;
        });

        local hit = hit_region(swatch, UDim2.new(0, 0, 0, -3), UDim2.new(1, 4, 1, 6));
        local swatch_parts = { outer = swatch; hovered = false; open = false; };

        local panel_record = {
            anchor = display_frame;
            owner = hit;
            gap = 4;
            align_right = true;
            picker = picker;
            swatch = swatch_parts;
            close = close_panel;
        };

        local menu_record = {
            anchor = display_frame;
            owner = hit;
            gap = 4;
            align_right = true;
            picker = picker;
            has_alpha = has_alpha;
            swatch = swatch_parts;
            close = close_menu;
        };

        if (type(properties.Title) == "string") then
            picker.Title = properties.Title;
        end;

        if (has_alpha) then
            panel_height = 274;

            create("ImageLabel", {
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 5;
                Image = "http://www.roblox.com/asset/?id=12977615774";
                Parent = display_frame;
            });
        end;

        picker.SetHSVFromRGB = function(self, color)
            local hue, saturation, vibrance = Color3.toHSV(color);

            picker.Hue = hue;
            picker.Sat = saturation;
            picker.Vib = vibrance;
        end;

        picker.Display = function(self)
            local value = Color3.fromHSV(picker.Hue, picker.Sat, picker.Vib);
            local transparency = picker.Transparency;
            local changed = (value ~= shown_value) or (transparency ~= shown_transparency);
            local darker = nil;

            picker.Value = value;

            if (popup.current == panel_record) then
                color_panel.map.BackgroundColor3 = Color3.fromHSV(picker.Hue, 1, 1);
                color_panel.cursor.Position = UDim2.new(picker.Sat, 0, 1 - picker.Vib, 0);
                color_panel.hue_cursor.AnchorPoint = Vector2.new(0, picker.Hue);
                color_panel.hue_cursor.Position = UDim2.new(0, 0, picker.Hue, 0);
                color_panel.alpha_bar.BackgroundColor3 = value;
                color_panel.alpha_cursor.AnchorPoint = Vector2.new(1 - transparency, 0);
                color_panel.alpha_cursor.Position = UDim2.new(1 - transparency, 0, 0, 0);
                color_panel.hex_box.Text = "#" .. value:ToHex();
                color_panel.rgb_box.Text = rgb_text(value);
            end;

            if (not changed) then
                return;
            end;

            darker = Library:GetDarkerColor(value);
            shown_value = value;
            shown_transparency = transparency;

            swatch.BackgroundColor3 = darker;
            display_frame.BackgroundColor3 = value;
            display_frame.BackgroundTransparency = transparency;
            display_frame.BorderColor3 = darker;

            Library:SafeCallback(picker.Callback, value);
            Library:SafeCallback(picker.Changed, value);
        end;

        picker.OnChanged = function(self, callback)
            picker.Changed = callback;
            callback(picker.Value);
        end;

        picker.Show = function(self)
            if (not color_panel.outer) then
                local panel_outer = create("Frame", {
                    Name = "Color";
                    Active = true;
                    BackgroundColor3 = white;
                    BorderColor3 = black;
                    Visible = false;
                    ZIndex = 220;
                });

                local panel_inner = create("Frame", {
                    BackgroundColor3 = "BackgroundColor";
                    BorderColor3 = "OutlineColor";
                    BorderMode = Enum.BorderMode.Inset;
                    Size = UDim2.new(1, 0, 1, 0);
                    ZIndex = 221;
                    Parent = panel_outer;
                });

                local map_outer = create("Frame", {
                    BorderColor3 = black;
                    Position = UDim2.new(0, 4, 0, 25);
                    Size = UDim2.new(0, 201, 0, 200);
                    ZIndex = 222;
                    Parent = panel_inner;
                });

                local map = create("ImageLabel", {
                    BorderSizePixel = 0;
                    Size = UDim2.new(1, 0, 1, 0);
                    ZIndex = 223;
                    Image = "rbxassetid://4155801252";
                    Parent = map_outer;
                });

                local cursor = create("ImageLabel", {
                    AnchorPoint = Vector2.new(0.5, 0.5);
                    Size = UDim2.new(0, 6, 0, 6);
                    BackgroundTransparency = 1;
                    Image = "http://www.roblox.com/asset/?id=9619665977";
                    ImageColor3 = black;
                    ZIndex = 224;
                    Parent = map;
                });

                create("ImageLabel", {
                    Size = UDim2.new(0, 4, 0, 4);
                    Position = UDim2.new(0, 1, 0, 1);
                    BackgroundTransparency = 1;
                    Image = "http://www.roblox.com/asset/?id=9619665977";
                    ZIndex = 225;
                    Parent = cursor;
                });

                local hue_outer = create("Frame", {
                    BorderColor3 = black;
                    Position = UDim2.new(0, 209, 0, 25);
                    Size = UDim2.new(0, 15, 0, 200);
                    ZIndex = 222;
                    Parent = panel_inner;
                });

                local hue_bar = create("Frame", {
                    BackgroundColor3 = white;
                    BorderSizePixel = 0;
                    Size = UDim2.new(1, 0, 1, 0);
                    ZIndex = 223;
                    Parent = hue_outer;
                });

                local hue_cursor = create("Frame", {
                    BackgroundColor3 = white;
                    BorderColor3 = black;
                    Size = UDim2.new(1, 0, 0, 1);
                    ZIndex = 223;
                    Parent = hue_bar;
                });

                create("UIGradient", {
                    Color = hue_sequence;
                    Rotation = 90;
                    Parent = hue_bar;
                });

                local hex_outer = create("Frame", {
                    BorderColor3 = black;
                    Position = UDim2.fromOffset(4, 229);
                    Size = UDim2.new(0.5, -6, 0, 20);
                    ZIndex = 223;
                    Parent = panel_inner;
                });

                local hex_inner = create("Frame", {
                    BackgroundColor3 = "MainColor";
                    BorderColor3 = "OutlineColor";
                    BorderMode = Enum.BorderMode.Inset;
                    Size = UDim2.new(1, 0, 1, 0);
                    ZIndex = 223;
                    Parent = hex_outer;
                });

                create("UIGradient", {
                    Color = button_gradient;
                    Rotation = 90;
                    Parent = hex_inner;
                });

                local hex_box = create("TextBox", {
                    BackgroundTransparency = 1;
                    ClearTextOnFocus = false;
                    ClipsDescendants = true;
                    Position = UDim2.new(0, 5, 0, 0);
                    Size = UDim2.new(1, -10, 1, 0);
                    Font = Library.Font;
                    PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
                    PlaceholderText = "Hex color";
                    TextColor3 = "FontColor";
                    TextSize = 14;
                    TextXAlignment = Enum.TextXAlignment.Left;
                    ZIndex = 225;
                });

                apply_text_stroke(hex_box);
                hex_box.Parent = hex_inner;

                local rgb_outer = hex_outer:Clone();
                local rgb_inner = rgb_outer.Frame;
                local rgb_box = rgb_inner.TextBox;

                create(rgb_inner, {
                    BackgroundColor3 = "MainColor";
                    BorderColor3 = "OutlineColor";
                });

                create(rgb_box, {
                    PlaceholderText = "RGB color";
                    TextColor3 = "FontColor";
                });

                rgb_outer.Position = UDim2.new(0.5, 2, 0, 229);
                rgb_outer.Parent = panel_inner;

                local alpha_outer = create("Frame", {
                    BorderColor3 = black;
                    Position = UDim2.fromOffset(4, 253);
                    Size = UDim2.new(1, -8, 0, 15);
                    ZIndex = 224;
                    Parent = panel_inner;
                });

                local alpha_bar = create("Frame", {
                    BorderColor3 = "OutlineColor";
                    BorderMode = Enum.BorderMode.Inset;
                    Size = UDim2.new(1, 0, 1, 0);
                    ZIndex = 224;
                    Parent = alpha_outer;
                });

                create("ImageLabel", {
                    BackgroundTransparency = 1;
                    Size = UDim2.new(1, 0, 1, 0);
                    Image = "http://www.roblox.com/asset/?id=12978095818";
                    ZIndex = 225;
                    Parent = alpha_bar;
                });

                local alpha_cursor = create("Frame", {
                    BackgroundColor3 = white;
                    BorderColor3 = black;
                    Size = UDim2.new(0, 1, 1, 0);
                    ZIndex = 226;
                    Parent = alpha_outer;
                });

                local title = create_label({
                    Size = UDim2.new(1, -8, 0, 14);
                    Position = UDim2.fromOffset(4, 6);
                    TextXAlignment = Enum.TextXAlignment.Left;
                    TextSize = 14;
                    TextTruncate = Enum.TextTruncate.AtEnd;
                    TextWrapped = false;
                    ZIndex = 221;
                    Parent = panel_inner;
                });

                color_panel.outer = panel_outer;
                color_panel.title = title;
                color_panel.map = map;
                color_panel.cursor = cursor;
                color_panel.hue_bar = hue_bar;
                color_panel.hue_cursor = hue_cursor;
                color_panel.hex_box = hex_box;
                color_panel.rgb_box = rgb_box;
                color_panel.alpha_outer = alpha_outer;
                color_panel.alpha_bar = alpha_bar;
                color_panel.alpha_cursor = alpha_cursor;

                color_panel.fields = {
                    map = { outer = map_outer; hovered = false; active = false; };
                    hue = { outer = hue_outer; hovered = false; active = false; };
                    alpha = { outer = alpha_outer; hovered = false; active = false; };
                    hex = { outer = hex_outer; hovered = false; active = false; };
                    rgb = { outer = rgb_outer; hovered = false; active = false; };
                };

                map.InputBegan:Connect(press_map);
                hue_bar.InputBegan:Connect(press_hue);
                alpha_bar.InputBegan:Connect(press_alpha);
                hex_box.Focused:Connect(focus_hex);
                rgb_box.Focused:Connect(focus_rgb);
                hex_box.FocusLost:Connect(commit_hex);
                rgb_box.FocusLost:Connect(commit_rgb);

                for _, field in color_panel.fields do
                    watch_hover(field);
                end;

                panel_outer.Parent = root;
            end;

            color_panel.record = panel_record;
            color_panel.outer.Size = UDim2.fromOffset(230, panel_height);
            color_panel.alpha_outer.Visible = has_alpha;
            color_panel.title.Text = picker.Title;
            panel_record.frame = color_panel.outer;

            open_popup(panel_record);

            if (popup.current ~= panel_record) then
                return;
            end;

            picker:Display();

            swatch_parts.open = true;
            paint_border(swatch_parts);
        end;

        picker.Hide = function(self)
            close_popup(panel_record);
        end;

        picker.SetValue = function(self, hsv, transparency)
            picker.Transparency = transparency or picker.Transparency;
            picker.Hue = hsv[1];
            picker.Sat = hsv[2];
            picker.Vib = hsv[3];
            picker:Display();
        end;

        picker.SetValueRGB = function(self, color, transparency)
            picker.Transparency = transparency or picker.Transparency;
            picker:SetHSVFromRGB(color);
            picker:Display();
        end;

        on_press(hit, {
            click = function()
                if (popup.current == panel_record) then
                    picker:Hide();
                    return;
                end;

                picker:Show();
            end;

            alternate = function()
                if (not color_menu.outer) then
                    local width = 60;

                    local menu_outer = create("Frame", {
                        Active = true;
                        BorderColor3 = black;
                        Visible = false;
                        ZIndex = 220;
                    });

                    local menu_inner = create("Frame", {
                        BackgroundColor3 = "BackgroundColor";
                        BorderColor3 = "OutlineColor";
                        BorderMode = Enum.BorderMode.Inset;
                        Size = UDim2.fromScale(1, 1);
                        ZIndex = 221;
                        Parent = menu_outer;
                    });

                    create("UIListLayout", {
                        FillDirection = Enum.FillDirection.Vertical;
                        SortOrder = Enum.SortOrder.LayoutOrder;
                        Parent = menu_inner;
                    });

                    create("UIPadding", {
                        PaddingLeft = UDim.new(0, 4);
                        Parent = menu_inner;
                    });

                    for _, option in menu_options do
                        local text_width = Library:GetTextBounds(option.text, Library.Font, 13);

                        local row = create_label({
                            Size = UDim2.new(1, 0, 0, 15);
                            TextSize = 13;
                            Text = option.text;
                            TextXAlignment = Enum.TextXAlignment.Left;
                            ZIndex = 222;
                            Parent = menu_inner;
                        });

                        width = math.max(width, text_width);

                        table.insert(color_menu.rows, row);
                        watch_row_hover(row);
                        on_press(row, { click = option.action; });
                    end;

                    menu_outer.Size = UDim2.fromOffset(width + 10, #menu_options * 15 + 2);
                    menu_outer.Parent = root;
                    color_menu.outer = menu_outer;
                end;

                for _, row in color_menu.rows do
                    set_color(row, "TextColor3", "FontColorDark");
                end;

                color_menu.record = menu_record;
                menu_record.frame = color_menu.outer;

                open_popup(menu_record);

                if (popup.current ~= menu_record) then
                    return;
                end;

                swatch_parts.open = true;
                paint_border(swatch_parts);
            end;
        });

        watch_hover(swatch_parts);

        picker:SetHSVFromRGB(picker.Value);
        picker:Display();
        picker.DisplayFrame = display_frame;

        add_addon(self, swatch);
        options[index] = picker;

        return self;
    end;
end;

do
    local listen_delay = 0.2;
    local dot_interval = 0.4;
    local menu_width = 60;
    local default_modes = { "Always"; "Toggle"; "Hold"; };
    local mouse_names = { [mouse_button_one] = "MB1"; [mouse_button_two] = "MB2"; };

    local mode_menu = { frame = nil; inner = nil; rows = {}; entry = nil; record = nil; };

    local empty_callback = function() end;

    local key_lookup = {
        __index = function(entry, field)
            local bound = entry.bound;
            local name = entry.picker.Value;

            if (bound.name ~= name) then
                bound.name = name;
                bound.mouse_type = mouse_keys[name];
                bound.key_code = nil;

                if (type(name) == "string") then
                    bound.key_code = Enum.KeyCode:FromName(name);
                end;

                if (bound.key_code == Enum.KeyCode.Unknown) then
                    bound.key_code = nil;
                end;
            end;

            return bound[field];
        end;
    };

    local paint_line = function(entry)
        local line = entry.line;
        local color = "FontColor";

        if (not line) then
            return;
        end;

        if (not entry.picker:GetState()) then
            color = "FontColorDark";
        end;

        set_color(line, "TextColor3", color);
    end;

    local apply_key = function(entry, name)
        local width = Library:GetTextBounds(name, Library.Font, entry.display.TextSize);
        local box_width = math.max(28, width + 8);

        entry.picker.Value = name;
        entry.display.Text = name;
        entry.outer.Size = UDim2.new(0, box_width, 1, 0);
    end;

    local finish_picking = function(entry)
        entry.active = false;
        paint_border(entry);
    end;

    local report_change = function(picker, key)
        Library:SafeCallback(picker.ChangedCallback, key);
        Library:SafeCallback(picker.Changed, key);
    end;

    local listen_for_key = function(session, input)
        local input_type = input.UserInputType;
        local entry = session.entry;
        local picker = entry.picker;
        local name = mouse_names[input_type];
        local key = input_type;

        if (os.clock() < session.ready) then
            return false;
        end;

        if (input_type == keyboard) then
            name = input.KeyCode.Name;
            key = input.KeyCode;
        end;

        if (not name) then
            return false;
        end;

        binding.session = nil;
        task.defer(finish_picking, entry);

        if (key == Enum.KeyCode.Escape) then
            apply_key(entry, picker.Value);
            return true;
        end;

        if (key == Enum.KeyCode.Backspace) then
            name = "None";
            key = Enum.KeyCode.Unknown;
        end;

        apply_key(entry, name);
        picker:Update();

        task.spawn(report_change, picker, key);

        return true;
    end;

    local animate_dots = function(session)
        local display = session.entry.display;
        local dots = "";

        while (binding.session == session) do
            if (dots == "...") then
                dots = "";
            end;

            dots ..= ".";
            display.Text = dots;

            task.wait(dot_interval);
        end;
    end;

    local press_key = function(entry)
        local picker = entry.picker;

        if (entry.active) then
            return;
        end;

        if (picker.Mode == "Toggle") then
            picker.Toggled = not picker.Toggled;
            picker:DoClick();
        end;

        paint_line(entry);
    end;

    local release_key = function(entry)
        if (entry.active) then
            return;
        end;

        paint_line(entry);
    end;

    local paint_mode_row = function(row)
        local color = "FontColorDark";

        if (row.hovered) then
            color = "LabelColor";
        end;

        if (row.mode == mode_menu.entry.picker.Mode) then
            color = "AccentColor";
        end;

        set_color(row.label, "TextColor3", color);
    end;

    local close_mode_menu = function(record)
        record.entry.open = false;
        paint_border(record.entry);
    end;

    local open_mode_menu = function(entry)
        local modes = entry.modes;
        local rows = mode_menu.rows;

        if (not mode_menu.frame) then
            mode_menu.frame = create("Frame", {
                Active = true;
                BorderColor3 = black;
                Visible = false;
                ZIndex = 220;
            });

            mode_menu.inner = create("Frame", {
                BackgroundColor3 = "BackgroundColor";
                BorderColor3 = "OutlineColor";
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 221;
                Parent = mode_menu.frame;
            });

            create("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = mode_menu.inner;
            });

            mode_menu.frame.Parent = root;
        end;

        while (#rows < #modes) do
            local row = { label = nil; mode = nil; hovered = false; };

            row.label = create_label({
                Active = false;
                Size = UDim2.new(1, 0, 0, 15);
                TextSize = 13;
                ZIndex = 222;
            });

            on_press(row.label, {
                click = function()
                    local picker = mode_menu.entry.picker;

                    picker.Mode = row.mode;

                    task.defer(close_popup, mode_menu.record);
                    picker:Update();
                end;
            });

            if (not touch_only) then
                row.label.MouseEnter:Connect(function()
                    row.hovered = true;
                    paint_mode_row(row);
                end);

                row.label.MouseLeave:Connect(function()
                    row.hovered = false;
                    paint_mode_row(row);
                end);
            end;

            row.label.Parent = mode_menu.inner;
            table.insert(rows, row);
        end;

        mode_menu.entry = entry;

        for index, row in rows do
            local mode = modes[index];

            row.mode = mode;
            row.hovered = false;
            row.label.Visible = (mode ~= nil);

            if (mode) then
                row.label.Text = mode;
                paint_mode_row(row);
            end;
        end;

        mode_menu.frame.Size = UDim2.fromOffset(menu_width, #modes * 15 + 2);
        mode_menu.record = {
            frame = mode_menu.frame;
            anchor = entry.outer;
            gap = 4;
            align_right = true;
            owner = entry.hit;
            entry = entry;
            close = close_mode_menu;
        };

        open_popup(mode_menu.record);

        if (popup.current ~= mode_menu.record) then
            return;
        end;

        entry.open = true;
        paint_border(entry);
    end;

    addon_functions.AddKeyPicker = function(self, index, properties)
        local parent = self;

        assert(properties.Default, "AddKeyPicker: Missing default value.");

        if (properties.SyncToggleState) then
            properties.Modes = { "Toggle" };
            properties.Mode = "Toggle";
        end;

        local modes = properties.Modes or default_modes;
        local mode = properties.Mode or "Toggle";
        local title = properties.Text or "";
        local text_size = 13;
        local text_top = 0;
        local toggled = false;
        local line = nil;

        if (not table.find(modes, mode)) then
            mode = modes[1];
        end;

        if (parent.Type == "Toggle") then
            text_size = 11;
            text_top = -1;
        end;

        if (not properties.Text) and (parent.Type == "Toggle") then
            title = parent.TextLabel.Text;
        end;

        if (properties.SyncToggleState) and (parent.Type == "Toggle") then
            toggled = parent.Value;
        end;

        local outer = create("Frame", {
            BackgroundColor3 = black;
            BorderColor3 = black;
            ZIndex = 6;
        });

        local inner = create("Frame", {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 7;
            Parent = outer;
        });

        local display = create_label({
            Position = UDim2.new(0, 0, 0, text_top);
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = text_size;
            ZIndex = 8;
            Parent = inner;
        });

        local hit = hit_region(outer, UDim2.new(0, 0, 0, -3), UDim2.new(1, 4, 1, 6));

        if (not properties.NoUI) then
            line = create_label({
                TextXAlignment = Enum.TextXAlignment.Left;
                TextTruncate = Enum.TextTruncate.AtEnd;
                Size = UDim2.new(1, 0, 0, 18);
                TextSize = 13;
                Visible = false;
                ZIndex = 110;
                Parent = Library.KeybindContainer;
            });
        end;

        local picker = {
            Value = properties.Default;
            Toggled = toggled;
            Mode = mode;
            Type = "KeyPicker";
            Callback = properties.Callback or empty_callback;
            ChangedCallback = properties.ChangedCallback or empty_callback;
            SyncToggleState = properties.SyncToggleState or false;
        };

        local entry = setmetatable({
            picker = picker;
            bound = {};
            outer = outer;
            display = display;
            hit = hit;
            line = line;
            modes = modes;
            text = nil;
            press = press_key;
            release = release_key;
            shown = false;
            width = 0;
            active = false;
            hovered = false;
            open = false;
        }, key_lookup);

        local press_actions = {
            click = function()
                if (binding.session) or (entry.active) then
                    return;
                end;

                local session = {
                    listen = listen_for_key;
                    entry = entry;
                    ready = os.clock() + listen_delay;
                };

                entry.active = true;
                binding.session = session;

                close_popup(mode_menu.record);
                paint_border(entry);
                task.spawn(animate_dots, session);
            end;

            alternate = function()
                open_mode_menu(entry);
            end;
        };

        if (touch_only) then
            press_actions.click = press_actions.alternate;
        end;

        picker.Update = function(self)
            if (not line) then
                return;
            end;

            local text = string.format("[%s] %s (%s)", picker.Value, title, picker.Mode);

            paint_line(entry);

            if (text == entry.text) then
                return;
            end;

            local width = Library:GetTextBounds(text, Library.Font, 13);

            entry.text = text;
            entry.shown = (picker.Value ~= "None");
            entry.width = math.min(width, 300);
            line.Text = text;
            line.Visible = entry.shown;

            local widest = 0;
            local count = 0;

            for _, other in key_pickers do
                if (other.shown) then
                    count += 1;
                    widest = math.max(widest, other.width);
                end;
            end;

            Library.KeybindFrame.Size = UDim2.new(0, math.max(widest + 12, 210), 0, count * 18 + 25);
        end;

        picker.GetState = function(self)
            local mode = picker.Mode;

            if (mode == "Always") then
                return true;
            end;

            if (mode ~= "Hold") then
                return picker.Toggled;
            end;

            if (entry.mouse_type) then
                return input_service:IsMouseButtonPressed(entry.mouse_type);
            end;

            if (entry.key_code) then
                return input_service:IsKeyDown(entry.key_code);
            end;

            return false;
        end;

        picker.SetValue = function(self, value)
            local key = value[1];
            local mode = value[2];

            if (key ~= nil) then
                apply_key(entry, key);
            end;

            if (table.find(modes, mode)) then
                picker.Mode = mode;

                if (mode_menu.entry == entry) then
                    close_popup(mode_menu.record);
                end;
            end;

            picker:Update();
        end;

        picker.OnClick = function(self, callback)
            picker.Clicked = callback;
        end;

        picker.OnChanged = function(self, callback)
            picker.Changed = callback;
            callback(picker.Value);
        end;

        picker.DoClick = function(self)
            if (parent.Type == "Toggle") and (picker.SyncToggleState) then
                parent:SetValue(not parent.Value);
            end;

            Library:SafeCallback(picker.Callback, picker.Toggled);
            Library:SafeCallback(picker.Clicked, picker.Toggled);
        end;

        apply_key(entry, properties.Default);
        table.insert(key_pickers, entry);

        if (parent.Addons) then
            table.insert(parent.Addons, picker);
        end;

        on_press(hit, press_actions);
        watch_hover(entry);

        add_addon(parent, outer);

        picker:Update();
        options[index] = picker;

        return self;
    end;
end;

do
    local numeric_partials = { ["-"] = true; ["."] = true; ["-."] = true; };
    local unbounded = Vector2.new(math.huge, math.huge);
    local confirm_time = 0.5;
    local flash_time = 0.15;
    local divider_blank = 9;

    local dependents = {};

    local empty_callback = function() end;

    local new_button = function(first, second)
        local button = { Text = first; Func = second; };

        if (type(first) == "table") then
            button = {
                Text = first.Text;
                Func = first.Func;
                DoubleClick = first.DoubleClick;
                Tooltip = first.Tooltip;
            };
        end;

        assert(type(button.Func) == "function", "AddButton: `Func` callback is missing.");

        return button;
    end;

    local add_tooltip = function(self, tooltip)
        if (type(tooltip) == "string") then
            Library:AddToolTip(tooltip, self.Outer);
        end;

        return self;
    end;

    local paint_press = function(parts, pressed)
        local color = "MainColor";

        if (pressed) then
            color = "OutlineColor";
        end;

        set_color(parts.inner, "BackgroundColor3", color);
    end;

    local restore_button = function(parts, armed)
        if (parts.armed ~= armed) then
            return;
        end;

        parts.armed = nil;
        parts.active = false;
        set_color(parts.label, "TextColor3", "LabelColor");
        parts.label.Text = parts.text;
        parts.button.Locked = false;

        paint_border(parts);
    end;

    local activate_button = function(position, record)
        local parts = record.parts;
        local button = parts.button;
        local armed = parts.armed;

        paint_press(parts, false);

        if (armed) then
            restore_button(parts, armed);
            Library:SafeCallback(button.Func);
            return;
        end;

        if (button.Locked) then
            return;
        end;

        if (not button.DoubleClick) then
            Library:SafeCallback(button.Func);
            return;
        end;

        parts.count += 1;
        parts.armed = parts.count;
        parts.active = true;
        parts.text = parts.label.Text;
        set_color(parts.label, "TextColor3", "AccentColor");
        parts.label.Text = "Are you sure?";
        button.Locked = true;

        paint_border(parts);
        task.delay(confirm_time, restore_button, parts, parts.armed);
    end;

    local track_press = function(position, record)
        if (record.input.UserInputType == mouse_button_one) then
            record.moved = not inside(record.parts.outer, position);
        end;

        paint_press(record.parts, not record.moved);
    end;

    local release_press = function(position, record)
        paint_press(record.parts, false);
    end;

    local build_button = function(button)
        local outer = create("Frame", {
            BackgroundColor3 = black;
            BorderColor3 = black;
            Size = UDim2.new(1, -4, 0, 20);
            ZIndex = 5;
        });

        local inner = create("Frame", {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = outer;
        });

        local label = create_label({
            Position = UDim2.fromOffset(4, 0);
            Size = UDim2.new(1, -8, 1, 0);
            TextColor3 = "LabelColor";
            TextSize = 14;
            Text = button.Text;
            TextTruncate = Enum.TextTruncate.AtEnd;
            ZIndex = 6;
            Parent = inner;
        });

        local parts = {
            button = button;
            outer = outer;
            inner = inner;
            label = label;
            hovered = false;
            active = false;
            armed = nil;
            count = 0;
            text = nil;
        };

        create("UIGradient", {
            Color = button_gradient;
            Rotation = 90;
            Parent = inner;
        });

        button.Outer = outer;
        button.Inner = inner;
        button.Label = label;
        button.AddTooltip = add_tooltip;

        watch_hover(parts);

        outer.InputBegan:Connect(function(input)
            local input_type = input.UserInputType;
            local position = nil;
            local record = nil;

            if (input_type ~= mouse_button_one) and (input_type ~= touch) then
                return;
            end;

            position = flat(input.Position);

            if (is_blocked(outer, position)) then
                return;
            end;

            record = begin_gesture({ input = input; parts = parts; move = track_press; tap = activate_button; finish = release_press; });

            if (not record) then
                return;
            end;

            paint_press(parts, true);
        end);
    end;

    local add_sub_button = function(self, sub_first, sub_second)
        local sub_button = new_button(sub_first, sub_second);
        local main_outer = self.Outer;
        local container = main_outer.Parent;

        build_button(sub_button);

        local sub_outer = sub_button.Outer;

        main_outer.Size = UDim2.new(0.5, -4, 0, 20);
        sub_outer.Position = UDim2.new(1, 4, 0, 0);
        sub_outer.Size = UDim2.new(1, 0, 1, 0);
        sub_button:AddTooltip(sub_button.Tooltip);
        sub_outer.Parent = main_outer;

        container:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            local width = unscale(container.AbsoluteSize.X) - 8;
            local main_width = math.floor(width / 2);

            main_outer.Size = UDim2.new(0, main_width, 0, 20);
            sub_outer.Size = UDim2.new(0, width - main_width, 1, 0);
        end);

        return sub_button;
    end;

    local wrapped_height = function(text_label, text)
        local _, height = Library:GetTextBounds(text, Library.Font, 14, Vector2.new(unscale(text_label.AbsoluteSize.X), math.huge));

        return height + 1;
    end;

    local paint_input = function(parts)
        if (parts.flashes > 0) then
            set_color(parts.outer, "BorderColor3", "RiskColor");
            return;
        end;

        paint_border(parts);
    end;

    local end_flash = function(parts)
        parts.flashes -= 1;
        paint_input(parts);
    end;

    local flash_border = function(parts)
        parts.flashes += 1;
        paint_input(parts);

        task.delay(flash_time, end_flash, parts);
    end;

    local follow_cursor = function(parts)
        local box = parts.box;
        local text = box.Text;
        local cursor = box.CursorPosition;
        local reveal = 0;
        local shown_width = 0;
        local full_width = 0;
        local cursor_width = 0;
        local cursor_x = 0;

        if (not box:IsFocused()) or (text == "") then
            box.Position = UDim2.new(0, 2, 0, 0);
            return;
        end;

        reveal = unscale(parts.clip.AbsoluteSize.X);
        shown_width = box.TextBounds.X / view.scale;

        if (shown_width <= reveal - 4) then
            box.Position = UDim2.new(0, 2, 0, 0);
            return;
        end;

        if (cursor == -1) then
            return;
        end;

        full_width = text_service:GetTextSize(text, box.TextSize, box.Font, unbounded).X;
        cursor_width = text_service:GetTextSize(string.sub(text, 1, cursor - 1), box.TextSize, box.Font, unbounded).X;
        cursor_width = cursor_width * shown_width / full_width;
        cursor_x = box.Position.X.Offset + cursor_width;

        if (cursor_x < 2) then
            box.Position = UDim2.fromOffset(2 - cursor_width, 0);
            return;
        end;

        if (cursor_x > reveal - 3) then
            box.Position = UDim2.fromOffset(reveal - cursor_width - 3, 0);
        end;
    end;

    local format_value = function(slider, value)
        return string.format("%." .. slider.Rounding .. "f", value);
    end;

    local settle_value = function(slider, value, step)
        local factor = 10 ^ slider.Rounding;
        local low = math.min(slider.Min, slider.Max);
        local high = math.max(slider.Min, slider.Max);

        if (not step) then
            return math.clamp(math.round(value * factor) / factor, low, high);
        end;

        local steps = math.round((math.clamp(value, low, high) - slider.Min) / step);
        local settled = math.round((slider.Min + steps * step) * factor) / factor;

        if (settled > high) then
            settled = math.round((settled - step) * factor) / factor;
        end;

        if (settled < low) then
            settled = math.round((settled + step) * factor) / factor;
        end;

        return settled;
    end;

    local set_from_position = function(parts, position)
        local slider = parts.slider;
        local offset = (position.X - parts.outer.AbsolutePosition.X) / view.scale - 1;
        local value = slider:GetValueFromXOffset(math.clamp(offset, 0, slider.MaxSize));

        if (value == slider.Value) then
            return;
        end;

        slider.Value = value;
        slider:Display();

        Library:SafeCallback(slider.Callback, slider.Value);
        Library:SafeCallback(slider.Changed, slider.Value);
    end;

    local slide_to = function(position, record)
        set_from_position(record.slider, position);
    end;

    local slide_touch = function(position, record)
        local parts = record.slider;
        local delta = position - record.origin;

        if (record.axis) then
            set_from_position(parts, position);
            return;
        end;

        if (delta.Magnitude < 4) then
            return;
        end;

        if (math.abs(delta.Y) >= math.abs(delta.X)) then
            end_gesture(position, false);
            return;
        end;

        record.axis = "x";
        lock_column(record, parts.outer);
        parts.active = true;
        paint_border(parts);
        set_from_position(parts, position);
    end;

    local end_slide = function(position, record)
        local parts = record.slider;

        parts.active = false;
        paint_border(parts);
    end;

    groupbox_functions.AddLabel = function(self, text, wraps)
        local groupbox = self;
        local label = {};

        local text_label = create_label({
            Size = UDim2.new(1, -4, 0, 15);
            TextColor3 = "LabelColor";
            TextSize = 14;
            Text = text;
            TextWrapped = wraps or false;
            TextXAlignment = Enum.TextXAlignment.Left;
            TextYAlignment = Enum.TextYAlignment.Top;
            ZIndex = 5;
            Parent = groupbox.Container;
        });

        label.TextLabel = text_label;
        label.Container = groupbox.Container;

        label.SetText = function(self, new_text)
            text_label.Text = new_text;

            if (wraps) then
                text_label.Size = UDim2.new(1, -4, 0, wrapped_height(text_label, new_text));
            end;

            groupbox:Resize();
        end;

        if (wraps) then
            text_label.Size = UDim2.new(1, -4, 0, wrapped_height(text_label, text));

            text_label:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                text_label.Size = UDim2.new(1, -4, 0, wrapped_height(text_label, text_label.Text));
            end);
        else
            text_label.TextTruncate = Enum.TextTruncate.AtEnd;
            addon_rows[label] = { text = text_label; region = nil; offset = -4; edge = nil; height = 15; holder = nil; };
            setmetatable(label, base_addons);
        end;

        groupbox:AddBlank(5);

        return label;
    end;

    groupbox_functions.AddButton = function(self, first, second)
        local button = new_button(first, second);

        build_button(button);

        button.AddButton = add_sub_button;
        button:AddTooltip(button.Tooltip);
        button.Outer.Parent = self.Container;
        self:AddBlank(5);

        return button;
    end;

    groupbox_functions.AddDivider = function(self)
        local previous = trailing_blanks[self.Container];
        local above = 2;

        local outer = create("Frame", {
            BackgroundColor3 = black;
            BorderColor3 = black;
            Size = UDim2.new(1, -4, 0, 5);
            ZIndex = 5;
        });

        create("Frame", {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = outer;
        });

        if (previous) then
            above = math.max(divider_blank - previous.Size.Y.Offset, 0);
        end;

        self:AddBlank(above);
        outer.Parent = self.Container;
        self:AddBlank(divider_blank);
    end;

    groupbox_functions.AddInput = function(self, index, properties)
        assert(properties.Text, "AddInput: Missing `Text` string.");

        local input = {
            Value = properties.Default or "";
            Numeric = properties.Numeric or false;
            Finished = properties.Finished or false;
            Type = "Input";
            Callback = properties.Callback or empty_callback;
        };

        local finished = input.Finished;

        local outer = create("Frame", {
            BackgroundColor3 = black;
            BorderColor3 = black;
            Size = UDim2.new(1, -4, 0, 20);
            ZIndex = 5;
        });

        local inner = create("Frame", {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = outer;
        });

        local clip = create("Frame", {
            BackgroundTransparency = 1;
            ClipsDescendants = true;
            Position = UDim2.new(0, 3, 0, 0);
            Size = UDim2.new(1, -6, 1, 0);
            ZIndex = 7;
        });

        local box = create("TextBox", {
            BackgroundTransparency = 1;
            ClearTextOnFocus = false;
            Position = UDim2.new(0, 2, 0, 0);
            Size = UDim2.fromScale(5, 1);
            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = properties.Placeholder or "";
            Text = properties.Default or "";
            TextColor3 = "FontColor";
            TextSize = 14;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 7;
        });

        local input_parts = { outer = outer; clip = clip; box = box; hovered = false; active = false; flashes = 0; };

        if (box.PlaceholderText == "") then
            box.PlaceholderText = "...";
        end;

        create("UIGradient", {
            Color = button_gradient;
            Rotation = 90;
            Parent = inner;
        });

        apply_text_stroke(box);
        box.Parent = clip;
        clip.Parent = inner;

        input.SetValue = function(self, value)
            local text = tostring(value);
            local max_length = properties.MaxLength;

            if (max_length) and (#text > max_length) then
                text = string.sub(text, 1, max_length);
            end;

            if (input.Numeric) and (not tonumber(text)) and (#text > 0) then
                text = tostring(input.Value);
                flash_border(input_parts);
            end;

            input.Value = text;
            box.Text = text;

            Library:SafeCallback(input.Callback, input.Value);
            Library:SafeCallback(input.Changed, input.Value);
        end;

        input.OnChanged = function(self, callback)
            input.Changed = callback;
            callback(input.Value);
        end;

        if (not touch_only) then
            track_hover(outer, input_parts, paint_input);
        end;

        if (type(properties.Tooltip) == "string") then
            Library:AddToolTip(properties.Tooltip, outer);
        end;

        box:GetPropertyChangedSignal("Text"):Connect(function()
            local text = box.Text;
            local partial = (input.Numeric) and (numeric_partials[text] ~= nil);
            local rejected = (input.Numeric) and (text ~= "") and (not tonumber(text));
            local changed = (text ~= tostring(input.Value));

            follow_cursor(input_parts);

            if (finished) or (partial) or (not changed) then
                return;
            end;

            if (rejected) then
                box.Text = input.Value;
                flash_border(input_parts);
                return;
            end;

            input:SetValue(text);
        end);

        box:GetPropertyChangedSignal("CursorPosition"):Connect(function()
            follow_cursor(input_parts);
        end);

        box.Focused:Connect(function()
            input_parts.active = true;
            paint_input(input_parts);
            follow_cursor(input_parts);
        end);

        box.FocusLost:Connect(function(entered)
            local commit = (finished) and ((entered) or (touch_only));

            input_parts.active = false;
            paint_input(input_parts);

            if (commit) then
                input:SetValue(box.Text);
            elseif (box.Text ~= tostring(input.Value)) then
                box.Text = input.Value;
            end;

            follow_cursor(input_parts);
        end);

        add_title(self, properties.Text);
        outer.Parent = self.Container;
        self:AddBlank(5);

        options[index] = input;

        return input;
    end;

    groupbox_functions.AddToggle = function(self, index, properties)
        assert(properties.Text, "AddToggle: Missing `Text` string.");

        local toggle = {
            Value = properties.Default or false;
            Type = "Toggle";
            Callback = properties.Callback or empty_callback;
            Addons = {};
            Risky = properties.Risky;
        };

        local blank_size = properties.BlankSize or 7;
        local above = blank_above(self.Container);
        local reach = 3;
        local boxes = {};
        local blank = nil;

        local outer = create("Frame", {
            BackgroundColor3 = black;
            BorderColor3 = black;
            Size = UDim2.new(0, 13, 0, 13);
            ZIndex = 5;
        });

        local inner = create("Frame", {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = outer;
        });

        local text_label = create_label({
            Position = UDim2.new(0, 18, 0, -13);
            Size = UDim2.new(1, -22, 0, 12);
            TextColor3 = "LabelColor";
            TextSize = 14;
            Text = properties.Text;
            TextTruncate = Enum.TextTruncate.AtEnd;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 6;
        });

        if (above) then
            reach = math.min(above.Size.Y.Offset, 3);
        end;

        local region = create("Frame", {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 0, 0, -13 - reach);
            Size = UDim2.new(1, -4, 0, 13 + reach + math.min(blank_size, 4));
            ZIndex = 8;
        });

        local hit_area = hit_region(region, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0));

        if (toggle.Risky) then
            set_color(text_label, "TextColor3", "RiskColor");
        end;

        toggle.TextLabel = text_label;
        toggle.Container = self.Container;
        dependents[toggle] = boxes;
        addon_rows[toggle] = { text = text_label; region = region; offset = -22; edge = -4; height = 13; holder = nil; };

        toggle.Display = function(self)
            local fill = "MainColor";
            local edge = "OutlineColor";

            if (toggle.Value) then
                fill = "AccentColor";
                edge = "AccentColorDark";
            end;

            set_color(inner, "BackgroundColor3", fill);
            set_color(inner, "BorderColor3", edge);
        end;

        toggle.OnChanged = function(self, callback)
            toggle.Changed = callback;
            callback(toggle.Value);
        end;

        toggle.SetValue = function(self, value)
            local enabled = not not value;

            toggle.Value = enabled;
            toggle:Display();

            for _, addon in toggle.Addons do
                if (addon.Type == "KeyPicker") and (addon.SyncToggleState) then
                    addon.Toggled = enabled;
                    addon:Update();
                end;
            end;

            Library:SafeCallback(toggle.Callback, toggle.Value);
            Library:SafeCallback(toggle.Changed, toggle.Value);

            for _, dependency_box in boxes do
                dependency_box:Update();
            end;
        end;

        if (not touch_only) then
            Library:OnHighlight(region, outer, accent_border, black_border);
        end;

        if (type(properties.Tooltip) == "string") then
            Library:AddToolTip(properties.Tooltip, hit_area);
        end;

        on_press(hit_area, {
            click = function()
                toggle:SetValue(not toggle.Value);
            end;
        });

        toggle:Display();
        setmetatable(toggle, base_addons);

        outer.Parent = self.Container;
        blank = self:AddBlank(blank_size);
        text_label.Parent = blank;
        region.Parent = blank;

        toggles[index] = toggle;

        return toggle;
    end;

    groupbox_functions.AddSlider = function(self, index, properties)
        assert(properties.Default, "AddSlider: Missing default value.");
        assert(properties.Text, "AddSlider: Missing slider text.");
        assert(properties.Min, "AddSlider: Missing minimum value.");
        assert(properties.Max, "AddSlider: Missing maximum value.");
        assert(properties.Rounding, "AddSlider: Missing rounding value.");

        local rounding = properties.Rounding;

        local slider = {
            Value = properties.Default;
            Min = properties.Min;
            Max = properties.Max;
            Rounding = math.max(math.round(rounding), 0);
            MaxSize = 232;
            Type = "Slider";
            Callback = properties.Callback or empty_callback;
        };

        local compact_name = properties.Text;
        local text_inset = 0;
        local step = nil;

        local outer = create("Frame", {
            BackgroundColor3 = black;
            BorderColor3 = black;
            Size = UDim2.new(1, -4, 0, 18);
            ZIndex = 5;
        });

        local inner = create("Frame", {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = outer;
        });

        local fill = create("Frame", {
            BackgroundColor3 = "AccentColor";
            BorderColor3 = "AccentColorDark";
            Size = UDim2.new(0, 0, 1, 0);
            ZIndex = 7;
            Parent = inner;
        });

        local fill_edge = create("Frame", {
            BackgroundColor3 = "AccentColor";
            BorderSizePixel = 0;
            Position = UDim2.new(1, 0, 0, 0);
            Size = UDim2.new(0, 1, 1, 0);
            ZIndex = 8;
            Parent = fill;
        });

        local display_label = create_label({
            Position = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 0, 14);
            TextSize = 14;
            Text = "Infinite";
            ZIndex = 9;
            Parent = inner;
        });

        local fill_clip = create("Frame", {
            BackgroundColor3 = "AccentColor";
            BorderSizePixel = 0;
            ClipsDescendants = true;
            Size = UDim2.new(0, 0, 1, 0);
            ZIndex = 10;
            Parent = inner;
        });

        local fill_label = create("TextLabel", {
            BackgroundTransparency = 1;
            Font = Library.Font;
            Size = UDim2.new(0, 232, 0, 14);
            TextColor3 = "MainColor";
            TextSize = 14;
            Text = "Infinite";
            ZIndex = 11;
            Parent = fill_clip;
        });

        local slider_hit = hit_region(outer, UDim2.new(0, 0, 0, -4), UDim2.new(1, 0, 1, 8));

        local slider_parts = { slider = slider; outer = outer; hovered = false; active = false; };

        if (rounding > 0) and (rounding < 1) then
            step = rounding;
            slider.Rounding = 0;

            while (slider.Rounding < 6) do
                local scaled = step * 10 ^ slider.Rounding;

                if (math.abs(scaled - math.round(scaled)) < 1e-6) then
                    break;
                end;

                slider.Rounding += 1;
            end;
        end;

        if (properties.Compact) then
            text_inset = 4;
            display_label.Position = UDim2.new(0, 4, 0, 0);
            display_label.Size = UDim2.new(1, -8, 0, 14);
            display_label.TextTruncate = Enum.TextTruncate.AtEnd;
            fill_label.Position = UDim2.new(0, 4, 0, 0);
            fill_label.TextTruncate = Enum.TextTruncate.AtEnd;
        end;

        slider.Display = function(self)
            local suffix = properties.Suffix or "";
            local max_size = slider.MaxSize;
            local fill_width = math.ceil(max_size);
            local covered_width = 0;
            local value_text = format_value(slider, slider.Value) .. suffix;
            local max_text = format_value(slider, slider.Max) .. suffix;

            if (slider.Max ~= slider.Min) then
                fill_width = math.ceil(Library:MapValue(slider.Value, slider.Min, slider.Max, 0, max_size));
            end;

            if (properties.Compact) then
                display_label.Text = compact_name .. ": " .. value_text;
            elseif (properties.HideMax) then
                display_label.Text = value_text;
            else
                display_label.Text = value_text .. "/" .. max_text;
            end;

            fill.Size = UDim2.new(0, fill_width, 1, 0);
            fill.Visible = (fill_width > 0);
            fill_edge.Visible = (fill_width ~= 0) and (fill_width ~= max_size);
            covered_width = fill_width;

            if (fill_edge.Visible) then
                covered_width += 1;
            end;

            fill_clip.Size = UDim2.new(0, covered_width, 1, 0);
            fill_clip.Visible = fill.Visible;
            fill_label.Size = UDim2.new(0, max_size - text_inset * 2, 0, 14);
            fill_label.Text = display_label.Text;
        end;

        slider.OnChanged = function(self, callback)
            slider.Changed = callback;
            callback(slider.Value);
        end;

        slider.GetValueFromXOffset = function(self, offset)
            return settle_value(slider, Library:MapValue(offset, 0, slider.MaxSize, slider.Min, slider.Max), step);
        end;

        slider.SetValue = function(self, value)
            local amount = tonumber(value);

            if (not amount) or (amount ~= amount) then
                return;
            end;

            slider.Value = settle_value(slider, amount, step);
            slider:Display();

            Library:SafeCallback(slider.Callback, slider.Value);
            Library:SafeCallback(slider.Changed, slider.Value);
        end;

        slider.Value = settle_value(slider, tonumber(properties.Default), step);
        slider:Display();

        watch_hover(slider_parts);

        if (type(properties.Tooltip) == "string") then
            Library:AddToolTip(properties.Tooltip, slider_hit);
        end;

        slider_hit.InputBegan:Connect(function(input)
            local input_type = input.UserInputType;
            local position = nil;
            local record = nil;

            if (input_type ~= mouse_button_one) and (input_type ~= touch) then
                return;
            end;

            position = flat(input.Position);

            if (is_blocked(slider_hit, position)) then
                return;
            end;

            if (input_type == touch) then
                begin_gesture({ input = input; slider = slider_parts; move = slide_touch; tap = slide_to; finish = end_slide; });
                return;
            end;

            set_from_position(slider_parts, position);
            record = begin_gesture({ input = input; slider = slider_parts; move = slide_to; finish = end_slide; });

            if (not record) then
                return;
            end;

            slider_parts.active = true;
            paint_border(slider_parts);
        end);

        outer:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            slider.MaxSize = unscale(outer.AbsoluteSize.X) - 2;

            if (properties.Compact) then
                local suffix = properties.Suffix or "";
                local low_width = Library:GetTextBounds(": " .. format_value(slider, slider.Min) .. suffix, Library.Font, 14);
                local high_width = Library:GetTextBounds(": " .. format_value(slider, slider.Max) .. suffix, Library.Font, 14);
                local name_room = slider.MaxSize - 8 - math.max(low_width, high_width);
                local cut = #properties.Text;

                compact_name = properties.Text;

                while (cut > 0) and (Library:GetTextBounds(compact_name, Library.Font, 14) > name_room) do
                    cut -= 1;
                    compact_name = string.sub(properties.Text, 1, cut) .. "...";
                end;
            end;

            slider:Display();
        end);

        if (not properties.Compact) then
            add_title(self, properties.Text);
        end;

        outer.Parent = self.Container;
        self:AddBlank(properties.BlankSize or 6);

        options[index] = slider;

        return slider;
    end;

    groupbox_functions.AddDependencyBox = function(self)
        local groupbox = self;
        local dependency_box = { Dependencies = {}; };
        local box = nil;

        local holder = create("Frame", {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, 0);
        });

        local container = create("Frame", {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 1, 0);
            Parent = holder;
        });

        local layout = create("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = container;
        });

        box = { holder = holder; container = container; before = trailing_blanks[groupbox.Container]; titles = {}; };
        dependency_box.Container = container;

        dependency_box.Resize = function(self)
            holder.Size = UDim2.new(1, 0, 0, unscale(layout.AbsoluteContentSize.Y));

            for _, title in box.titles do
                title.Size = UDim2.new(1, -4, 0, title_height(box_blank(box)));
            end;

            groupbox:Resize();
        end;

        dependency_box.Update = function(self)
            local visible = true;

            for _, dependency in dependency_box.Dependencies do
                local element = dependency[1];

                if (element.Type == "Toggle") and (element.Value ~= dependency[2]) then
                    visible = false;
                    break;
                end;
            end;

            if (holder.Visible == visible) then
                return;
            end;

            if (not visible) and (popup.current) and (popup.current.anchor:IsDescendantOf(holder)) then
                close_popup(popup.current);
            end;

            holder.Visible = visible;
            dependency_box:Resize();
        end;

        dependency_box.SetupDependencies = function(self, dependencies)
            for _, dependency in dependencies do
                local boxes = nil;

                assert(type(dependency) == "table", "SetupDependencies: Dependency is not of type `table`.");
                assert(dependency[1], "SetupDependencies: Dependency is missing element argument.");
                assert(dependency[2] ~= nil, "SetupDependencies: Dependency is missing value argument.");

                boxes = dependents[dependency[1]];

                if (boxes) and (not table.find(boxes, dependency_box)) then
                    table.insert(boxes, dependency_box);
                end;
            end;

            dependency_box.Dependencies = dependencies;
            dependency_box:Update();
        end;

        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            dependency_box:Resize();
        end);

        setmetatable(dependency_box, base_groupbox);
        table.insert(Library.DependencyBoxes, dependency_box);

        holder.Parent = groupbox.Container;
        trailing_blanks[groupbox.Container] = nil;
        trailing_boxes[groupbox.Container] = box;

        return dependency_box;
    end;
end;

do
    local row_height = 20;
    local list_rows = 9;
    local flash_time = 0.15;

    local dropdown_list = {
        outer = nil;
        scrolling = nil;
        empty = nil;
        bound = nil;
        scrolled = nil;
        rows = {};
        shown = 0;
        first = 0;
    };
    local selected_names = {};

    local is_selected = function(record, value)
        local chosen = record.dropdown.Value;

        if (record.properties.Multi) then
            return chosen[value] == true;
        end;

        return chosen == value;
    end;

    local paint_row = function(row)
        local font = Font.fromEnum(Library.Font);
        local text_color = "FontColorDark";
        local border_color = "OutlineColor";
        local z_index = 223;

        if (row.selected) then
            font = Font.new(font.Family, Enum.FontWeight.Bold);
            text_color = "FontColor";
        end;

        if (row.hovered) then
            border_color = "AccentColor";
            z_index = 224;
        end;

        if (row.flashes > 0) then
            border_color = "RiskColor";
            z_index = 224;
        end;

        set_color(row.frame, "BackgroundColor3", "MainColor");
        set_color(row.frame, "BorderColor3", border_color);
        row.frame.ZIndex = z_index;
        row.label.FontFace = font;
        set_color(row.label, "TextColor3", text_color);
    end;

    local end_flash = function(row)
        row.flashes -= 1;
        paint_row(row);
    end;

    local create_row = function(parent)
        local frame = create("Frame", {
            Active = true;
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
            BorderMode = Enum.BorderMode.Middle;
            Size = UDim2.new(1, -1, 0, row_height);
            ZIndex = 223;
        });

        local row = {
            frame = frame;
            label = create_label({
                Position = UDim2.new(0, 6, 0, 0);
                Size = UDim2.new(1, -6, 1, 0);
                TextSize = 14;
                TextTruncate = Enum.TextTruncate.AtEnd;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 225;
                Parent = frame;
            });
            value = nil;
            selected = false;
            hovered = false;
            flashes = 0;
        };

        frame.Parent = parent;

        return row;
    end;

    local sync_rows = function(record)
        local rows = dropdown_list.rows;

        for index = 1, dropdown_list.shown do
            local row = rows[index];
            local selected = is_selected(record, row.value);

            if (row.selected ~= selected) then
                row.selected = selected;
                paint_row(row);
            end;
        end;
    end;

    local render_rows = function(record)
        local rows = dropdown_list.rows;
        local empty = dropdown_list.empty;
        local count = #record.dropdown.Values;
        local shown = math.min(count, list_rows);
        local width = unscale(record.anchor.AbsoluteSize.X);
        local height = math.clamp(count, 1, 8) * row_height + 1;

        for index = 1, shown do
            local row = rows[index];

            if (not row) then
                row = create_row(dropdown_list.scrolling);

                if (not touch_only) then
                    row.frame.MouseEnter:Connect(function()
                        row.hovered = true;
                        paint_row(row);
                    end);

                    row.frame.MouseLeave:Connect(function()
                        row.hovered = false;
                        paint_row(row);
                    end);
                end;

                on_press(row.frame, {
                    click = function()
                        local bound = dropdown_list.bound;
                        local wanted = not row.selected;
                        local dropdown = nil;
                        local multi = false;
                        local refused = false;
                        local selected_count = 0;

                        if (not bound) then
                            return;
                        end;

                        dropdown = bound.dropdown;
                        multi = bound.properties.Multi;

                        if (multi) then
                            for _ in dropdown.Value do
                                selected_count += 1;
                            end;
                        elseif (dropdown.Value) then
                            selected_count = 1;
                        end;

                        refused = (selected_count == 1) and (not wanted) and (not bound.properties.AllowNull);

                        if (refused) and (multi) then
                            row.flashes += 1;
                            paint_row(row);
                            task.delay(flash_time, end_flash, row);
                            return;
                        end;

                        if (refused) then
                            task.defer(close_popup, bound);
                            return;
                        end;

                        if (multi) then
                            dropdown.Value[row.value] = if (wanted) then true else nil;
                            sync_rows(bound);
                        else
                            dropdown.Value = if (wanted) then row.value else nil;
                            task.defer(close_popup, bound);
                        end;

                        dropdown:Display();

                        Library:SafeCallback(dropdown.Callback, dropdown.Value);
                        Library:SafeCallback(dropdown.Changed, dropdown.Value);
                    end;
                });

                rows[index] = row;
            end;

            row.frame.Visible = true;
        end;

        for index = shown + 1, dropdown_list.shown do
            rows[index].frame.Visible = false;
            rows[index].hovered = false;
        end;

        paint_row(empty);

        empty.frame.Visible = (count == 0);
        dropdown_list.shown = shown;
        dropdown_list.scrolling.CanvasSize = UDim2.fromOffset(0, count * row_height + 1);
        dropdown_list.outer.Size = UDim2.fromOffset(width, height);
    end;

    local top_row = function(record)
        local hidden = #record.dropdown.Values - dropdown_list.shown;
        local first = math.floor(dropdown_list.scrolling.CanvasPosition.Y / row_height);

        return math.clamp(first, 0, math.max(hidden, 0));
    end;

    local reveal_rows = function(scroll)
        local view_height = math.min(dropdown_list.shown, list_rows - 1) * row_height;

        for index = 1, dropdown_list.shown do
            local row = dropdown_list.rows[index];
            local top = (dropdown_list.first + index - 1) * row_height;
            local in_view = (top < scroll + view_height) and (top + row_height > scroll);

            if (row.hovered) and (not in_view) then
                row.hovered = false;
                paint_row(row);
            end;

            row.frame.Visible = in_view;
        end;
    end;

    local fill_rows = function(record)
        local values = record.dropdown.Values;
        local first = top_row(record);

        dropdown_list.first = first;

        for index = 1, dropdown_list.shown do
            local row = dropdown_list.rows[index];
            local position = first + index;

            row.value = values[position];
            row.selected = is_selected(record, row.value);
            row.label.Text = row.value;
            row.frame.Position = UDim2.fromOffset(0, (position - 1) * row_height);

            paint_row(row);
        end;

        reveal_rows(dropdown_list.scrolling.CanvasPosition.Y);
    end;

    local scroll_rows = function()
        local record = dropdown_list.bound;

        if (top_row(record) ~= dropdown_list.first) then
            fill_rows(record);
            return;
        end;

        reveal_rows(dropdown_list.scrolling.CanvasPosition.Y);
    end;

    local close_list = function(record)
        local rows = dropdown_list.rows;

        dropdown_list.scrolled:Disconnect();
        dropdown_list.scrolled = nil;
        dropdown_list.bound = nil;
        record.scroll = dropdown_list.scrolling.CanvasPosition;
        record.arrow.Rotation = 0;
        record.active = false;

        paint_border(record);

        for index = 1, dropdown_list.shown do
            local row = rows[index];

            if (row.hovered) then
                row.hovered = false;
                paint_row(row);
            end;
        end;
    end;

    local open_list = function(record)
        close_popup(popup.current);

        if (not dropdown_list.outer) then
            local outer = create("Frame", {
                Active = true;
                BackgroundColor3 = black;
                BorderColor3 = black;
                Visible = false;
                ZIndex = 220;
            });

            local inner = create("Frame", {
                BackgroundColor3 = "MainColor";
                BorderColor3 = "OutlineColor";
                BorderMode = Enum.BorderMode.Inset;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 221;
                Parent = outer;
            });

            local scrolling = create("ScrollingFrame", {
                BackgroundTransparency = 1;
                BorderSizePixel = 0;
                CanvasSize = UDim2.new(0, 0, 0, 0);
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 221;
                TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png";
                BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png";
                ScrollBarThickness = 3;
                ScrollBarImageColor3 = "AccentColor";
                VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar;
                Parent = inner;
            });

            local empty = create_row(scrolling);

            empty.label.Text = "No options";

            outer.Parent = root;
            dropdown_list.outer = outer;
            dropdown_list.scrolling = scrolling;
            dropdown_list.empty = empty;
        end;

        record.frame = dropdown_list.outer;

        render_rows(record);

        dropdown_list.scrolling.CanvasPosition = record.scroll;
        dropdown_list.bound = record;
        dropdown_list.scrolled = dropdown_list.scrolling:GetPropertyChangedSignal("CanvasPosition"):Connect(scroll_rows);
        record.arrow.Rotation = 180;
        record.active = true;

        fill_rows(record);
        paint_border(record);

        open_popup(record);

        if (popup.current ~= record) then
            close_list(record);
        end;
    end;

    groupbox_functions.AddDropdown = function(self, index, properties)
        local container = self.Container;

        if (properties.SpecialType == "Player") then
            properties.Values = player_names(nil);
            properties.AllowNull = true;
        elseif (properties.SpecialType == "Team") then
            properties.Values = team_names(teams);
            properties.AllowNull = true;
        end;

        assert(properties.Values, "AddDropdown: Missing dropdown value list.");
        assert(properties.AllowNull or properties.Default, "AddDropdown: Missing default value. Pass `AllowNull` as true if this was intentional.");

        local dropdown = {
            Values = properties.Values;
            Value = properties.Multi and {};
            Multi = properties.Multi;
            Type = "Dropdown";
            SpecialType = properties.SpecialType;
            Callback = properties.Callback or function() end;
        };

        local outer = create("Frame", {
            BackgroundColor3 = black;
            BorderColor3 = black;
            Size = UDim2.new(1, -4, 0, 20);
            ZIndex = 5;
        });

        local inner = create("Frame", {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = outer;
        });

        local arrow = create("ImageLabel", {
            AnchorPoint = Vector2.new(0, 0.5);
            BackgroundTransparency = 1;
            Position = UDim2.new(1, -16, 0.5, 0);
            Size = UDim2.new(0, 12, 0, 12);
            Image = "http://www.roblox.com/asset/?id=6282522798";
            ZIndex = 8;
            Parent = inner;
        });

        local value_label = create_label({
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -26, 1, 0);
            TextSize = 14;
            Text = "--";
            TextXAlignment = Enum.TextXAlignment.Left;
            TextTruncate = Enum.TextTruncate.AtEnd;
            ZIndex = 7;
            Parent = inner;
        });

        local record = {
            frame = nil;
            anchor = outer;
            outer = outer;
            gap = 2;
            close = close_list;
            dropdown = dropdown;
            properties = properties;
            arrow = arrow;
            scroll = Vector2.zero;
            hovered = false;
            active = false;
        };

        local defaults = {};

        create("UIGradient", {
            Color = button_gradient;
            Rotation = 90;
            Parent = inner;
        });

        dropdown.Display = function(self)
            local text = "";

            if (properties.Multi) then
                table.clear(selected_names);

                for _, value in dropdown.Values do
                    if (dropdown.Value[value]) then
                        table.insert(selected_names, value);
                    end;
                end;

                text = table.concat(selected_names, ", ");
            elseif (dropdown.Value) then
                text = dropdown.Value;
            end;

            if (text == "") then
                text = "--";
            end;

            value_label.Text = text;
        end;

        dropdown.GetActiveValues = function(self)
            local active = {};

            if (not properties.Multi) then
                return if (dropdown.Value) then 1 else 0;
            end;

            for value in dropdown.Value do
                table.insert(active, value);
            end;

            return active;
        end;

        dropdown.BuildDropdownList = function(self)
            if (dropdown_list.bound == record) then
                render_rows(record);
                fill_rows(record);
                place_popup(record);
            end;

            dropdown:Display();
        end;

        dropdown.SetValues = function(self, values)
            local changed = false;

            if (values) then
                dropdown.Values = values;
            end;

            if (properties.Multi) then
                for value in dropdown.Value do
                    if (not table.find(dropdown.Values, value)) then
                        dropdown.Value[value] = nil;
                        changed = true;
                    end;
                end;
            elseif (dropdown.Value) and (not table.find(dropdown.Values, dropdown.Value)) then
                dropdown.Value = nil;
                changed = true;
            end;

            dropdown:BuildDropdownList();

            if (not changed) then
                return;
            end;

            Library:SafeCallback(dropdown.Callback, dropdown.Value);
            Library:SafeCallback(dropdown.Changed, dropdown.Value);
        end;

        dropdown.OpenDropdown = function(self)
            open_list(record);
        end;

        dropdown.CloseDropdown = function(self)
            close_popup(record);
        end;

        dropdown.OnChanged = function(self, callback)
            dropdown.Changed = callback;
            callback(dropdown.Value);
        end;

        dropdown.SetValue = function(self, value)
            if (properties.Multi) then
                local chosen = {};
                local items = if (type(value) == "table") then value else { value };

                for key, flag in items do
                    local item = if (type(flag) == "boolean") then key else flag;

                    if (flag ~= false) and (table.find(dropdown.Values, item)) then
                        chosen[item] = true;
                    end;
                end;

                dropdown.Value = chosen;
            elseif (not value) then
                dropdown.Value = nil;
            elseif (table.find(dropdown.Values, value)) then
                dropdown.Value = value;
            end;

            if (dropdown_list.bound == record) then
                sync_rows(record);
            end;

            dropdown:Display();

            Library:SafeCallback(dropdown.Callback, dropdown.Value);
            Library:SafeCallback(dropdown.Changed, dropdown.Value);
        end;

        watch_hover(record);

        on_press(outer, {
            click = function()
                if (dropdown_list.bound == record) then
                    close_popup(record);
                    return;
                end;

                open_list(record);
            end;
        });

        if (type(properties.Tooltip) == "string") then
            Library:AddToolTip(properties.Tooltip, outer);
        end;

        if (type(properties.Default) == "table") then
            defaults = properties.Default;
        elseif (type(properties.Default) == "number") then
            defaults = { dropdown.Values[properties.Default] };
        elseif (type(properties.Default) == "string") then
            defaults = { properties.Default };
        end;

        for _, value in defaults do
            if (not table.find(dropdown.Values, value)) then
                continue;
            end;

            if (not properties.Multi) then
                dropdown.Value = value;
                break;
            end;

            dropdown.Value[value] = true;
        end;

        dropdown:Display();

        if (properties.Text) and (not properties.Compact) then
            add_title(self, properties.Text);
        end;

        outer.Parent = container;
        self:AddBlank(properties.BlankSize or 5);

        if (properties.SpecialType == "Player") then
            table.insert(player_dropdowns, dropdown);
        elseif (properties.SpecialType == "Team") then
            table.insert(team_dropdowns, dropdown);
        end;

        options[index] = dropdown;

        return dropdown;
    end;
end;

Library:GiveSignal(input_service.InputBegan:Connect(dispatch_began));
Library:GiveSignal(input_service.InputEnded:Connect(dispatch_ended));

Library:GiveSignal(players.PlayerAdded:Connect(function()
    refresh_dropdowns(player_dropdowns, player_names(nil));
end));

Library:GiveSignal(players.PlayerRemoving:Connect(function(player)
    refresh_dropdowns(player_dropdowns, player_names(player));
end));

Library:GiveSignal(teams.ChildAdded:Connect(refresh_team_lists));
Library:GiveSignal(teams.ChildRemoved:Connect(refresh_team_lists));

Library:GiveSignal(screen_gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    local current = gesture.active;

    if (current) then
        end_gesture(current.last, false);
    end;

    close_popup(popup.current);
    fit_window(view.holder);
    place_watermark(Library.Watermark);
    keep_on_screen(Library.KeybindFrame, Library.KeybindFrame.BorderSizePixel, Vector2.zero);
end));

if (topbar_found) then
    Library:GiveSignal(gui_service:GetPropertyChangedSignal("TopbarInset"):Connect(function()
        place_watermark(Library.Watermark);
    end));
end;

getgenv().Library = Library;

return Library;
