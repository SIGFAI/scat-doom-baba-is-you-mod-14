// SICRules: the rules of reality, Baba style. Every few tics it reads the word blocks (NOUN IS X in a row),
// applies what holds (transforms, FLOAT, BIG, WEAK, SLEEP, ROCKET IS CAT) and undoes what broke.
// It also runs the cat's plan: every RULE_GAP tics, or when it loses a life, the cat writes a new sentence
// in front of the player, pushing the last word into place with its head.

class SICRules : EventHandler
{
	const PARSE_TICS = 5;
	const RULE_GAP = 35 * 6;
	const MAX_SENTENCES = 4;
	const TARGET_AFTER = 35 * 6;   // a live rule's last word becomes a target for the demo player after 6 s
	const PUSH_TICS = 26;

	Array<SICWord> words;
	Array<int> ruleS, ruleO;
	SICCat cat;
	int sentences, deckPos, nextRuleAt, catSpawnAt;
	bool rocketCats, ended;

	// the cat pushing a word into place
	SICWord pushWord;
	Vector2 pushDir;
	int pushTics, pushS, pushO;

	// announcements for the HUD
	int annAt, annS, annO;
	bool annBroken;
	String annLine;
	int titleAt;

	int xp, xpLevel, xpLevelAt;

	// effects in progress
	Array<Actor> flashA;
	Array<int> flashT;
	Array<Actor> floaters;
	Array<Actor> fallers;
	Array<double> fallTop;
	Array<Actor> bigs;
	Array<Actor> pops;
	Array<int> popT;

	static const int DECK_S[] = { W_IMP, W_DEMON, W_PIG, W_ROCKET, W_ZOMBIE, W_COW, W_CHICKEN, W_IMP, W_CAT, W_DEMON };
	static const int DECK_O[] = { W_CHICKEN, W_PIG, W_FLOAT, W_CAT, W_COW, W_BIG, W_FLOAT, W_SLEEP, W_BIG, W_COW };

	clearscope static SICRules Get() { return SICRules(EventHandler.Find("SICRules")); }

	// ---------------------------------------------------------------- nouns
	static int NounOf(Actor a)
	{
		if (a is "SICCat") return W_CAT;
		if (a is "SICPig") return W_PIG;
		if (a is "SICCow") return W_COW;
		if (a is "SICChicken") return W_CHICKEN;
		if (a is "DoomImp") return W_IMP;
		if (a is "Demon") return W_DEMON;
		if (a is "ZombieMan" || a is "ShotgunGuy" || a is "ChaingunGuy") return W_ZOMBIE;
		return -1;
	}

	static Class<Actor> ClassOf(int w)
	{
		switch (w)
		{
		case W_IMP: return "DoomImp";
		case W_DEMON: return "Demon";
		case W_ZOMBIE: return "ZombieMan";
		case W_PIG: return "SICPig";
		case W_COW: return "SICCow";
		case W_CHICKEN: return "SICChicken";
		}
		return null;
	}

	bool HasRule(int s, int o)
	{
		for (int i = 0; i < ruleS.Size(); i++) if (ruleS[i] == s && ruleO[i] == o) return true;
		return false;
	}

	static String Quip(int s, int o)
	{
		if (s == W_IMP && o == W_CHICKEN) return "Fireballs are so last millennium. Have some eggs.";
		if (s == W_DEMON && o == W_PIG) return "Pinky? More like Oinky. Peer reviewed.";
		if (s == W_PIG && o == W_FLOAT) return "Behold: pigs fly. I said they would.";
		if (s == W_ROCKET && o == W_CAT) return "Your rockets are cats now. You are welcome.";
		if (s == W_ZOMBIE && o == W_COW) return "Moo. I find cows more intelligent.";
		if (s == W_COW && o == W_BIG) return "Bigger cow, bigger brain. That is science.";
		if (s == W_CHICKEN && o == W_FLOAT) return "Chickens cannot fly. Correction: now they can.";
		if (o == W_SLEEP) return "Nap time is a law of physics now.";
		if (s == W_CAT && o == W_BIG) return "I contain more genius than one small cat can hold.";
		if (s == W_DOOM && o == W_MINECRAFT) return "I rewrote Doom. Everything is blocks now. Purr.";
		if (o == W_WEAK) return "Hmm. That one was a typo.";
		return "Meow. I have improved reality again.";
	}

	// ---------------------------------------------------------------- level start
	override void WorldLoaded(WorldEvent e)
	{
		// Minecraft daylight: no pitch-black rooms
		for (int i = 0; i < level.sectors.Size(); i++)
		{
			let s = level.sectors[i];
			if (s.lightlevel < 168) s.SetLightLevel(168 + (s.lightlevel >> 3));
		}
		titleAt = 1;
		catSpawnAt = 50;
		nextRuleAt = 90;
	}

	override void WorldThingSpawned(WorldEvent e)
	{
		let w = SICWord(e.Thing);
		if (w) { if (!probing) words.Push(w); return; }
		let c = SICCat(e.Thing);
		if (c) cat = c;
	}

	override void WorldThingDamaged(WorldEvent e)
	{
		let m = e.Thing;
		if (!m || !m.bIsMonster || m is "SICWord" || m.health <= 0) return;
		// Minecraft hit: red flash and a little hop backwards
		if (flashA.Find(m) == flashA.Size())
		{
			flashA.Push(m);
			flashT.Push(7);
			m.A_SetTranslation('MCRed');
		}
		else flashT[flashA.Find(m)] = 7;
		if (m.pos.z <= m.floorz + 1 && m.mass < 1000)
		{
			m.vel.z += 3.2;
			let src = e.Inflictor ? e.Inflictor : e.DamageSource;
			if (src && src != m)
			{
				Vector2 d = src.Vec2To(m);
				double len = d.Length();
				if (len > 0) m.vel.xy += d / len * 3.;
			}
		}
		m.A_StartSound("sic/hurt", CHAN_AUTO, CHANF_OVERLAP, 0.8);
	}

	override void WorldThingDied(WorldEvent e)
	{
		let m = e.Thing;
		if (!m || !m.bIsMonster || m is "SICWord") return;
		int k = flashA.Find(m);
		if (k < flashA.Size()) { flashA.Delete(k); flashT.Delete(k); }
		SICDeathFX.Start(m);
		if (m is "SICCat") CatFinale(SICCat(m));
	}

	// "netevent sic_write <noun> <word>": the cat writes that rule now (testing, and a fun console toy)
	override void NetworkProcess(ConsoleEvent e)
	{
		if (!(e.Name ~== "sic_write")) return;
		if (!SICWord.IsNoun(e.Args[0]) || e.Args[1] < 0 || e.Args[1] >= W_COUNT) return;
		reqS.Push(e.Args[0]);   // written as soon as the cat is free, before its own plan
		reqO.Push(e.Args[1]);
		nextRuleAt = level.maptime;
	}
	Array<int> reqS, reqO;
	bool probing;

	// ---------------------------------------------------------------- every tic
	override void WorldTick()
	{
		let mo = players[consoleplayer].mo;
		if (!mo) return;
		int t = level.maptime;

		if (t == 6) OpeningSentence(mo);
		if (!cat && !ended && t >= catSpawnAt) SpawnCat(mo);

		// the cat's plan
		if (pushTics > 0) PushStep();
		else if (cat && cat.health > 0 && !cat.Knocked() && !ended && t >= nextRuleAt) WriteNextRule(mo);

		if (t % PARSE_TICS == 0) { Parse(); Apply(); }
		if (rocketCats) RocketsToCats();
		TauntStep(mo);
		FloatStep(t);
		FallStep();
		FlashStep();
		PopStep();
	}

	// ---------------------------------------------------------------- reading the rules
	SICWord WordNear(Vector2 xy, double z, SICWord except)
	{
		SICWord best = null;
		double bestD = 18;
		for (int i = 0; i < words.Size(); i++)
		{
			let w = words[i];
			if (!w || w == except || w.slideTics > 0 || abs(w.pos.z - z) > 24) continue;
			double d = (w.pos.xy - xy).Length();
			if (d < bestD) { bestD = d; best = w; }
		}
		return best;
	}

	void Parse()
	{
		for (int i = words.Size() - 1; i >= 0; i--) if (!words[i]) words.Delete(i);
		Array<int> ns, no;
		Array<SICWord> litWords;
		for (int i = 0; i < words.Size(); i++)
		{
			let w = words[i];
			if (w.word != W_IS || w.slideTics > 0) continue;
			Vector2 dir = Actor.AngleToVector(w.angle);
			let a = WordNear(w.pos.xy - dir * SICWord.SPACING, w.pos.z, w);
			let b = WordNear(w.pos.xy + dir * SICWord.SPACING, w.pos.z, w);
			if (!a || !b || !SICWord.IsNoun(a.word) || b.word == W_IS || b.word == a.word) continue;
			ns.Push(a.word);
			no.Push(b.word);
			litWords.Push(a);
			litWords.Push(w);
			litWords.Push(b);
			// the last word of a rule that has stood for a while is offered to the demo player as a target
			b.bIsMonster = !b.permanent && level.maptime - b.bornAt > TARGET_AFTER;
		}
		for (int i = 0; i < words.Size(); i++) words[i].SetLit(litWords.Find(words[i]) != litWords.Size());

		// what changed
		for (int i = 0; i < ns.Size(); i++)
		{
			bool had = false;
			for (int j = 0; j < ruleS.Size(); j++) if (ruleS[j] == ns[i] && ruleO[j] == no[i]) had = true;
			if (!had) RuleFormed(ns[i], no[i], litWords[i * 3 + 2]);
		}
		for (int j = 0; j < ruleS.Size(); j++)
		{
			bool still = false;
			for (int i = 0; i < ns.Size(); i++) if (ruleS[j] == ns[i] && ruleO[j] == no[i]) still = true;
			if (!still) RuleBroken(ruleS[j], ruleO[j]);
		}
		ruleS.Move(ns);
		ruleO.Move(no);
		rocketCats = HasRule(W_ROCKET, W_CAT);
	}

	void RuleFormed(int s, int o, SICWord last)
	{
		Console.PrintfEx(PRINT_NONOTIFY, "SIC_RULE on %s IS %s at %d", SICWord.NAMES[s], SICWord.NAMES[o], level.maptime);
		if (level.maptime > 10) Announce(s, o, false, Quip(s, o));
		if (last)
		{
			last.A_StartSound("sic/ruleon", CHAN_AUTO);
			for (int i = 0; i < 16; i++)
			{
				let sp = last.Spawn("SICSparkle", last.pos + (frandom(-90, 30), frandom(-90, 30), frandom(0, 56)));
				if (sp) { sp.SetShade(i % 2 ? "FFFFFF" : "FFE040"); sp.vel.z = frandom(0.5, 2); }
			}
		}
	}

	void RuleBroken(int s, int o)
	{
		Console.PrintfEx(PRINT_NONOTIFY, "SIC_RULE off %s IS %s at %d", SICWord.NAMES[s], SICWord.NAMES[o], level.maptime);
		Announce(s, o, true, s == W_DOOM ? "Who broke Doom? Rude." : "Hey! I was using that rule.");
		let mo = players[consoleplayer].mo;
		if (mo) mo.A_StartSound("sic/ruleoff", CHAN_AUTO);
	}

	void Announce(int s, int o, bool broken, String line)
	{
		annAt = level.maptime;
		annS = s;
		annO = o;
		annBroken = broken;
		annLine = line;
	}

	// ---------------------------------------------------------------- applying them
	void Apply()
	{
		Array<Actor> toTransform;
		Array<int> toNoun;
		let it = ThinkerIterator.Create("Actor");
		Actor a;
		while (a = Actor(it.Next()))
		{
			if (!a.bIsMonster || a.health <= 0 || a is "SICWord") continue;
			int n = NounOf(a);
			if (n < 0) continue;
			for (int i = 0; i < ruleS.Size(); i++)
			{
				if (ruleS[i] != n || ruleO[i] == n || !ClassOf(ruleO[i])) continue;
				if (a is "SICCat") continue;
				toTransform.Push(a);
				toNoun.Push(ruleO[i]);
				break;
			}
			bool fl = HasRule(n, W_FLOAT), big = HasRule(n, W_BIG);
			int fi = floaters.Find(a);
			if (fl && fi == floaters.Size()) { floaters.Push(a); a.bNoGravity = true; a.vel.z += 4; }
			else if (!fl && fi < floaters.Size()) DropFloater(fi);
			int bi = bigs.Find(a);
			if (big && bi == bigs.Size()) MakeBig(a, true);
			else if (!big && bi < bigs.Size()) MakeBig(a, false);
			if (HasRule(n, W_WEAK) && a.health > 1) a.health = 1;
			if (HasRule(n, W_SLEEP))
			{
				a.freezetics = PARSE_TICS + 1;
				if (level.maptime % 20 == 0)
				{
					let z = a.Spawn("SICSparkle", a.pos + (frandom(-8, 8), frandom(-8, 8), a.height));
					if (z) { z.SetShade("8090FF"); z.vel = (0.4, 0, 1.0); }
				}
			}
		}
		for (int i = 0; i < toTransform.Size(); i++) Transform(toTransform[i], toNoun[i]);
	}

	void Transform(Actor a, int to)
	{
		Class<Actor> cls = ClassOf(to);
		if (!a || !cls) return;
		let n = Actor.Spawn(cls, a.pos, ALLOW_REPLACE);
		if (!n) return;
		n.angle = a.angle;
		n.target = a.target;
		n.health = max(1, int(n.SpawnHealth() * double(a.health) / max(1, a.SpawnHealth())));
		if (n.target) n.SetState(n.SeeState);
		for (int i = 0; i < 6; i++) n.Spawn("SICPoof", a.pos + (frandom(-20, 20), frandom(-20, 20), frandom(4, 48)));
		for (int i = 0; i < 8; i++)
		{
			let sp = n.Spawn("SICSparkle", a.pos + (frandom(-24, 24), frandom(-24, 24), frandom(4, 56)));
			if (sp) sp.SetShade("FFE040");
		}
		n.A_StartSound("sic/transform", CHAN_AUTO);
		n.A_StartSound(n.SeeSound, CHAN_VOICE);
		pops.Push(n);
		popT.Push(0);
		int k = floaters.Find(a);
		if (k < floaters.Size()) floaters.Delete(k);
		k = bigs.Find(a);
		if (k < bigs.Size()) bigs.Delete(k);
		k = flashA.Find(a);
		if (k < flashA.Size()) { flashA.Delete(k); flashT.Delete(k); }
		a.ClearCounters();
		a.Destroy();
	}

	void MakeBig(Actor a, bool on)
	{
		let def = GetDefaultByType(a.GetClass());
		if (on)
		{
			bigs.Push(a);
			a.A_SetScale(def.scale.x * 1.5, def.scale.y * 1.5);
			a.A_SetSize(def.radius * 1.4, def.height * 1.5);
			a.health *= 2;
			a.A_StartSound("sic/transform", CHAN_AUTO);
			for (int i = 0; i < 5; i++) a.Spawn("SICPoof", a.pos + (frandom(-30, 30), frandom(-30, 30), frandom(4, 60)));
		}
		else
		{
			bigs.Delete(bigs.Find(a));
			a.A_SetScale(def.scale.x, def.scale.y);
			a.A_SetSize(def.radius, def.height);
			for (int i = 0; i < 4; i++) a.Spawn("SICPoof", a.pos + (frandom(-20, 20), frandom(-20, 20), frandom(4, 40)));
		}
	}

	void DropFloater(int i)
	{
		let a = floaters[i];
		floaters.Delete(i);
		if (!a) return;
		a.bNoGravity = GetDefaultByType(a.GetClass()).bNoGravity;
		fallers.Push(a);
		fallTop.Push(a.pos.z - a.floorz);
	}

	void FloatStep(int t)
	{
		for (int i = floaters.Size() - 1; i >= 0; i--)
		{
			let a = floaters[i];
			if (!a || a.health <= 0) { if (a) a.bNoGravity = false; floaters.Delete(i); continue; }
			double goal = a.floorz + 140 + 18 * sin(t * 5 + i * 70);
			goal = min(goal, a.ceilingz - a.height - 4);
			a.vel.z = clamp((goal - a.pos.z) * 0.08, -2.5, 2.5);
			a.vel.xy *= 0.9;
			if (t % 4 == 0) a.A_SpawnParticle("C0F4FF", SPF_FULLBRIGHT, 16, 4, 0, frandom(-a.radius, a.radius), frandom(-a.radius, a.radius), 0, 0, 0, -1.2);
		}
	}

	// they fall when FLOAT breaks: a hard landing hurts
	void FallStep()
	{
		for (int i = fallers.Size() - 1; i >= 0; i--)
		{
			let a = fallers[i];
			if (!a) { fallers.Delete(i); fallTop.Delete(i); continue; }
			if (a.pos.z > a.floorz + 1) continue;
			if (fallTop[i] > 40 && a.health > 0)
			{
				a.A_StartSound("sic/thud", CHAN_AUTO);
				for (int k = 0; k < 8; k++)
				{
					let c = a.Spawn("SICChip", a.pos + (frandom(-20, 20), frandom(-20, 20), 2));
					if (c) c.vel = (frandom(-3, 3), frandom(-3, 3), frandom(2, 5));
				}
				a.DamageMobj(null, null, 30 + int(fallTop[i] * 0.3), 'Falling');
			}
			fallers.Delete(i);
			fallTop.Delete(i);
		}
	}

	void FlashStep()
	{
		for (int i = flashA.Size() - 1; i >= 0; i--)
		{
			if (!flashA[i]) { flashA.Delete(i); flashT.Delete(i); continue; }
			if (--flashT[i] > 0) continue;
			if (flashA[i].health > 0) flashA[i].Translation = GetDefaultByType(flashA[i].GetClass()).Translation;
			flashA.Delete(i);
			flashT.Delete(i);
		}
	}

	// a new creature pops in: tiny, overshoots, settles
	void PopStep()
	{
		for (int i = pops.Size() - 1; i >= 0; i--)
		{
			let a = pops[i];
			if (!a) { pops.Delete(i); popT.Delete(i); continue; }
			let def = GetDefaultByType(a.GetClass());
			double f = ++popT[i] >= 10 ? 1. : 0.3 + 0.7 * popT[i] / 10. + 0.25 * sin(popT[i] * 18);
			if (bigs.Find(a) < bigs.Size()) f *= 1.5;
			a.A_SetScale(def.scale.x * f, def.scale.y * f);
			if (popT[i] >= 10) { pops.Delete(i); popT.Delete(i); }
		}
	}

	void RocketsToCats()
	{
		Array<Actor> list;
		let it = ThinkerIterator.Create("Rocket");
		Actor r;
		while (r = Actor(it.Next())) if (r.GetClass() == "Rocket" && r.target && r.target.player) list.Push(r);
		for (int i = 0; i < list.Size(); i++)
		{
			r = list[i];
			let c = Actor.Spawn("SICCatRocket", r.pos, ALLOW_REPLACE);
			if (!c) continue;
			c.target = r.target;
			c.vel = r.vel.Unit() * c.Speed;   // a flying cat is slower than a rocket: viewers can see it
			c.angle = r.angle;
			c.pitch = r.pitch;
			c.A_StartSound("sic/meow2", CHAN_VOICE);
			r.Destroy();
		}
	}

	// ---------------------------------------------------------------- the cat's plan
	SICWord MakeWord(int w, Vector3 p, double axis, int sid)
	{
		let wd = SICWord(Actor.Spawn("SICWord", p));
		if (!wd) return null;
		wd.word = w;
		wd.frame = w;
		wd.angle = axis;
		wd.sid = sid;
		return wd;
	}

	// Free floor for a sentence: centre ahead of the player, words along the player's right, plus room for the cat.
	Vector3 spot;      // FindSentenceSpot's answer (out Vector3 parameters trip the JIT)
	double spotAxis;
	int pickS, pickO;

	bool FindSentenceSpot(PlayerPawn mo)
	{
		// centre ahead of the player (straight first, then a little to the sides), words along the player's right,
		// room for the cat's push: slots -1..3 (the pushed word starts at 2.4) must be free floor in view
		static const double DISTS[] = { 340, 300, 400, 260, 460, 220, 520, 180 };
		static const double AIMS[] = { -22, 22, 0, -35, 35, -10, 10, -50, 50 };
		static const double TILTS[] = { 0, 20, -20 };
		int nz, nclear, nfloor, nloc, nsight;
		for (int d = 0; d < DISTS.Size(); d++)
		for (int a = 0; a < AIMS.Size(); a++)
		for (int k = 0; k < TILTS.Size(); k++)
		{
			double axis = mo.angle - 90 + TILTS[k];
			Vector2 dir = Actor.AngleToVector(axis);
			Vector2 c = mo.pos.xy + Actor.AngleToVector(mo.angle + AIMS[a], DISTS[d]);
			double z = level.PointInSector(c).floorplane.ZatPoint(c);
			if (abs(z - mo.pos.z) > 96) { nz++; continue; }
			bool ok = true;
			// keep clear of the other sentences, or their words read into this one
			for (int w = 0; w < words.Size() && ok; w++)
			{
				if (!words[w] || words[w].health <= 0) continue;
				for (int i = -2; i <= 3 && ok; i++)
					if ((words[w].pos.xy - (c + dir * (SICWord.SPACING * i))).Length() < 70) ok = false;
			}
			if (!ok) nclear++;
			for (int i = -1; i <= 3 && ok; i++)
			{
				Vector2 p = c + dir * (SICWord.SPACING * i);
				let sec = level.PointInSector(p);
				if (abs(sec.floorplane.ZatPoint(p) - z) > 8 || sec.ceilingplane.ZatPoint(p) - z < 64) { ok = false; nfloor++; break; }
				probing = true;   // a probe is not a word: keep it out of the word list
				let probe = Actor.Spawn("SICWord", (p, z));
				probing = false;
				if (!probe) { ok = false; break; }
				bool loc = probe.TestMobjLocation();
				ok = loc && probe.CheckSight(mo, SF_IGNOREVISIBILITY);
				if (!loc) nloc++; else if (!ok) nsight++;
				probe.Destroy();
			}
			if (ok) { spot = (c, z); spotAxis = axis; return true; }
		}
		Console.PrintfEx(PRINT_NONOTIFY, "SIC_SPOT none: z %d clear %d floor %d loc %d sight %d", nz, nclear, nfloor, nloc, nsight);
		return false;
	}

	void PickRule(PlayerPawn mo)
	{
		int s, o;
		if (reqS.Size())
		{
			pickS = reqS[0];
			pickO = reqO[0];
			reqS.Delete(0);
			reqO.Delete(0);
			return;
		}
		for (int tries = 0; tries < DECK_S.Size(); tries++)
		{
			s = DECK_S[deckPos % DECK_S.Size()];
			o = DECK_O[deckPos % DECK_S.Size()];
			deckPos++;
			if (!HasRule(s, o)) { pickS = s; pickO = o; return; }
		}
		static const int SUBJ[] = { W_IMP, W_DEMON, W_ZOMBIE, W_PIG, W_COW, W_CHICKEN };
		static const int OBJ[] = { W_PIG, W_COW, W_CHICKEN, W_FLOAT, W_BIG, W_SLEEP };
		s = SUBJ[random(0, SUBJ.Size() - 1)];
		o = OBJ[random(0, OBJ.Size() - 1)];
		if (o == s) o = W_FLOAT;
		pickS = s;
		pickO = o;
	}

	void WriteNextRule(PlayerPawn mo)
	{
		if (!FindSentenceSpot(mo)) { nextRuleAt = level.maptime + 35; return; }
		PickRule(mo);
		StartSentence(pickS, pickO, spot, spotAxis);
		nextRuleAt = level.maptime + RULE_GAP;
	}

	void StartSentence(int s, int o, Vector3 c, double axis)
	{
		// too many sentences: the cat clears the oldest one
		sentences++;
		int oldest = sentences - MAX_SENTENCES;
		for (int i = words.Size() - 1; i >= 0; i--)
			if (words[i] && words[i].sid > 0 && words[i].sid <= oldest && !words[i].permanent) words[i].Crumble();

		Vector2 dir = Actor.AngleToVector(axis);
		MakeWord(s, c - (dir * SICWord.SPACING, 0), axis, sentences);
		MakeWord(W_IS, c, axis, sentences);
		Vector3 start = c + (dir * SICWord.SPACING * 2.4, 0);
		pushWord = MakeWord(o, start, axis, sentences);
		if (!pushWord) return;
		pushWord.slideTo = c + (dir * SICWord.SPACING, 0);
		pushWord.slideTics = PUSH_TICS;
		pushWord.popTics = 0;
		pushDir = dir;
		pushTics = PUSH_TICS;
		pushS = s;
		pushO = o;
		if (cat)
		{
			BlinkCat(cat, start + (dir * 52, 0));
			cat.busy = max(cat.busy, PUSH_TICS + 4);
			cat.angle = atan2(-dir.y, -dir.x);
			cat.SetStateLabel("Push");
			cat.A_StartSound("sic/catmeow", CHAN_VOICE);
		}
		pushWord.A_StartSound("sic/push", CHAN_BODY);
	}

	void PushStep()
	{
		pushTics--;
		if (pushWord && cat && cat.health > 0)
		{
			cat.SetOrigin(pushWord.pos + (pushDir * 52, 0), true);
			cat.vel = (0, 0, 0);
			if (pushTics % 9 == 0) pushWord.A_StartSound("sic/push", CHAN_BODY, CHANF_OVERLAP);
		}
		if (pushTics <= 0 && cat && cat.health > 0)
		{
			cat.SetStateLabel("Smug");
			tauntAt = level.maptime + 45;
		}
	}

	// after a rule, the cat pops up a few steps in front of the player to gloat (and is easy to shoot)
	int tauntAt;
	void TauntStep(PlayerPawn mo)
	{
		if (!tauntAt || level.maptime < tauntAt) return;
		tauntAt = 0;
		if (!cat || cat.health <= 0 || cat.Knocked() || pushTics > 0) return;
		static const double AIMS[] = { 0, 15, -15, 30, -30 };
		static const double DISTS[] = { 190, 230, 150, 270 };
		for (int d = 0; d < DISTS.Size(); d++)
		for (int a = 0; a < AIMS.Size(); a++)
		{
			Vector2 xy = mo.pos.xy + Actor.AngleToVector(mo.angle + AIMS[a], DISTS[d]);
			double z = level.PointInSector(xy).floorplane.ZatPoint(xy);
			if (abs(z - mo.pos.z) > 48) continue;
			Vector3 old = cat.pos;
			cat.SetOrigin((xy, z), false);
			if (!cat.TestMobjLocation() || !cat.CheckSight(mo, SF_IGNOREVISIBILITY)) { cat.SetOrigin(old, false); continue; }
			cat.SetOrigin(old, false);
			BlinkCat(cat, (xy, z));
			cat.target = mo;
			cat.angle = cat.AngleTo(mo);
			cat.SetStateLabel("Taunt");
			return;
		}
	}

	void BlinkCat(SICCat c, Vector3 to)
	{
		for (int i = 0; i < 6; i++) c.Spawn("SICPoof", c.pos + (frandom(-16, 16), frandom(-16, 16), frandom(4, 44)));
		c.SetOrigin(to, false);
		c.ClearInterpolation();
		for (int i = 0; i < 6; i++) c.Spawn("SICPoof", to + (frandom(-16, 16), frandom(-16, 16), frandom(4, 44)));
		c.A_StartSound("sic/poof", CHAN_AUTO);
	}

	void SpawnCat(PlayerPawn mo)
	{
		if (!FindSentenceSpot(mo)) { catSpawnAt = level.maptime + 35; return; }
		Vector3 c = spot;
		let k = SICCat(Actor.Spawn("SICCat", c, ALLOW_REPLACE));
		if (!k) return;
		cat = k;
		k.angle = k.AngleTo(mo);
		k.target = mo;
		k.SetStateLabel("Smug");
		for (int i = 0; i < 8; i++) k.Spawn("SICPoof", c + (frandom(-20, 20), frandom(-20, 20), frandom(4, 48)));
		k.A_StartSound("sic/poof", CHAN_AUTO);
		k.A_StartSound("sic/catmeow", CHAN_VOICE);
	}

	// "DOOM IS MINECRAFT", already written when the level starts: the reason the world is made of blocks.
	void OpeningSentence(PlayerPawn mo)
	{
		if (!FindSentenceSpot(mo)) return;
		Vector3 c = spot;
		double axis = spotAxis;
		Vector2 dir = Actor.AngleToVector(axis);
		static const int W[] = { W_DOOM, W_IS, W_MINECRAFT };
		for (int i = 0; i < 3; i++)
		{
			let w = MakeWord(W[i], c + (dir * SICWord.SPACING * (i - 1), 0), axis, 0);
			if (w) w.permanent = true;
		}
		Announce(W_DOOM, W_MINECRAFT, false, Quip(W_DOOM, W_MINECRAFT));
	}

	void CatKnocked(SICCat c)
	{
		Console.PrintfEx(PRINT_NONOTIFY, "SIC_CAT life lost, %d left at %d", c.lives, level.maptime);
		Announce(W_CAT, -1, true, String.Format("Ow. Life %d of 9 used. I have plenty left.", SICCat.MAXLIVES - c.lives));
		for (int i = 0; i < 10; i++)
		{
			let sp = c.Spawn("SICSparkle", c.pos + (frandom(-20, 20), frandom(-20, 20), frandom(20, 56)));
			if (sp) sp.SetShade("FFE040");
		}
	}

	// back from a lost life: blink next to the player and write a revenge rule at once
	void CatRevenge(SICCat c)
	{
		let mo = players[consoleplayer].mo;
		c.busy = max(c.busy, 70);   // a short shield after coming back
		if (!mo || pushTics > 0) return;
		if (FindSentenceSpot(mo))
		{
			PickRule(mo);
			StartSentence(pickS, pickO, spot, spotAxis);
			nextRuleAt = level.maptime + RULE_GAP;
		}
	}

	void CatFinale(SICCat c)
	{
		ended = true;
		Announce(W_CAT, W_SLEEP, false, "Fine. You win. I need a nap. All nine of them.");
	}

	void AddXP(int n)
	{
		xp += n;
		if (xp >= 12 * (xpLevel + 1))
		{
			xp = 0;
			xpLevel++;
			xpLevelAt = level.maptime;
			let mo = players[consoleplayer].mo;
			if (mo)
			{
				mo.A_StartSound("sic/levelup", CHAN_AUTO);
				mo.GiveBody(10);
			}
		}
	}
}
