// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MonedaOamenilor} from "../src/MonedaOamenilor.sol";
import {QuadraticDAO} from "../src/QuadraticDAO.sol";
import {CircuitBreaker} from "../src/CircuitBreaker.sol";
import {POLVesting} from "../src/POLVesting.sol";

/// Fluxul complet, in ordinea in care se intampla in realitate.
/// Testele unitare verifica piese; astea verifica montajul — locul unde
/// contractele corecte individual pot fi conectate gresit.
contract IntegrareTest is Test {
    MonedaOamenilor tok;
    QuadraticDAO dao;
    CircuitBreaker breaker;
    POLVesting vesting;

    address deployer = address(0xDE9);
    address gardian = address(0x6A4D);
    address trez = address(0x7E20);
    address stak = address(0x57A4);

    address ana = address(0xA1);
    address bob = address(0xB0B);
    address echipa = address(0xE41);

    function setUp() public {
        vm.warp(1_700_000_000);
        vm.startPrank(deployer);

        tok = new MonedaOamenilor(deployer);
        breaker = new CircuitBreaker(deployer);
        dao = new QuadraticDAO(address(tok), gardian);
        vesting = new POLVesting(address(tok), deployer, trez);

        tok.setScutit(address(dao), true);
        tok.setScutit(address(vesting), true);
        tok.setDestinatii(trez, stak);

        // emisiune initiala inainte de predarea rolurilor
        tok.emite(ana, 1_000_000e18);
        tok.emite(bob, 1_000_000e18);
        tok.emite(trez, 500_000e18);
        tok.emite(deployer, 100_000e18);

        tok.grantRole(tok.GUVERNANTA(), address(dao));
        vm.stopPrank();

        bytes4[] memory permise = new bytes4[](3);
        permise[0] = MonedaOamenilor.setRate.selector;
        permise[1] = MonedaOamenilor.setTaxa.selector;
        permise[2] = MonedaOamenilor.setPraguri.selector;
        vm.prank(gardian);
        dao.initializeazaPermisiuni(address(tok), permise);

        // trezoreria alimenteaza rezerva de randament
        vm.startPrank(trez);
        vm.stopPrank();
    }

    // ==============================================================
    // Ciclul complet: circulatie -> economisire -> guvernanta
    // ==============================================================
    function test_FluxComplet() public {
        // --- 1. Ana tranzactioneaza; taxa se distribuie ---
        uint256 arsInainte = tok.totalArs();
        // Relativ, nu absolut: trezoreria a trimis deja 50.000 in rezerva
        // Vault-ului la initializare.
        uint256 trezInainte = tok.balanceOf(trez);
        vm.prank(ana);
        tok.transfer(bob, 1000e18);
        assertGt(tok.totalArs(), arsInainte, "taxa nu s-a aplicat");
        assertGt(tok.balanceOf(trez), trezInainte, "trezoreria nu a primit cota");

        // --- 2. Ana devine inactiva; demurrage o erodeaza ---
        uint256 soldInainte = tok.balanceOf(ana);
        skip(100 days);
        uint256 datorat = tok.demurrageDatorat(ana);
        assertGt(datorat, 0, "inactivitatea nu costa nimic");

        tok.deconteaza(ana);
        assertEq(tok.balanceOf(ana), soldInainte - datorat, "decontare gresita");

        // --- 3. Ana se blocheaza in loc sa se erodeze ---
        // Blocare IN-PLACE: tokenii raman in contul ei. Nu exista custodie,
        // nu exista randament promis, nu exista penalizare de iesire.
        uint256 soldLaBlocare = tok.balanceOf(ana);
        vm.prank(ana);
        tok.blocheaza(uint64(block.timestamp + 300 days));

        // --- 4. Aproape un an mai tarziu, soldul e intact ---
        skip(299 days);
        assertEq(tok.balanceOf(ana), soldLaBlocare, "soldul blocat s-a erodat");
        assertEq(tok.demurrageDatorat(ana), 0, "demurrage pe sold blocat");

        // dupa expirare, poate misca din nou
        skip(2 days);
        assertFalse(tok.esteBlocat(ana));
        vm.prank(ana);
        tok.transfer(bob, 1e18);

        // --- 5. Bob propune scaderea taxei si castiga votul ---
        uint256 id = dao.propune("Scade taxa la 0.3%", address(tok), abi.encodeCall(MonedaOamenilor.setTaxa, (30)));

        vm.startPrank(bob);
        tok.approve(address(dao), type(uint256).max);
        dao.voteaza(id, 200, true);
        vm.stopPrank();

        skip(15 days);
        dao.executa(id);
        assertEq(tok.taxaTranzactie(), 30, "guvernanta nu a avut efect");

        // --- 6. Bob isi recupereaza miza ---
        uint256 inainteMiza = tok.balanceOf(bob);
        vm.prank(bob);
        dao.revendicaMiza(id);
        assertEq(tok.balanceOf(bob) - inainteMiza, 40_000, "miza nu s-a intors");
    }

    // ==============================================================
    // Predarea rolurilor: deployer-ul nu mai poate nimic
    // ==============================================================
    function test_DupaPredareDeployerNuMaiAreputere() public {
        vm.startPrank(deployer);
        tok.renounceRole(tok.GUVERNANTA(), deployer);
        tok.renounceRole(tok.EMITENT(), deployer);
        vm.stopPrank();

        vm.prank(deployer);
        vm.expectRevert();
        tok.setTaxa(500);

        vm.prank(deployer);
        vm.expectRevert();
        tok.emite(deployer, 1e30);
    }

    function test_DupaPredareDoarDAOSchimbaParametrii() public {
        vm.startPrank(deployer);
        tok.renounceRole(tok.GUVERNANTA(), deployer);
        vm.stopPrank();

        // DAO-ul, prin vot, tot poate
        uint256 id =
            dao.propune("praguri noi", address(tok), abi.encodeCall(MonedaOamenilor.setPraguri, (45 days, 120 days)));
        vm.startPrank(bob);
        tok.approve(address(dao), type(uint256).max);
        dao.voteaza(id, 200, true);
        vm.stopPrank();

        skip(15 days);
        dao.executa(id);
        assertEq(tok.pragTransa1(), 45 days, "DAO-ul nu poate guverna");
    }

    // ==============================================================
    // Conectari gresite pe care le prinde doar integrarea
    // ==============================================================
    function test_MizaDinDAONuSeErodeazaInTimpulVotarii() public {
        uint256 id = dao.propune("test", address(tok), abi.encodeCall(MonedaOamenilor.setTaxa, (40)));

        vm.startPrank(bob);
        tok.approve(address(dao), type(uint256).max);
        dao.voteaza(id, 100, true); // miza 10.000
        vm.stopPrank();

        uint256 inDao = tok.balanceOf(address(dao));
        skip(200 days); // votare lunga + timelock

        assertEq(tok.balanceOf(address(dao)), inDao, "mizele s-au topit");

        vm.prank(bob);
        dao.revendicaMiza(id);
    }

    function test_VestingulNuSeErodeaza() public {
        vm.startPrank(deployer);
        tok.approve(address(vesting), 100_000e18);
        vesting.creeazaGrafic(echipa, 100_000e18, 180 days, 730 days);
        vm.stopPrank();

        skip(400 days);
        assertEq(tok.demurrageDatorat(address(vesting)), 0, "vesting-ul s-a erodat");

        vm.prank(echipa);
        vesting.elibereaza(0);
        assertGt(tok.balanceOf(echipa), 0, "nu s-a putut elibera");
    }

    // ==============================================================
    // Conservare: nimic nu apare si nimic nu dispare nejustificat
    // ==============================================================
    function test_ConservareaValorii() public {
        uint256 supplyInitial = tok.totalSupply();
        uint256 arsInitial = tok.totalArs();

        vm.prank(ana);
        tok.transfer(bob, 10_000e18);
        skip(200 days);
        tok.deconteaza(ana);
        tok.deconteaza(bob);

        uint256 arsTotal = tok.totalArs() - arsInitial;

        // Tot ce a disparut din supply a fost ars. Nimic nu s-a evaporat.
        assertEq(tok.totalSupply(), supplyInitial - arsTotal, "supply-ul nu se reconciliaza");
    }

    function testFuzz_SupplyNuCresteNiciodataFaraEmisiune(uint96 suma, uint32 zile) public {
        suma = uint96(bound(suma, 1e15, 100_000e18));
        zile = uint32(bound(zile, 1, 2000));

        uint256 inainte = tok.totalSupply();

        vm.prank(ana);
        tok.transfer(bob, suma);
        skip(uint256(zile) * 1 days);
        tok.deconteaza(ana);
        tok.deconteaza(bob);

        assertLe(tok.totalSupply(), inainte, "supply-ul a crescut fara emisiune");
    }
}
