; Overlay segment DASH: the dashboard art (see tools/dash.py): the whole image for the
; start-up blit and the scanner part for the per-frame restore.
        ORG $F300
DASHIMG INCLUDEBIN "gen/dashfull.bin"
SCANIMG INCLUDEBIN "gen/dashscan.bin"
        END
