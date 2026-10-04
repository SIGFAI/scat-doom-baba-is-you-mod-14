// Rule words, Baba style: a sentence is three blocks in a row (NOUN IS NOUN/PROPERTY), read along the IS block's
// angle. Shots and explosions knock the blocks around; a block out of line breaks the rule.

enum ESICWord
{
	W_IMP, W_DEMON, W_ZOMBIE, W_ROCKET, W_CAT, W_PIG, W_COW, W_CHICKEN, W_DOOM,
	W_IS,
	W_FLOAT, W_BIG, W_WEAK, W_SLEEP, W_SMART, W_MINECRAFT,
	W_COUNT
}

class SICWord : Actor
{
	const SPACING = 48.;

	int word;
	int sid;          // sentence it was written in
	bool lit;         // part of a rule that holds right now
	bool permanent;   // the opening sentence: never offered to the player as a target
	int slideTics;    // pushed into place by the cat
	Vector3 slideTo;
	int popTics;
	int bornAt;

	static const String NAMES[] = { "IMP", "DEMON", "ZOMBIE", "ROCKET", "CAT", "PIG", "COW", "CHICKEN", "DOOM",
		"IS", "FLOAT", "BIG", "WEAK", "SLEEP", "SMART", "MINECRAFT" };

	Default
	{
		Radius 22;
		Height 46;
		Scale 0.5;
		Mass 250;
		Health 1000;
		Tag "Rule word";
		+SOLID
		+SHOOTABLE
		+NOBLOOD
		+DONTTHRUST
		+NOTELEPORT
		+DONTGIB
		+SLIDESONWALLS
	}

	States
	{
	Spawn:
		WORD A -1;
		Stop;
	}

	static bool IsNoun(int w) { return w >= W_IMP && w <= W_DOOM; }
	static bool IsProp(int w) { return w >= W_FLOAT && w < W_COUNT; }

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		bornAt = level.maptime;
		popTics = 8;
		A_SetTranslation('SICDim');
	}

	override void Tick()
	{
		Super.Tick();
		if (isFrozen()) return;
		frame = word;
		if (slideTics > 0)
		{
			SetOrigin(pos + (slideTo - pos) / slideTics, true);
			vel = (0, 0, 0);
			slideTics--;
		}
		double s = 0.5;
		if (popTics > 0) { popTics--; s = 0.5 * (1. - popTics / 8.) + 0.15 * sin(popTics * 22.5); }
		else if (lit) s = 0.5 + 0.012 * sin(level.maptime * 24 + word * 47);   // live text wobbles, like Baba's
		scale = (s, s);
	}

	void SetLit(bool on)
	{
		if (on == lit) return;
		lit = on;
		bBright = on;
		if (on) Translation = Default.Translation;
		else A_SetTranslation('SICDim');
		if (!on) bIsMonster = false;
	}

	// Shots and blasts shove the block (no health lost): this is how the player breaks a rule.
	override int DamageMobj(Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		if (slideTics > 0 || popTics > 0) return 0;
		Actor from = inflictor ? inflictor : source;
		Vector2 d = from ? from.Vec2To(self) : AngleToVector(angle);
		double len = d.Length();
		d = len > 0 ? d / len : AngleToVector(angle);
		// a fresh rule is set in stone for a few seconds (stray shots barely move it); then it is fair game
		// "DOOM IS MINECRAFT" (permanent) holds the world together and a fresh rule is set in stone for a few seconds
		bool fresh = permanent || (level.maptime - bornAt < SICRules.TARGET_AFTER && !bIsMonster);
		if (fresh)
		{
			let sp = Spawn("SICSparkle", pos + (frandom(-16, 16), frandom(-16, 16), frandom(8, 44)));
			if (sp) sp.SetShade("FFE040");
			return 0;
		}
		double push = clamp(damage * 0.3, 2., 16.);
		vel.xy += d * push;
		vel.z += min(damage * 0.04, 5.);
		for (int i = 0; i < 4; i++)
		{
			let c = Spawn("SICChip", pos + (frandom(-12, 12), frandom(-12, 12), frandom(10, 40)));
			if (c) { c.vel = (d * frandom(1, 4), frandom(2, 6)); c.frame = 0; }
		}
		A_StartSound("sic/push", CHAN_BODY, CHANF_OVERLAP, 0.8);
		return 0;
	}

	// The block shatters into chips (the cat clears an old sentence).
	void Crumble()
	{
		for (int i = 0; i < 12; i++)
		{
			let c = Spawn("SICChip", pos + (frandom(-16, 16), frandom(-16, 16), frandom(4, 44)));
			if (c) c.vel = (frandom(-4, 4), frandom(-4, 4), frandom(2, 7));
		}
		Spawn("SICPoof", pos + (0, 0, 20));
		A_StartSound("sic/blockhit", CHAN_AUTO);
		Destroy();
	}
}
