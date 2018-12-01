T=8
W=240
H=136

ST={
  STAND=1,
  RUN=2,
  JUMP=3
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

function make_anim(c0,w,h,count)
  anim = {}
  for i=1,count do
    anim[i] = make_tex(c0 + (i-1)*w, w, h)
  end
  return anim
end

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
  anim={tick=0,speed=0.13,sp={
    [ST.STAND]=make_anim(280, 2, 3, 1),
    [ST.RUN]=make_anim(272, 2, 3, 4),
    [ST.JUMP]=make_anim(284, 2, 3, 1)
  }},
  ctrl=true
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

JMP_IMP=2.8
ACCEL=0.2
OVERJMP_ACC=0.1

cam={x=W//2,y=0}

-- tile types
solid_sprites_index = 80
spikeFirst=32
spikeLast=32

BTN_UP=0
BTN_LEFT=2
BTN_RIGHT=3
BTN_Z=4

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

-- buttons state
btn_st={
  [BTN_UP]=false,
  [BTN_LEFT]=false,
  [BTN_RIGHT]=false,
  [BTN_Z]=false
}

function btni(id)
  if btn(id) then
    btn_st[id]=true
    return false
  elseif btn_st[id] then
    btn_st[id]=false
    return true
  end
end

-- triiger button event once on contituous button press
function btno(id)
  if btn(id) then
    if not btn_st[id] then
      btn_st[id]=true
      return true
    else
      return false
    end
  else
    btn_st[id]=false
    return false
  end
end

-- tile helpers
function IsTileSolid(x, y)
  tileId = mget(x, y)
  return (tileId >= solid_sprites_index)
end

function isTileSpike(x,y)
  id = mget(x,y)
  return id>=spikeFirst and id <=spikeLast
end

function animate(e)
  local anim=e.anim.sp
  if e.state ~= nil then anim=e.anim.sp[e.state] end
  e.sp=anim[(math.floor(e.anim.tick)%#anim)+1]
  e.anim.tick = e.anim.tick+e.anim.speed
end

function drawEnt(e,cam)
  local i=1
  for i,t in ipairs(e.sp) do
    for j,v in ipairs(t) do
      if e.dir == nil or e.dir == DIR.R then
        spr(v, e.x+(j-1)*T+cam.x, e.y+(i-1)*T+cam.y, 0)
      else
        tlen = #t
        spr(v, e.x+(tlen-j)*T+cam.x, e.y+(i-1)*T+cam.y, 0, 1, 1)
      end
    end
  end
end

function collide(e1,e2)
  return e2.rigid and
    (e1.x+e1.cr.x < e2.x+e2.cr.x+e2.cr.w and e2.x+e2.cr.x < e1.x+e1.cr.x+e1.cr.w) and
    (e1.y+e1.cr.y < e2.y+e2.cr.y+e2.cr.h and e2.y+e2.cr.y < e1.y+e1.cr.y+e1.cr.h)
end

function handleInput()
  local iv={pos=vec2(0,0), jump=false}
  if btn(BTN_LEFT) then
    iv.pos.x = -1
  elseif btn(BTN_RIGHT) then
    iv.pos.x = 1
  end
  if btno(BTN_UP) then
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
  for i,en in ipairs(entities) do
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

function update(e)
  if e.grab_by ~= nil then return end
  local iv={pos=vec2(0,0), jump=false}
  if e.ctrl ~= nil then iv=handleInput() end
  if e.mass then
    if isOnFloor(e) then
      if iv.jump then
        e.vy=-1*JMP_IMP
      else
        e.vy=0
      end
    elseif isUnderCeiling(e) and e.vy < 0 then
      e.vy=0
    elseif btn(BTN_UP) and e.vy < 0 then
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

function updateState(e)
  if e.vx ~= 0 then
    e.state = ST.RUN
  else
    e.state = ST.STAND
  end
  if not isOnFloor(e) then
    e.state=ST.JUMP
  end

  if e.vx > 0 then
    e.dir = DIR.R
  elseif e.vx < 0 then
    e.dir = DIR.L
  end
end

function updateCam(cam,e)
  cam.x=math.min(W//2,W//2-e.x)
  -- cam.y=math.min(H//2,H//2-e.y)
end

crx, cry = 0, 0
function drawMap(e,cam)
  map(crx,cry,60,34,crx*8+cam.x,cry*8+cam.y,-1,1, function(tile, x, y)
    return tile
  end)
end

function grab_object(e)
  if btn(BTN_Z) then
    local cr_grab = {x=e.cr.x-1, y=e.cr.y, w=e.cr.w+2, h=e.cr.h}
    local e_gr = {x=e.x, y=e.y, cr=cr_grab}
    for i,en in ipairs(entities) do
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

function initFail()
end

function TICFail()
  cls()
  local string="YOU LOOSE"
  local w=print(string,0,-6)
  print(string,(W-w)//2,(H-6)//2)
  if btn(BTN_Z) then mode=MOD_GAME end
end

function initGame()
  Player.x = 10
  Player.y = 10
  Corpse.x = 50
  Corpse.y = 10
  entities = {Player, Corpse}
end

function TICGame()
  cls()
  updateCam(cam, Player)
  updateState(Player)
  update(Player)
  update(Corpse)
  drawMap(Player, cam)
  animate(Player)
  animate(Corpse)
  drawEnt(Player, cam)
  drawEnt(Corpse, cam)
  grab_object(Player)
  if isTouchSpikeTiles(Player) then mode=MOD_FAIL end
  if Player.grabbed ~= nil then print("grabbed", 10, 10, 8) end
  if Corpse.grab_by ~= nil then print("is grabbed", 10, 18, 8) end
end

-- game modes
MOD_GAME=1
MOD_FAIL=2

TICMode={
  [MOD_GAME]=TICGame,
  [MOD_FAIL]=TICFail
}

inits={
  [MOD_GAME]=initGame,
  [MOD_FAIL]=initFail
}

function init()
  mode = MOD_GAME
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
