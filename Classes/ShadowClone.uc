class ShadowClone extends GGGoat;

function UpdateHeadLookAt();

simulated event PostBeginPlay()
{
	local GGGoat goat;
	local int index;

	super.PostBeginPlay();

	goat=GGGoat(Owner);
	if(goat == none)
		return;

	mesh.SetSkeletalMesh(goat.mesh.SkeletalMesh);
	Mesh.SetPhysicsAsset(goat.Mesh.PhysicsAsset);
	Mesh.SetAnimTreeTemplate(goat.Mesh.AnimTreeTemplate);
	Mesh.AnimSets[ 0 ] = goat.Mesh.AnimSets[ 0 ];
	SetCollisionSize(goat.GetCollisionRadius(), goat.GetCollisionHeight());
	for(index=0 ; index < goat.Mesh.Materials.Length ; index++)
	{
		mesh.SetMaterial(index, goat.mesh.Materials[index]);
	}
	//myMut.WorldInfo.Game.Broadcast(myMut, "Spawn clone");
	SetPhysics( PHYS_None );
	PlaceClone();
	SetPhysics( PHYS_Falling );
	StandUp();
	Controller=none;
	mAnimNodeSlot.PlayCustomAnim( 'Idle', 1.0f, 0.2f, 0.2f, true, true );

	SetOwner(none);
}

/** called when the actor falls out of the world 'safely' (below KillZ and such) */
simulated event FellOutOfWorld(class<DamageType> dmgType)
{
	SetRagdoll(true);
}

/*
 * Place the clone on the floor
 */
function PlaceClone(optional vector pos=vect(0, 0, 0))
{
	local vector traceStart, traceEnd, hitLocation, hitNormal;
	local Actor hitActor;

	// Try to fit cylinder collision into location.
	if(IsZero(pos))
	{
		traceEnd = Location;
	}
	else
	{
		traceEnd = pos;
	}
	traceStart = Location + vect( 0, 0, 1) * GetCollisionHeight() * 1.25f;

	hitActor = Trace( hitLocation, hitNormal, traceEnd, traceStart, true, GetCollisionExtent() );
	if( hitActor == none )
	{
		hitLocation = traceStart;
	}

	if( !SetCloneLocation(self, hitLocation ) )
	{
		// Avoid letting the goat slip through the ground at all cost.
		// This time just check encroachment against the world even if it means the physics may explode!
		bNoEncroachCheck = true;
		if( !SetCloneLocation(self, hitLocation ) )
		{
			// Ops!
		}
		bNoEncroachCheck = default.bNoEncroachCheck;
	}
}

/*
 * Try to place the clone at the proposed location
 */
function bool SetCloneLocation(GGPawn gpawn, vector proposedLocation )
{
	local vector adjustedLocation;

	if( gpawn.SetLocation( proposedLocation ) )
	{
		return true;
	}

	adjustedLocation = proposedLocation + gpawn.GetCollisionRadius() * vect( 1, 1, 0 );
	if( gpawn.SetLocation( adjustedLocation ) )
	{
		return true;
	}
	adjustedLocation = proposedLocation + gpawn.GetCollisionRadius() * vect( 1, -1, 0 );
	if( gpawn.SetLocation( adjustedLocation ) )
	{
		return true;
	}
	adjustedLocation = proposedLocation + gpawn.GetCollisionRadius() * vect( -1, 1, 0 );
	if( gpawn.SetLocation( adjustedLocation ) )
	{
		return true;
	}
	adjustedLocation = proposedLocation + gpawn.GetCollisionRadius() * vect( -1, -1, 0 );
	if( gpawn.SetLocation( adjustedLocation ) )
	{
		return true;
	}

	return false;
}

DefaultProperties
{}