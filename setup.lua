local args = {...}

local pack = nil
local target_path = ""

local standard_bin = {
    "/disk/utilities/cat.lua",
    "/disk/utilities/df.lua",
    "/disk/utilities/touch.lua",
    "/disk/utilities/whereis.lua",
    "/disk/services/svcman.lua",
    "/disk/networking/ping.lua"
}

local standard_lib = {
    "/disk/services/redrun.lua",
    "/disk/networking/network.lua",
    "/disk/networking/wireless.lua",
    "/disk/networking/wireless_dummy.lua"
}

local standard_startup = {
    "/disk/_startup/svcman.lua",
    "/disk/_startup/krempel.lua"
}

local function create_folders()
    if not fs.exists("/bin") then
        fs.makeDir("/bin")
        print("Created /bin")
    end
    if not fs.exists("/lib") then
        fs.makeDir("/lib")
        print("Created /lib")
    end
    if not fs.exists("/var") then
        fs.makeDir("/var")
        print("Created /var")
    end
end

local function copy_programs(folder, programs)
    folder = target_path .. folder
    for _, program in pairs(programs) do
        local file_name = fs.getName(program)
        if fs.exists(folder .. "/" .. file_name) then
            fs.delete(folder .. "/" .. file_name)
        end
        fs.copy(program, folder .. "/" .. file_name)
        print("- Copied " .. program .. " -> " .. folder .. "/" .. file_name)
    end
end

local function prepare_startup()
    print("Setting up startup environment...")

    if fs.exists(target_path .. "/startup") and not fs.isDir(target_path .. "/startup") then
        fs.move(target_path .. "/startup", target_path .. "/startup.temp")
    end

    if not fs.exists(target_path .. "/startup") then
        fs.makeDir(target_path .. "/startup")
    end

    if fs.exists(target_path .. "/startup.temp") and not fs.exists(target_path .. "/startup/00_startup") then
        print("Moved /startup to /startup/00_startup")
        fs.move(target_path .. "/startup.temp", target_path .. "/startup/00_startup")
    end

    if fs.exists(target_path .. "startup.lua") and not fs.exists(target_path .. "/startup/00_startup.lua") then
        print("Moved /startup.lua to /startup/00_startup.lua")
        fs.move(target_path .. "/startup.lua", target_path .. "/startup/00_startup.lua")
    end
end

local function install_standard()
    print("Installing Standard Pack")

    create_folders()

    copy_programs("/bin", standard_bin)
    copy_programs("/lib", standard_lib)

    prepare_startup()

    copy_programs("/startup", standard_startup)

    print("Installation of the Standard Pack completed")
end

local function install_weather()
    print("Installing Weather Station Software")

    copy_programs("/bin", { "/disk/software/weatherstation.lua" })

    print("Installation of Weather Station Software completed")
end

local function install_servernoise()
    print("Installing Server Noise Generator Software")

    copy_programs("/bin", { "/disk/software/servernoise.lua" })
    copy_programs("/var", { "/disk/software/servernoise.dfpwm" })

    print("Installation of Server Noise Generator Software completed")
end

local function install_mbs()
    local url = "https://raw.githubusercontent.com/SquidDev-CC/mbs/master/mbs.lua"
    if target_path ~= "" then
        print("Target installation of MBS not supported, skipping")
        return
    end
    if fs.exists("/.mbs") then
        print("MBS already installed, skipping")
        return
    end
    print("Installing MBS")

    fs.makeDir("/.mbs")

    local ok = http.checkURL(url)
    if not ok then
        print("Error downloading MBS, skipping")
        fs.delete("/.mbs")
        return
    end

    local response = http.get(url)
    if not response then
        print("Error downloading MBS, skipping")
        fs.delete("/.mbs")
        return
    end

    local file = fs.open("/.mbs/mbs.lua", "w")
    file.write(response.readAll())
    file.close()

    shell.run("/.mbs/mbs.lua", "install")

    print("Installation of MBS completed")
end

if args ~= nil then
    pack = args[1]
    if args[2] ~= nil then
        target_path = args[2]
    end
end

print(" == Setup of CC-Krempel ==")

if pack == "standard" then
    install_standard()
    return
end

if pack == "weatherstation" then
    install_weather()
    return
end

if pack == "servernoise" then
    install_servernoise()
    return
end

if pack == "mbs" then
    install_mbs()
    return
end

if pack == "all" then
    install_standard()
    install_weather()
    install_servernoise()
    install_mbs()
    return
end

print("Usage: setup <bundle> [target]")
print("Choose one of the following bundles:")
print("")
print(" all             Install everything below")
print("")
print(" standard        Standard Pack, including:")
print("                 - Unix like tools (cat, df, touch, whereis)")
print("                 - Service manager (svcman)")
print("                 - Networking service & utilities (ping)")
print("")
print(" weatherstation  Weather Station Software")
print("")
print(" servernoise     Server Noise Generator Software")
print("")
print(" mbs             Mildly Better Shell (MBS)")
print("                 - 3rd-party software by SquidDev-CC")
print("                 - Internet access required")
print("                 - Path installation not supported")
print("")