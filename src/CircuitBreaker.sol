// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title CircuitBreaker — inghetare la anomalii, cu atestare M-din-N
/// @notice DOAR TESTNET. Vezi README.md.
///
/// DIFERENTE FATA DE SPECIFICATIE (docs/ABATERI.md):
///
///  1. ATESTARE M-DIN-N, NU O SINGURA ADRESA. Documentul descria "oracole
///     rotationale, 3 din 5", dar contractul avea `onlyAIOracle` — o adresa
///     care putea ingheta trezoreria singura. Cheia aia compromisa =
///     protocol oprit. Aici e nevoie de `pragAtestari` semnaturi distincte
///     pe acelasi raport.
///
///  2. Raportul e identificat prin hash-ul CONTINUTULUI (metrici + fereastra
///     de timp). Doi oracoli atesteaza acelasi raport doar daca au vazut
///     aceleasi date. In specificatie, fiecare apel crea un raport nou.
///
///  3. Dezghetarea automata are timp maxim. In specificatie, `autoUnfreeze`
///     exista dar nimic nu garanta ca cineva o cheama. O trezorerie inghetata
///     la nesfarsit fiindca nimeni nu apasa un buton e acelasi lucru cu o
///     trezorerie pierduta: aici `esteInghetat()` expira singur.
///
///  4. Validatorii se numara dintr-un set, nu printr-o bucla peste un
///     `getValidator(i)` care nu exista in specificatie.
contract CircuitBreaker is AccessControl {
    bytes32 public constant ORACOL = keccak256("ORACOL");
    bytes32 public constant VALIDATOR = keccak256("VALIDATOR");
    bytes32 public constant GUVERNANTA = keccak256("GUVERNANTA");

    struct Raport {
        uint64 primaAtestare;
        uint32 atestari;
        bool declansat;
    }

    /// hash raport -> stare
    mapping(bytes32 => Raport) public rapoarte;
    /// hash raport -> oracol -> a atestat
    mapping(bytes32 => mapping(address => bool)) public aAtestat;
    /// hash raport -> validator -> a votat anularea
    mapping(bytes32 => mapping(address => bool)) public aVotatAnulare;
    mapping(bytes32 => uint32) public voturiAnulare;

    uint256 public pragAtestari = 3;
    /// Strict mai mic decat pragAtestari: repornirea nu poate fi mai grea
    /// decat oprirea.
    uint256 public pragAnulare = 2;

    /// Limita de rata: cate inghetari sunt permise intr-o fereastra. Fara
    /// ea, oracoli compromise pot ingheta la nesfarsit, reluand dupa fiecare
    /// expirare.
    uint256 public maxInghetariPeZi = 3;
    uint64 public ziCurenta;
    uint32 public inghetariAzi;
    /// Cat timp ramane valabila o atestare pana se aduna pragul. Fara
    /// fereastra, atestari de acum o luna s-ar putea combina cu una noua.
    uint256 public fereastraAtestare = 1 hours;
    /// Durata maxima a inghetarii. Expira singura.
    uint256 public durataInghetare = 6 hours;

    uint64 public inghetatLa;
    bytes32 public raportActiv;

    event Atestat(bytes32 indexed raport, address oracol, uint256 total);
    event Inghetat(bytes32 indexed raport, uint256 cand);
    event Dezghetat(bytes32 indexed raport, string motiv);
    event VotAnulare(bytes32 indexed raport, address validator, uint256 total);

    error DejaAtestat();
    error DejaDeclansat();
    error NuEInghetat();
    error FereastraExpirata();

    constructor(address guvernanta_) {
        _grantRole(DEFAULT_ADMIN_ROLE, guvernanta_);
        _grantRole(GUVERNANTA, guvernanta_);
    }

    /// @notice Trezoreria e inghetata acum?
    /// @dev Expira SINGURA dupa `durataInghetare`. Nu depinde de nimeni sa
    ///      cheme o functie de dezghetare.
    function esteInghetat() public view returns (bool) {
        if (inghetatLa == 0) return false;
        return block.timestamp < inghetatLa + durataInghetare;
    }

    /// @notice Un oracol atesteaza un raport de anomalie.
    /// @param hashRaport keccak(metrici, fereastra) — identic pentru oracoli
    ///        care au vazut aceleasi date.
    function atesta(bytes32 hashRaport) external onlyRole(ORACOL) {
        Raport storage r = rapoarte[hashRaport];
        if (r.declansat) revert DejaDeclansat();
        if (aAtestat[hashRaport][msg.sender]) revert DejaAtestat();

        if (r.primaAtestare == 0) {
            r.primaAtestare = uint64(block.timestamp);
        } else if (block.timestamp > r.primaAtestare + fereastraAtestare) {
            revert FereastraExpirata();
        }

        aAtestat[hashRaport][msg.sender] = true;
        r.atestari += 1;
        emit Atestat(hashRaport, msg.sender, r.atestari);

        if (r.atestari >= pragAtestari) {
            uint64 azi = uint64(block.timestamp / 1 days);
            if (azi != ziCurenta) {
                ziCurenta = azi;
                inghetariAzi = 0;
            }
            require(inghetariAzi < maxInghetariPeZi, "limita zilnica de inghetari");
            inghetariAzi += 1;

            r.declansat = true;
            inghetatLa = uint64(block.timestamp);
            raportActiv = hashRaport;
            emit Inghetat(hashRaport, block.timestamp);
        }
    }

    /// @notice Validatorii pot ridica inghetarea inainte de expirare.
    function voteazaAnulare(bytes32 hashRaport) external onlyRole(VALIDATOR) {
        if (!esteInghetat()) revert NuEInghetat();
        if (aVotatAnulare[hashRaport][msg.sender]) revert DejaAtestat();

        aVotatAnulare[hashRaport][msg.sender] = true;
        voturiAnulare[hashRaport] += 1;
        emit VotAnulare(hashRaport, msg.sender, voturiAnulare[hashRaport]);

        if (voturiAnulare[hashRaport] >= pragAnulare) {
            inghetatLa = 0;
            emit Dezghetat(hashRaport, "vot validatori");
        }
    }

    // --- guvernanta ---
    function setPraguri(uint256 atestari, uint256 anulare) external onlyRole(GUVERNANTA) {
        require(atestari > 1, "minim 2 atestari");
        // Ridicarea inghetarii trebuie sa fie MAI USOARA decat declansarea.
        // Altfel un set de oracoli compromise poate opri protocolul, iar
        // validatorii nu au cum sa-l reporneasca — DoS permanent cu aparenta
        // de siguranta. §6.1, "Circuit breaker — DoS repetat".
        require(anulare < atestari, "anularea trebuie sa fie mai usoara");
        pragAtestari = atestari;
        pragAnulare = anulare;
    }

    function setDurate(uint256 fereastra, uint256 inghetare) external onlyRole(GUVERNANTA) {
        require(inghetare <= 24 hours, "inghetare prea lunga");
        fereastraAtestare = fereastra;
        durataInghetare = inghetare;
    }
}

/// @notice Se mosteneste in contractele care trebuie oprite la anomalii.
abstract contract Intreruptibil {
    CircuitBreaker public immutable breaker;

    error TrezorerieInghetata();

    constructor(address breaker_) {
        breaker = CircuitBreaker(breaker_);
    }

    modifier candNuEInghetat() {
        if (address(breaker) != address(0) && breaker.esteInghetat()) {
            revert TrezorerieInghetata();
        }
        _;
    }
}
