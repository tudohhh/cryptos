# Abateri de la specificația inițială

Fiecare abatere de mai jos e deliberată. Codul din specificație, executat
literal, produce contracte care blochează sau distrug fonduri. Documentul
ăsta există ca whitepaper-ul și codul să spună **același lucru** — distanța
dintre ele era problema cea mai gravă a variantei inițiale.

## Bug-uri care distrugeau fonduri

### 1. `withdrawVault` nu putea fi apelată niciodată

```solidity
// specificația:
uint256 yield = (amount * baseYield *
    (block.timestamp - block.timestamp - (vault.duration * 30 days)))
    / (100 * 365 days);
```

`block.timestamp - block.timestamp` = 0, apoi `0 - (duration * 30 days)` e
negativ într-un `uint256` → panic în Solidity 0.8.x. **Orice depunere în
Vault devenea nerecuperabilă.** Nu era edge case, era calea principală.

**Acum:** randamentul se rezervă la depunere și se plătește integral la
scadență. `test_RetragereaLaScadentaChiarFunctioneaza`.

### 2. Primul transfer al oricărui cont nou îi ardea tot soldul

`lastTransactionTime[user]` e 0 pentru un cont nou, deci
`block.timestamp - 0` ≈ 57 de ani → intra direct pe transa maximă.

**Acum:** `ultimaActivitate == 0` înseamnă „cont nou", nu „inactiv din 1970".
Ceasul pornește la prima primire de tokeni. `test_ContNouNuEsteTaxat`.

### 3. `_calculateDemurrage` returna de ~10^16 ori soldul

```solidity
return (balance * demurrageLevel1 * 1e18) / (100 * 30 days) * inactiveTime;
```

Înmulțirea cu `1e18` combinată cu ordinea operațiilor. Pentru 1000 de tokeni
și 45 de zile de inactivitate rezulta 1.5 × 10^19 tokeni. `_burn` dădea
revert de fiecare dată.

**Acum:** calcul pe transe, cu plafon dur la soldul contului.
`testFuzz_DemurrageMereuSubSold` verifică pe 512 combinații.

### 4. `demurrageLevel2 = 25` însemna 25%/lună, nu 2.5%

Comentariul și whitepaper-ul spuneau 2.5%. Codul, folosit ca `25/100`,
aplica de zece ori mai mult.

**Acum:** rate în basis points (`250` = 2.5%), fără ambiguitate.

## Bug-uri care goleau contractul

### 5. `transferFrom` ocolea complet modelul economic

Specificația suprascria doar `transfer`. Un `approve` către tine însuți și
treceai pe lângă demurrage, taxe și arderi — adică pe lângă tot protocolul.

**Acum:** logica stă în `_update`, hook-ul prin care trec `transfer`,
`transferFrom`, `mint` și `burn`. `test_TransferFromNuOcolesteTaxa`.

### 6. Session Keys nu verificau nimic

```solidity
function verifySignature(...) private pure returns (bool) {
    return true; // Placeholder
}
```

Marcată `pure` în timp ce pretindea că verifică. Orice agent cu o cheie
putea transfera până la `maxSpend` fără acordul utilizatorului.

**Acum:** EIP-712 + `ECDSA.recover`, iar semnatarul trebuie să fie
deținătorul contului. În plus, nonce și deadline pe fiecare operațiune —
specificația semna `(user, amount, recipient, chainid)`, fără nonce, deci
aceeași semnătură se putea rejuca la infinit.
`test_AgentulNuPoateExecutaFaraSemnatura`, `test_SemnaturaNuSePoateRejuca`.

### 7. `_applyDemurrage` ardea de două ori și transfera din nimic

Ardea `demurrageAmount` de la utilizator, apoi mai încerca să ardă 33% de la
`address(this)`, unde nu ajunsese nimic. Revert garantat.

**Acum:** o singură colectare, împărțită 33/33/34, cu restul din împărțire
alocat explicit ca să nu se piardă wei. `test_ImpartireaNuPierdeWei`.

### 8. Burn către `address(0)`

`Splitter` transfera partea arsă la adresa zero. OpenZeppelin ERC20 dă
revert (`ERC20InvalidReceiver`).

**Acum:** `_burn`, nu transfer.

### 9. Voturile nu se recuperau niciodată

`QuadraticDAO.vote` lua `votePower²` tokeni și nu exista nicio funcție de
retragere. Fiecare vot distrugea definitiv miza.

**Acum:** `revendicaMiza(id)` — funcția care lipsea complet. Miza se
blochează pe durata votării și se recuperează după, inclusiv la propuneri
anulate: miza e garanție, nu pedeapsă. `test_MizaSeRecupereazaDupaVot`.

### 10. `emit DemurrageApplied(..., inactiveTime > ...)` nu compila

`inactiveTime` nu exista în acel scope.

## Schimbări de design, nu bug-uri

### 11. Demurrage pe transe, nu retroactiv

Specificația aplica rata ultimei transe pe **tot** intervalul de
inactivitate. Cineva inactiv 100 de zile plătea 2.5% pe toate cele 100.

Acum: 0% pe primele 30, 1% pe următoarele 60, 2.5% pe ultimele 10. A pedepsi
retroactiv o perioadă în care regula era alta e greu de justificat față de
utilizator.

### 12. Plafoane dure peste care guvernanța nu poate trece

`MAX_RATE_BPS = 1000` (10%/lună), `MAX_TAXA_BPS = 500` (5%),
`MAX_APY_BPS = 2000`. Fără ele, o propunere greșită sau ostilă poate seta
100% și confisca soldurile. Un vot nu trebuie să poată face asta.

### 13. Randamentul Vault e finanțat, nu promis

Specificația promitea 2% APY fără să spună de unde vin tokenii. Acum există
o rezervă alimentată explicit, iar depunerea e **refuzată la intrare** dacă
rezerva nu acoperă randamentul.

Mai bine refuzi un depozit decât să nu poți plăti la scadență. A doua
variantă are un nume și nu e „bug".

### 14. Adrese scutite

Vault-ul, trezoreria și contractul de staking nu plătesc demurrage. Fără
asta, tokenii din Vault s-ar eroda — adică exact opusul scopului Vault-ului.

### 15. CircuitBreaker: atestare M-din-N, nu o singură adresă

Documentul descria „oracole rotaționale, 3 din 5", dar contractul avea
`onlyAIOracle` — o adresă care putea îngheța trezoreria singură. Cheia aia
compromisă însemna protocol oprit.

**Acum:** `pragAtestari` semnături distincte pe **același** raport,
identificat prin hash-ul conținutului. Atestări pe rapoarte diferite nu se
adună. `test_UnSingurOracolNuPoateIngheta`.

### 16. Înghețarea expiră singură

`autoUnfreeze` exista în specificație, dar nimic nu garanta că o cheamă
cineva. O trezorerie înghețată la nesfârșit fiindcă nimeni nu apasă un buton
e același lucru cu o trezorerie pierdută.

**Acum:** `esteInghetat()` returnează `false` automat după `durataInghetare`.
`test_InghetareaExpiraSingura`.

### 17. Propunerile DAO execută apeluri de pe listă albă

Specificația avea un `_executeAction` gol. O propunere care trece trebuie să
poată chema ceva — dar nu orice: fără listă albă, o propunere acceptată
putea chema `emite()` și crea tokeni la infinit.

Lista albă se schimbă tot prin vot, iar permisiunea se reverifică **la
execuție**, nu doar la propunere: o propunere veche nu trebuie să poată
folosi o permisiune retrasă între timp.

### 18. Gardianul poate anula, nu poate executa

Asimetrie deliberată. Puterea de a opri ceva rău e mult mai puțin
periculoasă decât puterea de a face ceva.

### 19. POLVesting: a doua alocare nu o mai șterge pe prima

`vestingSchedules[beneficiary] = schedule` suprascria graficul anterior. O a
doua alocare pentru aceeași persoană îi pierdea prima.
**Acum:** listă de grafice per beneficiar.

### 20. Revocarea vesting-ului nu confiscă retroactiv

`revoked` exista ca flag, dar nicio funcție nu-l seta și nu se spunea ce se
întâmplă cu tokenii. **Acum:** ce s-a maturizat rămâne al beneficiarului,
doar partea nematurizată se întoarce la trezorerie. Un vesting care poate fi
revocat retroactiv nu e vesting.

## Ce nu e implementat

**`StabilityFund`** — și nu din lipsă de timp.

Un fond al protocolului care cumpără automat propriul token de pe piață
când prețul scade, cu praguri nepublicate și intervenții netransparente,
intră direct peste prevederile de abuz de piață din MiCA (Titlul VI).
Nu e o problemă pe care o rezolvi în Solidity.

Dacă vrei totuși mecanism de stabilitate, varianta apărabilă arată altfel:
intervenții anunțate în avans, praguri publice și imuabile, plafon pe
volum, fiecare operațiune vizibilă on-chain înainte să se execute.
Diferența dintre „operațiune de trezorerie transparentă" și „manipulare"
stă exact în lucrurile astea. Merită discutată cu un avocat înainte de cod.

**`AntiFlashloanGuard`** — nu mai e nevoie de el ca modul separat.
Protecția din specificație (număr de bloc per adresă) se ocolea banal cu
alte adrese. Vault-ul are scadențe minime și penalizare pe principal, ceea
ce face atacul neprofitabil fără a mai adăuga un contract.
