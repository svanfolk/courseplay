function courseplay:handleMode10(vehicle,allowedToDrive,lx,lz, dt)

	
	if vehicle.cp.mode9TargetSilo == nil then
		vehicle.cp.mode9TargetSilo = courseplay:getMode9TargetBunkerSilo(vehicle,1)
	end
	if not vehicle.cp.mode9TargetSilo then
		courseplay:setInfoText(vehicle, courseplay:loc('COURSEPLAY_MODE10_NOSILO'));
		return true, false;
	end
	
	local emptyTimer = 2
	local x,y,z = getWorldTranslation(vehicle.cp.workTools[1].rootNode)
	local dx,dy,dz = getWorldTranslation(vehicle.cp.DirectionNode)
	local ty = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 1, z);
	local dty = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, dx, 1, dz)
	local nodeX,nodeY,nodeZ = worldToLocal(vehicle.cp.DirectionNode,x,y,z)
	local nx, ny, nz = localDirectionToWorld(vehicle.cp.DirectionNode, 0, 0, -1)
	local zeroX,zeroY,zeroZ = dx+(nx*-nodeZ) ,dy+(ny*-nodeZ),dz+(nz*-nodeZ)
	local offSetX,offSetY,offSetZ = worldToLocal(vehicle.cp.DirectionNode,zeroX,zeroY,zeroZ)
	local diffY = (zeroY-ty)-(dy-dty)
	
	local fwd = true
	local cx,cy,cz =0,0,0;
	local goSave = false
	if vehicle.cp.mode10.searchCourseplayersOnly then
		for rootNode,courseplayer in pairs (CpManager.activeCoursePlayers) do
			local distance = courseplay:distanceToPoint(courseplayer,vehicle.Waypoints[1].cx,ty ,vehicle.Waypoints[1].cz) --courseplay:nodeToNodeDistance(vehicle.cp.DirectionNode, rootNode)
			--print(string.format("%s: distance = %s",tostring(rootNode),tostring(distance)))
			if distance  < vehicle.cp.mode10.searchRadius and courseplayer ~= vehicle then
				local insert = true
				for i=1,#vehicle.cp.mode10.stoppedCourseplayers do
					if courseplayer == vehicle.cp.mode10.stoppedCourseplayers[i] then
						insert = false
					end
				end
				if insert then
					table.insert(vehicle.cp.mode10.stoppedCourseplayers,courseplayer)
				end
			end
		end
	else
		for _,steerable in pairs(g_currentMission.steerables) do
			local x,y,z = getWorldTranslation(steerable.rootNode)
			local distance = courseplay:distance(x,z,vehicle.Waypoints[1].cx,vehicle.Waypoints[1].cz) 
			if distance  < vehicle.cp.mode10.searchRadius and steerable ~= vehicle and steerable.isMotorStarted then
				local insert = true
				for i=1,#vehicle.cp.mode10.stoppedCourseplayers do
					if steerable == vehicle.cp.mode10.stoppedCourseplayers[i] then
						insert = false
					end
				end
				if insert then
					table.insert(vehicle.cp.mode10.stoppedCourseplayers,steerable)
				end
			end
		end
	end
	
	if #vehicle.cp.mode10.stoppedCourseplayers > 0 then
		for i=1, #vehicle.cp.mode10.stoppedCourseplayers do
			if i > 1 or not vehicle.Waypoints[vehicle.cp.previousWaypointIndex].wait then
				vehicle.cp.mode10.stoppedCourseplayers[i].cp.isNotAllowedToDrive = true
			end
		end
		goSave = true
	else
		courseplay:setVehicleWait(vehicle, false);
	end
	
	local inBunker = vehicle.cp.waypointIndex == 1 
	local refSpeed = 30

	if vehicle.cp.hasDriveControl then 
		courseplay:setFourWheelDrive(vehicle,inBunker)
	end
	
	if  inBunker or vehicle.cp.mode10.isStuck then 
		if vehicle.cp.modeState == 1 then --push
			courseplay:setShieldTarget(vehicle,"down")
			fwd = false
			if vehicle.cp.actualTarget == nil or vehicle.cp.BunkerSiloMap == nil then
				courseplay:getActualTarget(vehicle)
			end
			local newSx = vehicle.cp.BunkerSiloMap[#vehicle.cp.BunkerSiloMap][1].sx 
			local newSz = vehicle.cp.BunkerSiloMap[#vehicle.cp.BunkerSiloMap][1].sz 
			local newWx = vehicle.cp.BunkerSiloMap[#vehicle.cp.BunkerSiloMap][#vehicle.cp.BunkerSiloMap[#vehicle.cp.BunkerSiloMap]].wx
			local newWz = vehicle.cp.BunkerSiloMap[#vehicle.cp.BunkerSiloMap][#vehicle.cp.BunkerSiloMap[#vehicle.cp.BunkerSiloMap]].wz
			local newHx = vehicle.cp.BunkerSiloMap[#vehicle.cp.BunkerSiloMap][1].hx
			local newHz = vehicle.cp.BunkerSiloMap[#vehicle.cp.BunkerSiloMap][1].hz
			local wY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, newWx, 1, newWz); 
			local hY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, newHx, 1, newHz);
		
			local fillType = TipUtil.getFillTypeAtLine(newWx, wY, newWz, newHx, hY, newHz, 5)
			local newFillLevel = TipUtil.getFillLevelAtArea(fillType, newSx, newSz, newWx, newWz, newHx, newHz )
			
			local hasFillLevel = vehicle.cp.totalFillLevel > 100
			
			if vehicle.cp.speeds.bunkerSilo > 15 then
				vehicle.cp.speeds.bunkerSilo = 15
			end
			
			if vehicle.cp.mode10FillLevel == nil then 
				vehicle.cp.mode10FillLevel  = newFillLevel 
			end
			
			if vehicle.cp.fillLevelGo == nil then 
				vehicle.cp.fillLevelGo = true 
			end
			
			
			local currentHeight = (y-ty)-(dy-dty)
			vehicle.cp.currentHeigth = currentHeight
			local shouldBHeight = vehicle.cp.mode10.shieldHeight
			local heightDiff  = courseplay:round(shouldBHeight,2) - courseplay:round(currentHeight,2)
			local targetHeigth = courseplay:round(shouldBHeight,2) - (diffY*0.75)			
			
			if vehicle.cp.mode10.leveling then
				if vehicle.cp.speeds.bunkerSilo > 8 then
					emptyTimer = 0.8
				end
				refSpeed =  15
			else
				targetHeigth = 0
				refSpeed = 20
			end	
			
			vehicle.cp.mode10.targetHeigth = targetHeigth
						
			if vehicle.cp.shieldState == "down" and  targetHeigth < 0 then  --TODO find a proper way to trigger  swinging 
				--print("jump detected : "..tostring(vehicle.cp.mode10.lastDiffDiff))
				if not vehicle.cp.mode10.jumpIsCounted then
					vehicle.cp.mode10.jumpsPerRun = vehicle.cp.mode10.jumpsPerRun + 1 
					vehicle.cp.mode10.jumpIsCounted = true
				end
			else
				vehicle.cp.mode10.jumpIsCounted = false
			end
			
			if vehicle.cp.shieldState == "down" and math.abs(diffY) > 0.01 then -- math.abs(heightDiff) > 0.05 then
				--check whether we have the target height in our table or set the closest 
				local closestIndex = 99
				local closestValue = 99
				if vehicle.cp.mode10.alphaList[targetHeigth] then
					closestIndex = targetHeigth
				else
					for indexHeight,alpha in pairs (vehicle.cp.mode10.alphaList) do
						local diff = math.abs(targetHeigth-indexHeight)
						if closestValue > diff then
							closestIndex = indexHeight
							closestValue = diff
						end				
					end	
				end	
				--print("set MoveShield to ".. tostring(closestIndex))
				courseplay:moveShield(vehicle,"up",dt,vehicle.cp.mode10.alphaList[closestIndex])
				
			elseif vehicle.cp.shieldState == "up" then
				--make a table of moveAlphas per shield height
				local height = courseplay:round(nodeY,3) --(currentHeight,2)
				if vehicle.cp.mode10.alphaList[height] == nil then
					vehicle.cp.mode10.alphaList[height] = vehicle.cp.workTools[1].attacherJointControl.controls[1].moveAlpha
					--print("add "..tostring(height).." to alphaList")
					if vehicle.cp.mode10.lowestAlpha > height then
						vehicle.cp.mode10.lowestAlpha = height
					end
				end
				return true,false
			end

			refSpeed = math.min(refSpeed,vehicle.cp.speeds.bunkerSilo)
			
			if vehicle.cp.fillLevelGo and  hasFillLevel then
				vehicle.cp.fillLevelGo = false
			end
			
			local isThrought = courseplay:timerIsThrough(vehicle,'levelerEmpty',false)
			if isThrought then
				courseplay:resetCustomTimer(vehicle, 'levelerEmpty',true);
			end
			
			
			if (vehicle.cp.mode10FillLevel ~= newFillLevel and newFillLevel~= 0)
			or vehicle.cp.slippingStage > 0 
			or isThrought
			or (y-ty > 4 and not vehicle.cp.mode10.leveling)
			or (not hasFillLevel and vehicle.cp.fillLevelGo and vehicle.cp.actualTarget.line >= #vehicle.cp.BunkerSiloMap-1)
			--or (vehicle.cp.mode10.jumpsPerRun >= 2 and vehicle.cp.actualTarget.line > 3)
			then
				if goSave then
					courseplay:setWaypointIndex(vehicle, 2);
					vehicle.cp.fillLevelGo = true
					--courseplay:getActualTarget(vehicle)
				else
					courseplay:setModeState(vehicle, 2);
					vehicle.cp.mode10.isStuck = false
				end
				vehicle.cp.mode10FillLevel = nil
				if vehicle.cp.mode10.automaticSpeed and vehicle.cp.mode10.leveling then
					if vehicle.cp.mode10.jumpsPerRun >= 1 then
						vehicle.cp.speeds.bunkerSilo = math.max(vehicle.cp.speeds.bunkerSilo - 1,3)
					elseif vehicle.cp.mode10.jumpsPerRun == 0 and vehicle.cp.actualTarget.line > #vehicle.cp.BunkerSiloMap*0.8 then
						vehicle.cp.speeds.bunkerSilo = math.min(vehicle.cp.speeds.bunkerSilo + 1,15)
					end
				end
				vehicle.cp.mode10.jumpsPerRun = 0
				
				--vehicle.cp.mode10.alphaList = {}
				if vehicle.cp.mode10.automaticHeigth and (vehicle.cp.mode10FillLevel ~= newFillLevel and newFillLevel~= 0) and hasFillLevel then
					vehicle.cp.mode10.shieldHeight = vehicle.cp.mode10.shieldHeight + 0.05
				elseif isThrought and vehicle.cp.actualTarget.line > 3 and vehicle.cp.actualTarget.line < #vehicle.cp.BunkerSiloMap*0.75 and vehicle.cp.mode10.jumpsPerRun <= 4 then
					vehicle.cp.mode10.shieldHeight = vehicle.cp.mode10.shieldHeight - 0.025
				end
					
				return true,false
			else
				vehicle.cp.mode10FillLevel = newFillLevel
			end
			
			if not vehicle.cp.fillLevelGo  and not hasFillLevel then
				if courseplay:timerIsThrough(vehicle,'levelerEmpty') then
					courseplay:setCustomTimer(vehicle, "levelerEmpty", emptyTimer);
				end
			else
				courseplay:resetCustomTimer(vehicle, 'levelerEmpty',true);
			end
	
			--make the target where to go next
			local targetUnit = vehicle.cp.BunkerSiloMap[vehicle.cp.actualTarget.line][vehicle.cp.actualTarget.column]
			cx ,cz = targetUnit.cx, targetUnit.cz
			cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cx, 1, cz);
			local distanceToTarget =  courseplay:distance(x,z, cx, cz) --distance from shovel to target
			if distanceToTarget < 1 then
				vehicle.cp.actualTarget.line = math.min(vehicle.cp.actualTarget.line + 1,#vehicle.cp.BunkerSiloMap)
				vehicle.cp.mode9triesTheSameFillUnit = false
			end
		
			if vehicle.cp.actualTarget.line == #vehicle.cp.BunkerSiloMap then
				if courseplay:distanceToPoint(vehicle, cx, cy, cz) < 1 then
					courseplay:setModeState(vehicle, 2);
				end
			end
			
			if vehicle.cp.actualTarget.line >= #vehicle.cp.BunkerSiloMap-1 then
				refSpeed= 6
			end
			
		elseif vehicle.cp.modeState == 2 then --pull
			courseplay:setShieldTarget(vehicle,"up")

			cx,cz = vehicle.Waypoints[vehicle.cp.numWaypoints].cx, vehicle.Waypoints[vehicle.cp.numWaypoints].cz
			cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cx, 1, cz);
			if courseplay:distance3D(x,y,z,cx,cy,cz) < 3  then
				courseplay:setModeState(vehicle, 1);
				vehicle.cp.fillLevelGo = true
				vehicle.cp.maxHeight = 0
				courseplay:getActualTarget(vehicle)
				--return true, false
			end
			if vehicle.cp.slippingStage == 1 and vehicle.cp.actualTarget.line > 4 then
				if vehicle.cp.actualTarget.column > 1 then
					cx, _, cz = localToWorld(vehicle.cp.DirectionNode, 2,  0, 3);
				else
					cx, _, cz = localToWorld(vehicle.cp.DirectionNode, -2,  0, 3);
				end
			elseif vehicle.cp.slippingStage > 1 then
				vehicle.cp.mode10.isStuck = true
			end
		else
			vehicle.cp.fillLevelGo = true
			vehicle.cp.modeState = 1
		end --end inBunker
		
		if vehicle.cp.mode10.isStuck then
			if math.abs(vehicle.lastSpeedReal*3600) > 2 then
				if courseplay:timerIsThrough(vehicle,'stuckTimer',false ) then
					vehicle.cp.mode10.isStuck = false
				end
				if courseplay:timerIsThrough(vehicle,'stuckTimer') then
					courseplay:setCustomTimer(vehicle, "stuckTimer", 2);
				end
			else
				courseplay:resetCustomTimer(vehicle, 'stuckTimer',true);
			end
			local otherColumn = vehicle.cp.actualTarget.column +1
			local otherLine = math.min(vehicle.cp.actualTarget.line,vehicle.cp.actualTarget.line+2)
			if otherColumn > #vehicle.cp.BunkerSiloMap[1] then
				otherColumn = 1
			end
			local targetUnit = vehicle.cp.BunkerSiloMap[otherLine][otherColumn]
			cx ,cz = targetUnit.cx, targetUnit.cz
			fwd = false
		end 	
		
		
		lx,lz = AIVehicleUtil.getDriveDirection(vehicle.cp.DirectionNode, cx, cy, cz);
		if math.abs(vehicle.lastSpeedReal) < 0.0001 and not g_currentMission.missionInfo.stopAndGoBraking then
			if not fwd then
				vehicle.nextMovingDirection = -1
			else
				vehicle.nextMovingDirection = 1
			end;
		end;
		local steeringAngle = vehicle.cp.steeringAngle;
		if vehicle.cp.isFourWheelSteering and vehicle.cp.curSpeed > 20 then
			-- We are a four wheel steered vehicle, so dampen the steeringAngle when driving fast, since we turn double as fast as normal and will cause oscillating.
			steeringAngle = vehicle.cp.steeringAngle * 2;
		end;
		lx,lz = AIVehicleUtil.getDriveDirection(vehicle.cp.DirectionNode, cx, cy, cz);
		if not fwd then
			lx = -lx
			lz = -lz
		end
		--drawDebugLine(x, y, z, 1, 0, 0, cx, cy+5, cz, 1, 1, 0);
		courseplay:handleSlipping(vehicle, refSpeed);
		AIVehicleUtil.driveInDirection(vehicle, dt, steeringAngle, 1, 0.5, 20, true, fwd, lx, lz, refSpeed, 1);
			
		return false,false;
	else
		courseplay:setShieldTarget(vehicle,"up")
		if vehicle.cp.previousWaypointIndex < 2 and vehicle.cp.slippingStage > 1 then
			vehicle.cp.mode10.isStuck = true
		end
	end
	
	return true ,allowedToDrive;
end;

function courseplay:setShieldTarget(vehicle,target)
	if vehicle.cp.targetShieldState ~= target then
		vehicle.cp.targetShieldState = target
	end
end
		 
function courseplay:moveShield(vehicle,moveUp,dt,fixAlpha)
	local leveler = vehicle.cp.workTools[1]
	local move = 0
	local factor = 0.4
	if moveUp == "up" then
		move = -factor
	elseif moveUp == "down" then
		move = factor
	end

	if leveler.attacherJointControl ~= nil and leveler.attacherJointControl.controls ~= nil and leveler.attacherJointControl.jointDesc ~= nil then
            --for i=1,2 do
                local control = leveler.attacherJointControl.controls[1] --[i]; --TODO figure out which attacher is to move
                if control.controlActionIndex ~= nil then
                    local jointDesc = leveler.attacherJointControl.jointDesc;
                    if fixAlpha then
						control.moveAlpha = fixAlpha
					else
						local moveAlpha = control.moveAlpha + (0.001 * dt * move);
						moveAlpha = Utils.clamp(moveAlpha, jointDesc.upperAlpha, jointDesc.lowerAlpha);
						if moveAlpha == jointDesc.upperAlpha 
						or moveAlpha == jointDesc.lowerAlpha 
						then
							return true
						end
						control.moveAlpha = moveAlpha 
					end
                end
            --end

            local isDirty = false;
            for i=1,2 do
                local control = leveler.attacherJointControl.controls[i];
                if control.moveAlphaSend ~= control.moveAlpha then
                    control.moveAlphaSend = control.moveAlpha;
                    isDirty = true;
                end
            end
            if isDirty then
                leveler:raiseDirtyFlags(leveler.attacherJointControl.dirtyFlag);
                leveler:updateAttacherJoint(leveler.attacherJointControl.controls[1].moveAlpha, leveler.attacherJointControl.controls[2].moveAlpha);
            end

	end;
end

function courseplay:getActualTarget(vehicle)
	--print(string.format("courseplay:getActualTarget(vehicle) called by %s",tostring(courseplay.utils:getFnCallPath(3))))
	vehicle.cp.BunkerSiloMap = courseplay:createBunkerSiloMap(vehicle, vehicle.cp.mode9TargetSilo)
	if vehicle.cp.BunkerSiloMap ~= nil then
		local stopSearching = false
		local mostFillLevelAtLine = 0
		local mostFillLevelIndex = 2
		local fillLevelsPerColumn = {}
		if vehicle.cp.mode10.leveling then -- if leveling, toggle sides independently
			local fullestColumn = 0
			if vehicle.cp.mode10.lastActualTarget then
				local nextColumnIndex = vehicle.cp.mode10.lastActualTarget+1
				if nextColumnIndex > #vehicle.cp.BunkerSiloMap[1] then
					nextColumnIndex = 1
				end
				fullestColumn = nextColumnIndex
			else
				vehicle.cp.mode10.lastActualTarget = 1
				fullestColumn = 1
			end			
			vehicle.cp.actualTarget = {
										line = 1;
										column = fullestColumn;
													}
			vehicle.cp.mode10.lastActualTarget = fullestColumn
		else	-- if not leveling, find column with most fillLevel
			for lineIndex, line in pairs(vehicle.cp.BunkerSiloMap) do
				if stopSearching then
					break
				end
				mostFillLevelAtLine = 0
				for column, fillUnit in pairs(line) do
					if 	mostFillLevelAtLine < fillUnit.fillLevel then
						mostFillLevelAtLine = fillUnit.fillLevel
						mostFillLevelIndex = column
					end
					if column == #line and mostFillLevelAtLine > 0 then
						fillUnit = line[mostFillLevelIndex]
						if vehicle.cp.mode9SavedLastFillLevel == courseplay:round(fillUnit.fillLevel,1) then
							courseplay:debug(('%s triesTheSameFillUnit fillLevel: %s'):format(nameNum(vehicle),tostring(vehicle.cp.mode9SavedLastFillLevel)),10)
							vehicle.cp.mode9triesTheSameFillUnit = true
						end
						vehicle.cp.actualTarget = {
											line = lineIndex;
											column = mostFillLevelIndex;
													}
						vehicle.cp.mode9SavedLastFillLevel = courseplay:round(fillUnit.fillLevel,1)
						
						stopSearching = true
						break
					end
				end
			end
		end
	end
end