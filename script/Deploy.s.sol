// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {AutomatedEscrow} from "src/AutomatedEscrow.sol";
import {console} from "forge-std/console.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/**
 * @title DeployAutomatedEscrow
 * @notice Script para desplegar el contrato AutomatedEscrow en Base Sepolia
 * @dev Ejecutar con: forge script script/Deploy.s.sol:DeployAutomatedEscrow --rpc-url base_sepolia --broadcast --verify
 */
// script/Deploy.s.sol

contract DeployAutomatedEscrow is Script {
    
    function run() external returns (AutomatedEscrow) {
        
        // 1. OBTENER LA DIRECCIÓN DEL TOKEN DE UNA VARIABLE DE ENTORNO
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS"); 
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("=================================================");
        console.log("Desplegando AutomatedEscrow en Base Sepolia...");
        console.log("=================================================");
        console.log("Deployer address:", vm.addr(deployerPrivateKey));
        
        // 2. USAR LA VARIABLE OBTENIDA EN SU LUGAR
        console.log("Token address:", tokenAddress);
        console.log("Chain ID:", block.chainid);
        
        // 3. ACTUALIZAR LA REGLA DE REQUIRE
        require(tokenAddress != address(0), "ERROR: Debes configurar TOKEN_ADDRESS en tu entorno");
        
        // Iniciar broadcast (transacciones reales en la blockchain)
        vm.startBroadcast(deployerPrivateKey);
        
        // Desplegar el contrato
        // 4. USAR LA VARIABLE OBTENIDA EN LA INSTANCIACIÓN
        AutomatedEscrow escrow = new AutomatedEscrow(tokenAddress);
        
        // ... (resto del script sin cambios)
        
        return escrow;
    }
}

/**
 * @title DeployMockToken
 * @notice Script para desplegar un token ERC20 de prueba en Base Sepolia
 * @dev Ejecutar con: forge script script/Deploy.s.sol:DeployMockToken --rpc-url base_sepolia --broadcast --verify
 */
contract DeployMockToken is Script {
    
    function run() external returns (address) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=================================================");
        console.log("Desplegando MockERC20 en Base Sepolia...");
        console.log("=================================================");
        console.log("Deployer address:", deployer);
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Desplegar token mock
        MockERC20ForDeploy token = new MockERC20ForDeploy("Test USDC", "TUSDC");
        
        // Mintear tokens iniciales al deployer (para testing)
        token.mint(deployer, 1_000_000 * 10**18); // 1 millón de tokens
        
        vm.stopBroadcast();
        
        console.log("=================================================");
        console.log("Token desplegado exitosamente!");
        console.log("MockERC20 address:", address(token));
        console.log("Balance del deployer:", token.balanceOf(deployer) / 10**18, "tokens");
        console.log("=================================================");
        console.log("");
        console.log("IMPORTANTE: Copia esta direccion y usala en Deploy.s.sol:");
        console.log("TOKEN_ADDRESS = %s;", address(token));
        console.log("");
        console.log("Verifica el token en:");
        console.log("https://sepolia.basescan.org/address/%s", address(token));
        console.log("=================================================");
        
        return address(token);
    }
}

/**
 * @title MockERC20ForDeploy
 * @notice Contrato auxiliar de token ERC20 para deployment
 */
contract MockERC20ForDeploy is ERC20 {
    constructor(string memory name, string memory symbol) 
        ERC20(name, symbol) {}
    
    /**
     * @notice Función pública para mintear tokens
     * @param to Dirección destinataria
     * @param amount Cantidad de tokens a mintear
     */
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
    
    /**
     * @notice Función pública para quemar tokens
     * @param from Dirección desde donde quemar
     * @param amount Cantidad de tokens a quemar
     */
    function burn(address from, uint256 amount) public {
        _burn(from, amount);
    }
}