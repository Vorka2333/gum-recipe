# vorp_surgery (MVP)

Ressource RedM orientée chirurgie/traumatologie pour VORP (`vorp_core` + `vorp_inventory`) avec validation serveur stricte.

## Dépendances
- `oxmysql`
- `vorp_core` (standard)
- `vorp_inventory` (standard)

## Installation
1. Copier `resources/[med]/vorp_surgery`.
2. Ajouter dans `server.cfg`:
   ```cfg
   ensure oxmysql
   ensure vorp_core
   ensure vorp_inventory
   ensure vorp_surgery
   ```
3. Démarrer le serveur: la migration SQL `sql/001_init.sql` est appliquée au lancement.

## Architecture
```
vorp_surgery/
  fxmanifest.lua
  config.lua
  shared/
    utils.lua
    locales.lua
  locales/
    fr.lua
    en.lua
  server/
    inventory_bridge.lua
    db.lua
    logs.lua
    injuries.lua
    surgery.lua
    admin.lua
    server.lua
  client/
    interactions.lua
    effects.lua
    nui_bridge.lua
    client.lua
  html/
    index.html
    style.css
    app.js
    assets/body_schema.svg
  sql/001_init.sql
  logs/med_logs.jsonl
```

## SQL / Persistance
- `med_player_state`: état agrégé (douleur, choc, hémorragie, infection, états JSON).
- `med_injuries`: blessures persistantes par zone/type/sévérité.
- `med_treatments`: actes reçus + log opératoire (JSON).
- `med_logs`: logs admin/anti-exploit/audit.

## Flow client/server (MVP)
1. Le patient entre dans une zone de table fixe -> `med:server:setOnTable(true)`.
2. Le médecin proche presse **G** -> `med:server:requestStartSurgery(patient)`.
3. Serveur valide **distance + table + outils inventaire + état**.
4. Client médecin ouvre la NUI fullscreen (`med:client:beginSurgery`).
5. NUI envoie journal d'actions/timing/erreurs (`complete`).
6. Serveur revalide:
   - durée minimale réaliste,
   - cohérence étapes (zone/incision/retractors/sutures...),
   - patient toujours valide/proche/sur table,
   - outils toujours présents.
7. Serveur calcule **résultat médical final** et applique DB/états/effets.
8. En incohérence: échec + `exploit_flag` + logs admin.

## Sécurité
- Aucun résultat médical n'est accepté côté client.
- NUI/client ne font que remonter un `action log`.
- Toute guérison/complication est décidée côté serveur.
- Déconnexion médecin/patient en opération: interruption propre + conséquence médicale (plaie ouverte/risques) + log.

## Commandes admin
- `/meddebug [id]`
- `/medclear <id>`
- `/medset <id> <type> <zone> <severity> <cause>`

## API serveur (exports)
- `exports.vorp_surgery:addInjury(sourceOrCharIdentifier, injuryTable)`
- `exports.vorp_surgery:getMedicalState(sourceOrCharIdentifier)`

## Config importante
- Mapping items dans `Config.Inventory.Items`.
- Outils requis non consommés (`ConsumeItems = false`).
- Auto-détection blessures: présente mais désactivée (`AutoDetectionEnabled = false`).
- Logs DB + console + fichier JSONL optionnel.

## Limitations MVP
- Tables fixes uniquement.
- Pas de système porter/poser patient.
- Détection auto des causes de dégâts volontairement prudente (off par défaut).
