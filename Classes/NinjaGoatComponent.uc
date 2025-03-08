class NinjaGoatComponent extends GGMutatorComponent;

var GGGoat gMe;
var GGMutator myMut;
var name lastKey;
var bool dashing;
var float dashDuration;
var float doubleKeypressTime;
var vector oldVelocity;
var float oldStrafeSpeed;
var float oldWalkSpeed;
var float oldReverseSpeed;
var float oldSprintSpeed;
var ParticleSystem mDashParticleTemplate;
var ParticleSystemComponent mDashParticle;
var AudioComponent mAC;
var SoundCue mDashCue;
var float dashSpeed;
var bool ninjaReflexes;
var float ninjaReflexesDilation;
var bool tooLate;
var float lastBaseY, lastStrafe;

var array<ShadowClone> mShadowClones;
var int maxShadowClones;
var int nextSwapIndex;
var vector spawnLoc;
var bool lickPressed;

/**
 * See super.
 */
function AttachToPlayer( GGGoat goat, optional GGMutator owningMutator )
{
	super.AttachToPlayer(goat, owningMutator);

	if(mGoat != none)
	{
		gMe=goat;
		myMut=owningMutator;

		gMe.mRagdollCollisionSpeed=1000000000;
		gMe.mRagdollLandSpeed=1000000;
	}
}

function NotifyOnPossess( Controller C, Pawn P )
{
	super.NotifyOnPossess(C, P);

	if(P == gMe)
	{
		doubleKeypressTime=GGLocalPlayer(PlayerController( C ).Player).mIsUsingGamePad?0.3f:default.doubleKeypressTime;
	}
}

function KeyState( name newKey, EKeyState keyState, PlayerController PCOwner )
{
	local GGPlayerInputGame localInput;
	local vector direction;
	local float durationModifier;

	if(PCOwner != gMe.Controller)
		return;

	localInput = GGPlayerInputGame( PCOwner.PlayerInput );

	if( keyState == KS_Down )
	{
		//Dash if double press on direction
		direction=vect(0, 0, 0);
		if(newKey == lastKey)
		{
			//myMut.WorldInfo.Game.Broadcast(myMut, "double keypress detected : " $ newKey);
			if(!tooLate)
			{
				if(localInput.IsKeyIsPressed("GBA_Forward", string( newKey )) || newKey == 'PadUp')
				{
					direction=Vector(gMe.Rotation)<<Rotator(vect(1,0,0));
				}
				if(localInput.IsKeyIsPressed("GBA_Back", string( newKey )) || newKey == 'PadDown')
				{
					direction=Vector(gMe.Rotation)<<Rotator(vect(-1,0,0));
				}
				if(localInput.IsKeyIsPressed("GBA_Left", string( newKey )) || newKey == 'PadLeft')
				{
					direction=Vector(gMe.Rotation)<<Rotator(vect(0,1,0));
				}
				if(localInput.IsKeyIsPressed("GBA_Right", string( newKey )) || newKey == 'PadRight')
				{
					direction=Vector(gMe.Rotation)<<Rotator(vect(0,-1,0));
				}

				Dash(direction);
			}
		}
		lastKey = newKey;
		if(dashing)//Prevent key spam detected as double keypress
		{
			lastKey='';
		}

		//Detect if double keypress is valid
		if( gMe.IsTimerActive( NameOf( DoubleKeyPressFail ) ) )
		{
			gMe.ClearTimer( NameOf( DoubleKeyPressFail ) );
		}
		durationModifier=myMut.WorldInfo.Game.GameSpeed;
		if(ninjaReflexes)
		{
			durationModifier*=ninjaReflexesDilation;
		}
		gMe.SetTimer( doubleKeypressTime*durationModifier, false, NameOf( DoubleKeyPressFail ), self);
		//gMe.ResetTimerTimeDilation(NameOf( DoubleKeyPressFail ));
		tooLate=false;

		//Allow to unragdoll in the air
		if(localInput.IsKeyIsPressed("GBA_ToggleRagdoll", string( newKey )))
		{
			//WorldInfo.Game.Broadcast(self, "ragdoll key");
			if(gMe.mIsRagdoll && gMe.mIsInAir)
			{
				StandUpInAir();
			}
		}

		if(localInput.IsKeyIsPressed("GBA_AbilityBite", string( newKey )))
		{
			lickPressed = true;
		}

		//Toogle ninja reflexes or swap clone
		if(newKey == 'X' || newKey == 'XboxTypeS_LeftShoulder')
		{
			if(gMe.Controller != none && (!GGPlayerControllerGame( gMe.Controller ).mFreeLook || !SwapClone()))
			{
				ToggleNinjaReflexes();
			}
		}
	}
	else if( keyState == KS_Up )
	{
		if(localInput.IsKeyIsPressed("GBA_AbilityBite", string( newKey )))
		{
			lickPressed = false;
		}
	}
}

function DoubleKeyPressFail()
{
	//myMut.WorldInfo.Game.Broadcast(myMut, "double keypress fail");
	tooLate=true;
}

function StandUpInAir()
{
	local rotator NewRotation;
	local bool tooSoon;

	tooSoon = myMut.WorldInfo.TimeSeconds - gMe.mTimeForRagdoll < gMe.mMinRagdollTime;
	if( tooSoon )
	{
		return;
	}

	gMe.mWasRagdollStartedByPlayer = false;

	// Make sure the rotation when we stand up is same as the rotation of the ragdoll
	NewRotation = gMe.Rotation;
	NewRotation.Yaw = rotator( gMe.mesh.GetBoneAxis( gMe.mStandUpBoneName, AXIS_X ) ).Yaw;
	gMe.SetRotation( NewRotation );

	if(gMe.mIsRagdoll && !gMe.mTerminatingRagdoll && gMe.mIsInAir)
	{
		gMe.CollisionComponent = gMe.mesh;
		gMe.SetPhysics( PHYS_Falling );
		gMe.SetRagdoll( false );
	}
}

function Dash(vector direction)
{
	local float durationModifier;

	if(dashing || gMe.mIsRagdoll || IsZero(direction))
	{
		return;
	}
	//myMut.WorldInfo.Game.Broadcast(myMut, "Dash!");
	mDashParticle = gMe.WorldInfo.MyEmitterPool.SpawnEmitterMeshAttachment( mDashParticleTemplate, gMe.mesh, 'EffectSocket_01', true );
	myMut.PlaySound( mDashCue, , , , gMe.Location );
	oldStrafeSpeed=gMe.mStrafeSpeed;
	gMe.mStrafeSpeed=dashSpeed;
	oldWalkSpeed=gMe.mWalkSpeed;
	gMe.mWalkSpeed=dashSpeed;
	oldReverseSpeed=gMe.mReverseSpeed;
	gMe.mReverseSpeed=dashSpeed;
	oldSprintSpeed=gMe.mSprintSpeed;
	gMe.mSprintSpeed=dashSpeed;
	oldVelocity=gMe.Velocity;
	gMe.Velocity=Normal(direction)*dashSpeed;
	durationModifier=1.f;
	if(ninjaReflexes)
	{
		durationModifier=1;//ninjaReflexesDilation;
	}
	gMe.SetTimer( dashDuration*durationModifier, false, NameOf( StopDash ), self);
	if(lickPressed)
	{
		spawnLoc=gMe.Location;
		gMe.SetTimer( dashDuration*durationModifier, false, NameOf( SpawnShadowClone ), self);
	}
	dashing=true;
}

function StopDash()
{
	//myMut.WorldInfo.Game.Broadcast(myMut, "Stop Dash");
	if(!dashing)
	{
		return;
	}
	gMe.mStrafeSpeed=oldStrafeSpeed;
	gMe.mWalkSpeed=oldWalkSpeed;
	gMe.mReverseSpeed=oldReverseSpeed;
	gMe.mSprintSpeed=oldSprintSpeed;
	gMe.Velocity=oldVelocity;
	if(gMe.Physics == PHYS_WallRun)
	{
		gMe.Velocity.z=600.f;
	}
	dashing=false;
}

/*
 * Ragdoll management
 */
function OnRagdoll( Actor ragdolledActor, bool isRagdoll )
{
	local ShadowClone shadowClone;

	super.OnRagdoll(ragdolledActor, isRagdoll);

	if(dashing && isRagdoll)
	{
		if(ragdolledActor == gMe)
		{
			StopDash();
		}
	}
	// Kill shadow clones if they ragdoll
	foreach mShadowClones(shadowClone)
	{
		if(ragdolledActor == shadowClone)
		{
			DestroyShadowClone(shadowClone);
			break;
		}
	}
}

function ToggleNinjaReflexes()
{
	local GGPlayerControllerGame gpc;

	if(gMe.Controller == none)
		return;

	ninjaReflexes=!ninjaReflexes;
	gpc = GGPlayerControllerGame( gMe.Controller );

	if(ninjaReflexes)
	{
		gMe.CustomTimeDilation=ninjaReflexesDilation;
		gMe.RotationRate*=ninjaReflexesDilation;
		gMe.mPawnTurnInterpSpeed*=ninjaReflexesDilation*2.f;
		gMe.mPawnTurnInterpSpeedAir*=ninjaReflexesDilation*2.f;
		gpc.mRotationRate*=ninjaReflexesDilation;
		gpc.mPawnRotInterpSpeedMax*=ninjaReflexesDilation;
		gpc.mPawnRotInterpSpeed*=ninjaReflexesDilation;
		gpc.mPawnRotInterpSpeedIncrease*=ninjaReflexesDilation;
		gpc.mKeyRotationRate*=ninjaReflexesDilation;
	}
	else
	{
		gMe.CustomTimeDilation=1.f;
		gMe.RotationRate/=ninjaReflexesDilation;
		gMe.mPawnTurnInterpSpeed/=ninjaReflexesDilation*2.f;
		gMe.mPawnTurnInterpSpeedAir/=ninjaReflexesDilation*2.f;
		gpc.mRotationRate/=ninjaReflexesDilation;
		gpc.mPawnRotInterpSpeedMax/=ninjaReflexesDilation;
		gpc.mPawnRotInterpSpeed/=ninjaReflexesDilation;
		gpc.mPawnRotInterpSpeedIncrease/=ninjaReflexesDilation;
		gpc.mKeyRotationRate/=ninjaReflexesDilation;
	}
}

function Tick( float deltaTime )
{
	local float currentBaseY, currentStrafe;

	//Allow to stick to walls
	if(gMe.Physics == PHYS_WallRun)
	{
		gMe.Velocity.z = FMax(gMe.Velocity.z, 0.f);
	}

	//Double press management for controllers
	if(gMe.Controller != none && GGLocalPlayer(PlayerController( gMe.Controller ).Player).mIsUsingGamePad)
	{
		currentBaseY=PlayerController( gMe.Controller ).PlayerInput.aBaseY;
		currentStrafe=PlayerController( gMe.Controller ).PlayerInput.aStrafe;


		if(currentBaseY > 0.8f && lastBaseY <= 0.8f && lastBaseY > 0)
		{
			//myMut.WorldInfo.Game.Broadcast(myMut, "Up");
			KeyState('PadUp', KS_Down, PlayerController(gMe.Controller));
		}
		else if(currentBaseY < -0.8f && lastBaseY >= -0.8f && lastBaseY < 0)
		{
			//myMut.WorldInfo.Game.Broadcast(myMut, "Down");
			KeyState('PadDown', KS_Down, PlayerController(gMe.Controller));
		}
		else if(currentStrafe > 0.8f && lastStrafe <= 0.8f && lastStrafe > 0)
		{
			//myMut.WorldInfo.Game.Broadcast(myMut, "Right");
			KeyState('PadRight', KS_Down, PlayerController(gMe.Controller));
		}
		else if(currentStrafe < -0.8f && lastStrafe >= -0.8f && lastStrafe < 0)
		{
			//myMut.WorldInfo.Game.Broadcast(myMut, "Left");
			KeyState('PadLeft', KS_Down, PlayerController(gMe.Controller));
		}

		lastBaseY=PlayerController( gMe.Controller ).PlayerInput.aBaseY;
		lastStrafe=PlayerController( gMe.Controller ).PlayerInput.aStrafe;
	}
}

function SpawnShadowClone()
{
	local ShadowClone newShadowClone;
	local rotator spawnRot;

	spawnRot.Yaw=gMe.Rotation.Yaw;
	newShadowClone = myMut.Spawn(class'ShadowClone',gMe,, spawnLoc, spawnRot,, true);
	mShadowClones.AddItem(newShadowClone);

	if((myMut.WorldInfo.Game.GameSpeed >= 1.f || myMut.WorldInfo.bPlayersOnly) && mShadowClones.Length > maxShadowClones)
	{
		DestroyShadowClone(mShadowClones[0]);
	}
	nextSwapIndex = mShadowClones.Length - 1;
}

function DestroyShadowClone(GGGoat shadowClone)
{
	mShadowClones.RemoveItem(shadowClone);
	gMe.WorldInfo.MyEmitterPool.SpawnEmitter( mDashParticleTemplate, shadowClone.Location);

	shadowClone.ShutDown();
	shadowClone.Destroy();
}

function bool SwapClone()
{
	local ShadowClone sClone;
	local vector destination, oldLocation, destVel, oldVel;
	local rotator destRotation, oldRotation, camOffset;

	if(mShadowClones.Length == 0 || gMe.mIsRagdoll || gMe.DrivenVehicle != none || gMe.Controller == none)
		return false;

	if(nextSwapIndex < 0 || nextSwapIndex >= mShadowClones.Length)
	{
		nextSwapIndex = mShadowClones.Length - 1;
	}

	sClone = mShadowClones[nextSwapIndex];
	nextSwapIndex--;

	oldLocation = gMe.Location;
	oldRotation.Yaw = gMe.Rotation.Yaw;
	oldVel = gMe.Velocity;
	destination = sClone.Location;
	destRotation = sClone.Rotation;
	destVel = sClone.Velocity;

	//Swap positions
	gMe.SetPhysics(PHYS_None);
	sClone.SetPhysics(PHYS_None);

	gMe.bNoEncroachCheck = true;
	sClone.bNoEncroachCheck = true;

	sClone.SetCloneLocation(gMe, destination);
	sClone.SetCloneLocation(sClone, oldLocation);

	gMe.bNoEncroachCheck = gMe.default.bNoEncroachCheck;
	sClone.bNoEncroachCheck = sClone.default.bNoEncroachCheck;

	camOffset = PlayerController(gMe.Controller).PlayerCamera.Rotation - gMe.Rotation;

	gMe.SetRotation(destRotation);
	sClone.SetRotation(oldRotation);

	PlayerController(gMe.Controller).PlayerCamera.SetRotation(gMe.Rotation + camOffset);

	gMe.SetPhysics(PHYS_Falling);
	sClone.SetPhysics(PHYS_Falling);

	gMe.Velocity=destVel;
	sClone.Velocity=oldVel;
	if(VSize(sClone.Velocity) < 0.1f)
	{
		sClone.AddVelocity(vect(0, 0, -1), sClone.Location, class'GGDamageType');
	}

	return true;
}

defaultproperties
{
	gMe=none
	lastKey=none
	dashing=false
	oldVelocity=(x=0, y=0, z=0)
	oldStrafeSpeed=0.f
	oldWalkSpeed=0.f
	oldReverseSpeed=0.f
	oldSprintSpeed=0.f
	ninjaReflexes=false
	tooLate=true

	mDashParticleTemplate=ParticleSystem'Goat_Effects.Effects.Effects_Landing_01'
	mDashCue=SoundCue'Goat_Sounds.Cue.Fan_Jump_Cue'

	dashSpeed=10000.f
	dashDuration=0.2f
	doubleKeypressTime=0.2f
	ninjaReflexesDilation=4.f
	maxShadowClones=3
}