#!/usr/bin/env python

import inkex, os, sys, tempfile
from inkex import command
from typing import List

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

ACTION_DESELECT = 'select-clear'

class ActionIteratorExtension(inkex.EffectExtension):
    """Main code for the extension"""
    
    def __init__(self):
        inkex.Effect.__init__(self)
        
    def add_arguments(self, pars):
        pars.add_argument("--iterations", type=int, default=1)
        pars.add_argument("--action_name", type=str, default=None)
        pars.add_argument("--tab", type=str, default='Controls')

    def get_elements(self):
        """ 
        Gets the elements required for this script and returns an error if insufficient elements are found\n
        Can function with a selection or with a group/layer of elements
        """

        polygons_selection: List[inkex.BaseElement] = self.svg.selection.filter(inkex.BaseElement)

        # if first element in selection is group (layers are groups), set selection to children
        if (len(self.svg.selection) > 0 and isinstance(self.svg.selection[0], inkex.Group)):
            polygons_selection = [element for element in self.svg.selection[0].getchildren() if isinstance(element, inkex.BaseElement)]

        if (len(polygons_selection) < 1):
            halting_message('Please select at least one element')
        
        return polygons_selection

    def construct_actions(
            self,
            elements: List[inkex.BaseElement],
            action: str,
            number_of_times: int,
            temp_file: str) -> List[str]:
        """
        Generates the actions to enact the users request
        """
        actions_list = []

        for element in elements:
            for i in range(number_of_times):
                self.document.write(temp_file)
                actions_list.append(create_selection_action(element.get_id()))
                actions_list.append(action)

                actions_list.append(ACTION_DESELECT)
                actions_list.append(f"export-filename:{temp_file};export-overwrite;export-do")

        
        actions_list.append(ACTION_DESELECT)
        return actions_list
        
    def execute_actions(
        self,
        actions_list: List[str],
        temp_file_path: str):
        """ Runs a list of inkscape actions against a file"""

        actions = ";".join(actions_list)
        command.inkscape(temp_file_path, actions=actions)

        return actions

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
        
        actions_list = self.construct_actions(
            elements,
            self.options.action_name,
            self.options.iterations,
            temp_file)
                
        self.execute_actions(actions_list, temp_file)		

        self.document = inkex.load_svg(temp_file)

        self.cleanup(temp_file)


if __name__ == '__main__':
    ActionIteratorExtension().run()
