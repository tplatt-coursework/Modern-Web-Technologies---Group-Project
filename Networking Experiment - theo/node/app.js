const net = require('net');

const server = net.createServer(socket => {
  console.log('Client connected');

  socket.on('data', data => {
    console.log('Received:', data.toString());
    let msg = JSON.stringify({type: "server_message", command:"update_button", data: data.toString()})
    console.log("msg: "+msg)
    socket.write(msg);
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