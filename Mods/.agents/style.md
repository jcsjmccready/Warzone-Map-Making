# Code style

## Chained UI builder calls

When a chained call (e.g. `UI.CreateImage(...)`, `UI.CreateButton(...)`) has more than two
`.Method(...)` links, each link goes on its own line, indented under the opening call:

```lua
UI.CreateImage(row).SetSprite(originIcon)
    .SetPreferredWidth(LIST_VIEW_ICON_SIZE)
    .SetMinWidth(0)
    .SetFlexibleWidth(0)
    .SetPreferredHeight(LIST_VIEW_ICON_SIZE)
    .SetMinHeight(0);
```

A two-link chain can stay on one line. Apply this to every `UI.Create*`/`SetX()` builder chain of 3+
links, and reformat any such chain you touch while editing a file to match, even if unrelated to the
change you're making.
