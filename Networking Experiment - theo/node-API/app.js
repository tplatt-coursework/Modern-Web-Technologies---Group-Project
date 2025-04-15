let express = require('express')
let app = express()
const port = 3500


// Middleware
app.use(express.urlencoded({ extended: true }))
app.use(express.json())


// 
app.get("/GET", function(req, res){
    try{
        let response = {
            "msg":"Responding to /POST",
            "payload": {"bax":"qud"},
            "foo":"bar"
        }
        res.status(200).send(response)
        console.log("/GET: 200")
    }catch(e){
        console.error(`Error: ${e}`)
        res.status(500).send('Internal Server Error')
        console.log("/GET: 500")
    }
})

app.post('/POST', function(req, res){
    try{
        let response = {
            "msg":"Responding to /POST",
            "payload": {"nested":"json"},
            "foo":"bar"
        }
        res.status(200).send(response)
        console.log("/POST: 200")
    }catch(e){
        console.error(`Error: ${e}`)
        res.status(500).send('Internal Server Error')
        console.log("/POST: 500")
    }
})

app.listen(port, function() {
  console.log("App listening on port " + port + "!")
})
