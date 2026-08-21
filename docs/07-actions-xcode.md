# Xcode — Actions restantes (SpeakEasy)

Basé sur la vérification de HEAD `940bd70` (main). Chemin critique 🔴 100 % fait ;
reste **3 écarts** (S0.1, S5.4, S5.2) + la **validation « Définition de terminé »** et la **finalisation App Store**.

---

## 1. Les 3 écarts à corriger

### 1.1 S0.1 — Partager le scheme (Xcode uniquement, 2 min)

Le commit `fdcfa8c` n'a ajouté que la règle `.gitignore` ; **aucun `.xcscheme` n'est versionné**.

1. Ouvrir `SpeakEasy.xcodeproj`.
2. Menu **Product › Scheme › Manage Schemes…**.
3. Coche **Shared** sur le scheme `SpeakEasy`.
4. Fermer. Le fichier apparaît :  
   `SpeakEasy.xcodeproj/xcshareddata/xcschemes/SpeakEasy.xcscheme`
5. Commiter ce fichier (message : `S0.1: share SpeakEasy scheme`).
   - Vérifier que `.gitignore` ne bloque pas `xcshareddata/xcschemes` (règle actuelle n'ignore que `xcuserdata/**/*.xcscheme`).
   - Le jardin est dans `xcshareddata`, PAS `xcuserdata` — ne pas le ranger côté utilisateur.

### 1.2 S5.4 — Localisation française (Xcode + traductions, ~1 j)

Le code fait déjà 9 appels `String(localized:)`, mais `developmentRegion = en`, `knownRegions = (en, Base)` et **aucun fichier `.strings`/`.xcstrings`** : tout sort en anglais.

1. **File › New › File… › String Catalog** → nom `Localizable` (crée `Localizable.xcstrings`).
2. Xcode liste automatiquement chaque `String(localized:)` comme entrée de la table.
3. Dans le catalogue, ligne du projet : **+** › *Add localizations / French* (ou *Make French the development language*).
4. Renseigner les traductions `fr` sur chaque ligne (statut → « Reviewed » pour les 3 points verts).
5. Ajouter `fr` à `knownRegions` dans `project.pbxproj` (Xcode le fait en général seul) :
   ```pbxproj
   knownRegions = (
       en,
       fr,
       Base,
   );
   ```
6. **Clé manquante à créer** : la notification utilise `String(localized: "notification.title")` et `"notification.body"` — vérifier qu'elles sont bien exposées par le catalogue.
7. Validation : simulateur/device en **français** (Settings › General › Language), relancer, contrôler chaque écran (Home, Practice, Résultat, Révision, Réglages, Onboarding).

**⚠️ Le changement de langue déclenche le re-onboarding (S3.5)** : si `hasCompletedOnboarding` dépend de la locale, toute bascule de langue relance l'onboarding. C'est voulu — à confirmer en test.

### 1.3 S5.2 — Réécoute A/B (patch Swift + build)

L'infra existe (`AttemptAudioRecorder` → `.caf`, `SpeechPlaybackService.speak(_:slow:)`) mais **aucune UI de réécoute de la tentative** n'est branchée (ni `slow:`, ni bouton A/B dans `ResultContent`/`ResultContent.swift`).

- **Prérequis : patch Swift à produire côté Pi** (bouton « Réécouter » qui relit le `.caf` de la tentative + `speak(sentence.english)` du modèle, option vitesse lente).
- Ensuite, validation Xcode :
  1. Build + run sur appareil réel.
  2. Enregistrer un essai, taper réécoute → entendre **sa propre voix**, puis l'**A/B** (modèle vs tentative).
  3. Vérifier : le `.caf` est bien relu depuis `AttemptAudioRecorder.url`, pas de fuite de session audio.

---

## 2. Validation « Définition de terminé » (sur appareil réel)

Chaque tâche du tracker n'est terminée que si elle passe ces contrôles — rien de tout cela n'est vérifiable depuis le Pi.

### 2.1 Build strict concurrency (`S0.2`)
```bash
xcodebuild build \
  -project SpeakEasy.xcodeproj -scheme SpeakEasy \
  -destination 'platform=iOS, name=<ton iPhone>' 2>&1 | grep -c "error:"
```
- Doit tendre vers **0 erreur**, **0 warning** (le grep ci-dessus compte les `error:` ; ajouter `| grep -c "warning:"` pour les warnings).
- Les tests restent en `SWIFT_VERSION=5.0` (normal) ; l'**app** est en 6.0 + `complete`.

### 2.2 Tests unitaires
```bash
xcodebuild test \
  -project SpeakEasy.xcodeproj -scheme SpeakEasy \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
- 24 tests attendus (scoring, normalisation, feedback, VM, scheduler, plan, migration).

### 2.3 Accessibility Inspector (chaque écran)
1. Xcode › **Xcode › Open Developer Tool › Accessibility Inspector**.
2. Parcourir : Home, Onboarding, Practice (ready/recording/processing/error), Résultat, Révision, Réglages.
3. **Zéro nouvel avertissement** ; vérifier en particulier :
   - `MicrophoneButton` a bien un label accessible (pas seulement une icône).
   - Waveform / `LiveTranscriptView` ne font pas de lecture bruyante de dix éléments par seconde.
   - Contraste AA sur le fond (`Theme.onColor`, `Theme.brand`).

### 2.4 Comportement sur appareil réel (pas simulateur)
- Vrai microphone → scoring réel (simulateur : pas de micro).
- `SpeechTranscriber` assets installés ; scénario **S3.5** : premier lancement → onboarding télécharge les assets ; couper l'accès API sur l'appareil → message d'échec d'installation, pas de crash.
- **S3.4 interruptions** : pendant un enregistrement, couper le réseau / prendre un appel → l'app pause et reprend proprement.
- **S1.3 auto-stop** : un silence prolongé ne doit plus arrêter la session tout seul (seul le timeout de la VM, `maxRecordingDuration`, le fait).

---

## 3. Finalisation App Store (S5.7)

1. **Recherche de code mort** (grep, côté Pi déjà partiellement fait) — à confirmer au build :
   - Symbole orphelins non référencés (ex. `sessionProgressText`, `isLastInCatalog`, `cancel` non utilisés).
   - Compilateur : les warnings de dead/inaccessible code apparaissent au build strict.
2. **PrivacyInfo.xcprivacy** présent ✅ — vérifier qu'il liste bien :
   - la collecte audio (micro) et la reconnaissance vocale,
   - les raisons (`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`),
   - pas de tracking (App Privacy).
3. **Archive & Upload** :
   ```bash
   # dans Xcode : Product › Archive, puis Window › Organizer › Distribute App
   ```
   Boutique : app name, identifiant `s1933.SpeakEasy` vérifié (utiliser le vrai `PRODUCT_BUNDLE_IDENTIFIER` dans `log stream`).

---

## 4. Ordre recommandé sur le Mac

| Ordre | Action | Impact | Effort |
|---|---|---|---|
| 1 | **S0.1** Partager le scheme | réparabilité du repo | 5 min |
| 2 | **S0.2/2.1/2.2** Build strict + comptage erreurs/warnings | vérifie S1→S4 réellement | 15 min |
| 3 | **2.3/2.4** Accessibilité + appareils réels | confirme les 🔴 | 1–2 j |
| 4 | **S5.4** Localisation FR | produit fini | ~1 j |
| 5 | **S5.2** patch A/B + validation | finition UX | ~1 j |
| 6 | **3** Finalisation App Store | livraison | 1 j |

---

## 5. Rappels / commandes utiles

```bash
# Build (compter erreurs ET warnings) — depuis racine repo sur le Mac
xcodebuild build -project SpeakEasy.xcodeproj -scheme SpeakEasy \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  | grep -cE "error:|warning:"

# Tests
xcodebuild test -project SpeakEasy.xcodeproj -scheme SpeakEasy \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# Logs speech/audio en filtrant par bundle réel
log stream --predicate 'subsystem == "s1933.SpeakEasy"'
```

**À confirmer côté Pi avant le patch S5.2** : schéma exact du bouton réécoute (placement dans `ResultContent`, vitesse `slow`, stratégie A/B). Dis-moi si tu veux que je génère ce patch Swift maintenant.