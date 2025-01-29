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

BONUS_PREFIX = 'BonusLink_'

class LabelToIdExtension(inkex.EffectExtension):
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

        polygons_selection: List[inkex.BaseElement] = self.svg.selection.filter(inkex.BaseElement)

        # if first element in selection is group (layers are groups), set selection to children
        if (len(self.svg.selection) > 0 and isinstance(self.svg.selection[0], inkex.Group)):
            polygons_selection = [element for element in self.svg.selection[0].getchildren() if isinstance(element, inkex.BaseElement)]

        if (len(polygons_selection) < 1):
            halting_message('Please select at least one element')
        
        return polygons_selection

    def modify_elements(self, elements: List[inkex.BaseElement]):
        """
        Sets the ids of the given elements
        """
                
        for element in elements:
            label = element.label
            # remove characters warzone will ignore in the id but allow in the name
            label = label.replace("'", "") # apostrophes
            label = label.replace(" ", "") # white space
            
            element.set_id(f'{BONUS_PREFIX}{label}')

    def effect(self):

        inkscape_version = get_inkscape_version()
        if(inkscape_version < 1.2):
            halting_message('This extension only supports inkscape versions >=1.2')
    
        elements = self.get_elements()
        
        self.modify_elements(elements)

if __name__ == '__main__':
    LabelToIdExtension().run()
