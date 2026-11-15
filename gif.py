#!/usr/bin/env python3

import ctypes
import os
import sys
import time

APP_ID = 108600
ITEM_ID = 3838091936
HERE = os.path.dirname(os.path.abspath(__file__))
GIF = os.path.join(HERE, "preview.gif")
LIB = "/data/Gaming/Steam/steamapps/common/ProjectZomboid/projectzomboid/natives/libsteam_api.so"
SUBMIT_ITEM_UPDATE_RESULT = 3404


def main():
    check = "--check" in sys.argv
    size = os.path.getsize(GIF)
    if size > 1024 * 1024:
        sys.exit(f"preview.gif is {size} bytes, Steam's limit is 1 MB")

    os.environ["SteamAppId"] = os.environ["SteamGameId"] = str(APP_ID)
    api = ctypes.CDLL(LIB)
    err = ctypes.create_string_buffer(1024)
    api.SteamAPI_InitFlat.argtypes = [ctypes.c_char_p]
    if api.SteamAPI_InitFlat(err) != 0:
        sys.exit(
            "Steam init failed (is Steam running and logged in?): " + err.value.decode()
        )

    try:
        api.SteamAPI_SteamUGC_v021.restype = ctypes.c_void_p
        api.SteamAPI_SteamUtils_v010.restype = ctypes.c_void_p
        ugc, utils = api.SteamAPI_SteamUGC_v021(), api.SteamAPI_SteamUtils_v010()
        if not ugc or not utils:
            sys.exit("Steam UGC interface unavailable")
        if check:
            print("Steam connection OK, nothing uploaded.")
            return

        api.SteamAPI_ISteamUGC_StartItemUpdate.argtypes = [
            ctypes.c_void_p,
            ctypes.c_uint32,
            ctypes.c_uint64,
        ]
        api.SteamAPI_ISteamUGC_StartItemUpdate.restype = ctypes.c_uint64
        api.SteamAPI_ISteamUGC_SetItemPreview.argtypes = [
            ctypes.c_void_p,
            ctypes.c_uint64,
            ctypes.c_char_p,
        ]
        api.SteamAPI_ISteamUGC_SetItemPreview.restype = ctypes.c_bool
        api.SteamAPI_ISteamUGC_SubmitItemUpdate.argtypes = [
            ctypes.c_void_p,
            ctypes.c_uint64,
            ctypes.c_char_p,
        ]
        api.SteamAPI_ISteamUGC_SubmitItemUpdate.restype = ctypes.c_uint64
        api.SteamAPI_ISteamUtils_IsAPICallCompleted.argtypes = [
            ctypes.c_void_p,
            ctypes.c_uint64,
            ctypes.POINTER(ctypes.c_bool),
        ]
        api.SteamAPI_ISteamUtils_IsAPICallCompleted.restype = ctypes.c_bool
        api.SteamAPI_ISteamUtils_GetAPICallResult.argtypes = [
            ctypes.c_void_p,
            ctypes.c_uint64,
            ctypes.c_void_p,
            ctypes.c_int,
            ctypes.c_int,
            ctypes.POINTER(ctypes.c_bool),
        ]
        api.SteamAPI_ISteamUtils_GetAPICallResult.restype = ctypes.c_bool

        h = api.SteamAPI_ISteamUGC_StartItemUpdate(ugc, APP_ID, ITEM_ID)
        if not api.SteamAPI_ISteamUGC_SetItemPreview(ugc, h, GIF.encode()):
            sys.exit("SetItemPreview rejected the file")
        call = api.SteamAPI_ISteamUGC_SubmitItemUpdate(
            ugc, h, None
        )

        failed = ctypes.c_bool()
        deadline = time.time() + 120
        while not api.SteamAPI_ISteamUtils_IsAPICallCompleted(
            utils, call, ctypes.byref(failed)
        ):
            if time.time() > deadline:
                sys.exit("timed out waiting for Steam")
            api.SteamAPI_RunCallbacks()
            time.sleep(0.2)

        buf = (ctypes.c_ubyte * 32)()
        api.SteamAPI_ISteamUtils_GetAPICallResult(
            utils, call, buf, 16, SUBMIT_ITEM_UPDATE_RESULT, ctypes.byref(failed)
        )
        result = int.from_bytes(bytes(buf[0:4]), "little", signed=True)
        if failed.value or result != 1:
            sys.exit(
                f"Steam refused the update (EResult {result}, see partner.steamgames.com/doc/api/steam_api#EResult)"
            )
        print("Done: preview.gif is now the Workshop preview.")
    finally:
        api.SteamAPI_Shutdown()


if __name__ == "__main__":
    main()
