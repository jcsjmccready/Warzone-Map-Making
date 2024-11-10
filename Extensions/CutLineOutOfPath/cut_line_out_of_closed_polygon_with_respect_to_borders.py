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


ACTION_PATH_DIFFERENCE = 'path-difference'
ACTION_DESELECT = 'select-clear'
ACTION_OBJECT_STROKE_TO_PATH = 'object-stroke-to-path'
DEFAULT_STROKE_WIDTH = 1

class CutLineOutOfClosedPolygonWithRespectToBordersExtension(inkex.EffectExtension):
    """Main code for the extension"""
    
    def __init__(self):
        inkex.Effect.__init__(self)
        
    def add_arguments(self, pars):
        pars.add_argument("--margin", type=int, default=1)
        
    def create_cutting_path(self, closed_polygon: inkex.PathElement, original_line: inkex.PathElement) -> inkex.Path:
        """
        Creates the path that is used to cut through the closed polygon

        Args:
            closed_polygon (inkex.Path): The polygon to be cut through
            original_line (inkex.Path): The line that should be visible through the cut

        Returns:
            inkex.Path: The cutting line
        """
        cutting_line = original_line.duplicate()

        closed_polygon_style = closed_polygon.effective_style()
        original_line_style = original_line.effective_style()
        cutting_line_style = cutting_line.effective_style()
        
        closed_polygon_stroke_width = float(closed_polygon_style["stroke-width"]) if "stroke-width" in closed_polygon_style else DEFAULT_STROKE_WIDTH
        original_line_stroke_width = float(original_line_style["stroke-width"]) if "stroke-width" in original_line_style else DEFAULT_STROKE_WIDTH

        if(closed_polygon.style["fill"] != None and closed_polygon_stroke_width != 0):
            cutting_line_style["stroke-width"] = closed_polygon_stroke_width + original_line_stroke_width + self.options.margin
        else:
            cutting_line_style["stroke-width"] = original_line_stroke_width + self.options.margin

        cutting_line_style["fill"] = None
        cutting_line_style["stroke"] = '#ffffff'

        original_line.ancestors()[0].add(cutting_line)
        
        return cutting_line
    
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

    def get_elements(self) -> (tuple[inkex.Path, inkex.Path]):
        """
        Overkill selection checks
        :return: The line and polygon from the selection
        """
        if (len(self.svg.selection.ids) != 2):
            halting_message('Please select the path and line you wish to cut out of it')
        
        polygons_selection: List[inkex.PathElement] = self.svg.selection.filter(inkex.PathElement)

        line_polygon = None
        closed_polygon = None

        if(self.is_closed_path_naive(polygons_selection[0])):
            closed_polygon = polygons_selection[0]
            line_polygon = polygons_selection[1]
        elif(self.is_closed_path_naive(polygons_selection[1])):
            line_polygon = polygons_selection[0]
            closed_polygon = polygons_selection[1]
        else:
            halting_message('You have not selected a closed polygon and a line')

        return (closed_polygon, line_polygon)

    def construct_actions(
            self,
            closed_polygon_id: str,
            path_id: str,
            temp_file: str) -> str:
        """
        Generates the actions to cut the given line out of the given closed polygon
        """
        actions_list = []

        actions_list.append(create_selection_action(path_id))
        actions_list.append(ACTION_OBJECT_STROKE_TO_PATH)

        actions_list.append(ACTION_DESELECT)

        actions_list.append(create_selection_action(path_id))
        actions_list.append(create_selection_action(closed_polygon_id))
        actions_list.append(ACTION_PATH_DIFFERENCE)

        actions_list.append(f"export-filename:{temp_file};export-overwrite;export-do")

        actions_list.append(ACTION_DESELECT)
        actions = ";".join(actions_list)

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
    
        closed_polygon_element, line_element = self.get_elements()
        cutting_path_element = self.create_cutting_path(closed_polygon_element, line_element)
        
        # create a temp SVG document
        # this has to be after the create cutting path for them to exist in it
        temp_file = tempfile.mktemp('temp.svg')
        self.document.write(temp_file)
        
        actions = self.construct_actions(
            closed_polygon_element.get_id(),
            cutting_path_element.get_id(),
            temp_file)		

        command.inkscape(temp_file, actions=actions)

        self.document = inkex.load_svg(temp_file)

        self.cleanup(temp_file)


if __name__ == '__main__':
    CutLineOutOfClosedPolygonWithRespectToBordersExtension().run()
