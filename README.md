# Moneda Oamenilor

Token cu demurrage progresiv pe inactivitate, pe L2 EVM.

## Statut: TESTNET. Nu deploya pe mainnet.

Contractele n-au trecut audit profesional. Până atunci, orice deploy cu
valoare reală e o decizie proastă, indiferent cât de verzi sunt testele.

Înainte de mainnet, trei lucruri, în ordinea asta:

1. **Audit profesional.** Nu review de prieteni. Contract cu demurrage +
   trezorerie + guvernanță = suprafață de atac mare.
2. **Analiză MiCA cu un avocat.** Din decembrie 2024 regulamentul se aplică
   integral. Un token cu ofertă publică, trezorerie și fond de stabilitate
   care intervine pe piață nu e zonă gri — sunt obligații de white paper
   notificat, iar intervențiile fondului ating prevederile de abuz de piață.
3. **Testnet cu utilizatori reali**, minimum câteva luni.

## Ce e implementat

| Contract | Statut | Teste |
|---|---|---|
| `MonedaOamenilor.sol` | funcțional, cu blocare in-place | 21 |
| `QuadraticDAO.sol` | funcțional | 12 |
| `CircuitBreaker.sol` | funcțional | 8 |
| `SessionKeysManager.sol` | funcțional | 8 |
| `POLVesting.sol` | funcțional | 6 |
| `Splitter` | logica e în token | — |
| `AntiFlashloanGuard` | nu mai e necesar | — |
| `StabilityFund` | **nu se implementează** — vezi ABATERI.md | — |

**70 de teste trec**, inclusiv fuzz cu 512 rulări pe invariantele critice.

## Deploy

```bash
export PRIVATE_KEY=0x...
export GARDIAN=0x...      # multisig, NU cheia de deploy
export TREZORERIE=0x...
export STAKING=0x...
# toate sunt OBLIGATORII: scriptul dă revert dacă lipsesc sau dacă
# GARDIAN/TREZORERIE coincid cu cheia de deploy

forge script script/Deploy.s.sol --rpc-url $BASE_SEPOLIA_RPC --broadcast --verify
```

Scriptul face configurarea în ordinea corectă și **predă rolurile către DAO**,
apoi verifică predarea și dă revert dacă deployer-ul a rămas cu putere.

Ordinea contează. Două greșeli frecvente pe care le previne:

- **Scutirile înainte de primii tokeni.** Fără ele, Vault-ul își erodează
  propriile depozite și mizele din DAO se topesc în timpul votării.
- **Renunțarea la roluri la final.** Cine face deploy primește inevitabil
  guvernanța, ca să poată configura. Dacă nu o cedează, tot discursul despre
  guvernanță descentralizată e fals: o cheie privată schimbă orice parametru
  fără vot.

`emite` **nu** e pe lista albă a DAO-ului. Nicio propunere nu poate crea
tokeni. După deploy nimeni nu mai are rolul `EMITENT` — emisiunea inițială se
face înainte de predare.

## Important: codul diferă de specificația inițială

Specificația conținea bug-uri care blocau sau distrugeau fonduri — între
altele, o retragere din Vault care dădea panic **întotdeauna**, lăsând
depunerile nerecuperabile.

Toate abaterile sunt documentate în [`docs/ABATERI.md`](docs/ABATERI.md),
fiecare cu motivul și cu testul care o apără.

**Whitepaper-ul trebuie actualizat să corespundă codului** înainte să ajungă
la cineva. Distanța dintre ce promite documentul și ce face contractul era
problema cea mai gravă a variantei inițiale — mai gravă decât oricare bug
individual.

## Rulare

```bash
forge build
forge test
forge test --match-test testFuzz -vvv   # doar fuzz
```

## Model economic

**Demurrage pe transe:**

| Inactivitate | Rată |
|---|---|
| 0–30 zile | 0% |
| 30–90 zile | 1% / 30 zile |
| peste 90 zile | 2.5% / 30 zile |

Se aplică pe interval, nu retroactiv: cine e inactiv 100 de zile plătește 0%
pe primele 30, 1% pe următoarele 60, 2.5% pe ultimele 10.

**Distribuție** (demurrage + taxe): 33% ars, 33% trezorerie, 34% validatori.
Restul din împărțire merge la validatori, ca suma părților să fie exactă.

**Plafoane peste care guvernanța nu poate trece:** 10%/lună demurrage,
5% taxă, 20% APY, și **perioadă de grație minimă de 30 de zile**.

Ultima a fost adăugată după audit: fără ea, `setPraguri(1 secondă, 2 secunde)`
combinat cu rata maximă dădea ~72% erodare anuală de la o secundă de
inactivitate. Afirmația „un vot nu poate confisca solduri" era falsă exact pe
vectorul ăsta. Vezi §0.4.B din [`docs/AUDIT-JURIDIC.md`](docs/AUDIT-JURIDIC.md).

**Demurrage-ul este evitabil** printr-un auto-transfer sub pragul de
micro-tranzacții. Comportamentul e documentat în
[`docs/EVAZIUNE-DEMURRAGE.md`](docs/EVAZIUNE-DEMURRAGE.md), cu variante de
rezolvare. Până la o decizie, **whitepaper-ul nu are voie să afirme că
deținătorii inactivi plătesc demurrage** — la literă, plătesc doar cei
neinformați.

**Blocare in-place** (înlocuiește `SavingsVault`, care a fost retras):

`blocheaza(pana)` restricționează propriul sold până la o dată, maxim un an.
**Tokenii nu părăsesc contul** — `balanceOf` îi conține tot timpul. Nu există
custodie, nu există randament promis, nu există penalizare de ieșire.

Beneficiul blocării este scutirea de demurrage. Atât. Blochezi ca să nu
pierzi, nu ca să câștigi.

De ce s-a schimbat: `SavingsVault` muta tokenii în contract, ceea ce făcea
din utilizator un creditor în loc de proprietar — adică **custodie de
criptoactive în numele clienților**, serviciu CASP sub MiCA art. 59. Iar
randamentul de 2% garantat, finanțat din prelevări de la alți deținători,
activa simultan testul Howey și analogia cu depozitul bancar. Vezi §2.3 din
[`docs/AUDIT-JURIDIC.md`](docs/AUDIT-JURIDIC.md).

## Imutabilitate

Guvernanța poate modifica **exact trei parametri**: ratele de demurrage,
taxa de tranzacție și pragurile. Nimic altceva, niciodată. Nu se poate
autoextinde: `setPermis` nu e pe propria listă albă.

Nimeni — inclusiv fondatorii — nu poate emite tokeni noi, nu poate accesa
fondurile utilizatorilor și nu poate modifica altceva. E verificabil on-chain.

Asta e o proprietate, nu o limitare, și trebuie descrisă ca atare. Orice
material care sugerează o guvernanță adaptabilă sau un roadmap de parametri
ar fi fals.
