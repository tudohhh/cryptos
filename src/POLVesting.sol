// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title POLVesting — eliberare graduala, cu cliff
/// @notice DOAR TESTNET. Vezi README.md.
///
/// DIFERENTE FATA DE SPECIFICATIE (docs/ABATERI.md):
///
///  1. `revoked` exista in specificatie ca flag, dar nicio functie nu-l
///     setea si nu se spunea ce se intampla cu tokenii revocati. Aici:
///     revocarea e definitiva, ce s-a maturizat deja ramane al
///     beneficiarului, restul se intoarce la trezorerie. Un vesting care
///     poate fi revocat retroactiv nu e vesting.
///
///  2. Un beneficiar poate avea mai multe grafice. In specificatie,
///     `vestingSchedules[beneficiary] = schedule` STERGEA graficul anterior:
///     a doua alocare pentru aceeasi persoana ii pierdea prima.
contract POLVesting {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    address public trezorerie;
    address public administrator;

    struct Grafic {
        uint128 total;
        uint128 eliberat;
        uint64 inceput;
        uint64 cliff;
        uint64 durata;
        bool revocat;
    }

    mapping(address => Grafic[]) public grafice;
    uint256 public totalBlocat;

    event GraficCreat(address indexed beneficiar, uint256 index, uint256 total, uint256 durata);
    event Eliberat(address indexed beneficiar, uint256 index, uint256 suma);
    event Revocat(address indexed beneficiar, uint256 index, uint256 returnat);

    error NuEAdministrator();
    error NimicDeEliberat();
    error DejaRevocat();
    error SumaZero();
    error CliffPesteDurata();

    modifier doarAdmin() {
        if (msg.sender != administrator) revert NuEAdministrator();
        _;
    }

    constructor(address token_, address administrator_, address trezorerie_) {
        token = IERC20(token_);
        administrator = administrator_;
        trezorerie = trezorerie_;
    }

    function creeazaGrafic(address beneficiar, uint128 total, uint64 cliff, uint64 durata)
        external
        doarAdmin
        returns (uint256 index)
    {
        if (total == 0) revert SumaZero();
        if (cliff > durata) revert CliffPesteDurata();

        token.safeTransferFrom(msg.sender, address(this), total);
        totalBlocat += total;

        grafice[beneficiar].push(
            Grafic({
                total: total,
                eliberat: 0,
                inceput: uint64(block.timestamp),
                cliff: cliff,
                durata: durata,
                revocat: false
            })
        );

        index = grafice[beneficiar].length - 1;
        emit GraficCreat(beneficiar, index, total, durata);
    }

    /// @notice Cat s-a maturizat pana acum dintr-un grafic.
    function maturizat(address beneficiar, uint256 index) public view returns (uint256) {
        Grafic storage g = grafice[beneficiar][index];
        if (block.timestamp < g.inceput + g.cliff) return 0;
        uint256 scurs = block.timestamp - g.inceput;
        if (scurs >= g.durata) return g.total;
        return (uint256(g.total) * scurs) / g.durata;
    }

    function elibereaza(uint256 index) external {
        Grafic storage g = grafice[msg.sender][index];
        uint256 disponibil = maturizat(msg.sender, index) - g.eliberat;
        if (disponibil == 0) revert NimicDeEliberat();

        g.eliberat += uint128(disponibil);
        totalBlocat -= disponibil;

        token.safeTransfer(msg.sender, disponibil);
        emit Eliberat(msg.sender, index, disponibil);
    }

    /// @dev Ce s-a maturizat deja RAMANE al beneficiarului. Doar partea
    ///      nematurizata se intoarce.
    function revoca(address beneficiar, uint256 index) external doarAdmin {
        Grafic storage g = grafice[beneficiar][index];
        if (g.revocat) revert DejaRevocat();

        uint256 castigat = maturizat(beneficiar, index);
        uint256 nematurizat = uint256(g.total) - castigat;

        g.revocat = true;
        g.total = uint128(castigat); // graficul se opreste aici
        g.durata = uint64(block.timestamp - g.inceput);
        if (g.durata == 0) g.durata = 1;

        if (nematurizat > 0) {
            totalBlocat -= nematurizat;
            token.safeTransfer(trezorerie, nematurizat);
        }

        emit Revocat(beneficiar, index, nematurizat);
    }

    function numarGrafice(address beneficiar) external view returns (uint256) {
        return grafice[beneficiar].length;
    }
}
