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

class AddElementsToBonusExtension(inkex.EffectExtension):
    """Main code for the extension"""
    
    DESCRIPTOR_VALUE_SEPARATOR_CHARACTER = ";"
    BONUS_VALUE_KEY = 'bonus_value'
    BONUS_PARENTS_KEY = 'bonus_parents'
    
    def __init__(self):
        inkex.Effect.__init__(self)
        
    def add_arguments(self, pars):
        pars.add_argument("--tab", type=str, default='Controls')
        pars.add_argument("--recolour_elements", type=inkex.Boolean, default=True)
        pars.add_argument("--colour", type=inkex.Color, default=inkex.Color("black"))
        pars.add_argument("--set_bonus_value", type=inkex.Boolean, default=False)
        pars.add_argument("--bonus_value_formula", type=str, default='n')

    def create_descriptor(self, key, value):
        return inkex.Desc(self.descriptor_key_value_format(key, value))

    def upsert_descriptor(self, parent, key, value):
        descriptor = self.get_descriptor(parent, key)
        if(descriptor != None):
            descriptor.text = self.descriptor_key_value_format(key, value)
            return descriptor
        
        descriptor = self.create_descriptor(key, value)
        parent.add(descriptor)
        return descriptor

    def get_descriptor(self, parent, key):
        for child in parent.getchildren():
            if(key in child.text):
                #TODO: I would prefer to add in a type check on if the child is a Desc (failed previously to do this)
                return child

    def descriptor_key_value_format(self, key, value):
        return f'{self.descriptor_key_separator_format(key)}{value}'

    def descriptor_key_separator_format(self, key):
        return f'{key}='

    def get_elements(self) -> (inkex.BaseElement, List[inkex.BaseElement]):
        """ 
        Gets the elements required for this script and returns an error if insufficient elements are found\n
        """

        polygons_selection: List[inkex.BaseElement] = self.svg.selection.filter(inkex.BaseElement)

        bonus = [polygon for polygon in polygons_selection if BONUS_PREFIX in polygon.get_id()]
        elements = [polygon for polygon in polygons_selection if BONUS_PREFIX not in polygon.get_id()]

        if (len(elements) < 1):
            halting_message('Please select at least one element')
        
        if (len(bonus) < 1):
            halting_message('Please select one bonus')
            
        return bonus[0], elements
 
    def modify_elements(self, bonus: inkex.BaseElement, elements: List[inkex.BaseElement]):
        """
        Modifies the elements adding them to the bonus
        """

        bonus_name = bonus.label
        element_counter = 0
        
        for element in elements:
            element_counter += 1
            
            if(self.options.recolour_elements):
                element.style["stroke"] = self.options.colour

            descriptor = self.get_descriptor(element, self.BONUS_PARENTS_KEY)
            if(descriptor == None):
                descriptor = self.create_descriptor(self.BONUS_PARENTS_KEY, bonus_name)
                element.add(descriptor)
            else:
                existing_parents = descriptor.text.replace(self.descriptor_key_separator_format(self.BONUS_PARENTS_KEY),"")
                self.upsert_descriptor(element, self.BONUS_PARENTS_KEY, \
                    f'{existing_parents}{self.DESCRIPTOR_VALUE_SEPARATOR_CHARACTER}{bonus_name}')
                
        if(self.options.set_bonus_value):
            if(self.options.bonus_value_formula == 'n_1'):
                element_counter = element_counter -1
            self.upsert_descriptor(bonus, self.BONUS_VALUE_KEY, element_counter)

    def effect(self):

        inkscape_version = get_inkscape_version()
        if(inkscape_version < 1.2):
            halting_message('This extension only supports inkscape versions >=1.2')
    
        bonus, elements = self.get_elements()
        
        self.modify_elements(bonus, elements)

if __name__ == '__main__':
    AddElementsToBonusExtension().run()
