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
app.ws('/',(ws,req)=>{
    

    // console.log("FooBar")
    // ws.on('connection',ws => {
    ws.id = getUniqueID();
    while(clients[ws.id] != undefined){
        ws.id = getUniqueID();
    }
    clients[ws.id]=ws
    console.log(`Client Connected, id=${ws.id}`)

    let on_connect = {
        code:200,
        source:"ID Assigner",
        response:ws.id
    }
    ws.send(JSON.stringify(on_connect))

    ws.on('message',data=>{
        try{
            let message = data.toString('utf-8')           

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
                response:""
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
        console.log('Client disconnected:',ws.id)
        delete clients[ws.id]
    })

    ws.onerror = error => {
        console.error('WebSocket error:', error)
    }
    // })
})



app.use(express.static(path.join(__dirname, 'game_export')));
app.listen(PORT, function () {
    console.log(`WebSocket server started on port ${PORT}`)
})