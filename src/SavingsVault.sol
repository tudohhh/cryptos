// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title SavingsVault — adapost de demurrage, cu randament finantat
/// @notice DOAR TESTNET. Vezi README.md.
///
/// DIFERENTE FATA DE SPECIFICATIE (docs/ABATERI.md):
///
///  1. `withdrawVault` din specificatie continea
///     `block.timestamp - block.timestamp - (duration * 30 days)`, care e
///     negativ intr-un uint256 => panic in 0.8.x. NIMENI nu putea retrage.
///     Aici randamentul se calculeaza pe durata efectiv scursa.
///
///  2. Randamentul e FINANTAT, nu inventat. Specificatia promitea 2% APY
///     fara sa spuna de unde vin tokenii. Aici exista o rezerva alimentata
///     explicit din trezorerie; daca nu ajunge, depunerea e respinsa la
///     intrare, nu la iesire. Mai bine refuzi un depozit decat sa nu poti
///     plati la scadenta.
///
///  3. Randamentul se rezerva LA DEPUNERE si se scade din disponibil.
///     Altfel primii care retrag golesc rezerva si ultimii nu mai primesc.
///
///  4. Protectia anti-flashloan nu se bazeaza pe numar de bloc per adresa
///     (banal de ocolit cu alte adrese), ci pe faptul ca pozitiile au
///     scadenta minima si penalizarea se aplica pe principal.
contract SavingsVault is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant GUVERNANTA = keccak256("GUVERNANTA");

    IERC20 public immutable token;

    struct Pozitie {
        uint128 principal;
        uint128 randamentRezervat;
        uint64 scadenta;
        uint32 durataLuni;
        bool retrasa;
    }

    mapping(address => Pozitie[]) public pozitii;

    /// Tokeni pusi deoparte pentru randamente deja promise. Nu pot fi
    /// folositi pentru alte depuneri.
    uint256 public randamentAngajat;
    /// Total principal aflat in custodie. Separat de rezerva.
    uint256 public totalPrincipal;

    uint256 public apyBps = 200; // 2%
    uint256 public penalizareBps = 1000; // 10% la retragere anticipata
    address public trezorerie;

    uint256 public constant AN = 365 days;
    uint256 public constant BPS = 10_000;
    uint256 public constant MAX_APY_BPS = 2_000; // 20%, plafon dur

    event Depus(address indexed cont, uint256 index, uint256 suma, uint256 luni, uint256 randament);
    event Retras(address indexed cont, uint256 index, uint256 suma);
    event RetrasAnticipat(address indexed cont, uint256 index, uint256 suma, uint256 penalizare);
    event RezervaAlimentata(uint256 suma);

    error DurataInvalida();
    error SumaZero();
    error RezervaInsuficienta(uint256 necesar, uint256 disponibil);
    error DejaRetrasa();
    error NuEScadenta(uint256 scadenta, uint256 acum);
    error DejaScadenta();
    error ApyPestePlafon();

    constructor(address token_, address guvernanta_) {
        token = IERC20(token_);
        _grantRole(DEFAULT_ADMIN_ROLE, guvernanta_);
        _grantRole(GUVERNANTA, guvernanta_);
    }

    /// @notice Cati tokeni sunt liberi pentru a garanta randamente noi.
    /// @dev Soldul contractului minus principalul in custodie minus
    ///      randamentele deja promise. Ce ramane e rezerva utilizabila.
    function rezervaDisponibila() public view returns (uint256) {
        uint256 sold = token.balanceOf(address(this));
        uint256 angajat = totalPrincipal + randamentAngajat;
        return sold > angajat ? sold - angajat : 0;
    }

    /// @notice Trezoreria trimite tokeni ca sa poata fi platite randamentele.
    function alimenteazaRezerva(uint256 suma) external {
        token.safeTransferFrom(msg.sender, address(this), suma);
        emit RezervaAlimentata(suma);
    }

    function randamentPentru(uint256 suma, uint256 luni) public view returns (uint256) {
        // Durata reala in secunde, nu "luni" tratate ca ani.
        uint256 durata = luni * 30 days;
        return (suma * apyBps * durata) / (BPS * AN);
    }

    function depune(uint256 suma, uint256 luni) external nonReentrant {
        if (luni != 3 && luni != 6 && luni != 12) revert DurataInvalida();
        if (suma == 0) revert SumaZero();

        uint256 randament = randamentPentru(suma, luni);

        // Verificam ACUM ca putem plati la scadenta. Daca nu, refuzam
        // depunerea. Alternativa — sa acceptam si sa nu putem plati peste
        // 12 luni — transforma o problema de trezorerie in inselaciune.
        uint256 disponibil = rezervaDisponibila();
        if (randament > disponibil) {
            revert RezervaInsuficienta(randament, disponibil);
        }

        token.safeTransferFrom(msg.sender, address(this), suma);

        randamentAngajat += randament;
        totalPrincipal += suma;

        pozitii[msg.sender].push(
            Pozitie({
                principal: uint128(suma),
                randamentRezervat: uint128(randament),
                scadenta: uint64(block.timestamp + luni * 30 days),
                durataLuni: uint32(luni),
                retrasa: false
            })
        );

        emit Depus(msg.sender, pozitii[msg.sender].length - 1, suma, luni, randament);
    }

    function retrage(uint256 index) external nonReentrant {
        Pozitie storage p = pozitii[msg.sender][index];
        if (p.retrasa) revert DejaRetrasa();
        if (block.timestamp < p.scadenta) {
            revert NuEScadenta(p.scadenta, block.timestamp);
        }

        p.retrasa = true;
        uint256 total = uint256(p.principal) + p.randamentRezervat;

        totalPrincipal -= p.principal;
        randamentAngajat -= p.randamentRezervat;

        token.safeTransfer(msg.sender, total);
        emit Retras(msg.sender, index, total);
    }

    function retrageAnticipat(uint256 index) external nonReentrant {
        Pozitie storage p = pozitii[msg.sender][index];
        if (p.retrasa) revert DejaRetrasa();
        if (block.timestamp >= p.scadenta) revert DejaScadenta();

        p.retrasa = true;

        uint256 principal = p.principal;
        uint256 penalizare = (principal * penalizareBps) / BPS;
        uint256 catreUtilizator = principal - penalizare;

        totalPrincipal -= principal;
        // Randamentul rezervat se elibereaza: nu mai e datorat.
        randamentAngajat -= p.randamentRezervat;

        token.safeTransfer(msg.sender, catreUtilizator);
        if (penalizare > 0 && trezorerie != address(0)) {
            token.safeTransfer(trezorerie, penalizare);
        }

        emit RetrasAnticipat(msg.sender, index, catreUtilizator, penalizare);
    }

    function numarPozitii(address cont) external view returns (uint256) {
        return pozitii[cont].length;
    }

    // --- guvernanta ---
    function setApy(uint256 apyBps_) external onlyRole(GUVERNANTA) {
        if (apyBps_ > MAX_APY_BPS) revert ApyPestePlafon();
        apyBps = apyBps_;
    }

    function setTrezorerie(address t) external onlyRole(GUVERNANTA) {
        trezorerie = t;
    }
}
