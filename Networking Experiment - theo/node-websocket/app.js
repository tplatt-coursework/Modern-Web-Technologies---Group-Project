const net = require('net');

const server = net.createServer(socket => {
  console.log('Client connected');

  socket.on('data', data => {
    try{
      console.log('Received:', JSON.parse(data));

      let buffer = {
        code:200,
        response:JSON.parse(data)
      }

      let payload = JSON.stringify(buffer)
      socket.write(payload);

    }catch(e){
      console.error(e)

      let boffer = {
        code:400,
        response:"Internal Server Error", 
      }

      let payload = JSON.stringify(boffer)
      socket.write(payload);
    }
  });

  socket.on('close', () => {
    console.log('Client disconnected');
  });

  socket.on('error', err => {
    console.error('Socket error:', err);
  });
});

server.listen(3500, () => {
  console.log('Server listening on port 3500');
});