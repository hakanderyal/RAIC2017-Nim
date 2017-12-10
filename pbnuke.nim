from pbehavior import PlayerBehavior
from groupcounter import GroupCounter

proc initPBNuke*(gc: var GroupCounter): PlayerBehavior

from analyze import WorldState, Players
from actions import nuke, group, ungroup, newSelection, actMove
from actionchain import initActionChain
from condactions import atNukeEnd
from enhanced import Group
from groupcounter import getFreeGroup
from gparams import flyers
from model.move import Move
from math import floor
from pbehavior import PBResult, PBRType
from vehicles import resolve
from utils import debug, getSqDistance, areaFromUnits

proc initPBNuke(gc: var GroupCounter): PlayerBehavior =
  let nukegroup = gc.getFreeGroup()
  var added = false
  result.tick = proc(ws: WorldState,gc:var GroupCounter,m:var Move): PBResult =
    let me = ws.players[Players.me]
    if me.next_nuclear_strike_tick_index > 0 or
       me.remainingNuclearStrikeCooldownTicks > 0:
      added = false
      return PBResult(kind: PBRType.empty)
    if added:
      return PBResult(kind: PBRType.empty)
    let v = ws.vehicles
    let sqNukeRadius = ws.game.tacticalNuclearStrikeRadius *
                       ws.game.tacticalNuclearStrikeRadius
    let sqVision = ws.game.fighterVisionRange * ws.game.fighterVisionRange
    debug("Vision: " & $sqVision)
    debug("NR: " & $sqNukeRadius)
    for mc in v.byMyAerialCluster & v.byMyGroundCluster:
      let vplusc = (distanceToCenter: 1.0, point: mc.center) & @(mc.vertices)
      for ec in v.byEnemyCluster:
        for vv in vplusc:
          if vv.distanceToCenter == 0:
            continue
          let distance = ec.center.getSqDistance(vv.point)
          if distance > 4*vv.distanceToCenter*vv.distanceToCenter + sqVision:
            break
          debug("Distance to enemy cluster center: " & $distance)
          if distance < sqVision * 0.9 and distance > sqNukeRadius:
            debug("Iterating over units")
            let units = v.resolve(mc.cluster)
            for u in units:
              if u.durability == 0:
                continue
              let pu = (x: u.x, y: u.y)
              let sqdistance = pu.getSqDistance(ec.center)
              let is_flyer = u.thetype.ord in flyers
              let celltype =
                if is_flyer:
                  ws.world.weatherByCellXY[int(floor(u.x/32))][int(floor(u.y/32))]
                    .ord
                else:
                  ws.world.terrainByCellXY[int(floor(u.x/32))][int(floor(u.y/32))]
                    .ord
              let vision = ws.gparams.visionByType[u.thetype.ord] *
                           ws.gparams.visionFactorsByEnv[int(is_flyer)][celltype]
              if sqdistance < vision * vision:
                var oldgroup: Group = 0
                let area = (left: u.x-1, right: u.x+1, top: u.y-1, bottom: u.y+1)
                let emptymove = (x: 0.00001, y: 0.00001)
                for g in u.groups:
                  oldgroup = g
                  break
                var actionChain = @[newSelection(area, u.thetype)]
                if oldgroup > 0.Group:
                  actionChain.add(ungroup(oldgroup))
                actionChain &= @[
                  actMove(emptymove),
                  nuke(ec.center, u.id),
                  group(nukegroup),
                  atNukeEnd(Players.me),
                  newSelection(nukegroup)
                ]
                if oldgroup > 0.Group:
                  actionChain.add(group(oldgroup))
                actionChain.add(ungroup(nukegroup))
                added = true
                return PBResult(kind: PBRType.addPBehavior,
                                behavior: initActionChain(actionChain))
