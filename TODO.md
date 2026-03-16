# 🦴 GITHUBBONE DEFINITIVO — Roadmap Erasmus (20 Feb → 30 Giu)
  
---  
  
# 🎯 Obiettivo entro il 30 giugno  
  
- [ ] GitHub pulito e professionale  
- [x] 1 progetto PESO pubblicato (Fuzz Triage Pipeline)  
- [ ] 2 progetti MEDIUM pubblicati  
- [ ] 1 progetto SMALL  
- [ ] 3–6 writeup tecnici  
- [ ] CV tecnico + LinkedIn sistemato  
  
> Regola d’oro: meno repository, ma molto curati.  
  
---  
  
# 🧪 Progetto PESO — Fuzz Triage Pipeline  
  
Pipeline completa di fuzzing e triage automatizzato progettata per simulare workflow reali di vulnerability discovery.  
  
## Stato attuale  
  
Pipeline **completamente funzionante** con:  
  
- Docker environment riproducibile  
- libFuzzer harness  
- corpus automatico  
- crash capture automatico  
- crash reproduction  
- crash minimization  
- crash triage  
- crash deduplication  
- report automatici (Markdown + JSON)  
  
Run reale eseguita:  
  
- ~51 milioni di executions  
- coverage ~605  
- corpus generato ~513 inputs  
  
Deliverable raggiunto: **pipeline fuzzing end-to-end funzionante**  
  
---  
  
# 🔥 Fase 1 — Sanitizer Integration  
  
Obiettivo: migliorare diagnosi crash.  
  
## Tasks  
  
- [ ] Migliorare integrazione AddressSanitizer  
- [ ] Migliorare integrazione UndefinedBehaviorSanitizer  
- [ ] Estrarre crash type automaticamente  
- [ ] Migliorare stacktrace extraction  
- [ ] Classificare automaticamente i crash  
  
Deliverable: **crash diagnostics migliorati**  
  
---  
  
# 🔥 Fase 2 — Crash Minimization (COMPLETATA)  
  
Sistema di minimizzazione crash implementato.  
  
Funzionalità:  
  
- minimizzazione automatica  
- riduzione dimensione input  
- metadata salvato  
- output salvato in:  

artifacts/minimized/

  
Deliverable: **crash minimizzati automaticamente**  
  
---  
  
# 🔥 Fase 3 — Multi-Target Support  
  
Obiettivo: trasformare il tool in framework.  
  
## Targets previsti  
  
- cjson (attuale)  
- libpng  
- sqlite  
- yaml parser  
  
## Tasks  
  
- [ ] generalizzare fetch.sh  
- [ ] generalizzare build.sh  
- [ ] supportare harness multipli  
  
Deliverable: **fuzzing framework generico**  
  
---  
  
# 🔥 Fase 4 — Coverage Tracking  
  
Obiettivo: analizzare copertura del fuzzer.  
  
## Tasks  
  
- [ ] integrare llvm-profdata  
- [ ] integrare llvm-cov  
- [ ] salvare coverage per run  
- [ ] generare HTML coverage report  
  
Output previsto:  

artifacts/coverage/

  
Deliverable: **coverage reporting**  
  
---  
  
# 🔥 Fase 5 — Corpus Management  
  
Gestione avanzata corpus.  
  
## Tasks  
  
- [ ] corpus merge automatico  
- [ ] corpus deduplication  
- [ ] corpus minimization  
- [ ] riutilizzo corpus tra run  
  
Struttura:  

corpus/  
initial/  
merged/  
minimized/

  
Deliverable: **corpus lifecycle completo**  
  
---  
  
# 🔥 Fase 6 — Crash Bucketing  
  
Obiettivo: classificazione crash.  
  
## Tasks  
  
- [ ] dedup basato su stacktrace  
- [ ] bucket per crash type  
- [ ] bucket per funzione  
- [ ] bucket per file:line  
  
Deliverable: **crash classification**  
  
---  
  
# 🔥 Fase 7 — CI Fuzzing  
  
Automazione via GitHub Actions.  
  
## Tasks  
  
- [ ] smoke fuzzing automatico  
- [ ] upload crash automatico  
- [ ] upload report automatico  
  
Deliverable: **CI fuzzing pipeline**  
  
---  
  
# 🔥 Fase 8 — Multi-Engine Support  
  
Supporto multipli engine.  
  
Engines:  
  
- libFuzzer  
- AFL++  
  
## Tasks  
  
- [ ] integrare AFL++  
- [ ] engine selection CLI  

fuzzpipe fuzz --engine libfuzzer  
fuzzpipe fuzz --engine afl

  
Deliverable: **multi-engine support**  
  
---  
  
# 🔥 Fase 9 — Root Cause Detection  
  
Obiettivo: estrarre automaticamente:  
  
- crash type  
- crash function  
- crash file  
- crash line  
  
Deliverable: **automatic root cause extraction**  
  
---  
  
# 🔥 Fase 10 — OSS-Fuzz Style Architecture  
  
Architettura finale:  

fuzzpipe/  
targets/  
artifacts/  
runs/  
crashes/  
reports/  
coverage/  
minimized/

  
Deliverable: **mini OSS-Fuzz architecture**  
  
---  
  
# 🧠 Progetto MEDIUM #1 — QRStrike  
  
Toolkit CLI per analisi sicurezza QR code.  
  
Funzioni previste:  
  
- payload classification  
- redirect chain analysis  
- QR fuzzing  
- dataset generation  
- risk scoring  
- report automatici  
  
Deliverable: **QR security research toolkit**  
  
---  
  
# ☁️ Progetto MEDIUM #2 — Cloud Misconfig Lab  
  
Laboratorio cloud vulnerabile.  
  
Obiettivo:  
  
- AWS/GCP misconfigurations  
- exploit dimostrativi  
- detection  
- remediation  
  
Deliverable: **cloud security lab**  
  
---  
  
# 🌐 Progetto MEDIUM #3 — Secure App + Threat Model  
  
Web app vulnerabile con:  
  
- threat model STRIDE  
- exploit dimostrativi  
- documentazione sicurezza  
  
Deliverable: **secure design case study**  
  
---  
  
# 🔧 Progetto SMALL  
  
Possibili opzioni:  
  
- Ghidra automation scripts  
- reverse engineering writeup  
- exploit walkthrough  
  
---  
  
# 📝 Writeups  
  
Obiettivo: **3–6 writeup tecnici**  
  
Possibili temi:  
  
- designing fuzzing pipelines  
- crash triage automation  
- QR security research  
- redirect chain analysis  
- parser fuzzing experiments  
  
---  
  
# 🎯 Priorità prossima sessione  
  
1. migliorare crash diagnostics  
2. coverage tracking  
3. multi-target support  
4. polishing repository  
  
---  
  
# 📊 Progresso progetto  
  
Completamento stimato:  
  
**45%**  
  
La pipeline base è completata.  
Ora la fase è di **espansione e polishing**.  
  
---  
  
# 🧠 Stato attuale  
  
Pipeline completa con:  
  
- fuzzing funzionante  
- crash capture  
- crash reproduction  
- crash minimization  
- triage automatico  
- report automatico  
- demo crash riproducibile  
  
UX disponibile:  

.\fuzz\run.ps1 fuzz  
.\fuzz\run.ps1 repro  
.\fuzz\run.ps1 triage  
.\fuzz\run.ps1 minimize

  
Il tool è già **usabile come fuzzing lab completo**.