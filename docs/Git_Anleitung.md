# Git- & Repository-Handbuch

Dieses Handbuch dient der Dokumentation der Git-Workflow-Richtlinien, Sicherheits-Best-Practices (wie GnuPG/SSH-Signierung) und dem Umgang mit Zweigen (Branches) in diesem Repository.

---

## 1. Grundlegende Konfiguration
Vor dem ersten Commit sollten Name und E-Mail-Adresse global oder lokal im Repository festgelegt werden:

```bash
git config --local user.name "Dorian (Giantfossil)"
git config --local user.email "xdorian17590x@gmail.com"
```

### Empfohlene globale Einstellungen:
* **Standard-Pull-Verhalten (Rebase):** Verhindert unnötige Merge-Commits und hält die Historie linear.
  ```bash
  git config --global pull.rebase true
  ```
* **Standard-Branch-Name:** `main` statt `master` festlegen.
  ```bash
  git config --global init.defaultBranch main
  ```

---

## 2. Commit-Signierung (GnuPG & SSH)
Da Sicherheit und Integrität in diesem Projekt eine wichtige Rolle spielen, sollten Commits kryptografisch signiert werden.

### A) Signieren mit GnuPG
1. **Vorhandene GPG-Schlüssel auflisten:**
   ```bash
   gpg --list-secret-keys --keyid-format=long
   ```
2. **Git mitteilen, welchen Schlüssel es nutzen soll:**
   ```bash
   git config --local user.signingkey <DEINE_SCHLÜSSEL_ID>
   ```
3. **Automatische Signierung für dieses Repository aktivieren:**
   ```bash
   git config --local commit.gpgsign true
   ```

### B) Signieren mit SSH (Moderne Alternative)
Wenn du lieber deinen SSH-Schlüssel zur Signierung verwendest:
1. **Git auf SSH-Signierung umstellen:**
   ```bash
   git config --local gpg.format ssh
   ```
2. **Pfad zum SSH-Schlüssel angeben:**
   ```bash
   git config --local user.signingkey ~/.ssh/id_ed25519.pub
   ```
3. **Automatische Signierung aktivieren:**
   ```bash
   git config --local commit.gpgsign true
   ```

---

## 3. Branching-Modell & Rebase-Workflows
Das Repository verwendet eine lineare Historie. Commits werden bevorzugt per Rebase statt per Merge integriert.

### Wichtige Befehle im Arbeitsalltag:
* **Neuen Branch erstellen und wechseln:**
   ```bash
   git checkout -b feature-name
   ```
* **Aktuelle Änderungen vom Remote-Repository holen und einpflegen (linear):**
   ```bash
   git pull --rebase origin main
   ```
* **Feature-Branch auf den aktuellen Stand von `main` bringen:**
   ```bash
   git checkout feature-name
   git rebase main
   ```

### Hilfe bei laufendem Rebase (Rebase-State):
Wenn sich das Repository (wie aktuell) in einem Rebase-Zustand befindet:
* **Fortschritt anzeigen:** `git status` zeigt an, welche Dateien Konflikte aufweisen.
* **Nach Konfliktlösung fortfahren:** 
  ```bash
  git add <konfliktdatei>
  git rebase --continue
  ```
* **Rebase komplett abbrechen** (stellt den Zustand vor dem Rebase wieder her):
  ```bash
  git rebase --abort
  ```

---

## 4. Gitignore-Richtlinien
Dateien, die private Daten, Passwörter, temporäre Testdaten (wie Benchmark-Logs von `fio`) oder benutzerspezifische Desktop-Caches enthalten, werden über die `.gitignore` vom Tracking ausgeschlossen.

**Aktuelle `.gitignore` Konfiguration:**
* `ai_instructions.txt` (Darf laut Regel A nicht von der K.I. manipuliert/committet werden).
* `.directory` (KDE-Ordner-Konfigurationsdateien, da Dorian KDE nutzt).
* `*.log` (Temporäre Ausgaben von Skripten).
* `fio_test_file*` (Temporäre Benchmark-Dateien).

---

## 5. Remote-Synchronisation
Der Remote-Server ist als `origin` verknüpft:
```bash
git remote -v
# origin  https://github.com/Giantfossil/projekt_storage.git (fetch)
# origin  https://github.com/Giantfossil/projekt_storage.git (push)
```

**Änderungen pushen:**
```bash
# Auf dem aktuellen Branch pushen
git push origin <branch_name>

# Wenn nach einem Rebase die Historie auf dem Remote-Server überschrieben werden muss (Force-Push mit Schutz):
git push origin <branch_name> --force-with-lease
```
