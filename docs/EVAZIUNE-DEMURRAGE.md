# Evaziunea demurrage-ului — variante, nu decizie

**Constatarea §0.4.A din `docs/AUDIT-JURIDIC.md`.** Documentul ăsta prezintă
opțiuni și consecințe. **Alegerea e a fondatorului**, nu a mea: fiecare
variantă schimbă modelul economic, iar unele au și consecințe juridice.

## Ce se întâmplă acum

`test_DOCUMENTAT_DemurrageEvitabilPrinAutoTransfer` demonstrează: un
auto-transfer de 0,9 tokeni la fiecare 29 de zile evită demurrage-ul
**integral**, un an întreg, cu zero taxe. Suma e sub `pragMicroTx`, deci nici
taxa de tranzacție nu se aplică. Costul: gas pe L2, fracțiuni de cent.

Mecanismul nu descurajează tezaurizarea. Transferă valoare **dinspre cei care
nu știu, către cei care știu** — plus către trezorerie și validatori.

Asta e problema juridică, nu evitabilitatea în sine. O taxă evitabilă și
**declarată** e o alegere de design. Una evitabilă și nedeclarată, într-un
document care spune „deținătorii inactivi plătesc", e informație incorectă
sub MiCA art. 6 și potențial practică înșelătoare sub Legea 363/2007.

---

## Varianta 1 — Nu schimba codul, schimbă documentul

Declari explicit că demurrage-ul se resetează la orice transfer, inclusiv
către sine, și că oricine poate face asta. Publici cum.

- **Cost de implementare:** zero
- **Efect economic:** demurrage-ul devine, de facto, opțional. Veniturile
  trezoreriei din demurrage tind spre zero pe măsură ce utilizatorii află.
- **Poziție juridică:** cea mai curată dintre toate. Nimic ascuns.
- **Problema:** modelul economic din whitepaper își pierde motorul. Dacă
  demurrage-ul e opțional, ce mai rămâne din „moneda care circulă"?

## Varianta 2 — Auto-transferul nu resetează ceasul

O linie: dacă `de_la == catre`, nu reseta `ultimaActivitate`.

- **Cost:** minim, o condiție în `_update`
- **Efect:** oprește cazul trivial
- **Problema:** se ocolește cu două adrese care își trimit reciproc. A→B,
  B→A, ambele resetate. Costă dublu gas și nimic altceva.
- **Verdict:** rezolvă simptomul, nu problema. Nu o recomand singură,
  pentru că dă impresia că problema e rezolvată.

## Varianta 3 — Resetare proporțională cu ce ai mișcat efectiv

Ceasul se resetează integral doar dacă transferi cel puțin o fracțiune din
sold (de exemplu 1%). Sub prag, ceasul avansează parțial sau deloc.

- **Cost:** moderat. Schimbă `_update` și necesită regândirea invariantelor.
- **Efect:** activitatea simbolică nu mai cumpără scutire. Ca să eviți
  demurrage-ul trebuie să miști valoare reală — adică exact ce vrea
  mecanismul să încurajeze.
- **Problema:** cine are sold mare trebuie să miște sume mari ca să se
  scutească. Poate fi corect (proporțional) sau regresiv, depinde cum îl
  privești. Trebuie explicat clar în whitepaper.
- **Observație:** e varianta care corespunde cel mai bine intenției
  declarate a mecanismului.

## Varianta 4 — Eroziune globală prin indice, cu scutire pentru activi

Rescriere: soldurile devin „shares", un indice global scade continuu, iar
utilizatorii activi primesc rabat. Modelul clasic de demurrage
(Gesell / stamp scrip), implementat cum se face în DeFi.

- **Cost:** mare. Rescriere a contractului de bază, cu tot ce înseamnă
  pentru testele existente și pentru integrări.
- **Efect:** matematic solid, imposibil de evitat prin gesturi.
- **Problema:** rebasing rupe integrarea cu DEX-uri, poduri și portofele
  care presupun solduri ERC-20 stabile. E o decizie de arhitectură, nu o
  reparație.

## Varianta 5 — Elimină `pragMicroTx` pentru auto-transferuri

Taxa se aplică și sub prag dacă `de_la == catre`.

- **Cost:** mic
- **Efect:** face evaziunea să coste 0,5% pe ciclu, adică ~6% pe an — mai
  mult decât demurrage-ul de nivel 1 pe care îl evită.
- **Problema:** tot se ocolește cu două adrese. Combinată cu varianta 2,
  acoperă și cazul ăla parțial.

---

## Ce recomand ca proces, nu ca soluție

Alegerea depinde de un lucru pe care numai tu îl știi: **ce vrea de fapt să
facă mecanismul.**

- Dacă vrea **venit pentru trezorerie** → varianta 3 sau 4, altfel venitul
  dispare pe măsură ce oamenii află.
- Dacă vrea **semnal comportamental** (împinge oamenii spre Vault sau spre
  cheltuire) → varianta 1 poate fi suficientă: cine face efortul să evite a
  interacționat oricum cu protocolul.
- Dacă vrea **corectitudine între deținători** → varianta 3, singura care
  tratează la fel utilizatorul informat și pe cel neinformat.

Indiferent de variantă: **whitepaper-ul trebuie să descrie comportamentul
real**, inclusiv ce rămâne evitabil. Asta e valabil și dacă alegi varianta 1,
și e partea care contează juridic mai mult decât alegerea tehnică.

Spune-mi care direcție și o implementez cu teste.
