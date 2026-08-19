# RAPORT DE AUDIT JURIDIC, REGULATOR ȘI FISCAL

## Proiect „Moneda Oamenilor" (repo: `tudohhh/cryptos`, branch `feat/nucleu-token`)
### Perspectiva: fondator persoană fizică, rezident fiscal în România

**Data analizei:** 19 august 2026
**Bază documentară:** cod sursă clonat și citit integral (`src/*.sol`, `script/Deploy.s.sol`, `docs/ABATERI.md`, `README.md`, suita de teste), plus cadrul normativ UE și RO în vigoare la data prezentei.

---

> **Notă de statut.** Acest document este o analiză juridico-tehnică produsă de un sistem AI, nu de un avocat înscris în barou, și nu constituie consultanță juridică în sensul Legii nr. 51/1995. Este construit ca să fie *direct utilizabil* de un avocat și de un consultant fiscal: identifică problemele, articolele aplicabile și soluțiile concrete, astfel încât timpul plătit unui profesionist să se ducă pe validare și implementare, nu pe descoperire. Trei chestiuni marcate în text drept **[VERIFICARE OBLIGATORIE]** cer confirmare pe forma consolidată a textelor de lege înainte de orice decizie.

---

# 0. SINTEZĂ EXECUTIVĂ

## 0.1. Verdict

**NU LANSA ÎN CONFIGURAȚIA ACTUALĂ. NU LANSA CA PERSOANĂ FIZICĂ. NU LANSA DIN ROMÂNIA CA JURISDICȚIE DE EMISIUNE.**

Nu pentru că proiectul ar fi rău construit — codul este, tehnic, peste media pieței, iar `docs/ABATERI.md` demonstrează o disciplină pe care puțini fondatori o au. Ci pentru trei motive structurale, care nu se rezolvă prin redenumiri sau prin clauze în Terms of Service:

1. **MiCA art. 4 alin. (1) lit. (a) cere ca ofertantul de criptoactive să fie *persoană juridică*.** O persoană fizică nu poate face legal o ofertă publică de criptoactive în UE. Nu există derogare, nu există „zonă gri", nu există interpretare favorabilă. Configurația actuală a scriptului de deploy — în care deployer-ul primește `EMITENT` și emite integral supply-ul înainte de predarea rolurilor — te înregistrează *on-chain, cu timestamp, ireversibil*, ca ofertant persoană fizică.

2. **România nu are, la data prezentei, autoritate competentă desemnată în aplicarea MiCA.** <cite index="8-1">Prim-vicepreședintele ASF a confirmat public că nicio autoritate din România nu este desemnată competentă în aplicarea Regulamentului (UE) 2023/1114, astfel încât nu pot fi primite sau soluționate cereri formulate în temeiul acestui regulament</cite>. <cite index="17-1">Un proiect de ordonanță de urgență a fost prezentat în primă lectură la Guvern la 2 aprilie 2026</cite>, dar <cite index="19-1">Comisia Europeană a declanșat procedură de infringement împotriva României pentru neadoptarea legislației interne de aplicare a MiCA, iar Parlamentul a fost în vacanță până la 1 septembrie 2026</cite>. Consecință practică brutală: **dacă ești ofertant român, nu ai unde notifica white paper-ul.** Nu e o problemă de birocrație lentă — e o imposibilitate juridică de conformare. Structura cu entitate emitentă în altă jurisdicție UE nu este optimizare fiscală; este singura cale de conformare disponibilă.

3. **Mecanismul `SavingsVault` combină trei elemente care, împreună, formează exact tiparul pe care un procuror român îl încadrează fără efort:** (i) fonduri ale publicului transferate în custodia unui contract, (ii) promisiune de randament fix predeterminat (2% APY), (iii) randament finanțat din sumele prelevate de la *alți* deținători prin demurrage și taxe. Elementul (iii) este cel toxic. Nu contează că îl numești „rezervă finanțată" în loc de „dobândă": mecanismul prin care un participant primește un câștig garantat din sumele prelevate de la alți participanți are un nume în doctrina penală, iar acel nume nu e „model economic inovator".

## 0.2. Cele zece riscuri majore, ordonate după probabilitatea × severitatea consecinței personale

| # | Risc | Consecință maximă pentru fondator |
|---|---|---|
| 1 | Ofertă publică de criptoactiv făcută de persoană fizică, fără white paper notificat | Interzicerea ofertei, amenzi MiCA (până la 700.000 EUR sau 5% din CA anuală pentru persoane fizice/juridice, funcție de faptă), răspundere civilă față de fiecare achizitor |
| 2 | `SavingsVault` cu randament garantat finanțat din prelevări de la alți utilizatori | Dosar penal — înșelăciune (art. 244 C.pen.), eventual în formă continuată; sechestru pe conturi și cripto |
| 3 | Demurrage **complet evitabil** prin auto-transfer sub prag (vezi §0.3) → doar utilizatorii neinformați plătesc | Practică comercială înșelătoare (Legea 363/2007), informații false în white paper (MiCA art. 6-7), potențial înșelăciune |
| 4 | Absența unei autorități competente în RO → imposibilitatea notificării | Blocaj total al lansării conforme din România |
| 5 | Fondatorul rămâne administrator perpetuu al `POLVesting`, deși scriptul afișează „Deployer-ul nu mai are putere" | Declarație factual falsă în documentația proiectului; distruge apărarea „protocol descentralizat" pentru MiCA, Howey și fiscal |
| 6 | DAO neînregistrat + fondator identificabil | Răspundere personală nelimitată; calificare posibilă ca societate simplă/asociere în participație (art. 1889-1920 C.civ.) |
| 7 | Demurrage aplicat automat asupra soldurilor consumatorilor + parametri modificabili prin vot | Clauze abuzive (Legea 193/2000), acțiune ANPC în încetare cu efect *erga omnes* asupra tuturor contractelor |
| 8 | Trezoreria (33% din fiecare prelevare) controlată dintr-o adresă legată de fondator | Venit impozabil la încasare, nedeclarat → evaziune fiscală (Legea 241/2005 art. 9), 2-8 ani închisoare |
| 9 | Scor de reputație / social mining (dacă se implementează) | Interdicție AI Act art. 5 alin. (1) lit. (c) — social scoring; amenzi până la 35 mil. EUR sau 7% din cifra de afaceri mondială |
| 10 | Închiderea conturilor bancare RO la prima detecție de flux cripto | Blocaj operațional; imposibilitatea de a plăti salarii/furnizori; efect de cascadă asupra SRL-ului |

## 0.3. Constatare preliminară critică: briefing-ul nu descrie codul

Mandatul primit enumeră mecanisme care **nu există în repository**, și descrie greșit mecanisme care există. Aceasta nu e o observație pedantă — este ea însăși una dintre cele mai mari expuneri juridice ale proiectului, pentru că orice document (white paper, pitch deck, site) care descrie sistemul așa cum îl descrie briefing-ul conține informații false despre un produs financiar oferit publicului.

| Ce spune briefing-ul | Ce spune codul |
|---|---|
| „Demurrage 0.5%" | Demurrage pe transe: **0% / 1% / 2.5% per 30 zile**. Cifra de 0.5% este `taxaTranzactie` (50 bps), un mecanism complet diferit |
| „Savings Vault" | Există: `SavingsVault.sol`, custodial, 3/6/12 luni, 2% APY, penalizare 10% la ieșire anticipată |
| „Session Keys ERC-4337" | **Nu este ERC-4337.** Este un contract propriu de delegare EIP-712 peste ERC-20. Nu există EntryPoint, nu există UserOperation, nu există account abstraction |
| „AI Circuit Breakers" | Există `CircuitBreaker.sol`, dar nu conține AI. Conține atestare M-din-N de la adrese cu rol `ORACOL`. Componenta AI e complet în afara lanțului și nespecificată |
| „Social Mining cu Scor de Reputație" | **Nu există în cod.** Niciun contract, nicio referință |
| „POL Genesis Pool" | **Nu există.** Există `POLVesting.sol`, care e altceva: eliberare graduală cu cliff |
| „Split 33/33/34" | Confirmat: `COTA_ARDERE = 33`, `COTA_TREZORERIE = 33`, `COTA_VALIDATORI = 34`, cu restul din împărțire la validatori |
| Guvernanță DAO | Există, dar **blocată permanent la 4 parametri** (vezi §2.6) |

**Implicație juridică directă:** `README.md` afirmă corect că „Whitepaper-ul trebuie actualizat să corespundă codului". Această propoziție este, din perspectivă juridică, cea mai valoroasă din tot repository-ul. Sub MiCA art. 6 alin. (1) lit. (b)-(c) și art. 15, informația din white paper trebuie să fie corectă, clară și neînșelătoare, iar ofertantul răspunde civil pentru prejudiciul cauzat de informații incorecte. În dreptul român, aceeași faptă, dacă a determinat achiziții, se poate încadra la art. 244 C.pen. (înșelăciune), unde inducerea în eroare prin prezentarea ca adevărată a unei fapte mincinoase, în scopul obținerii unui folos patrimonial injust, se pedepsește cu închisoare de la 6 luni la 3 ani, iar în varianta cu mijloace frauduloase, de la 1 la 5 ani.

## 0.4. Trei constatări de cod cu greutate juridică maximă

Acestea nu apar în `ABATERI.md` și nu au fost identificate în mandatul primit. Sunt rezultatul citirii liniare a contractelor.

### (A) Demurrage-ul este trivial evitabil — deci discriminatoriu de facto

În `MonedaOamenilor._update()`, decontarea se face pentru expeditor (`_deconteaza(de_la)`), care setează `ultimaActivitate[cont] = block.timestamp`. Taxa de tranzacție se aplică doar dacă `suma >= pragMicroTx` (1 token). Destinatarul nu își resetează ceasul decât la prima primire.

Consecință: **orice utilizator care își trimite sieși 0,9 tokeni o dată la 29 de zile nu plătește niciodată demurrage.** Cost: gas-ul de pe un L2, adică fracțiuni de cent. Nu există `require` care să blocheze auto-transferul, iar suma fiind sub `pragMicroTx`, nici taxa de 0.5% nu se aplică.

Efectul real al mecanismului nu este „descurajarea tezaurizării". Este un transfer de valoare **dinspre utilizatorii care nu știu acest lucru, către cei care îl știu** — plus către trezorerie și validatori. Într-un litigiu ANPC sau într-un dosar penal, acesta este exact tipul de asimetrie informațională care transformă un „model economic" în „practică comercială înșelătoare" (Legea 363/2007, art. 6-8) și, dacă se demonstrează intenția, în inducere în eroare.

Un white paper care afirmă că „deținătorii inactivi plătesc demurrage" ar fi, la litera lui, fals: deținătorii *neinformați* plătesc demurrage.

### (B) Plafoanele „dure" nu plafonează ce cred că plafonează

`README.md` și comentariile din cod prezintă `MAX_RATE_BPS = 1000` ca garanție că „un vot nu trebuie să poată confisca solduri". Însă:

```solidity
function setPraguri(uint256 prag1, uint256 prag2) external onlyRole(GUVERNANTA) {
    if (prag1 >= prag2) revert PraguriInversate();
    pragTransa1 = prag1;
    pragTransa2 = prag2;
}
```

Nu există limită inferioară. Guvernanța poate seta `pragTransa1 = 1 second`, `pragTransa2 = 2 seconds`. Combinat cu `setRate(1000, 1000)`, rezultă **10% pe 30 de zile aplicat de la o secundă de inactivitate**, adică ~71,8% erodare anuală, asupra tuturor deținătorilor, inclusiv retroactiv asupra intervalului de inactivitate deja scurs la momentul votului.

Mai mult, `setPraguri` **nu are plafon** în lista albă a DAO-ului — dimpotrivă, este unul dintre cei 4 selectori whitelisted în `Deploy.s.sol`. Deci este exact vectorul lăsat deschis.

Juridic: afirmația „un vot nu poate confisca solduri" este falsă. Dacă apare în white paper, este informație incorectă în sensul MiCA art. 6. Iar clauza contractuală care permite modificarea unilaterală a caracteristicii economice esențiale a produsului, fără preaviz și fără drept de retragere, este prezumat abuzivă sub Legea 193/2000, Anexa 1 lit. a) și lit. g).

### (C) Fondatorul rămâne administrator perpetuu al `POLVesting`

`Deploy.s.sol`:
```solidity
vesting = new POLVesting(address(token), deployer, trezorerie);
```
`administrator_` = `deployer`. Etapa 5 („PREDAREA ROLURILOR") predă `GUVERNANTA` și `DEFAULT_ADMIN_ROLE` pentru `token`, `vault` și `breaker`. **`POLVesting` nu apare deloc.** Funcția `_verifica()` nu îl testează. `POLVesting` nu are funcție de transfer al calității de administrator.

Rezultat: fondatorul poate, oricând și unilateral, să creeze grafice de vesting noi și să revoce grafice existente — perpetuu, fără vot, fără timelock.

Iar `_raport()` afișează pe consolă, la finalul deploy-ului:
```
Roluri predate catre DAO. Deployer-ul nu mai are putere.
```

Aceasta este o **afirmație factual falsă produsă de propriul cod al proiectului**. Consecințele se propagă în trei direcții simultan:
- **MiCA:** distruge argumentul de descentralizare care ar putea scoate protocolul din sfera serviciilor CASP (considerentul 22);
- **Howey / SEC:** confirmă „efforts of others" — fondatorul păstrează control managerial asupra distribuției;
- **ANAF:** confirmă control efectiv asupra unui activ generator de venit, cu consecințe de rezidență fiscală și impozitare (§4).

---

# 1. CLASIFICARE TOKEN ȘI CONFORMITATE UE

## 1.1. Clasificarea sub MiCA (Regulamentul UE 2023/1114)

MiCA cunoaște trei categorii, iar clasificarea este determinată de mecanism, nu de denumire.

**Nu este EMT (Electronic Money Token).** Un EMT urmărește să mențină o valoare stabilă prin referire la valoarea unei singure monede oficiale și conferă deținătorului drept de răscumpărare la valoare nominală, oricând, de la emitent (art. 3 alin. (1) pct. 7, art. 49). `MonedaOamenilor.sol` nu are peg, nu are rezervă în fiat, nu are funcție de răscumpărare. Nu intră.

**Nu este ART (Asset-Referenced Token).** Un ART urmărește stabilitatea prin referire la o altă valoare, la un coș de active sau la o combinație (art. 3 alin. (1) pct. 6). Nu există niciun mecanism de referențiere. **Atenție însă:** `StabilityFund`, mecanismul decis a nu fi implementat, ar fi împins tokenul periculos de aproape de ART — un fond care intervine pe piață pentru a susține prețul *este* un mecanism de stabilizare. Decizia din `ABATERI.md` de a nu-l implementa este, din perspectivă juridică, cea mai bună decizie luată în tot proiectul, și motivarea („intră direct peste prevederile de abuz de piață din MiCA, Titlul VI") este corectă. Nu reveni asupra ei.

**Este „alt criptoactiv" (Titlul II MiCA).** Categoria reziduală: criptoactiv care nu este nici ART, nici EMT. Aceasta este clasificarea corectă și, paradoxal, cea mai ușoară — obligațiile Titlului II sunt semnificativ mai reduse decât ale Titlurilor III-IV.

**Test suplimentar obligatoriu — nu cumva este instrument financiar?** Dacă tokenul ar fi calificat drept instrument financiar în sensul MiFID II, MiCA nu s-ar aplica (art. 2 alin. (4) lit. (a)), dar s-ar aplica regimul mult mai greu al Legii 126/2018 și al Regulamentului Prospect (UE) 2017/1129. Poziția în `SavingsVault` — sumă blocată pe termen determinat, cu randament predeterminat, transferabilă? (nu este: pozițiile sunt în `mapping(address => Pozitie[])`, netransferabile) — nu îndeplinește criteriul negociabilității pe piața de capital. **Concluzie: nu e valoare mobiliară în sens MiFID II, dar marja este mai mică decât pare.** Dacă vreodată pozițiile din Vault devin tokenizate/transferabile (un „vault receipt token"), tokenul respectiv devine aproape sigur instrument financiar. Nu face asta.

## 1.2. Obligațiile Titlului II — ce trebuie făcut înainte de lansare

| Obligație | Temei | Detaliu operațional |
|---|---|---|
| Ofertantul să fie **persoană juridică** | art. 4 alin. (1) lit. (a) | **Blocant absolut.** Vezi §1.3 |
| White paper întocmit conform Anexei I | art. 6 | Conținut minim: ofertant, proiect, ofertă, criptoactiv, drepturi/obligații, tehnologie, riscuri, impact climatic |
| **Notificare** la autoritatea competentă | art. 8 | Cu cel puțin 20 de zile lucrătoare înainte de publicare. Nu e aprobare — e notificare, dar autoritatea poate suspenda/interzice |
| Publicare pe site | art. 9 | Înainte de începerea ofertei sau a admiterii la tranzacționare |
| Comunicări de marketing conforme | art. 7 | Identificabile ca atare, corecte, clare, neînșelătoare, **consistente cu white paper-ul**. Include Twitter/X, Discord, Telegram |
| Drept de retragere 14 zile | art. 13 | Pentru deținătorii de retail care achiziționează **direct de la ofertant**. Nu poate fi exclus contractual. Nu se aplică dacă tokenul e deja admis la tranzacționare |
| Conduită onestă, gestiunea conflictelor de interese, custodie sigură a fondurilor colectate | art. 14 | Fondurile colectate în ofertă trebuie păstrate separat |
| Răspundere civilă pentru white paper | art. 15 | Ofertantul **și membrii organului său de conducere** răspund pentru prejudiciu. Sarcina probei este favorabilă investitorului |
| Titlul VI — abuz de piață | art. 86-92 | Se aplică din momentul admiterii la tranzacționare. Include interdicția tranzacționării pe baza informațiilor privilegiate și a manipulării pieței |

**Exceptări de la white paper (art. 4 alin. (2)) — analizează-le, dar nu te baza pe ele:**
- ofertă către mai puțin de 150 de persoane pe stat membru;
- contravaloare totală sub 1.000.000 EUR pe 12 luni;
- exclusiv către investitori calificați;
- oferit gratuit.

Ultima este cea la care fondatorii se agață și cea în care cad. Art. 4 alin. (3) precizează că un criptoactiv **nu** este considerat oferit gratuit atunci când achizitorii trebuie să furnizeze date cu caracter personal sau când ofertantul primește onorarii, comisioane sau beneficii monetare/nemonetare în schimb. **Un airdrop condiționat de KYC, de conectarea unui cont social, sau de orice formă de „social mining" NU este gratuit în sensul MiCA.** Iar în cazul de față, taxa de tranzacție de 0.5% și demurrage-ul direcționate către trezorerie sunt tocmai beneficii monetare primite de protocol de la deținători.

## 1.3. Blocantul absolut: art. 4 alin. (1) lit. (a) și situația din România

Două constrângeri se suprapun și trebuie citite împreună.

**Prima:** ofertantul trebuie să fie persoană juridică. Fondatorul persoană fizică nu poate emite legal. Iar configurația actuală de deploy îl face ofertant *de facto și dovedibil*: `MonedaOamenilor` primește rolul `EMITENT` pe adresa deployer-ului; `_raport()` notează explicit că „emisiunea inițială: nimeni nu mai are EMITENT în afara DAO", ceea ce înseamnă că mint-ul total se face **înainte** de predarea rolurilor, adică de către persoana fizică. Blockchain-ul păstrează asta permanent, cu semnătură criptografică, timestamp și trasabilitate către adresa care a plătit gas-ul. Nu există versiune a acestei povești în care fondatorul spune „nu am fost eu emitentul".

**A doua:** dacă ofertantul e persoană juridică *română*, statul membru de origine este România, iar notificarea white paper-ului se face la autoritatea competentă din România. Care nu există. <cite index="19-1">ASF a confirmat că nu a primit și nu a soluționat cereri de autorizare în temeiul MiCA, întrucât nu este desemnată în prezent autoritate competentă</cite>. Contextul general: <cite index="10-1">OUG nr. 10/2025 a fost prezentată public drept act de implementare, iar 1 iulie 2026 a fost consfințită ca dată la care încetează regimul tranzitoriu pentru furnizorii de servicii cripto</cite> — dar <cite index="15-1">analiza tehnică a acelei ordonanțe arată că ea a modificat, în realitate, Legea nr. 129/2019 pentru alinierea la Regulamentele TFR și MiCA și a abrogat art. 30¹, eliminând complet vechea cerință națională de autorizare</cite>, fără a rezolva desemnarea autorității competente conform art. 93 MiCA.

Rezultatul e o capcană perfectă: vechiul regim de înregistrare a fost desființat, noul regim nu poate fi accesat, iar perioada tranzitorie a expirat.

**Consecință strategică, fără ocolișuri:** entitatea emitentă **trebuie** constituită într-un stat membru UE cu autoritate competentă funcțională și cu practică MiCA reală. Nu este optimizare — este singura cale de conformare. Recomandări, în ordinea preferinței pentru acest profil de proiect:

1. **Lituania** — Bank of Lithuania, cel mai mare volum de autorizări CASP din UE, proces documentat, costuri rezonabile, personal vorbitor de engleză, substanță economică realizabilă cu 2-3 persoane;
2. **Irlanda** — Central Bank of Ireland, reputațional cel mai solid, dar exigent și lent;
3. **Malta** — MFSA, experiență din regimul VFA pre-MiCA, dar cu un cost reputațional în relația cu băncile;
4. **Liechtenstein** (SEE, TVTG) — cel mai bun cadru tehnic pentru token-based economies, dar cost ridicat și acces bancar dificil pentru proiecte early-stage.

**Elveția: recomandare nuanțată.** Este excelentă pentru o *fundație* (Stiftung) care deține IP-ul și trezoreria, cu practică FINMA matură pe clasificarea token-urilor. Dar Elveția **nu este în UE**, deci o fundație elvețiană nu poate notifica un white paper MiCA și nu poate obține pașaportarea. Dacă intenționezi să oferi tokenul în UE — și îl vei oferi, pentru că utilizatorii tăi sunt aici — ai nevoie de o entitate UE. Structura funcțională e hibridă: fundație elvețiană (IP, trezorerie, guvernanță) + entitate operațională UE (ofertant MiCA) + SRL RO (servicii de dezvoltare).

**Panama: nu.** Nu pentru că ar fi ilegal, ci pentru că este operațional letal. O entitate panameză în structură înseamnă că nicio bancă românească și aproape nicio bancă europeană nu va deschide sau menține contul SRL-ului. Vezi §2.7.

## 1.4. Testul Howey și expunerea față de SEC

Chiar dacă nu vizezi piața americană, analiza contează: (i) SEC afirmă jurisdicție asupra ofertelor accesibile din SUA, indiferent de locul emitentului; (ii) calificarea drept „security" în SUA are efect de contaminare reputațională și bancară globală; (iii) raționamentul Howey influențează tot mai mult analiza europeană a graniței MiCA/MiFID.

Cele patru elemente, aplicate la `SavingsVault`:

| Element Howey | Aplicare la Vault | Verdict |
|---|---|---|
| **Investment of money** | `token.safeTransferFrom(msg.sender, address(this), suma)` — utilizatorul transferă valoare economică în custodia contractului | ✅ Îndeplinit. „Money" include criptoactive (SEC v. Shavers) |
| **Common enterprise** | Toate depunerile intră într-un pool comun; `rezervaDisponibila()` se calculează pe soldul agregat al contractului; soarta unui deponent depinde de suficiența rezervei comune | ✅ Îndeplinit. Horizontal commonality clasică |
| **Expectation of profit** | `apyBps = 200` — randament de 2% predeterminat, calculat și rezervat la depunere. Nu e speculativ, e *promis* | ✅ Îndeplinit, în forma cea mai puternică posibilă |
| **From the efforts of others** | Rezerva e alimentată prin `alimenteazaRezerva()` din trezorerie; trezoreria e alimentată din demurrage și taxe colectate de la alți utilizatori; APY-ul e setat de guvernanță | ✅ Îndeplinit |

**Concluzie: `SavingsVault` este, în forma actuală, un investment contract sub testul Howey. Cu marjă confortabilă, nu la limită.**

Tokenul de bază, luat separat, are o poziție mai bună — nu promite randament, iar demurrage-ul îl face un activ care *pierde* valoare pasiv, ceea ce argumentează împotriva „expectation of profit". Ironic, mecanismul cel mai riscant sub dreptul consumatorului este cel mai protector sub Howey.

**Nuanță esențială despre staking și distribuția din trezorerie.** Cota de 34% direcționată către adresa `staking` este descrisă drept „validatori". Dacă acei „validatori" sunt entități care furnizează un serviciu real (operare de infrastructură), plata lor este remunerație pentru serviciu. Dacă însă sunt pur și simplu deținători care blochează tokeni și primesc o cotă din prelevări, atunci ai un al doilea investment contract, iar poziția devine indefensabilă. **Codul nu spune care dintre cele două este** — adresa `staking` e un simplu `address` configurabil. Definește-o juridic înainte să o definești tehnic.

**Măsuri minime de mitigare a expunerii SUA:**
- geo-blocare IP a jurisdicției SUA la nivel de front-end, cu log-uri păstrate;
- clauză de reprezentare în ToS: utilizatorul declară că nu e US Person în sensul Regulation S;
- interdicție expresă de participare pentru US Persons, aplicată și la nivelul airdrop-urilor;
- fără marketing, fără prezență la conferințe US, fără listare pe exchange-uri cu utilizatori US;
- screening OFAC pe adresele care interacționează cu contractele controlate.

Aceste măsuri nu garantează nimic (vezi cazurile LBRY, Library Credits), dar transformă un dosar de „ofertă neînregistrată" într-unul mult mai greu de construit.

## 1.5. Natura DAO și răspunderea personală a fondatorului

`QuadraticDAO.sol` nu are personalitate juridică. Din perspectiva dreptului român, un grup de persoane care contribuie cu bunuri (tokenii mizați) și desfășoară o activitate comună în scopul obținerii unui beneficiu, fără a se înregistra, riscă calificarea drept **societate simplă** (art. 1881 și urm. Cod civil) sau **asociere în participație** (art. 1949-1954 Cod civil).

Textul cu adevărat periculos este **art. 1889 alin. (4) Cod civil**: dacă o societate fără personalitate juridică este prezentată terților ca având personalitate, cei care au lucrat în numele ei răspund **solidar și nelimitat**. Un DAO care apare public sub o denumire, cu un site, cu o trezorerie și cu comunicări la persoana întâi plural („noi construim", „protocolul nostru") face exact această prezentare.

Consecințe concrete pentru fondator, ca persoană fizică rezidentă în România:
- **Răspundere patrimonială nelimitată** — bunuri personale, imobile, conturi, autovehicule;
- **Calitatea de administrator de fapt** — cine deține cheia de gardian, cine păstrează `POLVesting`, cine operează front-end-ul, acela administrează, indiferent ce spune documentația;
- **Competența instanțelor române** — utilizatorul român consumator poate acționa la propriul domiciliu (art. 18 Regulamentul Bruxelles I bis); nicio clauză de jurisdicție elvețiană nu îl împiedică;
- **Solidaritate cu ceilalți contribuitori** — dacă un co-fondator sau un membru activ produce un prejudiciu, creditorul se poate îndrepta integral împotriva ta.

**Soluția de structurare:**
1. **Wrapper cu personalitate juridică pentru DAO.** Opțiuni utilizabile: fundație de interes privat elvețiană (Stiftung), asociație elvețiană (Verein — folosit de Ethereum Foundation, Cardano, Aave), Cayman Foundation Company (dominant în practică, dar cu penalizare bancară în relația cu România), sau Marshall Islands DAO LLC (recunoaște formal DAO-ul ca entitate; excelent conceptual, dezastruos bancar).
   **Recomandare pentru acest profil: Verein elvețian.** Cost de constituire redus, fără capital minim, recunoaștere internațională, acceptabil pentru bănci, iar membrii nu răspund personal pentru obligațiile asociației (art. 75a Codul civil elvețian — răspunderea e limitată la patrimoniul asociației).
2. **Separarea strictă a rolurilor.** Fondatorul nu trebuie să fie simultan: emitent, gardian, administrator `POLVesting`, operator front-end, beneficiar al trezoreriei și prestator de servicii prin SRL. Fiecare cumul suplimentar adaugă un argument procurorului.
3. **Gardianul trebuie să fie multisig cu semnatari independenți**, nu cheia de deploy. `Deploy.s.sol` permite implicit `gardian = deployer` prin `vm.envOr("GARDIAN", deployer)`. Elimină acest fallback — transformă-l în `vm.envUint` care dă revert dacă variabila lipsește. Un default periculos ajunge în producție cu o probabilitate care nu merită discutată.
4. **Documentează predarea.** Hotărâre a organului de conducere al fundației, publicată, cu adresele on-chain, data și hash-urile tranzacțiilor de renunțare la roluri. Într-un litigiu, „am renunțat la control" trebuie să fie o probă, nu o afirmație.

---

# 2. RISCURI PENALE ȘI BANCARE SPECIFICE ÎN ROMÂNIA

## 2.1. `SavingsVault` versus atragerea neautorizată de depozite — analiza tehnică

Aceasta este întrebarea centrală a mandatului și merită un răspuns precis, nu unul alarmist.

**Textul aplicabil.** Art. 5 alin. (1) din OUG nr. 99/2006 interzice oricărei persoane fizice, juridice sau entități fără personalitate juridică ce nu este instituție de credit să se angajeze într-o activitate de atragere de depozite sau de alte fonduri rambursabile de la public. Art. 5 alin. (6) definește „publicul" ca orice persoană care nu are cunoștințele și experiența necesare pentru evaluarea riscului de nerambursare a plasamentelor efectuate — o definiție care acoperă exact utilizatorul retail al unei aplicații cripto. Încălcarea art. 5 constituie infracțiune, sancționată de art. 410 din aceeași ordonanță. **[VERIFICARE OBLIGATORIE: limitele de pedeapsă din art. 410 pe forma consolidată la zi — reținerea mea este închisoare de la 2 la 7 ani, dar cifra trebuie confirmată pe textul actual înainte de a fi folosită într-o notă de risc semnată.]**

**Elementul care decide: ce înseamnă „fonduri".** În sensul OUG 99/2006 și al Directivei CRD, „fonduri" înseamnă bancnote, monede, monedă scripturală și monedă electronică. Un token care nu este EMT, nu este monedă electronică și nu este exprimat în unități monetare oficiale **nu este, la litera textului, „fonduri"**.

Prin urmare, un vault în care intră tokeni și ies tokeni, fără nicio interacțiune cu moneda fiat, **nu întrunește, în opinia mea, elementul material al infracțiunii prevăzute de art. 5 coroborat cu art. 410**.

Acesta este răspunsul tehnic corect. Acum, răspunsul practic.

## 2.2. De ce răspunsul tehnic corect nu te protejează

Cinci factori transformă o poziție juridică apărabilă într-un dosar penal real.

**(1) Numele proiectului.** „Moneda Oamenilor". Simbol: „MO". Denumirea contractului: `MonedaOamenilor.sol`. Nu poți susține simultan că activul nu este „fonduri" pentru că nu e monedă, și că se numește „Moneda Oamenilor" pentru că este o monedă. Un procuror nu are nevoie de expertiză în Solidity pentru a face această observație, iar primul lucru pe care îl citește un judecător este numele.

Adăugat: **art. 16 din Legea nr. 312/2004 privind Statutul BNR** stabilește leul ca singurul mijloc legal de plată pe teritoriul României. Denumirea de „monedă" pentru un instrument privat, folosită într-o aplicație destinată plăților la comercianți, atrage atenția BNR pe un al doilea palier, independent de OUG 99/2006.

**(2) Vocabularul mecanismului.** `SavingsVault`, „Savings", „depune", „retrage", „scadență", „randament", „APY", „penalizare la retragere anticipată". Acesta este, cuvânt cu cuvânt, vocabularul depozitului bancar la termen. Un contract care se numește „Seif de Economii", în care „depui" bani pe „3, 6 sau 12 luni", primești „randament" la „scadență" și plătești „penalizare" dacă „retragi anticipat" **este descrierea unui depozit la termen**, indiferent de ce spune codul.

**(3) Momentul on-ramp-ului fiat.** Dacă utilizatorul, în orice punct al parcursului din aplicație, plătește RON sau EUR și primește o poziție în Vault — chiar dacă între cele două există o conversie automată în token — atunci fondurile *sunt* fonduri, iar analiza de la §2.1 se prăbușește instantaneu. Aceasta este linia roșie tehnică cea mai importantă din tot raportul: **niciun flux fiat nu trebuie să atingă vreodată mecanismul de blocare, nici direct, nici prin conversie automată în același flux de utilizator.**

**(4) Promisiunea de rambursare a principalului.** `retrage()` returnează `principal + randamentRezervat`. Aceasta este o promisiune de restituire integrală a sumei plus un plus. Caracterul „rambursabil" este esența noțiunii de „alte fonduri rambursabile". Chiar dacă activul nu e „fonduri", structura este identică — iar în drept, structurile identice atrag analogii, iar analogiile atrag rechizitorii.

**(5) Sursa randamentului.** Aceasta e cea mai gravă. Randamentul provine dintr-o rezervă alimentată din trezorerie, iar trezoreria e alimentată cu 33% din fiecare prelevare de demurrage și din fiecare taxă de tranzacție plătită de *alți* deținători. Deci: **deținătorii inactivi și cei care tranzacționează finanțează randamentul garantat al deponenților.** Descris astfel — și așa va fi descris de un expert desemnat de instanță — mecanismul este o redistribuire de la participanții neinformați către cei informați, cu randament garantat. Nu e un Ponzi în sens tehnic (nu depinde de aporturi *noi* pentru a plăti obligații vechi, iar `depune()` refuză depunerea dacă rezerva nu acoperă randamentul — o decizie de design excelentă). Dar este suficient de aproape încât distincția să fie făcută de un expert judiciar, după doi ani de proces, cu conturile tale deja sechestrate.

**Verdict pe secțiune: riscul penal de încadrare la art. 5 + art. 410 OUG 99/2006 este MEDIU-SPRE-RIDICAT ca probabilitate de începere a urmăririi penale, și SCĂZUT-SPRE-MEDIU ca probabilitate de condamnare.** Distincția nu te consolează: începerea urmăririi penale înseamnă percheziție informatică, ridicarea hardware wallet-urilor, sechestru asigurător pe conturi și cripto (art. 249-254 Cod procedură penală), închiderea conturilor bancare în 48 de ore de la aflarea de către bancă, și 2-4 ani de viață consumați. Riscul care contează nu e condamnarea. E dosarul.**

## 2.3. Reconstrucția juridică a mecanismului: de la „Vault" la „Time-Lock non-custodial"

Aici e partea în care redenumirea *nu* este suficientă, și e important să înțelegi de ce.

**Problema de fond: contractul actual ESTE custodial.** `token.safeTransferFrom(msg.sender, address(this), suma)` mută tokenii din contul utilizatorului în contul contractului. Din acel moment, `balanceOf(utilizator)` nu îi mai conține. Utilizatorul are o creanță — o intrare în `mapping(address => Pozitie[])` — nu un activ. Dacă găsești un bug, el pierde tokenii. Dacă guvernanța schimbă ceva, el depinde de guvernanță. Aceasta este, în sens juridic și în sens MiCA, **custodie și administrare de criptoactive în numele clienților** — un serviciu CASP (art. 3 alin. (1) pct. 16 lit. (a) și art. 59), pentru care ai nevoie de autorizație pe care în România nu o poți obține.

A redenumi un contract custodial în „non-custodial time-lock" nu îl face non-custodial. Îl face un contract custodial cu o denumire înșelătoare — adică adaugă o problemă în loc să rezolve una.

**Soluția reală: rescrie mecanismul ca blocare in-place.**

```
Arhitectura corectă (schematic):

MonedaOamenilor.sol:
  mapping(address => uint64) public blocatPanaLa;

  function blocheaza(uint64 pana) external {
      require(pana > blocatPanaLa[msg.sender]);   // doar prelungire
      require(pana <= block.timestamp + 365 days); // plafon
      blocatPanaLa[msg.sender] = pana;
      // efect: scutire de demurrage cât timp e blocat
  }

  // în _update():
  if (de_la != address(0) && block.timestamp < blocatPanaLa[de_la]) {
      revert SoldBlocat();
  }
```

Diferențele juridice, fiecare decisivă:

| Aspect | Vault actual (custodial) | Time-lock in-place |
|---|---|---|
| Cine deține tokenii | Contractul `SavingsVault` | Utilizatorul, în propriul cont |
| `balanceOf(utilizator)` | Nu conține suma | Conține suma, permanent |
| Natura juridică | Creanță împotriva unui terț | Proprietate cu restricție de dispoziție auto-impusă |
| Serviciu CASP de custodie | **Da** — expunere art. 59 MiCA | **Nu** — nimeni nu deține activele altcuiva |
| „Fonduri rambursabile" | Structural identic | Nu există restituire — nimic nu a plecat |
| Risc de furt prin bug | Pool comun, un bug golește tot | Fiecare cont e izolat |
| Howey — „investment of money" | Îndeplinit | Discutabil; nu există transfer de valoare către o entitate comună |

**A doua modificare, la fel de importantă: elimină randamentul garantat.** `apyBps = 200` este promisiunea care activează simultan Howey, analogia cu depozitul și expunerea de consumator. Variantele defensibile, în ordinea siguranței:

1. **Fără randament.** Beneficiul blocării este scutirea de demurrage. Atât. Aceasta e economic coerentă (blochezi ca să nu pierzi, nu ca să câștigi) și juridic aproape inatacabilă.
2. **Recompensă discreționară**, votată periodic de guvernanță, fără nicio promisiune prealabilă, fără rată afișată, fără calcul la momentul blocării. Riscant, dar apărabil.
3. **Randament garantat și prerezervat** (varianta actuală) — indefensabilă. Nu o păstra.

**A treia: elimină penalizarea de 10%.** `penalizareBps = 1000` transferă 10% din principalul utilizatorului către trezorerie în caz de ieșire anticipată. O clauză penală care transferă 10% din capitalul consumatorului către profesionist, pentru exercitarea unui drept de retragere, este prezumat abuzivă (Legea 193/2000, Anexa 1 lit. i) — obligarea consumatorului la despăgubiri disproporționat de mari) și intră în conflict direct cu dreptul de retragere de 14 zile din MiCA art. 13. Într-un time-lock in-place, problema dispare de la sine: nu există ieșire anticipată, pentru că blocarea e absolută până la termen. Ceea ce e, de altfel, mai onest.

## 2.4. Glosar terminologic obligatoriu

Această tabelă trebuie aplicată **simultan** în cod, în interfață, în white paper, în ToS și în comunicările publice. Inconsistența dintre paliere este ea însăși un risc: un contract numit corect și un tweet numit greșit produc același dosar.

| ❌ Termen interzis | ✅ Înlocuire | Motiv |
|---|---|---|
| Savings Vault / Seif / Economii | **Blocare voluntară pe termen** / *Voluntary Time-Lock* | Vocabular bancar → art. 5-6 OUG 99/2006 |
| Depozit / a depune / deponent | **Blocare** / a bloca / deținător cu sold blocat | „Depozit" e termen legal definit |
| Retragere / a retrage | **Deblocare** / expirarea blocării | Retragerea presupune că altcineva deținea |
| Randament / dobândă / APY | **(eliminat)** sau *recompensă de protocol, variabilă, negarantată* | Promisiunea de randament activează Howey |
| Scadență | **Data expirării blocării** | Vocabular de instrument de datorie |
| Penalizare la retragere anticipată | **(eliminat — blocarea e irevocabilă)** | Clauză penală abuzivă |
| **Moneda / Monedă / Currency** | **Token de utilitate** / *unitate de cont a protocolului* | Art. 16 Legea 312/2004 — leul e unicul mijloc legal de plată |
| Taxă (de inactivitate) | **Rată de demurrage** / *reducere programată a soldului* | „Taxa" e prelevare a statului; folosirea creează aparența unei prelevări publice |
| Trezorerie | **Fond operațional al protocolului** | „Trezorerie" evocă atribuții publice |
| Validatori | **Operatori de infrastructură** *(dacă prestează serviciu real)* | Dacă nu validează nimic, denumirea e înșelătoare |
| Bancă, bancar, banking, neobank | **(interzis absolut)** | Art. 6 OUG 99/2006 — interdicție expresă de utilizare a denumirii |
| Investiție / investitor / profit / ROI | **Utilizator / participant** | Vocabularul de investiție construie testul Howey în locul reclamantului |
| „Garantat", „sigur", „stabil" | **(interzis)** | Practică comercială înșelătoare (Legea 363/2007) |
| DAO „deține" / „decide" | **Deținătorii de token votează asupra parametrilor X, Y, Z** | Personificarea DAO-ului sugerează personalitate juridică → art. 1889 alin. (4) C.civ. |

## 2.5. Al doilea risc penal, subestimat: art. 244 Cod penal

Riscul de la art. 410 OUG 99/2006 este cel pe care îl anticipează toată lumea. Cel de la **art. 244 Cod penal (înșelăciunea)** este cel care produce condamnări, pentru că nu cere nicio calificare tehnică — doar o discrepanță între ce s-a promis și ce s-a livrat, plus un prejudiciu.

Elementele deja prezente în proiect, care ar construi acuzarea:

| Afirmație din proiect | Realitatea din cod |
|---|---|
| „Deployer-ul nu mai are putere" (`Deploy.s.sol`, `_raport()`) | Fondatorul rămâne administrator perpetuu al `POLVesting` |
| „Un vot nu trebuie să poată confisca solduri" (README) | `setPraguri` fără limită inferioară permite 10%/lună de la o secundă de inactivitate |
| „Guvernanță descentralizată" | Lista albă e blocată permanent la 4 selectori; DAO-ul nu se poate modifica (§2.6) |
| Demurrage prezentat ca aplicabil deținătorilor inactivi | Evitabil integral prin auto-transfer sub 1 token (§0.4.A) |
| „Session Keys ERC-4337" (dacă apare în materiale) | Nu există ERC-4337 în cod |
| „Social Mining", „POL Genesis Pool" (dacă apar) | Nu există în cod |

Fiecare linie din coloana stângă, dacă ajunge într-un material public și determină pe cineva să achiziționeze, este o cărămidă în latura obiectivă a infracțiunii. Cumulate, formează un tipar — iar tiparul e ceea ce transformă „eroare de comunicare" în „intenție".

**Remediere, în ordinea urgenței:**
1. Corectează `_raport()` — este cod care minte. Adaugă `POLVesting` în etapa 5 de predare și în `_verifica()`, sau transformă `administrator` într-o adresă de DAO de la constructor.
2. Adaugă limite inferioare la `setPraguri` (ex.: `require(prag1 >= 30 days)`).
3. Rezolvă evitabilitatea demurrage-ului sau **documentează-o explicit** ca proprietate cunoscută a sistemului. A doua variantă e legitimă și mult mai ieftină decât prima — dar tăcerea nu e o opțiune.
4. Instituie o regulă de proces: **niciun material public nu se publică fără verificare linie-cu-linie față de codul deployat la acel commit.** Păstrează dovada verificării.

## 2.6. Constatare suplimentară: guvernanța este permanent blocată

`QuadraticDAO.setPermis()` poate fi apelată **doar de contractul însuși**, printr-o propunere executată. Dar pentru ca o propunere care apelează `setPermis` să poată fi creată, perechea `(address(dao), setPermis.selector)` trebuie să fie deja în lista albă. `initializeazaPermisiuni()` este singura cale de a adăuga intrări inițiale, poate fi apelată doar de gardian și doar înainte de prima propunere — iar `Deploy.s.sol` o folosește pentru exact 4 selectori, toți pe contractul token:

```solidity
permise[0] = MonedaOamenilor.setRate.selector;
permise[1] = MonedaOamenilor.setTaxa.selector;
permise[2] = MonedaOamenilor.setPraguri.selector;
permise[3] = MonedaOamenilor.setScutit.selector;
```

`setPermis` nu e printre ele. Nici `setDestinatii`. Nici `SavingsVault.setApy` sau `setTrezorerie`. Nici `CircuitBreaker.setPraguri` sau `setDurate`. Nici `grantRole` pe vreun contract.

**Consecință: după deploy, guvernanța poate modifica exact patru parametri, pentru totdeauna. Nu poate adăuga niciodată alți parametri. Nu poate schimba APY-ul Vault-ului. Nu poate schimba pragurile Circuit Breaker-ului. Nu se poate autoextinde. Nu poate remedia nimic.**

Aceasta e o proprietate cu două fețe:
- **Juridic favorabilă:** absența unei entități capabile să modifice sistemul este cel mai puternic argument disponibil pentru descentralizare — sub MiCA (considerentul 22), sub Howey („efforts of others" slăbește dramatic) și sub analiza ANAF privind controlul.
- **Juridic periculoasă dacă e descrisă greșit:** orice material care sugerează o guvernanță adaptabilă, un roadmap de parametri sau capacitatea comunității de a evolua protocolul este fals.

**Recomandare:** păstrează blocajul — este un activ juridic — dar descrie-l onest și proeminent: *„Protocolul este imuabil, cu excepția a patru parametri. Nimeni, inclusiv fondatorii, nu poate modifica altceva, nu poate emite tokeni noi și nu poate accesa fondurile utilizatorilor."* Aceasta este o afirmație adevărată, verificabilă on-chain, și e cea mai bună apărare pe care o are proiectul.

## 2.7. Relația cu băncile comerciale din România

Aceasta este, statistic, problema care ucide cele mai multe proiecte cripto românești — înaintea oricărui procuror.

**Cadrul.** Legea nr. 129/2019, astfel cum a fost modificată prin OUG nr. 10/2025, impune băncilor măsuri de cunoaștere a clientelei și obligația de a refuza sau înceta relația de afaceri atunci când nu pot aplica măsurile de cunoaștere. Băncile au drept de reziliere unilaterală, cu preaviz scurt sau fără, în temeiul propriilor condiții generale. Practica de „de-risking" — refuzul preventiv al unor categorii întregi de clienți — este larg răspândită și, în lipsa unei obligații legale de a contracta, dificil de contestat.

**Ce declanșează, concret, închiderea contului:**
- încasări în cont personal de la exchange-uri (Binance, Kraken, Bybit) — cel mai frecvent factor;
- CAEN cripto declarat la Registrul Comerțului (6499, 6619) — unele bănci refuză la deschidere;
- plăți către/de la entități din Panama, Seychelles, BVI, Insulele Marshall;
- mențiunea „crypto", „token", „blockchain" în descrierea plăților;
- flux P2P — încasări multiple, de la persoane fizice diferite, cu sume similare;
- solicitare de la ONPCSB sau organ de urmărire penală;
- articol de presă negativ despre proiect (băncile fac monitorizare adverse media).

**Ce se întâmplă efectiv.** Nu primești un telefon. Primești o notificare de reziliere cu 15-30 de zile, fără motivare (băncile nu au obligația de a motiva, iar în cazul unui raport de tranzacție suspectă, art. 8 din Legea 129/2019 le *interzice* să te informeze — interdicția de „tipping-off"). Fondurile rămân blocate până la închidere. Deschiderea unui cont nou la altă bancă devine dificilă: refuzul precedent apare în procesul de onboarding.

În plus, ONPCSB poate dispune suspendarea unei tranzacții pentru 48 de ore, prelungibilă de procuror; iar în caz de dosar penal, sechestrul asigurător (art. 249 Cod procedură penală) blochează conturile pe durata procesului.

**Arhitectura bancară recomandată — trei niveluri, complet separate:**

**Nivelul 1 — Operațional România (SRL).** Bancă locală: BT sau BCR. CAEN principal **6201** (activități de realizare a soft-ului la comandă) sau **6209**, plus **7311** (publicitate) pentru marketing. **Fără CAEN cripto.** Contract de prestări servicii cu entitatea străină, facturi lunare, dovezi de livrare (rapoarte, commit log, timesheet-uri). Prin acest cont trec exclusiv: încasările pentru servicii software/marketing, salariile, chiria, furnizorii. **Zero cripto. Niciodată.**

**Nivelul 2 — Trezorerie corporativă (entitatea UE/CH).** Bancă în jurisdicția entității: Sygnum sau AMINA (Elveția), sau o instituție cu apetit cripto din Lituania. Aici se face conversia cripto→fiat, aici stau rezervele.

**Nivelul 3 — On-chain.** Multisig (Safe), cu semnatari distribuiți geografic și juridic. Nu se atinge de nivelurile 1 și 2 decât prin fluxuri documentate.

**Regula de aur:** niciun euro provenit direct dintr-o vânzare de cripto nu trebuie să ajungă în contul personal din România sau în contul SRL-ului. Traseul unic acceptabil este: cripto → conversie la nivelul 2 → factură de servicii → transfer bancar către SRL → salariu/dividend către persoana fizică. Fiecare săgeată are un document în spate.

**Comunicare proactivă.** Înainte de primul flux semnificativ, programează o discuție cu ofițerul de conformitate al băncii și prezintă: structura de grup, contractul de servicii, sursa fondurilor entității străine, licențele. Băncile penalizează surpriza, nu riscul. Un dosar pregătit dinainte schimbă complet dinamica.

---

# 3. PROTECȚIA CONSUMATORULUI ȘI DREPTUL DE PROPRIETATE

## 3.1. Este legală reducerea automată a soldului?

Răspunsul scurt: **da, dar numai dacă demurrage-ul este o caracteristică constitutivă a activului, nu o prelevare aplicată asupra unui activ preexistent.** Toată apărarea juridică depinde de această distincție, iar codul actual o subminează în două puncte.

**Argumentul care funcționează.** Art. 44 din Constituție, art. 555 Cod civil și art. 1 din Protocolul nr. 1 la CEDO protejează proprietatea împotriva ingerințelor. Dar un token cu demurrage nu produce o ingerință: utilizatorul dobândește, de la bun început, un activ ale cărui unități scad programat în absența activității. Nu i se ia nimic — a primit exact ceea ce activul este. Analogia corectă este cu un bilet care expiră, cu un abonament neutilizat sau cu o marfă perisabilă, nu cu o confiscare. Nimeni nu susține că un bilet de tren cu valabilitate limitată încalcă dreptul de proprietate.

Această apărare este solidă și, în opinia mea, ar rezista în instanță — **dacă și numai dacă** sunt îndeplinite cumulativ trei condiții:

1. **Informarea este precontractuală, proeminentă și cuantificată.** Nu îngropată la punctul 14.3 din ToS. Ecran dedicat, înainte de prima achiziție, cu simulare numerică: *„1.000 de tokeni neatinși timp de 12 luni devin 897."* Cifra concretă face diferența dintre „ai fost informat" și „ai fost informat formal".
2. **Regula nu se schimbă în defavoarea deținătorului după achiziție.** Aici codul actual eșuează (vezi §0.4.B).
3. **Aplicarea este neutră, automată și nediscriminatorie.** Aici codul actual eșuează din nou (`setScutit`).

## 3.2. Cele două puncte în care apărarea se rupe

**Punctul unu: parametrii sunt modificabili în defavoarea deținătorului, retroactiv.**

Guvernanța poate crește `rataTransa1` și `rataTransa2` până la 10% pe 30 de zile și poate reduce `pragTransa1` la o secundă. Modificarea produce efecte **imediat**, inclusiv asupra intervalului de inactivitate deja acumulat: `demurrageDatorat()` calculează pe baza `block.timestamp - ultimaActivitate[cont]`, folosind ratele **curente**, nu pe cele în vigoare la momentul acumulării. Un deținător inactiv de 89 de zile, care sub regulile de la achiziție ar fi datorat ~2% din sold, poate datora brusc ~29% dacă un vot schimbă pragurile.

Sub Legea nr. 193/2000, o clauză care dă profesionistului dreptul de a modifica unilateral caracteristicile esențiale ale produsului, fără un motiv întemeiat menționat în contract și fără dreptul consumatorului de a rezilia, este prezumat abuzivă (Anexa 1, lit. a) și lit. g)). Consecința juridică nu este o amendă — este că **clauza este considerată nescrisă**, iar consumatorul poate cere restituirea a tot ce i s-a prelevat în temeiul ei. ANPC poate introduce acțiune în încetare, iar hotărârea produce efecte asupra tuturor contractelor identice — nu doar față de reclamant.

*Remediere:*
```solidity
uint256 public constant MIN_PRAG_TRANSA1 = 30 days;
uint256 public constant PREAVIZ = 30 days;
mapping(bytes32 => uint256) public modificareProgramata; // hash param -> timestamp activare

// setPraguri devine: programează, nu aplică
// aplicarea se face după PREAVIZ, iar calculul demurrage
// folosește rata în vigoare la momentul acumulării, pe segmente
```
Costul e o refactorizare a `demurrageDatorat()` pe segmente istorice de rată. Este muncă reală. Este și diferența dintre un mecanism apărabil și unul care cade la primul proces.

**Punctul doi: `setScutit` permite tratament discriminatoriu.**

`setScutit(address, bool)` este în lista albă a DAO-ului. Guvernanța poate, printr-un vot, să scutească adrese individuale de demurrage. Deținătorii mari — inclusiv cei care controlează votul, prin însăși natura votului cuadratic ponderat prin miză — se pot scuti reciproc, în timp ce utilizatorii mici plătesc.

Combinat cu evitabilitatea tehnică de la §0.4.A, rezultatul este un mecanism care, în practică, **se aplică aproape exclusiv utilizatorilor mici și neinformați**. Aceasta nu mai e o problemă de clauze abuzive. E o problemă de practică comercială înșelătoare (art. 6-8 din Legea nr. 363/2007) și, potențial, de discriminare contractuală.

*Remediere:* restrânge `setScutit` la o listă de adrese de contract ale protocolului, verificabilă prin `code.length > 0`, și scoate-o din lista albă a guvernanței. Scutirile trebuie să fie structurale (Vault, DAO, vesting), nu discreționare.

## 3.3. Aplicabilitatea Legii 193/2000 — există un „profesionist"?

Legea 193/2000 se aplică raportului profesionist–consumator. Un protocol pur descentralizat, fără operator, teoretic nu generează un astfel de raport: relația e între utilizator și cod.

În practică, un „profesionist" există dacă: operezi front-end-ul; publici Terms of Service; ai un canal de suport; faci marketing; primești venituri (trezoreria); controlezi orice parametru. **Proiectul îndeplinește, în forma actuală, toate cele șase criterii.** Argumentul „nu suntem profesionist" nu este disponibil.

Regimuri aplicabile cumulativ:
- **Legea 193/2000** — clauze abuzive;
- **Legea 363/2007** — practici comerciale incorecte;
- **OUG 34/2014** — contracte la distanță, informare precontractuală;
- **MiCA art. 13** — drept de retragere 14 zile pentru achiziții directe de la ofertant, neexcludibil;
- **Regulamentul Bruxelles I bis art. 17-19** — consumatorul te poate acționa la domiciliul său, iar clauza de jurisdicție străină nu îl împiedică. Nicio structură offshore nu te scoate din fața Judecătoriei Piatra Neamț dacă reclamantul e din Piatra Neamț.

## 3.4. Clauzele contractuale necesare pentru acoperirea Demurrage-ului

Următoarele clauze sunt necesare, nu suficiente. Ele funcționează doar dacă modificările de cod din §3.2 sunt implementate — o clauză care descrie o protecție inexistentă în cod agravează situația în loc să o amelioreze.

**Clauza 1 — Definirea naturii activului (precontractuală, ecran separat, acceptare distinctă).**
> Tokenul MO este un activ digital cu ofertă descrescătoare prin design. Reducerea programată a soldurilor inactive (demurrage) nu constituie o taxă, o prelevare, o sancțiune sau o modificare a activului: este o caracteristică constitutivă și permanentă a acestuia, existentă anterior și independent de orice raport contractual dintre Utilizator și Operator. Prin achiziționare, Utilizatorul dobândește un activ care are, de la origine, această proprietate. Tokenul MO nu este monedă, nu este mijloc legal de plată, nu este monedă electronică, nu este depozit, nu este instrument financiar și nu conferă niciun drept de creanță împotriva Operatorului sau a vreunei alte persoane.

**Clauza 2 — Informare cuantificată și consimțământ informat.**
Bifă separată, nepresetată, precedată de o simulare numerică pe soldul real al utilizatorului, cu tabelul complet al ratelor și pragurilor. Logarea consimțământului cu timestamp, versiunea ToS și hash-ul parametrilor în vigoare. Reînnoirea consimțământului la fiecare modificare de parametri.

**Clauza 3 — Plafoane contractuale oglindă și interdicția retroactivității.**
> Ratele de demurrage nu pot depăși [X]% per 30 de zile, iar pragul de inactivitate nu poate coborî sub 30 de zile. Aceste limite sunt înscrise ca imutabile în contractele inteligente și nu pot fi modificate prin niciun mecanism, inclusiv prin vot de guvernanță. Orice modificare a parametrilor produce efecte exclusiv pentru viitor, asupra perioadelor de inactivitate care încep după data intrării ei în vigoare. Perioadele de inactivitate deja acumulate rămân guvernate de parametrii aplicabili la momentul acumulării.

**Clauza 4 — Preaviz și drept de ieșire.**
> Orice modificare a parametrilor în defavoarea deținătorilor intră în vigoare la cel puțin 30 de zile de la publicarea on-chain a hotărârii de guvernanță. În acest interval, Utilizatorul poate transfera, converti sau bloca soldul fără costuri suplimentare și fără aplicarea parametrilor modificați.

**Clauza 5 — Dreptul de retragere (MiCA art. 13).**
> Utilizatorul consumator care achiziționează tokeni direct de la Ofertant beneficiază de un drept de retragere de 14 zile calendaristice de la data achiziției, fără penalități și fără obligația de a motiva. Dreptul nu se aplică achizițiilor efectuate pe o platformă de tranzacționare.

**Clauza 6 — Limitarea răspunderii, calibrată corect.**
Atenție: **art. 1355 alin. (1) Cod civil sancționează cu nulitatea clauza care exclude răspunderea pentru prejudicii cauzate cu intenție sau din culpă gravă.** O clauză de tipul „Operatorul nu răspunde pentru nicio pierdere, indiferent de cauză" este nulă și, mai grav, semnalează instanței rea-credință. Formulare utilizabilă:
> Operatorul răspunde pentru prejudiciile cauzate cu intenție sau din culpă gravă. Răspunderea pentru prejudiciile cauzate din culpă ușoară este limitată la [sumă], cu excepția cazurilor în care legea nu permite limitarea. Operatorul nu răspunde pentru: fluctuațiile de valoare ale tokenului; pierderea cheilor private de către Utilizator; funcționarea rețelei blockchain subiacente; acțiunile terților asupra cărora nu are control.

**Clauza 7 — Circuit breaker.**
> Utilizatorul ia la cunoștință că protocolul include un mecanism automat de suspendare temporară a anumitor funcții, declanșat prin atestarea concordantă a minimum [3] operatori independenți de monitorizare. Durata maximă a unei suspendări este de [6] ore, iar expirarea este automată. În perioada de suspendare, [enumerare exactă a funcțiilor afectate și neafectate]. Operatorul nu garantează disponibilitatea neîntreruptă și nu răspunde pentru pierderi de oportunitate rezultate din suspendare, sub rezerva Clauzei 6.

**Clauza 8 — Excluderea jurisdicțiilor.**
Reprezentare și garanție a utilizatorului că nu este US Person în sensul Regulation S, nu se află pe liste de sancțiuni (OFAC, UE, ONU), nu accesează serviciul dintr-o jurisdicție interzisă. Geo-blocare efectivă, cu log-uri păstrate — declarația fără implementare tehnică nu valorează nimic în fața unei autorități.

**Clauza 9 — Identificarea operatorului.**
Contrar intuiției, **identifică-te clar.** Denumirea completă a entității, sediul, numărul de înregistrare, adresa de contact, autoritatea de supraveghere dacă există. Anonimatul nu protejează — atrage. Un proiect fără operator identificabil este, pentru ANPC și pentru un procuror, prezumtiv fraudulos; iar identificarea e oricum inevitabilă din analiza on-chain și din înregistrările de domeniu.

**Clauza 10 — Soluționarea litigiilor.**
Nu insera clauză compromisorie (arbitraj) în raporturile cu consumatorii: este prezumat abuzivă. Prevede o procedură internă de reclamații cu termen de răspuns și menționează dreptul consumatorului de a se adresa ANPC și instanțelor competente de la domiciliul său.

---

# 4. ARHITECTURA FISCALĂ ȘI STRUCTURAREA HIBRIDĂ (ANAF)

## 4.1. Structura recomandată — și ce anume o poate distruge

```
        ┌─────────────────────────────────────────┐
        │   FUNDAȚIE / VEREIN (Elveția, Zug)      │
        │   • deține IP, marcă, domenii            │
        │   • deține trezoreria protocolului       │
        │   • guvernanță, grant-uri                │
        │   • NU face ofertă publică în UE         │
        └───────────────┬─────────────────────────┘
                        │ finanțare / grant
                        ▼
        ┌─────────────────────────────────────────┐
        │   ENTITATE OPERAȚIONALĂ UE (Lituania)   │
        │   • OFERTANTUL în sens MiCA art. 4       │
        │   • notifică white paper-ul              │
        │   • operează front-end-ul, ToS           │
        │   • autorizare CASP dacă e cazul         │
        └───────────────┬─────────────────────────┘
                        │ contract de prestări servicii
                        │ (dezvoltare software + marketing B2B)
                        ▼
        ┌─────────────────────────────────────────┐
        │   SRL ROMÂNIA                            │
        │   • CAEN 6201 / 6209 / 7311              │
        │   • prestator de servicii, atât          │
        │   • fără tokeni, fără trezorerie         │
        │   • fără decizii de guvernanță           │
        └───────────────┬─────────────────────────┘
                        │ salariu + dividende
                        ▼
                 FONDATOR (PF, rezident RO)
```

Există un singur mod în care această structură funcționează și zece moduri în care se prăbușește. Toate cele zece se reduc la un principiu: **structura trebuie să reflecte realitatea, nu invers.**

## 4.2. Riscul numărul unu: rezidența fiscală a entității străine

**Art. 7 pct. 18 din Codul fiscal** definește persoana juridică română, printre altele, ca persoana juridică străină **care are locul de exercitare a conducerii efective în România**. Consecința calificării: entitatea străină devine contribuabil român pentru profitul mondial, cu impozit de 16%, plus obligații declarative retroactive, plus dobânzi și penalități, plus expunerea la art. 9 din Legea nr. 241/2005 (evaziune fiscală).

ANAF aplică un chestionar de rezidență fiscală și urmărește elemente factuale:
- unde se iau efectiv deciziile strategice;
- unde se află persoanele care le iau;
- de unde se semnează contractele și se aprobă plățile;
- unde se țin ședințele organului de conducere și unde se redactează procesele-verbale;
- de unde se accesează conturile bancare (adrese IP — băncile păstrează log-uri, iar ANAF le poate solicita);
- cine deține cheile private ale multisig-ului.

**Realitatea brutală:** dacă fondatorul stă în Piatra Neamț, semnează totul din Piatra Neamț, deține singurele chei relevante și e singurul care decide ceva, atunci fundația elvețiană **este** rezidentă fiscal în România, indiferent de ce scrie în actul constitutiv. Nicio structură nu supraviețuiește unei conduceri efective unipersonale exercitate dintr-un singur loc.

**Substanța economică minimă, non-negociabilă:**

| Element | Cerință |
|---|---|
| Organ de conducere | Minimum 2 membri, dintre care **cel puțin unul rezident în jurisdicția entității**, cu competențe reale și remunerație de piață |
| Ședințe | Trimestriale, ținute fizic în jurisdicție, cu procese-verbale semnate, dovezi de deplasare |
| Sediu | Birou real sau domiciliere profesională cu servicii efective; nu doar căsuță poștală |
| Conturi bancare | Deschise și operate din jurisdicție; ordine de plată semnate de directorul local |
| Decizii | Documentate ca hotărâri ale organului de conducere, nu ca instrucțiuni ale fondatorului |
| Contabilitate și audit | Locale, cu situații financiare depuse |
| Chei private | Multisig cu semnatari în jurisdicții diferite; fondatorul român **nu** trebuie să dețină singur puterea de semnare |

Costul realist al substanței: **25.000–60.000 EUR/an** pentru Elveția, 15.000–35.000 EUR/an pentru Lituania. Dacă bugetul nu suportă aceste cifre, structura hibridă **nu este viabilă** și trebuie renunțat la ea în favoarea unei structuri simple, integral românești, cu profil de risc diferit. O structură internațională fără substanță este mai periculoasă decât absența ei: adaugă acuzația de artificialitate peste toate celelalte.

## 4.3. Prețuri de transfer — SRL-ul român ca prestator

Fondatorul controlând ambele entități, acestea sunt **persoane afiliate** în sensul art. 7 pct. 26 din Codul fiscal. Consecințe:

- **Principiul valorii de piață** (art. 11 Cod fiscal): prețul serviciilor trebuie să fie cel dintre persoane independente. ANAF poate ajusta prețurile și recalcula impozitul.
- **Dosarul prețurilor de transfer**: obligatoriu peste pragurile stabilite prin Ordinul ANAF nr. 442/2016; sub praguri, se prezintă la cerere în cadrul unei inspecții. **[VERIFICARE: pragurile la zi.]** Recomandarea mea: întocmește-l oricum, chiar sub prag. Costă 3.000–6.000 EUR și transformă o inspecție ostilă într-una administrativă.
- **Metoda recomandată**: cost-plus. Pentru servicii de dezvoltare software cu valoare adăugată redusă, o marjă de **5–10% peste costurile totale** este apărabilă și aliniată cu practica OECD pentru servicii intragrup cu valoare adăugată scăzută.
- **Documentație suportivă obligatorie**: contract-cadru cu descrierea serviciilor, SOW-uri, facturi lunare, rapoarte de activitate, timesheet-uri, commit log-uri corelate cu orele facturate, corespondență. ANAF nu contestă cifra din factură — contestă **absența dovezii că serviciul a fost prestat**.

**Capcană nouă din 2026:** deducerea cheltuielilor cu servicii primite de la afiliați (proprietate intelectuală, management, consultanță) a fost <cite index="30-1">limitată la 1% din cheltuieli</cite>. Aceasta lovește în sens invers: dacă SRL-ul român ar plăti royalty sau management fee către fundație, deducerea ar fi plafonată drastic. **Concluzie: fluxul trebuie să fie unidirecțional — bani dinspre entitatea străină către SRL, niciodată invers.** Nu structura SRL-ul ca licențiat al mărcii.

## 4.4. Intrarea banilor în România — fluxul complet

**Pasul 1 — Contract.** Contract de prestări servicii între entitatea străină (beneficiar) și SRL (prestator). Obiect: dezvoltare software, mentenanță, marketing B2B. Preț: cost-plus, cu formulă explicită. Legea aplicabilă și instanța: alegerea nu contează fiscal, dar preferă legea română pentru simplitate.

**Pasul 2 — Facturare lunară.** Factura menționează: „servicii de dezvoltare software conform contractului nr. X". **Nu** menționează „crypto", „token", „blockchain" — nu din intenție de disimulare, ci pentru că descrierea corectă a serviciului prestat de SRL *este* dezvoltare software. Include mențiunea de taxare inversă / neimpozabil în România, cu temeiul legal.

**Pasul 3 — TVA.** Locul prestării serviciilor către o persoană impozabilă stabilită în afara României este la beneficiar (art. 278 alin. (2) Cod fiscal) → operațiunea nu este impozabilă în România. Obligații:
- dacă SRL-ul nu e plătitor de TVA, trebuie să obțină **cod special de TVA** (art. 317) înainte de prima prestare;
- pentru beneficiari din UE: declarația recapitulativă **D390**;
- pentru beneficiari din afara UE (Elveția): nu se depune D390;
- **[VERIFICARE OBLIGATORIE]** dacă fundația elvețiană **nu** desfășoară activitate economică și nu se califică drept persoană impozabilă, regula B2B nu se aplică. Pentru servicii prestate electronic și pentru publicitate către persoane neimpozabile stabilite în afara UE, art. 278 alin. (5) lit. h) plasează tot locul la beneficiar — deci rezultatul rămâne același. Dar acesta este exact genul de detaliu în care o inspecție găsește 21% TVA plus accesorii pe trei ani. Confirmă-l cu contabilul, în scris, înainte de prima factură.
- plafonul de scutire TVA: <cite index="27-1">395.000 lei, neschimbat în 2026</cite>; cota standard: 21%.

**Pasul 4 — Impozitare la nivelul SRL.**
- **Regim micro**: <cite index="28-1">de la 1 ianuarie 2026 a rămas o singură cotă de 1% pe veniturile microîntreprinderilor, iar plafonul a coborât la 100.000 EUR de la 250.000, salariatul cu normă întreagă fiind condiție de acces</cite>. <cite index="31-1">Plafonul se cumulează cu veniturile întreprinderilor legate, potrivit art. 47 alin. (1¹) din Codul fiscal</cite> — atenție dacă ai mai multe firme.
- **Peste plafon**: impozit pe profit 16%. <cite index="28-1">Punctul de echilibru între cele două regimuri se atinge la o marjă de 6,25%</cite>: peste ea, regimul micro e mai avantajos.
- Pentru un SRL de servicii cu marjă cost-plus de 5–10%, calculul e strâns. Fă-l pe cifre reale, nu pe intuiție.

**Pasul 5 — Scoaterea banilor către persoana fizică.**
- **Salariu**: deductibil la SRL, dar cu contribuții totale de ~41,5% plus 10% impozit. Necesar oricum pentru condiția de micro.
- **Dividende**: <cite index="27-1">impozit 16% din 2026, aplicabil oricărei distribuții făcute în 2026 indiferent din ce an provine profitul, reținut la sursă la momentul plății efective</cite> (Legea nr. 141/2025).
- **CASS**: 10% dacă veniturile cumulate din dividende, investiții, chirii și alte surse ating <cite index="29-1">plafonul de 6 salarii minime brute</cite>. <cite index="34-1">Pentru 2026, salariul de referință confirmat de ANAF este 4.050 lei</cite> → prag de 24.300 lei. Contribuția e datorată la o bază fixă raportată la plafon, nu la venitul integral.

**Pasul 6 — Dosarul de justificare, ținut permanent.** Contract, facturi, extrase, rapoarte de livrare, dosar de prețuri de transfer, certificat de rezidență fiscală al beneficiarului, dovezi de substanță ale entității străine. Acest dosar nu se construiește la primirea avizului de inspecție. Se construiește lunar, de la prima factură.

## 4.5. Tratamentul fiscal al split-ului 33/33/34

Fiecare din cele trei cote are un regim diferit, iar diferențele contează.

**33% ARS (`_burn`).** Tokenii sunt arși direct din soldul utilizatorului. Nimeni nu îi primește. **Nu există eveniment fiscal pentru emitent, protocol sau fondator** — nu poate exista venit acolo unde nu există încasare. Pentru utilizator, arderea reprezintă o pierdere care, tehnic, ar putea fi luată în calcul la determinarea câștigului la înstrăinarea ulterioară (cost de achiziție raportat la unități rămase). Codul fiscal nu reglementează expres ipoteza. Argumentul rezonabil: baza de cost totală rămâne neschimbată, distribuită pe mai puține unități. Documentează metoda și fii consecvent.

**33% TREZORERIE — punctul fiscal cel mai periculos din tot proiectul.**

Fiecare prelevare de demurrage și fiecare taxă de tranzacție trimit 33% către adresa `trezorerie`. Acesta este un **flux continuu de venit**, de la potențial mii de plătitori, 24/7.

Întrebarea decisivă: **cine controlează juridic acea adresă?**

| Titular al controlului | Consecință fiscală |
|---|---|
| SRL-ul român | Venit din exploatare, impozabil **la momentul încasării**, la cursul BNR al zilei. La regim micro: 1% pe fiecare intrare — inclusiv pe tokeni pe care nu i-ai vândut și pe care poate nu îi vei putea vinde. Catastrofal pentru cash-flow |
| Fondatorul, persoană fizică | Venit din alte surse sau din activități independente, impozabil la primire, plus CASS. Risc de recalificare ca activitate economică nedeclarată |
| Entitatea străină cu substanță reală | Venit al entității străine, impozitat în jurisdicția ei. Fără impact în România — **singura variantă viabilă** |
| Contract fără proprietar, cu guvernanță blocată | Cea mai bună poziție teoretică. Dar necesită ca nimeni să nu poată muta fondurile. Verifică: `setDestinatii` **nu** e în lista albă a DAO-ului, deci adresa trezoreriei e fixată permanent la deploy — o proprietate favorabilă, dacă adresa e ea însăși necontrolată |

**Recomandare fermă:** trezoreria trebuie să aparțină entității străine, cu multisig ai cărui semnatari nu sunt majoritar români, iar SRL-ul român nu trebuie să atingă niciodată acei tokeni. Dacă trezoreria finanțează dezvoltarea, o face prin **plata facturilor SRL-ului în fiat**, după conversie la nivelul entității străine.

**34% VALIDATORI — obligația de reținere la sursă, ratată de aproape toți.**

Dacă entitatea care distribuie este română și beneficiarii sunt persoane fizice române, apare obligația de **reținere a impozitului la sursă** pentru venituri din alte surse (art. 114-115 Cod fiscal), plus declarațiile D112 și D205, plus eventual CASS. Neîndeplinirea = obligație fiscală proprie a plătitorului, plus accesorii, plus contravenții.

Într-un sistem cu distribuție automată către mii de adrese pseudonime, această obligație este **imposibil de îndeplinit**. Nu știi cine sunt, nu știi unde sunt rezidenți, nu ai CNP-urile lor.

Soluție: distribuția trebuie să fie **automată, on-chain, fără intervenția vreunei entități române**, iar contractul de staking nu trebuie să fie controlat de o entitate română. Documentează faptul că protocolul distribuie, nu o persoană juridică. Aceasta este o altă situație în care descentralizarea reală nu e ideologie, ci necesitate fiscală.

## 4.6. Impozitarea tokenilor deținuți de fondator

Zona cu cea mai mare datorie fiscală ascunsă.

**Alocația de fondator prin `POLVesting`.** La fiecare eliberare (`elibereaza`), fondatorul intră în posesia unor tokeni cu valoare de piață. Tratamentul cel mai probabil: **venit impozabil la momentul dobândirii**, la valoarea de piață din acea zi, ca venit din alte surse (16% + eventual CASS). Ulterior, la înstrăinare, se impozitează câștigul, cu baza de cost egală cu valoarea deja impozitată.

Problema practică: dacă tokenul are preț de piață ridicat la vesting și se prăbușește înainte de vânzare, **datorezi impozit pe o valoare pe care nu ai realizat-o niciodată**. Este mecanismul care a falimentat mii de angajați din startup-uri americane după 2000. Se atenuează prin: eliberări eșalonate frecvent, vânzare imediată a unei fracțiuni pentru acoperirea impozitului, sau structurarea alocației ca drept condiționat care nu se dobândește decât la momentul vânzării.

**[VERIFICARE OBLIGATORIE]** Codul fiscal nu reglementează expres momentul impozitării tokenilor primiți gratuit. Aceasta este candidata perfectă pentru o **soluție fiscală individuală anticipată** (art. 52 Cod de procedură fiscală): obții de la ANAF o poziție obligatorie pentru administrația fiscală, valabilă pentru situația ta concretă. Costă o taxă și durează câteva luni. Merită fiecare zi de așteptare.

**Tranzacționarea personală.** <cite index="34-1">Pentru câștigurile din transferul de monedă virtuală obținute de la 1 ianuarie 2026, cota este 16%, calculată de contribuabil în Declarația unică; CASS de 10% este datorată dacă veniturile cumulate din categoriile relevante ating cel puțin șase salarii minime, iar CAS nu se datorează pentru acest tip de venit</cite>. <cite index="33-1">Se menține neimpozitarea câștigului sub 200 lei pe tranzacție, cu condiția ca totalul câștigurilor anuale să nu depășească 600 lei</cite>. Termen: <cite index="34-1">25 mai 2027 pentru câștigurile din 2026</cite>.

**Transparența totală, de care mulți nu au înțeles încă implicațiile.** <cite index="37-1">Guvernul a adoptat, la 5 decembrie 2025, ordonanța care obligă furnizorii de servicii de criptoactive să raporteze toate tranzacțiile utilizatorilor către ANAF, aliniind România la standardele CARF/DAC8</cite>. <cite index="5-1">Toate platformele active cu utilizatori români, indiferent de unde sunt licențiate, sunt obligate să raporteze anual tranzacțiile către ANAF</cite>.

Concret: ANAF primește automat, de la fiecare exchange, istoricul tău. Strategia „nu declar și sper" a încetat să existe în ianuarie 2026. Nedeclararea configurează art. 9 din Legea nr. 241/2005 privind evaziunea fiscală, cu pedeapsă de bază închisoare de la 2 la 8 ani, majorată în funcție de prejudiciu — dar cu cauze de reducere semnificativă a pedepsei în caz de acoperire integrală a prejudiciului.

## 4.7. TVA-ul tokenului: ambiguitatea care trebuie rezolvată în avans

Două regimuri posibile, cu rezultate opuse:

**Varianta A — mijloc de plată (CJUE, cauza C-264/14 Hedqvist).** Operațiunile de schimb între monedă tradițională și monedă virtuală folosită ca mijloc de plată sunt scutite de TVA, ca operațiuni privind devizele (transpus la art. 292 alin. (2) lit. a) pct. 3 Cod fiscal). Poziționarea „Moneda Oamenilor" ca instrument de plată la comercianți împinge spre această calificare.

**Varianta B — cupon valoric (Directiva 2016/1065, art. 274¹ Cod fiscal).** Dacă tokenul conferă dreptul de a primi bunuri sau servicii identificabile, poate fi un cupon cu utilizări multiple, cu TVA datorată la momentul răscumpărării. Poziționarea de „utility token" împinge spre această calificare.

Cele două se exclud, iar diferența poate fi de 21% din volum. **Nu lăsa ambiguitatea nerezolvată.** Fie clarifici poziționarea (mijloc general de plată, fără drepturi la bunuri/servicii determinate — recomandat), fie obții o soluție fiscală anticipată.

**Contabilitate.** Nu există în România un standard dedicat criptoactivelor. Aplicabile: Reglementările contabile OMFP nr. 1802/2014 și, prin analogie, poziția IFRS IC din 2019 (criptoactivele deținute sunt, de regulă, imobilizări necorporale, sau stocuri dacă sunt deținute pentru vânzare în cursul normal al activității). Stabilește o politică contabilă scrisă, aprobată, care să prevadă: metoda de determinare a costului (FIFO recomandat), sursa cursului de schimb (BNR pentru RON, sursa de piață pentru cripto/EUR), momentul recunoașterii veniturilor și tratamentul deprecierii. Consecvența contează mai mult decât alegerea.

---

# 5. AML/CFT, PROTECȚIA DATELOR ȘI RĂSPUNDEREA PENTRU AI

## 5.1. Proof-of-Personhood și biometria: recomandarea este să nu o implementezi

**Cadrul.** Art. 9 alin. (1) GDPR interzice prelucrarea datelor biometrice pentru identificarea unică a unei persoane. Singura excepție realist disponibilă unui proiect privat este consimțământul explicit, art. 9 alin. (2) lit. (a).

**De ce consimțământul nu funcționează aici.** Art. 7 alin. (4) GDPR prevede că, la evaluarea caracterului liber al consimțământului, se ține seama de măsura în care executarea contractului este condiționată de consimțământul pentru o prelucrare care nu este necesară executării. Dacă scanarea biometrică este **condiție de acces** la serviciu sau la airdrop, consimțământul nu este liber, deci nu este valabil, deci prelucrarea este ilegală din start. Este un cerc din care nu se iese prin redactare de politici de confidențialitate.

**Precedentele.** Autoritățile europene și non-europene au dispus, începând din 2023-2025, măsuri împotriva sistemelor de identitate bazate pe scanare a irisului — suspendări, ordine de ștergere și amenzi în Spania, Portugalia, Germania (Bavaria), Kenya și Hong Kong. **[VERIFICARE: stadiul actual al fiecărei proceduri.]** Direcția este univocă: sistemele de proof-of-personhood biometric sunt tratate ca prelucrare de risc maxim.

**Alternative recomandate, în ordinea preferinței:**
1. **EUDI Wallet / eIDAS 2.0** — portofelul european de identitate digitală permite dovada unor atribute (majorat, unicitate, cetățenie) fără dezvăluirea identității. Este soluția de viitor și, spre deosebire de biometrie, are sprijin de reglementare, nu opoziție.
2. **Atestări emise de terți acreditați** — un furnizor KYC verifică documentul o singură dată și emite o atestare criptografică; protocolul nu vede și nu stochează niciodată date personale.
3. **Sybil-resistance non-biometric** — graf social, dovadă de vechime a portofelului, cost economic al creării de identități multiple, verificare prin numere de telefon cu limite.
4. **Fără PoP.** Întreabă-te dacă unicitatea persoanei este cu adevărat necesară funcțional, sau doar dezirabilă pentru distribuție echitabilă. Costul juridic al biometriei depășește aproape sigur beneficiul.

**Obligații conexe, dacă totuși se colectează date personale:**
- **DPIA obligatorie** (art. 35 GDPR) — prelucrare la scară largă, tehnologie nouă, categorii speciale;
- **Reprezentant în UE** (art. 27) dacă operatorul e stabilit în afara UE;
- **Transferuri internaționale** (art. 44-49) — clauze contractuale standard plus evaluare de impact al transferului;
- **Notificare ANSPDCP** în caz de breșă, în 72 de ore.

## 5.2. GDPR și blockchain: incompatibilitatea structurală

**Adresele de portofel sunt date cu caracter personal** atunci când pot fi legate, direct sau indirect, de o persoană fizică — ceea ce se întâmplă din momentul primului KYC, al primei retrageri către un cont bancar sau al primei analize de lanț. Considerentul 26 GDPR și practica autorităților sunt clare pe acest punct.

Rezultă un conflict care nu are soluție tehnică pe lanț public: **art. 17 GDPR conferă dreptul la ștergere, iar blockchain-ul este proiectat să facă ștergerea imposibilă.** EDPB a adoptat în 2025 orientări dedicate blockchain-ului, iar linia lor este consecventă cu principiul protecției datelor începând cu momentul conceperii (art. 25).

**Reguli de arhitectură, obligatorii:**
1. **Nicio dată personală on-chain. Niciodată. Nici criptată, nici hash-uită.** Un hash al unui CNP este o dată personală: spațiul de valori posibile e mic, iar reversarea prin forță brută e trivială.
2. Datele personale stau **exclusiv off-chain**, într-o bază de date pe care o poți efectiv șterge.
3. Legătura on-chain ↔ off-chain se face prin identificatori aleatorii, fără semnificație intrinsecă.
4. Documentează formal, în registrul de prelucrări, alegerea de a nu stoca date pe lanț. Această decizie, documentată *înainte* de incident, este cea mai bună apărare într-un control.
5. Pentru cererile de ștergere privind date deja pe lanț: politica trebuie să prevadă ștergerea legăturii off-chain (care face datele anonime în sens practic) și să explice transparent limita tehnică. Nu promite ce nu poți executa.

## 5.3. Scorul de reputație: risc de interdicție absolută sub AI Act

Mandatul menționează „Social Mining cu Scor de Reputație". Modulul nu există în cod. **Recomandarea mea este să rămână așa.**

**Art. 5 alin. (1) lit. (c) din Regulamentul (UE) 2024/1689 (AI Act) interzice** sistemele de IA care evaluează sau clasifică persoane fizice pe baza comportamentului social sau a caracteristicilor personale, cu un scor social care conduce la tratament defavorabil în contexte fără legătură cu cel al colectării datelor, sau la tratament nejustificat ori disproporționat față de comportament.

Un „scor de reputație" care determină cuantumul recompenselor, accesul la funcții sau ponderea în guvernanță se apropie periculos de această definiție. Interdicțiile din Titlul II se aplică din 2 februarie 2025, cu sancțiuni de până la 35.000.000 EUR sau 7% din cifra de afaceri mondială totală anuală, aplicabile din august 2025. Este cel mai sever plafon de amendă din întreg dreptul european al tehnologiei — peste GDPR.

**Suplimentar, art. 22 GDPR** conferă dreptul de a nu face obiectul unei decizii bazate exclusiv pe prelucrare automată care produce efecte juridice sau similar semnificative. Un scor calculat algoritmic, care reduce recompensele cuiva, intră în această categorie și declanșează obligația de a asigura intervenție umană, dreptul de a-și exprima punctul de vedere și dreptul de a contesta.

**Dacă mecanismul este totuși necesar funcțional:**
- bazează-l **exclusiv pe contribuții obiective și verificabile** în cadrul protocolului (volum de muncă livrată, propuneri adoptate), niciodată pe comportament social, afiliere sau caracteristici personale;
- nu îl numi „reputație" și nu îl numi „scor social" — denumirea singură atrage încadrarea;
- asigură transparența completă a formulei de calcul și posibilitatea de recalculare independentă;
- prevede o cale de contestare cu intervenție umană;
- efectele să fie proporționale și limitate la contextul în care s-au produs contribuțiile.

## 5.4. ONPCSB, Travel Rule și plățile la comercianți

**Ești entitate raportoare?** Legea nr. 129/2019, astfel cum a fost modificată prin OUG nr. 10/2025, aliniază regimul la MiCA și TFR. Testul practic:

| Activitate | Entitate raportoare? |
|---|---|
| Publicarea unui smart contract imuabil, fără control ulterior | **Nu** |
| Front-end care doar afișează date on-chain | **Nu** |
| Front-end care agregă și rutează schimburi, cu comision | **Da** — recepție/transmitere de ordine sau schimb |
| Custodia cheilor sau a activelor utilizatorilor | **Da** — custodie și administrare |
| Procesare de plăți cripto pentru comercianți | **Da** — serviciu de transfer |
| Comerciant care acceptă cripto pentru marfa proprie | **Nu**, prin acest simplu fapt |

Obligațiile, dacă răspunsul este „da": desemnarea persoanei responsabile cu aplicarea legii și a unui ofițer de conformitate; proceduri scrise de cunoaștere a clientelei; evaluare proprie de risc; raportarea tranzacțiilor suspecte către ONPCSB; raportarea operațiunilor peste praguri; păstrarea evidențelor 5 ani; instruirea personalului. Neîndeplinirea atrage amenzi substanțiale și, în situații calificate, răspundere penală pentru complicitate la spălare de bani (art. 49 din Legea nr. 129/2019).

**Travel Rule — Regulamentul (UE) 2023/1113**, aplicabil din 30 decembrie 2024. Pentru transferurile de criptoactive între furnizori de servicii: informații complete despre plătitor și beneficiar, **fără prag de minimis** (spre deosebire de transferurile de fonduri, unde există pragul de 1.000 EUR). Pentru transferuri către sau dinspre portofele auto-găzduite peste 1.000 EUR: verificarea faptului că portofelul aparține clientului.

**Orizontul 2027 — Regulamentul (UE) 2024/1624 (AMLR)**, aplicabil din 10 iulie 2027: interzicerea conturilor anonime de criptoactive și a criptoactivelor care sporesc anonimatul pentru entitățile obligate, plafon de 10.000 EUR pentru plățile în numerar la nivelul UE. Dacă modelul de business depinde de anonimatul utilizatorilor, are dată de expirare cunoscută.

**Plățile P2P între utilizatori**, fără intermediar, nu generează obligații de raportare pentru dezvoltatorul protocolului. Aceasta este o consecință directă a caracterului non-custodial — încă un motiv pentru care rescrierea Vault-ului conform §2.3 nu e cosmetică.

## 5.5. Răspunderea pentru Circuit Breaker și AI Copilot

**Cine răspunde dacă rețeaua se oprește nejustificat?**

Trei temeiuri se pot cumula:

1. **Răspundere contractuală** (art. 1350 Cod civil) — dacă ToS promite disponibilitate. Soluție: nu promite. Prevede explicit posibilitatea suspendării.
2. **Răspundere delictuală** (art. 1357 Cod civil) — pentru fapta proprie a operatorilor de oracol. Fiecare oracol răspunde pentru atestarea sa; dacă oracolii sunt entități juridice distincte, răspunderea se fragmentează, ceea ce e favorabil fondatorului. Dacă toți oracolii sunt controlați de fondator, se concentrează integral asupra lui.
3. **Răspunderea pentru produse cu defect — riscul nou și subestimat.** Directiva (UE) 2024/2853 înlocuiește regimul din 1985 și **include expres software-ul și sistemele de IA în noțiunea de produs**. Răspunderea este **obiectivă** — nu se cere culpă — și **nu poate fi înlăturată sau limitată prin contract**. Termenul de transpunere de către statele membre este 9 decembrie 2026. Consecință: **nicio clauză din ToS nu te va proteja împotriva unei acțiuni întemeiate pe defectul software-ului**, iar termenul e la mai puțin de patru luni distanță.

**Constatare de cod cu relevanță juridică:** `CircuitBreaker` permite înghețări repetate. `esteInghetat()` expiră automat după `durataInghetare` (implicit 6 ore, maxim 24 prin `setDurate`), ceea ce e un design bun. Dar nimic nu împiedică cei 3 oracoli să atesteze un raport nou imediat după expirare. **Trei chei de oracol compromise = refuz de serviciu perpetuu, în cicluri de 6 ore.** Sub Directiva 2024/2853, aceasta este un defect de proiectare pentru care răspunderea e obiectivă.

*Remediere:* limită de rată (maximum N înghețări per fereastră de 30 de zile), obligația publicării on-chain a justificării, rotația obligatorie a cheilor de oracol, prag de anulare mai coborât decât pragul de declanșare (în prezent `pragAnulare = 5` este **mai mare** decât `pragAtestari = 3` — e mai ușor să oprești sistemul decât să îl repornești; inversează raportul).

**Session Keys și prompt injection.**

Vestea bună, și e semnificativă: designul actual cere o **semnătură EIP-712 proaspătă de la deținătorul contului pentru fiecare operațiune**, cu nonce și deadline. Aceasta este cea mai puternică apărare juridică posibilă: fiecare transfer are consimțământul demonstrabil al utilizatorului. Un agent compromis prin prompt injection **nu poate transfera nimic** fără o semnătură pe care doar utilizatorul o poate produce. Corectarea placeholder-ului `return true` documentată în `ABATERI.md` nu a fost o remediere de securitate — a fost eliminarea unei răspunderi civile nelimitate.

Trei vulnerabilități rămase, cu relevanță juridică:

1. **`revoca()` nu curăță lista de destinatari.** Setează doar `activa = false`. Intrările din `destinatarPermis[cont][agent][destinatar]` persistă indefinit.
2. **`creeazaCheie()` suprascrie structura, dar destinatarii vechi rămân valabili și se adaugă cei noi.** Un utilizator care revocă o cheie compromisă și creează una nouă pentru același agent **moștenește lista de destinatari a atacatorului**.
3. **`creeazaCheie()` resetează `cheltuit` la 0.** Recrearea cheii acordă un plafon cumulat nou, integral.

Combinate: utilizator cu agent compromis → revocă → recreează „în siguranță" → agentul are din nou acces la destinatarii adăugați de atacator, cu plafon proaspăt. Aceasta este exact secvența pe care o va urma un utilizator prudent, iar rezultatul e opusul celui așteptat.

*Remediere:* păstrează destinatarii într-o structură versionată (`mapping(address => mapping(address => uint256)) versiuneCheie`, cu destinatarii indexați pe versiune), astfel încât recrearea să invalideze automat toate permisiunile anterioare.

**Semnătura oarbă.** Dacă agentul AI construiește payload-ul și utilizatorul îl semnează într-un portofel care afișează date ininteligibile, consimțământul devine formal. În fața unei autorități de protecție a consumatorului, „a semnat" nu echivalează cu „a consimțit în cunoștință de cauză". Asigură-te că structura EIP-712 se afișează lizibil (sumă, destinatar, termen) în portofelele uzuale, și documentează testarea acestui aspect.

---

# 6. MATRICEA DE RISCURI ȘI PLANUL DE REMEDIERE

## 6.1. Matricea

| Modul / Mecanism | Risc legal principal (RO/UE) | Încălcare potențială | Severitate | Soluție de remediere |
|---|---|---|---|---|
| **Emisiune de către PF** | Ofertant persoană fizică | MiCA art. 4 alin. (1) lit. (a) | **CRITICĂ** | Entitate juridică UE ca ofertant; mint efectuat exclusiv de aceasta |
| **Ofertă fără white paper** | Ofertă publică nenotificată | MiCA art. 6, 8, 9 | **CRITICĂ** | White paper Anexa I, notificat cu 20 zile lucrătoare înainte, în stat membru cu autoritate funcțională |
| **Jurisdicția RO** | Autoritate competentă inexistentă | MiCA art. 93 | **CRITICĂ** | Emitent în Lituania/Irlanda; România exclusiv ca prestator de servicii |
| **`SavingsVault` custodial** | Custodie neautorizată; analogie cu depozitul | MiCA art. 59; OUG 99/2006 art. 5 + 410 | **CRITICĂ** | Rescriere ca time-lock in-place (§2.3); tokenii nu părăsesc contul utilizatorului |
| **Randament 2% garantat** | Investment contract; redistribuire de la alți deținători | Howey; art. 244 C.pen. | **CRITICĂ** | Eliminarea randamentului; beneficiul blocării = scutirea de demurrage |
| **Demurrage evitabil (§0.4.A)** | Practică înșelătoare; asimetrie informațională | Legea 363/2007 art. 6-8; MiCA art. 6-7 | **CRITICĂ** | Remediere tehnică sau dezvăluire proeminentă; interzicerea afirmațiilor false |
| **`setPraguri` fără limită inferioară** | Modificare unilaterală retroactivă a caracteristicii esențiale | Legea 193/2000 Anexa 1 lit. a), g) | **CRITICĂ** | `MIN_PRAG = 30 days`; preaviz 30 zile; calcul pe segmente istorice de rată |
| **`POLVesting` — admin perpetuu (§0.4.C)** | Afirmație factual falsă în cod și documentație | MiCA art. 6, 15; art. 244 C.pen. | **CRITICĂ** | Predarea administratorului către DAO sau multisig; corectarea `_raport()`; extinderea `_verifica()` |
| **Trezoreria controlată din RO** | Venit neimpozitat la încasare | Cod fiscal art. 19; Legea 241/2005 art. 9 | **CRITICĂ** | Trezoreria în patrimoniul entității străine; SRL-ul nu atinge tokeni |
| **Rezidența fiscală a entității străine** | Conducere efectivă în România | Cod fiscal art. 7 pct. 18 | **CRITICĂ** | Substanță economică reală: director local, ședințe, conturi, multisig distribuit |
| **Scor de reputație (dacă se implementează)** | Social scoring interzis | AI Act art. 5 alin. (1) lit. (c); GDPR art. 22 | **CRITICĂ** | A nu se implementa; alternativ, exclusiv contribuții obiective, cu drept de contestare |
| **PoP biometric** | Consimțământ nevalabil pentru date de categorie specială | GDPR art. 9, art. 7 alin. (4) | **CRITICĂ** | Fără biometrie; EUDI Wallet sau atestări de la terți |
| **DAO neînregistrat** | Răspundere personală nelimitată | C.civ. art. 1889 alin. (4), 1920 | **RIDICATĂ** | Verein elvețian sau fundație; separarea rolurilor |
| **`penalizareBps = 1000`** | Clauză penală disproporționată | Legea 193/2000 Anexa 1 lit. i); MiCA art. 13 | **RIDICATĂ** | Eliminare; blocarea devine irevocabilă până la termen |
| **`setScutit` discreționar** | Tratament discriminatoriu între deținători | Legea 363/2007; Legea 193/2000 | **RIDICATĂ** | Restrângere la contracte ale protocolului; scoatere din lista albă |
| **Denumirea „Moneda"** | Aparență de mijloc legal de plată | Legea 312/2004 art. 16; OUG 99/2006 art. 6 | **RIDICATĂ** | Redenumire; glosarul din §2.4 aplicat pe toate palierele |
| **Conturi bancare RO** | De-risking, reziliere unilaterală | Legea 129/2019 art. 11-15 | **RIDICATĂ** | Arhitectură pe trei niveluri; comunicare proactivă cu conformitatea băncii |
| **34% către validatori** | Obligație de reținere la sursă neîndeplinită | Cod fiscal art. 114-115 | **RIDICATĂ** | Distribuție automată on-chain, fără entitate română plătitoare |
| **TVA-ul tokenului** | Calificare incertă (Hedqvist vs. cupon) | Cod fiscal art. 292, art. 274¹ | **RIDICATĂ** | Soluție fiscală individuală anticipată (art. 52 C.proc.fisc.) |
| **Tokeni de fondator** | Impozitare la vesting pe valoare nerealizată | Cod fiscal art. 114-116 | **RIDICATĂ** | SFIA; eșalonare; rezervă de lichiditate pentru impozit |
| **Circuit breaker — DoS repetat** | Defect de produs, răspundere obiectivă | Directiva (UE) 2024/2853 | **RIDICATĂ** | Limită de rată; `pragAnulare < pragAtestari`; rotația cheilor |
| **Session Keys — destinatari persistenți** | Autorizare de transferuri neconsimțite | GDPR art. 32 analogic; răspundere delictuală | **RIDICATĂ** | Versionarea cheilor; invalidarea automată a permisiunilor la revocare |
| **Guvernanță blocată la 4 parametri** | Descriere înșelătoare a adaptabilității | MiCA art. 6-7 | **MEDIE** | Descriere onestă a imutabilității ca proprietate, nu ca limitare ascunsă |
| **Prețuri de transfer** | Prețuri neconforme valorii de piață | Cod fiscal art. 11; Ordin 442/2016 | **MEDIE** | Dosar de prețuri de transfer; cost-plus 5-10%; documentație de livrare |
| **Absența geo-blocării SUA** | Ofertă neînregistrată de securities | Securities Act 1933 §5 | **MEDIE** | Geo-blocare cu log-uri; reprezentări în ToS; screening OFAC |
| **Date personale on-chain** | Imposibilitatea ștergerii | GDPR art. 17, 25 | **MEDIE** | Arhitectură off-chain; nicio dată personală pe lanț, nici hash-uită |
| **`Distribuit` — arderea implicită** | Dacă `trezorerie == address(0)`, totul se arde | Discrepanță față de documentație | **MICĂ** | Verificare la deploy; `_verifica()` să testeze destinațiile |

## 6.2. Plan de remediere pe faze

### FAZA 0 — imediat, înainte de orice altceva (0-14 zile). Cost: ~0

Acestea sunt corecturi de adevăr, nu de conformitate. Nu costă bani și elimină cele mai stupide riscuri.

1. Corectează `_raport()` din `Deploy.s.sol` — codul afirmă ceva fals despre propria stare.
2. Adaugă `POLVesting` la etapa de predare a rolurilor și la `_verifica()`.
3. Elimină fallback-urile periculoase: `vm.envOr("GARDIAN", deployer)` → `vm.envAddress` care dă revert dacă lipsește.
4. Inventariază toate materialele publice existente (site, README, prezentări, mesaje pe rețele) și verifică fiecare afirmație față de cod. Șterge sau corectează tot ce nu se verifică.
5. Confirmă în scris statutul TESTNET pe toate canalele. Cât timp e testnet, cu tokeni fără valoare și fără ofertă, expunerea regulatorie este aproape nulă. **Aceasta este cea mai valoroasă poziție pe care o ai. Nu o pierde din grabă.**

### FAZA 1 — decizii structurale (14-60 zile). Cost: 15.000-40.000 EUR

6. **Decizia de jurisdicție.** Consultanță cu o casă de avocatură din statul ales (Lituania sau Irlanda). Buget: 8.000-15.000 EUR pentru opinia inițială și structurare.
7. **Constituirea entităților.** Verein/fundație CH sau echivalent + entitate operațională UE. Buget: 5.000-15.000 EUR plus costurile de substanță.
8. **Contract de prestări servicii SRL ↔ entitate străină**, cu politica de prețuri de transfer.
9. **Consultanță fiscală RO** pentru validarea fluxului și depunerea cererilor de soluție fiscală anticipată (TVA-ul tokenului, momentul impozitării tokenilor de fondator). Buget: 3.000-6.000 EUR.
10. **Deschiderea conturilor bancare** pe cele trei niveluri, cu dosarul de conformitate pregătit din timp.

### FAZA 2 — remedieri de cod (30-90 zile, în paralel cu Faza 1)

11. Rescrierea mecanismului de blocare ca time-lock in-place (§2.3) — cea mai importantă modificare tehnică din listă.
12. Eliminarea randamentului garantat și a penalizării de retragere anticipată.
13. `MIN_PRAG_TRANSA1 = 30 days` și mecanism de preaviz de 30 de zile pentru modificările în defavoarea deținătorilor.
14. Calculul demurrage-ului pe segmente istorice de rată, astfel încât modificările să nu se aplice retroactiv.
15. Restrângerea `setScutit` la contracte ale protocolului; scoaterea din lista albă a guvernanței.
16. Circuit breaker: limită de rată la înghețări, `pragAnulare < pragAtestari`, justificare on-chain obligatorie.
17. Session Keys: versionarea cheilor cu invalidarea automată a permisiunilor la revocare.
18. Decizia asupra evitabilității demurrage-ului: remediere tehnică sau dezvăluire explicită.

### FAZA 3 — documentație și conformitate (60-120 zile). Cost: 20.000-45.000 EUR

19. **Audit de securitate profesional.** `README.md` are dreptate că e obligatoriu. Buget realist: 15.000-40.000 EUR pentru un audit serios pe această suprafață. Un audit ieftin e mai periculos decât niciun audit — creează aparența de diligență fără substanță.
20. **White paper conform Anexei I MiCA**, redactat de avocat, verificat linie cu linie față de codul auditat.
21. **Terms of Service** cu cele 10 clauze din §3.4, în română și engleză.
22. **Politica de confidențialitate, registrul de prelucrări, DPIA** dacă se prelucrează date personale.
23. **Proceduri AML** dacă vreo componentă califică drept CASP.
24. **Geo-blocare** implementată tehnic, cu păstrarea log-urilor.
25. **Fluxul de consimțământ informat** pentru demurrage, cu simulare numerică și versionare.

### FAZA 4 — lansare (120+ zile)

26. Notificarea white paper-ului, cu 20 de zile lucrătoare înainte de publicare.
27. Deploy pe mainnet, cu predarea integrală și verificată a rolurilor.
28. Publicarea hotărârilor de predare, cu hash-urile tranzacțiilor.
29. Monitorizare continuă: modificările legislative în domeniu au o cadență de câteva luni, nu de câțiva ani.

**Buget total estimat pentru conformare: 60.000-130.000 EUR în primul an, plus 25.000-60.000 EUR anual pentru menținerea substanței.**

Dacă această cifră nu este disponibilă, concluzia nu este „lansăm oricum, cu riscuri". Concluzia este că modelul trebuie redus la o formă care nu declanșează aceste obligații: fără ofertă publică, fără mecanism de blocare cu randament, fără trezorerie care colectează de la utilizatori, fără front-end operat comercial. Un protocol pur, imuabil, publicat ca software liber, fără ofertă și fără operator, are un profil de risc dramatic diferit — și este o opțiune legitimă, nu un eșec.

## 6.3. Testul GO / NO-GO, de aplicat înainte de mainnet

Lansarea este permisă doar dacă **toate** răspunsurile sunt „da":

- [ ] Ofertantul este o persoană juridică dintr-un stat membru cu autoritate competentă funcțională?
- [ ] White paper-ul este notificat, iar cele 20 de zile lucrătoare au trecut?
- [ ] Fiecare afirmație din white paper a fost verificată individual față de codul deployat la commit-ul respectiv?
- [ ] Mecanismul de blocare este non-custodial, iar tokenii rămân în conturile utilizatorilor?
- [ ] S-a eliminat orice promisiune de randament predeterminat?
- [ ] Parametrii nu pot fi modificați retroactiv în defavoarea deținătorilor, iar limitele sunt imutabile în cod?
- [ ] Auditul de securitate profesional este finalizat, iar constatările critice și majore sunt remediate și reverificate?
- [ ] Fondatorul a renunțat, verificabil on-chain, la **toate** rolurile privilegiate — inclusiv `POLVesting`?
- [ ] Trezoreria aparține entității străine, iar SRL-ul român nu deține și nu primește tokeni?
- [ ] Entitatea străină are substanță economică demonstrabilă?
- [ ] Conturile bancare sunt deschise, iar băncile cunosc structura?
- [ ] Geo-blocarea SUA și screening-ul de sancțiuni funcționează, cu log-uri?
- [ ] ToS și fluxul de consimțământ informat sunt publicate și testate?
- [ ] Nicio dată personală nu ajunge pe lanț?
- [ ] Nu există niciun modul de scor de reputație și nicio componentă biometrică?

---

## Anexă — surse și acte normative principale

**Uniunea Europeană**
- Regulamentul (UE) 2023/1114 (MiCA) — art. 4-15 (oferte de alte criptoactive), 59 (autorizare CASP), 86-92 (abuz de piață), 93 (autorități competente), 143 (dispoziții tranzitorii)
- Regulamentul (UE) 2023/1113 (TFR — Travel Rule)
- Regulamentul (UE) 2024/1624 (AMLR), aplicabil din 10 iulie 2027
- Regulamentul (UE) 2024/1689 (AI Act) — art. 5 alin. (1) lit. (c), art. 50
- Regulamentul (UE) 2016/679 (GDPR) — art. 7, 9, 17, 22, 25, 27, 35, 44-49
- Directiva (UE) 2024/2853 privind răspunderea pentru produsele cu defect
- Regulamentul (UE) 1215/2012 (Bruxelles I bis) — art. 17-19
- CJUE, cauza C-264/14 *Skatteverket / Hedqvist*

**România**
- OUG nr. 99/2006 privind instituțiile de credit — art. 5, 6, 18, 410
- OUG nr. 10/2025 (modificarea Legii nr. 129/2019, aliniere TFR/MiCA)
- Legea nr. 129/2019 privind prevenirea spălării banilor
- Legea nr. 312/2004 privind Statutul BNR — art. 16
- Legea nr. 193/2000 privind clauzele abuzive
- Legea nr. 363/2007 privind practicile comerciale incorecte
- OUG nr. 34/2014 privind contractele la distanță
- Legea nr. 227/2015 (Codul fiscal) — art. 7, 11, 19, 47, 114-116, 170, 274¹, 278, 292, 317
- Legea nr. 207/2015 (Codul de procedură fiscală) — art. 52
- Legea nr. 141/2025 (majorarea cotelor de impozitare din 2026)
- Legea nr. 241/2005 privind evaziunea fiscală — art. 9
- Codul civil — art. 555, 1350, 1355, 1357, 1881-1889, 1920, 1949-1954
- Codul penal — art. 244, 249
- Codul de procedură penală — art. 249-254

---

*Sfârșitul raportului. Cele trei puncte marcate [VERIFICARE OBLIGATORIE] trebuie confirmate pe textele consolidate înainte de utilizarea raportului ca temei al unei decizii.*
