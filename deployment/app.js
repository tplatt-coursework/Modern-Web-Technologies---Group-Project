const express = require('express')
const expressWs = require('express-ws')
const path = require('path');
const PORT = 3500
var app = express()
expressWs(app)


// const wss = new WebSocket.Server({port:PORT})

//https://stackoverflow.com/questions/13364243/websocketserver-node-js-how-to-differentiate-clients



// get /
// app.get('/', (req, res) => {
//     res.sendFile(require('./foo.html'))
//     res.end()
// })

getUniqueID = function () {
    function s4() {
        return Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(1);
    }
    return s4() + s4() + '-' + s4();
};
const clients = {}

// Track disconnected clients for a period of time
const disconnectedClients = {};
// Increase reconnection timeframe to 30 minutes (30 * 60 * 1000)
const DISCONNECTED_CLIENT_TIMEOUT = 30 * 60 * 1000;

app.ws('/ws',(ws,req)=>{
    
    // Check if this is a reconnection of a previously disconnected client
    let reconnectedClientId = null;
    for (const [id, info] of Object.entries(disconnectedClients)) {
        // If the IP address matches, this might be a reconnection
        if (info.ip === req.ip) {
            reconnectedClientId = id;
            console.log(`Possible reconnection from IP ${req.ip}, using previous ID: ${reconnectedClientId}`);
            delete disconnectedClients[id];
            break;
        }
    }
    
    ws.id = reconnectedClientId || getUniqueID();
    while(clients[ws.id] != undefined){
        ws.id = getUniqueID();
    }
    clients[ws.id] = ws;
    ws.connectionInfo = {
        ip: req.ip,
        connectedAt: new Date(),
        lastActive: new Date()
    };
    
    console.log(`Client Connected, id=${ws.id}, ip=${req.ip}`)

    let on_connect = {
        code: 200,
        source: "ID Assigner",
        response: JSON.stringify(ws.id)  // Stringify the ID to ensure it's valid JSON
    }
    ws.send(JSON.stringify(on_connect))

    // Announce new client to all existing clients
    console.log(`Announcing new client ${ws.id} to all existing clients. Total clients: ${Object.keys(clients).length}`)
    
    // Send list of existing clients to the new client
    for(const [id,socket] of Object.entries(clients)){
        if(id != ws.id){
            // Tell existing clients about the new client
            let announceToExisting = {
                code:201,
                source:ws.id,
                response:JSON.stringify({
                    note:"User Present",
                    content:ws.id
                })
            }
            socket.send(JSON.stringify(announceToExisting));
            
            // Tell the new client about existing clients
            let announceToNew = {
                code:201,
                source:id,
                response:JSON.stringify({
                    note:"User Present",
                    content:id
                })
            }
            ws.send(JSON.stringify(announceToNew));
            
            console.log(`Cross-announced clients ${ws.id} and ${id}`)
        }
    }
    
    // Also tell the new client about recently disconnected clients
    for(const [id, info] of Object.entries(disconnectedClients)){
        // Include recently disconnected clients (< 30 minutes ago)
        const disconnectedTime = new Date(info.disconnectedAt);
        const cutoffTime = new Date(Date.now() - DISCONNECTED_CLIENT_TIMEOUT);
        
        if (disconnectedTime > cutoffTime) {
            let announceDisconnected = {
                code:201,
                source:id,
                response:JSON.stringify({
                    note:"User Present",
                    content:id
                })
            }
            ws.send(JSON.stringify(announceDisconnected));
            console.log(`Informed new client ${ws.id} about recently disconnected client ${id}`);
        }
    }

    // Set up a keep-alive interval to ping this client
    ws.keepAliveInterval = setInterval(() => {
        // Only send if the connection is open
        if (ws.readyState === 1) { // WebSocket.OPEN = 1
            try {
                let keepAlive = {
                    code: 200,
                    source: "KeepAlive",
                    response: "ping"
                };
                ws.send(JSON.stringify(keepAlive));
                
                // Also notify other clients this user is still present
                for(const [id,socket] of Object.entries(clients)){
                    if(id != ws.id && socket.readyState === 1){
                        let stillPresent = {
                            code: 201,
                            source: ws.id,
                            response: JSON.stringify({
                                note: "User Present",
                                content: ws.id
                            })
                        };
                        socket.send(JSON.stringify(stillPresent));
                    }
                }
            } catch (e) {
                console.error(`Error sending keep-alive to ${ws.id}:`, e);
                clearInterval(ws.keepAliveInterval);
            }
        } else {
            // Connection is not open, clear the interval
            console.log(`Clearing keep-alive for disconnected client ${ws.id}`);
            clearInterval(ws.keepAliveInterval);
        }
    }, 15000); // Every 15 seconds

    ws.on('message',data=>{
        try{
            let message = data.toString('utf-8')
            // Update last active timestamp
            ws.connectionInfo.lastActive = new Date();
            
            let parsedMsg;
            try {
                parsedMsg = JSON.parse(message);
                //console.log(`Received message from ${ws.id}:`, parsedMsg.note);
            } catch (e) {
                console.error("Failed to parse message:", message);
            }

            for(const [id,socket] of Object.entries(clients)){
                if(id != ws.id){
                    let buffer = {
                        code:201,
                        source:ws.id,
                        response:message
                    }
        
                    let payload = JSON.stringify(buffer)
                    socket.send(payload);
                }
            }

            let buffer = {
                code:100,
                source:ws.id,
                response:JSON.stringify({note: "Acknowledged"})
            }

            let payload = JSON.stringify(buffer)
            ws.send(payload);
        }catch(e){
            console.group(`message from ${ws.id}`)

            console.group("packet:")
            console.log(data);
            console.groupEnd()

            console.group('Error:')
            console.error(e)
            console.groupEnd()

            console.groupEnd()
    
            let boffer = {
            code:500,
            response:"Internal Server Error", 
            }
    
            let payload = JSON.stringify(boffer)
            ws.send(payload);
        }

    })
    
    ws.on('close', () => {
        console.log('Client disconnected:', ws.id)
        
        // Clear the keep-alive interval
        if (ws.keepAliveInterval) {
            clearInterval(ws.keepAliveInterval);
        }
        
        // Don't immediately delete the client - store it as disconnected
        if (ws.connectionInfo) {
            disconnectedClients[ws.id] = {
                ip: ws.connectionInfo.ip,
                disconnectedAt: new Date(),
                wasConnectedFor: (new Date() - ws.connectionInfo.connectedAt) / 1000
            };
            console.log(`Stored disconnected client ${ws.id} for potential reconnection`);
            
            // Schedule cleanup after 30 minutes
            setTimeout(() => {
                if (disconnectedClients[ws.id]) {
                    console.log(`Removing disconnected client ${ws.id} after timeout`);
                    delete disconnectedClients[ws.id];
                }
            }, DISCONNECTED_CLIENT_TIMEOUT);
        }
        
        delete clients[ws.id]
    })

    ws.onerror = error => {
        console.error('WebSocket error:', error)
    }
})



app.use(express.static(path.join(__dirname, 'game_export')));
app.listen(PORT, function () {
    console.log(`WebSocket server started on port ${PORT}`)
})
