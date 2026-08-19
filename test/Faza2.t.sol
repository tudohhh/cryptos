// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MonedaOamenilor} from "../src/MonedaOamenilor.sol";
import {CircuitBreaker} from "../src/CircuitBreaker.sol";
import {SessionKeysManager} from "../src/SessionKeysManager.sol";

/// Faza 2 din docs/AUDIT-JURIDIC.md §6.2.
contract Faza2Test is Test {
    MonedaOamenilor tok;
    address guv = address(0x60F);
    address ana = address(0xA1);
    address bob = address(0xB0B);

    function setUp() public {
        vm.warp(1_700_000_000);
        tok = new MonedaOamenilor(guv);
        vm.startPrank(guv);
        tok.setDestinatii(address(0x7E20), address(0x57A4));
        tok.emite(ana, 1000e18);
        tok.emite(bob, 1000e18);
        vm.stopPrank();
    }

    // ==============================================================
    // §2.3 — blocare in-place: tokenii NU pleaca nicaieri
    // ==============================================================
    function test_TokeniiRamanInContulUtilizatorului() public {
        uint256 sold = tok.balanceOf(ana);

        vm.prank(ana);
        tok.blocheaza(uint64(block.timestamp + 90 days));

        // AICI E DIFERENTA fata de Vault-ul custodial: balanceOf neschimbat.
        // Utilizatorul e proprietar cu restrictie, nu creditor.
        assertEq(tok.balanceOf(ana), sold, "tokenii au parasit contul");
        assertTrue(tok.esteBlocat(ana));
    }

    function test_SoldulBlocatNuPoateIesi() public {
        vm.startPrank(ana);
        tok.blocheaza(uint64(block.timestamp + 90 days));
        vm.expectRevert();
        tok.transfer(bob, 1e18);
        vm.stopPrank();
    }

    function test_SoldulBlocatNuIeseNiciPrinTransferFrom() public {
        vm.startPrank(ana);
        tok.approve(bob, 100e18);
        tok.blocheaza(uint64(block.timestamp + 90 days));
        vm.stopPrank();

        vm.prank(bob);
        vm.expectRevert();
        tok.transferFrom(ana, bob, 100e18);
    }

    function test_BlocareaScutesteDeDemurrage() public {
        vm.prank(ana);
        tok.transfer(bob, 1e18);
        uint256 sold = tok.balanceOf(ana);

        vm.prank(ana);
        tok.blocheaza(uint64(block.timestamp + 300 days));

        skip(200 days);
        assertEq(tok.demurrageDatorat(ana), 0, "soldul blocat s-a erodat");
        assertEq(tok.balanceOf(ana), sold, "sold modificat");
    }

    function test_DupaExpirareSoldulSeElibereaza() public {
        vm.prank(ana);
        tok.blocheaza(uint64(block.timestamp + 30 days));
        skip(31 days);

        assertFalse(tok.esteBlocat(ana));
        vm.prank(ana);
        tok.transfer(bob, 1e18); // trebuie sa mearga
    }

    /// Nu exista iesire anticipata, deci nu exista penalizare de 10% pe
    /// principal. Problema clauzei abuzive dispare de la sine.
    function test_NuExistaIesireAnticipata() public {
        vm.startPrank(ana);
        tok.blocheaza(uint64(block.timestamp + 90 days));
        // nu exista nicio functie de deblocare; doar prelungire
        vm.expectRevert();
        tok.blocheaza(uint64(block.timestamp + 1 days));
        vm.stopPrank();
    }

    function test_BlocareaNuPoateDepasiUnAn() public {
        vm.prank(ana);
        vm.expectRevert();
        tok.blocheaza(uint64(block.timestamp + 400 days));
    }

    /// Cine e deja inactiv de 6 luni nu scapa de ce datoreaza blocandu-se.
    function test_BlocareaNuStergeDemurrageAcumulat() public {
        vm.prank(ana);
        tok.transfer(bob, 1e18);
        skip(180 days);

        uint256 datorat = tok.demurrageDatorat(ana);
        assertGt(datorat, 0);
        uint256 sold = tok.balanceOf(ana);

        vm.prank(ana);
        tok.blocheaza(uint64(block.timestamp + 90 days));

        assertEq(tok.balanceOf(ana), sold - datorat, "a scapat de datorie");
    }

    // ==============================================================
    // §6.1 — CircuitBreaker: repornirea nu poate fi mai grea decat oprirea
    // ==============================================================
    function test_AnulareaTrebuieSaFieMaiUsoaraDecatDeclansarea() public {
        CircuitBreaker cb = new CircuitBreaker(guv);
        vm.prank(guv);
        vm.expectRevert();
        cb.setPraguri(3, 5); // anulare mai grea decat declansarea: DoS permanent

        vm.prank(guv);
        cb.setPraguri(3, 2); // corect
        assertEq(cb.pragAnulare(), 2);
    }

    function test_LimitaZilnicaDeInghetari() public {
        CircuitBreaker cb = new CircuitBreaker(guv);
        address[3] memory o = [address(0x1), address(0x2), address(0x3)];
        vm.startPrank(guv);
        for (uint256 i = 0; i < 3; i++) {
            cb.grantRole(cb.ORACOL(), o[i]);
        }
        vm.stopPrank();

        // 3 inghetari permise pe zi. Fara skip: ramanem in aceeasi zi.
        for (uint256 r = 0; r < 3; r++) {
            bytes32 h = keccak256(abi.encode("raport", r));
            for (uint256 i = 0; i < 3; i++) {
                vm.prank(o[i]);
                cb.atesta(h);
            }
        }

        // a patra, in aceeasi zi: refuzata
        bytes32 h4 = keccak256("raport4");
        vm.prank(o[0]);
        cb.atesta(h4);
        vm.prank(o[1]);
        cb.atesta(h4);
        vm.prank(o[2]);
        vm.expectRevert();
        cb.atesta(h4);
    }

    // ==============================================================
    // §6.1 — SessionKeys: permisiunile mor la revocare
    // ==============================================================
    function test_DestinatariiNuSupravietuiescRevocarii() public {
        SessionKeysManager skm = new SessionKeysManager(address(tok));
        address agent = address(0xA6E7);
        address magazin = address(0x5409);

        address[] memory dest = new address[](1);
        dest[0] = magazin;

        vm.startPrank(ana);
        skm.creeazaCheie(agent, 100e18, 1000e18, 5, 30 days, dest);
        uint256 v1 = skm.versiuneCheie(ana, agent);
        assertTrue(skm.destinatarPermis(ana, agent, v1, magazin));

        skm.revoca(agent);

        // cheie noua, FARA destinatari: vechiul magazin nu mai e autorizat
        address[] memory gol = new address[](0);
        skm.creeazaCheie(agent, 100e18, 1000e18, 5, 30 days, gol);
        uint256 v2 = skm.versiuneCheie(ana, agent);
        vm.stopPrank();

        assertGt(v2, v1, "versiunea nu a crescut");
        assertFalse(skm.destinatarPermis(ana, agent, v2, magazin), "destinatarul vechi a supravietuit revocarii");
    }
}
