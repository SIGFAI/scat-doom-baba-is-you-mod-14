// The SuperIntelligent Cat: reads the rules of reality and rewrites them (SICRules drives the writing).
// Nine lives: each "death" knocks it out, it blinks away and writes a revenge rule; the ninth is final.

class SICCat : Actor
{
	const MAXLIVES = 9;
	int lives;
	int busy;        // tics left pushing a word: the rules handler moves it

	Default
	{
		Monster;
		Health 300;
		Radius 26;
		Height 60;
		Speed 9;
		Mass 150;
		Scale 0.6;
		PainChance 110;
		MinMissileChance 120;
		SeeSound "sic/catmeow";
		PainSound "sic/cathiss";
		ActiveSound "sic/catmeow";
		DeathSound "sic/catyowl";
		Obituary "%o was outsmarted by the SuperIntelligent Cat.";
		Tag "SuperIntelligent Cat";
		+LOOKALLAROUND
		+FLOORCLIP
		+NOINFIGHTING
	}

	States
	{
	Spawn:
		SCAT A 10 A_Look;
		Loop;
	See:
		SCAT ABCD 3 A_Chase;
		Loop;
	Missile:
		SCAT S 12 A_FaceTarget;
		SCAT S 4 Bright
		{
			A_StartSound("sic/laser", CHAN_WEAPON);
			A_CustomRailgun(9, 0, "00FFFF", "C0FFFF", RGF_SILENT | RGF_FULLBRIGHT, 1, 0, "SICLaserPuff", 0, 0, 1200, 16, 1.5, 0, null, 6);
		}
		SCAT G 10;
		Goto See;
	Pain:
		SCAT H 3;
		SCAT H 5 A_Pain;
		Goto See;
	Push:
		SCAT EF 5;
		Loop;
	Smug:
		SCAT G 8 A_StartSound("sic/purr", CHAN_VOICE);
		SCAT G 16;
		Goto See;
	Taunt:   // right in front of the player, gloating about its new rule
		SCAT G 6 A_StartSound("sic/catmeow", CHAN_VOICE);
		SCAT G 20 A_FaceTarget;
		SCAT A 10 A_FaceTarget;
		SCAT G 30 A_StartSound("sic/purr", CHAN_VOICE);
		Goto See;
	LoseLife:
		SCAT K 32;
		SCAT K 1 A_LifeLost;
		Goto See;
	Death:
		SCAT K 6 A_Scream;
		SCAT K -1;
		Stop;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		lives = MAXLIVES;
	}

	override void Tick()
	{
		Super.Tick();
		if (busy > 0) busy--;
	}

	bool Knocked() { return InStateSequence(CurState, FindState("LoseLife")); }

	override int DamageMobj(Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		if (health <= 0) return 0;
		if (busy > 0 || Knocked())
		{
			// too busy being brilliant: shots fizzle on a cyan shimmer
			let s = Spawn("SICSparkle", pos + (frandom(-14, 14), frandom(-14, 14), frandom(10, 44)));
			if (s) s.SetShade("40FFFF");
			return 0;
		}
		damage = min(damage, 120);   // a single rocket never takes a whole life
		if (lives > 1 && damage >= health)
		{
			lives--;
			health = SpawnHealth();
			A_StartSound("sic/catyowl", CHAN_VOICE);
			SetStateLabel("LoseLife");
			let h = SICRules.Get();
			if (h) h.CatKnocked(self);
			return 0;
		}
		return Super.DamageMobj(inflictor, source, damage, mod, flags, angle);
	}

	void A_LifeLost()
	{
		let h = SICRules.Get();
		if (h) h.CatRevenge(self);
	}
}
