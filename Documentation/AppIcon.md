# App icon

Lyrx's icon was created using GPT 6 Astra in Codex. It is a hand holding a silver microphone over a deep teal gradient. The microphone suggests singing and lyrics; the open space around the emblem keeps its silhouette clear at small sizes.

![Lyrx app icon](Images/AppIcon.png)

## Editing

Open `Lyrx/AppIcon.icon` in Icon Composer. The document keeps the background separate from its transparent foreground artwork in `Assets/Hand-and-Microphone.png`. The foreground is scaled to 72% so the microphone and wrist remain inside the system mask. Glass effects on the illustration and group translucency are disabled to preserve its colors and clean edges; the background uses the system's material treatment.

The shared iOS/macOS document supports Default, Dark, and Mono appearances. Preview the 26 design generation as well as newer system rendering when editing with a newer Xcode. Keep the project at object version 77 for the Xcode 26.6 CI toolchain.

Xcode discovers the document through the synchronized app folder and compiles it using the existing `AppIcon` build setting. The PNG above is only a documentation preview; the app uses the layered document.

## Artwork brief

The foreground artwork uses this prompt:

```text
Use case: logo-brand.
Asset type: transparent foreground artwork for the Lyrx native Apple app icon, to be imported into Icon Composer above a separate deep teal background.
Primary request: a beautiful, memorable stylized hand holding a singing microphone. Lyrx is a lyric reading app.
Subject: one simplified sculptural hand in warm ivory, fingers clearly wrapped naturally around the lower stem of a classic handheld microphone, with a pearl silver rounded capsule grille and dark teal handle. The microphone leans gently toward the upper right. Warm ivory hand, silver grille, deep petrol handle; strong recognizable silhouette.
Style/medium: refined minimal editorial illustration, broad smooth shapes, precise edges, restrained tonal modeling, premium native app icon quality. Simple grille slots, no tiny mesh, no photographic detail, no skin pores.
Composition/framing: square 1024 by 1024 transparent canvas. Center the complete hand and microphone as one cohesive emblem, occupying approximately 70 percent of canvas width and 76 percent of canvas height. Keep all fingertips and the wrist end within the canvas, ample clear margin on every side. Designed to remain readable at 32 pixels.
Constraints: actual transparent background, no rounded square, no border, no text, no letters, no logos, no watermark, no additional objects, no floor, no cast shadow, no glow. Icon Composer will add its own material and shadow. The wrist ends in a clean softly rounded shape, not cut off at the edge.
```
