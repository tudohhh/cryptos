// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {MonedaOamenilor} from "../src/MonedaOamenilor.sol";
import {SavingsVault} from "../src/SavingsVault.sol";
import {QuadraticDAO} from "../src/QuadraticDAO.sol";
import {CircuitBreaker} from "../src/CircuitBreaker.sol";
import {SessionKeysManager} from "../src/SessionKeysManager.sol";
import {POLVesting} from "../src/POLVesting.sol";

/// @title Deploy — Base Sepolia
/// @notice Ordinea din acest script nu e cosmetica. Facuta gresit, lasa
///         protocolul intr-o stare in care o singura adresa il controleaza,
///         sau in care Vault-ul isi erodeaza propriile depozite.
///
/// ETAPA CRITICA: PREDAREA ROLURILOR (pasul 5).
/// Cel care face deploy primeste inevitabil rolurile de guvernanta, ca sa
/// poata configura. Daca nu le cedeaza la final, tot discursul despre
/// guvernanta descentralizata e fals: o cheie privata poate schimba orice
/// parametru fara vot. Scriptul verifica la final ca predarea chiar s-a
/// facut si da revert daca nu.
///
/// Rulare:
///   forge script script/Deploy.s.sol --rpc-url $BASE_SEPOLIA_RPC \
///     --broadcast --verify
contract Deploy is Script {
    MonedaOamenilor public token;
    SavingsVault public vault;
    QuadraticDAO public dao;
    CircuitBreaker public breaker;
    SessionKeysManager public sesiuni;
    POLVesting public vesting;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);

        // envAddress, NU envOr. Cu `envOr(..., deployer)`, o variabila de
        // mediu uitata facea tacut ca gardianul, trezoreria si stakingul sa
        // fie toate cheia de deploy — adica exact concentrarea de putere pe
        // care restul scriptului incearca sa o desfaca. Mai bine esueaza
        // deploy-ul cu "variabila lipseste" decat sa reuseasca gresit.
        // Constatarea §6.2 din docs/AUDIT-JURIDIC.md.
        address gardian = vm.envAddress("GARDIAN");
        address trezorerie = vm.envAddress("TREZORERIE");
        address staking = vm.envAddress("STAKING");

        require(gardian != deployer, "GARDIAN nu poate fi cheia de deploy");
        require(trezorerie != deployer, "TREZORERIE nu poate fi cheia de deploy");

        vm.startBroadcast(pk);

        // --- 1. Contractele ---
        token = new MonedaOamenilor(deployer);
        breaker = new CircuitBreaker(deployer);
        vault = new SavingsVault(address(token), deployer);
        dao = new QuadraticDAO(address(token), gardian);
        sesiuni = new SessionKeysManager(address(token));
        vesting = new POLVesting(address(token), deployer, trezorerie);

        // --- 2. Scutiri de demurrage ---
        // OBLIGATORIU inainte ca vreun token sa ajunga in contractele astea.
        // Fara scutire, Vault-ul isi erodeaza propriile depozite si mizele
        // din DAO se topesc in timpul votarii — exact opusul scopului lor.
        token.setScutit(address(vault), true);
        token.setScutit(address(dao), true);
        token.setScutit(address(vesting), true);
        token.setScutit(address(sesiuni), true);

        // --- 3. Destinatiile pentru 33/33/34 ---
        // setDestinatii scuteste automat trezoreria si stakingul.
        token.setDestinatii(trezorerie, staking);
        vault.setTrezorerie(trezorerie);

        // --- 4. Lista alba a DAO-ului ---
        // Trebuie facuta INAINTE de prima propunere: initializeazaPermisiuni
        // refuza dupa aceea. Aici alegem exact ce poate schimba guvernanta.
        // Observa ce NU e pe lista: `emite`. O propunere nu trebuie sa poata
        // crea tokeni la infinit.
        bytes4[] memory permise = new bytes4[](4);
        permise[0] = MonedaOamenilor.setRate.selector;
        permise[1] = MonedaOamenilor.setTaxa.selector;
        permise[2] = MonedaOamenilor.setPraguri.selector;
        permise[3] = MonedaOamenilor.setScutit.selector;
        // gardian == deployer in configuratia implicita; daca gardianul e
        // alt multisig, pasul asta se face din el.
        if (gardian == deployer) {
            dao.initializeazaPermisiuni(address(token), permise);
        } else {
            console.log("ATENTIE: ruleaza initializeazaPermisiuni din gardian");
        }

        // --- 5. PREDAREA ROLURILOR ---
        token.grantRole(token.GUVERNANTA(), address(dao));
        vault.grantRole(vault.GUVERNANTA(), address(dao));
        breaker.grantRole(breaker.GUVERNANTA(), address(dao));

        // Renuntarea, in ordine: intai rolurile de lucru, la final adminul.
        // Odata renuntat DEFAULT_ADMIN_ROLE, operatiunea e ireversibila.
        token.renounceRole(token.GUVERNANTA(), deployer);
        token.renounceRole(token.EMITENT(), deployer);
        vault.renounceRole(vault.GUVERNANTA(), deployer);
        breaker.renounceRole(breaker.GUVERNANTA(), deployer);

        token.grantRole(token.DEFAULT_ADMIN_ROLE(), address(dao));
        vault.grantRole(vault.DEFAULT_ADMIN_ROLE(), address(dao));
        breaker.grantRole(breaker.DEFAULT_ADMIN_ROLE(), address(dao));

        token.renounceRole(token.DEFAULT_ADMIN_ROLE(), deployer);
        vault.renounceRole(vault.DEFAULT_ADMIN_ROLE(), deployer);
        breaker.renounceRole(breaker.DEFAULT_ADMIN_ROLE(), deployer);

        // POLVesting lipsea complet din etapa asta. Deployer-ul ramanea
        // administrator PERPETUU — putea crea si revoca grafice de vesting
        // oricand, fara vot — in timp ce _raport() afisa contrariul.
        // Constatarea §0.4.C din docs/AUDIT-JURIDIC.md.
        vesting.setAdministrator(address(dao));

        vm.stopBroadcast();

        _verifica(deployer);
        _raport();
    }

    /// @dev Verificari care dau revert daca predarea nu s-a facut complet.
    ///      Mai bine esueaza deploy-ul decat sa ramana o cheie cu puteri
    ///      depline si nimeni sa nu observe.
    function _verifica(address deployer) internal view {
        require(!token.hasRole(token.DEFAULT_ADMIN_ROLE(), deployer), "deployer inca e admin pe token");
        require(!token.hasRole(token.GUVERNANTA(), deployer), "deployer inca e guvernanta");
        require(!token.hasRole(token.EMITENT(), deployer), "deployer inca poate emite");
        require(!vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), deployer), "deployer inca e admin pe vault");
        require(!breaker.hasRole(breaker.DEFAULT_ADMIN_ROLE(), deployer), "deployer inca e admin pe breaker");
        require(token.hasRole(token.GUVERNANTA(), address(dao)), "DAO nu are guvernanta");
        require(vesting.administrator() == address(dao), "deployer inca administreaza vesting-ul");
        require(token.scutit(address(vault)), "vault neexceptat: depozitele se erodeaza");
        require(token.scutit(address(dao)), "DAO neexceptat: mizele se topesc");
    }

    function _raport() internal view {
        console.log("");
        console.log("=== ADRESE (Base Sepolia) ===");
        console.log("MonedaOamenilor  ", address(token));
        console.log("SavingsVault     ", address(vault));
        console.log("QuadraticDAO     ", address(dao));
        console.log("CircuitBreaker   ", address(breaker));
        console.log("SessionKeys      ", address(sesiuni));
        console.log("POLVesting       ", address(vesting));
        console.log("");
        console.log("Roluri predate catre DAO, inclusiv administrarea POLVesting.");
        console.log("Verificat on-chain de _verifica(), nu doar afirmat aici.");
        console.log("");
        console.log("RAMAS DE FACUT MANUAL:");
        console.log(" - acorda rolul ORACOL pe CircuitBreaker (minim 5 adrese)");
        console.log(" - acorda rolul VALIDATOR pe CircuitBreaker");
        console.log(" - alimenteaza rezerva Vault-ului din trezorerie");
        console.log(" - emisiunea initiala: nimeni nu mai are EMITENT in afara DAO");
    }
}
