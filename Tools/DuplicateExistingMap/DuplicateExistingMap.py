###
#   DuplicateExistingMap Tool
#
#   This script is used to duplicate a warzone's maps data.
#
#   It takes the game id from a multiplayer game made using an old map 
#   & downloads what it can about the map from the query game api.
#   Tip: create a multiplayer game with code invites. This lets you do it with one person.
#
#   It subsequently parses that data, creates commands and posts those commands
#   to the mapmaking api using the id of the new map.
#
#   It is important that the svg uploaded for the duplicate map is the same as the old
#
#   To do these things it requires the authorization parameters. The users email and apiToken
#
###


import requests
from typing import List
from json import dumps
from abc import ABC
from tkinter import *
from tkinter import ttk
from tkinter import messagebox
from traceback import format_exc
from webbrowser import open_new_tab

## Classes from the QueryGame API: https://www.warzone.com/wiki/Query_game_API
class QueryGameTerritory:
    connectedTo: List[int]
    name: str
    coords: str
    id: str

    def __init__(self, name, id, connectedTo, coords):
        self.name = name
        self.id = id
        self.connectedTo = connectedTo
        self.coords = coords

class QueryGameBonus:
    territoryIDs: List[int]
    name: str
    value: str
    id: str

    def __init__(self, id, name, value, territoryIDs):
        self.name = name
        self.id = id
        self.value = value
        self.territoryIDs = territoryIDs

## Classes from the Set Map Details API: https://www.warzone.com/wiki/Set_map_details_API

class Command(ABC):
    command = ""

    def to_JSON(self):
        return dumps(self, default = lambda o: o.__dict__, sort_keys=True, indent=4)
    
    def validate(self):
        pass

    def get_error_string(self, field):
        return f"Invalid {field} for Command {self.command}: {self.to_JSON()}"


class WarzoneSetDetailsPostRequestModel:
    email: str
    APIToken: str
    mapID: int
    commands = List[Command]

    def __init__(self, email, APIToken, mapID, commands):
        self.email = email
        self.APIToken = APIToken
        self.mapID = int(mapID)
        self.commands = commands
    
    def to_JSON(self):
        return dumps(self, default = lambda o: o.__dict__, indent = 4)

class SetTerritoryNameCommand(Command):
    id: int
    name: str

    def __init__(self, id, territoryName):
        self.command = "setTerritoryName"
        self.id = int(id)
        self.name = territoryName

    def validate(self):
        errors = []
        if(self.id == None):
            errors.append(self.get_error_string("id"))
        if(self.name == None or self.name == ""):
            errors.append(self.get_error_string("name"))
        
        if(len(errors)>0):
            return errors

class SetTerritoryCenterpointCommand(Command):
    id: int
    x: str
    y: str

    def __init__(self, id, x, y):
        self.command = "setTerritoryCenterPoint"
        self.id = int(id)
        self.x = str(x)
        self.y = str(y)

    def validate(self):
        errors = []
        if(self.id == None):
            errors.append(self.get_error_string("id"))
        if(self.x == None or self.x == ""):
            errors.append(self.get_error_string("x"))
        if(self.y == None or self.y == ""):
            errors.append(self.get_error_string("y"))
        
        if(len(errors)>0):
            return errors

class AddBonusCommand(Command):
    name: str
    armies: int
    color: str

    def __init__(self, bonusName, armies, color = "#000000"):
        self.command = "addBonus"
        self.name = bonusName
        self.armies = int(armies)
        self.color = color

    def validate(self):
        errors = []
        if(self.armies == None):
            errors.append(self.get_error_string("armies"))
        if(self.name == None or self.name == ""):
            errors.append(self.get_error_string("name"))
        if(self.color == None or self.color == "" or len(self.color)!=7):
            errors.append(self.get_error_string("color"))
        
        if(len(errors)>0):
            return errors

class AddTerritoryToBonusCommand(Command):
    id: int
    bonusName: str

    def __init__(self, territoryId, bonusName):
        self.command = "addTerritoryToBonus"
        self.id = int(territoryId)
        self.bonusName = bonusName
    
    def validate(self):
        errors = []
        if(self.id == None):
            errors.append(self.get_error_string("id"))
        if(self.bonusName == None or self.bonusName == ""):
            errors.append(self.get_error_string("bonusName"))
        
        if(len(errors)>0):
            return errors

class AddTerritoryConnectionCommand(Command):
    id1: int
    id2: int
    wrap: str

    def __init__(self, territoryId, territoryId2, wrap = "Normal"):
        self.command = "addTerritoryConnection"
        self.wrap = wrap
        self.id1 = int(territoryId)
        self.id2 = int(territoryId2)
    
    def validate(self):
        errors = []
        if(self.id1 == None):
            errors.append(self.get_error_string("id1"))
        if(self.id2 == None):
            errors.append(self.get_error_string("id2"))
        if(self.wrap == None or self.wrap == ""):
            errors.append(self.get_error_string("wrap"))
        if(self.wrap != "Normal" and self.wrap != "WrapHorizontally" and self.wrap != "WrapVertically"):
            errors.append(f"Invalid wrap for Command {self.command}. Only Normal, WrapHorizontally, WrapVertically supported by Warzone: {self.to_JSON()}")
        
        if(len(errors)>0):
            return errors

## initiate gui
root = Tk()

## Functions

def GetMap(gameId: int, email: str, apiToken: str) -> str:
    response = requests.get(f'https://www.warzone.com/API/GameFeed?GameID={gameId}&Email={email}&APIToken={apiToken}')
    return response.json()

def ParseResponseForUploadables(mapJson: str):

    # territories
    territoriesJson = mapJson["territories"]
    territories: List[QueryGameTerritory] = []
    for territoryJson in territoriesJson:
        territories.append(QueryGameTerritory(**territoryJson))

    # bonuses
    bonusesJson = mapJson["bonuses"]
    bonuses: List[QueryGameBonus] = []
    for bonusJson in bonusesJson:
        bonuses.append(QueryGameBonus(**bonusJson))

    return territories, bonuses

# Hashing function
def CantorPairingFunction(a: int, b: int) -> int:
    # can't trust these are REAL numbers
    intA = int(a)
    intB = int(b)
    return (intA + intB) * (intA + intB + 1) / 2 + intA

def ConvertClassesToCommands(territories: List[QueryGameTerritory], bonuses: List[QueryGameBonus]) -> List[Command]: 
    commands: List[Command] = []

    # non-idempotent commands!
    addBonusCommands: List[AddBonusCommand] = []
    addTerritoryToBonusCommands: List[AddTerritoryToBonusCommand] = []
    addTerritoryConnectionCommands: List[AddTerritoryConnectionCommand] = []

    # idempotent commands
    setTerritoryNameCommands: List[SetTerritoryNameCommand] = []
    setTerritoryCenterpointCommands: List[SetTerritoryCenterpointCommand] = []

    connectionHashes: List[int] = []

    for bonus in bonuses:
        addBonusCommand = AddBonusCommand(bonus.name, bonus.value) # must discard existing bonus id
        addBonusCommands.append(addBonusCommand)

        for territoryId in bonus.territoryIDs:
            addTerritoryToBonusCommand = AddTerritoryToBonusCommand(territoryId, bonus.name)
            addTerritoryToBonusCommands.append(addTerritoryToBonusCommand)

    for territory in territories:
        setTerritoryNameCommand = SetTerritoryNameCommand(territory.id, territory.name)
        setTerritoryNameCommands.append(setTerritoryNameCommand)
        
        x,y = territory.coords.split(",")
        setTerritoryCenterpointCommand = SetTerritoryCenterpointCommand(territory.id, x, y)
        setTerritoryCenterpointCommands.append(setTerritoryCenterpointCommand)

        for connectionId in territory.connectedTo:
            hash = CantorPairingFunction(territory.id, connectionId)

            if(hash in connectionHashes):
                continue

            addTerritoryConnectionCommand = AddTerritoryConnectionCommand(territory.id, connectionId)
            addTerritoryConnectionCommands.append(addTerritoryConnectionCommand)
            connectionHashes.append(hash)

    # addBonusCommands first as can't add territories to non-existant bonuses
    commands = addBonusCommands + addTerritoryToBonusCommands + addTerritoryConnectionCommands + setTerritoryNameCommands + setTerritoryCenterpointCommands
    return commands

def UploadMap(email: str, token: str, mapId: int, commands: List[Command]) -> str:
    model = WarzoneSetDetailsPostRequestModel(email, token, mapId, commands)
    
    json_string = model.to_JSON()

    response = requests.post(
        url= 'https://www.warzone.com/API/SetMapDetails',
        data = json_string)
    
    responseJson = response.json()
    error = responseJson.get('error', None)

    # return json_string
    return error

def DuplicateMap(oldMapGameId: int, newMapId: int, email: str, apiKey: str):
    #get map
    mapJson = None
    try:
        jsonData = GetMap(oldMapGameId, email, apiKey)

        error = jsonData['error'] if 'error' in jsonData else None
        if error != None:
            messagebox.showerror("Error from warzone query game API", error)
            exit()

        mapJson = jsonData['map']
    except Exception:
        messagebox.showerror("An exception occurred while retrieving the old map", format_exc())
        exit()

    #parse map
    commands = []
    try:
        territories, bonuses = ParseResponseForUploadables(mapJson)
        commands = ConvertClassesToCommands(territories, bonuses)
    except Exception:
        show_terminating_popup("An exception occurred while parsing the old map", format_exc())
        exit()

    # validate commands
    errors = []
    for command in commands:
        error = command.validate()
        if(error is not None):
            errors.append(command.validate(error))
    if(len(errors)):
        show_terminating_popup("Errors detected while validating commands", errors)

    # upload map
    try:
        error = UploadMap(email, apiKey, newMapId, commands)
        if error != None:
            show_terminating_popup("Error from warzone upload map details API", error)
    except Exception:
        show_terminating_popup("An exception occurred while uploading the new map details", format_exc())


def DuplicateMapWrapper(oldMapGameId: int, newMapId: int, email: str, apiKey: str) -> None:

    if oldMapGameId == '':
        messagebox.showerror('Error', 'Missing old map game id')
        return
    if newMapId == '':
        messagebox.showerror('Error', 'Missing new map id')
        return
    if email == '':
        messagebox.showerror('Error', 'Missing email')
        return
    if apiKey == '':
        messagebox.showerror('Error', 'Missing api key')
        return
    
    try:
        DuplicateMap(oldMapGameId, newMapId, email, apiKey)
        SuccessWindow(newMapId)
    except Exception:
        show_terminating_popup("An exception occurred", format_exc())

def callback(url):
   open_new_tab(url)
   
def SuccessWindow(newMapId: str):
    toplevel = Toplevel(root)

    toplevel.title("Success")
    toplevel.geometry("230x80")

    l1=Label(toplevel, image="::tk::icons::information")
    l1.grid(row=0, column=0)

    left_label = Label(toplevel, text=f'Check out your map', cursor="hand2", relief='raised', foreground='blue')#text= "Left-bottom")
    left_label.grid(row=0, column=1)
    left_label.bind("<Button-1>", lambda e:callback(f'https://www.warzone.com/SinglePlayer?PreviewMap={newMapId}'))

def show_terminating_popup(title: str, message: str):
    popup = Toplevel(root)
    popup.title("Message")

    # Make the window not resizable
    popup.resizable(False, False)

    # Add a label
    label = ttk.Label(popup, text=title)
    label.pack(pady=5)

    # Add a Text widget so the user can copy from it
    text_box = Text(popup, wrap="word", height=40, width=50)
    text_box.insert("1.0", message)
    text_box.configure(state="normal")  # keep it editable if you want copy/paste
    text_box.pack(padx=10, pady=5)

    # Optional: select all text for easy copying
    text_box.focus()
    text_box.tag_add("sel", "1.0", "end")

    # Add a close button
    ttk.Button(popup, text="Close", command=root.destroy).pack(pady=5)

## construct gui
root.title("Warzone Map Duplicator")

mainframe = ttk.Frame(root, padding="3 3 12 12")
mainframe.grid(column=0, row=0, sticky=(N, W, E, S))
root.columnconfigure(0, weight=1)
root.rowconfigure(0, weight=1)

# notes
ttk.Label(mainframe, wraplength='350', text=f'To get the new map id, it can be extracted from the public link for the map, accessed via "Link for Sharing" in the map designer').grid(column=1, row=1, columnspan=3, sticky=W)
ttk.Label(mainframe, wraplength='350', text=f'You can retrieve your api key from https://www.warzone.com/API/GetAPIToken').grid(column=1, row=2, columnspan=3, sticky=W)
ttk.Label(mainframe, wraplength='350', text=f'To retrieve the old maps details it queries an existing game. Please create a multiplayer game and use the game id from the link. i.e. https://www.warzone.com/MultiPlayer?GameID=39480679').grid(column=1, row=3, columnspan=3, sticky=W)


# oldMapId
ttk.Label(mainframe, text="Old Map Game Id").grid(column=1, row=4, sticky=W)
oldMapGameId = StringVar()
oldMapGameIdEntry = ttk.Entry(mainframe, width=7, textvariable=oldMapGameId)
oldMapGameIdEntry.grid(column=2, row=4, sticky=(W, E))

# newMapId
ttk.Label(mainframe, text="New Map Id").grid(column=1, row=5, sticky=W)
newMapId = StringVar()
newMapIdEntry = ttk.Entry(mainframe, width=7, textvariable=newMapId)
newMapIdEntry.grid(column=2, row=5, sticky=(W, E))

# email
ttk.Label(mainframe, text="Email").grid(column=1, row=6, sticky=W)
email = StringVar()
emailEntry = ttk.Entry(mainframe, width=30, textvariable=email)
emailEntry.grid(column=2, row=6, sticky=(W, E))

# apiKey
ttk.Label(mainframe, text="Api Key").grid(column=1, row=7, sticky=W)
apiKey = StringVar()
apiKeyEntry = ttk.Entry(mainframe, width=30, textvariable=apiKey, show="*")
apiKeyEntry.grid(column=2, row=7, sticky=(W, E))

ttk.Button(mainframe, text="Duplicate", command= lambda: DuplicateMapWrapper(oldMapGameId.get(), newMapId.get(), email.get(), apiKey.get())).grid(column=3, row=8, sticky=W)

for child in mainframe.winfo_children(): 
    child.grid_configure(padx=5, pady=5)

oldMapGameIdEntry.focus()
root.bind("<Return>", lambda: DuplicateMapWrapper(oldMapGameId.get(), newMapId.get(), email.get(), apiKey.get()))

## run gui
root.mainloop()
