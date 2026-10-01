# 📦 szcore_benchmark

[![SzCore Resource](https://img.shields.io/badge/SzCore-FiveM%20Resource-00f0ff?style=for-the-badge&logo=fivem&logoColor=white)](https://github.com/Szilko121/SzCore-Framework)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

> Diagnosztikai profilozó és mérés eszköz az erőforrások memóriahasználatához és tick rate optimalizálásához.  
> *Diagnostic profiling and benchmarking tool for measuring resmon, tick rates, and resource memory impact.*

---

## ✨ Főbb Jellemzők (Features)
- 🚀 **Alacsony erőforráshasználat (0.00ms idle)**
- 🔒 **Szerveroldali hitelesítés és biztonsági ellenőrzések**
- 🌐 **Többnyelvűség (i18n): Magyar (HU) & Angol (EN)**
- 🧩 **Szerves integráció az SzCore ökoszisztémával**
- 🔄 **Nyílt exportok és események (Events & Callbacks)**

---

## 📋 Követelmények (Requirements)
- FiveM Server Artifacts (minimum `v5848` vagy frissebb)
- [`szcore`](https://github.com/Szilko121/szcore)
- `oxmysql`
- `ox_lib` (ajánlott)

---

## 📥 Telepítés (Installation)

1. Töltsd le vagy klónozd a repository-t a szervered `resources` mappájába:
   ```bash
   git clone https://github.com/Szilko121/szcore_benchmark.git
   ```
2. Add hozzá a `server.cfg` konfigurációs fájlodhoz:
   ```cfg
   ensure szcore_benchmark
   ```
3. Szükség esetén szabd testre a `config.lua` fájlban található beállításokat.

---

## 💻 Exportok & Használat (Exports)

```lua
-- Kliensoldali lekérdezés példa:
local isReady = exports['szcore_benchmark']:isReady()

-- Szerveroldali esemény példa:
TriggerEvent('szcore_benchmark:server:notify', source, 'Sikeres művelet!')
```

---

## 📜 Licenc
Kiadva a **MIT** licenc alatt. Részletekért lásd a `LICENSE` fájlt.
