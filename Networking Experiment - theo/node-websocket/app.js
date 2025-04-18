const WebSocket = require('ws')
const PORT = 3500
const wss = new WebSocket.Server({port:PORT})

//https://stackoverflow.com/questions/13364243/websocketserver-node-js-how-to-differentiate-clients
wss.getUniqueID = function () {
    function s4() {
        return Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(1);
    }
    return s4() + s4() + '-' + s4();
};

wss.on('connection',ws => {
    ws.id = wss.getUniqueID();
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
            // console.group(`message from ${ws.id}`)
            // console.group("packet:")
            // console.log(data);
            // console.groupEnd()
            // console.group('string:')
            // console.log(message)
            // console.groupEnd()
            // console.groupEnd()
            

            wss.clients.forEach(function each(client) {
                if(client.id != ws.id){
                    let buffer = {
                        code:201,
                        source:ws.id,
                        response:message
                    }
          
                    let payload = JSON.stringify(buffer)
                    client.send(payload);
                    // console.log("Sent payload to ",client.id)
                }
            })

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
    })

    ws.onerror = error => {
        console.error('WebSocket error:', error)
    }
})

console.log(`WebSocket server started on port ${PORT}`)