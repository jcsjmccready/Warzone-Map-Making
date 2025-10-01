#!/usr/bin/env python

import inkex, os, sys, tempfile, re, json
from inkex import command
from typing import List
from abc import ABC

# from svgpath2mpl import parse_path
# from matplotlib.path import Path
# import matplotlib.transforms as transforms
# import numpy as np

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
    
def get_warzone_identifiable_path(
        type: str,
        root: inkex.BaseElement,
        is_recursive: bool = True) -> List[inkex.PathElement]:
    slash = '//' if is_recursive else '/'
    return root.xpath(
        f".{slash}{Svg.PATH}[contains(@{Svg.ID}, '{type}')]",
        namespaces=inkex.NSS
    )

BONUS_PREFIX = 'BonusLink_'
TERRITORY_IDENTIFIER = 'Territory_'

class Svg:
    ID = 'id'
    GROUP = 'svg:g'
    PATH = 'svg:path'
    TITLE = 'svg:title'
    CLONE = 'svg:use'
    ELLIPSE = 'svg:ellipse'
    RECTANGLE = 'svg:rect'
    TEXT = 'svg:text'
    TSPAN = 'svg:tspan'

    STYLE = 'style'
    FILL = 'fill'
    STROKE = 'stroke'
    STROKE_WIDTH = 'stroke-width'
    
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

BONUS_PREFIX = 'BonusLink_'

def create_selection_action(element_id) -> str:
    """ creates the select action for a given element id"""
    return f'select-by-id:{element_id}'


ACTION_PATH_COMBINE = 'path-combine'
ACTION_DESELECT = 'select-clear'

class LabelToIdExtension(inkex.EffectExtension):
    """Main code for the extension"""
    
    def __init__(self):
        inkex.Effect.__init__(self)
        
    def add_arguments(self, pars):
        pars.add_argument("--tab", type=str, default='Controls')

    def get_elements(self) -> (tuple[List[inkex.BaseElement], List[inkex.BaseElement]]):
        """
        Overkill selection checks
        :return: The line and polygon from the selection
        """
        if (len(self.svg.selection.ids) != 2):
            halting_message('Please select the two groups')
         
        group_1 = self.svg.selection[0]
        group_2 = self.svg.selection[1]
        
        if(not isinstance(self.svg.selection[0], inkex.Group) or not isinstance(self.svg.selection[1], inkex.Group)):
            halting_message('You have not selected two groups')
        
        if(len(group_1.getchildren()) != len(group_2.getchildren())):
            halting_message('The number of children in the groups is different')
        
        return (group_1.getchildren(), group_2.getchildren())

    def construct_actions(
            self,
            element1: str,
            element2: str) -> str:
        """
        Generates the actions to cut the given line out of the given closed polygon
        """
        actions_list = []

        actions_list.append(create_selection_action(element2.get_id()))
        actions_list.append(create_selection_action(element1.get_id()))
        actions_list.append(ACTION_PATH_COMBINE)

        actions_list.append(ACTION_DESELECT)

        return actions_list

    def cleanup(self, temp_file: str) -> None:
        """ Deletes the temporary file used for modifying the svg without causing permanent damage if it fails poorly """
        try:
            os.remove(temp_file)
        except Exception:  # pylint: disable=broad-except
            inkex.errormsg(f'Error removing temporary file: {tempfile}\n\n')

    def get_territory_name(self, territory: inkex.BaseElement) -> str:
        try:
            return re.sub(r'/^[A-Z]+$/i', '', territory.label.replace(' ', '').replace('\'', '').replace('&',''))
        except:
            halting_message(f'exception encountered: {territory.get_id()}')
            
    def modify_elements(self, contract_territories: List[inkex.BaseElement], keep_territories: List[inkex.BaseElement]):
        """
        Sets the ids of the given elements
        """
        
        commands = []
        for contract_territory in contract_territories:
            contract_territory_name = self.get_territory_name(contract_territory)

            for keep_territory in keep_territories:
                keep_territory_name = self.get_territory_name(keep_territory)
                penalty_bonus_name = f'0{contract_territory_name}{keep_territory_name}'
                commands.append(AddBonusCommand(penalty_bonus_name,3))
                commands.append(AddTerritoryToBonusCommand(contract_territory.get_id().replace(TERRITORY_IDENTIFIER,""), penalty_bonus_name))
                commands.append(AddTerritoryToBonusCommand(keep_territory.get_id().replace(TERRITORY_IDENTIFIER,""), penalty_bonus_name))
        
        json_model = WarzoneSetDetailsPostRequestModel('ignore', 'ignore', 0, commands)
        json_string = json_model.to_JSON()
        inkex.debug(json_string)

    def effect(self):

        inkscape_version = get_inkscape_version()
        if(inkscape_version < 1.2):
            halting_message('This extension only supports inkscape versions >=1.2')
    
        contract_territories = []
        contract_territories.append(get_warzone_identifiable_path(f'{TERRITORY_IDENTIFIER}1159', self.svg, True)[0])
        contract_territories.append(get_warzone_identifiable_path(f'{TERRITORY_IDENTIFIER}1117', self.svg, True)[0])
        contract_territories.append(get_warzone_identifiable_path(f'{TERRITORY_IDENTIFIER}1152', self.svg, True)[0])
        contract_territories.append(get_warzone_identifiable_path(f'{TERRITORY_IDENTIFIER}1162', self.svg, True)[0])
        contract_territories.append(get_warzone_identifiable_path(f'{TERRITORY_IDENTIFIER}1124', self.svg, True)[0])
        contract_territories.append(get_warzone_identifiable_path(f'{TERRITORY_IDENTIFIER}1153', self.svg, True)[0])
        contract_territories.append(get_warzone_identifiable_path(f'{TERRITORY_IDENTIFIER}1107', self.svg, True)[0])
        contract_territories.append(get_warzone_identifiable_path(f'{TERRITORY_IDENTIFIER}1142', self.svg, True)[0])
        
        
        poi_territories = []
        poi_territories.append(get_warzone_identifiable_path(f'{TERRITORY_IDENTIFIER}1010', self.svg, True)[0])
        poi_territories.append(get_warzone_identifiable_path(f'{TERRITORY_IDENTIFIER}1009', self.svg, True)[0])
        poi_territories.append(get_warzone_identifiable_path(f'{TERRITORY_IDENTIFIER}1011', self.svg, True)[0])
        poi_territories.append(get_warzone_identifiable_path(f'{TERRITORY_IDENTIFIER}1012', self.svg, True)[0])
        poi_territories.append(get_warzone_identifiable_path(f'{TERRITORY_IDENTIFIER}1221', self.svg, True)[0])
        poi_territories.append(get_warzone_identifiable_path(f'{TERRITORY_IDENTIFIER}486', self.svg, True)[0])
        
        self.modify_elements(contract_territories, poi_territories)
        
        # (group1, group2) = self.get_elements()
        
        # create a temp SVG document
        # this has to be after the create cutting path for them to exist in it
        # temp_file = tempfile.mktemp('temp.svg')
        # self.document.write(temp_file)
        
        # actions_list = []
        # for i in range(len(group1)):
        #     actions_list.extend(self.construct_actions(group1[i],group2[i]))

        # actions_list.append(f"export-filename:{temp_file};export-overwrite;export-do")
        
        # actions = ";".join(actions_list)
        # command.inkscape(temp_file, actions=actions)

        # self.document = inkex.load_svg(temp_file)

        # self.cleanup(temp_file)

if __name__ == '__main__':
    LabelToIdExtension().run()
