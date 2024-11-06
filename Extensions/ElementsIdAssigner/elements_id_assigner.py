###
#   Element Property Counter
#
#   This script is used to assign a values to the id of an svg element with a counter
#
#   It will apply the function to all children of a given group/layer or all elements selected
#
#   The value given will be the given prefix + a counter i.e. Territory_0, Territory_1, Territory_n for a prefix of "Territory_"
#
###

import inkex, os, sys, tempfile
from inkex import command

def get_inkscape_version() -> float:
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


def haltingMessage(message: str) -> None:
    inkex.errormsg(message)
    sys.exit()

class ElementsIdAssigner(inkex.EffectExtension):

    def add_arguments(self, pars):
        pars.add_argument("--prefix", type=str, default="CHANGEME",\
                          help="Please specify the prefix")

    def __init__(self):
        inkex.Effect.__init__(self)
    
    def get_elements(self):
        polygons_selection: inkex.ElementList = self.svg.selection.filter(inkex.BaseElement)

        if(type(self.svg.selection[0]) is inkex.Layer or type(self.svg.selection[0]) is inkex.Group):
            polygons_selection = self.svg.selection[0].getchildren()

        return polygons_selection

    def effect(self):

        inkscape_version = get_inkscape_version()
        if(inkscape_version < 1.2):
            haltingMessage('This extension only supports inkscape versions >=1.2')
    
        elements = self.get_elements()

        counter = 0
        for element in elements:
            element.set_id(f'{self.options.prefix}{counter}')
            counter = counter + 1


if __name__ == '__main__':
    ElementsIdAssigner().run()
