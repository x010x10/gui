local http_service = game:GetService("HttpService");

local parser = {
    Toggle = {};
    Slider = {};
    Dropdown = {};
    ColorPicker = {};
    KeyPicker = {};
    Input = {};
};

local save_manager = {
    Folder = "LinoriaLibSettings";
    Ignore = {};
    Parser = parser;
    Library = nil;
    AutoloadLabel = nil;
};

local config_path = function(folder, name)
    return folder .. "/settings/" .. name .. ".json";
end;

local autoload_path = function(folder)
    return folder .. "/settings/autoload.txt";
end;

local autoload_name = function(folder)
    local path = autoload_path(folder);
    local name = nil;

    if (not isfile(path)) then
        return nil;
    end;

    name = string.gsub(readfile(path), "[\r\n]+$", "");

    return name;
end;

local autoload_text = function(folder)
    local name = autoload_name(folder);
    local missing = (not name) or (not isfile(config_path(folder, name)));

    if (missing) then
        return "Current autoload config: none";
    end;

    return "Current autoload config: " .. name;
end;

parser.Toggle.Save = function(index, toggle)
    return { type = "Toggle"; idx = index; value = toggle.Value; };
end;

parser.Toggle.Load = function(index, entry)
    local toggle = Toggles[index];

    if (toggle) then
        toggle:SetValue(entry.value);
    end;
end;

parser.Slider.Save = function(index, slider)
    return { type = "Slider"; idx = index; value = tostring(slider.Value); };
end;

parser.Slider.Load = function(index, entry)
    local slider = Options[index];

    if (slider) then
        slider:SetValue(entry.value);
    end;
end;

parser.Dropdown.Save = function(index, dropdown)
    local selected = dropdown.Value;

    if (dropdown.Multi) then
        selected = {};

        for _, option in dropdown.Values do
            if (dropdown.Value[option]) then
                selected[tostring(option)] = true;
            end;
        end;
    end;

    return { type = "Dropdown"; idx = index; value = selected; mutli = dropdown.Multi; };
end;

parser.Dropdown.Load = function(index, entry)
    local dropdown = Options[index];
    local value = entry.value;
    local selected = {};

    if (not dropdown) then
        return;
    end;

    if (dropdown.Multi) and (type(value) == "table") then
        for _, option in dropdown.Values do
            local flagged = (value[option] == true) or (value[tostring(option)] == true);

            if (flagged) or (table.find(value, option)) then
                table.insert(selected, option);
            end;
        end;

        value = selected;
    end;

    dropdown:SetValue(value);
end;

parser.ColorPicker.Save = function(index, picker)
    return { type = "ColorPicker"; idx = index; value = picker.Value:ToHex(); transparency = picker.Transparency; };
end;

parser.ColorPicker.Load = function(index, entry)
    local picker = Options[index];

    if (picker) then
        picker:SetValueRGB(Color3.fromHex(entry.value), entry.transparency);
    end;
end;

parser.KeyPicker.Save = function(index, picker)
    return { type = "KeyPicker"; idx = index; mode = picker.Mode; key = picker.Value; };
end;

parser.KeyPicker.Load = function(index, entry)
    local picker = Options[index];

    if (picker) then
        picker:SetValue({ entry.key; entry.mode; });
    end;
end;

parser.Input.Save = function(index, input)
    return { type = "Input"; idx = index; text = input.Value; };
end;

parser.Input.Load = function(index, entry)
    local input = Options[index];

    if (input) and (type(entry.text) == "string") then
        input:SetValue(entry.text);
    end;
end;

save_manager.SetIgnoreIndexes = function(self, indexes)
    for _, index in indexes do
        self.Ignore[index] = true;
    end;
end;

save_manager.SetFolder = function(self, folder)
    self.Folder = folder;
    self:BuildFolderTree();
end;

save_manager.Save = function(self, name)
    local objects = {};
    local success = false;
    local encoded = nil;
    local written = false;

    if (not name) then
        return false, "no config file is selected";
    end;

    if (not string.find(name, "%S")) then
        return false, "name is empty";
    end;

    if (string.find(name, "[/\\:*?\"<>|]")) then
        return false, "name cannot contain / \\ : * ? \" < > |";
    end;

    for _, elements in { Toggles; Options; } do
        for index, element in elements do
            local element_parser = self.Parser[element.Type];

            if (self.Ignore[index]) or (not element_parser) then
                continue;
            end;

            table.insert(objects, element_parser.Save(index, element));
        end;
    end;

    success, encoded = pcall(function()
        return http_service:JSONEncode({ objects = objects; });
    end);

    if (not success) then
        return false, "failed to encode data";
    end;

    self:BuildFolderTree();

    written = pcall(writefile, config_path(self.Folder, name), encoded);

    if (not written) then
        return false, "failed to write file";
    end;

    return true;
end;

save_manager.Load = function(self, name)
    local path = nil;
    local contents = nil;
    local success = false;
    local decoded = nil;

    if (not name) then
        return false, "no config file is selected";
    end;

    path = config_path(self.Folder, name);

    if (not isfile(path)) then
        return false, "invalid file";
    end;

    contents = readfile(path);

    success, decoded = pcall(function()
        return http_service:JSONDecode(contents);
    end);

    if (not success) then
        return false, "decode error";
    end;

    if (type(decoded) ~= "table") or (type(decoded.objects) ~= "table") then
        return false, "invalid config";
    end;

    for _, entry in decoded.objects do
        if (type(entry) ~= "table") then
            continue;
        end;

        local entry_parser = self.Parser[entry.type];

        if (entry_parser) then
            task.spawn(entry_parser.Load, entry.idx, entry);
        end;
    end;

    return true;
end;

save_manager.BuildFolderTree = function(self)
    for _, path in { self.Folder; self.Folder .. "/settings"; } do
        if (not isfolder(path)) then
            makefolder(path);
        end;
    end;
end;

save_manager.RefreshConfigList = function(self)
    local folder = self.Folder .. "/settings";
    local names = {};

    if (not isfolder(folder)) then
        return names;
    end;

    for _, file in listfiles(folder) do
        local name = string.match(file, "([^/\\]+)%.json$");

        if (name) then
            table.insert(names, name);
        end;
    end;

    return names;
end;

save_manager.SetLibrary = function(self, library)
    self.Library = library;
end;

save_manager.LoadAutoloadConfig = function(self)
    local library = self.Library;
    local name = autoload_name(self.Folder);
    local loaded = false;
    local reason = nil;
    local config_list = nil;

    if (not name) then
        return;
    end;

    loaded, reason = self:Load(name);

    if (not loaded) and (library) then
        library:Notify("Failed to load autoload config: " .. reason);
    end;

    if (not loaded) then
        return;
    end;

    config_list = Options.SaveManager_ConfigList;

    if (config_list) then
        config_list:SetValues(self:RefreshConfigList());
        config_list:SetValue(name);
    end;

    if (library) then
        library:Notify(string.format("Auto loaded config %q", name));
    end;
end;

save_manager.BuildConfigSection = function(self, tab)
    assert(self.Library, "Must set SaveManager.Library");

    local library = self.Library;
    local section = tab:AddRightGroupbox("Configuration");
    local config_name = section:AddInput("SaveManager_ConfigName", { Text = "Config name"; Placeholder = "Type a name"; });
    local config_list = section:AddDropdown("SaveManager_ConfigList", { Text = "Config list"; Values = self:RefreshConfigList(); AllowNull = true; });

    section:AddDivider();

    section:AddButton("Save config", function()
        local typed = config_name.Value;
        local blank = (string.gsub(typed, " ", "") == "");
        local name = typed;
        local saved = false;
        local reason = nil;

        if (blank) then
            name = config_list.Value;
        end;

        if (not name) then
            library:Notify("Type a name or select a config", 2);
            return;
        end;

        saved, reason = self:Save(name);

        if (not saved) then
            library:Notify("Failed to save config: " .. reason);
            return;
        end;

        library:Notify(string.format("Saved config %q", name));

        config_list:SetValues(self:RefreshConfigList());
        config_list:SetValue(name);

        self.AutoloadLabel:SetText(autoload_text(self.Folder));
    end):AddButton("Load config", function()
        local name = config_list.Value;
        local loaded, reason = self:Load(name);

        if (not loaded) then
            library:Notify("Failed to load config: " .. reason);
            return;
        end;

        library:Notify(string.format("Loaded config %q", name));
    end);

    section:AddButton("Set as autoload", function()
        local name = config_list.Value;

        if (not name) then
            library:Notify("No config selected", 2);
            return;
        end;

        self:BuildFolderTree();

        writefile(autoload_path(self.Folder), name);
        self.AutoloadLabel:SetText(autoload_text(self.Folder));

        library:Notify(string.format("Set %q to auto load", name));
    end):AddButton("Clear autoload", function()
        local path = autoload_path(self.Folder);

        if (isfile(path)) then
            delfile(path);
        end;

        self.AutoloadLabel:SetText("Current autoload config: none");

        library:Notify("Cleared auto load");
    end);

    section:AddButton({
        Text = "Delete config";
        DoubleClick = true;
        Func = function()
            local name = config_list.Value;
            local path = nil;

            if (not name) then
                library:Notify("No config selected", 2);
                return;
            end;

            path = config_path(self.Folder, name);

            if (isfile(path)) then
                delfile(path);
            end;

            if (autoload_name(self.Folder) == name) then
                delfile(autoload_path(self.Folder));
            end;

            self.AutoloadLabel:SetText(autoload_text(self.Folder));

            library:Notify(string.format("Deleted config %q", name));

            config_list:SetValues(self:RefreshConfigList());
            config_list:SetValue(nil);
        end;
    });

    self.AutoloadLabel = section:AddLabel(autoload_text(self.Folder), true);

    self:SetIgnoreIndexes({ "SaveManager_ConfigList"; "SaveManager_ConfigName"; });
end;

return save_manager;
