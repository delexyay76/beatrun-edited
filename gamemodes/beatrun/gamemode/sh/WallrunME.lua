local vwrtime = 1.5
local hwrtime = 1.5
tiltdir = 1
-- local tilt = 0
local wrmins = Vector(-16, -16, 0)
local wrmaxs = Vector(16, 16, 16)

local RealismMode = GetConVar("Beatrun_RealismMode")

local ledgetime = 0
local foundledge = false
local climbstartpos = vector_origin
local climboffset = vector_origin
local climboffset2 = vector_origin

function PuristWallrunningCheck(ply, mv, cmd, vel, eyeang, timemult, speedmult)
	local downvel = mv:GetVelocity().z

	if downvel > -75 then
		downvel = math.max(downvel, 10)
	end

	timemult = math.Clamp(math.max(downvel * 0.1, -10), 0.5, 1.1)

	if not ply:OnGround() and mv:KeyDown(IN_JUMP) and mv:GetVelocity().z > -200 then
		local tr = ply.WallrunTrace
		local trout = ply.WallrunTraceOut

		tr.start = ply:EyePos() - Vector(0, 0, 15)
		tr.endpos = tr.start + eyeang:Forward() * 25
		tr.filter = ply
		tr.collisiongroup = COLLISION_GROUP_PLAYER_MOVEMENT
		tr.output = trout

		util.TraceLine(tr)

		if trout.HitNormal:IsEqualTol(ply:GetWallrunDir(), 0.25) then return end
		if trout.Entity and trout.Entity.IsNPC and (trout.Entity.NoWallrun or trout.Entity:IsNPC() or trout.Entity:IsPlayer()) then return false end

		if trout.Hit and timemult > 0.5 then
			tr.start = tr.start + Vector(0, 0, 10)
			tr.endpos = tr.start + eyeang:Forward() * 30

			util.TraceLine(tr)

			if trout.Hit then
				local angdir = trout.HitNormal:Angle()
				angdir.y = angdir.y - 180

				local wallnormal = trout.HitNormal
				local eyeang = Angle(angdir)
				eyeang.x = 0

				tr.start = ply:EyePos() - Vector(0, 0, 5)
				tr.endpos = tr.start + eyeang:Forward() * 40
				tr.filter = ply
				tr.collisiongroup = COLLISION_GROUP_PLAYER_MOVEMENT
				tr.output = trout

				util.TraceLine(tr)

				if not trout.Hit then return end

				if SERVER then
					ply:EmitSound("Bump.Concrete")
				end

				if ply:GetWallrunTime() - CurTime() > -2 then
					timemult = math.max(1 - math.max(ply:GetWallrunCount() - 1, 0) * 0.4, 0.25)
				else
					ply:SetWallrunCount(0)
				end

				ply.WallrunOrigAng = angdir

				ply:SetWallrunData(1, CurTime() + (not RealismMode:GetBool() and vwrtime or 1) * timemult * speedmult, wallnormal)
				ply:ViewPunch(Angle(-5, 0, 0))

				ParkourEvent("wallrunv", ply)

				if CLIENT and IsFirstTimePredicted() then
					BodyLimitX = 30
					BodyLimitY = 70
					BodyAnimCycle = 0

					BodyAnim:SetSequence("wallrunverticalstart")

					ply.OrigEyeAng = angdir
				elseif game.SinglePlayer() then
					net.Start("BodyAnimWallrun")
						net.WriteBool(true)
						net.WriteAngle(angdir)
					net.Send(ply)
				end

				return
			end
		end
	end

	if not ply:OnGround() or mv:KeyPressed(IN_JUMP) then
		local tr = ply.WallrunTrace
		local trout = ply.WallrunTraceOut

		tr.start = ply:EyePos()
		tr.endpos = tr.start + eyeang:Right() * 25
		tr.filter = ply
		tr.collisiongroup = COLLISION_GROUP_PLAYER_MOVEMENT
		tr.output = trout

		util.TraceLine(tr)

		if trout.HitNormal:IsEqualTol(ply:GetWallrunDir(), 0.25) then return end

		if trout.Hit and trout.HitNormal:IsEqualTol(ply:GetEyeTrace().HitNormal, 0.1) then
			local ovel = mv:GetVelocity() * 0.85
			ovel.z = 0

			ply:SetWallrunOrigVel(ovel)
			ply:SetWallrunElevated(false)

			mv:SetVelocity(vector_origin)

			ply:SetWallrunData(2, CurTime() + (not RealismMode:GetBool() and hwrtime or 1) * timemult, trout.HitNormal)

			ParkourEvent("wallrunh", ply)

			ply:ViewPunch(Angle(0, 1, 0))

			if CLIENT and IsFirstTimePredicted() then
				tiltdir = -1

				hook.Add("CalcViewBA", "WallrunningTilt", WallrunningTilt)
			elseif SERVER and game.SinglePlayer() then
				net.Start("WallrunTilt")
					net.WriteBool(true)
				net.Send(ply)
			end

			return
		end
	end

	if not ply:OnGround() or mv:KeyPressed(IN_JUMP) then
		local tr = ply.WallrunTrace
		local trout = ply.WallrunTraceOut

		tr.start = ply:EyePos()
		tr.endpos = tr.start + eyeang:Right() * -25
		tr.filter = ply
		tr.collisiongroup = COLLISION_GROUP_PLAYER_MOVEMENT
		tr.output = trout

		util.TraceLine(tr)

		if trout.HitNormal:IsEqualTol(ply:GetWallrunDir(), 0.25) then return end

		if trout.Hit and trout.HitNormal:IsEqualTol(ply:GetEyeTrace().HitNormal, 0.1) then
			local ovel = mv:GetVelocity() * 0.85
			ovel.z = 0

			ply:SetWallrunOrigVel(ovel)
			ply:SetWallrunDir(trout.HitNormal)

			mv:SetVelocity(vector_origin)

			ply:SetWallrunElevated(false)
			ply:SetWallrunData(3, CurTime() + (not RealismMode:GetBool() and hwrtime or 1) * timemult, trout.HitNormal)

			ParkourEvent("wallrunh", ply)

			ply:ViewPunch(Angle(0, -1, 0))

			if CLIENT and IsFirstTimePredicted() then
				tiltdir = 1

				hook.Add("CalcViewBA", "WallrunningTilt", WallrunningTilt)
			elseif game.SinglePlayer() then
				net.Start("WallrunTilt")
					net.WriteBool(false)
				net.Send(ply)
			end

			return
		end
	end
end

function PuristWallrunningThink(ply, mv, cmd, wr, wrtimeremains)
	if wr == 4 then
		local ang = cmd:GetViewAngles()
		ang.x = 0

		local vel = ang:Forward() * (RealismMode:GetBool() and 5 or 30)
		vel.z = RealismMode:GetBool() and -30 or 25

		mv:SetVelocity(vel)
		mv:SetSideSpeed(0)
		mv:SetForwardSpeed(0)

		if foundledge then
			ply:SetMoveType(MOVETYPE_WALK)
			foundledge = false
		end

		if ply:GetWallrunTime() < CurTime() or mv:GetVelocity():Length() < 10 then
			ply:SetWallrun(0)
			ply:SetQuickturn(false)


			mv:SetVelocity(vel * (RealismMode:GetBool() and 0 or 4))

			local activewep = ply:GetActiveWeapon()

			if ply:UsingRH() then
				activewep:SendWeaponAnim(ACT_VM_HITCENTER)
				activewep:SetBlockAnims(false)
			end

			return
		end

		if mv:KeyPressed(IN_JUMP) then
			ParkourEvent("jumpwallrun", ply)

			ply:SetSafetyRollKeyTime(CurTime() + 0.001)

			vel = RealismMode:GetBool() and ang:Forward() * 30 or vel
			vel.z = 30
			
			vel:Mul(ply:GetOverdriveMult())

			mv:SetVelocity(vel * 8)

			ply:SetWallrun(0)
			ply:SetQuickturn(false)

			local activewep = ply:GetActiveWeapon()

			if ply:UsingRH() then
				activewep:SendWeaponAnim(ACT_VM_HITCENTER)
				activewep:SetBlockAnims(false)
			end
		end

		return
	end

	if wr == 1 and wrtimeremains then
		local velz = math.Clamp((ply:GetWallrunTime() - CurTime()) / (not RealismMode:GetBool() and vwrtime or 1), 0.1, 1)
		local vecvel = Vector()
		vecvel.z = (RealismMode:GetBool() and 250 or 200) * velz
		vecvel:Add(ply:GetWallrunDir():Angle():Forward() * -50)
		vecvel:Mul(ply:GetOverdriveMult())

		if not foundledge then
			mv:SetVelocity(vecvel)
		end
		mv:SetForwardSpeed(0)
		mv:SetSideSpeed(0)

		local tr = ply.WallrunTrace

		local tr_up = {}
		local tr_down = {}
		local tr_front = {}

		local tr_roof = {}

		local trout = ply.WallrunTraceOut

		local trout_up = {}
		local trout_down = {}
		local trout_front = {}

		local trout_roof = {}

		local eyeang = ply.WallrunOrigAng or Angle()
		eyeang.x = 0

		tr.start = ply:EyePos() - Vector(0, 0, 5)
		tr.endpos = tr.start + eyeang:Forward() * 40
		tr.filter = ply
		tr.collisiongroup = COLLISION_GROUP_PLAYER_MOVEMENT
		tr.output = trout

		tr_roof.start = ply:EyePos()
		tr_roof.endpos = tr_roof.start + eyeang:Up() * 25
		tr_roof.filter = ply
		tr_roof.collisiongroup = COLLISION_GROUP_PLAYER_MOVEMENT
		tr_roof.output = trout_roof

		util.TraceLine(tr)
		util.TraceLine(tr_roof)

		tr_up.start = ply:EyePos() + (eyeang:Forward() * 14)
		tr_up.endpos = tr_up.start + eyeang:Up() * 20
		tr_up.filter = ply
		tr_up.collisiongroup = COLLISION_GROUP_PLAYER_MOVEMENT
		tr_up.output = trout_up

		tr_down.start = ply:EyePos() + (eyeang:Forward() * 14) + (eyeang:Up() * 30)
		tr_down.endpos = tr_down.start - eyeang:Up() * 50
		tr_down.filter = ply
		tr_down.collisiongroup = COLLISION_GROUP_PLAYER_MOVEMENT
		tr_down.output = trout_down

		tr_front.start = ply:EyePos() + (eyeang:Forward() * -15) + (eyeang:Up() * 10)
		tr_front.endpos = tr_front.start + eyeang:Forward() * 40
		tr_front.filter = ply
		tr_front.collisiongroup = COLLISION_GROUP_PLAYER_MOVEMENT
		tr_front.output = trout_front

		util.TraceLine(tr_up)
		util.TraceLine(tr_front)
		util.TraceLine(tr_down)

		if (not trout.Hit or trout_roof.Hit) and not foundledge then
			ply:SetWallrunTime(0)
		end

		if trout_up.Hit and trout_front.Hit and (trout_down.Hit and trout_down.HitBox == trout_up.HitBox and not trout_down.StartSolid) and not foundledge and not trout_roof.Hit then
			foundledge = true
			climbstartpos = mv:GetOrigin()
			climboffset = trout_front.HitPos:Distance2D(mv:GetOrigin())
			climboffset2 = trout_down.HitPos:Distance(mv:GetOrigin())
			ply:SetDTFloat(13, 0)
			lasttime = CurTime() + 0.25
		end
		if foundledge then
			mv:SetVelocity(vector_origin)

			local mlerp = ply:GetDTFloat(13)
			local FT = FrameTime()
		    local TargetTick = 1 / FT / 30
			local mlerprate = 0.1 / TargetTick

			local mvec = LerpVector(ply:GetDTFloat(13), climbstartpos, climbstartpos+(eyeang:Forward() * -(climboffset/1.65))+(eyeang:Up() * (climboffset2/2)))
			mv:SetOrigin(mvec)

			ply:SetDTFloat(13, Lerp(mlerprate, mlerp, 1))

	        ply:SetMoveType(MOVETYPE_NOCLIP)

			if lasttime < CurTime() then
				ply:SetWallrunTime(0)

				ply:SetMoveType(MOVETYPE_WALK)
				mv:SetOrigin(climbstartpos+(eyeang:Forward() * -(climboffset/1.65))+(eyeang:Up() * (climboffset2/2)))

				ply:SetVelocity(eyeang:Up() * 60)

				foundledge = false
			end
		end

		if mv:KeyPressed(IN_JUMP) and (mv:KeyDown(IN_MOVELEFT) or mv:KeyDown(IN_MOVERIGHT)) then
			local dir = mv:KeyDown(IN_MOVERIGHT) and 1 or -1
			local vel = mv:GetVelocity()
			vel.z = 250

			mv:SetVelocity(vel + eyeang:Right() * 150 * dir)

			local event = ply:GetWallrun() == 3 and "jumpwallrunright" or "jumpwallrunleft"

			ParkourEvent(event, ply)

			if IsFirstTimePredicted() then
				ply:EmitSound("Wallrun.Concrete")
			end
		end
	end

	if wr >= 2 and wrtimeremains then
		local dir = wr == 2 and 1 or -1

		mv:SetForwardSpeed(0)
		mv:SetSideSpeed(0)

		local ovel = ply:GetWallrunOrigVel()
		local vecvel = ply:GetWallrunDir():Angle():Right() * dir * math.max(ovel:Length() + 50, 75)

		if ovel:Length() > 400 then
			ovel:Mul(0.975)

			ply:SetWallrunOrigVel(ovel)
		end

		local tr = ply.WallrunTrace
		local trout = ply.WallrunTraceOut
		local mins, maxs = ply:GetCollisionBounds()
		mins.z = -32

		if not ply:GetWallrunElevated() then
			tr.start = mv:GetOrigin()
			tr.endpos = tr.start
			tr.maxs = maxs
			tr.mins = mins
			tr.filter = ply
			tr.collisiongroup = COLLISION_GROUP_PLAYER_MOVEMENT
			tr.output = trout

			util.TraceHull(tr)
		end

		if not ply:GetWallrunElevated() and trout.Hit then
			vecvel.z = RealismMode:GetBool() and 25 or 100
		elseif not ply:GetWallrunElevated() and not trout.Hit then
			ply:SetWallrunElevated(true)
		end

		if ply:GetWallrunElevated() then
			vecvel.z = 0 + math.Clamp(-(CurTime() - ply:GetWallrunTime() + 1.025) * (RealismMode:GetBool() and 300 or 250), -400, (RealismMode:GetBool() and 0 or 25))
		end

		if vecvel:Length() > 300 then
			vecvel:Mul(ply:GetOverdriveMult())
		end

		mv:SetVelocity(vecvel)

		local eyeang = ply:EyeAngles()
		eyeang.x = 0

		if ply:GetVelocity():Length() <= 75 then
			ply:SetWallrunTime(0)
		end

		tr.start = ply:EyePos()
		tr.endpos = tr.start + eyeang:Right() * 45 * dir
		tr.maxs = wrmaxs
		tr.mins = wrmins
		tr.filter = ply
		tr.collisiongroup = COLLISION_GROUP_PLAYER_MOVEMENT
		tr.output = trout

		util.TraceHull(tr)

		if not trout.Hit and ply:GetWallrunTime() - CurTime() < (not RealismMode:GetBool() and hwrtime or 1) * 0.7 then
			tr.start = ply:EyePos()
			tr.endpos = tr.start + eyeang:Forward() * -60
			tr.filter = ply
			tr.output = trout

			util.TraceLine(tr)

			if not trout.Hit then
				ply:SetWallrunTime(0)
			else
				if not ply:GetWallrunDir():IsEqualTol(trout.HitNormal, 0.75) then
					ply:SetWallrunTime(0)
				end

				ply:SetWallrunDir(trout.HitNormal)
			end
		elseif ply:GetWallrunTime() - CurTime() < (not RealismMode:GetBool() and hwrtime or 1) * 0.7 then
			tr.start = ply:EyePos()
			tr.endpos = tr.start + eyeang:Right() * 45 * dir
			tr.filter = ply
			tr.collisiongroup = COLLISION_GROUP_PLAYER_MOVEMENT
			tr.output = trout

			util.TraceLine(tr)

			if trout.Hit and ply:GetWallrunDir():IsEqualTol(trout.HitNormal, 0.75) then
				ply:SetWallrunDir(trout.HitNormal)
			end
		end

		if mv:KeyPressed(IN_JUMP) and ply:GetWallrunTime() - CurTime() ~= (not RealismMode:GetBool() and hwrtime or 1) then
			ply:SetQuickturn(false)
			ply:SetWallrunTime(0)
			ply:SetSafetyRollKeyTime(CurTime() + 0.001)

			mv:SetVelocity(eyeang:Forward() * math.max(150, vecvel:Length() - 25) + Vector(0, 0, (not RealismMode:GetBool() and 250 or 175)))

			local event = ply:GetWallrun() == 3 and "jumpwallrunright" or "jumpwallrunleft"

			ParkourEvent(event, ply)

			if IsFirstTimePredicted() then
				ply:EmitSound("Wallrun.Concrete")
			end
		end
	end

	if ply:GetWallrunSoundTime() < CurTime() then
		local delay = nil
		local wr = ply:GetWallrun()

		if wr == 1 then
			delay = math.Clamp(math.abs(ply:GetWallrunTime() - CurTime() - 2.75) / (not RealismMode:GetBool() and vwrtime or 1) * 0.165, 0.175, 0.3)
		else
			delay = math.Clamp(math.abs(ply:GetWallrunTime() - CurTime()) / (not RealismMode:GetBool() and hwrtime or 1) * 0.165, 0.15, 1.75)
		end

		if SERVER then
			ply:EmitSound("Wallrun.Concrete")

			timer.Simple(0.025, function()
				ply:EmitSound("WallrunRelease.Concrete")
			end)
		end

		ply:SetWallrunSoundTime(CurTime() + delay)
		ply:ViewPunch(Angle(0.25, 0, 0))
	end

	if (ply:GetWallrunTime() < CurTime() or mv:GetVelocity():Length() < 10) and not foundledge then
		if ply.vwrturn == 0 then
			ply:SetQuickturn(false)
		end

		if CLIENT and IsFirstTimePredicted() and wr == 1 then
			BodyLimitX = 90
			BodyLimitY = 180
			BodyAnimCycle = 0

			BodyAnim:SetSequence("jumpair")
		elseif game.SinglePlayer() and wr == 1 then
			net.Start("BodyAnimWallrun")
				net.WriteBool(false)
			net.Send(ply)
		end

		ply:SetWallrun(0)

		return
	end
end