// Minecraft feel: block chips on impacts, the grey "poof" of a mob vanishing, XP orbs that fly to the player,
// sparkles when a rule forms, and the tip-over death every monster gets.

class SICChip : Actor
{
	int life;
	Default
	{
		Radius 2;
		Height 2;
		Scale 0.7;
		Gravity 0.8;
		+NOBLOCKMAP
		+DROPOFF
		+NOTELEPORT
		+MOVEWITHSECTOR
		+CANNOTPUSH
	}
	States
	{
	Spawn:
		MCCH A -1;
		Stop;
	}
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		frame = random(0, 3);
		life = random(25, 45);
	}
	override void Tick()
	{
		Super.Tick();
		if (isFrozen()) return;
		if (pos.z <= floorz) vel.xy *= 0.6;
		if (--life <= 0) Destroy();
	}
}

class SICPoof : Actor
{
	Default
	{
		Scale 0.45;
		+NOINTERACTION
		+NOBLOCKMAP
	}
	States
	{
	Spawn:
		MCPF A 3 NoDelay { vel.z = frandom(0.6, 1.4); vel.xy = (frandom(-0.6, 0.6), frandom(-0.6, 0.6)); }
		MCPF BCD 4;
		Stop;
	}
}

// A white sparkle, tinted per use (rule colours).
class SICSparkle : Actor
{
	Default
	{
		Scale 0.7;
		RenderStyle "AddStencil";
		StencilColor "FFFFFF";
		+NOINTERACTION
		+NOBLOCKMAP
		+BRIGHT
	}
	States
	{
	Spawn:
		MCSP ABC 4;
		Stop;
	}
}

class SICXPOrb : Actor
{
	int age;
	Default
	{
		Radius 4;
		Height 6;
		Scale 0.4;
		Gravity 0.5;
		+NOBLOCKMAP
		+DROPOFF
		+NOTELEPORT
		+BRIGHT
		+CANNOTPUSH
	}
	States
	{
	Spawn:
		MCXP A -1;
		Stop;
	}
	override void Tick()
	{
		Super.Tick();
		if (isFrozen()) return;
		age++;
		frame = (age / 4) % 2;
		let mo = players[consoleplayer].mo;
		if (!mo) return;
		if (age > 22)
		{
			bNoGravity = true;
			Vector3 d = Vec3To(mo) + (0, 0, 6);   // to the feet: an orb never flies into the camera
			double len = d.Length();
			if (len < 64 || age > 140)
			{
				let h = SICRules.Get();
				if (h) h.AddXP(1);
				mo.A_StartSound("sic/xp", CHAN_AUTO, CHANF_OVERLAP, 0.7);
				Destroy();
				return;
			}
			vel = d / len * min(14., 3. + age * 0.12);
		}
		else if (pos.z <= floorz) vel.xy *= 0.7;
	}
}

// The dying monster turns red, tips over on its side, then vanishes in a poof and drops XP (any monster).
class SICDeathFX : Actor
{
	Actor victim;
	double rollTo;
	int t, orbs;

	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
		+ROLLSPRITE
	}
	States
	{
	Spawn:
		TNT1 A -1;
		Stop;
	}

	static void Start(Actor m)
	{
		State st = m.FindState("Death");
		bool own = m is "SICMob" || m is "SICCat";
		if (!own) st = m.FindState("Pain") ? m.FindState("Pain") : m.SeeState;
		if (!st) return;
		let fx = SICDeathFX(Spawn("SICDeathFX", m.pos));
		if (!fx) return;
		fx.victim = m;
		fx.sprite = st.sprite;
		fx.frame = st.Frame;
		fx.angle = m.angle;
		fx.scale = m.scale;
		fx.rollTo = own ? 0 : (random(0, 1) ? 90 : -90);
		fx.orbs = clamp(m.SpawnHealth() / 30, 2, 8);
		fx.A_SetTranslation('MCRed');
		m.A_SetRenderStyle(1, STYLE_None);
	}

	override void Tick()
	{
		if (isFrozen()) return;
		t++;
		if (victim) SetOrigin(victim.pos, true);
		if (t <= 8 && rollTo) A_SetRoll(rollTo * t / 8., SPF_INTERPOLATE);
		if (t == 24)
		{
			for (int i = 0; i < 5; i++) Spawn("SICPoof", pos + (frandom(-20, 20), frandom(-20, 20), frandom(6, 40)));
			for (int i = 0; i < orbs; i++)
			{
				let o = Spawn("SICXPOrb", pos + (0, 0, 16));
				if (o) o.vel = (frandom(-3, 3), frandom(-3, 3), frandom(3, 6));
			}
			A_StartSound("sic/poof", CHAN_AUTO);
			if (victim && victim.health <= 0) victim.Destroy();
			Destroy();
		}
	}
}

// Bullets chip the blocks: pixel chips and a crunch instead of Doom's spark.
class SICBulletPuff : BulletPuff replaces BulletPuff
{
	Default
	{
		Scale 0.3;
	}
	States
	{
	Spawn:
	Melee:
		MCPF D 3 NoDelay
		{
			for (int i = 0; i < 4; i++)
			{
				let c = Spawn("SICChip", pos);
				if (c) c.vel = (frandom(-3, 3), frandom(-3, 3), frandom(1, 5));
			}
			A_StartSound("sic/blockhit", CHAN_AUTO, CHANF_OVERLAP, 0.45);
		}
		MCPF D 3;
		Stop;
	}
}

class SICLaserPuff : Actor
{
	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
		+PUFFONACTORS
		+ALWAYSPUFF
		Scale 0.5;
		RenderStyle "AddStencil";
		StencilColor "40FFFF";
	}
	States
	{
	Spawn:
		MCSP ABC 3 Bright;
		Stop;
	}
}
