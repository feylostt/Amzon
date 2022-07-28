-- Ender Modem
local side = "back"
rednet.open(side)

-- Version
local v = "1.0"

-- Password Hash
os.loadAPI("hash")

-- Server's Computer ID (Change this!!)
local serverID = 9

-- Screen Size
x, y = term.getSize()

-- Print/Write centered text
function printCentered(text, yPos)
    xPos = math.ceil((x/2)-(string.len(text)/2))
    term.setCursorPos(xPos, yPos)
    print(text)
end

function writeCentered(text, yPos)
    xPos = math.ceil((x/2)-(string.len(text)/2))
    term.setCursorPos(xPos, yPos)
    write(text)
end

-- Send Data to Server
function send(info)
    rednet.send(serverID, info)
end

-- Logged in banking
function bank(account, pin)
    term.setBackgroundColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)

    print("Comfy Credit Union")

    printCentered("Choose an Option")
    printCentered("[1] Deposit")
    printCentered("[2] Withdraw")
    printCentered("[3] Check Balance")
    printCentered("[4] Log Out")

    writeCentered("Option: ")
    op = read()
end

-- Login to bank
function bankLogin(account, pin)
    pinHash = hash.hashPassword(pin)

    send(textutils.serialise(account))
    send(textutils.serialize(pinHash))

    id, msg = rednet.receive(10)
    if id == serverID then
        if msg == "crct" then
            bank(account, pin)
        else
            print("WRONG ACCOUNT OR PIN")
            sleep(1)
            begin()
        end
    else
        print("ERROR, PLEASE TRY AGAIN")
        sleep(1)
        begin()
    end
end

-- Start
function begin()
    term.setBackgroundColor(colors.blue)
    term.clear()
    term.setCursorPos(1,1)
    term.setTextColor(colors.black)
    print("Comfy Credit Union")
    term.setCursorPos(1,4)
    print("Enter User # and PIN")
    write("Account #")
    acc = read()
    write("PIN: ")
    pin = read("*")
    bankLogin(acc, pin)
end
 
while true do
    begin()
end
