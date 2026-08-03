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

| Action | Keyboard | Gamepad |
|--------|----------|---------|
| Steer left/right | A / D | Left stick |
| Tuck (speed boost) | W | Left stick down |
| Edge (slow) | S | Left stick up |
| Jump | Space | A / Cross |
| Camera | Mouse | Right stick |
| Restart | R | Start |
| Free-ride / Race toggle | Tab | Select |

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
