#!/usr/bin/env python3
"""Create tiny synthetic animation records; never requires copyrighted game art."""
from pathlib import Path
import sys
import shutil

BASE = {
    'VELE-1.ANI': '00000a0a000006000b0a0000',
    'VFRA-1.ANI': '000000000202000001000200000002020000020004000000020200000000',
    'VLIST-1.ANI': '0000ffff0100ffff0000ffff',
    'VSPR-0.TAB': '000000000202050000000202',
    'VSPR-0.DAT': '04010203040405060708',
    'VSTART-1.ANI': '00000000',
}
def generate(out: Path):
    normal, transparent = out/'source-synthetic', out/'source-transparent'
    palette = bytes(channel for idx in range(256) for channel in (idx % 64,)*3)
    for folder in (normal, transparent):
        folder.mkdir(parents=True, exist_ok=True)
        for name, data in BASE.items():
            if folder == transparent and name == 'VSPR-0.TAB': data = '000000000202060000000202'
            if folder == transparent and name == 'VSPR-0.DAT': data = '0101ff0203040405060708'
            (folder/name).write_bytes(bytes.fromhex(data))
        (folder/'MPALETTE.DAT').write_bytes(palette)
    malformed=out/'malformed'
    shutil.copytree(normal,malformed,dirs_exist_ok=True)
    raw=bytearray((malformed/'VLIST-1.ANI').read_bytes())
    raw[2:4]=b'\x01\x00'
    (malformed/'VLIST-1.ANI').write_bytes(raw)
    fixture=out/'fixture'
    data_dir,qdata_dir=fixture/'DATA',fixture/'QDATA'
    data_dir.mkdir(parents=True,exist_ok=True); qdata_dir.mkdir(parents=True,exist_ok=True)
    for name in ('VSTART-1.ANI','VFRA-1.ANI','VLIST-1.ANI','VELE-1.ANI'):
        shutil.copyfile(normal/name,data_dir/name)
    import struct
    raw,tab=bytearray(),bytearray()
    for kind in range(2):
        pixels=[]
        for y in range(32):
            for x in range(32):
                if kind == 0:
                    value = 1 if (11 <= x < 21 and 5 <= y < 27) or (5 <= x < 27 and 11 <= y < 21) else 255
                    if 11 <= x < 21 and 11 <= y < 21: value = 2
                else:
                    value = 3 if (x-16)**2+(y-16)**2 < 13**2 else 255
                    if (x-16)**2+(y-16)**2 < 7**2: value = 2
                pixels.append(value)
        tab += struct.pack('<IBB',len(raw),32,32)
        for i in range(0,len(pixels),32):
            raw.append(32); raw += bytes(pixels[i:i+32])
    (data_dir/'VSPR-0.TAB').write_bytes(tab)
    (data_dir/'VSPR-0.DAT').write_bytes(raw)
    pal=bytearray(768)
    for index,rgb in {1:(63,8,12),2:(63,63,63),3:(10,32,60)}.items():
        pal[index*3:index*3+3]=bytes(rgb)
    (data_dir/'MPALETTE.DAT').write_bytes(pal)
    ghosts=bytes(range(256))*256
    for name in ('GHOST1.DAT','GHOST2.DAT','GHOST66.DAT'):
        (qdata_dir/name).write_bytes(ghosts)
    assert len(raw)==2112 and len(tab)==12
if __name__=='__main__':
    if len(sys.argv)!=2:raise SystemExit('usage: generate_fixtures.py DIRECTORY')
    generate(Path(sys.argv[1]))
