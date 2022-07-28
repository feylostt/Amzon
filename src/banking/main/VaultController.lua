-- Computer ID (CHANGE THIS)
local computerID = 3

-- Ender Modem
local side = "right"
rednet.open(side)

-- Version
local v = "1.0"

-- Load hash api for passwords
os.loadAPI("hash")

-- Authentication
function auth(id, account, pin)
    local accountRight = false
    local pinRight = false

    if fs.exists(account) then 
        accountRight = true
        local readAccount = fs.open(account, "r")
        pinFound = rf.readAll()

        if hash.checkPassword(pin, pinFound) then
            pinRight = true
        end
        rf.close()
    end

    if accountRight then
        if pinRight then
            rednet.send(id, "correct")
        end
    end
end

-- Main Loop
function begin()
    term.setBackgroundColor(colors.pink)
    term.clear()
    term.setCursorPos(1, 1)
    print("Vault Controller V"..v)
    id1, msg1 = rednet.receive()
    id2, msg2 = rednet.receive()
    a = textutils.unserialize(msg1)
    p = textutils.unserialize(msg2)
    if id1 == id2 then
        auth(id1, a, p)
    end
end

while true do
    begin()
end