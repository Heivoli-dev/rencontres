# Protocole d'échange (v1) – identique sur Mac, iPhone et Android

## Bluetooth basse consommation (BLE)

| Élément | UUID |
|---|---|
| Service de l'appli (annoncé) | `29AA63FB-0552-4A4B-8CD2-4042B4BA69E5` |
| Caractéristique **PROFIL** (lecture) | `E9868EB7-D7E8-4D4F-9368-BE0BBFBE99F6` |
| Caractéristique **BOÎTE** (écriture avec réponse) | `65148279-FF49-4B8B-BF3B-411B1F0EC7B9` |

Chaque appareil fait les deux rôles en même temps :

- **Annonceur (périphérique)** : il annonce le service et répond aux deux caractéristiques.
- **Chercheur (central)** : il cherche le service, se connecte, **lit PROFIL** (le profil de l'autre) puis **écrit son propre profil dans BOÎTE**. Il se déconnecte ensuite.

Une seule connexion suffit donc pour un échange dans les deux sens. C'est important pour l'iPhone en arrière-plan : il ne peut pas bien annoncer, mais il peut chercher et se connecter.

## Anti-doublon

- Chaque installation a un **identifiant d'appareil** aléatoire de 16 octets, fixé une fois pour toutes. Il voyage dans le profil.
- Une rencontre n'est comptée qu'une fois par **délai** (réglable, 2 h par défaut) pour un même identifiant d'appareil.
- Le chercheur évite aussi de se reconnecter au même appareil pendant ce délai.

## Format binaire du profil (taille maximale : 220 octets)

| Octets | Contenu |
|---|---|
| 0 | Version du format = `1` |
| 1 à 16 | Identifiant d'appareil (16 octets) |
| 17 à 27 | Recette de la créature (11 octets, voir ci-dessous) |
| 28 | Longueur L1 du pseudo (UTF-8, 32 octets max) |
| … | Pseudo |
| suivant | Longueur L2 du jeu du moment (UTF-8, 48 octets max) |
| … | Jeu du moment |
| suivant | Longueur L3 du message court (UTF-8, 120 octets max) |
| … | Message court |

Un texte trop long est coupé sans casser de caractère. Un lecteur doit **ignorer les octets en trop** après le message : on pourra ainsi ajouter des champs dans une version 2 sans casser la v1.

## Recette de la créature (11 octets, dans cet ordre)

| # | Champ | Valeurs |
|---|---|---|
| 0 | Couleur du corps | 0 Nuit · 1 Ardoise · 2 Prune · 3 Forêt · 4 Ciel · 5 Pêche |
| 1 | Couleur des branchies | 0 Lavande · 1 Bleu · 2 Rose · 3 Menthe · 4 Soleil |
| 2 | Branchies | 0 Pétales · 1 Longues · 2 Courtes · 3 Aucune |
| 3 | Queue | 0 Nageoire · 1 Pompon · 2 Fine · 3 Aucune |
| 4 | Yeux | 0 Brillants · 1 Points · 2 Endormis |
| 5 | Marque | 0 Losange · 1 Aucune · 2 Taches · 3 Rayures |
| 6 | Chapeau | 0 Aucun · 1 Casquette · 2 Bonnet · 3 Haut-de-forme · 4 Couronne · 5 Sorcier · 6 Casque audio · 7 Nœud · 8 Fleur |
| 7 | Lunettes | 0 Aucunes · 1 Rondes · 2 Soleil · 3 Roses |
| 8 | Cou | 0 Rien · 1 Écharpe · 2 Nœud pap · 3 Clochette · 4 Bandana |
| 9 | Fierté | 0 Aucun · 1 Arc-en-ciel · 2 Trans · 3 Bi · 4 Lesbien · 5 Pan · 6 Non-binaire · 7 Asexuel |
| 10 | Geste | 0 Calme · 1 Salut · 2 Joie · 3 Danse · 4 Curieux · 5 Timide |

Une valeur inconnue (venant d'une version plus récente) doit être remplacée par 0 à l'affichage.

## Rendu de la créature

Le même fichier `shared/creature/creature.html` (WebGL) sert sur les trois plateformes, dans une vue web. Il expose :

```js
setCreature([11 octets], { yaw: -0.4, spin: false })
```
