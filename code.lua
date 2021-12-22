-- author: BOOtak
-- name: Paw Noir

T=8
W=240
H=136

MAP_W=30
MAP_H=17

sf=string.format

DEBUG=false

SPAWNX=10
SPAWNY=80

LEVEL_SPRITES={15,31,47,63,79,95,111,127}
LEVELS=#LEVEL_SPRITES

ST={
  STAND=1,
  RUN=2,
  JUMP=3,
  DIE=4,
  DEAD=5,
  SHOOT=6
}

DIR={
  L=1,
  R=2
}

-- animation helpers
function make_tex(c0,w,h)
  tex={}
  for i=1,h do
    tex[i]={}
    for j=1,w do
      tex[i][j]=c0 + (j-1) + (i-1)*16
    end
  end
  return tex
end

function mul_tex(tex,count)
  h,w=#tex,#(tex[1])
  for i=1,h do
    for j=1,count-1 do
      for k=1,w do
        table.insert(tex[i], tex[i][k])
      end
    end
  end
  return tex
end

function make_anim(c0,w,h,count)
  anim = {}
  for i=1,count do
    anim[i] = make_tex(c0 + (i-1)*w, w, h)
  end
  return anim
end

bg0={x=0,y=0,
  sp=mul_tex(make_tex(132,6,4),6),
  parallax=0.7,
  off=48,
  offVal=0
}

bg1={
  x=0,y=40,
  sp=mul_tex(make_tex(32,13,6),4),
  parallax=0.6,
  off=104,
  offVal=0
}

Player = {
  x=0,
  y=0,
  cr={x=1,y=0,w=14,h=24},
  vx=0,
  vy=0,
  rigid=true,
  mass=true,
  state=ST.STAND,
  dir=DIR.R,
  can_die=true,
  lives=9,
  anim={tick=0,speed=0.13,sp={
    [ST.STAND]=make_anim(280, 2, 3, 1),
    [ST.RUN]=make_anim(272, 2, 3, 4),
    [ST.JUMP]=make_anim(284, 2, 3, 1),
    [ST.DIE]=make_anim(286,2,3,1),
    [ST.DEAD]=make_anim(286,2,3,1)
  }},
  ctrl=true
}

Flag={
  x=103*T,
  y=4*T,
  vx=0,vy=0,
  cr={x=8,y=8,w=16,h=16},
  anim={tick=0,speed=0.1,sp=make_anim(373,4,4,2)}
}

Corpse = {
  x=0,
  y=0,
  cr={x=0,y=11,w=24,h=13},
  vx=0,
  vy=0,
  rigid=true,
  mass=true,
  grabbable=true,
  anim={tick=0,speed=0.1,sp=make_anim(320,3,3,3)}
}

Bullet={
  x=0,
  y=0,
  cr={x=1,y=1,w=6,h=6},
  vx=0,
  vy=0,
  rigid=false,
  mass=false,
  bullet={penetr=false},
  dir=DIR.R,
  sp=make_tex(416,1,1)
}

Enemy = {
  x=0,
  y=0,
  cr={x=1,y=0,w=14,h=24},
  vx=0,
  vy=0,
  rigid=true,
  mass=true,
  follow=true,
  dir=DIR.L,
  state=ST.STAND,
  shoot={e=Bullet,dy=10,sp=1,cd=10,tick=0,row=3,crow=0,cpause=0,pause=90},
  anim={tick=0,speed=0.13,sp={
    [ST.SHOOT]=make_anim(368,2,3,2),
    [ST.STAND]=make_anim(368,2,3,1)
  }},
  sp=make_tex(368,2,3)
}

JMP_IMP=2.8
ACCEL=0.2
OVERJMP_ACC=0.1

cam={x=W//2,y=0}

-- tile types
solid_sprites_index = 208
spikeFirst=192
spikeLast=196
spawnId0=1
spawnId1=147

BTN_UP=0
BTN_DOWN=1
BTN_LEFT=2
BTN_RIGHT=3
BTN_Z=4
BTN_X=5

function vec2(xV, yV)
  return {x=xV,y=yV}
end

function v2mul(v, s)
  return vec2(v.x*s, v.y*s)
end

function v2div(v,s)
  return vec2(v.x/s, v.y/s)
end

function v2add(v1, v2)
  return vec2(v1.x+v2.x,v1.y+v2.y)
end

function sign(x) return x>0 and 1 or x<0 and -1 or 0 end

function deepcopy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
    copy = {}
    for orig_key, orig_value in next, orig, nil do
      copy[deepcopy(orig_key)] = deepcopy(orig_value)
    end
    setmetatable(copy, deepcopy(getmetatable(orig)))
  else -- number, string, boolean, etc
    copy = orig
  end
  return copy
end

function removeFrom(tab,obj,toDel)
  obj.__rem=true
  obj.__del=toDel
end

function cleanup(tab)
  for i = #tab, 1, -1 do
    obj=tab[i]
    if obj.__rem then
      obj.__rem=false
      table.remove(tab, i)
      if obj.__del then obj=nil end
    end
  end
end

SPAWNED_ENEMIES = {}
function isEnemySpawned(c,r)
  for i,v in ipairs(SPAWNED_ENEMIES) do
    if v.x == c and v.y == r then return true end
  end
  return false
end

function spawnEnemy(c,r)
  if not isEnemySpawned(c,r) then
    table.insert(SPAWNED_ENEMIES, (vec2(c,r)))
    en = deepcopy(Enemy)
    en.x,en.y=c*T,r*T
    table.insert(ENTITIES, en)
  end
end

-- buttons state
btn_st={
  [BTN_UP]=false,
  [BTN_LEFT]=false,
  [BTN_RIGHT]=false,
  [BTN_Z]=false
}

-- tile helpers
function IsTileSolid(x, y)
  tileId = mget(x, y)
  return (tileId >= solid_sprites_index)
end

function isTilsSpawner(x,y)
  tileId=mget(x,y)
  return tileId == spawnId0 or tileId==spawnId1
end

function isTileSpike(x,y)
  id = mget(x,y)
  return id>=spikeFirst and id <=spikeLast
end

function animate(e)
  if e.anim == nil then return end
  local anim=e.anim.sp
  if e.state ~= nil then anim=e.anim.sp[e.state] end
  e.sp=anim[(math.floor(e.anim.tick)%#anim)+1]
  e.anim.tick = e.anim.tick+e.anim.speed
end

function drawEnt(e,cam)
  local i=1
  local dx,dy=0,0
  if cam ~= nil then dx,dy = cam.x,cam.y end
  for i,t in ipairs(e.sp) do
    for j,v in ipairs(t) do
      if e.dir == nil or e.dir == DIR.R then
        spr(v, e.x+(j-1)*T-dx, e.y+(i-1)*T-dy, 0)
      else
        tlen = #t
        spr(v, e.x+(tlen-j)*T-dx, e.y+(i-1)*T-dy, 0, 1, 1)
      end
    end
  end
end

function intersect(e1,e2)
  return (e1.x+e1.cr.x < e2.x+e2.cr.x+e2.cr.w and e2.x+e2.cr.x < e1.x+e1.cr.x+e1.cr.w) and
    (e1.y+e1.cr.y < e2.y+e2.cr.y+e2.cr.h and e2.y+e2.cr.y < e1.y+e1.cr.y+e1.cr.h)
end

function collide(e1,e2)
  return e2.rigid and intersect(e1, e2)
end

function handleInput()
  local iv={pos=vec2(0,0), jump=false}
  if btn(BTN_LEFT) then
    iv.pos.x = -1
  elseif btn(BTN_RIGHT) then
    iv.pos.x = 1
  end
  if btnp(BTN_UP) then
    iv.jump=true
  end
  return iv
end

--callback(c,r)
function collideTile(dp,cr,callback)
  local x1 = dp.x + cr.x
  local y1 = dp.y + cr.y
  local x2 = x1 + cr.w - 1
  local y2 = y1 + cr.h - 1
  -- check all tiles touched by the rect
  local startC = x1 // T
  local endC = x2 // T
  local startR = y1 // T
  local endR = y2 // T
  for c = startC, endC do
    for r = startR, endR do
      callback(c,r)
    end
  end
end

function CanMove(dp,e)
  local cm=true
  collideTile(dp,e.cr, function(c,r)
    if IsTileSolid(c, r) then
      cm=false
      return
    end
  end)
  for i,en in ipairs(ENTITIES) do
    if e ~= en and collide({x=dp.x,y=dp.y,cr=e.cr},en) then return false end
  end
  return cm
end

function isOnFloor(e)
  return not CanMove(vec2(e.x,e.y+1),e) and e.vy >= 0
end

function isUnderCeiling(e)
  return not CanMove(vec2(e.x,e.y-1),e)
end

function isTouchSpikeTiles(e)
  ts=false
  collideTile(vec2(e.x,e.y),e.cr,function(c,r)
    if isTileSpike(c,r) then ts=true end
  end)
  return ts
end

function TryMoveBy(e,dp)
  local pos=vec2(e.x, e.y)
  if (e.rigid) then
    local dx,dy=0,0
    for i=0,math.ceil(dp.y),sign(dp.y) do
      if dx == 0 then
        for j=0,math.ceil(dp.x),sign(dp.x) do
          if CanMove(vec2(e.x+j,e.y+i),e) and dp.x~=0 then
            dx=j
          else
            break
          end
        end
      end
      if CanMove(vec2(e.x+dx,e.y+i),e) and dp.y ~= 0 then
        dy=i
      end
      if dp.y==0 then break end
    end
    e.x=e.x+dx
    e.y=e.y+dy
  else
    e.x=e.x+dp.x
    e.y=e.y+dp.y
  end
end

function die(e)
  if e.state ~= ST.DEAD then e.state=ST.DIE end
end

function update(e)
  if e.grab_by ~= nil then return end
  local iv={pos=vec2(e.vx,e.vy), jump=false}
  if e.ctrl then iv=handleInput() end
  if e.mass then
    if e.rigid and isOnFloor(e) then
      if iv.jump then
        e.vy=-1*JMP_IMP
      else
        e.vy=0
      end
    elseif e.rigid and isUnderCeiling(e) and e.vy < 0 then
      e.vy=0
    elseif e.ctrl and btn(BTN_UP) and e.vy < 0 then
      e.vy=e.vy+OVERJMP_ACC
    else
      e.vy = e.vy+ACCEL
    end
  end

  e.vx=iv.pos.x
  local dp=vec2(e.vx, e.vy)
  if e.grabbed ~= nil then
    gr=e.grabbed
    if (dp.x < 0 and e.x < gr.x) or (dp.x > 0 and e.x > gr.x) then
      TryMoveBy(e,dp)
      TryMoveBy(gr,dp)
    else
      TryMoveBy(gr,dp)
      TryMoveBy(e,dp)
    end
  else
    TryMoveBy(e,dp)
  end
end

function handleState(e)
  if e.oldState ~= e.state then initState(e) end
  local st=e.state
  if e.state == nil then return nil end
  if e.state == ST.RUN then
    if e.vy ~= 0 then st=ST.JUMP
    elseif e.vx == 0 then st=ST.STAND end
  end
  if e.state == ST.STAND then
    if e.vy ~= 0 then st=ST.JUMP
    elseif e.vx ~= 0 then st=ST.RUN end
  end
  if e.state == ST.JUMP then
    if isOnFloor(e) then st=ST.STAND end
  end
  if e.state == ST.DIE then
    if e.vx == 0 then
      if e.dieTick <= 0 then
        st=ST.DEAD
      else
        e.dieTick = e.dieTick-1
      end
    end
  end
  if e.state == ST.DEAD then
    if e.deadT <= 0 then
      respawn(e)
      st=ST.STAND
    else
      e.deadT = e.deadT-1
    end
  end

  e.oldState = e.state
  e.state = st
end

function initState(e)
  if e.state == ST.DIE then
    e.dieTick = 10
    if e.ctrl ~= nil then e.ctrl = false end
    e.vx=0
  end
  if e.state == ST.DEAD then
    e.deadT = 60
    e.lives=e.lives-1
    if e.lives <= 0 then mode=MOD_FAIL end
    removeFrom(ENTITIES, e, false)
    spawnCorpse(e)
  end
end

function spawnBullet(be,bsp,e)
  newb=deepcopy(be)
  newb.dir=e.dir
  if e.dir == nil or e.dir == DIR.R then
    newb.x=e.x+e.cr.w+1
    newb.vx=e.shoot.sp
  else
    newb.x=e.x-newb.cr.w-1
    newb.vx=-1*e.shoot.sp
  end
  newb.y=e.y+e.shoot.dy
  table.insert(ENTITIES, newb)
end

function handleBullet(e,cam)
  if e.bullet == nil then return end
  for i,en in ipairs(ENTITIES) do
    if collide(e,en) and e ~= en then
      if not e.bullet.penetr then
        removeFrom(ENTITIES, e, true)
      end
      if en.can_die then die(en) end
      return
    end
  end
  if not inViewPort(e,cam) then
    removeFrom(ENTITIES, e, true)
  end
end

function handleFollow(e,target)
  if e.follow == nil then return end
  if e.x < target.x then e.dir=DIR.R
  elseif e.x > target.x then e.dir=DIR.L
  end
end

function handleShoot(e)
  if e.shoot == nil then return end
  sh = e.shoot
  -- shoot={e=Bullet,dy=8,sp=1,cd=10,tick=0,row=3,crow=0,cpause=0,pause=40},
  if sh.cpause == 0 then
    sh.newPause=sh.pause-sh.pause//2+math.random(sh.pause)
    e.state=ST.SHOOT
    if sh.tick % sh.cd == 1 then
      spawnBullet(sh.e,sh.sp,e)
    end
    if sh.tick >= sh.cd*sh.row then
      sh.cpause=sh.cpause+1
      sh.tick=0
    else
      sh.tick=sh.tick+1
    end
  else
    e.state=ST.STAND
    sh.cpause=sh.cpause+1
    if sh.cpause >= sh.newPause then sh.cpause = 0 end
  end
end

function handleParallax(bg,cam)
  -- if bg.x+cam.x > -1*bg.off then bg.offVal = bg.offVal - bg.off
  -- elseif bg.x+cam.x < -1*bg.off then bg.offVal = bg.offVal + bg.off end
  local pr=-cam.x * bg.parallax
  bg.x = -1 * pr + ((pr+cam.x) // bg.off) * bg.off
end

function updateDir(e)
  if e.dir == nil then return nil end
  if e.vx > 0 then return DIR.R
  elseif e.vx < 0 then return DIR.L
  else return e.dir
  end
end

function respawn(e)
  e.x,e.y = SPAWNX,SPAWNY
  if e.ctrl ~= nil then e.ctrl = true end
  e.state=ST.STAND
  table.insert(ENTITIES, e)
end

function spawnCorpse(e)
  new_ent = deepcopy(Corpse)
  -- TODO: try to spawn corpse in empty position
  new_ent.x, new_ent.y = e.x, e.y
  table.insert(ENTITIES, new_ent)
end

function updateCam(cam,e)
  -- TODO: fix camera pos
  cam.x=e.x-W//2
  if e.x < W // 2 then cam.x = 0 end
end

function inViewPort(e,cam)
  return e.x - cam.x > 0 and e.x - cam.x < W
end

function disposeFallen(e,cam)
  if e.y - cam.y > H + 200 then
    removeFrom(ENTITIES, e)
  end
end

function drawMap(e,cam)
  local cx,cy = cam.x//T, cam.y // T
  local offx=cx * T - cam.x
  map(cx,cy,31,17,offx,0,0,1, function(tile, x, y)
    if isTilsSpawner(x,y) then
      spawnEnemy(x,y)
      if DEBUG then return tile else return tile-1 end
    end
    return tile
  end)
end

function grab_object(e)
  if btn(BTN_Z) then
    local cr_grab = {x=e.cr.x-1, y=e.cr.y, w=e.cr.w+2, h=e.cr.h}
    local e_gr = {x=e.x, y=e.y, cr=cr_grab}
    for i,en in ipairs(ENTITIES) do
      if (collide(e_gr, en)) and en.grabbable and en ~= e then
        if e.grabbed ~= nil then e.grabbed.grab_by = nil end
        e.grabbed = en
        en.grab_by = e
        return
      end
    end
  end
  if e.grabbed ~= nil then
    e.grabbed.grab_by = nil
    e.grabbed = nil
  end
end

function renderHud(e)
  s=mul_tex(make_tex(372,1,1),e.lives)
  hud={x=8,y=8,sp=s}
  drawEnt(hud)
end

function initFail()
end

function TICFail()
  cls()
  local string="YOU LOSE"
  local w=print(string,0,-6)
  print(string,(W-w)//2,(H-6)//2)
  if btn(BTN_Z) then mode=MOD_GAME end
end

function initGame()
  for i=0,8 do
    for j=0,8 do
      if mget(i*MAP_W,j*MAP_H) == LEVEL_SPRITES[CURRENT_LEVEL] then
        SPAWNX, SPAWNY = i*W + 20, j*H + 80
        break
      end
    end
  end

  Player.x = SPAWNX
  Player.y = SPAWNY
  cam.y=Player.y//H * H
  Player.lives=9
  Player.state=ST.STAND
  ENTITIES = {Player, Flag}
  bg={bg0,bg1}
  SPAWNED_ENEMIES={}
end

function TICGame()
  cls()
  rect(0,0,W,H,6)
  updateCam(cam, Player)
  drawEnt(bg0,cam)
  drawEnt(bg1,cam)
  drawMap(Player, cam)
  handleState(Player)
  for i,e in ipairs(ENTITIES) do
    e.dir=updateDir(e)
    handleShoot(e)
    handleBullet(e,cam)
    handleFollow(e,Player)
    update(e)
    animate(e)
    drawEnt(e,cam)
    disposeFallen(e,cam)
  end
  cleanup(ENTITIES)
  for i,v in ipairs(bg) do
    handleParallax(v,cam)
  end
  renderHud(Player)
  grab_object(Player)
  if isTouchSpikeTiles(Player) then die(Player) end
  if Player.y-cam.y > 200 then die(Player) end
  if intersect(Player, Flag) then mode=MOD_WIN end
  if Player.lives < 9 and not gotit then
    print("Press Z to grab dead body", 10-cam.x,124)
    if Player.grabbed ~= nil then gotit=true end
  end
end

function initWin()
end

function TICWin()
  cls()
  local string="WOW, YOU WON!"
  local w=print(string,0,-6)
  print(string,(W-w)//2,(H-6)//2)
  if btn(BTN_Z) then mode=MOD_GAME end
end

function initIntro()
  LOGO_TO=1
end

function TICIntro()
  cls(7)
  spr(432, 88, 24, -1, 8)
  print("CAT_IN_THE_DARK", 72, 108, 0)
  LOGO_TO=LOGO_TO+1
  local x,y,d = mouse()
  if d then mode=MOD_GAME end
  if btn(BTN_Z) then mode=MOD_GAME end
  if btn(BTN_X) then mode=MOD_SELECT_LEVEL end
  if LOGO_TO > 120 then mode=MOD_GAME end
end

CURRENT_LEVEL=1
function initSelectLevel()
  CURRENT_LEVEL=1
end

function TICSelectLevel()
  cls(6)
  local str = "Select level:"
  local w = print(str, 0, -10)
  print(str, W//2-w//2 + 1, H//2 + 1, 7)
  print(str, W//2-w//2, H//2, 0)
  str = sf("- %d -", CURRENT_LEVEL)
  w = print(str, 0, -10)
  print(str, W//2-w//2 + 1, H//2 + 1 + 10, 7)
  print(str, W//2-w//2, H//2 + 10, 0)

  if btnp(BTN_UP) then CURRENT_LEVEL = CURRENT_LEVEL + 1 end
  if btnp(BTN_DOWN) then CURRENT_LEVEL = CURRENT_LEVEL - 1 end
  if CURRENT_LEVEL > LEVELS then CURRENT_LEVEL = LEVELS end
  if CURRENT_LEVEL < 1 then CURRENT_LEVEL = 1 end

  if btn(BTN_Z) then mode=MOD_GAME end
end

-- game modes
MOD_GAME=1
MOD_FAIL=2
MOD_WIN=3
MOD_INTRO=4
MOD_SELECT_LEVEL=5

TICMode={
  [MOD_GAME]=TICGame,
  [MOD_FAIL]=TICFail,
  [MOD_WIN]=TICWin,
  [MOD_INTRO]=TICIntro,
  [MOD_SELECT_LEVEL]=TICSelectLevel
}

inits={
  [MOD_GAME]=initGame,
  [MOD_FAIL]=initFail,
  [MOD_WIN]=initWin,
  [MOD_INTRO]=initIntro,
  [MOD_SELECT_LEVEL]=initSelectLevel
}

function init()
  mode = MOD_INTRO
end

init()
function TIC()
  if oldMode == nil or oldMode ~= mode then
    if inits[mode] ~= nil then
      inits[mode]()
    end
    oldMode=mode
  end
  TICMode[mode]()
end
