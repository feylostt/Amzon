-- sha256
local MOD = 2^32
local MODM = MOD-1
 
local function memoize(f)
    local mt = {}
    local t = setmetatable({}, mt)
    function mt:__index(k)
        local v = f(k)
        t[k] = v
        return v
    end
    return t
end
 
local function make_bitop_uncached(t, m)
    local function bitop(a, b)
        local res,p = 0,1
        while a ~= 0 and b ~= 0 do
            local am, bm = a % m, b % m
            res = res + t[am][bm] * p
            a = (a - am) / m
            b = (b - bm) / m
            p = p*m
        end
        res = res + (a + b) * p
        return res
    end
    return bitop
end

local function make_bitop(t)
    local op1 = make_bitop_uncached(t,2^1)
    local op2 = memoize(function(a) return memoize(function(b) return op1(a, b) end) end)
    return make_bitop_uncached(op2, 2 ^ (t.n or 1))
end
 
local bxor1 = make_bitop({[0] = {[0] = 0,[1] = 1}, [1] = {[0] = 1, [1] = 0}, n = 4})
 
local function bxor(a, b, c, ...)
    local z = nil
    if b then
        a = a % MOD
        b = b % MOD
        z = bxor1(a, b)
        if c then z = bxor(z, c, ...) end
        return z
    elseif a then return a % MOD
    else return 0 end
end
 
local function band(a, b, c, ...)
    local z
    if b then
        a = a % MOD
        b = b % MOD
        z = ((a + b) - bxor1(a,b)) / 2
        if c then z = bit32_band(z, c, ...) end
        return z
    elseif a then return a % MOD
    else return MODM end
end
 
local function bnot(x) return (-1 - x) % MOD end
 
local function rshift1(a, disp)
    if disp < 0 then return lshift(a,-disp) end
    return math.floor(a % 2 ^ 32 / 2 ^ disp)
end
 
local function rshift(x, disp)
    if disp > 31 or disp < -31 then return 0 end
    return rshift1(x % MOD, disp)
end
 
local function lshift(a, disp)
    if disp < 0 then return rshift(a,-disp) end 
    return (a * 2 ^ disp) % 2 ^ 32
end
 
local function rrotate(x, disp)
    x = x % MOD
    disp = disp % 32
    local low = band(x, 2 ^ disp - 1)
    return rshift(x, disp) + lshift(low, 32 - disp)
end
 
local k = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}
 
local function str2hexa(s)
    return (string.gsub(s, ".", function(c) return string.format("%02x", string.byte(c)) end))
end
 
local function num2s(l, n)
    local s = ""
    for i = 1, n do
        local rem = l % 256
        s = string.char(rem) .. s
        l = (l - rem) / 256
    end
    return s
end
 
local function s232num(s, i)
    local n = 0
    for i = i, i + 3 do n = n*256 + string.byte(s, i) end
    return n
end
 
local function preproc(msg, len)
    local extra = 64 - ((len + 9) % 64)
    len = num2s(8 * len, 8)
    msg = msg .. "\128" .. string.rep("\0", extra) .. len
    assert(#msg % 64 == 0)
    return msg
end
 
local function initH256(H)
    H[1] = 0x6a09e667
    H[2] = 0xbb67ae85
    H[3] = 0x3c6ef372
    H[4] = 0xa54ff53a
    H[5] = 0x510e527f
    H[6] = 0x9b05688c
    H[7] = 0x1f83d9ab
    H[8] = 0x5be0cd19
    return H
end
 
local function digestblock(msg, i, H)
    local w = {}
    for j = 1, 16 do w[j] = s232num(msg, i + (j - 1)*4) end
    for j = 17, 64 do
        local v = w[j - 15]
        local s0 = bxor(rrotate(v, 7), rrotate(v, 18), rshift(v, 3))
        v = w[j - 2]
        w[j] = w[j - 16] + s0 + w[j - 7] + bxor(rrotate(v, 17), rrotate(v, 19), rshift(v, 10))
    end
 
    local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
    for i = 1, 64 do
        local s0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
        local maj = bxor(band(a, b), band(a, c), band(b, c))
        local t2 = s0 + maj
        local s1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
        local ch = bxor (band(e, f), band(bnot(e), g))
        local t1 = h + s1 + ch + k[i] + w[i]
        h, g, f, e, d, c, b, a = g, f, e, d + t1, c, b, a, t1 + t2
    end
 
    H[1] = band(H[1] + a)
    H[2] = band(H[2] + b)
    H[3] = band(H[3] + c)
    H[4] = band(H[4] + d)
    H[5] = band(H[5] + e)
    H[6] = band(H[6] + f)
    H[7] = band(H[7] + g)
    H[8] = band(H[8] + h)
end
 
local function sha256(msg)
    msg = preproc(msg, #msg)
    local H = initH256({})
    for i = 1, #msg, 64 do digestblock(msg, i, H) end
    return str2hexa(num2s(H[1], 4) .. num2s(H[2], 4) .. num2s(H[3], 4) .. num2s(H[4], 4) ..
        num2s(H[5], 4) .. num2s(H[6], 4) .. num2s(H[7], 4) .. num2s(H[8], 4))
end


errorCode = "**ERROR_CODE_0001**"
accounts = {}
os.pullEvent = os.pullEventRaw
side2 = "bottom" -- Card Reader
proto = "CCU_DATA_RETRIEVAL"
side = "back" -- Modem

function reset()
    BTC = colors.lightGray
    BGC = colors.black
    TXC = colors.white
    TTC = colors.gray
end
reset()

rednet.open(side,true)
term.clear()
term.setCursorPos(1,1)

rednet.open(side,true)
term.clear()
term.setCursorPos(1,1)
function mainMenu()
    while true do
        clear()
        y2 = 8
        x2 = 10
        while y2 ~= 13 do
            while x2 ~= 20 do
                paintutils.drawPixel(x2,y2,BTC)
                x2 = x2+1
            end
            x2 = 10
            y2 = y2+1
        end
        y2 = 8
        x2 = 32
        while y2 ~= 13 do
            while x2 ~= 42 do
                paintutils.drawPixel(x2,y2,BTC)
                x2 = x2+1
            end
            x2 = 32
            y2 = y2+1
        end
        term.setCursorPos(13,10)
        print("CCU")
        term.setCursorPos(13,11)
        print("Card")
        term.setCursorPos(33,10)
        print("Account#")
        term.setCursorPos(34,11)
        print("& Pass")
        while true do
            local event,button,x1,y1 = os.pullEvent("mouse_click")
            if button==1 and x1 > 9 and x1 < 20 and y1 > 7 and y1 < 13 then
                clear()
                ifCard()
                break
            elseif button==1 and x1 > 31 and x1 < 42 and y1 > 7 and y1 < 13 then
                clear()
                ifPass()
                break
            end
        end
    end
end

function ifPass()
    clear()
    print("This feature has been disabled in preference for a safer and more secure login procedure.")
    sleep(3)
    clear()
end
   
function clear()
    term.setBackgroundColor(BGC)
    term.clear()
    paintutils.drawLine(1,1,51,1,TTC)
    term.setCursorPos(1,1)
    term.setTextColor(colors.yellow)
    print("CCU: Comfy Credit Union")
    paintutils.drawPixel(51,19,BGC)
    term.setTextColor(TXC)
    term.setCursorPos(1,2)
end
   
function ifCard()
    while true do
        if disk.isPresent(side2)==false then
            while disk.isPresent(side2)==false do
                clear()
                term.setCursorPos(1,2)
                print("Please Enter your CCU Banking Card.")
                sleep(1)
                clear()
                sleep(1)
            end
        elseif disk.isPresent(side2)==true then
            if fs.exists("disk/acc")==true then
                clear()
                print("Please enter the account you wish to access.")
                write("Account: ")
                AccNum = read()
                local salt
                for k1, v1 in pairs(fs.list("disk/acc")) do
                    if v1 == AccNum then
                        local file = fs.open("disk/acc/"..v1, "r")
                        salt, name = file.readLine(), file.readLine()
                        file.close()
                    end
                end
                if not salt then
                    print("Account Name Invalid")
                    return
                end
                clear()
                print("Please enter your password.")
                write("Password: ")
                pass = sha256(read("*")..salt)
                getAccData()
                if pass1 == errorCode then
                    clear()
                    print("Your card is not associated with any CCU Accounts.")
                    sleep(2)
                    clear()
                    print("Please take your card.")
                    disk.eject(side2)
                    sleep(2)
                    break
                elseif pass~=pass1 then
                    clear()
                    write("The password you entered didn't match the password associated with the account belonging to this banking card.")
                    sleep(2)
                    clear()
                    print("Please take your card.")
                    disk.eject(side2)
                    sleep(2)
                    break
                elseif pass==pass1 then
                    clear()
                    print("Welcome, "..name..".")
                    sleep(3)
                    bank()
                    reset()
                    break
                end
            else
                clear()
                print("The card you entered is not a registered CCU Banking Card.")
                sleep(2)
                clear()
                print("Please take your card.")
                disk.eject(side2)
                sleep(2)
                break
            end
        end
    end
end
   
function getAccData()
    rednet.broadcast(AccNum,proto)
    senderID, pass1 = rednet.receive(proto)
end
   
function bank()
    clear()
    print("Downloading Personalized GUI data...")
    print("Downloading Button Color...")
    rednet.broadcast("colorRequest",proto)
    sleep(.01)
    senderID, message = rednet.receive(proto)
    if message=="accNum" then
        rednet.broadcast(AccNum,proto)
        senderID, BTC = rednet.receive(proto)
        sleep(.01)
        print("Downloading Background Color...")
        rednet.broadcast("background",proto)
        senderID, BGC = rednet.receive(proto)
        sleep(.01)
        print("Downloading Text Color...")
        rednet.broadcast("text",proto)
        senderID, TXC = rednet.receive(proto)
        sleep(.01)
        print("Downloading Title Color...")
        rednet.broadcast("title",proto)
        sleep(.01)
        senderID, TTC = rednet.receive(proto)
        sleep(.01)
        clear()
    end
    while true do
        clear()
        print("Please select an option.")
        x2 = 2
        y2 = 4
        while y2 ~= 16 do
            paintutils.drawLine(x2,y2,(x2+1),y2,BTC)
            y2 = y2+3
        end
        paintutils.drawPixel(51,19,BGC)
        term.setCursorPos(5,4)
        print("Check Balance")
        term.setCursorPos(5,7)
        print("Deposit")
        term.setCursorPos(5,10)
        print("Withdraw")
        term.setCursorPos(5,13)
        print("Exit")
        local event, button, x1, y1 = os.pullEvent("mouse_click")
        if y1==4 then
            if x1==2 or x1==3 then
                bal()
            end
        elseif y1==7 then
            if x1==2 or x1==3 then
                deposit()
            end
        elseif y1==10 then
            if x1==2 or x1==3 then
                withdraw()
            end
        elseif y1==13 then
            if x1==2 or x1==3 then
                ex()
            break
            end
        else
            paintutils.drawPixel(51,19,BTC)
        end
    end
end

function bal()
    clear()
    rednet.broadcast("bal",proto)
    senderID, message = rednet.receive(proto)
    sleep(.01)
    rednet.broadcast(AccNum,proto)
    senderID, balance = rednet.receive(proto)
    print("Your current remaining balance is:")
    print("$"..balance)
    print("")
    print("Click anywhere to return.")
    os.pullEvent("mouse_click")
end

function outPay()
    bal()
end
   
function inPay()
    bal()
end
   
function deposit()
    clear()
    print("Please put your diamonds in the compartment above.")
    sleep(5)

    local barrel = peripheral.find("minecraft:barrel")
    local vault = peripheral.find("create:item_vault")

    local depositAmount = 0

    for slot, item in pairs(barrel.list()) do
        if item.name == "minecraft:diamond" then
            vault.pullItems(peripheral.getName(barrel), slot)
            depositAmount = depositAmount + item.count
        end
    end

    if depositAmount == 0 then
        print("No diamonds found.")
        sleep(3)
        clear()
    else
        clear()
        print("Preparing to make payment...")
        sleep(.02)
        rednet.broadcast("deposit",proto)
        print("Receiving startup confirmation...")
        senderID, message = rednet.receive(proto)
        sleep(.02)
        print("Sending deposit ammount...")
        rednet.broadcast(depositAmount,proto)
        print("Done!")
        sleep(3)
        clear()
    end
end

-- < 1729
function withdraw()
    clear()
    print("Please empty the compartment above.")
    sleep(5)

    local barrel = peripheral.find("minecraft:barrel")
    local vault = peripheral.find("create:item_vault")

    local withdrawAmount = 0

    for slot, item in pairs(barrel.list()) do
        if item.name == "minecraft:diamond" then
            vault.pullItems(peripheral.getName(barrel), slot)
            depositAmount = depositAmount + item.count
        end
    end

    if depositAmount == 0 then
        print("No diamonds found.")
        sleep(3)
        clear()
    else
        clear()
        print("Preparing to make payment...")
        sleep(.02)
        rednet.broadcast("deposit",proto)
        print("Receiving startup confirmation...")
        senderID, message = rednet.receive(proto)
        sleep(.02)
        print("Sending deposit ammount...")
        rednet.broadcast(depositAmount,proto)
        print("Done!")
        sleep(3)
        clear()
    end
end

function makePay()
    clear()
    print("Requesting information...")
    rednet.broadcast("reqAcc",proto)
    count = 0
    while message ~= "noFile" do
        count = count+1
        senderID, message = rednet.receive(proto)
        sleep(.01)
        accounts[count] = message
    end
    clear()
    print("Please enter one of the accounts below to deposit to.")
    print("")
    count = 0
    while account ~= "noFile" do
        count = count+1
        account = accounts[count]
        if account ~= "noFile" then
            print(account)
        end
    end
    print("")
    write("Pay to: ")
    inp = read()
    count = 0
    account = ""
    while account ~= "noFile" do
        count = count+1
        account = accounts[count]
        if inp==account then
            clear()
            print("How much would you like to deposit?")
            write("$")
            xDolla = read()
            xDolla = tonumber(xDolla)
            if xDolla==0 or xDolla < 0 then
                clear()
                print("That is an invalid transaction. You must deposite at least $.01.")
                sleep(3)
                clear()
            else
                clear()
                print("Retrieving information...")
                rednet.broadcast("bal",proto)
                senderID, balance = rednet.receive(proto)
                balance = tonumber(balance)
                sleep(2)
                clear()
                if xDolla > balance then
                    print("That is an invalid transaction. You have insufficient funds ("..balance..")")
                    sleep(3)
                    clear()
                else
                    clear()
                    print("Preparing to make payment...")
                    sleep(.02)
                    rednet.broadcast("makePayment",proto)
                    print("Receiving startup confirmation...")
                    senderID, message = rednet.receive(proto)
                    sleep(.02)
                    print("Sending account access request...")
                    rednet.broadcast(inp,proto)
                    print("Receiving continue confirmation...")
                    senderID, message = rednet.receive(proto)
                    sleep(.02)
                    print("Sending deposit ammount...")
                    rednet.broadcast(xDolla,proto)
                    print("Receiving continue confirmation...")
                    senderID, message = rednet.receive(proto)
                    sleep(.02)
                    print("Requesting Balance...")
                    rednet.broadcast("bal",proto)
                    print("Waiting for Balance...")
                    senderID, balance = rednet.receive(proto)
                    clear()
                    print("Transaction complete.")
                    print("Remaining Balance:")
                    print("$"..balance)
                    sleep(3)
                    clear()
                    break
                end
            end
        elseif inp=="cancel" then
            clear()
            break
        elseif inp~=account and account~="noFile" then
            clear()
        else
            clear()
            print("That account was not listed.")
            sleep(3)
            clear()
        end
    end
end
   
function pSet()
    while true do
        pSetClear()
        local event, button, x1, y1 = os.pullEvent("mouse_click")
        if y1==1 then
            TTC = TTC*2
            if TTC == 16 then
            TTC = TTC*2
            elseif TTC==65536 then
            TTC = 1
            end
        elseif y1 > 1 and y1 < 5 or y==5 and x1 < 16 or y==7 and x1 > 4 and x1 < 13 then
            TXC = TXC*2
            if TXC == BGC then
            TXC = TXC*2
            end
            if TXC == 65536 then
            TXC = 1
            end
        elseif y1==7 and x1 > 1 and x1 < 4 then
            BTC = BTC*2
            if BTC == BGC then
                BTC = BTC*2
            end
            if BTC == 65536 then
                BTC = 1
            end
        elseif y1==9 and x1 > 1 and x1 < 4 then
            clear()
            pSetSave()
            break
        else
            BGC = BGC*2
            while BGC==BTC or BGC==TXC do
            if BGC==BTC then
                BGC = BGC*2
            elseif BGC==TXC then
                BGC = BGC*2
            end
            if BGC==65536 then
                BGC = 1
            end
            end
            if BGC==65536 then
                BGC = 1
            end
        end
    end
end
   
function pSetClear()
    clear()
    print("Click anywhere on the screen to cycle through the colors to your prefered settings, then click the exit button. You can click on this text to change the text color.")
    paintutils.drawLine(2,7,3,7,BTC)
    paintutils.drawLine(2,9,3,9,BTC)
    paintutils.drawPixel(51,19,BGC)
    term.setCursorPos(5,7)
    print("<--Button")
    term.setCursorPos(5,9)
    print("Exit")
end
   
function pSetSave()
    clear()
    print("Preparing to save data...")
    rednet.broadcast("personalize",proto)
    senderID, message = rednet.receive(proto)
    sleep(.01)
    print("Saving Button Colors...")
    rednet.broadcast(BTC,proto)
    senderID, message = rednet.receive(proto)
    sleep(.01)
    print("Saving Background Colors...")
    rednet.broadcast(BGC,proto)
    senderID, message = rednet.receive(proto)
    sleep(.01)
    print("Saving Text Colors...")
    rednet.broadcast(TXC,proto)
    senderID, message = rednet.receive(proto)
    sleep(.01)
    print("Saving Titlebar Colors...")
    rednet.broadcast(TTC,proto)
    senderID, message = rednet.receive(proto)
    clear()
end
   
function ex()
    reset()
    clear()
    disk.eject("bottom")
end
   
mainMenu()
  