In this file I want to explain the ideas to this repository.

Previus Chagpt discussion: https://chatgpt.com/share/6a6bd04d-c888-83e9-8290-0b2b5e03ae4b (it's open and everybody could see).

It'll be used to:

- setup/update all my different machines (home, work).
  - is it worthwile to run the setup/update on startup process?
  - is it possible to run the setup/update on lookscreen?
  - we need to reduze friction. If on startup it let a long time it'll have terrible experience.
  - If this is a problem, starts only with the setup process. Or it's better to think how to solve this at the beginning.
- syncronize all my machines (home, work) smothly.
  - use a script to run on machine startup to syncronize all machines:
    - pull repo (github)
    - run install/update commands
  - use a script to run before a machine shutdown.
    - check git status to see any changes. If yes ask for a default commit message? check changes and commit using ia?
  - create/update omarchy skills to everytime a change is done, do it in the correct place, commit and push it to the github repository

- Do in parts:
  - start the construction with dotfiles.
    - Start creating a simple dotfile configuration like change some keybinging, monitors configuration or things like that.
    - Does  using stow as suggested by the documentation is a good idea?
  - Other parts involve claude configuration and installations could be done next.
  - Changes could be incremental.

- Why configure git aliases on git install and not globally (lewagon do that)?
- Create a claude skill/hook/agent to everytime a configuration or program is install, do it in this setup file.
- Create a claude skill/hook/agent to every new project creation use Infisical.

- Doubts:
  - Omarchy comes with a skill call omarchy. It is specific for dealing with omarchy configuration by claude ai. When we create synlinks to our own configuration:
    - does I'll need to change also this omarchy skill? It alread points out the right files (~/.config.) in the omarchy hierarquical structure.
  - Related to the question above, when I create a synlink to a file that alread exists in the file system, lets supose the skill I mention above. What happens? Does it subscribe the atual system file for the new link (or my dotfile file)? How this will interfier with my process.
