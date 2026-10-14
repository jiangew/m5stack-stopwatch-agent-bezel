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
