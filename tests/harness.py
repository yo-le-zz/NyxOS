#!/usr/bin/env python3
"""Run a Lua scenario against the CC:Tweaked mock. Usage: harness.py scenario.lua"""
import os, sys, shutil, tempfile
from lupa import luajit21 as L

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.environ.get("REPO", "/home/claude/nyxos")

def main():
    scenario = sys.argv[1]
    keep = "--keep" in sys.argv
    rt = L.LuaRuntime(encoding="latin-1", unpack_returned_tuples=True)
    sb = tempfile.mkdtemp(prefix="ccsb_")
    rom = tempfile.mkdtemp(prefix="ccrom_")
    def lst(p): return rt.table_from(sorted(os.listdir(p)))
    def rm(p):
        shutil.rmtree(p) if os.path.isdir(p) else os.remove(p)
    def mkdirs(p): os.makedirs(p, exist_ok=True)
    def copy(a, b):
        if os.path.isdir(a): shutil.copytree(a, b)
        else: shutil.copyfile(a, b)
    def move(a, b): shutil.move(a, b)
    def readfile(p):
        with open(p, "rb") as f: return f.read().decode("latin-1")
    def writefile(p, c):
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "wb") as f: f.write(c.encode("latin-1"))
    py = rt.table(
        exists=os.path.exists, isdir=os.path.isdir, listdir=lst, rm=rm, mkdirs=mkdirs, copy=copy, move=move,
        size=lambda p: os.path.getsize(p) if os.path.isfile(p) else 0, dirname=os.path.dirname,
        used=lambda: sum(os.path.getsize(os.path.join(r,f)) for r,_,fs_ in os.walk(sb) for f in fs_),
        readfile=readfile, writefile=writefile,
    )
    g = rt.globals()
    g.SANDBOX, g.ROMDIR, g.PY, g.REPO, g.HARNESS_DIR = sb, rom, py, REPO, HERE
    H = rt.execute(open(os.path.join(HERE, "mock.lua")).read())
    g.H = H
    try:
        rt.execute(open(scenario).read())
    finally:
        if not keep:
            shutil.rmtree(sb, ignore_errors=True); shutil.rmtree(rom, ignore_errors=True)
        else:
            print("SANDBOX:", sb)

main()
