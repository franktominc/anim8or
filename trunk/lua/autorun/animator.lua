
ANIMATOR = {}

function ANIMATOR.Save( name, tbl )

	file.Write( "animator/" .. name .. ".txt", glon.encode( tbl ) )
	
end

function ANIMATOR.Load( name )

	return glon.decode( file.Read( "animator/" .. name .. ".txt" ) )

end

function ANIMATOR.CreateScene( ply, tbl ) // to be used with save/load

	for k,v in pairs( tbl.Scenes ) do
	
		local prop = ents.Create( v.Type )
		prop:SetPos( v.Positions[1] )
		prop:SetAngles( v.Angles[1] )
		prop:SetModel( v.Model )
		prop:SetSolid( SOLID_VPHYSICS )
		prop:SetNotSolid( true )
		
		if v.Type == "prop_ragdoll" then
		
			for i=0, prop:GetBoneCount() do
		
				prop:SetBonePosition( i, v.BonePositions[1][i], v.BoneAngles[1][i] )
				
			end
			
		end
		
		prop:Spawn()
		
		local phys = prop:GetPhysicsObject()
		
		if ValidEntity( phys ) then
		
			phys:EnableMotion( false )
		
		end
		
		tbl.Scene[k].Prop = prop
		
		ply:AddScene( v )
	
	end

end

function ANIMATOR.Think()

	for k,v in pairs( player.GetAll() ) do
	
		if v.PlayingAnimation then
		
			local key = v.CurrentKeyframe
			local nextkey = v.NextKeyframe
			
			if not key then
			
				key = 1
				nextkey = 2
				v.CurrentKeyframe = 1
				v.NextKeyframe = 2
				v.Durations = {}
				
			end
		
			for c,d in pairs( v:GetScenes() ) do
			
				v.Durations[c] = v.Durations[c] or CurTime() + ( d.Durations[ key ] or 1.0 )
			
				if #d.Positions > 1 then
				
					local mul = d.Transition( v.Durations[c] -  ( d.Durations[ key ] or 1.0 ), ( d.Durations[ key ] or 1.0 ) )
					local pos = LerpVector( mul, d.Positions[ key ], d.Positions[ nextkey ] )
					local ang = LerpAngle( mul, d.Angles[ key ], d.Angles[ nextkey ] )
					
					d.Prop:SetPos( pos )
					d.Prop:SetAngles( ang )
					
					if d.Type == "prop_ragdoll" then
		
						for i=0, d.Prop:GetBoneCount() do
						
							//local pos = LerpVector( mul, d.BonePositions[ key ][i], d.BonePositions[ nextkey ][i] )
							//local ang = LerpAngle( mul, d.BoneAngles[ key ][i], d.BoneAngles[ nextkey ][i] )
		
							//d.Prop:SetBonePosition( i, pos, ang ) <<< THIS IS WRONG
							//d.Prop:SetBoneMatrix( d.BonePositions[ key ][i] )
							
							if d.Prop:GetBoneMatrix( i ) then
							
								d.Prop.BoneTable[i] = d.BonePositions[ key ][i]
								
							end
				
						end
					
					end
					
				end
				
				if v.Durations[c] <= CurTime() then
				
					key = nextkey
					nextkey = nextkey + 1
					
					v.Durations[c] = CurTime() + ( d.Durations[ key ] or 1.0 )
					v.CurrentKeyframe = key
					
					if not d.Positions[ nextkey ] then
					
						v.NextKeyframe = 1
						
					else
					
						v.NextKeyframe = nextkey
					
					end

				end
			
			end
		
		end
		
	end

end

hook.Add( "Think", "ANIMATOR.Think", ANIMATOR.Think )

function ANIMATOR.InitBoneFunc( ent )

	if not ValidEntity( ent ) or ent:GetClass() != "prop_ragdoll" then return end

	ent.BuildBonePositions = function( self, numbones, numphys )
		
		for i=0, numbones do
		
			if self:GetBoneMatrix( i ) and self.BoneTable and self.BoneTable[i] then
			
				self:SetBonePosition( i, unpack( self.BoneTable[i] ) )
			
			end
		
		end
	
	end
	
end

hook.Add( "OnEntityCreated", "ANIMATOR.InitBoneFunc", ANIMATOR.InitBoneFunc )

function TOGGLEANIM( sex )
	
	Entity(1).PlayingAnimation = sex

end

function ANIMTEST()

	local tr = util.TraceLine( util.GetPlayerTrace( Entity(1) ) )
	
	if not ValidEntity( tr.Entity ) then return end
	
	Entity(1):InsertKeyframe( tr.Entity )

end

local meta = FindMetaTable( "Player" )
if not meta then return end 

function meta:AddScene( tbl )

	if not self.Scenes then
	
		self.Scenes = {}
	
	end
	
	table.insert( self.Scenes, tbl )

end

function meta:GetScene( id )

	return self.Scenes[id]

end

function meta:GetScenes()

	return self.Scenes or {}

end

function meta:RemoveScene( id )

	table.remove( self.Scenes, id )

end

function meta:SceneExists( ent )

	for k,v in pairs( self:GetScenes() ) do
	
		if v.Prop == ent then
		
			return k
		
		end
	
	end
	
end

function meta:NewScene( ent )

	local tbl = {}
	tbl.BonePositions = {}
	tbl.Positions = {}
	tbl.Angles = {}
	tbl.Durations = {}
	tbl.Positions[1] = ent:GetPos()
	tbl.Angles[1] = ent:GetAngles()
	tbl.Durations[1] = 1.0
	tbl.Type = ent:GetClass()
	tbl.Model = ent:GetModel()
	tbl.Prop = ent
	
	ent.BoneTable = {}
	
	tbl.Transition = function( start, movetime ) 

		local mul = math.Clamp( ( CurTime() - start ) / movetime, 0, 1 )
		
		return mul  // linear for now
		
	end
	
	self:AddScene( tbl )

end

function meta:InsertKeyframe( ent )

	local k = self:SceneExists( ent )
	
	if not k then 
	
		self:NewScene( ent )
		k = self:SceneExists( ent )
	
	end
	
	self.Scenes[k].Positions[ #self.Scenes[k].Positions + 1 ] = ent:GetPos()
	self.Scenes[k].Angles[ #self.Scenes[k].Angles + 1 ] = ent:GetAngles()
	
	if ent:GetClass() == "prop_ragdoll" then
	
		local num = #self.Scenes[k].BonePositions + 1
	
		self.Scenes[k].BonePositions[ num ] = {}
		
		for i=0, ent:GetBoneCount() do
		
			// local matrix = ent:GetBoneMatrix( i )
		
			self.Scenes[k].BonePositions[ num ][ i ] = { ent:GetBonePosition( i ) }
		
		end
		
	end

end
