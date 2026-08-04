# Peak Ski 🎿

A 3D open-world ski simulator inspired by Ubisoft's *Steep*.  
Built with [Godot 4](https://godotengine.org/) + GDScript.

## Features (Vertical Slice v0.1)

- 🏔️ A hand-sculpted low-poly mountain with jumps and a gully
- ⛷️ Ski physics: gravity-driven speed, edge-carve steering, snow friction & air drag
- 💥 G-force landing model — stick the landing or wipe out
- 🏁 Race challenge: start gate → slalom checkpoints → finish, with a live timer
- 📊 Best-time persistence across sessions
- 🌨️ Snow-spray particles behind skis and ambient wind SFX

## Controls

| Action | Keyboard |
|--------|----------|
| Steer left / right | A / D |
| Tuck (less drag, more speed) | W |
| Edge (brake) | S |
| Jump | Space |
| Camera orbit / zoom | Mouse / wheel |
| Respawn at the top | R |
| Pause menu | Esc |

## The Run

A ~780 m descent: a gentle run-in to get set, steepening into a ~31° pitch with
a jump kicker, then easing into a flat run-out. Ski through the green start
gate to begin the timed run, take all four blue checkpoint gates in order, and
cross the red finish gate. A clean run takes around 25 seconds.

## Requirements

- [Godot 4.x](https://godotengine.org/download/) (no extra plugins needed)
- Windows 10/11 recommended; also runs on macOS & Linux

## How to Run

1. Clone the repo
2. Open Godot 4, click **Import** → select the `peak-ski/` folder → **Open**
3. Press **F5** (Run) — the game starts immediately on `scenes/Main.tscn`

## Roadmap

- [ ] Snowboard sport
- [ ] Wingsuit / paraglide
- [ ] Multiple mountains
- [ ] Online leaderboards
- [ ] Replay capture & share
- [ ] Trick-scoring combos

## License

MIT — see [LICENSE](LICENSE).
