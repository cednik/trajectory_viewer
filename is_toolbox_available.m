function r = is_toolbox_available(name)
    r = false;
    for v = ver
        if any(strcmpi(v.Name, name))
            r = true;
            return;
        end
    end
end