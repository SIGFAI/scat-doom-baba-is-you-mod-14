// Blocky farm mobs the cat's rules turn Doom monsters into (IMP IS CHICKEN, DEMON IS PIG, ZOMBIE IS COW).
// Same health and bite as the monster they replace, so a fight still lasts a few seconds.

class SICMob : Actor
{
	Default
	{
		Monster;
		Scale 0.5;
		Mass 120;
		+FLOORCLIP
	}
}

class SICChicken : SICMob
{
	Default
	{
		Health 60;
		Radius 20;
		Height 56;
		Speed 8;
		PainChance 200;
		SeeSound "sic/chicken";
		PainSound "sic/chicken";
		DeathSound "sic/chicken";
		ActiveSound "sic/chicken";
		Obituary "%o was pelted with eggs by a chicken.";
		Tag "Chicken";
	}
	States
	{
	Spawn:
		MCHK A 10 A_Look;
		Loop;
	See:
		MCHK ABCD 3 A_Chase;
		Loop;
	Missile:
		MCHK E 8 A_FaceTarget;
		MCHK F 6 A_SpawnProjectile("SICEgg", 30);
		MCHK E 5;
		Goto See;
	Pain:
		MCHK H 3;
		MCHK H 3 A_Pain;
		Goto See;
	Death:
		MCHK K 6 A_Scream;
		MCHK K -1;
		Stop;
	}
}

class SICEgg : Actor
{
	Default
	{
		Projectile;
		Radius 6;
		Height 8;
		Speed 15;
		Damage 3;
		Scale 0.7;
		DeathSound "sic/eggsplat";
		+RANDOMIZE
		+ROLLSPRITE
		+ZDOOMTRANS
	}
	States
	{
	Spawn:
		MEGG A 1 { roll += 30; }
		Loop;
	Death:
		MEGG A 0
		{
			A_Scream();
			for (int i = 0; i < 10; i++)
				A_SpawnParticle(i % 3 ? "FFE060" : "FFFFF0", SPF_FULLBRIGHT, 20, 5, 0, 0, 0, 4, frandom(-3, 3), frandom(-3, 3), frandom(1, 4), 0, 0, -0.3);
		}
		Stop;
	}
}

class SICPig : SICMob
{
	Default
	{
		Health 150;
		Radius 22;
		Height 44;
		Speed 10;
		PainChance 180;
		MeleeRange 60;
		SeeSound "sic/pig";
		PainSound "sic/pig";
		DeathSound "sic/pig";
		ActiveSound "sic/pig";
		AttackSound "sic/pig";
		Obituary "%o was bitten by a pig.";
		Tag "Pig";
	}
	States
	{
	Spawn:
		MPIG A 10 A_Look;
		Loop;
	See:
		MPIG ABCD 2 A_Chase;
		Loop;
	Melee:
		MPIG E 6 A_FaceTarget;
		MPIG F 6 A_CustomMeleeAttack(random(1, 10) * 4, "sic/pig");
		MPIG E 4;
		Goto See;
	Pain:
		MPIG H 3;
		MPIG H 3 A_Pain;
		Goto See;
	Death:
		MPIG K 6 A_Scream;
		MPIG K -1;
		Stop;
	}
}

class SICCow : SICMob
{
	Default
	{
		Health 80;
		Radius 26;
		Height 62;
		Speed 9;
		PainChance 160;
		MeleeRange 68;
		SeeSound "sic/cow";
		PainSound "sic/cow";
		DeathSound "sic/cow";
		ActiveSound "sic/cow";
		Obituary "%o was headbutted by a cow.";
		Tag "Cow";
	}
	States
	{
	Spawn:
		MCOW A 10 A_Look;
		Loop;
	See:
		MCOW ABCD 3 A_Chase;
		Loop;
	Melee:
		MCOW E 7 A_FaceTarget;
		MCOW F 6 A_CustomMeleeAttack(random(3, 8) * 3, "sic/cow");
		MCOW E 4;
		Goto See;
	Pain:
		MCOW H 3;
		MCOW H 4 A_Pain;
		Goto See;
	Death:
		MCOW K 6 A_Scream;
		MCOW K -1;
		Stop;
	}
}

// ROCKET IS CAT: the player's rockets fly as cats, trailing smoke, and blow up with a meow.
class SICCatRocket : Rocket
{
	Default
	{
		Scale 0.6;
		Speed 13;
		SeeSound "";
		DeathSound "weapons/rocklx";
		Obituary "%o was hit by a flying cat.";
	}
	States
	{
	Spawn:
		CATR A 2 Bright A_CatTrail;
		CATR B 2 Bright A_CatTrail;
		Loop;
	Death:
		MISL B 8 Bright
		{
			A_StartSound("sic/meow", CHAN_VOICE, CHANF_OVERLAP);
			A_Explode();
			for (int i = 0; i < 6; i++) Spawn("SICPoof", pos + (frandom(-24, 24), frandom(-24, 24), frandom(-16, 16)));
			for (int i = 0; i < 16; i++)
				A_SpawnParticle(i % 2 ? "FF9A30" : "FFD27A", SPF_FULLBRIGHT, 30, 6, 0, 0, 0, 0, frandom(-5, 5), frandom(-5, 5), frandom(-1, 6), 0, 0, -0.25);
		}
		MISL C 6 Bright;
		MISL D 4 Bright;
		Stop;
	}
	void A_CatTrail()
	{
		if (level.maptime % 2 == 0) Spawn("SICPoof", pos - vel * 0.6);
		A_SpawnParticle("FFB050", SPF_FULLBRIGHT, 14, 4, 0, frandom(-4, 4) - vel.x * 0.3, frandom(-4, 4) - vel.y * 0.3, frandom(-4, 4));
	}
}
