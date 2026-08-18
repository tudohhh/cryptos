// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MonedaOamenilor} from "../src/MonedaOamenilor.sol";

/// Teste care reproduc bug-urile din specificatia initiala.
/// Fiecare are numele bug-ului pe care il apara, ca sa nu reapara la refactor.
contract MonedaOamenilorTest is Test {
    MonedaOamenilor tok;

    address guv = address(0x60F);
    address ana = address(0xA1);
    address bob = address(0xB0B);
    address trez = address(0x7E20);
    address stak = address(0x57A4);

    function setUp() public {
        vm.warp(1_700_000_000); // timp realist, nu 1
        tok = new MonedaOamenilor(guv);
        vm.startPrank(guv);
        tok.setDestinatii(trez, stak);
        tok.emite(ana, 1000e18);
        tok.emite(bob, 1000e18);
        vm.stopPrank();
    }

    // ==============================================================
    // BUG 1 din spec: primul transfer al unui cont nou ii ardea tot
    // ==============================================================
    function test_ContNouNuEsteTaxat() public {
        address nou = address(0x9E0);
        vm.prank(guv);
        tok.emite(nou, 100e18);

        assertEq(tok.demurrageDatorat(nou), 0, "cont nou taxat");

        vm.prank(nou);
        tok.transfer(bob, 50e18);

        // 0.5% taxa pe 50 => 0.25. Sold 100 - 50 = 50, fara demurrage.
        assertEq(tok.balanceOf(nou), 50e18, "soldul contului nou a fost erodat");
    }

    // ==============================================================
    // BUG 2 din spec: rata transei 2 aplicata retroactiv pe tot intervalul
    // ==============================================================
    function test_DemurrageSeCalculeazaPeTranse() public {
        vm.prank(ana);
        tok.transfer(bob, 1e18); // porneste ceasul

        uint256 sold = tok.balanceOf(ana);
        skip(100 days);

        // Asteptat: 0% pe 30z + 1% pe 60z + 2.5% pe 10z
        uint256 asteptat = (sold * 100 * 60 days) / (10_000 * 30 days) + (sold * 250 * 10 days) / (10_000 * 30 days);

        assertEq(tok.demurrageDatorat(ana), asteptat, "calcul pe transe gresit");

        // Varianta din spec (2.5% pe toate 100 de zile) ar fi dat mult mai mult
        uint256 variantaSpec = (sold * 250 * 100 days) / (10_000 * 30 days);
        assertLt(tok.demurrageDatorat(ana), variantaSpec, "taxeaza retroactiv");
    }

    // ==============================================================
    // BUG 3 din spec: demurrage putea depasi soldul => revert permanent
    // ==============================================================
    function test_DemurrageNuDepasesteNiciodataSoldul() public {
        vm.prank(ana);
        tok.transfer(bob, 1e18);

        skip(4000 days); // ~11 ani de inactivitate

        uint256 sold = tok.balanceOf(ana);
        assertLe(tok.demurrageDatorat(ana), sold, "datoreaza mai mult decat are");

        // Si decontarea chiar trece, nu da revert
        tok.deconteaza(ana);
        assertEq(tok.balanceOf(ana), 0, "ar trebui erodat complet, fara revert");
    }

    // ==============================================================
    // BUG 4 din spec: transferFrom ocolea complet demurrage-ul si taxele
    // ==============================================================
    function test_TransferFromNuOcolesteTaxa() public {
        vm.prank(ana);
        tok.approve(bob, 100e18);

        uint256 arsInainte = tok.totalArs();

        vm.prank(bob);
        tok.transferFrom(ana, bob, 100e18);

        assertGt(tok.totalArs(), arsInainte, "transferFrom a ocolit taxa");
    }

    function test_TransferFromDeclanseazaDemurrage() public {
        vm.prank(ana);
        tok.transfer(bob, 1e18);
        skip(60 days);

        vm.prank(ana);
        tok.approve(bob, 10e18);

        uint256 datorat = tok.demurrageDatorat(ana);
        assertGt(datorat, 0, "ar trebui sa datoreze ceva");

        vm.prank(bob);
        tok.transferFrom(ana, bob, 10e18);

        assertEq(tok.demurrageDatorat(ana), 0, "demurrage nedecontat");
    }

    // ==============================================================
    // Impartirea 33/33/34 — suma partilor trebuie sa fie EXACTA
    // ==============================================================
    function test_ImpartireaNuPierdeWei() public {
        vm.prank(ana);
        tok.transfer(bob, 1e18);
        skip(60 days);

        uint256 datorat = tok.demurrageDatorat(ana);
        uint256 arsInainte = tok.totalArs();
        uint256 trezInainte = tok.balanceOf(trez);
        uint256 stakInainte = tok.balanceOf(stak);

        tok.deconteaza(ana);

        uint256 ars = tok.totalArs() - arsInainte;
        uint256 laTrez = tok.balanceOf(trez) - trezInainte;
        uint256 laStak = tok.balanceOf(stak) - stakInainte;

        assertEq(ars + laTrez + laStak, datorat, "s-au pierdut wei la impartire");
    }

    // ==============================================================
    // Vault-ul trebuie sa fie adapost real de demurrage
    // ==============================================================
    function test_AdreseleScutiteNuSuntErodate() public {
        vm.prank(guv);
        tok.emite(trez, 500e18);

        skip(365 days);

        assertEq(tok.demurrageDatorat(trez), 0, "trezoreria e erodata");
        assertEq(tok.balanceOf(trez), 500e18);
    }

    // ==============================================================
    // Guvernanta nu poate confisca prin parametri
    // ==============================================================
    function test_GuvernantaNuPoateSetaRataConfiscatoare() public {
        vm.prank(guv);
        vm.expectRevert();
        tok.setRate(5000, 5000); // 50% pe luna

        vm.prank(guv);
        vm.expectRevert();
        tok.setTaxa(9000); // 90% taxa
    }

    function test_DoarGuvernantaSchimbaParametrii() public {
        vm.prank(ana);
        vm.expectRevert();
        tok.setRate(100, 200);
    }

    // ==============================================================
    // Micro-tranzactiile raman fara taxa
    // ==============================================================
    function test_MicroTranzactiileNuSuntTaxate() public {
        vm.prank(ana);
        tok.transfer(bob, 1e18); // porneste ceasul, fara skip

        uint256 arsInainte = tok.totalArs();
        vm.prank(ana);
        tok.transfer(bob, 0.5e18); // sub prag

        assertEq(tok.totalArs(), arsInainte, "micro-tranzactie taxata");
    }

    // ==============================================================
    // Fuzz: demurrage nu depaseste soldul, pentru orice sold si durata
    // ==============================================================
    function testFuzz_DemurrageMereuSubSold(uint96 sold, uint32 zile) public {
        sold = uint96(bound(sold, 1e12, type(uint96).max));
        zile = uint32(bound(zile, 0, 10_000));

        address u = address(0xF02);
        vm.prank(guv);
        tok.emite(u, sold);

        vm.prank(u);
        tok.transfer(bob, 1); // porneste ceasul

        skip(uint256(zile) * 1 days);

        uint256 datorat = tok.demurrageDatorat(u);
        assertLe(datorat, tok.balanceOf(u), "demurrage peste sold");

        // si decontarea nu da revert, oricare ar fi valorile
        tok.deconteaza(u);
    }
}
