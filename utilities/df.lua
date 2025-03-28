local arg = ...

local folders = fs.list("/")

local mounts = {
    ["hdd"] = "/"
}

for _, folder in ipairs(folders) do
    if fs.isDir(folder) then
        local new = true
        for mount, path in pairs(mounts) do
            if fs.getDrive(folder) == mount then
                new = false
            end
        end
        if new then
            mounts[fs.getDrive(folder)] = "/" .. folder
        end
    end
end

print("Filesystem  Size      Used      Avail     Use%    Mount")
print("----------------------------------------------------------")

for mount, path in pairs(mounts) do
    local filesystem = mount
    local size = fs.getCapacity(path)
    local avail = fs.getFreeSpace(path)
    local used
    local use
    if size == nil or avail == nil then
        size = "-"
        avail = "-"
        used = "-"
        use = "-"
    else
        used = size - avail
        use = string.format("%.1f", used / avail * 100.0) .. "%"

        if arg == "-h" then
            if size > 1000000 then
                used = string.format("%.1f", used / 1000000.0) .. "M"
                size = string.format("%.1f", size / 1000000.0) .. "M"
                avail = string.format("%.1f", avail / 1000000.0) .. "M"
            else
                used = string.format("%.1f", used / 1000.0) .. "K"
                size = string.format("%.1f", size / 1000.0) .. "K"
                avail = string.format("%.1f", avail / 1000.0) .. "K"
            end
        end
    end

    

    print(string.format("%-12s%-10s%-10s%-10s%-8s%-8s", mount, size, used, avail, use, path))
end

