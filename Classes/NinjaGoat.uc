class NinjaGoat extends GGMutator;

var array< NinjaGoatComponent > mComponents;

/**
 * See super.
 */
function ModifyPlayer(Pawn Other)
{
	local GGGoat goat;
	local NinjaGoatComponent ninjaComp;

	super.ModifyPlayer( other );

	goat = GGGoat( other );
	if( goat != none )
	{
		ninjaComp=NinjaGoatComponent(GGGameInfo( class'WorldInfo'.static.GetWorldInfo().Game ).FindMutatorComponent(class'NinjaGoatComponent', goat.mCachedSlotNr));
		if(ninjaComp != none && mComponents.Find(ninjaComp) == INDEX_NONE)
		{
			mComponents.AddItem(ninjaComp);
		}
	}
}

simulated event Tick( float delta )
{
	local int i;

	for( i = 0; i < mComponents.Length; i++ )
	{
		mComponents[ i ].Tick( delta );
	}
	super.Tick( delta );
}

DefaultProperties
{
	mMutatorComponentClass=class'NinjaGoatComponent'
}