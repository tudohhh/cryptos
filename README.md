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
| `MonedaOamenilor.sol` | funcțional | 11 |
| `SavingsVault.sol` | funcțional | 10 |
| `QuadraticDAO.sol` | funcțional | 12 |
| `CircuitBreaker.sol` | funcțional | 8 |
| `SessionKeysManager.sol` | funcțional | 8 |
| `POLVesting.sol` | funcțional | 6 |
| `Splitter` | logica e în token | — |
| `AntiFlashloanGuard` | nu mai e necesar | — |
| `StabilityFund` | **nu se implementează** — vezi ABATERI.md | — |

**55 de teste trec**, inclusiv fuzz cu 512 rulări pe invariantele critice.

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
5% taxă, 20% APY. Un vot nu trebuie să poată confisca solduri.

**Vault:** 3/6/12 luni, scutit de demurrage, randament finanțat dintr-o
rezervă. Depunerea e refuzată dacă rezerva nu acoperă randamentul promis.
