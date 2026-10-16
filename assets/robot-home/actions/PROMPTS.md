# Response pose edit prompts

Built-in imagegen, original idle images as edit targets.


# Action artwork prompts

Built-in imagegen edits. Original local edit targets were inspected with view_image. Each image was generated once.

## jazz

Use case: identity-preserve
Asset type: one action sprite for a 300px embedded display.
Edit target: the supplied Jazz image. This is a precise local pose edit of this exact robot, not a redesign.
Primary request: Raise ONLY the arm on the VIEWER-RIGHT, which currently rests against the waist, into a friendly clear thumbs-up beside the viewer-right shoulder. The existing viewer-left thumbs-up stays exactly where it is, so the result is a cheerful double thumbs-up.
Preserve the entire head exactly: same helmet, blue visor, facial geometry, expression, size, tilt, and original pixel position. Preserve torso shape, white armor, blue/red stripe, wheels and all materials. Preserve hips, both legs and both feet exactly with the same locations and scale. Preserve the image camera, chibi anime line art, lighting, black square background, and full canvas framing. Do not recenter, zoom, crop, or shrink the character.
Change only the previously resting viewer-right arm/hand as needed. Lift the elbow and forearm naturally to make a clearly readable thumb-up; keep the silhouette fully within the canvas with black margin. The new gesture must be unmistakably different from the original waist-resting hand at small size.
No text, labels, particles, new accessories, watermark, floor, shadows or extra characters. Output a single square image with the same 1280x1280 framing as the input.

## hotrod

Use case: identity-preserve
Asset type: one action sprite for a 300px embedded display.
Edit target: the supplied red and orange Hotrod robot. Make a precise pose edit of this exact character, not a redesign.
Primary request: a lively friendly greeting: the torso leans slightly forward at the hips and the arm on VIEWER-RIGHT bends up, holding an open palm in a clear wave beside its shoulder. Keep the expression warm.
Preserve exact head identity, helmet, blue eyes, face geometry, style, proportions and scale; head may tilt very slightly forward with the torso, but must remain at almost the same canvas position. Preserve red armor, orange thighs, yellow flame chest, silver forearm exhausts, and yellow shoulder fins. Preserve both legs and feet exactly with their original positions and scale: no step, no lifted foot, no crouch, no altered stance. Keep the original character size and all black margins. Keep viewer-left arm close to its original resting position. Use the same polished chibi anime line art, shading and materials.
Black square canvas, no scenery, text, labels, particles, watermarks, new props, extra robots, floor, or crop. Do not zoom or recenter. The new wave and gentle forward lean must read clearly at small size, while maintaining the original anchored feet. Output one square image with the same 1280x1280 full-canvas framing as the input.

## wheeljack

Use case: identity-preserve
Asset type: one action sprite for a 300px embedded display.
Edit target: the supplied Wheeljack robot. This is a precise localized action edit of this exact robot, not a redesign.
Primary request: lift the existing compact silver open-ended wrench and the VIEWER-LEFT hand that holds it upward, so the wrench is proudly presented beside the viewer-left shoulder and temple, above the current position. Bend the elbow upward naturally. Put the bottom of the fist at shoulder height, with the compact wrench extending upward beside the head; its top should stay lower than the tallest helmet antenna. This is a cheerful engineer's acknowledgement gesture. Keep the tool clearly separate from the face and blue ear panel, and fully within the canvas.
Preserve the head and helmet EXACTLY in shape, size, position and expression, including white antennae, green forehead, blue eyes and blue side panels, segmented mask. Preserve white armor with green/red stripes, chest design, original chibi anime rendering, materials and lighting. Preserve the viewer-right arm/hand against hip. Preserve hips, legs and both feet exactly, same dimensions and pixel locations. Do not scale, recenter, zoom, change stance or crop. Keep original black square canvas and generous margins, with the same character size.
Change only the viewer-left arm, hand, and existing wrench as needed to lift that tool; keep the rest unchanged. No extra tools, new objects, particles, floor, scenery, text, labels, watermarks, or other robots. Output one square image with the same 1280x1280 full-canvas framing as the input.



# Response artwork prompts

Built-in image_gen; each original idle PNG was viewed before editing.

## hound

Use case: identity-preserve. Asset type: one 300px Home robot response-pose animation frame. Input image 1 is the exact edit target Hound idle, not merely a reference. Primary request: edit ONLY the saluting arm/hand to give a visibly crisp friendly salute response: move his right hand (viewer-left) slightly upward to the upper temple edge, straighten all four fingers together with a clear flat diagonal hand, and move elbow slightly outward so the new gesture is distinguishable from the relaxed salute in the source. Keep the saluting hand alongside the helmet without covering eyes or face. Preserve the other arm. Scene: exactly uniform pure black square background. Style: match this same polished chibi anime robot illustration and exact olive green, silver, dark gray, cyan eyes, warm yellow lamps. Invariants: same face, expression, head geometry and position, torso and jeep grille, all panel shapes, antenna, legs, wheels, feet, character scale and exact canvas placement. Do not shift, crop, zoom, redesign or relight the subject. Feet and head should be in exactly the same locations. No text, watermark, border, weapon, prop, extra limb or duplicate hand. Keep full character visible. One image only.

## ironhide

Use case: identity-preserve. Asset type: one 300px Home robot response-pose animation frame. Input image 1 is the exact edit target Ironhide idle. Primary request: change ONLY his right arm/hand (viewer-left) into a friendly strong closed-fist acknowledgement: elbow bent, forearm angled up, black mechanical fist held just in front of the left side of his chest around lower windshield level, fist fully visible and readable, without covering his face. This is a cheerful reassuring fist gesture, no punch and no violence. Preserve the other hanging arm. Scene: exactly uniform pure black square background. Style: match this same polished chibi anime robot illustration and exact red armor, silver legs and face, black joints, cyan eyes, yellow trim. Invariants: identical face/expression, head shape and head location, van chest and all body panels, torso, hips, legs, wheels, feet, scale, and exact canvas placement. Keep head and feet at precisely their original positions. Do not rotate whole body, shift, zoom, crop, redesign or relight. No text, watermark, border, weapon, prop, extra limb or duplicate hand. Keep full character visible. One image only.

## ratchet

Use case: identity-preserve. Asset type: one 300px Home robot response-pose animation frame. Input image 1 is the exact edit target Ratchet idle. Primary request: edit ONLY his right arm/hand (viewer-left) into a clear friendly OK acknowledgement beside his shoulder: bend the elbow upward and outward, put the silver mechanical hand in the black space just to viewer-left of his shoulder at roughly face-chin height, thumb and index fingertip touch to form a large closed circular OK ring with obvious black hole, remaining three fingers raised and slightly spread. Hand must read as an OK gesture when image is reduced to 300px, and must not cover face or eyes. Preserve the other lowered arm. Scene: exactly uniform pure black square background. Style: match this same polished chibi anime robot illustration, exact white/red/silver palette, cyan eyes, ambulance chest, shoulder crosses. Invariants: identical face and friendly expression, head geometry and position, van chest, all armor panels except articulated raising arm, torso, hips, legs, wheels, feet, proportions, scale, exact canvas placement. Keep head and feet in precisely original locations. Do not shift, zoom, rotate whole body, crop, redesign or relight. No medical instruments, props, text, watermark, border, extra limb or duplicate hand. Keep full character visible. One image only.


## hound chosen replacement: chest acknowledgement

Use case: identity-preserve. Asset type: one 300px Home robot response-pose animation frame. Input image 1 is the exact edit target Hound idle, not merely a reference. Primary request: change ONLY his right arm/hand (viewer-left), lowering the saluting hand completely away from his head into a respectful military acknowledgement: a clearly closed black mechanical fist laid over the upper left chest, roughly in front of the viewer-left windshield, elbow bent outward and forearm diagonally across the upper torso. This must look visibly different from the original temple salute at 300px. His head is fully unobstructed, and there is NO saluting hand near his helmet. Preserve his other arm. Scene: exactly uniform pure black square background. Style: match this same polished chibi anime robot illustration and exact olive green, silver, dark gray, cyan eyes, warm yellow lamps. Invariants: identical face, smile, head geometry and position, torso and jeep grille, all armor panels apart from the moving articulated arm, antenna, legs, wheels, feet, character scale and exact canvas placement. Keep head and feet precisely in their original locations. Do not shift, zoom, crop, rotate whole body, redesign or relight. No text, watermark, border, weapon, prop, extra limb or duplicate hand. Keep full character visible. One image only.

The first hound prompt above is discarded; its source and fitted files are preserved as discarded-hound-salute.png/jpg. This chosen replacement was edited directly from the original idle source.


# Decepticon idle and response prompts (2026-10-16)

Built-in imagegen; selected raw sources remain local and ignored. Prompts below
contain no personal paths. The selected source hashes and fixed transforms are
in `manifest.json`. Proportion and face refinements precede the response edit.

## megatron

### idle prompt

Use case: stylized-concept. Asset type: one full-body robot character sprite for a 300x300 round-watch UI. Create a recognizable classic Transformers G1 MEGATRON, alone, full body from helmet to boots. Match Japanese super-deformed mecha cartoon style: approximately THREE HEADS TALL, oversized head, bold clean dark ink outlines, intricate but readable segmented armor, crisp cel-shaded silver/charcoal metal planes, red eyes, black waist and joints, red small armor accents, distinctive gray Megatron bucket helmet and angular stern face. His iconic black cylindrical forearm cannon may be compact and integral to the arm, pointed harmlessly downward. Relaxed confident idle stance, both feet planted at same baseline, one hand lightly clenched by waist, no attack, no projectile. Square image, pure solid BLACK #000000 background, centered isolated character, generous pure black padding all around; figure occupies at most 78% width and 86% height. Whole head, hands and boots inside canvas. Flat 2D anime/cel illustration, NOT photorealistic, NOT metallic 3D toy render, NOT pixel art. Camera front three-quarter view very slight, readable at tiny size, consistent chibi proportions. No circle or halo, no glow, no effects, no scenery, no ground shadow extending into padding, no labels, typography, logos, watermarks, UI or second character. Single production-ready character illustration only.

### pose prompt

Use case: precise-object-edit. Edit this EXACT megatron full-body idle sprite into its one click-response animation frame. Bend and raise ONLY his non-cannon arm (on viewer RIGHT), bring a strongly clenched fist beside upper chest/shoulder in a confident acknowledgement. Cannon arm remains lowered. CRITICAL REGISTRATION: keep original square canvas size, pure black background, exact head size/location/orientation and face, chest/hips, legs and boots pixel positions, stance, body scale, camera, lighting, ink/cel style and every color unchanged. Modify only the specified shoulder/elbow/forearm/hand and necessary joint occlusion; do not redesign, zoom, recenter, move legs, enlarge helmet or change wings. Keep full character inside canvas. Clearly different arm silhouette from idle. No extra effects, rings, glow, text, scene, character or weapon. This frame will toggle with the unmodified original; stable feet/head/body alignment is essential.

## starscream

### idle prompt

Use case: stylized-concept. One production full-body character sprite, square pure solid BLACK #000000 background, centered and isolated from head to both boots with generous black padding: at most78% width and86% height. Japanese super-deformed mecha ANIME drawing, THREE HEADS TALL oversized helmet/head, bold dark outlines, detailed but readable layered armor, crisp cel-shaded metal planes and dark joints; flat 2D cel illustration matching a tiny watch Autobot cast, not photorealistic or 3D render. Both feet planted at one stable baseline. No circle, halo, glow, effects, scene, text, watermark, extra character or detached weapon. Complete head/hands/boots in frame. Subject: Classic G1 STARSCREAM: recognizable gray/white jet-robot, red chest with dark blue canopy, blue forearms and blue boots, dark helmet and silver smirking face with red eyes, angular swept jet wings behind shoulders with red trim, symmetrical wing silhouette and compact integral upper-arm null rays. Proud relaxed idle stance, hands lightly curled at sides; three-quarter front view slight.

### proportion edit prompt

Use case: style-transfer. Image1 is the EDIT TARGET: starscream idle sprite. Image2 is the accepted Optimus sprite and is ONLY the exact CHIBI PROPORTION / illustration style reference. Rework image1 to match image2's compact super-deformed body proportions and bold detailed cel shading. The helmet/head including face must occupy roughly ONE THIRD of the complete figure height, NOT one sixth. Shorten torso and legs and enlarge head; very short stocky thighs, large chunky boots, broad compact body. Approximately THREE HEADS TALL in total, like image2. Keep unmistakable starscream identity, existing colors, distinctive helmet, face/visor/eye, armor and integrated vehicle parts from image1; DO NOT give it Optimus features or Autobot colors. Full body, relaxed idle hands, boots planted. Pure black square background and generous padding; do not crop hands/wings/helmet/boots. No scene, text, circle, glow, added character or effects. Change proportions/style only; one clear compact chibi character suitable for a tiny round watch screen.

### pose prompt

Use case: precise-object-edit. Edit this EXACT starscream full-body idle sprite into its one click-response animation frame. Raise ONLY the arm on viewer RIGHT into a playful open-hand greeting near shoulder/head level, palm visible; the other arm remains at its original side. CRITICAL REGISTRATION: keep original square canvas size, pure black background, exact head size/location/orientation and face, chest/hips, legs and boots pixel positions, stance, body scale, camera, lighting, ink/cel style and every color unchanged. Modify only the specified shoulder/elbow/forearm/hand and necessary joint occlusion; do not redesign, zoom, recenter, move legs, enlarge helmet or change wings. Keep full character inside canvas. Clearly different arm silhouette from idle. No extra effects, rings, glow, text, scene, character or weapon. This frame will toggle with the unmodified original; stable feet/head/body alignment is essential.

## soundwave

### idle prompt

Use case: stylized-concept. One production full-body character sprite, square pure solid BLACK #000000 background, centered and isolated from head to both boots with generous black padding: at most78% width and86% height. Japanese super-deformed mecha ANIME drawing, THREE HEADS TALL oversized helmet/head, bold dark outlines, detailed but readable layered armor, crisp cel-shaded metal planes and dark joints; flat 2D cel illustration matching a tiny watch Autobot cast, not photorealistic or 3D render. Both feet planted at one stable baseline. No circle, halo, glow, effects, scene, text, watermark, extra character or detached weapon. Complete head/hands/boots in frame. Subject: Classic G1 SOUNDWAVE: navy blue cassette-deck robot, squared dark blue helmet with white angular crest, red horizontal visor and silver mouthplate; large gold-bordered dark cassette-window chest, white/silver forearms and thighs, dark blue shin armor with white blocks, compact integral shoulder cylinder. Broad calm upright idle stance, hands lowered; slight front three-quarter view.

### proportion edit prompt

Use case: style-transfer. Image1 is the EDIT TARGET: soundwave idle sprite. Image2 is the accepted Optimus sprite and is ONLY the exact CHIBI PROPORTION / illustration style reference. Rework image1 to match image2's compact super-deformed body proportions and bold detailed cel shading. The helmet/head including face must occupy roughly ONE THIRD of the complete figure height, NOT one sixth. Shorten torso and legs and enlarge head; very short stocky thighs, large chunky boots, broad compact body. Approximately THREE HEADS TALL in total, like image2. Keep unmistakable soundwave identity, existing colors, distinctive helmet, face/visor/eye, armor and integrated vehicle parts from image1; DO NOT give it Optimus features or Autobot colors. Full body, relaxed idle hands, boots planted. Pure black square background and generous padding; do not crop hands/wings/helmet/boots. No scene, text, circle, glow, added character or effects. Change proportions/style only; one clear compact chibi character suitable for a tiny round watch screen.

### pose prompt

Use case: precise-object-edit. Edit this EXACT soundwave full-body idle sprite into its one click-response animation frame. Raise ONLY the hand on viewer RIGHT to the side of his helmet as a listening acknowledgement, fingertips near ear; other arm unchanged, cassette chest unchanged. CRITICAL REGISTRATION: keep original square canvas size, pure black background, exact head size/location/orientation and face, chest/hips, legs and boots pixel positions, stance, body scale, camera, lighting, ink/cel style and every color unchanged. Modify only the specified shoulder/elbow/forearm/hand and necessary joint occlusion; do not redesign, zoom, recenter, move legs, enlarge helmet or change wings. Keep full character inside canvas. Clearly different arm silhouette from idle. No extra effects, rings, glow, text, scene, character or weapon. This frame will toggle with the unmodified original; stable feet/head/body alignment is essential.

## shockwave

### idle prompt

Use case: stylized-concept. One production full-body character sprite, square pure solid BLACK #000000 background, centered and isolated from head to both boots with generous black padding: at most78% width and86% height. Japanese super-deformed mecha ANIME drawing, THREE HEADS TALL oversized helmet/head, bold dark outlines, detailed but readable layered armor, crisp cel-shaded metal planes and dark joints; flat 2D cel illustration matching a tiny watch Autobot cast, not photorealistic or 3D render. Both feet planted at one stable baseline. No circle, halo, glow, effects, scene, text, watermark, extra character or detached weapon. Complete head/hands/boots in frame. Subject: Classic G1 SHOCKWAVE: rich purple cyclopean robot, hexagonal helmet enclosing ONE luminous-yellow painted eye (no aura), no face or mouth, translucent-looking pink/magenta geometric chest window rendered with crisp cel shading, silver joints, large squared purple boots, one hand and compact integrated left forearm barrel. Calm analytical idle stance, single hand near hip, barrel safely downward. Slight front three-quarter view.

### proportion edit prompt

Use case: style-transfer. Image1 is the EDIT TARGET: shockwave idle sprite. Image2 is the accepted Optimus sprite and is ONLY the exact CHIBI PROPORTION / illustration style reference. Rework image1 to match image2's compact super-deformed body proportions and bold detailed cel shading. The helmet/head including face must occupy roughly ONE THIRD of the complete figure height, NOT one sixth. Shorten torso and legs and enlarge head; very short stocky thighs, large chunky boots, broad compact body. Approximately THREE HEADS TALL in total, like image2. Keep unmistakable shockwave identity, existing colors, distinctive helmet, face/visor/eye, armor and integrated vehicle parts from image1; DO NOT give it Optimus features or Autobot colors. Full body, relaxed idle hands, boots planted. Pure black square background and generous padding; do not crop hands/wings/helmet/boots. No scene, text, circle, glow, added character or effects. Change proportions/style only; one clear compact chibi character suitable for a tiny round watch screen.

### pose prompt

Use case: precise-object-edit. Edit this EXACT shockwave full-body idle sprite into its one click-response animation frame. Raise ONLY his normal non-cannon hand (on viewer LEFT) with one index finger pointing upward beside chest in an analytical acknowledgement; integrated cannon arm remains safely lowered. CRITICAL REGISTRATION: keep original square canvas size, pure black background, exact head size/location/orientation and face, chest/hips, legs and boots pixel positions, stance, body scale, camera, lighting, ink/cel style and every color unchanged. Modify only the specified shoulder/elbow/forearm/hand and necessary joint occlusion; do not redesign, zoom, recenter, move legs, enlarge helmet or change wings. Keep full character inside canvas. Clearly different arm silhouette from idle. No extra effects, rings, glow, text, scene, character or weapon. This frame will toggle with the unmodified original; stable feet/head/body alignment is essential.

## thundercracker

### idle prompt

Use case: style-transfer. EDIT the attached accepted Optimus watch sprite into a DIFFERENT classic G1 Decepticon character described below. Preserve this exact compact super-deformed cartoon proportion: oversized head about ONE THIRD of full figure height, short stocky body and legs, chunky boots, about three heads tall. Preserve bold detailed dark ink outlines, crisp vivid cel shading, and readability at300px. Replace Optimus identity, armor, helmet, face and colors completely with the requested character; do NOT retain Autobot truck windows or Optimus helmet. One complete isolated full-body figure, relaxed idle stance, both boots on same baseline, hands lowered or relaxed. Square pure BLACK #000000 background, generous black safety padding, no halo/circle/glow/effects/scenery/text/UI/watermark/other character. All helmet, wings, hands and boots fit in canvas. Subject replacement: THUNDERCRACKER: cobalt and medium-blue classic Seeker jet robot, light gray arms/thighs, dark helmet around silver face with red eyes; orange/yellow cockpit canopy chest, swept broad blue wings with white and red trim behind shoulders, compact integrated arm cylinders, chunky blue boots. Calm confident expression. Distinctly BLUE, not Starscream red.

### face edit prompt

Use case: precise-object-edit. Edit ONLY the small silver lower-face area of this thundercracker G1 robot. Replace the current featureless silver mouth-mask plate with a recognizable sculpted angular SILVER ROBOT FACE showing a distinct nose bridge, narrow visible mouth/lips and chin/jaw, as classic G1 Decepticons have; no Optimus-style mask. Preserve exact helmet outline and size, red eyes, entire rest of body/armor/colors, pose, boots/feet, camera/framing, style, square canvas and black background unchanged. Do not enlarge the face, change the head position, alter any body part, add text/effects or redesign anything else.

### pose prompt

Use case: precise-object-edit. Edit this EXACT thundercracker full-body idle sprite into its one click-response animation frame. Raise the viewer-RIGHT forearm into a friendly clear thumbs-up beside the chest; the other arm stays down.
CRITICAL REGISTRATION: keep the original square canvas size, pure black background, exact head size/location/orientation and face, chest/hips, legs and boots pixel positions, stance, body scale, camera, lighting, ink/cel style and every color unchanged. Modify only the specified shoulder/elbow/forearm/hand and necessary joint occlusion; do not redesign, zoom, recenter, move legs, enlarge the helmet or change wings. Clearly different arm silhouette, no effects, rings, text, scene or extra weapon.

## skywarp

### idle prompt

Use case: style-transfer. EDIT the attached accepted Optimus watch sprite into a DIFFERENT classic G1 Decepticon character described below. Preserve this exact compact super-deformed cartoon proportion: oversized head about ONE THIRD of full figure height, short stocky body and legs, chunky boots, about three heads tall. Preserve bold detailed dark ink outlines, crisp vivid cel shading, and readability at300px. Replace Optimus identity, armor, helmet, face and colors completely with the requested character; do NOT retain Autobot truck windows or Optimus helmet. One complete isolated full-body figure, relaxed idle stance, both boots on same baseline, hands lowered or relaxed. Square pure BLACK #000000 background, generous black safety padding, no halo/circle/glow/effects/scenery/text/UI/watermark/other character. All helmet, wings, hands and boots fit in canvas. Subject replacement: SKYWARP: classic Seeker jet robot in BLACK/charcoal and vivid PURPLE, silver-gray thighs and upper arms, black helmet with silver face and red eyes, orange/yellow canopy in chest, purple forearms and chunky purple/black boots, black swept wings with purple edges. Mischievous expression, idle compact stance. Distinct black-purple scheme.

### face edit prompt

Use case: precise-object-edit. Edit ONLY the small silver lower-face area of this skywarp G1 robot. Replace the current featureless silver mouth-mask plate with a recognizable sculpted angular SILVER ROBOT FACE showing a distinct nose bridge, narrow visible mouth/lips and chin/jaw, as classic G1 Decepticons have; no Optimus-style mask. Preserve exact helmet outline and size, red eyes, entire rest of body/armor/colors, pose, boots/feet, camera/framing, style, square canvas and black background unchanged. Do not enlarge the face, change the head position, alter any body part, add text/effects or redesign anything else.

### pose prompt

Use case: precise-object-edit. Edit this EXACT skywarp full-body idle sprite into its one click-response animation frame. Raise the viewer-RIGHT forearm and open the purple hand for a short friendly wave beside the cheek; the other arm stays down.
CRITICAL REGISTRATION: keep the original square canvas size, pure black background, exact head size/location/orientation and face, chest/hips, legs and boots pixel positions, stance, body scale, camera, lighting, ink/cel style and every color unchanged. Modify only the specified shoulder/elbow/forearm/hand and necessary joint occlusion; do not redesign, zoom, recenter, move legs, enlarge the helmet or change wings. Clearly different arm silhouette, no effects, rings, text, scene or extra weapon.

## blitzwing

### idle prompt

Use case: style-transfer. EDIT the attached accepted Optimus watch sprite into a DIFFERENT classic G1 Decepticon character described below. Preserve this exact compact super-deformed cartoon proportion: oversized head about ONE THIRD of full figure height, short stocky body and legs, chunky boots, about three heads tall. Preserve bold detailed dark ink outlines, crisp vivid cel shading, and readability at300px. Replace Optimus identity, armor, helmet, face and colors completely with the requested character; do NOT retain Autobot truck windows or Optimus helmet. One complete isolated full-body figure, relaxed idle stance, both boots on same baseline, hands lowered or relaxed. Square pure BLACK #000000 background, generous black safety padding, no halo/circle/glow/effects/scenery/text/UI/watermark/other character. All helmet, wings, hands and boots fit in canvas. Subject replacement: BLITZWING: classic G1 triple-changer tank/jet robot, tan/sand shoulder and upper-body armor, angular PURPLE helmet/face-surround and purple chest/waist accents, red visor and silver face, chunky tan boots and dark-purple lower leg sections, short tank treads integrated along outer shins and a compact folded turret silhouette behind shoulders. Broad stocky sturdy stance, no tank vehicle separate.

### face edit prompt

Use case: precise-object-edit. Edit ONLY the small silver lower-face area of this blitzwing G1 robot. Replace the current featureless silver mouth-mask plate with a recognizable sculpted angular SILVER ROBOT FACE showing a distinct nose bridge, narrow visible mouth/lips and chin/jaw, as classic G1 Decepticons have; no Optimus-style mask. Preserve exact helmet outline and size, red eyes, entire rest of body/armor/colors, pose, boots/feet, camera/framing, style, square canvas and black background unchanged. Do not enlarge the face, change the head position, alter any body part, add text/effects or redesign anything else.

### pose prompt

Use case: precise-object-edit. Edit this EXACT blitzwing full-body idle sprite into its one click-response animation frame. Bend the viewer-RIGHT elbow to raise one clenched purple fist beside the upper chest as a confident acknowledgement; the other arm stays down.
CRITICAL REGISTRATION: keep the original square canvas size, pure black background, exact head size/location/orientation and face, chest/hips, legs and boots pixel positions, stance, body scale, camera, lighting, ink/cel style and every color unchanged. Modify only the specified shoulder/elbow/forearm/hand and necessary joint occlusion; do not redesign, zoom, recenter, move legs, enlarge the helmet or change wings. Clearly different arm silhouette, no effects, rings, text, scene or extra weapon.

## astrotrain

### idle prompt

Use case: style-transfer. EDIT the attached accepted Optimus watch sprite into a DIFFERENT classic G1 Decepticon character described below. Preserve this exact compact super-deformed cartoon proportion: oversized head about ONE THIRD of full figure height, short stocky body and legs, chunky boots, about three heads tall. Preserve bold detailed dark ink outlines, crisp vivid cel shading, and readability at300px. Replace Optimus identity, armor, helmet, face and colors completely with the requested character; do NOT retain Autobot truck windows or Optimus helmet. One complete isolated full-body figure, relaxed idle stance, both boots on same baseline, hands lowered or relaxed. Square pure BLACK #000000 background, generous black safety padding, no halo/circle/glow/effects/scenery/text/UI/watermark/other character. All helmet, wings, hands and boots fit in canvas. Subject replacement: ASTROTRAIN: classic G1 triple-changer space-shuttle/train robot, white and light gray helmet and upper armor with deep purple chest/waist/shin sections, silver face and RED eyes beneath gray angular helmet brow, compact folded white shuttle wings behind shoulders with black trim, integrated wheel motifs on legs and oversized purple boots. Stable broad friendly idle stance, no separate train or shuttle.

### pose prompt

Use case: precise-object-edit. Edit this EXACT astrotrain full-body idle sprite into its one click-response animation frame. Lift the viewer-RIGHT forearm with a flat hand near the temple in a friendly salute; the other arm stays down.
CRITICAL REGISTRATION: keep the original square canvas size, pure black background, exact head size/location/orientation and face, chest/hips, legs and boots pixel positions, stance, body scale, camera, lighting, ink/cel style and every color unchanged. Modify only the specified shoulder/elbow/forearm/hand and necessary joint occlusion; do not redesign, zoom, recenter, move legs, enlarge the helmet or change wings. Clearly different arm silhouette, no effects, rings, text, scene or extra weapon.
