from utils import Point
from borders import Vertex
from enhanced import EVehicle, Group, VehicleId
from analyze import WorldState
from tables import Table

type
  PartInfo* = tuple
    center: Point
    vertices: array[16, Vertex]
    units: seq[EVehicle]
  FormationInfo* = tuple
    center: Point
    vertices: array[16, Vertex]
    units: seq[EVehicle]
    maxspeed: float
    associatedClusters: Table[int, PartInfo]

proc updateFormationInfo*(self: Group, ws: WorldState, isAerial: bool): FormationInfo

from vehicles import resolve, toGroup
from borders import obtainCenter, obtainBorders
from fastset import intersects, empty, `-`, FastSet
from tables import `[]`, initTable, `[]=`
from model.vehicle_type import VehicleType
from gparams import flyers

proc getMaxSpeed(ws: WorldState, units: FastSet[VehicleId]): float =
  result = 1000
  for t in VehicleType.ARRV..VehicleType.TANK:
    if units.intersects(ws.vehicles.byType[t]):
      let env = int(t.ord in flyers)
      result = min(ws.gparams.speedByType[t.ord] * ws.gparams.speedFactorsByEnv[env][1+env], result)

proc updateFormationInfo(self: Group, ws: WorldState, isAerial: bool): FormationInfo =
  let uset = ws.vehicles.byGroup[self]
  result.units = ws.vehicles.resolve(uset)
  if result.units.len() == 0:
    return
  result.maxspeed = getMaxSpeed(ws, uset)
  result.center = obtainCenter(result.units)
  result.vertices = obtainBorders(result.center, result.units)
  let clusters = 
    if isAerial: ws.vehicles.byMyAerialCluster
    else: ws.vehicles.byMyGroundCluster
  result.associatedClusters = initTable[int, PartInfo]()
  for i, c in clusters.pairs():
    if c.cluster.intersects(uset):
      let remains = c.cluster - uset
      if not remains.empty:
        var pi: PartInfo
        pi.units = ws.vehicles.resolve(remains)
        pi.center = obtainCenter(pi.units)
        pi.vertices = obtainBorders(pi.center, pi.units)
        result.associatedClusters[i] = pi

