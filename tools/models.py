import math
import os
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
MEDIA = os.path.join(HERE, "..", "Contents", "mods", "ViewDoctor", "42", "media")
MODELS = os.path.join(MEDIA, "models_X", "ViewDoctor")
TEXTURES = os.path.join(MEDIA, "textures", "ViewDoctor")

HEAD = """xof 0303txt 0032
template ColorRGBA {
 <35ff44e0-6c7c-11cf-8f52-0040333594a3>
 FLOAT red;
 FLOAT green;
 FLOAT blue;
 FLOAT alpha;
}

template ColorRGB {
 <d3e16e81-7835-11cf-8f52-0040333594a3>
 FLOAT red;
 FLOAT green;
 FLOAT blue;
}

template Material {
 <3d82ab4d-62da-11cf-ab39-0020af71e433>
 ColorRGBA faceColor;
 FLOAT power;
 ColorRGB specularColor;
 ColorRGB emissiveColor;
 [...]
}

template TextureFilename {
 <a42790e1-7810-11cf-8f52-0040333594a3>
 STRING filename;
}

template Frame {
 <3d82ab46-62da-11cf-ab39-0020af71e433>
 [...]
}

template Matrix4x4 {
 <f6f23f45-7686-11cf-8f52-0040333594a3>
 array FLOAT matrix[16];
}

template FrameTransformMatrix {
 <f6f23f41-7686-11cf-8f52-0040333594a3>
 Matrix4x4 frameMatrix;
}

template Vector {
 <3d82ab5e-62da-11cf-ab39-0020af71e433>
 FLOAT x;
 FLOAT y;
 FLOAT z;
}

template MeshFace {
 <3d82ab5f-62da-11cf-ab39-0020af71e433>
 DWORD nFaceVertexIndices;
 array DWORD faceVertexIndices[nFaceVertexIndices];
}

template Mesh {
 <3d82ab44-62da-11cf-ab39-0020af71e433>
 DWORD nVertices;
 array Vector vertices[nVertices];
 DWORD nFaces;
 array MeshFace faces[nFaces];
 [...]
}

template MeshNormals {
 <f6f23f43-7686-11cf-8f52-0040333594a3>
 DWORD nNormals;
 array Vector normals[nNormals];
 DWORD nFaceNormals;
 array MeshFace faceNormals[nFaceNormals];
}

template MeshMaterialList {
 <f6f23f42-7686-11cf-8f52-0040333594a3>
 DWORD nMaterials;
 DWORD nFaceIndexes;
 array DWORD faceIndexes[nFaceIndexes];
 [Material <3d82ab4d-62da-11cf-ab39-0020af71e433>]
}

template Coords2d {
 <f6f23f44-7686-11cf-8f52-0040333594a3>
 FLOAT u;
 FLOAT v;
}

template MeshTextureCoords {
 <f6f23f40-7686-11cf-8f52-0040333594a3>
 DWORD nTextureCoords;
 array Coords2d textureCoords[nTextureCoords];
}

"""


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def unit(a):
    l = math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2])
    if l < 1e-12:
        return (0.0, 1.0, 0.0)
    return (a[0] / l, a[1] / l, a[2] / l)


class Mesh:
    def __init__(self):
        self.tris = []

    def tri(self, a, b, c, both=False):
        self.tris.append((a, b, c))
        if both:
            self.tris.append((a, c, b))

    def quad(self, a, b, c, d, both=False):
        self.tri(a, b, c, both)
        self.tri(a, c, d, both)

    def fan(self, centre, rim, both=False):
        for i in range(len(rim)):
            self.tri(centre, rim[i], rim[(i + 1) % len(rim)], both)

    def tube(self, rings, caps=True):
        for r in range(len(rings) - 1):
            a, b = rings[r], rings[r + 1]
            n = len(a)
            for i in range(n):
                j = (i + 1) % n
                self.quad(a[i], b[i], b[j], a[j])
        if caps:
            first, last = rings[0], rings[-1]
            for i in range(1, len(first) - 1):
                self.tri(first[0], first[i + 1], first[i])
                self.tri(last[0], last[i], last[i + 1])

    def box(self, lo, hi):
        x0, y0, z0 = lo
        x1, y1, z1 = hi
        ring = lambda x: [(x, y0, z0), (x, y1, z0), (x, y1, z1), (x, y0, z1)]
        self.tube([ring(x0), ring(x1)])


def ring(x, radius, sides, squash=1.0, start=0.0):
    out = []
    for i in range(sides):
        a = start + 2 * math.pi * i / sides
        out.append((x, math.cos(a) * radius * squash, math.sin(a) * radius))
    return out


def gash():
    m = Mesh()
    rim = []
    for i in range(12):
        a = 2 * math.pi * i / 12
        rim.append((math.cos(a) * 0.05, 0.0012, -math.sin(a) * 0.011))
    m.fan((0.0, 0.0022, 0.0), rim, True)
    return m


def disc(radius, sides=8, height=0.001):
    m = Mesh()
    rim = [(math.cos(2 * math.pi * i / sides) * radius, height, -math.sin(2 * math.pi * i / sides) * radius) for i in range(sides)]
    m.fan((0.0, height, 0.0), rim, True)
    return m


def stitch():
    m = Mesh()
    rings = []
    for i in range(5):
        a = math.pi * i / 4
        cx, cy = -math.cos(a) * 0.009, math.sin(a) * 0.006 + 0.0005
        nx, ny = -math.cos(a), math.sin(a)
        r = 0.002
        rings.append([
            (cx + nx * r, cy + ny * r, 0.0),
            (cx - nx * r * 0.5, cy - ny * r * 0.5, r),
            (cx - nx * r * 0.5, cy - ny * r * 0.5, -r),
        ])
    m.tube(rings)
    return m


def rod(radius, sides=6):
    m = Mesh()
    m.tube([ring(-0.5, radius, sides), ring(0.5, radius, sides)], False)
    return m


def shard():
    m = Mesh()
    base = [(0.0, 0.004, 0.0015), (0.0, -0.001, 0.005), (0.0, -0.004, -0.001), (0.0, 0.001, -0.0045)]
    mid = [(0.028, 0.0045, 0.002), (0.03, -0.0015, 0.0035), (0.026, -0.003, -0.002), (0.031, 0.002, -0.003)]
    tip = (0.05, 0.0008, 0.0004)
    m.tube([base, mid], False)
    for i in range(4):
        m.tri(mid[i], tip, mid[(i + 1) % 4])
    m.tri(base[0], base[2], base[1])
    m.tri(base[0], base[3], base[2])
    return m


def bullet():
    m = Mesh()
    r = 0.0028
    m.tube([ring(0.0, r, 6), ring(0.008, r, 6), ring(0.0105, r * 0.6, 6)], False)
    last = ring(0.0105, r * 0.6, 6)
    for i in range(6):
        m.tri(last[i], (0.012, 0.0, 0.0), last[(i + 1) % 6])
    first = ring(0.0, r, 6)
    for i in range(1, 5):
        m.tri(first[0], first[i + 1], first[i])
    return m


def hole():
    m = Mesh()
    inner, outer = [], []
    for i in range(8):
        a = 2 * math.pi * i / 8
        inner.append((math.cos(a) * 0.0045, 0.0022, -math.sin(a) * 0.0045))
        outer.append((math.cos(a) * 0.007, 0.0006, -math.sin(a) * 0.007))
    m.fan((0.0, 0.0008, 0.0), inner, True)
    for i in range(8):
        j = (i + 1) % 8
        m.quad(inner[i], outer[i], outer[j], inner[j], True)
    return m


def band(half, arc, lift, segments=4):
    m = Mesh()
    r = 1.0 + lift
    for i in range(segments):
        a0 = -arc / 2 + arc * i / segments
        a1 = -arc / 2 + arc * (i + 1) / segments
        p0 = (-half, math.cos(a0) * r - 1.0, math.sin(a0) * r)
        p1 = (half, math.cos(a0) * r - 1.0, math.sin(a0) * r)
        p2 = (half, math.cos(a1) * r - 1.0, math.sin(a1) * r)
        p3 = (-half, math.cos(a1) * r - 1.0, math.sin(a1) * r)
        m.quad(p0, p3, p2, p1, True)
    return m


def patch():
    m = Mesh()
    rim = []
    for i, k in enumerate([1.0, 0.8, 0.95, 0.7, 1.0, 0.85, 0.9, 0.75, 0.95]):
        a = 2 * math.pi * i / 9
        rim.append((math.cos(a) * 0.015 * k, 0.001, -math.sin(a) * 0.012 * k))
    m.fan((0.0, 0.0016, 0.0), rim, True)
    return m


def board():
    m = Mesh()
    m.box((-0.11, 0.0, -0.015), (0.11, 0.008, 0.015))
    return m


def swab():
    m = Mesh()
    m.tube([ring(0.012, 0.0014, 4), ring(0.09, 0.0014, 4)])
    m.tube([ring(0.0, 0.003, 6), ring(0.007, 0.0045, 6), ring(0.014, 0.003, 6)])
    return m


def syringe():
    m = Mesh()
    m.tube([ring(0.0, 0.0003, 3), ring(0.03, 0.0006, 3)], False)
    m.tube([ring(0.03, 0.002, 6), ring(0.033, 0.005, 6), ring(0.075, 0.005, 6)])
    m.tube([ring(0.075, 0.0018, 4), ring(0.096, 0.0018, 4)], False)
    m.box((0.096, -0.007, -0.007), (0.1, 0.007, 0.007))
    return m


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def noise(x, y, seed):
    n = (x * 374761393 + y * 668265263 + seed * 2147483647) & 0xffffffff
    n = ((n ^ (n >> 13)) * 1274126177) & 0xffffffff
    return ((n ^ (n >> 16)) & 0xff) / 255.0


def flat(colour, spread, seed):
    def pixel(x, y):
        k = 1.0 + (noise(x, y, seed) - 0.5) * spread
        return tuple(max(0, min(255, int(c * k))) for c in colour)
    return pixel


def radial(centre, edge, spread, seed):
    def pixel(x, y):
        d = min(1.0, math.hypot(x - 7.5, y - 7.5) / 7.5)
        c = mix(centre, edge, d)
        k = 1.0 + (noise(x, y, seed) - 0.5) * spread
        return tuple(max(0, min(255, int(v * k))) for v in c)
    return pixel


def stripes(a, b, seed):
    def pixel(x, y):
        c = a if (x // 2) % 2 == 0 else b
        k = 1.0 + (noise(x, y, seed) - 0.5) * 0.08
        return tuple(max(0, min(255, int(v * k))) for v in c)
    return pixel


MODELS_LIST = {
    "VD_Gash": gash,
    "VD_Dot": lambda: disc(0.004),
    "VD_Stitch": stitch,
    "VD_Thread": lambda: rod(0.035),
    "VD_Vein": lambda: rod(0.06),
    "VD_Shard": shard,
    "VD_Bullet": bullet,
    "VD_Hole": hole,
    "VD_Wrap": lambda: band(0.3, 0.46, 0.05),
    "VD_Cut": lambda: band(0.06, 0.46, 0.03),
    "VD_Patch": patch,
    "VD_Board": board,
    "VD_Swab": swab,
    "VD_Syringe": syringe,
}

TEXTURE_LIST = {
    "VD_Gash": radial((60, 4, 6), (150, 22, 20), 0.2, 1),
    "VD_Dot": flat((235, 196, 92), 0.1, 2),
    "VD_Stitch": flat((236, 228, 205), 0.1, 3),
    "VD_Thread": flat((236, 228, 205), 0.1, 4),
    "VD_Vein": flat((70, 96, 190), 0.15, 5),
    "VD_Shard": radial((205, 238, 250), (150, 205, 225), 0.2, 6),
    "VD_Bullet": flat((176, 132, 62), 0.2, 7),
    "VD_Hole": radial((24, 2, 3), (120, 20, 18), 0.2, 8),
    "VD_Wrap": stripes((238, 234, 222), (212, 206, 190), 9),
    "VD_Cut": radial((70, 4, 6), (130, 16, 14), 0.25, 10),
    "VD_Patch": radial((80, 54, 26), (104, 74, 38), 0.35, 11),
    "VD_Burn": radial((70, 30, 24), (150, 70, 52), 0.35, 12),
    "VD_Glow": radial((255, 226, 150), (240, 110, 30), 0.1, 13),
    "VD_Board": stripes((150, 112, 70), (132, 96, 58), 14),
    "VD_Swab": radial((244, 242, 236), (214, 208, 196), 0.08, 15),
    "VD_Syringe": flat((205, 222, 232), 0.12, 16),
}


def write_model(name, mesh):
    xs = [p[0] for t in mesh.tris for p in t]
    zs = [p[2] for t in mesh.tris for p in t]
    x0, x1, z0, z1 = min(xs), max(xs), min(zs), max(zs)
    verts, normals, faces, coords = [], [], [], []
    for t in mesh.tris:
        n = unit(cross(sub(t[1], t[0]), sub(t[2], t[0])))
        base = len(verts)
        for p in t:
            verts.append(p)
            normals.append(n)
            u = 0.5 if x1 - x0 < 1e-9 else (p[0] - x0) / (x1 - x0)
            v = 0.5 if z1 - z0 < 1e-9 else (p[2] - z0) / (z1 - z0)
            coords.append((0.03 + 0.94 * u, 0.03 + 0.94 * v))
        faces.append((base, base + 1, base + 2))
    vec = lambda l: ",\n".join("   %.6f;%.6f;%.6f;" % p for p in l) + ";"
    fac = lambda l: ",\n".join("   3;%d,%d,%d;" % f for f in l) + ";"
    body = HEAD + "Material Mat_%s {\n 1.000000;1.000000;1.000000;1.000000;;\n 9.999999;\n 0.000000;0.000000;0.000000;;\n 0.000000;0.000000;0.000000;;\n TextureFilename {\n  \"%s.png\";\n }\n}\n" % (name, name)
    body += "Frame %s {\n FrameTransformMatrix {\n  1.000000,0.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,0.000000,1.000000;;\n }\n Mesh %s {\n" % (name, name)
    body += "  %d;\n%s\n  %d;\n%s\n" % (len(verts), vec(verts), len(faces), fac(faces))
    body += "  MeshNormals {\n   %d;\n%s\n   %d;\n%s\n  }\n" % (len(normals), vec(normals), len(faces), fac(faces))
    body += "  MeshMaterialList {\n   1;\n   %d;\n%s;\n   { Mat_%s }\n  }\n" % (len(faces), ",\n".join("   0" for _ in faces), name)
    body += "  MeshTextureCoords c1 {\n   %d;\n%s\n  }\n }\n}\n" % (len(coords), ",\n".join("   %.6f;%.6f;" % c for c in coords) + ";")
    with open(os.path.join(MODELS, name + ".x"), "w") as f:
        f.write(body)


def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)


def write_texture(name, pixel):
    raw = b""
    for y in range(16):
        raw += b"\x00" + b"".join(bytes(pixel(x, y)) + b"\xff" for x in range(16))
    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 16, 16, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(os.path.join(TEXTURES, name + ".png"), "wb") as f:
        f.write(data)


def numbers(block):
    return [float(v) for v in block.replace(",", ";").split(";") if v.strip()]


def check():
    for name in MODELS_LIST:
        text = open(os.path.join(MODELS, name + ".x")).read()
        assert text.startswith("xof 0303txt 0032"), name + ": header"
        mesh = text[text.index("Mesh " + name + " {") + len("Mesh " + name + " {"):]
        lines = [l.strip() for l in mesh.split("\n") if l.strip()]
        count = int(lines[0].rstrip(";"))
        assert 3 <= count < 200, name + ": %d vertices" % count
        for l in lines[1:1 + count]:
            vals = numbers(l)
            assert len(vals) == 3 and all(v == v and abs(v) < 10 for v in vals), name + ": vertex " + l
        faces = int(lines[1 + count].rstrip(";"))
        assert faces * 3 == count, name + ": face count"
        for l in lines[2 + count:2 + count + faces]:
            vals = numbers(l)
            assert vals[0] == 3 and all(0 <= v < count for v in vals[1:]), name + ": face " + l
        assert "MeshNormals" in mesh and "MeshTextureCoords" in mesh, name + ": normals and coords"
        assert "nan" not in mesh.lower(), name + ": NaN"
    for name in TEXTURE_LIST:
        data = open(os.path.join(TEXTURES, name + ".png"), "rb").read()
        assert data[:8] == b"\x89PNG\r\n\x1a\n", name + ": signature"
        assert struct.unpack(">II", data[16:24]) == (16, 16), name + ": size"
    for name in MODELS_LIST:
        assert name in TEXTURE_LIST, name + ": texture missing"
    print("models ok")


def main():
    if "--check" in sys.argv:
        check()
        return
    os.makedirs(MODELS, exist_ok=True)
    os.makedirs(TEXTURES, exist_ok=True)
    for name, build in MODELS_LIST.items():
        write_model(name, build())
    for name, pixel in TEXTURE_LIST.items():
        write_texture(name, pixel)


main()
