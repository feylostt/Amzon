proto = "CCU_DATA_RETRIEVAL"
side = "top"
rednet.open(side,true)
function clear()
    term.clear()
    term.setCursorPos(1,1)
end

while true do
    sleep(.01)
    clear()
    print("Recieving Data")
    senderID, opt = rednet.receive(proto)
    sleep(.01)
    if opt=="colorRequest" then
        clear()
        print("Requesting ACCNUM")
        rednet.broadcast("accNum",proto)
        senderID, acc = rednet.receive(proto)
        sleep(.01)
        print("Opening acc/"..acc.."/COLORS")
        f = fs.open("acc/"..acc.."/COLORS","r")
        BTC = tonumber(f.readLine())
        BGC = tonumber(f.readLine())
        TXC = tonumber(f.readLine())
        TTC = tonumber(f.readLine())
        f.close()
        print("Giving BTC: "..BTC)
        rednet.broadcast(BTC,proto)
        senderID, message = rednet.receive(proto)
        print("Giving BGC: "..BGC)
        sleep(.01)
        rednet.broadcast(BGC,proto)
        senderID, message = rednet.receive(proto)
        print("Giving TXC: "..TXC)
        sleep(.01)
        rednet.broadcast(TXC,proto)
        senderID, message = rednet.receive(proto)
        print("Giving TTC: "..TTC)
        sleep(.01)
        rednet.broadcast(TTC,proto)
    elseif opt=="bal" then
        rednet.broadcast("acc req", proto)
        senderID, acc = rednet.receive(proto)
        f = fs.open("acc/"..acc.."/BALANCE","r")
        bal = f.readLine()
        f.close()
        rednet.broadcast(bal,proto)
        sleep(.01)
    elseif opt=="reqAcc" then
        local FileList = fs.list("acc")
        for _, file in ipairs(FileList) do
            rednet.broadcast(file,proto)
            sleep(.03)
        end
        rednet.broadcast("noFile",proto)
    elseif opt == "deposit" then
        sleep(0.2)
        clear()
        print("Ready")
        rednet.broadcast("ready", proto)
        print("Receiving depto information")
        senderID, depTo = rednet.receive(proto)
        sleep(.01)
        rednet.broadcast("ready",proto)
        print("Receiving deposit information")
        senderID, depAmount = rednet.receive(proto)

        f = fs.open("acc/"..depTo.."/BALANCE", "r")
        preDeposit = tonumber(f.readline())
        f.close()
        print("Calculating deposit")
        
        deposited = preDeposit + depAmount

        print("Applying deposit to "..depTo)
        f = fs.open("acc/"..depTo.."/BALANCE","w")
        f.writeLine(deposited)
        f.close()
        clear()
        
    elseif opt=="makePayment" then
        sleep(.02)
        clear()
        print("Ready")
        rednet.broadcast("ready",proto)
        print("Receiving payto information")
        senderID, payTo = rednet.receive(proto)
        sleep(.01)
        rednet.broadcast("ready",proto)
        print("Receiving payfrom information")
        senderID, pay = rednet.receive(proto)
        sleep(.01)
        rednet.broadcast("ready",proto)
        print("Getting payto balance.")
        f = fs.open("acc/"..payTo.."/BALANCE","r")
        prePayTo = tonumber(f.readLine())
        f.close()
        print("Getting payfrom balance")
        f = fs.open("acc/"..acc.."/BALANCE","r")
        prePay = tonumber(f.readLine())
        f.close()
        print("Calculating Payment")
        if payTo==acc then
            print("Same Account; no change made.")
            payedTo = prePayTo
            payedFro = prePay
        else
            payedTo = prePayTo + pay
            payedFro = prePay - pay
        end
        print("Applying withdraw from "..acc)
        f = fs.open("acc/"..acc.."/BALANCE","w")
        f.writeLine(payedFro)
        f.close()
        print("Applying deposit to "..payTo)
        f = fs.open("acc/"..payTo.."/BALANCE","w")
        f.writeLine(payedTo)
        f.close()
        clear()
    elseif opt=="personalize" then
        print("Ready")
        sleep(.01)
        rednet.broadcast("ready",proto)
        senderID, BTC = rednet.receive(proto)
        sleep(.01)
        rednet.broadcast("ready",proto)
        senderID, BGC = rednet.receive(proto)
        sleep(.01)
        rednet.broadcast("ready",proto)
        senderID, TXC = rednet.receive(proto)
        sleep(.01)
        rednet.broadcast("ready",proto)
        senderID, TTC = rednet.receive(proto)
        f = fs.open("acc/"..acc.."/COLORS","w")
        f.writeLine(BTC)
        f.writeLine(BGC)
        f.writeLine(TXC)
        f.writeLine(TTC)
        f.close()
        rednet.broadcast("saved",proto)
    elseif opt=="newAcc" then
        rednet.broadcast("accNum Req",proto)
        senderID, newAccNum = rednet.receive(proto)
        sleep(.01)
        if fs.isDir("acc/"..tostring(newAccNum)) == true then
            rednet.broadcast("ERROR",proto)
        else
            rednet.broadcast("pass Req",proto)
            senderID, newAccPass = rednet.receive(proto)
            sleep(.01)
            fs.makeDir("acc/"..tostring(newAccNum))
            file = fs.open("acc/"..tostring(newAccNum).."/BALANCE","w")
            file.writeLine(0)
            file.close()
            file = fs.open("acc/"..tostring(newAccNum).."/COLORS","w")
            file.writeLine(colors.white)
            file.writeLine(colors.black)
            file.writeLine(colors.white)
            file.writeLine(colors.white)
            file.close()
            file = fs.open("acc/"..tostring(newAccNum).."/PASS","w")
            file.writeLine(tostring(newAccPass))
            file.close()
            rednet.broadcast("finished",proto)
        end
    elseif opt=="noOpt" then
        clear()
    else
        if fs.exists("acc/"..opt) then
            f = fs.open("acc/"..opt.."/PASS","r")
            pass = tostring(f.readLine())
            f.close()
            clear()
            print("Sending password")
            rednet.broadcast(pass,proto)
        else
            clear()
            print("Sending EC0001")
            rednet.broadcast("**ERROR_CODE_0001**",proto)
        end
    end
end