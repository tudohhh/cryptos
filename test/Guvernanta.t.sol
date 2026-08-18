// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MonedaOamenilor} from "../src/MonedaOamenilor.sol";
import {QuadraticDAO} from "../src/QuadraticDAO.sol";
import {CircuitBreaker} from "../src/CircuitBreaker.sol";
import {SessionKeysManager} from "../src/SessionKeysManager.sol";
import {POLVesting} from "../src/POLVesting.sol";

// ==================================================================
// DAO
// ==================================================================
contract QuadraticDAOTest is Test {
    MonedaOamenilor tok;
    QuadraticDAO dao;

    address guv = address(0x60F);
    address gardian = address(0x6A4D);
    address ana = address(0xA1);
    address bob = address(0xB0B);

    function setUp() public {
        vm.warp(1_700_000_000);
        tok = new MonedaOamenilor(guv);
        dao = new QuadraticDAO(address(tok), gardian);

        vm.startPrank(guv);
        tok.setScutit(address(dao), true); // mizele nu se erodeaza
        tok.emite(ana, 1_000_000e18);
        tok.emite(bob, 1_000_000e18);
        tok.grantRole(tok.GUVERNANTA(), address(dao));
        vm.stopPrank();

        bytes4[] memory sel = new bytes4[](1);
        sel[0] = MonedaOamenilor.setTaxa.selector;
        vm.prank(gardian);
        dao.initializeazaPermisiuni(address(tok), sel);
    }

    function _propune() internal returns (uint256) {
        return dao.propune("Scade taxa la 0.3%", address(tok), abi.encodeCall(MonedaOamenilor.setTaxa, (30)));
    }

    // ==============================================================
    // BUG PRINCIPAL DIN SPEC: mizele nu se recuperau niciodata
    // ==============================================================
    function test_MizaSeRecupereazaDupaVot() public {
        uint256 id = _propune();

        uint256 inainte = tok.balanceOf(ana);
        vm.startPrank(ana);
        tok.approve(address(dao), 100e18);
        dao.voteaza(id, 10, true); // miza = 100
        vm.stopPrank();

        assertEq(tok.balanceOf(ana), inainte - 100, "miza nu s-a blocat");

        skip(8 days);
        vm.prank(ana);
        dao.revendicaMiza(id);

        assertEq(tok.balanceOf(ana), inainte, "miza nu s-a recuperat");
    }

    function test_MizaNuSePoateRevendicaDeDouaOri() public {
        uint256 id = _propune();
        vm.startPrank(ana);
        tok.approve(address(dao), 100e18);
        dao.voteaza(id, 10, true);
        vm.stopPrank();

        skip(8 days);
        vm.prank(ana);
        dao.revendicaMiza(id);
        vm.prank(ana);
        vm.expectRevert();
        dao.revendicaMiza(id);
    }

    function test_MizaNuSePoateRevendicaInTimpulVotarii() public {
        uint256 id = _propune();
        vm.startPrank(ana);
        tok.approve(address(dao), 100e18);
        dao.voteaza(id, 10, true);
        vm.expectRevert();
        dao.revendicaMiza(id);
        vm.stopPrank();
    }

    // ==============================================================
    // Costul cuadratic
    // ==============================================================
    function test_CostulEstePatratulPuterii() public {
        uint256 id = _propune();
        uint256 inainte = tok.balanceOf(ana);

        vm.startPrank(ana);
        tok.approve(address(dao), 10_000e18);
        dao.voteaza(id, 100, true);
        vm.stopPrank();

        assertEq(inainte - tok.balanceOf(ana), 10_000, "cost != putere^2");
    }

    // ==============================================================
    // Executie
    // ==============================================================
    function test_PropunereaAcceptataChiarExecuta() public {
        uint256 id = _propune();

        vm.startPrank(ana);
        tok.approve(address(dao), type(uint256).max);
        dao.voteaza(id, 200, true); // 200 > cvorum 100
        vm.stopPrank();

        skip(15 days); // dupa votare + timelock
        dao.executa(id);

        assertEq(tok.taxaTranzactie(), 30, "propunerea nu a avut efect");
    }

    function test_TimelockulChiarBlocheaza() public {
        uint256 id = _propune();
        vm.startPrank(ana);
        tok.approve(address(dao), type(uint256).max);
        dao.voteaza(id, 200, true);
        vm.stopPrank();

        skip(8 days); // votare inchisa, timelock inca activ
        vm.expectRevert();
        dao.executa(id);
    }

    function test_CvorumNeatinsBlocheazaExecutia() public {
        uint256 id = _propune();
        vm.startPrank(ana);
        tok.approve(address(dao), type(uint256).max);
        dao.voteaza(id, 5, true); // sub cvorum
        vm.stopPrank();

        skip(15 days);
        vm.expectRevert();
        dao.executa(id);
    }

    function test_PropunereaRespinsaNuExecuta() public {
        uint256 id = _propune();
        vm.startPrank(ana);
        tok.approve(address(dao), type(uint256).max);
        dao.voteaza(id, 100, true);
        vm.stopPrank();
        vm.startPrank(bob);
        tok.approve(address(dao), type(uint256).max);
        dao.voteaza(id, 150, false);
        vm.stopPrank();

        skip(15 days);
        vm.expectRevert();
        dao.executa(id);
    }

    // ==============================================================
    // Lista alba
    // ==============================================================
    function test_NuSePoateChemaOriceContract() public {
        vm.expectRevert();
        dao.propune("rau", address(tok), abi.encodeCall(MonedaOamenilor.emite, (ana, 1e30)));
    }

    function test_GardianulPoateAnulaDarNuExecuta() public {
        uint256 id = _propune();
        vm.startPrank(ana);
        tok.approve(address(dao), type(uint256).max);
        dao.voteaza(id, 200, true);
        vm.stopPrank();

        vm.prank(gardian);
        dao.anuleaza(id);

        skip(15 days);
        vm.expectRevert();
        dao.executa(id);
    }

    function test_MizaSeRecupereazaSiDupaAnulare() public {
        uint256 id = _propune();
        uint256 inainte = tok.balanceOf(ana);
        vm.startPrank(ana);
        tok.approve(address(dao), 100e18);
        dao.voteaza(id, 10, true);
        vm.stopPrank();

        vm.prank(gardian);
        dao.anuleaza(id);

        vm.prank(ana);
        dao.revendicaMiza(id);
        assertEq(tok.balanceOf(ana), inainte, "miza pierduta la anulare");
    }

    function test_NuSeVoteazaDeDouaOri() public {
        uint256 id = _propune();
        vm.startPrank(ana);
        tok.approve(address(dao), type(uint256).max);
        dao.voteaza(id, 10, true);
        vm.expectRevert();
        dao.voteaza(id, 10, true);
        vm.stopPrank();
    }
}

// ==================================================================
// CircuitBreaker
// ==================================================================
contract CircuitBreakerTest is Test {
    CircuitBreaker cb;
    address guv = address(0x60F);
    address[5] oracoli = [address(0x01), address(0x02), address(0x03), address(0x04), address(0x05)];

    bytes32 raport = keccak256("velocity_drop_45pct_2026-08-18");

    function setUp() public {
        vm.warp(1_700_000_000);
        cb = new CircuitBreaker(guv);
        vm.startPrank(guv);
        for (uint256 i = 0; i < 5; i++) {
            cb.grantRole(cb.ORACOL(), oracoli[i]);
        }
        vm.stopPrank();
    }

    // ==============================================================
    // BUG DIN SPEC: o singura adresa putea ingheta trezoreria
    // ==============================================================
    function test_UnSingurOracolNuPoateIngheta() public {
        vm.prank(oracoli[0]);
        cb.atesta(raport);
        assertFalse(cb.esteInghetat(), "un singur oracol a inghetat protocolul");

        vm.prank(oracoli[1]);
        cb.atesta(raport);
        assertFalse(cb.esteInghetat(), "doi oracoli au inghetat protocolul");
    }

    function test_TreiOracoliInghetata() public {
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(oracoli[i]);
            cb.atesta(raport);
        }
        assertTrue(cb.esteInghetat(), "pragul de 3 nu a declansat");
    }

    function test_AcelasiOracolNuAtestaDeDouaOri() public {
        vm.prank(oracoli[0]);
        cb.atesta(raport);
        vm.prank(oracoli[0]);
        vm.expectRevert();
        cb.atesta(raport);
    }

    function test_AtestariPeRapoarteDiferiteNuSeAduna() public {
        vm.prank(oracoli[0]);
        cb.atesta(keccak256("raport_A"));
        vm.prank(oracoli[1]);
        cb.atesta(keccak256("raport_B"));
        vm.prank(oracoli[2]);
        cb.atesta(keccak256("raport_C"));
        assertFalse(cb.esteInghetat(), "rapoarte diferite s-au combinat");
    }

    // ==============================================================
    // BUG DIN SPEC: inghetarea putea ramane la nesfarsit
    // ==============================================================
    function test_InghetareaExpiraSingura() public {
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(oracoli[i]);
            cb.atesta(raport);
        }
        assertTrue(cb.esteInghetat());

        skip(7 hours); // durataInghetare = 6h
        assertFalse(cb.esteInghetat(), "trezoreria a ramas inghetata la nesfarsit");
    }

    function test_AtestarileVechiExpira() public {
        vm.prank(oracoli[0]);
        cb.atesta(raport);

        skip(2 hours); // fereastraAtestare = 1h

        vm.prank(oracoli[1]);
        vm.expectRevert();
        cb.atesta(raport);
    }

    function test_ValidatoriiPotAnula() public {
        vm.startPrank(guv);
        for (uint256 i = 0; i < 5; i++) {
            cb.grantRole(cb.VALIDATOR(), oracoli[i]);
        }
        vm.stopPrank();

        for (uint256 i = 0; i < 3; i++) {
            vm.prank(oracoli[i]);
            cb.atesta(raport);
        }
        assertTrue(cb.esteInghetat());

        for (uint256 i = 0; i < 5; i++) {
            vm.prank(oracoli[i]);
            cb.voteazaAnulare(raport);
        }
        assertFalse(cb.esteInghetat(), "validatorii nu au putut anula");
    }

    function test_NeoracolNuPoateAtesta() public {
        vm.prank(address(0xBAD));
        vm.expectRevert();
        cb.atesta(raport);
    }
}

// ==================================================================
// SessionKeys
// ==================================================================
contract SessionKeysTest is Test {
    MonedaOamenilor tok;
    SessionKeysManager skm;

    address guv = address(0x60F);
    uint256 anaPk = 0xA11CE;
    address ana;
    address agent = address(0xA6E7);
    address magazin = address(0x5409);

    function setUp() public {
        vm.warp(1_700_000_000);
        ana = vm.addr(anaPk);
        tok = new MonedaOamenilor(guv);
        skm = new SessionKeysManager(address(tok));

        vm.startPrank(guv);
        tok.emite(ana, 10_000e18);
        vm.stopPrank();

        address[] memory dest = new address[](1);
        dest[0] = magazin;

        vm.startPrank(ana);
        tok.approve(address(skm), type(uint256).max);
        skm.creeazaCheie(agent, 100e18, 1000e18, 5, 30 days, dest);
        vm.stopPrank();
    }

    function _semneaza(address destinatar, uint256 suma, uint256 nonce, uint256 deadline)
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = skm.digestPentru(ana, agent, destinatar, suma, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(anaPk, digest);
        return abi.encodePacked(r, s, v);
    }

    // ==============================================================
    // BUG PRINCIPAL DIN SPEC: verifySignature returna `true`
    // ==============================================================
    function test_AgentulNuPoateExecutaFaraSemnatura() public {
        bytes memory semnaturaFalsa = new bytes(65);
        vm.prank(agent);
        vm.expectRevert();
        skm.executa(ana, magazin, 50e18, 1, block.timestamp + 1 hours, semnaturaFalsa);
    }

    function test_SemnaturaAltcuivaERespinsa() public {
        uint256 altPk = 0xBAD;
        bytes32 digest = skm.digestPentru(ana, agent, magazin, 50e18, 1, block.timestamp + 1 hours);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(altPk, digest);

        vm.prank(agent);
        vm.expectRevert();
        skm.executa(ana, magazin, 50e18, 1, block.timestamp + 1 hours, abi.encodePacked(r, s, v));
    }

    function test_ExecutieValidaCuSemnatura() public {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _semneaza(magazin, 50e18, 1, deadline);

        vm.prank(agent);
        skm.executa(ana, magazin, 50e18, 1, deadline, sig);

        assertGt(tok.balanceOf(magazin), 0, "transferul nu s-a facut");
    }

    // ==============================================================
    // BUG DIN SPEC: aceeasi semnatura se putea rejuca la infinit
    // ==============================================================
    function test_SemnaturaNuSePoateRejuca() public {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _semneaza(magazin, 50e18, 1, deadline);

        vm.prank(agent);
        skm.executa(ana, magazin, 50e18, 1, deadline, sig);

        vm.prank(agent);
        vm.expectRevert();
        skm.executa(ana, magazin, 50e18, 1, deadline, sig);
    }

    function test_SemnaturaExpiraDupaDeadline() public {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _semneaza(magazin, 50e18, 1, deadline);

        skip(2 hours);
        vm.prank(agent);
        vm.expectRevert();
        skm.executa(ana, magazin, 50e18, 1, deadline, sig);
    }

    function test_DestinatarNepermisERespins() public {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _semneaza(address(0xDEAD), 50e18, 1, deadline);

        vm.prank(agent);
        vm.expectRevert();
        skm.executa(ana, address(0xDEAD), 50e18, 1, deadline, sig);
    }

    function test_PlafonulPeOperatiuneSeRespecta() public {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _semneaza(magazin, 200e18, 1, deadline); // plafon 100

        vm.prank(agent);
        vm.expectRevert();
        skm.executa(ana, magazin, 200e18, 1, deadline, sig);
    }

    function test_RevocareaOpresteAgentul() public {
        vm.prank(ana);
        skm.revoca(agent);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _semneaza(magazin, 50e18, 1, deadline);
        vm.prank(agent);
        vm.expectRevert();
        skm.executa(ana, magazin, 50e18, 1, deadline, sig);
    }
}

// ==================================================================
// POLVesting
// ==================================================================
contract POLVestingTest is Test {
    MonedaOamenilor tok;
    POLVesting vest;

    address guv = address(0x60F);
    address trez = address(0x7E20);
    address echipa = address(0xE41);

    function setUp() public {
        vm.warp(1_700_000_000);
        tok = new MonedaOamenilor(guv);
        vest = new POLVesting(address(tok), guv, trez);

        vm.startPrank(guv);
        tok.setScutit(address(vest), true);
        tok.emite(guv, 1_000_000e18);
        tok.approve(address(vest), type(uint256).max);
        vest.creeazaGrafic(echipa, 100_000e18, 180 days, 730 days);
        vm.stopPrank();
    }

    function test_NimicInainteDeCliff() public {
        skip(179 days);
        assertEq(vest.maturizat(echipa, 0), 0, "s-a eliberat inainte de cliff");
    }

    function test_EliberareGradualaDupaCliff() public {
        skip(365 days);
        uint256 m = vest.maturizat(echipa, 0);
        assertGt(m, 0);
        assertLt(m, 100_000e18, "s-a eliberat tot prea devreme");
    }

    function test_TotDupaDurataCompleta() public {
        skip(731 days);
        assertEq(vest.maturizat(echipa, 0), 100_000e18);
    }

    // ==============================================================
    // BUG DIN SPEC: a doua alocare stergea graficul anterior
    // ==============================================================
    function test_ADouaAlocareNuStergePrima() public {
        vm.startPrank(guv);
        vest.creeazaGrafic(echipa, 50_000e18, 90 days, 365 days);
        vm.stopPrank();

        assertEq(vest.numarGrafice(echipa), 2, "primul grafic a fost sters");
    }

    // ==============================================================
    // Revocarea nu ia inapoi ce s-a maturizat deja
    // ==============================================================
    function test_RevocareaPastreazaCeSaMaturizat() public {
        skip(365 days);
        uint256 castigat = vest.maturizat(echipa, 0);

        vm.prank(guv);
        vest.revoca(echipa, 0);

        vm.prank(echipa);
        vest.elibereaza(0);

        assertEq(tok.balanceOf(echipa), castigat, "s-a confiscat retroactiv");
    }

    function test_RestulSeIntoarceLaTrezorerie() public {
        skip(365 days);
        uint256 castigat = vest.maturizat(echipa, 0);

        vm.prank(guv);
        vest.revoca(echipa, 0);

        assertEq(tok.balanceOf(trez), 100_000e18 - castigat, "restul nu s-a returnat");
    }
}
