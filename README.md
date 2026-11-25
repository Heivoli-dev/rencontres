# Projet Rencontres (nom provisoire)

Appli de rencontres entre potes : quand deux appareils qui ont l'appli se croisent, ils s'échangent en Bluetooth un petit profil (pseudo, jeu du moment, message, créature 3D) et chacun garde la rencontre dans son historique.

## Dossiers

- `docs/PROTOCOLE.md` : le format d'échange, identique sur toutes les plateformes. **C'est la référence.**
- `shared/creature/creature.html` : la créature 3D pixelisée, utilisée telle quelle par le Mac, l'iPhone et Android.
- `mac/` : l'appli Mac (petite icône dans la barre des menus).
- `ios/` : l'appli iPhone (projet Xcode).
- `android/` : l'appli Android (à venir).

## Lancer l'appli Mac

Il faut macOS 13 ou plus récent, avec Xcode ou au moins ses outils en ligne de commande (`xcode-select --install`).

1. Ouvre le **Terminal**.
2. Tape `cd ` (avec un espace), glisse le dossier `mac` dans la fenêtre du Terminal, puis appuie sur Entrée.
3. Tape `./build.sh` puis Entrée.
4. Une petite étincelle apparaît en haut à droite, dans la barre des menus. Clique dessus.
5. Au premier lancement, accepte l'accès au **Bluetooth** et aux **notifications**.

Dans l'appli :
- **Profil** : ton pseudo, ton jeu du moment, ton message et ta créature.
- **Réglages** : le délai avant de recompter la même personne. Choisis « 1 min (test) » pour tes essais. Le **journal Bluetooth** montre ce qui se passe en direct.

Si le Bluetooth est refusé : Réglages Système › Confidentialité et sécurité › Bluetooth, puis active « Rencontres ».

Le script fabrique aussi **`build/Rencontres.dmg`**, à partager avec tes potes qui ont un Mac.
Comme l'appli n'est pas signée par Apple, chez eux il faudra faire **clic droit › Ouvrir** au premier lancement
(ou Réglages Système › Confidentialité et sécurité › « Ouvrir quand même »).

## Installer l'appli iPhone (sans App Store, compte Apple gratuit)

Il faut Xcode 16 ou plus récent (App Store du Mac).

1. Double-clique sur `ios/Rencontres.xcodeproj` : Xcode s'ouvre.
2. Branche ton iPhone au Mac avec un câble et déverrouille-le. Accepte « Faire confiance à cet ordinateur ».
3. Dans Xcode, menu **Xcode › Settings › Accounts** : ajoute ton identifiant Apple (bouton +).
4. Clique sur **Rencontres** en haut de la liste de gauche, onglet **Signing & Capabilities** :
   coche « Automatically manage signing » et choisis ta **Team** (ton nom, « Personal Team »).
   Si Xcode dit que l'identifiant est déjà pris, remplace `fr.heivoli.rencontres` par quelque chose d'unique, par exemple `fr.heivoli.rencontres.toi`.
5. En haut de la fenêtre, choisis ton iPhone comme appareil, puis clique sur le bouton **Lecture ▶**.
6. Sur l'iPhone, la première fois :
   - active le **Mode développeur** (Réglages › Confidentialité et sécurité › Mode développeur), l'iPhone redémarre ;
   - fais confiance à ton profil (Réglages › Général › VPN et gestion de l'appareil › ton identifiant › Faire confiance) ;
   - relance avec **Lecture ▶**.
7. Accepte le Bluetooth et les notifications.

L'appli expire au bout de **7 jours** avec un compte gratuit : il suffit de rebrancher l'iPhone et de recliquer sur Lecture ▶ (tes rencontres sont gardées).

Limites connues de l'iPhone : en arrière-plan, il trouve bien un Mac ou un Android, mais deux iPhone verrouillés se voient mal entre eux. Pour un test fiable, garde l'appli ouverte à l'écran.

## Tester sans deuxième appareil

Le Mac seul ne peut pas se croiser lui-même. Il faut un deuxième appareil qui a l'appli : ton iPhone, ou un autre Mac. Mets le délai sur « 1 min (test) » des deux côtés, ouvre les deux applis, et regarde le journal Bluetooth.
