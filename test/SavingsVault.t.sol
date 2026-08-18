// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MonedaOamenilor} from "../src/MonedaOamenilor.sol";
import {SavingsVault} from "../src/SavingsVault.sol";

contract SavingsVaultTest is Test {
    MonedaOamenilor tok;
    SavingsVault vault;

    address guv = address(0x60F);
    address ana = address(0xA1);
    address trez = address(0x7E20);

    function setUp() public {
        vm.warp(1_700_000_000);
        tok = new MonedaOamenilor(guv);
        vault = new SavingsVault(address(tok), guv);

        vm.startPrank(guv);
        tok.setDestinatii(trez, address(0x57A4));
        tok.setScutit(address(vault), true); // vault-ul e adapost, nu se erodeaza
        vault.setTrezorerie(trez);
        tok.emite(ana, 1000e18);
        tok.emite(guv, 100e18);
        // trezoreria alimenteaza rezerva de randament
        tok.approve(address(vault), 100e18);
        vault.alimenteazaRezerva(100e18);
        vm.stopPrank();
    }

    // ==============================================================
    // BUG-UL PRINCIPAL DIN SPEC: withdrawVault dadea panic la underflow
    // => fondurile ramaneau blocate permanent
    // ==============================================================
    function test_RetragereaLaScadentaChiarFunctioneaza() public {
        vm.startPrank(ana);
        tok.approve(address(vault), 100e18);
        vault.depune(100e18, 3);
        vm.stopPrank();

        skip(91 days);

        uint256 inainte = tok.balanceOf(ana);
        vm.prank(ana);
        vault.retrage(0); // in spec: panic, mereu

        assertGt(tok.balanceOf(ana), inainte, "nu s-a retras nimic");
    }

    function test_RandamentulEsteCorectSiPlatit() public {
        uint256 suma = 100e18;
        uint256 asteptat = (suma * 200 * (3 * 30 days)) / (10_000 * 365 days);

        vm.startPrank(ana);
        tok.approve(address(vault), suma);
        vault.depune(suma, 3);
        vm.stopPrank();

        skip(91 days);
        uint256 inainte = tok.balanceOf(ana);
        vm.prank(ana);
        vault.retrage(0);

        assertEq(tok.balanceOf(ana) - inainte, suma + asteptat, "randament gresit");
    }

    // ==============================================================
    // Randamentul trebuie sa fie finantat, nu promis in gol
    // ==============================================================
    function test_DepunereaERefuzataDacaRezervaNuAcopera() public {
        // rezerva e 100e18; o depunere uriasa ar cere randament peste ea
        vm.startPrank(guv);
        tok.emite(ana, 10_000_000e18);
        vm.stopPrank();

        vm.startPrank(ana);
        tok.approve(address(vault), 10_000_000e18);
        vm.expectRevert();
        vault.depune(10_000_000e18, 12);
        vm.stopPrank();
    }

    function test_PrimulCareRetrageNuGolesteRezerva() public {
        vm.startPrank(guv);
        tok.emite(address(0xB0B), 1000e18);
        vm.stopPrank();

        vm.startPrank(ana);
        tok.approve(address(vault), 500e18);
        vault.depune(500e18, 12);
        vm.stopPrank();

        vm.startPrank(address(0xB0B));
        tok.approve(address(vault), 500e18);
        vault.depune(500e18, 12);
        vm.stopPrank();

        skip(366 days);

        vm.prank(ana);
        vault.retrage(0);

        // al doilea trebuie sa poata retrage integral
        uint256 inainte = tok.balanceOf(address(0xB0B));
        vm.prank(address(0xB0B));
        vault.retrage(0);
        assertGt(tok.balanceOf(address(0xB0B)) - inainte, 500e18, "rezerva golita");
    }

    // ==============================================================
    // Vault-ul chiar protejeaza de demurrage
    // ==============================================================
    function test_FondurileDinVaultNuSuntErodate() public {
        vm.startPrank(ana);
        tok.approve(address(vault), 500e18);
        vault.depune(500e18, 12);
        vm.stopPrank();

        skip(365 days);

        // soldul vault-ului nu scade prin demurrage
        assertEq(tok.demurrageDatorat(address(vault)), 0);
    }

    // ==============================================================
    // Retragere anticipata
    // ==============================================================
    function test_PenalizareaMergeLaTrezorerie() public {
        vm.startPrank(ana);
        tok.approve(address(vault), 100e18);
        vault.depune(100e18, 6);
        vm.stopPrank();

        uint256 trezInainte = tok.balanceOf(trez);
        skip(30 days);

        vm.prank(ana);
        vault.retrageAnticipat(0);

        assertEq(tok.balanceOf(trez) - trezInainte, 10e18, "penalizare gresita");
    }

    function test_NuSePoateRetrageDeDouaOri() public {
        vm.startPrank(ana);
        tok.approve(address(vault), 100e18);
        vault.depune(100e18, 3);
        vm.stopPrank();

        skip(91 days);
        vm.prank(ana);
        vault.retrage(0);

        vm.prank(ana);
        vm.expectRevert();
        vault.retrage(0);
    }

    function test_NuSePoateRetrageInainteDeScadenta() public {
        vm.startPrank(ana);
        tok.approve(address(vault), 100e18);
        vault.depune(100e18, 3);
        vm.stopPrank();

        skip(30 days);
        vm.prank(ana);
        vm.expectRevert();
        vault.retrage(0);
    }

    function test_DurataInvalidaERespinsa() public {
        vm.startPrank(ana);
        tok.approve(address(vault), 100e18);
        vm.expectRevert();
        vault.depune(100e18, 7);
        vm.stopPrank();
    }

    // ==============================================================
    // Invarianta: contractul e mereu solvabil
    // ==============================================================
    function testFuzz_ContractulRamaneSolvabil(uint96 suma, uint8 alegere) public {
        suma = uint96(bound(suma, 1e15, 500e18));
        uint256 luni = [uint256(3), 6, 12][alegere % 3];

        vm.startPrank(ana);
        tok.approve(address(vault), suma);
        vault.depune(suma, luni);
        vm.stopPrank();

        // soldul contractului acopera mereu ce datoreaza
        assertGe(tok.balanceOf(address(vault)), vault.totalPrincipal() + vault.randamentAngajat(), "vault insolvabil");
    }
}
