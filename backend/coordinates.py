"""GCJ02 <-> WGS84, adapted from eviltransform (BSD-2-Clause)."""
import math
from route_engine import Point

def outside_china(p):
    return not (72.004 <= p.longitude <= 137.8347 and 0.8293 <= p.latitude <= 55.8271)

def wgs_to_gcj(p):
    if outside_china(p): return p
    x,y = p.longitude-105, p.latitude-35
    shared=(20*math.sin(6*x*math.pi)+20*math.sin(2*x*math.pi))*2/3
    lat=-100+2*x+3*y+.2*y*y+.1*x*y+.2*math.sqrt(abs(x))
    lat+=shared+(20*math.sin(y*math.pi)+40*math.sin(y*math.pi/3))*2/3
    lat+=(160*math.sin(y*math.pi/12)+320*math.sin(y*math.pi/30))*2/3
    lon=300+x+2*y+.1*x*x+.1*x*y+.1*math.sqrt(abs(x))
    lon+=shared+(20*math.sin(x*math.pi)+40*math.sin(x*math.pi/3))*2/3
    lon+=(150*math.sin(x*math.pi/12)+300*math.sin(x*math.pi/30))*2/3
    rad=math.radians(p.latitude); ee=.00669342162296594323; a=6378137.0
    magic=1-ee*math.sin(rad)**2; root=math.sqrt(magic)
    return Point(p.latitude+lat*180/((a*(1-ee))/(magic*root)*math.pi),
                 p.longitude+lon*180/(a/root*math.cos(rad)*math.pi))

def gcj_to_wgs(p):
    if outside_china(p):return p
    guess=p
    for _ in range(15):
        forward=wgs_to_gcj(guess)
        dlat,dlon=forward.latitude-p.latitude,forward.longitude-p.longitude
        guess=Point(guess.latitude-dlat,guess.longitude-dlon)
        if max(abs(dlat),abs(dlon))<1e-10:break
    return guess
