# Websocket communication protocol for ISK
ISK uses websockets to communicate between the server and various clients. This is used to update the html views for users and the presentation data on displays.

## Endpoints
There are two kinds of websocket endpoints, one for the interface between the server and slideshow displays and another for users.

### Display interface
The display interface is located at url /displays/:id/websocket where :id is the numeric id of the display. This connection will send updated display serializations as needed, receives updates from the display and handles the communication between the display remote control view and the display.

#### Message format
The messages for updated display serializations will be in this json serialized format:
```JSON
[
	"display",
	"data",
	{"id": 1}
]
```
where the first two fields are constant and the third and final field contains a hash of the serialized display data.

#### Commands
Commands are sent with a json serialized message in the following format
```JSON
[
	"command",
	#command_name,
	{"arg_1":1}
]
```
The #command_name-string is the name of the command and the hash contains the command specific parameters.

Results are returned in the same format with the hash containing the command specific results.

The supported commands are
* get_data, replies with the display serialization, no arguments
* goto_slide, instructs the display to change to a certain slide
* current_slide, display tells what slide it is currently showing
* slide_shown, display tells that a slide has been shown (for updating the override queue mostly) 
* shutdown, display tells that it is performing a requested shutdown
* error, display informs the server that a error has occured
* start, display tells the server that it is starting
* ping, replies with ['display', 'pong', payload] echoing the same payload as received

### General notification interface
The second websocket endpoint is at /isk-general and it is used for updating all html views for users when the various objects are updated.

### Message format
The messages are json serialized arrays. Their content is as follows:

```JSON
[
	"object",
	"message_type",
	{"key":1}
]
```

Where first element "object" is the class of object that this message is about and it is one of the following:
* display
* displaystate
* group
* master_group
* override_queue
* presentation
* slide
* ticket

The next element is the type of the action that triggered the message. It is one of the following:
* create, the object was created
* update, the object was updated somehow
* destroy, the object was deleted
* updated_image, the image associated with the object was updated

The last field is a hash representing the object that triggered the message. It will contain at least the key 'id' that contains the database id of the object. More comprehensive documentation of the different serializations TBW.

### Commands
The general endpoint supports two commands that generate svg previews. The commands are invoked by sending a message in the following format:
```JSON
[
	"command",
	#command_name
	{"data": value}
]
```
The second element of the array is the name of the command ("simple" or "template"). Last element is a hash of all the command specific parameters.

#### "simple" command

This command generates a svg preview for the simple editor. The command is
```JSON
[
	"command",
	"simple_svg"
	{
		"heading": "Slide heading",
		"text": "Slide contents\n<with highlight>",
		"text_size": 80,
		"text_aling": "left",
		"color": "red"
	}
]
```
If the command is successfull the server will respond by sending the following message back:
```JSON
[
	"simple",
	"svg",
	SVG_DATA
]
```
the SVG_DATA is the whole svg DOM as one string.

#### "template" command

This command is for updating the svg preview when editing template slides. The format of the command is
```JSON
[
	"command",
	"template_svg",
	{
		"template_id": 1,
		"field_id1": "contents",
		"field_id2": "contents2"
	}
]
```
Where template_id is the database id number of the template to use and the "field_id": "value" pairs are template specific text field identifiers and contents. The server will reply with:
```JSON
[
	"template",
	"svg",
	SVG_DATA
]
```
Where SVG_DATA is the generated SVG DOM as a single string.