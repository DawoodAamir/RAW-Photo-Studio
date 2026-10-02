"""Create an original linear DNG color chart without camera metadata or dependencies."""
from pathlib import Path
import struct

width, height = 256, 192
pixels = bytearray()
for y in range(height):
    for x in range(width):
        values = (0.08 + 0.7*x/(width-1), 0.08 + 0.7*y/(height-1), 0.3)
        pixels.extend(struct.pack('<HHH', *(int(v*65535) for v in values)))
entries = []
def add(tag, kind, count, data):
    entries.append((tag, kind, count, data))
def short(tag, *values): add(tag, 3, len(values), struct.pack('<'+'H'*len(values), *values))
def long(tag, value): add(tag, 4, 1, struct.pack('<I', value))
def text(tag, value):
    data = value.encode()+b'\0'; add(tag, 2, len(data), data)
def rational(tag, values, signed=False):
    data=b''.join(struct.pack('<ii' if signed else '<II', n,d) for n,d in values)
    add(tag, 10 if signed else 5, len(values), data)
long(254, 0); long(256, width); long(257, height)
short(258, 16,16,16); short(259, 1); short(262, 34892)
text(271, 'Portfolio'); text(272, 'Original linear chart')
long(273,0); short(274,1); short(277,3); long(278,height); long(279,len(pixels)); short(284,1)
add(50706,1,4,bytes([1,4,0,0])); add(50707,1,4,bytes([1,3,0,0])); text(50708,'Portfolio Linear Chart')
short(50714,0); long(50717,65535)
rational(50721,[(1 if i in (0,4,8) else 0,1) for i in range(9)],signed=True)
rational(50728,[(1,1)]*3); short(50778,21)
entries.sort()
extra=bytearray(); table=bytearray(); base=8+2+12*len(entries)+4
for tag,kind,count,data in entries:
    if len(data)>4:
        offset=base+len(extra); extra.extend(data)
        if len(extra)%2:extra.append(0)
        value=struct.pack('<I',offset)
    else:value=data.ljust(4,b'\0')
    table.extend(struct.pack('<HHI',tag,kind,count)+value)
strip_offset=base+len(extra)
for i,(tag,_,_,_) in enumerate(entries):
    if tag==273:table[i*12+8:i*12+12]=struct.pack('<I',strip_offset)
output=Path(__file__).resolve().parents[1]/'Tests/Fixtures/ColorChart.dng'
output.parent.mkdir(parents=True,exist_ok=True)
output.write_bytes(b'II'+struct.pack('<HI',42,8)+struct.pack('<H',len(entries))+table+struct.pack('<I',0)+extra+pixels)
print(output.name, output.stat().st_size, 'bytes')
