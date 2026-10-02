local theme_manager = {
    Library = nil;
};

theme_manager.SetLibrary = function(self, library)
    self.Library = library;
end;

theme_manager.ApplyToTab = function(self, tab, names)
    assert(self.Library, "Must set ThemeManager.Library");

    local library = self.Library;
    local theme_names = {};
    local shown = {};
    local default = nil;

    for _, theme in library.Themes do
        table.insert(theme_names, theme.Name);
    end;

    for _, name in names or theme_names do
        if (table.find(theme_names, name)) then
            table.insert(shown, name);
        end;
    end;

    default = shown[1];

    if (table.find(shown, library.Theme)) then
        default = library.Theme;
    end;

    tab:AddLeftGroupbox("Themes"):AddDropdown("ThemeManager_Theme", {
        Text = "Theme";
        Values = shown;
        Default = default;
        Callback = function(name)
            library:SetTheme(name);
        end;
    });

    if (default ~= library.Theme) then
        library:SetTheme(default);
    end;
end;

return theme_manager;
