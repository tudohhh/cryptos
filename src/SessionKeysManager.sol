// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title SessionKeysManager — delegare limitata catre un agent
/// @notice DOAR TESTNET. Vezi README.md.
///
/// DIFERENTE FATA DE SPECIFICATIE (docs/ABATERI.md):
///
///  1. SEMNATURA SE VERIFICA CU ADEVARAT. Specificatia avea:
///         function verifySignature(...) private pure returns (bool) {
///             return true; // Placeholder
///         }
///     marcata `pure` in timp ce pretindea ca verifica. Cu ea, orice agent
///     cu o cheie golea contul pana la `maxSpend` fara acordul nimanui.
///     Aici: EIP-712 + ECDSA.recover, iar semnatarul TREBUIE sa fie
///     detinatorul contului.
///
///  2. PROTECTIE LA REJUCARE. Specificatia semna (user, amount, recipient,
///     chainid) — fara nonce si fara termen. Aceeasi semnatura se putea
///     folosi de o mie de ori. Aici fiecare operatiune are nonce si deadline.
///
///  3. `maxSpend` e plafon PE OPERATIUNE plus un plafon cumulat separat.
///     Specificatia facea `key.maxSpend -= amount`, adica scadea limita,
///     amestecand cele doua notiuni.
///
///  4. Destinatarii permisi se tin intr-un mapping, nu intr-un array parcurs
///     liniar la fiecare executie.
contract SessionKeysManager is EIP712, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;

    bytes32 private constant TIP_OPERATIUNE = keccak256(
        "Operatiune(address cont,address agent,address destinatar,uint256 suma,uint256 nonce,uint256 deadline)"
    );

    struct Cheie {
        uint128 plafonOperatiune; // maxim pe o singura executie
        uint128 plafonTotal; // maxim cumulat pe viata cheii
        uint128 cheltuit; // cat s-a folosit din plafonTotal
        uint32 maximZilnic;
        uint32 contorZilnic;
        uint64 ziCurenta;
        uint64 expira;
        bool activa;
    }

    /// cont -> agent -> cheie
    mapping(address => mapping(address => Cheie)) public chei;
    /// cont -> agent -> destinatar -> permis
    mapping(address => mapping(address => mapping(address => bool))) public destinatarPermis;
    /// cont -> nonce consumat
    mapping(address => mapping(uint256 => bool)) public nonceFolosit;

    uint256 public constant MAX_DURATA = 30 days;

    event CheieCreata(address indexed cont, address indexed agent, uint256 plafonTotal, uint256 expira);
    event CheieRevocata(address indexed cont, address indexed agent);
    event Executat(address indexed cont, address indexed agent, address destinatar, uint256 suma);

    error CheieInactiva();
    error CheieExpirata();
    error PesteplafonOperatiune();
    error PestePlafonTotal();
    error LimitaZilnica();
    error DestinatarNepermis();
    error SemnaturaInvalida();
    error NonceFolosit();
    error TermenExpirat();
    error DurataPreaLunga();

    constructor(address token_) EIP712("SessionKeysManager", "1") {
        token = IERC20(token_);
    }

    function creeazaCheie(
        address agent,
        uint128 plafonOperatiune,
        uint128 plafonTotal,
        uint32 maximZilnic,
        uint64 durata,
        address[] calldata destinatari
    ) external {
        if (durata > MAX_DURATA) revert DurataPreaLunga();

        chei[msg.sender][agent] = Cheie({
            plafonOperatiune: plafonOperatiune,
            plafonTotal: plafonTotal,
            cheltuit: 0,
            maximZilnic: maximZilnic,
            contorZilnic: 0,
            ziCurenta: uint64(block.timestamp / 1 days),
            expira: uint64(block.timestamp + durata),
            activa: true
        });

        for (uint256 i = 0; i < destinatari.length; i++) {
            destinatarPermis[msg.sender][agent][destinatari[i]] = true;
        }

        emit CheieCreata(msg.sender, agent, plafonTotal, block.timestamp + durata);
    }

    function revoca(address agent) external {
        chei[msg.sender][agent].activa = false;
        emit CheieRevocata(msg.sender, agent);
    }

    /// @notice Agentul executa un transfer in numele contului.
    /// @dev Fiecare executie cere o semnatura EIP-712 PROASPATA de la
    ///      detinatorul contului. Cheia de sesiune limiteaza ce se poate
    ///      face; semnatura dovedeste ca utilizatorul a vrut exact asta.
    ///      Cele doua nu se inlocuiesc reciproc.
    function executa(
        address cont,
        address destinatar,
        uint256 suma,
        uint256 nonce,
        uint256 deadline,
        bytes calldata semnatura
    ) external nonReentrant {
        if (block.timestamp > deadline) revert TermenExpirat();
        if (nonceFolosit[cont][nonce]) revert NonceFolosit();

        Cheie storage k = chei[cont][msg.sender];
        if (!k.activa) revert CheieInactiva();
        if (block.timestamp > k.expira) revert CheieExpirata();
        if (suma > k.plafonOperatiune) revert PesteplafonOperatiune();
        if (uint256(k.cheltuit) + suma > k.plafonTotal) revert PestePlafonTotal();
        if (!destinatarPermis[cont][msg.sender][destinatar]) revert DestinatarNepermis();

        // Contor zilnic pe zi calendaristica UTC, nu pe fereastra mobila:
        // altfel un agent poate face 2x maximul la granita ferestrei.
        uint64 azi = uint64(block.timestamp / 1 days);
        if (azi != k.ziCurenta) {
            k.ziCurenta = azi;
            k.contorZilnic = 0;
        }
        if (k.contorZilnic >= k.maximZilnic) revert LimitaZilnica();

        // Verificarea care lipsea complet din specificatie.
        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(TIP_OPERATIUNE, cont, msg.sender, destinatar, suma, nonce, deadline))
        );
        if (ECDSA.recover(digest, semnatura) != cont) revert SemnaturaInvalida();

        nonceFolosit[cont][nonce] = true;
        k.contorZilnic += 1;
        k.cheltuit += uint128(suma);

        token.safeTransferFrom(cont, destinatar, suma);
        emit Executat(cont, msg.sender, destinatar, suma);
    }

    function digestPentru(
        address cont,
        address agent,
        address destinatar,
        uint256 suma,
        uint256 nonce,
        uint256 deadline
    ) external view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(TIP_OPERATIUNE, cont, agent, destinatar, suma, nonce, deadline)));
    }
}
