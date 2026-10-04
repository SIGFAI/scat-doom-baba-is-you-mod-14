// HUD: the title card, the rules in force (word tiles, top left), the latest rule change (big, top centre, with
// the cat's comment), the cat's nine lives (top right) and a Minecraft experience bar (bottom centre).

class SICHud : EventHandler
{
	Font fnt;
	TextureID tiles[W_COUNT];
	TextureID catIcon;

	override void OnRegister()
	{
		fnt = Font.GetFont("MCFont");
		if (!fnt) fnt = SmallFont;
		for (int i = 0; i < W_COUNT; i++) tiles[i] = TexMan.CheckForTexture(String.Format("WORD%c0", 65 + i), TexMan.Type_Any);
		catIcon = TexMan.CheckForTexture("SCATA1", TexMan.Type_Any);
	}

	ui void Text(String s, double x, double y, double sc, int col = Font.CR_WHITE, double alpha = 1., bool centre = false)
	{
		if (centre) x -= fnt.StringWidth(s) * sc / 2;
		Screen.DrawText(fnt, col, x, y, s, DTA_ScaleX, sc, DTA_ScaleY, sc, DTA_Alpha, alpha);
	}

	ui void Tile(int w, double x, double y, double size, double alpha = 1., bool dim = false)
	{
		if (w < 0 || w >= W_COUNT) return;
		Screen.DrawTexture(tiles[w], false, x, y, DTA_DestWidthF, size, DTA_DestHeightF, size, DTA_LeftOffset, 0, DTA_TopOffset, 0,
			DTA_Alpha, alpha, DTA_ColorOverlay, dim ? Color(150, 0, 0, 0) : Color(0, 0, 0, 0));
	}

	override void RenderOverlay(RenderEvent e)
	{
		let r = SICRules.Get();
		if (!r || automapactive) return;
		double W = Screen.GetWidth(), H = Screen.GetHeight();
		double u = H / 1080.;
		int t = level.maptime;

		// title card, first seconds
		if (t < 35 * 5)
		{
			double a = t < 35 * 4 ? 1. : 1. - (t - 35 * 4) / 35.;
			double ty = H - 330 * u;   // low on the screen: the cat's first sentence forms at the horizon
			Text("THE SUPERINTELLIGENT CAT", W / 2, ty, 3.5 * u, Font.CR_ORANGE, a, true);
			Text("A genius cat learned to rewrite the rules of reality.", W / 2, ty + 96 * u, 2 * u, Font.CR_WHITE, a, true);
			Text("Shoot its word blocks out of line to break its rules. Take all 9 of its lives.", W / 2, ty + 140 * u, 2 * u, Font.CR_GOLD, a, true);
		}

		// rules in force
		double x0 = 24 * u, y = 24 * u, ts = 54 * u;
		if (r.ruleS.Size())
		{
			Text("RULES", x0, y, 2 * u, Font.CR_GOLD);
			y += 44 * u;
			for (int i = 0; i < r.ruleS.Size(); i++)
			{
				Tile(r.ruleS[i], x0, y, ts);
				Tile(W_IS, x0 + ts + 4 * u, y, ts);
				Tile(r.ruleO[i], x0 + 2 * (ts + 4 * u), y, ts);
				y += ts + 6 * u;
			}
		}

		// latest change, big
		int age = t - r.annAt;
		if (r.annAt > 0 && age < 35 * 4)
		{
			double a = age < 35 * 3 ? 1. : 1. - (age - 35 * 3) / 35.;
			double pop = age < 8 ? 0.6 + 0.4 * age / 8. + 0.15 * sin(age * 22.5) : 1.;
			double big = 120 * u * pop;
			double cy = 70 * u;
			bool lifeLost = r.annO < 0;
			String head = lifeLost ? "THE CAT LOST A LIFE!" : (r.annBroken ? "RULE BROKEN!" : "NEW RULE!");
			Text(head, W / 2, cy - 54 * u, 2.5 * u, r.annBroken ? Font.CR_RED : Font.CR_GREEN, a, true);
			if (!lifeLost)
			{
				double rowW = 3 * big + 2 * 10 * u;
				double x = W / 2 - rowW / 2;
				Tile(r.annS, x, cy, big, a, r.annBroken);
				Tile(W_IS, x + big + 10 * u, cy, big, a, r.annBroken);
				Tile(r.annO, x + 2 * (big + 10 * u), cy, big, a, r.annBroken);
				if (r.annBroken) Screen.DrawThickLine(int(x - 10 * u), int(cy + big * 0.55), int(x + rowW + 10 * u), int(cy + big * 0.45), 12 * u, Color(255, 230, 40, 40), int(255 * a));
				cy += big + 14 * u;
			}
			else cy += 10 * u;
			Text("CAT: \"" .. r.annLine .. "\"", W / 2, cy, 2 * u, Font.CR_ORANGE, a, true);
		}

		// the cat's lives
		if (r.cat || r.ended)
		{
			int lives = r.cat ? r.cat.lives : 0;
			if (r.cat && r.cat.health <= 0) lives = 0;
			double ix = W - 24 * u - 9 * 62 * u, iy = 58 * u;
			Text("CAT LIVES", W - 24 * u - fnt.StringWidth("CAT LIVES") * 2 * u, 20 * u, 2 * u, Font.CR_ORANGE);
			for (int i = 0; i < 9; i++)
				Screen.DrawTexture(catIcon, false, ix + i * 62 * u, iy, DTA_DestWidthF, 60 * u, DTA_DestHeightF, 43 * u,
					DTA_LeftOffset, 0, DTA_TopOffset, 0, DTA_Alpha, i < lives ? 1. : 0.22);
		}

		// experience bar
		double bw = 560 * u, bh = 14 * u, bx = W / 2 - bw / 2, by = H - 64 * u;
		Screen.Dim(Color(0, 0, 0), 0.75, int(bx - 3 * u), int(by - 3 * u), int(bw + 6 * u), int(bh + 6 * u));
		double fill = r.xp / double(12 * (r.xpLevel + 1));
		Screen.Dim(Color(110, 230, 40), 1., int(bx), int(by), int(bw * fill), int(bh));
		Screen.Dim(Color(200, 255, 120), 1., int(bx), int(by), int(bw * fill), int(3 * u));
		Text(String.Format("%d", r.xpLevel), W / 2, by - 40 * u, 2.5 * u, Font.CR_GREEN, 1, true);
		if (r.xpLevelAt > 0 && t - r.xpLevelAt < 70)
			Text("LEVEL UP!", W / 2, by - 90 * u, 3 * u, Font.CR_GREEN, 1. - (t - r.xpLevelAt) / 70., true);
	}
}
