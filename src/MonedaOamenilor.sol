// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title MonedaOamenilor — token cu demurrage progresiv pe inactivitate
/// @notice DOAR TESTNET. Nu deploya pe mainnet fara audit profesional si
///         analiza MiCA. Vezi README.md, sectiunea "Statut".
///
/// DIFERENTE FATA DE SPECIFICATIA INITIALA (toate deliberate — vezi
/// docs/ABATERI.md pentru motivele complete):
///
///  1. Demurrage se calculeaza PE TRANSE, nu cu rata ultimei transe aplicata
///     retroactiv pe tot intervalul. Cineva inactiv 100 de zile plateste
///     0% pe primele 30, 1% pe urmatoarele 60, 2.5% pe ultimele 10 — nu
///     2.5% pe toate 100. Varianta initiala pedepsea retroactiv o perioada
///     in care regula era alta.
///
///  2. Se aplica in `_update`, nu prin suprascrierea lui `transfer`. Altfel
///     `transferFrom` ocoleste complet demurrage-ul si taxele: un `approve`
///     catre tine insuti si treci pe langa tot modelul economic.
///
///  3. Conturile noi nu sunt taxate. `lastActivity == 0` inseamna "cont nou",
///     nu "inactiv de la 1 ianuarie 1970". In varianta initiala, primul
///     transfer al oricarui utilizator il taxa maxim.
///
///  4. Demurrage-ul nu poate depasi soldul, iar guvernanta nu poate seta
///     rate peste `MAX_RATE_BPS`. Doua plase separate: una pe calcul, una
///     pe configurare.
///
///  5. Impartirea 33/33/34 se face din suma colectata, o singura data.
///     Varianta initiala ardea intreaga suma SI apoi mai incerca o
///     impartire — dubla contabilizare, revert garantat.
contract MonedaOamenilor is ERC20, AccessControl {
    // ---------------------------------------------------------------
    // Roluri
    // ---------------------------------------------------------------
    bytes32 public constant GUVERNANTA = keccak256("GUVERNANTA");
    bytes32 public constant EMITENT = keccak256("EMITENT");

    // ---------------------------------------------------------------
    // Constante de siguranta
    // ---------------------------------------------------------------
    uint256 public constant BPS = 10_000;
    uint256 public constant PERIOADA = 30 days;

    /// Plafon dur pe rata de demurrage. Guvernanta nu poate trece peste el
    /// nici prin vot. 1000 bps = 10% pe luna: deja extrem, dar nu confiscator.
    /// Fara plafonul asta, o propunere gresita (sau ostila) poate seta 100%.
    uint256 public constant MAX_RATE_BPS = 1_000;

    /// Idem pentru taxa de tranzactie: 5%.
    uint256 public constant MAX_TAXA_BPS = 500;

    /// Perioada de gratie minima. Fara ea, `setPraguri(1 seconds, 2 seconds)`
    /// combinat cu rata maxima dadea ~72% erodare anuala de la o secunda de
    /// inactivitate — si retroactiv pe intervalul deja scurs la momentul
    /// votului. README afirma ca "un vot nu poate confisca solduri";
    /// afirmatia era falsa exact pe vectorul asta.
    /// Constatarea §0.4.B din docs/AUDIT-JURIDIC.md.
    uint256 public constant MIN_PRAG_TRANSA1 = 30 days;

    // ---------------------------------------------------------------
    // Stare per utilizator
    // ---------------------------------------------------------------
    /// Ultimul moment cand contul a avut activitate. 0 = cont nou, netaxat.
    mapping(address => uint256) public ultimaActivitate;

    /// Blocare IN-PLACE: pana cand nu poate misca soldul din propriul cont.
    /// Tokenii NU pleaca nicaieri. `balanceOf` ii contine tot timpul.
    ///
    /// De ce asa si nu prin `SavingsVault`: mutarea tokenilor intr-un
    /// contract face din utilizator un creditor, nu un proprietar — adica
    /// exact custodie de criptoactive in numele clientilor (MiCA art. 59),
    /// serviciu CASP pentru care e nevoie de autorizatie. Blocarea in-place
    /// e o restrictie de dispozitie auto-impusa asupra propriului activ.
    /// Nimeni nu detine nimic al altcuiva. §2.3 din docs/AUDIT-JURIDIC.md.
    ///
    /// Beneficiul blocarii e scutirea de demurrage. Atat. Fara randament:
    /// blochezi ca sa nu pierzi, nu ca sa castigi.
    mapping(address => uint64) public blocatPanaLa;

    /// Plafon pe durata blocarii. Fara el, cineva isi poate bloca soldul
    /// pentru 100 de ani dintr-o greseala de conversie, ireversibil.
    uint256 public constant MAX_BLOCARE = 365 days;

    /// Adrese care nu platesc demurrage si nu declanseaza taxe: contractele
    /// protocolului (vault, trezorerie, staking, DEX pair). Fara asta,
    /// tokenurile blocate in Vault s-ar eroda, ceea ce contrazice scopul
    /// Vault-ului: sa fie adapostul de demurrage.
    mapping(address => bool) public scutit;

    // ---------------------------------------------------------------
    // Parametri guvernabili
    // ---------------------------------------------------------------
    uint256 public rataTransa1 = 100; // 1.0% / 30 zile
    uint256 public rataTransa2 = 250; // 2.5% / 30 zile  (NU 25% — vezi doc)
    uint256 public pragTransa1 = 30 days;
    uint256 public pragTransa2 = 90 days;

    uint256 public taxaTranzactie = 50; // 0.5%
    uint256 public pragMicroTx = 1e18; // sub 1 token: fara taxa

    // ---------------------------------------------------------------
    // Destinatii pentru impartirea 33/33/34
    // ---------------------------------------------------------------
    address public trezorerie;
    address public staking;
    uint256 public constant COTA_ARDERE = 33;
    uint256 public constant COTA_TREZORERIE = 33;
    uint256 public constant COTA_VALIDATORI = 34;

    // ---------------------------------------------------------------
    // Contabilitate
    // ---------------------------------------------------------------
    uint256 public totalArs;
    uint256 public totalDemurrage;

    /// Previne recursivitatea: `_distribuie` face transferuri, care ar
    /// reintra in `_update` si ar declansa iar decontarea.
    bool private _inDecontare;

    // ---------------------------------------------------------------
    // Evenimente
    // ---------------------------------------------------------------
    event DemurrageAplicat(address indexed cont, uint256 suma, uint256 transa);
    event TaxaAplicata(address indexed de_la, uint256 suma);
    event Distribuit(uint256 ars, uint256 trezorerie, uint256 validatori);
    event ParametruSchimbat(string nume, uint256 vechi, uint256 nou);
    event ScutireSchimbata(address indexed cont, bool scutit);
    event SoldBlocatPanaLa(address indexed cont, uint64 panaLa);

    // ---------------------------------------------------------------
    // Erori
    // ---------------------------------------------------------------
    error RataPesteplafon(uint256 ceruta, uint256 plafon);
    error PraguriInversate();
    error PragSubMinim(uint256 cerut, uint256 minim);
    error AdresaZero();
    error SoldBlocat(uint64 panaLa);
    error DoarPrelungire();
    error BlocarePreaLunga();

    constructor(address guvernanta_) ERC20("Moneda Oamenilor", "MO") {
        if (guvernanta_ == address(0)) revert AdresaZero();
        _grantRole(DEFAULT_ADMIN_ROLE, guvernanta_);
        _grantRole(GUVERNANTA, guvernanta_);
        _grantRole(EMITENT, guvernanta_);
        scutit[address(0)] = true;
        scutit[address(this)] = true;
    }

    // ===============================================================
    // Demurrage — miezul contractului
    // ===============================================================

    /// @notice Cat demurrage datoreaza un cont in acest moment.
    /// @dev Calcul pe transe. Rezultatul e mereu <= soldul contului.
    function demurrageDatorat(address cont) public view returns (uint256) {
        if (scutit[cont]) return 0;

        uint256 ultima = ultimaActivitate[cont];
        // Cont nou: nu are istoric de inactivitate. Nu il taxam pentru
        // timpul de dinainte sa existe.
        if (ultima == 0) return 0;

        // Blocarea e scutire de demurrage — asta e tot beneficiul ei.
        if (esteBlocat(cont)) return 0;

        uint256 sold = balanceOf(cont);
        if (sold == 0) return 0;

        uint256 inactiv = block.timestamp - ultima;
        if (inactiv <= pragTransa1) return 0;

        // Transa 1: intervalul [pragTransa1, pragTransa2]
        uint256 inTransa1;
        uint256 inTransa2;
        if (inactiv <= pragTransa2) {
            inTransa1 = inactiv - pragTransa1;
        } else {
            inTransa1 = pragTransa2 - pragTransa1;
            inTransa2 = inactiv - pragTransa2;
        }

        // Liniar in interiorul fiecarei transe. Inmultim inainte sa impartim,
        // ca sa nu pierdem precizie pe intervale scurte.
        uint256 datorat =
            (sold * rataTransa1 * inTransa1) / (BPS * PERIOADA) + (sold * rataTransa2 * inTransa2) / (BPS * PERIOADA);

        // Plasa de siguranta: nimeni nu poate datora mai mult decat are.
        // Se atinge doar dupa ani de inactivitate; existenta ei garanteaza
        // ca `_burn` nu revine niciodata cu revert din cauza asta.
        return datorat > sold ? sold : datorat;
    }

    /// @dev Deconteaza demurrage-ul acumulat si reseteaza ceasul.
    function _deconteaza(address cont) internal {
        if (_inDecontare || scutit[cont]) return;

        uint256 datorat = demurrageDatorat(cont);
        uint256 inactiv = ultimaActivitate[cont] == 0 ? 0 : block.timestamp - ultimaActivitate[cont];

        if (datorat > 0) {
            _inDecontare = true;
            _distribuie(cont, datorat);
            _inDecontare = false;

            totalDemurrage += datorat;
            emit DemurrageAplicat(cont, datorat, inactiv > pragTransa2 ? 2 : 1);
        }

        ultimaActivitate[cont] = block.timestamp;
    }

    // ===============================================================
    // Blocare in-place
    // ===============================================================

    /// @notice Isi blocheaza propriul sold pana la `pana`, in schimbul
    ///         scutirii de demurrage.
    /// @dev Doar PRELUNGIRE. Nu exista iesire anticipata si nu exista
    ///      penalizare — o clauza penala care ia 10% din capitalul
    ///      consumatorului pentru exercitarea unui drept de retragere e
    ///      prezumat abuziva (Legea 193/2000). Intr-o blocare absoluta,
    ///      problema dispare: nu ai ce penaliza, fiindca nu exista iesire.
    function blocheaza(uint64 pana) external {
        if (pana <= blocatPanaLa[msg.sender] || pana <= block.timestamp) {
            revert DoarPrelungire();
        }
        if (pana > block.timestamp + MAX_BLOCARE) revert BlocarePreaLunga();

        // Decontam ce se datoreaza INAINTE de blocare: altfel cineva inactiv
        // 6 luni s-ar bloca si ar scapa de demurrage-ul deja acumulat.
        _deconteaza(msg.sender);

        blocatPanaLa[msg.sender] = pana;
        emit SoldBlocatPanaLa(msg.sender, pana);
    }

    /// @notice Soldul e blocat acum?
    function esteBlocat(address cont) public view returns (bool) {
        return block.timestamp < blocatPanaLa[cont];
    }

    /// @notice Oricine poate declansa decontarea pentru un cont.
    /// @dev Necesar ca demurrage-ul sa nu depinda de vointa celui taxat.
    ///      Fara asta, un cont care nu tranzactioneaza niciodata nu plateste
    ///      niciodata — adica exact comportamentul pe care il descurajam.
    function deconteaza(address cont) external {
        _deconteaza(cont);
    }

    // ===============================================================
    // Impartirea 33/33/34
    // ===============================================================

    /// @dev Ia `suma` de la `de_la` si o imparte. Suma partilor e EXACT
    ///      `suma`: restul din impartire merge la validatori, altfel s-ar
    ///      pierde wei pe fiecare operatiune si contabilitatea ar deriva.
    function _distribuie(address de_la, uint256 suma) internal {
        uint256 ars = (suma * COTA_ARDERE) / 100;
        uint256 catreTrezorerie = (suma * COTA_TREZORERIE) / 100;
        uint256 catreValidatori = suma - ars - catreTrezorerie;

        if (ars > 0) {
            _burn(de_la, ars);
            totalArs += ars;
        }
        // Daca destinatia nu e configurata, partea se arde. Alternativa ar
        // fi revert, care ar bloca toate transferurile pana la configurare.
        if (catreTrezorerie > 0) {
            if (trezorerie == address(0)) {
                _burn(de_la, catreTrezorerie);
                totalArs += catreTrezorerie;
            } else {
                _transfer(de_la, trezorerie, catreTrezorerie);
            }
        }
        if (catreValidatori > 0) {
            if (staking == address(0)) {
                _burn(de_la, catreValidatori);
                totalArs += catreValidatori;
            } else {
                _transfer(de_la, staking, catreValidatori);
            }
        }

        emit Distribuit(ars, catreTrezorerie, catreValidatori);
    }

    // ===============================================================
    // Hook-ul central — prinde transfer, transferFrom, mint si burn
    // ===============================================================
    function _update(address de_la, address catre, uint256 suma) internal override {
        // In timpul distribuirii nu redeclansam nimic.
        if (_inDecontare) {
            super._update(de_la, catre, suma);
            return;
        }

        // 1. Soldul blocat nu poate iesi. Nici prin transfer, nici prin
        //    transferFrom, nici prin ardere.
        if (de_la != address(0) && esteBlocat(de_la)) {
            revert SoldBlocat(blocatPanaLa[de_la]);
        }

        // 2. Deconteaza demurrage-ul expeditorului INAINTE de transfer,
        //    altfel ar putea trimite tokeni pe care ii datoreaza deja.
        if (de_la != address(0)) {
            _deconteaza(de_la);
        }

        // 3. Taxa de tranzactie, doar pe transferuri intre utilizatori.
        uint256 net = suma;
        bool taxabil =
            de_la != address(0) && catre != address(0) && !scutit[de_la] && !scutit[catre] && suma >= pragMicroTx;

        if (taxabil && taxaTranzactie > 0) {
            uint256 taxa = (suma * taxaTranzactie) / BPS;
            if (taxa > 0) {
                net = suma - taxa;
                _inDecontare = true;
                _distribuie(de_la, taxa);
                _inDecontare = false;
                emit TaxaAplicata(de_la, taxa);
            }
        }

        super._update(de_la, catre, net);

        // 4. Porneste ceasul pentru destinatar daca e prima lui primire.
        //    Nu il resetam la fiecare primire: altfel oricine si-ar putea
        //    tine soldul "proaspat" trimitandu-si 1 wei de pe alt cont.
        if (catre != address(0) && ultimaActivitate[catre] == 0 && !scutit[catre]) {
            ultimaActivitate[catre] = block.timestamp;
        }
    }

    // ===============================================================
    // Emisiune
    // ===============================================================
    function emite(address catre, uint256 suma) external onlyRole(EMITENT) {
        _mint(catre, suma);
    }

    // ===============================================================
    // Guvernanta
    // ===============================================================
    function setRate(uint256 transa1, uint256 transa2) external onlyRole(GUVERNANTA) {
        if (transa1 > MAX_RATE_BPS) revert RataPesteplafon(transa1, MAX_RATE_BPS);
        if (transa2 > MAX_RATE_BPS) revert RataPesteplafon(transa2, MAX_RATE_BPS);
        emit ParametruSchimbat("rataTransa1", rataTransa1, transa1);
        emit ParametruSchimbat("rataTransa2", rataTransa2, transa2);
        rataTransa1 = transa1;
        rataTransa2 = transa2;
    }

    function setPraguri(uint256 prag1, uint256 prag2) external onlyRole(GUVERNANTA) {
        if (prag1 < MIN_PRAG_TRANSA1) revert PragSubMinim(prag1, MIN_PRAG_TRANSA1);
        if (prag1 >= prag2) revert PraguriInversate();
        emit ParametruSchimbat("pragTransa1", pragTransa1, prag1);
        emit ParametruSchimbat("pragTransa2", pragTransa2, prag2);
        pragTransa1 = prag1;
        pragTransa2 = prag2;
    }

    function setTaxa(uint256 taxaBps) external onlyRole(GUVERNANTA) {
        if (taxaBps > MAX_TAXA_BPS) revert RataPesteplafon(taxaBps, MAX_TAXA_BPS);
        emit ParametruSchimbat("taxaTranzactie", taxaTranzactie, taxaBps);
        taxaTranzactie = taxaBps;
    }

    function setDestinatii(address trezorerie_, address staking_) external onlyRole(GUVERNANTA) {
        trezorerie = trezorerie_;
        staking = staking_;
        if (trezorerie_ != address(0)) scutit[trezorerie_] = true;
        if (staking_ != address(0)) scutit[staking_] = true;
    }

    function setScutit(address cont, bool valoare) external onlyRole(GUVERNANTA) {
        scutit[cont] = valoare;
        emit ScutireSchimbata(cont, valoare);
    }
}
