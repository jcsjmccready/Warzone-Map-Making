#!/usr/bin/env python

import inkex
import os
import sys
import tempfile
from typing import List
from datetime import datetime
from inkex import command

ACTION_PATH_DIFFERENCE = 'path-difference'
ACTION_DESELECT = 'select-clear'
ACTION_DUPLICATE = 'duplicate'

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

def create_selection_action(element_id) -> str:
    """ creates the select action for a given element id"""
    return f'select-by-id:{element_id}'

class CutSelectedPolygonsOutOfEachOther(inkex.EffectExtension):
    """Main code for the extension"""
    
    def __init__(self):
        inkex.Effect.__init__(self)
    
    def add_arguments(self, pars):
        pars.add_argument("--tab", type=str, default='Controls')
        
    def get_elements(self):
        """ 
        Gets the elements required for this script and returns an error if insufficient elements are found\n
        Can function with a selection or with a group/layer of elements
        """

        polygons_selection: List[inkex.PathElement] = self.svg.selection.filter(inkex.PathElement)

        # if first element in selection is group (layers are groups), set selection to children
        if (len(self.svg.selection) > 0 and isinstance(self.svg.selection[0], inkex.Group)):
            polygons_selection = [element for element in self.svg.selection[0].getchildren() if isinstance(element, inkex.PathElement)]

        if (len(polygons_selection) < 2):
            halting_message('Please select at least two paths or group/layer containing them')
        
        return polygons_selection

    def are_points_near_to_each_other(
        self,
        primary_element,
        secondary_element) -> bool:
        """ Crude overlap detection of two elements"""
        
        primary_bbox = primary_element.bounding_box()
        secondary_bbox = secondary_element.bounding_box()
        
        multiplier = 1.05

        bbox_intersection = \
            primary_bbox.left * multiplier <= secondary_bbox.right * multiplier and \
            primary_bbox.top * multiplier <= secondary_bbox.bottom * multiplier and \
            primary_bbox.bottom * multiplier >= secondary_bbox.top * multiplier and \
            primary_bbox.right * multiplier >= secondary_bbox.left * multiplier
        
        return bbox_intersection

    def generate_actions_list(
        self,
        elements: [inkex.Path],
        temp_file_path: str) -> List[str]:
        """ Generates the required action list for cutting all the given elements out of one another """
        
        actions_list: List[str] = []
        for primary_element in elements:

            for secondary_element in elements:
                # skip if primary element
                if (primary_element.get_id() == secondary_element.get_id()):
                    continue
                
                # skip if not close to save on wasted compute
                are_points_close = self.are_points_near_to_each_other(primary_element, secondary_element)
                if(are_points_close == False):
                    continue

                # generate the list of actions to cut one element out from another
                actions_list.extend(self.generate_actions(primary_element, secondary_element))

        actions_list.append(f"export-filename:{temp_file_path};export-overwrite;export-do")
            
        actions_list.append(ACTION_DESELECT)
        return actions_list

    def generate_actions(
        self,
        primary_element: inkex.Path,
        secondary_element: inkex.Path
    ) -> List[str]:
        """ Generates the required action list for cutting a polygon out of another"""

        actions_list: List[str] = []
        actions_list.append(create_selection_action(primary_element.get_id()))
        actions_list.append(ACTION_DUPLICATE)
        actions_list.append(create_selection_action(secondary_element.get_id()))
        actions_list.append(ACTION_PATH_DIFFERENCE)
        actions_list.append(ACTION_DESELECT)
        return actions_list

    def execute_actions(
        self,
        actions_list: List[str],
        temp_file_path: str):
        """ Runs a list of inkscape actions against a file"""

        actions = ";".join(actions_list)
        command.inkscape(temp_file_path, actions=actions)

    def cleanup(self, temp_file: str) -> None:
        """ Deletes the temporary file used for modifying the svg without causing permanent damage if it fails poorly """
        try:
            os.remove(temp_file)
        except Exception:  # pylint: disable=broad-except
            inkex.errormsg(f'Error removing temporary file: {tempfile}\n\n')

    def effect(self):

        inkscape_version = get_inkscape_version()
        if(inkscape_version < 1.2):
            halting_message('This extension only supports inkscape versions >=1.2')
    
        elements = self.get_elements()
        
        # create a temp SVG document
        temp_file = tempfile.mktemp('temp.svg')
        self.document.write(temp_file)
        
        actions_list: List[str] = self.generate_actions_list(elements, temp_file)
        
        self.execute_actions(actions_list, temp_file)		

        # load temp SVG and then delete it
        self.document = inkex.load_svg(temp_file)
        self.cleanup(temp_file)


if __name__ == '__main__':
    CutSelectedPolygonsOutOfEachOther().run()
