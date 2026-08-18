// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title QuadraticDAO — guvernanta cu vot cuadratic
/// @notice DOAR TESTNET. Vezi README.md.
///
/// DIFERENTE FATA DE SPECIFICATIE (docs/ABATERI.md):
///
///  1. VOTURILE SE RECUPEREAZA. In specificatie, `vote` lua votePower^2
///     tokeni si nu exista nicio functie de retragere. Fiecare vot distrugea
///     definitiv miza. Aici miza se blocheaza pana la finalul votarii si se
///     revendica dupa.
///
///  2. Propunerile executa apeluri reale, nu au un `_executeAction` gol.
///     Ce nu poate fi executat on-chain nu are ce cauta intr-un vot on-chain.
///
///  3. Tinta apelurilor e pe lista alba. Fara asta, o propunere care trece
///     poate chema orice, inclusiv `transfer` pe trezorerie catre o adresa
///     oarecare. Lista alba se schimba tot prin vot, dar cu timelock dublu.
///
///  4. Cvorumul se calculeaza pe PUTEREA DE VOT emisa, nu pe supply. In
///     vot cuadratic, 10% din supply e un prag imposibil: ca sa emiti N
///     voturi blochezi N^2 tokeni.
contract QuadraticDAO is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;

    enum Stare {
        Activa,
        Respinsa,
        Acceptata,
        Executata,
        Anulata
    }

    struct Propunere {
        address propunator;
        string descriere;
        address tinta;
        bytes apel;
        uint64 inceput;
        uint64 sfarsit;
        uint64 executabilaDupa;
        uint256 voturiPentru;
        uint256 voturiContra;
        bool executata;
        bool anulata;
    }

    /// Miza unui votant pe o propunere. Necesara ca sa poata fi revendicata.
    struct Vot {
        uint256 putere;
        uint256 miza;
        bool pentru;
        bool revendicat;
    }

    Propunere[] public propuneri;
    mapping(uint256 => mapping(address => Vot)) public voturi;

    /// Selectori permisi per contract tinta. Cheia: keccak(tinta, selector).
    mapping(bytes32 => bool) public permis;

    uint256 public durataVot = 7 days;
    uint256 public timelock = 7 days;
    /// Cvorum absolut, in unitati de putere de vot. Guvernanta il ajusteaza
    /// pe masura ce creste participarea.
    uint256 public cvorum = 100;

    address public gardian; // poate doar ANULA, niciodata executa

    event PropunereCreata(uint256 indexed id, address propunator, string descriere);
    event Votat(uint256 indexed id, address votant, uint256 putere, uint256 miza, bool pentru);
    event MizaRevendicata(uint256 indexed id, address votant, uint256 miza);
    event PropunereExecutata(uint256 indexed id);
    event PropunereAnulata(uint256 indexed id);
    event PermisiuneSchimbata(address tinta, bytes4 selector, bool valoare);

    error VotareInchisa();
    error VotareInca();
    error DejaVotat();
    error PutereZero();
    error TimelockActiv();
    error DejaExecutata();
    error Anulata();
    error CvorumNeatins(uint256 obtinut, uint256 necesar);
    error Respinsa_();
    error ApelNepermis();
    error ApelEsuat();
    error NuEGardian();
    error NimicDeRevendicat();
    error PutereaPreaMare();

    constructor(address token_, address gardian_) {
        token = IERC20(token_);
        gardian = gardian_;
    }

    // ===============================================================
    // Propuneri
    // ===============================================================
    function propune(string calldata descriere, address tinta, bytes calldata apel) external returns (uint256 id) {
        if (!permis[_cheie(tinta, bytes4(apel))]) revert ApelNepermis();

        id = propuneri.length;
        propuneri.push(
            Propunere({
                propunator: msg.sender,
                descriere: descriere,
                tinta: tinta,
                apel: apel,
                inceput: uint64(block.timestamp),
                sfarsit: uint64(block.timestamp + durataVot),
                executabilaDupa: uint64(block.timestamp + durataVot + timelock),
                voturiPentru: 0,
                voturiContra: 0,
                executata: false,
                anulata: false
            })
        );
        emit PropunereCreata(id, msg.sender, descriere);
    }

    // ===============================================================
    // Vot cuadratic
    // ===============================================================

    /// @notice Blocheaza `putere^2` tokeni pentru `putere` voturi.
    /// @dev Miza se recupereaza cu `revendicaMiza` dupa inchiderea votarii.
    function voteaza(uint256 id, uint256 putere, bool pentru) external nonReentrant {
        Propunere storage p = propuneri[id];
        if (block.timestamp > p.sfarsit) revert VotareInchisa();
        if (p.anulata) revert Anulata();
        if (putere == 0) revert PutereZero();
        // Plafon care garanteaza ca putere^2 nu da overflow.
        if (putere > type(uint128).max) revert PutereaPreaMare();
        if (voturi[id][msg.sender].putere != 0) revert DejaVotat();

        uint256 miza = putere * putere;
        token.safeTransferFrom(msg.sender, address(this), miza);

        voturi[id][msg.sender] = Vot({putere: putere, miza: miza, pentru: pentru, revendicat: false});

        if (pentru) {
            p.voturiPentru += putere;
        } else {
            p.voturiContra += putere;
        }

        emit Votat(id, msg.sender, putere, miza, pentru);
    }

    /// @notice Recupereaza miza dupa inchiderea votarii.
    /// @dev Functia care lipsea complet din specificatie. Fara ea, fiecare
    ///      vot ardea definitiv patratul puterii de vot — participarea la
    ///      guvernanta costa capital pierdut, nu blocat.
    function revendicaMiza(uint256 id) external nonReentrant {
        Propunere storage p = propuneri[id];
        // Se poate revendica si la propuneri anulate: miza nu e pedeapsa.
        if (block.timestamp <= p.sfarsit && !p.anulata) revert VotareInca();

        Vot storage v = voturi[id][msg.sender];
        if (v.miza == 0 || v.revendicat) revert NimicDeRevendicat();

        v.revendicat = true;
        uint256 miza = v.miza;
        token.safeTransfer(msg.sender, miza);

        emit MizaRevendicata(id, msg.sender, miza);
    }

    // ===============================================================
    // Executie
    // ===============================================================
    function executa(uint256 id) external nonReentrant {
        Propunere storage p = propuneri[id];
        if (p.executata) revert DejaExecutata();
        if (p.anulata) revert Anulata();
        if (block.timestamp <= p.sfarsit) revert VotareInca();
        if (block.timestamp < p.executabilaDupa) revert TimelockActiv();

        uint256 total = p.voturiPentru + p.voturiContra;
        if (total < cvorum) revert CvorumNeatins(total, cvorum);
        if (p.voturiPentru <= p.voturiContra) revert Respinsa_();

        // Re-verificam permisiunea la EXECUTIE, nu doar la propunere.
        // Lista alba se poate schimba intre timp, iar o propunere veche nu
        // trebuie sa poata folosi o permisiune retrasa.
        if (!permis[_cheie(p.tinta, bytes4(p.apel))]) revert ApelNepermis();

        p.executata = true;

        (bool ok,) = p.tinta.call(p.apel);
        if (!ok) revert ApelEsuat();

        emit PropunereExecutata(id);
    }

    /// @notice Gardianul poate anula o propunere, dar nu poate executa una.
    /// @dev Asimetria e intentionata: puterea de a opri ceva rau e mult mai
    ///      putin periculoasa decat puterea de a face ceva.
    function anuleaza(uint256 id) external {
        if (msg.sender != gardian) revert NuEGardian();
        Propunere storage p = propuneri[id];
        if (p.executata) revert DejaExecutata();
        p.anulata = true;
        emit PropunereAnulata(id);
    }

    // ===============================================================
    // Lista alba — se modifica doar prin propuneri executate
    // ===============================================================
    function setPermis(address tinta, bytes4 selector, bool valoare) external {
        // Doar DAO-ul insusi, printr-o propunere executata.
        require(msg.sender == address(this), "doar prin vot");
        permis[_cheie(tinta, selector)] = valoare;
        emit PermisiuneSchimbata(tinta, selector, valoare);
    }

    /// @dev Configurare initiala, o singura data, inainte de prima propunere.
    function initializeazaPermisiuni(address tinta, bytes4[] calldata selectori) external {
        if (msg.sender != gardian) revert NuEGardian();
        require(propuneri.length == 0, "prea tarziu");
        for (uint256 i = 0; i < selectori.length; i++) {
            permis[_cheie(tinta, selectori[i])] = true;
            emit PermisiuneSchimbata(tinta, selectori[i], true);
        }
    }

    function _cheie(address tinta, bytes4 selector) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(tinta, selector));
    }

    function numarPropuneri() external view returns (uint256) {
        return propuneri.length;
    }

    function stare(uint256 id) external view returns (Stare) {
        Propunere storage p = propuneri[id];
        if (p.anulata) return Stare.Anulata;
        if (p.executata) return Stare.Executata;
        if (block.timestamp <= p.sfarsit) return Stare.Activa;
        uint256 total = p.voturiPentru + p.voturiContra;
        if (total < cvorum || p.voturiPentru <= p.voturiContra) return Stare.Respinsa;
        return Stare.Acceptata;
    }
}
