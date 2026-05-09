#!/usr/bin/env python

import inkex, json, os, sys, re
from typing import List
from abc import ABC

def get_inkscape_version() -> float:
    """ Retrieves the inkscape version that this script is being run against """
    ink = inkex.command.INKSCAPE_EXECUTABLE_NAME
    os.environ["SELF_CALL"] = "true"  # needed for version 1.3 and 1.3.1
    try: # needed prior to 1.1
        ink_version = inkex.command.call(ink, '--version').decode("utf-8")
    except AttributeError: # needed starting from 1.1
        ink_version = inkex.command.call(ink, '--version')

    pos = ink_version.find("Inkscape ")
    if pos != -1:
        pos += 9
    else:
        return None
    v_num = ink_version[pos:pos+3]
    return(float(v_num))

def halting_message(message: str) -> None:
    """ Displays an error message to inkscape and exits the program """
    inkex.errormsg(message)
    sys.exit()

BONUS_PREFIX = 'BonusLink_'
TERRITORY_IDENTIFIER = 'Territory_'

class WarzoneSetDetailsPostRequestModel:
    email = ""
    APIToken = ""
    mapID = 0
    commands = None

    def __init__(self, email, APIToken, mapID, commands):
        self.email = email
        self.APIToken = APIToken
        self.mapID = int(mapID)
        self.commands = commands
    
    def to_JSON(self):
        return json.dumps(self, default = lambda o: o.__dict__, indent = 4)

class Command(ABC):
    command = ""

    def to_JSON(self):
        return json.dumps(self, default = lambda o: o.__dict__, sort_keys=True, indent=4)
    
    def validate(self):
        pass

    def get_error_string(self, field):
        return f"Invalid {field} for Command {self.command}: {self.to_JSON()}"
    
class AddBonusCommand(Command):
    name = ""
    armies = None

    def __init__(self, bonus_name, armies):
        self.command = "addBonus"
        self.name = bonus_name
        self.armies = int(armies)

    def validate(self):
        errors = []
        if(self.armies == None):
            errors.append(self.get_error_string("armies"))
        if(self.name == None or self.name == ""):
            errors.append(self.get_error_string("name"))
        
        if(len(errors)>0):
            return errors

class AddTerritoryToBonusCommand(Command):
    id = None
    bonusName = ""

    def __init__(self, territory_id, bonus_name):
        self.command = "addTerritoryToBonus"
        self.id = int(territory_id)
        self.bonusName = bonus_name
    
    def validate(self):
        errors = []
        if(self.id == None):
            errors.append(self.get_error_string("id"))
        if(self.bonusName == None or self.bonusName == ""):
            errors.append(self.get_error_string("bonusName"))
        
        if(len(errors)>0):
            return errors

class LuthadelRiotStation(inkex.EffectExtension):
    """Main code for the extension"""
    
    def __init__(self):
        inkex.Effect.__init__(self)
        
    def add_arguments(self, pars):
        pars.add_argument("--tab", type=str, default='Controls')
    
    def is_closed_path_naive(self, path: inkex.Path) -> bool:
        """
        A naive approach to determining if a given path is closed
        Naive as assuming presence of duplicate points means it is closed
        This is technically not true but is a lazy way of detection the truthful cases we currently care about
        
        Args:
            path (inkex.Path): The path to check

        Returns:
            bool: if the path is closed
        """
        points: List[float, float] = []
        for point in path.get_path().end_points:
            points.append([point.x,point.y])
      
        points_with_no_duplicates = list(set(map(tuple,points)))
        return len(points_with_no_duplicates) != len(points)
    
    def get_elements(self):
        """
        Gets the elements required for this script and returns an error if insufficient elements are found\n
        Can function with a selection or with a group/layer of elements
        """

        polygons_selection: List[inkex.BaseElement] = self.svg.selection.filter(inkex.BaseElement)

        if (len(polygons_selection) < 2):
            halting_message('Please select at least two territories')
        
        station_territory = None
        effected_territories = None

        for territory in polygons_selection:
            if(not self.is_closed_path_naive(territory)):
                halting_message(f'Territory {territory.get_id()} is not a closed path')

        station_territory = polygons_selection[0]
        effected_territories = list(polygons_selection)[1:]

        return (station_territory, effected_territories)

    def modify_elements(self, station_territory: inkex.BaseElement, effected_territories: List[inkex.BaseElement]):
        """
        Sets the ids of the given elements
        """
        
        prefix = 'R'
        commands = []
        
        for territory in effected_territories:
            territory_name = re.sub(r'/^[A-Z]+$/i', '', territory.label.replace(' ', ''))
            full_name = f'0{prefix}{territory_name}'
            if(len(full_name) > 50):
                halting_message(f'{full_name} length constraint hit')
            
            commands.append(AddBonusCommand(full_name, 1))
            commands.append(AddTerritoryToBonusCommand(territory.get_id().replace(TERRITORY_IDENTIFIER,""), full_name))
            commands.append(AddTerritoryToBonusCommand(station_territory.get_id().replace(TERRITORY_IDENTIFIER,""), full_name))
            
            
        
        json_model = WarzoneSetDetailsPostRequestModel('ignore', 'ignore', 0, commands)
        json_string = json_model.to_JSON()
        inkex.debug(json_string)

    def effect(self):
        inkscape_version = get_inkscape_version()
        if(inkscape_version < 1.2):
            halting_message('This extension only supports inkscape versions >=1.2')
    
        station_territory, effected_territories = self.get_elements()
        
        self.modify_elements(station_territory, effected_territories)

if __name__ == '__main__':
    LuthadelRiotStation().run()
