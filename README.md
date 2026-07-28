Career Realms: The Shifter's Path
A 2D career-exploration RPG built in Godot 4. You play a Shifter who travels between five career realms, takes on quests in each, and earns stars for how well you perform — with skill in one domain quietly making you better at the others.

🏆 5th place at the FBLA National Leadership Conference.

The Five Domains
Domain	Sample quests
Engineering	Ancient Egypt Irrigation, Dyson Swarm
Farming	Village Farm Revival
Medicine	Forest Healing, Alien Gene Splicing, Nanobot Surgeon
Art	Prism Array
Leadership	Trading and negotiation quests
Each domain has its own house off the Main Hub, plus a star container room where your progress in that field is displayed.

How It Works
Stars. Every quest is scored out of 5 stars. Five domains × three quests × five stars = 75 stars at a perfect run. Your total determines which of five endings you get — the thresholds sit at 15, 30, 45, 60, and 75 stars.

Cross-domain synergy. This is the core idea of the game: careers aren't silos. Once you've earned 5 stars in a domain, it starts buffing your work in the others, and again at 10. Engineering skill speeds up your crop growth. Farming knowledge makes your healing more effective. Leadership extends the clock on your builds. The full matrix lives in scripts/core/DomainInteractionManager.gd.

The clock. Runs are timed, so you can't max everything — you decide where to specialize and what to leave on the table.

Running It
You'll need Godot 4.7 (Forward+). Open the project folder in the editor, or:

./run-game.sh
./run-game.sh --editor
run-game.sh expects a Godot binary at ~/Downloads/Godot_mono.app/... — edit the GODOT variable at the top to point at wherever yours lives.

⚠️ Art assets are not in this repository. The art/ and assets/ folders are gitignored to keep the repo a reasonable size, so a fresh clone will open with missing textures and audio. This repo is here to show the code and scene structure; you'll need the asset packs separately to actually play it.

Layout
scripts/core/     autoload singletons — game state, stars, endings, synergy
scenes/maps/      the Main Hub, domain houses, star container rooms
scenes/           quest scenes, UI, player, dialogue box
dialogue/         NPC conversation trees as JSON
inventory/        inventory and star-inventory system
shaders/          visual effects
State that has to survive scene changes runs through autoload singletons — GameState, StarManager, EndingManager, DomainInteractionManager, GrowthManager, and friends, all registered in project.godot.
