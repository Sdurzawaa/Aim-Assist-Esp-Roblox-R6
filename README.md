# 🎯 ESP & Aim Assist Script (Educational Project)

> An experimental project to learn overlay (ESP) and aim assistance techniques for Lua-based games (e.g., Roblox).  
> Built for educational and research purposes.

---

## ✨ Features
- **ESP (Extra Sensory Perception)**
  - Display player/NPC positions
  - Highlight models / boxes / names / healthbar
  - Distance indicator
- **Aim Assist**
  - Auto-lock to the nearest target within a FOV circle
  - Smooth aiming (no harsh snapping)
  - Configurable FOV
  - Wall check
- **UI Controls**
  - Toggle ON/OFF
  - Smoothness & target priority settings

---

## ⚙️ Requirements
- Lua executor (for private testing environments)
- Lua-based game (e.g., Roblox)
- Basic Lua scripting knowledge

---

## 🚀 How to Use
1. Launch the game in a testing environment / private server  
2. Inject the script using your executor  
3. Enable features from the UI:
   - ESP: ON  
   - Aim Assist: ON  

---

## 🧠 Technical Overview
- **ESP**  
  Uses `Highlight`, `BillboardGui`, or drawing APIs to mark entities in world space.
- **Aim Assist**  
  Finds the nearest valid target within a radius and smoothly adjusts the camera using interpolation (lerp).

---

## 🛡️ Disclaimer
> This project is intended **for educational, research, and private testing purposes only**.  
> Using this on public servers or in ways that violate a game’s ToS may result in bans or penalties.  
> All risks are borne by the user.

---

## 🤝 Credits
- Script logic & core ideas: **Sdurzawaa**  
- AI Assistant: **Claude AI** (assisted with ideas, debugging, and logic optimization)  
- Community references: Roblox documentation & developer forums  

---

## 📌 Notes
- Do not use on competitive or public servers.  
- Use this project to learn:
  - Vector math  
  - Camera control  
  - Raycasting & target selection  
  - Lua UI scripting  

---

## 📄 License
Educational Use Only  
Not for commercial distribution.
