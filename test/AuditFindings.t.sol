// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MonedaOamenilor} from "../src/MonedaOamenilor.sol";
import {POLVesting} from "../src/POLVesting.sol";

/// Constatarile §0.4 din docs/AUDIT-JURIDIC.md.
/// Nu sunt bug-uri de executie — de-asta nu le-au prins cele 62 de teste
/// existente. Sunt discrepante intre ce afirma proiectul despre el insusi
/// si ce face codul. Fiecare test de mai jos apara o afirmatie publica.
contract AuditFindingsTest is Test {
    MonedaOamenilor tok;
    POLVesting vest;

    address guv = address(0x60F);
    address deployer = address(0xDE9);
    address ana = address(0xA1);
    address bob = address(0xB0B);
    address trez = address(0x7E20);

    function setUp() public {
        vm.warp(1_700_000_000);
        tok = new MonedaOamenilor(guv);
        vest = new POLVesting(address(tok), deployer, trez);

        vm.startPrank(guv);
        tok.setDestinatii(trez, address(0x57A4));
        tok.emite(ana, 1000e18);
        tok.emite(deployer, 100_000e18);
        vm.stopPrank();
    }

    // ==============================================================
    // §0.4.B — plafoanele nu plafonau ce credeam
    //
    // README afirma: "un vot nu trebuie sa poata confisca solduri".
    // Cu praguri de o secunda, afirmatia era falsa.
    // ==============================================================
    function test_PragurileNuPotFiCoborateSubLimita() public {
        vm.prank(guv);
        vm.expectRevert();
        tok.setPraguri(1 seconds, 2 seconds);
    }

    function test_PragulMinimEsteDeTreizeciDeZile() public {
        vm.prank(guv);
        vm.expectRevert();
        tok.setPraguri(29 days, 90 days);

        // 30 de zile trece
        vm.prank(guv);
        tok.setPraguri(30 days, 90 days);
        assertEq(tok.pragTransa1(), 30 days);
    }

    /// Reconstituie exact atacul din audit: rata maxima + praguri minime.
    /// Chiar si in cel mai rau caz permis de contract, eroziunea ramane
    /// marginita, iar primele 30 de zile raman gratuite.
    function test_CelMaiRauVotPosibilNuConfisca() public {
        vm.startPrank(guv);
        tok.setRate(1000, 1000); // 10% / 30 zile, maximul
        tok.setPraguri(30 days, 31 days); // minimul permis acum
        vm.stopPrank();

        vm.prank(ana);
        tok.transfer(bob, 1e18);
        uint256 sold = tok.balanceOf(ana);

        skip(30 days);
        assertEq(tok.demurrageDatorat(ana), 0, "taxat in perioada de gratie");

        skip(30 days); // 60 de zile totale
        uint256 datorat = tok.demurrageDatorat(ana);
        assertLt(datorat, sold / 2, "un singur vot a confiscat jumatate din sold");
    }

    // ==============================================================
    // §0.4.C — fondatorul ramanea administrator perpetuu al POLVesting
    //
    // Deploy.s.sol afisa "Deployer-ul nu mai are putere", ceea ce era
    // factual fals: POLVesting nu aparea deloc in predarea rolurilor,
    // iar contractul nu avea nicio functie de transfer al administrarii.
    // ==============================================================
    function test_AdministrareaVestinguluiPoateFiPredata() public {
        address dao = address(0xDA0);

        vm.prank(deployer);
        vest.setAdministrator(dao);

        assertEq(vest.administrator(), dao, "predarea nu a functionat");

        // fostul administrator nu mai poate nimic
        vm.prank(deployer);
        vm.expectRevert();
        vest.creeazaGrafic(ana, 1000e18, 30 days, 365 days);
    }

    function test_DoarAdministratorulActualPredaMaiDeparte() public {
        vm.prank(ana);
        vm.expectRevert();
        vest.setAdministrator(ana);
    }

    function test_AdministrareaNuSePierdeDinGreseala() public {
        vm.prank(deployer);
        vm.expectRevert();
        vest.setAdministrator(address(0));
    }

    // ==============================================================
    // §0.4.A — demurrage-ul e evitabil prin auto-transfer
    //
    // Testul asta DOCUMENTEAZA comportamentul, nu il repara. Repararea
    // schimba modelul economic si e o decizie a fondatorului, nu a mea.
    // Vezi docs/EVAZIUNE-DEMURRAGE.md pentru variante.
    //
    // Cat timp comportamentul exista, el trebuie sa fie DECLARAT. Un
    // white paper care spune "detinatorii inactivi platesc demurrage" e
    // fals la litera: detinatorii NEINFORMATI platesc demurrage.
    // ==============================================================
    function test_DOCUMENTAT_DemurrageEvitabilPrinAutoTransfer() public {
        vm.prank(ana);
        tok.transfer(bob, 1e18); // porneste ceasul

        uint256 sold = tok.balanceOf(ana);

        // 12 luni de "activitate" simbolica: 0.9 tokeni catre sine insusi,
        // la fiecare 29 de zile. Sub pragMicroTx, deci nici taxa nu se aplica.
        for (uint256 i = 0; i < 12; i++) {
            skip(29 days);
            vm.prank(ana);
            tok.transfer(ana, 0.9e18);
        }

        assertEq(tok.balanceOf(ana), sold, "AICI E CONSTATAREA: un an intreg, zero demurrage, zero taxe");

        // Comparatie: cine nu stie trucul plateste.
        uint256 soldBob = tok.balanceOf(bob);
        assertGt(tok.demurrageDatorat(bob), 0, "utilizatorul pasiv plateste");
        console.log("Sold ana (informata):", tok.balanceOf(ana) / 1e18);
        console.log("Datorat bob (neinformat):", tok.demurrageDatorat(bob) / 1e18);
        assertGt(soldBob, 0);
    }
}
