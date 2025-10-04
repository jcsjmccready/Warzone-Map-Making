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

from dis import Instruction
import tkinter as tk
from tkinter import filedialog, messagebox
import os
import json
import requests
from traceback import format_exc
from typing import List
from abc import ABC
import webbrowser
import threading


# =====================================================
# ===============  ERROR & SUCCESS WINDOWS =============
# =====================================================

class ErrorWindow(tk.Toplevel):
    def __init__(self, parent, title, message, return_callback=None, max_chars=200, raw_response=None):
        super().__init__(parent)
        self.title(title)
        self.geometry("420x280")
        self.resizable(False, False)
        self.return_callback = return_callback
        self.raw_response = raw_response

        self.transient(parent)
        self.grab_set()

        if len(message) > max_chars:
            message = message[:max_chars] + "..."

        tk.Label(self, text=title, font=("Arial", 12, "bold"), fg="red").pack(pady=10)
        msg_box = tk.Text(self, wrap="word", height=6, width=48)
        msg_box.insert("1.0", message)
        msg_box.configure(state="disabled")
        msg_box.pack(padx=10, pady=5)

        btn_frame = tk.Frame(self)
        btn_frame.pack(pady=5)

        tk.Button(btn_frame, text="Copy Message", command=lambda: self.copy_message(message)).pack(side="left", padx=5)
        if self.raw_response:
            tk.Button(btn_frame, text="Show Raw Response", command=self.show_raw_response).pack(side="left", padx=5)
        tk.Button(btn_frame, text="Close", command=self.on_close).pack(side="left", padx=5)

        self.protocol("WM_DELETE_WINDOW", self.on_close)
        self.after(100, lambda: center_window(self))

    def copy_message(self, message):
        self.clipboard_clear()
        self.clipboard_append(message)
        messagebox.showinfo("Copied", "Message copied to clipboard.")

    def show_raw_response(self):
        RawResponseWindow(self, self.raw_response)

    def on_close(self):
        self.grab_release()
        self.destroy()
        if self.return_callback:
            self.return_callback()


class RawResponseWindow(tk.Toplevel):
    def __init__(self, parent, raw_data):
        super().__init__(parent)
        self.title("Raw API Response")
        self.geometry("500x400")
        self.resizable(True, True)

        self.transient(parent)
        self.grab_set()

        tk.Label(self, text="Raw Response (read-only)", font=("Arial", 11, "bold")).pack(pady=5)

        text_frame = tk.Frame(self)
        text_frame.pack(fill="both", expand=True, padx=10, pady=5)

        scrollbar = tk.Scrollbar(text_frame)
        scrollbar.pack(side="right", fill="y")

        text_box = tk.Text(text_frame, wrap="word", yscrollcommand=scrollbar.set)
        text_box.insert("1.0", raw_data)
        text_box.configure(state="disabled")
        text_box.pack(fill="both", expand=True)

        scrollbar.config(command=text_box.yview)

        btn_frame = tk.Frame(self)
        btn_frame.pack(pady=10)
        tk.Button(btn_frame, text="Copy", command=lambda: self.copy_to_clipboard(raw_data)).pack(side="left", padx=5)
        tk.Button(btn_frame, text="Close", command=self.close_window).pack(side="left", padx=5)

        self.protocol("WM_DELETE_WINDOW", self.close_window)
        self.after(100, lambda: center_window(self))

    def copy_to_clipboard(self, raw_data):
        self.clipboard_clear()
        self.clipboard_append(raw_data)
        messagebox.showinfo("Copied", "Raw response copied to clipboard.")

    def close_window(self):
        self.grab_release()
        self.destroy()


class MapDuplicateSuccessWindow(tk.Toplevel):
    def __init__(self, parent, newMapId):
        super().__init__(parent)
        self.title("Map Duplicate Success")
        self.geometry("380x180")
        self.resizable(False, False)

        self.transient(parent)
        self.grab_set()

        tk.Label(self, text="Map Duplicated Successfully!", font=("Arial", 13, "bold"), fg="green").pack(pady=15)
        link = f"https://www.warzone.com/SinglePlayer?PreviewMap={newMapId}"
        tk.Label(self, text=f"Map ID: {newMapId}", font=("Arial", 11)).pack()
        tk.Button(self, text="Open in Browser", command=lambda: webbrowser.open(link)).pack(pady=10)
        tk.Button(self, text="Close", command=self.close_window).pack(pady=5)
        self.after(100, lambda: center_window(self))

    def close_window(self):
        self.grab_release()
        self.destroy()


# =====================================================
# ===============  WARZONE MODEL CLASSES ==============
# =====================================================

class QueryGameTerritory:
    def __init__(self, name, id, connectedTo, coords):
        self.name = name
        self.id = int(id)
        self.connectedTo = connectedTo
        self.coords = coords


class QueryGameBonus:
    def __init__(self, id, name, value, territoryIDs):
        self.id = int(id)
        self.name = name
        self.value = int(value)
        self.territoryIDs = territoryIDs


class Command(ABC):
    command = ""
    def to_JSON(self):
        return json.dumps(self, default=lambda o: o.__dict__, sort_keys=True, indent=4)


class WarzoneSetDetailsPostRequestModel:
    def __init__(self, email, APIToken, mapID, commands):
        self.email = email
        self.APIToken = APIToken
        self.mapID = int(mapID)
        self.commands = commands

    def to_JSON(self):
        return json.dumps(self, default=lambda o: o.__dict__, indent=4)


class SetTerritoryNameCommand(Command):
    def __init__(self, id, territoryName):
        self.command = "setTerritoryName"
        self.id = int(id)
        self.name = territoryName


class SetTerritoryCenterpointCommand(Command):
    def __init__(self, id, x, y):
        self.command = "setTerritoryCenterPoint"
        self.id = int(id)
        self.x = str(x)
        self.y = str(y)


class AddBonusCommand(Command):
    def __init__(self, bonusName, armies, color="#000000"):
        self.command = "addBonus"
        self.name = bonusName
        self.armies = int(armies)
        self.color = color


class AddTerritoryToBonusCommand(Command):
    def __init__(self, territoryId, bonusName):
        self.command = "addTerritoryToBonus"
        self.id = int(territoryId)
        self.bonusName = bonusName


class AddTerritoryConnectionCommand(Command):
    def __init__(self, territoryId, territoryId2, wrap="Normal"):
        self.command = "addTerritoryConnection"
        self.id1 = int(territoryId)
        self.id2 = int(territoryId2)
        self.wrap = wrap


# =====================================================
# =================  HELPER FUNCTIONS =================
# =====================================================

def center_window(window):
    """Center a tkinter window on the screen."""
    window.update_idletasks()
    width = window.winfo_width()
    height = window.winfo_height()
    screen_width = window.winfo_screenwidth()
    screen_height = window.winfo_screenheight()
    x = (screen_width // 2) - (width // 2)
    y = (screen_height // 2) - (height // 2)
    window.geometry(f"{width}x{height}+{x}+{y}")


def CantorPairingFunction(a: int, b: int) -> int:
    intA, intB = int(a), int(b)
    return int((intA + intB) * (intA + intB + 1) / 2 + intA)


def ParseResponseForUploadables(mapJson: dict):
    territories = [QueryGameTerritory(**t) for t in mapJson["territories"]]
    bonuses = [QueryGameBonus(**b) for b in mapJson["bonuses"]]
    return territories, bonuses


def ConvertClassesToCommands(territories: List[QueryGameTerritory], bonuses: List[QueryGameBonus]) -> List[Command]:
    addBonusCommands, addTerritoryToBonusCommands, addTerritoryConnectionCommands = [], [], []
    setTerritoryNameCommands, setTerritoryCenterpointCommands = [], []
    connectionHashes = []

    for bonus in bonuses:
        addBonusCommands.append(AddBonusCommand(bonus.name, bonus.value))
        for territoryId in bonus.territoryIDs:
            addTerritoryToBonusCommands.append(AddTerritoryToBonusCommand(territoryId, bonus.name))

    for territory in territories:
        setTerritoryNameCommands.append(SetTerritoryNameCommand(territory.id, territory.name))
        x, y = territory.coords.split(",")
        setTerritoryCenterpointCommands.append(SetTerritoryCenterpointCommand(territory.id, x, y))

        for connectionId in territory.connectedTo:
            hash_val = CantorPairingFunction(territory.id, connectionId)
            if hash_val not in connectionHashes:
                addTerritoryConnectionCommands.append(AddTerritoryConnectionCommand(territory.id, connectionId))
                connectionHashes.append(hash_val)

    return addBonusCommands + addTerritoryToBonusCommands + addTerritoryConnectionCommands + setTerritoryNameCommands + setTerritoryCenterpointCommands


def UploadMap(email: str, token: str, mapId: int, commands: List[Command]) -> str:
    model = WarzoneSetDetailsPostRequestModel(email, token, mapId, commands)
    json_string = model.to_JSON()
    response = requests.post('https://www.warzone.com/API/SetMapDetails', data=json_string)
    responseJson = response.json()
    return responseJson.get('error', None), responseJson


# =====================================================
# ==================  INSTRUCTIONS ====================
# =====================================================

class InstructionsPage(tk.Frame):
    def __init__(self, parent, controller):
        super().__init__(parent)
        self.controller = controller
        self.configure(padx=20, pady=20)

        tk.Label(self, text="Instructions", font=("Arial", 14, "bold")).grid(row=0, column=0, columnspan=3, pady=(0, 15))

        instructions_text = (
            "This tool comes with two options:\n\n"
            "1. Download Map Details\n"
            "   - Requires a paid membership account.\n"
            "   - Saves a JSON file containing details of the old map.\n\n"
            "2. Duplicate Map\n"
            "   - Can be done with any account.\n"
            "   - Use the account you want the duplicated map to belong to.\n\n"
            "Steps to duplicate a map:\n\n"
            "Step 1: Upload the SVG for your duplicated map.\n"
            "   - The map should have the same territories and bonuses as the old map.\n\n"
            "Step 2: Create a multiplayer game using the code-invite option.\n"
            "   - Use your old map that you want to duplicate.\n"
            "   - Invite an account with paid membership to the lobby.\n"
            "     (The API requires a paid account to download map details.)\n\n"
            "Step 3: Use the 'Download Map Details' option.\n"
            "   - Provide the email and API key for the paid membership account.\n"
            "   - Instructions on where to find the API key will be provided.\n"
            "     Example API token: $z8RMaH0*$tF!q2WELoVu7^9cpBnKsGyZm4\n"
            "   - This will generate a JSON file with the old map details.\n\n"
            "Step 4: Duplicate the map.\n"
            "   - Provide the New Map ID where the duplicated map should be uploaded.\n"
            "   - Open the new map in the map designer and get the public link for sharing.\n"
            "   - Extract the numeric ID from the link, e.g., www.warzone.com/SinglePlayer?PreviewMap=108468\n\n"
            "Step 5: Upload the map using the email and API token for the account where the map should be created.\n"
            "   - Select the JSON file downloaded in Step 3.\n\n"
            "Step 6: Enjoy your duplicated map!"
        )

        # Display instructions in a scrollable Text widget
        text_widget = tk.Text(self, wrap="word", width=80, height=25)
        text_widget.insert("1.0", instructions_text)
        text_widget.config(state="disabled")
        text_widget.grid(row=1, column=0, columnspan=3, pady=(0, 20))

        # Buttons
        tk.Button(self, text="Back", command=lambda: controller.show_frame(MainMenu), width=20).grid(row=2, column=0, columnspan=3)

# =====================================================
# ==================  DOWNLOAD LOGIC ==================
# =====================================================

class DownloadMapPage(tk.Frame):
    def __init__(self, parent, controller):
        super().__init__(parent)
        self.controller = controller
        self.configure(padx=150, pady=20)

        tk.Label(self, text="Download Old Map Details", font=("Arial", 14, "bold")).grid(row=0, column=0, columnspan=3, pady=(0,15))

        tk.Label(self, text="Old Map Game ID").grid(row=1, column=0, sticky="w")
        self.old_map_id = tk.Entry(self, width=45)
        self.old_map_id.grid(row=1, column=1, columnspan=2, pady=2, sticky="w")

        # Email
        tk.Label(self, text="Email").grid(row=2, column=0, sticky="w")
        self.email_entry = tk.Entry(self, width=37)
        self.email_entry.grid(row=2, column=1, pady=2, sticky="w")
        tk.Button(self, text="Find", width=5,
                  command=lambda: webbrowser.open("https://www.warzone.com/ChangeEmail")).grid(row=2, column=2, sticky="w", padx=5)

        # API Key
        tk.Label(self, text="API Key").grid(row=3, column=0, sticky="w")
        self.api_key_entry = tk.Entry(self, width=37, show="*")
        self.api_key_entry.grid(row=3, column=1, pady=2, sticky="w")
        tk.Button(self, text="Find", width=5,
                  command=lambda: webbrowser.open("https://www.warzone.com/API/GetAPIToken")).grid(row=3, column=2, sticky="w", padx=5)

        # Download Path
        tk.Label(self, text="Download Path").grid(row=4, column=0, sticky="w")
        self.download_path = tk.Entry(self, width=37)
        self.download_path.grid(row=4, column=1, pady=2, sticky="w")
        tk.Button(self, text="Browse", command=lambda: self.download_path.insert(0, filedialog.askdirectory())).grid(row=4, column=2, sticky="w", padx=5)

        # Buttons
        tk.Button(self, text="Download", command=self.download_file, width=20).grid(row=5, column=0, columnspan=3, pady=10)
        tk.Button(self, text="Back", command=lambda: controller.show_frame(MainMenu), width=20).grid(row=6, column=0, columnspan=3)

    def add_entry(self, label_text, show=None):
        tk.Label(self, text=label_text).pack()
        entry = tk.Entry(self, show=show, width=60)
        entry.pack(pady=3)
        return entry

    def add_path_entry(self, label_text):
        tk.Label(self, text=label_text).pack()
        frame = tk.Frame(self)
        frame.pack(pady=3)
        entry = tk.Entry(frame, width=60)
        entry.pack(side="left")
        tk.Button(frame, text="Browse", command=lambda: entry.insert(0, filedialog.askdirectory())).pack(side="left")
        return entry

    def validate_fields(self):
        if not all([self.old_map_id.get().strip(), self.email_entry.get().strip(), self.api_key_entry.get().strip(), self.download_path.get().strip()]):
            ErrorWindow(self, "Missing Fields", "Please fill in all fields.")
            return False
        return True

    def GetMap(self, gameId: int, email: str, apiToken: str) -> dict:
        response = requests.get(f'https://www.warzone.com/API/GameFeed?GameID={gameId}&Email={email}&APIToken={apiToken}')
        return response.json()

    def DownloadMapDetails(self, oldMapGameId: int, email: str, apiKey: str, save_folder: str):
        try:
            jsonData = self.GetMap(oldMapGameId, email, apiKey)
            error = jsonData.get("error")
            if error:
                ErrorWindow(self, "Error from Warzone API", error, raw_response=json.dumps(jsonData, indent=4))
                return
            mapJson = jsonData.get("map")
            if not mapJson or "territories" not in mapJson or "bonuses" not in mapJson:
                ErrorWindow(self, "Invalid Map Data", "Map JSON missing 'territories' or 'bonuses'.")
                return
            save_path = os.path.join(save_folder, f"{oldMapGameId}_map.json")
            with open(save_path, "w", encoding="utf-8") as f:
                json.dump(mapJson, f, indent=4)
            messagebox.showinfo("Download Complete", f"Map details saved:\n{save_path}")
        except Exception:
            ErrorWindow(self, "Download Exception", format_exc())

    def download_file(self):
        if not self.validate_fields():
            return
        self.DownloadMapDetails(self.old_map_id.get().strip(), self.email_entry.get().strip(), self.api_key_entry.get().strip(), self.download_path.get().strip())


# =====================================================
# ===================  UPLOAD LOGIC ===================
# =====================================================

class DuplicateMapPage(tk.Frame):
    def __init__(self, parent, controller):
        super().__init__(parent)
        self.controller = controller
        self.configure(padx=150, pady=20)

        tk.Label(self, text="Duplicate Map", font=("Arial", 14, "bold")).grid(row=0, column=0, columnspan=3, pady=(0,15))

        tk.Label(self, text="New Map ID").grid(row=1, column=0, sticky="w")
        self.new_map_id = tk.Entry(self, width=45)
        self.new_map_id.grid(row=1, column=1, columnspan=2, pady=2, sticky="w")

        # Email
        tk.Label(self, text="Email").grid(row=2, column=0, sticky="w")
        self.email_entry = tk.Entry(self, width=37)
        self.email_entry.grid(row=2, column=1, pady=2, sticky="w")
        tk.Button(self, text="Find", width=5,
                  command=lambda: webbrowser.open("https://www.warzone.com/ChangeEmail")).grid(row=2, column=2, sticky="w", padx=5)

        # API Key
        tk.Label(self, text="API Key").grid(row=3, column=0, sticky="w")
        self.api_key_entry = tk.Entry(self, width=37, show="*")
        self.api_key_entry.grid(row=3, column=1, pady=2, sticky="w")
        tk.Button(self, text="Find", width=5,
                  command=lambda: webbrowser.open("https://www.warzone.com/API/GetAPIToken")).grid(row=3, column=2, sticky="w", padx=5)

        # File
        tk.Label(self, text="File").grid(row=4, column=0, sticky="w")
        self.file_path = tk.Entry(self, width=37)
        self.file_path.grid(row=4, column=1, pady=2, sticky="w")
        tk.Button(self, text="Browse", command=lambda: self.file_path.insert(0, filedialog.askopenfilename(filetypes=[("JSON Files","*.json")]))).grid(row=4, column=2, sticky="w", padx=5)

        # Buttons
        tk.Button(self, text="Upload", command=self.upload_file, width=20).grid(row=5, column=0, columnspan=3, pady=10)
        tk.Button(self, text="Back", command=lambda: controller.show_frame(MainMenu), width=20).grid(row=6, column=0, columnspan=3)

    def add_entry(self, label_text, show=None):
        tk.Label(self, text=label_text).pack()
        entry = tk.Entry(self, show=show, width=60)
        entry.pack(pady=3)
        return entry

    def add_file_entry(self, label_text):
        tk.Label(self, text=label_text).pack()
        frame = tk.Frame(self)
        frame.pack(pady=3)
        entry = tk.Entry(frame, width=60)
        entry.pack(side="left")
        tk.Button(frame, text="Browse", command=lambda: entry.insert(0, filedialog.askopenfilename(filetypes=[("JSON Files", "*.json")]))).pack(side="left")
        return entry

    def validate_fields(self):
        if not all([self.new_map_id.get().strip(), self.email_entry.get().strip(), self.api_key_entry.get().strip(), self.file_path.get().strip()]):
            ErrorWindow(self, "Missing Fields", "Please fill in all fields.")
            return False
        return True

    def upload_file(self):
        if not self.validate_fields():
            return

        new_map_id = self.new_map_id.get().strip()
        email = self.email_entry.get().strip()
        api_key = self.api_key_entry.get().strip()
        file_path = self.file_path.get().strip()

        def run_upload():
            try:
                with open(file_path, "r", encoding="utf-8") as f:
                    mapJson = json.load(f)

                territories, bonuses = ParseResponseForUploadables(mapJson)
                commands = ConvertClassesToCommands(territories, bonuses)
                error, raw_response = UploadMap(email, api_key, new_map_id, commands)

                if error:
                    ErrorWindow(self, "Upload Error", error, raw_response=json.dumps(raw_response, indent=4))
                    return

                MapDuplicateSuccessWindow(self, new_map_id)
            except Exception:
                ErrorWindow(self, "Upload Exception", format_exc())

        threading.Thread(target=run_upload, daemon=True).start()


# =====================================================
# ===================== MAIN MENU =====================
# =====================================================

class MainMenu(tk.Frame):
    def __init__(self, parent, controller):
        super().__init__(parent)
        self.controller = controller
        self.configure(padx=30, pady=30)

        # Title
        tk.Label(self, text="Choose an Option", font=("Arial", 18, "bold")).pack(pady=(0, 30))

        # Buttons container
        btn_frame = tk.Frame(self)
        btn_frame.pack(pady=10)

        # Buttons
        tk.Button(btn_frame, text="Instructions", width=50,
                  command=lambda: controller.show_frame(InstructionsPage)).pack(pady=10)
        tk.Button(btn_frame, text="Download Old Map Details (Membership Required)", width=50,
                  command=lambda: controller.show_frame(DownloadMapPage)).pack(pady=10)
        tk.Button(btn_frame, text="Duplicate Map", width=50,
                  command=lambda: controller.show_frame(DuplicateMapPage)).pack(pady=10)


# =====================================================
# ==================== MAIN APP =======================
# =====================================================

class WarzoneApp(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Warzone Map Tool")
        self.geometry("700x600")  # Wider to fit buttons nicely

        container = tk.Frame(self)
        container.pack(fill="both", expand=True)

        self.frames = {}
        for F in (MainMenu, InstructionsPage, DownloadMapPage, DuplicateMapPage):
            frame = F(container, self)
            self.frames[F] = frame
            frame.grid(row=0, column=0, sticky="nsew")

        self.show_frame(MainMenu)

    def show_frame(self, page):
        frame = self.frames[page]
        frame.tkraise()


if __name__ == "__main__":
    app = WarzoneApp()
    app.mainloop()
