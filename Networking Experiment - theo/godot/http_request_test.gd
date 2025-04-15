extends Node


var server_address = "http://127.0.0.1"
var server_port = 3500
var addr = server_address + ":" + str(server_port)

func _ready():
	pass




# Called when the HTTP request is completed.
func _http_request_completed(result, response_code, headers, body):
	var json = JSON.new()
	json.parse(body.get_string_from_utf8())
	var response = json.get_data()
	
	# Will print the user agent string used by the HTTPRequest node (as recognized by httpbin.org).
	print("Response from server:")
	print(" |  result:   "+str(result))
	print(" |  code:     "+str(response_code))
	print(" |  headers:  "+str(headers))
	print(" |  body:     "+str(body))
	print(" |  response: "+str(response))





func http_get(req:String,params):
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(self._http_request_completed)
	print("HTTP Request: "+addr+req+"")
	var res = await http_request.request(addr+req, ["Content-Type: application/json"], HTTPClient.METHOD_GET)
	if res != OK:
		push_error("An error occurred in the HTTP request.")

func http_post(req:String,_body):
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(self._http_request_completed)
	print("HTTP Request: "+addr+req+"")
	var body = JSON.new().stringify(_body)
	var res = await http_request.request(addr+req, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if res != OK:
		push_error("An error occurred in the HTTP request.")





func _on_post_button_pressed():
	http_post("/POST", {"foo":"bar"})

func _on_get_button_pressed():
	http_get("/GET","")
